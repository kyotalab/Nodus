//
//  NoteStore.swift
//  Nodus
//
//  PHASE 2: メモリ上のノート一覧と CRUD の入口（ダミーデータ）
//

import Foundation
import SwiftUI

/// ノート一覧の状態を保持し、ビューから `@EnvironmentObject` や `@ObservedObject` で参照する。
@MainActor
final class NoteStore: ObservableObject {
    /// 画面上に表示する全ノート。変更すると購読しているビューが再描画される。
    @Published var notes: [Note]

    /// 初期表示用のダミーデータを入れたストアを作る。
    init(notes: [Note] = NoteStore.makeDummyNotes()) {
        self.notes = notes
    }

    /// 現在時刻をファイル名の先頭 ID に使い、本文空の新規ノートを一覧の先頭に追加して返す。
    /// （仕様どおり、作成直後はタイムスタンプのみのファイル名）
    @discardableResult
    func createNote() -> Note {
        let now = Date()
        let stamp = Self.filenameTimestamp(from: now)
        let filename = "\(stamp).md"
        let note = Note(
            id: UUID(),
            filename: filename,
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

    /// PHASE 2 用: 実在しうる過去のタイムスタンプと、Markdown を含む本文で 6 件分を返す。
    private static func makeDummyNotes() -> [Note] {
        [
            Note(
                id: UUID(),
                filename: "202402101430.md",
                body: """
                # 最初のメモ

                まだ **タイトル** を付けていない下書き。`[[202403220915]]` へのリンクを試す。
                """,
                createdAt: dateFromFilenamePrefix("202402101430"),
                updatedAt: dateFromFilenamePrefix("202402101430")
            ),
            Note(
                id: UUID(),
                filename: "202403220915 SwiftUIとCompose.md",
                body: """
                ## 比較

                - SwiftUI: 宣言的 UI
                - Jetpack Compose: 同様の思想

                > どちらも状態駆動で組み立てやすい。
                """,
                createdAt: dateFromFilenamePrefix("202403220915"),
                updatedAt: dateFromFilenamePrefix("202404011200")
            ),
            Note(
                id: UUID(),
                filename: "202406011200.md",
                body: """
                短いメモ。`code` や *斜体* も混ぜる。
                """,
                createdAt: dateFromFilenamePrefix("202406011200"),
                updatedAt: dateFromFilenamePrefix("202406011200")
            ),
            Note(
                id: UUID(),
                filename: "202409301845 リンクとグラフ.md",
                body: """
                # 知識のつながり

                ノート同士を `[[202402101430]]` のように繋ぐと、後から検索しやすい。
                """,
                createdAt: dateFromFilenamePrefix("202409301845"),
                updatedAt: dateFromFilenamePrefix("202410051030")
            ),
            Note(
                id: UUID(),
                filename: "202501051030 日々のメモ.md",
                body: """
                - 買い物
                - 読書 30 分

                ```swift
                let x = 1
                ```
                """,
                createdAt: dateFromFilenamePrefix("202501051030"),
                updatedAt: dateFromFilenamePrefix("202501051030")
            ),
            Note(
                id: UUID(),
                filename: "202503151845.md",
                body: """
                タイムスタンプだけのファイル名の例。本文だけ日本語で書いておく。
                """,
                createdAt: dateFromFilenamePrefix("202503151845"),
                updatedAt: dateFromFilenamePrefix("202503201200")
            ),
        ]
    }

    /// ファイル名の先頭 12 桁 `yyyyMMddHHmm` を `Date` に変換する（失敗時は現在時刻）。
    private static func dateFromFilenamePrefix(_ prefix12: String) -> Date {
        let key = String(prefix12.prefix(12))
        return stampFormatter.date(from: key) ?? Date()
    }

    /// 任意の日時を、ノートファイル名用の 12 桁タイムスタンプ文字列にする。
    private static func filenameTimestamp(from date: Date) -> String {
        stampFormatter.string(from: date)
    }

    /// パースと生成の両方に使う（ロケール固定で文字列がブレないようにする）。
    private static let stampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "Asia/Tokyo")
        formatter.dateFormat = "yyyyMMddHHmm"
        return formatter
    }()
}
