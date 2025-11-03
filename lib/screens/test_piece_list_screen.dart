import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:glaze_manager/models/test_piece.dart';
import 'package:glaze_manager/screens/test_piece_edit_screen.dart';
import 'package:glaze_manager/services/firestore_service.dart';
import 'package:provider/provider.dart';

class TestPieceListScreen extends StatelessWidget {
  const TestPieceListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final firestoreService = Provider.of<FirestoreService>(
      context,
      listen: false,
    );

    return Scaffold(
      appBar: AppBar(title: const Text('テストピース一覧')),
      body: StreamBuilder<List<TestPiece>>(
        stream: firestoreService.getTestPieces(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('エラーが発生しました: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(
              child: Text(
                'テストピースが登録されていません。\n右下のボタンから追加してください。',
                textAlign: TextAlign.center,
              ),
            );
          }

          final testPieces = snapshot.data!;

          return ListView.builder(
            itemCount: testPieces.length,
            itemBuilder: (context, index) {
              final testPiece = testPieces[index];
              return ListTile(
                title: Text(testPiece.clayName), // 仮に素地土名を表示
                subtitle: Text(
                  '釉薬ID: ${testPiece.glazeId.substring(0, 6)}... ' + // IDの先頭6文字を表示
                      '焼成日: ${testPiece.createdAt.toDate().toLocal().toString().split(' ')[0]}',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () async {
                  // ネットワーク接続を確認
                  final connectivityResult = await Connectivity()
                      .checkConnectivity();
                  if (connectivityResult.contains(ConnectivityResult.none)) {
                    // オフラインの場合、警告ダイアログを表示
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('オフラインです'),
                        content: const Text(
                          '現在オフラインのため、画像のアップロードはできません。テキスト情報のみ保存可能です。',
                        ),
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
                      builder: (context) =>
                          TestPieceEditScreen(testPiece: testPiece),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.add),
        onPressed: () async {
          // ネットワーク接続を確認
          final connectivityResult = await Connectivity().checkConnectivity();
          if (connectivityResult.contains(ConnectivityResult.none)) {
            // オフラインの場合、警告ダイアログを表示
            final confirmed = await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('オフラインです'),
                content: const Text(
                  '現在オフラインのため、画像のアップロードはできません。テキスト情報のみ保存可能です。',
                ),
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
              builder: (context) => const TestPieceEditScreen(),
            ),
          );
        },
      ),
    );
  }
}
