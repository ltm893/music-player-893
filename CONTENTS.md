# music-player-893 — contents

Last updated: 2026-05-12

Quick index for humans and agents. Deep architecture and session notes live in **[CONTEXT.md](./CONTEXT.md)**. Setup and license live in **[README.md](./README.md)**.

## What this repo is

iOS app **MusicPlayer893** (`com.dliv.MusicPlayer893`): play MP3s from the app Documents folder, optional **cloud download** via Cognito + presigned URLs against the private **dropbox-893** API. Client only — configure with **`dliv_outputs.json`** (gitignored); see **`dliv_outputs.example.json`**.

## Repo layout

| Path | Purpose |
|------|---------|
| `ios/MusicPlayer/MusicPlayer.xcodeproj/` | Xcode project; **shared scheme** under `xcshareddata/xcschemes/MusicPlayer.xcscheme` |
| `ios/MusicPlayer/Application-Info.plist` | Merged plist: background audio, file sharing, export compliance (`ITSAppUsesNonExemptEncryption`), etc. |
| `ios/MusicPlayer/MusicPlayer.entitlements` | **CarPlay audio** (`com.apple.developer.carplay-audio`) + code signing |
| `ios/MusicPlayer/MusicPlayer/` | Swift sources, `Assets.xcassets`, bundled `dliv_outputs.json` (gitignored locally) |
| `ios/MusicPlayer/inject_carplay_plist.py` | Build phase: injects **CPTemplateApplicationScene** into the built `Info.plist` (Xcode merge drops nested `UISceneConfigurations` without this) |
| `dliv_outputs.example.json` | Example API/Cognito config for contributors |
| `dliv_outputs.json` | Your real config at repo root (gitignored) |
| `CONTEXT.md` | Maintainer notes, file map, related repos |
| `README.md` | Setup, build, license pointer |
| `LICENSE` | BSD-style terms + attribution |

## CarPlay (current)

- **Dashboard / Now Playing:** `MPNowPlayingInfoCenter` + remote commands in **`PlayerViewModel`** (works with split view).
- **Launcher (tap app icon):** **`CarPlaySceneDelegate`** + **`CarPlayListTemplates`** — nested **`CPListTemplate`** per folder (`pushTemplate`), shared tree via **`LocalLibraryTree`**; **Play All** / **Shuffle** per folder (same rules as iPhone); single track clears queue then plays one song.
- **`CarPlayPlayableContentAdapter`** holds a weak **`PlayerViewModel`** reference and rebuilds the root list when tracks reload (resets navigation stack).
- **Important:** Non-navigation apps use **`templateApplicationScene(_:didConnect:)`** (no `CPWindow`). **`setRootTemplate`** must run **before `didConnect` returns`** (no deferred `Task` for the initial root).
- **Icons:** `AppIcon` asset includes **CarPlay** (`car` idiom) slots; main target links **`MusicPlayer.entitlements`**.

## Build (short)

1. Configure `dliv_outputs.json` (root + `ios/MusicPlayer/MusicPlayer/`) per **README.md**.
2. Open **`ios/MusicPlayer/MusicPlayer.xcodeproj`**, scheme **MusicPlayer**, Run on device.
3. **CarPlay:** requires the **Car Play Audio** capability on the App ID in the Apple Developer portal and a provisioning profile that includes it.

## Related repos

See **CONTEXT.md** for the add-on family table (`cognito-s3-stack-893`, `dropbox-893`, etc.).
