# Jot app launch readiness — design

**Date:** 2026-10-03 · **Status:** Approved by James ("yes — proceed with all")
**Branch:** `app-launch-readiness`

## Goal
Take the Jot iOS app from "works for James" to a public TestFlight build, then an App Store subscription product. Positioning: the voice-capture app built for ADHD brains. Hardware (Rev A) is frozen after the 9 Oct demo until ~100 paying users.

## Inputs
- Code audit (2026-10-03), spot-checked: see `.10x/reviews/2026-10-03-launch-audit.md`.
- Simulator UI walkthrough (2026-10-03): see same file, "UI walkthrough".
- James's Develop-tab change notes: (1) add follow-up notes to an existing item/event; (2) mic orb hides the Delete button on the detail screen.

## Phases (each ships independently, in order)

### 1A — UI polish
1. Orb never covers actionable content: hide the capture dock on pushed detail screens; move Delete to a top-bar ⋯ menu (works in pushed and sheet presentations).
2. Launch screen matches the app background (no dark → light flash).
3. Denser list rows on Today and Inbox (smaller vertical padding, title + one meta line).
4. Quieter labels: kind shown by colour bar + dot + label; "Overdue" shown as time-colour change, not a second all-caps label.
5. Inbox groups by due bucket (Overdue, Today, Upcoming, No date, Done) instead of a single "Today" group.
6. Tab bar: consistent icon weight; Develop tab Debug-only (see 2.4).
7. Onboarding: fixed-height text block so headings don't jump between pages; no overlapping text in the "Just say it" animation.
8. Investigate delayed tap response on list rows (SwipeableRow gesture).

### 1B — Reliability
1. Recording never gets stuck: wall-clock max duration for both hold and hands-free; `AVAudioSession` interruption + route-change handling; gesture cancellation ends capture.
2. Never delete audio when transcription fails: save a "needs transcription" note that keeps the audio and can be retried.
3. Store open failure: no silent in-memory fallback; show a blocking recovery screen. Versioned schema before 1.0 (ADR-001).
4. Serialise `ReminderScheduler.refill` (single in-flight task, coalesced reruns).
5. Detail delete: dismiss first, then delete.
6. Background task around classification.

### 2 — Launch requirements
1. Backend proxy for Claude (no user API keys) — ADR-002.
2. Third-party AI disclosure in onboarding + privacy policy/terms pages.
3. `PrivacyInfo.xcprivacy` for app + widget targets.
4. Develop tab, shake-to-note, API-key UI compiled only in Debug.
5. Test target + shared schemes.

### 3 — UX gaps
1. Events: "Add to Calendar" (write access) and event alerts.
2. Undo for swipe-delete.
3. Notification tap opens the item; Done/Snooze actions.
4. Up Next widget: tap row opens item; record only via the orb button.
5. Re-sort / retry classification on an item.
6. Follow-up notes on any item (James's note #1).
7. Mic-denied path with "Open Settings".

### 4 — Subscriptions
Free tier (on-device Foundation Models, deterministic fallback) and Jot Pro (Claude via proxy), StoreKit 2, paywall — ADR-003.

## Out of scope
Hardware/BLE, iCloud sync, Android, accounts/login.

## Success criteria
- No capture is ever lost (audio or transcript) across interruption, offline, and store failure.
- A new user can install, onboard, and make a correct capture with zero configuration.
- Passes App Review on first submission.
- TestFlight day-7 retention measured with ≥30 external testers.

## Needs James (cannot be done from code)
- SharkNinja invention-assignment check before public launch.
- Apple Developer account, App Store Connect app record, subscription products.
- Hosting account for the proxy (Vercel, already used for jamescronin.dev) and the Anthropic API key as a server secret.
