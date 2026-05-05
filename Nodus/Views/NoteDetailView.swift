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
        if let attributed = try? AttributedString(markdown: loadedBody) {
            return attributed
        }
        return AttributedString(loadedBody)
    }
}
