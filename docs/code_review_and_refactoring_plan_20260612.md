# glaze_manager コードレビュー & リファクタリング計画 (2026-06-12)

本ドキュメントは、glaze_manager リポジトリ全体（Flutter クライアント `lib/`、Cloud Functions `functions/`、テスト `test/`、Firebase 設定）を対象とした包括レビューの調査内容・結果と、それに基づくリファクタリング計画・今後の実装計画をまとめたものである。単体で読めるよう、前提情報もすべて本文中に記載する。

---

## 1. 調査概要

### 1.1 対象と方法

- 対象ブランチ: `release`（作業ツリーはクリーン。`main` と多数のフィーチャーブランチが存在）
- 調査方法: 全モデル・全サービス・主要画面のソース精読、`flutter analyze` 出力（リポジトリ同梱の `analyze_output.txt`）の確認、Firebase 設定ファイル・Cloud Functions・テスト構成の確認
- コード規模: `lib/` 配下 51 ファイル（models 8 / services 5 / screens 24 / widgets 9 / theme 2 / main, firebase_options）、Cloud Functions は Python 1 ファイル（約 220 行）、テストは 41 ファイル

### 1.2 アプリ構成（現状把握）

陶芸用の釉薬レシピ・テストピース管理アプリ。Flutter（Windows / macOS / Android 対象）+ Firebase（Auth / Firestore / Storage / Functions）。

- **データモデル** (`lib/models/`): `Material`（原料、化学成分 Map 保持）、`Glaze`（釉薬、`recipe = {materialId: 配合量}`）、`TestPiece`（テストピース、釉薬・素地土・焼成プロファイル・焼成雰囲気への ID 参照と画像 URL・色解析データ）、`Clay`、`FiringProfile`、`FiringAtmosphere`、`TagData`、`ColorSwatch`（CIELAB 色、ΔE 計算と sRGB⇔Lab 変換を内蔵）
- **サービス層** (`lib/services/`): `FirestoreService`（全コレクションの CRUD を 1 クラスに集約、647 行）、`AuthService`（匿名 / メール / Google サインイン）、`StorageService`（テストピース画像のアップロード・削除）、`SettingsService`（SharedPreferences によるテーマ・グリッド列数）、`GlazeImporter`（Excel 一括インポート）
- **画面**: タブ 5 画面（テストピース一覧 / 検索 / 釉薬一覧 / 原料一覧 / 設定）+ 各エンティティの詳細・編集画面 + 調合計算・画像トリミング・ログイン
- **Cloud Functions** (`functions/main.py`, Python 3.13): Storage への画像アップロードをトリガに、①サムネイル生成（200px）②K-Means + 凝集マージによる釉薬色解析（CIELAB）③Firestore ドキュメントへの URL・色データ書き戻し
- **Firestore データ構造**: すべて `users/{uid}/` 配下のサブコレクション（materials / glazes / test_pieces / clays / firing_profiles / firing_atmospheres / tags / view_history）。ユーザー間共有なし

### 1.3 全体評価

機能は一通り動く水準にあり、`UnsavedChangesPopScope` や `CommonAppBarActions` など共通化の萌芽、41 ファイルのテスト、Cloud Functions による色解析パイプラインなど、個人開発としては丁寧に作られている。一方で、**(a) 保存フローの非同期処理に設計上の競合・データ欠損リスクがある**、**(b) セキュリティルールがリポジトリ管理外**、**(c) テストのモックが古くテストスイートがコンパイル不能**、**(d) 画面がデータ層に直結しており状態管理層がない**（5 重ネストの StreamBuilder 等）という構造的な課題があり、機能追加を続ける前に基盤整備を挟むべき段階にある。

---

## 2. 指摘事項

重要度の定義: **Critical** = データ破損・喪失やセキュリティに直結 / **High** = 明確なバグまたは高確率で問題化 / **Medium** = 設計・保守性の問題 / **Low** = 軽微・スタイル。

### 2.1 Critical

#### C-1. 画像アップロードと Firestore 書き込みの競合（新規テストピースのサムネイル・色解析が欠損する）

`lib/screens/test_piece_edit_screen.dart` の `_saveTestPiece()`（136 行目付近）は、**画像アップロードを await せずに開始してから** `addTestPiece()` でドキュメントを作成する。一方 Cloud Functions 側（`functions/main.py` の `process_uploaded_image`）はアップロード完了をトリガに `imagePath == file_path` でドキュメントを**1 回だけ検索し、見つからなければ何もせず終了する**（リトライなし）。

→ 新規作成時、アップロードが Firestore 書き込みより先に完了すると（小さい画像・高速回線で十分起こる）、`imageUrl` / `thumbnailUrl` / `colorData` が永久に設定されず、画像なしのテストピースになる。Storage 上のファイルも孤児化する。

**対処方針**: ドキュメント作成を先に await → その後アップロード開始、が最小修正。恒久対応はファイルパスに docId を含め（`users/{uid}/test_pieces/images/{docId}/{uuid}.jpg`）、Functions がパスから docId を直接特定する方式（検索クエリ自体を排除でき、競合が原理的に消える）。

#### C-2. Firestore / Storage セキュリティルールがリポジトリに存在しない

リポジトリ内に `firestore.rules` / `storage.rules` がなく、`firebase.json` にも rules / indexes のエントリがない。ルールはコンソール上でのみ管理されている状態で、①現在のルールが適切か検証不能、②誤操作・初期値のまま全公開になっていても気づけない、③環境再構築ができない。

**対処方針**: 現行ルールをエクスポートしてリポジトリに取り込み、`firebase.json` に登録。最低限「`users/{uid}/**` は `request.auth.uid == uid` のみ読み書き可、それ以外は拒否」を明文化し、Firebase Emulator + ルールテストを CI に追加する。

**追記（2026-06-12）**: コンソール上の現行ルールを確認したところ内容は上記の通り適切であり、無防備ではなかった。同日、`firestore.rules` / `storage.rules` としてリポジトリに取り込み `firebase.json` に登録済み（→ 決定事項 D-2）。残作業は Emulator ルールテストの追加のみ。

#### C-3. 画像アップロード失敗が完全に握りつぶされる

`lib/services/storage_service.dart` の `uploadTestPieceImage()` は失敗を `debugPrint` のみで吸収し（catch → ログ → 正常終了）、呼び出し側（C-1 と同じ保存フロー）も fire-and-forget。失敗してもユーザーに通知されず、`imagePath` だけが設定された壊れたドキュメントが残る。`deleteTestPieceImage()` も同様に握りつぶす。

**対処方針**: アップロードを「保留中 → 完了/失敗」の状態としてドキュメントまたはローカルキューで管理し、失敗時は再試行 UI を出す。少なくとも例外を上に投げ、SnackBar 等で通知する。

### 2.2 High

#### H-1. テストスイートがコンパイル不能（モック陳腐化）

`analyze_output.txt` 末尾に error が 1 件: `test/screens/main_tab_screen_test.mocks.dart:209` の `MockStorageService.uploadTestPieceImage` のシグネチャ（`Future<String?> Function(XFile?)`）が現行の `StorageService.uploadTestPieceImage`（`Future<void> Function({required Uint8List bytes, String? mimeType, required String name})`）と不一致（invalid_override）。`build_runner` でのモック再生成が行われておらず、41 ファイルあるテスト資産が実行できない。CI 構成（GitHub Actions 等）も見当たらないため、退行が検知されない。

**対処方針**: `dart run build_runner build --delete-conflicting-outputs` で再生成 → `flutter test` 全通過を確認 → analyze + test を回す CI を追加。

#### H-2. エンティティ削除時の参照整合性が未処理

- 釉薬削除（`glaze_edit_screen.dart` の `_confirmDelete`）: 参照するテストピースはそのまま残り、テストピース詳細画面は「関連する釉薬データが見つかりません。」となり実質閲覧不能になる（削除確認ダイアログは「関連するテストピースは削除されません」と表示するが、閲覧不能になることまでは伝えていない）
- 原料削除（`materials_list_screen.dart`）: レシピ内の該当行が「不明な原料」表示になる。**削除確認すらワンクッションのみで、どの釉薬が使用中かの警告がない**
- 素地土・焼成プロファイル・焼成雰囲気の削除も同様

**対処方針**: 削除前に参照数を集計して警告（「この原料は 12 件の釉薬で使用中です」）、参照があれば論理削除（`archived` フラグ）にする方針を推奨。物理削除＋カスケードは Spark プラン・オフライン併用環境ではトランザクション的に難しい。

#### H-3. `findOrCreate` 系の重複生成・N+1 クエリ

`lib/services/firestore_service.dart` の `findOrCreateMaterials` / `findOrCreatePigmentID` / `findOrCreatePigments`:

- 「既存一覧を読む → なければ作る」の間に他端末の書き込みが入ると同名原料が重複する（トランザクション・一意制約なし）。タグ（`addTag`）はドキュメント ID = タグ名なので安全だが、原料は auto-ID なので防げない
- Excel インポート（`glaze_import_service.dart` 129–147 行）は顔料 1 エントリごとに `findOrCreatePigmentID` を呼び、その中で毎回 `getMaterials().first`（全件取得）+ `getMaterialIdByName`（クエリ）が走る。行数×顔料数に比例した全件読み込みが発生
- `findOrCreatePigments`（複数版）は定義されているがインポートからは使われておらず、単数版がループで呼ばれている

**対処方針**: インポート開始時に原料を 1 回だけ取得してメモリ上の name→id マップを構築し、新規作成はバッチでまとめる。重複防止は「原料名の正規化値をドキュメント ID にする」か、作成をトランザクション化する。

#### H-4. 検索画面のデータが陳腐化する（スナップショット固定）

`lib/screens/search_screen.dart` は `initState` で全コレクションを `.first` で 1 回だけ取得しメモリに保持する（`_loadInitialData`）。以後、他画面でテストピースや釉薬を追加・編集・削除しても検索タブには反映されない（再読込はタグ管理画面から戻った時のみ）。タブは `MainTabScreen` 上で使い回されるため、アプリを再起動するまで古い結果を返し続ける。

**対処方針**: フェーズ3のデータキャッシュ層（後述）に乗せ、ストリーム購読に置き換えるのが本筋。暫定対応はタブ表示時の再取得。

#### H-5. `Color.withValues` を上書きする extension（SDK と意味が異なる）

`lib/screens/glaze_detail_screen.dart` 末尾の `extension ColorAlpha on Color { Color withValues({int? alpha, ...}) }` は、**Flutter SDK 本体の `Color.withValues({double? alpha, ...})`（0.0–1.0 の double）と同名で引数の型・スケールが異なる（0–255 の int）**。インポート状況によりどちらが解決されるかが変わり、`withValues(alpha: 0.5)` のようなコードが将来コンパイルエラーまたは別意味になる時限爆弾。実際に他ファイル（`test_piece_detail_screen.dart:647` など）では SDK 版を double で呼んでいる。

**対処方針**: extension を削除し、SDK の `withValues` / `withAlpha` に統一する。

#### H-6. `analyze_output.txt` が陳腐化しており、現状の警告数が不明

同梱の解析ログには「`unsaved_changes_pop_scope.dart:19` で `onPopInvoked` 非推奨」とあるが、現行コードは既に `onPopInvokedWithResult` に修正済み。つまりログは過去のもの。`clay_edit_screen` / `firing_atmosphere_edit_screen` / `firing_profile_edit_screen` の `onPopInvoked`、`color_swatch.dart` の `red/green/blue` 非推奨、`use_build_context_synchronously` 多数（約 20 件）が現在も残っているかは再実行しないと確定しない。

**対処方針**: `flutter analyze` を再実行して現状を確定し、`analyze_output.txt` はリポジトリから削除（CI に役割を移す）。

### 2.3 Medium

#### M-1. 状態管理層が存在せず、画面が FirestoreService に直結

全画面が `context.read<FirestoreService>()` で直接 CRUD を呼ぶ。結果として:

- `test_piece_list_screen.dart` は **StreamBuilder 5 重ネスト**（釉薬→素地土→雰囲気→プロファイル→テストピース）。内側 4 つの waiting 中は `SizedBox.shrink()` を返すため画面がチラつく可能性があり、可読性も低い
- 一覧・検索・編集の各画面がそれぞれ独立に同じコレクション全件を購読しており、Firestore 読み取り課金とメモリの両面で非効率
- ビジネスロジック（フィルタ・ソート・dirty 管理）が State クラスに混在し、ウィジェットテストでしか検証できない

未マージの `refactor-mvvm-architecture` ブランチが存在しており、過去に同じ問題意識があったことが伺える。

**対処方針**: フェーズ3参照。アプリ起動中は主要 6 コレクションをアプリスコープの「データストア」が 1 箇所で購読し、各画面はそれを参照する構成（Riverpod または現行 Provider + ChangeNotifier で実現可能）。これだけで 5 重ネスト・検索の陳腐化（H-4）・重複購読がまとめて解消する。

#### M-2. FirestoreService が 647 行のコピペ CRUD

7 コレクション分の add / get / getStream / update / delete がほぼ同型で繰り返されている。`withConverter<T>` を使った汎用リポジトリ基底クラス + エンティティ別の薄いリポジトリに分割すれば 1/3 程度になる見込み。また「一度だけ読む」用途に `snapshots().first` を使っている箇所が多数あるが、これはリスナーの張り剥がしを伴うため、一回読みには `get()` ベースの API を別途用意すべき。

#### M-3. MainTabScreen のタブ番号ハードコード結合

`main_tab_screen.dart` は `if (_selectedIndex == 2)`（インポートボタン）、`== 3`（原料編集）、`== 4`（サインアウト）のようにタブ位置で AppBar アクションを分岐し、リフレッシュも GlobalKey + `as` キャストで子 State を呼ぶ。タブの追加・並び替えで壊れる（実際、コメントに「原料タブのインデックスが3に変わったため修正」とあり既に一度壊れている）。各画面が自分の AppBar アクションを宣言する構成（タブ定義を `(title, icon, screen, actions)` のレコード/クラスのリストに集約）へ変更すべき。

#### M-4. Excel インポートの列規約が暗黙的で脆い

`glaze_import_service.dart` は「1列目=釉薬名、2列目=登録名、3列目〜末尾3列前=原料、末尾3列前=顔料、末尾列=備考」という規約をマジックナンバー（`skip(2)`、`headerRow.length - 3`）で実装している。列が 1 つ欠けると黙って誤読する。ヘッダー検証（期待する列名の確認）とプレビュー画面（取り込み内容の確認 UI）を挟むべき。`ImportResult` に `skippedGlazes` の名前リストが含まれない点も改善余地（件数のみ通知）。

#### M-5. 検索ロジックの細かい不整合

`search_screen.dart`:

- フィルタ本体はクエリを `\s+` で分割（137 行目）するが、チップ表示は `[ 　]+`（全角スペース対応、430 行目）で分割しており、全角スペース区切りの語はチップには分かれて出るのにフィルタでは 1 語扱いになる
- マイナス検索（`-語`）はフィルタには実装されているが、チップからは通常語と同じ見た目で削除時の再構築も `-` を保持しない
- 「最近見たテストピース」は `_allTestPieces`（H-4 の固定スナップショット）から引くため、起動後に作成したピースは閲覧履歴に出ない

#### M-6. 保存フローの細部

- `test_piece_edit_screen.dart`: `testPieceData` 構築後に `_colorData.clear()` を呼ぶが、`TestPiece.colorData` は**同じ List インスタンスへの参照**のため、保存されるドキュメントの colorData も空になる。現状は「新画像アップロード時は Functions が上書きするので空で良い」という意図と偶然一致しているが、エイリアシング依存で極めて脆い。モデルのコンストラクタで `List.unmodifiable` を取るか、明示的に `colorData: []` を渡すべき
- 画像差し替え時、**旧画像・旧サムネイルを Storage から削除していない**（削除はテストピース削除時のみ）→ 孤児ファイルが蓄積
- `glaze_edit_screen.dart` の保存はタグごとに `addTag` を await（get + set で 2 往復 × タグ数）。バッチ化可能
- レシピ行で配合量が数値でない場合 `?? 0.0` で黙って 0 保存、原料未選択行は黙って捨てる。バリデーションで弾くべき

#### M-7. 認証まわり

- `auth_service.dart` に匿名サインインがあるが、匿名 → Google/メールへの**アカウントリンク（linkWithCredential）が実装されていない**。匿名利用後にサインインするとデータが別 uid に紐づき、見かけ上消える
- Windows の Google サインイン（desktop_webview_auth）は `accessToken` のみで credential を作っており、例外はすべて `return null` で吸収（失敗理由がユーザーに伝わらない）
- Google の clientId がソースにハードコード（公開情報なので漏洩リスクは低いが、環境分離不能）

#### M-8. 依存関係の区分・ガバナンス

- `build_runner` と `mockito` が `dependencies`（本番依存）に入っている → `dev_dependencies` へ移動
- `desktop_webview_auth ^0.0.16` はメンテが事実上止まっているパッケージであり、Windows 認証の将来リスク
- `firestore.indexes.json` がなく、`getTestPiecesForGlaze` では複合インデックス回避のためクライアントソートをしている（コメントあり）。インデックスを IaC 管理すればサーバーソートに戻せる

#### M-9. Cloud Functions の細部

- README は「Spark（無料）プランで運用」を前提と明記しているが、**Cloud Functions（2nd gen / Python）は Blaze プランが必須**。実運用は Blaze と確認済み（→ 決定事項 D-1）のため、README 側を修正する
- ダウンロード URL を `firebaseStorageDownloadTokens` メタデータの手動生成で組み立てており、非公式 API への依存。署名付き URL か `getDownloadURL` 相当への移行を検討
- 色解析の `merge_threshold` / 中心 50% クロップ / 64×64 縮小などのパラメータがハードコード。妥当だが、調整時のために定数化＋docstring 整備を推奨

### 2.4 Low

- 非推奨 API: `withOpacity` → `withValues`、`Matrix4.translate/scale` → `translateByDouble` 等、`color_swatch.dart` の `Color.red/green/blue` getter（analyze ログ参照、要再確認）
- `use_build_context_synchronously` が約 20 箇所（async gap 後の context 使用。クラッシュ可能性は低いが lint 解消推奨）
- `main_tab_screen.dart` にコメントアウトされた旧 `_widgetOptions` 定義が残存
- `ColorSwatch` というクラス名が Flutter SDK の `ColorSwatch` と衝突しており、各所で `hide ColorSwatch` が必要になっている → `LabColor` 等へのリネーム推奨
- README が Shift-JIS ではなく UTF-8 で正しく保存されているか要確認（Windows ツールでの閲覧時に文字化けする環境がある）。内容も現状と乖離し始めている（タブ構成は記載済みだが検索仕様・Functions 仕様が未記載）
- ハードコードされた日本語 UI 文字列が全画面に散在。当面日本語のみで問題ないが、文言修正のしやすさのため定数集約は検討余地あり

### 2.5 良い点（維持すべきもの）

- `UnsavedChangesPopScope` / `CommonAppBarActions` / `CommonSearchBar` / `EmptyListPlaceholder` などの共通ウィジェット化の方向性
- モデル層が素直で、`fromFirestore` に後方互換のデフォルト値処理がある
- `ColorSwatch` の Lab⇔sRGB 変換・ΔE 計算は正確に実装されており、Functions 側の色解析（彩度加重マージ）も工夫されている
- Excel インポート、調合計算（総量⇔各原料の双方向換算）、スポイト色検索など、ドメインに根ざした機能設計
- テストが 41 ファイル分存在する（モック再生成すれば資産として活きる）

---

## 3. リファクタリング計画

依存関係順に 4 フェーズ + 機能フェーズに分ける。各フェーズは独立に PR 化でき、フェーズ内の項目は並行可能。

### フェーズ 0: 健全化（基盤の信頼回復）— 規模: 小

| # | 作業 | 対応する指摘 | 状態 |
|---|---|---|---|
| 0-1 | `build_runner` でモック再生成、`flutter test` 全通過 | H-1 | **完了 (2026-06-12)** 124 テスト全パス |
| 0-2 | `build_runner` / `mockito` を `dev_dependencies` へ移動 | M-8 | **完了 (2026-06-12)** |
| 0-3 | `flutter analyze` 再実行 → 非推奨 API・lint を一掃、`analyze_output.txt` 削除 | H-6, Low | **ほぼ完了**: 再実行の結果 No issues（過去コミットで修正済みと判明）。`analyze_output.txt` の削除のみ残 |
| 0-4 | `ColorAlpha` extension 削除、SDK の `withValues` に統一 | H-5 | **完了 (2026-06-12)** 全呼び出し箇所が SDK 版を使用していることを確認のうえ削除 |
| 0-5 | GitHub Actions で analyze + test の CI を構築 | H-1 | **ファイル作成済み** (`.github/workflows/ci.yaml`)。コミット & push で有効化 |

**完了条件**: CI グリーン。これ以降のフェーズはすべて CI の保護下で行う。

### フェーズ 1: データ層の安全化 — 規模: 中

| # | 作業 | 対応する指摘 |
|---|---|---|
| 1-1 | ~~Firestore / Storage ルールのリポジトリ管理化~~（2026-06-12 完了）。残: Emulator ルールテスト追加 | C-2 |
| 1-2 | `firestore.indexes.json` 追加、`getTestPiecesForGlaze` をサーバーソートに戻す | M-8 |
| 1-3 | `FirestoreService` をエンティティ別リポジトリに分割 — **概ね完了 (2026-06-12)**: 汎用基底 `UserScopedRepository<T>` + 8 リポジトリ (`lib/repositories/`) を新設し、`FirestoreService` は互換ファサード化（既存画面・テスト無変更）。一回読み用 `getAll()`/`getXxxOnce()` を追加しインポート処理の `snapshots().first` を排除。リポジトリ単体テスト9件追加。残: 画面側の `.first` 置き換え（フェーズ3のVM移行と同時に実施） | M-2 |
| 1-4 | `findOrCreate` 系をマップ事前構築 + バッチ作成に書き換え、インポートの N+1 を解消 — **一部完了 (2026-06-12)**: インポートを2パス化（全行パース → 顔料一括作成 → ID 解決1回）、タグ保存も `addTags` バッチ化。残: 同名原料の重複防止 | H-3 |
| 1-5 | モデルの List/Map フィールドを不変化（`List.unmodifiable`）し、エイリアシング起因の事故を予防 | M-6 |

### フェーズ 2: 保存フローの堅牢化（画像パイプライン）— 規模: 中

| # | 作業 | 対応する指摘 |
|---|---|---|
| 2-1 | 保存順序を「ドキュメント作成（await）→ アップロード開始」に変更（最小修正） — **完了 (2026-06-12)**。あわせて colorData のリスト参照共有も明示的なコピー/空リスト渡しに修正 | C-1, M-6 |
| 2-2 | 画像パスに docId を含める形式へ移行し、Functions をパスから docId 直接解決に変更（クエリ排除）。旧パス形式との互換処理を入れる — **実装完了 (2026-06-12)**: 新形式 `users/{uid}/test_pieces/images/{docId}/{uuid}.jpg`。新規作成は ID 先行発行 (`createTestPieceId` + `setTestPiece`)。Functions は docId 直接取得 + 旧形式は imagePath クエリでフォールバック。**Functions の再デプロイが必要** | C-1 |
| 2-3 | アップロード失敗の可視化 — **完了 (2026-06-12)**: `uploadTestPieceImage` が例外を伝播するよう変更し、保存フローはルートの SnackBar で失敗を通知（再試行 UI は状態管理導入後に検討） | C-3 |
| 2-4 | 画像差し替え時の旧画像・旧サムネイル削除 — **実装完了 (2026-06-12)**: Functions がドキュメント更新後に docId フォルダ内の旧世代ファイルを削除（新形式のみ）。テストピース削除時もフォルダごと削除する `deleteAllTestPieceFiles` を追加（旧形式は従来の URL 削除を併用） | M-6 |
| 2-5 | `_colorData` クリアの意図を明示化（`colorData: []` を明示的に渡す） | M-6 |

### フェーズ 3: 状態管理アーキテクチャ — 規模: 大

| # | 作業 | 対応する指摘 |
|---|---|---|
| 3-1 | アプリスコープの「データストア」導入 — **完了 (2026-06-12)**: `lib/providers/data_providers.dart` に主要 7 コレクションの `StreamProvider` + 派生マップを集約。認証状態の watch によりユーザー切替時に購読を自動で張り直す。flutter_riverpod は SDK 制約により ^2.6.1 を採用（3.x はリポジトリの SDK 更新後に移行）。既存 provider パッケージとは移行期間中併用 | M-1, H-4 |
| 3-2 | `test_piece_list_screen` の 5 重 StreamBuilder をデータストア参照に置換 — **完了 (2026-06-12)**: ConsumerStatefulWidget 化、`handleRefresh` は provider の invalidate で実装（MainTabScreen の GlobalKey 連携は互換維持） | M-1 |
| 3-3 | `search_screen` をデータストア参照に置換し、陳腐化を解消 — **完了 (2026-06-12)**: 起動時スナップショット (`_loadInitialData`) を廃止し、プロバイダ参照 + `ref.listen` による検索結果の追従に変更。他画面での追加・編集が検索タブに即反映される | H-4 |
| 3-4 | 主要画面のプロバイダ移行 — **大半完了 (2026-06-12)**: 釉薬一覧 / 原料一覧 / 釉薬詳細 / 釉薬編集 / テストピース詳細（6本の一回読み `_loadRelatedData` を全廃）/ テストピース編集（ドロップダウン選択肢）を移行。サブ画面（素地土・焼成プロファイル・焼成雰囲気の一覧/編集、原料詳細/編集、タグ管理、main_tab のインポート呼び出し = 計12箇所）は provider 経由のまま残存（移行期間中は両DIが併用でき動作に問題なし）。フィルタ・ソートロジックの ViewModel 分離は未着手 | M-1 |
| 3-5 | `MainTabScreen` のタブ定義をデータ駆動化（タブ位置ハードコード排除、GlobalKey キャスト排除） | M-3 |

既存の `refactor-mvvm-architecture` ブランチはマージせず設計リファレンスとして参照する（精査結果は決定事項 D-6 参照。リポジトリ分割粒度と ViewModel の責務分割は流用価値が高いが、コードベースが古く ChangeNotifier ベースのため、Riverpod で新規に実装し直す）。

### フェーズ 4: UX・整合性の仕上げ — 規模: 中

| # | 作業 | 対応する指摘 |
|---|---|---|
| 4-1 | 削除時の参照チェックと警告（使用中の原料・釉薬の削除に参照件数を表示）、必要なら論理削除導入 | H-2 |
| 4-2 | Excel インポートのヘッダー検証 + 取り込みプレビュー画面 | M-4 |
| 4-3 | 検索の語分割統一（全角スペース対応）とマイナス検索のチップ表現 | M-5 |
| 4-4 | 編集フォームのバリデーション強化（配合量の数値必須、原料未選択行の警告） | M-6 |
| 4-5 | 匿名 → 永続アカウントのリンク実装（`linkWithCredential`） | M-7, D-4 |
| 4-6 | 引き継ぎコード実装（Cloud Function によるワンタイムコード発行 + カスタムトークンでの旧 uid 引き継ぎ。設計は決定事項 D-4 参照） | D-4 |
| 4-7 | 一覧グリッドのサムネイル優先表示（原寸画像は詳細画面のみ）と README の実態反映（Blaze プラン） | D-5, D-1 |
| 4-8 | 配布準備: バージョニング運用ルール、Android 署名分離、Crashlytics、`main`/`release` ブランチ運用整理（アイコン更新コミット `f4fd47f` の release への取り込み含む） | D-7, D-6 |

---

## 4. 今後の実装計画（機能ロードマップ候補）

既存ブランチ名・データモデルから読み取れる構想と、ドメイン上自然な発展を候補として挙げる（確定済みの実装方針は §5 決定事項を参照。匿名アカウントのリンク・引き継ぎコードはフェーズ4の正式項目に昇格済み）。

1. **ゼーゲル式 / UMF 計算**: `Material.components`（SiO₂, Al₂O₃ 等の成分 Map）が既にあるため、釉薬レシピから統一分子式を自動計算し、釉薬の性質予測・近傍レシピ検索につなげられる。データモデル変更が不要で投資対効果が高い
2. **テストピースカードの並び替え・グルーピング**（`feat-card-reorder` ブランチの構想）: 焼成回・窯ごとのグループ表示
3. **色検索の強化**: 現状の CIE76 ΔE を CIEDE2000 に置き換え（知覚均等性向上、`ColorSwatch.deltaE` の差し替えのみ）
4. **データエクスポート**: インポートの対になる Excel/CSV 書き出し（バックアップ用途。Spark プラン前提ならユーザー自身のデータ救済手段として重要）
5. **複数窯・工房共有**: 現状は完全個人スコープ。共有が要件になる場合、`users/{uid}` 配下構造の見直しが必要になるため、フェーズ1のリポジトリ分割時にスコープ抽象を意識しておく

---

## 5. 決定事項（2026-06-12 確定）

レビュー時点で未決だった事項について、プロジェクトオーナーの回答により以下のとおり確定した。本計画の各フェーズはこの決定を前提とする。

### D-1. Firebase 料金プラン: Blaze で運用中

Cloud Functions は Blaze プランで実運用中。ストア公開はしないため課金ラインに達しない見込み。README の「Spark プラン前提」の記載は実態と異なるため修正対象。→ Functions ベースのサムネイル・色解析パイプラインは維持し、フェーズ2はその堅牢化に専念する。

### D-2. セキュリティルール: 内容確認済み・リポジトリ管理化済み

コンソールに設定されている現行ルールは「`users/{userId}/` 配下は `request.auth.uid == userId` のときのみ読み書き可」で、Firestore / Storage とも適切（無防備ではなかった）。このルールを `firestore.rules` / `storage.rules` としてリポジトリに取り込み、`firebase.json` に登録済み（2026-06-12）。以後 `firebase deploy` でルールも一緒にデプロイされる。ルール内容は安定運用中であり、よほどのことがない限り変更しない方針。残作業は Emulator でのルールテスト追加（フェーズ1）。

### D-3. 状態管理: Riverpod を採用

「将来性に優れる実装」を優先する方針のため、フェーズ3は Riverpod（riverpod_generator 含むコード生成ベース）で実装する。現行 Provider からは段階移行（両者は共存可能なため、画面単位で順次置き換える）。

### D-4. 匿名認証: 維持 + アカウントリンク + 引き継ぎコード

匿名サインインは使い勝手のため正式導線として残す。そのうえで以下 2 機能を実装する（フェーズ4で詳細設計）:

- **アカウントリンク**: 匿名 → Google / メールへの `linkWithCredential` による昇格（データを保ったままアカウント化）
- **引き継ぎコード**: 「アカウントリンクはしたくないが機種変更はしたい」という要望に応える機能。設計案: Cloud Function がワンタイムコード（短寿命・ハッシュ化して Firestore 保存）を発行し、新端末でコード入力 → Function がコードを検証して旧 uid のカスタムトークンを発行 → 新端末が旧アカウントとしてサインイン。コードの有効期限・一回性・試行回数制限が必須（Blaze 運用なので Function 実装に支障なし）

### D-5. データ規模: 数百件規模、ただし一桁上振れへの耐性は確保する

テストピースは個人あたり数百件想定。現行の全件クライアント検索は数百件なら問題ないが、数千件で体験が劣化しないよう以下を計画に織り込む:

- 一覧グリッドは `thumbnailUrl`（200px）を優先使用し、原寸画像は詳細画面のみ（現状は一覧でも原寸を読む実装。`test_piece_card.dart` はサムネイルをプレースホルダーにしか使っていない）
- フェーズ3のデータストアは全件購読を 1 箇所に集約（重複購読の排除で読み取り課金とメモリを抑制）
- ページング（`limit` + `startAfter`）は数千件到達時の追加対応として設計だけ用意し、実装は規模が見えてから

### D-6. 未マージブランチ: 精査完了、処分方針確定

`release` ブランチ基準で全ブランチを精査した結果:

| ブランチ | release との差分 | 内容 | 処分（2026-06-12 実施済み） |
|---|---|---|---|
| `android-login-test` | ahead 0 | マージ済み | 削除済み |
| `feat-card-reorder` | ahead 0 | 独自コミットなし（構想のみ） | 削除済み（機能はロードマップ §4-2 に記録済み） |
| `list` / `rel` / `google-antigravity-test` | ahead 0 | マージ済み | 削除済み |
| `feat-search-improve` / `refactor-widget-clean` | 実質 ahead 0（残コミットは取り込み済み README 更新の重複） | マージ済み | 削除済み |
| `total-redesign` | ahead 1 (`466b92a`) | 調合計算の初期総重量を「最大原料=100g」とする旧ドラフト。6分後の改訂版 `86057d7`（総量=パーツ×10）が release に取り込み済み | 削除済み |
| `main` | ahead 1 (`f4fd47f icon`) | 独自アプリアイコンの設定（実験で不採用と確認） | コミットを破棄し `main` を `release` と同一に更新（remote へ force push 済み）。タグ `archive/app-icon-experiment` で復元可能 |
| `refactor-mvvm-architecture` | ahead 1（大型 1 コミット, 2025-11-19） | 下記参照 | ブランチ削除済み。タグ `archive/refactor-mvvm-architecture` で設計参照可能 |

整理後のブランチは `main` と `release` の 2 本のみ（両者同一コミット）。破棄した 2 コミットはローカルタグ `archive/app-icon-experiment` / `archive/refactor-mvvm-architecture` から参照・復元できる。

**`refactor-mvvm-architecture` の精査詳細**: FirestoreService の全廃 → エンティティ別リポジトリ 8 ファイル（auth / clay / firing_atmosphere / firing_profile / glaze / material / tag / test_piece）+ ChangeNotifier ベースの ViewModel 7 画面分（glaze_list / glaze_edit / glaze_detail / search / test_piece_edit / test_piece_detail / material_detail）+ 共通ウィジェット 3 種（app_dropdown / confirm_dialog / loading_overlay）という、本計画のフェーズ1（リポジトリ分割）+ フェーズ3（VM 導入）と同じ方向の本格的な実装。**方向性は正しく、リポジトリ層の API 設計と各 VM の責務分割は再利用価値が高い**。ただし、(a) total-redesign（テーマ刷新・UX 改修）より前のコードベース上の 1 コミットで release との乖離が画面全域に及びマージは現実的でない、(b) ViewModel が ChangeNotifier ベースで D-3 の Riverpod 方針と合わない、(c) コミットメッセージ自体に「tests not completed」とある。→ **結論: マージは行わず、フェーズ1・3 実装時の設計リファレンスとして参照する**（リポジトリの分割粒度・メソッドシグネチャ・VM の状態分類はほぼ流用可、状態通知機構のみ Riverpod に置換）。

### D-7. ストア配布: 直ちにはしないが、将来できる状態にしておく

署名・バージョニングの整備は中優先度でフェーズ4以降に組み込む。具体的には: `version` の運用ルール決定（現状 0.0.1+1 固定）、Android 署名設定の分離（keystore をリポジトリ外で管理）、Crashlytics 導入（Blaze なので追加コストほぼなし）、`main` ↔ `release` のブランチ運用整理（現状 main と release が相互に 1 コミットずれており役割が不明瞭）。

---

## 6. 付録: 主要ファイル一覧（参照用）

| 区分 | パス | 行数規模 | 備考 |
|---|---|---|---|
| サービス | `lib/services/firestore_service.dart` | 647 行 | 全 CRUD 集約。フェーズ1で分割 |
| サービス | `lib/services/storage_service.dart` | 55 行 | エラー握りつぶし（C-3） |
| サービス | `lib/services/glaze_import_service.dart` | 186 行 | Excel インポート（H-3, M-4） |
| 画面 | `lib/screens/search_screen.dart` | 887 行 | 最大の画面。スナップショット固定（H-4） |
| 画面 | `lib/screens/test_piece_edit_screen.dart` | 698 行 | 保存フロー競合（C-1, M-6） |
| 画面 | `lib/screens/test_piece_detail_screen.dart` | 798 行 | スポイト検索・全画面表示含む |
| 画面 | `lib/screens/main_tab_screen.dart` | 284 行 | タブ番号結合（M-3） |
| Functions | `functions/main.py` | 219 行 | サムネイル + 色解析（C-1 関連） |
| テスト | `test/` 配下 | 41 ファイル | モック陳腐化で実行不能（H-1） |
