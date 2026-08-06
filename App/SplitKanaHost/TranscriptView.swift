import SwiftUI
import SplitKanaKit

/// 打った文字を見せるだけのビュー。キーボードの中央の空きに置く。
struct TranscriptView: View {

    let buffer: KanaTextBuffer
    let stats: TypingStats
    let lastCustomOutput: String?
    let onClear: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            header
            ScrollView {
                text
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
            }
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color(white: 1.0))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Color(white: 0.82), lineWidth: 1)
            )
            footer
        }
    }

    private var text: some View {
        let before = buffer.contextBeforeCursor
        let after = String(buffer.text.dropFirst(buffer.cursor))
        return (
            Text(before)
            + Text("|").foregroundColor(.accentColor)
            + Text(after)
        )
        .font(.system(size: 22))
        .lineSpacing(4)
        .textSelection(.enabled)
    }

    private var header: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            HStack(spacing: 12) {
                metric("文字", "\(stats.insertedCharacters)")
                metric("削除", "\(stats.backspaces)")
                metric("文字/分", "\(stats.charactersPerMinute(at: context.date))")
                Spacer(minLength: 0)
                Button("消す", action: onClear)
                    .font(.footnote)
                    .buttonStyle(.bordered)
            }
        }
    }

    private var footer: some View {
        HStack {
            Text(lastCustomOutput.map { "custom: \($0)" } ?? " ")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer(minLength: 0)
        }
    }

    private func metric(_ title: String, _ value: String) -> some View {
        HStack(spacing: 4) {
            Text(title).font(.caption2).foregroundStyle(.secondary)
            Text(value).font(.system(size: 15, weight: .semibold)).monospacedDigit()
        }
    }
}
