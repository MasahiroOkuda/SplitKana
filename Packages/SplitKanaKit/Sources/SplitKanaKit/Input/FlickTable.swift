/// フリック表（SPEC 2.3）。並びは 中央 / 左 / 上 / 右 / 下。
public enum FlickTable {
    public static let a           = FlickSet("あ", "い", "う", "え", "お")
    public static let ka          = FlickSet("か", "き", "く", "け", "こ")
    public static let sa          = FlickSet("さ", "し", "す", "せ", "そ")
    public static let ta          = FlickSet("た", "ち", "つ", "て", "と")
    public static let na          = FlickSet("な", "に", "ぬ", "ね", "の")
    public static let ha          = FlickSet("は", "ひ", "ふ", "へ", "ほ")
    public static let ma          = FlickSet("ま", "み", "む", "め", "も")
    public static let ya          = FlickSet("や", "「", "ゆ", "」", "よ")
    public static let ra          = FlickSet("ら", "り", "る", "れ", "ろ")
    public static let wa          = FlickSet("わ", "を", "ん", "ー", "〜")
    public static let punctuation = FlickSet("、", "。", "?", "!", "…")

    public static let all: [FlickSet] = [a, ka, sa, ta, na, ha, ma, ya, ra, wa, punctuation]
}
