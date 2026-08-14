import Foundation
import CoreGraphics
import SplitKanaCore

/// 拡張の設定の読み書き。
///
/// **保存先は拡張自身の `UserDefaults`。**App Group はフルアクセスが要るので使わない（SPEC 4）。
/// そのためホストアプリとは値を共有しない。これは仕様どおり。
///
/// `SplitKanaCore` にファイル保存を入れない方針なので、読み書きはここが持つ（README の責務境界）。
///
/// **値は端末クラスごとに分けて保存する。**iPhone 横と iPad 横では
/// 効く寸法がまったく違うので、ひとつの値を共有すると調整が噛み合わない。
enum KeyboardSettings {

    /// 調整できる項目。**数値で決まるものはすべてここに出す。**
    /// コード変更が要るのは新機能と不具合修正だけにするため（instruction.md）。
    enum Field: String, CaseIterable {
        case scale
        case topPadding
        case bottomInset
        case sideInset
        case flickThreshold

        var title: String {
            switch self {
            case .scale:          return "大きさ"
            case .topPadding:     return "上の余白"
            case .bottomInset:    return "下の浮き"
            case .sideInset:      return "左右位置"
            case .flickThreshold: return "フリック"
            }
        }

        var range: ClosedRange<Double> {
            switch self {
            case .scale:
                let r = KeyboardConfiguration.scaleRange
                return Double(r.lowerBound)...Double(r.upperBound)
            case .topPadding:     return 0...80
            case .bottomInset:    return 0...80
            case .sideInset:      return 0...120
            case .flickThreshold: return 6...40
            }
        }

        var step: Double { self == .scale ? 0.01 : 1 }

        func readout(_ value: Double) -> String {
            self == .scale ? String(format: "%.2f", value) : "\(Int(value))pt"
        }
    }

    // MARK: - 読み

    static func configuration(
        for deviceClass: DeviceClass,
        from defaults: UserDefaults = .standard
    ) -> KeyboardConfiguration {
        var configuration = KeyboardConfiguration.keyboardExtension
        let base = deviceClass.baseMetrics

        configuration.scale = value(.scale, deviceClass, defaults)
            .map { CGFloat($0) } ?? KeyboardConfiguration.defaultScale
        configuration.topPadding = value(.topPadding, deviceClass, defaults)
            .map { CGFloat($0) } ?? base.topPadding
        configuration.bottomInset = value(.bottomInset, deviceClass, defaults)
            .map { CGFloat($0) } ?? (KeyboardConfiguration.defaultBottomInset ?? 0)
        configuration.sideInset = value(.sideInset, deviceClass, defaults)
            .map { CGFloat($0) } ?? base.sideInset
        configuration.flickThreshold = value(.flickThreshold, deviceClass, defaults)
            .map { CGFloat($0) } ?? SplitKanaTuning.flickThreshold
        configuration.showsDuplicateColumn = duplicateColumn(deviceClass, defaults)

        return configuration
    }

    /// スライダーに出す現在値。保存が無ければ既定値。
    static func current(
        _ field: Field,
        for deviceClass: DeviceClass,
        from defaults: UserDefaults = .standard
    ) -> Double {
        if let saved = value(field, deviceClass, defaults) { return saved }
        return defaultValue(field, for: deviceClass)
    }

    static func defaultValue(_ field: Field, for deviceClass: DeviceClass) -> Double {
        let base = deviceClass.baseMetrics
        switch field {
        case .scale:          return Double(KeyboardConfiguration.defaultScale)
        case .topPadding:     return Double(base.topPadding)
        case .bottomInset:    return Double(KeyboardConfiguration.defaultBottomInset ?? 0)
        case .sideInset:      return Double(base.sideInset)
        case .flickThreshold: return Double(SplitKanaTuning.flickThreshold)
        }
    }

    static func duplicateColumn(
        _ deviceClass: DeviceClass,
        _ defaults: UserDefaults = .standard
    ) -> Bool {
        let key = key("showsDuplicateColumn", deviceClass)
        guard defaults.object(forKey: key) != nil else { return true }
        return defaults.bool(forKey: key)
    }

    /// かな漢字変換を使うか。既定は入り（true）。
    ///
    /// **切れるようにしてあるのは保険。**変換が重い・感触が合わないと分かっても
    /// Mac を返した後では作り直せないので、その場で素のかな入力に戻せる逃げ道を残す。
    static func conversionEnabled(
        _ deviceClass: DeviceClass,
        _ defaults: UserDefaults = .standard
    ) -> Bool {
        let key = key("conversionEnabled", deviceClass)
        guard defaults.object(forKey: key) != nil else { return true }
        return defaults.bool(forKey: key)
    }

    // MARK: - 書き

    static func save(
        _ field: Field,
        _ value: Double,
        for deviceClass: DeviceClass,
        to defaults: UserDefaults = .standard
    ) {
        defaults.set(value, forKey: key(field.rawValue, deviceClass))
    }

    static func saveDuplicateColumn(
        _ shows: Bool,
        for deviceClass: DeviceClass,
        to defaults: UserDefaults = .standard
    ) {
        defaults.set(shows, forKey: key("showsDuplicateColumn", deviceClass))
    }

    static func saveConversionEnabled(
        _ enabled: Bool,
        for deviceClass: DeviceClass,
        to defaults: UserDefaults = .standard
    ) {
        defaults.set(enabled, forKey: key("conversionEnabled", deviceClass))
    }

    /// この端末クラスぶんだけ既定値に戻す。他の端末クラスの調整は消さない。
    static func reset(for deviceClass: DeviceClass, in defaults: UserDefaults = .standard) {
        for field in Field.allCases {
            defaults.removeObject(forKey: key(field.rawValue, deviceClass))
        }
        defaults.removeObject(forKey: key("showsDuplicateColumn", deviceClass))
        defaults.removeObject(forKey: key("conversionEnabled", deviceClass))
    }

    // MARK: -

    private static func key(_ name: String, _ deviceClass: DeviceClass) -> String {
        "splitkana.\(deviceClass.rawValue).\(name)"
    }

    private static func value(
        _ field: Field,
        _ deviceClass: DeviceClass,
        _ defaults: UserDefaults
    ) -> Double? {
        let key = key(field.rawValue, deviceClass)
        guard defaults.object(forKey: key) != nil else { return nil }
        return defaults.double(forKey: key)
    }
}
