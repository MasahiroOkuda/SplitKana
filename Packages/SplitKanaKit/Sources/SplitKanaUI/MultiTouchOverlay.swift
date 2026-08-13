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

        override init(frame: CGRect) {
            super.init(frame: frame)
            isMultipleTouchEnabled = true
            isUserInteractionEnabled = true
            backgroundColor = .clear
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
