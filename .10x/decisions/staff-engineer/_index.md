# Staff Engineer — index
- [DISCOVERED] Conventions: `@Observable` controllers in the environment; design tokens in `Shared/DesignSystem.swift` and `Shared/Brand.swift` (`Color.jot*`, `Font.jot*`, `JotMetrics.gutter`, `.jot` animation); short doc comments on types explaining *why*; Debug-only helpers under `Jot/Debug` wrapped in `#if DEBUG`.
- [DISCOVERED] No test target, no CI, no shared schemes committed (schemes are auto-generated).
- Standard going forward: every change keeps the existing comment density and naming; user-facing errors never show raw server text.
