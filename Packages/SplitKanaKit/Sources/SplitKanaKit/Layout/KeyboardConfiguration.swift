import CoreGraphics

/// ホストから受け取る設定（SPEC 2.2 / 3.1）。
public struct KeyboardConfiguration: Equatable, Sendable {

    public static let scaleRange: ClosedRange<CGFloat> = 0.80...1.45
    public static let defaultScale: CGFloat = 1.10

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

    public init(
        functionColumn: [FunctionKey],
        showsDuplicateColumn: Bool = true,
        scale: CGFloat = KeyboardConfiguration.defaultScale,
        bottomInset: CGFloat? = nil,
        flickThreshold: CGFloat = SplitKanaTuning.flickThreshold
    ) {
        self.functionColumn = functionColumn
        self.showsDuplicateColumn = showsDuplicateColumn
        self.scale = scale
        self.bottomInset = bottomInset
        self.flickThreshold = flickThreshold
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

    /// 思考整理アプリ／確認用ホスト向けの機能列（SPEC 2.2）。
    static var hostApp: KeyboardConfiguration {
        KeyboardConfiguration(functionColumn: [
            FunctionKey(title: "結ぶ", output: .custom("connect")),
            FunctionKey(title: "囲む", output: .custom("enclose")),
            FunctionKey(title: "選ぶ", output: .custom("select")),
            FunctionKey(title: "英数", output: .custom("alphanumeric"))
        ])
    }

    /// キーボード拡張向けの機能列（SPEC 2.2）。フェーズ2で使う。
    ///
    /// 地球キーは拡張では必須。カーソルキーは `adjustTextPosition(byCharacterOffset:)` に落とす。
    static var keyboardExtension: KeyboardConfiguration {
        KeyboardConfiguration(functionColumn: [
            FunctionKey(title: "🌐", output: .nextInputMode),
            FunctionKey(title: "英数", output: .custom("alphanumeric")),
            FunctionKey(title: "◀", output: .cursor(-1)),
            FunctionKey(title: "▶", output: .cursor(1))
        ])
    }
}
