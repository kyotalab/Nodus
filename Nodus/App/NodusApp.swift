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
                        // 保存完了時のフック。将来の追加処理のために保持しておく。
                    }
                }
            }
        }
    }
}
