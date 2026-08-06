# Windows で `swift test` を通す

`SplitKanaCore` は Foundation しか使わないので、Mac がなくてもロジックのテストは全部走る。
そのための toolchain の入れ方。

## この機の現状（2026-08-06 時点）

- `winget` あり（v1.29.280）
- **Visual Studio は未インストール** ← ここが一番重い

## 手順

### 1. Visual Studio Build Tools（C++ ワークロード）

Swift for Windows は MSVC のリンカと Windows SDK を使う。Swift だけ入れても動かない。

```powershell
winget install --id Microsoft.VisualStudio.2022.BuildTools -e --override "--quiet --wait --add Microsoft.VisualStudio.Workload.VCTools --add Microsoft.VisualStudio.Component.Windows11SDK.26100 --includeRecommended"
```

- 管理者権限が要る
- ダウンロード 5〜8GB、回線次第で 20〜60 分
- Visual Studio 2022（IDE）が既に入っているなら Build Tools は不要。
  「C++ によるデスクトップ開発」ワークロードだけ追加すればよい

### 2. Swift toolchain

```powershell
winget install --id Swift.Toolchain -e
```

現時点の winget 版は **6.3.3**。

### 3. ターミナルを開き直す

PATH が入るのは新しいシェルから。閉じて開き直す（効かないならサインアウト／再起動）。

```powershell
swift --version
```

### 4. テストを走らせる

```bash
swift test --package-path Packages/SplitKanaKit
```

## 覚悟しておくこと

- **`SplitKanaUI` は Windows では空モジュールになる。** 中身が `#if canImport(SwiftUI)` で
  囲んであるため、ビルドは通るがコードは1行もコンパイルされない。
  **UI 側のコンパイルエラーは Windows では絶対に見つからない。**そこは Mac の仕事
- Core は `import CoreGraphics` を使わず `import Foundation` にしてある。
  `CGFloat` / `CGSize` / `CGRect` は swift-corelibs-foundation が提供する。
  ただし Darwin 版と完全に同じ API 面ではないので、初回は細かい修正が要るかもしれない
- `CGRect` の `Sendable` 準拠が Darwin 以外では宣言されていない場合、
  `Sendable` を名乗っている構造体に警告が出る。Swift 5 言語モードでは警告どまりで、失敗はしない
- `CGRect.intersects` はプラットフォーム差があるので、テストでは自前の重なり判定を使っている

## 入れずに済ませる道

CI に回すなら Linux コンテナのほうが速い（Build Tools が要らない）。

```bash
docker run --rm -v "$PWD":/src -w /src/Packages/SplitKanaKit swift:6.1 swift test
```

Windows に 8GB 入れたくないならこちらでもよい。
