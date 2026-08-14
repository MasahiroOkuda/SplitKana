#if canImport(SwiftUI) && canImport(UIKit)
import SwiftUI
import SplitKanaCore

/// キー1つ。**見た目だけ**を受け持つ。
///
/// タッチは受け取らない。どの指がどのキーを押しているかは
/// `SplitKanaKeyboardView` が `KeyboardGeometry.hitTest` で解決し、
/// その結果を `pressedDirection` として渡してくる。
/// こうしておかないと、両手の親指で同時に押したときに片方が落ちる。
///
/// 複製キーかどうかは**見た目にしか効かない**。出力は完全に同一（SPEC 2.1 / 10）。
struct KeyView: View {

    let placed: PlacedKey
    let palette: KeyPalette
    /// 押されていなければ nil。押されていれば、その指のフリック方向。
    let pressedDirection: FlickDirection?

    private var isPressed: Bool { pressedDirection != nil }
    private var flickSet: FlickSet? { placed.key.kind.flickSet }

    private var fill: Color {
        if isPressed { return palette.pressedFill }
        switch placed.key.kind {
        case .kana, .dakuten, .latin:
            return placed.isDuplicate ? palette.duplicateFill : palette.kanaFill
        case .backspace, .space, .newline, .function, .shift:
            return palette.functionFill
        }
    }

    private var stroke: Color {
        if placed.isDuplicate { return palette.duplicateStroke }
        switch placed.key.kind {
        case .kana, .dakuten, .latin: return palette.kanaStroke
        case .backspace, .space, .newline, .function, .shift: return palette.functionStroke
        }
    }

    /// 押下中はフリック方向の文字をキー上でも見せる。
    private var label: String {
        if let direction = pressedDirection, let flickSet = flickSet {
            return flickSet.character(for: direction)
        }
        return placed.key.kind.label
    }

    private var fontSize: CGFloat {
        let base = min(placed.rect.height, placed.rect.width)
        switch label.count {
        case 0, 1: return base * 0.46
        case 2: return base * 0.30
        default: return base * 0.22
        }
    }

    var body: some View {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
            .fill(fill)
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(stroke, lineWidth: 1)
            )
            .overlay(
                Text(label)
                    .font(.system(size: fontSize, weight: .regular))
                    .foregroundStyle(palette.label)
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                    .padding(.horizontal, 2)
            )
            .frame(width: placed.rect.width, height: placed.rect.height)
            .position(x: placed.rect.midX, y: placed.rect.midY)
            .allowsHitTesting(false)
    }
}
#endif
