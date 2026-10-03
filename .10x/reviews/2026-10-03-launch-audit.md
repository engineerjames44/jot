# Launch audit — 2026-10-03

Read-only code audit (subagent) with key findings spot-checked against source, plus a simulator walkthrough (iPhone 17, iOS 27 sim, Debug, `-JotSampleData YES`).

## Launch blockers
1. User-supplied Claude API key (`ClaudeClassifier.swift:77,86`, `SettingsView.swift:85-191`); first capture fails for every new user.
2. No disclosure that transcripts go to Anthropic; onboarding says on-device only (`OnboardingView.swift:40`). Guideline 5.1.2(i).
3. No `PrivacyInfo.xcprivacy` (UserDefaults required-reason API).
4. Silent in-memory store fallback (`SharedStore.swift:21-24`) — confirmed. No VersionedSchema; `DevNote` in production schema.
5. Develop tab + shake handler reachable in Release (`SettingsView.swift:42,195-217`, `ShakeDetector.swift:10`).
6. Audio deleted when transcription fails (`CaptureController.swift:216-218`) — confirmed.
7. No paywall requirements (restore, terms/privacy, manage subscription).
8. Raw server error bodies shown to users (`ClaudeClassifier.swift:123-125`).

## Bugs
1. Recording can get stuck: hold-gesture cancellation never ends capture (`CaptureDock.swift:101`); no max duration in hold mode; no AVAudioSession interruption/route handling; hands-free cap only runs when level chunks arrive (`CaptureController.swift:305-325`).
2. `ReminderScheduler.refill` re-entrancy (`ReminderScheduler.swift:14-56`) — confirmed: awaits between fetch and removeAll/add; called concurrently.
3. Repeating notification triggers ignore start date; monthly-on-31st skips short months (`ReminderScheduler.swift:76-88`).
4. No background task around classification (`CaptureController.swift:191-215`).
5. Detail delete while still bound (`ItemDetailView.swift:68-72`).
6. Undated reminders/events disappear from Today (`TodayView.swift:256,268`).
7. Today keeps yesterday's calendar events past midnight (`RootView.swift:90-99`).
8. `removeAllPendingNotificationRequests` clears the brief preview (`ReminderScheduler.swift:33`, `MorningBrief.swift:149`).

## UX gaps
Events never reach Calendar or alert; swipe-delete is instant and permanent; 4 s undo window; no re-sort/retry; notification taps do nothing; widget tap anywhere starts mic (`UpcomingWidget.swift:121`); mic-denied dead end; no export/delete-all.

## UI walkthrough
- Mic orb overlaps rows on Today/Inbox and hides Delete on detail at rest (reachable only by scrolling). James's note #2.
- Launch: dark launch background → light app flash, ~2 s.
- Cards tall: ~3 items per screen on Today.
- Label noise: "REMINDER OVERDUE" double all-caps.
- Inbox: single "TODAY · 10" group including future items.
- Tab bar: heavy hammer/gear glyphs; Develop visible.
- Onboarding: heading jumps between pages (variable body height); overlapping text mid-animation on page 2.
- Taps on rows/tabs sometimes register late.

## What's good
Capture pipeline is well structured; confirmation card with Undo/Edit; classifier is injected (`CaptureController.swift:99-111`), making proxy/on-device swaps easy; consistent design system; onboarding is strong.
