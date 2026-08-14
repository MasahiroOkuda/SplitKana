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

    /// 表示に使う候補の並び。候補が無いときは読みそのものを1件として扱う。
    ///
    /// `selected` が読みに落ちる規則と揃えてあるので、
    /// 表示側は「候補が無い」場合分けを持たなくてよい。
    public var displayCandidates: [String] {
        guard isComposing else { return [] }
        return candidates.isEmpty ? [reading] : candidates
    }

    /// いま何番目か（1始まり）と全部で何件か。変換中でなければ nil。
    ///
    /// **何度送っても現在地が分かるように出す。**
    /// 送るうちに自分がどこにいるか見失うのを防ぐのが目的（SPEC 5.2）。
    public var position: (index: Int, total: Int)? {
        let all = displayCandidates
        guard !all.isEmpty else { return nil }
        let clamped = all.indices.contains(selection) ? selection : 0
        return (clamped + 1, all.count)
    }

    /// ひとつ前の候補。**先頭にいるなら nil。**
    ///
    /// 「次に何が来るか」の予告なので、無い方向には何も出さない。
    public var previousCandidate: String? {
        neighbour(offset: -1)
    }

    /// ひとつ後ろの候補。**末尾にいるなら nil。**
    public var nextCandidate: String? {
        neighbour(offset: 1)
    }

    private func neighbour(offset: Int) -> String? {
        let all = displayCandidates
        guard all.indices.contains(selection) else { return nil }
        let index = selection + offset
        guard all.indices.contains(index) else { return nil }
        return all[index]
    }

    public static let empty = ConversionSession()
}
