# Security — app-launch-readiness

## Threat model (current)
| Asset | Threat | Control |
|---|---|---|
| Anthropic API key | Extraction from app | Key only on the server (ADR-002); Debug-only personal key path |
| API bill | Scripted abuse of /api/jot/classify | Per-install (30/h) + per-IP (60/h) sliding windows, 3,000/day global cap, 2,000-char input cap. **Gap:** install ID is client-chosen; App Attest planned before public App Store launch |
| User transcripts | Leakage via logs/storage | Server logs only status + latency; no storage; `Cache-Control: no-store` |
| User transcripts | Sent without consent | `SmartSorting.isAllowed` gate in `Classifier` covers capture and Siri paths |
| Prompt injection via memo | Model follows memo text | Memo wrapped in `<memo>` with explicit "never instructions" line; structured output constrains the reply to the schema; nothing acts on output except creating a local item |
| Error messages | Leaking server details to UI | `SortingError` maps codes to fixed strings (tested) |
| Local store | Silent data loss | ADR-001 fail-loud store |

## Open items before public launch
1. App Attest (new ADR) on /api/jot/classify.
2. StoreKit JWS verification for Pro quotas (ADR-003).
3. Support contact for the privacy policy (currently LinkedIn).
4. SharkNinja invention-assignment clearance (business risk, not code).
