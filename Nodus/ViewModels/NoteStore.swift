//
//  NoteStore.swift
//  Nodus
//
//  PHASE 3 STEP 4–5: iCloud Drive 上の .md の CRUD と、NSMetadataQuery による外部変更検知
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

    // MARK: - iCloud メタデータ監視（外部エディタの変更検知）

    /// 選択フォルダ配下の `.md` のメタデータ変化を追うクエリ。メインスレッドで操作する。
    private var metadataQuery: NSMetadataQuery?

    /// メタデータ通知のオブザーバをまとめて解除するため保持する。
    private var metadataQueryObservers: [NSObjectProtocol] = []

    /// 監視中に security-scoped アクセスを維持するためのフォルダ URL。
    private var monitoringScopedFolderURL: URL?

    /// `startAccessingSecurityScopedResource` が成功したか（対になる stop が必要）。
    private var didStartSecurityScopedAccessForMonitoring = false

    /// 通知が短時間に連続するのをまとめるデバウンス用ワークアイテム。
    private var metadataReloadDebounceWorkItem: DispatchWorkItem?

    /// メタデータ更新後の `loadNotes()` までの待ち時間（秒）。
    private let metadataReloadDebounceInterval: TimeInterval = 0.5

    init() {}

    /// `NodusApp` 側で `FolderBookmark` を注入する。URL が既にある場合は即ロードする。
    func configure(folderBookmark: FolderBookmark) {
        // フォルダが変わるたびに古い監視を止め、新しい bookmark に合わせる。
        stopMonitoring()
        self.folderBookmark = folderBookmark
        if folderBookmark.hasSelectedFolder {
            loadNotes()
            // 既に foreground のときは scenePhase の onChange が来ないことがあるため、フォルダ確定直後も監視を開始する。
            startMonitoring()
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

    // MARK: - メタデータ監視（STEP 5）

    /// `NSMetadataQuery` を開始し、選択フォルダ配下の `.md` の変化を監視する（メインスレッド専用）。
    func startMonitoring() {
        guard let folderBookmark, folderBookmark.hasSelectedFolder, let folderURL = folderBookmark.selectedFolderURL else {
            stopMonitoring()
            return
        }

        // 既に同じフォルダで動いていれば何もしない（二重開始を防ぐ）。
        if let query = metadataQuery, query.isStarted, monitoringScopedFolderURL == folderURL {
            return
        }

        stopMonitoring()

        // メタデータクエリは対象ディレクトリへの継続アクセスが必要なことがあるため、監視中だけ scope を張る。
        didStartSecurityScopedAccessForMonitoring = folderURL.startAccessingSecurityScopedResource()
        monitoringScopedFolderURL = folderURL

        let query = NSMetadataQuery()
        // ユーザーが選んだフォルダ（とそのサブフォルダ）だけを検索範囲にする。
        query.searchScopes = [folderURL as NSURL]
        // ファイル名が `.md` で終わるものに限定する。
        query.predicate = NSPredicate(format: "%K ENDSWITH[c] '.md'", NSMetadataItemFSNameKey)

        let center = NotificationCenter.default
        let queue = OperationQueue.main

        // 初回の結果収集が終わったタイミングでも一覧を同期する。
        let finishObserver = center.addObserver(
            forName: .NSMetadataQueryDidFinishGathering,
            object: query,
            queue: queue
        ) { [weak self] _ in
            self?.handleMetadataUpdate()
        }
        metadataQueryObservers.append(finishObserver)

        // 以降の iCloud 側の更新（外部アプリによる変更など）を拾う。
        let updateObserver = center.addObserver(
            forName: .NSMetadataQueryDidUpdate,
            object: query,
            queue: queue
        ) { [weak self] _ in
            self?.handleMetadataUpdate()
        }
        metadataQueryObservers.append(updateObserver)

        metadataQuery = query
        query.start()
    }

    /// メタデータ監視を停止し、リソースアクセスも解放する。
    func stopMonitoring() {
        metadataReloadDebounceWorkItem?.cancel()
        metadataReloadDebounceWorkItem = nil

        if let query = metadataQuery {
            for observer in metadataQueryObservers {
                NotificationCenter.default.removeObserver(observer)
            }
            metadataQueryObservers.removeAll()
            query.stop()
        }
        metadataQuery = nil

        if didStartSecurityScopedAccessForMonitoring, let url = monitoringScopedFolderURL {
            url.stopAccessingSecurityScopedResource()
        }
        didStartSecurityScopedAccessForMonitoring = false
        monitoringScopedFolderURL = nil
    }

    /// メタデータの変化を受け取り、デバウンスしたうえで一覧を再読込する。
    /// STEP 5 では編集モード保留は行わず、常に `loadNotes()` で同期する（編集時の保留は PHASE 4）。
    func handleMetadataUpdate() {
        metadataReloadDebounceWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.loadNotes()
        }
        metadataReloadDebounceWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + metadataReloadDebounceInterval, execute: work)
    }
}
