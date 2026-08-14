import Foundation
import SplitKanaCore
import KanaKanjiConverterModuleWithDefaultDictionary

/// AzooKey を `KanaKanjiConverting` に合わせるアダプタ。
///
/// **AzooKey への依存はこのファイルだけ。**`SplitKanaCore` からは見えない。
/// 変換器を差し替えたくなったら、ここを別の実装に取り替えるだけで済む（SPEC 5.3）。
@MainActor
final class AzooKeyConverter: KanaKanjiConverting {

    private let converter = KanaKanjiConverter()
    private let options: ConvertRequestOptions

    init() {
        // 学習は入れない。App Group を使わないので保存先は拡張自身の Library。
        let library = FileManager.default
            .urls(for: .libraryDirectory, in: .userDomainMask)[0]
        options = .withDefaultDictionary(
            requireJapanesePrediction: false,
            requireEnglishPrediction: false,
            keyboardLanguage: .ja_JP,
            learningType: .nothing,
            memoryDirectoryURL: library,
            sharedContainerURL: library,
            metadata: .init(versionString: "SplitKana")
        )
    }

    nonisolated func candidates(for reading: String) -> [String] {
        MainActor.assumeIsolated {
            guard !reading.isEmpty else { return [] }
            var composing = ComposingText()
            composing.insertAtCursorPosition(reading, inputStyle: .direct)
            let result = converter.requestCandidates(composing, options: options)
            return result.mainResults.map(\.text)
        }
    }
}
