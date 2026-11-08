#!/usr/bin/env python3
"""Build phone/watch derivatives from the VitalAnimations free sample.

This is a PoC importer: it only publishes mappings where the sample video
matches an exercise that already exists in the backend. The raw 1080p source
files stay outside the repository; only the generated derivatives and a
manifest are written under the git-ignored local media directory.

Usage (from the repository root):
    backend/.venv/Scripts/python.exe tools/media/build_vital_sample.py ^
        --source "C:\\Users\\me\\Downloads\\VitalAnimations (1)\\VitalAnimations"

    # Optional: emit SQL for the production database.
    backend/.venv/Scripts/python.exe tools/media/build_vital_sample.py ^
        --source ... --sql-out backend/media/exercises/vital/insert.sql
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import shutil
import subprocess
import sys
import uuid
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]

SOURCE_NAME = "VitalAnimations"
LICENSE_NOTE = "VitalAnimations free sample; PoC only; full license pending"

# Only exact movement matches are published. Keep this list small until the
# licensed dataset and the exercise mapping pipeline are available.
MAPPINGS = [
    {
        "video": "Free50/Free50/0054.mp4",
        "exercise_slug": "squat",
        "sex": "male",
    },
    {
        "video": "Free50/Free50/0057.mp4",
        "exercise_slug": "hip_thrust",
        "sex": "male",
    },
    {
        "video": "Free50/Free50/0060.mp4",
        "exercise_slug": "romanian_deadlift",
        "sex": "male",
    },
    {
        "video": "Free50/Free50/0064.mp4",
        "exercise_slug": "goblet_squat",
        "sex": "male",
    },
    {
        "video": "Free50/Free50/0074.mp4",
        "exercise_slug": "leg_press",
        "sex": "male",
    },
    {
        "video": "Free50/Free50/0077.mp4",
        "exercise_slug": "rowing_machine",
        "sex": "male",
    },
    {
        "video": "Free50/Free50/0085.mp4",
        "exercise_slug": "triceps_pushdown",
        "sex": "male",
    },
    {
        "video": "Free50/Free50/0086.mp4",
        "exercise_slug": "treadmill_walk",
        "sex": "male",
    },
    {
        "video": "Free50/Free50/0090.mp4",
        "exercise_slug": "shoulder_press",
        "sex": "male",
    },
    {
        "video": "Free50/Free50/0096.mp4",
        "exercise_slug": "lateral_raise",
        "sex": "male",
    },
    {
        "video": "Character Samples/homeWorkout/0473.mp4",
        "exercise_slug": "crunch",
        "sex": "female",
    },
]


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--source",
        default=os.getenv("VITAL_SAMPLE_DIR", ""),
        help="VitalAnimations sample root (contains Free50/ and Character Samples/)",
    )
    parser.add_argument(
        "--output",
        default=str(ROOT / "backend" / "media" / "exercises" / "vital"),
        help="Derivative output directory",
    )
    parser.add_argument(
        "--sql-out",
        default="",
        help="Write production INSERT statements to this path",
    )
    parser.add_argument("--phone-size", type=int, default=720)
    parser.add_argument("--watch-size", type=int, default=480)
    return parser.parse_args()


def find_ffmpeg() -> str:
    explicit = os.getenv("FFMPEG_BIN", "")
    if explicit:
        return explicit
    found = shutil.which("ffmpeg")
    if found:
        return found
    try:
        import imageio_ffmpeg  # type: ignore
    except ImportError as error:
        raise SystemExit(
            "ffmpeg not found. Install it, set FFMPEG_BIN, or "
            "pip install imageio-ffmpeg."
        ) from error
    return imageio_ffmpeg.get_ffmpeg_exe()


def run(command: list[str]) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        command,
        check=False,
        capture_output=True,
        text=True,
        encoding="utf-8",
        errors="replace",
    )


def probe_duration(ffmpeg: str, video: Path) -> float:
    result = run([ffmpeg, "-hide_banner", "-i", str(video)])
    match = re.search(r"Duration:\s*(\d+):(\d+):(\d+(?:\.\d+)?)", result.stderr)
    if not match:
        raise SystemExit(f"cannot read duration: {video}")
    hours, minutes, seconds = match.groups()
    return int(hours) * 3600 + int(minutes) * 60 + float(seconds)


def transcode(
    ffmpeg: str,
    source: Path,
    target: Path,
    size: int,
    crf: int,
    fps: int,
) -> None:
    target.parent.mkdir(parents=True, exist_ok=True)
    result = run(
        [
            ffmpeg,
            "-y",
            "-hide_banner",
            "-loglevel",
            "error",
            "-i",
            str(source),
            "-vf",
            f"scale={size}:{size}:flags=lanczos",
            "-c:v",
            "libx264",
            "-preset",
            "slow",
            "-crf",
            str(crf),
            "-pix_fmt",
            "yuv420p",
            "-r",
            str(fps),
            "-an",
            "-movflags",
            "+faststart",
            str(target),
        ]
    )
    if result.returncode != 0:
        raise SystemExit(f"ffmpeg failed: {target}\n{result.stderr}")


def poster(ffmpeg: str, source: Path, target: Path, size: int) -> None:
    result = run(
        [
            ffmpeg,
            "-y",
            "-hide_banner",
            "-loglevel",
            "error",
            "-ss",
            "0.4",
            "-i",
            str(source),
            "-frames:v",
            "1",
            "-vf",
            f"scale={size}:{size}:flags=lanczos",
            "-q:v",
            "4",
            "-update",
            "1",
            str(target),
        ]
    )
    if result.returncode != 0:
        raise SystemExit(f"ffmpeg poster failed: {target}\n{result.stderr}")


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def sql_escape(value: str) -> str:
    return value.replace("\\", "\\\\").replace("'", "''")


def write_sql(path: Path, items: list[dict]) -> None:
    statements = []
    for item in items:
        asset_id = str(uuid.uuid4())
        statements.append(
            "INSERT INTO exercise_media_assets "
            "(id, exercise_slug, sex, source, phone_url, watch_url, poster_url, "
            "duration_seconds, loop_start_ms, loop_end_ms, watch_sha256, version, "
            "status, license_note, created_at, updated_at) VALUES ("
            f"'{asset_id}', '{sql_escape(item['exercise_slug'])}', "
            f"'{sql_escape(item['sex'])}', '{sql_escape(item['source'])}', "
            f"'{sql_escape(item['phone_url'])}', "
            f"'{sql_escape(item['watch_url'])}', "
            f"'{sql_escape(item['poster_url'])}', "
            f"{item['duration_seconds']}, {item['loop_start_ms']}, "
            f"{item['loop_end_ms']}, '{item['sha256']}', {item['version']}, "
            f"'published', '{sql_escape(item['license_note'])}', NOW(), NOW()"
            ") ON DUPLICATE KEY UPDATE "
            "source=VALUES(source), phone_url=VALUES(phone_url), "
            "watch_url=VALUES(watch_url), poster_url=VALUES(poster_url), "
            "duration_seconds=VALUES(duration_seconds), "
            "loop_start_ms=VALUES(loop_start_ms), "
            "loop_end_ms=VALUES(loop_end_ms), watch_sha256=VALUES(watch_sha256), "
            "status=VALUES(status), license_note=VALUES(license_note), "
            "updated_at=NOW();"
        )
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text("\n".join(statements) + "\n", encoding="utf-8")


def main() -> int:
    args = parse_args()
    if not args.source:
        raise SystemExit("--source is required (or set VITAL_SAMPLE_DIR)")

    source_root = Path(args.source).expanduser().resolve()
    if not source_root.is_dir():
        raise SystemExit(f"source directory not found: {source_root}")

    output_root = Path(args.output).expanduser().resolve()
    output_root.mkdir(parents=True, exist_ok=True)
    ffmpeg = find_ffmpeg()

    items: list[dict] = []
    for mapping in MAPPINGS:
        source = source_root / mapping["video"]
        if not source.is_file():
            raise SystemExit(f"sample video missing: {source}")

        slug = mapping["exercise_slug"]
        sex = mapping["sex"]
        folder = output_root / slug
        phone_path = folder / f"{sex}-phone.mp4"
        watch_path = folder / f"{sex}-watch.mp4"
        poster_path = folder / f"{sex}-poster.jpg"

        duration = probe_duration(ffmpeg, source)
        transcode(
            ffmpeg,
            source,
            phone_path,
            args.phone_size,
            crf=23,
            fps=30,
        )
        transcode(
            ffmpeg,
            source,
            watch_path,
            args.watch_size,
            crf=26,
            fps=24,
        )
        poster(ffmpeg, source, poster_path, args.phone_size)

        relative = Path("exercises") / "vital" / slug
        items.append(
            {
                "exercise_slug": slug,
                "sex": sex,
                "source": SOURCE_NAME,
                "phone_url": f"/media/{relative.as_posix()}/{sex}-phone.mp4",
                "watch_url": f"/media/{relative.as_posix()}/{sex}-watch.mp4",
                "poster_url": f"/media/{relative.as_posix()}/{sex}-poster.jpg",
                "duration_seconds": round(duration),
                "loop_start_ms": 0,
                "loop_end_ms": int(round(duration * 1000)),
                "sha256": sha256(watch_path),
                "version": 1,
                "license_note": LICENSE_NOTE,
            }
        )
        print(
            f"{slug:20s} {sex:6s} "
            f"phone={phone_path.stat().st_size // 1024:5d}KB "
            f"watch={watch_path.stat().st_size // 1024:5d}KB"
        )

    manifest_path = output_root / "manifest.json"
    manifest_path.write_text(
        json.dumps(
            {
                "source": SOURCE_NAME,
                "license_note": LICENSE_NOTE,
                "items": items,
            },
            ensure_ascii=False,
            indent=2,
        )
        + "\n",
        encoding="utf-8",
    )
    print(f"manifest: {manifest_path}")

    if args.sql_out:
        sql_path = Path(args.sql_out).expanduser().resolve()
        write_sql(sql_path, items)
        print(f"sql: {sql_path}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
