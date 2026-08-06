import Foundation

/// かな漢字変換の抽象（SPEC 5.3）。
///
/// フェーズ4まで実装は入れない。かな入力のままで足りる可能性を実使用で確かめてから差し込む。
public protocol KanaKanjiConverting {
    func candidates(for reading: String) -> [String]
}

/// 「変換しない実装」。読みをそのまま1候補として返す。
public struct PassthroughConverter: KanaKanjiConverting {
    public init() {}

    public func candidates(for reading: String) -> [String] {
        reading.isEmpty ? [] : [reading]
    }
}
