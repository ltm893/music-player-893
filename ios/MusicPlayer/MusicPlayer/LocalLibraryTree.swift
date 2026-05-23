//
//  LocalLibraryTree.swift
//  MusicPlayer
//
//  Shared folder tree for local Documents MP3s (iPhone list + CarPlay).
//

import Foundation

struct LocalFolderNode: Identifiable {
    let id: String
    let name: String
    let path: String
    var directTracks: [Track]
    var children: [LocalFolderNode]

    var allTracks: [Track] {
        directTracks + children.flatMap(\.allTracks)
    }

    /// Play / Shuffle when the folder has direct MP3s or is a leaf (matches ContentView).
    var showsPlayButtons: Bool {
        !directTracks.isEmpty || children.isEmpty
    }
}

struct LocalLibraryRoot {
    var folders: [LocalFolderNode]
    var rootTracks: [Track]
}

enum LocalLibraryTree {

    static func build(from tracks: [Track]) -> LocalLibraryRoot {
        final class Node {
            let name: String
            let path: String
            var directTracks: [Track] = []
            var children: [String: Node] = [:]

            init(name: String, path: String) {
                self.name = name
                self.path = path
            }
        }

        let root = Node(name: "root", path: "")

        for track in tracks {
            let segments = (track.folder ?? "")
                .split(separator: "/")
                .map(String.init)

            var current = root
            var currentPath = ""
            for segment in segments {
                currentPath = currentPath.isEmpty ? segment : "\(currentPath)/\(segment)"
                if current.children[segment] == nil {
                    current.children[segment] = Node(name: segment, path: currentPath)
                }
                current = current.children[segment]!
            }
            current.directTracks.append(track)
        }

        func flatten(_ node: Node) -> [LocalFolderNode] {
            node.children.keys.sorted().compactMap { key in
                guard let child = node.children[key] else { return nil }
                return LocalFolderNode(
                    id: child.path,
                    name: child.name,
                    path: child.path,
                    directTracks: child.directTracks.sorted { $0.title < $1.title },
                    children: flatten(child)
                )
            }
        }

        return LocalLibraryRoot(
            folders: flatten(root),
            rootTracks: root.directTracks.sorted { $0.title < $1.title }
        )
    }
}
