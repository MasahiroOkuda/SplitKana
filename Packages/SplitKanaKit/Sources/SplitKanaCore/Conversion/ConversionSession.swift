import Foundation

/// 未確定の読みと、その変換候補（SPEC 5.2）。
///
/// **proxy もアプリのモデルも知らない。**状態を持つだけ。
public struct ConversionSession: Equatable, Sendable {

    /// 未確定の読み。空なら変換中でない。
    public var reading: String
    public var candidates: [String]
    public var selection: Int

    public init(reading: String = "", candidates: [String] = [], selection: Int = 0) {
        self.reading = reading
        self.candidates = candidates
        self.selection = selection
    }

    public var isComposing: Bool { !reading.isEmpty }

    /// いま確定するならこの文字列。
    ///
    /// 候補が無い／範囲外なら読みそのものを返す。**変換中は必ず非 nil。**
    public var selected: String? {
        guard isComposing else { return nil }
        guard candidates.indices.contains(selection) else { return reading }
        return candidates[selection]
    }

    public static let empty = ConversionSession()
}
