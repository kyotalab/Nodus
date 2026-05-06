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
    /// 一覧の並び順。選択状態は `@AppStorage` で永続化する。
    enum SortOrder: String, CaseIterable {
        case updatedDesc = "Updated (newest)"
        case createdDesc = "Created (newest)"
        case titleAsc = "Title (A-Z)"
        case backlinkDesc = "Most linked"
        case random = "Random"
    }

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
    /// 並び順の選択を永続化する。
    @AppStorage("sortOrder") private var sortOrderRawValue = SortOrder.updatedDesc.rawValue
    /// Random 並び順を安定保持するための ID 順序キャッシュ。
    @State private var randomOrderIDs: [String] = []
    /// スワイプ削除時に確認ダイアログへ渡す対象ノート。
    @State private var noteToDelete: Note?
    /// Settings シートの表示状態。
    @State private var isShowingSettings = false

    /// SearchEngine を使って、クエリに応じた一覧をリアルタイムで作る。
    private var filteredNotes: [Note] {
        SearchEngine.search(searchQuery, in: store.notes)
    }

    /// 検索後の結果に対して現在のソート順を適用した最終表示一覧。
    private var sortedNotes: [Note] {
        sort(filteredNotes, by: currentSortOrder)
    }

    /// 「検索クエリあり」かつ「結果 0 件」のときに空状態 UI を出す。
    private var shouldShowEmptySearchState: Bool {
        !searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && sortedNotes.isEmpty
    }

    /// 文字列保存値から現在の並び順を復元する（不正値はデフォルトへフォールバック）。
    private var currentSortOrder: SortOrder {
        SortOrder(rawValue: sortOrderRawValue) ?? .updatedDesc
    }

    var body: some View {
        Group {
            switch style {
            case .splitSidebar(let selection):
                splitSidebarList(selection: selection)
            case .compactStack:
                compactStackList
            }
        }
        .onAppear {
            // 初期表示時に Random が選ばれている場合の順序を準備する。
            if currentSortOrder == .random {
                reshuffleRandomOrder()
            }
        }
        .onChange(of: searchQuery) { _, _ in
            // Random 中に検索条件が変わった場合は、対象集合に対して並び順を作り直す。
            if currentSortOrder == .random {
                reshuffleRandomOrder()
            }
        }
        .onChange(of: store.notes) { _, _ in
            // データ更新時も Random のキャッシュ順を再生成して不整合を防ぐ。
            if currentSortOrder == .random {
                reshuffleRandomOrder()
            }
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
                    ForEach(sortedNotes) { note in
                        Text(note.displayName)
                            .tag(Optional(note.id))
                            .swipeActions(edge: .trailing) {
                                // 右スワイプで削除確認を開始する。
                                Button(role: .destructive) {
                                    noteToDelete = note
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
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
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        // 一覧画面から設定をシート表示する。
                        isShowingSettings = true
                    } label: {
                        Image(systemName: "gear")
                    }
                    .accessibilityLabel("Settings")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    sortMenu
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        addNote(splitSelection: selection)
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("New note")
                }
            }
            .sheet(isPresented: $isShowingSettings) {
                SettingsView()
            }
            .alert(item: $noteToDelete) { note in
                // 削除は必ず確認ダイアログを経由し、誤操作を防ぐ。
                Alert(
                    title: Text("Delete '\(deleteDisplayTitle(for: note))'?"),
                    message: Text("This cannot be undone."),
                    primaryButton: .cancel(Text("Cancel")),
                    secondaryButton: .destructive(Text("Delete")) {
                        store.deleteNote(note)
                    }
                )
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
                    ForEach(sortedNotes) { note in
                        NavigationLink(value: note.id) {
                            Text(note.displayName)
                        }
                        .swipeActions(edge: .trailing) {
                            // コンパクト表示でも同じ削除導線を提供する。
                            Button(role: .destructive) {
                                noteToDelete = note
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
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
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        // コンパクト表示でも同じ設定導線を提供する。
                        isShowingSettings = true
                    } label: {
                        Image(systemName: "gear")
                    }
                    .accessibilityLabel("Settings")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    sortMenu
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        addNote(splitSelection: nil)
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("New note")
                }
            }
            .sheet(isPresented: $isShowingSettings) {
                SettingsView()
            }
            .alert(item: $noteToDelete) { note in
                // 削除は必ず確認ダイアログを経由し、誤操作を防ぐ。
                Alert(
                    title: Text("Delete '\(deleteDisplayTitle(for: note))'?"),
                    message: Text("This cannot be undone."),
                    primaryButton: .cancel(Text("Cancel")),
                    secondaryButton: .destructive(Text("Delete")) {
                        store.deleteNote(note)
                    }
                )
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

    /// ソート選択 UI。現在選択中の項目にはチェックマークを表示する。
    private var sortMenu: some View {
        Menu {
            ForEach(SortOrder.allCases, id: \.rawValue) { order in
                Button {
                    selectSortOrder(order)
                } label: {
                    if currentSortOrder == order {
                        Label(order.rawValue, systemImage: "checkmark")
                    } else {
                        Text(order.rawValue)
                    }
                }
            }
        } label: {
            Image(systemName: "line.3.horizontal.decrease.circle")
        }
        .accessibilityLabel("Sort notes")
    }

    /// ソート種別に応じてノート配列を並べ替える。
    private func sort(_ notes: [Note], by order: SortOrder) -> [Note] {
        switch order {
        case .updatedDesc:
            return notes.sorted { $0.updatedAt > $1.updatedAt }
        case .createdDesc:
            return notes.sorted { $0.createdAt > $1.createdAt }
        case .titleAsc:
            return notes.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        case .backlinkDesc:
            // バックリンク数はソート時にだけ一度計算してキャッシュする。
            let backlinkCache = Dictionary(
                uniqueKeysWithValues: notes.map { note in
                    (note.id, LinkResolver.backlinkCount(for: note, in: store.notes))
                }
            )
            return notes.sorted { lhs, rhs in
                let lhsCount = backlinkCache[lhs.id] ?? 0
                let rhsCount = backlinkCache[rhs.id] ?? 0
                if lhsCount == rhsCount {
                    return lhs.updatedAt > rhs.updatedAt
                }
                return lhsCount > rhsCount
            }
        case .random:
            // Random はキャッシュ済み ID 順序に合わせて表示する。
            let orderMap = Dictionary(uniqueKeysWithValues: randomOrderIDs.enumerated().map { ($1, $0) })
            return notes.sorted { lhs, rhs in
                let lhsIndex = orderMap[lhs.id] ?? .max
                let rhsIndex = orderMap[rhs.id] ?? .max
                return lhsIndex < rhsIndex
            }
        }
    }

    /// 並び順選択を保存し、Random 選択時は毎回新しいシャッフルを生成する。
    private func selectSortOrder(_ order: SortOrder) {
        sortOrderRawValue = order.rawValue
        if order == .random {
            reshuffleRandomOrder()
        }
    }

    /// 現在の検索結果集合に対して Random 順序を再生成する。
    private func reshuffleRandomOrder() {
        randomOrderIDs = filteredNotes.map(\.id).shuffled()
    }

    /// 削除確認ダイアログに表示するタイトル文字列を返す。
    /// タイトルが空の場合は timestampID を使う。
    private func deleteDisplayTitle(for note: Note) -> String {
        note.title.isEmpty ? note.timestampID : note.title
    }
}
