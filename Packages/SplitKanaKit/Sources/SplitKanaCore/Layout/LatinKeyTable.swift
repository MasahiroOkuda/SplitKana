import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif

/// 英数モードのキー配置（QWERTY）。
///
/// かなモードは**列**で組むが、こちらは**行**で組む。
/// 行ごとにキー数が違い、半キーずれるので、列に押し込むと表現できない。
///
/// ```
/// 左パネル                右パネル
/// Q  W  E  R  T           Y  U  I  O  P
///  A  S  D  F              G  H  J  K  L
/// ⇧  Z  X  C  V            B  N  M  ⌫
/// 🌐 ⚙ かな  ␣             ␣      改行
/// ```
///
/// 左右で 10 / 9 / 7 文字を分けている。標準の QWERTY と同じ並び。
public enum LatinKeyTable {

    /// 1行ぶん。
    public struct Row: Equatable, Sendable {
        public let keys: [KeyDescriptor]
        /// 左端からのずらし量。キー幅を1とした倍数。
        ///
        /// QWERTY の段差を出すために使う。段差が無いと英字配列に見えない。
        public let indent: CGFloat

        public init(_ keys: [KeyDescriptor], indent: CGFloat = 0) {
            self.keys = keys
            self.indent = indent
        }

        /// この行が占める幅。キー幅を1とした値。
        public var width: CGFloat {
            indent + keys.reduce(0) { $0 + CGFloat(max(1, $1.columnSpan)) }
        }
    }

    /// パネルの列数。左右とも5。行の中身が変わっても枠は変えない。
    public static let columns = 5

    public static func leftRows(shifted: Bool) -> [Row] {
        [
            Row(letters("qwert", shifted: shifted)),
            Row(letters("asdf", shifted: shifted), indent: 0.5),
            Row([KeyDescriptor(.shift)] + letters("zxcv", shifted: shifted)),
            Row([
                KeyDescriptor(.function(FunctionKey(title: "🌐", output: .nextInputMode))),
                KeyDescriptor(.function(FunctionKey(
                    title: "⚙", output: KeyboardConfiguration.settingsOutput))),
                KeyDescriptor(.function(FunctionKey(
                    title: "かな", output: KeyboardConfiguration.kanaModeOutput))),
                KeyDescriptor(.space, columnSpan: 2)
            ])
        ]
    }

    public static func rightRows(shifted: Bool) -> [Row] {
        [
            Row(letters("yuiop", shifted: shifted)),
            Row(letters("ghjkl", shifted: shifted)),
            Row(letters("bnm", shifted: shifted) + [KeyDescriptor(.backspace)], indent: 0.5),
            Row([
                KeyDescriptor(.space, columnSpan: 3),
                KeyDescriptor(.newline, columnSpan: 2)
            ])
        ]
    }

    private static func letters(_ text: String, shifted: Bool) -> [KeyDescriptor] {
        text.map { character in
            let letter = shifted ? String(character).uppercased() : String(character)
            return KeyDescriptor(.latin(letter))
        }
    }
}
