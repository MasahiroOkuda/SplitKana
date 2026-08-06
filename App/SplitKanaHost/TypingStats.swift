import Foundation
import SplitKanaKit

/// フェーズ1で測るもの：文字/分、削除キーの回数、届かないキーの有無（SPEC 7）。
/// 「届かないキー」は打っていて気づくしかないので、ここでは前2つだけ数える。
struct TypingStats: Equatable {

    private(set) var insertedCharacters = 0
    private(set) var backspaces = 0
    private(set) var startedAt: Date?

    mutating func record(_ output: KeyOutput) {
        switch output {
        case .insert(let string):
            start()
            insertedCharacters += string.count
        case .space, .newline:
            start()
            insertedCharacters += 1
        case .backspace:
            start()
            backspaces += 1
        case .dakuten, .cursor, .nextInputMode, .custom:
            break
        }
    }

    mutating func reset() {
        self = TypingStats()
    }

    private mutating func start() {
        if startedAt == nil { startedAt = Date() }
    }

    func elapsed(at now: Date) -> TimeInterval {
        guard let startedAt = startedAt else { return 0 }
        return max(0, now.timeIntervalSince(startedAt))
    }

    func charactersPerMinute(at now: Date) -> Int {
        let seconds = elapsed(at: now)
        guard seconds >= 1 else { return 0 }
        return Int((Double(insertedCharacters) / seconds * 60).rounded())
    }
}
