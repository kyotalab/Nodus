//
//  NoteStore.swift
//  Nodus
//
//  PHASE 3: ノート一覧の状態管理。STEP 3時点では仮URL使用、STEP 4でiCloud Drive対応予定。
//

import Combine
import Foundation

/// ノート一覧の状態を保持し、ビューから `@EnvironmentObject` や `@ObservedObject` で参照する。
@MainActor
final class NoteStore: ObservableObject {
    /// 画面上に表示する全ノート。変更すると購読しているビューが再描画される。
    @Published var notes: [Note]

    /// 初期表示用のダミーデータを入れたストアを作る。
    /// - Parameter notes: 省略時はダミー一覧。`nil` 以外を渡すとテスト等で差し替え可能。
    /// - Note: デフォルト引数に `makeDummyNotes()` を書かない（呼び出し側の非分離コンテキストで評価されエラーになるため）。
    init(notes: [Note]? = nil) {
        self.notes = notes ?? Self.makeDummyNotes()
    }

    /// 現在時刻をファイル名の先頭 ID に使い、本文空の新規ノートを一覧の先頭に追加して返す。
    /// （仕様どおり、作成直後はタイムスタンプのみのファイル名）
    @discardableResult
    func createNote() -> Note {
        let now = Date()
        let stamp = Self.filenameTimestamp(from: now)
        let filename = "\(stamp).md"
        let note = Note(
            // PHASE 3 STEP 3 時点では、実ファイル I/O 未実装のため仮 URL を使う。
            url: Self.dummyFileURL(filename: filename),
            body: "",
            createdAt: now,
            updatedAt: now
        )
        notes.insert(note, at: 0)
        return note
    }

    /// ID が一致するノートを一覧から取り除く（存在しなければ何もしない）。
    func deleteNote(_ note: Note) {
        notes.removeAll { $0.id == note.id }
    }

    // MARK: - ダミーデータ

    /// PHASE 2 用: 実在しうる過去のタイムスタンプと、Markdown を含む本文で 6 件分を返す（英語、Nodus 向けサンプル）。
    private static func makeDummyNotes() -> [Note] {
        [
            Note(
                url: dummyFileURL(filename: "202402101430.md"),
                body: """
                # Scratch note

                Draft with **no title** in the filename yet. Try a wiki link to [[202403220915]] and another to [[202409301845]].
                """,
                createdAt: dateFromFilenamePrefix("202402101430"),
                updatedAt: dateFromFilenamePrefix("202402101430")
            ),
            Note(
                url: dummyFileURL(filename: "202403220915 SwiftUI and Compose.md"),
                body: """
                ## Comparison

                - **SwiftUI**: declarative UI on Apple platforms
                - **Jetpack Compose**: declarative UI on Android

                > Both are state-driven and easy to compose.

                See also [[202402101430]] for a scratch link target.
                """,
                createdAt: dateFromFilenamePrefix("202403220915"),
                updatedAt: dateFromFilenamePrefix("202404011200")
            ),
            Note(
                url: dummyFileURL(filename: "202406011200.md"),
                body: """
                Short note mixing *italic*, inline `code`, and `[[202501051030]]` for link resolution tests.
                """,
                createdAt: dateFromFilenamePrefix("202406011200"),
                updatedAt: dateFromFilenamePrefix("202406011200")
            ),
            Note(
                url: dummyFileURL(filename: "202409301845 Links and graph.md"),
                body: """
                # Linking notes

                Connect notes with wiki links like `[[202402101430]]` or `[[202403220915 SwiftUI and Compose]]` so **search** and navigation stay useful after renames.

                > Partial IDs match filenames — good for Zettelkasten-style graphs.
                """,
                createdAt: dateFromFilenamePrefix("202409301845"),
                updatedAt: dateFromFilenamePrefix("202410051030")
            ),
            Note(
                url: dummyFileURL(filename: "202501051030 Daily log.md"),
                body: """
                - Groceries
                - Read for *30 minutes*

                ```swift
                struct Note: Identifiable {
                    let id: String
                }
                ```

                Backlink: [[202406011200]]
                """,
                createdAt: dateFromFilenamePrefix("202501051030"),
                updatedAt: dateFromFilenamePrefix("202501051030")
            ),
            Note(
                url: dummyFileURL(filename: "202503151845.md"),
                body: """
                Timestamp-only filename (`202503151845.md`). Body can still use **Markdown** and `[[202409301845]]` to exercise previews and link styling.
                """,
                createdAt: dateFromFilenamePrefix("202503151845"),
                updatedAt: dateFromFilenamePrefix("202503201200")
            ),
        ]
    }

    /// ファイル名の先頭 12 桁 `yyyyMMddHHmm` を `Date` に変換する（失敗時は現在時刻）。
    private static func dateFromFilenamePrefix(_ prefix12: String) -> Date {
        let key = String(prefix12.prefix(12))
        return DateFormatter.noteTimestamp.date(from: key) ?? Date()
    }

    /// 任意の日時を、ノートファイル名用の 12 桁タイムスタンプ文字列にする。
    private static func filenameTimestamp(from date: Date) -> String {
        DateFormatter.noteTimestamp.string(from: date)
    }

    /// PHASE 3 STEP 3 用: 実ファイル I/O 前のため、`/tmp` 配下の仮 URL を返す。
    private static func dummyFileURL(filename: String) -> URL {
        URL(fileURLWithPath: "/tmp").appendingPathComponent(filename)
    }
}
