# ADR 0001 · Apple Watch standalone workout

Status: accepted

Date: 2026-11-07

## Context

The iPhone app already owns the workout flow. The Apple Watch must be able to
run the same workout while the iPhone is in a locker, show a looping 3D
exercise animation, and accept commands from either device.

The first implementation must not depend on the iPhone being reachable during
the workout. It also must not create a second, divergent workout model.

## Decisions

1. **Shared core, separate UI**
   - Workout state lives in `ios/FitAIWorkoutCore`.
   - iOS and watchOS both render the same snapshot.
   - UI code remains platform-specific.

2. **Watch is the session leader**
   - The watch owns set progress and rest timing during a watch-led session.
   - The phone may send commands when reachable; it is read-only offline.
   - No split-brain editing.

3. **Commands, not mutations**
   - Every state change is a `WorkoutCommand` with an `operationID`.
   - `(exerciseID, setIndex)` is the idempotency key for completed sets.
   - The engine uses command timestamps; it never reads the wall clock.

4. **Offline-first**
   - The phone preloads the plan, media manifest and watch entitlement before
     the phone is left in a locker.
   - The watch persists every applied command and can recover after a crash.
   - Pro entitlement has a three-day verification grace, but the
     `pro_expires_at` timestamp is always a hard stop.
   - An already-started session may finish after expiry.

5. **Media**
   - The watch plays short H.264 MP4 loops through `WKInterfaceInlineMovie`.
   - Only the current day's clips are cached on the watch.
   - Fallback order: watch clip -> poster -> text instructions.
   - The iPhone remains the source for downloading and transferring clips.

6. **Voice**
   - Voice input uses watchOS system dictation (`TextFieldLink`) and a
     text/scribble fallback. `SFSpeechRecognizer` is not available on watchOS.
   - Replies are spoken with `AVSpeechSynthesizer`.
   - Text is always displayed. The default is silent; headphones may enable
     automatic playback.
   - Voice is an AI Q&A surface only. Plan changes are confirmed on iPhone.

7. **Entitlement**
   - Apple Watch training and watch voice are Pro-only.
   - No standard trial; the existing admin server grants promotional Pro days.
   - Family Sharing remains disabled.

## Non-goals

- Android
- watchOS plan editing or purchase
- cloud STT/TTS and always-on voice
- complications, Action Button, live heart-rate zones
- 3D animation UI on iPhone
