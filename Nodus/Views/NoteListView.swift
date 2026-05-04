//
//  NoteListView.swift
//  Nodus
//
//  PHASE 2: 一覧のみ。表示モードは親が `horizontalSizeClass` に応じて選ぶ。
//

import SwiftUI

/// ノート一覧。iPad 等では `List(selection:)` で Split の詳細と同期し、
/// iPhone（コンパクト幅）では `NavigationStack` + `NavigationPath` でプッシュ遷移する。
struct NoteListView: View {
    /// 一覧の出し分け（`Binding` を含むため `Equatable` にはしない）
    enum Style {
        /// `NavigationSplitView` のサイドバー用。選択は `timestampID`（`String`）で行う。
        case splitSidebar(selection: Binding<String?>)
        /// iPhone 向け。`NavigationPath` で詳細へプッシュし、+ からの遷移も同じ経路に載せる。
        case compactStack
    }

    @EnvironmentObject private var store: NoteStore
    let style: Style

    /// コンパクトレイアウト専用。新規作成後に `append(note.id)`（String）して詳細へ進む。
    @State private var compactNavigationPath = NavigationPath()

    var body: some View {
        switch style {
        case .splitSidebar(let selection):
            splitSidebarList(selection: selection)
        case .compactStack:
            compactStackList
        }
    }

    /// iPad / ワイド: `List(selection:)` と詳細ペインを `timestampID` で同期。
    private func splitSidebarList(selection: Binding<String?>) -> some View {
        NavigationStack {
            List(selection: selection) {
                ForEach(store.notes) { note in
                    Text(note.displayName)
                        .tag(Optional(note.id))
                }
            }
            .navigationTitle("Notes")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        addNote(splitSelection: selection)
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("New note")
                }
            }
        }
    }

    /// iPhone 等: 行タップまたは + から `String` ID を積んで `navigationDestination` で詳細へ。
    private var compactStackList: some View {
        NavigationStack(path: $compactNavigationPath) {
            List {
                ForEach(store.notes) { note in
                    NavigationLink(value: note.id) {
                        Text(note.displayName)
                    }
                }
            }
            .navigationTitle("Notes")
            .navigationDestination(for: String.self) { id in
                if let note = store.notes.first(where: { $0.id == id }) {
                    NoteDetailView(note: note)
                }
            }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        addNote(splitSelection: nil)
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("New note")
                }
            }
        }
    }

    /// `createNote()` 後、Split なら `selectedNoteID` を更新、コンパクトならナビゲーションパスに積む。
    private func addNote(splitSelection: Binding<String?>?) {
        let note = store.createNote()
        if let selection = splitSelection {
            selection.wrappedValue = note.id
        } else {
            compactNavigationPath.append(note.id)
        }
    }
}
