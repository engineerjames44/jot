# EM — app-launch-readiness

Order: 1A → 1B → 2 → 3 → 4. Each phase is a set of commits on `app-launch-readiness`; build + simulator check after every task.

| # | Task | Est | Depends |
|---|---|---|---|
| 1A.1 | Hide dock on detail; Delete → ⋯ menu; dismiss-then-delete | 1h | – |
| 1A.2 | Launch background matches app | 0.5h | – |
| 1A.3 | Denser rows + quieter labels (Today/Inbox) | 2h | – |
| 1A.4 | Inbox due-bucket grouping | 1.5h | – |
| 1A.5 | Tab icons + onboarding layout stability | 1h | – |
| 1A.6 | Tap latency investigation (SwipeableRow) | 1h | – |
| 1B.1 | Capture watchdog: max duration, interruptions, gesture cancel | 2h | – |
| 1B.2 | Keep audio on transcription failure | 1h | – |
| 1B.3 | ADR-001 versioned schema + store failure screen | 2h | ADR-001 |
| 1B.4 | Coalesced refill; preserve brief preview | 1h | – |
| 1B.5 | Background task around classification | 0.5h | – |
| 2.x | Proxy, disclosure, privacy manifest, Debug gating, tests | 1–2d | ADR-002 |
| 3.x | Calendar write, undo delete, notif actions, widget, re-sort, follow-ups | 2–3d | ADR-001 V2 |
| 4.x | Foundation Models free tier, StoreKit 2, paywall | 2–3d | ADR-003 |

Risks: Foundation Models unavailable in simulator/non-AI devices; proxy deploy needs James's Vercel + secrets; App Store Connect products need James.
