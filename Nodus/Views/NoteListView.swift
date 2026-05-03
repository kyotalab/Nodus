//
//  NoteListView.swift
//  Nodus
//
//  PHASE 2: 一覧のみ。表示モードは親が `horizontalSizeClass` に応じて選ぶ。
//

import SwiftUI

/// ノート一覧。iPad 等では `List(selection:)` で Split の詳細と同期し、
/// iPhone（コンパクト幅）では `NavigationLink` でスタック遷移する。
struct NoteListView: View {
    /// 一覧の出し分け（`Binding` を含むため `Equatable` にはしない）
    enum Style {
        /// `NavigationSplitView` のサイドバー用。選択は `UUID?` で行い、詳細側で `Note` を引き直す。
        case splitSidebar(selection: Binding<UUID?>)
        /// iPhone 向け。内側の `NavigationStack` でプッシュ遷移する。
        case compactStack
    }

    @EnvironmentObject private var store: NoteStore
    let style: Style

    var body: some View {
        switch style {
        case .splitSidebar(let selection):
            splitSidebarList(selection: selection)
        case .compactStack:
            compactStackList
        }
    }

    /// iPad / ワイド: 選択型は `UUID?` にして `List` のタグと確実に一致させる。
    private func splitSidebarList(selection: Binding<UUID?>) -> some View {
        NavigationStack {
            List(selection: selection) {
                ForEach(store.notes) { note in
                    Text(note.displayName)
                        .tag(Optional(note.id))
                }
            }
            .navigationTitle("Notes")
        }
    }

    /// iPhone 等: `NavigationLink` で `NoteDetailView` へプッシュ
    private var compactStackList: some View {
        NavigationStack {
            List {
                ForEach(store.notes) { note in
                    NavigationLink {
                        NoteDetailView(note: note)
                    } label: {
                        Text(note.displayName)
                    }
                }
            }
            .navigationTitle("Notes")
        }
    }
}
