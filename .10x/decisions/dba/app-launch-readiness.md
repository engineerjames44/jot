# DBA — app-launch-readiness

## Schema
- `JotSchemaV1` (1.0.0) = `JotItem`, `DevNote` exactly as shipped before versioning. `JotMigrationPlan` has no stages yet.
- Verified that the V1 container opens an existing pre-versioning store without migration or data loss (simulator, 11 items incl. audio-linked item).

## Next schema change (Phase 3) → `JotSchemaV2`
Planned additive fields on `JotItem`, all optional or defaulted, so a lightweight stage suffices:
- `needsClassification: Bool = false` (retry queue / re-sort)
- `classifiedBy: String?` ("claude" | "on-device" | "manual")
- `parentID: UUID?` for follow-ups (James's note #1) — chosen over a relationship to keep the migration lightweight and widget fetches simple.
Process: copy V1 models into `JotSchemaV1` as nested types before editing the live models; add `.lightweight(fromVersion: JotSchemaV1.self, toVersion: JotSchemaV2.self)`.

## Constraints
- `@Attribute(.unique)` on ids blocks CloudKit sync; revisit with a V-next if sync is scoped.
- Store lives in the App Group container; widgets read via `ModelContext(SharedStore.container)` and must never write.
