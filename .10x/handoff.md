# Handoff → SDE (Phase 1A)
Start with 1A.1 (dock on detail + Delete menu), per `decisions/senior-engineer/app-launch-readiness.md`. Build: `xcodebuild -project Jot.xcodeproj -scheme Jot -destination 'id=<sim>' build`. Run with `-JotSampleData YES` for realistic UI. Verify each task with simulator screenshots before moving on. ADR-001 must be followed for 1B.3.
