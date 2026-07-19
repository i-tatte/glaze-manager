# glaze_manager

陶芸用の釉薬レシピ・テストピース管理アプリ。
釉薬の調合情報と焼成結果を関連付けて管理し、オフラインでも利用可能。

## 技術スタック

- **Flutter** (Dart, SDK ^3.9.2) — Windows / macOS / Android
- **Firebase** — Auth / Cloud Firestore / Cloud Storage / Cloud Functions (Python 3.13)
- **Riverpod 2.x** — 状態管理

## 主な機能

- テストピースのギャラリー表示（サムネイル自動生成）
- 釉薬レシピの管理と Excel 一括インポート
- 画像からの自動色解析（K-Means, CIELAB）とスポイト色検索
- テキスト / タグ / 色の複合検索（AND 検索、除外検索、ΔE 閾値調整）
- 原料マスター管理（化学成分比の登録）
- 焼成プロファイル・雰囲気・素地土のマスター管理
- オフライン対応（楽観的保存、自動同期）
- 匿名 / Google / メール認証、アカウントリンク、引き継ぎコード

## セットアップ

### 前提条件

- Flutter SDK ^3.9.2
- Firebase プロジェクト（Blaze プラン）

### Firebase 設定

1. `firebase_config.example.json` を `firebase_config.json` にコピー
2. [Firebase Console](https://console.firebase.google.com/) から各プラットフォームの API キーを取得して記入

### ビルド・実行

```bash
flutter pub get
flutter run --dart-define-from-file=firebase_config.json
```

### テスト

```bash
flutter analyze
flutter test
```

### Cloud Functions デプロイ

```bash
cd functions
firebase deploy --only functions
```

### セキュリティルールテスト（要 Firebase Emulator + Java）

```bash
firebase emulators:exec --only firestore,storage --project demo-glaze-manager "npm --prefix rules_test test"
```

## CI

GitHub Actions (`.github/workflows/ci.yaml`) で以下を自動実行:
- `flutter analyze` + `flutter test`
- モック鮮度チェック（`build_runner` 再生成して差分検出）
- Firebase Emulator 上のルールテスト

## ドキュメント

- [仕様書](docs/spec.md) — アプリの機能要件・データモデル・不変条件
- [docs/legacy/](docs/legacy/) — 実施済みのリファクタリング計画・指示書（履歴として保存）
