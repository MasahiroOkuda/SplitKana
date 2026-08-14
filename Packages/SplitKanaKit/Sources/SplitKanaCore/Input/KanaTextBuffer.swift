import Foundation

/// `KeyOutput` を素朴なテキストバッファに適用する。
///
/// 拡張は `UITextDocumentProxy` を使うのでこれを通らない。アプリ側（および確認用ホスト）専用。
public struct KanaTextBuffer: Equatable, Sendable {

    public private(set) var text: String
    /// 文字（Character）単位のカーソル位置。0 ... text.count
    public private(set) var cursor: Int

    /// 空白キーが入れる文字。日本語かなキーボードに合わせて既定は全角。
    public var spaceCharacter: String

    public init(text: String = "", spaceCharacter: String = "\u{3000}") {
        self.text = text
        self.cursor = text.count
        self.spaceCharacter = spaceCharacter
    }

    /// カーソル手前の文字列（拡張の `documentContextBeforeInput` に相当）。
    public var contextBeforeCursor: String {
        String(text.prefix(cursor))
    }

    public var contextAfterCursor: String {
        String(text.dropFirst(cursor))
    }

    /// 適用したら true。`custom` / `nextInputMode` はホストの仕事なので false を返して素通しする。
    @discardableResult
    public mutating func apply(_ output: KeyOutput) -> Bool {
        switch output {
        case .insert(let string):
            insert(string)
        case .space:
            insert(spaceCharacter)
        case .newline:
            insert("\n")
        case .backspace:
            deleteBackward()
        case .dakuten:
            return cycleDakuten()
        case .cursor(let offset):
            cursor = min(max(cursor + offset, 0), text.count)
        case .candidate:
            return false
        case .nextInputMode, .custom:
            return false
        }
        return true
    }

    public mutating func reset() {
        text = ""
        cursor = 0
    }

    // MARK: - 編集操作

    private mutating func insert(_ string: String) {
        let index = text.index(text.startIndex, offsetBy: cursor)
        text.insert(contentsOf: string, at: index)
        cursor += string.count
    }

    private mutating func deleteBackward() {
        guard cursor > 0 else { return }
        let index = text.index(text.startIndex, offsetBy: cursor - 1)
        text.remove(at: index)
        cursor -= 1
    }

    /// 直前1文字を巡回させる。巡回対象でなければ何もしない。
    private mutating func cycleDakuten() -> Bool {
        guard cursor > 0 else { return false }
        let index = text.index(text.startIndex, offsetBy: cursor - 1)
        guard let replacement = DakutenCycle.next(after: text[index]) else { return false }
        text.replaceSubrange(index...index, with: String(replacement))
        return true
    }
}
