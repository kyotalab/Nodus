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

    /// iPad の Split では `Note` 丸ごとの `List(selection:)` がタグ一致に失敗することがあるため、ID 文字列で選ぶ。
    @State private var selectedNoteID: String?

    var body: some View {
        Group {
            if horizontalSizeClass == .regular {
                NavigationSplitView {
                    NoteListView(style: .splitSidebar(selection: $selectedNoteID))
                } detail: {
                    detailPane
                }
            } else {
                NoteListView(style: .compactStack)
            }
        }
    }

    /// 詳細ペイン。選択 ID に対応する `Note` をストアから引き直す（一覧と常に同じインスタンスを指す）。
    @ViewBuilder
    private var detailPane: some View {
        if let id = selectedNoteID, let note = store.notes.first(where: { $0.id == id }) {
            NoteDetailView(note: note)
        } else {
            EmptySelectionView()
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(NoteStore())
}
