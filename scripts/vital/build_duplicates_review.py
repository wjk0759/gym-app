from __future__ import annotations

import csv
import html
import json
from collections import defaultdict
from pathlib import Path


def load_json(path: Path):
    return json.loads(path.read_text(encoding="utf-8"))


def main() -> None:
    data = Path("data/vital")
    actions = load_json(data / "vital_actions_zh_draft.json")

    path_by_slug = {}
    with (data / "vital_actions_review_videos.csv").open(
        encoding="utf-8-sig", newline=""
    ) as handle:
        for row in csv.DictReader(handle):
            path_by_slug[row["slug"]] = row.get("primary_video_path", "")

    groups = defaultdict(list)
    for action in actions:
        groups[action["name_zh"]].append(action)

    # Recommendation per group. Default is "merge".
    # Values: (kind, label, {slug: suggested_name})
    RECOMMEND = {
        # C — need decision
        "单腿腿举": ("split", "拆分改名", {
            "vital-single-leg-leg-press": "单腿腿举（保留）",
            "vital-single-leg-press": "仰卧单腿对抗腿举",
        }),
        "哑铃侍者弯举": ("split", "拆分改名", {
            "vital-dumb-waiter-dumbbell": "哑铃侍者式肩外旋",
            "vital-dumbbell-waiter-curl": "哑铃侍者弯举（保留）",
        }),
        "哑铃后束飞鸟": ("split", "拆站姿/坐姿", {
            "vital-rear-delt-dumbbell-fly": "哑铃俯身后束飞鸟",
            "vital-rear-delt-fly-with-dumbbell": "坐姿哑铃后束飞鸟",
        }),
        "坐姿划船机": ("check", "看视频再定（器械/绳索）", {
            "vital-machine-seated-row": "器械坐姿划船",
            "vital-seated-row-machine": "绳索坐姿划船（或合并）",
        }),
        "平板支撑下犬式": ("merge", "合并", {
            "vital-plank-to-downward-dog": "并入“平板支撑下犬式”",
        }),
        # B — merge + fix tags
        "杠铃片前平举": ("merge_fix", "合并 + 标签统一 other/杠铃片", {}),
        "窄握杠铃卧推": ("merge_fix", "合并 + 标签统一 arms", {}),
        "窄距俯卧撑": ("merge_fix", "合并 + 标签统一 arms", {}),
        "绳索后束飞鸟": ("merge_fix", "合并 + 标签统一 shoulders", {}),
        "负重俄罗斯转体": ("merge_fix", "合并 + 标签统一 dumbbell", {}),
        "跑步机跑步": ("merge_fix", "合并 + 标签统一 machine", {}),
        "钻石俯卧撑": ("merge_fix", "合并 + 标签统一 arms", {}),
    }

    KIND_BADGE = {
        "merge": ("#1f6f43", "#d0f0d8", "直接合并"),
        "merge_fix": ("#8a6d1f", "#f7ecb8", "合并+改标签"),
        "split": ("#7a1f1f", "#f6d2d2", "拆分/改名"),
        "check": ("#1f4d7a", "#d0e4f6", "看视频再定"),
    }

    dup_groups = [
        (name, rows) for name, rows in groups.items() if len(rows) > 1
    ]
    kind_order = {"split": 0, "check": 1, "merge_fix": 2, "merge": 3}

    def sort_key(item):
        name, rows = item
        kind = RECOMMEND.get(name, ("merge", "直接合并", {}))[0]
        return (kind_order.get(kind, 9), -len(rows), name)

    dup_groups.sort(key=sort_key)

    def video_block(uri, path):
        if not uri:
            return "<span class='faint'>无视频</span>"
        return (
            f"<video src='{html.escape(uri)}' controls preload='metadata'></video>"
            f"<div class='faint'>{html.escape(path)}</div>"
        )

    parts = [
        "<!doctype html><meta charset='utf-8'>",
        "<title>Vital 1500 重复动作复核</title>",
        "<style>"
        "body{font-family:system-ui,'Microsoft YaHei',sans-serif;background:#0f1520;color:#e8eef8;margin:0;padding:20px}"
        ".card{background:#182231;border:1px solid #2a3545;border-radius:10px;margin:16px 0;padding:16px}"
        "h1{font-size:22px}h2{font-size:18px;border-bottom:1px solid #2a3545;padding-bottom:8px}"
        ".gname{font-size:18px;font-weight:700;margin:0 0 4px}"
        ".gmeta{color:#8d9bb1;font-size:12px;margin:0 0 12px}"
        ".badge{display:inline-block;border-radius:999px;padding:2px 10px;font-size:12px;font-weight:600;margin-left:8px}"
        ".row{display:flex;gap:16px;flex-wrap:wrap;align-items:flex-start;border-top:1px solid #243044;padding-top:12px;margin-top:12px}"
        ".row:first-of-type{border-top:0;padding-top:0;margin-top:0}"
        "video{width:320px;max-width:100%;background:#000;border-radius:6px}"
        ".vname{font-weight:600;font-size:15px}.slug{color:#8d9bb1;font-size:12px}"
        ".tags{font-size:12px;margin-top:2px}.tag{display:inline-block;border:1px solid #3a4a60;border-radius:4px;padding:0 6px;margin-right:4px}"
        ".sugg{margin-top:6px;font-size:13px;color:#7ba4ff}"
        ".faint{color:#8d9bb1;font-size:12px;word-break:break-all}"
        "a{color:#7ba4ff}.legend{color:#8d9bb1;font-size:13px;margin:8px 0 20px}"
        "</style>",
        "<h1>Vital 1500 重复动作复核</h1>",
        "<p class='legend'>共 "
        + str(len(dup_groups))
        + " 组同名重复，"
        + str(sum(len(r) for _, r in dup_groups))
        + " 条。视频为原始源文件（未转码）。按建议排序：拆分/改名 → 看视频 → 合并+改标签 → 直接合并。</p>",
    ]

    for name, rows in dup_groups:
        kind, label, suggested = RECOMMEND.get(name, ("merge", "直接合并", {}))
        bg, fg, _badge_text = KIND_BADGE[kind]
        parts.append(
            "<div class='card'>"
            f"<p class='gname'>{html.escape(name)}"
            f"<span class='badge' style='background:{bg};color:{fg}'>{html.escape(label)}</span></p>"
            f"<p class='gmeta'>{len(rows)} 条</p>"
        )
        for action in rows:
            slug = action["slug"]
            uri = ""
            p = path_by_slug.get(slug, "")
            if p:
                uri = Path(p).as_uri()
            sugg = suggested.get(slug, "")
            sugg_html = (
                f"<div class='sugg'>建议 → {html.escape(sugg)}</div>" if sugg else ""
            )
            media_extra = len(action.get("media", [])) - 1
            extra = (
                f"<span class='faint'>（另有 {media_extra} 条变体媒体）</span>"
                if media_extra > 0
                else ""
            )
            parts.append(
                "<div class='row'>"
                f"<div>{video_block(uri, p)}</div>"
                "<div>"
                f"<div class='vname'>{html.escape(action['name_en'])} {extra}</div>"
                f"<div class='slug'>{html.escape(slug)}</div>"
                f"<div class='tags'><span class='tag'>{html.escape(action['equipment'])}</span>"
                f"<span class='tag'>{html.escape(action['muscle_group'])}</span>"
                f"<span class='tag'>媒体 {len(action.get('media', []))}</span></div>"
                f"{sugg_html}"
                "</div></div>"
            )
        parts.append("</div>")

    parts.append("</body>")
    html_out = data / "duplicates_review.html"
    html_out.write_text("\n".join(parts), encoding="utf-8")

    # CSV
    csv_out = data / "duplicates_review.csv"
    with csv_out.open("w", encoding="utf-8-sig", newline="") as handle:
        writer = csv.writer(handle)
        writer.writerow(
            [
                "group_name",
                "recommendation",
                "variant_index",
                "slug",
                "name_en",
                "equipment",
                "muscle_group",
                "media_count",
                "primary_video_path",
                "suggested_name",
            ]
        )
        for name, rows in dup_groups:
            kind, label, suggested = RECOMMEND.get(name, ("merge", "直接合并", {}))
            for idx, action in enumerate(rows, 1):
                writer.writerow(
                    [
                        name,
                        label,
                        idx,
                        action["slug"],
                        action["name_en"],
                        action["equipment"],
                        action["muscle_group"],
                        len(action.get("media", [])),
                        path_by_slug.get(action["slug"], ""),
                        suggested.get(action["slug"], ""),
                    ]
                )

    print("groups", len(dup_groups), "rows", sum(len(r) for _, r in dup_groups))
    print("wrote", html_out)
    print("wrote", csv_out)


if __name__ == "__main__":
    main()
