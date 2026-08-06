import CoreGraphics

/// 実機で調整が要る定数（SPEC 2.3 / 10 / 11）。散らさずここに集める。
public enum SplitKanaTuning {
    /// フリック判定しきい値。初期値 18pt。
    public static let flickThreshold: CGFloat = 18

    /// タップ領域を見た目のキーより上下左右に広げる量。
    public static let touchOutset: CGFloat = 2

    /// 分割を成立させる最小の中央空きスペース。これを下回るなら分割しない。
    public static let minimumCenterGap: CGFloat = 80

    /// 画面に収めるために縮めてよい下限。ここを割るなら分割をやめて統合レイアウトへ落とす。
    public static let minimumSplitScale: CGFloat = 0.80
}

/// ドラッグ量からフリック方向を決める。
public enum FlickResolver {
    public static func direction(
        translation: CGSize,
        threshold: CGFloat = SplitKanaTuning.flickThreshold
    ) -> FlickDirection {
        let dx = translation.width
        let dy = translation.height
        guard max(abs(dx), abs(dy)) >= threshold else { return .center }
        if abs(dx) >= abs(dy) {
            return dx < 0 ? .left : .right
        } else {
            return dy < 0 ? .up : .down
        }
    }
}
