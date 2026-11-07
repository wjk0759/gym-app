"""Canonical gym-equipment catalog for photo recognition.

The vision model does not invent exercise names. It picks one equipment type
from this catalog, then the backend maps that equipment to actions that already
exist in the active exercise library. Keeping the catalog in code makes the
prompt, aliases and action mapping reviewable in one place.
"""

from __future__ import annotations

from dataclasses import dataclass


@dataclass(frozen=True)
class EquipmentType:
    slug: str
    name_zh: str
    name_en: str
    aliases: tuple[str, ...]
    category: str
    exercise_slugs: tuple[str, ...] = ()


CATALOG: tuple[EquipmentType, ...] = (
    EquipmentType(
        "leg_press",
        "腿举机",
        "Leg Press",
        ("腿举", "倒蹬", "倒蹬机", "45度腿举", "哈克腿举", "leg press"),
        "machine",
        ("cm_leg_press", "cm_hack_squat"),
    ),
    EquipmentType(
        "hack_squat",
        "哈克深蹲机",
        "Hack Squat",
        ("哈克", "哈克机", "哈克深蹲", "hack squat", "linear hack press"),
        "machine",
        ("cm_hack_squat", "cm_leg_press"),
    ),
    EquipmentType(
        "pec_deck",
        "蝴蝶机",
        "Pec Deck",
        (
            "蝴蝶机夹胸",
            "夹胸机",
            "蝴蝶机反向飞鸟",
            "pec deck",
            "chest fly machine",
            "butterfly machine",
        ),
        "machine",
        ("cm_pec_deck", "cm_reverse_fly"),
    ),
    EquipmentType(
        "chest_press_machine",
        "坐姿推胸机",
        "Chest Press Machine",
        ("推胸机", "坐姿推胸", "器械推胸", "chest press", "seated chest press"),
        "machine",
        ("cm_machine_chest_press", "cm_bench_press", "cm_dumbbell_press"),
    ),
    EquipmentType(
        "cable_station",
        "龙门架 / 绳索训练站",
        "Cable Station",
        (
            "龙门架",
            "大飞鸟",
            "绳索训练器",
            "绳索站",
            "functional trainer",
            "cable crossover",
            "dual cable",
            "pulley machine",
        ),
        "cable",
        (
            "cm_cable_fly",
            "cm_triceps_pushdown",
            "cm_seated_row",
            "cm_face_pull",
            "cm_straight_arm_pulldown",
            "cm_cable_crunch",
            "cm_cable_kickback",
        ),
    ),
    EquipmentType(
        "lat_pulldown",
        "高位下拉机",
        "Lat Pulldown",
        ("高位下拉", "下拉机", "lat pulldown", "cable lat pulldown"),
        "machine",
        ("cm_lat_pulldown",),
    ),
    EquipmentType(
        "seated_row",
        "坐姿划船机",
        "Seated Cable Row",
        ("坐姿划船", "划船机", "seated row", "seated cable row", "back row machine"),
        "machine",
        ("cm_seated_row", "cm_tbar_row", "cm_barbell_row"),
    ),
    EquipmentType(
        "leg_extension",
        "腿屈伸机",
        "Leg Extension",
        ("腿屈伸", "坐姿腿屈伸", "leg extension"),
        "machine",
        ("cm_leg_extension",),
    ),
    EquipmentType(
        "leg_curl",
        "腿弯举机",
        "Leg Curl",
        (
            "腿弯举",
            "俯卧腿弯举",
            "坐姿腿弯举",
            "lying leg curl",
            "seated leg curl",
            "leg curl",
        ),
        "machine",
        ("cm_leg_curl",),
    ),
    EquipmentType(
        "hip_abduction",
        "髋外展机",
        "Hip Abduction",
        ("髋外展", "坐姿外展", "hip abduction", "abductor machine"),
        "machine",
        ("cm_hip_abduction",),
    ),
    EquipmentType(
        "hip_adduction",
        "髋内收机",
        "Hip Adduction",
        ("髋内收", "坐姿内收", "hip adduction", "adductor machine"),
        "machine",
        ("cm_hip_adduction",),
    ),
    EquipmentType(
        "hip_thrust",
        "臀推机",
        "Hip Thrust Machine",
        ("臀推", "臀推机", "臀推架", "hip thrust", "glute drive"),
        "machine",
        ("cm_hip_thrust", "cm_glute_bridge"),
    ),
    EquipmentType(
        "smith_machine",
        "史密斯机",
        "Smith Machine",
        ("史密斯", "史密斯架", "smith", "smith machine"),
        "machine",
        (
            "cm_squat",
            "cm_bench_press",
            "cm_barbell_row",
            "cm_machine_shoulder_press",
            "cm_front_squat",
        ),
    ),
    EquipmentType(
        "squat_rack",
        "深蹲架",
        "Squat Rack",
        ("深蹲架", "力量架", "power rack", "squat rack", "half rack"),
        "free_weight",
        ("cm_squat", "cm_front_squat", "cm_barbell_row", "cm_bench_press"),
    ),
    EquipmentType(
        "bench_press",
        "卧推凳",
        "Bench Press",
        ("卧推", "卧推凳", "平板卧推", "bench press", "flat bench"),
        "free_weight",
        ("cm_bench_press", "cm_dumbbell_press", "cm_close_grip_bench"),
    ),
    EquipmentType(
        "incline_bench",
        "上斜卧推凳",
        "Incline Bench",
        ("上斜卧推", "上斜凳", "incline bench", "incline press"),
        "free_weight",
        ("cm_incline_bench_press", "cm_dumbbell_press"),
    ),
    EquipmentType(
        "shoulder_press_machine",
        "推肩机",
        "Shoulder Press Machine",
        ("推肩机", "坐姿推举", "器械推举", "shoulder press machine", "overhead press machine"),
        "machine",
        ("cm_machine_shoulder_press", "cm_shoulder_press"),
    ),
    EquipmentType(
        "lateral_raise_machine",
        "侧平举机",
        "Lateral Raise Machine",
        ("侧平举机", "lateral raise machine"),
        "machine",
        ("cm_lateral_raise",),
    ),
    EquipmentType(
        "preacher_bench",
        "牧师凳",
        "Preacher Bench",
        ("牧师凳", "牧师椅", "preacher bench", "preacher curl"),
        "free_weight",
        ("cm_preacher_curl",),
    ),
    EquipmentType(
        "back_extension",
        "山羊挺身架",
        "Back Extension Bench",
        ("山羊挺身", "罗马椅", "背伸展", "back extension", "roman chair"),
        "free_weight",
        ("cm_back_extension", "cm_glute_bridge"),
    ),
    EquipmentType(
        "ab_machine",
        "卷腹机",
        "Ab Crunch Machine",
        ("卷腹机", "腹肌机", "ab machine", "abdominal machine", "crunch machine"),
        "machine",
        ("cm_cable_crunch", "cm_crunch"),
    ),
    EquipmentType(
        "torso_rotation",
        "转体机",
        "Torso Rotation Machine",
        ("转体机", "躯干旋转", "torso rotation"),
        "machine",
    ),
    EquipmentType(
        "pullup_bar",
        "引体向上架",
        "Pull-up Bar",
        ("引体架", "单杠", "pull up bar", "chin up bar"),
        "bodyweight_station",
        ("cm_pullup",),
    ),
    EquipmentType(
        "dip_station",
        "双杠架",
        "Dip Station",
        ("双杠", "臂屈伸架", "dip station", "parallel bars"),
        "bodyweight_station",
        ("cm_dip", "cm_pullup"),
    ),
    EquipmentType(
        "assisted_pullup",
        "助力引体机",
        "Assisted Pull-up / Dip",
        ("助力引体", "引体助力机", "dip chin assist", "assisted pull up"),
        "machine",
        ("cm_pullup", "cm_dip"),
    ),
    EquipmentType(
        "calf_raise",
        "提踵机",
        "Calf Raise Machine",
        ("提踵机", "站姿提踵", "坐姿提踵", "calf raise"),
        "machine",
        ("cm_standing_calf_raise", "cm_seated_calf_raise"),
    ),
    EquipmentType(
        "glute_kickback",
        "后踢机",
        "Glute Kickback Machine",
        ("后踢机", "臀踢", "glute kickback", "kickback machine"),
        "machine",
        ("cm_cable_kickback",),
    ),
    EquipmentType(
        "treadmill",
        "跑步机",
        "Treadmill",
        ("跑步机", "treadmill", "run"),
        "cardio",
        ("cm_treadmill",),
    ),
    EquipmentType(
        "elliptical",
        "椭圆机",
        "Elliptical",
        ("椭圆机", "elliptical", "cross trainer"),
        "cardio",
        ("cm_elliptical",),
    ),
    EquipmentType(
        "rowing_machine",
        "划船机",
        "Rowing Machine",
        ("划船机", "rower", "rowing machine", "concept2"),
        "cardio",
        ("cm_rowing_machine",),
    ),
    EquipmentType(
        "stationary_bike",
        "动感单车",
        "Stationary Bike",
        ("动感单车", "健身车", "spin bike", "stationary bike", "exercise bike"),
        "cardio",
        ("cm_stationary_bike",),
    ),
    EquipmentType(
        "stair_climber",
        "爬楼机",
        "Stair Climber",
        ("爬楼机", "台阶机", "stairmaster", "stair climber", "stepmill"),
        "cardio",
    ),
    EquipmentType(
        "dumbbell_rack",
        "哑铃架",
        "Dumbbell Rack",
        ("哑铃架", "哑铃区", "dumbbell rack"),
        "free_weight",
        (
            "cm_dumbbell_press",
            "cm_dumbbell_row",
            "cm_dumbbell_curl",
            "cm_lateral_raise",
            "cm_hammer_curl",
        ),
    ),
    EquipmentType(
        "barbell_rack",
        "杠铃架",
        "Barbell Rack",
        ("杠铃架", "杠铃片", "barbell rack", "weight plates"),
        "free_weight",
        ("cm_squat", "cm_bench_press", "cm_barbell_row", "cm_romanian_deadlift"),
    ),
    EquipmentType(
        "kettlebell",
        "壶铃",
        "Kettlebell",
        ("壶铃", "kettlebell"),
        "free_weight",
    ),
    EquipmentType(
        "battle_rope",
        "战绳",
        "Battle Rope",
        ("战绳", "battle rope"),
        "accessory",
    ),
    EquipmentType(
        "sled",
        "雪橇",
        "Sled",
        ("雪橇", "推雪橇", "sled", "prowler"),
        "accessory",
    ),
)

_BY_SLUG = {item.slug: item for item in CATALOG}


def get(slug: str | None) -> EquipmentType | None:
    if not slug:
        return None
    return _BY_SLUG.get(slug.strip().lower())


def match_name(value: str | None) -> EquipmentType | None:
    """Find a catalog entry by Chinese/English name or alias."""
    text = (value or "").strip().lower().replace("_", " ").replace("-", " ")
    if not text:
        return None
    for item in CATALOG:
        names = (item.name_zh, item.name_en, *item.aliases)
        if any(
            name.lower().replace("_", " ").replace("-", " ") in text
            or text in name.lower().replace("_", " ").replace("-", " ")
            for name in names
        ):
            return item
    return None


def prompt_catalog() -> str:
    """Compact catalog block for the vision prompt."""
    lines = []
    for item in CATALOG:
        aliases = ", ".join(item.aliases[:6])
        actions = ", ".join(item.exercise_slugs[:4]) or "无"
        lines.append(
            f"- {item.slug} | {item.name_zh} | {item.name_en} | "
            f"别名：{aliases} | 可做动作：{actions}"
        )
    return "\n".join(lines)
