//
//  NoteDetailView.swift
//  Nodus
//
//  PHASE 2: 詳細ペインのプレースホルダー（エディタは後続フェーズ）
//

import SwiftUI

/// 1件のノートの詳細。PHASE 2 では本文をそのまま見せるだけ。
struct NoteDetailView: View {
    let note: Note

    var body: some View {
        ScrollView {
            Text(note.body)
                .font(.body)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
        }
        .navigationTitle(note.displayName)
    }
}
