# Windows で `swift test` を通す

`SplitKanaCore` は Foundation しか使わないので、Mac がなくてもロジックのテストは全部走る。

**動作確認済み**（2026-08-06）：Swift 6.3.3 / VS Build Tools 17.14.37516 / Windows SDK 10.0.26100、
36 テスト全パス、警告ゼロ。

## 走らせる

```bash
scripts\swift-test.bat
```

引数はそのまま `swift test` に渡る。

```bash
scripts\swift-test.bat --filter DakutenCycleTests
```

**素の `swift test` は通らない。** 理由は下の「3つの落とし穴」。スクリプトはそれを吸収しているだけ。

## 入れるもの

### 1. Visual Studio Build Tools（C++ ワークロード）

Swift for Windows は MSVC の `link.exe` と Windows SDK を使う。Swift だけでは動かない。
管理者権限が要る（UAC が出る）。ダウンロード 5〜8GB。

```powershell
winget install --id Microsoft.VisualStudio.2022.BuildTools -e --accept-package-agreements --accept-source-agreements --override "--quiet --wait --norestart --add Microsoft.VisualStudio.Workload.VCTools --includeRecommended"
```

Visual Studio 2022（IDE）が既にあるなら「C++ によるデスクトップ開発」ワークロードを足すだけでよい。

### 2. Swift toolchain

```powershell
winget install --id Swift.Toolchain -e --accept-package-agreements --accept-source-agreements
```

Python 3.10 と VC Redist が依存として一緒に入る。

### 3. ターミナルを開き直す

PATH と `SDKROOT` はユーザー環境変数に書かれるので、新しいシェルからしか見えない。

## 3つの落とし穴

素の `swift test` が失敗する理由。全部 `scripts\swift-test.bat` が処理している。

### `link.exe` が見つからない

```
error: toolchain is invalid: could not find CLI tool `link` at any of these directories
```

SwiftPM は MSVC のリンカを PATH から探す。`vcvars64.bat` を通す必要がある。
そのうえ `vcvars64.bat` は `vswhere.exe` を PATH から探すので、
`%ProgramFiles(x86)%\Microsoft Visual Studio\Installer` も先に通しておく。

### 標準ライブラリが読めない

```
error: unable to load standard library for target 'x86_64-unknown-windows-msvc'
```

`SDKROOT` が無い。インストーラが**ユーザー環境変数として**書くので、
インストール前に起動していたプロセスには伝わらない。

```
SDKROOT=%LOCALAPPDATA%\Programs\Swift\Platforms\<version>\Windows.platform\Developer\SDKs\Windows.sdk\
```

### index store で swift-frontend が落ちる

```
While indexing module 'WinSDK'
...\um\lmjoin.h:198:1: importing 'NetRenameMachineInDomain'
Exception Code: 0xC0000005
```

WinSDK を索引付けする途中でコンパイラがクラッシュする。

**`--disable-index-store` で逃げてはいけない。**Windows / Linux の XCTest は
テスト発見に index store を使うので、切ると今度は発見側が死ぬ。

```
error: index store path does not exist: ...\debug\index\store
error: fatalError
```

正解は index store を残したまま、落ちる原因のシステムモジュールだけ索引付けから外すこと。

```
swift test --enable-index-store -Xswiftc -index-ignore-system-modules -Xswiftc -index-ignore-clang-modules
```

## バッチファイルを書くときの注意

`scripts\swift-test.bat` は **ASCII のみ・CRLF のみ**で書いてある。

- cmd はバッチを OEM コードページで読むので、日本語コメントを入れると
  そのバイト列で行が壊れ、**後続の行が途中で切れて別のコマンドとして実行される**
- LF だけの改行でも同様に誤解析する

`.gitattributes` で `*.bat text eol=crlf` を指定してあるのはこのため
（リポジトリ全体は `eol=lf`）。

## 覚悟しておくこと

- **`SplitKanaUI` は Windows では空モジュールになる。** 中身が `#if canImport(SwiftUI)` で
  囲んであるため、ビルドは通るがコードは1行もコンパイルされない。
  **UI 側のコンパイルエラーは Windows では絶対に見つからない。**そこは Mac の仕事
- 確認できるのは Core のロジックだけ。ただしフリック判定・濁点巡回・寸法計算・
  ポップアップの置き場所は全部 Core にあるので、仕様の芯の部分は押さえられる

## Linux で回す場合

Build Tools が要らないぶん速い。index store の問題も出ない。

```bash
docker run --rm -v "$PWD":/src -w /src/Packages/SplitKanaKit swift:6.1 swift test
```
