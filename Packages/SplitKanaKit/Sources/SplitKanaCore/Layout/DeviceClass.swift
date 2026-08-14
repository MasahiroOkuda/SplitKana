import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif

/// 端末別の初期値（SPEC 3.2）。
///
/// **表の値は「倍率1.0のときの寸法」として持つ。**実寸は必ずコンテナ寸法から計算し直す。
public struct BaseMetrics: Sendable {
    public let keyWidth: CGFloat
    public let keyHeight: CGFloat
    public let gapX: CGFloat
    public let gapY: CGFloat
    /// 画面端とパネルの間
    public let sideInset: CGFloat
    /// キーボード上端の余白
    public let topPadding: CGFloat
    /// 下端からの浮かせ量の既定値
    public let bottomInset: CGFloat

    /// 設定で上書きできるものを差し替えた寸法。
    ///
    /// 上書きは `nil` なら端末別の既定値のまま。こうしておくと、
    /// 計算側は「既定値か設定値か」を気にせず `base` を読むだけで済む。
    func applying(_ configuration: KeyboardConfiguration) -> BaseMetrics {
        BaseMetrics(
            keyWidth: keyWidth,
            keyHeight: keyHeight,
            gapX: gapX,
            gapY: gapY,
            sideInset: configuration.sideInset ?? sideInset,
            topPadding: configuration.topPadding ?? topPadding,
            bottomInset: bottomInset
        )
    }
}

public enum DeviceClass: String, Sendable {
    case phoneLandscape
    case phonePortrait
    case padPortrait
    case padLandscape

    public static func resolve(containerSize: CGSize, isPad: Bool) -> DeviceClass {
        let isLandscape = containerSize.width >= containerSize.height
        if isPad {
            return isLandscape ? .padLandscape : .padPortrait
        }
        return isLandscape ? .phoneLandscape : .phonePortrait
    }

    public var baseMetrics: BaseMetrics {
        switch self {
        case .phoneLandscape:
            // 844 × 390 想定。キー 64 × 59。
            return BaseMetrics(keyWidth: 64, keyHeight: 59, gapX: 6, gapY: 6,
                               sideInset: 8, topPadding: 8, bottomInset: 8)
        case .phonePortrait:
            // 390 幅。分割せず5列（SPEC 3.3）。
            return BaseMetrics(keyWidth: 70, keyHeight: 54, gapX: 5, gapY: 5,
                               sideInset: 6, topPadding: 6, bottomInset: 4)
        case .padPortrait:
            // 820 × 1180 想定。キー 72 × 64。iPad は握り位置が下から1/3なので浮かせる（SPEC 3.4）。
            return BaseMetrics(keyWidth: 72, keyHeight: 64, gapX: 8, gapY: 8,
                               sideInset: 16, topPadding: 12, bottomInset: 24)
        case .padLandscape:
            // 1180 × 820 想定。キー 78 × 70。中央が最も広く空く。
            return BaseMetrics(keyWidth: 78, keyHeight: 70, gapX: 8, gapY: 8,
                               sideInset: 20, topPadding: 12, bottomInset: 24)
        }
    }

    /// このクラスで分割を試みるか。iPhone 縦は試さない（SPEC 3.3）。
    /// 実際に分割するかは中央の空き幅を見て `KeyboardGeometry` が決める。
    public var attemptsSplit: Bool {
        self != .phonePortrait
    }
}
