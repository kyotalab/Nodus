//
//  EmptySelectionView.swift
//  Nodus
//
//  PHASE 2: ノート未選択時の詳細ペイン（ロゴのみ等は後で仕上げる）
//

import SwiftUI

/// iPad などでノートが選ばれていないときに詳細側へ表示する空状態。
struct EmptySelectionView: View {
    var body: some View {
        // 仕様どおり、未選択時はテキスト案内を出さずロゴ相当のみを表示する。
        Text("Nodus")
            .font(.system(size: 40, weight: .semibold, design: .rounded))
            .foregroundStyle(.secondary)
    }
}
