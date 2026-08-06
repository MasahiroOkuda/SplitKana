#if canImport(SwiftUI)
import SwiftUI
import SplitKanaCore

/// 分割かなキーボード本体。
///
/// このビューは**コンテナ全面**を占める。左右のパネルは計算済みの矩形に絶対配置され、
/// 中央（`geometry.freeRegion`）には何も置かない。ホストがそこを自由に使う。
///
/// `KeyOutput` を出すだけで、テキストがどこへ行くかは知らない（SPEC 1）。
public struct SplitKanaKeyboardView: View {

    private let geometry: KeyboardGeometry
    private let configuration: KeyboardConfiguration
    private let palette: KeyPalette
    private let onOutput: (KeyOutput) -> Void

    @State private var activeKey: PlacedKey?
    @State private var activeDirection: FlickDirection = .center

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
            // ポップアップはパネルより上のレイヤに1つだけ描く。
            // パネルの外側に固定されるので、どのキーにも重ならない。
            popupLayer
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
                    flickThreshold: configuration.flickThreshold,
                    palette: palette,
                    onOutput: onOutput,
                    onFlickChange: { key, direction in
                        activeKey = key
                        activeDirection = direction
                    }
                )
            }
        }
    }

    @ViewBuilder
    private var popupLayer: some View {
        if let activeKey = activeKey,
           let flickSet = activeKey.key.kind.flickSet,
           let placement = geometry.popupPlacement(for: activeKey, itemCount: flickSet.assigned.count) {
            FlickPopupView(
                flickSet: flickSet,
                selected: activeDirection,
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
