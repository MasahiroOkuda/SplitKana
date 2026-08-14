import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif

/// かなを打つか英数を打つか。
///
/// かなは**列**で組み、英数は**行**で組む。行ごとにキー数が違って半キーずれるので、
/// 同じ組み方では表現できない（SPEC 2.6）。
public enum InputMode: String, Equatable, Sendable {
    case kana
    case latin
}

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

    /// かなを打つか、英数を打つか。
    public var mode: InputMode

    /// 英数モードで次の1文字を大文字にするか。
    public var isShifted: Bool

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
        sideInset: CGFloat? = nil,
        mode: InputMode = .kana,
        isShifted: Bool = false
    ) {
        self.functionColumn = functionColumn
        self.showsDuplicateColumn = showsDuplicateColumn
        self.scale = scale
        self.bottomInset = bottomInset
        self.flickThreshold = flickThreshold
        self.topPadding = topPadding
        self.sideInset = sideInset
        self.mode = mode
        self.isShifted = isShifted
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

    /// 設定パネルの開閉。拡張は `UIAlertController` を出せないので、
    /// 設定はキーボードの中にパネルとして持つ（SPEC 4）。
    static let settingsOutput = KeyOutput.custom("settings")

    /// 英数モードへ切り替える。
    static let latinModeOutput = KeyOutput.custom("latin")
    /// かなモードへ戻す。
    static let kanaModeOutput = KeyOutput.custom("kana")
    /// ⇧。次の1文字を大文字にする。続けて押すと固定。
    static let shiftOutput = KeyOutput.custom("shift")

    /// キーボード拡張向けの機能列（SPEC 2.2）。
    ///
    /// 地球キーは拡張では必須。席は4つしか無いので、カーソルは1キーに集約してある。
    static var keyboardExtension: KeyboardConfiguration {
        KeyboardConfiguration(functionColumn: [
            FunctionKey(title: "🌐", output: .nextInputMode),
            FunctionKey(title: "⚙", output: KeyboardConfiguration.settingsOutput),
            // **1つのキーで左右を兼ねる。**左右に振ってカーソルを動かす。
            // 席が4つしか無いので、◀▶ で2つ使うと英数のぶんが残らない。
            // タップは何もしない（動かす向きが決まらないため）。
            FunctionKey(
                title: "◀▶",
                output: .custom("noop"),
                flickOutputs: [.left: .cursor(-1), .right: .cursor(1)]
            ),
            FunctionKey(title: "英数", output: KeyboardConfiguration.latinModeOutput)
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
