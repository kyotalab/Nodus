import UIKit

/// 1つの .md ファイルを管理する UIDocument サブクラス。
/// UIDocument が iCloud 同期・外部変更検知・競合解決を担う。
final class NoteDocument: UIDocument {

    /// ファイルの本文。UIDocument が読み書きの橋渡しをする。
    var body: String = ""
    /// 外部変更で body が更新されたときに NoteStore へ伝えるコールバック。
    var onExternalChange: (() -> Void)?

    // MARK: - 読み込み（UIDocument が外部変更を検知したとき自動で呼ぶ）

    override func load(fromContents contents: Any, ofType typeName: String?) throws {
        guard let data = contents as? Data else {
            body = ""
            return
        }
        let newBody = String(data: data, encoding: .utf8) ?? ""
        // 初回ロードと外部変更による再ロードを区別するため、
        // body に変化があったときだけコールバックを呼ぶ。
        let isExternalChange = !body.isEmpty && newBody != body
        body = newBody
        if isExternalChange {
            DispatchQueue.main.async { [weak self] in
                self?.onExternalChange?()
            }
        }
    }

    // MARK: - 書き込み（save(to:for:) を呼ぶと UIDocument がこれを呼ぶ）

    override func contents(forType typeName: String) throws -> Any {
        return body.data(using: .utf8) ?? Data()
    }
}
