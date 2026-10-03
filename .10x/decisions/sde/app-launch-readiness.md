# SDE — app-launch-readiness

## Phase 1A — UI polish (done)
| Task | Commit | Notes |
|---|---|---|
| 1A.1 Orb hidden on detail; Delete in ⋯ menu; dismiss-then-delete | 12c4f9d | Today/Inbox own `NavigationStack(path:)`; dock shows at root or while `capture.phase != .idle`. Confirmation dialog must be attached to the Menu (iOS 26 doesn't present it from the scroll content when triggered from a toolbar menu). Delete runs 450 ms after dismiss. |
| 1A.2 Launch colour + shorter handoff | (launch commit) | `LaunchBackground` now light/dark. Handoff ~0.6 s (was ~1.3 s). Note: simulator caches launch snapshots across install-over; verify on clean install. |
| 1A.3 Denser rows, quieter labels | (rows commit) | New `jotRow()` (`JotMetrics.rowInsets` 12/16). `JotCard` now takes `EdgeInsets`; `jotCard(padding:)` unchanged for callers. |
| 1A.4 Inbox grouping | (rows commit) | **Deviation:** kept capture-date grouping (Inbox = capture log; Today already shows due items). Renamed headers "Captured today/yesterday/<date>". |
| 1A.5 Onboarding stability | (rows commit) | Hidden 3-line placeholder in a ZStack keeps heading fixed and still grows with Dynamic Type. Sample sentence is an AttributedString with unspoken words clear. Tab icons unchanged (iOS uses fill variants; Develop tab leaves Release in Phase 2). |
| 1A.6 Tap latency | — | Not reproduced as a code bug. Pushes take ~1 s in the iOS 27 simulator (Liquid Glass + Debug). `HorizontalPan` only begins on horizontal drags. **Verify on device**; profile with Instruments if it persists. |

## Tech debt
- 450 ms sleep before delete is a timing assumption; replace with deleting in the parent's `onChange(of: path)` if it ever races.
