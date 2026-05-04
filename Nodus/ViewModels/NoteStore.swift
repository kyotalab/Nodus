//
//  NoteStore.swift
//  Nodus
//
//  PHASE 3 STEP 4: iCloud Drive 上の .md ファイルを一覧・作成・保存・削除する
//

import Combine
import Foundation

/// ノート一覧の状態を保持し、ビューから `@EnvironmentObject` で参照する。
@MainActor
final class NoteStore: ObservableObject {
    /// 表示中のノート一覧。本文は遅延ロードのため初期値は空文字で保持する。
    @Published private(set) var notes: [Note] = []

    /// security-scoped bookmark へのアクセス窓口。
    private var folderBookmark: FolderBookmark?

    init() {}

    /// `NodusApp` 側で `FolderBookmark` を注入する。URL が既にある場合は即ロードする。
    func configure(folderBookmark: FolderBookmark) {
        self.folderBookmark = folderBookmark
        if folderBookmark.hasSelectedFolder {
            loadNotes()
        } else {
            notes = []
        }
    }

    /// 指定フォルダ内の `.md` ファイル一覧を読み込み、`notes` を更新する。
    /// 本文はまだ読まず、`body` は空文字で初期化する（遅延ロード）。
    func loadNotes() {
        guard let folderBookmark else {
            print("⚠️ NoteStore.loadNotes: FolderBookmark is not configured.")
            notes = []
            return
        }

        do {
            let loadedNotes = try folderBookmark.withScopedAccess { folderURL in
                let fileManager = FileManager.default
                // iOS では作成日時は creationDateKey（NSURLCreationDateKey）。contentCreationDateKey は利用できない。
                let keys: [URLResourceKey] = [
                    .isRegularFileKey,
                    .creationDateKey,
                    .contentModificationDateKey,
                ]

                let urls = try fileManager.contentsOfDirectory(
                    at: folderURL,
                    includingPropertiesForKeys: keys,
                    options: [.skipsHiddenFiles]
                )

                let mdURLs = urls.filter { $0.pathExtension.lowercased() == "md" }
                let mapped: [Note] = mdURLs.map { url in
                    let values = try? url.resourceValues(forKeys: Set(keys))
                    // 更新日時は常に contentModificationDate を使う。
                    let updatedAt = values?.contentModificationDate ?? Date()
                    // 作成日時は creationDate。ボリュームが未対応で nil のときは更新日時で代替する。
                    let createdAt = values?.creationDate ?? updatedAt
                    return Note(
                        url: url,
                        body: "",
                        createdAt: createdAt,
                        updatedAt: updatedAt
                    )
                }
                // 新しい順で表示するため更新日時の降順で揃える。
                return mapped.sorted { $0.updatedAt > $1.updatedAt }
            }
            notes = loadedNotes
        } catch {
            print("❌ NoteStore.loadNotes failed: \(error.localizedDescription)")
            notes = []
        }
    }

    /// 現在時刻ベースの `YYYYMMDDHHmm.md` を作成し、一覧の先頭へ追加する。
    @discardableResult
    func createNote() -> Note? {
        guard let folderBookmark else {
            print("⚠️ NoteStore.createNote: FolderBookmark is not configured.")
            return nil
        }

        do {
            let note = try folderBookmark.withScopedAccess { folderURL in
                let now = Date()
                let stamp = DateFormatter.noteTimestamp.string(from: now)
                let filename = "\(stamp).md"
                let fileURL = folderURL.appendingPathComponent(filename)

                // 空ファイルを UTF-8 の空文字として作成する。
                try "".write(to: fileURL, atomically: true, encoding: .utf8)

                return Note(
                    url: fileURL,
                    body: "",
                    createdAt: now,
                    updatedAt: now
                )
            }
            notes.insert(note, at: 0)
            return note
        } catch {
            print("❌ NoteStore.createNote failed: \(error.localizedDescription)")
            return nil
        }
    }

    /// ノート本文をファイルへ保存し、`updatedAt` を現在時刻に更新する。
    func saveNote(_ note: Note) {
        guard let folderBookmark else {
            print("⚠️ NoteStore.saveNote: FolderBookmark is not configured.")
            return
        }

        do {
            let now = Date()
            try folderBookmark.withScopedAccess { _ in
                try note.body.write(to: note.url, atomically: true, encoding: .utf8)
            }

            if let index = notes.firstIndex(where: { $0.url == note.url }) {
                var updated = notes[index]
                updated.body = note.body
                updated.updatedAt = now
                notes[index] = updated
            }
        } catch {
            print("❌ NoteStore.saveNote failed: \(error.localizedDescription)")
        }
    }

    /// ノートのファイルを削除し、一覧からも取り除く。
    func deleteNote(_ note: Note) {
        guard let folderBookmark else {
            print("⚠️ NoteStore.deleteNote: FolderBookmark is not configured.")
            return
        }

        do {
            try folderBookmark.withScopedAccess { _ in
                try FileManager.default.removeItem(at: note.url)
            }
            notes.removeAll { $0.url == note.url }
        } catch {
            print("❌ NoteStore.deleteNote failed: \(error.localizedDescription)")
        }
    }

    /// 詳細表示時に本文を都度読み込む（遅延ロード）。
    func loadBody(for note: Note) -> String {
        guard let folderBookmark else {
            print("⚠️ NoteStore.loadBody: FolderBookmark is not configured.")
            return ""
        }

        do {
            return try folderBookmark.withScopedAccess { _ in
                try String(contentsOf: note.url, encoding: .utf8)
            }
        } catch {
            print("❌ NoteStore.loadBody failed: \(error.localizedDescription)")
            return ""
        }
    }
}
