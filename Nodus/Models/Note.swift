//
//  Note.swift
//  Nodus
//
//  PHASE 2: ダミーデータ用のノートモデル（ファイル I/O なし）
//

import Foundation

/// 1件のノートを表すモデル。リスト表示や詳細画面の識別に `Identifiable` を使う。
struct Note: Identifiable {
    /// SwiftUI の `List` などで行を一意に識別するための ID（ファイルとは別の安定キー）
    let id: UUID

    /// ディスク上のファイル名（例: `202604271321 Title.md`）
    var filename: String

    /// Markdown 形式の本文
    var body: String

    /// ノートの作成日時
    var createdAt: Date

    /// 最終更新日時
    var updatedAt: Date

    /// ファイル名の先頭 12 文字（Wiki リンク `[[ID]]` の ID 部分に相当するタイムスタンプ）
    /// 仕様上は `YYYYMMDDHHmm` の 12 桁を想定するが、ここでは文字列として先頭 12 文字を返すだけに留める。
    var timestampID: String {
        String(filename.prefix(12))
    }

    /// 拡張子 `.md` を除いたファイル名から、先頭 12 文字（タイムスタンプ）より後ろをタイトルとみなす。
    /// 区切りの空白は除去する。タイムスタンプのみ（例: `202604271321.md`）のときは空文字。
    var title: String {
        let stem = Self.stemByRemovingMarkdownExtension(from: filename)
        guard stem.count >= 12 else { return "" }
        let afterTimestamp = stem.dropFirst(12)
        return String(afterTimestamp).trimmingCharacters(in: .whitespaces)
    }

    /// タイトル抽出のため、`.md` 拡張子だけを取り除いた文字列を得る（`.MD` なども同様に扱う）。
    private static func stemByRemovingMarkdownExtension(from filename: String) -> String {
        let lower = filename.lowercased()
        guard lower.hasSuffix(".md"), filename.count >= 4 else { return filename }
        return String(filename.dropLast(3))
    }
}
