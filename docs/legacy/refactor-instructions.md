# refactor-instructions.md — glaze_manager リファクタリング指示書

作成日: 2026-06-12（コードベース全体の精読と baseline 検証にもとづく）
対象コミット: `2a8384b` (main, 作業ツリークリーン)

> この指示書は実装担当モデル（Codex / Opus 等）への作業指示である。
> **書かれていない変更はしないこと。** 証拠なく大きな削除・全面書き換えをしないこと。
> 目的は「既存仕様を壊さず、負債を減らし、今後変更しやすい状態にする」ことであり、見た目の綺麗さではない。

---

## 1. Objective

1. 精読で確認された**実バグ 2 件**（原料新規作成時のカテゴリ無視、検索画面の初期色検索が発火しない疑い）を、再現テストを先に書いたうえで修正する。
2. 既存計画書（`docs/code_review_and_refactoring_plan_20260612.md`）の**残項目のうち安全に実施できるもの**（モデルの防御的コピー、重複コードの共通化、build() 内 Stream 生成の解消、検索ロジックの抽出）を完了する。
3. 大きな設計変更（ファサード廃止、ColorSwatch リネーム、provider 完全撤去、オフライン保存戦略）は**実装せず提案にとどめる**。
4. 全フェーズを通して `flutter analyze` No issues / `flutter test` 全パスを維持する。

## 2. Project Understanding（前提知識）

### 2.1 何のアプリか
陶芸用の釉薬レシピ・テストピース管理アプリ。Flutter（Windows / macOS / Android）+ Firebase（Auth / Firestore / Storage / Cloud Functions, **Blaze プラン**）。個人利用・オフライン対応必須（`main.dart` で `persistenceEnabled: true`）。仕様の一次資料は `README.md`、直近の包括レビューと進捗は `docs/code_review_and_refactoring_plan_20260612.md`（以下「計画書」）。

### 2.2 アーキテクチャ（2026-06-12 現在。計画書のフェーズ 0〜4 はほぼ実装済み）
- **モデル** `lib/models/`: `Material`(化学成分Map) / `Glaze`(`recipe = {materialId: 配合量}`) / `TestPiece`(各マスターへのID参照 + 画像URL + 色解析データ) / `Clay` / `FiringProfile` / `FiringAtmosphere` / `TagData` / `ColorSwatch`(CIELAB, ΔE計算・sRGB変換内蔵。**Flutter SDK の ColorSwatch と同名のため各所で `hide ColorSwatch`**)
- **リポジトリ** `lib/repositories/`: 汎用基底 `UserScopedRepository<T>`（`users/{uid}/{collection}` の共通CRUD）+ エンティティ別 8 リポジトリ。
- **ファサード** `lib/services/firestore_service.dart`（247行）: 旧 API 名で各リポジトリへ委譲するだけの互換層。**全画面・全テストがこれを経由**（`firestoreServiceProvider` 経由）。
- **データ層 Provider** `lib/providers/data_providers.dart`: 主要 7 コレクションのアプリスコープ `StreamProvider` + 派生 Map。`authStateChangesProvider` を watch してユーザー切替で購読を張り直す。各画面は `ref.watch` で参照（Riverpod 2.6 系）。
- **残存する provider パッケージ**: `SettingsService`(ChangeNotifier) と `AuthService` のみ `main.dart` の `MultiProvider` で供給（移行期間中の併用、計画書 D-3）。
- **サービス**: `AuthService`（匿名/メール/Google サインイン、アカウントリンク、引き継ぎコード。callable は **HTTPS 直叩き**＝cloud_functions プラグインが Windows 非対応のため）/ `StorageService`（docId を含むパスへの画像アップロード、失敗は例外伝播）/ `GlazeImporter`（Excel 2段階インポート: パース→プレビュー→確定）/ `SettingsService`（SharedPreferences）。
- **Cloud Functions** `functions/main.py`（Python 3.13, us-central1, **デプロイ済み**）:
  - `process_uploaded_image`: Storage finalize トリガ。サムネイル200px生成 + K-Means色解析 + Firestore 書き戻し + 旧世代ファイル掃除。**パスの docId からドキュメントを直接解決**（旧形式は imagePath クエリでフォールバック）。
  - `issue_transfer_code` / `redeem_transfer_code`: 引き継ぎコード（SHA-256 ハッシュを docID に保存、無期限、1回使用、再発行で旧コード無効）。
- **セキュリティルール**: `firestore.rules` / `storage.rules`（`users/{uid}/**` を本人のみ）。`rules_test/`（Node + Emulator）でテスト済み。**ルールは安定運用中で変更しない方針**（計画書 D-2）。
- **CI** `.github/workflows/ci.yaml`: analyze + test + モック鮮度チェック（build_runner 再生成して diff が出たら fail）+ Emulator ルールテスト。
- **テスト**: `test/` 41ファイル・138 テスト。画面テストは `ProviderScope(overrides:[firestoreServiceProvider.overrideWithValue(mock)])` + `authStateChangesProvider` の差し替えで実 Firebase に触れない構成（例: `test/screens/test_piece_list_screen_test.dart`）。モックは `test/screens/main_tab_screen_test.mocks.dart`（mockito 生成）。

### 2.3 データフロー（重要な不変条件）
テストピース保存（`test_piece_edit_screen.dart` `_saveTestPiece`）:
1. 新規時は `createTestPieceId()` で **ID を先に発行**
2. 画像があればパスを `users/{uid}/test_pieces/images/{docId}/{uuid}.jpg` に確定
3. **Firestore 書き込みを await で完了**させる（新規は `setTestPiece`、更新は `updateTestPiece`）
4. その後に画像アップロードを**待たずに開始**（失敗はルート ScaffoldMessenger の SnackBar で通知）
5. Cloud Function がアップロード完了後に `imageUrl` / `thumbnailUrl` / `colorData` を書き戻す

この**順序（3→4）と新形式パスは、デプロイ済み Functions との契約**である。崩すと新規テストピースのサムネイル・色解析が欠損する（計画書 C-1 で修正済みの競合が再発する）。また**新画像がある保存では `colorData: []` を明示的に渡す**（Functions が上書きする契約。`test_piece_edit_screen.dart:182`）。

## 3. Behaviors To Preserve（絶対に壊してはいけない挙動）

1. **Firestore スキーマ**: コレクション名（materials / glazes / test_pieces / clays / firing_profiles / firing_atmospheres / tags / view_history、トップレベル transfer_codes）、フィールド名、`users/{uid}/` スコープ、`TestPiece.toFirestore` が書く `relatedGlazeIds`（検索用非正規化フィールド、複合インデックス対象）。
2. **Storage パス形式**: 新形式 `users/{uid}/test_pieces/images/{docId}/{file}` と旧形式（フォルダなし）の互換扱い。
3. **保存順序の不変条件**（§2.3）と、新画像保存時の `colorData: []`。
4. **引き継ぎコードのプロトコル**: クライアントとデプロイ済み Functions の双方に跨る（コード長12、ハッシュ docID、無期限、1回使用、再発行無効化、トークン発行成功後に使用済み化）。
5. **callable の HTTPS 直叩き**（`AuthService._callFunction`）。cloud_functions プラグインへ置き換えないこと（Windows 非対応）。
6. **認証導線**: 匿名サインイン（警告ダイアログ付き）/ Google / メール / 引き継ぎコード、匿名→リンク昇格（uid 維持）。
7. **オフライン永続化**: `persistenceEnabled: true`。
8. **削除確認ダイアログの参照件数警告**（全 6 箇所: 原料×2・釉薬・素地土・焼成雰囲気・焼成プロファイル。計画書 H-2/4-1）。
9. **Excel インポートの 2 段階処理**（パース→プレビューダイアログ→確定）とヘッダー検証（末尾から3列目=「顔料」、末尾=「備考」）、重複名スキップ、新規原料の自動作成。
10. **検索仕様**: スペース区切り AND、`-語` 除外、原料名マッチは釉薬名等マッチより後ろに並ぶ、色検索は ΔE 閾値スライダー + 近い順ソート、タグ AND。
11. **一覧はサムネイル優先**（`thumbnailUrl ?? imageUrl`）、原寸は詳細画面のみ。
12. UI の日本語文言・タブ構成（テストピース/検索/釉薬/原料/設定）・F5 リフレッシュ。
13. 依存バージョン: SDK `^3.9.2`、`flutter_riverpod ^2.6.1`（**3.x へ上げない**。SDK 制約のため。計画書 3-1）。

## 4. Non-Negotiables（作業ルール）

1. **最初に `git status` を確認**する。未コミット変更があれば作業を始めずに報告する。自分の変更と既存の変更を混ぜない。
2. main ブランチで直接作業しない。`refactor/debt-cleanup-YYYYMMDD` 等のブランチを切る。
3. **編集前に baseline を記録**する（§6 のコマンドを実行し、結果を最終報告に含める）。
4. 変更は**フェーズ単位・小さく戻しやすいコミット**にする（目安: 1 画面 or 1 負債項目 = 1 コミット）。
5. **無関係な整形・ついでのリファクタリングをしない**。`dart format` をリポジトリ全体にかけない（触ったファイルのみ可）。
6. 列挙されたバグ修正（R-1〜R-4）以外で**既存挙動を変えない**。
7. 正しい仕様が判断できない場合は**実装を止めて質問**する（§5）。
8. 各フェーズ終了時に `flutter analyze` と `flutter test` を実行し、グリーンでなければ次へ進まない。
9. **依存パッケージの追加・更新・削除をしない**（Phase 7 の提案承認後を除く）。
10. **`firebase deploy` を実行しない**。`functions/`、`firestore.rules`、`storage.rules`、`firestore.indexes.json`、`lib/firebase_options.dart`、`android/ ios/ macos/ web/ windows/ linux/` のネイティブ設定は**変更禁止**（Phase 7 の提案文書を除く）。
11. テストの削除・skip 禁止。テストの期待値を変える必要が生じた場合は、なぜ変えるのが正しいのかを報告に明記する。
12. `FirestoreService` のメソッドシグネチャを変えた場合は `dart run build_runner build --delete-conflicting-outputs` でモックを再生成し、生成物もコミットする（CI が鮮度を検証する）。

## 5. Stop And Ask Conditions（止まって質問する条件）

- Firestore に**保存されるデータの形**（フィールド名・型・値）が変わる変更が必要になったとき。
- `functions/main.py`・セキュリティルール・インデックス定義に手を入れたくなったとき。
- 認証・引き継ぎコード・課金（Blaze 無料枠）に影響しうる変更。
- **テストと実装が矛盾**しているのを見つけたとき（どちらが正かを勝手に決めない）。
- Phase 5 の防御的コピー導入で実行時エラーやテスト失敗が出て、**そのコレクション変更が意図的な実装か判断できない**とき。
- 削除候補のコードが本当に未使用か確信できないとき（`flutter analyze` と grep の両方で根拠を示せない場合）。
- この指示書と計画書（docs/）の記述が食い違うとき。
- 互換性（旧形式 Storage パス、旧データのフィールド欠損へのデフォルト値処理）を壊す可能性に気づいたとき。

## 6. Baseline Commands（検証コマンドと 2026-06-12 時点の結果）

リポジトリルートで実行する。

| コマンド | 用途 | 2026-06-12 の結果 |
|---|---|---|
| `git status` | 作業前確認 | clean (main, `2a8384b`) |
| `flutter analyze` | 静的解析 | **No issues found** |
| `flutter test` | 単体・ウィジェットテスト | **138 件 全パス** |
| `dart run build_runner build --delete-conflicting-outputs` | モック再生成 | 差分なし（CI が検証） |
| `firebase emulators:exec --only firestore,storage --project demo-glaze-manager "npm --prefix rules_test test"` | ルールテスト（要 firebase-tools + Java。ローカルで環境がなければ CI に委ねてよい） | 9/9 パス（計画書 1-1） |

このセッションで baseline を再実行し、上記と一致することを確認・記録してから編集を始めること。

## 7. Debt Map（負債一覧）

優先度: ★★★=バグ/退行疑い ★★=構造的負債 ★=軽微。
「実装可否」: ✅=このタスクで実装してよい / 🔶=再現確認後に実装 / 🛑=提案のみ（承認が必要）。

### R-1 ★★★ 原料の新規作成でカテゴリ選択が無視される ✅
- **根拠**: `lib/screens/material_edit_screen.dart:86` — 新規作成分岐で `category: app.MaterialCategory.base` をハードコード。一方 UI のカテゴリ `SegmentedButton`（同 287–310 行）は新規作成時も表示・操作可能で `_selectedCategory` を更新する。更新分岐（96 行）は `_selectedCategory` を使っている。
- **なぜ負債/バグか**: 新規作成画面で「顔料」を選んで保存しても「母剤」で保存される。UI の意図と保存処理が食い違う明確なバグ。
- **影響範囲**: 原料マスターのカテゴリ値。カテゴリは一覧の絞り込み・チップ表示・インポートの顔料判定表示に使われる。
- **付随バグ**: 同ファイル 98 行 `firestoreService.updateMaterial(updatedMaterial);` に **await 漏れ**（エラーが catch されず、他の保存処理と非一貫）。
- **改善案**: 新規分岐も `category: _selectedCategory` にする。98 行に `await` を付ける。
- **検証**: 先に失敗するウィジェットテストを書く（新規作成→顔料選択→保存→mock の `addMaterial` に渡った `Material.category` が pigment であること）。`test/screens/material_edit_screen_test.dart` に追加。
- **リスク**: 低。挙動変更だが「UI の選択が保存される」という自明な意図への修正。

### R-2 ★★★ 検索画面: スポイト/色見本からの初期色検索が自動実行されない疑い 🔶
- **根拠**: `lib/screens/search_screen.dart:386-394` — `initialColor` の適用が `ref.listen(testPiecesProvider, ...)` のコールバック内にのみある。`testPiecesProvider` はアプリスコープ（非 autoDispose）でタブ画面が常時 watch しているため、詳細画面から `SearchScreen(initialColor: ...)` を push した時点で**既に値を持ち、以後データ変更がなければ listen は発火しない**（Riverpod の `ref.listen` は変化時のみ発火）。`initState` では `_searchColor` を設定するだけで `_applyFilters()` を呼ばない。
- **歴史的経緯**: Riverpod 移行前は `_loadInitialData()` 完了後に明示的に適用していた（計画書 H-4 / 3-3）。移行コミット `4d7cea8` で導入された退行の可能性が高い。既存テスト `test/screens/search_screen_test.dart` は initialColor を扱っていない（未カバー）。テストでは provider を新規生成するため stream の初回 emit で listen が発火し、**テストでは再現せず実機でのみ発生**しうる点に注意。
- **影響範囲**: テストピース詳細のスポイト検索・色見本タップ→検索画面遷移という主要動線。
- **改善案**: まず再現テストを書く（overrides で **値を先に流し終えた provider 状態**を作ってから pump し、検索結果ビューが出るかを検証。例: `testPiecesProvider.overrideWith((ref) => Stream.value(data))` では初回 emit で発火してしまうため、`pumpWidget` 後に一度 settle してから `SearchScreen(initialColor: ...)` を push する構成にする等、実機条件を模す)。再現したら、`initState` で `WidgetsBinding.instance.addPostFrameCallback`（または build 内で `testPiecesAsync.hasValue && !_appliedInitialColor` のとき post-frame で `_applyFilters()`）により初回適用する。`ref.listen` による追従はそのまま残す。
- **検証**: 新規テスト + 既存 search テスト全パス。可能なら手動確認（テストピース詳細→色見本タップ→検索結果が即表示される）。
- **リスク**: 低〜中。再現しなかった場合は**修正せず**「退行なし」と報告して閉じる。

### R-3 ★★ build() 内での Stream 生成（再購読・スピナー点滅・読み取り増） ✅
- **根拠**:
  - `lib/screens/glaze_detail_screen.dart:26` `getGlazeStream(glaze.id!)`、同 `:201` `getTestPiecesForGlaze(glazeId)` — build 内で毎回新しい Stream を生成して StreamBuilder に渡している。この画面は `materialsProvider` も watch しているため、原料データ変化のたびに再購読し `ConnectionState.waiting` で全画面スピナーに戻る。
  - `lib/screens/test_piece_detail_screen.dart:66` `getTestPieceStream(...)` — 同様。こちらは 6 つの provider を watch しており再購読頻度が高い。
  - `lib/screens/material_detail_screen.dart:24` `getMaterialStream(...)` — 同様。
  - `lib/screens/search_screen.dart:674-676` `getRecentTestPieceIds()` — **検索バーの 1 キーストロークごとに** setState → rebuild → view_history クエリを再購読する。
- **なぜ負債か**: Flutter の既知アンチパターン。リスナーの張り剥がしコスト、Firestore 読み取りの無駄、UI の点滅。計画書 M-1 の「重複購読の排除」の取り残し。
- **改善案**: `lib/providers/data_providers.dart` に autoDispose family の StreamProvider を追加し、4 箇所を `ref.watch` に置き換える:
  ```dart
  final glazeByIdProvider = StreamProvider.autoDispose.family<Glaze, String>(
    (ref, id) => ref.watch(firestoreServiceProvider).getGlazeStream(id));
  final testPieceByIdProvider = StreamProvider.autoDispose.family<TestPiece, String>(...);
  final materialByIdProvider = StreamProvider.autoDispose.family<Material, String>(...);
  final testPiecesForGlazeProvider = StreamProvider.autoDispose.family<List<TestPiece>, String>(...);
  final recentTestPieceIdsProvider = StreamProvider.autoDispose<List<String>>(
    (ref) => ref.watch(firestoreServiceProvider).getRecentTestPieceIds());
  ```
  ローディング/エラー時の表示文言は現状と同一に保つ（`AsyncValue.when` で対応付ける）。
- **影響範囲**: 詳細 3 画面 + 検索の「最近見たテストピース」。
- **検証**: 既存の各画面テストが（mock の同メソッドを呼ぶため）そのまま通るはず。通らない場合は表示状態の対応漏れを疑う。1 画面 = 1 コミット。
- **リスク**: 中。表示分岐（waiting/error/データなし）の写し間違いに注意。挙動は等価を維持。

### R-4 ★★ ログイン画面のサインイン失敗が無通知 ✅
- **根拠**: `lib/screens/login_screen.dart:257-262` — `_signIn` の catch が `GoogleSignInCanceled` 以外も `debugPrint` のみで握りつぶす。ユーザーには何も表示されない（計画書 M-7 の残り）。
- **改善案**: キャンセル以外の例外時に SnackBar（例: 「サインインに失敗しました: $e」）を表示。`mounted` ガード必須。
- **検証**: `test/screens/login_screen_test.dart` にテスト追加（AuthService mock が throw → SnackBar 文言）。既存テスト全パス。
- **リスク**: 低。

### R-5 ★★ 未保存確認 PopScope の重複実装（共通ウィジェット未使用） ✅
- **根拠**: `UnsavedChangesPopScope`（`lib/widgets/common/unsaved_changes_pop_scope.dart`）と全く同じダイアログ込みの PopScope を 3 画面がインライン再実装している:
  `clay_edit_screen.dart:82-106` / `firing_atmosphere_edit_screen.dart:84-108` / `firing_profile_edit_screen.dart:114-141`。
  さらに同 3 画面は AppBar の保存ボタン+ローディング表示も `CommonAppBarActions` を使わず手書きしている。
- **なぜ負債か**: 文言・挙動修正が 4 箇所に分散する。共通化済みの他 3 画面（glaze_edit / material_edit / test_piece_edit）と非対称。
- **改善案**: 3 画面を `UnsavedChangesPopScope(isDirty: _isDirty, child: ...)` + `CommonAppBarActions(isLoading: _isLoading, onSave: ..., onDelete: null)` に置き換える。ダイアログ文言は完全一致しているため挙動は等価。スピナーの見た目（サイズ 24・色）のみ僅かに変わる。
- **付随修正**: `common_app_bar_actions.dart:25` のスピナーが `color: Colors.black` 固定でダークテーマで見えない → 色指定を外す（テーマ既定色に任せる）。
- **検証**: 該当 3 画面のテスト（clay_edit / firing_atmosphere_edit / firing_profile_edit）+ 共通化済み画面のテストが全パス。スピナー色のアサーションがあれば追従修正し報告。
- **リスク**: 低。

### R-6 ★★ Firestore からの数値復元が int 値で実行時例外になりうる ✅
- **根拠**: `lib/models/glaze.dart:31` `Map<String, double>.from(data['recipe'])`、`lib/models/material.dart:46` 同様。Firestore の数値は整数で保存されていると `int` で返るため、`Map<String, double>.from` は実行時に型エラーを投げる。現行アプリは常に double で書くため顕在化していないが、手作業・外部ツール・将来のインポート形式変更で壊れる。`ColorSwatch.fromMap` は既に `(v as num?)?.toDouble()` で安全に書かれており非対称。
- **改善案**: `recipe` / `components` の復元を `map.map((k, v) => MapEntry(k, (v as num).toDouble()))` 形式に変更。`FiringProfile.reductionStartTemp/EndTemp`（int）は現状のままでよい。
- **検証**: `test/models/glaze_test.dart` / `material_test.dart` に「int 値を含むデータから復元できる」テストを追加。
- **リスク**: 低（読み取りの寛容化のみ。書き込み形式は不変）。

### R-7 ★★ モデルのコレクションフィールドが可変（エイリアシング事故の温床） ✅（ただし下記の注意厳守）
- **根拠**: 計画書 1-5 の未実施項目。`Glaze.recipe/tags`、`TestPiece.additionalGlazeIds/colorData`、`Material.components` は呼び出し元のリスト/マップへの参照をそのまま保持する。過去に `_colorData.clear()` が保存データを壊しかけた実績がある（計画書 M-6。現在は呼び出し側のコピーで回避済み: `test_piece_edit_screen.dart:69,182`）。
- **改善案**: 各モデルのコンストラクタで防御的コピーを取る（イニシャライザで `tags = List.of(tags)` のように）。`List.unmodifiable` まで踏み込むかは任意だが、**踏み込む場合はモデルのコレクションを直接 mutate している箇所がないことを grep（`.add(` `.remove(` `.clear(` 等）と全テストで確認**してから。画面側は `widget.glaze?.tags.toList()` のようにコピーしてから編集する実装になっているはず — 例外を見つけたら R-7 はコピーのみに留めて報告。
- **検証**: モデル単体テストに「コンストラクタに渡したリストを後から変更してもモデルに影響しない」を追加。全テストパス。
- **リスク**: 中。unmodifiable は実行時例外に化けるため、防御的コピー（List.of/Map.of）を既定とし、unmodifiable は任意。

### R-8 ★★ 検索ロジックが State に埋め込まれユニットテスト不能 ✅
- **根拠**: `lib/screens/search_screen.dart:93-217` `_applyFilters()` — テキスト/タグ/色フィルタとソートが State メソッド内にあり、ウィジェットテストでしか検証できない（887 行で最大の画面。計画書 3-4 の「フィルタ・ソートロジックの ViewModel 分離は未着手」に対応）。
- **改善案**: フィルタ部を純関数（例: `lib/services/test_piece_search.dart` に `List<TestPiece> filterTestPieces({required List<TestPiece> pieces, required String query, required List<String> selectedTags, Color? color, double deltaEThreshold, required Map<String,Glaze> glazeMap, ...})`）として抽出し、`_applyFilters` はそれを呼ぶだけにする。**先に現挙動を固定するユニットテストを書いてから移す**（AND 検索 / `-` 除外 / 原料マッチが後ろに並ぶ / 色ソート / タグ AND / 釉薬が glazeMap にないピースは除外、の各ケース）。
- **検証**: 新規ユニットテスト + 既存 `search_screen_test.dart` 全パス。
- **リスク**: 中。ロジックの写し間違い防止のためテスト先行を必須とする。

### R-9 ★ 検索画面のソース可読性（Unicode エスケープ・正規表現の二重定義） ✅
- **根拠**: `lib/screens/search_screen.dart:420,435` に `「-語」...`・`'... を除外'` 等のエスケープ表記（他ファイルは日本語リテラル）。また語分割の正規表現がフィルタ側 `\s+`（104 行）とチップ側 `[ 　]+`（417, 440 行）で二重定義。Dart(ECMAScript) の `\s` は U+3000 を含むため**実害はない**（計画書 4-3 で確認済み）が、同じ概念が 2 表記なのは事故のもと。
- **改善案**: エスケープを日本語リテラルへ戻す。分割正規表現を `static final _termSplitter = RegExp(r'\s+');` の 1 定数に統一して両方から使う。
- **検証**: `flutter test`（検索のチップ表示テストが存在する）。
- **リスク**: 低。

### R-10 ★ DropdownButtonFormField の非推奨 API を ignore で抑制 ✅
- **根拠**: `lib/screens/firing_atmosphere_edit_screen.dart:138-139` — `// ignore: deprecated_member_use` 付きで `value:` を使用。`test_piece_edit_screen.dart:491,512` は既に `initialValue:` へ移行済みで非対称。
- **改善案**: `initialValue:` に置き換えて ignore コメントを削除。
- **検証**: 該当画面テスト。
- **リスク**: 低。

### R-11 ★ ImageCropScreen の戻り値が非型付き Map ✅（任意）
- **根拠**: `lib/screens/image_crop_screen.dart:79-82` が `{'fileName':…, 'bytes':…}` の `Map<String, dynamic>` を返し、受け側 `test_piece_edit_screen.dart:104-117` が文字列キーで取り出す。
- **改善案**: Dart 3 のレコード `({String fileName, Uint8List bytes})` 化。
- **リスク**: 低。時間が余った場合のみ。

### R-12 🛑 FirestoreService ファサードの去就（提案のみ）
- **根拠**: `lib/services/firestore_service.dart` は委譲のみの互換層だが、全画面と全テストモックの結節点になっている。docstring には「新規コードは個別リポジトリを直接使用してよい」とある。
- **論点**: 画面を `materialRepositoryProvider` 等へ直結しファサードを削除すれば一層薄くなるが、41 テストファイルのモック構成を全面書き換える大手術で、ユーザー価値はない。
- **指示**: **実装しない**。Phase 7 で「維持 / 段階移行 / 一括移行」の比較と推奨（維持）を 1 ページにまとめて提案する。

### R-13 🛑 ColorSwatch → LabColor リネーム（提案のみ、承認後は実施可）
- **根拠**: Flutter SDK の `ColorSwatch` と衝突し、6 ファイル以上で `hide ColorSwatch` が必要（計画書 Low 指摘）。シリアライズキー（'L','a','b','percentage'）はクラス名と無関係なので**保存データへの影響はない**。
- **指示**: 機械的リネームだが diff が広いため、オーナー承認を確認してから単独コミットで実施。承認が確認できなければ提案のみ。

### R-14 🛑 provider パッケージの完全撤去（SettingsService / AuthService の Riverpod 化）（提案のみ）
- **根拠**: `main.dart:35-44` で移行期間中の併用と明記。残 2 サービスを Riverpod（`ChangeNotifierProvider` 相当 or `Notifier`）へ移せば provider 依存を消せるが、ほぼ全画面テストのセットアップ変更を伴う。
- **指示**: 実装しない。移行手順（テスト含む影響ファイル一覧付き）を提案として書く。

### R-15 🛑 オフライン時の保存 UX（要確認 → 提案のみ）
- **根拠**: 全保存フローが Firestore 書き込みを `await` する（例: `glaze_edit_screen.dart:143-149`、`clay_edit_screen.dart:54`、`test_piece_edit_screen.dart:191-195`）。cloud_firestore の write Future は**サーバー ACK まで完了しない**仕様のため、オフラインでは保存ボタンが無限スピナーになり pop されない可能性が高い（書き込み自体はローカルキューに乗り、リスナーには即反映される）。README はオフライン編集を必須要件と明記しており矛盾しうる。
- **指示**: **コードを変えない**。§9 の質問 Q2 の回答待ち。提案として「await をやめ楽観的に pop する」「タイムアウト付き await」「接続状態で分岐」の比較を書く。

### R-16 🛑 Cloud Functions の細部（提案のみ）
- **根拠**: `functions/main.py:330-341` の `firebaseStorageDownloadTokens` メタデータ手動生成（非公式 API 依存、計画書 M-9）、色解析パラメータのハードコード、引き継ぎコードと画像パイプラインが 1 ファイル同居。
- **指示**: デプロイ権限がないため**変更禁止**。改善提案のみ。

### R-17 ★ 計画書の進捗表が古い ✅（ドキュメントのみ）
- **根拠**: `docs/code_review_and_refactoring_plan_20260612.md` のフェーズ 0-3 に「`analyze_output.txt` の削除のみ残」とあるが、ファイルは既に存在しない。0-5「コミット & push で有効化」も完了済み（CI はリポジトリに存在）。
- **指示**: 最終フェーズで進捗表を実態に合わせて更新し、本指示書による変更を追記する。

### 触らない・問題なしと判断したもの（疑って時間を使わないこと）
- `MainTabScreen` のタブ定義はデータ駆動化済み（`_TabDefinition` リスト）。GlobalKey + null 安全キャストの F5 リフレッシュは許容（計画書 3-5）。
- インポートの 2 パス化・タグの `addAll` バッチ・`findOrCreate` の重複受容（単一ユーザー前提）は計画書 1-4 / D 判断で確定済み。
- `firing_chart.dart` のチャート補間ロジック、`mixing_calculator_screen.dart` の双方向換算、`ColorSwatch` の Lab⇔sRGB 変換・CIE76 ΔE は正しく実装されている（CIEDE2000 化はロードマップであり本タスク外）。
- セキュリティルールとルールテスト一式。

## 8. Implementation Phases（実施順）

> 各フェーズの完了条件: `flutter analyze` No issues / `flutter test` 全パス / フェーズ内容のコミット完了。

### Phase 0: 現状確認と baseline 記録
1. `git status`（clean でなければ停止・報告）。ブランチ作成。
2. `flutter analyze` / `flutter test` を実行し、§6 の baseline と一致することを記録。
3. 不一致なら停止・報告。

### Phase 1: 安全網（バグの再現テストを先に書く）
1. R-1 の失敗するウィジェットテストを追加（この時点では red であることを確認・記録）。
2. R-2 の再現テストを追加（red になるか green になるかを記録。green なら R-2 は「退行なし」でクローズ）。
3. テストのみのコミット（red のままコミットせず、Phase 2 の修正と同一コミットにしてもよい。どちらにしたかを報告）。

### Phase 2: バグ修正（小粒・1 件 = 1 コミット）
1. R-1: カテゴリ反映 + `await` 追加 → Phase 1 のテストが green になること。
2. R-2: 再現した場合のみ修正。
3. R-4: サインイン失敗の SnackBar。
4. R-10: `initialValue:` 化。

### Phase 3: 機械的な重複排除・表記統一
1. R-5: 3 画面の PopScope / AppBar アクション共通化 + スピナー色修正（1 画面 = 1 コミットでも、まとめて 1 コミットでもよい）。
2. R-9: Unicode エスケープ解消・正規表現定数化。
3. （任意）R-11。

### Phase 4: build() 内 Stream 生成の解消（R-3）
1. family プロバイダを `data_providers.dart` に追加（テストの override 方法をコメントで示す）。
2. `material_detail_screen` → `glaze_detail_screen` → `test_piece_detail_screen` → `search_screen`（閲覧履歴）の順に、**1 画面 = 1 コミット**で置換。
3. 各コミットでテスト全パスを確認。表示分岐（loading / error / 空）の文言は現状維持。

### Phase 5: モデルの堅牢化
1. R-6: 数値復元の `num.toDouble()` 化 + モデルテスト追加。
2. R-7: 防御的コピー + エイリアシング非共有のテスト追加。unmodifiable 化は mutate 箇所ゼロを確認できた場合のみ。

### Phase 6: 検索ロジック抽出（R-8）
1. 現挙動を固定するユニットテストを先に作成（純関数の入出力として記述）。
2. `_applyFilters` から純関数へ移動。画面側は呼び出しと setState のみ。
3. 既存ウィジェットテスト全パス。

### Phase 7: 提案書の作成（実装しない）
`docs/refactor-proposals-YYYYMMDD.md` に R-12 / R-13 / R-14 / R-15 / R-16 の各提案（現状・選択肢・推奨・影響ファイル・移行手順・リスク）をまとめる。**コードは変更しない。**

### Phase 8: ドキュメント更新と最終報告
1. R-17: 計画書の進捗表更新 + 本作業の結果を追記。
2. §10 の形式で最終報告。

## 9. 実装前に確認すべき質問（オーナー回答待ちの項目）

実装担当モデルへ: **以下は回答がなくても Phase 0〜6, 8 は実施できる**。回答が得られた場合のみ指示に従うこと。

- **Q1. `firestore.indexes.json` はデプロイ済みか？**（`firebase deploy --only firestore:indexes`）
  計画書 1-2 に「デプロイが必要」とあり、コードは複合インデックス前提のサーバーソートクエリ（`test_piece_repository.dart:36-43`）を既に使用中。未デプロイなら釉薬詳細のテストピース一覧が本番でエラーになる。**リポジトリからは確認不能**。→ 実装担当はコードを変えず、最終報告でこの確認を再掲すること。
- **Q2. オフラインで保存（釉薬・原料等）を行うと完了するか？**（R-15）
  無限スピナーになる場合、修正方針（楽観的 pop / タイムアウト付き await / 接続状態分岐）の選択承認が必要。承認まで実装禁止。
- **Q3. `FirestoreService` ファサードは当面維持でよいか？**(R-12) 推奨: 維持。
- **Q4. `ColorSwatch` → `LabColor` リネームを実施してよいか？**(R-13) 推奨: 実施（保存データ影響なし、CI 保護下の機械的変更）。

## 10. Verification Requirements & Reporting Format

### 検証要件
- 各フェーズ終了時: `flutter analyze`（No issues）と `flutter test`（全パス・件数を記録）。
- モック再生成が必要な変更後: `dart run build_runner build --delete-conflicting-outputs` → `git diff` で生成物の差分を確認しコミットに含める。
- 新規テストは「バグ修正前に red / 修正後に green」のログを残す（R-1, R-2）。
- ルールテストはコード変更がルールに触れない限りローカル実行不要（CI に委ねる）。
- 可能な環境であれば手動スモーク（任意・推奨）: アプリ起動 → 各タブ表示 → 釉薬詳細 → テストピース詳細 → 色見本タップ → 検索結果表示。

### 報告フォーマット（フェーズごと）
```
## Phase N: <名前>
- 目的: <1行>
- 変更ファイル: <一覧>
- 実行コマンドと結果: <flutter analyze / flutter test の出力要約。test は件数明記>
- 逸脱・未了・気づき: <なし、または内容>
- 判断を要した点: <あれば。なぜそう判断したか>
```
最終報告には: 全コミット一覧（hash + 1 行説明）、最後に実行した全コマンドと結果、未実施項目（理由付き）、§9 への回答待ち事項の再掲、Phase 7 提案書へのリンク、を含める。

## 11. Out-of-scope（このタスクでやらないこと）

- 計画書 4-8 の配布準備（バージョニング、Android 署名、Crashlytics、main/release ブランチ運用）。
- 新機能: ゼーゲル式/UMF 計算、データエクスポート、カード並び替え、ページング、CIEDE2000 への置換、工房共有。
- 依存パッケージの追加・更新（riverpod 3.x 化、desktop_webview_auth の置換を含む）。
- `firebase deploy` を要する一切の変更（functions / rules / indexes）。
- UI デザイン・文言の刷新、i18n、文字列の定数集約。
- README の全面改稿（事実誤りを見つけた場合は報告のみ）。
- `rules_test/`・CI 定義の変更（壊れている場合は報告のみ）。
