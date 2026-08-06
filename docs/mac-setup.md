# Mac を借りて作業するときの手引き

このファイルは **Mac を貸してくれる人／Mac の前に座る人**がそのまま読めるように書いてある。

## このプロジェクトは何か

iPhone / iPad 用の**分割かなキーボード**。画面の左右端にキーを寄せて、両手で持ったまま
親指だけで打てるようにするもの。いまは「フェーズ1」で、キーボードの部品と、
それを試すためだけの小さなアプリができている段階。

開発は Windows 機で進めている。**Mac が必要なのは、画面に出る部分のビルドと実行だけ。**

## いちばん大事な前提

**画面まわりのコードは、まだ一度もコンパイルされていない。**

ロジック（フリック判定・濁点巡回・寸法計算）は Windows でテスト済みで全部通っているが、
SwiftUI の部分は Apple の SDK がないとコンパイルすらできないため、未検証のまま。

**初回のビルドではエラーが出る前提でいてほしい。** それは失敗ではなく、
Mac を借りる目的そのもの。エラーが出たら、**エラーメッセージをそのままコピーして渡す**のが
いちばん価値のある成果物になる。

---

## Mac でしかできないこと

Apple の制約であって、工夫で回避できるものはひとつもない。

| | なぜ Mac だけなのか |
|---|---|
| **SwiftUI のコンパイル** | SwiftUI は Apple の SDK にしか存在しない。`Sources/SplitKanaUI/` と `App/SplitKanaHost/` はここでしかビルドできない |
| **Xcode プロジェクトの作成** | `.xcodeproj` は Xcode でしか作れない。このリポジトリには入れていないので**最初の1回だけ**必要 |
| **iOS シミュレータでの実行** | シミュレータは macOS 専用 |
| **実機（iPhone / iPad）へのインストール** | 署名とデバイスへの転送が Xcode 経由でしかできない |
| **Xcode Previews** | 同上 |
| **キーボード拡張の動作確認** | フェーズ2以降。拡張は実機かシミュレータでしか動かない |
| **App Store / TestFlight への提出** | 将来の話 |

## Mac がなくてもできること

| | 補足 |
|---|---|
| **ロジックのテスト** | `SplitKanaCore` は Foundation しか使わない。Windows で36テストが全部通っている |
| コードの編集 | 全部 |
| git の操作 | 全部 |
| 寸法計算やレイアウトの検証 | 数値として検証できる範囲は Windows で完結する |

**境界は「画面に出るかどうか」。**出るものは Mac、出ないものはどこでも。

---

## 用意してもらうもの

- **macOS** — Xcode 15 以降が動くバージョン（Sonoma 以降が無難）
- **Xcode** — App Store から無料。**10GB 以上あり、ダウンロードだけで1時間かかることもある**
- ディスク空き **30GB 程度**（Xcode 本体 + シミュレータ + ビルド成果物）
- 実機で試すなら **USB ケーブル**と **Apple ID**

> **Mac を借りる前に Xcode のインストールだけ済ませておいてもらえると、
> 当日の時間がまるごと浮く。**ここが最大の時間短縮ポイント。

---

## 当日の手順

### 1. コードを取ってくる

```bash
git clone https://github.com/MasahiroOkuda/SplitKana.git
cd SplitKana
```

Private リポジトリなので GitHub の認証を聞かれる。`gh` を入れておくと楽。

```bash
brew install gh
gh auth login
```

### 2. Xcode プロジェクトを作る（1回だけ・5分）

1. Xcode → File → New → Project → iOS → **App**
   - Product Name: `SplitKanaHost`
   - Interface: **SwiftUI** / Language: **Swift**
   - 保存先: clone した `SplitKana/` の直下
   - **「Create Git repository」のチェックは外す**（もうリポジトリがある）
2. File → Add Package Dependencies… → **Add Local…** → `Packages/SplitKanaKit`
   - `SplitKanaCore` と `SplitKanaUI` の**両方**を `SplitKanaHost` ターゲットに追加
3. Xcode が作ったテンプレートの `ContentView.swift` と `SplitKanaHostApp.swift` を削除
4. `App/SplitKanaHost/` の4ファイルをドラッグして追加
   - `SplitKanaHostApp.swift` / `HostRootView.swift` / `TranscriptView.swift` / `TypingStats.swift`
   - **「Copy items if needed」はオフ**、Target は `SplitKanaHost` にチェック
5. ターゲット設定
   - Minimum Deployments: **iOS 17.0**
   - iPhone Orientation: **Landscape Left / Landscape Right** を有効に

### 3. シミュレータでビルド（ここが本番）

iPhone のシミュレータを選んで ▶ を押す。

**エラーが出たら、その時点で手を止めて内容を渡す。**
Xcode の Issue Navigator（左ペインの ⚠️ タブ）を開き、赤い行を全部コピーするのがいちばん早い。
直したものを Windows 側から push するので、`git pull` して再ビルドする往復になる。

ビルドが通ったら**画面を横向きにする**（シミュレータの Command + ← / →）。
左右にキーの塊、中央に打った文字が出れば成功。スクリーンショットを撮って残す。

### 4. 実機に入れる（できれば）

シミュレータはマウスで押すだけなので、**両手で持って親指で打つ感触は測れない。**
このプロジェクトの目的は「毎日打って測る」ことなので、実機に入るところまで行きたい。

1. iPhone を USB でつなぐ → iPhone 側で「このコンピュータを信頼」
2. Xcode の Signing & Capabilities → Team に **Apple ID を追加**
3. 実行先を実機にして ▶
4. iPhone 側で 設定 → 一般 → VPN とデバイス管理 → アカウントを「信頼」

---

## 貸す人に迷惑をかけないための注意

- **署名に使う Apple ID は、アプリを使う本人のものを一時的に追加する。**
  Xcode → Settings → Accounts で追加し、**作業が終わったら削除する。**
  貸主のアカウントで署名すると、そのアカウントに紐づいてしまう
- **無料の Apple ID で入れたアプリは7日で起動しなくなる。**
  毎日使い続けるには Apple Developer Program（年99ドル）が要る。
  今回は「動くことの確認」までなので無料で十分
- Xcode とシミュレータで **30GB 前後**使う。終わったら消してよいか確認しておく

---

## 時間の見積もり

| | 目安 |
|---|---|
| Xcode のインストール | 1〜2時間（**事前に済ませておきたい**） |
| clone + プロジェクト作成 | 10分 |
| 初回ビルドとエラー修正 | **30分〜2時間**（未知数。ここが読めない） |
| シミュレータで動作確認 | 10分 |
| 実機インストール | 20分 |

エラー修正は Windows 側でもできるが、**直したかどうかの確認には毎回 Mac が要る。**
細切れに借りるより、**2〜3時間まとめて**借りられるほうが圧倒的に効率がよい。

---

## 借りている間にやっておくと得なこと

Mac が手元にある時間は貴重なので、ついでに済ませたいもの。

- ビルドが通った状態の `.xcodeproj` を**コミットして push する**
  → 次に Mac を触るとき、プロジェクト作成の手順を飛ばせる
- シミュレータで **iPad 横向き**も見ておく（このレイアウトが本命）
- iPhone 縦向きも見ておく（分割しない5列にフォールバックするはず）
