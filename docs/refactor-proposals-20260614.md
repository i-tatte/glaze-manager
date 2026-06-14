# refactor-proposals-20260614.md — 提案のみ（実装しない項目）

作成日: 2026-06-14
対象ブランチ: `refactor/debt-cleanup-20260614`
前提: `refactor-instructions.md` の Phase 7。**ここに書かれた項目はコードを変更していない。**
オーナーの承認をもって、別タスク・別 PR で実施する想定。

この文書は負債項目 R-12 / R-13 / R-14 / R-15 / R-16 について
「現状・選択肢・推奨・影響ファイル・移行手順・リスク」をまとめる。
末尾に `refactor-instructions.md` §9（オーナー回答待ち Q1〜Q4）への対応関係を再掲する。

---

## R-12 🛑 `FirestoreService` ファサードの去就

### 現状
- `lib/services/firestore_service.dart`（約247行）は各リポジトリ（`materialRepository` 等 8 個）へ
  委譲するだけの互換層。
- 全画面が `firestoreServiceProvider` 経由でこのファサードを参照し、
  **全 41 テストファイルのモック（`MockFirestoreService`）がこの 1 クラスに集約**されている。
- docstring に「新規コードは個別リポジトリを直接使用してよい」とある。

### 選択肢
1. **維持（推奨）**: 現状のまま。ファサードを単一のモック結節点として残す。
2. **段階移行**: 新規・改修する画面のみ個別リポジトリ（`materialRepositoryProvider` 等）へ直結し、
   ファサードは縮小しながら当面残す。
3. **一括移行**: 全画面をリポジトリ直結に書き換え、ファサードを削除。
   41 テストファイルのモック構成（`MockFirestoreService` → 各 `MockXxxRepository`）を全面書き換え。

### 推奨
**1. 維持。** 理由:
- ファサードは「テストが 1 つのモックを差し替えるだけで全 CRUD を制御できる」という実利を生んでいる。
  これを崩すと各画面テストが複数モックのセットアップを抱える。
- 委譲のみで分岐ロジックを持たないため、**バグの温床になっていない**（負債としては軽微）。
- 一括移行はユーザー価値ゼロで、リグレッション面積（41 テスト）だけが大きい。

### 影響ファイル（一括移行を選んだ場合）
- `lib/services/firestore_service.dart`（削除）
- 全画面（約20 ファイル）の `ref.read/watch(firestoreServiceProvider)` 呼び出し
- `lib/providers/data_providers.dart`（リポジトリ Provider の公開）
- `test/**` の `MockFirestoreService` を使う全テスト（約41ファイル）＋ `*.mocks.dart` 再生成

### 移行手順（段階移行を選んだ場合）
1. 各リポジトリの `Provider` を `data_providers.dart` に公開（`materialRepositoryProvider` 等）。
2. 改修対象の画面だけを 1 画面ずつリポジトリ直結に変更し、その画面テストのモックを差し替え。
3. ファサードのメソッドが全く参照されなくなった時点で削除を検討。

### リスク
- 一括移行: 中〜高（テスト全面改修によるリグレッション）。
- 段階移行: 低だが、移行期間中はファサードとリポジトリ直結が混在し一貫性が落ちる。
- 維持: なし。

---

## R-13 🛑 `ColorSwatch` → `LabColor` リネーム

### 現状
- アプリ独自の `lib/models/color_swatch.dart` の `ColorSwatch` が Flutter SDK の
  `ColorSwatch` と名前衝突し、参照側で `import 'package:flutter/material.dart' hide ColorSwatch;`
  が必要。
- 現在 `hide ColorSwatch` は **5 ファイル**で使用中:
  `lib/screens/search_screen.dart` / `lib/screens/test_piece_detail_screen.dart` /
  `lib/screens/test_piece_edit_screen.dart` / `lib/services/test_piece_search.dart` /
  `test/models/color_swatch_test.dart`（本リファクタで `test_piece_search.dart` が 1 件増えた）。
- **シリアライズキーは `'L' / 'a' / 'b' / 'percentage'` でクラス名と無関係**。
  → リネームしても Firestore 保存データ・`functions/main.py` の色解析出力に影響しない。

### 選択肢
1. **`LabColor` にリネーム（推奨・承認後）**: クラス名・ファイル名（`lab_color.dart`）を機械的に変更し、
   各所の `hide ColorSwatch` を削除。
2. 現状維持（`hide` を許容）。

### 推奨
**1. リネーム実施（オーナー承認が前提）。** 保存データへの影響がなく、CI（analyze+test）が保護下で
機械的に検証できるため安全。ただし diff が広い（クラス名出現箇所すべて）ので**単独コミット**にする。

### 影響ファイル
- `lib/models/color_swatch.dart` → `lib/models/lab_color.dart`（クラス名 `ColorSwatch` → `LabColor`、
  `fromColor` / `fromMap` / `toMap` / `deltaE` / `toColor` はそのまま）
- 参照側 5 ファイル（上記）＋ `lib/models/test_piece.dart`（`List<ColorSwatch>` フィールド型）
- `test/models/color_swatch_test.dart` → `test/models/lab_color_test.dart`

### 移行手順
1. クラス名・ファイル名を一括置換。`hide ColorSwatch` を削除し、衝突がなくなったことを analyze で確認。
2. `toMap`/`fromMap` のキー（'L','a','b','percentage'）は**変更しない**（保存互換のため）。
3. `flutter analyze` / `flutter test` 全パスを確認して単独コミット。

### リスク
- 低。機械的リネームで、シリアライズ形式不変。唯一の注意点は「キー名を巻き込んで変えない」こと。

---

## R-14 🛑 provider パッケージの完全撤去（`SettingsService` / `AuthService` の Riverpod 化）

### 現状
- `lib/main.dart` の `MultiProvider` で `ChangeNotifierProvider<SettingsService>` と
  `Provider<AuthService>` を供給（移行期間中の併用、計画書 D-3）。
- 参照箇所:
  - `SettingsService`: `main.dart`（テーマ）, `search_screen.dart`（`context.watch<SettingsService>()` で
    `gridCrossAxisCount`）, `settings_screen.dart` ほか。
  - `AuthService`: `login_screen.dart`（`Provider.of<AuthService>`）, `auth_wrapper.dart`,
    `test_piece_list_screen.dart` 等。
- テスト側は `Provider<AuthService>` / `ChangeNotifierProvider<SettingsService>.value` で
  モックを注入している（`test/screens/` の 5 ファイル: login / search / main_tab / settings /
  test_piece_list）。

### 選択肢
1. **現状維持**: provider と Riverpod を併用。
2. **Riverpod 化（提案）**: `SettingsService` を `ChangeNotifierProvider`（riverpod 2.x）または
   `Notifier` 化、`AuthService` を `Provider` 化し、`package:provider` 依存を削除。

### 推奨
中期的には **2.（Riverpod 一本化）が望ましい**（依存とメンタルモデルが 1 つになる）が、
**ほぼ全画面テストのセットアップ変更を伴う**ため、R-12 のリポジトリ移行とまとめて 1 度に行うのが効率的。
単独での緊急性は低い。

### 影響ファイル
- `lib/main.dart`（`MultiProvider`/`Consumer<SettingsService>` を `ProviderScope` 配下の Riverpod 参照へ）
- `lib/services/settings_service.dart` / `lib/services/auth_service.dart`（Provider 定義の追加）
- 参照画面: `search_screen.dart` / `settings_screen.dart` / `login_screen.dart` /
  `auth_wrapper.dart` / `test_piece_list_screen.dart` ほか
- テスト: `test/screens/{login,search,main_tab,settings,test_piece_list}_screen_test.dart`
  の provider 注入を Riverpod の `overrides` へ移行。`pubspec.yaml` から `provider` を削除。

### 移行手順
1. `settingsServiceProvider = ChangeNotifierProvider((ref) => SettingsService())`、
   `authServiceProvider = Provider((ref) => AuthService())` を定義。
2. `main.dart` の `MultiProvider` を撤去し、`MaterialApp` を `Consumer`（riverpod）でラップして
   テーマを購読。
3. 各画面の `context.watch/read<...>` / `Provider.of<...>` を `ref.watch/read(...)` に置換（1 画面ずつ）。
4. 各画面テストの provider 注入を `ProviderScope(overrides: [...])` へ移行。
5. 全画面が provider 非依存になったら `pubspec.yaml` の `provider` を削除し、`flutter pub get`。

### リスク
- 中。テストセットアップの全面変更による一時的なリグレッション。依存削除（Non-Negotiable 9）は
  **承認後にのみ**実施。

---

## R-15 🛑 オフライン時の保存 UX

### 現状
- すべての保存フローが Firestore 書き込みを `await` する
  （例: `glaze_edit_screen.dart` の `_saveGlaze`、`clay_edit_screen.dart` `_saveClay`、
  `test_piece_edit_screen.dart` `_saveTestPiece`）。
- `cloud_firestore` の write `Future` は**サーバー ACK まで完了しない**仕様。
  オフラインでは書き込みはローカルキューに乗り、リスナー（プロバイダ）には即反映されるが、
  `await` は解決されないため、**保存ボタンが無限スピナーのまま画面が pop されない**可能性が高い。
- `README` はオフライン編集を必須要件としており、矛盾しうる（`refactor-instructions.md` §9 Q2）。
- **本リファクタではコードを変更していない**（要オーナー確認）。

### 選択肢（オーナーの Q2 回答後に 1 つを選ぶ）
1. **楽観的 pop**: 書き込みの `Future` を `await` せず（`unawaited`）に即 pop。失敗はルートの
   `ScaffoldMessenger` で SnackBar 通知（テストピース画像アップロードと同じ方式）。
   - 利点: オフラインでも即完了。リスナーで楽観反映済み。
   - 注意: §2.3 の保存順序不変条件（テストピースは「Firestore 書き込み完了 → 画像アップロード開始」）を
     崩さないこと。テストピース保存だけは現行の await 順序を保つか、別途設計が必要。
2. **タイムアウト付き `await`**: `.timeout(Duration(seconds: N))` で、超過時はローカル保存済みとみなして
   pop。
   - 利点: オンライン時は従来どおり、オフライン時のみ救済。
   - 注意: タイムアウト値の決定。誤検知時に「保存された」表示が出る。
3. **接続状態で分岐**: `connectivity_plus` で接続を確認し、オフラインなら楽観的 pop、オンラインなら
   `await`。
   - 利点: 体験が一番自然。
   - 注意: 分岐ぶんの複雑性と接続判定の信頼性。

### 推奨
まず **Q2 の実機確認（オフラインで保存が完了するか）を取得**するのが先。
無限スピナーが再現する場合の方針推奨は **1.（楽観的 pop）+ SnackBar 通知**。
理由: 個人利用・オフライン必須という要件に最も合致し、Firestore のローカルキャッシュが
楽観反映を担保するため。ただし**テストピース保存は §2.3 の順序契約があるため例外的に現行 await を維持**し、
他マスター（釉薬・原料・素地土・焼成）から先に適用する。

### 影響ファイル
- `lib/screens/{glaze,material,clay,firing_atmosphere,firing_profile}_edit_screen.dart` の保存処理
- （慎重に）`lib/screens/test_piece_edit_screen.dart`（順序契約に注意）
- 各画面テスト（pop の期待値）

### リスク
- 中。楽観的 pop は「実際には書き込み失敗だが UI 上は成功」に見えるケースを生む。
  SnackBar 通知とリトライ導線の設計が要る。**承認まで実装しない。**

---

## R-16 🛑 Cloud Functions（`functions/main.py`）の細部

### 現状（**デプロイ権限がないため変更禁止**。提案のみ）
- `firebaseStorageDownloadTokens` メタデータの手動生成（非公式 API 依存、計画書 M-9）。
- 色解析パラメータ（K-Means のクラスタ数・サムネイル 200px 等）のハードコード。
- 引き継ぎコード処理（`issue/redeem_transfer_code`）と画像パイプライン（`process_uploaded_image`）が
  1 ファイルに同居。

### 選択肢
1. 現状維持。
2. リファクタ提案（承認・デプロイ体制が整ってから）:
   - ダウンロード URL は手動トークン生成をやめ、公式の署名付き URL 生成
     （`generate_signed_url`）または Storage SDK の正規手段へ。
   - 色解析パラメータを環境変数 / 設定ドキュメント化。
   - 引き継ぎコードと画像処理をモジュール分割（`transfer_codes.py` / `image_pipeline.py`）。

### 推奨
**現状維持（このタスクでは変更しない）。** クライアントとデプロイ済み Functions の契約
（§2.3 / §3 の不変条件）に跨るため、変更にはデプロイとルール/インデックスの再検証が必須。
改善はデプロイ権限と検証環境（Emulator + 本番相当）が用意できた段階で別タスク化する。

### 影響ファイル
- `functions/main.py`（＋分割する場合は新規モジュール）
- 影響波及: Storage パス契約、`TestPiece` の `imageUrl/thumbnailUrl/colorData` 書き戻し、
  引き継ぎコードのプロトコル。

### リスク
- 高（本番デプロイ・課金・データ契約に直結）。**このリファクタの対象外。**

---

## `refactor-instructions.md` §9（オーナー回答待ち）への対応

| 質問 | 内容 | 本リファクタでの扱い |
|---|---|---|
| **Q1** | `firestore.indexes.json` はデプロイ済みか（複合インデックス前提のサーバーソート） | **リポジトリからは確認不能**。コードは変更せず、最終報告で再掲（要オーナー確認）。 |
| **Q2** | オフライン保存は完了するか（R-15） | 実機確認待ち。再現する場合の方針は R-15 の「楽観的 pop」を推奨。**承認まで実装しない。** |
| **Q3** | `FirestoreService` ファサードは維持でよいか（R-12） | **推奨: 維持。** 上記 R-12 参照。 |
| **Q4** | `ColorSwatch` → `LabColor` リネーム実施可否（R-13） | **推奨: 実施（保存データ影響なし・CI 保護下）。** 承認が得られれば単独コミットで対応可能。 |
