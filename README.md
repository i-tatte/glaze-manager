# glaze_manager

陶芸用の釉薬レシピ・テストピース管理アプリ。
釉薬の調合情報と焼成結果を関連付けて管理し、オフラインでも利用可能。

## 技術スタック

- **Flutter** (Dart, SDK ^3.9.2) — Windows / macOS / Android
- **Firebase** — Auth / Cloud Firestore / Cloud Storage / Cloud Functions (Python 3.13)
- **Riverpod 2.x** — 状態管理

## 主な機能

- テストピースのギャラリー表示（サムネイル自動生成）
- テストピースごとの調合の記録（釉薬を後から編集・削除しても、焼いた時点の調合が残る）
- 焼成回（焼いた日・窯・条件・実績を一度入力し、同じ窯のテストピースで共有）
- 評価（星 1〜5）と番号、2〜4 枚を並べる比較表示
- 連続登録、カメラ撮影（Android）、複数写真の一括選択
- 釉薬レシピの管理と Excel 一括インポート、複製による派生の記録
- 画像からの自動色解析（K-Means, CIELAB）とスポイト色検索
- テキスト / タグ / 色の複合検索（AND 検索、除外検索、ΔE 閾値調整）
- 原料マスター管理（化学成分比の登録）
- 焼成プロファイル・雰囲気・素地土のマスター管理
- オフライン対応（楽観的保存、自動同期、写真のアップロード待ちの保持と再送）
- 全データの書き出し（JSON・Excel・写真を 1 つの ZIP に）
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

### 実アプリの結合テスト（Windows、要 Firebase Emulator + Java）

実アプリを Firebase エミュレータ（デモ用のプロジェクト）に繋いで、登録・写真の送信・書き戻し・オフライン保存と再起動後の送信などを通しで確かめる。実プロジェクトには繋がらない。

```powershell
# 1. エミュレータを起動する（別のターミナルで。Ctrl+C で止める）
tool\emulator\start_emulators.ps1

# 2. Cloud Functions の確認（20 項目）
functions\venv\Scripts\python.exe tool\emulator\functions_emulator_check.py

# 3. 実アプリの通しの確認
tool\emulator\run_it.ps1 -Test app_flow_test.dart -Mode online
tool\emulator\run_it.ps1 -Test app_flow_test.dart -Mode offline_save -Define GM_FIRESTORE_PORT=8599,GM_STORAGE_PORT=8598
tool\emulator\run_it.ps1 -Test app_flow_test.dart -Mode after_restart
```

ログと測った値は `build\it\` に出る。`offline_save` には、誰も待ち受けていないポートを渡す。

## CI

GitHub Actions (`.github/workflows/ci.yaml`) で以下を自動実行:
- `flutter analyze` + `flutter test`
- モック鮮度チェック（`build_runner` 再生成して差分検出）
- Firebase Emulator 上のルールテスト

## ドキュメント

- [仕様書](docs/spec.md) — アプリの機能要件・データモデル・不変条件
- [価値向上の方針](docs/価値向上方針.md) — このアプリが何を目指すか、次に何をするか
- [実装計画書 — 試験ノート化](docs/実装計画_試験ノート化.md) — 2026-11 に実装した 10 項目の計画
- [docs/legacy/](docs/legacy/) — 実施済みのリファクタリング計画・指示書（履歴として保存）
