//
//  NodusRootView.swift
//  Nodus
//
//  WindowGroup の中身と scenePhase 連携をまとめる（App 本体は @Environment を持てないため分離）
//

import SwiftUI

/// メイン UI と `scenePhase` に応じた `NoteStore` のメタデータ監視の開始・停止を担う。
struct NodusRootView: View {
    @Environment(\.scenePhase) private var scenePhase

    @ObservedObject var noteStore: NoteStore
    @ObservedObject var folderBookmark: FolderBookmark

    var body: some View {
        Group {
            if folderBookmark.hasSelectedFolder {
                ContentView()
                    .environmentObject(noteStore)
                    .environmentObject(folderBookmark)
            } else {
                FolderPickerView(folderBookmark: folderBookmark) {
                    noteStore.loadNotes()
                }
            }
        }
        .onAppear {
            noteStore.configure(folderBookmark: folderBookmark)
        }
        .onChange(of: folderBookmark.selectedFolderURL) { _, _ in
            noteStore.configure(folderBookmark: folderBookmark)
        }
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .active:
                if folderBookmark.hasSelectedFolder {
                    noteStore.startMonitoring()
                }
            case .background:
                noteStore.stopMonitoring()
            default:
                break
            }
        }
    }
}
