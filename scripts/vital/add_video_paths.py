from __future__ import annotations

import argparse
import csv
import html
import os
from pathlib import Path


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--data", type=Path, default=Path("data/vital"))
    parser.add_argument(
        "--vital-root",
        type=Path,
        default=Path(os.environ.get("VITAL1500_ROOT", r"E:\3d健身素材\1500VitalAnimations")),
    )
    args = parser.parse_args()

    actions = __import__("json").loads(
        (args.data / "vital_actions_zh_draft.json").read_text(encoding="utf-8")
    )
    for action in actions:
        paths = []
        for media in action.get("media", []):
            relative = media["source_file"].replace("/", os.sep)
            paths.append(str(args.vital_root / relative))
        action["video_paths"] = paths
        action["primary_video_path"] = paths[0] if paths else ""
        action["primary_video_uri"] = Path(paths[0]).as_uri() if paths else ""

    fields = [
        "slug",
        "name_en",
        "name_zh_draft",
        "name_zh_llm",
        "name_zh_source",
        "xunji_candidate",
        "xunji_candidate_match_type",
        "review_priority",
        "equipment",
        "muscle_group",
        "sex_variants",
        "media_count",
        "primary_video_path",
        "all_video_paths",
        "instructions_zh",
    ]

    def row(action):
        return [
            action["slug"],
            action["name_en"],
            action["name_zh"],
            action.get("name_zh_llm", ""),
            action["name_zh_source"],
            action.get("xunji_candidate", ""),
            action.get("xunji_candidate_match_type", ""),
            action["review_priority"],
            action["equipment"],
            action["muscle_group"],
            "/".join(action["sex_variants"]),
            len(action.get("media", [])),
            action["primary_video_path"],
            " | ".join(action["video_paths"]),
            " / ".join(action.get("instructions_zh") or []),
        ]

    def write(path, rows):
        with path.open("w", encoding="utf-8-sig", newline="") as handle:
            writer = csv.writer(handle)
            writer.writerow(fields)
            for item in rows:
                writer.writerow(row(item))

    write(args.data / "vital_actions_review_videos.csv", actions)
    write(
        args.data / "review_high_videos.csv",
        [a for a in actions if a["review_priority"] == "high"],
    )
    write(
        args.data / "review_medium_videos.csv",
        [a for a in actions if a["review_priority"] == "medium"],
    )
    write(
        args.data / "review_low_videos.csv",
        [a for a in actions if a["review_priority"] == "low"],
    )

    high = [a for a in actions if a["review_priority"] == "high"]
    parts = [
        "<!doctype html><meta charset='utf-8'>",
        "<title>Vital 1500 高优先级复核</title>",
        "<style>body{font-family:system-ui,'Microsoft YaHei',sans-serif;background:#0f1520;color:#e8eef8;margin:20px}"
        "table{border-collapse:collapse;width:100%}td,th{border-bottom:1px solid #2a3545;padding:8px;vertical-align:top;text-align:left}"
        "th{position:sticky;top:0;background:#182231;z-index:1}video{width:240px;max-height:180px;background:#000}"
        "a{color:#7ba4ff}.faint{color:#8d9bb1;font-size:12px}"
        "</style><h1>Vital 1500 高优先级复核</h1>",
        f"<p class='faint'>共 {len(high)} 条 / 源视频未转码。CSV：review_high_videos.csv</p>",
        "<table><thead><tr><th>动作</th><th>中文草稿</th><th>训记候选</th><th>视频</th></tr></thead><tbody>",
    ]
    for action in high:
        video = (
            f"<video src='{html.escape(action['primary_video_uri'])}' controls preload='none'></video>"
            if action["primary_video_uri"]
            else "<span class='faint'>无视频</span>"
        )
        parts.append(
            "<tr>"
            f"<td><strong>{html.escape(action['name_en'])}</strong><div class='faint'>{html.escape(action['slug'])}</div></td>"
            f"<td>{html.escape(action['name_zh'])}<div class='faint'>{html.escape(action['name_zh_source'])}</div></td>"
            f"<td>{html.escape(action.get('xunji_candidate', '') or '—')}<div class='faint'>{html.escape(action.get('xunji_candidate_match_type', '') or '')}</div></td>"
            f"<td>{video}<div class='faint'>{html.escape(action['primary_video_path'])}</div></td>"
            "</tr>"
        )
    parts.append("</tbody></table>")
    (args.data / "review_high_videos.html").write_text("\n".join(parts), encoding="utf-8")

    print("actions", len(actions), "high", len(high))
    print("wrote", args.data / "review_high_videos.csv")
    print("wrote", args.data / "review_high_videos.html")
    print("wrote", args.data / "review_medium_videos.csv")
    print("wrote", args.data / "review_low_videos.csv")
    print("wrote", args.data / "vital_actions_review_videos.csv")


if __name__ == "__main__":
    main()
