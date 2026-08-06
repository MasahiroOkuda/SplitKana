import SwiftUI
import SplitKanaCore
import SplitKanaUI

struct HostRootView: View {

    @State private var buffer = KanaTextBuffer()
    @State private var stats = TypingStats()
    @State private var notice: String?
    /// 機能列は拡張と同じ 🌐 / 英数 / ◀ / ▶。
    /// ◀▶ はここで効く。🌐 と英数はフェーズ1では表示のみ。
    @State private var configuration = KeyboardConfiguration.keyboardExtension

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
                    notice: notice,
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
            notice = nil
            return
        }

        // バッファが扱わない出力。フェーズ1では受け取ったことを見せるだけ。
        switch output {
        case .nextInputMode:
            notice = "🌐 はキーボード拡張でのみ動く（フェーズ2）"
        case .custom("alphanumeric"):
            notice = "英数モードは未実装"
        case .custom(let name):
            notice = "custom: \(name)"
        case .dakuten:
            notice = nil   // 巡回対象でない文字。無反応でよい
        default:
            notice = nil
        }
    }

    private func clear() {
        buffer.reset()
        stats.reset()
        notice = nil
    }
}

#Preview("iPhone 横") {
    HostRootView()
}
