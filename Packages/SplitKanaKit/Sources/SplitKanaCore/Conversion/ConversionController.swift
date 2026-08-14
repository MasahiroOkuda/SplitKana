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
}
