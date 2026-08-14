# Claude Code への指示（フェーズ2：キーボード拡張化）

ホストアプリが実機で動くところまで来ました。
次は「全アプリで使えるキーボード」にします。以下をそのまま貼ってください。

---

## 貼り付ける指示（本体）

```
SPEC.md を読んで。フェーズ1のホストアプリが実機で動くところまで確認できた。
次はフェーズ2、キーボード拡張化をやりたい。

最終目標は Simeji のように、メモでも Safari でも LINE でも
普段のキーボードとして使えること。App Store には出さない、自分専用。

## 前提の確認から始めて

まず現状を確認してから作業を始めて：
- SplitKanaKit が UITextDocumentProxy に依存していないか
  （依存していたら先に KeyOutput 経由に直す）
- ホストアプリと拡張の両方から使える形になっているか
- 現在のターゲット構成と Bundle ID

確認結果を報告してから、次に進んで。

## Xcode の GUI 操作が要る部分は、手順を教えて

キーボード拡張のターゲット追加は Xcode の GUI 操作なので、
コマンドではできない。私がやるので手順を書いて：
- File > New > Target のどこを選ぶか
- ターゲット名は何にするか
- Bundle ID の命名規則（親アプリの Bundle ID + サフィックスにする必要がある）
- SplitKanaKit をリンクする手順
- 署名（Signing & Capabilities）で何を選ぶか

私が GUI 操作を終えたら報告するので、そこからコードを書いて。

## 実装してほしいこと

### KeyboardViewController
- SplitKanaKit の KeyboardView を載せる
- KeyOutput を textDocumentProxy に流す
  - insert(String) → insertText
  - backspace → deleteBackward
  - space / newline → insertText
  - dakuten → documentContextBeforeInput の末尾1文字を取って
    deleteBackward + insertText で置き換え
  - cursor(Int) → adjustTextPosition(byCharacterOffset:)
  - nextInputMode → advanceToNextInputMode()
- 高さ制約は priority 999（.required にしない。フローティング時に壊れる）

### 機能列を KeyboardConfiguration.keyboardExtension に
🌐 / 英数 / ◀ / ▶ の4つ。
- 🌐 は必須（他のキーボードに切り替える手段がないと使い物にならない）
- ◀ ▶ は adjustTextPosition で実装

### レイアウト分岐
SPEC 3 のとおり。iPhone 横 / iPad 縦横は分割、iPhone 縦は5列にフォールバック。
幅はハードコードせず、実際のコンテナ幅から毎回計算すること。
iPad は Split View / Stage Manager で幅が変わる。

### Info.plist
- PrimaryLanguage = ja-JP
- IsASCIICapable = false
- RequestsOpenAccess = false（触覚は当面あきらめる）

## 設定パネルも同じ回で作りたい（フェーズ3を前倒し）

理由：Mac を借りている期間が限られていて、
返却後はコードを直せない。数値の調整をアプリ内で完結させたい。

キーボード内にパネルとして持つ（UIAlertController は拡張では使えない）。
保存は拡張自身の UserDefaults。App Group はフルアクセスが要るので使わない。

調整できるようにしたい項目：
- キーの大きさ（倍率）
- キーボード全体の高さ
- 下端からの浮かせ量
- 左右パネルの左右位置
- 右パネルを3列 / 4列
- フリック判定のしきい値
- iPhone横 / iPhone縦 / iPad横 / iPad縦 で別々に保存

「数値で決まるもの」は原則すべて設定パネルに出して、
ハードコードを残さないで。コード変更が要るのは
新機能と不具合修正だけにしたい。

## 進め方
一度に全部やらず、動くところまで進めたら教えて。
私が実機で確認して、結果を報告する。それから次へ。
```

---

## 補足：この後の流れ

1. Claude Code が現状を報告 → 問題があれば先に直す
2. **あなたが Xcode で拡張ターゲットを追加**（GUI 操作。指示が出ます）
3. Claude Code がコードを書く
4. 実機に転送 → **iPad の設定 → 一般 → キーボード → キーボード → 新しいキーボードを追加**
5. 文字入力中に 🌐 を長押しして切り替え、実際に使ってみる
6. 気になる点を Claude Code に伝えて直す（Mac がある間に集中的に）

## Mac を返す前に必ず確認すること

返却後は直せないので、この5つは必ず実機で試してください。

- [ ] メモ、Safari、LINE など**複数のアプリ**で動くか（アプリごとに挙動が違うことがある）
- [ ] iPhone 縦・横、iPad 縦・横の**4パターンすべて**
- [ ] iPad の Split View で幅を変えても崩れないか
- [ ] 設定パネルで変えた値が、**キーボードを閉じて開き直しても残るか**
- [ ] 🌐 で他のキーボードに戻れるか（戻れないと詰みます）

## 覚えておくこと

- 署名は**1年で切れます**。切れるとキーボードが使えなくなるので、
  1年後にまた Mac が要ります（カレンダーに入れておくと安全）
- 触覚フィードバックが欲しくなったら「フルアクセス」の許可が要ります。
  必要なら Mac がある間に `RequestsOpenAccess = true` に変えて試してください
- 音声入力は拡張では使えません。パスワード欄では純正キーボードに戻ります。これは仕様です
