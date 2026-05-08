//
//  SettingsView.swift
//  Nodus
//
//  PHASE 5: Storage / Editor / About をまとめた設定画面
//

import SwiftUI
import UIKit
import UniformTypeIdentifiers

/// アプリ設定を 1 画面に集約したビュー。
struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    /// 設定からフォルダ再選択するため、環境オブジェクトで bookmark 管理を受け取る。
    @EnvironmentObject private var folderBookmark: FolderBookmark

    /// エディタ初期モードの保存先。`edit` / `preview` の文字列で保持する。
    @AppStorage("defaultEditorMode") private var defaultEditorMode = "edit"

    /// フォルダピッカー表示制御。
    @State private var isPresentingFolderPicker = false
    /// フォルダ選択失敗時のメッセージ。
    @State private var folderSelectionErrorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Storage") {
                    Button {
                        // 設定からの再選択フロー開始時に、いったん選択状態をクリアする。
                        folderSelectionErrorMessage = nil
                        folderBookmark.clearSelectionForSettings()
                        isPresentingFolderPicker = true
                    } label: {
                        HStack {
                            Text("Zettelkasten Folder")
                            Spacer()
                            Text(currentFolderPathText)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                    }

                    if let folderSelectionErrorMessage {
                        Text(folderSelectionErrorMessage)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }

                Section("Editor") {
                    // 初期表示モードを 2 択で永続化する。
                    Picker("Default Mode", selection: $defaultEditorMode) {
                        Text("Edit").tag("edit")
                        Text("Preview").tag("preview")
                    }
                    .pickerStyle(.segmented)
                }

                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text(appVersion)
                            .foregroundStyle(.secondary)
                    }

                    // Link を使って Safari でサポートページを開く。
                    Link("Support", destination: supportURL)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $isPresentingFolderPicker) {
                SettingsFolderDocumentPicker { result in
                    switch result {
                    case .success(let url):
                        do {
                            try folderBookmark.saveSelectedFolder(url)
                            // 保存後に再読込し、購読側へ最新URLを通知する。
                            folderBookmark.reload()
                        } catch {
                            folderSelectionErrorMessage = "Failed to save the selected folder."
                        }
                    case .failure(let error):
                        // キャンセル時も含め、選択結果をユーザーに明示する。
                        folderSelectionErrorMessage = error.localizedDescription
                    }
                }
            }
        }
    }

    /// About セクションに表示するバージョン文字列を組み立てる。
    private var appVersion: String {
        let shortVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
        return shortVersion ?? "Unknown"
    }

    /// サポートリンクの暫定 URL。
    private var supportURL: URL {
        URL(string: "mailto:kyouta.nakada@gmail.com")!
    }

    /// 現在のフォルダ表示文字列。DEBUG シミュレータでは固定ラベルを返す。
    private var currentFolderPathText: String {
        #if DEBUG
        #if targetEnvironment(simulator)
        return "Simulator (Debug Mode)"
        #else
        return folderBookmark.selectedFolderURL?.path ?? "Not selected"
        #endif
        #else
        return folderBookmark.selectedFolderURL?.path ?? "Not selected"
        #endif
    }
}

/// Settings 画面専用のフォルダ選択ラッパー。
private struct SettingsFolderDocumentPicker: UIViewControllerRepresentable {
    let onPicked: (Result<URL, Error>) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onPicked: onPicked)
    }

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        // iCloud Drive のフォルダ選択を直接行う。
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.folder], asCopy: false)
        picker.delegate = context.coordinator
        picker.allowsMultipleSelection = false
        picker.directoryURL = FileManager.default.url(forUbiquityContainerIdentifier: NodusICloudContainerIdentifier.string)?
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
            onPicked(.failure(SettingsFolderPickerError.cancelled))
        }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else {
                onPicked(.failure(SettingsFolderPickerError.emptySelection))
                return
            }

            guard isICloudFolder(url) else {
                onPicked(.failure(SettingsFolderPickerError.notICloudFolder))
                return
            }
            onPicked(.success(url))
        }

        /// URL リソース値とパスの両面で iCloud 配下かを判定する。
        private func isICloudFolder(_ url: URL) -> Bool {
            let values = try? url.resourceValues(forKeys: [.isUbiquitousItemKey])
            if values?.isUbiquitousItem == true {
                return true
            }
            return url.path.contains("/Mobile Documents/")
        }
    }
}

private enum SettingsFolderPickerError: LocalizedError {
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
    SettingsView()
        .environmentObject(FolderBookmark())
}
