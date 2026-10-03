# CTO — app-launch-readiness
- **Verdict:** build. Highest-scoring of the options James evaluated (panel 2026-10-03); most of the product exists.
- **Build vs buy:** keep on-device transcription (free, private). Classification: Claude via our own proxy for Pro; Apple Foundation Models on-device for Free. No third-party SDKs (analytics, crash reporting) for v1 — Xcode Organizer + TestFlight feedback is enough.
- **Backend:** smallest possible — one serverless route in the existing jamescronin.dev Next.js app on Vercel, reusing its Upstash rate limiter. Separate service only if usage demands it.
- **Risk:** SharkNinja IP assignment — James to clear before public launch. Not a code task.
