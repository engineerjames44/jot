# Architect — app-launch-readiness

## Phase 1A (UI)
- Capture dock visibility is driven by navigation depth: Today/Inbox own a `NavigationPath`; the dock renders only at root. Detail screens get a top-bar ⋯ menu (Delete, later Re-sort/Follow-up).
- Inbox grouping is a pure function `InboxGrouping.sections(items, now:)` → testable.

## Phase 1B (Reliability)
- `CaptureController` owns a `CaptureWatchdog`: wall-clock timer (max 3 min hold / 90 s hands-free) independent of audio chunks, plus `AVAudioSession.interruptionNotification` and `routeChangeNotification` (old device unavailable) → `endCapture`.
- Transcription failure keeps the audio and saves a note ("Voice note", details explain transcription failed) with the recording playable. No schema change in 1B, because V1 must match the on-disk schema; a proper `needsTranscription` retry flag arrives in schema V2 (Phase 3).
- `ReminderScheduler.refill` becomes a coalescing actor-style queue on MainActor: one in-flight `Task`; calls during a run set `needsRerun` and run once more after.
- Store opening per ADR-001.

## Failure modes considered
Interrupted mic, offline first run (speech assets), store corruption, concurrent notification refills, deleting an object a view still observes, backgrounding mid-request.

## Phase 2+
See ADR-002 (proxy) and ADR-003 (entitlements) — written before those phases start.
