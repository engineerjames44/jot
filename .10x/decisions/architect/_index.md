# Architect — index
- [DISCOVERED] Layers: `Audio/` (AudioSource → MicAudioSource, AudioTee writes .m4a) → `Speech/` (SpeechTranscription) → `AI/` (ClaudeClassifier, injected as `Classify` closure into CaptureController) → `Model/` (JotItem, SwiftData in App Group via `SharedStore`) → `Services/` (ReminderScheduler, CalendarService read-only, MorningBrief, LiveActivityController, ItemActions) → `Views/`.
- [DISCOVERED] Widgets/intents share `Shared/` (model, design system, App Group store, Live Activity attributes, StartRecordingIntent).
- [DISCOVERED] Capture state machine lives in `CaptureController` (`phase`: idle/starting/recording/transcribing/classifying/saved/failed).
## Features
- app-launch-readiness (ADR-001 schema versioning; ADR-002 classifier proxy; ADR-003 entitlements)
