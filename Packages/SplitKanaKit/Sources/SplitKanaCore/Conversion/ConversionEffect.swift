import Foundation

/// 状態機械が「何をすべきか」を返すための指示（SPEC 1 の境界）。
///
/// `SplitKanaCore` は `UITextDocumentProxy` に触らない。
/// 拡張側がこれを `setMarkedText` / `insertText` / `unmarkText` に落とす。
public enum ConversionEffect: Equatable, Sendable {
    /// 未確定表示を更新する
    case markedText(String)
    /// 確定して挿入する
    case commit(String)
    /// 未確定表示を消す
    case clear
    /// 変換に関係ない出力。そのまま流す
    case passthrough(KeyOutput)
}
