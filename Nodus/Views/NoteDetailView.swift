//
//  NoteDetailView.swift
//  Nodus
//
//  PHASE 2: 詳細ペインのプレースホルダー（エディタは後続フェーズ）
//

import SwiftUI

/// 1件のノートの詳細。PHASE 3 STEP 4 では本文を遅延ロードして表示する。
struct NoteDetailView: View {
    @EnvironmentObject private var store: NoteStore
    let note: Note
    @State private var loadedBody = ""

    var body: some View {
        ScrollView {
            Text(loadedBody)
                .font(.body)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
        }
        .navigationTitle(note.displayName)
        .task(id: note.url) {
            // DEBUG シミュレータのダミーデータは body を直接持つため、まずそちらを優先する。
            if !note.body.isEmpty {
                loadedBody = note.body
            } else {
                // 実ファイル運用時は従来どおり遅延ロードする。
                loadedBody = store.loadBody(for: note)
            }
        }
    }
}
