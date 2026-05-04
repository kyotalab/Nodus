//
//  FolderBookmark.swift
//  Nodus
//
//  PHASE 3: iCloud Drive フォルダの security-scoped bookmark 管理
//

import Combine
import Foundation

/// 選択済みフォルダの bookmark を永続化し、起動時に復元する。
@MainActor
final class FolderBookmark: ObservableObject {
    /// 設定画面から再選択したいときのフックとして利用するキー。
    static let userDefaultsKey = "selectedFolderBookmark"

    /// 復元済みのノート保存先フォルダ URL。未選択時は `nil`。
    @Published private(set) var selectedFolderURL: URL?

    /// UI 側が「選択済みかどうか」を簡単に判定するための補助プロパティ。
    var hasSelectedFolder: Bool {
        selectedFolderURL != nil
    }

    init() {
        restoreFromUserDefaults()
    }

    /// ドキュメントピッカーで選ばれた URL を bookmark として保存する。
    func saveSelectedFolder(_ url: URL) throws {
        // security-scoped URL へのアクセスを開始してから bookmark を作成する。
        let didStartAccess = url.startAccessingSecurityScopedResource()
        defer {
            if didStartAccess {
                url.stopAccessingSecurityScopedResource()
            }
        }

        let bookmarkData = try url.bookmarkData(
            options: [],
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
        UserDefaults.standard.set(bookmarkData, forKey: Self.userDefaultsKey)
        selectedFolderURL = url
    }

    /// 保存済み bookmark を読み直して状態を更新する（設定変更後の再読込フック）。
    func reload() {
        restoreFromUserDefaults()
    }

    /// 設定画面から「フォルダを変更する」操作に使える初期フック。
    func clearSelectionForSettings() {
        UserDefaults.standard.removeObject(forKey: Self.userDefaultsKey)
        selectedFolderURL = nil
    }

    /// 現在の URL に一時アクセスして処理を行う共通ユーティリティ。
    func withScopedAccess<T>(_ work: (URL) throws -> T) throws -> T {
        guard let selectedFolderURL else {
            throw FolderBookmarkError.missingSelection
        }

        let didStartAccess = selectedFolderURL.startAccessingSecurityScopedResource()
        defer {
            if didStartAccess {
                selectedFolderURL.stopAccessingSecurityScopedResource()
            }
        }
        return try work(selectedFolderURL)
    }

    /// UserDefaults 内の bookmark を復元し、有効なら `selectedFolderURL` に反映する。
    private func restoreFromUserDefaults() {
        guard let bookmarkData = UserDefaults.standard.data(forKey: Self.userDefaultsKey) else {
            selectedFolderURL = nil
            return
        }

        do {
            var isStale = false
            let restoredURL = try URL(
                resolvingBookmarkData: bookmarkData,
                options: [],
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )

            // 1度 start/stop して access 可否を確認し、無効 bookmark を早期検知する。
            let didStartAccess = restoredURL.startAccessingSecurityScopedResource()
            if didStartAccess {
                restoredURL.stopAccessingSecurityScopedResource()
            }
            guard didStartAccess else {
                throw FolderBookmarkError.securityScopeAccessDenied
            }

            // stale な bookmark は、同じ URL で作り直して再保存する。
            if isStale {
                try saveSelectedFolder(restoredURL)
            } else {
                selectedFolderURL = restoredURL
            }
        } catch {
            UserDefaults.standard.removeObject(forKey: Self.userDefaultsKey)
            selectedFolderURL = nil
        }
    }
}

enum FolderBookmarkError: LocalizedError {
    case missingSelection
    case securityScopeAccessDenied

    var errorDescription: String? {
        switch self {
        case .missingSelection:
            return "No folder is selected."
        case .securityScopeAccessDenied:
            return "Could not access the selected folder."
        }
    }
}
