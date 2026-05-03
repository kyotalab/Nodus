//
//  NoteListView.swift
//  Nodus
//
//  PHASE 2: ContentView からの呼び出しに応じる最小の一覧（本実装は後続フェーズ）
//

import SwiftUI

/// サイドバー用のノート一覧。選択中ノートは親の `@State` とバインディングで共有する。
struct NoteListView: View {
    @EnvironmentObject private var store: NoteStore
    @Binding var selectedNote: Note?

    var body: some View {
        List {
            ForEach(store.notes) { note in
                Button {
                    selectedNote = note
                } label: {
                    Text(rowLabel(for: note))
                }
                .foregroundStyle(.primary)
            }
        }
        .navigationTitle("ノート")
    }

    /// 一覧行に出す文字列（タイトルがあればそれ、なければタイムスタンプ ID）
    private func rowLabel(for note: Note) -> String {
        let title = note.title
        return title.isEmpty ? note.timestampID : title
    }
}
