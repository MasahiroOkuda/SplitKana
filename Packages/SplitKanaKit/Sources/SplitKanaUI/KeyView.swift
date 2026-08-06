#if canImport(SwiftUI)
import SwiftUI
import SplitKanaCore

/// キー1つ。押下中はフリック方向を追い、離した瞬間に `KeyOutput` を1つだけ出す。
///
/// ポップアップは自分では描かない。押している方向を親へ報告するだけで、
/// 実際の描画はパネルの外側（`SplitKanaKeyboardView`）がまとめて受け持つ。
///
/// 複製キーかどうかは**見た目にしか効かない**。出力は完全に同一（SPEC 2.1 / 10）。
struct KeyView: View {

    let placed: PlacedKey
    let flickThreshold: CGFloat
    let palette: KeyPalette
    let onOutput: (KeyOutput) -> Void
    let onFlickChange: (PlacedKey?, FlickDirection) -> Void

    @State private var isPressed = false
    @State private var direction: FlickDirection = .center

    private var flickSet: FlickSet? { placed.key.kind.flickSet }

    private var fill: Color {
        if isPressed { return palette.pressedFill }
        switch placed.key.kind {
        case .kana, .dakuten:
            return placed.isDuplicate ? palette.duplicateFill : palette.kanaFill
        case .backspace, .space, .newline, .function:
            return palette.functionFill
        }
    }

    private var stroke: Color {
        if placed.isDuplicate { return palette.duplicateStroke }
        switch placed.key.kind {
        case .kana, .dakuten: return palette.kanaStroke
        case .backspace, .space, .newline, .function: return palette.functionStroke
        }
    }

    /// 押下中はフリック方向の文字をキー上でも見せる。
    private var label: String {
        if isPressed, let flickSet = flickSet {
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
            // タップ領域は見た目より上下左右 2pt 広く取る（SPEC 10）。
            .padding(SplitKanaTuning.touchOutset)
            .contentShape(Rectangle())
            .gesture(dragGesture)
            .position(x: placed.rect.midX, y: placed.rect.midY)
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                isPressed = true
                direction = FlickResolver.direction(
                    translation: value.translation,
                    threshold: flickThreshold
                )
                if flickSet != nil {
                    onFlickChange(placed, direction)
                }
            }
            .onEnded { value in
                let finalDirection = FlickResolver.direction(
                    translation: value.translation,
                    threshold: flickThreshold
                )
                emit(finalDirection)
                isPressed = false
                direction = .center
                onFlickChange(nil, .center)
            }
    }

    private func emit(_ direction: FlickDirection) {
        if let flickSet = flickSet {
            onOutput(.insert(flickSet.character(for: direction)))
        } else {
            // フリックを持たないキーは方向を無視する。
            onOutput(placed.key.kind.baseOutput)
        }
    }
}
#endif
