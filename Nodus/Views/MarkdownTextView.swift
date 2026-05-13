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

        // キーボードツールバーを inputAccessoryView として設定する
        textView.inputAccessoryView = makeToolbar(for: textView, coordinator: context.coordinator)

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
            // 可能であればカーソル位置を復元する
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

    private func makeToolbar(for textView: UITextView, coordinator: Coordinator) -> UIView {
        let toolbar = UIInputView(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 44), inputViewStyle: .keyboard)
        toolbar.allowsSelfSizing = true

        let items: [(title: String, insertion: String)] = [
            ("#", "# "),
            ("**", "****"),
            ("*", "**"),
            (">", "> "),
            ("[[", "[[]]"),
            ("⇥", "\t"),
        ]

        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.distribution = .fillEqually
        stackView.translatesAutoresizingMaskIntoConstraints = false

        for item in items {
            let button = UIButton(type: .system)
            button.setTitle(item.title, for: .normal)
            button.titleLabel?.font = UIFont.monospacedSystemFont(ofSize: 16, weight: .regular)
            // insertion テキストをタグではなく accessibilityIdentifier で保持する
            button.accessibilityIdentifier = item.insertion
            button.addTarget(coordinator, action: #selector(Coordinator.toolbarButtonTapped(_:)), for: .touchUpInside)
            stackView.addArrangedSubview(button)
        }

        toolbar.addSubview(stackView)
        NSLayoutConstraint.activate([
            stackView.leadingAnchor.constraint(equalTo: toolbar.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: toolbar.trailingAnchor),
            stackView.topAnchor.constraint(equalTo: toolbar.topAnchor),
            stackView.bottomAnchor.constraint(equalTo: toolbar.bottomAnchor),
        ])

        return toolbar
    }

    final class Coordinator: NSObject, UITextViewDelegate {
        var parent: MarkdownTextView
        weak var textView: UITextView?

        init(_ parent: MarkdownTextView) {
            self.parent = parent
        }

        @objc func toolbarButtonTapped(_ sender: UIButton) {
            guard let insertion = sender.accessibilityIdentifier else { return }
            guard let textView else { return }

            // カーソル位置に直接挿入する
            if let selectedRange = textView.selectedTextRange {
                textView.replace(selectedRange, withText: insertion)

                // ****や[[]]はカーソルを中央に移動する
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
