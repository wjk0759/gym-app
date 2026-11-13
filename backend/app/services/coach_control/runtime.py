"""Coach runtime for the first control-plane slices.

The model is not allowed to write here. Intent resolution chooses a capability;
the capability resolves facts, the server builds the card, and confirmation
executes through the action ledger.
"""

from __future__ import annotations

import re
import time
from uuid import uuid4

from sqlalchemy import select
from sqlalchemy.orm import Session

from ...models import CoachActionRecord, CoachPending, CoachSession, CoachTurn, utcnow
from . import capabilities  # noqa: F401 - registers capabilities
from .events import emit_event
from .state import (
    cancel_active_pending,
    cancel_pending,
    consume_pending,
    get_active_pending,
    get_or_create_session,
    serialize_pending,
    serialize_session,
    set_pending,
)

DIET = "diet.log_food"
PLANNED = "diet.log_planned_meal"
SKIP_MEAL = "diet.skip_planned_meal"
RESTORE_MEAL = "diet.restore_planned_meal"
SWAP_MEAL = "diet.swap_meal"
TRAINING = "training.reschedule"
SKIP_TRAINING = "training.skip"
CARDIO = "training.log_cardio"
WEIGHT = "body.log_weight"
REVIEW = "review.weekly"
GOAL = "profile.update_goal"


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


def _looks_like_goal(message: str) -> bool:
    if re.search(r"怎么|多少|为什么|吗|？|\?", message):
        return False
    return bool(
        re.search(r"目标|减脂|减肥|增肌|塑形|重塑|耐力|体能", message)
        and re.search(r"\d|月|日|前", message)
    )


def _looks_like_review(message: str) -> bool:
    return bool(re.search(r"复盘|本周总结|这周怎么样|这周状态|周报", message))


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


def _looks_like_weight(message: str) -> bool:
    return bool(
        re.search(r"体重|称重|称了|称一下", message)
        and re.search(r"\d", message)
    )


def _looks_like_food(message: str) -> bool:
    if re.search(r"多少|热量|卡路里|为什么|怎么|吗|？|\?", message):
        return False
    if re.search(r"记|吃|喝|补|餐|零食|夜宵", message):
        return True
    return bool(
        re.search(
            r"\d+(?:\.\d+)?\s*(g|克|ml|毫升|杯|份|碗|个|片|勺|盒|瓶)",
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


def _food_reply(resolution: dict) -> str:
    items = resolution.get("items") or []
    kcal = round(sum(float(item.get("kcal") or 0) for item in items))
    return f"已识别 {len(items)} 种食物，约 {kcal} kcal。确认后写入。"


def _training_reply(payload: dict) -> str:
    return (
        f"准备把「{payload.get('title') or '训练'}」"
        f"从 {payload.get('from_date')} 改到 {payload.get('to_date')}。确认后生效。"
    )


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
    context = app_context if isinstance(app_context, dict) else {}
    text = message.strip()
    turn = CoachTurn(
        session_id=session.id,
        user_id=user_id,
        input_text=text[:4000],
        status="running",
    )
    db.add(turn)
    db.flush()

    pending = get_active_pending(db, user_id, session.id)
    if pending is not None and re.search(r"取消|不要了|算了|不记了", text):
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
    # A new user turn supersedes an old card. Confirmation/cancel should use
    # the dedicated endpoints; typing a new request means the old card is stale.
    if pending is not None and pending.kind in {"card", "insight"}:
        cancel_active_pending(db, session)
        pending = None

    intent_override: str | None = None
    if pending is not None and pending.kind == "draft":
        if pending.capability_id == DIET:
            if not _looks_like_diet_slot_answer(text):
                cancel_pending(db, session, pending)
                pending = None
            else:
                text = f"{pending.payload.get('text') or ''} {text}".strip()[:2000]
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
            reply = f"准备记录体重 {payload['weight_kg']} kg。确认后写入。"
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

        resolution = await resolve_diet(db, user_id, text)
        if resolution.get("questions") or resolution.get("missing_slots"):
            question = (resolution.get("questions") or ["这餐还需要补充信息。"])[0]
            _pending_draft(
                db,
                session,
                capability_id=DIET,
                payload={
                    "text": text,
                    "date": resolution.get("date"),
                    "meal": resolution.get("meal"),
                    "questions": resolution.get("questions") or [],
                },
            )
            reply = question
            turn.intent = DIET
        else:
            payload = {
                "date": resolution["date"],
                "meal": resolution["meal"],
                "raw_text": text[:500],
                "items": resolution.get("items") or [],
            }
            _pending_card(
                db,
                session,
                capability_id=DIET,
                payload=payload,
            )
            reply = _food_reply(resolution)
            turn.intent = DIET
    else:
        reply = (
            "这条控制链路目前支持记录饮食和调整训练日期。"
            "你可以说“午餐吃了100克鸡胸肉”，或者说“把周四的训练改到周六”。"
        )
        turn.intent = "unsupported"

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


def _load_pending(db: Session, user_id: str, pending_id: str) -> tuple[CoachSession, CoachPending]:
    pending = db.get(CoachPending, pending_id)
    if pending is None or pending.user_id != user_id:
        raise LookupError("待确认操作不存在")
    session = db.get(CoachSession, pending.session_id)
    if session is None or session.user_id != user_id:
        raise LookupError("会话不存在")
    return session, pending


def confirm_pending(db: Session, user_id: str, pending_id: str) -> dict:
    session, pending = _load_pending(db, user_id, pending_id)
    if pending.status != "pending" or pending.kind != "card":
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
            "idempotent": True,
        }
    if existing is not None and existing.status == "undone":
        raise ValueError("这次操作已经撤销，请重新生成")

    receipt: dict
    before: dict = {}
    after: dict = {}
    if pending.capability_id == DIET:
        from .capabilities.diet import execute as execute_diet

        result = execute_diet(db, user_id, action_id, pending.payload)
        receipt = {
            "summary": "已写入饮食记录",
            "date": pending.payload.get("date"),
            "meal": pending.payload.get("meal"),
            "items": len(result.get("created_logs") or []),
            "deep_link": f"fitai://nutrition/{pending.payload.get('date')}",
        }
        after = {"created_logs": result.get("created_logs") or []}
        event_type = "FoodLogged"
        entity_type = "food_log"
        entity_id = action_id
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
            "summary": f"已记录体重 {pending.payload.get('weight_kg')} kg",
            "date": pending.payload.get("date"),
            "deep_link": "fitai://profile",
        }
        event_type = "BodyMetricLogged"
        entity_type = "body_metric"
        entity_id = action_id
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
    emit_event(
        db,
        user_id,
        event_type,
        entity_type=entity_type,
        entity_id=entity_id,
        payload={"action_id": action_id, "receipt": receipt},
    )
    consume_pending(db, session, pending)
    db.commit()
    return {
        "action_id": action_id,
        "status": "executed",
        "receipt": receipt,
        "idempotent": False,
    }


def cancel(db: Session, user_id: str, pending_id: str) -> dict:
    session, pending = _load_pending(db, user_id, pending_id)
    if pending.status != "pending":
        return {"ok": True, "already": True}
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
    if record.capability_id == DIET:
        from .capabilities.diet import undo as undo_diet

        result = undo_diet(db, user_id, action_id, record.payload)
    elif record.capability_id == TRAINING:
        from .capabilities.training import undo as undo_training

        result = undo_training(
            db,
            user_id,
            action_id,
            record.payload,
            record.before or {},
        )
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
    elif record.capability_id == CARDIO:
        from .capabilities.training import undo_cardio

        result = undo_cardio(db, user_id, action_id, record.payload)
    elif record.capability_id == WEIGHT:
        from .capabilities.body import undo as undo_weight

        result = undo_weight(db, user_id, action_id, record.payload)
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
    return {"action_id": action_id, "status": "undone", "result": result}


def session_state(db: Session, user_id: str, session_id: str) -> dict:
    session = db.get(CoachSession, session_id)
    if session is None or session.user_id != user_id:
        raise LookupError("会话不存在")
    pending = get_active_pending(db, user_id, session.id)
    return serialize_session(session, pending)
