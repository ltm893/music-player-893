//
//  MusicPlayerTests.swift
//  MusicPlayerTests
//

import Testing
import Foundation
@testable import MusicPlayer

// MARK: - Helpers

/// Builds a fake Documents-rooted URL without touching the filesystem.
/// Uses the real Documents directory as the base so Track.init() correctly
/// parses folder and relativePath.
private func docURL(_ relativePath: String) -> URL {
    let docs = FileManager.default
        .urls(for: .documentDirectory, in: .userDomainMask)[0]
    return docs.appendingPathComponent(relativePath)
}

private func makeTrack(_ relativePath: String) -> Track {
    Track(url: docURL(relativePath))
}

// MARK: - Track Tests

@Suite("Track")
struct TrackTests {

    @Test("title strips file extension")
    func titleStripsExtension() {
        let track = makeTrack("My Song.mp3")
        #expect(track.title == "My Song")
    }

    @Test("root track has nil folder")
    func rootTrackHasNilFolder() {
        let track = makeTrack("song.mp3")
        #expect(track.folder == nil)
    }

    @Test("subfolder track captures folder name")
    func subfolderTrackCapturesFolder() {
        let track = makeTrack("Jazz/song.mp3")
        #expect(track.folder == "Jazz")
    }

    @Test("nested subfolder track captures full folder path")
    func nestedSubfolderCapturesFullPath() {
        let track = makeTrack("Jazz/Bebop/song.mp3")
        #expect(track.folder == "Jazz/Bebop")
    }

    @Test("relativePath is path from Documents root")
    func relativePathFromDocumentsRoot() {
        let track = makeTrack("Jazz/song.mp3")
        #expect(track.relativePath == "Jazz/song.mp3")
    }

    @Test("equality is by id, not url")
    func equalityById() {
        let url = docURL("song.mp3")
        let a = Track(url: url)
        let b = Track(url: url)
        // Two tracks with the same URL but different UUIDs are not equal
        #expect(a != b)
    }

    @Test("same instance is equal to itself")
    func sameInstanceIsEqual() {
        let track = makeTrack("song.mp3")
        #expect(track == track)
    }
}

// MARK: - CloudFile Tests

@Suite("CloudFile")
struct CloudFileTests {

    @Test("name is last path component of key")
    func nameIsLastComponent() {
        let file = CloudFile(key: "Music/Jazz/song.mp3", size: 0)
        #expect(file.name == "song.mp3")
    }

    @Test("isMp3 true for mp3 extension")
    func isMp3True() {
        let file = CloudFile(key: "Music/song.mp3", size: 0)
        #expect(file.isMp3)
    }

    @Test("isMp3 false for non-mp3 extension")
    func isMp3False() {
        let file = CloudFile(key: "Music/song.flac", size: 0)
        #expect(!file.isMp3)
    }

    @Test("isMp3 case insensitive")
    func isMp3CaseInsensitive() {
        let file = CloudFile(key: "Music/SONG.MP3", size: 0)
        #expect(file.isMp3)
    }

    @Test("displayTitle strips .mp3")
    func displayTitleStripsExtension() {
        let file = CloudFile(key: "Music/01 - Song Title.mp3", size: 0)
        #expect(file.displayTitle == "01 - Song Title")
    }

    @Test("musicRelativePath strips Music prefix")
    func musicRelativePathStripsPrefix() {
        let file = CloudFile(key: "Music/Jazz/song.mp3", size: 0)
        #expect(file.musicRelativePath == "Jazz/song.mp3")
    }

    @Test("musicRelativePath nil for bare Music key")
    func musicRelativePathNilForBareKey() {
        let file = CloudFile(key: "Music/", size: 0)
        #expect(file.musicRelativePath == nil)
    }

    @Test("musicRelativeFolder strips filename from path")
    func musicRelativeFolderStripsFilename() {
        let file = CloudFile(key: "Music/Jazz/Bebop/song.mp3", size: 0)
        #expect(file.musicRelativeFolder == "Jazz/Bebop")
    }

    @Test("musicRelativeFolder nil for root-level file")
    func musicRelativeFolderNilForRootFile() {
        let file = CloudFile(key: "Music/song.mp3", size: 0)
        #expect(file.musicRelativeFolder == nil)
    }
}

// MARK: - CloudFolder Tests

@Suite("CloudFolder")
struct CloudFolderTests {

    @Test("name is last path component of key")
    func nameIsLastComponent() {
        let folder = CloudFolder(key: "Music/Jazz/", hasMp3s: true, hasSubFolders: false)
        #expect(folder.name == "Jazz")
    }

    @Test("top-level folder name")
    func topLevelFolderName() {
        let folder = CloudFolder(key: "Music/", hasMp3s: false, hasSubFolders: true)
        #expect(folder.name == "Music")
    }
}

// MARK: - SyncResult Tests

@Suite("SyncResult")
struct SyncResultTests {

    private func makeFile(_ key: String) -> CloudFile { CloudFile(key: key, size: 0) }
    private func makeSyncItem(key: String, isLocal: Bool) -> SyncItem {
        SyncItem(file: makeFile(key), subfolder: "", isLocal: isLocal)
    }

    @Test("missingCount equals cloudOnly count")
    func missingCountEqualsCloudOnly() {
        let result = SyncResult(
            cloudOnly: [makeSyncItem(key: "Music/a.mp3", isLocal: false),
                        makeSyncItem(key: "Music/b.mp3", isLocal: false)],
            synced:    [makeSyncItem(key: "Music/c.mp3", isLocal: true)],
            localOnly: [],
            checkedAt: Date()
        )
        #expect(result.missingCount == 2)
    }

    @Test("totalCloud is cloudOnly plus synced")
    func totalCloudSum() {
        let result = SyncResult(
            cloudOnly: [makeSyncItem(key: "Music/a.mp3", isLocal: false)],
            synced:    [makeSyncItem(key: "Music/b.mp3", isLocal: true),
                        makeSyncItem(key: "Music/c.mp3", isLocal: true)],
            localOnly: [],
            checkedAt: Date()
        )
        #expect(result.totalCloud == 3)
    }

    @Test("empty result has zero counts")
    func emptyResultZeroCounts() {
        let result = SyncResult(cloudOnly: [], synced: [], localOnly: [], checkedAt: Date())
        #expect(result.missingCount == 0)
        #expect(result.totalCloud == 0)
    }
}

// MARK: - SyncItem Tests

@Suite("SyncItem")
struct SyncItemTests {

    @Test("subfolderOrNil returns nil for empty string")
    func subfolderOrNilEmpty() {
        let item = SyncItem(file: CloudFile(key: "Music/song.mp3", size: 0), subfolder: "", isLocal: false)
        #expect(item.subfolderOrNil == nil)
    }

    @Test("subfolderOrNil returns value when non-empty")
    func subfolderOrNilNonEmpty() {
        let item = SyncItem(file: CloudFile(key: "Music/Jazz/song.mp3", size: 0), subfolder: "Jazz", isLocal: false)
        #expect(item.subfolderOrNil == "Jazz")
    }
}

// MARK: - LocalLibraryTree Tests

@Suite("LocalLibraryTree")
struct LocalLibraryTreeTests {

    @Test("empty track list produces empty root")
    func emptyTracks() {
        let root = LocalLibraryTree.build(from: [])
        #expect(root.folders.isEmpty)
        #expect(root.rootTracks.isEmpty)
    }

    @Test("root-level tracks go into rootTracks")
    func rootTracks() {
        let tracks = [makeTrack("b.mp3"), makeTrack("a.mp3")]
        let root = LocalLibraryTree.build(from: tracks)
        #expect(root.rootTracks.count == 2)
        #expect(root.folders.isEmpty)
        // sorted by title
        #expect(root.rootTracks[0].title == "a")
        #expect(root.rootTracks[1].title == "b")
    }

    @Test("subfolder tracks appear in folder node not rootTracks")
    func subfolderTracksInFolderNode() {
        let tracks = [makeTrack("Jazz/song.mp3")]
        let root = LocalLibraryTree.build(from: tracks)
        #expect(root.rootTracks.isEmpty)
        #expect(root.folders.count == 1)
        #expect(root.folders[0].name == "Jazz")
        #expect(root.folders[0].directTracks.count == 1)
    }

    @Test("folders sorted alphabetically")
    func foldersSortedAlphabetically() {
        let tracks = [makeTrack("Rock/song.mp3"), makeTrack("Jazz/song.mp3"), makeTrack("Blues/song.mp3")]
        let root = LocalLibraryTree.build(from: tracks)
        let names = root.folders.map(\.name)
        #expect(names == ["Blues", "Jazz", "Rock"])
    }

    @Test("nested folders build correct hierarchy")
    func nestedFolderHierarchy() {
        let tracks = [makeTrack("Jazz/Bebop/song.mp3")]
        let root = LocalLibraryTree.build(from: tracks)
        #expect(root.folders.count == 1)
        let jazz = root.folders[0]
        #expect(jazz.name == "Jazz")
        #expect(jazz.directTracks.isEmpty)
        #expect(jazz.children.count == 1)
        #expect(jazz.children[0].name == "Bebop")
        #expect(jazz.children[0].directTracks.count == 1)
    }

    @Test("allTracks includes direct and nested tracks")
    func allTracksRecursive() {
        let tracks = [
            makeTrack("Jazz/direct.mp3"),
            makeTrack("Jazz/Bebop/nested.mp3")
        ]
        let root = LocalLibraryTree.build(from: tracks)
        let jazz = root.folders[0]
        #expect(jazz.allTracks.count == 2)
    }

    @Test("directTracks sorted by title within folder")
    func directTracksSortedByTitle() {
        let tracks = [makeTrack("Jazz/c.mp3"), makeTrack("Jazz/a.mp3"), makeTrack("Jazz/b.mp3")]
        let root = LocalLibraryTree.build(from: tracks)
        let titles = root.folders[0].directTracks.map(\.title)
        #expect(titles == ["a", "b", "c"])
    }

    @Test("showsPlayButtons true for leaf folder with no children")
    func showsPlayButtonsLeaf() {
        let tracks = [makeTrack("Jazz/song.mp3")]
        let root = LocalLibraryTree.build(from: tracks)
        #expect(root.folders[0].showsPlayButtons == true)
    }

    @Test("showsPlayButtons true for folder with direct tracks even if it has children")
    func showsPlayButtonsWithDirectTracks() {
        let tracks = [makeTrack("Jazz/direct.mp3"), makeTrack("Jazz/Bebop/nested.mp3")]
        let root = LocalLibraryTree.build(from: tracks)
        let jazz = root.folders[0]
        #expect(jazz.showsPlayButtons == true)
    }

    @Test("showsPlayButtons false for pure container folder")
    func showsPlayButtonsPureContainer() {
        let tracks = [makeTrack("Jazz/Bebop/song.mp3")]
        let root = LocalLibraryTree.build(from: tracks)
        let jazz = root.folders[0]
        // Jazz has no direct tracks and has children — pure container
        #expect(jazz.showsPlayButtons == false)
    }

    @Test("mixed root and folder tracks")
    func mixedRootAndFolderTracks() {
        let tracks = [makeTrack("root.mp3"), makeTrack("Jazz/jazz.mp3")]
        let root = LocalLibraryTree.build(from: tracks)
        #expect(root.rootTracks.count == 1)
        #expect(root.folders.count == 1)
    }

    @Test("multiple tracks in same folder")
    func multipleTracksInSameFolder() {
        let tracks = [makeTrack("Jazz/a.mp3"), makeTrack("Jazz/b.mp3"), makeTrack("Jazz/c.mp3")]
        let root = LocalLibraryTree.build(from: tracks)
        #expect(root.folders.count == 1)
        #expect(root.folders[0].directTracks.count == 3)
    }
}
