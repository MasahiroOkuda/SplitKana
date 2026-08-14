import Foundation

/// キーボードが外へ出す唯一の出力。
///
/// SplitKanaCore は `UITextDocumentProxy` にもアプリのモデルにも触らない（SPEC 1）。
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
    /// 変換候補を送る。+1 で次、-1 で前（SPEC 5.2）
    case candidate(Int)
    /// 地球キー（拡張のみ）
    case nextInputMode
    /// 「結ぶ」「囲む」など（アプリ内のみ）
    case custom(String)
}

public extension KeyOutput {

    /// 押しっぱなしで繰り返してよいか（SPEC 2.5）。
    ///
    /// **キーではなく出力で決める。**⌫ の長押しも、カーソルキーのフリック維持も、
    /// 「同じことを続けたい」という同じ操作なので、同じ仕組みに乗せる。
    ///
    /// 文字の挿入は繰り返さない。押しっぱなしで同じ字が並ぶのは事故にしかならない。
    /// 変換候補送りも繰り返さない（行き過ぎたぶんを戻す操作が要るだけ）。
    var repeatsWhileHeld: Bool {
        switch self {
        case .backspace, .cursor:
            return true
        case .insert, .space, .newline, .dakuten, .candidate, .nextInputMode, .custom:
            return false
        }
    }
}
