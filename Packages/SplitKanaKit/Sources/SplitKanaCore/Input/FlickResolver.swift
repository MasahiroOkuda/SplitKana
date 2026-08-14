import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif

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

    /// ポップアップの1項目の大きさ（キー寸法に対する比率）。
    public static let popupItemRatio: CGFloat = 0.86

    /// ポップアップの内側余白。左右・上下に同じだけ入る。
    public static let popupPadding: CGFloat = 4

    /// ⌫ を押しっぱなしにしてから連続削除が始まるまで。
    /// 短すぎると1文字消すつもりが走り出す。
    public static let repeatDelay: TimeInterval = 0.4

    /// 連続削除の間隔。
    public static let repeatInterval: TimeInterval = 0.07

    /// 空白キーの左フリックで入れる文字。
    /// 日本語の文章では全角のほうを使うことが多い。
    public static let fullWidthSpace = "\u{3000}"
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
