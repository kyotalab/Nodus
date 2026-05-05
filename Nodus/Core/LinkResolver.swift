import Foundation

/// `[[ID]]` 形式のリンク解決と被リンク計算を担う純粋ロジック。
enum LinkResolver {
    /// `filename` に `id` が部分一致する最初のノートを返す。
    static func resolve(_ id: String, in notes: [Note]) -> Note? {
        notes.first { $0.filename.contains(id) }
    }

    /// 本文から `[[...]]` パターンをすべて抽出し、内側の文字列を返す。
    static func extractLinkIDs(from body: String) -> [String] {
        // Swift Regex（iOS 16+）で `[[...]]` の最短一致を走査する。
        let pattern = /\[\[(.+?)\]\]/
        return body.matches(of: pattern).map { String($0.1) }
    }

    /// 対象ノートの ID を本文に含む「他ノート」の件数を返す。
    static func backlinkCount(for note: Note, in notes: [Note]) -> Int {
        let targetID = note.timestampID
        return notes.filter { other in
            // 自分自身は被リンク元として数えない。
            other.id != note.id && other.body.contains(targetID)
        }.count
    }
}
