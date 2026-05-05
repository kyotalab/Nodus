//
//  NoteListView.swift
//  Nodus
//
//  PHASE 4: SearchEngineによるリアルタイム検索・空状態UXを含むノート一覧。
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
    /// 検索バー入力。空文字のときは全件表示する。
    @State private var searchQuery = ""

    /// SearchEngine を使って、クエリに応じた一覧をリアルタイムで作る。
    private var filteredNotes: [Note] {
        SearchEngine.search(searchQuery, in: store.notes)
    }

    /// 「検索クエリあり」かつ「結果 0 件」のときに空状態 UI を出す。
    private var shouldShowEmptySearchState: Bool {
        !searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && filteredNotes.isEmpty
    }

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
                if shouldShowEmptySearchState {
                    // 結果ゼロ時は、メッセージと新規作成アクションを表示する。
                    Text("Nothing found for \"\(searchQuery)\"")
                        .foregroundStyle(.secondary)
                    Button("+ Create new note") {
                        addNote(splitSelection: selection)
                    }
                } else {
                    ForEach(filteredNotes) { note in
                        Text(note.displayName)
                            .tag(Optional(note.id))
                    }
                }
            }
            // 検索バーは常時表示し、入力に応じて filteredNotes を更新する。
            .searchable(
                text: $searchQuery,
                placement: .navigationBarDrawer(displayMode: .always)
            )
            // Zettelkasten の検索入力は小文字をデフォルトとするため自動大文字化を無効化する。
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
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
                if shouldShowEmptySearchState {
                    // コンパクト表示でも同じ UX を維持する。
                    Text("Nothing found for \"\(searchQuery)\"")
                        .foregroundStyle(.secondary)
                    Button("+ Create new note") {
                        addNote(splitSelection: nil)
                    }
                } else {
                    ForEach(filteredNotes) { note in
                        NavigationLink(value: note.id) {
                            Text(note.displayName)
                        }
                    }
                }
            }
            // iPhone 系レイアウトにも検索バーを常時表示する。
            .searchable(
                text: $searchQuery,
                placement: .navigationBarDrawer(displayMode: .always)
            )
            // コンパクト表示でも検索入力時の自動大文字化を無効化する。
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
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
        guard let note = store.createNote() else { return }
        if let selection = splitSelection {
            selection.wrappedValue = note.id
        } else {
            compactNavigationPath.append(note.id)
        }
    }
}
