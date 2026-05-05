import Foundation

/// ノート一覧に対する全文検索（ファイル名 + 本文）を担う純粋ロジック。
enum SearchEngine {
    /// クエリをスペース区切りで AND 検索し、条件に合うノートだけを返す。
    static func search(_ query: String, in notes: [Note]) -> [Note] {
        // 大文字小文字を無視し、連続スペースは split により自動で無視する。
        let terms = query
            .lowercased()
            .split(separator: " ")
            .map(String.init)

        // 空クエリ（または空白のみ）の場合は全件を返す。
        guard !terms.isEmpty else { return notes }

        // 検索対象はファイル名と本文を連結した文字列。
        return notes.filter { note in
            let searchTarget = (note.filename + " " + note.body).lowercased()
            // すべての検索語を含むノートのみを採用する（AND 検索）。
            return terms.allSatisfy { searchTarget.contains($0) }
        }
    }
}
