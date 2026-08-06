import SwiftUI

/// キー1つ。押下中はフリック方向を追い、離した瞬間に `KeyOutput` を1つだけ出す。
///
/// 複製キーかどうかは**見た目にしか効かない**。出力は完全に同一（SPEC 2.1 / 10）。
struct KeyView: View {

    let placed: PlacedKey
    let gap: CGFloat
    let flickThreshold: CGFloat
    let palette: KeyPalette
    let onOutput: (KeyOutput) -> Void
    let onActiveChange: (String?) -> Void

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

    /// 押下中に見せる文字。フリック方向の文字をキー上でも先に見せる。
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
            .overlay(alignment: .center) { popup }
            // タップ領域は見た目より上下左右 2pt 広く取る（SPEC 10）。
            .padding(SplitKanaTuning.touchOutset)
            .contentShape(Rectangle())
            .gesture(dragGesture)
            .position(x: placed.rect.midX, y: placed.rect.midY)
            .zIndex(isPressed ? 1 : 0)
    }

    @ViewBuilder
    private var popup: some View {
        if isPressed, let flickSet = flickSet {
            let itemWidth = placed.rect.width * 0.86
            let itemHeight = min(placed.rect.height, placed.rect.width) * 0.86
            let popupWidth = FlickPopupView.width(for: flickSet, itemWidth: itemWidth)
            let distance = (placed.rect.width + popupWidth) / 2 + gap
            FlickPopupView(
                flickSet: flickSet,
                selected: direction,
                itemWidth: itemWidth,
                itemHeight: itemHeight,
                palette: palette
            )
            .offset(x: placed.popupSide == .trailing ? distance : -distance)
            .transition(.opacity)
        }
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                if !isPressed {
                    isPressed = true
                    onActiveChange(placed.id)
                }
                direction = FlickResolver.direction(
                    translation: value.translation,
                    threshold: flickThreshold
                )
            }
            .onEnded { value in
                let finalDirection = FlickResolver.direction(
                    translation: value.translation,
                    threshold: flickThreshold
                )
                emit(finalDirection)
                isPressed = false
                direction = .center
                onActiveChange(nil)
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
