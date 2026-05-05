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
    let note: Note
    /// 編集中の本文。初期表示時にノート本文またはファイルから読み込んでセットする。
    @State private var loadedBody = ""
    /// 編集モード/プレビューモードの切替状態。現時点では編集モード固定開始。
    @State private var isEditing: Bool = true
    /// 本文変更時の自動保存を 2 秒遅延させるためのワークアイテム。
    @State private var autosaveWorkItem: DispatchWorkItem?
    /// キーボードツールバー表示のため、TextEditor のフォーカス状態を保持する。
    @FocusState private var isEditorFocused: Bool
    /// プレビュー内の wiki リンクタップで遷移するための宛先ノート。
    @State private var linkedNoteForNavigation: Note?

    var body: some View {
        Group {
            if isEditing {
                // 編集モード: TextEditor でプレーンテキストを編集する。
                TextEditor(text: $loadedBody)
                    .font(.system(.body, design: .monospaced))
                    .padding(.horizontal, 8)
                    .focused($isEditorFocused)
                    .onChange(of: loadedBody) { _, _ in
                        scheduleAutosave()
                    }
            } else {
                // プレビューモード: Markdown を AttributedString で描画する。
                ScrollView {
                    Text(markdownPreviewText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                }
            }
        }
        .navigationTitle(note.displayName)
        .navigationDestination(item: $linkedNoteForNavigation) { linkedNote in
            // wiki リンクタップ時は同じ詳細画面をさらに積んで遷移する。
            NoteDetailView(note: linkedNote)
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                // 右上ボタンで Edit / Preview を切り替える。
                Button(isEditing ? "Preview" : "Edit") {
                    if isEditing {
                        // 編集からプレビューへ移るときは未保存内容を即時保存する。
                        saveImmediately()
                    }
                    isEditing.toggle()
                }
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
        .task(id: note.url) {
            // DEBUG シミュレータのダミーデータは body を直接持つため、まずそちらを優先する。
            if !note.body.isEmpty {
                loadedBody = note.body
            } else {
                // 実ファイル運用時は従来どおり遅延ロードする。
                loadedBody = store.loadBody(for: note)
            }
        }
        .onDisappear {
            // 画面離脱時に保留中の保存タスクを破棄し、内容は即時保存する。
            autosaveWorkItem?.cancel()
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
    }

    /// 現在の本文を反映した保存用 Note を作る。
    private var noteForSave: Note {
        var editable = note
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
    }

    /// キーボードツールバーの入力を本文末尾へ追加する（案A）。
    private func appendToEditor(_ text: String) {
        loadedBody += text
        isEditorFocused = true
    }

    /// Markdown を描画用文字列へ変換する（失敗時は生テキスト表示）。
    private var markdownPreviewText: AttributedString {
        // STEP 1: 解決済み `[[ID]]` を一時的な markdown リンクへ変換する。
        let transformed = replacingResolvedWikiLinksWithMarkdownLinks(in: loadedBody)

        // STEP 2: markdown としてレンダリングする。
        var attributed = (try? AttributedString(markdown: transformed)) ?? AttributedString(transformed)

        // 未解決 `[[ID]]` はグレーで表示し、解決済みリンクとの差を明示する。
        applyUnresolvedWikiLinkStyle(to: &attributed)
        return attributed
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

    /// 未解決 wiki リンク表記 `[[...]]` の文字色をシステムグレーにする。
    private func applyUnresolvedWikiLinkStyle(to attributed: inout AttributedString) {
        let source = String(attributed.characters)
        let pattern = /\[\[(.+?)\]\]/

        for match in source.matches(of: pattern) {
            let id = String(match.1)
            guard LinkResolver.resolve(id, in: store.notes) == nil else { continue }

            guard
                let lower = AttributedString.Index(match.range.lowerBound, within: attributed),
                let upper = AttributedString.Index(match.range.upperBound, within: attributed)
            else { continue }

            attributed[lower..<upper].foregroundColor = .gray
        }
    }
}
