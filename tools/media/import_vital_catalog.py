#!/usr/bin/env python3
"""Generate the backend import artifacts for the Vital action library.

Two modes:

1. Catalog SQL + media manifest (no transcoding, fast):
       python tools/media/import_vital_catalog.py \
           --catalog data/vital/vital_actions_v2.json \
           --sql-out data/vital/exercises_insert.sql \
           --manifest data/vital/media_manifest.json

2. Transcode + media SQL (heavy; run after reviewing the schema):
       python tools/media/import_vital_catalog.py \
           --catalog data/vital/vital_actions_v2.json \
           --source "E:\\3d健身素材\\1500VitalAnimations" \
           --transcode --output backend/media/exercises/vital \
           --media-sql data/vital/media_insert.sql \
           --ffmpeg D:\\EVCapture\\ffmpeg.exe
"""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import subprocess
import uuid
from pathlib import Path

LICENSE_NOTE = "Vital Animations EULA 2026.1"
SOURCE_NAME = "vital_animations"

PHONE_SIZE = 1080
WATCH_SIZE = 360


def sql_escape(value: str) -> str:
    return value.replace("\\", "\\\\").replace("'", "''")


def variant_key_for(md: dict) -> str:
    vid = str(md.get("video_id") or "").strip()
    stem = Path(md.get("source_file", "")).stem
    base = vid or stem
    return f"{md.get('pack', '')}-{base}"


def load_actions(catalog: Path) -> list[dict]:
    return json.loads(catalog.read_text(encoding="utf-8"))


def write_exercises_sql(actions: list[dict], out: Path) -> None:
    statements = []
    for a in actions:
        slug = a["slug"]
        name_zh = a["name_zh"]
        name_en = (a.get("name_en") or "").strip()
        muscle = a.get("muscle_group") or "core"
        equipment = a.get("equipment") or "other"
        is_compound = 1 if a.get("is_compound") else 0
        difficulty = int(a.get("difficulty") or 1)
        steps = a.get("instructions_zh") or []
        instructions = "\n".join(str(s) for s in steps) if steps else ""
        name_en_sql = f"'{sql_escape(name_en)}'" if name_en else "NULL"
        statements.append(
            "INSERT INTO exercises "
            "(slug, name_zh, name_en, muscle_group, equipment, is_compound, "
            "difficulty, instructions, contraindications, is_active, source, "
            "license, created_at) VALUES ("
            f"'{sql_escape(slug)}', '{sql_escape(name_zh)}', {name_en_sql}, "
            f"'{sql_escape(muscle)}', '{sql_escape(equipment)}', {is_compound}, "
            f"{difficulty}, '{sql_escape(instructions)}', '[]', 1, "
            f"'{SOURCE_NAME}', '{LICENSE_NOTE}', NOW()) "
            "ON DUPLICATE KEY UPDATE "
            "name_zh=VALUES(name_zh), name_en=VALUES(name_en), "
            "muscle_group=VALUES(muscle_group), equipment=VALUES(equipment), "
            "is_compound=VALUES(is_compound), difficulty=VALUES(difficulty), "
            "instructions=VALUES(instructions), source=VALUES(source), "
            "license=VALUES(license);"
        )
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text("\n".join(statements) + "\n", encoding="utf-8")


def build_manifest(actions: list[dict]) -> tuple[list[dict], dict[str, str]]:
    """Return (manifest_rows, variant_key_by_source_file)."""
    rows: list[dict] = []
    key_of: dict[str, str] = {}
    used: dict[str, str] = {}
    for a in actions:
        for md in a.get("media", []):
            src = md.get("source_file")
            if not src:
                continue
            key = variant_key_for(md)
            if key in used and used[key] != src:
                digest = hashlib.sha1(src.encode("utf-8")).hexdigest()[:6]
                key = f"{key}-{digest}"
            used.setdefault(key, src)
            key_of[src] = key
            rows.append(
                {
                    "slug": a["slug"],
                    "name_zh": a["name_zh"],
                    "variant_key": key,
                    "source_pack": md.get("pack"),
                    "sex": md.get("sex"),
                    "visual_style": md.get("visual_style"),
                    "visual_priority": md.get("visual_priority"),
                    "is_primary_for_watch": bool(md.get("primary_for_watch")),
                    "source_file": src,
                    "size_bytes": md.get("size_bytes"),
                    "note": md.get("note"),
                }
            )
    return rows, key_of


def write_manifest(rows: list[dict], out: Path) -> None:
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(
        json.dumps(rows, ensure_ascii=False, indent=1), encoding="utf-8"
    )


# ---------------------------------------------------------------------------
# Transcode helpers (mode 2)
# ---------------------------------------------------------------------------

def run(command: list[str]) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        command, check=False, capture_output=True, text=True,
        encoding="utf-8", errors="replace",
    )


def probe_duration(ffmpeg: str, video: Path) -> float:
    result = run([ffmpeg, "-hide_banner", "-i", str(video)])
    match = re.search(r"Duration:\s*(\d+):(\d+):(\d+(?:\.\d+)?)", result.stderr)
    if not match:
        raise SystemExit(f"cannot read duration: {video}")
    h, m, s = match.groups()
    return int(h) * 3600 + int(m) * 60 + float(s)


def transcode(
    ffmpeg: str, source: Path, target: Path, size: int, crf: int, fps: int, preset: str
) -> None:
    target.parent.mkdir(parents=True, exist_ok=True)
    result = run([
        ffmpeg, "-y", "-hide_banner", "-loglevel", "error",
        "-i", str(source),
        "-vf",
        f"scale={size}:{size}:force_original_aspect_ratio=decrease,"
        f"pad={size}:{size}:(ow-iw)/2:(oh-ih)/2:color=white",
        "-c:v", "libx264", "-preset", preset, "-crf", str(crf),
        "-pix_fmt", "yuv420p", "-r", str(fps), "-an",
        "-movflags", "+faststart", str(target),
    ])
    if result.returncode != 0:
        raise SystemExit(f"ffmpeg failed: {target}\n{result.stderr}")


def poster(ffmpeg: str, source: Path, target: Path, size: int) -> None:
    result = run([
        ffmpeg, "-y", "-hide_banner", "-loglevel", "error",
        "-ss", "0.4", "-i", str(source),
        "-frames:v", "1",
        "-vf",
        f"scale={size}:{size}:force_original_aspect_ratio=decrease,"
        f"pad={size}:{size}:(ow-iw)/2:(oh-ih)/2:color=white",
        "-q:v", "4", "-update", "1", str(target),
    ])
    if result.returncode != 0:
        raise SystemExit(f"ffmpeg poster failed: {target}\n{result.stderr}")


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def write_media_sql(rows: list[dict], out: Path) -> None:
    statements = []
    for r in rows:
        if not r.get("phone_url"):
            continue
        asset_id = str(uuid.uuid4())
        statements.append(
            "INSERT INTO exercise_media_assets "
            "(id, exercise_slug, sex, variant_key, source_pack, visual_style, "
            "visual_priority, source, phone_url, watch_url, poster_url, "
            "duration_seconds, loop_start_ms, loop_end_ms, watch_sha256, "
            "version, status, license_note, created_at, updated_at) VALUES ("
            f"'{asset_id}', '{sql_escape(r['slug'])}', "
            f"'{sql_escape(r['sex'])}', '{sql_escape(r['variant_key'])}', "
            f"'{sql_escape(r['source_pack'])}', "
            f"'{sql_escape(r['visual_style'])}', {r['visual_priority']}, "
            f"'{SOURCE_NAME}', '{sql_escape(r['phone_url'])}', "
            f"'{sql_escape(r['watch_url'])}', "
            f"'{sql_escape(r['poster_url'])}', "
            f"{r['duration_seconds']}, {r['loop_start_ms']}, "
            f"{r['loop_end_ms']}, '{r['sha256']}', 1, 'published', "
            f"'{LICENSE_NOTE}', NOW(), NOW()) "
            "ON DUPLICATE KEY UPDATE "
            "sex=VALUES(sex), source_pack=VALUES(source_pack), "
            "visual_style=VALUES(visual_style), "
            "visual_priority=VALUES(visual_priority), "
            "source=VALUES(source), phone_url=VALUES(phone_url), "
            "watch_url=VALUES(watch_url), poster_url=VALUES(poster_url), "
            "duration_seconds=VALUES(duration_seconds), "
            "loop_start_ms=VALUES(loop_start_ms), "
            "loop_end_ms=VALUES(loop_end_ms), "
            "watch_sha256=VALUES(watch_sha256), status=VALUES(status), "
            "license_note=VALUES(license_note), updated_at=NOW();"
        )
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text("\n".join(statements) + "\n", encoding="utf-8")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--catalog", default="data/vital/vital_actions_v2.json")
    parser.add_argument("--sql-out", default="data/vital/exercises_insert.sql")
    parser.add_argument("--manifest", default="data/vital/media_manifest.json")
    parser.add_argument("--source", default="", help="1500VitalAnimations root")
    parser.add_argument("--transcode", action="store_true")
    parser.add_argument("--output", default="backend/media/exercises/vital")
    parser.add_argument("--media-sql", default="data/vital/media_insert.sql")
    parser.add_argument("--ffmpeg", default="")
    parser.add_argument("--phone-size", type=int, default=PHONE_SIZE)
    parser.add_argument("--watch-size", type=int, default=WATCH_SIZE)
    parser.add_argument("--preset", default="medium")
    parser.add_argument("--jobs", type=int, default=4)
    parser.add_argument("--limit", type=int, default=0, help="只处理前 N 条（测试用）")
    args = parser.parse_args()

    actions = load_actions(Path(args.catalog))
    write_exercises_sql(actions, Path(args.sql_out))
    rows, key_of = build_manifest(actions)
    write_manifest(rows, Path(args.manifest))
    print(f"actions={len(actions)} manifest_rows={len(rows)}")
    print(f"wrote {args.sql_out}")
    print(f"wrote {args.manifest}")

    if not args.transcode:
        return 0

    if not args.source:
        raise SystemExit("--source is required with --transcode")
    source_root = Path(args.source).expanduser().resolve()
    ffmpeg = args.ffmpeg or "ffmpeg"
    output_root = Path(args.output).expanduser().resolve()
    output_root.mkdir(parents=True, exist_ok=True)

    work = rows if args.limit <= 0 else rows[: args.limit]

    from concurrent.futures import ThreadPoolExecutor
    import threading

    print_lock = threading.Lock()
    missing = 0

    def process(r: dict) -> None:
        nonlocal missing
        src = source_root / r["source_file"].replace("/", "\\")
        if not src.is_file():
            with print_lock:
                missing += 1
                print(f"MISSING {r['source_file']}")
            return
        slug = r["slug"]
        folder = output_root / slug / r["variant_key"] / "v1"
        phone_path = folder / "iphone.mp4"
        watch_path = folder / "watch.mp4"
        poster_path = folder / "poster.jpg"
        duration = probe_duration(ffmpeg, src)
        transcode(ffmpeg, src, phone_path, args.phone_size, crf=23, fps=30, preset=args.preset)
        transcode(ffmpeg, src, watch_path, args.watch_size, crf=26, fps=24, preset=args.preset)
        poster(ffmpeg, src, poster_path, args.phone_size)
        rel = Path("exercises") / "vital" / slug / r["variant_key"] / "v1"
        r["phone_url"] = f"/media/{rel.as_posix()}/iphone.mp4"
        r["watch_url"] = f"/media/{rel.as_posix()}/watch.mp4"
        r["poster_url"] = f"/media/{rel.as_posix()}/poster.jpg"
        r["duration_seconds"] = round(duration)
        r["loop_start_ms"] = 0
        r["loop_end_ms"] = int(round(duration * 1000))
        r["sha256"] = sha256(watch_path)
        with print_lock:
            print(
                f"{slug:36s} {r['variant_key']:22s} "
                f"phone={phone_path.stat().st_size // 1024}KB "
                f"watch={watch_path.stat().st_size // 1024}KB"
            )

    with ThreadPoolExecutor(max_workers=args.jobs) as pool:
        list(pool.map(process, work))

    print(f"missing={missing} processed={len(work) - missing}")

    write_media_sql(rows, Path(args.media_sql))
    print(f"wrote {args.media_sql}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
