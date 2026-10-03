# ADR-001: Versioned SwiftData schema and fail-loud store opening

**Status:** Accepted
**Date:** 2026-10-03
**Feature:** app-launch-readiness
**Author:** 10x-Team (Architect + Staff Engineer + DBA)

## Context
`SharedStore.container` opens the App Group store with an unversioned schema (`JotItem`, `DevNote`). If opening fails it silently falls back to an in-memory store: the app looks empty and everything captured that session is lost on quit. Once 1.0 ships, any model change without a migration plan risks exactly that failure on users' devices. Phase 3 will add fields (`needsClassification`, follow-ups).

## Decision
1. Introduce `JotSchemaV1: VersionedSchema` containing the current `JotItem` and `DevNote` exactly as shipped, and `JotMigrationPlan: SchemaMigrationPlan` (stages empty for now). Future changes add `JotSchemaV2` + a lightweight stage.
2. `DevNote` stays in the schema (removing it is itself a migration); the Develop UI is compiled out of Release instead.
3. Replace the silent fallback with a `StoreState` result: on failure the app shows a blocking "Jot couldn't open your notes" screen with Retry and a support link, and **never** writes to an in-memory store. Widgets/intents treat a failed store as "no data" and don't write.
4. Keep `@Attribute(.unique)` for now; revisit when iCloud sync is scoped (CloudKit forbids unique constraints).

## Alternatives Considered
| Alternative | Pros | Cons | Why Not |
|---|---|---|---|
| Keep in-memory fallback | App always launches | Silent data loss | Violates "never lose what was said" |
| `fatalError` on failure | Simple, loud | Crash loop, App Review risk, no recovery | Hostile to users |
| Move store to Core Data | Mature migrations | Rewrite, loses SwiftData ergonomics | Not worth it for 2 models |

## Consequences
### Positive
- Future model changes are explicit and testable.
- Failures are visible and recoverable instead of silently destroying data.
### Negative
- Every model change now requires a new schema version.
### Risks
- Wrapping existing models in V1 must match the on-disk schema exactly, or the first launch migrates unexpectedly. Mitigation: V1 references the existing model types unchanged; verify by launching over an existing store in the simulator.

## Dependencies
Constrains Phase 3 model changes (must add V2). Blocks CloudKit until unique constraint is removed.
