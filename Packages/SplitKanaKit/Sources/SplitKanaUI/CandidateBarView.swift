#if canImport(SwiftUI)
import SwiftUI
import SplitKanaCore

/// 変換候補を見せるだけのビュー（SPEC 5.2）。
///
/// **タップさせない。**中央は親指が届かないので、候補は空白キーで送る。
///
/// 見せ方の要点は3つ。
///
/// 1. **読みを消さない。**候補だけを出すと、何度か送るうちに
///    自分が何と打とうとしていたのか画面から分からなくなる
/// 2. **いま何番目かを出す。**送った回数を数えなくても現在地が分かるように
/// 3. **前後をうっすら添える。**次に何が来るかの予告。端では出さない
///
/// ```
/// かんがえ                    3 / 12
///     考え   [ 考え ]   勘が絵
/// ```
public struct CandidateBarView: View {

    private let session: ConversionSession
    private let region: CGRect

    /// このビューが必要とする高さ。置き場所を決める側と食い違わないよう公開する。
    public static let preferredHeight: CGFloat = 62

    public init(session: ConversionSession, region: CGRect) {
        self.session = session
        self.region = region
    }

    public var body: some View {
        // 何も表示することがなければ何も描かない。背景だけ描くバーは誤座標の罠になる。
        if session.isComposing {
            VStack(alignment: .leading, spacing: 2) {
                readingRow
                candidateRow
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .frame(width: region.width, height: Self.preferredHeight, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color(white: 1.0).opacity(0.94))
            )
            .offset(x: region.minX, y: region.minY)
            // 表示専用。タッチはキーボードのものを邪魔しない。
            .allowsHitTesting(false)
        }
    }

    /// 上段：読みと現在地。**読みはどの候補を選んでいても消えない。**
    private var readingRow: some View {
        HStack(spacing: 8) {
            Text(session.reading)
                .font(.system(size: 13))
                .foregroundStyle(Self.secondaryInk)
                .lineLimit(1)
                .truncationMode(.head)

            Spacer(minLength: 4)

            if let position = session.position, position.total > 1 {
                Text("\(position.index) / \(position.total)")
                    .font(.system(size: 12, weight: .medium))
                    .monospacedDigit()
                    .foregroundStyle(Self.secondaryInk)
            }
        }
    }

    /// 下段：前・選択中・次。端では無い方向に何も出さない。
    private var candidateRow: some View {
        HStack(spacing: 10) {
            neighbour(session.previousCandidate)

            Text(session.selected ?? session.reading)
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(Self.primaryInk)
                .lineLimit(1)
                .padding(.horizontal, 8)
                .padding(.vertical, 1)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Color.accentColor.opacity(0.18))
                )
                .layoutPriority(1)

            neighbour(session.nextCandidate)

            Spacer(minLength: 0)
        }
    }

    @ViewBuilder
    private func neighbour(_ text: String?) -> some View {
        if let text {
            Text(text)
                .font(.system(size: 15))
                .foregroundStyle(Self.fadedInk)
                .lineLimit(1)
                .truncationMode(.tail)
        }
    }

    // 背景を明るい色に固定しているので、文字色も固定する。
    // `Color.primary` はダークモードで白くなり、白い帯の上で読めなくなる。
    private static let primaryInk = Color(white: 0.10)
    private static let secondaryInk = Color(white: 0.42)
    private static let fadedInk = Color(white: 0.62)
}
#endif
