"""Coach runtime for the first control-plane slices.

The model is not allowed to write here. Intent resolution chooses a capability;
the capability resolves facts, the server builds the card, and confirmation
executes through the action ledger.
"""

from __future__ import annotations

import contextlib
import copy
import re
import time
from datetime import datetime, timezone
from uuid import uuid4

from sqlalchemy import select
from sqlalchemy.orm import Session

from ...models import (
    AgentActionEvent,
    CoachActionRecord,
    CoachPending,
    CoachSession,
    CoachTurn,
    FoodLog,
    Profile,
    utcnow,
)
from ..food_text import MEAL_LABELS, parse_meal
from ..safety import assess_safety
from . import capabilities  # noqa: F401 - registers capabilities
from .capability_context import CapabilityContext
from .consumers import consume_event
from .context import with_plan_context
from .conversation import build_conversation_context
from .events import emit_event
from .registry import CAPABILITIES
from .state import (
    PENDING_TTL,
    cancel_active_pending,
    cancel_pending,
    consume_pending,
    get_active_pending,
    get_or_create_session,
    serialize_pending,
    serialize_session,
    set_pending,
    update_pending,
)

DIET = "diet.log_food"
DIET_UPDATE = "diet.update_log"
DIET_DELETE = "diet.delete_log"
DIET_PLAN = "diet.generate_day"
DIET_WEEK = "diet.generate_week"
DIET_DAY_STRATEGY = "diet.edit_day_strategy"
DIET_REVIEW = "diet.review_day"
PLANNED = "diet.log_planned_meal"
SKIP_MEAL = "diet.skip_planned_meal"
RESTORE_MEAL = "diet.restore_planned_meal"
SWAP_MEAL = "diet.swap_meal"
TRAINING = "training.reschedule"
SKIP_TRAINING = "training.skip"
CARDIO = "training.log_cardio"
UPDATE_WORKOUT = "training.update_workout"
DELETE_WORKOUT = "training.delete_workout"
PREVIEW = "training.preview_next"
WEEK_SCHEDULE = "training.week_schedule"
EDIT_EXERCISES = "training.edit_day_exercises"
EDIT_EXERCISE = "training.edit_day_exercise"
ADD_DAY = "training.add_plan_day"
STRENGTH = "training.log_strength"
WEIGHT = "body.log_weight"
BODY_REVIEW = "body.review_trend"
DELETE_METRIC = "body.delete_metric"
REVIEW = "review.weekly"
GOAL = "profile.update_goal"
PLAN = "training.generate_plan"
ADJUST_PLAN = "training.adjust_plan"
CONFIGURE_PLAN = "training.configure_plan"
RESTORE_PLAN = "training.restore_plan"
START_TRAINING_UI = "ui.start_training"
OPEN_SCREEN_UI = "ui.open_screen"
REMINDERS_UI = "ui.configure_reminders"
MEMORY = "memory.remember"
BATCH = "coach.batch"


def _looks_like_reschedule(message: str) -> bool:
    return bool(
        re.search(r"改到|改期|顺延|挪到|换到|调到|改天|换一天|改一下", message)
        and re.search(
            r"周[一二三四五六日天]|星期[一二三四五六日天]|礼拜[一二三四五六日天]|"
            r"今天|明天|后天|\d{1,2}月\d{1,2}[日号]|\d{4}[-/.]\d{1,2}[-/.]\d{1,2}",
            message,
        )
    )


def _is_affirmative(message: str) -> bool:
    return bool(
        re.fullmatch(
            r"(对|是|是的|可以|嗯|好|行|没错)[。.!！]?",
            message.strip(),
        )
    )


def _looks_like_diet_slot_answer(message: str) -> bool:
    value = message.strip()
    if _is_affirmative(value):
        return True
    if re.search(
        r"\d+(?:\.\d+)?\s*(g|克|ml|毫升|杯|份|碗|个|片|勺|盒|瓶)|"
        r"(半|一|两|二|三)\s*(杯|份|碗|个|片|勺)",
        value,
        flags=re.IGNORECASE,
    ):
        return True
    return len(value) <= 20 and bool(
        re.search(r"吃|喝|餐|零食|夜宵|鸡|牛|猪|鱼|蛋|奶|饭|面|肠|菜|果", value)
    )


def _looks_like_training_slot_answer(message: str) -> bool:
    value = message.strip()
    if _is_affirmative(value):
        return True
    return bool(
        re.search(
            r"周[一二三四五六日天]|星期[一二三四五六日天]|礼拜[一二三四五六日天]|"
            r"今天|明天|后天|\d{1,2}月\d{1,2}[日号]|\d{4}[-/.]\d{1,2}[-/.]\d{1,2}",
            value,
        )
    )


def _looks_like_planned_meal(message: str) -> bool:
    return bool(
        re.search(
            r"计划餐|按计划吃|计划早餐|计划午餐|计划晚餐|计划加餐|"
            r"记录.*计划.*餐|把.*计划.*餐.*记",
            message,
        )
    )


def _looks_like_skip_meal(message: str) -> bool:
    return bool(
        re.search(r"跳过", message)
        and re.search(r"早餐|午餐|晚餐|加餐|这餐|计划餐", message)
    )


def _looks_like_restore_meal(message: str) -> bool:
    return bool(
        re.search(r"恢复", message)
        and re.search(r"早餐|午餐|晚餐|加餐|这餐|计划餐", message)
    )


def _looks_like_swap_meal(message: str) -> bool:
    return bool(
        re.search(r"换一餐|换餐|换掉这餐", message)
        or (
            re.search(r"换成|换掉|换一个", message)
            and re.search(r"早餐|午餐|晚餐|加餐|这餐|计划餐", message)
        )
    )


def _last_action_capability(
    db: Session,
    user_id: str,
    session_id: str,
) -> str | None:
    record = db.execute(
        select(CoachActionRecord)
        .where(
            CoachActionRecord.user_id == user_id,
            CoachActionRecord.session_id == session_id,
        )
        .order_by(CoachActionRecord.created_at.desc())
    ).scalars().first()
    return record.capability_id if record is not None else None


def _minutes_since(value: datetime | None) -> int | None:
    if value is None:
        return None
    moment = value if value.tzinfo is not None else value.replace(tzinfo=timezone.utc)
    return max(
        0,
        int((datetime.now(timezone.utc) - moment.astimezone(timezone.utc)).total_seconds() // 60),
    )


def _looks_like_correction(message: str) -> bool:
    if _looks_like_diet_strategy_edit(message):
        return False
    if (
        _looks_like_food_update(message)
        or _looks_like_food_delete(message)
        or _looks_like_workout_update(message)
        or _looks_like_workout_delete(message)
        or _looks_like_plan_configure(message)
        or _looks_like_plan_edit(message)
        or _looks_like_exercise_edit(message)
        or _looks_like_batch_exercise_edit(message)
        or _looks_like_single_exercise_edit(message)
        or _looks_like_reschedule(message)
        or _looks_like_weight(message)
    ):
        return False
    return bool(re.search(r"记错|不是|改成|应该是|修正|改一下", message))


def _diet_correction_parts(message: str) -> tuple[str, list[str]]:
    """Split a correction into resolver text and old terms to remove.

    Supports both "不是鸡胸肉，是牛肉" and
    "鸡胸肉不是200g，是150g"; the latter keeps the food name in the resolver
    text so the new grams land on the right item.
    """
    value = re.sub(
        r"^(记错了|修正|改一下|应该是)[，,。；;\s]*",
        "",
        message.strip(),
    ).strip()
    replaced = re.search(
        r"(?P<prefix>[^，,。；;]*?)不是(?P<old>[^，,。；;]+?)"
        r"[，,。；;]?\s*是(?P<new>.+)",
        value,
    )
    if replaced is not None:
        prefix = replaced.group("prefix").strip(" ，,。；;")
        old = replaced.group("old").strip(" ，,。；;")
        new = replaced.group("new").strip(" ，,。；;")
        terms = [item for item in (prefix, old) if item]
        resolve_text = f"{prefix} {new}".strip() if prefix else new
        return resolve_text, terms
    fallback = re.sub(
        r"^(不是|改成|改为|换成|修正|应该是|改一下)[，,。；;\s]*",
        "",
        value,
    ).strip()
    return fallback, []


def _correction_food_text(message: str) -> str:
    """Remove conversational correction framing before food resolution."""
    return _diet_correction_parts(message)[0]


def _is_amount_only_correction(value: str) -> bool:
    return bool(
        re.fullmatch(
            r"\s*\d+(?:\.\d+)?\s*(?:g|克|ml|毫升|kg|公斤|斤)?\s*",
            value,
            flags=re.IGNORECASE,
        )
    )


def _diet_draft_from_payload(payload: dict) -> dict:
    """Turn an executed food action payload into a resolver draft."""
    draft = copy.deepcopy(payload or {})
    if not draft.get("meals") and draft.get("meal"):
        draft["meals"] = [
            {
                "meal": draft["meal"],
                "date": draft.get("date"),
                "items": [
                    copy.deepcopy(item)
                    for item in draft.get("items") or []
                    if isinstance(item, dict)
                ],
            }
        ]
    return draft


def _diet_draft_from_logs(
    db: Session,
    user_id: str,
    action: CoachActionRecord,
) -> dict:
    """Build a correction draft from the logs that still exist."""
    logs = (
        db.execute(
            select(FoodLog)
            .where(
                FoodLog.user_id == user_id,
                FoodLog.source_action_id == action.id,
            )
            .order_by(FoodLog.logged_at, FoodLog.id)
        )
        .scalars()
        .all()
    )
    payload = action.payload if isinstance(action.payload, dict) else {}
    groups: dict[str, dict] = {}
    for log in logs:
        meal = str(log.meal or payload.get("meal") or "lunch")
        group = groups.setdefault(
            meal,
            {"meal": meal, "date": payload.get("date"), "items": []},
        )
        grams = float(log.grams or 0)
        group["items"].append(
            {
                "name": log.food_name,
                "grams": grams,
                "kcal": float(log.kcal or 0),
                "protein_g": float(log.protein or 0),
                "carbs_g": float(log.carbs or 0),
                "fat_g": float(log.fat or 0),
                "fiber_g": float(log.fiber or 0),
                "portion": f"{round(grams)}g",
                "confidence": float(log.estimate_confidence or 0.7),
            }
        )
    return {
        "date": payload.get("date"),
        "meal": payload.get("meal") or next(iter(groups), None),
        "items": [
            item for group in groups.values() for item in group["items"]
        ],
        "meals": list(groups.values()),
    }


def _diet_action_for_correction(
    db: Session,
    user_id: str,
    last_action: CoachActionRecord | None,
) -> CoachActionRecord | None:
    """Find the food sub-action when the latest action was a batch."""
    if last_action is None:
        return None
    if last_action.capability_id == DIET:
        return last_action
    if last_action.capability_id != BATCH:
        return None
    sub_ids = [
        str(value)
        for value in (last_action.after or {}).get("sub_action_ids") or []
        if str(value).strip()
    ]
    if not sub_ids:
        return None
    records = (
        db.execute(
            select(CoachActionRecord).where(
                CoachActionRecord.user_id == user_id,
                CoachActionRecord.id.in_(sub_ids),
            )
        )
        .scalars()
        .all()
    )
    diet_records = [
        record
        for record in records
        if record.capability_id == DIET and record.status == "executed"
    ]
    return diet_records[0] if len(diet_records) == 1 else None


def _strip_diet_items_by_terms(
    draft: dict,
    terms: list[str],
    meal: str | None = None,
) -> list[str]:
    if not terms:
        return []
    removed: list[str] = []
    for group in draft.get("meals") or [draft]:
        if not isinstance(group, dict):
            continue
        if meal and str(group.get("meal") or "") != meal:
            continue
        kept = []
        for item in group.get("items") or []:
            name = str(item.get("name") or "").strip()
            if name and any(
                term in name or name in term for term in terms
            ):
                removed.append(name)
            else:
                kept.append(item)
        group["items"] = kept
    return removed


def _strip_replaced_diet_items(
    draft: dict,
    text: str,
    meal: str | None = None,
) -> list[str]:
    """Drop old items named by a '不是 X，是 Y' correction."""
    _, terms = _diet_correction_parts(text)
    return _strip_diet_items_by_terms(draft, terms, meal or parse_meal(text))



def _infer_diet_draft_meal(
    draft: dict,
    text: str,
) -> tuple[str | None, bool]:
    """Pick the meal a meal-less correction refers to.

    Returns (meal, ambiguous). An item that appears in more than one meal is
    ambiguous; guessing would silently edit the wrong meal.
    """
    if parse_meal(text) is not None:
        return None, False
    groups = [
        group
        for group in draft.get("meals") or []
        if isinstance(group, dict) and str(group.get("meal") or "").strip()
    ]
    if len(groups) == 1:
        return str(groups[0]["meal"]), False
    matched: set[str] = set()
    for group in groups:
        for item in group.get("items") or []:
            if not isinstance(item, dict):
                continue
            name = re.sub(r"[（(].*?[）)]", "", str(item.get("name") or "")).strip()
            if len(name) >= 2 and name in text:
                matched.add(str(group["meal"]))
                break
    if len(matched) == 1:
        return matched.pop(), False
    return None, len(matched) > 1


def _diet_replacement_meta(payload: dict) -> dict:
    replaced_id = str((payload or {}).get("replace_action_id") or "").strip()
    if not replaced_id:
        return {}
    return {
        "replace_action_id": replaced_id,
        "replaces_previous": True,
    }


def _looks_like_food_delete(message: str) -> bool:
    return bool(
        re.search(r"删掉|删除|去掉|移除", message)
        and re.search(
            r"饮食|早餐|午饭|午餐|晚饭|晚餐|加餐|夜宵|吃了|喝的|食物|"
            r"鸡|牛|猪|鱼|蛋|奶|饭|面|菜|果|肉",
            message,
        )
    )


def _looks_like_food_update(message: str) -> bool:
    return bool(
        re.search(r"改成|改为|修正|应该是|改一下|调整", message)
        and re.search(
            r"早餐|午饭|午餐|晚饭|晚餐|加餐|夜宵|吃了|喝的|食物|"
            r"鸡|牛|猪|鱼|蛋|奶|饭|面|菜|果|肉|克|"
            r"kcal|千卡|大卡",
            message,
            flags=re.IGNORECASE,
        )
    )


def _looks_like_workout_delete(message: str) -> bool:
    if re.search(
        r"体重|体脂|腰围|臂围|腿围|身体记录|身体数据|"
        r"饮食|早餐|午餐|晚餐|加餐|食物",
        message,
    ):
        return False
    return bool(
        re.search(r"删掉|删除|去掉|移除", message)
        and re.search(r"训练|跑步|有氧|运动|记录|这条|那次", message)
    )


def _looks_like_workout_update(message: str) -> bool:
    return bool(
        re.search(r"改成|改为|修正|改一下|调整", message)
        and re.search(
            r"训练记录|跑步|有氧|运动|时长|分钟|组|重量|kg|公斤",
            message,
            flags=re.IGNORECASE,
        )
    )


def _looks_like_plan_configure(message: str) -> bool:
    has_shape = bool(
        re.search(
            r"每周\s*[1-7一二三四五六七]\s*(?:练|次|天)|"
            r"一周\s*[1-7一二三四五六七]\s*(?:练|次|天)|"
            r"[1-5一二三四五]\s*分化|推拉腿|"
            r"周[一二三四五六日天].*周[一二三四五六日天]",
            message,
        )
    )
    has_minutes = bool(re.search(r"\d{2,3}\s*分钟", message))
    has_plan = "计划" in message
    if has_shape and (
        has_plan or "每周" in message or "一周" in message or "分化" in message
    ):
        return True
    return has_plan and has_minutes and bool(re.search(r"改|调|安排", message))


def _looks_like_memory(message: str) -> bool:
    return bool(
        re.match(r"^(?:请)?(?:帮我)?(?:记住|记一下|记下)", message.strip())
    )


def _looks_like_reminders(message: str) -> bool:
    return bool(
        re.search(r"提醒|闹钟", message)
        and re.search(
            r"改|设|开|关|点|每天|早上|上午|中午|下午|晚上|点半|[0-9]",
            message,
        )
    )


def _looks_like_start_training(message: str) -> bool:
    if re.search(
        r"新的训练计划|调整训练计划|修改训练计划|生成.*计划|"
        r"重排.*计划|计划调整|计划配置",
        message,
    ):
        return False
    return bool(
        re.search(
            r"开始训练|开始今天|开始.*(?:训练|练)|"
            r"从.+?(?:训练|练|计划).*开始|"
            r"带我练|开始练|练起来|开始今天的训练|练今天|练明天",
            message,
        )
    )


def _looks_like_open_screen(message: str) -> bool:
    return bool(
        re.search(r"打开|进入|跳到|去一下", message)
        and re.search(
            r"训练记录|训练历史|训练安排|日程|饮食|身体|体型|设置|档案|"
            r"计划|教练|器械|记忆|经期|今天",
            message,
        )
    )


def _looks_like_analysis_screen(message: str) -> bool:
    """Photo analysis / equipment scan requested without an upload.

    The coach page hosts the camera sheets already; opening them from the
    control plane keeps these capabilities inside the coach instead of sending
    the user to a separate module as the primary path.
    """
    if not re.search(r"分析|评估|看看|识别|扫描|拍照|拍张|照片", message):
        return False
    return bool(re.search(r"体型|体态|身材|器械|设备", message))


def _should_try_semantic_route(message: str) -> bool:
    """Cheap gate before spending a model call on intent routing."""
    value = message.strip()
    if not value or len(value) > 120:
        return False
    if re.search(r"怎么|为什么|如何|什么是|吗|？|\?", value):
        return False
    if re.search(
        r"记|改|换|加|删|安排|开始|打开|设置|设到|取消|恢复|跳过|完成|"
        r"上传|拍照|识别|绑定|导出|删除|调整|生成|重排|顺延|挪|放到|算|"
        r"调|称|量",
        value,
    ):
        return True
    if re.search(r"\d", value):
        return True
    return bool(re.search(r"帮我|我想|我要|能不能|可以帮", value))


def _looks_like_action_request(message: str) -> bool:
    """Action-like text that fell through to free chat is a coverage gap."""
    if re.search(r"怎么|为什么|为何|吗|？|\?|什么|多少|如何|哪个", message):
        return False
    return bool(
        re.search(
            r"记|改|换|加|删|安排|开始|打开|设置|提醒|会员|订阅|"
            r"取消|恢复|跳过|完成|上传|拍照|识别|绑定|导出|删除",
            message,
        )
    )


def _looks_like_plan(message: str) -> bool:
    return bool(
        re.search(
            r"生成.{0,6}计划|重新.{0,4}计划|重排.{0,4}计划|排.{0,4}计划|"
            r"4周计划|新的训练计划|给我.*计划",
            message,
        )
    )


def _looks_like_plan_restore(message: str) -> bool:
    if re.search(r"恢复.*(?:餐|饮食)|计划餐", message):
        return False
    return bool(
        re.search(r"恢复|回到|切回|换回|找回", message)
        and re.search(r"计划|版本|上一版|上一份|历史", message)
    )


def _looks_like_plan_adjust(message: str) -> bool:
    return bool(
        re.search(r"调整.{0,6}计划|计划.{0,6}调整", message)
        or (
            re.search(
                r"减量|加量|降低重量|减重|轻一点|太累|恢复不过来|"
                r"太满|太忙|时间不够|没时间|坚持不下来",
                message,
            )
            and re.search(r"计划|训练", message)
        )
    )


def _looks_like_add_day(message: str) -> bool:
    if not re.search(
        r"加一次|加个|加一天|补一次|想练|额外练|加练",
        message,
    ):
        return False
    return bool(
        re.search(r"胸|背|腿|肩|手臂|全身|上肢|下肢", message)
    )


def _looks_like_batch_exercise_edit(message: str) -> bool:
    parts = [
        item
        for item in re.split(r"[，,；;]\s*", message)
        if item.strip()
    ]
    count = 0
    for part in parts:
        if not re.search(
            r"卧推|深蹲|硬拉|划船|推举|飞鸟|弯举|下压|引体|"
            r"臂屈伸|腿举|推胸|蝴蝶机|夹胸|侧平举|后束|卷腹|臀桥",
            part,
        ):
            continue
        if re.search(
            r"改成|加到|调到|重量|休息|每组|"
            r"\d+\s*(?:组|次|kg|公斤)",
            part,
            flags=re.IGNORECASE,
        ):
            count += 1
    return count >= 2


def _looks_like_single_exercise_edit(message: str) -> bool:
    if re.search(r"[、/]", message):
        return False
    if (
        re.search(r"计划|训练", message)
        and re.search(r"[，,；;]", message)
        and re.search(r"改成|换成|替换|加", message)
    ):
        return False
    if not re.search(
        r"卧推|深蹲|硬拉|划船|推举|飞鸟|弯举|下压|引体|"
        r"臂屈伸|腿举|推胸|蝴蝶机|夹胸|侧平举|后束|卷腹|臀桥",
        message,
    ):
        return False
    return bool(
        re.search(
            r"换成|替换成|替换为|改成|加到|调到|删掉|去掉|删除|"
            r"加上|加一个|加个|增加|再加",
            message,
        )
        or (
            re.search(r"组|次|kg|公斤|秒", message)
            and re.search(r"重量|休息|每组", message)
        )
    )


def _looks_like_exercise_edit(message: str) -> bool:
    if re.search(
        r"鸡胸肉|牛肉|猪肉|鱼肉|米饭|早餐|午餐|晚餐|加餐|吃了|食物",
        message,
    ):
        return False
    if not re.search(r"改成|换成|换为|替换为|替换成", message):
        return False
    if not re.search(
        r"计划|训练|练胸|练背|练腿|练肩|练手臂|胸|背|腿|肩|手臂",
        message,
    ):
        return False
    # A full-day replacement is a list. A single swap ("卧推换成杠铃卧推")
    # stays on the legacy modify_workout path.
    return bool(re.search(r"[、,，;；/]", message))


def _looks_like_plan_edit(message: str) -> bool:
    if re.search(r"改到|改期|顺延|挪到|换到|调到", message):
        return False
    if re.search(r"减量|加量|降低重量|减重|轻一点|太累|恢复不过来", message):
        return False
    return bool(
        re.search(
            r"(?:改|修改|调整).{0,8}(?:训练)?计划|"
            r"(?:训练)?计划.{0,8}(?:改|修改|调整)",
            message,
        )
    )


def _looks_like_goal(message: str) -> bool:
    if re.search(r"怎么|多少|为什么|吗|？|\?", message):
        return False
    return bool(
        re.search(r"目标|减脂|减肥|增肌|塑形|重塑|耐力|体能", message)
        and re.search(r"\d|月|日|前", message)
    )


def _looks_like_review(message: str) -> bool:
    return bool(re.search(r"复盘|本周总结|这周怎么样|这周状态|周报", message))


def _looks_like_diet_strategy_edit(message: str) -> bool:
    if not re.search(
        r"均衡|碳循环|低碳|高蛋白|地中海|素食|16\s*[:：]\s*8|168|轻断食",
        message,
    ):
        return False
    if not re.search(
        r"今天|明天|后天|昨天|周[一二三四五六日天]|星期[一二三四五六日天]|"
        r"礼拜[一二三四五六日天]|\d{1,2}月\d{1,2}[日号]",
        message,
    ):
        return False
    return bool(re.search(r"改成|换成|改为|调整|餐单|饮食", message))


def _looks_like_diet_week(message: str) -> bool:
    if not re.search(r"一周|本周|这周|下周|周计划|7\s*天|七天", message):
        return False
    if re.search(r"怎么样|复盘|总结|吃了什么|缺什么|多少", message):
        return False
    return bool(
        re.search(r"排|安排|生成|做|来一份|计划|餐单|食谱", message)
        and re.search(r"饮食|餐|营养", message)
    )


def _looks_like_diet_plan(message: str) -> bool:
    return bool(
        re.search(
            r"排.*餐|安排.*餐|安排.*饮食|饮食.*安排|饮食计划|餐单|食谱|"
            r"明天吃什么|今天吃什么|一周.*餐",
            message,
        )
    )


def _looks_like_diet_review(message: str) -> bool:
    if re.search(r"本周|这周|一周|周报", message):
        return False
    if re.search(r"图片|照片|刚才|刚刚|上面|这张|那张|这道菜|这个菜", message):
        return False
    return bool(
        re.search(
            r"饮食|吃了|摄入|热量|卡路里|蛋白|营养|碳水|脂肪",
            message,
        )
        and re.search(
            r"缺|复盘|总结|看看|怎么样|够不够|够吗|超标|摄入|吃了多少|吃了什么|吃什么",
            message,
        )
    )


def _looks_like_body_review(message: str) -> bool:
    if _looks_like_body_delete(message):
        return False
    return bool(
        re.search(r"体重|体脂|腰围|身体|身材|目标进度", message)
        and re.search(
            r"变化|趋势|怎么样|怎么|如何|进度|最近|几周|吗|？|\?",
            message,
        )
    )


def _looks_like_body_delete(message: str) -> bool:
    return bool(
        re.search(r"删|删除|去掉|清掉|清除", message)
        and re.search(
            r"体重|体脂|腰围|臂围|腿围|身体记录|身体数据|称重",
            message,
        )
    )


def _looks_like_week_schedule(message: str) -> bool:
    if re.search(r"复盘|完成率|怎么样|总结|状态", message):
        return False
    if re.search(r"饮食|餐|营养|食谱|餐单", message):
        return False
    if re.search(
        r"太满|太累|太忙|减量|加量|降低重量|减重|轻一点|恢复不过来|调整",
        message,
    ):
        return False
    return bool(
        re.search(r"下周|本周|这周|一周|上周", message)
        and re.search(r"练什么|训练安排|计划|日程|安排", message)
    )


def _looks_like_training_preview(message: str) -> bool:
    return bool(
        re.search(
            r"练什么|练哪|下一练|下次训练|训练安排|接下来.*练",
            message,
        )
    )


def _looks_like_skip_training(message: str) -> bool:
    return bool(
        re.search(r"跳过|不练|少练|休息", message)
        and re.search(r"训练|今天|明天|后天|这周|本周", message)
    )


def _looks_like_cardio(message: str) -> bool:
    return bool(
        re.search(r"跑|慢跑|骑车|单车|自行车|游泳|快走|走路|划船|有氧", message)
        and re.search(
            r"\d+(?:\.\d+)?\s*(分钟|min|小时|h)",
            message,
            re.IGNORECASE,
        )
    )


def _looks_like_strength(message: str) -> bool:
    return bool(
        not re.search(r"体重|称重", message)
        and re.search(r"\d+(?:\.\d+)?\s*(kg|公斤|斤)", message, re.IGNORECASE)
        and re.search(r"\d+\s*(组|次|个|reps?)", message, re.IGNORECASE)
    )


def _looks_like_weight(message: str) -> bool:
    return bool(
        re.search(
            r"体重|称重|称了|称一下|上秤|过秤|体脂|腰围|臂围|手臂围|腿围|大腿围",
            message,
        )
        and re.search(r"\d", message)
    )


def _looks_like_food(message: str) -> bool:
    if re.search(r"体重|体脂|腰围|臂围|腿围|训练计划|计划改成|卧推|深蹲|硬拉|划船|推举|飞鸟|弯举|下压|引体", message):
        return False
    if re.search(r"不想吃|没吃|不吃|吃不下|没胃口|不想喝|没喝", message):
        return False
    if re.search(r"多少|热量|卡路里|为什么|怎么|吗|？|\?", message):
        return False
    if re.search(r"吃|喝|餐|饭|零食|夜宵|记录饮食|记饮食", message):
        return True
    return bool(
        re.search(
            r"\d+(?:\.\d+)?\s*(?:杯|份|碗|个|片|勺|盒|瓶|(?<!k)g|克|ml|毫升)",
            message,
            flags=re.IGNORECASE,
        )
    )


def _pending_card(
    db: Session,
    session: CoachSession,
    *,
    capability_id: str,
    payload: dict,
) -> CoachPending:
    return set_pending(
        db,
        session,
        kind="card",
        capability_id=capability_id,
        payload=payload,
        action_id=str(uuid4()),
    )


def _pending_draft(
    db: Session,
    session: CoachSession,
    *,
    capability_id: str,
    payload: dict,
) -> CoachPending:
    return set_pending(
        db,
        session,
        kind="draft",
        capability_id=capability_id,
        payload=payload,
    )


def _finish_pending(
    db: Session,
    session: CoachSession,
    turn: CoachTurn,
    started: float,
    *,
    capability_id: str,
    payload: dict,
    reply: str,
    kind: str = "card",
) -> dict:
    if kind == "proposal":
        set_pending(
            db,
            session,
            kind="proposal",
            capability_id=capability_id,
            payload=payload,
        )
    elif kind == "insight":
        set_pending(
            db,
            session,
            kind="insight",
            capability_id=capability_id,
            payload=payload,
        )
    elif kind == "draft":
        _pending_draft(
            db,
            session,
            capability_id=capability_id,
            payload=payload,
        )
    else:
        _pending_card(
            db,
            session,
            capability_id=capability_id,
            payload=payload,
        )
    turn.intent = capability_id
    turn.status = "completed"
    turn.reply = reply
    turn.latency_ms = int((time.perf_counter() - started) * 1000)
    session.last_turn_at = utcnow()
    session.updated_at = utcnow()
    db.commit()
    active = get_active_pending(db, session.user_id, session.id)
    return {
        "session": serialize_session(session, active),
        "turn_id": turn.id,
        "intent": turn.intent,
        "status": turn.status,
        "reply": reply,
        "pending": serialize_pending(active),
    }


def _food_reply(resolution: dict) -> str:
    items = resolution.get("items") or []
    kcal = round(sum(float(item.get("kcal") or 0) for item in items))
    return f"已识别 {len(items)} 种食物，约 {kcal} kcal。确认后写入。"


def _food_reply_multi(meals: list[dict]) -> str:
    items = [
        item
        for meal in meals
        for item in (meal.get("items") or [])
    ]
    kcal = round(sum(float(item.get("kcal") or 0) for item in items))
    labels = "、".join(
        MEAL_LABELS.get(str(meal.get("meal") or ""), str(meal.get("meal") or ""))
        for meal in meals
    )
    return (
        f"已识别 {labels}，共 {len(items)} 种食物，约 {kcal} kcal。"
        "确认后一次写入。"
    )


def _food_question_text(meals: list[dict]) -> str:
    questions: list[str] = []
    for meal in meals:
        for question in meal.get("questions") or []:
            text = str(question).strip()
            if text and text not in questions:
                questions.append(text)
    if not questions:
        return "这餐还需要补充信息。"
    if len(questions) == 1:
        return questions[0]
    return "还需要确认：" + "；".join(questions[:4])


def _body_metric_parts(payload: dict) -> list[str]:
    parts: list[str] = []
    if payload.get("weight_kg") is not None:
        parts.append(f"体重 {payload['weight_kg']} kg")
    if payload.get("body_fat_pct") is not None:
        parts.append(f"体脂 {payload['body_fat_pct']}%")
    if payload.get("waist_cm") is not None:
        parts.append(f"腰围 {payload['waist_cm']} cm")
    if payload.get("arm_cm") is not None:
        parts.append(f"臂围 {payload['arm_cm']} cm")
    if payload.get("thigh_cm") is not None:
        parts.append(f"腿围 {payload['thigh_cm']} cm")
    return parts


def _body_metric_reply(payload: dict) -> str:
    return f"准备记录{'、'.join(_body_metric_parts(payload))}。确认后写入。"


def _training_reply(payload: dict) -> str:
    return (
        f"准备把「{payload.get('title') or '训练'}」"
        f"从 {payload.get('from_date')} 改到 {payload.get('to_date')}。确认后生效。"
    )


def _pending_reply(
    db: Session,
    session: CoachSession,
    turn: CoachTurn,
    started: float,
    pending: CoachPending,
    *,
    intent: str,
    reply: str,
) -> dict:
    turn.intent = intent
    turn.status = "completed"
    turn.reply = reply
    turn.latency_ms = int((time.perf_counter() - started) * 1000)
    session.last_turn_at = utcnow()
    session.updated_at = utcnow()
    db.commit()
    return {
        "session": serialize_session(session, pending),
        "turn_id": turn.id,
        "intent": turn.intent,
        "status": turn.status,
        "reply": reply,
        "pending": serialize_pending(pending),
    }


async def _handle_executed_diet_correction(
    db: Session,
    user_id: str,
    session: CoachSession,
    turn: CoachTurn,
    started: float,
    text: str,
    last_action: CoachActionRecord | None,
    conversation,
) -> dict | None:
    """Replace an executed food action without duplicating its other items.

    The old logs stay in place until the corrected card is confirmed. The
    replacement then deletes the old action and writes the merged set in one
    transaction.
    """
    if last_action is None or last_action.capability_id != DIET:
        return None
    if not _looks_like_food(text) or re.search(r"\d+\s*(kg|公斤|斤)", text):
        return None
    payload = last_action.payload if isinstance(last_action.payload, dict) else {}
    # Read the logs that still exist, not the original action payload. A food
    # the user deleted or edited outside this action must not be resurrected.
    draft = _diet_draft_from_logs(db, user_id, last_action)
    if not draft.get("meals"):
        return _finish_reply(
            db,
            session,
            turn,
            started,
            intent=DIET,
            reply="这条饮食记录已经不在了，直接重新告诉我吃了什么就好。",
        )
    default_meal, ambiguous = _infer_diet_draft_meal(draft, text)
    if ambiguous:
        return _finish_pending(
            db,
            session,
            turn,
            started,
            capability_id=DIET,
            payload={
                **draft,
                "replace_action_id": last_action.id,
                "replaces_previous": True,
                "message": _correction_food_text(text) or text,
                "strip_terms": _diet_correction_parts(text)[1],
                "text": text,
                "needs_meal": True,
            },
            reply=(
                "这个食物在多餐里都有。告诉我改哪一餐，"
                "比如“记错了，午餐鸡胸肉是150g”。"
            ),
            kind="draft",
        )
    _strip_replaced_diet_items(
        draft,
        text,
        parse_meal(text) or default_meal,
    )
    resolve_text = _correction_food_text(text) or text
    if _is_amount_only_correction(resolve_text):
        item_count = sum(
            len(group.get("items") or [])
            for group in draft.get("meals") or []
            if isinstance(group, dict)
        )
        if item_count > 1:
            return _finish_reply(
                db,
                session,
                turn,
                started,
                intent=DIET,
                reply=(
                    "要改哪样食物？可以说“鸡胸肉不是200g，"
                    "是150g”。"
                ),
            )
    from .capabilities.diet import resolve as resolve_diet

    resolution = await resolve_diet(
        db,
        user_id,
        resolve_text,
        history_context=conversation.reference_context(),
        draft=draft,
        default_meal=default_meal,
    )
    meals = resolution.get("meals") or []
    questions = [
        str(question)
        for meal in meals
        for question in meal.get("questions") or []
        if str(question).strip()
    ] + [
        str(question)
        for question in resolution.get("questions") or []
        if str(question).strip()
    ]
    missing_slots = [
        slot
        for meal in meals
        for slot in meal.get("missing_slots") or []
        if isinstance(slot, dict)
    ] + [
        slot
        for slot in resolution.get("missing_slots") or []
        if isinstance(slot, dict)
    ]
    new_payload = {
        "replace_action_id": last_action.id,
        "replaces_previous": True,
        "date": payload.get("date") or resolution.get("date"),
        "meal": resolution.get("meal") or payload.get("meal"),
        "items": resolution.get("items") or [],
        "raw_text": text[:500],
    }
    if meals:
        # A correction is about the existing record, not a new day. Keep the
        # original action date even if the user says "昨天" while correcting.
        for meal in meals:
            if isinstance(meal, dict):
                meal["date"] = new_payload["date"]
        new_payload["meals"] = meals
    if questions or missing_slots:
        new_payload.update(
            {
                "text": text,
                "questions": list(dict.fromkeys(questions)),
                "missing_slots": missing_slots,
            }
        )
        reply = (
            _food_question_text(meals)
            if meals
            else (questions[0] if questions else "这餐还需要补充信息。")
        )
        return _finish_pending(
            db,
            session,
            turn,
            started,
            capability_id=DIET,
            payload=new_payload,
            reply=reply,
            kind="draft",
        )
    if not new_payload["items"] and not meals:
        return _finish_reply(
            db,
            session,
            turn,
            started,
            intent=DIET,
            reply="没认出要改哪样食物。可以说“记错了，午餐鸡胸肉是150g”。",
        )
    detail = _food_reply_multi(meals) if meals else _food_reply(resolution)
    return _finish_pending(
        db,
        session,
        turn,
        started,
        capability_id=DIET,
        payload=new_payload,
        reply=f"改好了，确认后会替换上一条记录。{detail}",
    )


async def _pending_card_followup(
    db: Session,
    user_id: str,
    session: CoachSession,
    turn: CoachTurn,
    pending: CoachPending,
    text: str,
    conversation,
    started: float,
) -> dict | None:
    """Update an existing card instead of silently throwing it away.

    This is the global context rule: additions and corrections first look at
    the active pending. Only an explicit cancel or an unrelated new intent
    should replace the card.
    """
    capability = pending.capability_id
    payload = dict(pending.payload or {})
    correction = bool(
        re.search(r"记错|不是|改成|改为|换成|应该是|修正|改一下", text)
    )
    addition = bool(
        re.search(r"还有|再加|另外|加上|补充|再记|顺便|加一个|加一份", text)
    )

    if capability == WEIGHT:
        if not (correction or addition or re.fullmatch(r"[\d.]+", text.strip())):
            return None
        from .capabilities.body import resolve as resolve_weight

        resolution = resolve_weight(text)
        if not resolution.get("ready"):
            reply = (resolution.get("questions") or ["新的体重大概多少公斤？"])[0]
            return _pending_reply(
                db,
                session,
                turn,
                started,
                pending,
                intent=WEIGHT,
                reply=reply,
            )
        new_payload = {**payload, **resolution["payload"]}
        update_pending(db, session, pending, payload=new_payload)
        return _pending_reply(
            db,
            session,
            turn,
            started,
            pending,
            intent=WEIGHT,
            reply=_body_metric_reply(new_payload),
        )

    if capability == DIET:
        if not (addition or correction or _looks_like_food(text)):
            return None
        from .capabilities.diet import resolve as resolve_diet

        draft = _diet_draft_from_payload(payload)
        default_meal = None
        resolve_text = text
        if correction:
            default_meal, _ = _infer_diet_draft_meal(draft, text)
            _strip_replaced_diet_items(
                draft,
                text,
                parse_meal(text) or default_meal,
            )
            resolve_text = _correction_food_text(text) or text
        resolution = await resolve_diet(
            db,
            user_id,
            resolve_text,
            history_context=conversation.reference_context(),
            draft=draft,
            default_meal=default_meal,
        )
        meals = resolution.get("meals") or []
        replacement = _diet_replacement_meta(payload)
        questions = [
            str(question)
            for meal in meals
            for question in meal.get("questions") or []
            if str(question).strip()
        ] + [
            str(question)
            for question in resolution.get("questions") or []
            if str(question).strip()
        ]
        missing_slots = [
            slot
            for meal in meals
            for slot in meal.get("missing_slots") or []
            if isinstance(slot, dict)
        ] + [
            slot
            for slot in resolution.get("missing_slots") or []
            if isinstance(slot, dict)
        ]
        if questions or missing_slots:
            new_payload = {
                **replacement,
                "text": text,
                "date": resolution.get("date") or payload.get("date"),
                "meal": resolution.get("meal") or payload.get("meal"),
                "items": resolution.get("items") or payload.get("items") or [],
                "meals": meals or None,
                "questions": list(dict.fromkeys(questions)),
                "missing_slots": missing_slots,
            }
            update_pending(db, session, pending, kind="draft", payload=new_payload)
            reply = (
                _food_question_text(meals)
                if meals
                else (questions[0] if questions else "这餐还需要补充信息。")
            )
            return _pending_reply(
                db,
                session,
                turn,
                started,
                pending,
                intent=DIET,
                reply=reply,
            )
        if not resolution.get("items") and not meals:
            return None
        new_payload = {
            **replacement,
            "date": resolution.get("date") or payload.get("date"),
            "meal": resolution.get("meal") or payload.get("meal"),
            "raw_text": text[:500],
            "items": resolution.get("items") or [],
        }
        if meals:
            new_payload["meals"] = meals
        update_pending(db, session, pending, payload=new_payload)
        reply = _food_reply_multi(meals) if meals else _food_reply(resolution)
        return _pending_reply(
            db,
            session,
            turn,
            started,
            pending,
            intent=DIET,
            reply=reply,
        )

    if capability == TRAINING:
        from .capabilities.training import parse_training_date

        target = parse_training_date(text)
        if target is None:
            return None
        new_payload = {**payload, "to_date": target.isoformat()}
        update_pending(db, session, pending, payload=new_payload)
        return _pending_reply(
            db,
            session,
            turn,
            started,
            pending,
            intent=TRAINING,
            reply=_training_reply(new_payload),
        )

    if capability == GOAL:
        from .capabilities.profile import resolve as resolve_goal

        resolution = resolve_goal(text)
        if not resolution.get("ready"):
            reply = (resolution.get("questions") or ["想怎么改目标？"])[0]
            return _pending_reply(
                db,
                session,
                turn,
                started,
                pending,
                intent=GOAL,
                reply=reply,
            )
        new_payload = {**payload, **resolution["payload"]}
        update_pending(db, session, pending, payload=new_payload)
        return _pending_reply(
            db,
            session,
            turn,
            started,
            pending,
            intent=GOAL,
            reply="目标改好了，确认后更新。",
        )

    if capability == CARDIO:
        from .capabilities.training import resolve_cardio

        title = str(payload.get("title") or "").strip()
        resolution = resolve_cardio(f"{title} {text}".strip() if title else text)
        if not resolution.get("ready"):
            reply = (resolution.get("questions") or ["这次练了多久？"])[0]
            return _pending_reply(
                db,
                session,
                turn,
                started,
                pending,
                intent=CARDIO,
                reply=reply,
            )
        new_payload = {**payload, **resolution["payload"]}
        update_pending(db, session, pending, payload=new_payload)
        return _pending_reply(
            db,
            session,
            turn,
            started,
            pending,
            intent=CARDIO,
            reply=(
                f"改好了，准备记录{new_payload.get('title')} "
                f"{new_payload.get('duration_minutes')} 分钟。确认后写入。"
            ),
        )

    if correction or addition:
        # Do not silently lose a write card just because its capability does
        # not have an in-place merge handler yet.
        return _pending_reply(
            db,
            session,
            turn,
            started,
            pending,
            intent=capability,
            reply="我先保留这张卡。你是要修改它，还是先确认/取消？",
        )

    return None


def _split_batch_clauses(message: str) -> list[str]:
    parts = re.split(
        r"(?:然后|再|顺便|另外|还要|同时|并且|以及)",
        message,
    )
    if len([part for part in parts if part.strip()]) < 2:
        parts = re.split(r"[，,；;]\s*", message)
    return [
        part.strip(" ，,。；;")
        for part in parts
        if part.strip(" ，,。；;")
    ]


def _discard_batch_programs(
    db: Session,
    user_id: str,
    program_ids: list[str],
) -> None:
    if not program_ids:
        return
    from .capabilities.plan import discard

    for program_id in program_ids:
        discard(db, user_id, program_id)
    db.commit()


async def _try_batch_turn(
    db: Session,
    user_id: str,
    message: str,
    context,
    conversation,
) -> dict | None:
    """Resolve two or more independent actions into one confirmation card.

    This is intentionally conservative: every clause must resolve cleanly.
    If any clause needs clarification, fall back to the normal single-intent
    path so the user does not get a half-understood batch.
    """
    clauses = _split_batch_clauses(message)
    if len(clauses) < 2:
        return None

    actions: list[dict] = []
    seen: set[str] = set()
    created_program_ids: list[str] = []
    for clause in clauses:
        action: dict | None = None
        meal_capability = None
        if _looks_like_restore_meal(clause):
            meal_capability = RESTORE_MEAL
        elif _looks_like_skip_meal(clause):
            meal_capability = SKIP_MEAL
        elif _looks_like_swap_meal(clause):
            meal_capability = SWAP_MEAL
        elif _looks_like_planned_meal(clause):
            meal_capability = PLANNED
        if meal_capability is not None:
            from .capabilities.diet import resolve_planned

            resolution = resolve_planned(clause, require_explicit_meal=True)
            if resolution.get("ready"):
                payload = resolution["payload"]
                labels = {
                    PLANNED: "记录计划餐",
                    SKIP_MEAL: "跳过计划餐",
                    RESTORE_MEAL: "恢复计划餐",
                    SWAP_MEAL: "换一餐",
                }
                action = {
                    "capability_id": meal_capability,
                    "payload": payload,
                    "summary": (
                        f"{labels[meal_capability]}：{payload['date']} "
                        f"{MEAL_LABELS.get(payload['meal'], payload['meal'])}"
                    ),
                }
        elif _looks_like_plan_restore(clause):
            from .capabilities.plan import resolve_restore

            resolution = resolve_restore(db, user_id, clause)
            if resolution.get("ready"):
                payload = resolution["payload"]
                action = {
                    "capability_id": RESTORE_PLAN,
                    "payload": payload,
                    "summary": payload.get("summary") or "恢复历史计划",
                }
        elif _looks_like_plan_configure(clause):
            from .capabilities.plan_configure import (
                resolve as resolve_configure,
            )

            resolution = resolve_configure(db, user_id, clause)
            if resolution.get("ready"):
                created_program_ids.append(
                    str(resolution.get("program_id") or "")
                )
                action = {
                    "capability_id": CONFIGURE_PLAN,
                    "payload": {
                        "program_id": resolution["program_id"],
                        "plan": resolution.get("plan") or {},
                        "profile_before": resolution.get("profile_before") or {},
                        "profile_after": resolution.get("profile_after") or {},
                        "summary": resolution.get("summary") or "",
                    },
                    "summary": resolution.get("summary") or "调整计划频率",
                }
        elif _looks_like_reschedule(clause):
            from .capabilities.training import resolve as resolve_training

            resolution = resolve_training(db, user_id, clause, context)
            if resolution.get("ready"):
                payload = resolution["payload"]
                action = {
                    "capability_id": TRAINING,
                    "payload": payload,
                    "summary": _training_reply(payload),
                }
        elif _looks_like_add_day(clause):
            from .capabilities.training_add_day import resolve as resolve_add_day

            resolution = resolve_add_day(db, user_id, clause, context)
            if resolution.get("ready"):
                payload = resolution["payload"]
                action = {
                    "capability_id": ADD_DAY,
                    "payload": payload,
                    "summary": payload.get("summary")
                    or f"增加 {payload.get('date')} 的{payload.get('title')}训练",
                }
        elif _looks_like_skip_training(clause):
            from .capabilities.training import resolve_skip

            resolution = resolve_skip(db, user_id, clause, context)
            if resolution.get("ready"):
                payload = resolution["payload"]
                action = {
                    "capability_id": SKIP_TRAINING,
                    "payload": payload,
                    "summary": f"跳过 {payload.get('date')} 的「{payload.get('title')}」",
                }
        elif _looks_like_weight(clause):
            from .capabilities.body import resolve as resolve_weight

            resolution = resolve_weight(clause)
            if resolution.get("ready"):
                payload = resolution["payload"]
                action = {
                    "capability_id": WEIGHT,
                    "payload": payload,
                    "summary": _body_metric_reply(payload),
                }
        elif _looks_like_goal(clause):
            from .capabilities.profile import resolve as resolve_goal

            resolution = resolve_goal(clause)
            if resolution.get("ready"):
                action = {
                    "capability_id": GOAL,
                    "payload": resolution["payload"],
                    "summary": "更新目标",
                }
        elif (
            _looks_like_single_exercise_edit(clause)
            or _looks_like_batch_exercise_edit(clause)
        ):
            from .capabilities.training_exercise_edit import (
                resolve as resolve_exercise_edit,
            )

            resolution = resolve_exercise_edit(db, user_id, clause, context)
            if resolution.get("ready"):
                payload = resolution["payload"]
                action = {
                    "capability_id": EDIT_EXERCISE,
                    "payload": payload,
                    "summary": payload.get("summary") or "调整单个动作",
                }
        elif _looks_like_exercise_edit(clause):
            from .capabilities.training_edit import (
                resolve as resolve_day_edit,
            )

            resolution = resolve_day_edit(db, user_id, clause, context)
            if resolution.get("ready"):
                payload = resolution["payload"]
                action = {
                    "capability_id": EDIT_EXERCISES,
                    "payload": payload,
                    "summary": payload.get("summary") or "调整当天动作",
                }
        elif _looks_like_workout_delete(clause):
            from .capabilities.log_edit import resolve_delete_workout

            resolution = resolve_delete_workout(db, user_id, clause)
            if resolution.get("ready"):
                action = {
                    "capability_id": DELETE_WORKOUT,
                    "payload": resolution["payload"],
                    "summary": resolution.get("summary")
                    or "删除训练记录",
                }
        elif _looks_like_workout_update(clause):
            from .capabilities.log_edit import resolve_update_workout

            resolution = resolve_update_workout(db, user_id, clause)
            if resolution.get("ready"):
                action = {
                    "capability_id": UPDATE_WORKOUT,
                    "payload": resolution["payload"],
                    "summary": resolution.get("summary")
                    or "修改训练记录",
                }
        elif _looks_like_strength(clause):
            from .capabilities.training import resolve_strength

            resolution = resolve_strength(db, clause)
            if resolution.get("ready"):
                payload = resolution["payload"]
                action = {
                    "capability_id": STRENGTH,
                    "payload": payload,
                    "summary": (
                        f"记录{payload.get('title')} "
                        f"{len(payload.get('sets') or [])} 组"
                    ),
                }
        elif _looks_like_cardio(clause):
            from .capabilities.training import resolve_cardio

            resolution = resolve_cardio(clause)
            if resolution.get("ready"):
                payload = resolution["payload"]
                action = {
                    "capability_id": CARDIO,
                    "payload": payload,
                    "summary": (
                        f"记录{payload.get('title')} "
                        f"{payload.get('duration_minutes')} 分钟"
                    ),
                }
        elif _looks_like_food_delete(clause):
            from .capabilities.log_edit import resolve_delete_food

            resolution = resolve_delete_food(db, user_id, clause)
            if resolution.get("ready"):
                action = {
                    "capability_id": DIET_DELETE,
                    "payload": resolution["payload"],
                    "summary": resolution.get("summary")
                    or "删除饮食记录",
                }
        elif _looks_like_food_update(clause):
            from .capabilities.log_edit import resolve_update_food

            resolution = resolve_update_food(db, user_id, clause)
            if resolution.get("ready"):
                action = {
                    "capability_id": DIET_UPDATE,
                    "payload": resolution["payload"],
                    "summary": resolution.get("summary")
                    or "修改饮食记录",
                }
        elif _looks_like_food(clause):
            from .capabilities.diet import resolve as resolve_diet

            resolution = await resolve_diet(
                db,
                user_id,
                clause,
                history_context=conversation.reference_context(),
            )
            if not resolution.get("questions") and not resolution.get(
                "missing_slots"
            ):
                meals = resolution.get("meals") or []
                payload = {
                    "date": resolution["date"],
                    "meal": resolution["meal"],
                    "raw_text": clause[:500],
                    "items": resolution.get("items") or [],
                }
                if meals:
                    payload["meals"] = meals
                action = {
                    "capability_id": DIET,
                    "payload": payload,
                    "summary": (
                        _food_reply_multi(meals)
                        if meals
                        else _food_reply(resolution)
                    ),
                }
        if action is None:
            _discard_batch_programs(db, user_id, created_program_ids)
            return None
        capability = action["capability_id"]
        # Multiple planned-meal actions are useful (skip lunch and dinner),
        # but two writes to the exact same meal would duplicate work.
        action_key = capability
        if capability in {PLANNED, SKIP_MEAL, RESTORE_MEAL, SWAP_MEAL}:
            action_key = (
                f"{capability}:{action['payload'].get('date')}:"
                f"{action['payload'].get('meal')}"
            )
        elif capability in {DIET_UPDATE, DIET_DELETE}:
            # Editing or deleting two different food rows is a valid batch.
            action_key = (
                f"{capability}:{action['payload'].get('client_id')}"
            )
        if action_key in seen:
            _discard_batch_programs(db, user_id, created_program_ids)
            return None
        seen.add(action_key)
        actions.append(action)
        if len(actions) > 3:
            _discard_batch_programs(db, user_id, created_program_ids)
            return None

    if len(actions) < 2:
        _discard_batch_programs(db, user_id, created_program_ids)
        return None
    lines = [
        f"{index + 1}. {action['summary']}"
        for index, action in enumerate(actions)
    ]
    reply = "我会一起处理这几项：\n" + "\n".join(lines) + "\n确认后一起执行。"
    plan = context.get("plan") if hasattr(context, "get") else None
    plan = plan if isinstance(plan, dict) else {}
    batch_context = {}
    if str(plan.get("id") or "").strip():
        batch_context = {
            "plan_id": str(plan.get("id")),
            "day_ids": [
                str(day.get("id"))
                for day in plan.get("days") or []
                if isinstance(day, dict) and str(day.get("id") or "").strip()
            ],
        }
    payload = {
        "summary": f"{len(actions)} 项操作",
        "batch": actions,
        "reply": reply,
    }
    if batch_context:
        payload["context"] = batch_context
    return payload


async def _dispatch_semantic_capability(
    db: Session,
    user_id: str,
    session: CoachSession,
    turn: CoachTurn,
    started: float,
    text: str,
    context,
    conversation,
    capability_id: str,
) -> dict | None:
    """Execute a capability selected by the semantic fallback router."""
    if capability_id == DIET:
        from .capabilities.diet import resolve as resolve_diet

        resolution = await resolve_diet(
            db,
            user_id,
            text,
            history_context=conversation.reference_context(),
        )
        meals = resolution.get("meals") or []
        questions = [
            str(question)
            for meal in meals
            for question in meal.get("questions") or []
            if str(question).strip()
        ] + [
            str(question)
            for question in resolution.get("questions") or []
            if str(question).strip()
        ]
        missing = [
            slot
            for meal in meals
            for slot in meal.get("missing_slots") or []
            if isinstance(slot, dict)
        ]
        if questions or missing:
            payload = {
                "text": text,
                "date": resolution.get("date"),
                "meal": resolution.get("meal"),
                "items": resolution.get("items") or [],
                "meals": meals or None,
                "questions": list(dict.fromkeys(questions)),
                "missing_slots": missing,
            }
            reply = (
                _food_question_text(meals)
                if meals
                else (questions[0] if questions else "这餐还需要补充信息。")
            )
            return _finish_pending(
                db,
                session,
                turn,
                started,
                capability_id=DIET,
                payload=payload,
                reply=reply,
                kind="draft",
            )
        if not resolution.get("items") and not meals:
            return None
        payload = {
            "date": resolution["date"],
            "meal": resolution["meal"],
            "raw_text": text[:500],
            "items": resolution.get("items") or [],
        }
        if meals:
            payload["meals"] = meals
        reply = _food_reply_multi(meals) if meals else _food_reply(resolution)
        return _finish_pending(
            db,
            session,
            turn,
            started,
            capability_id=DIET,
            payload=payload,
            reply=reply,
        )

    if capability_id == WEIGHT:
        from .capabilities.body import resolve as resolve_weight

        resolution = resolve_weight(text)
        if not resolution.get("ready"):
            question = (resolution.get("questions") or ["体重大概多少公斤？"])[0]
            return _finish_pending(
                db,
                session,
                turn,
                started,
                capability_id=WEIGHT,
                payload={"message": text},
                reply=question,
                kind="draft",
            )
        payload = resolution["payload"]
        return _finish_pending(
            db,
            session,
            turn,
            started,
            capability_id=WEIGHT,
            payload=payload,
            reply=_body_metric_reply(payload),
        )

    if capability_id == DELETE_METRIC:
        from .capabilities.body import resolve_delete

        resolution = resolve_delete(db, user_id, text)
        if not resolution.get("ready"):
            question = (
                resolution.get("questions") or ["要删哪条身体记录？"]
            )[0]
            return _finish_pending(
                db,
                session,
                turn,
                started,
                capability_id=DELETE_METRIC,
                payload={"message": text},
                reply=question,
                kind="draft",
            )
        payload = resolution["payload"]
        return _finish_pending(
            db,
            session,
            turn,
            started,
            capability_id=DELETE_METRIC,
            payload=payload,
            reply=f"{payload['summary']}？确认后删除。",
        )

    if capability_id == RESTORE_PLAN:
        from .capabilities.plan import resolve_restore

        resolution = resolve_restore(db, user_id, text)
        if not resolution.get("ready"):
            question = (
                resolution.get("questions") or ["想恢复哪一版计划？"]
            )[0]
            return _finish_reply(
                db,
                session,
                turn,
                started,
                intent=RESTORE_PLAN,
                reply=question,
            )
        payload = resolution["payload"]
        return _finish_pending(
            db,
            session,
            turn,
            started,
            capability_id=RESTORE_PLAN,
            payload=payload,
            reply=f"{payload['summary']}？确认后切换。",
            kind="proposal",
        )

    if capability_id == GOAL:
        from .capabilities.profile import resolve as resolve_goal

        resolution = resolve_goal(text)
        if not resolution.get("ready"):
            question = (resolution.get("questions") or ["想怎么改目标？"])[0]
            return _finish_pending(
                db,
                session,
                turn,
                started,
                capability_id=GOAL,
                payload={"message": text},
                reply=question,
                kind="draft",
            )
        return _finish_pending(
            db,
            session,
            turn,
            started,
            capability_id=GOAL,
            payload=resolution["payload"],
            reply="目标改好了，确认后更新。",
        )

    if capability_id == TRAINING:
        from .capabilities.training import resolve as resolve_training

        resolution = resolve_training(db, user_id, text, context)
        if not resolution.get("ready"):
            question = (resolution.get("questions") or ["要把哪一天改到哪天？"])[0]
            return _finish_pending(
                db,
                session,
                turn,
                started,
                capability_id=TRAINING,
                payload={"message": text, "app_context": context},
                reply=question,
                kind="draft",
            )
        payload = resolution["payload"]
        return _finish_pending(
            db,
            session,
            turn,
            started,
            capability_id=TRAINING,
            payload=payload,
            reply=_training_reply(payload),
        )

    if capability_id == SKIP_TRAINING:
        from .capabilities.training import resolve_skip

        resolution = resolve_skip(db, user_id, text, context)
        if not resolution.get("ready"):
            question = (resolution.get("questions") or ["要跳过哪一天？"])[0]
            return _finish_pending(
                db,
                session,
                turn,
                started,
                capability_id=SKIP_TRAINING,
                payload={"message": text, "app_context": context},
                reply=question,
                kind="draft",
            )
        payload = resolution["payload"]
        return _finish_pending(
            db,
            session,
            turn,
            started,
            capability_id=SKIP_TRAINING,
            payload=payload,
            reply=f"准备跳过「{payload.get('title') or '训练'}」。确认后生效。",
        )

    if capability_id == ADD_DAY:
        from .capabilities.training_add_day import resolve as resolve_add_day

        resolution = resolve_add_day(db, user_id, text, context)
        if not resolution.get("ready"):
            question = (
                resolution.get("questions") or ["暂时不能增加训练日。"]
            )[0]
            return _finish_reply(
                db,
                session,
                turn,
                started,
                intent=ADD_DAY,
                reply=question,
            )
        payload = resolution["payload"]
        return _finish_pending(
            db,
            session,
            turn,
            started,
            capability_id=ADD_DAY,
            payload=payload,
            reply=f"{payload.get('summary') or '加练草案好了。'}确认后生效。",
            kind="proposal",
        )

    if capability_id in {PLANNED, SKIP_MEAL, RESTORE_MEAL, SWAP_MEAL}:
        from .capabilities.diet import resolve_planned

        resolution = resolve_planned(text, require_explicit_meal=True)
        if not resolution.get("ready"):
            question = (resolution.get("questions") or ["哪一餐？"])[0]
            return _finish_pending(
                db,
                session,
                turn,
                started,
                capability_id=capability_id,
                payload={"message": text},
                reply=question,
                kind="draft",
            )
        payload = resolution["payload"]
        labels = {
            PLANNED: "记录计划餐",
            SKIP_MEAL: "跳过计划餐",
            RESTORE_MEAL: "恢复计划餐",
            SWAP_MEAL: "换一餐",
        }
        return _finish_pending(
            db,
            session,
            turn,
            started,
            capability_id=capability_id,
            payload=payload,
            reply=(
                f"准备{labels[capability_id]}：{payload['date']} "
                f"{MEAL_LABELS.get(payload['meal'], payload['meal'])}。确认后生效。"
            ),
        )

    if capability_id == CARDIO:
        from .capabilities.training import resolve_cardio

        resolution = resolve_cardio(text)
        if not resolution.get("ready"):
            question = (resolution.get("questions") or ["这次练了多久？"])[0]
            return _finish_pending(
                db,
                session,
                turn,
                started,
                capability_id=CARDIO,
                payload={"message": text},
                reply=question,
                kind="draft",
            )
        payload = resolution["payload"]
        return _finish_pending(
            db,
            session,
            turn,
            started,
            capability_id=CARDIO,
            payload=payload,
            reply=(
                f"准备记录{payload.get('title')} "
                f"{payload.get('duration_minutes')} 分钟。确认后写入。"
            ),
        )

    if capability_id == STRENGTH:
        from .capabilities.training import resolve_strength

        resolution = resolve_strength(db, text)
        if not resolution.get("ready"):
            question = (resolution.get("questions") or ["记录哪个动作？"])[0]
            return _finish_pending(
                db,
                session,
                turn,
                started,
                capability_id=STRENGTH,
                payload={"message": text},
                reply=question,
                kind="draft",
            )
        payload = resolution["payload"]
        return _finish_pending(
            db,
            session,
            turn,
            started,
            capability_id=STRENGTH,
            payload=payload,
            reply=(
                f"准备记录{payload.get('title')} "
                f"{len(payload.get('sets') or [])} 组。确认后写入。"
            ),
        )

    if capability_id == PREVIEW:
        from .capabilities.training_preview import resolve as resolve_preview

        resolution = resolve_preview(db, user_id, context)
        payload = resolution.get("payload") or {}
        return _finish_pending(
            db,
            session,
            turn,
            started,
            capability_id=PREVIEW,
            payload=payload,
            reply=payload.get("summary") or "训练预览已整理好。",
            kind="insight",
        )

    if capability_id == WEEK_SCHEDULE:
        from .capabilities.training_week import resolve as resolve_week

        resolution = resolve_week(db, user_id, text, context)
        payload = resolution.get("payload") or {}
        return _finish_pending(
            db,
            session,
            turn,
            started,
            capability_id=WEEK_SCHEDULE,
            payload=payload,
            reply=payload.get("summary") or "本周安排已整理好。",
            kind="insight",
        )

    if capability_id == DIET_REVIEW:
        from .capabilities.diet_review import resolve as resolve_diet_review

        resolution = resolve_diet_review(db, user_id, text)
        payload = resolution.get("payload") or {}
        return _finish_pending(
            db,
            session,
            turn,
            started,
            capability_id=DIET_REVIEW,
            payload=payload,
            reply=payload.get("summary") or "饮食复盘已整理好。",
            kind="insight",
        )

    if capability_id == REVIEW:
        from .capabilities.review import resolve as resolve_review

        resolution = resolve_review(db, user_id)
        payload = resolution.get("payload") or {}
        return _finish_pending(
            db,
            session,
            turn,
            started,
            capability_id=REVIEW,
            payload=payload,
            reply=payload.get("summary") or "本周复盘已整理好。",
            kind="insight",
        )

    if capability_id == MEMORY:
        from .capabilities.memory import resolve as resolve_memory

        resolution = resolve_memory(text)
        if not resolution.get("ready"):
            question = (resolution.get("questions") or ["想让我记住什么？"])[0]
            return _finish_reply(
                db,
                session,
                turn,
                started,
                intent=MEMORY,
                reply=question,
            )
        payload = resolution["payload"]
        return _finish_pending(
            db,
            session,
            turn,
            started,
            capability_id=MEMORY,
            payload=payload,
            reply=f"记住「{str(payload.get('content') or '')[:80]}」",
        )

    if capability_id == REMINDERS_UI:
        from .capabilities.ui_actions import resolve_reminders

        resolution = resolve_reminders(text)
        if not resolution.get("ready"):
            question = (resolution.get("questions") or ["提醒设到几点？"])[0]
            return _finish_reply(
                db,
                session,
                turn,
                started,
                intent=REMINDERS_UI,
                reply=question,
            )
        return _finish_pending(
            db,
            session,
            turn,
            started,
            capability_id=REMINDERS_UI,
            payload=resolution["payload"],
            reply=resolution.get("summary") or "训练提醒已更新。",
        )

    return None


def _finish_reply(
    db: Session,
    session: CoachSession,
    turn: CoachTurn,
    started: float,
    *,
    intent: str,
    reply: str,
) -> dict:
    turn.intent = intent
    turn.status = "completed"
    turn.reply = reply
    turn.latency_ms = int((time.perf_counter() - started) * 1000)
    session.last_turn_at = utcnow()
    session.updated_at = utcnow()
    db.commit()
    return {
        "session": serialize_session(session, None),
        "turn_id": turn.id,
        "intent": turn.intent,
        "status": turn.status,
        "reply": reply,
        "pending": None,
    }


async def handle_turn(
    db: Session,
    user_id: str,
    message: str,
    *,
    session_id: str | None = None,
    app_context: dict | None = None,
) -> dict:
    started = time.perf_counter()
    session = get_or_create_session(db, user_id, session_id)
    context = with_plan_context(
        db,
        user_id,
        app_context if isinstance(app_context, dict) else {},
    )
    text = message.strip()
    turn = CoachTurn(
        session_id=session.id,
        user_id=user_id,
        input_text=text[:4000],
        status="running",
    )
    db.add(turn)
    db.flush()

    conversation = build_conversation_context(
        db,
        user_id,
        session.id,
        exclude_turn_id=turn.id,
        max_turns=50,
        query=text,
    )
    context = CapabilityContext(context, conversation, text)
    if len(conversation.turns) >= 10 and len(conversation.turns) % 10 == 0:
        from ..memory import schedule_session_summary

        schedule_session_summary(user_id, session.id)

    pending = get_active_pending(db, user_id, session.id)

    # Hard safety boundaries run before any capability can build or confirm a
    # write. A blocked turn also drops the stale card so it cannot be confirmed
    # later with one tap.
    decision = assess_safety(db.get(Profile, user_id), text)
    if decision.reply:
        if pending is not None:
            _discard_pending_resource(db, user_id, pending)
            cancel_active_pending(db, session)
        turn.status = "blocked"
        turn.intent = "safety"
        turn.reply = decision.reply
        turn.latency_ms = int((time.perf_counter() - started) * 1000)
        session.last_turn_at = utcnow()
        session.updated_at = utcnow()
        emit_event(
            db,
            user_id,
            "SafetyBlocked",
            entity_type="coach_session",
            entity_id=session.id,
            payload={"flag": decision.flag, "reason": decision.reason},
        )
        db.commit()
        return {
            "session": serialize_session(session, None),
            "turn_id": turn.id,
            "intent": turn.intent,
            "status": turn.status,
            "reply": turn.reply,
            "pending": None,
        }

    if pending is not None and re.search(r"取消|不要了|算了|不记了", text):
        _discard_pending_resource(db, user_id, pending)
        cancel_pending(db, session, pending)
        turn.status = "completed"
        turn.intent = pending.capability_id
        turn.reply = "已取消这次操作。"
        session.last_turn_at = utcnow()
        session.updated_at = utcnow()
        db.commit()
        return {
            "session": serialize_session(session, None),
            "turn_id": turn.id,
            "intent": turn.intent,
            "status": turn.status,
            "reply": turn.reply,
            "pending": None,
        }
    # Additions and corrections must be applied to the active card before any
    # generic "new turn supersedes old card" rule. Otherwise "还有一杯奶茶"
    # or "记错了 74kg" silently loses the pending write.
    if pending is not None and pending.kind == "card":
        followup = await _pending_card_followup(
            db,
            user_id,
            session,
            turn,
            pending,
            text,
            conversation,
            started,
        )
        if followup is not None:
            return followup

    # A new user turn supersedes an old card. Confirmation/cancel should use
    # the dedicated endpoints; typing a new request means the old card is stale.
    if pending is not None and pending.kind in {"card", "insight", "proposal"}:
        _discard_pending_resource(db, user_id, pending)
        cancel_active_pending(db, session)
        pending = None

    intent_override: str | None = None
    diet_draft: dict | None = None
    if pending is not None and pending.kind == "draft":
        if pending.capability_id == DIET:
            if not _looks_like_diet_slot_answer(text):
                cancel_pending(db, session, pending)
                pending = None
            else:
                if pending.payload.get("needs_meal"):
                    text = (
                        f"{pending.payload.get('message') or ''} {text}"
                    ).strip()[:2000]
                diet_draft = dict(pending.payload or {})
                intent_override = DIET
        elif pending.capability_id == TRAINING:
            if not _looks_like_training_slot_answer(text):
                cancel_pending(db, session, pending)
                pending = None
            else:
                stored = pending.payload.get("app_context")
                if isinstance(stored, dict):
                    context = {**stored, **context}
                text = f"{pending.payload.get('message') or ''} {text}".strip()[:2000]
                intent_override = TRAINING
        elif pending.capability_id in {PLANNED, SKIP_MEAL, RESTORE_MEAL, SWAP_MEAL}:
            if not _looks_like_diet_slot_answer(text):
                cancel_pending(db, session, pending)
                pending = None
            else:
                text = f"{pending.payload.get('message') or ''} {text}".strip()[:2000]
                intent_override = pending.capability_id
        elif pending.capability_id == DELETE_METRIC:
            if not (
                _looks_like_training_slot_answer(text)
                or re.search(
                    r"体重|体脂|腰围|臂围|腿围|最近|最新",
                    text,
                )
            ):
                cancel_pending(db, session, pending)
                pending = None
            else:
                text = (
                    f"{pending.payload.get('message') or ''} {text}"
                ).strip()[:2000]
                intent_override = DELETE_METRIC
        elif pending.capability_id == WEIGHT:
            if not re.search(r"\d", text):
                cancel_pending(db, session, pending)
                pending = None
            else:
                text = f"{pending.payload.get('message') or ''} {text}".strip()[:2000]
                intent_override = WEIGHT
        elif pending.capability_id == CARDIO:
            if not _looks_like_cardio(text) and not re.search(r"\d", text):
                cancel_pending(db, session, pending)
                pending = None
            else:
                text = f"{pending.payload.get('message') or ''} {text}".strip()[:2000]
                intent_override = CARDIO
        elif pending.capability_id == STRENGTH:
            if not _looks_like_strength(text) and not re.search(r"\d", text):
                cancel_pending(db, session, pending)
                pending = None
            else:
                text = f"{pending.payload.get('message') or ''} {text}".strip()[:2000]
                intent_override = STRENGTH
        elif pending.capability_id == SKIP_TRAINING:
            if not _looks_like_training_slot_answer(text):
                cancel_pending(db, session, pending)
                pending = None
            else:
                stored = pending.payload.get("app_context")
                if isinstance(stored, dict):
                    context = {**stored, **context}
                text = f"{pending.payload.get('message') or ''} {text}".strip()[:2000]
                intent_override = SKIP_TRAINING
        elif pending.capability_id == GOAL:
            if not _looks_like_goal(text) and not re.search(r"\d", text):
                cancel_pending(db, session, pending)
                pending = None
            else:
                text = f"{pending.payload.get('message') or ''} {text}".strip()[:2000]
                intent_override = GOAL

    if intent_override is None:
        batch = await _try_batch_turn(db, user_id, text, context, conversation)
        if batch is not None:
            batch_reply = str(batch.pop("reply") or "")
            return _finish_pending(
                db,
                session,
                turn,
                started,
                capability_id=BATCH,
                payload=batch,
                reply=batch_reply,
            )

    if intent_override is None and _looks_like_plan_configure(text):
        from .capabilities.plan_configure import resolve as resolve_configure

        resolution = resolve_configure(db, user_id, text)
        if resolution.get("ready"):
            return _finish_pending(
                db,
                session,
                turn,
                started,
                capability_id=CONFIGURE_PLAN,
                payload={
                    "program_id": resolution["program_id"],
                    "plan": resolution["plan"],
                    "profile_before": resolution.get("profile_before") or {},
                    "profile_after": resolution.get("profile_after") or {},
                },
                reply=resolution.get("summary") or "计划已重新排好，确认后激活。",
                kind="proposal",
            )
        return _finish_reply(
            db,
            session,
            turn,
            started,
            intent=CONFIGURE_PLAN,
            reply=(resolution.get("questions") or ["想怎么调整计划？"])[0],
        )

    if intent_override is None and _looks_like_reminders(text):
        from .capabilities.ui_actions import resolve_reminders

        resolution = resolve_reminders(text)
        if resolution.get("ready"):
            return _finish_pending(
                db,
                session,
                turn,
                started,
                capability_id=REMINDERS_UI,
                payload=resolution["payload"],
                reply=resolution.get("summary") or "确认后设置提醒。",
            )
        return _finish_reply(
            db,
            session,
            turn,
            started,
            intent=REMINDERS_UI,
            reply=(resolution.get("questions") or ["提醒设在几点？"])[0],
        )

    if intent_override is None and _looks_like_memory(text):
        from .capabilities.memory import resolve as resolve_memory

        resolution = resolve_memory(text)
        if resolution.get("ready"):
            return _finish_pending(
                db,
                session,
                turn,
                started,
                capability_id=MEMORY,
                payload=resolution["payload"],
                reply=resolution.get("summary") or "确认后记住这条偏好。",
            )
        return _finish_reply(
            db,
            session,
            turn,
            started,
            intent=MEMORY,
            reply=(resolution.get("questions") or ["想让我记住什么？"])[0],
        )

    if intent_override is None and _looks_like_start_training(text):
        from .capabilities.ui_actions import resolve_start

        resolution = resolve_start(db, user_id, context, text)
        if resolution.get("ready"):
            return _finish_pending(
                db,
                session,
                turn,
                started,
                capability_id=START_TRAINING_UI,
                payload=resolution["payload"],
                reply=resolution.get("summary") or "确认后开始训练。",
            )
        return _finish_reply(
            db,
            session,
            turn,
            started,
            intent=START_TRAINING_UI,
            reply=(resolution.get("questions") or ["现在没有可开始的训练。"])[0],
        )

    if intent_override is None and (
        _looks_like_open_screen(text) or _looks_like_analysis_screen(text)
    ):
        from .capabilities.ui_actions import resolve_open

        resolution = resolve_open(text)
        if resolution.get("ready"):
            return _finish_pending(
                db,
                session,
                turn,
                started,
                capability_id=OPEN_SCREEN_UI,
                payload=resolution["payload"],
                reply=resolution.get("summary") or "确认后打开页面。",
            )
        return _finish_reply(
            db,
            session,
            turn,
            started,
            intent=OPEN_SCREEN_UI,
            reply=(resolution.get("questions") or ["想打开哪个页面？"])[0],
        )

    if intent_override is None and _looks_like_add_day(text):
        from .capabilities.training_add_day import resolve as resolve_add_day

        resolution = resolve_add_day(db, user_id, text, context)
        if resolution.get("ready"):
            payload = resolution["payload"]
            set_pending(
                db,
                session,
                kind="proposal",
                capability_id=ADD_DAY,
                payload=payload,
            )
            reply = f"{payload.get('summary') or '加练草案好了。'}确认后生效。"
        else:
            reply = (
                resolution.get("questions") or ["暂时不能增加训练日。"]
            )[0]
        turn.intent = ADD_DAY
        turn.status = "completed"
        turn.reply = reply
        turn.latency_ms = int((time.perf_counter() - started) * 1000)
        session.last_turn_at = utcnow()
        session.updated_at = utcnow()
        db.commit()
        active = get_active_pending(db, user_id, session.id)
        return {
            "session": serialize_session(session, active),
            "turn_id": turn.id,
            "intent": turn.intent,
            "status": turn.status,
            "reply": reply,
            "pending": serialize_pending(active),
        }

    if intent_override is None and (
        _looks_like_single_exercise_edit(text)
        or _looks_like_batch_exercise_edit(text)
    ):
        from .capabilities.training_exercise_edit import (
            resolve as resolve_single_exercise_edit,
        )

        resolution = resolve_single_exercise_edit(db, user_id, text, context)
        if resolution.get("ready"):
            payload = resolution["payload"]
            set_pending(
                db,
                session,
                kind="proposal",
                capability_id=EDIT_EXERCISE,
                payload=payload,
            )
            reply = f"{payload.get('summary') or '动作调整草案好了。'}确认后生效。"
        else:
            reply = (
                resolution.get("questions") or ["动作调整暂时不能生成。"]
            )[0]
        turn.intent = EDIT_EXERCISE
        turn.status = "completed"
        turn.reply = reply
        turn.latency_ms = int((time.perf_counter() - started) * 1000)
        session.last_turn_at = utcnow()
        session.updated_at = utcnow()
        db.commit()
        active = get_active_pending(db, user_id, session.id)
        return {
            "session": serialize_session(session, active),
            "turn_id": turn.id,
            "intent": turn.intent,
            "status": turn.status,
            "reply": reply,
            "pending": serialize_pending(active),
        }

    if intent_override is None and _looks_like_exercise_edit(text):
        from .capabilities.training_edit import (
            resolve as resolve_exercise_edit,
        )

        resolution = resolve_exercise_edit(db, user_id, text, context)
        if resolution.get("ready"):
            payload = resolution["payload"]
            set_pending(
                db,
                session,
                kind="proposal",
                capability_id=EDIT_EXERCISES,
                payload=payload,
            )
            reply = f"{payload.get('summary') or '动作调整草案好了。'}确认后生效。"
        else:
            reply = (
                resolution.get("questions") or ["动作调整暂时不能生成。"]
            )[0]
        turn.intent = EDIT_EXERCISES
        turn.status = "completed"
        turn.reply = reply
        turn.latency_ms = int((time.perf_counter() - started) * 1000)
        session.last_turn_at = utcnow()
        session.updated_at = utcnow()
        db.commit()
        active = get_active_pending(db, user_id, session.id)
        return {
            "session": serialize_session(session, active),
            "turn_id": turn.id,
            "intent": turn.intent,
            "status": turn.status,
            "reply": reply,
            "pending": serialize_pending(active),
        }

    if intent_override is None and _looks_like_plan_edit(text):
        reply = (
            "可以。你想改哪一类？\n"
            "1. 改训练日：把周三的训练改到周五\n"
            "2. 换动作：把哑铃卧推换成杠铃卧推\n"
            "3. 调强度：计划太累，减量\n"
            "直接说具体改法，我会生成待确认卡。"
        )
        turn.intent = "training.edit_plan"
        turn.status = "completed"
        turn.reply = reply
        turn.latency_ms = int((time.perf_counter() - started) * 1000)
        session.last_turn_at = utcnow()
        session.updated_at = utcnow()
        db.commit()
        return {
            "session": serialize_session(session, None),
            "turn_id": turn.id,
            "intent": turn.intent,
            "status": turn.status,
            "reply": reply,
            "pending": None,
        }

    if intent_override is None and _looks_like_correction(text):
        last_action = conversation.last_action
        last_age = (
            _minutes_since(last_action.created_at)
            if last_action is not None
            else None
        )
        session_age = _minutes_since(session.last_turn_at)
        if last_action is not None and last_age is not None and last_age <= 15:
            last_capability = last_action.capability_id
        elif session_age is not None and session_age <= 15:
            last_capability = session.active_topic
        else:
            last_capability = None
        if last_capability == WEIGHT:
            from .capabilities.body import resolve as resolve_weight

            resolution = resolve_weight(text)
            if resolution.get("ready"):
                payload = resolution["payload"]
                _pending_card(
                    db,
                    session,
                    capability_id=WEIGHT,
                    payload=payload,
                )
                reply = f"改好了，准备记录体重 {payload['weight_kg']} kg。确认后写入。"
            else:
                question = (resolution.get("questions") or ["体重大概多少公斤？"])[0]
                _pending_draft(
                    db,
                    session,
                    capability_id=WEIGHT,
                    payload={"message": text},
                )
                reply = question
            turn.intent = WEIGHT
            turn.status = "completed"
            turn.reply = reply
            turn.latency_ms = int((time.perf_counter() - started) * 1000)
            session.last_turn_at = utcnow()
            session.updated_at = utcnow()
            db.commit()
            active = get_active_pending(db, user_id, session.id)
            return {
                "session": serialize_session(session, active),
                "turn_id": turn.id,
                "intent": turn.intent,
                "status": turn.status,
                "reply": reply,
                "pending": serialize_pending(active),
            }
        if last_capability in {DIET, BATCH} and last_action is not None:
            diet_action = _diet_action_for_correction(db, user_id, last_action)
            if diet_action is not None:
                handled = await _handle_executed_diet_correction(
                    db,
                    user_id,
                    session,
                    turn,
                    started,
                    text,
                    diet_action,
                    conversation,
                )
                if handled is not None:
                    return handled
        if last_capability is None:
            emit_event(
                db,
                user_id,
                "CoachActionGap",
                entity_type="coach_turn",
                entity_id=turn.id,
                payload={"message": text[:500], "stage": "clarification"},
            )
            reply = "你想改的是体重、饮食，还是训练？直接告诉我新的数值或内容。"
            turn.intent = "clarification"
            turn.status = "completed"
            turn.reply = reply
            turn.latency_ms = int((time.perf_counter() - started) * 1000)
            session.last_turn_at = utcnow()
            session.updated_at = utcnow()
            db.commit()
            return {
                "session": serialize_session(session, None),
                "turn_id": turn.id,
                "intent": turn.intent,
                "status": turn.status,
                "reply": reply,
                "pending": None,
            }

    if intent_override is None and _looks_like_body_review(text):
        from .capabilities.body_review import resolve as resolve_body_review

        resolution = resolve_body_review(db, user_id)
        payload = resolution["payload"]
        set_pending(
            db,
            session,
            kind="insight",
            capability_id=BODY_REVIEW,
            payload=payload,
        )
        reply = payload.get("summary") or "身体趋势已经整理好。"
        turn.intent = BODY_REVIEW
        turn.status = "completed"
        turn.reply = reply
        turn.latency_ms = int((time.perf_counter() - started) * 1000)
        session.last_turn_at = utcnow()
        session.updated_at = utcnow()
        db.commit()
        active = get_active_pending(db, user_id, session.id)
        return {
            "session": serialize_session(session, active),
            "turn_id": turn.id,
            "intent": turn.intent,
            "status": turn.status,
            "reply": reply,
            "pending": serialize_pending(active),
        }

    if intent_override is None and _looks_like_week_schedule(text):
        from .capabilities.training_week import resolve as resolve_week_schedule

        resolution = resolve_week_schedule(db, user_id, text, context)
        payload = resolution["payload"]
        set_pending(
            db,
            session,
            kind="insight",
            capability_id=WEEK_SCHEDULE,
            payload=payload,
        )
        reply = payload.get("summary") or "本周训练安排已经整理好。"
        turn.intent = WEEK_SCHEDULE
        turn.status = "completed"
        turn.reply = reply
        turn.latency_ms = int((time.perf_counter() - started) * 1000)
        session.last_turn_at = utcnow()
        session.updated_at = utcnow()
        db.commit()
        active = get_active_pending(db, user_id, session.id)
        return {
            "session": serialize_session(session, active),
            "turn_id": turn.id,
            "intent": turn.intent,
            "status": turn.status,
            "reply": reply,
            "pending": serialize_pending(active),
        }

    if intent_override is None and _looks_like_training_preview(text):
        from .capabilities.training_preview import (
            resolve as resolve_training_preview,
        )

        resolution = resolve_training_preview(db, user_id, context)
        payload = resolution["payload"]
        set_pending(
            db,
            session,
            kind="insight",
            capability_id=PREVIEW,
            payload=payload,
        )
        reply = payload.get("summary") or "下一练已经整理好。"
        turn.intent = PREVIEW
        turn.status = "completed"
        turn.reply = reply
        turn.latency_ms = int((time.perf_counter() - started) * 1000)
        session.last_turn_at = utcnow()
        session.updated_at = utcnow()
        db.commit()
        active = get_active_pending(db, user_id, session.id)
        return {
            "session": serialize_session(session, active),
            "turn_id": turn.id,
            "intent": turn.intent,
            "status": turn.status,
            "reply": reply,
            "pending": serialize_pending(active),
        }

    if intent_override is None and _looks_like_diet_strategy_edit(text):
        from .capabilities.diet_day_strategy import (
            resolve as resolve_day_strategy,
        )

        resolution = await resolve_day_strategy(db, user_id, text)
        if resolution.get("ready"):
            payload = resolution["payload"]
            set_pending(
                db,
                session,
                kind="proposal",
                capability_id=DIET_DAY_STRATEGY,
                payload=payload,
            )
            reply = f"{payload.get('summary') or '单日饮食草案好了。'}确认后保存。"
        else:
            reply = (
                resolution.get("questions") or ["单日饮食策略暂时不能调整。"]
            )[0]
        turn.intent = DIET_DAY_STRATEGY
        turn.status = "completed"
        turn.reply = reply
        turn.latency_ms = int((time.perf_counter() - started) * 1000)
        session.last_turn_at = utcnow()
        session.updated_at = utcnow()
        db.commit()
        active = get_active_pending(db, user_id, session.id)
        return {
            "session": serialize_session(session, active),
            "turn_id": turn.id,
            "intent": turn.intent,
            "status": turn.status,
            "reply": reply,
            "pending": serialize_pending(active),
        }

    if intent_override is None and _looks_like_diet_week(text):
        from .capabilities.diet_week import resolve as resolve_diet_week

        resolution = await resolve_diet_week(db, user_id, text)
        if resolution.get("ready"):
            payload = resolution["payload"]
            set_pending(
                db,
                session,
                kind="proposal",
                capability_id=DIET_WEEK,
                payload=payload,
            )
            reply = f"{payload.get('summary') or '一周饮食草案好了。'}确认后保存。"
        else:
            reply = (
                resolution.get("questions") or ["一周饮食计划暂时不能生成。"]
            )[0]
        turn.intent = DIET_WEEK
        turn.status = "completed"
        turn.reply = reply
        turn.latency_ms = int((time.perf_counter() - started) * 1000)
        session.last_turn_at = utcnow()
        session.updated_at = utcnow()
        db.commit()
        active = get_active_pending(db, user_id, session.id)
        return {
            "session": serialize_session(session, active),
            "turn_id": turn.id,
            "intent": turn.intent,
            "status": turn.status,
            "reply": reply,
            "pending": serialize_pending(active),
        }

    if intent_override is None and _looks_like_diet_plan(text):
        from .capabilities.diet_plan import resolve as resolve_diet_plan

        resolution = await resolve_diet_plan(db, user_id, text)
        if resolution.get("ready"):
            payload = resolution["payload"]
            set_pending(
                db,
                session,
                kind="proposal",
                capability_id=DIET_PLAN,
                payload=payload,
            )
            reply = f"{payload.get('summary') or '饮食计划草案好了。'}确认后保存。"
        else:
            reply = (resolution.get("questions") or ["饮食计划暂时不能生成。"])[0]
        turn.intent = DIET_PLAN
        turn.status = "completed"
        turn.reply = reply
        turn.latency_ms = int((time.perf_counter() - started) * 1000)
        session.last_turn_at = utcnow()
        session.updated_at = utcnow()
        db.commit()
        active = get_active_pending(db, user_id, session.id)
        return {
            "session": serialize_session(session, active),
            "turn_id": turn.id,
            "intent": turn.intent,
            "status": turn.status,
            "reply": reply,
            "pending": serialize_pending(active),
        }

    if intent_override is None and _looks_like_diet_review(text):
        from .capabilities.diet_review import resolve as resolve_diet_review

        resolution = resolve_diet_review(db, user_id, text)
        payload = resolution["payload"]
        set_pending(
            db,
            session,
            kind="insight",
            capability_id=DIET_REVIEW,
            payload=payload,
        )
        reply = payload.get("summary") or "今天的饮食复盘已经生成。"
        turn.intent = DIET_REVIEW
        turn.status = "completed"
        turn.reply = reply
        turn.latency_ms = int((time.perf_counter() - started) * 1000)
        session.last_turn_at = utcnow()
        session.updated_at = utcnow()
        db.commit()
        active = get_active_pending(db, user_id, session.id)
        return {
            "session": serialize_session(session, active),
            "turn_id": turn.id,
            "intent": turn.intent,
            "status": turn.status,
            "reply": reply,
            "pending": serialize_pending(active),
        }

    if intent_override is None and _looks_like_review(text):
        from .capabilities.review import resolve as resolve_review

        resolution = resolve_review(db, user_id)
        payload = resolution["payload"]
        set_pending(
            db,
            session,
            kind="insight",
            capability_id=REVIEW,
            payload=payload,
        )
        reply = payload.get("summary") or "本周复盘已经生成。"
        turn.intent = REVIEW
        turn.status = "completed"
        turn.reply = reply
        turn.latency_ms = int((time.perf_counter() - started) * 1000)
        session.last_turn_at = utcnow()
        session.updated_at = utcnow()
        db.commit()
        active = get_active_pending(db, user_id, session.id)
        return {
            "session": serialize_session(session, active),
            "turn_id": turn.id,
            "intent": turn.intent,
            "status": turn.status,
            "reply": reply,
            "pending": serialize_pending(active),
        }

    if intent_override is None and _looks_like_plan_adjust(text):
        from .capabilities.plan import resolve_adjust

        resolution = resolve_adjust(db, user_id, text)
        if resolution.get("ready"):
            plan_data = resolution["plan"]
            set_pending(
                db,
                session,
                kind="proposal",
                capability_id=ADJUST_PLAN,
                payload={
                    "program_id": resolution["program_id"],
                    "plan": plan_data,
                },
            )
            reply = (
                f"计划调整草案好了：{plan_data.get('title') or '训练计划'}。"
                "确认后激活。"
            )
        else:
            reply = (resolution.get("questions") or ["计划暂时不能调整。"])[0]
        turn.intent = ADJUST_PLAN
        turn.status = "completed"
        turn.reply = reply
        turn.latency_ms = int((time.perf_counter() - started) * 1000)
        session.last_turn_at = utcnow()
        session.updated_at = utcnow()
        db.commit()
        active = get_active_pending(db, user_id, session.id)
        return {
            "session": serialize_session(session, active),
            "turn_id": turn.id,
            "intent": turn.intent,
            "status": turn.status,
            "reply": reply,
            "pending": serialize_pending(active),
        }

    if intent_override is None and _looks_like_plan_restore(text):
        from .capabilities.plan import resolve_restore

        resolution = resolve_restore(db, user_id, text)
        if resolution.get("ready"):
            payload = resolution["payload"]
            return _finish_pending(
                db,
                session,
                turn,
                started,
                capability_id=RESTORE_PLAN,
                payload=payload,
                reply=f"{payload['summary']}？确认后切换。",
                kind="proposal",
            )
        return _finish_reply(
            db,
            session,
            turn,
            started,
            intent=RESTORE_PLAN,
            reply=(resolution.get("questions") or ["想恢复哪一版计划？"])[0],
        )

    if intent_override is None and _looks_like_plan(text):
        from .capabilities.plan import resolve as resolve_plan

        resolution = await resolve_plan(db, user_id)
        if resolution.get("ready"):
            plan_data = resolution["plan"]
            set_pending(
                db,
                session,
                kind="proposal",
                capability_id=PLAN,
                payload={
                    "program_id": resolution["program_id"],
                    "plan": plan_data,
                },
            )
            reply = (
                f"计划排好了：{plan_data.get('title') or '训练计划'}，"
                f"{plan_data.get('weeks') or 4} 周。确认后激活。"
            )
        else:
            reply = (resolution.get("questions") or ["计划暂时生成不了。"])[0]
        turn.intent = PLAN
        turn.status = "completed"
        turn.reply = reply
        turn.latency_ms = int((time.perf_counter() - started) * 1000)
        session.last_turn_at = utcnow()
        session.updated_at = utcnow()
        db.commit()
        active = get_active_pending(db, user_id, session.id)
        return {
            "session": serialize_session(session, active),
            "turn_id": turn.id,
            "intent": turn.intent,
            "status": turn.status,
            "reply": reply,
            "pending": serialize_pending(active),
        }

    if intent_override == GOAL or (
        intent_override is None and _looks_like_goal(text)
    ):
        from .capabilities.profile import resolve as resolve_goal

        resolution = resolve_goal(text)
        if resolution.get("ready"):
            payload = resolution["payload"]
            _pending_card(
                db,
                session,
                capability_id=GOAL,
                payload=payload,
            )
            reply = "目标已整理好，确认后更新。"
        else:
            question = (resolution.get("questions") or ["想改成什么目标？"])[0]
            _pending_draft(
                db,
                session,
                capability_id=GOAL,
                payload={"message": text},
            )
            reply = question
        turn.intent = GOAL
        turn.status = "completed"
        turn.reply = reply
        turn.latency_ms = int((time.perf_counter() - started) * 1000)
        session.last_turn_at = utcnow()
        session.updated_at = utcnow()
        db.commit()
        active = get_active_pending(db, user_id, session.id)
        return {
            "session": serialize_session(session, active),
            "turn_id": turn.id,
            "intent": turn.intent,
            "status": turn.status,
            "reply": reply,
            "pending": serialize_pending(active),
        }

    if intent_override is None and _looks_like_food_delete(text):
        from .capabilities.log_edit import resolve_delete_food

        resolution = resolve_delete_food(db, user_id, text)
        if resolution.get("ready"):
            return _finish_pending(
                db,
                session,
                turn,
                started,
                capability_id=DIET_DELETE,
                payload=resolution["payload"],
                reply=resolution.get("summary") or "确认后删除这条饮食记录。",
            )
        return _finish_reply(
            db,
            session,
            turn,
            started,
            intent=DIET_DELETE,
            reply=(resolution.get("questions") or ["要删除哪条饮食记录？"])[0],
        )

    if intent_override is None and _looks_like_food_update(text):
        from .capabilities.log_edit import resolve_update_food

        resolution = resolve_update_food(db, user_id, text)
        if resolution.get("ready"):
            return _finish_pending(
                db,
                session,
                turn,
                started,
                capability_id=DIET_UPDATE,
                payload=resolution["payload"],
                reply=resolution.get("summary") or "确认后修改这条饮食记录。",
            )
        return _finish_reply(
            db,
            session,
            turn,
            started,
            intent=DIET_UPDATE,
            reply=(resolution.get("questions") or ["要改成多少？"])[0],
        )

    if intent_override is None and _looks_like_workout_delete(text):
        from .capabilities.log_edit import resolve_delete_workout

        resolution = resolve_delete_workout(db, user_id, text)
        if resolution.get("ready"):
            return _finish_pending(
                db,
                session,
                turn,
                started,
                capability_id=DELETE_WORKOUT,
                payload=resolution["payload"],
                reply=resolution.get("summary") or "确认后删除这条训练记录。",
            )
        return _finish_reply(
            db,
            session,
            turn,
            started,
            intent=DELETE_WORKOUT,
            reply=(resolution.get("questions") or ["要删除哪条训练记录？"])[0],
        )

    if intent_override is None and _looks_like_workout_update(text):
        from .capabilities.log_edit import resolve_update_workout

        resolution = resolve_update_workout(db, user_id, text)
        if resolution.get("ready"):
            return _finish_pending(
                db,
                session,
                turn,
                started,
                capability_id=UPDATE_WORKOUT,
                payload=resolution["payload"],
                reply=resolution.get("summary") or "确认后修改这条训练记录。",
            )
        return _finish_reply(
            db,
            session,
            turn,
            started,
            intent=UPDATE_WORKOUT,
            reply=(resolution.get("questions") or ["要改时长、重量还是备注？"])[0],
        )

    meal_capability: str | None = None
    if intent_override in {PLANNED, SKIP_MEAL, RESTORE_MEAL}:
        meal_capability = intent_override
    elif intent_override is None:
        if _looks_like_restore_meal(text):
            meal_capability = RESTORE_MEAL
        elif _looks_like_skip_meal(text):
            meal_capability = SKIP_MEAL
        elif _looks_like_swap_meal(text):
            meal_capability = SWAP_MEAL
        elif _looks_like_planned_meal(text):
            meal_capability = PLANNED

    if meal_capability is not None:
        from .capabilities.diet import resolve_planned

        resolution = resolve_planned(text, require_explicit_meal=True)
        if resolution.get("ready"):
            payload = resolution["payload"]
            _pending_card(
                db,
                session,
                capability_id=meal_capability,
                payload=payload,
            )
            labels = {
                PLANNED: "记录计划餐",
                SKIP_MEAL: "跳过计划餐",
                RESTORE_MEAL: "恢复计划餐",
                SWAP_MEAL: "换一餐",
            }
            reply = (
                f"准备{labels[meal_capability]}：{payload['date']} "
                f"{payload['meal']}。确认后生效。"
            )
        else:
            question = (resolution.get("questions") or ["哪一餐？"])[0]
            _pending_draft(
                db,
                session,
                capability_id=meal_capability,
                payload={"message": text},
            )
            reply = question
        turn.intent = meal_capability
    elif intent_override == SKIP_TRAINING or (
        intent_override is None and _looks_like_skip_training(text)
    ):
        from .capabilities.training import resolve_skip

        resolution = resolve_skip(db, user_id, text, context)
        if resolution.get("ready"):
            payload = resolution["payload"]
            _pending_card(
                db,
                session,
                capability_id=SKIP_TRAINING,
                payload=payload,
            )
            reply = f"准备跳过 {payload['date']} 的「{payload['title']}」。确认后生效。"
        else:
            question = (resolution.get("questions") or ["想跳过哪一天？"])[0]
            _pending_draft(
                db,
                session,
                capability_id=SKIP_TRAINING,
                payload={"message": text, "app_context": context},
            )
            reply = question
        turn.intent = SKIP_TRAINING
    elif intent_override == TRAINING or (
        intent_override is None and _looks_like_reschedule(text)
    ):
        from .capabilities.training import resolve as resolve_training

        resolution = resolve_training(db, user_id, text, context)
        if resolution.get("ready"):
            payload = resolution["payload"]
            _pending_card(
                db,
                session,
                capability_id=TRAINING,
                payload=payload,
            )
            reply = _training_reply(payload)
            turn.intent = TRAINING
        else:
            question = (resolution.get("questions") or ["想改到哪一天？"])[0]
            _pending_draft(
                db,
                session,
                capability_id=TRAINING,
                payload={"message": text, "app_context": context},
            )
            reply = question
            turn.intent = TRAINING
    elif intent_override == CARDIO or (
        intent_override is None and _looks_like_cardio(text)
    ):
        from .capabilities.training import resolve_cardio

        resolution = resolve_cardio(text)
        if resolution.get("ready"):
            payload = resolution["payload"]
            _pending_card(
                db,
                session,
                capability_id=CARDIO,
                payload=payload,
            )
            reply = (
                f"准备记录 {payload['date']} 的{payload['title']}，"
                f"{payload['duration_minutes']} 分钟。确认后写入。"
            )
        else:
            question = (resolution.get("questions") or ["这次练了多久？"])[0]
            _pending_draft(
                db,
                session,
                capability_id=CARDIO,
                payload={"message": text},
            )
            reply = question
        turn.intent = CARDIO
    elif intent_override == STRENGTH or (
        intent_override is None and _looks_like_strength(text)
    ):
        from .capabilities.training import resolve_strength

        resolution = resolve_strength(db, text)
        if resolution.get("ready"):
            payload = resolution["payload"]
            _pending_card(
                db,
                session,
                capability_id=STRENGTH,
                payload=payload,
            )
            reply = (
                f"准备记录 {payload['date']} 的{payload['title']}，"
                f"{len(payload['sets'])} 组。确认后写入。"
            )
        else:
            question = (resolution.get("questions") or ["动作、重量和次数是什么？"])[0]
            _pending_draft(
                db,
                session,
                capability_id=STRENGTH,
                payload={"message": text},
            )
            reply = question
        turn.intent = STRENGTH
    elif intent_override == DELETE_METRIC or (
        intent_override is None and _looks_like_body_delete(text)
    ):
        from .capabilities.body import resolve_delete

        resolution = resolve_delete(db, user_id, text)
        if resolution.get("ready"):
            payload = resolution["payload"]
            _pending_card(
                db,
                session,
                capability_id=DELETE_METRIC,
                payload=payload,
            )
            reply = f"{payload['summary']}？确认后删除。"
        else:
            question = (
                resolution.get("questions") or ["要删哪条身体记录？"]
            )[0]
            _pending_draft(
                db,
                session,
                capability_id=DELETE_METRIC,
                payload={"message": text},
            )
            reply = question
        turn.intent = DELETE_METRIC
    elif intent_override == WEIGHT or (
        intent_override is None and _looks_like_weight(text)
    ):
        from .capabilities.body import resolve as resolve_weight

        resolution = resolve_weight(text)
        if resolution.get("ready"):
            payload = resolution["payload"]
            _pending_card(
                db,
                session,
                capability_id=WEIGHT,
                payload=payload,
            )
            reply = _body_metric_reply(payload)
        else:
            question = (resolution.get("questions") or ["体重大概多少公斤？"])[0]
            _pending_draft(
                db,
                session,
                capability_id=WEIGHT,
                payload={"message": text},
            )
            reply = question
        turn.intent = WEIGHT
    elif intent_override == DIET or (
        intent_override is None and _looks_like_food(text)
    ):
        from .capabilities.diet import resolve as resolve_diet

        if diet_draft:
            strip_terms = [
                str(value)
                for value in diet_draft.get("strip_terms") or []
                if str(value).strip()
            ]
            if strip_terms:
                _strip_diet_items_by_terms(
                    diet_draft,
                    strip_terms,
                    parse_meal(text),
                )
        resolution = await resolve_diet(
            db,
            user_id,
            text,
            history_context=conversation.reference_context(),
            draft=diet_draft,
        )
        meals = resolution.get("meals") or []
        replacement = _diet_replacement_meta(diet_draft or {})
        all_questions = [
            str(question)
            for meal in meals
            for question in meal.get("questions") or []
            if str(question).strip()
        ]
        if resolution.get("questions"):
            all_questions.extend(
                str(question)
                for question in resolution.get("questions") or []
                if str(question).strip()
            )
        all_missing = [
            slot
            for meal in meals
            for slot in meal.get("missing_slots") or []
            if isinstance(slot, dict)
        ] + [
            slot
            for slot in resolution.get("missing_slots") or []
            if isinstance(slot, dict)
        ]
        if all_questions or all_missing:
            _pending_draft(
                db,
                session,
                capability_id=DIET,
                payload={
                    **replacement,
                    "text": text,
                    "date": resolution.get("date"),
                    "meal": resolution.get("meal"),
                    "items": resolution.get("items") or [],
                    "meals": meals or None,
                    "missing_slots": all_missing,
                    "questions": all_questions,
                },
            )
            reply = _food_question_text(meals) if meals else (
                all_questions[0] if all_questions else "这餐还需要补充信息。"
            )
            turn.intent = DIET
        else:
            payload = {
                **replacement,
                "date": resolution["date"],
                "meal": resolution["meal"],
                "raw_text": text[:500],
                "items": resolution.get("items") or [],
            }
            if meals:
                payload["meals"] = meals
            _pending_card(
                db,
                session,
                capability_id=DIET,
                payload=payload,
            )
            if meals:
                reply = _food_reply_multi(meals)
            else:
                reply = _food_reply(resolution)
                other_meals = [
                    item
                    for item in resolution.get("meal_mentions") or []
                    if item != resolution.get("meal")
                ]
                if other_meals:
                    labels = "、".join(
                        MEAL_LABELS.get(item, item) for item in other_meals
                    )
                    reply += f" 另外看到你提到{labels}，确认这餐后我再帮你记。"
            turn.intent = DIET
    else:
        profile = db.get(Profile, user_id)
        if profile is None:
            reply = "先完成个人档案，我才能给你更准确的建议。"
            turn.intent = "unsupported"
        else:
            if _should_try_semantic_route(text):
                from .router import route_intent

                routed = await route_intent(
                    db,
                    user_id,
                    text,
                    history_context=conversation.reference_context(),
                )
                if routed is not None:
                    dispatched = await _dispatch_semantic_capability(
                        db,
                        user_id,
                        session,
                        turn,
                        started,
                        text,
                        context,
                        conversation,
                        routed,
                    )
                    if dispatched is not None:
                        return dispatched

            from ...config import settings
            from ..memory import schedule_memory_extraction
            from ..queries import active_program
            from .capabilities.coach_answer import (
                resolve as resolve_answer,
            )

            history = conversation.history_items()
            if _looks_like_action_request(text):
                emit_event(
                    db,
                    user_id,
                    "CoachActionGap",
                    entity_type="coach_turn",
                    entity_id=turn.id,
                    payload={"message": text[:500]},
                )
            try:
                result = await resolve_answer(
                    db,
                    profile,
                    active_program(db, user_id),
                    history,
                    text,
                    app_context=context,
                    memory_book=conversation.memory_context_text(),
                )
            except Exception as exc:  # noqa: BLE001 - keep failed turns auditable
                turn.status = "failed"
                turn.error = str(exc)[:500]
                db.commit()
                raise
            reply = result.get("reply") or "我在。可以再说具体一点。"
            if result.get("safety_flag"):
                turn.intent = "safety"
                turn.status = "blocked"
            else:
                turn.intent = "coach.answer"
                if not settings.use_mock_llm and len(text.strip()) >= 8:
                    schedule_memory_extraction(
                        user_id,
                        text,
                        reply,
                        source="coach_control",
                    )

    if turn.status != "blocked":
        turn.status = "completed"
    turn.reply = reply
    turn.latency_ms = int((time.perf_counter() - started) * 1000)
    session.last_turn_at = utcnow()
    session.updated_at = utcnow()
    db.commit()
    active = get_active_pending(db, user_id, session.id)
    return {
        "session": serialize_session(session, active),
        "turn_id": turn.id,
        "intent": turn.intent,
        "status": turn.status,
        "reply": reply,
        "pending": serialize_pending(active),
    }


def _discard_pending_resource(
    db: Session,
    user_id: str,
    pending: CoachPending | None,
) -> None:
    if pending is None:
        return
    if pending.capability_id == BATCH:
        from .capabilities.plan import discard

        for action in (pending.payload or {}).get("batch") or []:
            if not isinstance(action, dict):
                continue
            if str(action.get("capability_id") or "") not in {
                PLAN,
                ADJUST_PLAN,
                CONFIGURE_PLAN,
            }:
                continue
            program_id = str(
                (action.get("payload") or {}).get("program_id") or ""
            )
            if program_id:
                discard(db, user_id, program_id)
        return
    if pending.capability_id not in {PLAN, ADJUST_PLAN, CONFIGURE_PLAN}:
        return
    program_id = str((pending.payload or {}).get("program_id") or "")
    if program_id:
        from .capabilities.plan import discard

        discard(db, user_id, program_id)


def _load_pending(db: Session, user_id: str, pending_id: str) -> tuple[CoachSession, CoachPending]:
    pending = db.get(CoachPending, pending_id)
    if pending is None or pending.user_id != user_id:
        raise LookupError("待确认操作不存在")
    session = db.get(CoachSession, pending.session_id)
    if session is None or session.user_id != user_id:
        raise LookupError("会话不存在")
    return session, pending


def _confirm_batch(
    db: Session,
    user_id: str,
    session: CoachSession,
    pending: CoachPending,
    action_id: str,
) -> dict:
    actions = pending.payload.get("batch")
    if not isinstance(actions, list) or len(actions) < 2:
        raise ValueError("批量操作内容不完整")

    batch_context = pending.payload.get("context") or {}
    allowed_plan = str(batch_context.get("plan_id") or "").strip()
    allowed_days = {
        str(day_id)
        for day_id in batch_context.get("day_ids") or []
        if str(day_id).strip()
    }
    for item in actions[:3]:
        if not isinstance(item, dict):
            raise ValueError("批量操作内容不完整")
        capability_id = str(item.get("capability_id") or "")
        if capability_id not in {
            TRAINING,
            SKIP_TRAINING,
            ADD_DAY,
            EDIT_EXERCISE,
            EDIT_EXERCISES,
        }:
            continue
        sub_payload = item.get("payload")
        sub_payload = sub_payload if isinstance(sub_payload, dict) else {}
        if allowed_plan and str(sub_payload.get("plan_id") or "") != allowed_plan:
            raise ValueError("训练计划已变化，请重新生成这张卡")
        if (
            capability_id
            in {
                TRAINING,
                SKIP_TRAINING,
                EDIT_EXERCISE,
                EDIT_EXERCISES,
            }
            and allowed_days
            and str(sub_payload.get("day_id") or "") not in allowed_days
        ):
            raise ValueError("训练日已变化，请重新生成这张卡")

    executed_ids: list[str] = []
    sub_pending_ids: list[str] = []
    results: list[dict] = []
    try:
        for item in actions[:3]:
            if not isinstance(item, dict):
                raise ValueError("批量操作内容不完整")
            capability_id = str(item.get("capability_id") or "")
            sub_payload = item.get("payload")
            if not capability_id or capability_id == BATCH:
                raise ValueError("批量操作包含不支持的能力")
            if not isinstance(sub_payload, dict):
                sub_payload = {}
            sub_id = str(uuid4())
            sub_pending = CoachPending(
                id=str(uuid4()),
                session_id=session.id,
                user_id=user_id,
                kind="card",
                capability_id=capability_id,
                payload=sub_payload,
                status="pending",
                action_id=sub_id,
                expires_at=utcnow() + PENDING_TTL,
            )
            db.add(sub_pending)
            db.flush()
            sub_pending_ids.append(sub_pending.id)
            result = confirm_pending(db, user_id, sub_pending.id)
            executed_ids.append(str(result.get("action_id") or sub_id))
            results.append(result)
    except Exception as exc:  # noqa: BLE001 - roll back partial batch
        for sub_id in executed_ids:
            with contextlib.suppress(Exception):
                undo_action(db, user_id, sub_id)
        for sub_pending_id in sub_pending_ids:
            sub_pending = db.get(CoachPending, sub_pending_id)
            if sub_pending is not None and sub_pending.status == "pending":
                _discard_pending_resource(db, user_id, sub_pending)
                sub_pending.status = "cancelled"
        db.commit()
        raise ValueError("批量操作执行失败，已回滚已完成项") from exc

    domains = sorted(
        {
            domain
            for result in results
            for domain in result.get("refresh_domains") or []
        }
    )
    receipt = {
        "summary": f"已执行 {len(results)} 项操作",
        "actions": [result.get("receipt") or {} for result in results],
        "capability_id": BATCH,
        "action_id": action_id,
        "refresh_domains": domains,
    }
    record = CoachActionRecord(
        id=action_id,
        user_id=user_id,
        session_id=session.id,
        capability_id=BATCH,
        status="executed",
        payload=pending.payload,
        before={"sub_action_ids": executed_ids},
        after={"sub_action_ids": executed_ids},
        receipt=receipt,
        undo_token=action_id,
        idempotency_key=action_id,
        executed_at=utcnow(),
    )
    db.add(record)
    consume_pending(db, session, pending)
    db.commit()
    return {
        "action_id": action_id,
        "status": "executed",
        "receipt": receipt,
        "refresh_domains": domains,
        "idempotent": False,
    }


def _replace_previous_coach_action(
    db: Session,
    user_id: str,
    action_id: str,
) -> list[dict]:
    """Mark an executed food action undone and snapshot its current logs.

    Used when a correction card is confirmed. Keeping this in the same
    transaction as the new inserts means a failed write leaves the old logs
    intact. The snapshot is what undo restores, so a food the user deleted
    before correcting is not resurrected.
    """
    record = db.execute(
        select(CoachActionRecord).where(
            CoachActionRecord.id == action_id,
            CoachActionRecord.user_id == user_id,
        )
    ).scalar_one_or_none()
    if record is None:
        raise LookupError("要替换的记录不存在")
    if record.status == "undone":
        return []
    if record.status != "executed":
        raise ValueError("上一条记录已经不能替换")
    if record.capability_id != DIET:
        raise ValueError("只能替换饮食记录")
    from ..coach_actions.food_actions import _food_log_payload
    from .capabilities.diet import undo as undo_diet

    logs = (
        db.execute(
            select(FoodLog)
            .where(
                FoodLog.user_id == user_id,
                FoodLog.source_action_id == record.id,
            )
            .order_by(FoodLog.logged_at, FoodLog.id)
        )
        .scalars()
        .all()
    )
    snapshot = [_food_log_payload(log) for log in logs]
    undo_diet(db, user_id, record.id, record.payload)
    record.status = "undone"
    record.undone_at = utcnow()
    emit_event(
        db,
        user_id,
        "ActionUndone",
        entity_type="coach_action",
        entity_id=action_id,
        payload={"capability_id": record.capability_id, "replaced": True},
    )
    db.flush()
    return snapshot


def _undo_diet_replacement(
    db: Session,
    user_id: str,
    record: CoachActionRecord,
    replaced_id: str,
) -> dict:
    """Undo a replacement and restore the logs it replaced."""
    from ..coach_actions.food_actions import _restore_food_log
    from .capabilities.diet import undo as undo_diet

    result = undo_diet(db, user_id, record.id, record.payload)
    snapshots = [
        item
        for item in (record.before or {}).get("previous_logs") or []
        if isinstance(item, dict)
    ]
    existing_client_ids = {
        str(log.client_id)
        for log in db.execute(
            select(FoodLog).where(
                FoodLog.user_id == user_id,
                FoodLog.source_action_id == replaced_id,
            )
        )
        .scalars()
        .all()
    }
    restored = 0
    for snapshot in snapshots:
        client_id = str(snapshot.get("client_id") or "")
        if client_id and client_id in existing_client_ids:
            continue
        db.add(_restore_food_log(db, user_id, snapshot))
        restored += 1
    old = db.get(CoachActionRecord, replaced_id)
    if old is not None and old.user_id == user_id:
        old.status = "executed"
        old.undone_at = None
    db.flush()
    return {
        **result,
        "replaced_action_id": replaced_id,
        "restored_previous": restored,
    }


def confirm_pending(db: Session, user_id: str, pending_id: str) -> dict:
    session, pending = _load_pending(db, user_id, pending_id)
    if pending.status != "pending" or pending.kind not in {"card", "proposal"}:
        raise ValueError("这个操作已经处理或不是待确认卡片")
    action_id = pending.action_id or str(uuid4())

    existing = db.execute(
        select(CoachActionRecord).where(
            CoachActionRecord.user_id == user_id,
            CoachActionRecord.idempotency_key == action_id,
        )
    ).scalar_one_or_none()
    if existing is not None and existing.status == "executed":
        return {
            "action_id": existing.id,
            "status": existing.status,
            "receipt": existing.receipt or {},
            "refresh_domains": list(
                CAPABILITIES[existing.capability_id].refreshes
                if existing.capability_id in CAPABILITIES
                else (existing.receipt or {}).get("refresh_domains", [])
            ),
            "idempotent": True,
        }
    if existing is not None and existing.status == "undone":
        raise ValueError("这次操作已经撤销，请重新生成")

    if pending.capability_id == BATCH:
        return _confirm_batch(db, user_id, session, pending, action_id)

    receipt: dict
    before: dict = {}
    after: dict = {}
    if pending.capability_id in {PLAN, ADJUST_PLAN, CONFIGURE_PLAN}:
        from .capabilities.plan import activate as activate_plan

        result = activate_plan(
            db,
            user_id,
            str(pending.payload.get("program_id") or ""),
        )
        if pending.capability_id == CONFIGURE_PLAN:
            profile_after = pending.payload.get("profile_after") or {}
            profile = db.get(Profile, user_id)
            if profile is not None and isinstance(profile_after, dict):
                for field in ("weekly_days", "session_minutes"):
                    if field in profile_after:
                        setattr(profile, field, profile_after[field])
                db.flush()
        after = result.get("plan") or {}
        before = {
            "previous_program_id": result.get("previous_program_id"),
            "program_id": result.get("program_id"),
            "profile_before": pending.payload.get("profile_before") or {},
        }
        receipt = {
            "summary": f"已激活计划「{after.get('title') or '训练计划'}」",
            "plan_id": result.get("program_id"),
            "deep_link": "fitai://plan",
        }
        event_type = (
            "TrainingPlanGenerated"
            if pending.capability_id == PLAN
            else "TrainingPlanAdjusted"
        )
        entity_type = "program"
        entity_id = str(result.get("program_id") or "")
    elif pending.capability_id == RESTORE_PLAN:
        from .capabilities.plan import activate as activate_plan

        result = activate_plan(
            db,
            user_id,
            str(pending.payload.get("program_id") or ""),
        )
        after = result.get("plan") or {}
        before = {
            "previous_program_id": result.get("previous_program_id"),
            "program_id": result.get("program_id"),
        }
        receipt = {
            "summary": f"已恢复计划「{after.get('title') or '训练计划'}」",
            "plan_id": result.get("program_id"),
            "deep_link": "fitai://plan",
        }
        event_type = "TrainingPlanRestored"
        entity_type = "program"
        entity_id = str(result.get("program_id") or "")
    elif pending.capability_id == DIET:
        from .capabilities.diet import execute as execute_diet

        replace_action_id = str(
            pending.payload.get("replace_action_id") or ""
        ).strip()
        if replace_action_id:
            previous_logs = _replace_previous_coach_action(
                db, user_id, replace_action_id
            )
            before = {
                "replaced_action_id": replace_action_id,
                "previous_logs": previous_logs,
            }
        result = execute_diet(db, user_id, action_id, pending.payload)
        receipt = {
            "summary": (
                "已替换上一条饮食记录"
                if replace_action_id
                else "已写入饮食记录"
            ),
            "date": pending.payload.get("date"),
            "meal": pending.payload.get("meal"),
            "items": len(result.get("created_logs") or []),
            "deep_link": f"fitai://nutrition/{pending.payload.get('date')}",
        }
        if replace_action_id:
            receipt["replaced_action_id"] = replace_action_id
        after = {"created_logs": result.get("created_logs") or []}
        event_type = "FoodLogged"
        entity_type = "food_log"
        entity_id = action_id
    elif pending.capability_id in {DIET_UPDATE, DIET_DELETE}:
        from .capabilities import log_edit

        if pending.capability_id == DIET_UPDATE:
            result = log_edit.execute_update_food(
                db, user_id, action_id, pending.payload
            )
            summary = "已修改饮食记录"
            event_type = "FoodLogUpdated"
        else:
            result = log_edit.execute_delete_food(
                db, user_id, action_id, pending.payload
            )
            summary = "已删除饮食记录"
            event_type = "FoodLogDeleted"
        after = result
        db.add(
            AgentActionEvent(
                user_id=user_id,
                action_id=action_id,
                action_type=pending.capability_id,
                status="executed",
                detail={"result": result},
            )
        )
        db.flush()
        receipt = {
            "summary": summary,
            "client_id": pending.payload.get("client_id"),
            "date": pending.payload.get("date"),
            "meal": pending.payload.get("meal"),
            "deep_link": (
                f"fitai://nutrition/{pending.payload.get('date')}"
                if pending.payload.get("date")
                else "fitai://nutrition"
            ),
        }
        entity_type = "food_log"
        entity_id = action_id
    elif pending.capability_id in {UPDATE_WORKOUT, DELETE_WORKOUT}:
        from .capabilities import log_edit

        if pending.capability_id == UPDATE_WORKOUT:
            result = log_edit.execute_update_workout(
                db, user_id, action_id, pending.payload
            )
            summary = "已修改训练记录"
            event_type = "WorkoutUpdated"
        else:
            result = log_edit.execute_delete_workout(
                db, user_id, action_id, pending.payload
            )
            summary = "已删除训练记录"
            event_type = "WorkoutDeleted"
        after = result
        db.add(
            AgentActionEvent(
                user_id=user_id,
                action_id=action_id,
                action_type=pending.capability_id,
                status="executed",
                detail={"result": result},
            )
        )
        db.flush()
        receipt = {
            "summary": summary,
            "session_id": pending.payload.get("session_id"),
            "deep_link": "fitai://workout_history",
        }
        entity_type = "workout"
        entity_id = str(pending.payload.get("session_id") or action_id)
    elif pending.capability_id in {
        START_TRAINING_UI,
        OPEN_SCREEN_UI,
        REMINDERS_UI,
    }:
        from .capabilities.ui_actions import execute_ui

        result = execute_ui(db, user_id, action_id, pending.payload)
        after = result
        if pending.capability_id == START_TRAINING_UI:
            summary = f"已准备开始「{pending.payload.get('title') or '训练'}」"
        elif pending.capability_id == OPEN_SCREEN_UI:
            summary = f"已准备打开「{pending.payload.get('title') or '页面'}」"
        else:
            summary = (
                "训练提醒已关闭。"
                if pending.payload.get("enabled") is False
                else (
                    "训练提醒已设为 "
                    f"{int(pending.payload.get('hour') or 0):02d}:"
                    f"{int(pending.payload.get('minute') or 0):02d}。"
                )
            )
        receipt = {
            "summary": summary,
            "day_id": pending.payload.get("day_id"),
            "screen": pending.payload.get("screen"),
            "enabled": pending.payload.get("enabled"),
            "hour": pending.payload.get("hour"),
            "minute": pending.payload.get("minute"),
            "deep_link": (
                "fitai://workout"
                if pending.capability_id == START_TRAINING_UI
                else (
                    f"fitai://screen/{pending.payload.get('screen') or 'today'}"
                    if pending.capability_id == OPEN_SCREEN_UI
                    else "fitai://settings"
                )
            ),
        }
        event_type = "UIActionRequested"
        entity_type = "coach_action"
        entity_id = action_id
    elif pending.capability_id == MEMORY:
        from .capabilities.memory import execute as execute_memory

        result = execute_memory(db, user_id, action_id, pending.payload)
        after = result
        receipt = {
            "summary": f"已记住：{str(result.get('content') or '')[:80]}",
            "deep_link": "fitai://profile",
        }
        event_type = "MemoryRemembered"
        entity_type = "memory"
        entity_id = str(result.get("memory_id") or action_id)
    elif pending.capability_id == TRAINING:
        from .capabilities.training import execute as execute_training

        result = execute_training(db, user_id, action_id, pending.payload)
        before = result.get("before") or {}
        after = result.get("after") or {}
        receipt = {
            "summary": "已调整训练日期",
            **result.get("receipt", {}),
            "plan_id": pending.payload.get("plan_id"),
            "day_id": pending.payload.get("day_id"),
            "deep_link": (
                f"fitai://plan/{pending.payload.get('plan_id')}"
                f"/day/{pending.payload.get('day_id')}"
            ),
        }
        event_type = "TrainingRescheduled"
        entity_type = "plan_day"
        entity_id = str(pending.payload.get("day_id") or "")
    elif pending.capability_id == GOAL:
        from .capabilities.profile import execute as execute_goal

        result = execute_goal(db, user_id, action_id, pending.payload)
        before = result.get("before") or {}
        after = result.get("after") or {}
        receipt = {
            "summary": "已更新目标",
            "deep_link": "fitai://profile",
        }
        event_type = "GoalUpdated"
        entity_type = "goal"
        entity_id = action_id
    elif pending.capability_id == SKIP_TRAINING:
        from .capabilities.training import execute_skip as execute_skip_training

        result = execute_skip_training(db, user_id, action_id, pending.payload)
        before = result.get("before") or {}
        after = result.get("after") or {}
        receipt = {
            "summary": f"已跳过 {pending.payload.get('date')} 的训练",
            "date": pending.payload.get("date"),
            "deep_link": (
                f"fitai://plan/{pending.payload.get('plan_id')}"
                f"/day/{pending.payload.get('day_id')}"
            ),
        }
        event_type = "TrainingSkipped"
        entity_type = "plan_day"
        entity_id = str(pending.payload.get("day_id") or "")
    elif pending.capability_id == STRENGTH:
        from .capabilities.training import execute_strength

        result = execute_strength(db, user_id, action_id, pending.payload)
        after = result
        receipt = {
            "summary": (
                f"已记录{pending.payload.get('title')} "
                f"{len(pending.payload.get('sets') or [])} 组"
            ),
            "date": pending.payload.get("date"),
            "deep_link": "fitai://workout_history",
        }
        event_type = "WorkoutLogged"
        entity_type = "workout"
        entity_id = action_id
    elif pending.capability_id == CARDIO:
        from .capabilities.training import execute_cardio

        result = execute_cardio(db, user_id, action_id, pending.payload)
        after = result
        receipt = {
            "summary": (
                f"已记录{pending.payload.get('title')} "
                f"{pending.payload.get('duration_minutes')} 分钟"
            ),
            "date": pending.payload.get("date"),
            "deep_link": "fitai://workout_history",
        }
        event_type = "WorkoutLogged"
        entity_type = "workout"
        entity_id = action_id
    elif pending.capability_id == WEIGHT:
        from .capabilities.body import execute as execute_weight

        result = execute_weight(db, user_id, action_id, pending.payload)
        after = result
        receipt = {
            "summary": f"已记录{'、'.join(_body_metric_parts(pending.payload))}",
            "capability_id": WEIGHT,
            "client_id": action_id,
            "date": pending.payload.get("date"),
            "weight_kg": pending.payload.get("weight_kg"),
            "body_fat_pct": pending.payload.get("body_fat_pct"),
            "waist_cm": pending.payload.get("waist_cm"),
            "arm_cm": pending.payload.get("arm_cm"),
            "thigh_cm": pending.payload.get("thigh_cm"),
            "deep_link": "fitai://profile",
        }
        event_type = "BodyMetricLogged"
        entity_type = "body_metric"
        entity_id = action_id
    elif pending.capability_id == DELETE_METRIC:
        from .capabilities.body import execute_delete

        result = execute_delete(db, user_id, action_id, pending.payload)
        before = result.get("before") or {}
        after = {
            key: value
            for key, value in result.items()
            if key != "before"
        }
        receipt = {
            "summary": (
                pending.payload.get("summary") or "已删除身体记录"
            ),
            "date": pending.payload.get("date"),
            "metric_id": pending.payload.get("metric_id"),
            "deep_link": "fitai://body",
        }
        event_type = "BodyMetricDeleted"
        entity_type = "body_metric"
        entity_id = str(pending.payload.get("metric_id") or "")
    elif pending.capability_id == DIET_DAY_STRATEGY:
        from .capabilities.diet_day_strategy import (
            execute as execute_day_strategy,
        )

        result = execute_day_strategy(db, user_id, action_id, pending.payload)
        before = result.get("before") or {}
        receipt = {
            "summary": (
                f"已保存 {pending.payload.get('date')} 的"
                f"「{pending.payload.get('strategy')}」餐单"
            ),
            "capability_id": DIET_DAY_STRATEGY,
            "date": pending.payload.get("date"),
            "target_kcal": result.get("target_kcal"),
            "deep_link": "fitai://nutrition",
        }
        event_type = "DietPlanGenerated"
        entity_type = "meal_plan"
        entity_id = str(pending.payload.get("date") or "")
    elif pending.capability_id == DIET_WEEK:
        from .capabilities.diet_week import execute as execute_diet_week

        result = execute_diet_week(db, user_id, action_id, pending.payload)
        before = result.get("before") or {}
        receipt = {
            "summary": (
                f"已保存 {pending.payload.get('week_start')} 起一周饮食计划"
            ),
            "capability_id": DIET_WEEK,
            "date": pending.payload.get("week_start"),
            "deep_link": "fitai://nutrition",
        }
        event_type = "DietPlanGenerated"
        entity_type = "meal_plan"
        entity_id = str(pending.payload.get("week_start") or "")
    elif pending.capability_id == DIET_PLAN:
        from .capabilities.diet_plan import execute as execute_diet_plan

        result = execute_diet_plan(db, user_id, action_id, pending.payload)
        before = result.get("before") or {}
        receipt = {
            "summary": f"已保存 {pending.payload.get('date')} 饮食计划",
            "capability_id": DIET_PLAN,
            "date": pending.payload.get("date"),
            "target_kcal": result.get("target_kcal"),
            "deep_link": "fitai://nutrition",
        }
        event_type = "DietPlanGenerated"
        entity_type = "meal_plan"
        entity_id = str(pending.payload.get("date") or "")
    elif pending.capability_id == ADD_DAY:
        from .capabilities.training_add_day import execute as execute_add_day

        result = execute_add_day(db, user_id, action_id, pending.payload)
        after = result.get("plan") or {}
        before = result.get("before") or {}
        receipt = {
            "summary": (
                f"已增加 {pending.payload.get('date')} 的"
                f"「{pending.payload.get('title')}」训练"
            ),
            "plan_id": pending.payload.get("plan_id"),
            "day_id": result.get("day_id"),
            "deep_link": "fitai://plan",
        }
        event_type = "TrainingPlanAdjusted"
        entity_type = "program"
        entity_id = str(pending.payload.get("plan_id") or "")
    elif pending.capability_id in {EDIT_EXERCISES, EDIT_EXERCISE}:
        from .capabilities.training_edit import (
            execute as execute_exercise_edit,
        )

        result = execute_exercise_edit(db, user_id, action_id, pending.payload)
        after = result.get("plan") or {}
        before = result.get("before") or {}
        receipt = {
            "summary": f"已更新「{pending.payload.get('title')}」的动作",
            "plan_id": pending.payload.get("plan_id"),
            "day_id": pending.payload.get("day_id"),
            "deep_link": "fitai://plan",
        }
        event_type = "TrainingPlanAdjusted"
        entity_type = "program"
        entity_id = str(pending.payload.get("plan_id") or "")
    elif pending.capability_id in {PLANNED, SKIP_MEAL, RESTORE_MEAL, SWAP_MEAL}:
        from .capabilities import diet as diet_capability

        if pending.capability_id == SWAP_MEAL:
            result = diet_capability.execute_swap(
                db, user_id, action_id, pending.payload
            )
            summary = "已换一餐"
            event_type = "DietMealSwapped"
        elif pending.capability_id == PLANNED:
            result = diet_capability.execute_planned(
                db, user_id, action_id, pending.payload
            )
            summary = "已记录计划餐"
            event_type = "PlannedMealLogged"
        elif pending.capability_id == SKIP_MEAL:
            result = diet_capability.execute_skip(
                db, user_id, action_id, pending.payload
            )
            summary = "已跳过计划餐"
            event_type = "PlannedMealSkipped"
        else:
            result = diet_capability.execute_restore(
                db, user_id, action_id, pending.payload
            )
            summary = "已恢复计划餐"
            event_type = "PlannedMealRestored"
        after = result
        receipt = {
            "summary": summary,
            "date": pending.payload.get("date"),
            "meal": pending.payload.get("meal"),
            "deep_link": f"fitai://nutrition/{pending.payload.get('date')}",
        }
        entity_type = "meal_plan"
        entity_id = action_id
    else:
        raise ValueError("暂不支持这个能力")

    receipt.setdefault("capability_id", pending.capability_id)
    receipt.setdefault("action_id", action_id)
    record = CoachActionRecord(
        id=action_id,
        user_id=user_id,
        session_id=session.id,
        capability_id=pending.capability_id,
        status="executed",
        payload=pending.payload,
        before=before,
        after=after,
        receipt=receipt,
        undo_token=action_id,
        idempotency_key=action_id,
        executed_at=utcnow(),
    )
    db.add(record)
    event = emit_event(
        db,
        user_id,
        event_type,
        entity_type=entity_type,
        entity_id=entity_id,
        payload={"action_id": action_id, "receipt": receipt},
    )
    consume_event(db, event)
    consume_pending(db, session, pending)
    db.commit()
    return {
        "action_id": action_id,
        "status": "executed",
        "receipt": receipt,
        "plan": after
        if pending.capability_id in {
            PLAN,
            ADJUST_PLAN,
            CONFIGURE_PLAN,
            EDIT_EXERCISES,
            EDIT_EXERCISE,
            ADD_DAY,
        }
        else None,
        "refresh_domains": list(
            CAPABILITIES[pending.capability_id].refreshes
            if pending.capability_id in CAPABILITIES
            else ()
        ),
        "idempotent": False,
    }


def cancel(db: Session, user_id: str, pending_id: str) -> dict:
    session, pending = _load_pending(db, user_id, pending_id)
    if pending.status != "pending":
        return {"ok": True, "already": True}
    _discard_pending_resource(db, user_id, pending)
    cancel_pending(db, session, pending)
    db.commit()
    return {"ok": True, "pending_id": pending_id}


def undo_action(db: Session, user_id: str, action_id: str) -> dict:
    record = db.execute(
        select(CoachActionRecord).where(
            CoachActionRecord.id == action_id,
            CoachActionRecord.user_id == user_id,
        )
    ).scalar_one_or_none()
    if record is None or record.status != "executed":
        raise LookupError("这个操作已经不能撤销")
    if record.capability_id == BATCH:
        sub_ids = [
            str(value)
            for value in (record.before or {}).get("sub_action_ids") or []
            if str(value).strip()
        ]
        undone: list[dict] = []
        for sub_id in sub_ids:
            try:
                undone.append(undo_action(db, user_id, sub_id))
            except Exception:  # noqa: BLE001 - undo the rest of the batch
                continue
        record.status = "undone"
        record.undone_at = utcnow()
        db.commit()
        domains = sorted(
            {
                domain
                for item in undone
                for domain in item.get("refresh_domains") or []
            }
        )
        return {
            "restored": True,
            "undone": undone,
            "refresh_domains": domains,
        }

    if record.capability_id == DIET:
        replaced_id = str(
            (record.before or {}).get("replaced_action_id") or ""
        ).strip()
        if replaced_id:
            result = _undo_diet_replacement(
                db, user_id, record, replaced_id
            )
        else:
            from .capabilities.diet import undo as undo_diet

            result = undo_diet(db, user_id, action_id, record.payload)
    elif record.capability_id in {DIET_UPDATE, DIET_DELETE}:
        from .capabilities import log_edit

        if record.capability_id == DIET_UPDATE:
            result = log_edit.undo_update_food(
                db, user_id, action_id, record.payload
            )
        else:
            result = log_edit.undo_delete_food(
                db, user_id, action_id, record.payload
            )
    elif record.capability_id in {UPDATE_WORKOUT, DELETE_WORKOUT}:
        from .capabilities import log_edit

        if record.capability_id == UPDATE_WORKOUT:
            result = log_edit.undo_update_workout(
                db, user_id, action_id, record.payload
            )
        else:
            result = log_edit.undo_delete_workout(
                db, user_id, action_id, record.payload
            )
    elif record.capability_id == MEMORY:
        from .capabilities.memory import undo as undo_memory

        result = undo_memory(db, user_id, action_id, record.payload)
    elif record.capability_id == TRAINING:
        from .capabilities.training import undo as undo_training

        result = undo_training(
            db,
            user_id,
            action_id,
            record.payload,
            record.before or {},
        )
    elif record.capability_id in {
        PLAN,
        ADJUST_PLAN,
        CONFIGURE_PLAN,
        RESTORE_PLAN,
    }:
        from .capabilities.plan import undo_activate

        result = undo_activate(
            db,
            user_id,
            str(record.payload.get("program_id") or ""),
            (record.before or {}).get("previous_program_id"),
        )
        profile_before = (record.before or {}).get("profile_before") or {}
        if isinstance(profile_before, dict) and profile_before:
            profile = db.get(Profile, user_id)
            if profile is not None:
                for field in ("weekly_days", "session_minutes"):
                    if field in profile_before:
                        setattr(profile, field, profile_before[field])
                db.flush()
    elif record.capability_id == GOAL:
        from .capabilities.profile import undo as undo_goal

        result = undo_goal(
            db,
            user_id,
            action_id,
            record.payload,
            record.before or {},
        )
    elif record.capability_id == SKIP_TRAINING:
        from .capabilities.training import undo_skip as undo_skip_training

        result = undo_skip_training(
            db,
            user_id,
            action_id,
            record.payload,
            record.before or {},
        )
    elif record.capability_id == STRENGTH:
        from .capabilities.training import undo_strength

        result = undo_strength(db, user_id, action_id, record.payload)
    elif record.capability_id == CARDIO:
        from .capabilities.training import undo_cardio

        result = undo_cardio(db, user_id, action_id, record.payload)
    elif record.capability_id == WEIGHT:
        from .capabilities.body import undo as undo_weight

        result = undo_weight(db, user_id, action_id, record.payload)
    elif record.capability_id == DELETE_METRIC:
        from .capabilities.body import undo_delete

        result = undo_delete(
            db,
            user_id,
            record.before or {},
            record.payload,
        )
    elif record.capability_id == DIET_DAY_STRATEGY:
        from .capabilities.diet_day_strategy import (
            undo as undo_day_strategy,
        )

        result = undo_day_strategy(
            db,
            user_id,
            record.before or {},
            record.payload,
        )
    elif record.capability_id == DIET_WEEK:
        from .capabilities.diet_week import undo as undo_diet_week

        result = undo_diet_week(db, user_id, record.before or {}, record.payload)
    elif record.capability_id == DIET_PLAN:
        from .capabilities.diet_plan import undo as undo_diet_plan

        result = undo_diet_plan(db, user_id, record.before or {}, record.payload)
    elif record.capability_id in {EDIT_EXERCISES, EDIT_EXERCISE}:
        from .capabilities.training_edit import undo as undo_exercise_edit

        result = undo_exercise_edit(
            db,
            user_id,
            record.before or {},
            record.payload,
        )
    elif record.capability_id == ADD_DAY:
        from .capabilities.training_add_day import undo as undo_add_day

        result = undo_add_day(db, user_id, record.before or {}, record.payload)
    elif record.capability_id == PLANNED:
        from .capabilities.diet import undo_planned

        result = undo_planned(db, user_id, action_id, record.payload)
    elif record.capability_id == SKIP_MEAL:
        from .capabilities.diet import undo_skip

        result = undo_skip(db, user_id, action_id, record.payload)
    elif record.capability_id == RESTORE_MEAL:
        from .capabilities.diet import undo_restore

        result = undo_restore(db, user_id, action_id, record.payload)
    elif record.capability_id == SWAP_MEAL:
        from .capabilities.diet import undo_swap

        result = undo_swap(db, user_id, action_id, record.payload)
    else:
        raise ValueError("暂不支持撤销这个能力")
    record.status = "undone"
    record.undone_at = utcnow()
    emit_event(
        db,
        user_id,
        "ActionUndone",
        entity_type="coach_action",
        entity_id=action_id,
        payload={"capability_id": record.capability_id},
    )
    db.commit()
    return {
        "action_id": action_id,
        "status": "undone",
        "result": result,
        "refresh_domains": list(
            CAPABILITIES[record.capability_id].refreshes
            if record.capability_id in CAPABILITIES
            else ()
        ),
    }


def session_state(db: Session, user_id: str, session_id: str) -> dict:
    session = db.get(CoachSession, session_id)
    if session is None or session.user_id != user_id:
        raise LookupError("会话不存在")
    pending = get_active_pending(db, user_id, session.id)
    return serialize_session(session, pending)
