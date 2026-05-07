//
//  MarkdownWebView.swift
//  Nodus
//
//  プレビュー用: marked.js（CDN）で Markdown を HTML にし、WKWebView で表示する。
//

import SwiftUI
import WebKit

/// Markdown 本文を WKWebView でレンダリングする（GFM・改行・テーブル等は marked に委譲）。
struct MarkdownWebView: UIViewRepresentable {
    let markdown: String
    /// `nodus://` リンクがタップされたときに呼ばれる（ホスト相当のノート ID 文字列）。
    let onLinkTapped: (String) -> Void
    /// レンダリング後のドキュメント高さ（親の `ScrollView` 内でフレーム高さに使う）。省略時は高さ通知なし。
    var onContentHeightChange: ((CGFloat) -> Void)? = nil

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> WKWebView {
        // メッセージハンドラで JS から高さを受け取るための設定。
        let config = WKWebViewConfiguration()
        config.userContentController.add(context.coordinator, name: Coordinator.bridgeName)

        let webView = WKWebView(frame: .zero, configuration: config)
        // リンク遷移は delegate で判別し、nodus / http(s) を個別処理する。
        webView.navigationDelegate = context.coordinator
        // 外側の SwiftUI ScrollView とスクロールが競合しないよう、内側スクロールは止める。
        webView.scrollView.isScrollEnabled = false
        webView.scrollView.bounces = false
        webView.isOpaque = false
        webView.backgroundColor = .clear
        context.coordinator.webView = webView
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        // SwiftUI 側のクロージャ差し替えに追随する。
        context.coordinator.parent = self
        // 本文が変わったときだけ HTML を再生成して読み込む。
        if context.coordinator.lastMarkdown != markdown {
            context.coordinator.lastMarkdown = markdown
            context.coordinator.loadHTML(markdown: markdown, into: webView)
        }
    }

    /// ビュー破棄時にメッセージハンドラを外し、リークや二重登録を防ぐ。
    static func dismantleUIView(_ uiView: WKWebView, coordinator: Coordinator) {
        uiView.configuration.userContentController.removeScriptMessageHandler(forName: Coordinator.bridgeName)
        uiView.navigationDelegate = nil
    }

    final class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        /// JS から Swift へ高さを送るときのチャンネル名。
        static let bridgeName = "nodusMarkdownBridge"

        var parent: MarkdownWebView
        weak var webView: WKWebView?
        /// 無限ループを避けるため、直近で読み込んだ Markdown を保持する。
        var lastMarkdown: String?

        init(parent: MarkdownWebView) {
            self.parent = parent
        }

        /// Markdown を base64 で HTML に埋め込み、marked で描画する。
        func loadHTML(markdown: String, into webView: WKWebView) {
            // JS 文字列のエスケープ問題を避けるため、本文は base64 のみをテンプレートへ埋め込む。
            let b64 = Data(markdown.utf8).base64EncodedString()
            let html = Self.htmlTemplate(markdownBase64: b64)
            webView.loadHTMLString(html, baseURL: nil)
        }

        // MARK: - WKNavigationDelegate

        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
        ) {
            guard navigationAction.navigationType == .linkActivated,
                  let url = navigationAction.request.url
            else {
                decisionHandler(.allow)
                return
            }

            if url.scheme == "nodus" {
                // アプリ内遷移用スキーム: ナビゲーションは止めて Swift 側へ渡す。
                let id = url.host ?? url.lastPathComponent
                if !id.isEmpty {
                    DispatchQueue.main.async {
                        self.parent.onLinkTapped(id)
                    }
                }
                decisionHandler(.cancel)
                return
            }

            if url.scheme == "http" || url.scheme == "https" {
                // 通常の URL は Safari で開く（プレビュー内に読み込まない）。
                DispatchQueue.main.async {
                    UIApplication.shared.open(url)
                }
                decisionHandler(.cancel)
                return
            }

            decisionHandler(.allow)
        }

        // MARK: - WKScriptMessageHandler

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            // DOM 高さを受け取り、親 SwiftUI が `.frame(height:)` を更新できるようにする。
            guard message.name == Self.bridgeName,
                  let body = message.body as? [String: Any],
                  let kind = body["kind"] as? String,
                  kind == "height",
                  let value = body["value"] as? Double
            else { return }

            let height = CGFloat(value)
            DispatchQueue.main.async {
                self.parent.onContentHeightChange?(height)
            }
        }

        /// cdnjs の marked とスタイルを含む完全な HTML ドキュメント（`prefers-color-scheme` で外観モード対応）。
        private static func htmlTemplate(markdownBase64 b64: String) -> String {
            """
            <!DOCTYPE html>
            <html lang="en">
            <head>
            <meta charset="utf-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, viewport-fit=cover">
            <script src="https://cdnjs.cloudflare.com/ajax/libs/marked/15.0.7/marked.min.js"></script>
            <style>
              :root {
                color-scheme: light dark;
              }
              html, body {
                margin: 0;
                padding: 0;
                font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
                font-size: 16px;
                line-height: 1.5;
              }
              #content {
                padding: 16px;
                box-sizing: border-box;
              }
              @media (prefers-color-scheme: light) {
                body { background: #ffffff; color: #000000; }
              }
              @media (prefers-color-scheme: dark) {
                body { background: #000000; color: #ffffff; }
              }
              a { color: #007AFF; }
              .nodus-wiki-unresolved { color: #8E8E93; }
              pre, code {
                font-family: ui-monospace, SFMono-Regular, Menlo, monospace;
                font-size: 14px;
              }
              pre {
                padding: 12px;
                border-radius: 8px;
                overflow-x: auto;
              }
              @media (prefers-color-scheme: light) {
                pre { background: rgba(0,0,0,0.06); }
              }
              @media (prefers-color-scheme: dark) {
                pre { background: rgba(255,255,255,0.08); }
              }
              table { border-collapse: collapse; width: 100%; margin: 1em 0; }
              th, td { border: 1px solid; padding: 6px 8px; }
              @media (prefers-color-scheme: light) {
                th, td { border-color: #c6c6c8; }
              }
              @media (prefers-color-scheme: dark) {
                th, td { border-color: #3a3a3c; }
              }
              img { max-width: 100%; height: auto; }
              blockquote {
                margin: 0.5em 0;
                padding-left: 12px;
                border-left: 3px solid #8E8E93;
              }
            </style>
            </head>
            <body>
            <div id="content"></div>
            <script>
              (function() {
                var b64 = '\(b64)';
                function utf8FromBase64(b64) {
                  var bin = atob(b64);
                  var bytes = new Uint8Array(bin.length);
                  for (var i = 0; i < bin.length; i++) bytes[i] = bin.charCodeAt(i);
                  return new TextDecoder('utf-8').decode(bytes);
                }
                function postHeight() {
                  var h = Math.max(document.documentElement.scrollHeight, document.body.scrollHeight);
                  if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.\(Self.bridgeName)) {
                    window.webkit.messageHandlers.\(Self.bridgeName).postMessage({ kind: 'height', value: h });
                  }
                }
                function render() {
                  if (typeof marked === 'undefined') {
                    requestAnimationFrame(render);
                    return;
                  }
                  marked.use({ gfm: true, breaks: true });
                  var md = utf8FromBase64(b64);
                  document.getElementById('content').innerHTML = marked.parse(md);
                  postHeight();
                  window.addEventListener('resize', postHeight);
                }
                render();
              })();
            </script>
            </body>
            </html>
            """
        }
    }
}
