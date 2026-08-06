import Foundation

/// キーボードが外へ出す唯一の出力。
///
/// SplitKanaKit は `UITextDocumentProxy` にもアプリのモデルにも触らない（SPEC 1）。
/// 拡張側はこれを proxy に流し、アプリ側は自前バッファに流す。
public enum KeyOutput: Equatable, Sendable {
    /// 文字を入れる
    case insert(String)
    case backspace
    case space
    case newline
    /// 直前1文字を巡回（小書き → 濁点 → 半濁点）
    case dakuten
    /// 相対移動（-1 / +1）
    case cursor(Int)
    /// 地球キー（拡張のみ）
    case nextInputMode
    /// 「結ぶ」「囲む」など（アプリ内のみ）
    case custom(String)
}
