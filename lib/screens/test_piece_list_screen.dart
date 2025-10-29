import 'package:flutter/material.dart';
import 'package:glaze_manager/models/test_piece.dart';
import 'package:glaze_manager/screens/test_piece_edit_screen.dart';
import 'package:glaze_manager/services/firestore_service.dart';
import 'package:provider/provider.dart';

class TestPieceListScreen extends StatelessWidget {
  const TestPieceListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final firestoreService = Provider.of<FirestoreService>(context, listen: false);

    return Scaffold(
      appBar: AppBar(
        title: const Text('テストピース一覧'),
      ),
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
                        '焼成日: ${testPiece.createdAt.toDate().toLocal().toString().split(' ')[0]}'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  // 既存のテストピースを編集
                  Navigator.of(context).push(MaterialPageRoute(
                    builder: (context) => TestPieceEditScreen(testPiece: testPiece),
                  ));
                },
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.add),
        onPressed: () {
          // 新規テストピースを作成
          Navigator.of(context).push(MaterialPageRoute(
            builder: (context) => const TestPieceEditScreen(),
          ));
        },
      ),
    );
  }
}