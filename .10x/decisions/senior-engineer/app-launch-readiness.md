# Senior Engineer — approach (1A/1B)
- 1A.1: `TodayView`/`InboxView` hold `@State path: [JotItem]` for their `NavigationStack(path:)`; `safeAreaInset` shows `CaptureDock` only when `path.isEmpty`. `ItemDetailView` adds `.toolbar { Menu(ellipsis) { Delete } }`; delete = set flag, `dismiss()`, then delete on next runloop via `Task { @MainActor in … }`. Remove inline Delete button.
- 1A.2: `Color.launchBackground` / launch screen colour → same as `jotBackground` light/dark.
- 1A.3/1A.4: find shared row view (`ItemRow`/`TimelineCard`) and `KindLabel`; reduce vertical padding, drop the separate "OVERDUE" label in favour of red time text.
- 1A.6: `SwipeableRow` uses a DragGesture likely as `.gesture` on a Button/NavigationLink → use `.simultaneousGesture` with minimumDistance ≥ 12 or a horizontal-only check so taps aren't delayed.
- 1B.1: watchdog Task started in `beginCapture` (sleep until cap → `endCapture`); observers registered in `MicAudioSource.start`, finishing the stream on interruption; `CaptureOrb` gesture adds `.onDisappear`/scenePhase guard and `GestureState` reset to end capture if cancelled.
- 1B.4: `private static var running: Task<Void, Never>?` + `rerun` flag.
