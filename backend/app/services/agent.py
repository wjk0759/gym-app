"""Bounded coach agent: model chooses tools, Python owns all writes.

The model is deliberately not allowed to write a plan directly. It can read
context, ask for a proposal, and remember a preference. Applying a proposal is
a separate, user-authenticated endpoint.
"""

from __future__ import annotations

import json
import logging
import re
import time
from datetime import date, datetime, timedelta, timezone
from typing import Any
from uuid import uuid4

from sqlalchemy import and_, func, select
from sqlalchemy.orm import Session

from ..config import settings
from ..models import (
    AgentPlanProposal,
    AgentRun,
    AgentStep,
    ChatMessage,
    FoodLog,
    MealPlan,
    PlanDayState,
    Profile,
    Program,
    SetLog,
    WorkoutSession,
    utcnow,
)
from . import llm
from .citations import build_reply_citations
from .coach_actions.schemas import (
    DeleteFoodLogPayload,
    DeleteWorkoutPayload,
    LogFoodPayload,
    LogPlannedMealPayload,
    LogWorkoutPayload,
    UpdateFoodLogPayload,
    UpdateWorkoutPayload,
)
from .coach_context import build_coach_context, recent_training
from .coach_core import coach_core_prompt
from .diet_review import build_diet_review, utc_window
from .exercise_search import search_exercise_payload
from .food_text import resolve_food_text
from .memory import remember_facts, schedule_memory_extraction
from .plan_generator import build_template_plan, validate_plan_for_user
from .plan_validator import PlanValidationError
from .prompt_registry import prompt_version
from .queries import active_goal, active_program
from .reply_guard import review_reply
from .safety import assess_safety
from .serializers import save_plan
from .training_history import (
    exercise_history_payload,
    workout_detail_payload,
)

logger = logging.getLogger(__name__)

MAX_STEPS = 7
# 一周最多 7 天；整周取消/批量跳过应在一次工具调用里完成，
# 否则模型会被“最多 3 个动作”的校验逼着拆成多轮，延迟从十几秒涨到一分钟以上。
MAX_APP_ACTIONS = 7
PROPOSAL_TTL_MINUTES = 30
ALLOWED_TOOLS = {
    "get_context",
    "get_recent_training",
    "get_exercise_history",
    "get_workout_detail",
    "lookup_exercise",
    "resolve_food",
    "propose_plan",
    "propose_app_actions",
    "remember",
}
APP_ACTION_TYPES = {
    "reschedule_training",
    "skip_training",
    "start_training",
    "open_screen",
    "update_goal",
    "log_body_metric",
    "create_diet_plan",
    "swap_diet_meal",
    "log_food",
    "log_planned_meal",
    "update_food_log",
    "delete_food_log",
    "log_workout",
    "update_workout_log",
    "delete_workout_log",
    "recognize_equipment",
    "analyze_body",
    "modify_workout",
}
APP_SCREENS = {
    "today",
    "plan",
    "coach",
    "equipment",
    "profile",
    "training_schedule",
    "nutrition",
    "body_checkin",
    "profile_edit",
    "workout_history",
    "agent_memory",
    "period_schedule",
}

SPLIT_ALIASES = {
    "1分化": "1分化",
    "全身": "1分化",
    "全身训练": "1分化",
    "fullbody": "1分化",
    "full body": "1分化",
    "3分化": "3分化",
    "推拉腿": "3分化",
    "推/拉/腿": "3分化",
    "推、拉、腿": "3分化",
    "pushpulllegs": "3分化",
    "push pull legs": "3分化",
    "5分化": "5分化",
    "胸背腿肩手臂": "5分化",
    "胸/背/腿/肩/手臂": "5分化",
}


def _forced_food_log_intent(message: str) -> bool:
    """A narrow guard for the common "log what I ate" phrasing.

    The model still resolves the food and writes the confirmation; this only
    prevents it from turning an explicit logging request into `open_screen`.
    """
    text = message.strip()
    if any(token in text for token in ("打开饮食", "饮食页", "看看饮食")):
        return False
    if _forced_workout_log_intent(text):
        return False
    return bool(
        re.search(
            r"帮我记|记一下|记录一下|补记|帮我记录|记饮食|记录饮食|"
            r"吃了.{0,40}(记|记录)|喝了.{0,40}(记|记录)",
            text,
        )
    )


def _forced_workout_log_intent(message: str) -> bool:
    text = message.strip()
    if any(token in text for token in ("开始训练", "打开训练", "训练页")):
        return False
    # "练完吃了一碗面" is a food-logging request, not a workout record.
    if re.search(r"吃|喝|奶茶|饭|餐|粉|面", text):
        return False
    return bool(
        re.search(
            r"跑了|骑车|游泳|练完|练了|补录.{0,8}训练|记录.{0,8}训练|"
            r"刚才那次训练|昨天.{0,8}(跑|练)",
            text,
        )
    )


def _normalize_split(value: Any) -> str | None:
    if value is None:
        return None
    text = str(value).strip().lower().replace(" ", "")
    text = text.replace("，", "/").replace("、", "/").replace("\\", "/")
    text = re.sub(r"/+", "/", text)
    return SPLIT_ALIASES.get(text) or SPLIT_ALIASES.get(
        str(value).strip()
    )

AGENT_INSTRUCTIONS = """你可以读取用户状态、读取训练记录、生成计划草案、记录长期偏好，并为用户准备 App 内的可执行操作。

用户追问省略主语时（如“那明天怎么调”“这个怎么安排”），优先承接上一轮的主题和限制：上一轮聊饮食就答饮食，上一轮聊动作就答动作，不要跳到训练计划或身体数据；只有用户明确换话题时才切换。

你每一步只能输出一个 JSON 对象，不要输出 Markdown：
{"action":"tool","tool":"get_context","arguments":{}}
{"action":"tool","tool":"get_recent_training","arguments":{"days":30}}
{"action":"tool","tool":"lookup_exercise","arguments":{"query":"弹力带划船","limit":3}}
{"action":"tool","tool":"resolve_food","arguments":{"text":"湿炒螺蛳粉一份，半杯奶茶","meal":"lunch","date":"2026-11-13"}}
{"action":"tool","tool":"get_exercise_history","arguments":{"slug":"bench_press","limit":5}}
{"action":"tool","tool":"get_workout_detail","arguments":{"session_id":"训练记录ID"}}
{"action":"tool","tool":"propose_plan","arguments":{"weekly_days":3,"weekdays":[2,4,6],"session_minutes":45,"split":"3分化","weeks":4,"focus":["back","shoulders"]}}
{"action":"tool","tool":"propose_app_actions","arguments":{"actions":[{"type":"reschedule_training","title":"把明天的训练改到周四","summary":"保留原训练内容，只调整日期","requires_confirmation":true,"payload":{"day_id":"本地训练日ID","target_date":"2026-10-29"}}]}}
{"action":"tool","tool":"propose_app_actions","arguments":{"actions":[{"type":"log_body_metric","title":"记录体重 70kg","summary":"写入今天身体数据","requires_confirmation":true,"payload":{"weight_kg":70}}]}}
{"action":"tool","tool":"propose_app_actions","arguments":{"actions":[{"type":"create_diet_plan","title":"生成本周碳循环饮食计划","summary":"训练日高碳、休息日低碳，蛋白质固定","requires_confirmation":true,"payload":{"strategy":"carb_cycle","week_start":"2026-10-26"}}]}}
{"action":"tool","tool":"propose_app_actions","arguments":{"actions":[{"type":"swap_diet_meal","title":"把周四午餐换一餐","summary":"保持热量和蛋白质不变，只替换菜品","requires_confirmation":true,"payload":{"date":"2026-11-12","meal":"lunch"}}]}}
{"action":"tool","tool":"propose_app_actions","arguments":{"actions":[{"type":"log_food","title":"记录午餐：湿炒螺蛳粉和奶茶","summary":"约 775 kcal，蛋白质 24.5g","requires_confirmation":true,"payload":{"date":"2026-11-13","meal":"lunch","raw_text":"湿炒螺蛳粉一份，半杯奶茶","items":[{"name":"湿炒螺蛳粉","portion":"1份","grams":500,"kcal":600,"protein_g":22,"carbs_g":80,"fat_g":18,"confidence":0.72},{"name":"奶茶","portion":"半杯","grams":250,"kcal":175,"protein_g":2.5,"carbs_g":30,"fat_g":5.8,"confidence":0.68}]}}]}}
{"action":"tool","tool":"propose_app_actions","arguments":{"actions":[{"type":"log_planned_meal","title":"记录计划午餐","summary":"把今天计划里的午餐记为已吃","requires_confirmation":true,"payload":{"date":"2026-11-13","meal":"lunch"}}]}}
{"action":"tool","tool":"propose_app_actions","arguments":{"actions":[{"type":"log_workout","title":"补录昨天跑步","summary":"30 分钟有氧，写入训练记录","requires_confirmation":true,"payload":{"date":"2026-11-12","title":"跑步","duration_minutes":30,"kind":"cardio"}}]}}
{"action":"tool","tool":"propose_app_actions","arguments":{"actions":[{"type":"update_workout_log","title":"修正昨天训练","summary":"把深蹲重量改成 60kg","requires_confirmation":true,"payload":{"session_id":"训练记录ID","sets":[{"slug":"goblet-squat","weight_kg":60,"reps":8,"rpe":8}]}}]}}
{"action":"tool","tool":"propose_app_actions","arguments":{"actions":[{"type":"recognize_equipment","title":"拍照识别器械","summary":"打开相机识别器械，可加入个人动作库","requires_confirmation":true,"payload":{}}]}}
{"action":"tool","tool":"propose_app_actions","arguments":{"actions":[{"type":"analyze_body","title":"拍照分析体型","summary":"拍全身或半身照，给出训练重点","requires_confirmation":true,"payload":{}}]}}
{"action":"tool","tool":"propose_app_actions","arguments":{"actions":[{"type":"modify_workout","title":"把今天的卧推换成哑铃卧推","summary":"保留组数，改动作和重量","requires_confirmation":true,"payload":{"day_id":"本地训练日ID","scope":"day","changes":[{"op":"swap","from_slug":"bench_press","to_slug":"dumbbell_press"},{"op":"sets","slug":"dumbbell_press","sets":2}]}}]}}
{"action":"tool","tool":"remember","arguments":{"kind":"preference","content":"用户出差期间只有哑铃"}}
{"action":"final","message":"给用户的最终回复"}
{"action":"ask_user","message":"需要补充的信息"}

规则：
1. 用户要调整训练计划、频率、训练日、时长、分化或器械时，先调用 get_context；如果需要评估近期执行情况，再调用 get_recent_training。
2. 只有用户明确描述训练安排或要求改计划时才调用 propose_plan。计划参数默认沿用用户档案，只修改用户明确提出的部分。
3. propose_plan 成功后会返回 proposal_id 和 changes。你要在 final 中告诉用户这是待确认草案，不能声称已经应用。
- 用户明确说想重点练某 1–2 个部位时，propose_plan 的 focus 只能是 chest / back / legs / glutes / shoulders / arms / core；没有明确重点就不要传，也不要用 propose_app_actions 代替。
4. 用户只是问知识、动作、疼痛或恢复建议时，直接 final，不要为了使用工具而使用工具。
5. 疼痛、胸闷、晕厥、呼吸困难、孕期/术后等情况必须建议就医或停止相关训练，不做医疗诊断。用户提到腰突、半月板损伤、肩峰撞击、足底筋膜炎等已知诊断时，不能只给动作替换；先建议找医生/康复师评估，再给无痛范围内的替代。夜间痛、静息痛、持续肿胀或疼痛超过一周，也要建议专业评估。给出“先停/先别练”后，必须补一句什么时候需要专业评估，不能只反问。
6. 不要编造工具、动作 slug、训练记录或用户信息。信息不足时用 ask_user。
7. 不要输出 JSON 以外的内容。
8. 给出训练建议前，优先参考 state.coach_context（服务端已计算好的档案、目标、当前计划、最近训练、饮食、身体数据和记忆）；需要刷新或查看更细的近期记录时再调用 get_context / get_recent_training。不要自己重算计划日期、热量、体重或训练量。
9. 不要用泛泛的“多喝水、坚持训练、循序渐进”凑字数。先给结论，再给 1–2 个具体动作/组数/重量/时间建议，并说明依据；用户没要完整方案时，不要扩成整套计划。列表最多 3 条，每条一句话。
10. 如果用户的安排已经发生变化，直接指出哪一天、哪个动作或哪个参数需要改，不要重复整份计划。
11. 用户要改今天/某天的动作、组数、次数、重量、休息，或删除/增加动作时，必须调用 propose_app_actions，type=modify_workout；不要只给文字建议，也不要用 propose_plan 代替单日改课。
12. modify_workout 的 from_slug/slug 必须是当前计划里已有的动作；换动作/加动作前先用 lookup_exercise 确认目标 slug，不要编造。默认 scope=day，只改指定训练日；用户明确说“以后都/整个计划”时才用 scope=plan。最多 8 条改动；换动作后重量默认不沿用旧动作，需要指定时再加一条 weight；add 只作用于指定训练日，不要用 scope=plan 批量加动作。
13. 改课是待确认操作；final 里要说明“确认后才会改”，不能声称已经改好。
14. 如果 app_context.today_day.in_progress=true，说明训练已经开始；不要用 modify_workout 改当前这次训练，先让用户在训练页用“调整/替换”改本次训练；可以改之后的训练日。
15. 用户问某个动作最近练得怎么样、为什么没进步、下次加不加重量、有没有退步时，先调用 get_exercise_history；用返回的真实每组数据回答，不要用计划目标代替实际完成。
16. 用户问某天/某次训练的具体内容时，调用 get_workout_detail；只引用返回的数据，不要编造重量、次数或 RPE。
17. 用户提到关节、腰、颈、肩、膝、肘、腕疼痛时，即使只是问“要不要停”，回答必须先说停止/减量，并补一句什么情况需要医生或康复师评估；不能只给替代动作。

App Context 和可执行操作：
- state.coach_context 是服务端构建的版本化上下文，包含 profile、goal、current_plan（当前周训练）、recent_training、body_metrics、nutrition_7d、today_nutrition（今天的计划餐、实际摄入和剩余额度）、equipment_library 和 memories；它是回答事实问题的首选依据。回答“今天还能吃多少/计划餐完成了吗”必须读 today_nutrition。
- state.safety_context 是服务端前置安全上下文（未成年、慢性病、用药、跌倒/平衡风险）；必须遵守，必要时建议家长、医生或康复师介入。
- state.app_context 是 iOS 本地计划和当前页面，包含 plan.days（day_id/title/date/completed/skipped/exercises）、today、selected_tab，以及最近一次图片/视频的 visual_context。app_context.plan 是手机端最新计划；如果它和 coach_context.current_plan 冲突，以 app_context.plan 为准（服务端可能还没收到本地改课）。
- state.app_context.visual_context 是图片/视频分析的结构化记忆；history 里的“[图片]”标记表示用户发过附件。用户说“图中 / 这张 / 她 / 他 / 刚才那张”时，先结合 visual_context 和 history 回答，绝对不要说自己没收到图、看不到人或没有图片。
- 只要本轮存在 visual_context，且用户问的是这张图/视频里的动作、体型、体脂、器械或食物，当前结论必须以 visual_context 为准；coach_context.body_metrics 只能用于历史对比，不能覆盖本次视觉结果。
- 用户没有发图却要求“看照片估体脂”时，先要一张全身正面/侧面照和身高体重腰围；不要把历史 body_fat_pct 说成本次视觉估算。用户问“现在体脂多少”但没有本轮图片时，只说明这次看不到照片并请用户发当前照片，不要报历史体脂数字，即使用“上次记录”标注也不要说。
- 体脂只输出一个约数，例如“大概 20% 左右”；不展示区间、不给小数。用户问“降了吗/最近怎么样”时，也要先给本次 visual_context 的约数，再拿历史 body_metrics 对比；不要用历史值代替本次结论。用户要求记录时，调用 log_body_metric，payload 至少包含 body_fat_pct；只记录体脂也可以，不要因为缺体重就不调用，更不要编体重/腰围。
- 如果 visual_context 不足以回答追问，说明上次分析里能看到什么、还缺什么，再请用户重发或补拍；不要假装重新看了图，也不要要求用户把同一张图再发一遍来“证明”你看过。
- 用户追问图片中人物或物品的可见属性时，先给基于 visual_context 的最佳判断，再说明限制；不评价美丑、不诊断、不制造焦虑。
- state.coach_skill 仅用于兼容旧客户端；当前统一为 AI 私人健身教练，不区分康复师/营养师模式。训练、饮食、恢复、器械和日程都可以直接回答，并识别和准备 App 操作。
- 用户要求改期、跳过、开始训练、打开页面或修改目标时，必须调用 propose_app_actions，不要只在 final 里描述。
- 只能使用这些 action type：reschedule_training、skip_training、start_training、open_screen、update_goal、log_body_metric、create_diet_plan、swap_diet_meal、log_food、log_planned_meal、update_food_log、delete_food_log、log_workout、update_workout_log、delete_workout_log、recognize_equipment、analyze_body、modify_workout。
- 用户说“我的体重现在是 70kg”时，调用 log_body_metric，payload 至少包含 weight_kg（可选 body_fat_pct、waist_cm），不要让用户自己去页面填写。
- 体重、体脂、腰围等身体数据只能用 propose_app_actions + log_body_metric；绝对不要用 remember，也不要把 remember 当作更新身体数据的方式。
- 用户想安排饮食计划、碳循环、低碳、高蛋白、地中海、素食、16:8 或换饮食策略时，调用 create_diet_plan。payload.strategy 只能是 balanced / carb_cycle / low_carb / high_protein / mediterranean / vegetarian / time_restricted_16_8，week_start 用周一日期（YYYY-MM-DD，可省略，默认本周）。先说明会按什么策略排，再让用户确认。
- 用户只想替换某一餐、不想重排整周时，调用 swap_diet_meal。payload 必须包含 date（YYYY-MM-DD）和 meal（breakfast / lunch / dinner / snack）；服务端会保持当天热量和三大营养素不变，只换菜品。不要说已经换好，等用户确认。
- 如果 state.forced_intent=log_food，本轮只能使用 get_context、resolve_food、propose_app_actions；propose_app_actions 的 type 必须是 log_food / log_planned_meal / update_food_log / delete_food_log。不要调用 open_screen 或 create_diet_plan。
- 如果 state.forced_intent=log_workout，本轮只能使用 get_context、lookup_exercise、get_exercise_history、propose_app_actions；propose_app_actions 的 type 只能是 log_workout。用户说“练完了/跑了/补录”不是“开始训练”，不要调用 start_training。
- 用户说“我今天吃了/喝了……帮我记一下/补记/记录饮食”时：
  1. 先调用 resolve_food，text 传用户原话，meal 尽量从上下文判断，date 用今天或用户指定日期。
  2. 如果 resolve_food 返回 questions，先 ask_user 补份量，不要直接写。
  3. 如果返回 items，调用 propose_app_actions，type=log_food，payload.items 使用 resolve_food 的结果。
  4. 不要调用 open_screen nutrition，不要调用 create_diet_plan，也不要让用户自己去页面填写。
- 用户说“我吃了计划里的午餐/晚餐”时，调用 log_planned_meal，payload 包含 date 和 meal；这会把计划餐记为完成。
- 用户说“我昨天跑了 30 分钟/今天补录一次训练/把刚才那次训练记上”时，调用 log_workout；payload 至少包含 date、title、duration_minutes，kind 用 strength 或 cardio。不要把“已经练完/补录”误判成 start_training。
- log_workout 的记录日期不能是未来；动作型训练可以带 sets（slug、重量、次数、RPE），有氧可以只写 title + duration。
- 用户要修改或删除已经记录的训练时，调用 update_workout_log / delete_workout_log；session_id 必须来自 recent_training.recent_sessions 或用户明确提供的记录 ID，不要猜。修改动作重量/次数时传完整 sets 列表。
- 用户说“打开饮食页”时才调用 open_screen nutrition；“记录饮食”不等于“打开饮食页”。
- 用户说“把刚才那条饮食改成/删掉”时，使用 update_food_log / delete_food_log，client_id 必须来自 app_context 或用户明确提供的记录 ID；找不到记录就 ask_user，不要猜。
- 用户问某个动作怎么做、主要练哪里、目标肌肉、动作细节、动作替代、器械对应动作时，都要先调用 lookup_exercise，query 用最短动作名（如“弹力带划船”“深蹲”），limit 默认 3。只引用返回的步骤，不要凭记忆编造动作；没有结果就说明没查到，并让用户补充动作名或器械。
- 用户想拍器械、问某个器械怎么练、或想把器械加入个人动作库时，调用 recognize_equipment。payload 可以为空；不要假装已经识别，等用户在相机里拍完。
- 用户想拍体型照、看体态、问训练重点时，调用 analyze_body。payload 可以为空；不要假装已经分析，等用户拍完。
- reschedule_training / skip_training 优先使用 app_context 里存在的 day_id；也可以传 date（YYYY-MM-DD）。改期目标用 target_date；如果用户说“最近空档”，target_date 传 "next_free"。
- 用户要求取消/跳过整周或多天训练时，把每一天的 skip_training 放在同一次 propose_app_actions 的 actions 数组里（最多 7 个），不要拆成多次工具调用。
- open_screen 的 payload.screen 只能是：today、plan、coach、equipment、profile、training_schedule、nutrition、body_checkin、profile_edit、workout_history、agent_memory、period_schedule。
- update_goal 的 payload 字段可包含 goal_type（lose_fat/build_muscle/recomp/endurance）、target_weight_kg、target_date、weekly_days、session_minutes。
- 不要声称操作已执行。final 中应说明“已准备好操作，请确认”，不要声称页面已经打开、训练已经开始或训练已经改期；由 iOS 确认后执行。
- 所有操作（包括 open_screen）都必须让用户点击操作卡后再执行。
"""

SYSTEM_PROMPT = coach_core_prompt() + "\n\n" + AGENT_INSTRUCTIONS
AGENT_PROMPT_VERSION = prompt_version("agent", SYSTEM_PROMPT)
REVIEW_PROMPT_VERSION = "review-rules@v1"


def _safe_json(value: Any) -> Any:
    """Make tool observations safe for JSON columns and the prompt."""
    try:
        return json.loads(json.dumps(value, ensure_ascii=False, default=str))
    except (TypeError, ValueError):
        return {"value": str(value)[:2000]}


def _program_summary(program: Program | None) -> dict | None:
    if program is None:
        return None
    first_week = [day for day in program.days if day.week_index == 1]
    return {
        "id": program.id,
        "title": program.title,
        "version": program.version,
        "weeks": program.weeks,
        "weekly_days": len(first_week),
        "weekdays": sorted(day.weekday for day in first_week),
        "day_titles": [day.title for day in first_week],
        "generated_by": program.generated_by,
    }


def _weekday_label(value: int) -> str:
    return ["一", "二", "三", "四", "五", "六", "日"][max(0, min(6, value - 1))]


def _normalize_weekdays(raw: Any) -> list[int]:
    if not isinstance(raw, (list, tuple)):
        return []
    result = sorted({int(item) for item in raw if str(item).isdigit() and 1 <= int(item) <= 7})
    return result


FOCUS_LABELS = {
    "chest": "胸",
    "back": "背",
    "legs": "腿",
    "glutes": "臀",
    "shoulders": "肩",
    "arms": "手臂",
    "core": "核心",
}
FOCUS_ALIASES = {
    "胸": "chest",
    "胸部": "chest",
    "背": "back",
    "背部": "back",
    "腿": "legs",
    "腿部": "legs",
    "臀": "glutes",
    "臀部": "glutes",
    "肩": "shoulders",
    "肩部": "shoulders",
    "手臂": "arms",
    "胳膊": "arms",
    "核心": "core",
    "腰腹": "core",
}


def _normalize_focus(raw: Any) -> list[str]:
    if not isinstance(raw, (list, tuple)):
        return []
    result: list[str] = []
    for item in raw:
        value = str(item).strip().lower()
        value = FOCUS_ALIASES.get(value, value)
        if value in FOCUS_LABELS and value not in result:
            result.append(value)
        if len(result) >= 2:
            break
    return result


def _make_changes(
    old_program: Program | None,
    old_profile: Profile,
    plan: dict,
    weekly_days: int,
    weekdays: list[int],
    session_minutes: int | None,
    split: str | None,
    focus: list[str] | None = None,
) -> list[str]:
    changes: list[str] = []
    old_weekly = 0
    if old_program:
        old_weekly = len(
            [day for day in old_program.days if day.week_index == 1]
        )
    if old_weekly and old_weekly != weekly_days:
        changes.append(f"每周训练 {old_weekly} → {weekly_days} 天")
    elif not old_weekly:
        changes.append(f"建立每周 {weekly_days} 天的训练节奏")
    if weekdays:
        changes.append("训练日：" + "、".join(f"周{_weekday_label(item)}" for item in weekdays))
    if session_minutes and session_minutes != old_profile.session_minutes:
        changes.append(f"单次训练 {old_profile.session_minutes or 45} → {session_minutes} 分钟")
    if split:
        changes.append(f"训练分化为 {split}")
    if focus:
        changes.append("重点部位：" + "、".join(FOCUS_LABELS[item] for item in focus))
    old_days = len(old_program.days) if old_program else 0
    new_days = len(plan.get("days", []))
    if old_days != new_days:
        changes.append(f"训练日数量 {old_days} → {new_days}")
    if old_program and old_program.title != plan.get("title"):
        changes.append(f"计划标题：{plan.get('title')}")
    return changes


def _serialize_proposal(proposal: AgentPlanProposal) -> dict:
    return {
        "id": proposal.id,
        "title": proposal.title,
        "status": proposal.status,
        "changes": (proposal.diff_data or {}).get("changes", []),
        "diff": proposal.diff_data or {},
        "validation": proposal.validation_data or {},
        "expires_at": proposal.expires_at.isoformat() if proposal.expires_at else None,
    }


def _record_step(
    db: Session,
    run: AgentRun,
    step_type: str,
    *,
    tool_name: str | None = None,
    input_data: dict | None = None,
    output_data: dict | None = None,
    status: str = "ok",
    error: str | None = None,
    latency_ms: int | None = None,
) -> None:
    run.step_count += 1
    db.add(
        AgentStep(
            run_id=run.id,
            step_index=run.step_count,
            step_type=step_type,
            tool_name=tool_name,
            input_json=_safe_json(input_data or {}),
            output_json=_safe_json(output_data or {}),
            status=status,
            error=error,
            latency_ms=latency_ms,
        )
    )


_PENDING_ACTION_CLAIMS = (
    ("已经帮你", "准备帮你"),
    ("已经为你", "准备为你"),
    ("已经取消", "准备取消"),
    ("已经记录", "准备记录"),
    ("已经更新", "准备更新"),
    ("已经改", "准备改"),
    ("已经生效", "确认后生效"),
    ("已为你", "准备为你"),
    ("已帮你", "准备帮你"),
    ("已把", "准备把"),
    ("已取消", "准备取消"),
    ("已记录", "准备记录"),
    ("已更新", "准备更新"),
    ("已改", "准备改"),
    ("已开始", "准备开始"),
    ("已写入", "准备写入"),
    ("已保存", "准备保存"),
    ("已生效", "确认后生效"),
)

def _guard_pending_action_claims(message: str) -> str:
    """Do not let the model claim a card was applied before user confirmation."""
    text = message.strip()
    changed = False
    for old, new in _PENDING_ACTION_CLAIMS:
        if old in text:
            text = text.replace(old, new)
            changed = True
    if changed and "确认" not in text:
        text += "\n\n操作还没有执行，点确认后才生效。"
    return text


_WORKOUT_CHANGE_OPS = {"swap", "sets", "reps", "weight", "rest", "remove", "add"}
_EXERCISE_SLUG_RE = re.compile(r"^[a-z0-9][a-z0-9_-]{1,79}$")


def _workout_int(value: Any, field: str, low: int, high: int) -> int:
    try:
        number = int(value)
    except (TypeError, ValueError) as exc:
        raise ValueError(f"{field} must be an integer") from exc
    if number < low or number > high:
        raise ValueError(f"{field} out of range")
    return number


def _workout_float(value: Any, field: str, low: float, high: float) -> float:
    try:
        number = float(value)
    except (TypeError, ValueError) as exc:
        raise ValueError(f"{field} must be a number") from exc
    if number < low or number > high:
        raise ValueError(f"{field} out of range")
    return round(number, 2)


def _normalize_workout_changes(raw_changes: Any) -> list[dict]:
    """Validate the small, explicit vocabulary the app can apply to one day."""
    if not isinstance(raw_changes, list) or not raw_changes:
        raise ValueError("modify_workout requires a non-empty changes list")
    if len(raw_changes) > 8:
        raise ValueError("at most 8 workout changes are allowed")

    result: list[dict] = []
    for raw in raw_changes:
        if not isinstance(raw, dict):
            continue
        op = str(raw.get("op", "")).strip().lower()
        if op not in _WORKOUT_CHANGE_OPS:
            raise ValueError(f"unsupported workout change: {op}")

        item: dict[str, Any] = {"op": op}
        if op == "swap":
            from_slug = str(raw.get("from_slug", "")).strip()
            to_slug = str(raw.get("to_slug", "")).strip()
            if not _EXERCISE_SLUG_RE.match(from_slug):
                raise ValueError("swap requires from_slug")
            if not _EXERCISE_SLUG_RE.match(to_slug):
                raise ValueError("swap requires to_slug")
            if from_slug == to_slug:
                raise ValueError("swap target must be different")
            item.update({"from_slug": from_slug, "to_slug": to_slug})
        else:
            slug = str(raw.get("slug", "")).strip()
            if not _EXERCISE_SLUG_RE.match(slug):
                raise ValueError(f"{op} requires slug")
            item["slug"] = slug
            if op == "sets":
                item["sets"] = _workout_int(raw.get("sets"), "sets", 1, 10)
            elif op == "reps":
                reps = str(raw.get("reps", "")).strip()
                if not reps or len(reps) > 20 or "\n" in reps:
                    raise ValueError("reps must be a short string")
                item["reps"] = reps
            elif op == "weight":
                item["weight_kg"] = _workout_float(
                    raw.get("weight_kg"), "weight_kg", 0, 500
                )
            elif op == "rest":
                item["rest_sec"] = _workout_int(raw.get("rest_sec"), "rest_sec", 0, 300)
            elif op == "add":
                if raw.get("sets") is not None:
                    item["sets"] = _workout_int(raw.get("sets"), "sets", 1, 10)
                if raw.get("reps") is not None:
                    reps = str(raw.get("reps")).strip()
                    if not reps or len(reps) > 20 or "\n" in reps:
                        raise ValueError("reps must be a short string")
                    item["reps"] = reps
                if raw.get("weight_kg") is not None:
                    item["weight_kg"] = _workout_float(
                        raw.get("weight_kg"), "weight_kg", 0, 500
                    )
                if raw.get("rest_sec") is not None:
                    item["rest_sec"] = _workout_int(
                        raw.get("rest_sec"), "rest_sec", 0, 300
                    )
        result.append(item)

    if not result:
        raise ValueError("no valid workout changes")
    return result


def _normalize_app_actions(
    raw_actions: Any, app_context: dict | None = None
) -> list[dict]:
    if not isinstance(raw_actions, list) or not raw_actions:
        raise ValueError("actions must be a non-empty list")
    if len(raw_actions) > MAX_APP_ACTIONS:
        raise ValueError(f"at most {MAX_APP_ACTIONS} actions are allowed")

    plan_days = []
    if isinstance(app_context, dict):
        plan = app_context.get("plan")
        if isinstance(plan, dict):
            plan_days = plan.get("days") if isinstance(plan.get("days"), list) else []
    allowed_day_ids = {
        str(item.get("id"))
        for item in plan_days
        if isinstance(item, dict) and item.get("id")
    }

    result: list[dict] = []
    for raw in raw_actions:
        if not isinstance(raw, dict):
            continue
        action_type = str(raw.get("type", "")).strip()
        if action_type not in APP_ACTION_TYPES:
            raise ValueError(f"unsupported action type: {action_type}")

        payload = raw.get("payload")
        payload = payload if isinstance(payload, dict) else {}
        day_id = str(payload.get("day_id", "")).strip()
        if day_id and allowed_day_ids and day_id not in allowed_day_ids:
            raise ValueError("day_id is not present in app_context")
        date_value = str(payload.get("date", "")).strip()
        target_date = str(payload.get("target_date", "")).strip()

        def valid_date(value: str) -> bool:
            if not value:
                return False
            try:
                datetime.strptime(value, "%Y-%m-%d")
                return True
            except ValueError:
                return False

        if (
            action_type in {"reschedule_training", "skip_training"}
            and not day_id
            and not valid_date(date_value)
        ):
            raise ValueError(f"{action_type} requires day_id or date")
        if action_type == "reschedule_training":
            if target_date != "next_free" and not valid_date(target_date):
                raise ValueError("target_date must be YYYY-MM-DD or next_free")
            payload["target_date"] = target_date
        if action_type == "open_screen":
            screen = str(payload.get("screen", "")).strip()
            if screen not in APP_SCREENS:
                raise ValueError("unsupported screen")
            payload["screen"] = screen
        if action_type == "update_goal":
            goal_type = str(payload.get("goal_type", "")).strip()
            if goal_type and goal_type not in {
                "lose_fat",
                "build_muscle",
                "recomp",
                "endurance",
            }:
                raise ValueError("unsupported goal_type")
            if not any(
                key in payload
                for key in (
                    "goal_type",
                    "target_weight_kg",
                    "target_date",
                    "weekly_days",
                    "session_minutes",
                )
            ):
                raise ValueError("update_goal requires at least one field")
        if action_type == "log_body_metric":
            raw_weight = payload.get("weight_kg")
            if raw_weight is None:
                if payload.get("body_fat_pct") is None and payload.get("waist_cm") is None:
                    raise ValueError(
                        "log_body_metric requires weight_kg, body_fat_pct or waist_cm"
                    )
            else:
                try:
                    weight = float(raw_weight)
                except (TypeError, ValueError) as exc:
                    raise ValueError("weight_kg must be a number") from exc
                if weight < 25 or weight > 300:
                    raise ValueError("weight_kg out of range")
                payload["weight_kg"] = weight
            if payload.get("body_fat_pct") is not None:
                try:
                    fat = float(payload["body_fat_pct"])
                except (TypeError, ValueError) as exc:
                    raise ValueError("body_fat_pct must be a number") from exc
                if fat < 3 or fat > 60:
                    raise ValueError("body_fat_pct out of range")
                payload["body_fat_pct"] = fat
        if action_type == "create_diet_plan":
            strategy = str(payload.get("strategy") or "balanced").strip()
            if strategy not in {
                "balanced",
                "carb_cycle",
                "low_carb",
                "high_protein",
                "mediterranean",
                "vegetarian",
                "time_restricted_16_8",
            }:
                raise ValueError("unsupported diet strategy")
            payload["strategy"] = strategy
            week_start = str(payload.get("week_start") or "").strip()
            if week_start:
                if not valid_date(week_start):
                    raise ValueError("week_start must be YYYY-MM-DD")
                payload["week_start"] = week_start
        if action_type == "log_food":
            if not valid_date(date_value):
                payload["date"] = datetime.now(REVIEW_TZ).date().isoformat()
            if not isinstance(payload.get("items"), list) or not payload["items"]:
                raise ValueError("log_food requires items; call resolve_food first")
            try:
                payload = LogFoodPayload.model_validate(payload).model_dump(
                    mode="json"
                )
            except Exception as exc:
                raise ValueError(f"log_food payload invalid: {exc}") from exc
        if action_type == "log_planned_meal":
            if not valid_date(date_value):
                payload["date"] = datetime.now(REVIEW_TZ).date().isoformat()
            try:
                payload = LogPlannedMealPayload.model_validate(payload).model_dump(
                    mode="json"
                )
            except Exception as exc:
                raise ValueError(f"log_planned_meal payload invalid: {exc}") from exc
        if action_type in {"update_food_log", "delete_food_log"}:
            try:
                model = (
                    UpdateFoodLogPayload
                    if action_type == "update_food_log"
                    else DeleteFoodLogPayload
                )
                payload = model.model_validate(payload).model_dump(mode="json")
            except Exception as exc:
                raise ValueError(f"{action_type} payload invalid: {exc}") from exc
        if action_type == "log_workout":
            if not valid_date(date_value):
                payload["date"] = datetime.now(REVIEW_TZ).date().isoformat()
            try:
                payload = LogWorkoutPayload.model_validate(payload).model_dump(
                    mode="json"
                )
            except Exception as exc:
                raise ValueError(f"log_workout payload invalid: {exc}") from exc
        if action_type in {"update_workout_log", "delete_workout_log"}:
            try:
                model = (
                    UpdateWorkoutPayload
                    if action_type == "update_workout_log"
                    else DeleteWorkoutPayload
                )
                payload = model.model_validate(payload).model_dump(mode="json")
            except Exception as exc:
                raise ValueError(f"{action_type} payload invalid: {exc}") from exc
        if action_type == "swap_diet_meal":
            meal = str(payload.get("meal") or "").strip().lower()
            if meal not in {"breakfast", "lunch", "dinner", "snack"}:
                raise ValueError("swap_diet_meal requires a valid meal")
            payload["meal"] = meal
            if not valid_date(date_value):
                payload["date"] = datetime.now(REVIEW_TZ).date().isoformat()
            else:
                payload["date"] = date_value
        if action_type == "modify_workout":
            payload["changes"] = _normalize_workout_changes(payload.get("changes"))
            scope = str(payload.get("scope") or "day").strip().lower()
            if scope not in {"day", "plan"}:
                raise ValueError("unsupported modify_workout scope")
            payload["scope"] = scope

        title = str(raw.get("title") or action_type).strip()[:120]
        summary = str(raw.get("summary") or "").strip()[:500]
        result.append(
            {
                "id": str(uuid4()),
                "type": action_type,
                "title": title,
                "summary": summary,
                "requires_confirmation": True,
                "payload": _safe_json(payload),
            }
        )
    if not result:
        raise ValueError("no valid actions")
    return result


def _tool_result(
    db: Session,
    run: AgentRun,
    user_id: str,
    tool: str,
    arguments: dict,
    app_context: dict | None = None,
) -> dict:
    if tool == "get_context":
        return {
            "ok": True,
            "context": build_coach_context(db, user_id, app_context=app_context),
        }
    if tool == "get_recent_training":
        return {"ok": True, **recent_training(db, user_id, int(arguments.get("days", 30)))}
    if tool == "get_exercise_history":
        slug = str(arguments.get("slug") or "").strip()
        try:
            limit = int(arguments.get("limit") or 5)
        except (TypeError, ValueError):
            limit = 5
        return exercise_history_payload(db, user_id, slug, limit)
    if tool == "get_workout_detail":
        session_id = str(arguments.get("session_id") or "").strip()
        return workout_detail_payload(db, user_id, session_id)
    if tool == "remember":
        kind = str(arguments.get("kind", "preference"))[:30]
        content = str(arguments.get("content", "")).strip()[:1000]
        if not content:
            return {"ok": False, "error": "memory content is empty"}
        # 身体数据是结构化 App 数据，不是长期记忆。模型有时会反复调用
        # remember 试图记录体重，最终耗尽步骤；这里直接给出可恢复的错误。
        if kind in {"body_metric", "metric", "weight", "body"} or any(
            token in content for token in ("体重", "体脂", "腰围")
        ):
            return {
                "ok": False,
                "error": "身体数据不要写入 remember；请调用 propose_app_actions，type=log_body_metric",
            }
        saved = remember_facts(
            db,
            user_id,
            [{"kind": kind, "content": content, "confidence": 1.0}],
            source="agent",
        )
        return {
            "ok": True,
            "remembered": [
                {"kind": item.kind, "key": item.memory_key, "content": item.content}
                for item in saved
            ],
        }
    if tool == "lookup_exercise":
        query = str(arguments.get("query") or "").strip()
        if not query:
            return {"ok": False, "error": "lookup_exercise requires query"}
        try:
            limit = int(arguments.get("limit") or 3)
        except (TypeError, ValueError):
            limit = 3
        return search_exercise_payload(query, limit)

    if tool == "propose_plan":
        profile = db.get(Profile, user_id)
        if profile is None:
            return {"ok": False, "error": "用户还没有完成个人档案"}
        weekdays = _normalize_weekdays(arguments.get("weekdays"))
        weekly_days = len(weekdays) if weekdays else max(
            1, min(7, int(arguments.get("weekly_days") or profile.weekly_days or 3))
        )
        session_minutes = arguments.get("session_minutes")
        if session_minutes is not None:
            session_minutes = max(15, min(180, int(session_minutes)))
        split = _normalize_split(arguments.get("split"))
        focus = _normalize_focus(arguments.get("focus"))
        weeks = max(1, min(8, int(arguments.get("weeks") or 4)))
        goal = active_goal(db, user_id)
        try:
            built = build_template_plan(
                db,
                profile,
                goal.type if goal else "recomp",
                weeks=weeks,
                split=split,
                weekly_days=weekly_days,
                session_minutes=session_minutes,
                weekdays=weekdays,
                focus=focus,
            )
        except Exception as exc:  # noqa: BLE001 - tool error is returned to the model
            return {"ok": False, "error": str(exc)[:500]}

        plan = built["plan"]
        old_program = active_program(db, user_id)
        changes = _make_changes(
            old_program,
            profile,
            plan,
            weekly_days,
            weekdays,
            session_minutes,
            split,
            focus,
        )
        diff = {
            "changes": changes,
            "base": _program_summary(old_program),
            "proposed": {
                "title": plan.get("title"),
                "weekly_days": weekly_days,
                "weekdays": weekdays,
                "session_minutes": session_minutes or profile.session_minutes or 45,
                "weeks": weeks,
                "day_count": len(plan.get("days", [])),
                "focus": focus,
            },
        }
        for old in db.execute(
            select(AgentPlanProposal).where(
                AgentPlanProposal.user_id == user_id,
                AgentPlanProposal.status == "draft",
            )
        ).scalars():
            old.status = "superseded"
        proposal = AgentPlanProposal(
            user_id=user_id,
            run_id=run.id,
            base_program_id=old_program.id if old_program else None,
            base_version=old_program.version if old_program else None,
            status="draft",
            title=plan.get("title", "训练计划")[:120],
            plan_data=plan,
            diff_data=diff,
            validation_data={"warnings": built["warnings"], "valid": True},
            expires_at=utcnow() + timedelta(minutes=PROPOSAL_TTL_MINUTES),
        )
        db.add(proposal)
        db.commit()
        return {"ok": True, "proposal": _serialize_proposal(proposal)}
    if tool == "propose_app_actions":
        try:
            actions = _normalize_app_actions(arguments.get("actions"), app_context)
        except ValueError as exc:
            return {"ok": False, "error": str(exc)}
        return {"ok": True, "actions": actions}
    return {"ok": False, "error": f"unknown tool: {tool}"}


REVIEW_TZ = timezone(timedelta(hours=8))


def _week_start(now: datetime) -> datetime:
    local = now.astimezone(REVIEW_TZ)
    start = (local - timedelta(days=local.weekday())).replace(
        hour=0, minute=0, second=0, microsecond=0
    )
    return start.astimezone(timezone.utc)


def _review_snapshot(
    db: Session, user_id: str, start: datetime, end: datetime
) -> dict:
    where = (
        WorkoutSession.user_id == user_id,
        WorkoutSession.started_at >= start,
        WorkoutSession.started_at < end,
    )
    aggregate = db.execute(
        select(
            func.count(func.distinct(WorkoutSession.id)),
            func.count(SetLog.id),
            func.coalesce(func.sum(SetLog.weight_kg * SetLog.reps), 0.0),
            func.coalesce(func.sum(SetLog.rpe), 0.0),
        )
        .select_from(WorkoutSession)
        .outerjoin(
            SetLog,
            and_(
                SetLog.session_id == WorkoutSession.id,
                SetLog.completed.is_(True),
            ),
        )
        .where(*where)
    ).one()
    durations = list(
        db.execute(
            select(WorkoutSession.duration_min).where(
                *where, WorkoutSession.duration_min.is_not(None)
            )
        ).scalars()
    )
    last_session_at = db.scalar(select(func.max(WorkoutSession.started_at)).where(*where))
    completed_sets = int(aggregate[1] or 0)
    rpe_total = float(aggregate[3] or 0)
    return {
        "sessions": int(aggregate[0] or 0),
        "completed_sets": completed_sets,
        "volume_kg": round(float(aggregate[2] or 0), 1),
        "average_rpe": round(rpe_total / completed_sets, 1)
        if completed_sets
        else None,
        "average_duration_min": round(sum(durations) / len(durations))
        if durations
        else 0,
        "last_session_at": last_session_at.isoformat() if last_session_at else None,
    }


def _plan_week_adherence(
    db: Session,
    program: Program | None,
    user_id: str,
    week_start: datetime,
    week_end: datetime,
    now: datetime,
) -> dict:
    """Count planned, completed, skipped and missed plan days for one week.

    The schedule comes from ``plan_day_states`` where the client has moved a
    day, and falls back to the plan's week rows otherwise. A day counts as
    completed only when the linked workout covered its planned sets; partial
    sessions remain missed until finished.
    """
    empty = {
        "planned": 0,
        "completed": 0,
        "skipped": 0,
        "missed": 0,
        "rate": None,
    }
    if program is None:
        return empty

    local_start = week_start.astimezone(REVIEW_TZ)
    week_dates = {(local_start + timedelta(days=offset)).date() for offset in range(7)}
    today_local = now.astimezone(REVIEW_TZ).date()

    states = {
        item.day_id: item
        for item in db.execute(
            select(PlanDayState).where(
                PlanDayState.user_id == user_id,
                PlanDayState.plan_id == program.id,
            )
        )
        .scalars()
        .all()
    }
    day_ids = [day.id for day in program.days]
    completed_sets: dict[str, int] = {}
    if day_ids:
        rows = db.execute(
            select(WorkoutSession.program_day_id, func.count(SetLog.id))
            .select_from(WorkoutSession)
            .outerjoin(
                SetLog,
                and_(
                    SetLog.session_id == WorkoutSession.id,
                    SetLog.completed.is_(True),
                ),
            )
            .where(
                WorkoutSession.user_id == user_id,
                WorkoutSession.program_day_id.in_(day_ids),
                WorkoutSession.started_at >= week_start,
                WorkoutSession.started_at < week_end,
            )
            .group_by(WorkoutSession.program_day_id)
        ).all()
        completed_sets = {str(day_id): int(count or 0) for day_id, count in rows}

    created_at = program.created_at
    if created_at.tzinfo is None:
        created_at = created_at.replace(tzinfo=timezone.utc)
    anchor_local = created_at.astimezone(REVIEW_TZ).date()
    anchor_monday = anchor_local - timedelta(days=anchor_local.weekday())

    planned = completed = skipped = missed = 0
    for day in program.days:
        state = states.get(day.id)
        scheduled = (
            state.assigned_date
            if state is not None and state.assigned_date is not None
            else anchor_monday
            + timedelta(days=(day.week_index - 1) * 7 + day.weekday - 1)
        )
        if scheduled not in week_dates:
            continue
        planned += 1
        if state is not None and state.skipped_at is not None:
            skipped += 1
            continue
        required = sum(max(1, item.sets) for item in day.exercises)
        if completed_sets.get(day.id, 0) >= max(1, required):
            completed += 1
        elif scheduled < today_local:
            missed += 1

    eligible = max(0, planned - skipped)
    return {
        "planned": planned,
        "completed": completed,
        "skipped": skipped,
        "missed": missed,
        "rate": (completed / eligible) if eligible else None,
    }


def generate_weekly_review(db: Session, user_id: str) -> dict:
    """Create an auditable, rule-based weekly review without an LLM call.

    The review is intentionally deterministic: users can request it after every
    workout without spending model tokens, while the run and its tool outputs
    remain visible in the admin Agent audit page.
    """
    profile = db.get(Profile, user_id)
    if profile is None:
        raise ValueError("请先完成个人档案，再生成周复盘")

    now = utcnow()
    week_start = _week_start(now)
    previous_start = week_start - timedelta(days=7)
    current = _review_snapshot(db, user_id, week_start, week_start + timedelta(days=7))
    previous = _review_snapshot(db, user_id, previous_start, week_start)
    context = build_coach_context(db, user_id)
    nutrition = context.get("nutrition_7d") or {}
    program = active_program(db, user_id)
    adherence = _plan_week_adherence(
        db,
        program,
        user_id,
        week_start,
        week_start + timedelta(days=7),
        now,
    )
    planned_days = adherence["planned"]
    eligible_days = max(0, planned_days - adherence["skipped"])
    target = planned_days or max(1, int(profile.weekly_days or 3))
    if eligible_days:
        completion = min(1.5, adherence["completed"] / eligible_days)
    else:
        completion = min(1.5, current["sessions"] / target)
    minutes = profile.session_minutes or 45

    local_week_start = week_start.astimezone(REVIEW_TZ).date()
    local_week_end = local_week_start + timedelta(days=6)
    diet_plans = (
        db.execute(
            select(MealPlan).where(
                MealPlan.user_id == user_id,
                MealPlan.plan_date >= local_week_start,
                MealPlan.plan_date <= local_week_end,
            )
        )
        .scalars()
        .all()
    )
    diet_log_start, diet_log_end = utc_window(local_week_start, local_week_end)
    diet_logs = (
        db.execute(
            select(FoodLog).where(
                FoodLog.user_id == user_id,
                FoodLog.logged_at >= diet_log_start,
                FoodLog.logged_at < diet_log_end,
            )
        )
        .scalars()
        .all()
    )
    diet_review = build_diet_review(
        diet_plans,
        diet_logs,
        local_week_start,
        local_week_end,
    )
    diet_totals = diet_review["totals"]

    wins: list[str] = []
    watchouts: list[str] = []
    actions: list[str] = []

    if current["sessions"] == 0:
        summary = (
            f"本周还没有训练记录。先按计划完成一次 {minutes} 分钟的训练，"
            "不要一上来追求强度，先把节奏找回来。"
        )
        watchouts.append("本周训练频率不足")
        actions.append(f"从今天或明天安排一次 {minutes} 分钟的全身训练")
    elif eligible_days:
        summary = (
            f"本周计划 {planned_days} 次，完成 {adherence['completed']} 次，"
            f"计划完成率 {completion:.0%}；跳过 {adherence['skipped']} 次，"
            f"错过 {adherence['missed']} 次，总容量 {current['volume_kg']:.0f} kg。"
        )
        if adherence["missed"]:
            watchouts.append(f"有 {adherence['missed']} 次计划训练未完成")
        if adherence["completed"] >= 1:
            wins.append("按计划完成了训练")
        if adherence["completed"] >= eligible_days:
            wins.append("本周计划全部完成")
            actions.append("下周保持频率，主力动作在动作稳定时加 2.5% 重量或 +1 次")
        else:
            actions.append(
                f"先补 1 次 {minutes} 分钟训练，优先保留主项，不必把错过的次数全部补回来"
            )
    else:
        if current["sessions"] >= target:
            summary = (
                f"本周完成 {current['sessions']}/{target} 次训练，达到计划目标，"
                f"总容量 {current['volume_kg']:.0f} kg。"
            )
            wins.append("训练频率达标")
            actions.append("下周保持频率，主力动作在动作稳定时加 2.5% 重量或 +1 次")
        else:
            summary = (
                f"本周完成 {current['sessions']}/{target} 次训练，完成率 "
                f"{completion:.0%}，还差 {max(0, target - current['sessions'])} 次。"
            )
            wins.append("已经完成部分训练")
            actions.append(f"剩余时间优先补 1 次 {minutes} 分钟训练，不必追求练到力竭")

    if current["average_rpe"] is not None:
        if current["average_rpe"] >= 8.5:
            watchouts.append("平均 RPE 偏高，恢复压力较大")
            actions.append("下一次同动作降 1 组或降 5% 重量，把 RPE 控制在 7–8")
        elif current["average_rpe"] <= 5.5:
            actions.append("下一次在动作稳定时加 2.5% 重量或 +1 次，逐步增加刺激")

    if previous["volume_kg"] > 0 and current["volume_kg"] > previous["volume_kg"] * 1.1:
        wins.append("训练容量较上周提升")
    elif previous["volume_kg"] > 0 and current["volume_kg"] < previous["volume_kg"] * 0.8:
        watchouts.append("训练容量较上周下降")

    logged_days = int(nutrition.get("logged_days") or 0)
    diet_planned_meals = int(diet_totals["planned_meals"] or 0)
    diet_adherence = diet_totals["adherence_rate"]
    if diet_planned_meals and logged_days == 0:
        watchouts.append("有饮食计划但本周没有记录")
        actions.append(
            f"本周有 {diet_planned_meals} 餐计划；先在午餐或晚餐记录一餐，判断餐单是否合适"
        )
    elif diet_planned_meals and (diet_adherence or 0) < 0.6:
        actions.append(
            f"计划餐只记录了 {diet_totals['logged_plan_meals']}/{diet_planned_meals} 餐；"
            "先把最容易执行的一餐固定下来，不要一次要求全部做到"
        )
    elif logged_days < 3:
        actions.append(
            f"本周只有 {logged_days} 天有饮食记录，先做到每天至少记录一餐，便于判断热量"
        )
    if not wins:
        wins.append("建立了本周训练基线")
    if not actions:
        actions.append("下一次训练后记录 RPE 和训练感受，帮助教练继续调整")

    review = {
        "period": "week",
        "week_start": week_start.astimezone(REVIEW_TZ).date().isoformat(),
        "stats": {
            "sessions": current["sessions"],
            "planned": target,
            "completion_rate": round(completion, 2),
            "planned_days": planned_days,
            "completed_plan_days": adherence["completed"],
            "skipped_plan_days": adherence["skipped"],
            "missed_plan_days": adherence["missed"],
            "adherence_rate": (
                round(adherence["rate"], 2)
                if adherence["rate"] is not None
                else None
            ),
            "volume_kg": current["volume_kg"],
            "average_rpe": current["average_rpe"],
            "average_duration_min": current["average_duration_min"],
            "previous_volume_kg": previous["volume_kg"],
            "nutrition_logged_days": logged_days,
            "diet_planned_meals": diet_planned_meals,
            "diet_logged_plan_meals": diet_totals["logged_plan_meals"],
            "diet_adherence_rate": diet_adherence,
            "diet_planned_kcal": diet_totals["planned_kcal"],
            "diet_actual_kcal": diet_totals["actual_kcal"],
            "plan_title": (context.get("current_plan") or {}).get("title"),
        },
        "summary": summary,
        "wins": wins[:3],
        "watchouts": watchouts[:3],
        "actions": actions[:3],
        "generated_at": now.isoformat(),
    }

    run = AgentRun(
        user_id=user_id,
        intent="review_week",
        status="running",
        model="review-rules-v1",
        prompt_version=REVIEW_PROMPT_VERSION,
        input_text="auto:weekly_review",
    )
    db.add(run)
    db.flush()
    _record_step(
        db,
        run,
        "tool",
        tool_name="get_context",
        input_data={"scope": "weekly_review"},
        output_data={
            "profile": context.get("profile"),
            "current_plan": context.get("current_plan"),
            "nutrition_7d": nutrition,
            "memories": context.get("memories"),
        },
    )
    _record_step(
        db,
        run,
        "tool",
        tool_name="get_recent_training",
        input_data={"days": 7},
        output_data={"current": current, "previous": previous},
    )
    _record_step(
        db,
        run,
        "decision",
        input_data={"policy": "weekly_review_rules_v1"},
        output_data=review,
    )
    run.status = "completed"
    run.output_text = summary[:4000]
    run.completed_at = utcnow()
    db.commit()
    review["run_id"] = run.id
    return review


def _mock_agent_response(db: Session, user_id: str) -> str:
    # The normal app uses its local coach when no LLM key is configured.
    if db.get(Profile, user_id) is None:
        return "请先完成个人档案，我才能读取你的训练条件并安排计划。"
    return "AI 服务暂时不可用。我可以先读取你的本地训练记录，但这次没有生成新的计划草案。"


def _agent_fallback_reply(
    db: Session,
    user_id: str,
    message: str,
    *,
    profile: Profile | None = None,
) -> tuple[str | None, list[dict], str | None]:
    """Deterministic local reply when the model/provider fails.

    The legacy coach already has safe rules for common questions (today's
    workout, substitutions, protein, schedule). Reuse them instead of returning
    a generic "try again" when the user's data is enough to answer.
    """
    try:
        profile = profile or db.get(Profile, user_id)
        if profile is None:
            return None, [], None
        from .coach import _mock_reply

        program = active_program(db, user_id)
        reply, citations = _mock_reply(message, profile, program, db, "trainer")
        review = review_reply(profile, reply)
        if review.blocked:
            return review.reply, [], review.safety_flag
        return reply, citations, None
    except Exception:  # noqa: BLE001 - fallback must never mask the original error
        logger.exception("Agent deterministic fallback failed")
        return None, [], None


async def run_agent(
    db: Session,
    user_id: str,
    message: str,
    *,
    session_id: str | None = None,
    history: list[ChatMessage] | None = None,
    skill: str = "trainer",
    app_context: dict | None = None,
) -> dict:
    run = AgentRun(
        user_id=user_id,
        session_id=session_id,
        intent="coach_chat",
        status="running",
        model=settings.llm_model,
        prompt_version=AGENT_PROMPT_VERSION,
        input_text=message[:4000],
    )
    db.add(run)
    db.flush()

    observations: list[dict] = []
    final_message: str | None = None
    proposal: AgentPlanProposal | None = None
    actions: list[dict] = []
    error: str | None = None
    usage: dict[str, int] = {}
    output_flag: str | None = None
    citations: list[dict] = []
    started = time.perf_counter()

    profile = db.get(Profile, user_id)
    decision = assess_safety(profile, message)
    if decision.reply:
        final_message = decision.reply
        run.status = "completed"
        run.output_text = final_message
        run.completed_at = utcnow()
        db.commit()
        return {
            "run_id": run.id,
            "status": run.status,
            "reply": final_message,
            "proposal": None,
            "actions": [],
            "safety_flag": decision.flag,
            "citations": [],
            "elapsed_ms": int((time.perf_counter() - started) * 1000),
            "usage": usage,
            "error": None,
        }

    try:
        if settings.use_mock_llm:
            fallback_message, fallback_citations, fallback_flag = (
                _agent_fallback_reply(
                    db,
                    user_id,
                    message,
                    profile=profile,
                )
            )
            final_message = fallback_message or _mock_agent_response(db, user_id)
            citations = fallback_citations
            output_flag = fallback_flag
            run.status = "completed"
            run.intent = "fallback"
            error = "LLM is not configured; deterministic fallback"
        else:
            coach_context = build_coach_context(db, user_id)
            forced_food_log = _forced_food_log_intent(message)
            forced_workout_log = (
                not forced_food_log and _forced_workout_log_intent(message)
            )
            allowed_tools = sorted(ALLOWED_TOOLS)
            if forced_food_log:
                allowed_tools = [
                    "get_context",
                    "resolve_food",
                    "propose_app_actions",
                ]
            elif forced_workout_log:
                allowed_tools = [
                    "get_context",
                    "lookup_exercise",
                    "get_exercise_history",
                    "propose_app_actions",
                ]
            state = {
                "user_message": message,
                "current_date": (
                    (coach_context.get("today") or {}).get("date")
                    or datetime.now(timezone.utc).date().isoformat()
                ),
                "coach_context": coach_context,
                "safety_context": decision.caution,
                "history": [
                    {"role": item.role, "content": item.content[:1000]}
                    for item in (history or [])[-10:]
                    if item.role in {"user", "assistant"}
                ],
                "app_context": _safe_json(app_context or {}),
                "coach_skill": "trainer",
                "observations": observations,
                "forced_intent": (
                    "log_food"
                    if forced_food_log
                    else "log_workout" if forced_workout_log else None
                ),
                "allowed_tools": allowed_tools,
                "max_steps": MAX_STEPS,
            }
            for _ in range(MAX_STEPS):
                step_started = time.perf_counter()
                # Persist audit steps and release the read connection while
                # waiting on the model. A 30–90s LLM call must not pin a DB
                # connection from the pool.
                db.commit()
                raw = await llm.complete_json(
                    SYSTEM_PROMPT,
                    json.dumps(state, ensure_ascii=False),
                    reasoning_effort=settings.llm_agent_reasoning_effort,
                    usage=usage,
                    db=db,
                    user_id=user_id,
                    kind="agent",
                    prompt_version=AGENT_PROMPT_VERSION,
                )
                _record_step(
                    db,
                    run,
                    "decision",
                    input_data={"state_step": run.step_count + 1},
                    output_data={"action": raw},
                    latency_ms=int((time.perf_counter() - step_started) * 1000),
                )
                action = str(raw.get("action", "final"))
                if action == "tool":
                    tool = str(raw.get("tool", ""))
                    arguments = raw.get("arguments") if isinstance(raw.get("arguments"), dict) else {}
                    tool_started = time.perf_counter()
                    try:
                        if tool == "resolve_food":
                            text = str(arguments.get("text") or "").strip()
                            if not text:
                                result = {
                                    "ok": False,
                                    "error": "resolve_food requires text",
                                }
                            else:
                                target = None
                                raw_date = str(arguments.get("date") or "").strip()
                                if raw_date:
                                    try:
                                        target = date.fromisoformat(raw_date)
                                    except ValueError:
                                        target = None
                                result = await resolve_food_text(
                                    db,
                                    user_id,
                                    text,
                                    meal=str(arguments.get("meal") or "lunch"),
                                    target_date=target,
                                )
                                result = {"ok": True, **result}
                        else:
                            result = _tool_result(
                                db, run, user_id, tool, arguments, app_context
                            )
                        status = "ok" if result.get("ok", True) else "error"
                        if forced_food_log and tool == "propose_app_actions":
                            proposed = result.get("actions")
                            food_types = {
                                "log_food",
                                "log_planned_meal",
                                "update_food_log",
                                "delete_food_log",
                            }
                            if not isinstance(proposed, list) or not proposed or any(
                                str(item.get("type")) not in food_types
                                for item in proposed
                                if isinstance(item, dict)
                            ):
                                result = {
                                    "ok": False,
                                    "error": (
                                        "本轮 forced_intent=log_food；只能使用 "
                                        "log_food / log_planned_meal / "
                                        "update_food_log / delete_food_log，"
                                        "不要打开页面或生成饮食计划"
                                    ),
                                }
                                status = "error"
                        if forced_workout_log and tool == "propose_app_actions":
                            proposed = result.get("actions")
                            if not isinstance(proposed, list) or not proposed or any(
                                str(item.get("type")) != "log_workout"
                                for item in proposed
                                if isinstance(item, dict)
                            ):
                                result = {
                                    "ok": False,
                                    "error": (
                                        "本轮 forced_intent=log_workout；只能使用 "
                                        "log_workout，不要开始训练或修改计划"
                                    ),
                                }
                                status = "error"
                        tool_error = None if status == "ok" else str(result.get("error", ""))[:500]
                    except Exception as exc:  # noqa: BLE001 - tool failures return to model
                        result = {"ok": False, "error": str(exc)[:500]}
                        status = "error"
                        tool_error = str(exc)[:500]
                    _record_step(
                        db,
                        run,
                        "tool",
                        tool_name=tool,
                        input_data=arguments,
                        output_data=result,
                        status=status,
                        error=tool_error,
                        latency_ms=int((time.perf_counter() - tool_started) * 1000),
                    )
                    observations.append({"tool": tool, "result": result})
                    state["observations"] = observations
                    if isinstance(result.get("proposal"), dict):
                        proposal = db.get(
                            AgentPlanProposal,
                            result["proposal"].get("id"),
                        )
                    if isinstance(result.get("actions"), list):
                        actions = result["actions"]
                    continue
                if action in {"final", "ask_user"}:
                    final_message = str(raw.get("message", "")).strip()
                    break
                observations.append(
                    {
                        "error": "invalid action",
                        "allowed_actions": ["tool", "final", "ask_user"],
                    }
                )
                state["observations"] = observations

        if not final_message:
            final_message = "我需要再确认一下你的目标。你希望调整训练日、频率，还是训练时长？"
        if proposal is None:
            proposal = (
                db.execute(
                    select(AgentPlanProposal)
                    .where(AgentPlanProposal.run_id == run.id)
                    .order_by(AgentPlanProposal.created_at.desc())
                )
                .scalars()
                .first()
            )

        review = review_reply(profile, final_message)
        if review.blocked:
            logger.warning(
                "agent output blocked by guard: %s",
                ",".join(review.rules),
            )
            final_message = review.reply
            output_flag = review.safety_flag
            actions = []
            if proposal is not None:
                proposal.status = "superseded"
                proposal = None
            run.intent = "safety"
            _record_step(
                db,
                run,
                "safety",
                output_data={
                    "action": "blocked",
                    "rules": list(review.rules),
                },
            )

        if proposal is not None or any(
            item.get("requires_confirmation") for item in actions
        ):
            final_message = _guard_pending_action_claims(final_message)
            run.status = "needs_confirmation"
        elif run.status == "running":
            run.status = "completed"
        if actions:
            run.intent = "app_action"
        elif proposal is not None:
            run.intent = "plan_change"
        citations = build_reply_citations(
            db,
            final_message,
            program=active_program(db, user_id),
        )
        run.output_text = final_message[:4000]
        run.completed_at = utcnow()
        db.commit()
        if not settings.use_mock_llm and run.status != "failed":
            schedule_memory_extraction(
                user_id,
                message,
                final_message,
                source="agent",
            )
    except Exception as exc:  # noqa: BLE001 - agent failures must be visible in the run
        logger.exception("Agent run failed")
        db.rollback()
        run = db.get(AgentRun, run.id)
        if run is None:
            raise
        error = str(exc)[:1000]
        # A final reply/action may already have been generated. Do not replace
        # it just because a later memory/audit step failed.
        preserved = (final_message or "").strip()
        if preserved:
            run.output_text = preserved[:4000]
            run.status = (
                "needs_confirmation"
                if proposal is not None
                or any(item.get("requires_confirmation") for item in actions)
                else "completed"
            )
        else:
            if proposal is not None or actions:
                final_message = "我先把可执行方案准备好了，请确认后再执行。"
                citations = []
                run.status = "needs_confirmation"
            else:
                fallback_message, fallback_citations, fallback_flag = (
                    _agent_fallback_reply(db, user_id, message)
                )
                if fallback_message:
                    final_message = fallback_message
                    citations = fallback_citations
                    output_flag = fallback_flag
                    run.status = "completed"
                    run.intent = "fallback"
                else:
                    run.status = "failed"
                    final_message = (
                        "这次请求没有完成，可能是模型服务短暂异常，可以重试。"
                    )
            run.output_text = final_message
        run.error = error
        run.completed_at = utcnow()
        db.commit()
        final_message = run.output_text

    return {
        "run_id": run.id,
        "status": run.status,
        "reply": final_message or "",
        "proposal": _serialize_proposal(proposal) if proposal else None,
        "actions": actions,
        "safety_flag": output_flag or decision.flag,
        "citations": citations,
        "elapsed_ms": int((time.perf_counter() - started) * 1000),
        "usage": usage,
        "error": error,
    }


def _plan_number(value: Any) -> float | None:
    if value in (None, ""):
        return None
    try:
        return round(float(value), 4)
    except (TypeError, ValueError):
        return None


def _plan_signature(plan: dict) -> tuple:
    """Canonical plan shape for revalidation comparison.

    Numeric JSON can round-trip as int or float (7 vs 7.0), so compare the
    normalized values instead of serialized JSON.
    """
    days = []
    for day in plan.get("days") or []:
        exercises = tuple(
            (
                str(item.get("slug") or ""),
                int(item.get("order_index") or 0),
                int(item.get("sets") or 0),
                str(item.get("reps") or ""),
                _plan_number(item.get("weight_kg")),
                int(item.get("rest_sec") or 0),
                _plan_number(item.get("rpe")),
            )
            for item in (day.get("exercises") or [])
        )
        days.append(
            (
                int(day.get("week_index") or 0),
                int(day.get("weekday") or 0),
                str(day.get("title") or ""),
                tuple(str(item) for item in (day.get("focus") or [])),
                exercises,
            )
        )
    return (
        str(plan.get("title") or ""),
        int(plan.get("weeks") or 0),
        tuple(days),
    )


def apply_proposal(db: Session, user_id: str, proposal_id: str) -> tuple[Program, AgentPlanProposal]:
    proposal = db.execute(
        select(AgentPlanProposal)
        .where(AgentPlanProposal.id == proposal_id)
        .with_for_update()
    ).scalar_one_or_none()
    if proposal is None or proposal.user_id != user_id:
        raise LookupError("计划草案不存在")
    if proposal.status != "draft":
        raise ValueError("计划草案已经处理过")
    expires = proposal.expires_at
    if expires is not None and expires.tzinfo is None:
        expires = expires.replace(tzinfo=timezone.utc)
    if expires is not None and expires < utcnow():
        proposal.status = "expired"
        db.commit()
        raise ValueError("计划草案已过期，请重新生成")
    current = active_program(db, user_id)
    if proposal.base_program_id and (
        current is None
        or current.id != proposal.base_program_id
        or current.version != proposal.base_version
    ):
        raise RuntimeError("当前计划已经变化，请重新生成草案")

    try:
        cleaned, warnings = validate_plan_for_user(
            db,
            user_id,
            proposal.plan_data,
        )
    except PlanValidationError as exc:
        raise ValueError(
            "你的伤病或器械条件已经变化，请重新生成计划草案"
        ) from exc
    if warnings or _plan_signature(cleaned) != _plan_signature(
        proposal.plan_data
    ):
        raise ValueError(
            "你的伤病、器械或训练频率已经变化，请重新生成计划草案"
        )

    goal = active_goal(db, user_id)
    program = save_plan(
        db,
        user_id,
        proposal.plan_data,
        goal_type=goal.type if goal else "recomp",
        generated_by="agent",
        model_name=settings.llm_model if not settings.use_mock_llm else "template",
    )
    profile = db.get(Profile, user_id)
    proposed = (proposal.diff_data or {}).get("proposed") or {}
    if profile is not None:
        if proposed.get("weekly_days"):
            profile.weekly_days = max(1, min(7, int(proposed["weekly_days"])))
        if proposed.get("session_minutes"):
            profile.session_minutes = max(15, min(180, int(proposed["session_minutes"])))
    proposal.status = "applied"
    proposal.applied_at = utcnow()
    if proposal.run_id:
        run = db.get(AgentRun, proposal.run_id)
        if run is not None:
            run.status = "completed"
            run.completed_at = utcnow()
    db.commit()
    return program, proposal
