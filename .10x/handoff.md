# Handoff → Architect/SDE (Phase 2: launch requirements)
1A and 1B done; see `decisions/sde/app-launch-readiness.md` and `decisions/dba/app-launch-readiness.md`.

Next, Phase 2. **Write ADR-002 (classifier proxy) before coding the proxy.** Order:
1. 2.4 Debug-gate Develop tab, shake, API-key UI, DevNote recorder (no dependencies).
2. 2.3 PrivacyInfo.xcprivacy for Jot + JotWidgets.
3. 2.5 Test target `JotTests` + shared schemes; first tests: ReminderScheduler.trigger, ClassifiedItem.dueDate, Inbox grouping, capture watchdog limits.
4. 2.2 AI disclosure in onboarding + Settings; privacy policy/terms pages (AppFoyer plugin needs a fresh session).
5. 2.1 Proxy (ADR-002): Next.js route in jamescronin-dev, client `ProxyClaudeClassifier`. Deploy + secrets need James.
