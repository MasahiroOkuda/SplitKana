#if canImport(SwiftUI) && canImport(UIKit)
import SwiftUI
import SplitKanaCore

/// 分割かなキーボード本体。
///
/// このビューは**コンテナ全面**を占める。左右のパネルは計算済みの矩形に絶対配置され、
/// 中央（`geometry.freeRegion`）には何も置かない。ホストがそこを自由に使う。
///
/// **両手の親指の同時押しに対応している。**キーはタッチを受け取らず、
/// パネルごとに敷いた `MultiTouchOverlay` が生のタッチを指ごとに流し、
/// `KeyboardGeometry.hitTest` が当たりを決める。
/// タッチ判定をビューの重なりから切り離してあるので、指の数だけ独立して解ける。
///
/// `KeyOutput` を出すだけで、テキストがどこへ行くかは知らない（SPEC 1）。
public struct SplitKanaKeyboardView: View {

    private struct Finger {
        let start: CGPoint
        let hit: KeyHit
        var direction: FlickDirection
    }

    private let geometry: KeyboardGeometry
    private let configuration: KeyboardConfiguration
    private let palette: KeyPalette
    private let onOutput: (KeyOutput) -> Void

    @State private var fingers: [ObjectIdentifier: Finger] = [:]

    public init(
        geometry: KeyboardGeometry,
        configuration: KeyboardConfiguration,
        palette: KeyPalette = .standard,
        onOutput: @escaping (KeyOutput) -> Void
    ) {
        self.geometry = geometry
        self.configuration = configuration
        self.palette = palette
        self.onOutput = onOutput
    }

    public var body: some View {
        ZStack(alignment: .topLeading) {
            ForEach(geometry.panels) { panel in
                panelView(panel)
                    .frame(width: panel.frame.width, height: panel.frame.height)
                    .offset(x: panel.frame.minX, y: panel.frame.minY)
            }
            // ポップアップはパネルより上のレイヤに描く。
            // パネルの外側に固定されるので、どのキーにも重ならない。
            popupLayer
            touchLayer
        }
        .frame(width: geometry.containerSize.width,
               height: geometry.containerSize.height,
               alignment: .topLeading)
    }

    private func panelView(_ panel: PanelGeometry) -> some View {
        ZStack(alignment: .topLeading) {
            ForEach(panel.keys) { placed in
                KeyView(
                    placed: placed,
                    palette: palette,
                    pressedDirection: direction(forKey: placed.id)
                )
            }
        }
    }

    /// パネルごとに1つ。同じパネルを2本の指で押すことは想定しない（親指は片側に1本）。
    @ViewBuilder
    private var popupLayer: some View {
        ForEach(geometry.panels) { panel in
            if let finger = fingers.values.first(where: {
                   $0.hit.panelID == panel.id && $0.hit.key.kind.flickSet != nil
               }),
               let flickSet = finger.hit.key.kind.flickSet,
               let placement = geometry.popupPlacement(for: finger.hit, itemCount: flickSet.assigned.count) {
                FlickPopupView(
                    flickSet: flickSet,
                    selected: finger.direction,
                    itemWidth: placement.itemWidth,
                    itemHeight: placement.itemHeight,
                    palette: palette
                )
                .frame(width: placement.rect.width, height: placement.rect.height)
                .offset(x: placement.rect.minX, y: placement.rect.minY)
                .allowsHitTesting(false)
            }
        }
    }

    /// パネルの上だけに敷く。中央の空きはホストのものなので塞がない。
    private var touchLayer: some View {
        let outset = SplitKanaTuning.touchOutset
        return ForEach(geometry.panels) { panel in
            MultiTouchOverlay { phase, id, local in
                handle(phase, id, CGPoint(x: panel.frame.minX - outset + local.x,
                                          y: panel.frame.minY - outset + local.y))
            }
            .frame(width: panel.frame.width + outset * 2,
                   height: panel.frame.height + outset * 2)
            .offset(x: panel.frame.minX - outset, y: panel.frame.minY - outset)
        }
    }

    // MARK: - タッチ

    private func direction(forKey id: String) -> FlickDirection? {
        fingers.values.first { $0.hit.keyID == id }?.direction
    }

    private func handle(_ phase: MultiTouchOverlay.Phase, _ id: ObjectIdentifier, _ point: CGPoint) {
        switch phase {
        case .began:
            guard let hit = geometry.hitTest(point) else { return }
            fingers[id] = Finger(start: point, hit: hit, direction: .center)

        case .moved:
            guard var finger = fingers[id] else { return }
            finger.direction = FlickResolver.direction(
                translation: CGSize(width: point.x - finger.start.x,
                                    height: point.y - finger.start.y),
                threshold: configuration.flickThreshold
            )
            fingers[id] = finger

        case .ended:
            guard let finger = fingers.removeValue(forKey: id) else { return }
            emit(finger)

        case .cancelled:
            fingers.removeValue(forKey: id)
        }
    }

    private func emit(_ finger: Finger) {
        if let flickSet = finger.hit.key.kind.flickSet {
            onOutput(.insert(flickSet.character(for: finger.direction)))
        } else {
            // フリックを持たないキーは方向を無視する。
            onOutput(finger.hit.key.kind.baseOutput)
        }
    }
}

/// コンテナ寸法を自分で測る版。キーボード拡張（フェーズ2）はこちらを使う想定。
public struct AutoSplitKanaKeyboardView: View {

    private let configuration: KeyboardConfiguration
    private let palette: KeyPalette
    private let onOutput: (KeyOutput) -> Void

    public init(
        configuration: KeyboardConfiguration,
        palette: KeyPalette = .standard,
        onOutput: @escaping (KeyOutput) -> Void
    ) {
        self.configuration = configuration
        self.palette = palette
        self.onOutput = onOutput
    }

    public var body: some View {
        GeometryReader { proxy in
            let geometry = KeyboardGeometry.make(
                containerSize: proxy.size,
                safeArea: SafeAreaInsets(proxy.safeAreaInsets),
                isPad: DeviceIdiom.isPad,
                configuration: configuration
            )
            SplitKanaKeyboardView(
                geometry: geometry,
                configuration: configuration,
                palette: palette,
                onOutput: onOutput
            )
        }
    }
}
#endif
