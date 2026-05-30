# music-player-893 — testing guide

Last updated: 2026-05-30

---

## Running tests

### Script (recommended)

```bash
./run_tests.sh
```

Runs `MusicPlayerTests`, auto-resolves the simulator, and prints a pass/fail summary.
Defaults to `iPhone 16`. Pass a different simulator name as an argument:

```bash
./run_tests.sh "iPhone 16 Pro"
./run_tests.sh "iPhone 16 Plus"
```

The script:
- Cleans up stale `.xcresult` and log files before each run
- Resolves the simulator device ID automatically (avoids name/OS mismatch errors)
- Overrides `IPHONEOS_DEPLOYMENT_TARGET` to match the simulator OS
- Saves the full xcodebuild log to `/tmp/xcodebuild-test.log`
- Exits with code `1` if any test fails (CI-compatible)

### Xcode

Open `ios/MusicPlayer/MusicPlayer.xcodeproj`, select the `MusicPlayerTests` target,
and press `Cmd+U`. Results appear in the Test Navigator (`Cmd+6`).

---

## Test framework

Tests use **Swift Testing** (`import Testing`, `@Test`, `@Suite`, `#expect`),
introduced in Xcode 16 / Swift 6. This is different from the older XCTest framework:

| | Swift Testing | XCTest |
|---|---|---|
| Import | `import Testing` | `import XCTest` |
| Test marker | `@Test` | `func test...()` |
| Suite marker | `@Suite` | `class ... : XCTestCase` |
| Assertion | `#expect(value == other)` | `XCTAssertEqual(value, other)` |
| Log format | `Test case '...' passed` | `Test Case '...' passed` |

---

## What is tested

### Track (7 tests)
`Track` is the core model — these tests cover all the logic in `Track.init()`.

| Test | What it checks |
|---|---|
| `titleStripsExtension` | `"My Song.mp3"` → title is `"My Song"` |
| `rootTrackHasNilFolder` | File at Documents root → `folder == nil` |
| `subfolderTrackCapturesFolder` | `"Jazz/song.mp3"` → `folder == "Jazz"` |
| `nestedSubfolderCapturesFullPath` | `"Jazz/Bebop/song.mp3"` → `folder == "Jazz/Bebop"` |
| `relativePathFromDocumentsRoot` | `"Jazz/song.mp3"` → `relativePath == "Jazz/song.mp3"` |
| `equalityById` | Two tracks with the same URL but different UUIDs are not equal |
| `sameInstanceIsEqual` | A track equals itself |

### CloudFile (9 tests)
Covers path parsing, `isMp3`, `displayTitle`, `musicRelativePath`, and `musicRelativeFolder`.

| Test | What it checks |
|---|---|
| `nameIsLastComponent` | `"Music/Jazz/song.mp3"` → name is `"song.mp3"` |
| `isMp3True` | `.mp3` extension returns `true` |
| `isMp3False` | `.flac` extension returns `false` |
| `isMp3CaseInsensitive` | `.MP3` returns `true` |
| `displayTitleStripsExtension` | `"01 - Song.mp3"` → `"01 - Song"` |
| `musicRelativePathStripsPrefix` | `"Music/Jazz/song.mp3"` → `"Jazz/song.mp3"` |
| `musicRelativePathNilForBareKey` | `"Music/"` → `nil` |
| `musicRelativeFolderStripsFilename` | `"Music/Jazz/Bebop/song.mp3"` → `"Jazz/Bebop"` |
| `musicRelativeFolderNilForRootFile` | `"Music/song.mp3"` → `nil` |

### CloudFolder (2 tests)
| Test | What it checks |
|---|---|
| `nameIsLastComponent` | `"Music/Jazz/"` → name is `"Jazz"` |
| `topLevelFolderName` | `"Music/"` → name is `"Music"` |

### SyncResult (3 tests)
| Test | What it checks |
|---|---|
| `missingCountEqualsCloudOnly` | `missingCount` equals `cloudOnly.count` |
| `totalCloudSum` | `totalCloud` is `cloudOnly + synced` |
| `emptyResultZeroCounts` | Empty result has zero counts |

### SyncItem (2 tests)
| Test | What it checks |
|---|---|
| `subfolderOrNilEmpty` | Empty string subfolder → `nil` |
| `subfolderOrNilNonEmpty` | Non-empty subfolder → returns the value |

### LocalLibraryTree (11 tests)
`LocalLibraryTree.build()` is the core folder-tree logic shared by both the iPhone
list and CarPlay. These tests cover all branching paths.

| Test | What it checks |
|---|---|
| `emptyTracks` | Empty input → empty root |
| `rootTracks` | Root-level files go into `rootTracks`, sorted by title |
| `subfolderTracksInFolderNode` | Subfolder files go into folder node, not `rootTracks` |
| `foldersSortedAlphabetically` | Folders are sorted A→Z |
| `nestedFolderHierarchy` | `Jazz/Bebop/song.mp3` builds a two-level hierarchy |
| `allTracksRecursive` | `allTracks` includes direct + nested tracks |
| `directTracksSortedByTitle` | Tracks within a folder are sorted by title |
| `showsPlayButtonsLeaf` | Leaf folder (no children) shows play buttons |
| `showsPlayButtonsWithDirectTracks` | Folder with direct tracks shows play buttons |
| `showsPlayButtonsPureContainer` | Folder with only subfolders, no direct tracks → no play buttons |
| `mixedRootAndFolderTracks` | Mix of root and subfolder tracks splits correctly |

---

## What is not tested (and why)

### PlayerViewModel
`PlayerViewModel` uses `AVAudioPlayer` which requires a real audio file and a device
or simulator with audio support. Testing it needs dependency injection — a
`PlayerViewModelProtocol` and a mock audio engine that replaces `AVAudioPlayer`.

**To add:** Extract an `AudioPlayerProtocol` with `play()`, `pause()`, `stop()`,
`currentTime`, and `duration`. Inject it into `PlayerViewModel`. A `MockAudioPlayer`
can then simulate playback in tests without touching the filesystem or audio session.

### CloudService
`CloudService` talks to Cognito and a private API Gateway. Testing it needs:
- A mock `URLSession` (or `URLProtocol` subclass) to intercept network calls
- Fake Keychain responses for token storage
- Stub JSON responses for auth and file listing

**To add:** Extract a `CloudServiceProtocol` and inject a `MockCloudService` in
views and tests. The mock can return canned `SyncResult` and `[CloudFile]` values
without hitting the network.

### CarPlay (CarPlaySceneDelegate, CarPlayListTemplates)
CarPlay templates require a connected `CPInterfaceController` which is only available
on a physical device with a CarPlay session. These are best covered by manual
testing on device or in the CarPlay simulator inside Xcode.

---

## Adding new tests

1. Open `ios/MusicPlayer/MusicPlayerTests/MusicPlayerTests.swift`
2. Add a new `@Suite` struct for a new area, or a new `@Test` inside an existing suite
3. Use the `makeTrack()` / `docURL()` helpers at the top of the file to build
   test fixtures without touching the real filesystem
4. Run `./run_tests.sh` to verify

### Example

```swift
@Suite("MyNewFeature")
struct MyNewFeatureTests {

    @Test("does the right thing")
    func doesTheRightThing() {
        let track = makeTrack("Jazz/song.mp3")
        #expect(track.folder == "Jazz")
    }
}
```

---

## Test file locations

| File | Purpose |
|---|---|
| `ios/MusicPlayer/MusicPlayerTests/MusicPlayerTests.swift` | All unit tests |
| `ios/MusicPlayer/MusicPlayerUITests/` | UI test target (empty — not yet used) |
| `run_tests.sh` | CLI test runner script |
| `TESTING.md` | This file |
