import SwiftUI

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

    @State private var activeKeyID: String?

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
                    .zIndex(panel.keys.contains { $0.id == activeKeyID } ? 1 : 0)
            }
        }
        .frame(width: geometry.containerSize.width, height: geometry.containerSize.height, alignment: .topLeading)
    }

    private func panelView(_ panel: PanelGeometry) -> some View {
        ZStack(alignment: .topLeading) {
            ForEach(panel.keys) { placed in
                KeyView(
                    placed: placed,
                    gap: geometry.gapX,
                    flickThreshold: configuration.flickThreshold,
                    palette: palette,
                    onOutput: onOutput,
                    onActiveChange: { activeKeyID = $0 }
                )
                .zIndex(placed.id == activeKeyID ? 1 : 0)
            }
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
