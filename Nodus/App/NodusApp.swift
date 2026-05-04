//
//  NodusApp.swift
//  Nodus
//
//  Created by 中田恭大 on 2026/05/03.
//

import SwiftUI

@main
struct NodusApp: App {
    /// ノート一覧状態はアプリ全体で 1 つを共有する。
    @StateObject private var noteStore = NoteStore()
    /// 初回フォルダ選択状態（bookmark 復元結果）を保持する。
    @StateObject private var folderBookmark = FolderBookmark()

    var body: some Scene {
        WindowGroup {
            Group {
                // bookmark が未設定なら初回フォルダ選択 UI を表示する。
                if folderBookmark.hasSelectedFolder {
                    ContentView()
                        .environmentObject(noteStore)
                        .environmentObject(folderBookmark)
                } else {
                    FolderPickerView(folderBookmark: folderBookmark) {
                        // フォルダ選択直後にノート一覧を読み込む。
                        noteStore.loadNotes()
                    }
                }
            }
            .onAppear {
                // 起動時に FolderBookmark を NoteStore へ渡して連携を開始する。
                noteStore.configure(folderBookmark: folderBookmark)
            }
            .onChange(of: folderBookmark.selectedFolderURL) { _, _ in
                // フォルダ変更時（初回選択含む）は毎回再読込する。
                noteStore.configure(folderBookmark: folderBookmark)
            }
        }
    }
}
