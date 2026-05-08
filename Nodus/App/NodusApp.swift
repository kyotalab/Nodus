//
//  NodusApp.swift
//  Nodus
//
//  Created by 中田恭大 on 2026/05/03.
//

import SwiftUI

@main
struct NodusApp: App {
    // iCloud コンテナ IDは `NodusICloudContainerIdentifier`（FolderBookmark.swift）と entitlements で一致させる。

    /// ノート一覧状態はアプリ全体で 1 つを共有する。
    @StateObject private var noteStore = NoteStore()
    /// 初回フォルダ選択状態（bookmark 復元結果）を保持する。
    @StateObject private var folderBookmark = FolderBookmark()

    var body: some Scene {
        WindowGroup {
            NodusRootView(noteStore: noteStore, folderBookmark: folderBookmark)
        }
    }
}
