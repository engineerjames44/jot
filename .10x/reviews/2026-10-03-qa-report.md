# QA — app-launch-readiness

## Automated (JotTests, Swift Testing) — 26 tests, all passing
Date parsing (offsets, local times, junk), recurrence + completion roll-forward, notification triggers (incl. future-start repeating), sorting error mapping, V1→V2 migration on a real store file, SortLater apply + consent gate, undo delete (same-ID restore, replacement), JotLink round-trips.

## Verified in simulator (iPhone 17, iOS 27 sim, Debug)
- Orb hidden on detail; Delete in ⋯ menu with confirmation; delete without crash.
- Launch colour (clean install), onboarding headings stable.
- Hold-to-record → live transcript → sorted item, through the real `/api/jot/classify` on a local server.
- Store: pre-versioning store opens intact; corrupted store → blocking screen; V1 store upgrades to V2 in place.
- Smart sorting off → note flagged; on → sorted automatically.
- Follow-up recorded from an event, linked and listed.
- Deep link opens item; event notification scheduled; mic-denied card.

## Not verifiable in simulator — must test on device before TestFlight
1. Interruptions mid-recording: incoming call, Siri, AirPods removed, Notification Center pulled during a hold.
2. Notification Done / Snooze buttons from the lock screen.
3. Widget taps on the home screen (small + medium).
4. Real speech recognition offline on first run (voice-note fallback keeps audio).
5. Tap latency (simulator showed multi-second input lag that is not the app: 0% CPU at idle).
6. Locking the phone right after a hands-free capture (background task).

## Known gaps
- Add to Calendar not built.
- Monthly reminders on the 29th–31st skip short months (iOS calendar trigger limit).
- Hands-free with continuous background noise runs to the 90 s cap.
