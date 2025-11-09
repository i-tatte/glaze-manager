import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:glaze_manager/models/firing_atmosphere.dart';
import 'package:glaze_manager/models/firing_profile.dart';
import 'package:glaze_manager/models/glaze.dart';
import 'package:glaze_manager/models/test_piece.dart';
import 'package:glaze_manager/screens/test_piece_edit_screen.dart';
import 'package:glaze_manager/services/firestore_service.dart';
import 'package:glaze_manager/services/storage_service.dart';
import 'package:glaze_manager/widgets/firing_chart.dart';
import 'package:provider/provider.dart';

class TestPieceDetailScreen extends StatefulWidget {
  final TestPiece testPiece;

  const TestPieceDetailScreen({super.key, required this.testPiece});

  @override
  State<TestPieceDetailScreen> createState() => _TestPieceDetailScreenState();
}

class _TestPieceDetailScreenState extends State<TestPieceDetailScreen> {
  late Future<Map<String, dynamic>> _detailsFuture;

  @override
  void initState() {
    super.initState();
    _detailsFuture = _loadDetails();
  }

  Future<Map<String, dynamic>> _loadDetails() async {
    final firestoreService = context.read<FirestoreService>();
    final glaze = (await firestoreService.getGlazes().first).firstWhere(
      (g) => g.id == widget.testPiece.glazeId,
    );

    FiringProfile? firingProfile;
    if (widget.testPiece.firingProfileId != null) {
      firingProfile = (await firestoreService.getFiringProfiles().first)
          .firstWhere((p) => p.id == widget.testPiece.firingProfileId);
    }

    FiringAtmosphere? firingAtmosphere;
    if (widget.testPiece.firingAtmosphereId != null) {
      firingAtmosphere = (await firestoreService.getFiringAtmospheres().first)
          .firstWhere((a) => a.id == widget.testPiece.firingAtmosphereId);
    }

    return {
      'glaze': glaze,
      'firingProfile': firingProfile,
      'firingAtmosphere': firingAtmosphere,
    };
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('削除の確認'),
        content: const Text('このテストピースを本当に削除しますか？\nこの操作は元に戻せません。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('削除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final navigator = Navigator.of(context);
      try {
        final firestoreService = context.read<FirestoreService>();
        final storageService = context.read<StorageService>();

        // Storageから画像を削除
        if (widget.testPiece.imageUrl != null) {
          await storageService.deleteTestPieceImage(widget.testPiece.imageUrl!);
        }
        // Firestoreからドキュメントを削除
        await firestoreService.deleteTestPiece(widget.testPiece.id!);

        navigator.pop(); // 詳細画面を閉じる
      } catch (e) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('削除に失敗しました: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('テストピース詳細'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            tooltip: '編集',
            onPressed: () async {
              _navigateToEditScreen(context, testPiece: widget.testPiece);
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.red),
            tooltip: '削除',
            onPressed: _confirmDelete,
          ),
        ],
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _detailsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('詳細データの読み込みに失敗しました: ${snapshot.error}'));
          }
          if (!snapshot.hasData) {
            return const Center(child: Text('データが見つかりません。'));
          }

          final details = snapshot.data!;
          final Glaze glaze = details['glaze'];
          final FiringProfile? firingProfile = details['firingProfile'];
          final FiringAtmosphere? firingAtmosphere =
              details['firingAtmosphere'];

          return LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth / constraints.maxHeight > 1.2;
              if (isWide) {
                return _buildWideLayout(glaze, firingProfile, firingAtmosphere);
              } else {
                return _buildNarrowLayout(
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
  }

  Widget _buildWideLayout(
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
            child: _buildImage(),
          ),
        ),
        const VerticalDivider(width: 1),
        Expanded(
          flex: 1,
          child: _buildInfoPanel(glaze, firingProfile, firingAtmosphere),
        ),
      ],
    );
  }

  Widget _buildNarrowLayout(
    Glaze glaze,
    FiringProfile? firingProfile,
    FiringAtmosphere? firingAtmosphere,
  ) {
    return ListView(
      children: [
        Padding(padding: const EdgeInsets.all(16.0), child: _buildImage()),
        _buildInfoPanel(glaze, firingProfile, firingAtmosphere),
      ],
    );
  }

  Widget _buildImage() {
    return AspectRatio(
      aspectRatio: 1.0,
      child: widget.testPiece.imageUrl != null
          ? Image.network(
              widget.testPiece.imageUrl!,
              fit: BoxFit.contain,
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return const Center(child: CircularProgressIndicator());
              },
              errorBuilder: (context, error, stackTrace) =>
                  const Icon(Icons.broken_image, size: 60, color: Colors.grey),
            )
          : Container(
              color: Colors.grey[200],
              child: const Icon(Icons.photo, size: 60, color: Colors.grey),
            ),
    );
  }

  Widget _buildInfoPanel(
    Glaze glaze,
    FiringProfile? firingProfile,
    FiringAtmosphere? firingAtmosphere,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoTile('釉薬名', glaze.name),
          _buildInfoTile('素地土名', widget.testPiece.clayName),
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

  Widget _buildInfoTile(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 4),
          Text(value, style: Theme.of(context).textTheme.bodyLarge),
        ],
      ),
    );
  }

  /// 編集画面へ遷移する（オフラインチェック含む）
  Future<void> _navigateToEditScreen(
    BuildContext context, {
    TestPiece? testPiece,
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
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => TestPieceEditScreen(testPiece: testPiece),
      ),
    );
  }
}
