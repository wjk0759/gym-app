from __future__ import annotations

import csv
import json
import re
from pathlib import Path

DATA = Path("data/vital")

# 中文术语同义替换（生成搜索别名）。key 出现在正式名里时，替换成 value 里的每一个。
TERM_SYNONYMS = {
    "弓步蹲": ["箭步蹲", "弓步"],
    "箭步蹲": ["弓步蹲", "箭步"],
    "臀推": ["臀冲"],
    "臀冲": ["臀推"],
    "颈前深蹲": ["前蹲"],
    "前蹲": ["颈前深蹲"],
    "过顶推举": ["过头推举"],
    "过头推举": ["过顶推举"],
    "哈克深蹲": ["哈克机深蹲"],
    "哈克机深蹲": ["哈克深蹲"],
    "保加利亚分腿蹲": ["保加利亚蹲", "保加利亚剪蹲"],
    "保加利亚蹲": ["保加利亚分腿蹲", "保加利亚剪蹲"],
    "保加利亚剪蹲": ["保加利亚分腿蹲", "保加利亚蹲"],
    "罗马尼亚硬拉": ["罗马硬拉"],
    "罗马硬拉": ["罗马尼亚硬拉"],
    "引体向上": ["引体", "正手引体向上"],
    "仰卧臂屈伸": ["碎颅者", "颅骨粉碎者"],
    "提踵": ["踮脚"],
    "踮脚": ["提踵"],
    "深蹲跳": ["跳跃深蹲"],
    "跳跃深蹲": ["深蹲跳"],
    "俯身划船": ["俯身提拉"],
    "俯身提拉": ["俯身划船"],
    "面拉": ["绳索面拉"],
    "绳索面拉": ["面拉"],
    "双杠臂屈伸": ["双杠"],
    "宽握": ["宽距"],
    "宽距": ["宽握"],
    "窄握": ["窄距"],
    "窄距": ["窄握"],
    "单臂": ["单手", "单侧"],
    "单手": ["单臂", "单侧"],
    "单腿": ["单脚", "单侧腿"],
    "站姿": ["站立", "站式"],
    "坐姿": ["坐式"],
    "仰卧": ["平躺", "躺姿"],
    "跪姿": ["跪式"],
    "交替": ["交替式"],
    "杠铃片": ["铃片", "杠铃盘"],
    "弹力带": ["弹力绳", "阻力带"],
    "弹力绳": ["弹力带", "阻力带"],
    "史密斯机": ["史密斯", "史密斯架"],
    "自重": ["徒手", "身体自重"],
    "徒手": ["自重", "身体自重"],
    "侧平板支撑": ["侧撑", "侧面平板"],
    "消防栓式": ["消防栓踢腿", "小狗撒尿式"],
    "壶铃摆动": ["壶铃甩"],
    "壶铃甩": ["壶铃摆动"],
    "屈腿": ["屈膝"],
    "屈膝": ["屈腿"],
    "直腿": ["伸直腿"],
    "反向蝴蝶机": ["反向飞鸟机", "蝴蝶机反向"],
    "B站姿": ["B字步", "B姿势"],
    "B字步": ["B站姿", "B姿势"],
    "地雷管": ["地雷杆", "landmine"],
    "山羊挺身": ["背屈伸", "背伸展"],
}

# 逐动作补充别名（特殊/音译/品牌）。
EXTRA_ALIASES = {
    "斯文德推举": ["斯文德推胸", "杠铃片夹胸"],
    "潘德雷划船": ["彭德莱划船", "彭德雷划船", "Pendlay 划船"],
    "泽奇深蹲": ["Zercher 深蹲"],
    "杰弗森深蹲": ["杰佛森深蹲"],
    "哥本哈根侧平板": ["哥本哈根平板", "Copenhagen plank"],
    "90/90髋旋转": ["9090旋转", "90-90旋转"],
    "V字两头起": ["V字起坐", "V字卷腹", "V-up"],
    "EZ杠弯举": ["EZ杆弯举", "曲杆弯举"],
    "EZ杆二头弯举": ["EZ杠二头弯举", "曲杆二头弯举"],
    "船式": ["Navasana", "船式瑜伽"],
    "萤火虫式": ["Tittibhasana"],
    "蛙式": ["Mandukasana", "青蛙式"],
    "蝎子式": ["Vrschikasana"],
    "坐姿体前屈": ["Paschimottanasana"],
    "死虫式": ["死虫", "Dead Bug"],
    "鸟狗式": ["鸟狗", "Bird Dog"],
    "波比跳": ["立卧撑", "Burpee"],
    "战绳": ["甩绳", "Battle Rope"],
    "登山跑": ["登山者", "Mountain Climber"],
    "开合跳": ["跳开合", "Jumping Jack"],
    "高抬腿": ["高抬腿跑"],
    "早安式": ["早安", "Good Morning"],
    "六角杠硬拉": ["六角杠铃硬拉", "Trap Bar 硬拉"],
    "反向超伸": ["反向山羊挺身", "Reverse Hyper"],
    "伐木": ["伐木式", "Wood Chop"],
    "俄罗斯转体": ["俄式转体", "Russian Twist"],
    "负重俄罗斯转体": ["负重转体", "俄罗斯转体"],
    "屈臂撑": ["双杠臂屈伸"],
    "俯卧撑": ["Push-Up", "Pushup"],
    "卧推": ["Bench Press"],
    "深蹲": ["Squat"],
    "硬拉": ["Deadlift"],
    "划船": ["Row"],
    "弯举": ["Curl"],
    "下压": ["Pushdown"],
    "飞鸟": ["Fly"],
    "推举": ["Press"],
}


def norm_en(value: str) -> list[str]:
    """英文别名：原文、小写、去掉括号和连字符变体。"""
    out = set()
    if not value:
        return list(out)
    v = value.strip()
    out.add(v)
    out.add(v.lower())
    # strip parenthetical
    stripped = re.sub(r"\s*\([^)]*\)\s*", " ", v).strip()
    if stripped and stripped != v:
        out.add(stripped)
        out.add(stripped.lower())
    # hyphen -> space
    nospace = v.replace("-", " ")
    if nospace != v:
        out.add(nospace)
        out.add(nospace.lower())
    return list(out)


def expand_zh(name: str) -> set[str]:
    out = set()
    for term, alts in TERM_SYNONYMS.items():
        if term in name:
            for alt in alts:
                out.add(name.replace(term, alt))
    return out


def main() -> None:
    # 训记精确名 → canonical slug
    canon_of = {}
    with (DATA / "vital_merge_decisions.csv").open(encoding="utf-8-sig", newline="") as fh:
        for row in csv.DictReader(fh):
            canon = row.get("canonical_slug")
            if canon:
                canon_of[row["slug"]] = canon

    xunji_by_canon = {}
    with (DATA / "xunji_vital_mapping.csv").open(encoding="utf-8-sig", newline="") as fh:
        for row in csv.DictReader(fh):
            if row.get("match_type") != "exact":
                continue
            vital_slug = row.get("vital_slug")
            name = (row.get("xunji_name") or "").strip()
            if not vital_slug or not name:
                continue
            canon = canon_of.get(vital_slug, vital_slug)
            xunji_by_canon.setdefault(canon, set()).add(name)

    files = ["vital_actions_v2.json", "vital_face_office_v2.json"]
    for fname in files:
        actions = json.loads((DATA / fname).read_text(encoding="utf-8"))
        enrich(actions, canon_of, xunji_by_canon)
        (DATA / fname).write_text(
            json.dumps(actions, ensure_ascii=False, indent=1), encoding="utf-8"
        )
        import statistics
        counts = [len(a["aliases"]) for a in actions]
        total = sum(counts)
        print(f"{fname}: actions {len(actions)}, aliases {total}, avg {round(statistics.mean(counts),1)}, max {max(counts)}")


def enrich(actions, canon_of, xunji_by_canon) -> None:
    for a in actions:
        aliases = set(a.get("aliases", []))

        # 英文名 + 变体（只用纠正后的 name_en，不用错误的 source_name_en）
        aliases.update(norm_en(a.get("name_en", "")))

        # 训记精确名
        aliases.update(xunji_by_canon.get(a["slug"], set()))

        # 中文术语替换
        aliases.update(expand_zh(a["name_zh"]))

        # 逐动作补充
        aliases.update(EXTRA_ALIASES.get(a["name_zh"], []))

        # 清理：去空、去自身、去纯空格、去长度过短
        cleaned = set()
        for al in aliases:
            al = str(al).strip()
            if not al or al == a["name_zh"] or len(al) < 2:
                continue
            cleaned.add(al)
        a["aliases"] = sorted(cleaned)


if __name__ == "__main__":
    main()
