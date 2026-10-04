# Jot

A voice-first personal hub for iOS 26. Hold the mic button, speak, and Jot turns
it into a note, task, reminder, or calendar event.

## Pipeline

```
AudioSource (MicAudioSource; BLE later)
  → SpeechTranscription (SpeechAnalyzer, on-device)
  → OnDeviceClassifier (Apple Foundation Models, default)
    or ProxyClassifier (Claude Haiku 4.5 via jamescronin.dev/api/jot/classify, opt-in)
  → JotItem (SwiftData)
  → ReminderScheduler (local notifications, soonest 64)
```

| Folder | What's there |
| --- | --- |
| `Jot/Audio` | `AudioSource` protocol and the mic implementation |
| `Jot/Speech` | On-device transcription and format conversion |
| `Jot/AI` | Sorting: on-device classifier (default), the jamescronin.dev proxy for Claude (opt-in), prompts and parsing |
| `Jot/Model` | `JotItem` SwiftData model |
| `Jot/Services` | Capture loop, Keychain, notifications, EventKit (read-only) |
| `Jot/Views` | Today, Inbox, item detail, Settings, record button |

### Adding the BLE source

Implement `AudioSource` (return an `AsyncStream<AudioChunk>` of PCM buffers in any
format, finish it on `stop()`) and pass it to `CaptureController(source:)` in
`JotApp`. Transcription converts to the analyzer's format itself.

## Targets

| Target | What it is |
| --- | --- |
| `Jot` | The app |
| `JotWidgets` | Home/Lock Screen widgets, the Control Center control, and the capture Live Activity |

`Shared/` is compiled into both: the SwiftData model, design system, brand colors,
the App Group store, Live Activity attributes, and the record intent. Both targets
use the App Group `group.com.jamescronin.Jot` so they read the same items.

## Develop tab (change notes)

A tab for noting changes to Jot itself as you use it. Tap the orb to record (tap
again to save); the words are kept exactly as said (no Claude), along with the
recording, the screen you were on, and the app version. **Shake the phone
anywhere** to record a note tagged with the current screen. **Export PDF** or
**Export TXT** makes a file of every note (open ones grouped into Bugs, Changes,
and Ideas, then Done) and opens the share sheet: Save to Files, AirDrop, Mail, and so on.

On by default in Debug builds, off in Release; toggle it in Settings › Developer.

## Setup

1. Open `Jot.xcodeproj` in Xcode 26.
2. Pick your team under Signing & Capabilities (and change the bundle ID if needed).
3. Run on a device or simulator. Sorting works out of the box on Apple's on-device model.
   Claude sorting is an opt-in under **Settings**; it goes through the jamescronin.dev proxy,
   which holds the API key, so Release builds never hold a key. Debug builds also accept a personal
   Claude key in Settings (Keychain only) for experiments, which calls Claude directly.

For UI work, launch a Debug build with the argument `-JotSampleData YES`
(Edit Scheme › Run › Arguments) to fill an empty store with a sample day and sample change notes.

The first recording downloads the on-device speech model for your language.
If sorting fails (model unavailable, offline), the transcript is saved as a note and sorted later, so nothing is lost.
