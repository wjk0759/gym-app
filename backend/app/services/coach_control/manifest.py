"""Declarative action specs for coach routing and UI cards.

The registry owns execution metadata; this manifest owns the language surface:
example utterances, slot names and the card family. A future LLM fallback
router can use this catalogue without touching the deterministic runtime.
"""

from __future__ import annotations

from dataclasses import dataclass


@dataclass(frozen=True)
class ActionSpec:
    id: str
    examples: tuple[str, ...]
    slots: tuple[str, ...] = ()
    card: str = "generic"


ACTION_SPECS: dict[str, ActionSpec] = {
    "body.log_weight": ActionSpec(
        "body.log_weight",
        ("今天体重73kg", "体脂22%，腰围84cm", "记录一下体重72.5"),
        ("date", "weight_kg", "body_fat_pct", "waist_cm"),
        "metric",
    ),
    "body.review_trend": ActionSpec(
        "body.review_trend",
        ("最近体重怎么样", "我的体脂趋势如何", "腰围有变化吗"),
        ("metric", "range"),
        "insight",
    ),
    "body.delete_metric": ActionSpec(
        "body.delete_metric",
        (
            "删掉今天的体重记录",
            "删除最近一条体脂记录",
            "把昨天腰围记录去掉",
        ),
        ("date", "metric_id", "fields"),
        "generic",
    ),
    "coach.answer": ActionSpec(
        "coach.answer",
        ("减脂怎么吃", "今天状态不好怎么办", "深蹲膝盖疼正常吗"),
        (),
        "text",
    ),
    "diet.log_food": ActionSpec(
        "diet.log_food",
        ("午饭吃了鸡胸肉200g", "早餐两个鸡蛋一杯牛奶", "晚饭干蒸牛肉加米饭"),
        ("date", "meal", "items"),
        "food",
    ),
    "diet.log_planned_meal": ActionSpec(
        "diet.log_planned_meal",
        ("按计划吃午餐", "今天晚餐就按餐单来"),
        ("date", "meal"),
        "food",
    ),
    "diet.skip_planned_meal": ActionSpec(
        "diet.skip_planned_meal",
        ("跳过今天晚餐", "午餐不吃了"),
        ("date", "meal"),
        "food",
    ),
    "diet.restore_planned_meal": ActionSpec(
        "diet.restore_planned_meal",
        ("恢复今天晚餐", "午餐还是按计划吃"),
        ("date", "meal"),
        "food",
    ),
    "diet.swap_meal": ActionSpec(
        "diet.swap_meal",
        ("晚餐换一份", "午餐换掉", "今天晚餐换成鱼"),
        ("date", "meal"),
        "food",
    ),
    "diet.edit_day_strategy": ActionSpec(
        "diet.edit_day_strategy",
        ("明天改成低碳", "今天饮食换成高蛋白", "周三用碳循环"),
        ("date", "strategy"),
        "food",
    ),
    "diet.generate_day": ActionSpec(
        "diet.generate_day",
        ("帮我排明天的餐", "生成今天的饮食计划", "安排一份高蛋白餐单"),
        ("date", "strategy"),
        "food",
    ),
    "diet.review_day": ActionSpec(
        "diet.review_day",
        ("今天饮食缺什么", "今天吃了多少热量", "看看今天的营养"),
        ("date",),
        "insight",
    ),
    "diet.generate_week": ActionSpec(
        "diet.generate_week",
        ("排一周饮食", "生成下周餐单", "做七天饮食计划"),
        ("week_start", "strategy"),
        "food",
    ),
    "diet.update_log": ActionSpec(
        "diet.update_log",
        ("把午饭的鸡胸肉改成150g", "早餐鸡蛋改成两个", "那条饮食记录热量改成300"),
        ("client_id", "date", "meal", "items"),
        "food",
    ),
    "diet.delete_log": ActionSpec(
        "diet.delete_log",
        ("删掉午饭的鸡胸肉", "删除刚才那条饮食记录"),
        ("client_id",),
        "food",
    ),
    "training.update_workout": ActionSpec(
        "training.update_workout",
        ("把今天跑步改成40分钟", "刚才的训练改成45分钟"),
        ("session_id", "duration_minutes", "sets", "notes"),
        "training",
    ),
    "training.delete_workout": ActionSpec(
        "training.delete_workout",
        ("删掉今天跑步记录", "删除刚才那次训练"),
        ("session_id",),
        "training",
    ),
    "memory.remember": ActionSpec(
        "memory.remember",
        ("记住我每周二四六练", "记一下我不喜欢跑步", "以后都晚上训练"),
        ("content",),
        "memory",
    ),
    "training.generate_plan": ActionSpec(
        "training.generate_plan",
        ("帮我生成一个4周计划", "重新做一份训练计划", "给我新的训练计划"),
        ("weeks", "split", "focus", "equipment"),
        "plan",
    ),
    "training.adjust_plan": ActionSpec(
        "training.adjust_plan",
        ("计划太满了，减量", "最近太忙，训练计划调整一下", "计划太累，降低强度"),
        ("adjustment",),
        "plan",
    ),
    "training.configure_plan": ActionSpec(
        "training.configure_plan",
        (
            "每周3练，二四六，45分钟，3分化",
            "把计划改成一周四练",
            "训练日改成周一三五",
        ),
        ("weekly_days", "weekdays", "session_minutes", "split"),
        "plan",
    ),
    "training.restore_plan": ActionSpec(
        "training.restore_plan",
        (
            "恢复上一版计划",
            "回到之前那版训练计划",
            "恢复版本2",
        ),
        ("program_id", "version"),
        "plan",
    ),
    "profile.update_goal": ActionSpec(
        "profile.update_goal",
        ("我想减脂到72kg", "目标改成增肌", "目标体重75kg，明年2月前"),
        ("goal_type", "target_weight_kg", "target_date"),
        "profile",
    ),
    "review.weekly": ActionSpec(
        "review.weekly",
        ("复盘本周", "这周训练怎么样", "给我周报"),
        (),
        "insight",
    ),
    "training.reschedule": ActionSpec(
        "training.reschedule",
        ("把今天训练改到明天", "周三的训练挪到周四", "改到后天"),
        ("day_id", "from_date", "to_date"),
        "training",
    ),
    "training.log_cardio": ActionSpec(
        "training.log_cardio",
        ("今天跑步30分钟", "刚骑了20分钟单车", "记录一次有氧"),
        ("date", "title", "duration_minutes"),
        "training",
    ),
    "training.skip": ActionSpec(
        "training.skip",
        ("今天不练了", "跳过今天的训练", "今天休息"),
        ("day_id", "date"),
        "training",
    ),
    "training.log_strength": ActionSpec(
        "training.log_strength",
        ("今天卧推60kg 8次3组", "深蹲80公斤做了4组", "记录今天的硬拉"),
        ("date", "title", "sets"),
        "training",
    ),
    "training.add_plan_day": ActionSpec(
        "training.add_plan_day",
        ("今天想练背", "明天加一次腿", "补一次胸"),
        ("date", "focus", "exercises"),
        "training",
    ),
    "training.edit_day_exercises": ActionSpec(
        "training.edit_day_exercises",
        ("把今天的胸改成这几个动作", "把周三的训练换成背"),
        ("day_id", "date", "exercises"),
        "training",
    ),
    "training.edit_day_exercise": ActionSpec(
        "training.edit_day_exercise",
        ("卧推换成哑铃卧推", "深蹲改成腿举"),
        ("day_id", "exercise_slug", "replacement_slug"),
        "training",
    ),
    "training.preview_next": ActionSpec(
        "training.preview_next",
        ("今天练什么", "明天练什么", "下一练是什么"),
        ("date",),
        "insight",
    ),
    "training.week_schedule": ActionSpec(
        "training.week_schedule",
        ("这周怎么安排", "下周练什么", "本周训练安排"),
        ("week_start",),
        "insight",
    ),
    "ui.start_training": ActionSpec(
        "ui.start_training",
        ("开始训练", "带我练", "开始今天的训练"),
        (),
        "ui",
    ),
    "ui.open_screen": ActionSpec(
        "ui.open_screen",
        ("打开训练记录", "看看饮食", "进入设置"),
        ("screen",),
        "ui",
    ),
    "ui.configure_reminders": ActionSpec(
        "ui.configure_reminders",
        ("把训练提醒改成早上8点", "关闭提醒", "每天20:30提醒我训练"),
        ("enabled", "hour", "minute"),
        "ui",
    ),
}


def spec_for(capability_id: str) -> ActionSpec | None:
    return ACTION_SPECS.get(capability_id)
