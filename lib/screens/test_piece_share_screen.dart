import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart'
    show ConsumerStatefulWidget, ConsumerState, AsyncValueX;
import 'package:glaze_manager/models/glaze.dart';
import 'package:glaze_manager/models/material.dart' as m;
import 'package:glaze_manager/models/test_piece.dart';
import 'package:glaze_manager/providers/data_providers.dart';
import 'package:glaze_manager/theme/app_theme.dart';
import 'package:glaze_manager/utils/date_format.dart';
import 'package:glaze_manager/utils/png_exporter.dart';
import 'package:glaze_manager/utils/test_piece_display.dart';
import 'package:glaze_manager/widgets/test_piece_image.dart';
import 'package:glaze_manager/widgets/common/color_swatch_row.dart';
import 'package:glaze_manager/widgets/common/info_tile.dart';
import 'package:glaze_manager/widgets/common/rating_stars.dart';
import 'package:glaze_manager/widgets/common/recipe_table.dart';
import 'package:glaze_manager/widgets/firing_chart.dart';

/// テストピースの情報 (写真・レシピ・焼成・素地土) を1枚のカードにまとめて
/// PNG として共有/保存する画面。
///
/// カードは論理幅 800px 固定で組み、RepaintBoundary を pixelRatio 2.5 で
/// キャプチャする。狭い画面では FittedBox で縮小表示されるが、変換は
/// RepaintBoundary の外側なのでキャプチャは常に等倍。
/// 配色は共有相手の環境や印刷を考慮して常にライトテーマで出力する。
class TestPieceShareScreen extends ConsumerStatefulWidget {
  final TestPiece testPiece;

  const TestPieceShareScreen({super.key, required this.testPiece});

  @override
  ConsumerState<TestPieceShareScreen> createState() =>
      _TestPieceShareScreenState();
}

class _TestPieceShareScreenState extends ConsumerState<TestPieceShareScreen> {
  static const double _captureWidth = 800.0;
  static const double _pixelRatio = 2.5;

  final GlobalKey _captureKey = GlobalKey();

  bool _imageReady = false; // precache 完了 (画像なしなら即 true)
  bool _isExporting = false;
  bool _precacheStarted = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_precacheStarted) {
      _precacheStarted = true;
      _precacheImage();
    }
  }

  /// キャプチャに画像の読み込み中表示が写らないよう、precache 完了を待ってから
  /// エクスポートボタンを有効化する。オフライン等で失敗しても機能は殺さない
  /// (壊れ画像アイコンのまま書き出せる)。
  Future<void> _precacheImage() async {
    // アップロード待ちがあれば端末内の画像を、なければネットワークの画像を使う
    final pending = ref.read(uploadQueueProvider).pending[widget.testPiece.id];
    final url = widget.testPiece.imageUrl;
    final ImageProvider provider;
    if (pending != null) {
      provider = FileImage(File(pending.localPath));
    } else if (url != null && url.isNotEmpty) {
      provider = CachedNetworkImageProvider(url);
    } else {
      setState(() => _imageReady = true);
      return;
    }
    try {
      await precacheImage(
        provider,
        context,
      ).timeout(const Duration(seconds: 10));
    } catch (_) {
      // タイムアウト・オフライン時はそのまま進む
    }
    if (mounted) setState(() => _imageReady = true);
  }

  Future<void> _export(String glazeName) async {
    if (_isExporting) return;
    setState(() => _isExporting = true);
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    try {
      // precache 済みでも画面反映前のフレームを掴まないよう1フレーム待つ
      await WidgetsBinding.instance.endOfFrame;
      final bytes = await PngExporter.captureBoundary(
        _captureKey,
        pixelRatio: _pixelRatio,
      );

      final now = DateTime.now();
      final dateSuffix =
          '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
      final fileName =
          '${PngExporter.sanitizeFileName(glazeName)}_$dateSuffix.png';

      final result = await PngExporter.export(bytes: bytes, fileName: fileName);
      if (result == PngExportResult.success && mounted) {
        final isMobile = !kIsWeb && (Platform.isAndroid || Platform.isIOS);
        if (!isMobile) {
          scaffoldMessenger.showSnackBar(
            const SnackBar(content: Text('PNGを保存しました')),
          );
        }
      }
    } catch (e) {
      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text('書き出しに失敗しました: $e')),
      );
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final testPiece = widget.testPiece;
    final glazeMap = ref.watch(glazeMapProvider);
    final clayMap = ref.watch(clayMapProvider);
    final atmosphereMap = ref.watch(firingAtmosphereMapProvider);
    final profileMap = ref.watch(firingProfileMapProvider);
    final firingMap = ref.watch(firingMapProvider);
    final materials = ref.watch(materialsProvider).valueOrNull ?? [];

    final glaze = glazeMap[testPiece.glazeId];
    final glazeName = glazeDisplayName(testPiece, glazeMap);
    final isMobile = !kIsWeb && (Platform.isAndroid || Platform.isIOS);

    // 出力は常にライトテーマ (共有相手の環境や印刷を考慮)。
    // プレビューもカードと同じテーマで包み、見たままが書き出されるようにする
    return Theme(
      data: AppTheme.light,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('共有プレビュー'),
          actions: [
            IconButton(
              icon: Icon(isMobile ? Icons.share : Icons.save_alt),
              tooltip: isMobile ? '共有' : 'PNGを保存',
              onPressed: (_imageReady && !_isExporting)
                  ? () => _export(glazeName)
                  : null,
            ),
          ],
        ),
        body: Stack(
          children: [
            SingleChildScrollView(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: RepaintBoundary(
                      key: _captureKey,
                      child: _buildCaptureCard(
                        testPiece,
                        glaze,
                        glazeName,
                        clayDisplayName(testPiece, clayMap, fallback: '未設定'),
                        resolveFiring(
                          testPiece,
                          firingMap: firingMap,
                          atmosphereMap: atmosphereMap,
                          profileMap: profileMap,
                        ),
                        materials,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (!_imageReady || _isExporting)
              const Positioned.fill(
                child: ColoredBox(
                  color: Colors.black26,
                  child: Center(child: CircularProgressIndicator()),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCaptureCard(
    TestPiece testPiece,
    Glaze? glaze,
    String glazeName,
    String? clayName,
    ResolvedFiring firing,
    List<m.Material> materials,
  ) {
    final theme = AppTheme.light;
    final createdAt = testPiece.createdAt.toDate();
    final dateText = formatDate(createdAt);
    final glazeMap = ref.read(glazeMapProvider);
    final additionalGlazeNames = [
      for (final id in testPiece.additionalGlazeIds)
        additionalGlazeDisplayName(testPiece, id, glazeMap),
    ];
    // 写しがあれば写しの調合を、なければ現在の釉薬の調合を使う
    final snapshotGlaze = testPiece.snapshot?.glaze;
    final hasRecipe = snapshotGlaze != null
        ? snapshotGlaze.lines.isNotEmpty
        : (glaze != null && glaze.recipe.isNotEmpty);
    final hasPendingUpload =
        ref.watch(uploadQueueProvider).pending[testPiece.id] != null;

    return Material(
      // 透過PNGにならないよう背景を明示的に塗る
      color: theme.colorScheme.surface,
      child: SizedBox(
        width: _captureWidth,
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Text(
                      glazeName,
                      style: theme.textTheme.headlineSmall,
                    ),
                  ),
                  Text(dateText, style: theme.textTheme.bodySmall),
                ],
              ),
              if (testPiece.rating != null) ...[
                const SizedBox(height: 8),
                RatingStars(rating: testPiece.rating),
              ],
              const SizedBox(height: 16),
              if (testPiece.imageUrl != null || hasPendingUpload) ...[
                AspectRatio(
                  aspectRatio: 1.0,
                  // 書き出す画像にアップロード待ちの印は写さない
                  child: TestPieceImage(
                    testPiece: testPiece,
                    preferThumbnail: false,
                    fit: BoxFit.contain,
                    iconSize: 60,
                    showPendingBadge: false,
                  ),
                ),
                const SizedBox(height: 16),
              ],
              if (testPiece.colorData != null &&
                  testPiece.colorData!.isNotEmpty) ...[
                ColorSwatchRow(colorData: testPiece.colorData!),
                const SizedBox(height: 16),
              ],
              if (hasRecipe) ...[
                Text('調合', style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                if (snapshotGlaze != null)
                  RecipeTable.fromSnapshot(
                    snapshot: snapshotGlaze,
                    materials: materials,
                  )
                else
                  RecipeTable(recipe: glaze!.recipe, materials: materials),
                const Divider(height: 32),
              ],
              if (additionalGlazeNames.isNotEmpty)
                InfoTile(label: '追加の釉薬', value: additionalGlazeNames.join('、')),
              InfoTile(label: '素地土名', value: clayName ?? '未設定'),
              InfoTile(label: '焼成雰囲気', value: firing.atmosphereLabel),
              if (firing.profileName != null) ...[
                const Divider(height: 32),
                Text('焼成プロファイル', style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                Text(firing.profileName!, style: theme.textTheme.bodyLarge),
                if (firing.curveData != null &&
                    firing.curveData!.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  FiringChart(
                    curveData: firing.curveData!,
                    isReduction: firing.isReduction,
                    reductionStartTemp: firing.reductionStartTemp,
                    reductionEndTemp: firing.reductionEndTemp,
                    // キャプチャに補間アニメの中間フレームが写らないようにする
                    duration: Duration.zero,
                  ),
                ],
              ] else
                InfoTile(label: '焼成プロファイル', value: firing.profileLabel),
              if (testPiece.note != null && testPiece.note!.isNotEmpty) ...[
                const Divider(height: 32),
                Text('備考', style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                Text(testPiece.note!, style: theme.textTheme.bodyLarge),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
