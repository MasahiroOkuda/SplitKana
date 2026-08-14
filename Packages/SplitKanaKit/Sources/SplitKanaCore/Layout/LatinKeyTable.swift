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
/// 左パネル                  右パネル
/// Q  W  E  R  T             Y  U  I  O  P
///  A  S  D  F  G             H  J  K  L
/// ⇧  Z  X  C  V  B             N  M  ,  .  ⌫
/// 🌐 ⚙ かな   ␣              ␣       改行
/// ```
///
/// **どちらの手で打つかで分ける。**G と B は左手の人差し指なので左。
/// 左右のキー数が揃わないぶんパネル幅も揃わないが、
/// 揃えるために打つ手と違う側へ寄せるほうが、打っていて迷う。
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

    /// 左パネルの列数。⇧ を頭に付けた ZXCVB の行がいちばん長い。
    public static let leftColumns = 6
    /// 右パネルの列数。N M , . ⌫ の行がいちばん長い。
    public static let rightColumns = 6

    public static func leftRows(shifted: Bool) -> [Row] {
        [
            Row(letters("qwert", shifted: shifted)),
            Row(letters("asdfg", shifted: shifted), indent: 0.5),
            Row([KeyDescriptor(.shift)] + letters("zxcvb", shifted: shifted)),
            Row([
                KeyDescriptor(.function(FunctionKey(title: "🌐", output: .nextInputMode))),
                KeyDescriptor(.function(FunctionKey(
                    title: "⚙", output: KeyboardConfiguration.settingsOutput))),
                // 英字の次はかな。巡回は かな → 数字 → 英字 → かな。
                KeyDescriptor(.function(FunctionKey(
                    title: InputMode.latin.next.label,
                    output: KeyboardConfiguration.nextModeOutput))),
                KeyDescriptor(.space, columnSpan: 3)
            ])
        ]
    }

    /// 段差は左パネルから続いている。
    /// 左が 0 / 0.5 / 1.0 とずれていくので、右も同じだけずらす。
    public static func rightRows(shifted: Bool) -> [Row] {
        [
            Row(letters("yuiop", shifted: shifted)),
            Row(letters("hjkl", shifted: shifted), indent: 0.5),
            // 読点・句点は ⇧ で変わらない。英数モードなので半角のまま。
            Row(letters("nm", shifted: shifted)
                + [KeyDescriptor(.latin(",")), KeyDescriptor(.latin(".")),
                   KeyDescriptor(.backspace)], indent: 1),
            Row([
                KeyDescriptor(.space, columnSpan: 3),
                KeyDescriptor(.newline, columnSpan: 3)
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
