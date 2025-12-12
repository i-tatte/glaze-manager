import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:flutter/rendering.dart' hide ColorSwatch;
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart' hide ColorSwatch;
import 'package:glaze_manager/models/clay.dart';
import 'package:glaze_manager/models/color_swatch.dart';
import 'package:glaze_manager/models/firing_atmosphere.dart';
import 'package:glaze_manager/models/firing_profile.dart';
import 'package:glaze_manager/models/glaze.dart';
import 'package:glaze_manager/models/material.dart' as m;
import 'package:glaze_manager/models/test_piece.dart';
import 'package:glaze_manager/screens/glaze_detail_screen.dart';
import 'package:glaze_manager/screens/test_piece_edit_screen.dart';
import 'package:glaze_manager/screens/mixing_calculator_screen.dart';
import 'package:glaze_manager/services/firestore_service.dart';
import 'package:glaze_manager/widgets/firing_chart.dart';
import 'package:glaze_manager/screens/search_screen.dart';
import 'package:provider/provider.dart';

class TestPieceDetailScreen extends StatefulWidget {
  final TestPiece testPiece;

  const TestPieceDetailScreen({super.key, required this.testPiece});

  @override
  State<TestPieceDetailScreen> createState() => _TestPieceDetailScreenState();
}

class _TestPieceDetailScreenState extends State<TestPieceDetailScreen> {
  bool _isEyedropperActive = false;
  final GlobalKey _imageKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _updateViewHistory();
  }

  void _updateViewHistory() {
    // initStateではcontext.readが直接使えないため、Future.microtaskで遅延実行
    Future.microtask(() {
      if (!mounted) return;
      context.read<FirestoreService>().updateViewHistory(widget.testPiece.id!);
    });
  }

  @override
  Widget build(BuildContext context) {
    final firestoreService = context.read<FirestoreService>();

    return StreamBuilder<TestPiece>(
      stream: firestoreService.getTestPieceStream(widget.testPiece.id!),
      builder: (context, testPieceSnapshot) {
        if (testPieceSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (testPieceSnapshot.hasError || !testPieceSnapshot.hasData) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(child: Text('テストピースデータの読み込みに失敗しました。')),
          );
        }

        final testPiece = testPieceSnapshot.data!;

        return Scaffold(
          appBar: AppBar(
            title: const Text('テストピース詳細'),
            actions: [
              IconButton(
                icon: const Icon(Icons.edit),
                tooltip: '編集',
                onPressed: () =>
                    _navigateToEditScreen(context, testPiece: testPiece),
              ),
            ],
          ),
          body: FutureBuilder<Map<String, dynamic>>(
            // 関連データを取得するFuture
            future: _loadRelatedData(firestoreService, testPiece),
            builder: (context, relatedDataSnapshot) {
              if (relatedDataSnapshot.connectionState ==
                  ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (relatedDataSnapshot.hasError) {
                return Center(
                  child: Text(
                    '関連データの読み込みに失敗しました: ${relatedDataSnapshot.error}',
                  ),
                );
              }

              final details = relatedDataSnapshot.data ?? {};
              final Glaze? glaze = details['glaze'];
              final Clay? clay = details['clay'];
              final FiringProfile? firingProfile = details['firingProfile'];
              final FiringAtmosphere? firingAtmosphere =
                  details['firingAtmosphere'];
              final List<Glaze> additionalGlazes =
                  details['additionalGlazes'] ?? [];
              final List<m.Material> materials = details['materials'] ?? [];

              if (glaze == null) {
                return const Center(child: Text('関連する釉薬データが見つかりません。'));
              }

              return LayoutBuilder(
                builder: (context, constraints) {
                  final isWide =
                      constraints.maxWidth / constraints.maxHeight > 1.2;
                  if (isWide) {
                    return _buildWideLayout(
                      testPiece,
                      glaze,
                      clay,
                      firingProfile,
                      firingAtmosphere,
                      constraints,
                      additionalGlazes,
                      materials,
                    );
                  } else {
                    return _buildNarrowLayout(
                      testPiece,
                      glaze,
                      clay,
                      firingProfile,
                      firingAtmosphere,
                      additionalGlazes,
                      materials,
                    );
                  }
                },
              );
            },
          ),
        );
      },
    );
  }

  /// TestPieceに関連するデータを非同期で取得する
  Future<Map<String, dynamic>> _loadRelatedData(
    FirestoreService firestoreService,
    TestPiece testPiece,
  ) async {
    // 各IDに対応するドキュメントを直接取得
    final glazeFuture = firestoreService
        .getGlazeStream(testPiece.glazeId)
        .first;
    final clayFuture = firestoreService.getClayStream(testPiece.clayId).first;

    final Future<FiringProfile?> profileFuture =
        testPiece.firingProfileId != null
        ? firestoreService
              .getFiringProfileStream(testPiece.firingProfileId!)
              .first
        : Future.value(null);

    final Future<FiringAtmosphere?> atmosphereFuture =
        testPiece.firingAtmosphereId != null
        ? firestoreService
              .getFiringAtmosphereStream(testPiece.firingAtmosphereId!)
              .first
        : Future.value(null);

    // 追加の釉薬を取得
    final additionalGlazesFuture = Future.wait(
      testPiece.additionalGlazeIds.map(
        (id) => firestoreService.getGlazeStream(id).first,
      ),
    );

    // 原料一覧を取得
    final materialsFuture = firestoreService.getMaterials().first;

    // 各データを並行して取得
    final results = await Future.wait([
      glazeFuture,
      clayFuture,
      profileFuture,
      atmosphereFuture,
      additionalGlazesFuture,
      materialsFuture,
    ]);

    return {
      'glaze': results[0] as Glaze?,
      'clay': results[1] as Clay?,
      'firingProfile': results[2] as FiringProfile?,
      'firingAtmosphere': results[3] as FiringAtmosphere?,
      'additionalGlazes': results[4] as List<Glaze>,
      'materials': results[5] as List<m.Material>,
    };
  }

  Widget _buildWideLayout(
    TestPiece testPiece,
    Glaze glaze,
    Clay? clay,
    FiringProfile? firingProfile,
    FiringAtmosphere? firingAtmosphere,
    BoxConstraints constraints,
    List<Glaze> additionalGlazes,
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
            firingProfile,
            firingAtmosphere,
            additionalGlazes,
            materials,
          ),
        ),
      ],
    );
  }

  Widget _buildNarrowLayout(
    TestPiece testPiece,
    Glaze glaze,
    Clay? clay,
    FiringProfile? firingProfile,
    FiringAtmosphere? firingAtmosphere,
    List<Glaze> additionalGlazes,
    List<m.Material> materials,
  ) {
    return ListView(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: _buildImage(testPiece),
        ),
        _buildInfoPanel(
          testPiece,
          glaze,
          clay,
          firingProfile,
          firingAtmosphere,
          additionalGlazes,
          materials,
        ),
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
                    onTapUp: _isEyedropperActive ? _handleImageTap : null,
                    onTap: !_isEyedropperActive && testPiece.imageUrl != null
                        ? () => _showFullScreenImage(context, testPiece)
                        : null,
                    child: RepaintBoundary(
                      key: _imageKey,
                      child: (testPiece.imageUrl != null)
                          ? CachedNetworkImage(
                              imageUrl: testPiece.imageUrl!,
                              fit: BoxFit.contain,
                              placeholder: (context, url) => const Center(
                                child: CircularProgressIndicator(),
                              ),
                              errorWidget: (context, url, error) => const Icon(
                                Icons.broken_image_outlined,
                                size: 50,
                                color: Colors.grey,
                              ),
                            )
                          : Container(
                              color: Colors.grey[200],
                              child: const Icon(
                                Icons.photo,
                                size: 60,
                                color: Colors.grey,
                              ),
                            ),
                    ),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: IconButton(
                        icon: Icon(
                          _isEyedropperActive
                              ? Icons.colorize
                              : Icons.colorize_outlined,
                          color: _isEyedropperActive
                              ? Colors.white
                              : Colors.grey[300],
                        ),
                        onPressed: () {
                          setState(() {
                            _isEyedropperActive = !_isEyedropperActive;
                          });
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                _isEyedropperActive
                                    ? '画像をタップして色を選択してください'
                                    : 'スポイトモードを終了しました',
                              ),
                              duration: const Duration(seconds: 1),
                            ),
                          );
                        },
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
              children: [_buildColorSwatches(testPiece.colorData!)],
            ),
          ),
      ],
    );
  }

  Widget _buildInfoPanel(
    TestPiece testPiece,
    Glaze glaze,
    Clay? clay,
    FiringProfile? firingProfile,
    FiringAtmosphere? firingAtmosphere,
    List<Glaze> additionalGlazes,
    List<m.Material> materials,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // レシピを最優先で表示
          if (glaze.recipe.isNotEmpty) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('レシピ', style: Theme.of(context).textTheme.titleMedium),
                TextButton.icon(
                  onPressed: () {
                    final materialMap = {
                      for (var m in materials) m.id!: m.name,
                    };
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => MixingCalculatorScreen(
                          recipe: glaze.recipe,
                          materialNames: materialMap,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.calculate),
                  label: const Text('調合計算へ'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _buildRecipeTable(glaze.recipe, materials),
            const Divider(height: 32),
          ],

          _buildInfoTile(
            '釉薬名 (メイン)',
            glaze.name, // glazeはnullでないことが確認済み
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => GlazeDetailScreen(glaze: glaze),
                ),
              );
            },
          ),
          if (additionalGlazes.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('追加の釉薬', style: Theme.of(context).textTheme.labelLarge),
            ...additionalGlazes.map(
              (g) => InkWell(
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => GlazeDetailScreen(glaze: g),
                    ),
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                  child: Text(
                    g.name,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ),
            ),
          ],
          _buildInfoTile('素地土名', clay?.name ?? '未設定'),
          _buildInfoTile(
            '焼成雰囲気',
            firingAtmosphere?.name ?? '未設定',
            tooltip: '焼成時の窯の雰囲気（酸化・還元など）です。',
          ),
          const Divider(height: 32),
          if (firingProfile != null) ...[
            Row(
              children: [
                Text(
                  '焼成プロファイル',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(width: 8),
                const Tooltip(
                  message: '焼成時の温度変化の記録です。',
                  triggerMode: TooltipTriggerMode.tap,
                  child: Icon(Icons.info_outline, size: 20, color: Colors.grey),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              firingProfile.name,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 16),
            if (firingProfile.curveData != null &&
                firingProfile.curveData!.isNotEmpty)
              FiringChart(curveData: firingProfile.curveData!),
          ] else
            _buildInfoTile('焼成プロファイル', '未設定'),

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

  Widget _buildRecipeTable(
    Map<String, double> recipe,
    List<m.Material> materials,
  ) {
    if (recipe.isEmpty) return const SizedBox.shrink();

    final materialMap = {for (var m in materials) m.id!: m.name};
    final sortedEntries = recipe.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value)); // 量の多い順

    return Table(
      border: TableBorder.all(color: Colors.grey.shade300),
      columnWidths: const {0: FlexColumnWidth(2), 1: FlexColumnWidth(1)},
      children: sortedEntries.map((entry) {
        final materialName = materialMap[entry.key] ?? '不明な原料';
        return TableRow(
          children: [
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(materialName),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(
                '${entry.value.toStringAsFixed(1)}g',
                textAlign: TextAlign.right,
              ),
            ),
          ],
        );
      }).toList(),
    );
  }

  /// 色見本ウィジェットを生成
  Widget _buildColorSwatches(List<ColorSwatch> colorData) {
    final significantColors = colorData
        .where((x) => x.percentage > 5.0)
        .toList();

    return Wrap(
      spacing: 8.0,
      runSpacing: 8.0,
      children: significantColors.map((swatch) {
        return InkWell(
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) =>
                    SearchScreen(initialColor: swatch.toColor()),
              ),
            );
          },
          child: Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: swatch.toColor(),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.black54, width: 1.0),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildInfoTile(
    String label,
    String value, {
    VoidCallback? onTap,
    String? tooltip,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(label, style: Theme.of(context).textTheme.labelLarge),
              if (tooltip != null) ...[
                const SizedBox(width: 4),
                Tooltip(
                  message: tooltip,
                  triggerMode: TooltipTriggerMode.tap,
                  child: const Icon(
                    Icons.info_outline,
                    size: 16,
                    color: Colors.grey,
                  ),
                ),
              ],
            ],
          ),
          InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4.0),
              child: Text(
                value,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: onTap != null
                      ? Theme.of(context).colorScheme.primary
                      : null,
                  decoration: onTap != null ? TextDecoration.underline : null,
                ),
              ),
            ),
          ),
        ],
      ),
    );
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

  Future<void> _handleImageTap(TapUpDetails details) async {
    final RenderRepaintBoundary boundary =
        _imageKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final ui.Image image = await boundary.toImage();
    final ByteData? byteData = await image.toByteData(
      format: ui.ImageByteFormat.rawRgba,
    );

    if (!mounted) return;

    if (byteData == null) return;

    final double width = boundary.size.width;
    final double height = boundary.size.height;

    final int x = details.localPosition.dx.toInt();
    final int y = details.localPosition.dy.toInt();

    if (x < 0 || x >= width || y < 0 || y >= height) return;

    final int offset = (y * image.width + x) * 4;
    final int r = byteData.getUint8(offset);
    final int g = byteData.getUint8(offset + 1);
    final int b = byteData.getUint8(offset + 2);
    final int a = byteData.getUint8(offset + 3);

    final Color pickedColor = Color.fromARGB(a, r, g, b);

    setState(() {
      _isEyedropperActive = false;
    });

    if (!mounted) return;

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
                    child: CachedNetworkImage(
                      imageUrl: widget.testPiece.imageUrl!,
                      fit: BoxFit.contain,
                      placeholder: (context, url) =>
                          const Center(child: CircularProgressIndicator()),
                      errorWidget: (context, url, error) => const Center(
                        child: Icon(Icons.error, color: Colors.red, size: 50),
                      ),
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
