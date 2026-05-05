import Foundation

/// ノートファイル名を仕様どおりに分解・検証する純粋ロジック。
enum NoteFilenameParser {
    /// 読み込み時に許可する拡張子（The Archive 互換のため `.txt` も受け入れる）。
    static let supportedExtensions = ["md", "txt"]

    /// 新規作成時に採用する既定拡張子（作成側ロジックで使用）。
    static let defaultExtension = "md"

    /// ファイル名の先頭 12 文字をタイムスタンプ ID として返す。
    static func timestampID(from filename: String) -> String {
        String(filename.prefix(12))
    }

    /// 拡張子を除いたファイル名から、先頭 12 文字以降をタイトルとして返す。
    /// タイムスタンプのみの場合は空文字を返す。
    static func title(from filename: String) -> String {
        let stem = displayName(from: filename)
        guard stem.count >= 12 else { return "" }
        let afterTimestamp = stem.dropFirst(12)
        return String(afterTimestamp).trimmingCharacters(in: .whitespaces)
    }

    /// 一覧表示用に、対応拡張子（`.md` / `.txt`）を除いたファイル名を返す。
    static func displayName(from filename: String) -> String {
        let lower = filename.lowercased()

        // 末尾の拡張子が対応一覧に含まれる場合のみ取り除く。
        for ext in supportedExtensions {
            let suffix = "." + ext
            if lower.hasSuffix(suffix), filename.count >= suffix.count {
                return String(filename.dropLast(suffix.count))
            }
        }

        return filename
    }

    /// `YYYYMMDDHHmm` で始まり、対応拡張子（`.md` / `.txt`）で終わるかを検証する。
    static func isValidNoteFilename(_ filename: String) -> Bool {
        let lower = filename.lowercased()
        let hasSupportedExtension = supportedExtensions.contains { lower.hasSuffix("." + $0) }
        guard hasSupportedExtension else { return false }

        let stem = displayName(from: filename)
        guard stem.count >= 12 else { return false }

        // 先頭 12 文字が 0-9 のみで構成されることを確認する。
        let id = stem.prefix(12)
        return id.allSatisfy(\.isNumber)
    }
}
