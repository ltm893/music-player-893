# CONTEXT.md — music-player-893
# Read this first at the start of every session.
# Last updated: 2026-05-05

## What this repo is
Standalone iOS music player — add-on for cognito-s3-stack-893.
Streams and downloads MP3s from a private S3 bucket via the dropbox-893 API.
No CDK backend of its own — consumes dropbox-893's API directly.

## Status: ✅ Working on iPhone

## Part of the add-on family
| Repo | Status | Description |
|------|--------|-------------|
| `cognito-s3-stack-893` | ✅ | Base: Cognito + S3 |
| `dropbox-893` | ✅ Deployed + verified | Private file manager — provides the API |
| `calendar-893` | ✅ Deployed + verified | Calendar CRUD |
| `music-player-893` | ✅ Working | iOS music player — this repo |
| `mileage-expense-tracker-893` | ✅ | MET iOS app |

## Architecture
- Raw URLSession + Cognito SRP — no Amplify SDK
- Reads dliv_outputs.json from app bundle (baked in at build time)
- dliv_outputs.json matches dropbox_outputs.json schema
- No CDK stack — uses dropbox-893 API Gateway directly
- Presigned download URLs: 12-hour expiry (covers full playback sessions)

## Deployment values (dliv_outputs.json)
Do **not** commit real endpoints or pool IDs in documentation. Copy **`dliv_outputs.example.json`** to **`dliv_outputs.json`** at the repo root and under `ios/MusicPlayer/MusicPlayer/`, then fill in values from your **dropbox_outputs.json** (or equivalent CDK outputs). Keep both copies gitignored.

## dliv_outputs.json
- Filename kept as dliv_outputs.json — written by deploy.sh, read by CloudService.swift
- Gitignored — never committed
- Must be added to Xcode target (Copy Bundle Resources)
- Schema matches dropbox_outputs.json

## Generic naming — all Dliv-prefixed names replaced
| Old | New |
|-----|-----|
| `DlivService` | `CloudService` |
| `DlivAuthError` | `CloudAuthError` |
| `DlivFolder` | `CloudFolder` |
| `DlivFile` | `CloudFile` |
| `DlivLoginView` | `LoginView` |
| `DlivBrowserView` | `CloudBrowserView` |

## Swift files in target
- MusicPlayerApp.swift   ← colors, button styles, @main entry point
- ContentView.swift      ← track list, player bar, cloud sync button
- CloudService.swift     ← raw Cognito SRP, reads dliv_outputs.json
- LoginView.swift        ← sign in form
- CloudBrowserView.swift ← cloud file browser
- DocumentPicker.swift  ← local file import
- Models.swift           ← CloudFolder, CloudFile, SyncItem, SyncResult
- PlayerViewModel.swift  ← AVAudioPlayer, queue, lock screen controls
- SyncView.swift         ← sync UI, download all, progress
- Track.swift            ← Track model
- dliv_outputs.json      ← baked into bundle, gitignored

## Xcode project
`ios/MusicPlayer/MusicPlayer.xcodeproj`

## Old MusicPlayer project (deprecated)
Previous prototype under `MusicPlayer/` elsewhere on disk — music-player-893 is the replacement.

## Structure
```
music-player-893/
├── ios/
│   └── MusicPlayer/
│       ├── Application-Info.plist   ← UIBackgroundModes audio, merged with generated plist
│       ├── MusicPlayer.xcodeproj
│       └── MusicPlayer/
│           ├── Assets.xcassets
│           ├── ContentView.swift
│           ├── CloudBrowserView.swift
│           ├── LoginView.swift
│           ├── CloudService.swift
│           ├── DocumentPicker.swift
│           ├── Models.swift
│           ├── MusicPlayerApp.swift
│           ├── PlayerViewModel.swift
│           ├── SyncView.swift
│           ├── Track.swift
│           └── dliv_outputs.json   ← baked into bundle, gitignored
├── dliv_outputs.json               ← gitignored, your values
├── dliv_outputs.example.json       ← committed, schema for forkers
├── CONTEXT.md
└── .gitignore
```

## Next steps
1. Build dliv-web-893 — web frontend on Amplify Hosting (no pipeline-deploy)
2. Archive old MusicPlayer project
3. Decommission broken dliv.com Amplify app
