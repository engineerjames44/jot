# Jot

A voice-first personal hub for iOS 26. Hold the mic button, speak, and Jot turns
it into a note, task, reminder, or calendar event.

## Pipeline

```
AudioSource (MicAudioSource; BLE later)
  → SpeechTranscription (SpeechAnalyzer, on-device)
  → ClaudeClassifier (claude-haiku-4-5-20251001, JSON schema output)
  → JotItem (SwiftData)
  → ReminderScheduler (local notifications, soonest 64)
```

| Folder | What's there |
| --- | --- |
| `Jot/Audio` | `AudioSource` protocol and the mic implementation |
| `Jot/Speech` | On-device transcription and format conversion |
| `Jot/AI` | Claude Messages API call, prompt, and response parsing |
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
3. Run on a device or simulator, open **Settings**, and paste your Claude API key.
   It's stored in the Keychain only — never in the repo or in code.

For UI work, launch a Debug build with the argument `-JotSampleData YES`
(Edit Scheme › Run › Arguments) to fill an empty store with a sample day and sample change notes.

The first recording downloads the on-device speech model for your language.
If the Claude call fails (no key, offline), the transcript is saved as a note so nothing is lost.
