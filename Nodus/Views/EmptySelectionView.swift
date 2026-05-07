//
//  EmptySelectionView.swift
//  Nodus
//
//  PHASE 2: ノート未選択時の詳細ペイン（ロゴのみ等は後で仕上げる）
//

import SwiftUI

/// iPad などでノートが選ばれていないときに詳細側へ表示する空状態。
/// 画像アセットは使わず、タイポグラフィのみでブランドを示すミニマルな表示。
struct EmptySelectionView: View {
    var body: some View {
        // 詳細ペイン全体を埋め、縦横とも中央にワードマークを置く。
        VStack(spacing: 12) {
            // アプリ名: 大きく薄いウェイトで主張しつつ控えめなトーンにする。
            Text("Nodus")
                .font(.largeTitle)
                .fontWeight(.thin)
                .foregroundStyle(.secondary)

            // コンセプトを一言で示す（00_project の Subtitle に相当）。
            Text("Plain text, connected thinking")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }
}
