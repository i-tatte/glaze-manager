import 'package:glaze_manager/models/clay.dart';
import 'package:glaze_manager/models/glaze.dart';
import 'package:glaze_manager/models/material.dart';
import 'package:glaze_manager/models/recipe_snapshot.dart';
import 'package:glaze_manager/models/test_piece.dart';

/// 写しを持たないテストピースについて、埋めるべき写しを返す。
/// 主たる釉薬が見つからないテストピースは対象にしない。
/// 追加釉薬のうち見つからないものは写しに含めない。
Map<String, TestPieceSnapshot> planSnapshotBackfill({
  required List<TestPiece> pieces,
  required Map<String, Glaze> glazeMap,
  required Map<String, Material> materialMap,
  required Map<String, Clay> clayMap,
}) {
  return {
    for (final piece in pieces)
      if (piece.id != null &&
          piece.snapshot == null &&
          glazeMap.containsKey(piece.glazeId))
        piece.id!: TestPieceSnapshot.capture(
          glazeId: piece.glazeId,
          additionalGlazeIds: piece.additionalGlazeIds,
          clayId: piece.clayId,
          glazeMap: glazeMap,
          materialMap: materialMap,
          clayMap: clayMap,
          source: SnapshotSource.backfilled,
        ),
  };
}
