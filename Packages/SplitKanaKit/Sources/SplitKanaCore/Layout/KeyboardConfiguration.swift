import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif

/// ホストから受け取る設定（SPEC 2.2 / 3.1）。
public struct KeyboardConfiguration: Equatable, Sendable {

    /// 下限は実測で 0.80 より小さくしたくなったため広げた。
    /// 分割の成否には影響しない（`KeyboardGeometry.make` の fitScale が別に見ている）。
    public static let scaleRange: ClosedRange<CGFloat> = 0.60...1.45

    /// Web プロトタイプでの実測値（SPEC 11）。
    public static let defaultScale: CGFloat = 0.80

    /// 同じく実測値。**端末別の既定値は使わず 0 で固定する**（SPEC 11）。
    /// ホームインジケータぶんは `safeArea.bottom` が別に確保するので、0 でも重ならない。
    public static let defaultBottomInset: CGFloat? = 0

    /// 左の機能列。4キー。多ければ切り、少なければ空きキーで埋める。
    public var functionColumn: [FunctionKey]

    /// 右パネルの複製列（あ列）を出すか。false なら右パネルは3列（SPEC 2.1）。
    public var showsDuplicateColumn: Bool

    /// キーの大きさ倍率。0.80〜1.45。
    public var scale: CGFloat

    /// 下端からの浮かせ量。nil なら端末別の既定値（SPEC 3.4）。
    public var bottomInset: CGFloat?

    /// フリック判定しきい値。
    public var flickThreshold: CGFloat

    /// キーの上に足す余白。nil なら端末別の既定値。
    ///
    /// **キーの大きさは変えずにキーボード全体の高さだけを変える**ためのつまみ（SPEC 11）。
    /// 下端側は `bottomInset` が受け持つので、こちらは上だけ。
    public var topPadding: CGFloat?

    /// 画面端とパネルの間。nil なら端末別の既定値。
    ///
    /// 左右パネルの左右位置を決める。握り位置に合わせて内側／外側に寄せる。
    public var sideInset: CGFloat?

    public init(
        functionColumn: [FunctionKey],
        showsDuplicateColumn: Bool = true,
        scale: CGFloat = KeyboardConfiguration.defaultScale,
        bottomInset: CGFloat? = KeyboardConfiguration.defaultBottomInset,
        flickThreshold: CGFloat = SplitKanaTuning.flickThreshold,
        topPadding: CGFloat? = nil,
        sideInset: CGFloat? = nil
    ) {
        self.functionColumn = functionColumn
        self.showsDuplicateColumn = showsDuplicateColumn
        self.scale = scale
        self.bottomInset = bottomInset
        self.flickThreshold = flickThreshold
        self.topPadding = topPadding
        self.sideInset = sideInset
    }

    /// 常に4キーに揃えた機能列。
    public var normalizedFunctionColumn: [FunctionKey] {
        var keys = Array(functionColumn.prefix(4))
        while keys.count < 4 {
            keys.append(FunctionKey(title: "", output: .custom("noop")))
        }
        return keys
    }

    public var clampedScale: CGFloat {
        min(max(scale, Self.scaleRange.lowerBound), Self.scaleRange.upperBound)
    }
}

public extension KeyboardConfiguration {

    /// キーボード拡張向けの機能列（SPEC 2.2）。
    ///
    /// 地球キーは拡張では必須。カーソルキーは両手が塞がった状態で動かせるので、
    /// 確認用ホストでもこの構成を使う（🌐 と英数はホストでは表示のみ）。
    /// 設定パネルの開閉。拡張は `UIAlertController` を出せないので、
    /// 設定はキーボードの中にパネルとして持つ（SPEC 4）。
    static let settingsOutput = KeyOutput.custom("settings")

    static var keyboardExtension: KeyboardConfiguration {
        KeyboardConfiguration(functionColumn: [
            FunctionKey(title: "🌐", output: .nextInputMode),
            // 英数は未実装で押しても何も起きなかったので、ここを ⚙ に充てた。
            // ◀▶ は両手が塞がったままカーソルを動かせる利点があるので残す（SPEC 2.2）。
            FunctionKey(title: "⚙", output: KeyboardConfiguration.settingsOutput),
            FunctionKey(title: "◀", output: .cursor(-1)),
            FunctionKey(title: "▶", output: .cursor(1))
        ])
    }

    /// 思考整理アプリ向けの機能列（SPEC 2.2）。フェーズ5以降で使う。
    static var thinkingApp: KeyboardConfiguration {
        KeyboardConfiguration(functionColumn: [
            FunctionKey(title: "結ぶ", output: .custom("connect")),
            FunctionKey(title: "囲む", output: .custom("enclose")),
            FunctionKey(title: "選ぶ", output: .custom("select")),
            FunctionKey(title: "英数", output: .custom("alphanumeric"))
        ])
    }
}
