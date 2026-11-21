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

from sqlalchemy import and_, func, or_, select
from sqlalchemy.orm import Session

from ..config import settings
from ..models import (
    AgentPlanProposal,
    AgentRun,
    AgentStep,
    AIMemory,
    ChatMessage,
    Exercise,
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
from .action_drafts import (
    answer_food_draft,
    cancel_active_draft,
    compact_draft,
    create_food_draft,
    draft_context,
    get_active_draft,
    needs_raw_clarification,
)
from .citations import build_reply_citations
from .coach_actions.schemas import (
    DeleteFoodLogPayload,
    DeleteWorkoutPayload,
    LogFoodPayload,
    LogPlannedMealPayload,
    LogWorkoutPayload,
    SkipPlannedMealPayload,
    UpdateFoodLogPayload,
    UpdateWorkoutPayload,
)
from .coach_context import build_coach_context, recent_training
from .coach_core import coach_core_prompt
from .diet_review import build_diet_review, utc_window
from .equipment import available_equipment_types
from .food_text import (
    food_log_context,
    parse_amount_grams,
    parse_food_date,
    parse_meal,
    resolve_food_text,
)
from .memory import (
    is_pending_action_fact,
    remember_facts,
    schedule_memory_extraction,
)
from .plan_generator import build_template_plan, validate_plan_for_user
from .plan_validator import PlanValidationError, injury_tags
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

MAX_STEPS = 10
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
    "skip_planned_meal",
    "restore_planned_meal",
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
    # Body metrics share "记一下" but must not be forced into the food tool set.
    if re.search(r"体重|体脂|腰围|身体数据", text):
        return False
    if _forced_workout_log_intent(text):
        return False
    # "今天训练改到明天，再记..." mixes a schedule change with food. Do not
    # let the food fast path inherit 明天 from the training clause.
    if re.search(r"改到|改期|顺延到|挪到|换到|调到", text):
        return False
    if re.search(
        r"帮我记|记一下|记录一下|补记|帮我记录|记饮食|记录饮食|"
        r"吃了.{0,40}(记|记录)|喝了.{0,40}(记|记录)",
        text,
    ):
        return True
    # In an active food-logging conversation a short "食物 + 份量" message is
    # already a complete log intent ("100 克玉米肉肠"). Do not require the
    # user to repeat "帮我记".
    if len(text) > 30 or re.search(
        r"多少|热量|卡路里|几|吗|？|\?|怎么|能不能|可以吗", text
    ):
        return False
    return bool(
        re.search(
            r"\d+(?:\.\d+)?\s*(g|克|ml|毫升|杯|份|碗|个|片|勺|盒|瓶)|"
            r"(半|一|两|二|三)\s*(杯|份|碗|个|片|勺)",
            text,
            flags=re.IGNORECASE,
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


def _is_draft_answer(message: str) -> bool:
    text = message.strip()
    if not text or _forced_workout_log_intent(text):
        return False
    if re.search(r"取消|不要了|算了|不记了", text):
        return True
    if re.fullmatch(r"(对|是|是的|可以|嗯|好|行|没错)[。.!！]?", text):
        return True
    if re.fullmatch(r"\d+(?:\.\d+)?", text):
        return True
    return bool(
        re.search(
            r"\d+(?:\.\d+)?\s*(ml|毫升|g|克)|"
            r"(半|一|两|二|三)\s*(杯|份|碗)",
            text,
            flags=re.IGNORECASE,
        )
    )


def _pending_action_correction(
    app_context: dict | None,
    message: str,
) -> dict | None:
    if not isinstance(app_context, dict):
        return None
    pending = app_context.get("pending_action")
    if not isinstance(pending, dict) or pending.get("type") != "log_food":
        return None
    payload = pending.get("payload")
    if not isinstance(payload, dict):
        return None
    items = payload.get("items")
    if not isinstance(items, list) or not items:
        return None
    if not re.search(r"记错|不是|改成|应该是|修正|改一下", message):
        grams = parse_amount_grams(message)
        if grams is None or len(message.strip()) > 20:
            return None
    else:
        grams = parse_amount_grams(message)
    if grams is None:
        return None

    target_index = None
    if len(items) == 1:
        target_index = 0
    else:
        for index, item in enumerate(items):
            name = str(item.get("name") or "")
            if name and name in message:
                target_index = index
                break
        if target_index is None:
            ordinals = {
                "第一": 0,
                "第1": 0,
                "第一个": 0,
                "第二": 1,
                "第2": 1,
                "第二个": 1,
                "第三": 2,
                "第3": 2,
                "第三个": 2,
            }
            for token, index in ordinals.items():
                if token in message and index < len(items):
                    target_index = index
                    break
    if target_index is None:
        names = "、".join(
            str(item.get("name") or "这一项") for item in items
        )
        return {
            "actions": [],
            "reply": f"这张卡里有 {names}，你是要把哪一项改成 {round(grams)}g？回复食物名或第几项。",
        }
    item = dict(items[target_index])
    old_grams = float(item.get("grams") or 0)
    if old_grams <= 0:
        return None
    factor = grams / old_grams
    item["grams"] = round(grams)
    item["portion"] = f"约{round(grams)}g"
    for key in ("kcal", "protein_g", "carbs_g", "fat_g"):
        if item.get(key) is not None:
            item[key] = round(float(item[key]) * factor, 1)
    updated_items = [dict(value) for value in items]
    updated_items[target_index] = item
    kcal = round(sum(float(value.get("kcal") or 0) for value in updated_items))
    raw = {
        "type": "log_food",
        "title": "修正饮食记录",
        "summary": f"约 {kcal} kcal",
        "requires_confirmation": True,
        "payload": {
            "date": payload.get("date")
            or datetime.now(REVIEW_TZ).date().isoformat(),
            "meal": payload.get("meal") or "lunch",
            "items": updated_items,
        },
    }
    return {
        "actions": _normalize_app_actions([raw]),
        "reply": "改好了，确认后按新的份量写入。",
    }


def _has_new_food_name(text: str) -> bool:
    cleaned = re.sub(
        r"\d+(?:\.\d+)?\s*(g|克|ml|毫升|杯|份|碗|个|片|勺|盒|瓶)|"
        r"(半|一|两|二|三|四|五|六|七|八|九|十)\s*"
        r"(g|克|ml|毫升|杯|份|碗|个|片|勺|盒|瓶)",
        "",
        text,
        flags=re.IGNORECASE,
    )
    cleaned = re.sub(
        r"记错|不是|改成|换成|改为|应该是|修正|改一下|了|是|的|我|你",
        "",
        cleaned,
    )
    return bool(re.search(r"[\u4e00-\u9fff]{2,}", cleaned))


async def _pending_food_replacement(
    db: Session,
    user_id: str,
    app_context: dict | None,
    message: str,
) -> dict | None:
    """Replace one food in a pending log card when the user corrects its name.

    Amount-only corrections stay on the deterministic fast path; this helper
    handles "不是玉米肉肠，是玉米鸡肉肠 100 克" and the single-item
    "玉米鸡肉肠 100 克" case without forcing the model to invent macros.
    """

    if not isinstance(app_context, dict):
        return None
    pending = app_context.get("pending_action")
    if not isinstance(pending, dict) or pending.get("type") != "log_food":
        return None
    payload = pending.get("payload")
    if not isinstance(payload, dict):
        return None
    items = payload.get("items")
    if not isinstance(items, list) or not items:
        return None

    target: int | None = None
    new_text: str | None = None
    for pattern in (
        re.compile(
            r"不是\s*(?P<old>[^，,。]+?)\s*[，,]\s*是\s*(?P<new>[^，,。]+)"
        ),
        re.compile(
            r"把?\s*(?P<old>[^，,。]+?)\s*(?:改成|换成|改为)\s*(?P<new>[^，,。]+)"
        ),
    ):
        match = pattern.search(message)
        if match is None:
            continue
        old = match.group("old").strip()
        for index, item in enumerate(items):
            name = str(item.get("name") or "") if isinstance(item, dict) else ""
            if old and name and (old in name or name in old):
                target = index
                new_text = match.group("new").strip()
                break
        if target is not None:
            break

    if (
        target is None
        and len(items) == 1
        and _has_new_food_name(message)
        and _forced_food_log_intent(message)
        and not re.search(
            r"记错|不是|改成|换成|改为|应该是|修正|"
            r"再|添加|加一个|另外|还有|记一下|帮我记|记录|补记",
            message,
        )
    ):
        target = 0
        new_text = message.strip()

    if target is None or not new_text:
        return None
    # "米饭改成250g" is a portion correction, not a replacement with a food
    # named "250g". Let the deterministic amount-only path handle it.
    if not _has_new_food_name(new_text):
        return None

    try:
        target_date = date.fromisoformat(str(payload.get("date") or ""))
    except ValueError:
        target_date = datetime.now(REVIEW_TZ).date()
    meal = str(payload.get("meal") or "lunch")
    if meal not in {"breakfast", "lunch", "dinner", "snack"}:
        meal = "lunch"

    resolution = await resolve_food_text(
        db,
        user_id,
        new_text,
        meal=meal,
        target_date=target_date,
        prefer_llm=True,
    )
    resolved_items = resolution.get("items") or []
    if resolution.get("questions") or not resolved_items:
        return {
            "actions": [],
            "reply": _food_question_message(resolution),
        }
    if len(resolved_items) != 1:
        return {
            "actions": [],
            "reply": "我解析出了多种食物，能只告诉我替换后的那一种吗？",
        }

    updated_items = [dict(item) for item in items]
    updated_items[target] = dict(resolved_items[0])
    kcal = round(
        sum(
            float(item.get("kcal") or 0)
            for item in updated_items
            if isinstance(item, dict)
        )
    )
    raw = {
        "type": "log_food",
        "title": "修正饮食记录",
        "summary": f"约 {kcal} kcal",
        "requires_confirmation": True,
        "payload": {
            "date": target_date.isoformat(),
            "meal": meal,
            "raw_text": (
                str(payload.get("raw_text") or "") + "；" + message
            )[:500],
            "items": updated_items,
        },
    }
    return {
        "actions": _normalize_app_actions([raw]),
        "reply": "改好了，确认后按修正后的食物和份量写入。",
    }


def _looks_like_food_clause(clause: str) -> bool:
    if re.search(r"体重|体脂|腰围|身体数据|目标|器械|计划", clause):
        return False
    if _forced_food_log_intent(clause):
        return True
    return bool(
        re.search(
            r"吃了|喝了|米饭|鸡|牛|鱼|虾|蛋|奶|面|菜|果|豆|薯|饼|粥|汤|"
            r"咖啡|茶|酒|水|汁|粉|包|饺|麦|肉|肠|餐",
            clause,
        )
    )


def _body_metric_payload(clause: str) -> dict | None:
    weight_match = re.search(
        r"(?:体重|称重)[^\d]{0,12}(\d{2,3}(?:\.\d+)?)\s*(公斤|kg|斤)?",
        clause,
        flags=re.IGNORECASE,
    )
    if weight_match is None:
        weight_match = re.search(
            r"(\d{2,3}(?:\.\d+)?)\s*(公斤|kg|斤)",
            clause,
            flags=re.IGNORECASE,
        )
    payload: dict = {}
    if weight_match is not None:
        value = float(weight_match.group(1))
        if (weight_match.group(2) or "").lower() == "斤":
            value /= 2
        if 25 <= value <= 300:
            payload["weight_kg"] = round(value, 1)
    fat_match = re.search(
        r"(?:体脂率?|体脂)[^\d]{0,8}(\d{1,2}(?:\.\d+)?)\s*%?",
        clause,
    )
    if fat_match is not None:
        value = float(fat_match.group(1))
        if 3 <= value <= 60:
            payload["body_fat_pct"] = round(value, 1)
    waist_match = re.search(
        r"(?:腰围)[^\d]{0,8}(\d{2,3}(?:\.\d+)?)\s*(cm|厘米)?",
        clause,
        flags=re.IGNORECASE,
    )
    if waist_match is not None:
        value = float(waist_match.group(1))
        if 30 <= value <= 200:
            payload["waist_cm"] = round(value, 1)
    return payload or None


def _looks_like_body_metric_clause(clause: str) -> bool:
    return bool(
        re.search(r"体重|体脂|腰围|称重", clause)
        and _body_metric_payload(clause)
    )


async def _food_action_for_clause(
    db: Session,
    user_id: str,
    clause: str,
    app_context: dict | None,
) -> tuple[dict | None, str | None]:
    pending = (
        app_context.get("pending_action")
        if isinstance(app_context, dict)
        else None
    )
    if (
        isinstance(pending, dict)
        and pending.get("type") == "log_food"
        and not re.search(r"再记|另外|还有|加一个|新记|补记", clause)
    ):
        try:
            correction = _pending_action_correction(app_context, clause)
        except Exception:
            correction = None
        if correction is not None:
            actions = correction.get("actions") or []
            if actions:
                return actions[0], None
            return None, str(correction.get("reply") or "需要确认改哪一项。")
    if re.search(r"改成|换成|改为|修正", clause):
        return (
            None,
            "你是想修改已经记录的这一餐，还是新记一笔？"
            "如果要修改，请在饮食记录里点对应食物；要新记，请说“新记 200g 米饭”。",
        )
    context = food_log_context(clause)
    resolution = await resolve_food_text(
        db,
        user_id,
        clause,
        meal=context["meal"],
        target_date=date.fromisoformat(context["date"]),
    )
    if (
        resolution.get("questions")
        or resolution.get("missing_slots")
        or not resolution.get("items")
    ):
        return None, _food_question_message(resolution)
    return (
        _build_food_log_action(
            resolution,
            clause,
            context["date"],
            context["meal"],
        ),
        None,
    )


async def _food_body_multi_intent_turn(
    db: Session,
    user_id: str,
    clauses: list[str],
    app_context: dict | None,
) -> dict | None:
    body_clauses = [
        clause for clause in clauses if _looks_like_body_metric_clause(clause)
    ]
    if not body_clauses:
        return None
    payload: dict = {}
    for clause in body_clauses:
        parsed = _body_metric_payload(clause)
        if parsed is None:
            continue
        for key, value in parsed.items():
            if key in payload and payload[key] != value:
                return {
                    "actions": [],
                    "reply": "这条消息里有多个不一致的身体数据，先告诉我这次以哪个为准。",
                }
            payload[key] = value
    if not payload:
        return None
    body_target = _body_target_date(body_clauses[0])

    food_clauses = [
        clause
        for clause in clauses
        if clause not in body_clauses and _looks_like_food_clause(clause)
    ]
    other_clauses = [
        clause
        for clause in clauses
        if clause not in body_clauses and clause not in food_clauses
    ]
    if not food_clauses:
        if other_clauses:
            return None
        metric_action = _build_body_metric_action(payload, body_target)
        if metric_action is None:
            return {
                "actions": [],
                "reply": "这组身体数据超出可记录范围，请检查后再发。",
            }
        return {
            "actions": [metric_action],
            "reply": (
                f"身体数据识别好了：{_body_metric_summary(payload)}。"
                f"确认后写入{_body_date_label(body_target)}身体数据。"
            ),
        }
    if other_clauses or len(food_clauses) != 1:
        return {
            "actions": [],
            "reply": (
                "这条消息里除了身体数据还有别的操作，先分开说会更稳："
                "这次只确认饮食和身体数据。"
            ),
        }
    food_action, question = await _food_action_for_clause(
        db,
        user_id,
        food_clauses[0],
        app_context,
    )
    if food_action is None:
        return {
            "actions": [],
            "reply": question or "饮食部分还需要确认，确认后一起写入。",
        }
    metric_action = _build_body_metric_action(payload, body_target)
    if metric_action is None:
        return {
            "actions": [],
            "reply": "这组身体数据超出可记录范围，请检查后再发。",
        }
    return {
        "actions": [food_action, metric_action],
        "reply": (
            f"饮食和身体数据都识别好了：{food_action.get('summary') or '饮食'}；"
            f"{_body_metric_summary(payload)}。确认后一起执行。"
        ),
    }


async def _body_reschedule_multi_intent_turn(
    db: Session,
    user_id: str,
    clauses: list[str],
    app_context: dict | None,
) -> dict | None:
    """Handle "log body metric + reschedule training" as one batch."""
    from .coach_control.runtime import _looks_like_reschedule

    body_clauses = [
        clause for clause in clauses if _looks_like_body_metric_clause(clause)
    ]
    training_clauses = [
        clause for clause in clauses if _looks_like_reschedule(clause)
    ]
    if len(body_clauses) != 1 or len(training_clauses) != 1:
        return None
    body_clause = body_clauses[0]
    training_clause = training_clauses[0]
    other_clauses = [
        clause
        for clause in clauses
        if clause not in body_clauses and clause not in training_clauses
    ]
    if other_clauses:
        return None
    metric_payload = _body_metric_payload(body_clause)
    if metric_payload is None:
        return None
    body_target = _body_target_date(body_clause)
    metric_action = _build_body_metric_action(metric_payload, body_target)
    if metric_action is None:
        return {
            "actions": [],
            "reply": "这组身体数据超出可记录范围，请检查后再发。",
        }

    from .coach_control.capabilities.training import (
        resolve as resolve_training,
    )

    resolution = resolve_training(
        db,
        user_id,
        training_clause,
        app_context,
    )
    if not resolution.get("ready"):
        questions = resolution.get("questions") or []
        question = (
            str(questions[0])
            if questions
            else "没有找到要改期的训练，请从训练手账里选一天。"
        )
        return {
            "actions": [],
            "reply": (
                f"{question} 身体数据我先不写入，等训练改期确认后一起处理。"
            ),
        }
    payload = resolution.get("payload") or {}
    training_action = None
    training_note = ""
    if resolution.get("already"):
        training_note = (
            f"训练本来就在 {payload.get('to_date')}，无需改期；"
        )
    else:
        from_date = str(payload.get("from_date") or "")
        to_date = str(payload.get("to_date") or "")
        title = str(payload.get("title") or "训练")
        training_action = _normalize_app_actions(
            [
                {
                    "type": "reschedule_training",
                    "title": "调整训练日期",
                    "summary": f"把 {from_date} 的「{title}」改到 {to_date}",
                    "requires_confirmation": True,
                    "payload": {
                        "day_id": payload.get("day_id"),
                        "date": from_date,
                        "target_date": to_date,
                    },
                }
            ],
            app_context,
        )[0]
        training_note = (
            f"把 {from_date} 的「{title}」改到 {to_date}，"
        )
    actions = (
        [training_action, metric_action]
        if training_action is not None
        else [metric_action]
    )
    return {
        "actions": actions,
        "reply": (
            f"{training_note}"
            f"身体数据按{_body_date_label(body_target)}记录："
            f"{_body_metric_summary(metric_payload)}。"
            "确认后一起执行。"
        ).strip(),
    }


def _build_body_metric_action(
    payload: dict,
    target_date: date | None = None,
) -> dict | None:
    date_label = ""
    if target_date is not None:
        payload["date"] = target_date.isoformat()
        today = datetime.now(REVIEW_TZ).date()
        if target_date != today:
            date_label = f"{target_date.month}月{target_date.day}日"
    title = "记录身体数据"
    if "weight_kg" in payload:
        title = f"记录{date_label}体重 {payload['weight_kg']:g}kg"
    elif "body_fat_pct" in payload:
        title = f"记录{date_label}体脂 {payload['body_fat_pct']:g}%"
    elif "waist_cm" in payload:
        title = f"记录{date_label}腰围 {payload['waist_cm']:g}cm"
    summary = (
        f"写入 {target_date.isoformat()} 身体数据"
        if target_date is not None
        else "写入今天身体数据"
    )
    try:
        return _normalize_app_actions(
            [
                {
                    "type": "log_body_metric",
                    "title": title,
                    "summary": summary,
                    "requires_confirmation": True,
                    "payload": payload,
                }
            ]
        )[0]
    except ValueError:
        return None


def _body_metric_summary(payload: dict) -> str:
    parts: list[str] = []
    if "weight_kg" in payload:
        parts.append(f"体重 {payload['weight_kg']:g}kg")
    if "body_fat_pct" in payload:
        parts.append(f"体脂 {payload['body_fat_pct']:g}%")
    if "waist_cm" in payload:
        parts.append(f"腰围 {payload['waist_cm']:g}cm")
    return "、".join(parts) or "身体数据"


_FOOD_CLAUSE_TOKENS = re.compile(
    r"吃了|喝了|米饭|鸡|牛|鱼|虾|蛋|奶|面|菜|果|豆|薯|饼|粥|汤|"
    r"咖啡|茶|酒|汁|粉|包|饺|麦|肉|肠|餐"
)
_BODY_QUESTION_TOKENS = re.compile(
    r"多少|正常|怎么样|如何|算胖|算瘦|胖吗|瘦吗|吗|？|\?"
)


def _body_target_date(clause: str) -> date:
    return parse_food_date(clause) or datetime.now(REVIEW_TZ).date()


def _body_date_label(target: date) -> str:
    today = datetime.now(REVIEW_TZ).date()
    if target == today:
        return "今天"
    return f"{target.month}月{target.day}日"


def _body_metric_action_turn(message: str) -> dict | None:
    """Deterministic body-metric card for explicit logging turns.

    "今天体重72kg" used to work only when the model chose the right tool;
    "记一下今天体重72kg" was even forced into the food tool set and produced
    no card. Parse body metrics before the model path instead.
    """
    if not _looks_like_body_metric_clause(message):
        return None
    if _FOOD_CLAUSE_TOKENS.search(message):
        return None
    if re.search(
        r"改到|改期|顺延|挪到|换到|调到|跳过|不练了|删除|删掉|去掉|移除|"
        r"加一组|减一组|改课|换成|改为|改成",
        message,
    ):
        return None
    if _BODY_QUESTION_TOKENS.search(message):
        return None
    parsed_date = parse_food_date(message)
    today = datetime.now(REVIEW_TZ).date()
    target = parsed_date or today
    if target > today:
        return {
            "actions": [],
            "reply": "未来日期的身体数据还不能记录，换一个日期？",
        }
    payload = _body_metric_payload(message)
    if not payload:
        return None
    action = _build_body_metric_action(payload, target)
    if action is None:
        return {
            "actions": [],
            "reply": "这组身体数据超出可记录范围，请检查后再发。",
        }
    return {
        "actions": [action],
        "reply": (
            f"身体数据识别好了：{_body_metric_summary(payload)}。"
            f"确认后写入{_body_date_label(target)}身体数据。"
        ),
    }


def _looks_like_regenerate_plan_request(message: str) -> bool:
    text = message.strip()
    if re.search(
        r"饮食|餐|每周|周[一二三四五六日天]|星期|分钟|分化|器械|部位|动作|"
        r"kg|公斤|斤",
        text,
    ):
        return False
    return bool(
        re.search(
            r"(?:重新|重做|再|换).{0,8}(?:生成|做|来)?一份?.{0,4}(?:训练)?计划",
            text,
        )
        or "重新生成计划" in text
    )


def _food_correction_without_pending(
    app_context: dict | None,
    message: str,
) -> bool:
    if not isinstance(app_context, dict):
        return False
    pending = app_context.get("pending_action")
    if isinstance(pending, dict) and pending.get("type") == "log_food":
        return False
    if not re.search(r"改成|换成|改为|修正", message):
        return False
    if re.search(r"新记|再记|另外|记一笔|补记|添加|加一个", message):
        return False
    return _looks_like_food_clause(message)


_OTHER_ACTION_MARKER_RE = re.compile(
    r"改到|改期|顺延|挪到|换到|调到|跳过|不练了|删除|删掉|去掉|移除|"
    r"加一组|减一组|再记|再帮|再加|另外|还有|同时|顺便|并且|以及"
)


def _looks_like_strength_log_message(message: str) -> bool:
    if re.search(r"吃|喝|餐|饭|饮食|体重|体脂|腰围", message):
        return False
    if not re.search(r"\d+\s*(组|次|个)", message):
        return False
    return bool(
        re.search(
            r"俯卧撑|深蹲|卧推|硬拉|引体|划船|推举|弯举|弓步|臀桥|平板|"
            r"蹲|推|拉|撑",
            message,
        )
    )


def _strength_log_action_turn(
    db: Session,
    user_id: str,
    message: str,
) -> dict | None:
    if _OTHER_ACTION_MARKER_RE.search(message):
        return None
    if not _looks_like_strength_log_message(message):
        return None
    clean = re.sub(
        r"\d+(?:\.\d+)?\s*(kg|公斤|斤|组|次|个|reps?)",
        " ",
        message,
        flags=re.IGNORECASE,
    )
    clean = re.sub(
        r"刚练完|练完|练了|做了|今天|昨天|前天|刚才|补录|记录|每组|大概|训练",
        " ",
        clean,
    )
    clean = re.sub(
        r"(?:上|下|这|本)?(?:周|星期|礼拜)[一二三四五六日天]",
        " ",
        clean,
    )
    clean = re.sub(r"\s*分(?:成)?\s*$", "", clean).strip(" ，,。")
    if not clean:
        return None
    exercise = db.execute(
        select(Exercise).where(
            Exercise.is_active.is_(True),
            Exercise.name_zh == clean,
        )
    ).scalar_one_or_none()
    if exercise is None:
        exercise = db.execute(
            select(Exercise)
            .where(
                Exercise.is_active.is_(True),
                Exercise.name_zh.contains(clean),
            )
            .order_by(
                Exercise.is_compound.desc(),
                func.length(Exercise.name_zh),
            )
            .limit(1)
        ).scalar_one_or_none()
    if exercise is None:
        return None

    reps_match = re.search(r"(\d+)\s*(次|个|reps?)", message, re.IGNORECASE)
    per_set_match = re.search(
        r"每\s*组\s*(?:做\s*)?(\d+)\s*(次|个|reps?)",
        message,
        re.IGNORECASE,
    )
    total_split_match = re.search(
        r"(\d+)\s*(?:次|个|reps?)[^。；;\n]{0,16}?分(?:成)?\s*(\d+)\s*组",
        message,
        re.IGNORECASE,
    )
    sets_match = re.search(r"(\d+)\s*组", message)
    if per_set_match is not None:
        reps = max(1, min(200, int(per_set_match.group(1))))
        sets = max(1, min(10, int(sets_match.group(1)))) if sets_match else 3
    elif total_split_match is not None:
        total = max(1, int(total_split_match.group(1)))
        sets = max(1, min(10, int(total_split_match.group(2))))
        reps = max(1, min(200, round(total / sets)))
    elif reps_match is not None:
        reps = max(1, min(200, int(reps_match.group(1))))
        sets = max(1, min(10, int(sets_match.group(1)))) if sets_match else 3
    else:
        return None
    weight = 0.0
    weight_match = re.search(
        r"(\d+(?:\.\d+)?)\s*(kg|公斤|斤)",
        message,
        flags=re.IGNORECASE,
    )
    if weight_match is not None:
        weight = float(weight_match.group(1))
        if weight_match.group(2) == "斤":
            weight /= 2
    target = parse_food_date(message) or datetime.now(REVIEW_TZ).date()
    if target > datetime.now(REVIEW_TZ).date():
        return {
            "actions": [],
            "reply": "未来的训练还不能记录，换一个日期？",
        }
    try:
        action = _normalize_app_actions(
            [
                {
                    "type": "log_workout",
                    "title": f"补录{exercise.name_zh}",
                    "summary": f"{sets} 组 × {reps} 次",
                    "requires_confirmation": True,
                    "payload": {
                        "date": target.isoformat(),
                        "title": exercise.name_zh,
                        "duration_minutes": max(15, sets * 4 + 5),
                        "kind": "strength",
                        "notes": message[:500],
                        "sets": [
                            {
                                "slug": exercise.slug,
                                "weight_kg": round(weight, 1),
                                "reps": reps,
                                "rpe": 7,
                                "set_index": index,
                            }
                            for index in range(1, sets + 1)
                        ],
                    },
                }
            ]
        )[0]
    except ValueError:
        return None
    error = _validate_workout_log_exercises(db, user_id, [action])
    if error is not None:
        return {"actions": [], "reply": error}
    return {
        "actions": [action],
        "reply": (
            f"识别到 {sets} 组 × {reps} 次 {exercise.name_zh}。"
            "确认后写入训练记录。"
        ),
    }


def _looks_like_cardio_log_message(message: str) -> bool:
    if re.search(r"吃|喝|餐|饭|饮食|体重|体脂|腰围", message):
        return False
    if not re.search(
        r"跑|骑车|骑行|游泳|椭圆|划船机|有氧|徒步|爬山|跳绳",
        message,
    ):
        return False
    return bool(
        re.search(
            r"\d+(?:\.\d+)?\s*(分钟|min|小时|h|公里|km)",
            message,
            re.IGNORECASE,
        )
    )


def _cardio_log_action_turn(
    db: Session,
    user_id: str,
    message: str,
) -> dict | None:
    if _OTHER_ACTION_MARKER_RE.search(message):
        return None
    if not _looks_like_cardio_log_message(message):
        return None
    from .coach_control.capabilities.training import resolve_cardio

    resolution = resolve_cardio(message)
    if not resolution.get("ready"):
        questions = resolution.get("questions") or []
        return {
            "actions": [],
            "reply": str(
                questions[0]
                if questions
                else "有氧训练还需要补充时长。"
            ),
        }
    payload = resolution.get("payload") or {}
    try:
        action = _normalize_app_actions(
            [
                {
                    "type": "log_workout",
                    "title": f"补录{payload.get('title') or '有氧训练'}",
                    "summary": f"{payload.get('duration_minutes') or 30} 分钟",
                    "requires_confirmation": True,
                    "payload": payload,
                }
            ]
        )[0]
    except ValueError:
        return None
    error = _validate_workout_log_exercises(db, user_id, [action])
    if error is not None:
        return {"actions": [], "reply": error}
    return {
        "actions": [action],
        "reply": (
            f"识别到 {payload.get('title') or '有氧训练'} "
            f"{payload.get('duration_minutes') or 30} 分钟。"
            "确认后写入训练记录。"
        ),
    }


def _diet_strategy(message: str) -> str | None:
    from .diet import DIET_STRATEGIES

    for strategy in DIET_STRATEGIES.values():
        if strategy.label and strategy.label in message:
            return strategy.id
    if re.search(r"16\s*[:：]\s*8|168|轻断食", message):
        return "time_restricted_16_8"
    return None


def _looks_like_week_diet_plan_request(message: str) -> bool:
    if re.search(r"吃了|喝了|记录饮食|记一下|补记", message):
        return False
    if not re.search(
        r"饮食计划|餐单|食谱|一周饮食|7\s*天饮食|七天饮食|"
        r"排一周|安排一周|整周饮食",
        message,
    ):
        return False
    return _diet_strategy(message) is not None or "饮食计划" in message


def _diet_plan_action_turn(db: Session, message: str) -> dict | None:
    if not _looks_like_week_diet_plan_request(message):
        return None
    from .coach_control.capabilities.diet_week import _week_start
    from .diet import DIET_STRATEGIES

    strategy_id = _diet_strategy(message) or "balanced"
    strategy = DIET_STRATEGIES.get(strategy_id, DIET_STRATEGIES["balanced"])
    week_start = _week_start(message)
    try:
        action = _normalize_app_actions(
            [
                {
                    "type": "create_diet_plan",
                    "title": f"生成一周{strategy.label}饮食计划",
                    "summary": f"{week_start.isoformat()} 起 7 天餐单",
                    "requires_confirmation": True,
                    "payload": {
                        "strategy": strategy_id,
                        "week_start": week_start.isoformat(),
                    },
                }
            ]
        )[0]
    except ValueError:
        return None
    return {
        "actions": [action],
        "reply": (
            f"按{strategy.label}策略排 {week_start.isoformat()} 起一周 7 天餐单。"
            "确认后生成，生成后可撤销。"
        ),
    }


_WEEKDAY_INDEX = {
    "一": 1,
    "二": 2,
    "三": 3,
    "四": 4,
    "五": 5,
    "六": 6,
    "日": 7,
    "天": 7,
}


def _message_target_date(message: str) -> date | None:
    parsed = parse_food_date(message)
    if parsed is not None:
        return parsed
    match = re.search(r"(?:周|星期|礼拜)([一二三四五六日天])", message)
    if match is None:
        return None
    target = _WEEKDAY_INDEX[match.group(1)]
    today = datetime.now(REVIEW_TZ).date()
    delta = (target - today.isoweekday()) % 7
    return today + timedelta(days=delta)


def _week_window(message: str) -> tuple[date, date, int]:
    today = datetime.now(REVIEW_TZ).date()
    monday = today - timedelta(days=today.isoweekday() - 1)
    if re.search(r"下下周", message):
        offset = 2
    elif re.search(r"下周|下星期|下礼拜", message):
        offset = 1
    elif re.search(r"上周|上星期|上礼拜", message):
        offset = -1
    else:
        offset = 0
    start = monday + timedelta(days=offset * 7)
    return start, start + timedelta(days=6), offset


def _plan_day_date(day: dict, states: dict[str, str]) -> date | None:
    raw = states.get(str(day.get("id")).lower()) or str(day.get("date") or "")
    if not raw:
        return None
    try:
        return date.fromisoformat(str(raw)[:10])
    except ValueError:
        return None


def _plan_day_weekday(day: dict, states: dict[str, str]) -> int | None:
    raw = day.get("weekday")
    if raw is not None:
        try:
            value = int(raw)
        except (TypeError, ValueError):
            value = 0
        if 1 <= value <= 7:
            return value
    parsed = _plan_day_date(day, states)
    return parsed.isoweekday() if parsed is not None else None


def _match_plan_day(
    app_context: dict | None,
    message: str,
) -> dict | None:
    if not isinstance(app_context, dict):
        return None
    plan = app_context.get("plan")
    if not isinstance(plan, dict):
        return None
    days = [item for item in plan.get("days") or [] if isinstance(item, dict)]
    if not days:
        return None
    states = {
        str(item.get("day_id")).lower(): str(item.get("assigned_date") or "")
        for item in plan.get("day_states") or []
        if isinstance(item, dict)
    }
    target_date = _message_target_date(message)
    candidates = days
    if target_date is not None:
        target_key = target_date.isoformat()
        dated = [
            item
            for item in days
            if _plan_day_date(item, states) == target_date
            or states.get(str(item.get("id")).lower()) == target_key
        ]
        weekday_matches = [
            item
            for item in days
            if _plan_day_weekday(item, states) == target_date.isoweekday()
        ]
        current_week = int(plan.get("current_week") or 1)
        current_week_matches = [
            item
            for item in weekday_matches
            if int(item.get("week_index") or 1) == current_week
        ]
        candidates = dated or current_week_matches or weekday_matches
    letters = {
        letter.upper()
        for letter in re.findall(r"全身\s*([A-Za-z])", message)
    }
    if letters:
        candidates = [
            item
            for item in candidates
            if any(
                letter in str(item.get("title") or "").upper()
                for letter in letters
            )
        ]
    if not candidates:
        return None
    if len(candidates) == 1:
        return candidates[0]
    current_week = int(plan.get("current_week") or 1)
    current = [
        item
        for item in candidates
        if int(item.get("week_index") or 1) == current_week
    ]
    if len(current) == 1:
        return current[0]
    if target_date is None and not letters:
        today_day = app_context.get("today_day")
        today_id = (
            str(today_day.get("id") or "").lower()
            if isinstance(today_day, dict)
            else ""
        )
        if today_id:
            for item in days:
                if str(item.get("id") or "").lower() == today_id:
                    return item
    return None


def _plan_day_label(day: dict) -> str:
    weekday = day.get("weekday_label")
    if not weekday:
        raw_weekday = day.get("weekday")
        try:
            if raw_weekday is not None:
                weekday = f"周{_weekday_label(int(raw_weekday))}"
        except (TypeError, ValueError):
            weekday = None
    if not weekday:
        parsed = _plan_day_date(day, {})
        if parsed is not None:
            weekday = f"周{_weekday_label(parsed.isoweekday())}"
    title = day.get("title") or "训练"
    return f"{weekday} {title}".strip() if weekday else str(title)


def _delete_last_exercise_turn(
    db: Session,
    user_id: str,
    message: str,
    app_context: dict | None,
) -> dict | None:
    if re.search(r"体重|体脂|腰围|饮食|吃了|喝了|记录饮食|补录饮食", message):
        return None
    date_refs = set(
        re.findall(
            r"今天|明天|后天|周[一二三四五六日天]|星期[一二三四五六日天]",
            message,
        )
    )
    letters = set(re.findall(r"全身\s*([A-Za-z])", message))
    if len(date_refs) > 1 or len(letters) > 1:
        return None
    if not re.search(r"删掉|删除|去掉|移除", message):
        return None
    if not re.search(r"最后(?:一个)?(?:动作)?|最后一项", message):
        return None
    day = _match_plan_day(app_context, message)
    if day is None:
        return None
    exercises = [
        item for item in day.get("exercises") or [] if isinstance(item, dict)
    ]
    if not exercises:
        return None
    last = exercises[-1]
    slug = str(last.get("slug") or "")
    if not slug:
        return None
    name = str(last.get("name_zh") or slug)
    label = _plan_day_label(day)
    try:
        action = _normalize_app_actions(
            [
                {
                    "type": "modify_workout",
                    "title": "删除动作",
                    "summary": f"从「{label}」删除「{name}」",
                    "requires_confirmation": True,
                    "payload": {
                        "scope": "day",
                        "day_id": day.get("id"),
                        "changes": [{"op": "remove", "slug": slug}],
                    },
                }
            ],
            app_context,
        )[0]
    except ValueError:
        return None
    error = _modify_workout_validation_error(
        db, user_id, [action], app_context
    )
    if error is not None:
        return {"actions": [], "reply": error}
    return {
        "actions": [action],
        "reply": (
            f"准备从「{label}」删除最后一个动作「{name}」。"
            "确认后生效。"
        ),
    }


def _skip_training_action_turn(
    db: Session,
    user_id: str,
    message: str,
    app_context: dict | None,
) -> dict | None:
    if re.search(r"吃|喝|饮食|餐|体重|体脂|腰围|记录|补录", message):
        return None
    if re.search(r"跑了|跑步|骑车|骑行|游泳|公里|分钟|练完|做了", message):
        return None
    date_refs = set(
        re.findall(
            r"今天|明天|后天|周[一二三四五六日天]|星期[一二三四五六日天]",
            message,
        )
    )
    letters = set(re.findall(r"全身\s*([A-Za-z])", message))
    if len(date_refs) > 1 or len(letters) > 1:
        return None
    if not re.search(r"跳过|不练了|不练|休息一天|休一天|今天休息", message):
        return None
    day = _match_plan_day(app_context, message)
    if day is None:
        return None
    target_date = _message_target_date(message)
    label = _plan_day_label(day)
    try:
        action = _normalize_app_actions(
            [
                {
                    "type": "skip_training",
                    "title": "跳过训练",
                    "summary": f"跳过「{label}」",
                    "requires_confirmation": True,
                    "payload": {
                        "day_id": day.get("id"),
                        "date": (
                            target_date.isoformat()
                            if target_date is not None
                            else None
                        ),
                    },
                }
            ],
            app_context,
        )[0]
    except ValueError:
        return None
    return {
        "actions": [action],
        "reply": (
            f"准备把「{label}」标记为跳过。确认后生效。"
        ),
    }


def _skip_reschedule_conflict_turn(message: str) -> dict | None:
    """A single training day cannot be both skipped and moved."""
    if re.search(r"不练了|不练", message) and re.search(
        r"挪到|改到|调整到|换到|顺延到",
        message,
    ):
        return {
            "actions": [],
            "reply": (
                "你是想直接跳过这次训练，还是改到另一天？"
                "两者只能选一个，告诉我就按你选的生成确认卡。"
            ),
        }
    return None


def _skip_week_action_turn(
    db: Session,
    user_id: str,
    message: str,
    app_context: dict | None,
) -> dict | None:
    """Skip every training day in the requested week."""
    if re.search(
        r"吃|喝|饮食|餐|体重|体脂|腰围|记录|补录|"
        r"改到|改期|顺延|挪到|换到|调到",
        message,
    ):
        return None
    if not re.search(
        r"这周|本周|这星期|下周|下星期|下礼拜|上周|上星期|上礼拜|"
        r"剩下|剩余|全部|整周",
        message,
    ):
        return None
    if not re.search(r"跳过|不练了|不练|休息", message):
        return None
    single_weekday = re.search(
        r"(?:(?:上|下|这|本)\s*)?(?:周|星期|礼拜)\s*[一二三四五六日天]",
        message,
    )
    if single_weekday and not re.search(
        r"都|剩下|剩余|全部|整周|所有",
        message,
    ):
        return None
    if not isinstance(app_context, dict):
        return None
    plan = app_context.get("plan")
    if not isinstance(plan, dict):
        return None
    days = [item for item in plan.get("days") or [] if isinstance(item, dict)]
    if not days:
        return None
    states = {
        str(item.get("day_id")).lower(): str(item.get("assigned_date") or "")
        for item in plan.get("day_states") or []
        if isinstance(item, dict)
    }
    today = datetime.now(REVIEW_TZ).date()
    week_start, week_end, offset = _week_window(message)
    week_label = "本周" if offset == 0 else ("下周" if offset > 0 else "上周")
    current_week = int(plan.get("current_week") or 1)
    target_week_index = current_week + offset
    candidates: list[tuple[date, dict]] = []
    seen: set[tuple[str, str]] = set()
    for day in days:
        if day.get("completed") or day.get("skipped") or day.get("in_progress"):
            continue
        target = _plan_day_date(day, states)
        if target is None:
            weekday = _plan_day_weekday(day, states)
            if (
                weekday is not None
                and int(day.get("week_index") or 1) == target_week_index
            ):
                target = week_start + timedelta(days=weekday - 1)
        if target is None or target < week_start or target > week_end:
            continue
        if offset == 0 and target < today:
            continue
        key = (target.isoformat(), str(day.get("title") or ""))
        if key in seen:
            continue
        seen.add(key)
        candidates.append((target, day))
    if not candidates:
        return {
            "actions": [],
            "reply": (
                f"{week_label}没有可跳过的训练，可能已经完成或已经跳过。"
            ),
        }
    candidates.sort(key=lambda item: item[0])
    actions: list[dict] = []
    labels: list[str] = []
    for target, day in candidates[:7]:
        label = _plan_day_label(day)
        try:
            action = _normalize_app_actions(
                [
                    {
                        "type": "skip_training",
                        "title": "跳过训练",
                        "summary": f"跳过 {target.month}月{target.day}日「{label}」",
                        "requires_confirmation": True,
                        "payload": {
                            "day_id": day.get("id"),
                            "date": target.isoformat(),
                        },
                    }
                ],
                app_context,
            )[0]
        except ValueError:
            continue
        actions.append(action)
        labels.append(f"{target.month}月{target.day}日 {label}")
    if not actions:
        return None
    return {
        "actions": actions,
        "reply": (
            f"准备跳过{week_label}"
            f"{'剩余 ' if offset == 0 else ''}{len(actions)} 次训练："
            f"{'、'.join(labels)}。确认后生效。"
        ),
    }


def _forget_memory_turn(
    db: Session,
    user_id: str,
    message: str,
) -> dict | None:
    if not re.search(r"忘掉|忘记|删掉|删除|清除|清掉|别记|不要记", message):
        return None
    if not re.search(r"记忆|忘掉|忘记|别记|不要记|这条|那条", message):
        return None
    if re.search(r"删掉|删除|清除|清掉", message) and not re.search(
        r"记忆|忘掉|忘记|这条|那条", message
    ):
        return None
    clean = re.sub(
        r"忘掉|忘记|删掉|删除|清除|清掉|别记|不要记|记住|这条|那条|"
        r"记忆|关于|我|的|吧|了|一下|，|。|,|\.",
        " ",
        message,
    )
    tokens = {
        token
        for token in re.findall(r"[\u4e00-\u9fff]{2,}", clean)
        if token not in {"记忆", "这条", "那条"}
    }
    if not tokens:
        return None
    rows = list(
        db.execute(
            select(AIMemory).where(
                AIMemory.user_id == user_id,
                AIMemory.active.is_(True),
            )
        )
        .scalars()
        .all()
    )
    matched = [
        row
        for row in rows
        if row.content
        and any(token in row.content for token in tokens)
    ]
    if not matched:
        try:
            action = _normalize_app_actions(
                [
                    {
                        "type": "open_screen",
                        "title": "打开长期记忆",
                        "summary": "在记忆列表里手动删除",
                        "requires_confirmation": True,
                        "payload": {"screen": "agent_memory"},
                    }
                ]
            )[0]
        except ValueError:
            return None
        return {
            "actions": [action],
            "reply": (
                "没有找到能直接匹配的长期记忆。"
                "已准备打开「AI 长期记忆」，你可以在里面删除对应条目。"
            ),
        }
    for row in matched[:5]:
        row.active = False
    db.flush()
    contents = "；".join(
        f"「{str(row.content)[:60]}」" for row in matched[:3]
    )
    return {
        "actions": [],
        "reply": f"已删除长期记忆：{contents}",
    }


_WHOLE_PLAN_CHANGE_RE = re.compile(
    r"整个计划|全部计划|所有训练日|每个训练日|每一天|以后都|全都|全部改|整周"
)
_PERMISSION_CLAIM_RE = re.compile(
    r"权限|只拿到|只获得|先准备的是(?:饮食|记录)|"
    r"这(?:一)?轮.{0,8}准备.{0,6}(?:饮食|记录)"
)
_CARD_CLAIM_RE = re.compile(
    r"记录卡|操作卡|确认卡|改课卡|动作卡|改期卡|跳过卡|目标卡|"
    r"饮食卡|训练卡|补录卡|卡片|(?:点|点击)确认"
)


def _looks_like_whole_plan_change(message: str) -> bool:
    if re.search(r"饮食|餐|重新生成|重做|换一份|新计划", message):
        return False
    if not _WHOLE_PLAN_CHANGE_RE.search(message):
        return False
    if not re.search(r"换|改|调整|替换|删除|删掉|去掉", message):
        return False
    return bool(
        re.search(
            r"动作|训练|计划|深蹲|卧推|硬拉|弓步|俯卧撑|划船|推举",
            message,
        )
    )


def _guard_permission_claims(message: str) -> str:
    if not _PERMISSION_CLAIM_RE.search(message):
        return message
    sentences = re.split(r"(?<=[。！？!?\n])", message)
    kept = [
        sentence
        for sentence in sentences
        if sentence.strip() and not _PERMISSION_CLAIM_RE.search(sentence)
    ]
    text = "".join(kept).strip()
    if text:
        return text
    return (
        "这轮没有生成可确认的操作卡，先不写入。"
        "请告诉我要改哪一天、哪个动作。"
    )


def _guard_action_card_claims(
    message: str,
    actions: list[dict],
    proposal: dict | None,
    pending_draft: dict | None,
) -> str:
    if actions or proposal is not None or pending_draft is not None:
        return message
    if not _CARD_CLAIM_RE.search(message):
        return message
    return (
        "这条还没有生成可确认的操作卡，先不写入。"
        "请把要记录的内容再说具体一点："
        "饮食说清食物和份量，训练说清动作、组数或时长。"
    )


_GOAL_REPLY_VALUE_RE = re.compile(
    r"(?:改成|改为|先定在|先定|定在|定为|建议(?:按|先)?|"
    r"目标(?:是|为|放在)?|控制在|定到|摸到|先摸到|稳住|稳定在|"
    r"先按|先到|达到|降到|减到|增到|提升到)"
    r"\s*(\d{2,3}(?:\.\d+)?)\s*(?:kg|公斤)"
)


_GOAL_VALUE_RE_TEMPLATE = r"(?<![\d.]){value}(?=\s*(?:kg|公斤|$|[，,。；;\s]))"


def _rewrite_goal_value(text: str, old: float, new: float) -> str:
    if not text:
        return text
    pattern = _GOAL_VALUE_RE_TEMPLATE.format(value=re.escape(f"{old:g}"))
    return re.sub(pattern, f"{new:g}", text)


def _guard_goal_action_consistency(
    message: str,
    actions: list[dict],
) -> str:
    """Keep an update_goal card aligned with the reply's advice.

    The model used to recommend 68kg in the text while the card still carried
    the requested 65kg, so confirming applied the value the coach just advised
    against. If the reply recommends a different target, align the card with
    the recommendation and say so explicitly. The card still requires an
    explicit confirmation.
    """
    goal_actions = [
        action
        for action in actions
        if action.get("type") == "update_goal"
        and isinstance(action.get("payload"), dict)
        and action["payload"].get("target_weight_kg") is not None
    ]
    if not goal_actions:
        return message
    try:
        payload_value = float(
            goal_actions[0]["payload"]["target_weight_kg"]
        )
    except (TypeError, ValueError):
        return message
    suggestions: list[float] = []
    for match in _GOAL_REPLY_VALUE_RE.finditer(message):
        try:
            value = float(match.group(1))
        except ValueError:
            continue
        if 25 <= value <= 300:
            suggestions.append(value)
    if not suggestions:
        return message
    suggested = suggestions[-1]
    if abs(suggested - payload_value) < 0.05:
        return message
    for action in goal_actions:
        action["payload"]["target_weight_kg"] = suggested
        action["title"] = _rewrite_goal_value(
            str(action.get("title") or ""),
            payload_value,
            suggested,
        )
        action["summary"] = _rewrite_goal_value(
            str(action.get("summary") or ""),
            payload_value,
            suggested,
        )
    note = (
        f"目标卡已按 {suggested:g}kg 准备；"
        f"如果你仍想 {payload_value:g}kg，先不要确认并告诉我。"
    )
    if note not in message:
        message = f"{message.rstrip()}\n\n{note}"
    return message


def _deterministic_extra_turn(
    db: Session,
    user_id: str,
    message: str,
    app_context: dict | None,
) -> dict | None:
    forget = _forget_memory_turn(db, user_id, message)
    if forget is not None:
        return forget
    diet = _diet_plan_action_turn(db, message)
    if diet is not None:
        return diet
    if _looks_like_whole_plan_change(message):
        return {
            "actions": [],
            "reply": (
                "改课目前一次只能按一个训练日改，不能一次改整个计划。"
                "你想先从哪一天开始？比如“先改周五全身 C”；"
                "确认一天后，再继续改下一天。"
            ),
        }
    return None


def _body_action_for_clause(
    clause: str,
) -> tuple[dict | None, str | None]:
    if not _looks_like_body_metric_clause(clause):
        return None, None
    payload = _body_metric_payload(clause)
    if not payload:
        return None, None
    target = _body_target_date(clause)
    if target > datetime.now(REVIEW_TZ).date():
        return None, "身体数据不能记录到未来日期，换一个日期？"
    action = _build_body_metric_action(payload, target)
    if action is None:
        return None, "这组身体数据超出可记录范围，请检查后再发。"
    return action, None


def _workout_action_for_clause(
    db: Session,
    user_id: str,
    clause: str,
) -> tuple[dict | None, str | None]:
    for helper in (_strength_log_action_turn, _cardio_log_action_turn):
        result = helper(db, user_id, clause)
        if result is None:
            continue
        actions = result.get("actions") or []
        if actions:
            return actions[0], None
        return None, str(
            result.get("reply") or "训练补录还需要补充信息。"
        )
    return None, None


def _reschedule_action_for_clause(
    db: Session,
    user_id: str,
    clause: str,
    app_context: dict | None,
) -> tuple[dict | None, str | None]:
    from .coach_control.runtime import _looks_like_reschedule

    if not _looks_like_reschedule(clause):
        return None, None
    from .coach_control.capabilities.training import (
        resolve as resolve_training,
    )

    resolution = resolve_training(db, user_id, clause, app_context)
    if not resolution.get("ready"):
        questions = resolution.get("questions") or []
        return None, str(
            questions[0]
            if questions
            else "没有找到要改期的训练，请从训练手账里选一天。"
        )
    payload = resolution.get("payload") or {}
    if resolution.get("already"):
        return None, f"训练本来就在 {payload.get('to_date')}，无需改期。"
    from_date = str(payload.get("from_date") or "")
    to_date = str(payload.get("to_date") or "")
    title = str(payload.get("title") or "训练")
    try:
        action = _normalize_app_actions(
            [
                {
                    "type": "reschedule_training",
                    "title": "调整训练日期",
                    "summary": f"把 {from_date} 的「{title}」改到 {to_date}",
                    "requires_confirmation": True,
                    "payload": {
                        "day_id": payload.get("day_id"),
                        "date": from_date,
                        "target_date": to_date,
                    },
                }
            ],
            app_context,
        )[0]
    except ValueError as exc:
        return None, str(exc)
    return action, None


def _clause_kind(clause: str) -> str:
    from .coach_control.runtime import _looks_like_reschedule

    if _looks_like_reschedule(clause):
        return "reschedule"
    if re.search(r"跳过|不练了|不练|休息一天|休一天", clause):
        return "skip"
    if _looks_like_body_metric_clause(clause):
        return "body"
    if _looks_like_strength_log_message(clause) or _looks_like_cardio_log_message(
        clause
    ):
        return "workout"
    if _looks_like_food_clause(clause):
        return "food"
    if re.search(r"删掉|删除|去掉|移除|加一组|减一组|改成|改为|换成|修改", clause):
        return "modify"
    return "unknown"


async def _mixed_action_multi_intent_turn(
    db: Session,
    user_id: str,
    clauses: list[str],
    app_context: dict | None,
) -> dict | None:
    """Combine workout/food/body/skip clauses without silently dropping one."""
    tagged: list[tuple[str, str]] = []
    for clause in clauses:
        kind = _clause_kind(clause)
        if kind == "unknown":
            return None
        tagged.append((kind, clause))
    kinds = {kind for kind, _ in tagged}
    if sum(1 for kind, _ in tagged if kind == "skip") > 1:
        # Multiple skip clauses are a batch; let the normal multi-action path
        # handle them instead of producing duplicate single-day cards.
        return None
    if "modify" in kinds:
        if len(tagged) > 1:
            return {
                "actions": [],
                "reply": (
                    "这条消息里有改课和其他操作，先分开确认："
                    "这次先处理哪一件？"
                ),
            }
        return None
    if not (kinds & {"workout", "skip"}):
        return None

    actions: list[dict] = []
    notes: list[str] = []
    for kind, clause in tagged:
        if kind == "food":
            action, question = await _food_action_for_clause(
                db,
                user_id,
                clause,
                app_context,
            )
            if action is None:
                return {
                    "actions": [],
                    "reply": question or "饮食部分还需要确认。",
                }
            actions.append(action)
        elif kind == "body":
            action, question = _body_action_for_clause(clause)
            if action is None:
                return {
                    "actions": [],
                    "reply": question or "身体数据还需要确认。",
                }
            actions.append(action)
        elif kind == "workout":
            action, question = _workout_action_for_clause(
                db, user_id, clause
            )
            if action is None:
                return {
                    "actions": [],
                    "reply": question or "训练补录还需要确认。",
                }
            actions.append(action)
        elif kind == "reschedule":
            action, note = _reschedule_action_for_clause(
                db, user_id, clause, app_context
            )
            if action is not None:
                actions.append(action)
            if note:
                notes.append(note)
        elif kind == "skip":
            result = _skip_training_action_turn(
                db, user_id, clause, app_context
            )
            if result is None:
                return {
                    "actions": [],
                    "reply": "跳过部分还需要确认是哪一天训练。",
                }
            skip_actions = result.get("actions") or []
            if not skip_actions:
                return {
                    "actions": [],
                    "reply": str(
                        result.get("reply")
                        or "跳过部分还需要确认是哪一天训练。"
                    ),
                }
            actions.extend(skip_actions)
    if not actions:
        if notes:
            return {"actions": [], "reply": " ".join(notes)}
        return None
    labels = [
        str(action.get("summary") or action.get("title") or "操作")
        for action in actions
    ]
    prefix = " ".join(notes)
    reply = (
        f"{prefix}识别到 {len(actions)} 个操作："
        f"{'；'.join(labels)}。确认后一起执行。"
    ).strip()
    return {"actions": actions, "reply": reply}


async def _multi_intent_action_turn(
    db: Session,
    user_id: str,
    message: str,
    app_context: dict | None,
) -> dict | None:
    """Handle "reschedule training + log food" as one batch.

    A forced food-log turn used to win the whole message, inherit "明天" from
    the training clause, and silently drop the reschedule. Resolve each clause
    separately and return both cards, or ask before writing either one.
    """
    from .coach_control.runtime import (
        _looks_like_reschedule,
        _split_batch_clauses,
    )

    clauses = _split_batch_clauses(message)
    if len(clauses) == 1 and _food_correction_without_pending(
        app_context, message
    ):
        return {
            "actions": [],
            "reply": (
                "你是想修改已经记录的这一餐，还是新记一笔？"
                "如果要修改，请在饮食记录里点对应食物；"
                "要新记，请说“新记 200g 米饭”。"
            ),
        }
    conflict = _skip_reschedule_conflict_turn(message)
    if conflict is not None:
        return conflict
    skip_week_result = _skip_week_action_turn(
        db, user_id, message, app_context
    )
    if skip_week_result is not None:
        return skip_week_result
    if not re.search(
        r"再记|再帮|再加|再把|再改|再删|另外|还有|同时|顺便|并且|以及",
        message,
    ):
        body_result = _body_metric_action_turn(message)
        if body_result is not None:
            return body_result
        delete_result = _delete_last_exercise_turn(
            db, user_id, message, app_context
        )
        if delete_result is not None:
            return delete_result
        skip_result = _skip_training_action_turn(
            db, user_id, message, app_context
        )
        if skip_result is not None:
            return skip_result
        strength_result = _strength_log_action_turn(db, user_id, message)
        if strength_result is not None:
            return strength_result
        cardio_result = _cardio_log_action_turn(db, user_id, message)
        if cardio_result is not None:
            return cardio_result
    if len(clauses) == 1 and _looks_like_reschedule(message):
        action, note = _reschedule_action_for_clause(
            db, user_id, message, app_context
        )
        if action is not None:
            return {
                "actions": [action],
                "reply": (
                    f"{action.get('summary') or '训练改期'}。确认后生效。"
                ),
            }
        if note:
            return {"actions": [], "reply": note}
    if len(clauses) < 2:
        return None
    mixed_result = await _mixed_action_multi_intent_turn(
        db,
        user_id,
        clauses,
        app_context,
    )
    if mixed_result is not None:
        return mixed_result
    body_reschedule_result = await _body_reschedule_multi_intent_turn(
        db,
        user_id,
        clauses,
        app_context,
    )
    if body_reschedule_result is not None:
        return body_reschedule_result
    body_result = await _food_body_multi_intent_turn(
        db,
        user_id,
        clauses,
        app_context,
    )
    if body_result is not None:
        return body_result
    training_clauses = [
        clause for clause in clauses if _looks_like_reschedule(clause)
    ]
    if not training_clauses:
        return None
    if len(training_clauses) > 1:
        # Multiple reschedules without a clear food clause are better handled
        # by the normal multi-action path.
        return None
    training_clause = training_clauses[0]
    food_clauses = [
        clause
        for clause in clauses
        if clause != training_clause and _looks_like_food_clause(clause)
    ]
    other_clauses = [
        clause
        for clause in clauses
        if clause != training_clause and clause not in food_clauses
    ]
    if not food_clauses:
        # No food intent: leave multi-reschedule or ordinary follow-ups to the
        # normal agent path.
        return None
    if other_clauses:
        return {
            "actions": [],
            "reply": (
                "这条消息里有改期、饮食和其他操作，先分开说会更稳："
                "这次只确认改期和饮食，其他内容请再发一条。"
            ),
        }
    if len(food_clauses) != 1:
        return {
            "actions": [],
            "reply": "要把训练改到哪一天？饮食部分也请单独说一句，我一起确认。",
        }
    food_clause = food_clauses[0]

    from .coach_control.capabilities.training import (
        resolve as resolve_training,
    )

    training_resolution = resolve_training(
        db,
        user_id,
        training_clause,
        app_context,
    )
    if not training_resolution.get("ready"):
        questions = training_resolution.get("questions") or []
        question = (
            str(questions[0])
            if questions
            else "没有找到要改期的训练，请从训练手账里选一天。"
        )
        return {
            "actions": [],
            "reply": (
                f"{question} 饮食我先不写入，等训练改期确认后一起处理。"
            ),
        }

    training_payload = training_resolution.get("payload") or {}
    training_action = None
    training_note = ""
    if training_resolution.get("already"):
        training_note = (
            f"训练本来就在 {training_payload.get('to_date')}，无需改期；"
        )
    else:
        from_date = str(training_payload.get("from_date") or "")
        to_date = str(training_payload.get("to_date") or "")
        title = str(training_payload.get("title") or "训练")
        training_action = _normalize_app_actions(
            [
                {
                    "type": "reschedule_training",
                    "title": "调整训练日期",
                    "summary": f"把 {from_date} 的「{title}」改到 {to_date}",
                    "requires_confirmation": True,
                    "payload": {
                        "day_id": training_payload.get("day_id"),
                        "date": from_date,
                        "target_date": to_date,
                    },
                }
            ],
            app_context,
        )[0]
        training_note = (
            f"把 {from_date} 的「{title}」改到 {to_date}，"
        )

    context = food_log_context(food_clause)
    food_resolution = await resolve_food_text(
        db,
        user_id,
        food_clause,
        meal=context["meal"],
        target_date=date.fromisoformat(context["date"]),
    )
    if (
        food_resolution.get("questions")
        or food_resolution.get("missing_slots")
        or not food_resolution.get("items")
    ):
        question = _food_question_message(food_resolution)
        return {
            "actions": [],
            "reply": (
                f"训练改期我先不执行；饮食部分还需要确认：{question}"
            ),
        }
    food_action = _build_food_log_action(
        food_resolution,
        food_clause,
        context["date"],
        context["meal"],
    )
    actions = (
        [training_action, food_action]
        if training_action is not None
        else [food_action]
    )
    meal_label = {
        "breakfast": "早餐",
        "lunch": "午餐",
        "dinner": "晚餐",
        "snack": "加餐",
    }.get(context["meal"], "这餐")
    return {
        "actions": actions,
        "reply": (
            f"{training_note}"
            f"饮食按 {context['date']} {meal_label} 记录，"
            f"{food_action.get('summary') or ''}。确认后一起执行。"
        ).strip(),
    }


def _draft_total(items: list[dict], key: str) -> float:
    return round(sum(float(item.get(key) or 0) for item in items), 1)


async def _resolve_raw_draft(
    db: Session,
    user_id: str,
    session_id: str | None,
    message: str,
) -> dict | None:
    draft = get_active_draft(db, user_id, session_id)
    if draft is None or not needs_raw_clarification(draft):
        return None
    payload = draft.payload or {}
    combined = f"{payload.get('raw_text') or ''} {message}".strip()[:500]
    target = None
    try:
        target = date.fromisoformat(str(payload.get("date") or ""))
    except ValueError:
        target = None
    resolution = await resolve_food_text(
        db,
        user_id,
        combined,
        meal=str(payload.get("meal") or "lunch"),
        target_date=target,
        prefer_llm=True,
    )
    slots = list(resolution.get("missing_slots") or [])
    questions = [
        str(value)[:120]
        for value in (resolution.get("questions") or [])
        if str(value).strip()
    ]
    items = resolution.get("items") or []
    if items and not slots and not questions:
        draft.payload = {
            "date": payload.get("date")
            or datetime.now(REVIEW_TZ).date().isoformat(),
            "meal": payload.get("meal") or "lunch",
            "raw_text": combined,
            "items": items,
        }
        draft.missing_slots = []
        draft.status = "consumed"
        draft.updated_at = utcnow()
        db.flush()
        return {
            "draft_id": draft.id,
            "ready": True,
            "date": draft.payload["date"],
            "meal": draft.payload["meal"],
            "items": items,
            "questions": [],
        }
    if items:
        payload["items"] = items
    payload["raw_text"] = combined
    if not slots and questions:
        slots = [{"field": "raw_text", "question": questions[0]}]
    draft.payload = payload
    draft.missing_slots = slots
    draft.status = "collecting"
    draft.updated_at = utcnow()
    db.flush()
    return {
        "draft_id": draft.id,
        "ready": False,
        "items": items,
        "questions": [item.get("question") for item in slots],
        "missing_slots": slots,
    }


async def _handle_draft_turn(
    db: Session,
    run: AgentRun,
    user_id: str,
    session_id: str | None,
    message: str,
    started: float,
    usage: dict[str, int],
) -> dict:
    answer = await _resolve_raw_draft(db, user_id, session_id, message)
    if answer is None:
        answer = answer_food_draft(db, user_id, session_id, message)
    if answer is None:
        raise LookupError("草稿已失效")
    actions: list[dict] = []
    if answer.get("cancelled"):
        final_message = "已取消这次记录。"
    elif answer.get("ready"):
        payload = {
            "date": answer.get("date")
            or datetime.now(REVIEW_TZ).date().isoformat(),
            "meal": answer.get("meal") or "lunch",
            "items": answer.get("items") or [],
        }
        kcal = _draft_total(payload["items"], "kcal")
        raw = {
            "type": "log_food",
            "title": "记录饮食",
            "summary": f"约 {int(kcal)} kcal",
            "requires_confirmation": True,
            "payload": payload,
        }
        actions = _normalize_app_actions([raw])
        final_message = f"补充好了，约 {int(kcal)} kcal。确认一下卡片就写入饮食记录。"
    else:
        question = _food_question_message(answer)
        draft = get_active_draft(db, user_id, session_id)
        final_message = (
            question
            if needs_raw_clarification(draft)
            else f"{question} 直接告诉我毫升或克数就行。"
        )
    run.intent = "app_action" if actions else "draft_clarification"
    run.status = "needs_confirmation" if actions else "completed"
    run.output_text = final_message
    run.completed_at = utcnow()
    _record_step(
        db,
        run,
        "tool",
        tool_name="resolve_food",
        input_data={"draft_answer": message[:200]},
        output_data=answer,
    )
    db.commit()
    return {
        "run_id": run.id,
        "status": run.status,
        "reply": final_message,
        "proposal": None,
        "actions": actions,
        "safety_flag": None,
        "citations": [],
        "pending_draft": compact_draft(get_active_draft(db, user_id, session_id)),
        "elapsed_ms": int((time.perf_counter() - started) * 1000),
        "usage": usage,
        "error": None,
    }


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
{"action":"tool","tool":"propose_app_actions","arguments":{"actions":[{"type":"update_food_log","title":"修正肉肠克数","summary":"把已记录的肉肠改成 230g","requires_confirmation":true,"payload":{"client_id":"来自 recent_logs 的 client_id","grams":230}}]}}
{"action":"tool","tool":"propose_app_actions","arguments":{"actions":[{"type":"log_planned_meal","title":"记录计划午餐","summary":"把今天计划里的午餐记为已吃","requires_confirmation":true,"payload":{"date":"2026-11-13","meal":"lunch"}}]}}
{"action":"tool","tool":"propose_app_actions","arguments":{"actions":[{"type":"skip_planned_meal","title":"跳过今晚计划餐","summary":"标记为主动跳过，不算漏记","requires_confirmation":true,"payload":{"date":"2026-11-13","meal":"dinner"}}]}}
{"action":"tool","tool":"propose_app_actions","arguments":{"actions":[{"type":"log_workout","title":"补录昨天跑步","summary":"30 分钟有氧，写入训练记录","requires_confirmation":true,"payload":{"date":"2026-11-12","title":"跑步","duration_minutes":30,"kind":"cardio"}}]}}
{"action":"tool","tool":"propose_app_actions","arguments":{"actions":[{"type":"log_workout","title":"补录深蹲","summary":"4 组 × 10 次，60kg","requires_confirmation":true,"payload":{"date":"2026-11-12","title":"深蹲","duration_minutes":45,"kind":"strength","sets":[{"slug":"goblet-squat","weight_kg":60,"reps":10,"rpe":8}]}}]}}
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
12. modify_workout 的 from_slug 必须来自 app_context.plan.days[].exercises[].slug；换动作/加动作前必须先调用 lookup_exercise，使用它返回的真实 slug，禁止把中文直译成英文 slug（例如“前弓步”不是 forward-lunge）。当前只支持 scope=day，不要用 scope=plan；用户说“以后都/整个计划”时先按当前训练日改，并说明可以逐日调整。最多 8 条改动；换动作后重量默认不沿用旧动作，需要指定时再加一条 weight。用户只要求改一天时，只能生成一张 reschedule_training，不要顺带改其他天。
13. 改课是待确认操作；final 里要说明“确认后才会改”，不能声称已经改好。
14. 如果 app_context.today_day.in_progress=true，说明训练已经开始；不要用 modify_workout 改当前这次训练，先让用户在训练页用“调整/替换”改本次训练；可以改之后的训练日。
15. 用户问某个动作最近练得怎么样、为什么没进步、下次加不加重量、有没有退步时，先调用 get_exercise_history；用返回的真实每组数据回答，不要用计划目标代替实际完成。
16. 用户问某天/某次训练的具体内容时，调用 get_workout_detail；只引用返回的数据，不要编造重量、次数或 RPE。
17. 用户提到关节、腰、颈、肩、膝、肘、腕疼痛时，即使只是问“要不要停”，回答必须先说停止/减量，并补一句什么情况需要医生或康复师评估；不能只给替代动作。
18. 不要声称自己“只有某种权限/只拿到某种权限”。本轮做不到就直说“这次先处理 X，稍后再处理 Y”，不要编造权限原因。
19. 用户提出超过现有器械能力的重量（例如只有 8kg 哑铃却要 20kg）时，先明确确认或改成可用重量；不要生成超过用户器械能力的重量卡。
20. 用户明确说“重新生成一份训练计划/换一份计划/重做计划”时，直接调用 propose_plan，参数沿用档案默认值，不要反问训练日、时长或动作；生成后说明确认后才会应用。

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
- 只能使用这些 action type：reschedule_training、skip_training、start_training、open_screen、update_goal、log_body_metric、create_diet_plan、swap_diet_meal、log_food、log_planned_meal、skip_planned_meal、restore_planned_meal、update_food_log、delete_food_log、log_workout、update_workout_log、delete_workout_log、recognize_equipment、analyze_body、modify_workout。
- 用户说“我的体重现在是 70kg”时，调用 log_body_metric，payload 至少包含 weight_kg（可选 body_fat_pct、waist_cm），不要让用户自己去页面填写。
- 体重、体脂、腰围等身体数据只能用 propose_app_actions + log_body_metric；绝对不要用 remember，也不要把 remember 当作更新身体数据的方式。
- 用户想安排饮食计划、碳循环、低碳、高蛋白、地中海、素食、16:8 或换饮食策略时，调用 create_diet_plan。payload.strategy 只能是 balanced / carb_cycle / low_carb / high_protein / mediterranean / vegetarian / time_restricted_16_8，week_start 用周一日期（YYYY-MM-DD，可省略，默认本周）。先说明会按什么策略排，再让用户确认。
- 用户只想替换某一餐、不想重排整周时，调用 swap_diet_meal。payload 必须包含 date（YYYY-MM-DD）和 meal（breakfast / lunch / dinner / snack）；服务端会保持当天热量和三大营养素不变，只换菜品。不要说已经换好，等用户确认。
- 如果 state.forced_intent=log_food，本轮只能使用 get_context、resolve_food、propose_app_actions；propose_app_actions 的 type 必须是 log_food / log_planned_meal / update_food_log / delete_food_log。不要调用 open_screen 或 create_diet_plan。
- 如果 state.forced_intent=log_workout，本轮只能使用 get_context、lookup_exercise、get_exercise_history、propose_app_actions；propose_app_actions 的 type 只能是 log_workout。用户说“练完了/跑了/补录”不是“开始训练”，不要调用 start_training。
- 如果 state.pending_draft 存在（例如正在记录午餐，只差奶茶份量），用户这句话要先当作草稿补参数：调用 resolve_food，draft_id 传 pending_draft.id，text 传用户原话；不要重新识别整餐，不要重新创建 log_food action。补完后 resolve_food 返回 ready=true，再用返回的 items 生成 log_food。
- 如果 app_context.pending_action 存在，说明这是还没确认的饮食/训练卡：用户说“记错了/改成/不是/应该是”时，应生成一张修正后的同类型 action 卡，不要调用 update_food_log（此时还没有 FoodLog）。只有 pending_action 不存在、且 today_nutrition.recent_logs 里有真实 client_id 时，才调用 update_food_log / delete_food_log，payload.client_id 必须来自 recent_logs，不能猜。
- 如果 resolve_food 返回 ready=false 或 questions，调用 ask_user 继续问，不要生成 action。用户说取消/不要了时，不要执行任何写入。
- 用户说“我今天吃了/喝了……帮我记一下/补记/记录饮食”时：
  1. 先调用 resolve_food，text 传用户原话，meal 尽量从上下文判断，date 用今天或用户指定日期。
  2. 如果 resolve_food 返回 questions，先 ask_user 补份量，不要直接写。
  3. 如果返回 items，调用 propose_app_actions，type=log_food，payload.items 使用 resolve_food 的结果。
  4. 不要调用 open_screen nutrition，不要调用 create_diet_plan，也不要让用户自己去页面填写。
- 用户说“我吃了计划里的午餐/晚餐”时，调用 log_planned_meal，payload 包含 date 和 meal；这会把计划餐记为完成。
- 用户说“今晚这餐不吃了/跳过这顿计划餐”时，调用 skip_planned_meal，payload 包含 date 和 meal；跳过不等于漏记，饮食复盘会单独计数。已经记录过的餐不能跳过。
- 用户说“恢复这餐/我没跳过”时，调用 restore_planned_meal，payload 包含 date 和 meal。
- 用户说“我昨天跑了 30 分钟/今天补录一次训练/把刚才那次训练记上”时，调用 log_workout；payload 至少包含 date、title、duration_minutes，kind 用 strength 或 cardio。不要把“已经练完/补录”误判成 start_training。
- log_workout 的记录日期不能是未来；kind=strength 必须先用 lookup_exercise 确认真实动作 slug，并带至少 1 个 sets（slug、weight_kg、reps、rpe）；空 sets 会被拒绝。只有 kind=cardio 才可以只写 title + duration。
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
    ("已经写入", "准备写入"),
    ("已经保存", "准备保存"),
    ("已经记上", "准备记录"),
    ("已经记好", "准备记录"),
    ("已经记下", "准备记录"),
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
    ("记上了", "准备好了"),
    ("记好了", "准备好了"),
    ("已记上", "准备记录"),
    ("已记好", "准备记录"),
    ("已记下", "准备记录"),
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
    raw_actions: Any,
    app_context: dict | None = None,
    food_resolution: dict | None = None,
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
            metric_date = str(payload.get("date") or "").strip()
            if metric_date:
                if not valid_date(metric_date):
                    raise ValueError("body metric date must be YYYY-MM-DD")
                if metric_date > datetime.now(REVIEW_TZ).date().isoformat():
                    raise ValueError("future body metric dates are not allowed")
                payload["date"] = metric_date
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
            if food_resolution is not None:
                if not food_resolution.get("ready", True):
                    raise ValueError("食物解析还没有完成，先补充信息")
                resolved_items = food_resolution.get("items") or []
                if resolved_items:
                    payload["items"] = resolved_items
                if food_resolution.get("date"):
                    payload["date"] = food_resolution["date"]
                if food_resolution.get("meal"):
                    payload["meal"] = food_resolution["meal"]
            if not valid_date(str(payload.get("date", ""))):
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
        if action_type in {"skip_planned_meal", "restore_planned_meal"}:
            if not valid_date(date_value):
                payload["date"] = datetime.now(REVIEW_TZ).date().isoformat()
            try:
                payload = SkipPlannedMealPayload.model_validate(payload).model_dump(
                    mode="json"
                )
            except Exception as exc:
                raise ValueError(f"{action_type} payload invalid: {exc}") from exc
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
            kind = str(payload.get("kind") or "strength").strip().lower()
            sets = payload.get("sets")
            if kind == "strength" and not (
                isinstance(sets, list) and sets
            ):
                raise ValueError(
                    "力量补录必须至少包含 1 个动作组（sets：slug、weight_kg、"
                    "reps）；请先调用 lookup_exercise 选择真实动作，"
                    "不要只写标题"
                )
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


def _exercise_lookup_item(row: Exercise) -> dict:
    return {
        "slug": row.slug,
        "name_zh": row.name_zh,
        "name_en": row.name_en,
        "equipment": row.equipment,
        "muscle_group": row.muscle_group,
        "is_compound": row.is_compound,
        "instructions": (row.instructions or "")[:600],
    }


def _lookup_exercise_payload(
    db: Session,
    query: str,
    limit: int = 5,
) -> dict:
    value = query.strip()
    if not value:
        return {"ok": False, "error": "lookup_exercise requires query"}
    pattern = f"%{value}%"
    rows = (
        db.execute(
            select(Exercise)
            .where(
                Exercise.is_active.is_(True),
                or_(
                    Exercise.name_zh.contains(value),
                    Exercise.name_en.ilike(pattern),
                ),
            )
            .order_by(
                Exercise.is_compound.desc(),
                Exercise.difficulty,
                Exercise.name_zh,
            )
            .limit(max(1, min(5, limit)))
        )
        .scalars()
        .all()
    )
    if not rows:
        return {
            "ok": False,
            "error": "没有找到匹配动作；不要编造 slug，请让用户补充动作名或器械。",
            "query": value,
        }
    return {
        "ok": True,
        "query": value,
        "exercises": [_exercise_lookup_item(row) for row in rows],
    }


def _exercise_slug_suggestions(
    db: Session,
    slug: str,
    equipment: set[str],
    limit: int = 4,
) -> str:
    tokens = [
        token
        for token in re.split(r"[-_\s]+", slug.lower())
        if len(token) >= 3
    ]
    base = select(Exercise).where(
        Exercise.is_active.is_(True),
        Exercise.equipment.in_(equipment),
    )
    rows: list[Exercise] = []
    if tokens:
        conditions = [
            or_(
                Exercise.slug.contains(token),
                Exercise.name_en.ilike(f"%{token}%"),
            )
            for token in tokens
        ]
        rows = (
            db.execute(base.where(and_(*conditions)).limit(limit))
            .scalars()
            .all()
        )
    if not rows:
        rows = (
            db.execute(
                base.order_by(
                    Exercise.is_compound.desc(),
                    Exercise.name_zh,
                ).limit(limit)
            )
            .scalars()
            .all()
        )
    return "、".join(
        f"{row.name_zh}({row.slug})" for row in rows
    ) or "暂无"


def _modify_workout_validation_error(
    db: Session,
    user_id: str,
    actions: list[dict],
    app_context: dict | None,
) -> str | None:
    """Validate modify_workout slugs before a confirmation card reaches iOS."""
    modify_actions = [
        action for action in actions if action.get("type") == "modify_workout"
    ]
    if not modify_actions:
        return None
    profile = db.get(Profile, user_id)
    equipment = set(
        available_equipment_types(
            db,
            user_id,
            list(profile.equipment or []) if profile else ["bodyweight"],
        )
    )
    banned = injury_tags(profile.injuries if profile else [])

    context = app_context if isinstance(app_context, dict) else {}
    plan = context.get("plan") if isinstance(context.get("plan"), dict) else {}
    days = plan.get("days") if isinstance(plan.get("days"), list) else []
    day_by_id = {
        str(item.get("id")).lower(): item
        for item in days
        if isinstance(item, dict) and item.get("id")
    }
    today_day = context.get("today_day")
    today_id = (
        str(today_day.get("id")).lower()
        if isinstance(today_day, dict) and today_day.get("id")
        else ""
    )

    for action in modify_actions:
        payload = action.get("payload")
        if not isinstance(payload, dict):
            continue
        scope = str(payload.get("scope") or "day").strip().lower()
        if scope != "day":
            return "目前只支持按训练日改课；请按具体训练日修改，不要用 scope=plan。"
        target_id = str(payload.get("day_id") or today_id).lower()
        target_day = day_by_id.get(target_id)
        day_slugs = {
            str(item.get("slug"))
            for item in (target_day.get("exercises") or [])
            if isinstance(item, dict) and item.get("slug")
        } if isinstance(target_day, dict) else set()

        changes = payload.get("changes")
        if not isinstance(changes, list):
            continue
        for change in changes:
            if not isinstance(change, dict):
                continue
            op = str(change.get("op") or "")
            slugs_to_check: list[str] = []
            if op == "swap":
                from_slug = str(change.get("from_slug") or "")
                to_slug = str(change.get("to_slug") or "")
                if target_day is not None and from_slug not in day_slugs:
                    return (
                        f"当天计划里没有动作 {from_slug}；"
                        "from_slug 必须来自 app_context.plan.days[].exercises[].slug。"
                    )
                if target_day is not None and to_slug in day_slugs:
                    return f"目标动作 {to_slug} 已经在当天计划里，不能重复换入。"
                slugs_to_check = [to_slug]
            elif op == "add":
                slug = str(change.get("slug") or "")
                if target_day is not None and slug in day_slugs:
                    return f"动作 {slug} 已经在当天计划里，不需要重复添加。"
                slugs_to_check = [slug]
            else:
                slug = str(change.get("slug") or "")
                if target_day is not None and slug not in day_slugs:
                    return (
                        f"当天计划里没有动作 {slug}；"
                        "修改组数/次数/重量前必须使用当天已有的 slug。"
                    )
                slugs_to_check = [slug]

            for slug in slugs_to_check:
                if not slug:
                    continue
                exercise = db.get(Exercise, slug)
                if exercise is None:
                    suggestions = _exercise_slug_suggestions(
                        db, slug, equipment
                    )
                    return (
                        f"动作不存在：{slug}。真实动作可能包括：{suggestions}。"
                        "请先调用 lookup_exercise 确认真实 slug，不要直译英文。"
                    )
                if not exercise.is_active:
                    return f"动作 {slug} 已停用，请换一个可用动作。"
                if exercise.equipment not in equipment:
                    return (
                        f"{exercise.name_zh}({slug}) 需要 {exercise.equipment}，"
                        "当前档案没有这个器械。请换成用户已有器械的动作。"
                    )
                if banned & set(exercise.contraindications or []):
                    return (
                        f"{exercise.name_zh}({slug}) 与当前伤病限制冲突，"
                        "请换一个安全动作。"
                    )
    return None


def _reschedule_batch_error(
    run: AgentRun,
    actions: list[dict],
) -> str | None:
    reschedules = [
        action
        for action in actions
        if action.get("type") == "reschedule_training"
    ]
    if len(reschedules) <= 1:
        return None
    text = str(run.input_text or "")
    requested = re.findall(
        r"改到|改期|顺延到|挪到|换到|调到",
        text,
    )
    if len(requested) >= 2:
        return None
    if re.search(r"都|分别|整周|每一天", text):
        return None
    return (
        "用户只要求改一天；一次只能生成一张改期卡，"
        "不要顺带改其他训练日。请只保留用户明确要求的那一天。"
    )


def _validate_workout_log_exercises(
    db: Session,
    user_id: str,
    actions: list[dict],
) -> str | None:
    """Reject workout logs that name an unknown or unowned exercise.

    The model used to invent ``barbell-full-squat`` and only fail at execution
    with a 422. Returning a readable tool error lets it call lookup_exercise
    and retry before a confirmation card reaches the user.
    """
    profile = db.get(Profile, user_id)
    if profile is None:
        return None
    workout_actions = [
        action for action in actions if action.get("type") == "log_workout"
    ]
    if not workout_actions:
        return None
    equipment = set(
        available_equipment_types(
            db,
            user_id,
            list(profile.equipment or []),
        )
    )
    examples = [
        f"{row.name_zh}({row.slug})"
        for row in db.execute(
            select(Exercise)
            .where(
                Exercise.is_active.is_(True),
                Exercise.plan_eligible.is_(True),
                Exercise.equipment.in_(equipment),
            )
            .order_by(Exercise.is_compound.desc(), Exercise.name_zh)
            .limit(8)
        )
        .scalars()
        .all()
    ]
    example_text = "、".join(examples) or "暂无"
    for action in workout_actions:
        payload = action.get("payload")
        sets = payload.get("sets") if isinstance(payload, dict) else None
        if not isinstance(sets, list):
            continue
        slugs = {
            str(item.get("slug") or "")
            for item in sets
            if isinstance(item, dict) and item.get("slug")
        }
        if not slugs:
            continue
        rows = list(
            db.execute(
                select(Exercise).where(Exercise.slug.in_(slugs))
            )
            .scalars()
            .all()
        )
        by_slug = {row.slug: row for row in rows}
        missing = sorted(slugs - set(by_slug))
        if missing:
            return (
                f"动作不存在：{'、'.join(missing)}。不要编造 slug；"
                "请先调用 lookup_exercise 查真实动作。"
                f"当前可用动作示例：{example_text}。"
            )
        blocked = [
            row for row in rows if row.equipment not in equipment
        ]
        if blocked:
            names = "、".join(
                f"{row.name_zh}({row.slug})" for row in blocked
            )
            return (
                f"{names} 需要当前档案没有的器械。"
                f"当前可用器械：{'、'.join(sorted(equipment))}；"
                f"可用动作示例：{example_text}。"
                "请换成用户已有器械的动作，不要直接记录。"
            )
    return None


def _food_question_message(result: dict) -> str:
    questions = [
        str(value).strip()
        for value in (result.get("questions") or [])
        if str(value).strip()
    ]
    if len(questions) == 1:
        return questions[0]
    if questions:
        return "还有几项需要确认：\n" + "\n".join(f"· {item}" for item in questions[:2])
    return "我还需要确认一下这餐的食物或份量。"


def _build_food_log_action(
    resolution: dict,
    raw_text: str,
    date_value: str,
    meal: str,
) -> dict:
    items = resolution.get("items") or []
    if not items:
        raise ValueError("食物还没有解析出可记录的项目")
    kcal = round(
        sum(float(item.get("kcal") or 0) for item in items if isinstance(item, dict))
    )
    return _normalize_app_actions(
        [
            {
                "type": "log_food",
                "title": "记录饮食",
                "summary": f"约 {kcal} kcal",
                "requires_confirmation": True,
                "payload": {
                    "date": date_value,
                    "meal": meal,
                    "raw_text": raw_text[:500],
                    "items": items,
                },
            }
        ]
    )[0]


def _tool_result(
    db: Session,
    run: AgentRun,
    user_id: str,
    tool: str,
    arguments: dict,
    app_context: dict | None = None,
    food_resolution: dict | None = None,
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
        if kind == "goal":
            return {
                "ok": False,
                "error": (
                    "目标变更请调用 propose_app_actions + update_goal，"
                    "确认后再更新；不要写入长期记忆。"
                ),
            }
        if is_pending_action_fact(kind, content):
            return {
                "ok": False,
                "error": (
                    "这条描述的是未确认的训练/计划变更；"
                    "等用户确认并执行后再写长期记忆。"
                ),
            }
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
            limit = int(arguments.get("limit") or 5)
        except (TypeError, ValueError):
            limit = 5
        return _lookup_exercise_payload(db, query, limit)

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
        first_week_days = [
            day
            for day in plan.get("days", [])
            if int(day.get("week_index") or 0) == 1
        ]
        first_week_summary = [
            {
                "weekday": int(day.get("weekday") or 0),
                "title": str(day.get("title") or "训练"),
                "focus": list(day.get("focus") or []),
                "exercise_count": len(day.get("exercises") or []),
            }
            for day in first_week_days
        ]
        actual_weekdays = weekdays or [
            item["weekday"] for item in first_week_summary if item["weekday"]
        ]
        diff = {
            "changes": changes,
            "base": _program_summary(old_program),
            "proposed": {
                "title": plan.get("title"),
                "weekly_days": len(first_week_days) or weekly_days,
                "weekdays": actual_weekdays,
                "day_titles": [
                    item["title"] for item in first_week_summary
                ],
                "days": first_week_summary,
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
            actions = _normalize_app_actions(
                arguments.get("actions"),
                app_context,
                food_resolution=food_resolution,
            )
            workout_error = _validate_workout_log_exercises(
                db, user_id, actions
            )
            if workout_error is not None:
                return {"ok": False, "error": workout_error}
            modify_error = _modify_workout_validation_error(
                db, user_id, actions, app_context
            )
            if modify_error is not None:
                return {"ok": False, "error": modify_error}
            reschedule_error = _reschedule_batch_error(run, actions)
            if reschedule_error is not None:
                return {"ok": False, "error": reschedule_error}
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
    from .coach_control.progression import build_plan as build_progression_plan
    from .coach_control.readiness import snapshot as readiness_snapshot

    readiness = readiness_snapshot(db, user_id, now=now)
    progression = build_progression_plan(db, user_id, program)
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

    # Adaptive periodization: the 7-day load against the 28-day average decides
    # whether next week should deload, hold, or progress. This is deterministic
    # and runs even when the user never records sleep or HRV.
    if readiness["status"] == "high_risk":
        if "近 7 天负荷明显高于前 3 周平均" not in watchouts:
            watchouts.append("近 7 天负荷明显高于前 3 周平均")
        if not any("减载" in item for item in actions):
            actions.append(
                "下周安排减载：主项降 1 组或 5% 重量，RPE 控制在 7–8，"
                "连续两天疲劳就休息"
            )
    elif readiness["status"] == "strained":
        if not any("降 1 组" in item for item in actions):
            actions.append("下一次同动作降 1 组，先不加重量，把 RPE 压到 7–8")
    elif readiness["status"] == "fresh":
        if not any("加 2.5%" in item for item in actions):
            actions.append("恢复窗口充足，下一次主项稳定时可加 2.5% 或 +1 次")

    if progression.get("ready"):
        changed = [
            item
            for item in progression.get("targets") or []
            if item.get("action") in {"up", "down"}
            and item.get("target_weight_kg") is not None
        ]
        if changed:
            preview = "、".join(
                f"{item['name']} {float(item['current_weight_kg']):g}"
                f"→{float(item['target_weight_kg']):g}kg"
                for item in changed[:2]
            )
            actions.append(f"下周按动作调整：{preview}；可在教练里确认后写入")

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
            "readiness_status": readiness["status"],
            "acute_load": readiness["acute_load"],
            "chronic_weekly_load": readiness["chronic_weekly_load"],
            "acwr": readiness["acwr"],
            "progression_ready": bool(progression.get("ready")),
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
        "readiness": readiness,
        "progression": progression,
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
            "pending_draft": compact_draft(
                get_active_draft(db, user_id, session_id)
            ),
            "elapsed_ms": int((time.perf_counter() - started) * 1000),
            "usage": usage,
            "error": None,
        }

    draft = get_active_draft(db, user_id, session_id)
    if draft is not None and _is_draft_answer(message):
        try:
            return await _handle_draft_turn(
                db, run, user_id, session_id, message, started, usage
            )
        except LookupError:
            # Draft expired or was cancelled between read and write; fall
            # through to the normal model path.
            pass

    try:
        correction = await _multi_intent_action_turn(
            db,
            user_id,
            message,
            app_context,
        )
    except Exception:
        correction = None
    if correction is None:
        try:
            replacement = await _pending_food_replacement(
                db,
                user_id,
                app_context,
                message,
            )
        except Exception:
            replacement = None
        if replacement is not None:
            correction = replacement
        else:
            try:
                correction = _pending_action_correction(app_context, message)
            except Exception:
                correction = None
    if correction is not None:
        actions = correction["actions"]
        final_message = correction["reply"]
        run.intent = "app_action" if actions else "clarification"
        run.status = "needs_confirmation" if actions else "completed"
        run.output_text = final_message
        run.completed_at = utcnow()
        _record_step(
            db,
            run,
            "tool",
            tool_name="update_pending_action",
            input_data={"message": message[:200]},
            output_data={"actions": actions},
        )
        if actions and session_id:
            cancel_active_draft(db, user_id, session_id)
        db.commit()
        return {
            "run_id": run.id,
            "status": run.status,
            "reply": final_message,
            "proposal": None,
            "actions": actions,
            "safety_flag": None,
            "citations": [],
            "pending_draft": None,
            "elapsed_ms": int((time.perf_counter() - started) * 1000),
            "usage": usage,
            "error": None,
        }

    deterministic = _deterministic_extra_turn(
        db,
        user_id,
        message,
        app_context,
    )
    if deterministic is not None:
        actions = deterministic["actions"]
        final_message = deterministic["reply"]
        run.intent = "app_action" if actions else "clarification"
        run.status = "needs_confirmation" if actions else "completed"
        run.output_text = final_message
        run.completed_at = utcnow()
        _record_step(
            db,
            run,
            "tool",
            tool_name="deterministic_action",
            input_data={"message": message[:200]},
            output_data={"actions": actions},
        )
        if actions and session_id:
            cancel_active_draft(db, user_id, session_id)
        db.commit()
        return {
            "run_id": run.id,
            "status": run.status,
            "reply": final_message,
            "proposal": None,
            "actions": actions,
            "safety_flag": None,
            "citations": [],
            "pending_draft": None,
            "elapsed_ms": int((time.perf_counter() - started) * 1000),
            "usage": usage,
            "error": None,
        }

    if _looks_like_regenerate_plan_request(message):
        proposal_result = _tool_result(
            db,
            run,
            user_id,
            "propose_plan",
            {},
            app_context,
        )
        if (
            proposal_result.get("ok")
            and isinstance(proposal_result.get("proposal"), dict)
        ):
            proposal_data = proposal_result["proposal"]
            final_message = (
                "新计划草案已经生成，确认后才会替换当前计划。"
            )
            run.intent = "plan_change"
            run.status = "needs_confirmation"
            run.output_text = final_message
            run.completed_at = utcnow()
            _record_step(
                db,
                run,
                "tool",
                tool_name="propose_plan",
                output_data=proposal_result,
            )
            if session_id:
                cancel_active_draft(db, user_id, session_id)
            db.commit()
            return {
                "run_id": run.id,
                "status": run.status,
                "reply": final_message,
                "proposal": proposal_data,
                "actions": [],
                "safety_flag": None,
                "citations": [],
                "pending_draft": None,
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
            food_context = food_log_context(message)
            state = {
                "user_message": message,
                "current_date": (
                    (coach_context.get("today") or {}).get("date")
                    or datetime.now(timezone.utc).date().isoformat()
                ),
                "food_context": food_context,
                "coach_context": coach_context,
                "safety_context": decision.caution,
                "history": [
                    {"role": item.role, "content": item.content[:1000]}
                    for item in (history or [])[-10:]
                    if item.role in {"user", "assistant"}
                ],
                "app_context": _safe_json(app_context or {}),
                "pending_draft": draft_context(
                    get_active_draft(db, user_id, session_id)
                ),
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
            food_resolution: dict | None = None
            food_date = food_context["date"]
            food_meal = food_context["meal"]
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
                            draft_id = str(arguments.get("draft_id") or "").strip()
                            if not text:
                                result = {
                                    "ok": False,
                                    "error": "resolve_food requires text",
                                }
                            elif draft_id:
                                active_draft = get_active_draft(
                                    db, user_id, session_id
                                )
                                if needs_raw_clarification(active_draft):
                                    answer = await _resolve_raw_draft(
                                        db, user_id, session_id, text
                                    )
                                else:
                                    answer = answer_food_draft(
                                        db, user_id, session_id, text
                                    )
                                if answer is None:
                                    result = {
                                        "ok": False,
                                        "error": "草稿已过期或不存在，请重新描述这餐",
                                    }
                                else:
                                    result = {"ok": True, **answer}
                            else:
                                target = parse_food_date(text)
                                if target is None:
                                    raw_date = str(
                                        arguments.get("date") or ""
                                    ).strip()
                                    if raw_date:
                                        try:
                                            target = date.fromisoformat(raw_date)
                                        except ValueError:
                                            target = None
                                if target is None:
                                    target = date.fromisoformat(food_context["date"])
                                parsed_meal = parse_meal(text)
                                meal = (
                                    parsed_meal
                                    or str(arguments.get("meal") or "").strip()
                                    or food_context["meal"]
                                )
                                if meal not in {
                                    "breakfast",
                                    "lunch",
                                    "dinner",
                                    "snack",
                                }:
                                    meal = food_context["meal"]
                                resolution = await resolve_food_text(
                                    db,
                                    user_id,
                                    text,
                                    meal=meal,
                                    target_date=target,
                                )
                                food_date = target.isoformat()
                                food_meal = meal
                                draft = create_food_draft(
                                    db,
                                    user_id,
                                    session_id,
                                    date=food_date,
                                    meal=meal,
                                    raw_text=text,
                                    resolution=resolution,
                                )
                                result = {
                                    "ok": True,
                                    **resolution,
                                    "date": food_date,
                                    "meal": food_meal,
                                    "text": text,
                                    "draft_id": draft.id if draft else None,
                                    "ready": not resolution.get("missing_slots")
                                    and not resolution.get("questions"),
                                }
                        else:
                            result = _tool_result(
                                db,
                                run,
                                user_id,
                                tool,
                                arguments,
                                app_context,
                                food_resolution=food_resolution,
                            )
                        status = "ok" if result.get("ok", True) else "error"
                        if forced_food_log and tool == "propose_app_actions":
                            proposed = result.get("actions")
                            if (
                                isinstance(proposed, list)
                                and any(
                                    isinstance(item, dict)
                                    and item.get("type") == "log_food"
                                    for item in proposed
                                )
                                and food_resolution is None
                            ):
                                result = {
                                    "ok": False,
                                    "error": (
                                        "记录饮食必须先调用 resolve_food，"
                                        "不能直接生成食物和热量。"
                                    ),
                                }
                                status = "error"
                                proposed = []
                            food_types = {
                                "log_food",
                                "log_planned_meal",
                                "skip_planned_meal",
                                "restore_planned_meal",
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
                    if tool == "resolve_food":
                        food_resolution = result
                        food_date = str(result.get("date") or food_date)
                        food_meal = str(result.get("meal") or food_meal)
                        if not result.get("ready", True):
                            # Slot filling is deterministic: ask one question
                            # and end the turn instead of letting the model
                            # keep retrying and eventually invent nutrition.
                            final_message = _food_question_message(result)
                            actions = []
                            run.intent = "clarification"
                            break
                        if forced_food_log:
                            try:
                                action = _build_food_log_action(
                                    result,
                                    message,
                                    food_date,
                                    food_meal,
                                )
                                actions = [action]
                                final_message = (
                                    f"已识别 {len(action['payload']['items'])} 种食物，"
                                    f"{action['summary']}。确认后写入。"
                                )
                            except ValueError as exc:
                                final_message = str(exc)
                                actions = []
                            break
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
            if actions:
                final_message = "操作已经准备好，请确认后执行。"
            elif proposal is not None:
                final_message = "计划草案已经生成，请确认。"
            else:
                final_message = (
                    "这次请求没有完成，可能是网络或模型服务异常。"
                    "请重试一次；如果是记录饮食，也可以直接到饮食页手动添加。"
                )
                error = error or "agent_max_steps"
                run.status = "failed"
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

        if actions and session_id:
            # A card and a draft are mutually exclusive. The card is the
            # authoritative next step; a stale draft must not keep asking the
            # same question underneath it.
            cancel_active_draft(db, user_id, session_id)

        if proposal is not None or any(
            item.get("requires_confirmation") for item in actions
        ):
            final_message = _guard_pending_action_claims(final_message)
            run.status = "needs_confirmation"
        elif run.status == "running":
            run.status = "completed"
        final_message = _guard_permission_claims(final_message)
        final_message = _guard_action_card_claims(
            final_message,
            actions,
            proposal,
            compact_draft(get_active_draft(db, user_id, session_id)),
        )
        final_message = _guard_goal_action_consistency(
            final_message,
            actions,
        )
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
        if (
            not settings.use_mock_llm
            and run.status not in {"failed", "needs_confirmation"}
        ):
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
        "pending_draft": compact_draft(
            get_active_draft(db, user_id, session_id)
        ),
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
