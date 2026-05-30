# music-player-893 — refactor notes

Last updated: 2026-05-30

Identified refactor opportunities from code review. Ordered by priority.

---

## 1. playNext() doesn't pop CarPlay to root when queue ends
**File:** `ios/MusicPlayer/MusicPlayer/PlayerViewModel.swift`
**Priority:** High — bug
**Tag:** quality

When the queue finishes naturally, `playNext()` clears state but never calls
`CarPlaySceneDelegate.popToRoot()`. Only `stop()` does. CarPlay stays stranded
inside a folder after a queue plays through to the end — same bug as the stop
button, just a different trigger path.

**Fix:** Extract the "clear + reset CarPlay" logic into a private `resetPlayback()`
helper and call it from both `stop()` and the end-of-queue path in `playNext()`.

---

## 2. Duplicate state teardown between stop() and playNext()
**File:** `ios/MusicPlayer/MusicPlayer/PlayerViewModel.swift`
**Priority:** Medium
**Tag:** simplify

Both methods reset `currentTrack`, `isPlaying`, `currentTime`, `duration`, and
call `stopProgressTimer()` + `nowPlayingInfo = nil`. The same 6–7 lines exist in
two places. A private `resetPlayback()` method eliminates the duplication and
ensures both paths stay in sync going forward.

---

## 3. skipNext() has two separate play paths that diverge
**File:** `ios/MusicPlayer/MusicPlayer/PlayerViewModel.swift`
**Priority:** Medium
**Tag:** simplify

When a queue is active, `skipNext()` calls `startPlayback()` directly, bypassing
the folder-queue logic in `play()`. When there's no queue, it calls `play()` —
which builds a folder queue. The two branches behave differently (e.g. skipping
past the end of a queue won't wrap into the next folder). Decide on a consistent
policy and unify the path.

---

## 4. folderToggleRow and folderHeaderRow are nearly identical
**File:** `ios/MusicPlayer/MusicPlayer/CloudBrowserView.swift`
**Priority:** Medium
**Tag:** simplify

Both render a chevron + folder name + tap-to-toggle row with nearly identical
markup. `folderHeaderRow` is used for root section headers; `folderToggleRow` is
used for nested folders with an indent parameter. Merge into one
`folderRow(folder:indent:)` view where `indent = 0` is the root case — removes
~30 lines of duplication.

---

## 5. Token refresh races: idToken() is not re-entrant
**File:** `ios/MusicPlayer/MusicPlayer/CloudService.swift`
**Priority:** High — potential bug
**Tag:** quality

If two API calls run concurrently with an expired token (e.g. `sync()` while a
download starts), both will call `refresh()` simultaneously — sending two Cognito
refresh requests in parallel. The second may fail because the first already
consumed the rotation window.

**Fix:** Use an `actor` or a `Task?` guard that coalesces concurrent refresh calls
into one in-flight request.

---

## 6. UIAppearance setup belongs in a dedicated configurator
**File:** `ios/MusicPlayer/MusicPlayer/MusicPlayerApp.swift`
**Priority:** Low
**Tag:** minor

`App.init()` has ~20 lines of `UIAppearance` configuration. Extract into a
`static func configureAppearance()` on a separate `AppAppearance` enum to keep
`MusicPlayerApp` clean and the style rules easy to find and update.

---

## Status

| # | Title | Priority | Done |
|---|-------|----------|------|
| 1 | playNext() CarPlay popToRoot | High | ✅ |
| 2 | resetPlayback() helper | Medium | ✅ |
| 3 | skipNext() unified path | Medium | ✅ |
| 4 | folderRow merge | Medium | ✅ |
| 5 | idToken() refresh race | High | ✅ |
| 6 | AppAppearance configurator | Low | ✅ |
