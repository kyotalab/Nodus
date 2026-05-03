//
//  ContentView.swift
//  Nodus
//
//  PHASE 2: NavigationSplitView のルート。サイドバーと詳細の切り替えだけを担う。
//

import SwiftUI

/// アプリ全体の分割レイアウトの起点。`NoteStore` は環境オブジェクトから取得する。
struct ContentView: View {
    /// 一覧・詳細で共有するノートストア（`NodusApp` で注入される想定）
    @EnvironmentObject private var store: NoteStore

    /// ユーザーが一覧で選んでいるノート。未選択時は詳細にプレースホルダーを出す。
    @State private var selectedNote: Note?

    var body: some View {
        // iPhone ではサイドバーが全画面、iPad では左ペインとして表示される。
        NavigationSplitView {
            // 左（サイドバー）: ノート一覧。選択状態は親が保持するバインディングで同期する。
            NoteListView(selectedNote: $selectedNote)
        } detail: {
            // 右（詳細）: 選択の有無で中身を切り替える。
            detailPane
        }
    }

    /// 詳細ペインの中身。ノートが選ばれていれば詳細ビュー、そうでなければ空選択用ビュー。
    @ViewBuilder
    private var detailPane: some View {
        if let note = selectedNote {
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
