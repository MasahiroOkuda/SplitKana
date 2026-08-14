import Foundation

/// 左の機能列に挿す1キー（SPEC 2.2）。ホストによって中身が変わる。
public struct FunctionKey: Equatable, Sendable {
    public let title: String
    public let output: KeyOutput

    /// 方向ごとの出力。指定の無い方向は `output` に落ちる。
    ///
    /// カーソルキーのように**1つのキーで左右を兼ねる**ために使う。
    /// 機能列は4つしか席が無いので、席を節約したいときに効く。
    public let flickOutputs: [FlickDirection: KeyOutput]

    public init(
        title: String,
        output: KeyOutput,
        flickOutputs: [FlickDirection: KeyOutput] = [:]
    ) {
        self.title = title
        self.output = output
        self.flickOutputs = flickOutputs
    }
}

/// キーの種別。
public enum KeyKind: Equatable, Sendable {
    case kana(FlickSet)
    /// 小゛゜。直前1文字を巡回させる。フリックは持たない。
    case dakuten
    case backspace
    case space
    case newline
    case function(FunctionKey)

    /// キーの見た目に出す文字。
    public var label: String {
        switch self {
        case .kana(let set): return set.center
        case .dakuten: return "小゛゜"
        case .backspace: return "⌫"
        case .space: return "空白"
        case .newline: return "改行"
        case .function(let key): return key.title
        }
    }

    /// 中央タップ（= フリックなし）で出る出力。
    public var baseOutput: KeyOutput {
        switch self {
        case .kana(let set): return .insert(set.center)
        case .dakuten: return .dakuten
        case .backspace: return .backspace
        case .space: return .space
        case .newline: return .newline
        case .function(let key): return key.output
        }
    }

    public var flickSet: FlickSet? {
        if case .kana(let set) = self { return set }
        return nil
    }

    /// フリック方向を踏まえた出力。
    ///
    /// 空白キーだけは左フリックで候補の逆送りになる（SPEC 5.2）。
    /// **ポップアップは出さない。**見た目に出るのはかなキーのフリックだけ。
    public func output(for direction: FlickDirection) -> KeyOutput {
        switch self {
        case .kana(let set):
            return .insert(set.character(for: direction))
        case .space:
            return direction == .left ? .candidate(-1) : .space
        case .function(let key):
            return key.flickOutputs[direction] ?? key.output
        default:
            return baseOutput
        }
    }
}

/// レイアウト前のキー定義。
public struct KeyDescriptor: Equatable, Sendable {
    public let kind: KeyKind
    /// 縦に占める行数。改行キーだけ 2（SPEC 2.1）。
    public let rowSpan: Int

    public init(_ kind: KeyKind, rowSpan: Int = 1) {
        self.kind = kind
        self.rowSpan = rowSpan
    }
}

/// キーの列。分割レイアウトと統合レイアウトはこの列を並べ替えるだけの違いになる。
public enum KeyColumn: String, Sendable {
    /// ホストで差し替わる機能列
    case function
    /// あ・た・ま・小゛゜（分割時は左右両方に出る）
    case aColumn
    /// か・な・や・わ
    case kaColumn
    /// さ・は・ら・、。?
    case saColumn
    /// ⌫・空白・改行
    case utility

    public func keys(configuration: KeyboardConfiguration) -> [KeyDescriptor] {
        switch self {
        case .function:
            return configuration.normalizedFunctionColumn.map { KeyDescriptor(.function($0)) }
        case .aColumn:
            return [
                KeyDescriptor(.kana(FlickTable.a)),
                KeyDescriptor(.kana(FlickTable.ta)),
                KeyDescriptor(.kana(FlickTable.ma)),
                KeyDescriptor(.dakuten)
            ]
        case .kaColumn:
            return [
                KeyDescriptor(.kana(FlickTable.ka)),
                KeyDescriptor(.kana(FlickTable.na)),
                KeyDescriptor(.kana(FlickTable.ya)),
                KeyDescriptor(.kana(FlickTable.wa))
            ]
        case .saColumn:
            return [
                KeyDescriptor(.kana(FlickTable.sa)),
                KeyDescriptor(.kana(FlickTable.ha)),
                KeyDescriptor(.kana(FlickTable.ra)),
                KeyDescriptor(.kana(FlickTable.punctuation))
            ]
        case .utility:
            return [
                KeyDescriptor(.backspace),
                KeyDescriptor(.space),
                KeyDescriptor(.newline, rowSpan: 2)
            ]
        }
    }
}
