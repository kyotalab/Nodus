//
//  NoteStore.swift
//  Nodus
//
//  PHASE 3 STEP 4–5: iCloud Drive 上の .md の CRUD と、NSMetadataQuery による外部変更検知
//

import Combine
import Foundation
import UIKit

/// ノート一覧の状態を保持し、ビューから `@EnvironmentObject` で参照する。
@MainActor
final class NoteStore: ObservableObject {
    /// 表示中のノート一覧。本文は遅延ロードのため初期値は空文字で保持する。
    @Published private(set) var notes: [Note] = []

    /// メタデータ通知で一覧を取り直した時刻。詳細画面が「外部から一覧が動いた」と判断するための単純なシグナル。
    @Published private(set) var lastExternalUpdateDate: Date = .distantPast

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

    /// 現在開いているノートの UIDocument キャッシュ。
    /// ノートが切り替わるたびに close → open する。
    private var openDocument: NoteDocument?
    private var openDocumentURL: URL?
    private var openDocumentStateObserver: NSObjectProtocol?

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
#if DEBUG
#if targetEnvironment(simulator)
        // DEBUG シミュレータ専用: 実ファイル読み込みは行わず、メモリ上の notes をそのまま使う。
        // folderBookmark 未設定でも警告を出さず、そのまま return して状態を維持する。
        return
#endif
#endif

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
#if DEBUG
#if targetEnvironment(simulator)
        // DEBUG シミュレータ専用: folderBookmark が未設定でもメモリ上で新規ノートを作成する。
        let now = Date()
        let stamp = DateFormatter.noteTimestamp.string(from: now)
        let filename = "\(stamp).md"
        let note = Note(
            url: URL(fileURLWithPath: "/tmp/\(filename)"),
            body: "",
            createdAt: now,
            updatedAt: now
        )
        notes.insert(note, at: 0)
        return note
#endif
#endif

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
#if DEBUG
#if targetEnvironment(simulator)
        // DEBUG シミュレータ専用: ファイル保存を行わず、メモリ上の notes だけ更新する。
        if let index = notes.firstIndex(where: { $0.url == note.url }) {
            var updated = notes[index]
            updated.body = note.body
            updated.updatedAt = Date()
            notes[index] = updated
        }
        return
#endif
#endif

        Task {
            do {
                let doc = try await openDocument(for: note.url)
                doc.body = note.body
                // UIDocument の save が contents(forType:) を呼んでファイルに書く。
                try await doc.save(to: note.url, for: .forOverwriting)
                // store.notes の updatedAt を更新する。
                await MainActor.run {
                    if let index = notes.firstIndex(where: { $0.url == note.url }) {
                        var updated = notes[index]
                        updated.body = note.body
                        updated.updatedAt = Date()
                        notes[index] = updated
                    }
                }
            } catch {
                print("❌ saveNote error: \(error)")
            }
        }
    }

    /// ノートタイトルを変更し、タイムスタンプ ID を保持したままファイル名だけをリネームする。
    /// - Parameters:
    ///   - note: 変更対象ノート
    ///   - newTitle: 新しいタイトル（空の場合は ID のみファイル名）
    /// - Returns: 更新後の Note。失敗時は nil。
    @discardableResult
    func renameNote(_ note: Note, newTitle: String) -> Note? {
        // ファイル名として使えない文字は除去し、前後空白はトリムする。
        let sanitizedTitle = newTitle.replacingOccurrences(of: "/", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
        let newFilename = sanitizedTitle.isEmpty
            ? "\(note.timestampID).md"
            : "\(note.timestampID) \(sanitizedTitle).md"

#if DEBUG
#if targetEnvironment(simulator)
        // DEBUG シミュレータ専用: ファイル操作を行わず、メモリ上の notes のみ更新する。
        if let index = notes.firstIndex(where: { $0.url == note.url }) {
            let updatedAt = Date()
            let newURL = URL(fileURLWithPath: "/tmp/\(newFilename)")
            notes[index] = Note(
                url: newURL,
                body: notes[index].body,
                createdAt: notes[index].createdAt,
                updatedAt: updatedAt
            )
            return notes[index]
        }
        return nil
#endif
#endif

        guard let folderBookmark else {
            print("⚠️ NoteStore.renameNote: FolderBookmark is not configured.")
            return nil
        }

        do {
            let renamed = try folderBookmark.withScopedAccess { _ in
                let destinationURL = note.url.deletingLastPathComponent().appendingPathComponent(newFilename)

                // 同名なら実ファイル移動は不要なため、そのまま日時だけ更新して返す。
                if destinationURL != note.url {
                    try FileManager.default.moveItem(at: note.url, to: destinationURL)
                }

                let updatedAt = Date()
                return Note(
                    url: destinationURL,
                    body: note.body,
                    createdAt: note.createdAt,
                    updatedAt: updatedAt
                )
            }

            if let index = notes.firstIndex(where: { $0.url == note.url }) {
                notes[index] = renamed
            }
            return renamed
        } catch {
            print("❌ NoteStore.renameNote failed: \(error.localizedDescription)")
            return nil
        }
    }

    /// ノートのファイルを削除し、一覧からも取り除く。
    func deleteNote(_ note: Note) {
#if DEBUG
#if targetEnvironment(simulator)
        // DEBUG シミュレータ専用: ファイル削除は行わず、メモリ上の notes からのみ削除する。
        notes.removeAll { $0.url == note.url }
        return
#endif
#endif

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
#if DEBUG
#if targetEnvironment(simulator)
        // DEBUG シミュレータ専用: 実ファイル読み込みを行わず、メモリ上の notes から本文を返す。
        return notes.first(where: { $0.url == note.url })?.body ?? ""
#endif
#endif

        // 同期的に読む必要があるため、キャッシュ済み Document を優先する。
        // キャッシュがない場合は直接ファイルから読む（従来の実装）。
        if let doc = openDocument, openDocumentURL == note.url {
            return doc.body
        }
        // フォールバック: 直接ファイル読み込み
        return (try? String(contentsOf: note.url, encoding: .utf8)) ?? ""
    }

    /// UIDocument を open してから body を返す非同期版 loadBody。
    /// .task 内など async コンテキストで使う。
    func loadBodyAsync(for note: Note) async -> String {
#if DEBUG
#if targetEnvironment(simulator)
        return notes.first(where: { $0.url == note.url })?.body ?? ""
#endif
#endif
        do {
            let doc = try await openDocument(for: note.url)
            return doc.body
        } catch {
            print("❌ loadBodyAsync error: \(error)")
            // フォールバック: 直接ファイル読み込み
            return (try? String(contentsOf: note.url, encoding: .utf8)) ?? ""
        }
    }

    /// 検索用に全ノートの本文を読み込んで返す。
    /// クエリがあるときだけ呼ぶこと（全件読み込みのためコストが高い）。
    func notesWithBody() -> [Note] {
        return notes.map { note in
            var n = note
            // キャッシュ済みDocumentがあればそこから、なければファイルから読む。
            n.body = cachedBody(for: note) ?? loadBody(for: note)
            return n
        }
    }

    /// 現在キャッシュ中の NoteDocument の body を返す。
    /// UIDocument が外部変更を受け取って revert した後の最新値。
    func cachedBody(for note: Note) -> String? {
        guard let doc = openDocument, openDocumentURL == note.url else { return nil }
        return doc.body
    }

    /// 指定 URL の NoteDocument を開いて返す。
    /// 同じ URL なら既存インスタンスを再利用する。
    func openDocument(for url: URL) async throws -> NoteDocument {
        // 同じ URL なら再利用
        if let doc = openDocument, openDocumentURL == url {
            return doc
        }
        // 別のノートに切り替わった場合は前の Document を閉じる
        if let doc = openDocument {
            await doc.close()
        }
        if let observer = openDocumentStateObserver {
            NotificationCenter.default.removeObserver(observer)
            openDocumentStateObserver = nil
        }
        let doc = NoteDocument(fileURL: url)
        try await doc.open() // UIDocument が load(fromContents:) を呼ぶ
        // UIDocument が外部変更を revert したとき body が更新されるので、
        // コールバック経由で lastExternalUpdateDate を更新する。
        doc.onExternalChange = { [weak self] in
            guard let self else { return }
            print("📡 UIDocument: external change applied, body updated")
            self.lastExternalUpdateDate = Date()
        }
        openDocument = doc
        openDocumentURL = url

        // UIDocument が外部変更を検知して revert したとき通知を受け取る。
        openDocumentStateObserver = NotificationCenter.default.addObserver(
            forName: UIDocument.stateChangedNotification,
            object: doc,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            let state = doc.documentState
            if state.contains(.inConflict) {
                print("📡 UIDocument: conflict detected")
                // TODO: v1.1で競合ダイアログを表示
            }
        }
        return doc
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
        // 実機ではユーザー選択 URL を searchScopes に直接渡すと更新通知が来ないことがあるため、
        // iCloud の ubiquitous スコープで拾い、パス接頭辞でフォルダを絞り込む。
        query.searchScopes = [NSMetadataQueryUbiquitousDocumentsScope]
        query.predicate = NSPredicate(
            format: "%K BEGINSWITH %@ AND %K ENDSWITH[c] '.md'",
            NSMetadataItemPathKey,
            folderURL.path,
            NSMetadataItemFSNameKey
        )

        let center = NotificationCenter.default
        let queue = OperationQueue.main

        // 初回の結果収集が終わったタイミングでも一覧を同期する。
        let finishObserver = center.addObserver(
            forName: .NSMetadataQueryDidFinishGathering,
            object: query,
            queue: queue
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                // 実際の結果走査と disableUpdates はデバウンス後の `handleMetadataUpdate` 内で行う。
                self.handleMetadataUpdate()
            }
        }
        metadataQueryObservers.append(finishObserver)

        // 以降の iCloud 側の更新（外部アプリによる変更など）を拾う。
        let updateObserver = center.addObserver(
            forName: .NSMetadataQueryDidUpdate,
            object: query,
            queue: queue
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.handleMetadataUpdate()
            }
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
    /// クエリ結果の細かい走査は行わず、`loadNotes()` 後に `lastExternalUpdateDate` だけ進めてビューへ通知する。
    func handleMetadataUpdate() {
        metadataReloadDebounceWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }

            self.loadNotes()
            // メタデータ経由でディスク一覧を取り直したタイミングを表す（詳細の再読込／編集中の保存抑止に使う）。
            self.lastExternalUpdateDate = Date()
        }
        metadataReloadDebounceWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + metadataReloadDebounceInterval, execute: work)
    }

#if DEBUG
    /// DEBUG + Simulator の動作確認専用ダミーデータを注入する。
    /// 本番ビルドにはコンパイルされないため、後で安全に削除できる。
    func loadDebugDummyNotesForSimulator() {
        let now = Date()

        // 検索と wiki link 挙動を確認しやすいよう、本文に多様な語彙を入れる。
        notes = [
            Note(
                url: URL(fileURLWithPath: "/tmp/202604271321 Swift basics.md"),
                body: """
                SwiftUI layout notes.
                Start with stacks, modifiers, and navigation patterns.
                Link to advanced note: [[202604271325]]
                """,
                createdAt: now,
                updatedAt: now
            ),
            Note(
                url: URL(fileURLWithPath: "/tmp/202604271322 Networking checklist.md"),
                body: """
                URLSession retry strategy and timeout values.
                Add logging for request and response headers.
                Related architecture note: [[202604271326]]
                """,
                createdAt: now,
                updatedAt: now
            ),
            Note(
                url: URL(fileURLWithPath: "/tmp/202604271323 Writing workflow.txt"),
                body: """
                Capture quick ideas, then connect them with links.
                Review weekly and extract evergreen notes.
                """,
                createdAt: now,
                updatedAt: now
            ),
            Note(
                url: URL(fileURLWithPath: "/tmp/202604271324 Search engine behavior.md"),
                body: """
                Test keyword matching in filename and body.
                Query examples: swift tutorial, networking timeout, evergreen.
                """,
                createdAt: now,
                updatedAt: now
            ),
            Note(
                url: URL(fileURLWithPath: "/tmp/202604271325 Advanced Swift patterns.md"),
                body: """
                Protocol-oriented design, generics, and type erasure.
                Backlink source example: [[202604271321]]
                """,
                createdAt: now,
                updatedAt: now
            ),
            Note(
                url: URL(fileURLWithPath: "/tmp/202604271326 Architecture map.md"),
                body: """
                Domain, data, and presentation boundaries.
                See networking checklist: [[202604271322]]
                """,
                createdAt: now,
                updatedAt: now
            ),
        ]
    }
#endif
}
