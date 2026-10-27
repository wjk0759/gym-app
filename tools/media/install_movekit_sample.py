#!/usr/bin/env python3
"""Install the free MoveKit sample clips for local evaluation.

The sample is downloaded from MoveKit's public free-sample endpoint. It may be
used inside a product under the MoveKit License, but the raw files must not be
redistributed. This script therefore writes the MP4/PNG files only into the
git-ignored local media directory and creates published ExerciseVideo rows.

Usage (from the repository root):
    backend/.venv/Scripts/python.exe tools/media/install_movekit_sample.py
    backend/.venv/Scripts/python.exe tools/media/install_movekit_sample.py --dry-run
    backend/.venv/Scripts/python.exe tools/media/install_movekit_sample.py --remove

The sample maps Pull Ups to the existing ``pullup`` exercise and Dumbbell Chest
Fly to the existing ``dumbbell_fly`` exercise. No production media is included
in this repository.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import shutil
import sys
import tempfile
import urllib.request
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "backend"))
os.chdir(ROOT / "backend")

from sqlalchemy import select  # noqa: E402

from app.db import SessionLocal  # noqa: E402
from app.models import Exercise, ExerciseVideo  # noqa: E402

SAMPLE_URL = "https://movekit.com/downloads/movekit-free-sample.zip"
SAMPLE_SHA256 = "b5583c15c427506be2154e113105c31fae74a1d126a9c3ef0e45f62cb69ff1e9"
SOURCE = "MoveKit free sample"
LICENSE_NOTE = "MoveKit License v1.0; free sample; no raw redistribution"
MAPPINGS = {
    "dumbbell-chest-fly": {
        "exercise_slug": "dumbbell_fly",
        "title": "哑铃飞鸟 · MoveKit 示例",
        "description": "MoveKit 免费示例：3D 人体哑铃飞鸟动作演示。",
    },
    "pull-ups": {
        "exercise_slug": "pullup",
        "title": "引体向上 · MoveKit 示例",
        "description": "MoveKit 免费示例：3D 人体引体向上动作演示。",
    },
}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--zip", default="", help="Use a local sample ZIP instead of downloading")
    parser.add_argument("--dry-run", action="store_true", help="Validate files without writing")
    parser.add_argument("--remove", action="store_true", help="Remove installed sample rows and files")
    return parser.parse_args()


def download_sample() -> Path:
    target = Path(tempfile.gettempdir()) / "movekit-free-sample.zip"
    if target.exists():
        digest = hashlib.sha256(target.read_bytes()).hexdigest()
        if digest == SAMPLE_SHA256:
            return target
    print(f"downloading {SAMPLE_URL}")
    with urllib.request.urlopen(SAMPLE_URL, timeout=120) as response:
        target.write_bytes(response.read())
    digest = hashlib.sha256(target.read_bytes()).hexdigest()
    if digest != SAMPLE_SHA256:
        raise SystemExit(f"sample checksum mismatch: expected {SAMPLE_SHA256}, got {digest}")
    return target


def extract(zip_path: Path) -> Path:
    dest = Path(tempfile.gettempdir()) / "movekit-free-sample-extracted"
    if dest.exists():
        shutil.rmtree(dest)
    dest.mkdir(parents=True)
    with zipfile.ZipFile(zip_path) as archive:
        archive.extractall(dest)
    return dest


def media_paths(root: Path, sample_slug: str) -> tuple[Path, Path]:
    base = root / "exercises" / "movekit"
    return base / f"{sample_slug}.mp4", base / f"{sample_slug}.png"


def main() -> int:
    args = parse_args()
    with SessionLocal() as session:
        exercises = {
            row.slug: row
            for row in session.execute(
                select(Exercise).where(Exercise.slug.in_([item["exercise_slug"] for item in MAPPINGS.values()]))
            ).scalars()
        }
        missing = [
            item["exercise_slug"]
            for item in MAPPINGS.values()
            if item["exercise_slug"] not in exercises
        ]
        if missing:
            raise SystemExit("exercise slug(s) not found: " + ", ".join(missing))

        media_root = Path(os.getenv("MEDIA_ROOT", "media"))
        if not media_root.is_absolute():
            media_root = (ROOT / "backend" / media_root).resolve()

        if args.remove:
            print("removing sample database rows and files")
            if not args.dry_run:
                for item in MAPPINGS.values():
                    rows = session.execute(
                        select(ExerciseVideo).where(
                            ExerciseVideo.exercise_slug == item["exercise_slug"],
                            ExerciseVideo.source == SOURCE,
                        )
                    ).scalars().all()
                    for row in rows:
                        session.delete(row)
                for sample_slug in MAPPINGS:
                    video, poster = media_paths(media_root, sample_slug)
                    video.unlink(missing_ok=True)
                    poster.unlink(missing_ok=True)
                session.commit()
            return 0

        sample_dir = extract(Path(args.zip) if args.zip else download_sample())
        metadata = json.loads((sample_dir / "metadata.json").read_text(encoding="utf-8"))
        by_slug = {item["slug"]: item for item in metadata}

        print(f"sample directory: {sample_dir}")
        print(f"media root: {media_root}")
        for sample_slug, mapping in MAPPINGS.items():
            item = by_slug.get(sample_slug)
            if not item:
                raise SystemExit(f"metadata missing sample: {sample_slug}")
            video_src = sample_dir / item["videoFile"]
            poster_src = sample_dir / item["posterFile"]
            if not video_src.exists() or not poster_src.exists():
                raise SystemExit(f"sample media missing: {sample_slug}")
            video_dest, poster_dest = media_paths(media_root, sample_slug)
            print(
                f"{mapping['exercise_slug']}: {video_src.name} -> {video_dest} "
                f"({video_src.stat().st_size / 1024 / 1024:.1f} MB)"
            )
            if args.dry_run:
                continue
            video_dest.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(video_src, video_dest)
            shutil.copy2(poster_src, poster_dest)
            video_url = f"/media/exercises/movekit/{video_dest.name}"
            poster_url = f"/media/exercises/movekit/{poster_dest.name}"
            row = session.execute(
                select(ExerciseVideo).where(
                    ExerciseVideo.exercise_slug == mapping["exercise_slug"],
                    ExerciseVideo.source == SOURCE,
                )
            ).scalars().first()
            if row is None:
                row = ExerciseVideo(
                    exercise_slug=mapping["exercise_slug"],
                    source=SOURCE,
                    created_by="sample-installer",
                )
                session.add(row)
            row.title = mapping["title"]
            row.description = mapping["description"]
            row.video_url = video_url
            row.poster_url = poster_url
            row.duration_seconds = round(float(item.get("durationSeconds") or 0))
            row.license_note = LICENSE_NOTE
            row.status = "published"
            row.version = 1
            print(f"  db: {mapping['exercise_slug']} -> {video_url}")
        if not args.dry_run:
            session.commit()
            print("installed. Open an exercise detail in the App to test.")
            print("API: /api/v1/videos/pullup and /api/v1/videos/dumbbell_fly")
        else:
            print("dry run only; no files or rows were written")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
