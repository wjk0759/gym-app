# MoveKit free sample notice

The two local demo clips installed by
`tools/media/install_movekit_sample.py` come from MoveKit's public free sample:

- Download: https://movekit.com/downloads/movekit-free-sample.zip
- Sample contents: two H.264 MP4 clips, poster PNGs, metadata, and license notice
- License: MoveKit License Agreement v1.0
- License summary: https://movekit.com/licensing
- Full agreement: https://movekit.com/license

Allowed inside this product: use in the app, websites, courses, ads, and
self-host the files for users, including through a CDN or signed URLs.

Not allowed: resell/redistribute the raw MP4, poster, or metadata as a
standalone asset pack; publish raw download links; use the animation as AI
training data or to create AI-derived media.

The downloaded clips are intentionally **not committed** to this repository.
The script writes them to the git-ignored local `backend/media/exercises/movekit`
directory and creates published `exercise_videos` rows. Run `--remove` to
delete the local sample files and database rows after evaluation.
