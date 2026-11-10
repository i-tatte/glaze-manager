import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart'
    show ConsumerStatefulWidget, ConsumerState, AsyncValueX;
import 'package:glaze_manager/models/firing_profile.dart';
import 'package:glaze_manager/models/glaze.dart';
import 'package:glaze_manager/models/material.dart' as m;
import 'package:glaze_manager/models/test_piece.dart';
import 'package:glaze_manager/providers/data_providers.dart';
import 'package:glaze_manager/theme/app_theme.dart';
import 'package:glaze_manager/utils/png_exporter.dart';
import 'package:glaze_manager/widgets/common/app_network_image.dart';
import 'package:glaze_manager/widgets/common/color_swatch_row.dart';
import 'package:glaze_manager/widgets/common/info_tile.dart';
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
    final url = widget.testPiece.imageUrl;
    if (url == null || url.isEmpty) {
      setState(() => _imageReady = true);
      return;
    }
    try {
      await precacheImage(
        CachedNetworkImageProvider(url),
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
    final materials = ref.watch(materialsProvider).valueOrNull ?? [];

    final glaze = glazeMap[testPiece.glazeId];
    final glazeName = glaze?.name ?? '不明な釉薬';
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
                        clayMap[testPiece.clayId]?.name,
                        atmosphereMap[testPiece.firingAtmosphereId]?.name,
                        profileMap[testPiece.firingProfileId],
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
    String? atmosphereName,
    FiringProfile? firingProfile,
    List<m.Material> materials,
  ) {
    final theme = AppTheme.light;
    final createdAt = testPiece.createdAt.toDate();
    final dateText = '${createdAt.year}/${createdAt.month}/${createdAt.day}';
    final additionalGlazeNames = [
      for (final id in testPiece.additionalGlazeIds)
        ref.read(glazeMapProvider)[id]?.name ?? '不明な釉薬',
    ];

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
              const SizedBox(height: 16),
              if (testPiece.imageUrl != null) ...[
                AspectRatio(
                  aspectRatio: 1.0,
                  child: AppNetworkImage(
                    url: testPiece.imageUrl,
                    fit: BoxFit.contain,
                    iconSize: 60,
                  ),
                ),
                const SizedBox(height: 16),
              ],
              if (testPiece.colorData != null &&
                  testPiece.colorData!.isNotEmpty) ...[
                ColorSwatchRow(colorData: testPiece.colorData!),
                const SizedBox(height: 16),
              ],
              if (glaze != null && glaze.recipe.isNotEmpty) ...[
                Text('調合', style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                RecipeTable(recipe: glaze.recipe, materials: materials),
                const Divider(height: 32),
              ],
              if (additionalGlazeNames.isNotEmpty)
                InfoTile(label: '追加の釉薬', value: additionalGlazeNames.join('、')),
              InfoTile(label: '素地土名', value: clayName ?? '未設定'),
              InfoTile(label: '焼成雰囲気', value: atmosphereName ?? '未設定'),
              if (firingProfile != null) ...[
                const Divider(height: 32),
                Text('焼成プロファイル', style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                Text(firingProfile.name, style: theme.textTheme.bodyLarge),
                if (firingProfile.curveData != null &&
                    firingProfile.curveData!.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  FiringChart.fromProfile(
                    firingProfile,
                    // キャプチャに補間アニメの中間フレームが写らないようにする
                    duration: Duration.zero,
                  ),
                ],
              ] else
                const InfoTile(label: '焼成プロファイル', value: '未設定'),
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
