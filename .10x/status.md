# Status — Jot

**Feature:** app-launch-readiness · **Branch:** app-launch-readiness
**Phase:** Implementation — 1A, 1B, 2 done (deploy pending James); Phase 3 next
**Updated:** 2026-10-03

## Phases
- [x] Discovery (codebase scan, audit, simulator walkthrough)
- [x] Brainstorm / spec approved (`specs/2026-10-03-app-launch-readiness-design.md`)
- [x] Strategy (cto, product-manager)
- [x] Design (architect, staff-engineer, ADR-001)
- [x] Planning (engineering-manager, senior-engineer)
- [x] 1A UI polish (tap latency: verify on device)
- [x] 1B Reliability (interruption paths: verify on device)
- [x] 2 Launch requirements (ADR-002) — site branch `jot-classify-api` needs deploy + env vars
- [ ] 3 UX gaps
- [ ] 4 Subscriptions (ADR-003 pending)
- [ ] Verification (QA + security)
- [ ] Delivery (TestFlight)

## Tasks
See `decisions/engineering-manager/app-launch-readiness.md`.

## Blockers / needs James
- SharkNinja IP clearance before public launch
- Apple Developer / App Store Connect setup, subscription products
- Vercel + Anthropic key as server secret for the proxy
