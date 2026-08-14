#if canImport(SwiftUI)
import SwiftUI
import SplitKanaCore

/// フリック候補のポップアップ。**十字**に並べる（SPEC 2.3）。
///
/// 指を動かす向きと文字のある向きが一致する。「お」は下フリックなので中央の下に出る。
/// 横一列だと、読んでから指の向きに翻訳する手間が挟まる。
///
/// 四隅は空ける。**枠ごと1枚の板にはしない**ので、空いたところは背景が透ける。
/// 置き場所は決めない。パネルのどこに固定するかは `KeyboardGeometry.popupPlacement` の仕事。
struct FlickPopupView: View {
    let flickSet: FlickSet
    let selected: FlickDirection
    let itemWidth: CGFloat
    let itemHeight: CGFloat
    let palette: KeyPalette

    /// 上から3段ぶん。中央の段だけ左右が埋まる。
    private static let rows: [[FlickDirection?]] = [
        [nil, .up, nil],
        [.left, .center, .right],
        [nil, .down, nil]
    ]

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(Self.rows.enumerated()), id: \.offset) { _, row in
                HStack(spacing: 0) {
                    ForEach(Array(row.enumerated()), id: \.offset) { _, direction in
                        cell(direction)
                    }
                }
            }
        }
        .padding(SplitKanaTuning.popupPadding)
        .allowsHitTesting(false)
    }

    @ViewBuilder
    private func cell(_ direction: FlickDirection?) -> some View {
        // 割り当ての無い方向は描かない。四隅も同じ扱いで空く。
        if let direction, let character = flickSet[direction] {
            let isSelected = direction == selected
            Text(character)
                .font(.system(size: itemHeight * 0.42, weight: isSelected ? .semibold : .regular))
                .foregroundStyle(isSelected ? Color.white : palette.popupLabel)
                .minimumScaleFactor(0.5)
                .lineLimit(1)
                .frame(width: itemWidth, height: itemHeight)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(isSelected ? palette.popupHighlight : palette.popupFill)
                        .shadow(color: .black.opacity(0.18), radius: 4, y: 2)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(palette.popupStroke, lineWidth: 1)
                )
        } else {
            Color.clear
                .frame(width: itemWidth, height: itemHeight)
        }
    }
}
#endif
