import 'package:cached_network_image/cached_network_image.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:glaze_manager/models/clay.dart';
import 'package:glaze_manager/models/glaze.dart';
import 'package:glaze_manager/models/material.dart' as m;
import 'package:glaze_manager/models/recipe_snapshot.dart';
import 'package:glaze_manager/models/test_piece.dart';
import 'package:glaze_manager/utils/test_piece_display.dart';
import 'package:glaze_manager/providers/data_providers.dart';
import 'package:glaze_manager/screens/color_pick_screen.dart';
import 'package:glaze_manager/screens/firing_detail_screen.dart';
import 'package:glaze_manager/screens/glaze_detail_screen.dart';
import 'package:glaze_manager/screens/test_piece_edit_screen.dart';
import 'package:glaze_manager/screens/test_piece_share_screen.dart';
import 'package:glaze_manager/screens/mixing_calculator_screen.dart';
import 'package:glaze_manager/widgets/firing_chart.dart';
import 'package:glaze_manager/screens/search_screen.dart';
import 'package:glaze_manager/widgets/common/app_network_image.dart';
import 'package:glaze_manager/widgets/common/color_swatch_row.dart';
import 'package:glaze_manager/widgets/common/info_tile.dart';
import 'package:glaze_manager/widgets/common/rating_stars.dart';
import 'package:glaze_manager/widgets/common/recipe_table.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart'
    show ConsumerStatefulWidget, ConsumerState, AsyncValueX;

class TestPieceDetailScreen extends ConsumerStatefulWidget {
  final TestPiece testPiece;

  const TestPieceDetailScreen({super.key, required this.testPiece});

  @override
  ConsumerState<TestPieceDetailScreen> createState() =>
      _TestPieceDetailScreenState();
}

class _TestPieceDetailScreenState extends ConsumerState<TestPieceDetailScreen> {
  @override
  void initState() {
    super.initState();
    _updateViewHistory();
  }

  void _updateViewHistory() {
    // initStateでは直接使えないため、Future.microtaskで遅延実行
    Future.microtask(() {
      if (!mounted) return;
      ref
          .read(firestoreServiceProvider)
          .updateViewHistory(widget.testPiece.id!);
    });
  }

  @override
  Widget build(BuildContext context) {
    // 関連データはアプリスコープのプロバイダから取得 (一回読みを廃止)
    final glazesAsync = ref.watch(glazesProvider);
    final glazeMap = ref.watch(glazeMapProvider);
    final clayMap = ref.watch(clayMapProvider);
    final profileMap = ref.watch(firingProfileMapProvider);
    final atmosphereMap = ref.watch(firingAtmosphereMapProvider);
    final firingMap = ref.watch(firingMapProvider);
    final materials = ref.watch(materialsProvider).valueOrNull ?? [];

    final testPieceAsync = ref.watch(
      testPieceByIdProvider(widget.testPiece.id!),
    );

    return testPieceAsync.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, stackTrace) => Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('テストピースデータの読み込みに失敗しました。')),
      ),
      data: (testPiece) {
        // 関連コレクションがまだロード中ならスピナー (旧 glazesAsync.isLoading 条件)
        if (glazesAsync.isLoading) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final Glaze? glaze = glazeMap[testPiece.glazeId];
        final Clay? clay = clayMap[testPiece.clayId];
        final firing = resolveFiring(
          testPiece,
          firingMap: firingMap,
          atmosphereMap: atmosphereMap,
          profileMap: profileMap,
        );

        return Scaffold(
          appBar: AppBar(
            title: const Text('テストピース詳細'),
            actions: [
              IconButton(
                icon: const Icon(Icons.share),
                tooltip: '共有画像を作成',
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) =>
                        TestPieceShareScreen(testPiece: testPiece),
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.edit),
                tooltip: '編集',
                onPressed: () =>
                    _navigateToEditScreen(context, testPiece: testPiece),
              ),
            ],
          ),
          body: LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth / constraints.maxHeight > 1.2;
              if (isWide) {
                return _buildWideLayout(
                  testPiece,
                  glaze,
                  clay,
                  firing,
                  constraints,
                  glazeMap,
                  materials,
                );
              } else {
                return _buildNarrowLayout(
                  testPiece,
                  glaze,
                  clay,
                  firing,
                  glazeMap,
                  materials,
                );
              }
            },
          ),
        );
      },
    );
  }

  Widget _buildWideLayout(
    TestPiece testPiece,
    Glaze? glaze,
    Clay? clay,
    ResolvedFiring firing,
    BoxConstraints constraints,
    Map<String, Glaze> glazeMap,
    List<m.Material> materials,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 左側：固定幅の画像エリア
        SizedBox(
          width: (constraints.maxHeight - 50), // 表示領域の高さに応じて幅を決定
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: _buildImage(testPiece),
          ),
        ),
        const VerticalDivider(width: 1),
        Expanded(
          // 右側：残りのスペースをすべて使用する情報エリア
          flex: 1,
          child: _buildInfoPanel(
            testPiece,
            glaze,
            clay,
            firing,
            glazeMap,
            materials,
          ),
        ),
      ],
    );
  }

  Widget _buildNarrowLayout(
    TestPiece testPiece,
    Glaze? glaze,
    Clay? clay,
    ResolvedFiring firing,
    Map<String, Glaze> glazeMap,
    List<m.Material> materials,
  ) {
    return ListView(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: _buildImage(testPiece),
        ),
        _buildInfoPanel(testPiece, glaze, clay, firing, glazeMap, materials),
      ],
    );
  }

  Widget _buildImage(TestPiece testPiece) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AspectRatio(
          aspectRatio: 1.0,
          child: Hero(
            tag: 'testPieceImage_${testPiece.id}',
            child: Material(
              child: Stack(
                children: [
                  GestureDetector(
                    onTap: testPiece.imageUrl != null
                        ? () => _showFullScreenImage(context, testPiece)
                        : null,
                    child: AppNetworkImage(
                      url: testPiece.imageUrl,
                      fit: BoxFit.contain,
                      iconSize: 60,
                    ),
                  ),
                  if (testPiece.imageUrl != null)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.colorize, color: Colors.white),
                          onPressed: () => _openEyedropperSearch(testPiece),
                          tooltip: 'スポイトで検索',
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        // 色見本表示エリア
        if (testPiece.colorData != null && testPiece.colorData!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ColorSwatchRow(
                  colorData: testPiece.colorData!,
                  onTapSwatch: (color) {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => SearchScreen(initialColor: color),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildInfoPanel(
    TestPiece testPiece,
    Glaze? glaze,
    Clay? clay,
    ResolvedFiring firing,
    Map<String, Glaze> glazeMap,
    List<m.Material> materials,
  ) {
    final snapshotGlaze = testPiece.snapshot?.glaze;
    final recipeDiffers =
        glaze != null &&
        snapshotGlaze != null &&
        !snapshotGlaze.hasSameRecipeAs(glaze.recipe);
    // 写しがあれば写しの調合を、なければ現在の釉薬の調合を使う
    final Map<String, double> recipe =
        snapshotGlaze?.recipe ?? glaze?.recipe ?? const {};
    final showRecipeSection = recipe.isNotEmpty || recipeDiffers;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // レシピを最優先で表示
          if (showRecipeSection) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('調合', style: Theme.of(context).textTheme.titleMedium),
                if (recipe.isNotEmpty)
                  TextButton.icon(
                    onPressed: () {
                      // 原料が現存すれば現在の名前、なければ写しの名前
                      final materialNames = <String, String>{
                        for (final line in snapshotGlaze?.lines ?? const [])
                          line.materialId: line.name,
                        for (var m in materials) m.id!: m.name,
                      };
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => MixingCalculatorScreen(
                            recipe: recipe,
                            materialNames: materialNames,
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.calculate),
                    label: const Text('調合計算へ'),
                  ),
              ],
            ),
            if (recipeDiffers)
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    '釉薬の現在の調合とは異なります。',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  TextButton(
                    onPressed: () => _confirmUpdateSnapshot(testPiece, glaze),
                    child: const Text('現在の調合に更新'),
                  ),
                ],
              ),
            const SizedBox(height: 8),
            if (snapshotGlaze != null)
              RecipeTable.fromSnapshot(
                snapshot: snapshotGlaze,
                materials: materials,
              )
            else
              RecipeTable(recipe: recipe, materials: materials),
            if (testPiece.snapshot?.source == SnapshotSource.backfilled) ...[
              const SizedBox(height: 8),
              Text(
                '移行時に、その時点の釉薬の調合から埋めた記録です。',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            const Divider(height: 32),
          ],

          if (testPiece.rating != null) ...[
            Text('評価', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 4),
            RatingStars(rating: testPiece.rating),
            const SizedBox(height: 8),
          ],
          if (testPiece.label != null)
            InfoTile(label: '番号', value: testPiece.label!),
          InfoTile(
            label: '釉薬名 (メイン)',
            value: glazeDisplayName(testPiece, glazeMap),
            // 釉薬が現存するときだけ詳細へ飛べる
            onTap: glaze == null
                ? null
                : () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => GlazeDetailScreen(glaze: glaze),
                      ),
                    );
                  },
          ),
          if (testPiece.additionalGlazeIds.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('追加の釉薬', style: Theme.of(context).textTheme.labelLarge),
            for (final id in testPiece.additionalGlazeIds)
              _buildAdditionalGlaze(testPiece, id, glazeMap),
          ],
          InfoTile(
            label: '素地土名',
            value: clay?.name ?? testPiece.snapshot?.clayName ?? '未設定',
          ),
          if (testPiece.firingId != null)
            InfoTile(
              label: '焼成回',
              value: firing.firing?.displayLabel ?? '不明',
              // 焼成回が現存するときだけ詳細へ飛べる
              onTap: firing.firing == null
                  ? null
                  : () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) =>
                            FiringDetailScreen(firingId: testPiece.firingId!),
                      ),
                    ),
            ),
          InfoTile(
            label: '焼成雰囲気',
            value: firing.atmosphereLabel,
            tooltip: '焼成時の窯の雰囲気（酸化・還元など）です。',
          ),
          const Divider(height: 32),
          if (firing.profileName != null) ...[
            Row(
              children: [
                Text(
                  '焼成プロファイル',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(width: 8),
                const Tooltip(
                  message: '焼成の計画として登録した温度曲線です。',
                  triggerMode: TooltipTriggerMode.tap,
                  child: Icon(Icons.info_outline, size: 20, color: Colors.grey),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              firing.profileName!,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 16),
            if (firing.curveData != null && firing.curveData!.isNotEmpty)
              FiringChart(
                curveData: firing.curveData!,
                isReduction: firing.isReduction,
                reductionStartTemp: firing.reductionStartTemp,
                reductionEndTemp: firing.reductionEndTemp,
              ),
          ] else
            InfoTile(label: '焼成プロファイル', value: firing.profileLabel),

          if (testPiece.note != null && testPiece.note!.isNotEmpty) ...[
            const Divider(height: 32),
            Text('備考', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(testPiece.note!, style: Theme.of(context).textTheme.bodyLarge),
          ],
        ],
      ),
    );
  }

  /// 追加釉薬の 1 件。現存すれば現在の名前とリンク、なければ写しの名前
  /// (リンクなし)、どちらもなければ「不明な釉薬」を表示する。
  Widget _buildAdditionalGlaze(
    TestPiece testPiece,
    String glazeId,
    Map<String, Glaze> glazeMap,
  ) {
    final glaze = glazeMap[glazeId];
    final name = additionalGlazeDisplayName(testPiece, glazeId, glazeMap);
    final style = Theme.of(context).textTheme.bodyLarge;
    final text = Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Text(
        name,
        style: glaze == null
            ? style
            : style?.copyWith(
                color: Theme.of(context).colorScheme.primary,
                decoration: TextDecoration.underline,
              ),
      ),
    );
    if (glaze == null) return text;
    return InkWell(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => GlazeDetailScreen(glaze: glaze),
          ),
        );
      },
      child: text,
    );
  }

  /// 写しの調合を釉薬の現在の調合に置き換える (確認のうえ)。
  Future<void> _confirmUpdateSnapshot(TestPiece testPiece, Glaze glaze) async {
    final snapshot = testPiece.snapshot;
    if (snapshot == null || testPiece.id == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        content: const Text('このテストピースの調合の記録を、釉薬の現在の調合に置き換えます。元に戻せません。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('更新'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final updated = snapshot.replacingGlaze(
      GlazeSnapshot.capture(glaze, ref.read(materialMapProvider)),
      source: SnapshotSource.saved,
    );
    ref
        .read(firestoreServiceProvider)
        .updateTestPieceFields(testPiece.id!, {'snapshot': updated.toMap()})
        .catchError((Object e) {
          scaffoldMessenger.showSnackBar(
            SnackBar(content: Text('保存に失敗しました: $e')),
          );
        });
  }

  /// 編集画面へ遷移する（オフラインチェック含む）
  Future<void> _navigateToEditScreen(
    BuildContext context, {
    required TestPiece testPiece,
  }) async {
    // ネットワーク接続を確認
    final connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult.contains(ConnectivityResult.none) &&
        context.mounted) {
      // オフラインの場合、警告ダイアログを表示
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('オフラインです'),
          content: const Text('現在オフラインのため、画像のアップロードはできません。テキスト情報のみ保存可能です。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('キャンセル'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('続ける'),
            ),
          ],
        ),
      );
      // 「続ける」が押されなかった場合は何もしない
      if (confirmed != true) return;
    }
    // オンライン、または警告後に「続ける」が押された場合、編集画面に遷移
    if (!context.mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => TestPieceEditScreen(testPiece: testPiece),
      ),
    );
  }

  void _showFullScreenImage(BuildContext context, TestPiece testPiece) {
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false, // 背景を透過させる
        barrierColor: Colors.black.withValues(alpha: 0.7), // 背景の半透明色
        pageBuilder: (context, animation, secondaryAnimation) {
          return _FullScreenImageScreen(testPiece: testPiece);
        },
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          // フェードイン・アウトのアニメーション
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  /// スポイト画面で色を選び、その色で検索画面へ遷移する
  Future<void> _openEyedropperSearch(TestPiece testPiece) async {
    final imageUrl = testPiece.imageUrl;
    if (imageUrl == null) return;

    final pickedColor = await Navigator.of(context).push<Color>(
      MaterialPageRoute(
        builder: (context) => ColorPickScreen(
          imageProvider: CachedNetworkImageProvider(imageUrl),
          mode: ColorPickMode.single,
        ),
      ),
    );

    if (pickedColor == null || !mounted) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => SearchScreen(initialColor: pickedColor),
      ),
    );
  }
}

/// 画像を全画面でインタラクティブに表示する専用の画面
class _FullScreenImageScreen extends StatefulWidget {
  final TestPiece testPiece;

  const _FullScreenImageScreen({required this.testPiece});

  @override
  State<_FullScreenImageScreen> createState() => _FullScreenImageScreenState();
}

class _FullScreenImageScreenState extends State<_FullScreenImageScreen> {
  late final TransformationController _transformationController;
  TapDownDetails? _doubleTapDetails;

  @override
  void initState() {
    super.initState();
    _transformationController = TransformationController();
  }

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  void _handleDoubleTapDown(TapDownDetails details) {
    _doubleTapDetails = details;
  }

  void _handleDoubleTap() {
    if (_transformationController.value != Matrix4.identity()) {
      // 既にズームされている場合はリセット
      _transformationController.value = Matrix4.identity();
    } else if (_doubleTapDetails != null) {
      // ズームされていない場合は、ダブルタップした位置を中心に2倍にズーム
      final position = _doubleTapDetails!.localPosition;
      _transformationController.value = Matrix4.identity()
        ..multiply(Matrix4.translationValues(-position.dx, -position.dy, 0.0))
        ..multiply(Matrix4.diagonal3Values(2.0, 2.0, 1.0));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GestureDetector(
        // 背景部分のタップで画面を閉じる
        behavior: HitTestBehavior.opaque, // 背景全体でタップを検知
        onTap: () => Navigator.of(context).pop(),
        child: Stack(
          children: [
            Center(
              child: GestureDetector(
                onDoubleTapDown: _handleDoubleTapDown,
                onDoubleTap: _handleDoubleTap,
                // 画像部分のタップイベントが背景に伝播しないようにする
                onTap: () {},
                child: Hero(
                  tag: 'testPieceImage_${widget.testPiece.id}',
                  child: InteractiveViewer(
                    transformationController: _transformationController,
                    panEnabled: true,
                    minScale: 0.8,
                    maxScale: 4.0,
                    child: AppNetworkImage(
                      url: widget.testPiece.imageUrl,
                      fit: BoxFit.contain,
                      iconSize: 50,
                    ),
                  ),
                ),
              ),
            ),
            // 閉じるボタン（AppBarの代替）
            Positioned(
              top: 0,
              left: 0,
              child: SafeArea(
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.of(context).pop(),
                  tooltip: '閉じる',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
