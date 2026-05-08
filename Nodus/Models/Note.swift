//
//  Note.swift
//  Nodus
//
//  PHASE 3-4: URLベースのノートモデル。NoteFilenameParserに解析を委譲する。
//

import Foundation

/// 1件のノートを表すモデル。PHASE 3 では実ファイル URL を識別の基準にする。
/// `List(selection:)` など分割ビューとの連携のため `Hashable` に準拠する。
struct Note: Identifiable, Hashable {
    /// ファイル実体の URL。将来の iCloud Drive ファイル I/O の基準になる。
    var url: URL

    /// Markdown 形式の本文
    var body: String

    /// ノートの作成日時
    var createdAt: Date

    /// 最終更新日時
    var updatedAt: Date

    /// `Identifiable` 用 ID。仕様どおりファイル名先頭 12 桁のタイムスタンプ ID を使う。
    var id: String {
        timestampID
    }

    /// ディスク上のファイル名（例: `202604271321 Title.md`）
    var filename: String {
        url.lastPathComponent
    }

    /// ファイル名の先頭 12 文字（Wiki リンク `[[ID]]` の ID 部分に相当するタイムスタンプ）
    /// 仕様上は `YYYYMMDDHHmm` の 12 桁を想定するが、ここでは文字列として先頭 12 文字を返すだけに留める。
    var timestampID: String {
        NoteFilenameParser.timestampID(from: filename)
    }

    /// 拡張子を除いたファイル名をそのまま返す（一覧表示は The Archive と同様にこの文字列を使う）。
    var displayName: String {
        NoteFilenameParser.displayName(from: filename)
    }

    /// 拡張子 `.md` を除いたファイル名から、先頭 12 文字（タイムスタンプ）より後ろをタイトルとみなす。
    /// 区切りの空白は除去する。タイムスタンプのみ（例: `202604271321.md`）のときは空文字。
    var title: String {
        NoteFilenameParser.title(from: filename)
    }
}
