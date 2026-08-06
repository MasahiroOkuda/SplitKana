/// 小゛゜キーの巡回表（SPEC 2.4）。
///
/// 巡回の原則：**小書き → 濁点 → 半濁点**。
/// 「っ」は促音として出現頻度が非常に高いため「づ」より先に来る。
/// この順序なら、小書きを持つキー（あ・う・つ・や・ゆ・よ・わ）はすべて小書きが1回目で揃う。
public enum DakutenCycle {

    /// 各リングは末尾から先頭へ戻る輪。1要素だけのキー（な行・ま行・ら行など）は登録しない。
    public static let rings: [[Character]] = [
        ["あ", "ぁ"], ["い", "ぃ"], ["う", "ぅ", "ゔ"], ["え", "ぇ"], ["お", "ぉ"],
        ["か", "が"], ["き", "ぎ"], ["く", "ぐ"], ["け", "げ"], ["こ", "ご"],
        ["さ", "ざ"], ["し", "じ"], ["す", "ず"], ["せ", "ぜ"], ["そ", "ぞ"],
        ["た", "だ"], ["ち", "ぢ"], ["つ", "っ", "づ"], ["て", "で"], ["と", "ど"],
        ["は", "ば", "ぱ"], ["ひ", "び", "ぴ"], ["ふ", "ぶ", "ぷ"], ["へ", "べ", "ぺ"], ["ほ", "ぼ", "ぽ"],
        ["や", "ゃ"], ["ゆ", "ゅ"], ["よ", "ょ"], ["わ", "ゎ"]
    ]

    private static let successor: [Character: Character] = {
        var map: [Character: Character] = [:]
        for ring in rings where ring.count > 1 {
            for (index, character) in ring.enumerated() {
                map[character] = ring[(index + 1) % ring.count]
            }
        }
        return map
    }()

    /// 次の字形。巡回対象でなければ nil（キーは無反応にする）。
    public static func next(after character: Character) -> Character? {
        successor[character]
    }

    /// 文字列末尾の1文字を巡回させた結果。巡回対象でなければ nil。
    ///
    /// 拡張側はこれを使って `deleteBackward()` + `insertText()` に落とす。
    public static func cyclingLastCharacter(of text: String) -> Character? {
        guard let last = text.last else { return nil }
        return next(after: last)
    }
}
