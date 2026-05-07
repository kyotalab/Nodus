//
//  ContentView.swift
//  Nodus
//
//  PHASE 2: NavigationSplitView のルート。サイドバーと詳細の切り替えだけを担う。
//

import SwiftUI

/// アプリ全体の分割レイアウトの起点。`NoteStore` は一覧・詳細の解決の両方で参照する。
struct ContentView: View {
    @EnvironmentObject private var store: NoteStore
    /// 横並びの列が「レギュラー」かどうか（iPhone 縦は通常 `.compact`）
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    /// サイドバー `List(selection:)` と共有する選択ノート ID（`nil` = 未選択）。
    /// `String` は `Note.id`（先頭 12 桁タイムスタンプ）と一致させる。
    @State private var selectedNoteID: String?

    var body: some View {
        Group {
            if horizontalSizeClass == .regular {
                NavigationSplitView {
                    // `$selectedNoteID` をそのまま渡し、一覧タップで更新 → detail が再評価される。
                    NoteListView(style: .splitSidebar(selection: $selectedNoteID))
                } detail: {
                    detailPane
                }
            } else {
                NoteListView(style: .compactStack)
            }
        }
    }

    /// 詳細ペイン。`selectedNoteID` はここでは書き換えない（一覧の `List` が唯一の更新元）。
    @ViewBuilder
    private var detailPane: some View {
        if let id = selectedNoteID, let note = store.notes.first(where: { $0.id == id }) {
            // 詳細列には外側 `NavigationStack` が無いため wiki 用に内側へ包む（iPhone compact では二重になるのを避け `false`）。
            NoteDetailView(note: note, embedInNavigationStack: true)
                // 選択切替で `@State` が前ノートのまま残らないようにする。
                .id(id)
        } else {
            EmptySelectionView()
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(NoteStore())
}
