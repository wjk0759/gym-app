"""Small retrieval smoke benchmark for the coach/food/equipment knowledge domains.

This is deliberately not a leaderboard. It catches obvious routing regressions
(e.g. a food query returning coach cards) before a larger labelled set exists.
"""

from __future__ import annotations

import json

from app.services.knowledge_search import search_knowledge

CASES = [
    ("coach", "深蹲膝盖内扣怎么纠正", ("膝内扣", "深蹲")),
    ("coach", "硬拉腰背怎么保持中立", ("硬拉",)),
    ("coach", "卧推肩膀疼怎么办", ("肩", "卧推")),
    ("coach", "蛋白质吃多少", ("蛋白质",)),
    ("coach", "减脂热量赤字", ("热量", "减脂")),
    ("coach", "16:8 轻断食注意什么", ("16:8", "断食")),
    ("coach", "头前伸怎么练", ("头前伸",)),
    ("coach", "训练时腰痛怎么办", ("腰痛",)),
    ("coach", "停练后怎么回归", ("回归",)),
    ("coach", "圆肩怎么练", ("圆肩",)),
    ("coach", "骨盆前倾怎么练", ("骨盆",)),
    ("coach", "碳水循环怎么做", ("碳水",)),
    ("coach", "高蛋白饮食怎么吃", ("高蛋白",)),
    ("coach", "训练时膝盖痛怎么办", ("膝",)),
    ("food", "米饭热量", ("白饭", "米饭")),
    ("food", "鸡胸肉蛋白质", ("鸡胸肉",)),
    ("food", "三文鱼多少卡", ("鲑鱼", "三文鱼")),
    ("food", "牛奶脂肪", ("鲜乳", "牛奶")),
    ("food", "苹果碳水", ("苹果",)),
    ("food", "酸奶热量", ("发酵乳", "酸奶")),
    ("food", "西兰花纤维", ("青花菜", "西兰花")),
    ("food", "鸡蛋热量", ("鸡蛋",)),
    ("food", "豆腐蛋白质", ("豆腐",)),
    ("food", "香蕉碳水", ("香蕉", "北蕉")),
    ("food", "燕麦热量", ("燕麦",)),
    ("food", "牛肉蛋白质", ("牛肉",)),
    ("equipment", "坐姿划船机怎么辨认", ("坐姿划船机",)),
    ("equipment", "哈克深蹲和史密斯机区别", ("哈克深蹲", "史密斯")),
    ("equipment", "蝴蝶机和反向飞鸟区别", ("蝴蝶机", "反向飞鸟")),
    ("equipment", "跑步机和椭圆机区别", ("跑步机", "椭圆机")),
    ("equipment", "臀推机怎么用", ("臀推",)),
    ("equipment", "高位下拉机怎么用", ("高位下拉",)),
    ("equipment", "腿举机怎么调", ("腿举",)),
    ("equipment", "史密斯机怎么用", ("史密斯",)),
    ("equipment", "蝴蝶机练哪里", ("蝴蝶",)),
    ("equipment", "助力引体向上机怎么调", ("助力",)),
]


def main() -> int:
    hit1 = 0
    hit3 = 0
    reciprocal = 0.0
    by_domain: dict[str, dict[str, float]] = {}
    rows = []
    for domain, query, expected in CASES:
        results = search_knowledge(query, domain=domain, limit=3)
        titles = [str(item.get("title") or "") for item in results]
        first = titles[0] if titles else ""
        top3 = " ".join(titles)
        one = any(token in first for token in expected)
        three = any(token in top3 for token in expected)
        rank = next(
            (
                index + 1
                for index, title in enumerate(titles)
                if any(token in title for token in expected)
            ),
            None,
        )
        hit1 += int(one)
        hit3 += int(three)
        reciprocal += 1.0 / rank if rank else 0.0
        bucket = by_domain.setdefault(
            domain,
            {"cases": 0, "hit@1": 0, "hit@3": 0, "mrr@3": 0.0},
        )
        bucket["cases"] += 1
        bucket["hit@1"] += int(one)
        bucket["hit@3"] += int(three)
        bucket["mrr@3"] += 1.0 / rank if rank else 0.0
        rows.append(
            {
                "domain": domain,
                "query": query,
                "titles": titles,
                "hit@1": one,
                "hit@3": three,
                "rank": rank,
            }
        )
    total = len(CASES)
    for bucket in by_domain.values():
        count = bucket["cases"]
        bucket["hit@1"] = round(bucket["hit@1"] / count, 4)
        bucket["hit@3"] = round(bucket["hit@3"] / count, 4)
        bucket["mrr@3"] = round(bucket["mrr@3"] / count, 4)
    summary = {
        "cases": total,
        "hit@1": round(hit1 / total, 4),
        "hit@3": round(hit3 / total, 4),
        "mrr@3": round(reciprocal / total, 4),
        "by_domain": by_domain,
        "misses": [row for row in rows if not row["hit@3"]],
        "results": rows,
    }
    print(json.dumps(summary, ensure_ascii=False, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
