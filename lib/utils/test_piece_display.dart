import 'package:glaze_manager/models/clay.dart';
import 'package:glaze_manager/models/glaze.dart';
import 'package:glaze_manager/models/test_piece.dart';

/// テストピースの主たる釉薬の表示名。
/// 釉薬が現存すれば現在の名前、削除されていれば写しの名前を返す。
String glazeDisplayName(
  TestPiece testPiece,
  Map<String, Glaze> glazeMap, {
  String fallback = '不明な釉薬',
}) {
  return glazeMap[testPiece.glazeId]?.name ??
      testPiece.snapshot?.glaze?.name ??
      fallback;
}

/// テストピースの追加釉薬 [glazeId] の表示名。
/// 現存すれば現在の名前、削除されていれば写しの名前を返す。
String additionalGlazeDisplayName(
  TestPiece testPiece,
  String glazeId,
  Map<String, Glaze> glazeMap, {
  String fallback = '不明な釉薬',
}) {
  return glazeMap[glazeId]?.name ??
      testPiece.snapshot?.glazeSnapshotFor(glazeId)?.name ??
      fallback;
}

/// テストピースの素地土の表示名。
/// 素地土が現存すれば現在の名前、削除されていれば写しの名前を返す。
String clayDisplayName(
  TestPiece testPiece,
  Map<String, Clay> clayMap, {
  String fallback = '不明な素地',
}) {
  return clayMap[testPiece.clayId]?.name ??
      testPiece.snapshot?.clayName ??
      fallback;
}
