//
//  NoteDetailView.swift
//  Nodus
//
//  PHASE 2: 詳細ペインのプレースホルダー（エディタは後続フェーズ）
//

import Combine
import SwiftUI
import UIKit

/// 1件のノートの詳細。PHASE 4 では編集/プレビュー切替と自動保存を担う。
struct NoteDetailView: View {
    /// 一覧・保存など通常のストア参照用（親が `.environmentObject` で渡す）。
    @EnvironmentObject private var store: NoteStore
    /// Settings で選んだ初期エディタモード（edit / preview）を参照する。
    @AppStorage("defaultEditorMode") private var defaultEditorMode = "edit"
    let note: Note
    /// iPad の `NavigationSplitView` 詳細列など、外側に `NavigationStack` が無いときだけ `true`（wiki 用プッシュのため）。
    /// iPhone の `compactStack` では外側に既に `NavigationStack` があるため `false` のままにする。
    var embedInNavigationStack: Bool = false
    /// リネーム後の URL を追従できるよう、編集中ノートの実体をローカル状態で持つ。
    @State private var currentNote: Note
    /// 編集中の本文。初期表示時にノート本文またはファイルから読み込んでセットする。
    @State private var loadedBody = ""
    /// タイトル編集用テキスト。空文字は Untitled プレースホルダで扱う。
    @State private var editingTitle = ""
    /// 編集モード/プレビューモードの切替状態。現時点では編集モード固定開始。
    @State private var isEditing: Bool = true
    /// 本文またはタイトルに未保存変更があるかを管理するフラグ。
    @State private var hasUnsavedChanges = false
    /// 本文変更時の自動保存を 2 秒遅延させるためのワークアイテム。
    @State private var autosaveWorkItem: DispatchWorkItem?
    /// キーボードツールバー表示のため、TextEditor のフォーカス状態を保持する。
    @FocusState private var isEditorFocused: Bool
    /// タイトル入力のフォーカス状態。Return またはフォーカス離脱でコミットする。
    @FocusState private var isTitleFocused: Bool
    /// プレビュー内 wiki リンクで遷移する宛先ノート（`NavigationLink` の destination に渡す）。
    @State private var linkedNoteForNavigation: Note?
    /// wiki リンクからのプッシュ遷移を有効化するフラグ（`NavigationStack` + `NavigationLink` 案）。
    @State private var isNavigatingToLinkedNote = false
    /// WKWebView プレビューの内容高さ（外側の ScrollView と二重スクロールを避ける）。
    @State private var markdownPreviewWebHeight: CGFloat = 200
    /// メタデータ等でストアが一覧を取り直したタイミングを受け、編集中は保存抑止フラグだけ立てる。
    @State private var hasExternalChange = false
    /// キーボードツールバーからカーソル位置に挿入するテキスト。
    /// MarkdownTextView が受け取って挿入後に nil にリセットする。
    @State private var toolbarInsertionText: String? = nil
    /// エディタのフォーカス状態（MarkdownTextView との双方向バインディング用）。
    @State private var isEditorFocusedState: Bool = false
    /// 共有シートの表示制御。
    @State private var isSharePresented = false

    init(note: Note, embedInNavigationStack: Bool = false) {
        self.note = note
        self.embedInNavigationStack = embedInNavigationStack
        _currentNote = State(initialValue: note)
        _editingTitle = State(initialValue: note.title)
        // defaultEditorMode は @AppStorage だが init では直接読めないため
        // UserDefaults から直接取得して初期値に使う。
        let savedMode = UserDefaults.standard.string(forKey: "defaultEditorMode") ?? "edit"
        _isEditing = State(initialValue: savedMode != "preview")
    }

    var body: some View {
        Group {
            if embedInNavigationStack {
                NavigationStack {
                    noteDetailScaffold
                }
            } else {
                noteDetailScaffold
            }
        }
    }

    /// 編集／プレビューとツールバー、wiki 用 `NavigationLink`（外側 `NavigationStack` は `embedInNavigationStack` で任意）。
    private var noteDetailScaffold: some View {
        Group {
                if isEditing {
                    // 編集モード: タイトル入力 + 本文編集。
                    VStack(alignment: .leading, spacing: 12) {
                        titleEditor

                        // 編集モード中のみ、未保存変更の状態を補助テキストで表示する。
                        if hasUnsavedChanges {
                            Text("Unsaved changes")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }

                        MarkdownTextView(
                            text: $loadedBody,
                            insertionText: $toolbarInsertionText,
                            isFocused: $isEditorFocusedState
                        )
                        .onChange(of: loadedBody) { _, _ in
                            // 本文が変化したら未保存フラグを立てる。
                            hasUnsavedChanges = true
                            scheduleAutosave()
                        }
                    }
                    .padding(.horizontal, 8)
                } else {
                    // プレビューモード: タイトル入力 + Markdown 表示 + 日時表示。
                    ScrollView {
                        VStack(alignment: .leading, spacing: 12) {
                            titleEditor

                            // marked.js + WKWebView で GFM プレビュー（wiki は Swift 側で nodus リンク化済み）。
                            MarkdownWebView(
                                markdown: markdownSourceForWebPreview,
                                onLinkTapped: { id in
                                    if let resolved = LinkResolver.resolve(id, in: store.notes) {
                                        linkedNoteForNavigation = resolved
                                        isNavigatingToLinkedNote = true
                                    }
                                },
                                onContentHeightChange: { markdownPreviewWebHeight = max($0, 44) }
                            )
                            .frame(height: markdownPreviewWebHeight)
                            .frame(maxWidth: .infinity, alignment: .leading)

                            // プレビュー時のみ、本文の下に作成/更新日時を表示する。
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Created  \(DateFormatter.noteDisplayTimestamp.string(from: currentNote.createdAt))")
                                Text("Updated  \(DateFormatter.noteDisplayTimestamp.string(from: currentNote.updatedAt))")
                            }
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        }
                        .padding()
                    }
                }
            }
            // 外側に `NavigationStack` が無い（iPad 詳細列）ときは `embedInNavigationStack` で包む。
            // 非表示 `NavigationLink` で wiki 先へプッシュする。
            .background {
                NavigationLink(
                    destination: wikiLinkNavigationDestination,
                    isActive: $isNavigatingToLinkedNote
                ) {
                    EmptyView()
                }
                .accessibilityHidden(true)
                .frame(width: 0, height: 0)
            }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    // 右上（右端側）: Edit / Preview 切替。
                    Button(isEditing ? "Preview" : "Edit") {
                        toggleEditPreviewMode()
                    }
                    // VoiceOver: 現在モードに応じて次に入るモードを説明する。
                    .accessibilityLabel(isEditing ? "Switch to preview mode" : "Switch to edit mode")
                    // iPad 外付けキーボード: ⌘E で編集／プレビュー切替（ボタンと同じ処理）。
                    .keyboardShortcut("e", modifiers: .command)
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        isSharePresented = true
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .accessibilityLabel("Share")
                    .sheet(isPresented: $isSharePresented) {
                        if let url = makeShareFileURL() {
                            ShareSheet(url: url)
                        }
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button {
                            UIPasteboard.general.string = "[[\(currentNote.timestampID)]]"
                        } label: {
                            Label("Copy Wiki Link", systemImage: "link")
                        }
                        Button {
                            NotificationCenter.default.post(name: .nodusPopToRoot, object: nil)
                        } label: {
                            Label("Back to List", systemImage: "list.bullet")
                        }
                        Button {
                            NotificationCenter.default.post(name: .nodusActivateSearch, object: nil)
                        } label: {
                            Label("Search Notes", systemImage: "magnifyingglass")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                    .accessibilityLabel("More options")
                }
            }
        .task(id: currentNote.id) {
            hasExternalChange = false

            // DEBUG シミュレータのダミーデータは body を直接持つため、まずそちらを優先する。
            if !currentNote.body.isEmpty {
                // DEBUG シミュレータのダミーデータは body を直接持つため優先する。
                loadedBody = currentNote.body
            } else {
                // UIDocument を await で開いてから body を読む。
                // 同期版 loadBody では open() 完了前にキャッシュなしフォールバックが走り
                // 空文字になることがあるため、非同期版を使う。
                loadedBody = await store.loadBodyAsync(for: currentNote)
            }
            editingTitle = currentNote.title

            // 新規作成（タイトル空）の直後は、タイトル入力へ自動フォーカスする。
            if currentNote.title.isEmpty {
                isTitleFocused = true
            }

            // ノート切替時は WKWebView の高さを初期化し、前ノートのレイアウト残りを避ける。
            markdownPreviewWebHeight = 200
        }
        // 一覧がメタデータ更新などで差し替わったとき、プレビュー表示用の本文を最新ファイルに追従させる（編集中は触らない）。
        .onChange(of: store.notes) { _, newNotes in
            // 編集モード中は外部変更を反映しない（v1.0 の方針。`loadedBody` を勝手に差し替えない）。
            guard !isEditing else { return }

            // 現在開いているノートと同一 ID の、ストア上の最新行を取る。
            guard let latest = newNotes.first(where: { $0.id == currentNote.id }) else { return }

            // ディスク側の更新時刻が進んでいれば、タスク初回ロード以降に溜まった古い `loadedBody` を捨てて再読込する。
            if latest.updatedAt > currentNote.updatedAt {
                currentNote = latest
                // UIDocumentのキャッシュを優先する。キャッシュがなければファイルから読む。
                let newBody = store.cachedBody(for: latest) ?? store.loadBody(for: latest)
                loadedBody = newBody
            }
        }
        // メタデータ経由で `loadNotes()` が走ったタイミングを Combine で購読する。
        // `onChange(of: store.lastExternalUpdateDate)` は `NavigationStack` 内で発火しないことがあるため、
        // `@Published` の `Publisher`（`$lastExternalUpdateDate`）へ直接 `onReceive` する。
        .onReceive(store.$lastExternalUpdateDate) { date in
            // 初期値 `.distantPast` のままの通知は無視する（初回購読時のノイズ対策）。
            guard date > .distantPast else { return }
            if isEditing {
            } else {
                // プレビュー中はファイルから本文を取り直し、一覧側のメタデータと表示を揃える。
                let body = store.cachedBody(for: currentNote) ?? store.loadBody(for: currentNote)
                if !body.isEmpty, body != loadedBody {
                    loadedBody = body
                    currentNote = store.notes.first(where: { $0.id == currentNote.id }) ?? currentNote
                }
            }
        }
        .onDisappear {
            // 画面離脱時はタイトル確定を先に行い、外部更新が無いときだけ本文を保存する。
            autosaveWorkItem?.cancel()
            commitTitle()
            // 未保存変更がない場合は保存をスキップする。
            // 内容が変わっていないのに saveNote() を呼ぶと
            // updatedAt が更新されてソート順が変わるため。
            guard hasUnsavedChanges else { return }
            // UIDocument がキャッシュしている最新 body と loadedBody を比較する。
            // 外部エディタが編集した内容が UIDocument に反映済みで、
            // かつ loadedBody と異なる場合は外部変更を優先してスキップする。
            if let cachedBody = store.cachedBody(for: currentNote),
               !cachedBody.isEmpty,
               cachedBody != loadedBody {
                return
            }
            saveImmediately()
        }
        .environment(\.openURL, OpenURLAction { url in
            // プレビュー内リンクのタップを捕捉し、`nodus://` だけ独自遷移に変換する。
            guard url.scheme == "nodus" else { return .systemAction }
            let id = url.host ?? url.lastPathComponent
            guard !id.isEmpty else { return .discarded }

            if let resolved = LinkResolver.resolve(id, in: store.notes) {
                linkedNoteForNavigation = resolved
                isNavigatingToLinkedNote = true
                return .handled
            } else {
                // 解決できない ID は遷移させない。
                return .discarded
            }
        })
        .onChange(of: isEditing) { _, newValue in
            // モード切替後の入力体験を安定させるため、編集モードに戻ったらフォーカスを戻す。
            isEditorFocusedState = newValue
        }
        .onChange(of: isTitleFocused) { _, focused in
            // タイトルをタップしたら編集モードへ入り、離脱時はタイトル確定を行う。
            if focused {
                // 新規作成時の自動フォーカス（isTitleFocused = true）では
                // 編集モードへの強制切替を行わない。
                // ユーザーが意図的にタイトルをタップしたときだけ編集モードにする。
                // 新規作成時は currentNote.title.isEmpty のため、
                // プレビューモードでタイトル欄をタップした場合のみ isEditing = true にする。
                if !isEditing {
                    // プレビュー中にタイトルをタップした場合のみ編集モードへ切り替える。
                    // ただし新規作成の自動フォーカスは title が空なので除外する。
                    if !currentNote.title.isEmpty {
                        isEditing = true
                    }
                }
            } else {
                commitTitle()
            }
        }
        .onChange(of: isNavigatingToLinkedNote) { _, isActive in
            // リンク先から戻ったら宛先をクリアし、次のタップで同じノートへ飛べるようにする。
            if !isActive {
                linkedNoteForNavigation = nil
            }
        }
    }

    /// wiki `NavigationLink` の遷移先（アクティブ時のみ `linkedNoteForNavigation` が入る）。
    @ViewBuilder
    private var wikiLinkNavigationDestination: some View {
        if let linkedNoteForNavigation {
            NoteDetailView(note: linkedNoteForNavigation, embedInNavigationStack: false)
        } else {
            EmptyView()
        }
    }

    /// 現在の本文を反映した保存用 Note を作る。
    private var noteForSave: Note {
        var editable = currentNote
        editable.body = loadedBody
        return editable
    }

    /// 2 秒デバウンスで自動保存を予約する。
    private func scheduleAutosave() {
        autosaveWorkItem?.cancel()
        let workItem = DispatchWorkItem {
            saveImmediately()
        }
        autosaveWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 2, execute: workItem)
    }

    /// 直ちに保存し、保留中の保存タスクをクリアする。
    private func saveImmediately() {
        autosaveWorkItem?.cancel()
        autosaveWorkItem = nil
        store.saveNote(noteForSave)
        refreshCurrentNoteFromStore()
        // 保存処理が完了したため、未保存フラグを下ろす。
        hasUnsavedChanges = false
    }

    /// 共有用の一時 .md ファイルを作成してURLを返す。
    /// ファイル名はノートのファイル名（例: 202604110833 タイトル.md）と同じにする。
    private func makeShareFileURL() -> URL? {
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(currentNote.filename)
        do {
            try loadedBody.write(to: tempURL, atomically: true, encoding: .utf8)
            return tempURL
        } catch {
            print("❌ makeShareFileURL error: \(error)")
            return nil
        }
    }

    /// キーボードツールバーの入力を本文末尾へ追加する（案A）。
    private func appendToEditor(_ text: String) {
        // カーソル位置への挿入を MarkdownTextView に委譲する
        toolbarInsertionText = text
        isEditorFocusedState = true
    }

    /// ツールバーおよび ⌘E と共通の、編集／プレビュー切替処理。
    private func toggleEditPreviewMode() {
        if isEditing {
            // 1. まず外部変更があれば loadedBody を最新に更新する
            let latest = store.cachedBody(for: currentNote) ?? store.loadBody(for: currentNote)
            if !latest.isEmpty, latest != loadedBody {
                loadedBody = latest
            }
            // 2. 最新の loadedBody で保存する
            saveImmediately()
        }
        isEditing.toggle()
    }

    /// 画面上部で常に表示するタイトル編集フィールド。
    private var titleEditor: some View {
        TextField("Untitled", text: $editingTitle)
            .font(.headline)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .submitLabel(.done)
            .focused($isTitleFocused)
            .onChange(of: editingTitle) { _, _ in
                // タイトルが変化したら未保存フラグを立てる。
                hasUnsavedChanges = true
            }
            .onSubmit {
                commitTitle()
            }
    }

    /// タイトル変更を NoteStore に反映し、成功時はローカル状態も更新する。
    private func commitTitle() {
        let normalizedInput = editingTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedCurrent = currentNote.title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard normalizedInput != normalizedCurrent else { return }

        guard let renamed = store.renameNote(noteForSave, newTitle: editingTitle) else {
            // 失敗時は現在のタイトル表示へ戻し、UIと実体の差分を解消する。
            editingTitle = currentNote.title
            return
        }

        currentNote = renamed
        editingTitle = renamed.title
        // タイトル変更のコミットが完了したため、未保存フラグを下ろす。
        hasUnsavedChanges = false
    }

    /// 保存やリネーム後に、一覧側の最新メタデータを取り直して表示の一貫性を保つ。
    private func refreshCurrentNoteFromStore() {
        guard let latest = store.notes.first(where: { $0.id == currentNote.id }) else { return }
        // currentNote を丸ごと差し替えると .task(id:) が再起動するため、
        // url と updatedAt だけを部分更新して @State の安定性を保つ。
        if currentNote.url != latest.url {
            currentNote.url = latest.url
        }
        if currentNote.updatedAt != latest.updatedAt {
            currentNote.updatedAt = latest.updatedAt
        }
    }

    /// 解決済み wiki を nodus リンク化し、未解決は Web 用 span でグレー表示する Markdown 文字列。
    private var markdownSourceForWebPreview: String {
        let withLinks = replacingResolvedWikiLinksWithMarkdownLinks(in: loadedBody)
        return wrappingUnresolvedWikiLinksInHTMLSpans(in: withLinks)
    }

    /// 残存する `[[ID]]`（未解決のみ）を CSS クラス付き span で包み、marked の HTML パススルーで色を付ける。
    private func wrappingUnresolvedWikiLinksInHTMLSpans(in body: String) -> String {
        let pattern = /\[\[.+?\]\]/
        var result = ""
        var cursor = body.startIndex

        for match in body.matches(of: pattern) {
            let range = match.range
            let full = String(match.0)
            result += String(body[cursor..<range.lowerBound])
            result += "<span class=\"nodus-wiki-unresolved\">\(full)</span>"
            cursor = range.upperBound
        }

        result += String(body[cursor...])
        return result
    }

    /// `[[ID]]` を走査し、解決済みのみ `[ID](nodus://ID)` へ置換する。
    private func replacingResolvedWikiLinksWithMarkdownLinks(in body: String) -> String {
        let pattern = /\[\[(.+?)\]\]/
        var result = ""
        var cursor = body.startIndex

        for match in body.matches(of: pattern) {
            let range = match.range
            let id = String(match.1)

            // マッチ開始までの通常テキストを先に連結する。
            result += String(body[cursor..<range.lowerBound])

            if LinkResolver.resolve(id, in: store.notes) != nil {
                // 解決できる ID だけをタップ可能リンクへ変換する。
                result += "[\(id)](nodus://\(id))"
            } else {
                // 未解決 ID は元の `[[...]]` を残す（後でグレー着色）。
                result += String(match.0)
            }

            cursor = range.upperBound
        }

        // 末尾に残った通常テキストを追加する。
        result += String(body[cursor...])
        return result
    }

    /// UIActivityViewController を SwiftUI から使うためのラッパー。
    private struct ShareSheet: UIViewControllerRepresentable {
        let url: URL

        func makeUIViewController(context: Context) -> UIActivityViewController {
            UIActivityViewController(
                activityItems: [url],
                applicationActivities: nil
            )
        }

        func updateUIViewController(
            _ uiViewController: UIActivityViewController,
            context: Context
        ) {}
    }
}

extension Notification.Name {
    static let nodusPopToRoot = Notification.Name("nodusPopToRoot")
    static let nodusActivateSearch = Notification.Name("nodusActivateSearch")
}
