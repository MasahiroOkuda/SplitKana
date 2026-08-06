import SwiftUI
import SplitKanaKit

struct HostRootView: View {

    @State private var buffer = KanaTextBuffer()
    @State private var stats = TypingStats()
    @State private var lastCustomOutput: String?
    @State private var configuration = KeyboardConfiguration.hostApp

    var body: some View {
        GeometryReader { proxy in
            let geometry = KeyboardGeometry.make(
                containerSize: proxy.size,
                safeArea: SafeAreaInsets(proxy.safeAreaInsets),
                isPad: DeviceIdiom.isPad,
                configuration: configuration
            )
            let region = transcriptRegion(for: geometry, in: proxy)

            ZStack(alignment: .topLeading) {
                Color(white: 0.93).ignoresSafeArea()

                TranscriptView(
                    buffer: buffer,
                    stats: stats,
                    lastCustomOutput: lastCustomOutput,
                    onClear: clear
                )
                .frame(width: region.width, height: region.height)
                .offset(x: region.minX, y: region.minY)

                SplitKanaKeyboardView(
                    geometry: geometry,
                    configuration: configuration,
                    onOutput: handle
                )
            }
        }
        .ignoresSafeArea()
    }

    /// キーが1つもない領域から、セーフエリアぶんだけ内側に寄せた矩形。
    private func transcriptRegion(for geometry: KeyboardGeometry, in proxy: GeometryProxy) -> CGRect {
        let free = geometry.freeRegion
        let top = proxy.safeAreaInsets.top + 8
        // 分割時は中央の帯が画面下端まで伸びるので、ホームインジケータぶんを避ける。
        let bottom = (geometry.isSplit ? proxy.safeAreaInsets.bottom : 0) + 8
        return CGRect(
            x: free.minX,
            y: free.minY + top,
            width: max(0, free.width),
            height: max(0, free.height - top - bottom)
        )
    }

    private func handle(_ output: KeyOutput) {
        stats.record(output)
        if buffer.apply(output) {
            lastCustomOutput = nil
            return
        }
        // バッファが扱わない出力（機能列の custom など）はホストの仕事。
        // フェーズ1では受け取ったことを見せるだけにする。
        if case .custom(let name) = output {
            lastCustomOutput = name
        }
    }

    private func clear() {
        buffer.reset()
        stats.reset()
        lastCustomOutput = nil
    }
}

#Preview("iPhone 横") {
    HostRootView()
}
