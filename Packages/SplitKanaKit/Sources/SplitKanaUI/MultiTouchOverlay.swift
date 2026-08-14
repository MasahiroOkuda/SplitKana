#if canImport(SwiftUI) && canImport(UIKit)
import SwiftUI
import UIKit

/// 生のタッチを指ごとにそのまま流すだけのビュー。
///
/// SwiftUI の `DragGesture` は別々のビューでも**同時には成立しない**。
/// 両手の親指で同時に打つと片方が落ちる。分割キーボードでは致命的なので、
/// UIKit のマルチタッチを直接受け取る。
///
/// どのキーに当たったかはここでは見ない。`KeyboardGeometry.hitTest` が
/// 計算済みの矩形で決める。ビューの重なりに依存しないので、指ごとに独立して解ける。
struct MultiTouchOverlay: UIViewRepresentable {

    enum Phase { case began, moved, ended, cancelled }

    /// 指の識別子と、このビュー内での座標。
    let onTouch: (Phase, ObjectIdentifier, CGPoint) -> Void

    func makeUIView(context: Context) -> TouchRelayView {
        let view = TouchRelayView()
        view.onTouch = onTouch
        return view
    }

    func updateUIView(_ uiView: TouchRelayView, context: Context) {
        uiView.onTouch = onTouch
    }

    final class TouchRelayView: UIView {
        var onTouch: ((Phase, ObjectIdentifier, CGPoint) -> Void)?

        /// **完全に透明にしてはいけない。**
        ///
        /// `backgroundColor = .clear` にすると、このビューにタッチが一切配送されない
        /// （実機で確認済み。`.contentShape(Rectangle())` を足しても直らない。
        /// あれは SwiftUI 側のジェスチャにしか効かず、子 UIView への配送は変えられない）。
        /// UIKit がヒットテストで見るのは `view.alpha` であって背景色ではないはずだが、
        /// SwiftUI 経由で載せた場合は中身が透明だと素通しになる。
        ///
        /// そこで、目には見えないが透明ではない色を敷く。
        /// `alpha` は UIKit のヒットテストのしきい値 0.01 より上に取る。
        static let hitTestableTint = UIColor(white: 0, alpha: 0.02)

        override init(frame: CGRect) {
            super.init(frame: frame)
            isMultipleTouchEnabled = true
            isUserInteractionEnabled = true
            backgroundColor = Self.hitTestableTint
        }

        required init?(coder: NSCoder) { fatalError("コードからは生成しない") }

        private func relay(_ phase: Phase, _ touches: Set<UITouch>) {
            guard let onTouch = onTouch else { return }
            for touch in touches {
                onTouch(phase, ObjectIdentifier(touch), touch.location(in: self))
            }
        }

        override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) { relay(.began, touches) }
        override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) { relay(.moved, touches) }
        override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) { relay(.ended, touches) }
        override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) { relay(.cancelled, touches) }
    }
}
#endif
