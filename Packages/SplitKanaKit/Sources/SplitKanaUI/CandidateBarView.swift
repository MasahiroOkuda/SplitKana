#if canImport(SwiftUI)
import SwiftUI
import SplitKanaCore

/// 変換候補を並べるビュー（SPEC 5.2）。
///
/// **左パネルの内側の縁から右へ順に並べる。**
/// 実機で確かめたところ、候補列の左端は左パネルのすぐ隣なので左親指が届く。
/// だから近い候補はタップ、遠い候補は空白キーで送る、という併用にしてある。
/// **1番目の候補がいちばん左（＝いちばん近い）に来ることが要点。**
///
/// 届く範囲を計算して絞ったりはしない。届かないところは押されないだけで、
/// そのために場合分けを持つ理由がない。
///
/// ```
/// かんがえ  3 / 12
/// [かんがえ] 考え  勘が絵  寒河江 …
/// ```
public struct CandidateBarView: View {

    private let session: ConversionSession
    private let region: CGRect
    /// 候補が押された。**その場で確定する**（選択して止まらない）。
    private let onSelect: (Int) -> Void

    /// このビューが必要とする高さ。置き場所を決める側と食い違わないよう公開する。
    public static let preferredHeight: CGFloat = 74

    /// 指で押せる高さ。見た目の文字より上下に余裕を取る（SPEC 10 と同じ考え方）。
    private static let rowHeight: CGFloat = 44

    public init(
        session: ConversionSession,
        region: CGRect,
        onSelect: @escaping (Int) -> Void = { _ in }
    ) {
        self.session = session
        self.region = region
        self.onSelect = onSelect
    }

    public var body: some View {
        // 何も表示することがなければ何も描かない。背景だけ描くバーは誤座標の罠になる。
        if session.isComposing {
            VStack(alignment: .leading, spacing: 0) {
                readingRow
                candidateRow
            }
            .padding(.horizontal, Self.horizontalPadding)
            .padding(.vertical, 4)
            .frame(width: region.width, height: Self.preferredHeight, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color(white: 1.0).opacity(0.94))
            )
            .offset(x: region.minX, y: region.minY)
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

            if let position = session.position, position.total > 1 {
                Text("\(position.index) / \(position.total)")
                    .font(.system(size: 12, weight: .medium))
                    .monospacedDigit()
                    .foregroundStyle(Self.secondaryInk)
            }

            Spacer(minLength: 0)
        }
        .frame(width: Self.contentWidth(in: region), height: 18, alignment: .leading)
        // 読みの帯はタップを取らない。候補だけが押せればよい。
        .allowsHitTesting(false)
    }

    /// 下段：候補を左から順に。**左端が左パネルにいちばん近い。**
    ///
    /// 幅に入りきらない分は切る。スクロールもさせない。
    /// 遠い候補は指が届かないので、キーで送るのが本来の使い方（SPEC 5.2）。
    private var candidateRow: some View {
        HStack(spacing: 4) {
            ForEach(Array(visible.enumerated()), id: \.offset) { index, text in
                candidate(text, at: index)
            }
            Spacer(minLength: 0)
        }
        // **幅を明示しないと `.clipped()` が効かない。**
        // 制約が無ければ行の幅は中身なりに広がり、その全体を「切って」も何も切れない。
        .frame(width: Self.contentWidth(in: region), height: Self.rowHeight, alignment: .leading)
        .clipped()
        // `.clipped()` は描画しか切らない。当たり判定も帯の中に閉じ込める。
        // これが無いと、はみ出した候補を右パネルの上で押せてしまう。
        .contentShape(Rectangle())
    }

    /// 帯の内側で使える幅。左右の余白ぶんを引く。
    private static func contentWidth(in region: CGRect) -> CGFloat {
        max(0, region.width - horizontalPadding * 2)
    }

    private static let horizontalPadding: CGFloat = 8

    /// 並べる候補。**多すぎても潰さない。**
    ///
    /// 潰すと1文字幅まで縮んで全部読めなくなる。入る数だけ出して残りは切る。
    private var visible: [String] {
        Array(session.displayCandidates.prefix(Self.maximumShown))
    }

    private static let maximumShown = 12

    private func candidate(_ text: String, at index: Int) -> some View {
        let isSelected = index == session.selection
        return Text(text)
            .font(.system(size: 20, weight: isSelected ? .semibold : .regular))
            .foregroundStyle(Self.primaryInk)
            .lineLimit(1)
            // **これが無いと幅に押し込まれて1文字ずつに潰れる。**
            .fixedSize(horizontal: true, vertical: false)
            .padding(.horizontal, 10)
            // 見た目の文字の高さより上下に余裕を持たせる。指で押す対象なので。
            .frame(height: Self.rowHeight - 6)
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(isSelected ? Color.accentColor.opacity(0.20) : Color(white: 0.94))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .stroke(isSelected ? Color.accentColor.opacity(0.75) : Color.clear,
                            lineWidth: 2)
            )
            // 文字の隙間ではなく矩形全体で受ける。
            .contentShape(Rectangle())
            .onTapGesture { onSelect(index) }
    }

    // 背景を明るい色に固定しているので、文字色も固定する。
    // `Color.primary` はダークモードで白くなり、白い帯の上で読めなくなる。
    private static let primaryInk = Color(white: 0.10)
    private static let secondaryInk = Color(white: 0.42)
}
#endif
