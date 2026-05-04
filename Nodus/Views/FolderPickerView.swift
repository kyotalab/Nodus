//
//  FolderPickerView.swift
//  Nodus
//
//  PHASE 3: 初回起動時のフォルダ選択 UI
//

import SwiftUI
import UIKit
import UniformTypeIdentifiers

/// 未選択時に表示する初回フォルダ選択画面。
struct FolderPickerView: View {
    @ObservedObject var folderBookmark: FolderBookmark

    /// 選択完了後に親ビューへ通知し、画面遷移を進める。
    let onSelectionCompleted: () -> Void

    @State private var isPresentingPicker = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                VStack(spacing: 12) {
                    Text("Select your Zettelkasten folder")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .multilineTextAlignment(.center)

                    Text("Choose the folder where your notes are stored.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                Button("Select Folder") {
                    errorMessage = nil
                    isPresentingPicker = true
                }
                .buttonStyle(.borderedProminent)

                if let errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(24)
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $isPresentingPicker) {
                FolderDocumentPicker { result in
                    switch result {
                    case .success(let url):
                        do {
                            try folderBookmark.saveSelectedFolder(url)
                            onSelectionCompleted()
                        } catch {
                            errorMessage = "Failed to save the selected folder."
                        }
                    case .failure(let error):
                        errorMessage = error.localizedDescription
                    }
                }
            }
        }
    }
}

/// UIDocumentPickerViewController を SwiftUI から使うためのラッパー。
private struct FolderDocumentPicker: UIViewControllerRepresentable {
    /// 選択結果を親へ返すコールバック。
    let onPicked: (Result<URL, Error>) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onPicked: onPicked)
    }

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        // フォルダのみ選択可能にし、元の場所（iCloud Drive）を直接参照する。
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.folder], asCopy: false)
        picker.delegate = context.coordinator
        picker.allowsMultipleSelection = false
        picker.directoryURL = FileManager.default.url(forUbiquityContainerIdentifier: nil)?
            .deletingLastPathComponent()
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    final class Coordinator: NSObject, UIDocumentPickerDelegate {
        private let onPicked: (Result<URL, Error>) -> Void

        init(onPicked: @escaping (Result<URL, Error>) -> Void) {
            self.onPicked = onPicked
        }

        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            onPicked(.failure(FolderPickerError.cancelled))
        }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else {
                onPicked(.failure(FolderPickerError.emptySelection))
                return
            }

            // iCloud Drive 配下フォルダのみ受け付ける（仕様要件）。
            guard isICloudFolder(url) else {
                onPicked(.failure(FolderPickerError.notICloudFolder))
                return
            }
            onPicked(.success(url))
        }

        /// URL リソース値とパスの両方で iCloud Drive 配下かを判定する。
        private func isICloudFolder(_ url: URL) -> Bool {
            let values = try? url.resourceValues(forKeys: [.isUbiquitousItemKey])
            if values?.isUbiquitousItem == true {
                return true
            }
            return url.path.contains("/Mobile Documents/")
        }
    }
}

private enum FolderPickerError: LocalizedError {
    case cancelled
    case emptySelection
    case notICloudFolder

    var errorDescription: String? {
        switch self {
        case .cancelled:
            return "Folder selection was cancelled."
        case .emptySelection:
            return "No folder was selected."
        case .notICloudFolder:
            return "Please select a folder in iCloud Drive."
        }
    }
}

#Preview {
    FolderPickerView(folderBookmark: FolderBookmark()) {}
}
