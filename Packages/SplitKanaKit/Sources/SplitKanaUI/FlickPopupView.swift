#if canImport(SwiftUI)
import SwiftUI
import SplitKanaCore

/// フリック候補のポップアップ。**横一列**に並べる（SPEC 2.3）。
///
/// 置き場所は決めない。パネルのどこに固定するかは `KeyboardGeometry.popupPlacement` の仕事。
struct FlickPopupView: View {
    let flickSet: FlickSet
    let selected: FlickDirection
    let itemWidth: CGFloat
    let itemHeight: CGFloat
    let palette: KeyPalette

    private var items: [(direction: FlickDirection, character: String)] {
        flickSet.assigned
    }

    var body: some View {
        HStack(spacing: 0) {
            ForEach(items, id: \.direction) { item in
                let isSelected = item.direction == selected
                Text(item.character)
                    .font(.system(size: itemHeight * 0.5, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? Color.white : palette.popupLabel)
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                    .frame(width: itemWidth, height: itemHeight)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(isSelected ? palette.popupHighlight : Color.clear)
                    )
            }
        }
        .padding(SplitKanaTuning.popupPadding)
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
#endif
