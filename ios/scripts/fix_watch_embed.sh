#!/bin/bash
# Xcode 26+ requires watchOS companion apps to live in the parent app's
# PlugIns/ directory. XcodeGen (<= 2.45.x) still generates the legacy
# Watch/ destination for `embed: true`, which makes the Watch app appear in
# the iPhone Watch app list but fail with "Could not install at this time".
#
# This post-generation hook rewrites the generated copy phase:
#   dstPath = "$(CONTENTS_FOLDER_PATH)/Watch"; -> dstPath = "";
#   dstSubfolderSpec = 16;                     -> dstSubfolderSpec = 13;
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
if [ -f "$ROOT/FitAI.xcodeproj/project.pbxproj" ]; then
  PBX="$ROOT/FitAI.xcodeproj/project.pbxproj"
elif [ -f "$ROOT/ios/FitAI.xcodeproj/project.pbxproj" ]; then
  PBX="$ROOT/ios/FitAI.xcodeproj/project.pbxproj"
else
  echo "watch embed fix: FitAI.xcodeproj not found under $ROOT" >&2
  exit 1
fi

before="$(grep -c 'CONTENTS_FOLDER_PATH)/Watch' "$PBX" || true)"
if [ "$before" -eq 0 ]; then
  echo "watch embed fix: already in PlugIns/ (nothing to do)"
  exit 0
fi

sed -i '' \
  -e 's|dstPath = "$(CONTENTS_FOLDER_PATH)/Watch";|dstPath = "";|g' \
  -e 's|dstSubfolderSpec = 16;|dstSubfolderSpec = 13;|g' \
  "$PBX"

after="$(grep -c 'CONTENTS_FOLDER_PATH)/Watch' "$PBX" || true)"
if [ "$after" -ne 0 ]; then
  echo "watch embed fix: failed, Watch/ destination still present" >&2
  exit 1
fi

echo "watch embed fix: moved Watch app to PlugIns/ (patched $before copy phase)"
