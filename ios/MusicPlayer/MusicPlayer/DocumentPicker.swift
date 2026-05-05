//
//  DocumentPicker.swift
//  MusicPlayer
//
//  Created by Louis Melchiorre        on 3/17/26.
//

import SwiftUI
import UniformTypeIdentifiers

/// Wraps UIDocumentPickerViewController so SwiftUI can present it as a sheet.
struct DocumentPicker: UIViewControllerRepresentable {

    /// Called with every URL the user picks
    var onPick: ([URL]) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onPick: onPick)
    }

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        // Allow picking .mp3 files (and the generic audio type as a fallback)
        let picker = UIDocumentPickerViewController(
            forOpeningContentTypes: [UTType.mp3, UTType.audio],
            asCopy: false          // we'll copy manually so we can check for duplicates
        )
        picker.allowsMultipleSelection = true
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    // MARK: - Coordinator

    class Coordinator: NSObject, UIDocumentPickerDelegate {
        var onPick: ([URL]) -> Void
        init(onPick: @escaping ([URL]) -> Void) { self.onPick = onPick }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            onPick(urls)
        }
    }
}
