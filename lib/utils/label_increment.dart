/// ピースの番号の次の候補を返す。
///
/// 番号の末尾が数字なら、その数字を 1 増やして返す。桁数は保つ
/// (「1108-03」は「1108-04」、「1108-09」は「1108-10」)。
/// 末尾が数字でない、または番号が null か空のときは null を返す。
String? nextLabel(String? label) {
  if (label == null || label.isEmpty) return null;
  final match = RegExp(r'(\d+)$').firstMatch(label);
  if (match == null) return null;
  final digits = match.group(1)!;
  final next = (BigInt.parse(digits) + BigInt.one).toString().padLeft(
    digits.length,
    '0',
  );
  return label.substring(0, match.start) + next;
}
