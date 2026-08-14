import Foundation

/// 変換の状態機械（SPEC 5.2）。
///
/// **`KeyOutput` を受けて `ConversionEffect` を返すだけ。**
/// テキストがどこへ行くかは知らない。だから Windows でもテストできる。
public struct ConversionController {

    private let converter: any KanaKanjiConverting
    public var session: ConversionSession

    public init(converter: any KanaKanjiConverting, session: ConversionSession = .empty) {
        self.converter = converter
        self.session = session
    }

    public mutating func handle(_ output: KeyOutput) -> [ConversionEffect] {
        switch output {
        case .insert(let text):
            session.reading += text
            return [refreshCandidates()]

        case .backspace where session.isComposing:
            session.reading.removeLast()
            guard session.isComposing else {
                session = .empty
                return [.clear]
            }
            return [refreshCandidates()]

        case .space where session.isComposing:
            return [moveCandidate(by: 1)]

        case .candidate(let step):
            guard session.isComposing else { return [] }
            return [moveCandidate(by: step)]

        default:
            return [.passthrough(output)]
        }
    }

    /// 読みが変わったので候補を引き直す。選択は先頭に戻す。
    private mutating func refreshCandidates() -> ConversionEffect {
        session.candidates = converter.candidates(for: session.reading)
        session.selection = 0
        return .markedText(session.selected ?? session.reading)
    }

    /// 候補を送る。**引き直さない。**端は巡回する。
    private mutating func moveCandidate(by step: Int) -> ConversionEffect {
        let count = session.candidates.count
        guard count > 0 else { return .markedText(session.reading) }
        session.selection = ((session.selection + step) % count + count) % count
        return .markedText(session.selected ?? session.reading)
    }
}
