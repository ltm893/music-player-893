# music-player-893

iOS music player for MP3s in your app Documents folder, with optional **cloud download** from a private S3-backed API (Cognito auth + presigned URLs). This repo is the client only — it expects outputs from a deployed **dropbox-style** stack (API Gateway + Cognito + bucket).

## Requirements

- Xcode (project targets recent iOS SDKs)
- A `dliv_outputs.json` (same schema as your stack’s `dropbox_outputs.json`) — **not** committed; see setup below

## Setup

1. Copy the example config and fill in values from your deployment:

   ```bash
   cp dliv_outputs.example.json dliv_outputs.json
   cp dliv_outputs.example.json ios/MusicPlayer/MusicPlayer/dliv_outputs.json
   ```

2. Edit both copies with your `aws_region`, Cognito pool + app client ids, API `base_url`, and `private_bucket` name.

3. Open **`ios/MusicPlayer/MusicPlayer.xcodeproj`** in Xcode.

4. Ensure **`dliv_outputs.json`** inside `MusicPlayer/MusicPlayer/` is included in the app target’s **Copy Bundle Resources** (so `CloudService` can load it at runtime).

## Build & run

Select the **MusicPlayer** scheme, pick a simulator or device, then **Run** (⌘R).

Background playback uses **`Application-Info.plist`** merged with the generated Info plist (`UIBackgroundModes` → `audio`).

## Repo layout

| Path | Purpose |
|------|---------|
| `ios/MusicPlayer/` | Xcode project + Swift sources |
| `dliv_outputs.example.json` | Example API/Cognito config |
| `CONTEXT.md` | Maintainer notes and architecture |
| `LICENSE` | BSD-style terms + attribution |

## License

See **[LICENSE](./LICENSE)**. Use of this code requires **reasonable attribution** to the copyright holder, in addition to the usual redistribution notice requirements.
