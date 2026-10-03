# ADR-002: Classify through Jot's own server, not a user-supplied API key

**Status:** Accepted
**Date:** 2026-10-03
**Feature:** app-launch-readiness
**Author:** 10x-Team (Architect + Staff Engineer + Security)

## Context
The app calls the Claude Messages API directly with an API key the user pastes into Settings (`ClaudeClassifier`, `KeychainStore`). No App Store user has a key, so every first capture becomes a note with "Add your Claude API key". The key can't ship in the binary either: anything in the app can be extracted. Prompt, schema and model are also baked into the app, so improving sorting needs an App Store release.

James already runs a Next.js site (jamescronin.dev) on Vercel with a Claude-backed route (`/api/ask`) protected by Upstash rate limits.

## Decision
1. Add `POST /api/jot/classify` to the jamescronin-dev app. It owns the prompt, JSON schema and model ID, calls Claude Haiku 4.5 with structured output, and returns the item JSON in the shape `ClassifiedItem` already decodes.
2. Request body: `{ transcript, now, timeZone, locale }` (`now` is ISO 8601 with offset). Headers: `X-Jot-Install` (random per-install UUID kept in the Keychain) and `X-Jot-Version`.
3. Abuse limits (v1, TestFlight): transcript ≤ 2,000 characters; per-install and per-IP sliding windows; a global daily cap so the bill is bounded. Limits live in Upstash with the same in-memory fallback as `/api/ask`.
4. Nothing user-written is stored or logged server-side: logs carry status codes and timings only.
5. Errors are mapped to a small, stable set the app shows in plain words: 400 `bad_request`, 429 `rate_limited` / `daily_limit`, 502 `upstream`, 422 `refused` / `unreadable`.
6. App: `ProxyClassifier` replaces `ClaudeClassifier` as the default. The direct-key classifier stays available in Debug builds only, for local experiments.
7. Hardening before the public App Store release (not TestFlight): App Attest assertions on each request (ADR to follow), and Pro entitlement checks from StoreKit signed transactions (ADR-003).

## Alternatives Considered
| Alternative | Pros | Cons | Why Not |
|---|---|---|---|
| Keep user API keys | No server | Nobody can use the app | Blocks launch |
| Ship a key in the app | Simple | Extractable; unbounded bill | Unsafe |
| Separate service (Cloudflare Worker, Firebase) | Isolated from the site | New account, new deploy pipeline, no existing rate limiter | More moving parts for no gain at this scale |
| App Attest from day one | Strong client auth | Server-side attestation verification is the largest piece of work; blocks TestFlight | Sequenced after TestFlight; caps bound the risk meanwhile |

## Consequences
### Positive
- Zero-setup sorting for every user.
- Prompt and model can change without an app release.
- Cost is bounded by caps from day one.

### Negative
- The site's uptime is now the app's sorting uptime. Mitigation: captures always save; failures become notes (and, in Phase 3, a retry queue).
- Until App Attest lands, a determined attacker can call the endpoint within the caps.

### Risks
- Rate-limit keys rely on a client-chosen install ID; IP limits and the global cap are the real backstop.
- Vercel function timeouts: Haiku with `max_tokens` 1024 returns in seconds; app timeout stays 30 s.

## Dependencies
- James: `ANTHROPIC_API_KEY` and Upstash vars on Vercel (the latter already exist for `/api/ask`), and a deploy.
- Constrains ADR-003: entitlement checks hang off this route.
