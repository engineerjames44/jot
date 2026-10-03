# Staff Engineer — app-launch-readiness
- Reuse design tokens; no new colours/fonts. Row density change lives in shared row components, not per-screen padding hacks.
- All Debug-only surfaces (`Develop/`, shake, API-key UI, sample data) behind `#if DEBUG`.
- User-facing errors: map to short, human messages; log details with `Logger` (os) under subsystem `com.jamescronin.Jot`.
- Add `JotTests` unit-test target covering pure logic first: Inbox grouping, recurrence next-occurrence, refill coalescing, classifier JSON parsing.
