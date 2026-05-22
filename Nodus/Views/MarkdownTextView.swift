import UIKit
import SwiftUI

/// UITextView を SwiftUI から使うためのラッパー。
/// カーソル位置へのテキスト挿入と loadedBody との双方向バインディングを提供する。
struct MarkdownTextView: UIViewRepresentable {
    @Binding var text: String
    /// 外部からカーソル位置に挿入するテキストを渡すためのバインディング。
    /// 挿入後は nil にリセットする。
    @Binding var insertionText: String?
    /// フォーカス状態を外部から制御するためのバインディング。
    @Binding var isFocused: Bool

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.delegate = context.coordinator
        context.coordinator.textView = textView
        textView.font = UIFont.monospacedSystemFont(
            ofSize: UIFont.preferredFont(forTextStyle: .body).pointSize,
            weight: .regular
        )
        textView.autocapitalizationType = .none
        textView.autocorrectionType = .no
        textView.backgroundColor = .clear
        textView.textContainerInset = UIEdgeInsets(top: 0, left: 4, bottom: 0, right: 4)

        // iOS の自動フォーマット（Markdownレンダリング）を無効化する
        if #available(iOS 16.0, *) {
            textView.isFindInteractionEnabled = false
        }
        textView.typingAttributes = [
            .font: UIFont.monospacedSystemFont(
                ofSize: UIFont.preferredFont(forTextStyle: .body).pointSize,
                weight: .regular
            ),
            .foregroundColor: UIColor.label,
        ]

        // キーボードツールバーを inputAccessoryView として設定する
        textView.inputAccessoryView = makeCurrentToolbar(coordinator: context.coordinator)

        return textView
    }

    func updateUIView(_ textView: UITextView, context: Context) {
        // Coordinator の parent を常に最新の MarkdownTextView に更新する。
        // onToolbarAction などのクロージャが古いキャプチャのままにならないようにするため。
        context.coordinator.parent = self
        // text が外部から変わった場合のみ反映する（カーソル位置を保持するため）
        if textView.text != text {
            let selectedRange = textView.selectedRange
            textView.text = text
            textView.typingAttributes = [
                .font: UIFont.monospacedSystemFont(
                    ofSize: UIFont.preferredFont(forTextStyle: .body).pointSize,
                    weight: .regular
                ),
                .foregroundColor: UIColor.label,
            ]
            if selectedRange.location <= (text as NSString).length {
                textView.selectedRange = selectedRange
            }
        }

        // フォーカス制御
        if isFocused && !textView.isFirstResponder {
            textView.becomeFirstResponder()
        } else if !isFocused && textView.isFirstResponder {
            textView.resignFirstResponder()
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    private func makeCurrentToolbar(coordinator: Coordinator) -> UIView {
        if coordinator.isExpandedPanelVisible {
            return makeExpandedToolbar(coordinator: coordinator)
        } else {
            return makeNormalToolbar(coordinator: coordinator)
        }
    }

    private func makeNormalToolbar(coordinator: Coordinator) -> UIInputView {
        let toolbar = UIInputView(
            frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 44),
            inputViewStyle: .keyboard
        )
        // ダークモード対応の背景色を設定する
        toolbar.backgroundColor = UIColor.systemBackground
        let items: [(title: String, insertion: String)] = [
            ("#", "# "), ("**", "****"), ("*", "**"),
            (">", "> "), ("[[", "[[]]"), ("⇥", "\t"),
        ]
        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.distribution = .fillEqually
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.spacing = 6
        stackView.layoutMargins = UIEdgeInsets(top: 6, left: 8, bottom: 6, right: 8)
        stackView.isLayoutMarginsRelativeArrangement = true
        for item in items {
            stackView.addArrangedSubview(makeToolbarButton(
                title: item.title, insertion: item.insertion, coordinator: coordinator))
        }
        let expandButton = UIButton(type: .system)
        expandButton.setTitle("≡", for: .normal)
        expandButton.titleLabel?.font = UIFont.systemFont(ofSize: 18, weight: .regular)
        expandButton.addTarget(coordinator, action: #selector(Coordinator.toggleExpandedPanel), for: .touchUpInside)
        stackView.addArrangedSubview(expandButton)
        toolbar.addSubview(stackView)
        NSLayoutConstraint.activate([
            stackView.leadingAnchor.constraint(equalTo: toolbar.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: toolbar.trailingAnchor),
            stackView.topAnchor.constraint(equalTo: toolbar.topAnchor),
            stackView.bottomAnchor.constraint(equalTo: toolbar.bottomAnchor),
        ])
        return toolbar
    }

    private func makeExpandedToolbar(coordinator: Coordinator) -> UIInputView {
        let toolbar = UIInputView(
            frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 132),
            inputViewStyle: .keyboard
        )
        // ダークモード対応の背景色を設定する
        toolbar.backgroundColor = UIColor.secondarySystemBackground
        let rows: [[(title: String, insertion: String)]] = [
            [("H1", "# "), ("H2", "## "), ("H3", "### "), ("B", "****"), ("I", "**"), ("S", "~~~~")],
            [
                ("-", "- "), ("1.", "1. "), ("[ ]", "- [ ] "), ("`", "```\n\n```"),
                ("Table", "| Header | Header |\n| ------ | ------ |\n| Cell   | Cell   |\n"),
            ],
        ]
        let outerStack = UIStackView()
        outerStack.axis = .vertical
        outerStack.distribution = .fillEqually
        outerStack.translatesAutoresizingMaskIntoConstraints = false
        for row in rows {
            let rowStack = UIStackView()
            rowStack.axis = .horizontal
            rowStack.distribution = .fillEqually
            for item in row {
                rowStack.addArrangedSubview(makeToolbarButton(
                    title: item.title, insertion: item.insertion, coordinator: coordinator))
            }
            outerStack.addArrangedSubview(rowStack)
        }
        let closeButton = UIButton(type: .system)
        closeButton.setTitle("✕ Close", for: .normal)
        closeButton.titleLabel?.font = UIFont.systemFont(ofSize: 14, weight: .regular)
        closeButton.addTarget(coordinator, action: #selector(Coordinator.toggleExpandedPanel), for: .touchUpInside)
        closeButton.heightAnchor.constraint(equalToConstant: 32).isActive = true
        let mainStack = UIStackView(arrangedSubviews: [outerStack, closeButton])
        mainStack.axis = .vertical
        mainStack.distribution = .fill
        mainStack.spacing = 4
        mainStack.translatesAutoresizingMaskIntoConstraints = false
        mainStack.layoutMargins = UIEdgeInsets(top: 6, left: 8, bottom: 6, right: 8)
        mainStack.isLayoutMarginsRelativeArrangement = true
        toolbar.addSubview(mainStack)
        NSLayoutConstraint.activate([
            mainStack.leadingAnchor.constraint(equalTo: toolbar.leadingAnchor),
            mainStack.trailingAnchor.constraint(equalTo: toolbar.trailingAnchor),
            mainStack.topAnchor.constraint(equalTo: toolbar.topAnchor),
            mainStack.bottomAnchor.constraint(equalTo: toolbar.bottomAnchor),
        ])
        return toolbar
    }

    private func makeToolbarButton(title: String, insertion: String, coordinator: Coordinator) -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle(title, for: .normal)
        button.titleLabel?.font = UIFont.monospacedSystemFont(ofSize: 17, weight: .medium)
        button.accessibilityIdentifier = insertion

        // ボタンの背景・角丸・ボーダーを設定してキーボードキーのように見せる
        button.backgroundColor = UIColor.tertiarySystemBackground
        button.layer.cornerRadius = 6
        button.layer.borderWidth = 0.5
        button.layer.borderColor = UIColor.separator.cgColor

        // ボタン間のマージン
        button.contentEdgeInsets = UIEdgeInsets(top: 4, left: 2, bottom: 4, right: 2)

        button.addTarget(coordinator, action: #selector(Coordinator.toolbarButtonTapped(_:)), for: .touchUpInside)
        return button
    }

    final class Coordinator: NSObject, UITextViewDelegate {
        var parent: MarkdownTextView
        weak var textView: UITextView?
        var isExpandedPanelVisible = false

        init(_ parent: MarkdownTextView) {
            self.parent = parent
        }

        @objc func toggleExpandedPanel() {
            isExpandedPanelVisible.toggle()
            // inputAccessoryView を差し替えて再表示
            textView?.inputAccessoryView = parent.makeCurrentToolbar(coordinator: self)
            textView?.reloadInputViews()
        }

        @objc func toolbarButtonTapped(_ sender: UIButton) {
            guard let insertion = sender.accessibilityIdentifier else { return }
            guard let textView else { return }
            if let selectedRange = textView.selectedTextRange {
                textView.replace(selectedRange, withText: insertion)
                let pairsNeedingCursorCenter = ["****", "**", "[[]]"]
                if pairsNeedingCursorCenter.contains(insertion) {
                    let halfLength = insertion.count / 2
                    if let currentPosition = textView.selectedTextRange?.start,
                       let newPosition = textView.position(from: currentPosition, offset: -halfLength) {
                        textView.selectedTextRange = textView.textRange(from: newPosition, to: newPosition)
                    }
                }
                parent.text = textView.text
            }
        }

        func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
            // Return キー以外は通常処理
            guard text == "\n" else { return true }

            let nsText = textView.text as NSString
            let currentText = nsText as String

            // カーソル位置から現在行の先頭を探す
            let cursorPosition = range.location
            let lineStart = nsText.lineRange(for: NSRange(location: cursorPosition, length: 0)).location

            // 現在行のテキストを取得
            let lineRange = nsText.lineRange(for: NSRange(location: cursorPosition, length: 0))
            let currentLine = nsText.substring(with: NSRange(
                location: lineRange.location,
                length: cursorPosition - lineRange.location
            ))

            // 自動補完パターンを判定する
            if let prefix = autoCompletePrefix(for: currentLine) {
                if prefix.isEmpty {
                    // 補完キャンセル: 現在行のプレフィックスを削除して空行にする
                    let lineStartIndex = currentText.index(currentText.startIndex, offsetBy: lineRange.location)
                    let cursorIndex = currentText.index(currentText.startIndex, offsetBy: cursorPosition)
                    let newText = currentText.replacingCharacters(
                        in: lineStartIndex..<cursorIndex,
                        with: ""
                    )
                    textView.text = newText
                    // カーソルを行頭に移動
                    let newPosition = textView.position(
                        from: textView.beginningOfDocument,
                        offset: lineRange.location
                    )
                    if let pos = newPosition {
                        textView.selectedTextRange = textView.textRange(from: pos, to: pos)
                    }
                    parent.text = textView.text
                    return false
                } else {
                    // 改行 + 補完プレフィックスを挿入
                    let insertion = "\n" + prefix
                    if let selectedRange = textView.selectedTextRange {
                        textView.replace(selectedRange, withText: insertion)
                    }
                    parent.text = textView.text
                    return false
                }
            }

            return true
        }

        /// 現在行のテキストから自動補完プレフィックスを返す。
        /// - Returns: 補完する文字列。空文字の場合は補完キャンセル。nil の場合は補完なし。
        private func autoCompletePrefix(for line: String) -> String? {
            // タスクリスト: - [ ] または - [x]
            if line.hasPrefix("- [ ] ") || line.hasPrefix("- [x] ") {
                // プレフィックスのみの行（テキストなし）→ 補完キャンセル
                if line == "- [ ] " || line == "- [x] " {
                    return ""
                }
                return "- [ ] "
            }

            // 箇条書き: -（スペース）
            if line.hasPrefix("- ") {
                if line == "- " {
                    return ""
                }
                return "- "
            }

            // 番号付きリスト: 数字.（スペース）
            let numberRegex = try? NSRegularExpression(pattern: "^(\\d+)\\. ")
            let nsLine = line as NSString
            if let match = numberRegex?.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)) {
                let numberRange = match.range(at: 1)
                let numberString = nsLine.substring(with: numberRange)
                let prefix = "\(numberString). "
                if line == prefix {
                    return ""
                }
                let nextNumber = (Int(numberString) ?? 1) + 1
                return "\(nextNumber). "
            }

            return nil
        }

        func textViewDidChange(_ textView: UITextView) {
            parent.text = textView.text
        }

        func textViewDidBeginEditing(_ textView: UITextView) {
            parent.isFocused = true
        }

        func textViewDidEndEditing(_ textView: UITextView) {
            parent.isFocused = false
        }
    }
}
