from __future__ import annotations

import json
import subprocess
from collections import defaultdict
from pathlib import Path

DATA = Path("data/vital").resolve()
ROOT = Path(r"E:\3d健身素材\1500VitalAnimations")
FFMPEG = r"D:\EVCapture\ffmpeg.exe"
SHEET_DIR = DATA / "contact_sheets"

SAMPLE_PER_PACK = 6


def main() -> None:
    actions = json.loads((DATA / "vital_actions_zh_draft.json").read_text(encoding="utf-8"))

    groups = defaultdict(list)
    for a in actions:
        for m in a.get("media", []):
            groups[(m.get("pack"), m.get("sex"))].append(m.get("source_file", ""))

    SHEET_DIR.mkdir(parents=True, exist_ok=True)

    sections = []
    for (pack, sex), files in sorted(groups.items()):
        files = sorted(set(files))
        samples = files[:: max(1, len(files) // SAMPLE_PER_PACK)][:SAMPLE_PER_PACK]
        pack_dir = SHEET_DIR / pack
        pack_dir.mkdir(parents=True, exist_ok=True)

        imgs = []
        for i, rel in enumerate(samples):
            src = ROOT / rel.replace("/", "\\")
            out = pack_dir / f"{i}.jpg"
            if not out.exists() and src.exists():
                subprocess.run(
                    [
                        FFMPEG, "-y", "-ss", "0.6", "-i", str(src),
                        "-frames:v", "1", "-q:v", "3", str(out),
                    ],
                    check=False,
                    capture_output=True,
                )
            if out.exists():
                imgs.append((out.as_uri(), rel))
            else:
                imgs.append(("", rel))

        cells = []
        for uri, rel in imgs:
            if uri:
                cells.append(
                    f"<figure style='margin:6px'>"
                    f"<img src='{uri}' style='width:200px;height:112px;object-fit:cover;background:#000;border-radius:4px'>"
                    f"<figcaption style='font-size:10px;color:#8d9bb1;max-width:200px;word-break:break-all'>{Path(rel).name}</figcaption>"
                    f"</figure>"
                )
            else:
                cells.append(
                    f"<figure style='margin:6px;width:200px;height:112px;border:1px dashed #3a4a60;display:flex;align-items:center;justify-content:center;color:#8d9bb1'>无帧</figure>"
                )
        sections.append(
            "<div class='pack'>"
            f"<div class='pname'>pack=<b>{pack}</b> · sex={sex} · n={len(files)}</div>"
            f"<div class='grid'>{''.join(cells)}</div>"
            "</div>"
        )

    html = (
        "<!doctype html><meta charset='utf-8'><title>Vital 视觉分类 contact sheet</title>"
        "<style>"
        "body{font-family:system-ui,'Microsoft YaHei',sans-serif;background:#0f1520;color:#e8eef8;margin:20px}"
        "h1{font-size:20px}.pack{border:1px solid #2a3545;border-radius:10px;padding:14px;margin:16px 0;background:#182231}"
        ".pname{font-size:15px;margin-bottom:10px}.grid{display:flex;flex-wrap:wrap}"
        ".legend{color:#8d9bb1;font-size:13px;margin:10px 0}"
        "</style>"
        "<h1>Vital 视觉分类 contact sheet（请对照 6 类模型填写）</h1>"
        "<div class='legend'>"
        "请告诉我每个 pack 对应哪一类：<br>"
        "① 灰色T恤3D人 ② 金发真人女 ③ 黑色背心真人女 ④ 红色背心3D男 ⑤ 肉色背心3D女 ⑥ 黑色背心3D肌肉建模女<br>"
        "（一个 pack 里如果混了多种，也请指出）"
        "</div>"
        + "".join(sections)
        + "</body>"
    )
    (DATA / "visual_contact_sheet.html").write_text(html, encoding="utf-8")
    print("packs", len(sections), "frames dir", SHEET_DIR)
    print("wrote", DATA / "visual_contact_sheet.html")


if __name__ == "__main__":
    main()
