//
//  NoteDetailView.swift
//  Nodus
//
//  PHASE 2: 詳細ペインのプレースホルダー（エディタは後続フェーズ）
//

import SwiftUI

/// 1件のノートの詳細。PHASE 4 では編集/プレビュー切替と自動保存を担う。
struct NoteDetailView: View {
    @EnvironmentObject private var store: NoteStore
    /// Settings で選んだ初期エディタモード（edit / preview）を参照する。
    @AppStorage("defaultEditorMode") private var defaultEditorMode = "edit"
    let note: Note
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
    /// プレビュー内の wiki リンクタップで遷移するための宛先ノート。
    @State private var linkedNoteForNavigation: Note?
    /// 画面初期表示時にだけ defaultEditorMode を適用するためのフラグ。
    @State private var hasAppliedDefaultMode = false
    /// WKWebView プレビューの内容高さ（外側の ScrollView と二重スクロールを避ける）。
    @State private var markdownPreviewWebHeight: CGFloat = 200

    init(note: Note) {
        self.note = note
        _currentNote = State(initialValue: note)
        _editingTitle = State(initialValue: note.title)
    }

    var body: some View {
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

                    TextEditor(text: $loadedBody)
                        .font(.system(.body, design: .monospaced))
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .focused($isEditorFocused)
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
        .navigationDestination(item: $linkedNoteForNavigation) { linkedNote in
            // wiki リンクタップ時は同じ詳細画面をさらに積んで遷移する。
            NoteDetailView(note: linkedNote)
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                // 右上（右端側）: Edit / Preview 切替。
                Button(isEditing ? "Preview" : "Edit") {
                    toggleEditPreviewMode()
                }
                // iPad 外付けキーボード: ⌘E で編集／プレビュー切替（ボタンと同じ処理）。
                .keyboardShortcut("e", modifiers: .command)
            }
            ToolbarItem(placement: .primaryAction) {
                // 共有ボタンは Edit の左隣（primaryAction では後から宣言したほうが中央寄り）に配置する。
                ShareLink(
                    item: loadedBody,
                    subject: Text(editingTitle.isEmpty ? currentNote.timestampID : editingTitle),
                    message: Text(editingTitle.isEmpty ? "" : editingTitle)
                ) {
                    Image(systemName: "square.and.arrow.up")
                }
                .accessibilityLabel("Share")
            }
            if isEditing {
                ToolbarItemGroup(placement: .keyboard) {
                    // 案A: カーソル厳密制御は行わず、入力テキストを末尾に追加する。
                    Button("#") { appendToEditor("# ") }
                    Button("**") { appendToEditor("****") }
                    Button("*") { appendToEditor("**") }
                    Button(">") { appendToEditor("> ") }
                    Button("[[") { appendToEditor("[[]]") }
                    Button("⇥") { appendToEditor("\t") }
                    Spacer()
                }
            }
        }
        .task(id: currentNote.id) {
            // Settings の既定モードを初回表示時にだけ反映する。
            if !hasAppliedDefaultMode {
                isEditing = defaultEditorMode != "preview"
                hasAppliedDefaultMode = true
            }

            // DEBUG シミュレータのダミーデータは body を直接持つため、まずそちらを優先する。
            if !currentNote.body.isEmpty {
                loadedBody = currentNote.body
            } else {
                // 実ファイル運用時は従来どおり遅延ロードする。
                loadedBody = store.loadBody(for: currentNote)
            }
            editingTitle = currentNote.title

            // 新規作成（タイトル空）の直後は、タイトル入力へ自動フォーカスする。
            if currentNote.title.isEmpty {
                isTitleFocused = true
            }

            // ノート切替時は WKWebView の高さを初期化し、前ノートのレイアウト残りを避ける。
            markdownPreviewWebHeight = 200
        }
        .onDisappear {
            // 画面離脱時に保留中の保存タスクを破棄し、内容は即時保存する。
            autosaveWorkItem?.cancel()
            commitTitle()
            saveImmediately()
        }
        .environment(\.openURL, OpenURLAction { url in
            // プレビュー内リンクのタップを捕捉し、`nodus://` だけ独自遷移に変換する。
            guard url.scheme == "nodus" else { return .systemAction }
            let id = url.host ?? url.lastPathComponent
            guard !id.isEmpty else { return .discarded }

            if let resolved = LinkResolver.resolve(id, in: store.notes) {
                linkedNoteForNavigation = resolved
                return .handled
            } else {
                // 解決できない ID は遷移させない。
                return .discarded
            }
        })
        .onChange(of: isEditing) { _, newValue in
            // モード切替後の入力体験を安定させるため、編集モードに戻ったらフォーカスを戻す。
            isEditorFocused = newValue
        }
        .onChange(of: isTitleFocused) { _, focused in
            // タイトルをタップしたら編集モードへ入り、離脱時はタイトル確定を行う。
            if focused {
                isEditing = true
            } else {
                commitTitle()
            }
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

    /// キーボードツールバーの入力を本文末尾へ追加する（案A）。
    private func appendToEditor(_ text: String) {
        loadedBody += text
        isEditorFocused = true
    }

    /// ツールバーおよび ⌘E と共通の、編集／プレビュー切替処理。
    private func toggleEditPreviewMode() {
        if isEditing {
            // 編集からプレビューへ移るときは未保存内容を即時保存する。
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
        if let latest = store.notes.first(where: { $0.id == currentNote.id }) {
            currentNote = latest
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
}
