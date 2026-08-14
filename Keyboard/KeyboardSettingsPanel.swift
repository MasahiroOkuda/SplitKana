import SwiftUI
import SplitKanaCore

/// キーボードの中に持つ設定パネル（SPEC 4 / instruction.md フェーズ3）。
///
/// 拡張では `UIAlertController` を出せないので、別画面ではなくここに置く。
/// 中央の空き（`freeRegion`）に開くので、**キーには一切かぶらない。**
///
/// 値は変えた瞬間に保存し、キーボードが再レイアウトされる。
/// 端末クラスごとに別々に持つので、iPad 横で詰めても iPhone 縦には影響しない。
struct KeyboardSettingsPanel: View {

    let region: CGRect
    let deviceClass: DeviceClass
    /// 実際に適用された倍率。画面に収めるため設定値より小さくなることがあるので見せる。
    let appliedScale: CGFloat
    /// キーの上に重なる置き方か。重なるなら背景を透かさない。
    var isOpaque: Bool = false
    /// 値が変わったら呼ぶ。呼び出し側が読み直して再レイアウトする。
    let onChange: () -> Void
    let onClose: () -> Void

    @State private var values: [KeyboardSettings.Field: Double] = [:]
    @State private var showsDuplicateColumn = true

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            header

            ForEach(KeyboardSettings.Field.allCases, id: \.self) { field in
                row(field)
            }

            HStack(spacing: 10) {
                Toggle("複製列", isOn: duplicateBinding)
                    .font(.system(size: 12))
                    .toggleStyle(.switch)
                    .fixedSize()
                Spacer(minLength: 0)
                Button("既定に戻す", action: reset)
                    .font(.system(size: 12))
                    .buttonStyle(.bordered)
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(white: 0.98).opacity(isOpaque ? 1.0 : 0.97))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color(white: 0.75), lineWidth: 1)
        )
        .frame(width: region.width, height: region.height, alignment: .center)
        .offset(x: region.minX, y: region.minY)
        .onAppear(perform: load)
    }

    private var header: some View {
        HStack(spacing: 8) {
            Text(label(for: deviceClass))
                .font(.system(size: 12, weight: .semibold))
            Text("実効 \(String(format: "%.2f", appliedScale))")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .monospacedDigit()
            Spacer(minLength: 0)
            Button("閉じる", action: onClose)
                .font(.system(size: 12))
                .buttonStyle(.borderedProminent)
        }
    }

    private func row(_ field: KeyboardSettings.Field) -> some View {
        let value = values[field] ?? KeyboardSettings.defaultValue(field, for: deviceClass)
        return HStack(spacing: 8) {
            Text(field.title)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .frame(width: 54, alignment: .leading)
            Slider(
                value: binding(field),
                in: field.range,
                step: field.step
            )
            Text(field.readout(value))
                .font(.system(size: 12, weight: .semibold))
                .monospacedDigit()
                .frame(width: 46, alignment: .trailing)
        }
    }

    // MARK: -

    private func binding(_ field: KeyboardSettings.Field) -> Binding<Double> {
        Binding(
            get: { values[field] ?? KeyboardSettings.defaultValue(field, for: deviceClass) },
            set: { newValue in
                values[field] = newValue
                KeyboardSettings.save(field, newValue, for: deviceClass)
                onChange()
            }
        )
    }

    private var duplicateBinding: Binding<Bool> {
        Binding(
            get: { showsDuplicateColumn },
            set: { newValue in
                showsDuplicateColumn = newValue
                KeyboardSettings.saveDuplicateColumn(newValue, for: deviceClass)
                onChange()
            }
        )
    }

    private func load() {
        for field in KeyboardSettings.Field.allCases {
            values[field] = KeyboardSettings.current(field, for: deviceClass)
        }
        showsDuplicateColumn = KeyboardSettings.duplicateColumn(deviceClass)
    }

    private func reset() {
        KeyboardSettings.reset(for: deviceClass)
        load()
        onChange()
    }

    private func label(for deviceClass: DeviceClass) -> String {
        switch deviceClass {
        case .phoneLandscape: return "iPhone 横"
        case .phonePortrait:  return "iPhone 縦"
        case .padPortrait:    return "iPad 縦"
        case .padLandscape:   return "iPad 横"
        }
    }
}
