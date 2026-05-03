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
        ContentUnavailableView(
            "ノートを選択",
            systemImage: "doc.text",
            description: Text("一覧からノートを選ぶと、ここに内容が表示されます。")
        )
    }
}
