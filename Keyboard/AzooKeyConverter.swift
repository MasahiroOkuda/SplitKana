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

    /// 直前に引いた読みと、そのときの候補（`Candidate` のまま）。
    ///
    /// 学習には文字列ではなく `Candidate` が要るのに、
    /// `KanaKanjiConverting` は `[String]` しか返さない。
    /// 確定時に引き当てられるよう、ここで持っておく。
    private var lastReading = ""
    private var lastCandidates: [Candidate] = []

    init() {
        // 学習の保存先。App Group は使わないので拡張自身のコンテナに置く（SPEC 4）。
        // ホストアプリとは共有されない。これは仕様どおり。
        let library = FileManager.default
            .urls(for: .libraryDirectory, in: .userDomainMask)[0]
        let memory = library.appendingPathComponent("SplitKanaMemory", isDirectory: true)
        try? FileManager.default.createDirectory(at: memory, withIntermediateDirectories: true)

        options = .withDefaultDictionary(
            requireJapanesePrediction: false,
            requireEnglishPrediction: false,
            keyboardLanguage: .ja_JP,
            // 変換結果に反映し、確定のたびに更新する。
            learningType: .inputAndOutput,
            memoryDirectoryURL: memory,
            sharedContainerURL: memory,
            metadata: .init(versionString: "SplitKana")
        )
    }

    /// **メインスレッド同期で呼ばれる前提。**
    /// `KeyboardViewController` のキー処理から `ConversionController` 経由で届く。
    /// `assumeIsolated` はそれが崩れるとクラッシュするので、非同期化しないこと。
    nonisolated func candidates(for reading: String) -> [String] {
        MainActor.assumeIsolated {
            guard !reading.isEmpty else { return [] }
            var composing = ComposingText()
            composing.insertAtCursorPosition(reading, inputStyle: .direct)
            let result = converter.requestCandidates(composing, options: options)

            lastReading = reading
            lastCandidates = result.mainResults
            return result.mainResults.map(\.text)
        }
    }

    /// 確定した候補を学習に反映する。
    ///
    /// 無変換（読みそのまま）で確定した場合は、対応する `Candidate` が無いので何もしない。
    /// 変換していないのだから覚えることも無い。
    nonisolated func learn(_ committed: String, for reading: String) {
        MainActor.assumeIsolated {
            guard reading == lastReading,
                  let candidate = lastCandidates.first(where: { $0.text == committed }) else {
                return
            }
            converter.setCompletedData(candidate)
            converter.updateLearningData(candidate)
        }
    }

    /// 学習内容を書き出す。
    ///
    /// **拡張はいつ殺されてもおかしくない。**キーボードが降りる合図で必ず流す。
    nonisolated func persistLearning() {
        MainActor.assumeIsolated {
            converter.sendToDicdataStore(.closeKeyboard)
        }
    }
}
