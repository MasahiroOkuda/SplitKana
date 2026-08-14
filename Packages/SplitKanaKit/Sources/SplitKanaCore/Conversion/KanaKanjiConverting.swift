import Foundation

/// かな漢字変換の抽象（SPEC 5.3）。
///
/// フェーズ4まで実装は入れない。かな入力のままで足りる可能性を実使用で確かめてから差し込む。
public protocol KanaKanjiConverting {
    func candidates(for reading: String) -> [String]

    /// 確定した結果を学習に反映する。
    ///
    /// **確定のたびに呼ぶ。**キーで確定してもタップで確定しても同じ。
    /// 変換器を持たない実装（テスト用など）は何もしなくてよい。
    func learn(_ committed: String, for reading: String)

    /// 学習した内容を保存する。
    ///
    /// **キーボードが降りるときに呼ぶ。**拡張はいつ殺されてもおかしくないので、
    /// 覚えたことを溜めたままにしない。
    func persistLearning()
}

public extension KanaKanjiConverting {
    func learn(_ committed: String, for reading: String) {}
    func persistLearning() {}
}

/// 「変換しない実装」。読みをそのまま1候補として返す。
public struct PassthroughConverter: KanaKanjiConverting {
    public init() {}

    public func candidates(for reading: String) -> [String] {
        reading.isEmpty ? [] : [reading]
    }
}
