# ADR-004: Schema V2 — follow-ups and a retry flag

**Status:** Accepted
**Date:** 2026-10-03
**Feature:** app-launch-readiness
**Author:** 10x-Team (Architect + DBA)

## Context
Phase 3 needs two things the 1.0 schema can't express:
1. James's change note: add follow-up notes to an earlier item ("after I talk to someone, add the follow-up to that event").
2. Captures saved as notes because sorting failed or was off should be sortable later (re-sort, retry when online, sort after turning Smart sorting on).

ADR-001 requires a new `VersionedSchema` and a migration stage for any model change.

## Decision
- `JotSchemaV2` adds to `JotItem`:
  - `parentID: UUID?` — set on a follow-up, pointing at the item it follows up.
  - `needsSorting: Bool = false` — true when a capture was kept as a note without being sorted.
- `JotSchemaV1` keeps frozen copies of the 1.0 models as nested types; V2 uses the live models.
- `JotMigrationPlan` gets a lightweight V1 → V2 stage. Both fields are optional or defaulted, so no custom migration code.
- Follow-ups are their own `JotItem`s (any kind), shown under their parent. A follow-up's parent being deleted leaves the follow-up as a normal item (`parentID` pointing nowhere is treated as no parent).

## Alternatives Considered
| Alternative | Pros | Cons | Why Not |
|---|---|---|---|
| SwiftData relationship (`parent`/`children`) | Referential integrity, cascade rules | Heavier migration; widgets and predicates get more complex; delete rules to design | A plain ID is enough for a list under the parent |
| Append follow-ups to `details` text | No schema change | Loses kind, date and recording per follow-up; can't be a reminder | Too limiting |
| Recompute "needs sorting" from title/details | No field | Fragile string matching | Not reliable |

## Consequences
- Positive: lightweight, testable migration; follow-ups can be reminders with their own times.
- Negative: no cascade delete; orphaned follow-ups are possible (handled as top-level items).
- Risk: migration mismatch on real stores. Mitigation: unit test that writes a V1 store and opens it with the V2 plan; simulator upgrade over an existing V1 store.
