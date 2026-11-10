import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart'
    show ConsumerWidget, WidgetRef, AsyncValueX;
import 'package:glaze_manager/models/firing.dart';
import 'package:glaze_manager/models/firing_atmosphere.dart';
import 'package:glaze_manager/models/test_piece.dart';
import 'package:glaze_manager/providers/data_providers.dart';
import 'package:glaze_manager/screens/firing_detail_screen.dart';
import 'package:glaze_manager/screens/firing_edit_screen.dart';
import 'package:glaze_manager/utils/test_piece_display.dart';
import 'package:glaze_manager/widgets/common/empty_list_placeholder.dart';

/// 焼成回の一覧。テストピースタブの AppBar のボタンから開く。
class FiringListScreen extends ConsumerWidget {
  const FiringListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final testPieces = ref.watch(testPiecesProvider).valueOrNull ?? [];
    final atmosphereMap = ref.watch(firingAtmosphereMapProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('焼成回')),
      body: Stack(
        children: [
          ref
              .watch(firingsProvider)
              .when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) => Center(child: Text('エラーが発生しました: $error')),
                data: (firings) {
                  if (firings.isEmpty) {
                    return const EmptyListPlaceholder(
                      message: '焼成回が登録されていません。\n右下のボタンから追加してください。',
                    );
                  }

                  return ListView.builder(
                    // 最後の項目が FAB に隠れないための余白
                    padding: const EdgeInsets.only(bottom: 80),
                    itemCount: firings.length,
                    itemBuilder: (context, index) {
                      final firing = firings[index];
                      return ListTile(
                        title: Text(firing.displayLabel),
                        subtitle: Text(
                          _subtitle(firing, testPieces, atmosphereMap),
                        ),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) =>
                                FiringDetailScreen(firingId: firing.id!),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
          Positioned(
            bottom: 16.0,
            right: 16.0,
            child: FloatingActionButton(
              heroTag: 'firingListFab',
              tooltip: '焼成回を追加',
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const FiringEditScreen(),
                  ),
                );
              },
              child: const Icon(Icons.add),
            ),
          ),
        ],
      ),
    );
  }

  /// 「雰囲気名 ・ N 枚」。写真待ちがあれば「（写真待ち M 枚）」を続ける。
  static String _subtitle(
    Firing firing,
    List<TestPiece> testPieces,
    Map<String, FiringAtmosphere> atmosphereMap,
  ) {
    final pieces = testPieces.where((tp) => tp.firingId == firing.id).toList();
    final awaiting = pieces.where(isAwaitingPhoto).length;
    final atmosphereName =
        atmosphereMap[firing.firingAtmosphereId]?.name ??
        firing.atmosphereName ??
        '未設定';
    final text = '$atmosphereName ・ ${pieces.length} 枚';
    return awaiting > 0 ? '$text（写真待ち $awaiting 枚）' : text;
  }
}
