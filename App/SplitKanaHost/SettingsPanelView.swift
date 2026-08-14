import SwiftUI
import SplitKanaCore

/// 実機で `scale` と `bottomInset` を詰めるための調整パネル（SPEC 11）。
///
/// フェーズ3の「キーボード内の設定パネル」とは別物で、**確認用ホスト専用**。
/// 値の保存はホスト側の仕事なので、ここでも `SplitKanaCore` にファイル保存は持ち込まない
/// （README の責務境界）。保存は呼び出し側の `@AppStorage` が持つ。
struct SettingsPanelView: View {

    @Binding var scale: Double
    @Binding var bottomInset: Double

    /// 下の浮かせ量の可動域。プロトタイプのスライダーと同じ 0〜60pt。
    static let bottomInsetRange: ClosedRange<Double> = 0...60

    static let defaultScale = Double(KeyboardConfiguration.defaultScale)
    static let defaultBottomInset = Double(KeyboardConfiguration.defaultBottomInset ?? 0)

    private var scaleRange: ClosedRange<Double> {
        let range = KeyboardConfiguration.scaleRange
        return Double(range.lowerBound)...Double(range.upperBound)
    }

    var body: some View {
        VStack(spacing: 6) {
            row("大きさ", value: $scale, range: scaleRange, step: 0.01,
                readout: String(format: "%.2f", scale))
            row("下の浮き", value: $bottomInset, range: Self.bottomInsetRange, step: 1,
                readout: "\(Int(bottomInset))pt")

            HStack(spacing: 8) {
                Text("実効倍率は画面に収まる範囲まで自動で下がる")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Spacer(minLength: 0)
                Button("既定に戻す", action: reset)
                    .font(.caption)
                    .buttonStyle(.bordered)
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(white: 1.0))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color(white: 0.82), lineWidth: 1)
        )
    }

    private func row(
        _ title: String,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        step: Double,
        readout: String
    ) -> some View {
        HStack(spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 56, alignment: .leading)
            Slider(value: value, in: range, step: step)
            Text(readout)
                .font(.system(size: 13, weight: .semibold))
                .monospacedDigit()
                .frame(width: 46, alignment: .trailing)
        }
    }

    private func reset() {
        scale = Self.defaultScale
        bottomInset = Self.defaultBottomInset
    }
}

#Preview {
    @Previewable @State var scale = SettingsPanelView.defaultScale
    @Previewable @State var bottomInset = SettingsPanelView.defaultBottomInset
    return SettingsPanelView(scale: $scale, bottomInset: $bottomInset)
        .padding()
        .background(Color(white: 0.93))
}
