#if canImport(SwiftUI)
import SwiftUI
import SplitKanaCore

/// 変換候補を並べて見せるだけのビュー（SPEC 5.2）。
///
/// **タップさせない。**中央は親指が届かないので、候補は空白キーで送る。
/// 入りきらない分は切る。選択中が必ず見えるよう、選択中を中央付近に置く。
public struct CandidateBarView: View {

    private let session: ConversionSession
    private let region: CGRect

    public init(session: ConversionSession, region: CGRect) {
        self.session = session
        self.region = region
    }

    public var body: some View {
        // 何も表示することがなければ何も描かない。背景だけ描くバーは誤座標の罠になる。
        if !visible.isEmpty {
            HStack(spacing: 6) {
                ForEach(Array(visible.enumerated()), id: \.offset) { _, item in
                    Text(item.text)
                        .font(.system(size: 18))
                        .lineLimit(1)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(item.isSelected ? Color.accentColor.opacity(0.20) : Color.clear)
                        )
                        .foregroundStyle(item.isSelected ? Color.primary : Color.secondary)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 8)
            .frame(width: region.width, height: 40, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color(white: 1.0).opacity(0.92))
            )
            .offset(x: region.minX, y: region.minY)
            // 表示専用。タッチはキーボードのものを邪魔しない。
            .allowsHitTesting(false)
        }
    }

    private struct Item {
        let text: String
        let isSelected: Bool
    }

    /// 選択中が必ず入るよう、その前後だけを取る。
    private var visible: [Item] {
        guard !session.candidates.isEmpty else {
            return session.isComposing ? [Item(text: session.reading, isSelected: true)] : []
        }
        let maximum = 8
        let count = session.candidates.count
        let start = max(0, min(session.selection - maximum / 2, count - maximum))
        let end = min(count, start + maximum)
        return (start..<end).map {
            Item(text: session.candidates[$0], isSelected: $0 == session.selection)
        }
    }
}
#endif
