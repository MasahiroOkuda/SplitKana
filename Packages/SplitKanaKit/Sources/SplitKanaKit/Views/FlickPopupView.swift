import SwiftUI

/// フリック候補のポップアップ。**横一列**に並べ、キーボードの外側へ開く（SPEC 2.3）。
///
/// 上下に開いてはいけない。4行あるためキーの縦が詰まっており、隣のキーと重なる。
/// キーボード拡張は自分の矩形の外に描画できないので、中央側に開く設計はその制約にも収まる。
struct FlickPopupView: View {
    let flickSet: FlickSet
    let selected: FlickDirection
    let itemWidth: CGFloat
    let itemHeight: CGFloat
    let palette: KeyPalette

    private var items: [(direction: FlickDirection, character: String)] {
        flickSet.assigned
    }

    static func width(for flickSet: FlickSet, itemWidth: CGFloat) -> CGFloat {
        CGFloat(flickSet.assigned.count) * itemWidth + 8
    }

    var body: some View {
        HStack(spacing: 0) {
            ForEach(items, id: \.direction) { item in
                let isSelected = item.direction == selected
                Text(item.character)
                    .font(.system(size: itemHeight * 0.44, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? Color.white : palette.popupLabel)
                    .frame(width: itemWidth, height: itemHeight)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(isSelected ? palette.popupHighlight : Color.clear)
                    )
            }
        }
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(palette.popupFill)
                .shadow(color: .black.opacity(0.18), radius: 6, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(palette.popupStroke, lineWidth: 1)
        )
        .allowsHitTesting(false)
    }
}
