import 'package:flutter/material.dart';
import 'package:glaze_manager/models/glaze.dart';
import 'package:glaze_manager/screens/glaze_edit_screen.dart';
import 'package:glaze_manager/services/firestore_service.dart';
import 'package:provider/provider.dart';

class GlazeListScreen extends StatelessWidget {
  const GlazeListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final firestoreService = Provider.of<FirestoreService>(context, listen: false);

    return Scaffold(
      appBar: AppBar(
        title: const Text('釉薬レシピ一覧'),
      ),
      body: StreamBuilder<List<Glaze>>(
        stream: firestoreService.getGlazes(),
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
                '釉薬が登録されていません。\n右下のボタンから追加してください。',
                textAlign: TextAlign.center,
              ),
            );
          }

          final glazes = snapshot.data!;

          return ListView.builder(
            itemCount: glazes.length,
            itemBuilder: (context, index) {
              final glaze = glazes[index];
              return ListTile(
                title: Text(glaze.name),
                subtitle: Text(glaze.tags.join(', ')),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.of(context).push(MaterialPageRoute(
                    builder: (context) => GlazeEditScreen(glaze: glaze),
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
          Navigator.of(context).push(MaterialPageRoute(
            builder: (context) => const GlazeEditScreen(),
          ));
        },
      ),
    );
  }
}