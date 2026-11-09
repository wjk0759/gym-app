from __future__ import annotations

import csv
import html
import json
from collections import defaultdict
from pathlib import Path

DATA = Path("data/vital")
DRAFT = DATA / "vital_actions_zh_draft.json"

# 视觉分类：pack -> 优先级（1 最高，Watch 与手机首条用它）
PACK_STYLE = {
    "100": 1, "100gym": 1, "430m": 1,      # 灰T恤3D
    "430f1": 2, "homepilates": 2, "yoga": 2,  # 金发真人女
    "women400": 3,                          # 黑背心真人女
    "200": 4,                               # 红背心3D男
    "430f2": 5, "wallpilates": 5,           # 肉色背心3D女
    "home130": 6,                           # 黑背心3D肌肉建模女
}
STYLE_LABEL = {
    1: "灰T恤3D",
    2: "金发真人女",
    3: "黑背心真人女",
    4: "红背心3D男",
    5: "肉色背心3D女",
    6: "黑背心3D肌肉建模女",
}
# 第二版再加入动作库的 pack
EXCLUDED_PACKS = {"face", "office"}


def load_json(path: Path):
    return json.loads(path.read_text(encoding="utf-8"))


# ---------------------------------------------------------------------------
# Decision tables. Each canonical action lists its member slugs (>=1).
# `name` is the final Chinese name. `equipment`/`muscle` override only when
# the source metadata is wrong. `note` shows in the review page.
# ---------------------------------------------------------------------------

ACTIONS = [
    # --- 俯卧撑系 ---
    dict(
        name="标准俯卧撑",
        slugs=[
            "vital-standard-push-up",
            "vital-standard-push-ups",
            "vital-push-up",
            "vital-push-ups",
        ],
        equipment="bodyweight",
        muscle="chest",
        note="标准俯卧撑 + 俯卧撑合并",
    ),
    dict(
        name="窄距俯卧撑",
        slugs=["vital-close-grip-push-ups", "vital-close-push-ups"],
        equipment="bodyweight",
        muscle="chest",
        note="close grip push ups + Close Push Ups（女版）合并",
    ),
    dict(
        name="上斜俯卧撑",
        slugs=["vital-incline-push-up", "vital-incline-push-ups", "vital-incline-pushup"],
        equipment="bodyweight",
        muscle="chest",
    ),
    dict(
        name="下斜俯卧撑",
        slugs=["vital-decline-push-up", "vital-decline-push-ups"],
        equipment="bodyweight",
        muscle="chest",
    ),
    dict(
        name="击掌俯卧撑",
        slugs=["vital-clap-push-up", "vital-clap-push-ups"],
        equipment="bodyweight",
        muscle="chest",
    ),
    dict(
        name="单手俯卧撑",
        slugs=["vital-one-hand-push-up", "vital-one-hand-push-ups"],
        equipment="bodyweight",
        muscle="chest",
    ),
    dict(
        name="跪姿俯卧撑",
        slugs=["vital-knee-push-up", "vital-knee-push-ups"],
        equipment="bodyweight",
        muscle="chest",
    ),
    dict(
        name="钻石俯卧撑",
        slugs=["vital-diamond-push-up", "vital-diamond-push-ups"],
        equipment="bodyweight",
        muscle="arms",
        note="钻石俯卧撑以三头为主，肌群统一 arms",
    ),
    # --- 卧推 ---
    dict(name="窄握杠铃卧推", slugs=["vital-close-grip-barbell-bench-press"], equipment="barbell", muscle="chest"),
    dict(name="杠铃卧推", slugs=["vital-close-grip-bench-press-barbell"], equipment="barbell", muscle="chest",
         name_en="barbell bench press",
         note="原英文标 close-grip，但实际是正常杠铃卧推"),
    dict(
        name="上斜杠铃卧推",
        slugs=["vital-incline-barbell-bench-press", "vital-incline-bench-press-barbell"],
        equipment="barbell",
        muscle="chest",
    ),
    # --- 硬拉 / 深蹲 ---
    dict(
        name="六角杠硬拉",
        slugs=["vital-hex-bar-deadlift", "vital-trap-bar-deadlift"],
        equipment="barbell",
        muscle="back",
    ),
    dict(
        name="杠铃深蹲",
        slugs=["vital-back-squat", "vital-barbell-back-squat"],
        equipment="barbell",
        muscle="legs",
    ),
    dict(
        name="靠墙深蹲",
        slugs=["vital-wall-squat", "vital-wall-squats"],
        equipment="bodyweight",
        muscle="legs",
    ),
    dict(
        name="靠墙单腿深蹲",
        slugs=["vital-wall-one-leg-squat", "vital-wall-one-leg-squats"],
        equipment="bodyweight",
        muscle="legs",
    ),
    dict(
        name="深蹲膝触地",
        slugs=["vital-squat-knee-dive", "vital-squat-with-knee-dive"],
        equipment="bodyweight",
        muscle="legs",
    ),
    dict(
        name="持瓶自重深蹲",
        slugs=["vital-bodyweight-squat-with-bottles-hand", "vital-bodyweight-squats-with-bottle"],
        equipment="bodyweight",
        muscle="legs",
    ),
    dict(
        name="弹力带深蹲",
        slugs=["vital-banded-squat", "vital-resistance-band-squat"],
        equipment="band",
        muscle="legs",
    ),
    dict(name="单腿倒蹬", slugs=["vital-single-leg-leg-press"], equipment="machine", muscle="legs",
         note="原名单腿腿举，改为单腿倒蹬"),
    dict(name="弹力带箭步蹲", slugs=["vital-single-leg-press"], equipment="band", muscle="legs",
         name_en="band lunge",
         note="原名单腿腿举/单腿 press，实为弹力带箭步蹲；instructions 需按视频重写"),
    dict(
        name="靠墙单腿站立（侧向扶墙）",
        slugs=["vital-wall-single-leg-stand-hold"],
        equipment="bodyweight",
        muscle="legs",
    ),
    dict(
        name="靠墙单腿站立（面向墙）",
        slugs=["vital-wall-single-leg-standing-hold"],
        equipment="bodyweight",
        muscle="legs",
    ),
    dict(
        name="单腿平衡",
        slugs=["vital-one-leg-balance", "vital-single-leg-balance"],
        equipment="bodyweight",
        muscle="legs",
    ),
    dict(name="跳箱", slugs=["vital-bench-jump", "vital-box-jump", "vital-jump-box"], equipment="bodyweight", muscle="legs"),
    dict(
        name="团身跳",
        slugs=["vital-tuck-jump", "vital-tunk-jump"],
        equipment="bodyweight",
        muscle="legs",
        note="tunk 为 tuck 拼写错误，合并",
    ),
    dict(
        name="消防栓式",
        slugs=["vital-fire-hydrant", "vital-fire-hydrants"],
        equipment="bodyweight",
        muscle="legs",
        note="标准中文名，别名消防栓踢腿",
    ),
    # --- 后束 / 肩 ---
    dict(name="蝴蝶机后束飞鸟", slugs=["vital-rear-delt-fly"], equipment="machine", muscle="shoulders",
         name_en="reverse pec deck fly",
         note="原标 dumbbell，实为反向蝴蝶机"),
    dict(name="坐姿俯身后束飞鸟", slugs=["vital-rear-flyes"], equipment="dumbbell", muscle="back",
         name_en="seated bent-over rear delt fly"),
    dict(
        name="哑铃俯身后束飞鸟",
        slugs=["vital-rear-delt-dumbbell-fly", "vital-rear-delt-fly-with-dumbbell"],
        equipment="dumbbell",
        muscle="back",
        note="站姿/坐姿两条合并为哑铃俯身后束飞鸟",
    ),
    dict(
        name="绳索后束飞鸟",
        slugs=["vital-cable-rear-delt-fly", "vital-rear-delt-cable-fly"],
        equipment="cable",
        muscle="shoulders",
        note="男女两版（龙门架）合并",
    ),
    dict(name="哑铃肩外旋", slugs=["vital-dumb-waiter-dumbbell"], equipment="dumbbell", muscle="shoulders",
         name_en="dumbbell shoulder external rotation",
         note="原哑铃侍者弯举，实为肩外旋"),
    dict(
        name="杠铃片前平举",
        slugs=["vital-front-raise-weighted-plate", "vital-plate-front-raise"],
        equipment="other",
        muscle="shoulders",
    ),
    # --- 二头 ---
    dict(
        name="哑铃弯举",
        slugs=["vital-biceps-curl", "vital-dumbbell-biceps-curl", "vital-dumbbell-curl"],
        equipment="dumbbell",
        muscle="arms",
    ),
    dict(
        name="锤式弯举",
        slugs=["vital-dumbbell-hammer-curl", "vital-hammer-curl"],
        equipment="dumbbell",
        muscle="arms",
    ),
    dict(name="蜘蛛弯举", slugs=["vital-dumbbell-spider-curl"], equipment="dumbbell", muscle="arms"),
    dict(name="交替蜘蛛弯举", slugs=["vital-spider-curl"], equipment="dumbbell", muscle="arms",
         name_en="alternating spider curl",
         note="女版实为交替弯举，改为交替蜘蛛弯举"),
    dict(name="哑铃侍者弯举", slugs=["vital-dumbbell-waiter-curl"], equipment="dumbbell", muscle="arms"),
    dict(name="坐姿哑铃弯举", slugs=["vital-dumbbell-concentration-bicep-curl"], equipment="dumbbell", muscle="arms",
         name_en="seated dumbbell curl"),
    dict(name="哑铃集中弯举", slugs=["vital-dumbbell-concentration-biceps-curl"], equipment="dumbbell", muscle="arms",
         name_en="dumbbell concentration curl",
         note="借助凳子支撑的集中弯举"),
    # --- 三头 ---
    dict(name="哑铃仰卧臂屈伸", slugs=["vital-dumbbell-skull-crusher"], equipment="dumbbell", muscle="arms"),
    dict(name="屈腿哑铃仰卧臂屈伸", slugs=["vital-dumbbell-skullcrusher"], equipment="dumbbell", muscle="arms"),
    # --- 核心 ---
    dict(name="卷腹", slugs=["vital-crunch", "vital-crunches"], equipment="bodyweight", muscle="core"),
    dict(
        name="仰卧打水",
        slugs=["vital-flutter-kick"],
        equipment="bodyweight",
        muscle="core",
        note="红色 3D 男版",
    ),
    dict(
        name="仰卧交叉打水",
        slugs=["vital-flutter", "vital-flutter-kicks"],
        equipment="bodyweight",
        muscle="core",
        note="两个女版，交叉打水",
    ),
    dict(name="仰卧屈膝举腿", slugs=["vital-lying-leg-raise-bent-knees"], equipment="bodyweight", muscle="core"),
    dict(
        name="跪姿弹力带髋外展",
        slugs=["vital-lying-leg-raises-bent-knee"],
        equipment="band",
        muscle="glutes",
        name_en="kneeling band hip abduction",
        note="原英文 lying leg raises (bent knee) 错，实为跪姿、双手撑地、大腿绑弹力带做髋外展；instructions 需重写",
    ),
    dict(
        name="平板支撑对侧手脚抬起",
        slugs=[
            "vital-plank-with-hand-and-leg-lift",
            "vital-plank-with-hand-and-leg-up",
            "vital-plank-with-opposite-hand-leg-lift",
        ],
        equipment="bodyweight",
        muscle="core",
    ),
    dict(name="平板支撑", slugs=["vital-plank", "vital-plank-pose"], equipment="bodyweight", muscle="core"),
    dict(
        name="平板支撑下犬式",
        slugs=["vital-plank-downward-dog", "vital-plank-to-downward-dog"],
        equipment="bodyweight",
        muscle="core",
    ),
    dict(
        name="平板支撑开合跳",
        slugs=["vital-plank-jack", "vital-plank-jacks"],
        equipment="bodyweight",
        muscle="core",
        note="以 plank jacks 为主",
    ),
    dict(
        name="平板支撑转髋",
        slugs=["vital-plank-hold-with-hips-twist", "vital-plank-with-hips-twist"],
        equipment="bodyweight",
        muscle="core",
    ),
    dict(name="直臂平板支撑伸手", slugs=["vital-plank-reach"], equipment="bodyweight", muscle="core",
         note="手掌撑地版"),
    dict(name="肘撑平板支撑伸手", slugs=["vital-plank-with-reach"], equipment="bodyweight", muscle="core",
         note="手肘撑地版；具体对应以视频首帧为准"),
    dict(
        name="转体仰卧起坐",
        slugs=["vital-twist-sit-ups", "vital-twisted-sit-ups"],
        equipment="bodyweight",
        muscle="core",
    ),
    dict(
        name="杠铃地雷管仰卧起坐",
        slugs=["vital-landmine-sit-up", "vital-landmine-sit-ups"],
        equipment="barbell",
        muscle="core",
    ),
    dict(
        name="臀桥反向卷腹",
        slugs=["vital-bridge-glutes-with-reverse-crunch", "vital-bridge-with-reverse-crunch"],
        equipment="bodyweight",
        muscle="core",
    ),
    dict(
        name="负重俄罗斯转体",
        slugs=["vital-russian-twist-weighted", "vital-weighted-russian-twist"],
        equipment="dumbbell",
        muscle="core",
    ),
    dict(
        name="船长椅屈膝举腿",
        slugs=["vital-captain-s-chair-leg-raise"],
        equipment="bodyweight",
        muscle="core",
    ),
    dict(
        name="船长椅直腿举腿",
        slugs=["vital-captain-s-chair-leg-raises"],
        equipment="bodyweight",
        muscle="core",
    ),
    dict(name="侧平板支撑", slugs=["vital-side-plank"], equipment="bodyweight", muscle="core"),
    dict(name="瑜伽侧板式", slugs=["vital-side-plank-vasisthasana"], equipment="bodyweight", muscle="core",
         note="梵文 Vasisthasana，瑜伽侧板式，非普通侧平板支撑"),
    dict(name="乌鸦式", slugs=["vital-crow-pose", "vital-crow-pose-kagasana"], equipment="bodyweight", muscle="core"),
    # --- 背 ---
    dict(name="引体向上", slugs=["vital-pull-up", "vital-pull-ups"], equipment="bodyweight", muscle="back"),
    dict(
        name="坐姿器械划船",
        slugs=[
            "vital-machine-seated-row",
            "vital-seated-row-machine",
            "vital-seated-machine-row",
            "vital-seated-row",
        ],
        equipment="machine",
        muscle="back",
        note="machine 4 条合并；1620 为可移动凳版本",
    ),
    dict(
        name="坐姿绳索划船机",
        slugs=["vital-seated-cable-row"],
        equipment="cable",
        muscle="back",
        name_en="seated cable row",
    ),
    dict(
        name="弹力带划船接臂屈伸",
        slugs=["vital-band-row-to-triceps", "vital-resistance-band-row-to-triceps"],
        equipment="band",
        muscle="back",
    ),
    dict(name="哑铃耸肩", slugs=["vital-dumbbell-shrug", "vital-dumbbell-shrugs"], equipment="dumbbell", muscle="back"),
    # --- 有氧 / 步法 ---
    dict(name="侧向滑步", slugs=["vital-lateral-shuffle"], equipment="bodyweight", muscle="cardio"),
    dict(name="前后交替滑步", slugs=["vital-lateral-shuffle-1"], equipment="bodyweight", muscle="cardio",
         name_en="forward-back shuffle",
         note="原英文标 lateral，实为前后交替"),
    dict(name="跑步机跑步", slugs=["vital-run-on-treadmill", "vital-treadmill-run"], equipment="machine", muscle="cardio"),
    dict(name="冲刺间歇跑", slugs=["vital-sprint-intervals-fast-running"], equipment="bodyweight", muscle="cardio",
         note="用户要求只用慢速；默认保留 plural 条为慢速，请确认"),
    # --- 拉伸 ---
    dict(
        name="站姿腘绳肌拉伸",
        slugs=["vital-standing-hamstring", "vital-standing-hamstring-stretch"],
        equipment="bodyweight",
        muscle="legs",
    ),
]

# Slugs to drop entirely from the library (still kept in source).
EXCLUDE = {
    "vital-sprint-interval-fast-running": "冲刺间歇跑（快速）— 用户要求只用慢速，此条不进入动作库",
}

SYNONYMS = {
    "标准俯卧撑": ["俯卧撑"],
    "窄距俯卧撑": ["窄握俯卧撑", "女版俯卧撑"],
    "单腿倒蹬": ["单腿腿举", "倒蹬"],
    "弹力带箭步蹲": ["弹力带弓步蹲", "弹力带箭步蹲"],
    "哑铃肩外旋": ["哑铃侍者式", "肩外旋"],
    "蝴蝶机后束飞鸟": ["反向蝴蝶机", "反向飞鸟机", "反向蝴蝶机飞鸟"],
    "坐姿俯身后束飞鸟": ["俯身后束飞鸟"],
    "哑铃俯身后束飞鸟": ["俯身后束飞鸟"],
    "绳索后束飞鸟": ["龙门架后束飞鸟"],
    "船长椅屈膝举腿": ["船长椅举腿", "屈膝举腿"],
    "船长椅直腿举腿": ["直腿举腿"],
    "交替蜘蛛弯举": ["交替弯举"],
    "仰卧交叉打水": ["剪刀腿", "交叉腿", "交叉打水"],
    "仰卧打水": ["仰卧交替打水", "打水"],
    "前后交替滑步": ["前后滑步", "快速前后步"],
    "瑜伽侧板式": ["侧板式", "侧平板支撑瑜伽"],
    "杠铃卧推": ["卧推"],
    "窄握杠铃卧推": ["窄握卧推"],
    "消防栓式": ["消防栓踢腿", "小狗撒尿式", "髋外展"],
    "直臂平板支撑伸手": ["手掌撑地平板支撑伸手", "直臂平板支撑交替伸手"],
    "肘撑平板支撑伸手": ["手肘撑地平板支撑伸手", "肘撑平板支撑交替伸手"],
    "负重俄罗斯转体": ["俄罗斯转体", "负重转体"],
    "跑步机跑步": ["跑步机", "跑步机跑"],
    "杠铃片前平举": ["杠铃片前举", "铃片前平举"],
    "六角杠硬拉": ["六角杠铃硬拉", "trap bar 硬拉"],
    "哑铃侍者弯举": ["侍者弯举"],
    "坐姿器械划船": ["坐姿划船机", "器械坐姿划船", "坐姿划船"],
    "坐姿绳索划船机": ["坐姿绳索划船", "绳索坐姿划船", "坐姿划船（绳索）"],
    "跪姿弹力带髋外展": ["弹力带髋外展", "跪姿髋外展", "弹力带跪姿髋外展"],
    "平板支撑下犬式": ["平板接下犬式"],
    "乌鸦式": ["鹤式"],
    "团身跳": ["收膝跳", "抱膝跳"],
    "跳箱": ["跳箱跳", "箱上跳"],
    "引体向上": ["引体", "引体上升"],
    "侧向滑步": ["横向滑步", "侧滑步"],
    "冲刺间歇跑": ["间歇冲刺", "冲刺跑"],
    "侧平板支撑": ["侧撑", "侧面平板"],
}


def main() -> None:
    actions = load_json(DRAFT)
    by_slug = {a["slug"]: a for a in actions}

    path_by_slug = {}
    with (DATA / "vital_actions_review_videos.csv").open(encoding="utf-8-sig", newline="") as fh:
        for row in csv.DictReader(fh):
            path_by_slug[row["slug"]] = row.get("primary_video_path", "")

    # Build merge map and per-slug overrides.
    merge_of = {}
    canonical_fields = {}
    for spec in ACTIONS:
        canon = spec["slugs"][0]
        canonical_fields[canon] = spec
        for s in spec["slugs"]:
            merge_of[s] = canon
    # Singles not in ACTIONS map to themselves.
    for a in actions:
        if a["slug"] not in merge_of:
            merge_of[a["slug"]] = a["slug"]

    # Build merged canonical actions.
    merged = {}
    for a in actions:
        canon = merge_of[a["slug"]]
        merged.setdefault(canon, []).append(a)

    out_actions = []
    decisions = []
    for canon, members in merged.items():
        spec = canonical_fields.get(canon)
        first = members[0]
        if spec:
            final_name = spec["name"]
            equipment = spec.get("equipment") or first["equipment"]
            muscle = spec.get("muscle") or first["muscle_group"]
            note = spec.get("note", "")
            name_en = spec.get("name_en") or first["name_en"]
        else:
            final_name = first["name_zh"]
            equipment = first["equipment"]
            muscle = first["muscle_group"]
            note = ""
            name_en = first["name_en"]

        # Collect media, dedupe by source_file.
        media = []
        seen = set()
        for m in members:
            for md in m.get("media", []):
                src = md.get("source_file")
                if src and src not in seen:
                    seen.add(src)
                    item = dict(md)
                    if Path(src).stem == "1620":
                        item["note"] = "可移动凳版本"
                    prio = PACK_STYLE.get(item.get("pack"))
                    item["visual_priority"] = prio if prio is not None else 99
                    item["visual_style"] = STYLE_LABEL.get(prio, "未知")
                    media.append(item)

        aliases = set()
        if len(members) > 1:
            for m in members:
                if m.get("name_en"):
                    aliases.add(m["name_en"])
                if m.get("name_zh"):
                    aliases.add(m["name_zh"])
        aliases.update(SYNONYMS.get(final_name, []))
        aliases.discard(final_name)

        old_names = " / ".join(sorted({m.get("name_zh", "") for m in members if m.get("name_zh")}))

        out_actions.append(
            {
                "slug": canon,
                "slug_aliases": sorted({m["slug"] for m in members}),
                "name_zh": final_name,
                "name_en": name_en,
                "source_name_en": first["name_en"],
                "aliases": sorted(aliases),
                "equipment": equipment,
                "muscle_group": muscle,
                "body_part": first.get("body_part", ""),
                "target": first.get("target"),
                "secondary_muscles": first.get("secondary_muscles") or [],
                "category": first.get("category"),
                "difficulty": first.get("difficulty", 1),
                "is_compound": first.get("is_compound", False),
                "instructions_zh": first.get("instructions_zh") or [],
                "instructions_needs_review": 1 if note else first.get("instructions_needs_review", 1),
                "name_zh_source": "manual_v2",
                "old_names_zh": old_names,
                "review_note": note,
                "sex_variants": sorted({md.get("sex") for md in media if md.get("sex")}),
                "media": media,
                "media_count": len(media),
                "source": "vital_animations",
                "license": "Vital Animations EULA 2026.1",
            }
        )

        for m in members:
            decisions.append(
                {
                    "slug": m["slug"],
                    "old_name_zh": m.get("name_zh", ""),
                    "new_name_zh": final_name,
                    "canonical_slug": canon,
                    "equipment": equipment,
                    "muscle_group": muscle,
                    "merged": len(members) > 1,
                    "media_count": len(m.get("media", [])),
                    "note": note,
                }
            )

    # Excluded slugs.
    for s, reason in EXCLUDE.items():
        a = by_slug.get(s)
        if a:
            decisions.append(
                {
                    "slug": s,
                    "old_name_zh": a.get("name_zh", ""),
                    "new_name_zh": "",
                    "canonical_slug": "",
                    "equipment": a["equipment"],
                    "muscle_group": a["muscle_group"],
                    "merged": False,
                    "media_count": len(a.get("media", [])),
                    "note": "EXCLUDE: " + reason,
                }
            )

    # Sort each action's media by visual priority, mark Watch primary.
    for a in out_actions:
        a["media"].sort(key=lambda md: (md.get("visual_priority", 99), md.get("source_file", "")))
        if a["media"]:
            a["media"][0]["primary_for_watch"] = True
            pm = a["media"][0]
            a["primary_media"] = {
                "source_file": pm["source_file"],
                "visual_style": pm.get("visual_style"),
                "visual_priority": pm.get("visual_priority"),
            }
        else:
            a["primary_media"] = None
        packs = {md.get("pack") for md in a["media"]}
        a["excluded_from_library"] = bool(packs) and packs <= EXCLUDED_PACKS

    main_actions = [a for a in out_actions if not a["excluded_from_library"]]
    face_office = [a for a in out_actions if a["excluded_from_library"]]

    out_actions.sort(key=lambda a: (a["muscle_group"], a["name_zh"]))
    main_actions.sort(key=lambda a: (a["muscle_group"], a["name_zh"]))
    face_office.sort(key=lambda a: (a["muscle_group"], a["name_zh"]))

    # Write JSON（主库不含 face/office）。
    (DATA / "vital_actions_v2.json").write_text(
        json.dumps(main_actions, ensure_ascii=False, indent=1), encoding="utf-8"
    )
    (DATA / "vital_face_office_v2.json").write_text(
        json.dumps(face_office, ensure_ascii=False, indent=1), encoding="utf-8"
    )

    # Write decisions CSV.
    with (DATA / "vital_merge_decisions.csv").open("w", encoding="utf-8-sig", newline="") as fh:
        w = csv.DictWriter(
            fh,
            fieldnames=[
                "slug", "old_name_zh", "new_name_zh", "canonical_slug",
                "equipment", "muscle_group", "merged", "media_count", "note",
            ],
        )
        w.writeheader()
        for d in sorted(decisions, key=lambda x: (x["new_name_zh"], x["slug"])):
            w.writerow(d)

    # Build review HTML.
    changed = [
        a
        for a in out_actions
        if len(a["slug_aliases"]) > 1
        or a["review_note"]
        or (len(a["slug_aliases"]) == 1 and a["old_names_zh"] and a["old_names_zh"] != a["name_zh"])
    ]
    changed.sort(key=lambda a: (not a["review_note"], a["name_zh"]))

    def video_block(slug):
        p = path_by_slug.get(slug, "")
        if not p:
            return "<span class='faint'>无视频</span>"
        uri = Path(p).as_uri()
        return f"<video src='{html.escape(uri)}' controls preload='metadata'></video><div class='faint'>{html.escape(p)}</div>"

    parts = [
        "<!doctype html><meta charset='utf-8'><title>Vital 动作库合并/改名复核 v2</title>",
        "<style>"
        "body{font-family:system-ui,'Microsoft YaHei',sans-serif;background:#0f1520;color:#e8eef8;margin:20px}"
        ".card{background:#182231;border:1px solid #2a3545;border-radius:10px;margin:16px 0;padding:16px}"
        "h1{font-size:22px}h2{font-size:18px}"
        ".n{font-size:18px;font-weight:700}.m{color:#8d9bb1;font-size:12px;margin:4px 0}"
        ".note{color:#f0c674;font-size:13px;margin:4px 0}"
        ".row{display:flex;gap:16px;flex-wrap:wrap;align-items:flex-start;border-top:1px solid #243044;padding-top:12px;margin-top:12px}"
        ".row:first-of-type{border-top:0;padding-top:0;margin-top:0}"
        "video{width:300px;max-width:100%;background:#000;border-radius:6px}"
        ".v{font-size:14px}.v small{color:#8d9bb1}"
        ".tag{display:inline-block;border:1px solid #3a4a60;border-radius:4px;padding:0 6px;margin-right:4px;font-size:12px}"
        ".aliases{color:#7ba4ff;font-size:12px}.faint{color:#8d9bb1;font-size:11px;word-break:break-all}"
        "</style>",
        f"<h1>Vital 动作库合并/改名复核 v2</h1>",
        f"<p class='faint'>合并后动作数 {len(out_actions)}（原 {len(actions)}）；下面只列发生变化的动作。</p>",
    ]

    for a in changed:
        parts.append(
            "<div class='card'>"
            f"<div class='n'>{html.escape(a['name_zh'])} "
            f"<span class='tag'>{html.escape(a['equipment'])}</span>"
            f"<span class='tag'>{html.escape(a['muscle_group'])}</span>"
            f"<span class='tag'>视频 {a['media_count']}</span></div>"
            f"<div class='m'>原：{html.escape(a['old_names_zh'])}</div>"
        )
        if a["review_note"]:
            parts.append(f"<div class='note'>⚠ {html.escape(a['review_note'])}</div>")
        if a["aliases"]:
            parts.append(f"<div class='aliases'>别名：{html.escape('、'.join(a['aliases']))}</div>")
        for s in a["slug_aliases"]:
            m = by_slug.get(s, {})
            parts.append(
                "<div class='row'>"
                f"<div>{video_block(s)}</div>"
                f"<div class='v'><strong>{html.escape(m.get('name_en',''))}</strong><br>"
                f"<small>{html.escape(s)} · {html.escape(m.get('name_zh',''))}</small></div>"
                "</div>"
            )
        parts.append("</div>")

    parts.append("</body>")
    (DATA / "duplicates_review_v2.html").write_text("\n".join(parts), encoding="utf-8")

    print("actions before", len(actions), "after(merged)", len(out_actions))
    print("main library", len(main_actions), "face/office(预留)", len(face_office))
    print("changed", len(changed), "excluded", len(EXCLUDE))
    print("media total", sum(a["media_count"] for a in main_actions))
    print("wrote", DATA / "vital_actions_v2.json")
    print("wrote", DATA / "vital_face_office_v2.json")
    print("wrote", DATA / "vital_merge_decisions.csv")
    print("wrote", DATA / "duplicates_review_v2.html")


if __name__ == "__main__":
    main()
