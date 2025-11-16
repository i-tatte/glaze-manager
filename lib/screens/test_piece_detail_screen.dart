import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:glaze_manager/models/firing_atmosphere.dart';
import 'package:glaze_manager/models/firing_profile.dart';
import 'package:glaze_manager/models/glaze.dart';
import 'package:glaze_manager/models/test_piece.dart';
import 'package:glaze_manager/screens/glaze_detail_screen.dart';
import 'package:glaze_manager/screens/test_piece_edit_screen.dart';
import 'package:glaze_manager/services/firestore_service.dart';
import 'package:glaze_manager/widgets/firing_chart.dart';
import 'package:provider/provider.dart';

class TestPieceDetailScreen extends StatefulWidget {
  final TestPiece testPiece;

  const TestPieceDetailScreen({super.key, required this.testPiece});

  @override
  State<TestPieceDetailScreen> createState() => _TestPieceDetailScreenState();
}

class _TestPieceDetailScreenState extends State<TestPieceDetailScreen> {
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
              final FiringProfile? firingProfile = details['firingProfile'];
              final FiringAtmosphere? firingAtmosphere =
                  details['firingAtmosphere'];

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
                      firingProfile,
                      firingAtmosphere,
                    );
                  } else {
                    return _buildNarrowLayout(
                      testPiece,
                      glaze,
                      firingProfile,
                      firingAtmosphere,
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
    // 各データを並行して取得
    final results = await Future.wait([
      firestoreService.getGlazes().first,
      firestoreService.getFiringProfiles().first,
      firestoreService.getFiringAtmospheres().first,
    ]);

    final allGlazes = results[0] as List<Glaze>;
    final allProfiles = results[1] as List<FiringProfile>;
    final allAtmospheres = results[2] as List<FiringAtmosphere>;

    final glaze = allGlazes.firstWhere(
      (g) => g.id == testPiece.glazeId,
      // orElseでデータが見つからない場合のデフォルト値を返す
      orElse: () => Glaze(
        name: '不明な釉薬',
        recipe: {},
        tags: [],
        createdAt: testPiece.createdAt,
      ),
    );

    FiringProfile? firingProfile;
    if (testPiece.firingProfileId != null) {
      firingProfile = allProfiles.firstWhere(
        (p) => p.id == testPiece.firingProfileId,
      );
    }

    FiringAtmosphere? firingAtmosphere;
    if (testPiece.firingAtmosphereId != null) {
      firingAtmosphere = allAtmospheres.firstWhere(
        (a) => a.id == testPiece.firingAtmosphereId,
      );
    }

    return {
      'glaze': glaze,
      'firingProfile': firingProfile,
      'firingAtmosphere': firingAtmosphere,
    };
  }

  Widget _buildWideLayout(
    TestPiece testPiece,
    Glaze glaze,
    FiringProfile? firingProfile,
    FiringAtmosphere? firingAtmosphere,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 1,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: _buildImage(testPiece),
          ),
        ),
        const VerticalDivider(width: 1),
        Expanded(
          flex: 1,
          child: _buildInfoPanel(
            testPiece,
            glaze,
            firingProfile,
            firingAtmosphere,
          ),
        ),
      ],
    );
  }

  Widget _buildNarrowLayout(
    TestPiece testPiece,
    Glaze glaze,
    FiringProfile? firingProfile,
    FiringAtmosphere? firingAtmosphere,
  ) {
    return ListView(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: _buildImage(testPiece),
        ),
        _buildInfoPanel(testPiece, glaze, firingProfile, firingAtmosphere),
      ],
    );
  }

  Widget _buildImage(TestPiece testPiece) {
    return AspectRatio(
      aspectRatio: 1.0,
      child: Hero(
        tag: 'testPieceImage_${testPiece.id}',
        child: Material(
          child: InkWell(
            onTap: testPiece.imageUrl != null
                ? () => _showFullScreenImage(context, testPiece)
                : null,
            child: (testPiece.imageUrl != null)
                ? CachedNetworkImage(
                    imageUrl: testPiece.imageUrl!,
                    fit: BoxFit.contain,
                    placeholder: (context, url) =>
                        const Center(child: CircularProgressIndicator()),
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
      ),
    );
  }

  Widget _buildInfoPanel(
    TestPiece testPiece,
    Glaze glaze,
    FiringProfile? firingProfile,
    FiringAtmosphere? firingAtmosphere,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoTile(
            '釉薬名',
            glaze.name,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => GlazeDetailScreen(glaze: glaze),
                ),
              );
            },
          ),
          _buildInfoTile('素地土名', testPiece.clayName),
          _buildInfoTile('焼成雰囲気', firingAtmosphere?.name ?? '未設定'),
          const Divider(height: 32),
          if (firingProfile != null) ...[
            Text('焼成プロファイル', style: Theme.of(context).textTheme.titleMedium),
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
        ],
      ),
    );
  }

  Widget _buildInfoTile(String label, String value, {VoidCallback? onTap}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelLarge),
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
    if (connectivityResult.contains(ConnectivityResult.none)) {
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
    if (!mounted) return;
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
        barrierColor: Colors.black.withOpacity(0.7), // 背景の半透明色
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
        ..translate(-position.dx, -position.dy)
        ..scale(2.0);
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
