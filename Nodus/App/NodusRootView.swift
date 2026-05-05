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
            if shouldBypassFolderPickerInDebugSimulator {
                // DEBUG + Simulator 専用: フォルダ選択をスキップして一覧画面を直接表示する。
                ContentView()
                    .environmentObject(noteStore)
                    .environmentObject(folderBookmark)
            } else if folderBookmark.hasSelectedFolder {
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
            if shouldBypassFolderPickerInDebugSimulator {
                // DEBUG + Simulator 専用: 本番フローに触れずダミーデータを注入する。
                noteStore.loadDebugDummyNotesForSimulator()
            } else {
                noteStore.configure(folderBookmark: folderBookmark)
            }
        }
        .onChange(of: folderBookmark.selectedFolderURL) { _, _ in
            if !shouldBypassFolderPickerInDebugSimulator {
                // 本番（または実機）では従来どおり bookmark 変更に追従する。
                noteStore.configure(folderBookmark: folderBookmark)
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            if shouldBypassFolderPickerInDebugSimulator {
                // DEBUG + Simulator では iCloud 監視を使わないため何もしない。
                return
            }
            switch newPhase {
            case .active:
                // フォアグラウンド復帰時に iCloud 側の変更を拾う監視を再開する。
                if folderBookmark.hasSelectedFolder {
                    noteStore.startMonitoring()
                }
            case .background:
                // バックグラウンドではクエリと security scope を解放する。
                noteStore.stopMonitoring()
            default:
                break
            }
        }
    }

    /// DEBUG ビルドのシミュレータ実行時だけ true になる分岐フラグ。
    /// この条件でフォルダ選択スキップを本番コードから完全に分離する。
    private var shouldBypassFolderPickerInDebugSimulator: Bool {
        #if DEBUG
        #if targetEnvironment(simulator)
        true
        #else
        false
        #endif
        #else
        false
        #endif
    }
}
