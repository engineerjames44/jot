# Handoff → SDE (Phase 3: UX gaps)
Phase 2 done; see `decisions/sde`, `decisions/security`, ADR-002. Site work lives on jamescronin-dev branch `jot-classify-api` (not pushed).

Phase 3 needs schema V2 (see `decisions/dba/app-launch-readiness.md`): `needsClassification`, `classifiedBy`, `parentID`. Write the V2 migration first, then:
1. 3.5 Re-sort / retry classification (uses needsClassification).
2. 3.6 Follow-ups on any item (parentID) — James's note #1.
3. 3.2 Undo for swipe-delete.
4. 3.3 Notification tap opens item; Done/Snooze actions.
5. 3.4 Widget: row taps open item; record only via button.
6. 3.1 Events → "Add to Calendar" (write-only access) + event alerts.
7. 3.7 Mic-denied path with Open Settings.
