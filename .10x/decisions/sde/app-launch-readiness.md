# SDE — app-launch-readiness

## Phase 1A — UI polish (done)
| Task | Commit | Notes |
|---|---|---|
| 1A.1 Orb hidden on detail; Delete in ⋯ menu; dismiss-then-delete | 12c4f9d | Today/Inbox own `NavigationStack(path:)`; dock shows at root or while `capture.phase != .idle`. Confirmation dialog must be attached to the Menu (iOS 26 doesn't present it from the scroll content when triggered from a toolbar menu). Delete runs 450 ms after dismiss. |
| 1A.2 Launch colour + shorter handoff | 6f66649 | `LaunchBackground` now light/dark. Handoff ~0.6 s (was ~1.3 s). Note: simulator caches launch snapshots across install-over; verify on clean install. |
| 1A.3 Denser rows, quieter labels | ad88184 | New `jotRow()` (`JotMetrics.rowInsets` 12/16). `JotCard` now takes `EdgeInsets`; `jotCard(padding:)` unchanged for callers. |
| 1A.4 Inbox grouping | ad88184 | **Deviation:** kept capture-date grouping (Inbox = capture log; Today already shows due items). Renamed headers "Captured today/yesterday/<date>". |
| 1A.5 Onboarding stability | ad88184 | Hidden 3-line placeholder in a ZStack keeps heading fixed and still grows with Dynamic Type. Sample sentence is an AttributedString with unspoken words clear. Tab icons unchanged (iOS uses fill variants; Develop tab leaves Release in Phase 2). |
| 1A.6 Tap latency | — | Not reproduced as a code bug. Pushes take ~1 s in the iOS 27 simulator (Liquid Glass + Debug). `HorizontalPan` only begins on horizontal drags. **Verify on device**; profile with Instruments if it persists. |

## Phase 1B — Reliability (done)
| Task | Commit | Notes |
|---|---|---|
| 1B.1 Capture watchdog, interruptions, gesture cancel | 046fb8e | 0.5 s wall-clock watchdog in `CaptureController`; caps 180 s held / 90 s hands-free; pause detection moved off the audio-chunk path. `AVAudioSession` interruption (began) and route change (oldDeviceUnavailable) → `stopNow()`. Orb uses `@GestureState` to catch cancelled touches. Interruption paths not exercisable in the simulator — **test on device** (incoming call, AirPods out, pull down Notification Center mid-hold). |
| 1B.2 Keep audio on transcription failure | 046fb8e | Saves a "Voice note" with playable audio when transcription throws, or returns nothing despite speech (peak level > 0.35). Silence is still discarded. |
| 1B.3 Versioned schema + fail-loud store | aff8039 | ADR-001. `SharedStore.loaded` is an immutable (container, error) pair; `canWrite` gates capture, the Siri intent, and the UI (`StoreUnavailableView`). Verified: old unversioned store opens intact; corrupted store → blocking screen. |
| 1B.4 Coalesced refill + brief preview + recurrence start | 0fd6a66 | Single in-flight refill with one rerun; reminder fields snapshotted before awaits; preview id `brief-preview` preserved. Recurring reminders with a future first date get a one-off trigger first. Monthly-on-31st still skips short months (iOS calendar trigger limitation) — documented, not fixed. |
| 1B.5 Background task around classification | 0fd6a66 | `beginBackgroundTask` around transcription + classification. |

## Tech debt
- 450 ms sleep before delete is a timing assumption; replace with deleting in the parent's `onChange(of: path)` if it ever races.
