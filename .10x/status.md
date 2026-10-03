# Status — Jot

**Feature:** app-launch-readiness · **Branch:** app-launch-readiness
**Phase:** 1A–3 done; server deployed 2026-10-03; subscriptions dropped (portfolio project); device testing next
**Updated:** 2026-10-03

## Phases
- [x] Discovery (codebase scan, audit, simulator walkthrough)
- [x] Brainstorm / spec approved (`specs/2026-10-03-app-launch-readiness-design.md`)
- [x] Strategy (cto, product-manager)
- [x] Design (architect, staff-engineer, ADR-001)
- [x] Planning (engineering-manager, senior-engineer)
- [x] 1A UI polish (tap latency: verify on device)
- [x] 1B Reliability (interruption paths: verify on device)
- [x] 2 Launch requirements (ADR-002) — proxy live at www.jamescronin.dev/api/jot/classify
- [x] 3 UX gaps (Add to Calendar deferred) — ADR-004
- [—] 4 Subscriptions — dropped (portfolio project)
- [~] Verification: automated + simulator done (see reviews/); device checklist pending
- [ ] Delivery (TestFlight)

## Tasks
See `decisions/engineering-manager/app-launch-readiness.md`.

## Blockers / needs James
- SharkNinja IP clearance before public launch
- Apple Developer / App Store Connect setup (for TestFlight)
- Confirm Upstash env vars in Vercel production (proxy is deployed and working)
