# Sobani（そばに）

> 推しを、そばに。— デスクトップアクスタアプリ

**[公式サイト](https://xn--xckxf.jp/sobani/)** | [GitHub](https://github.com/shiroemons/sobani)

お気に入りのキャラクター画像を、アクリルスタンドのようにデスクトップへ常駐表示する macOS アプリケーションです。アニメーション・音声・AI 会話といった機能は持たず、「好きな画像を飾る」ことだけに特化したシンプルな設計です。

## スクリーンショット

<p align="center">
  <img src="docs/screenshots/sobani-desktop.png" alt="デスクトップ表示" height="300">
  <img src="docs/screenshots/sobani-context-menu.png" alt="コンテキストメニュー" height="300">
  <img src="docs/screenshots/sobani-menubar.png" alt="メニューバー" height="300">
</p>

## 機能

- **フローティングウィンドウ** — 透明な背景で画像を最前面に常時表示。全仮想デスクトップ対応
- **複数ウィンドウ** — 好きなだけ並べて表示。重ね順の管理、Option キー一括操作
- **直感的な操作** — ドラッグ移動、スクロールリサイズ、右クリックメニュー、ダブルクリックでフローティングツールバー
- **画像の管理** — PNG/JPEG/GIF/TIFF/HEIC 対応。登録・切り替え・デフォルト画像のカスタマイズ
- **表示の調整** — 回転（0〜360°）、不透明度（10%〜100%）、左右反転をウィンドウごとに設定
- **画像の切り取り** — iPhone 写真アプリ風クロップエディタ。アスペクト比プリセット、傾き・パースペクティブ補正、Undo/Redo。非破壊編集
- **ゴーストモード** — ウィンドウをクリック透過にして半透明表示。Option+G で一括切り替え。不透明度のカスタマイズ可能
- **簡易背景除去** — 写真から被写体をワンクリック切り抜き
- **レイアウトプリセット** — ウィンドウ配置を保存・ワンクリック復元
- **ウィンドウ状態の保持** — 位置・サイズ・画像・回転・不透明度・ゴーストモードを終了時に自動保存、起動時に復元
- **自動アップデート** — GitHub Releases 経由。SHA256 検証付き
- **画面復元** — モニター切断・スリープ復帰時にウィンドウ位置を自動復元

## インストール

### Homebrew（推奨）

```sh
brew install --cask shiroemons/tap/sobani
```

### 手動インストール

[Releases](https://github.com/shiroemons/sobani/releases) ページから最新の ZIP をダウンロードし、`Sobani.app` を `/Applications` に移動してください。

> **初回起動時**: 「開発元が未確認」と表示される場合は、`Sobani.app` を右クリック →「開く」を選択してください。Homebrew 経由なら不要です。

## クイックスタート

1. `Sobani.app` を起動 → メニューバーにアイコン（👤）が表示されます
2. デフォルト画像が画面中央に表示されます
3. **ドラッグ**で移動、**スクロール**でリサイズ、**右クリック**で各種操作
4. 画像ファイルをウィンドウに**ドラッグ＆ドロップ**で追加（Option+ドロップで差し替え）
5. **Option+H** で全ウィンドウの表示/非表示切り替え

> 詳しい操作方法は [操作ガイド](docs/guide/usage.md) をご覧ください。

## 対応画像形式

PNG（推奨）・JPEG / JPG・GIF・TIFF・HEIC

> スマホ写真（JPEG/HEIC）もそのまま使えます。背景を消したい場合は右クリック →「背景を除去」でワンクリック切り抜き。透過 PNG なら背景なしのアクスタ風表示に。

## ドキュメント

詳細なガイドを `docs/guide/` に用意しています。

### ユーザー向け

- [操作ガイド](docs/guide/usage.md) — メニュー構造、画像管理、調整パネル、ゴーストモード、クロップエディタ
- [アップデートと画面復元](docs/guide/update-and-restore.md) — 自動アップデートの仕組み、エラーコード、モニター復元
- [トラブルシューティング](docs/guide/troubleshooting.md) — ログの確認方法と問題解決

### 開発者向け

- [アーキテクチャ](docs/guide/architecture.md) — コンポーネント関係、ライフサイクル、ウィンドウ構造
- [データフロー](docs/guide/data-flow.md) — ウィンドウ状態の保存・復元、画像管理のデータの流れ

## 開発

- **必要環境**: macOS 14.0+、Xcode 15.0+
- **ビルド**: `./build.sh`（SwiftLint 統合済み）
- **コードスタイル**: [SwiftLint](https://github.com/realm/SwiftLint)（`brew install swiftlint`）

## SNSで共有

Sobaniを使っている様子をぜひSNSでシェアしてください！

- **#SobaniApp** — アプリの感想やスクリーンショットに
- **#デスクトップアクスタ** — あなたのデスクトップを見せてください

## ライセンス

本プロジェクトのソースコードは [MIT License](LICENSE) のもとで公開されています。
