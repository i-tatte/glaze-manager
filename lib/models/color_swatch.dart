/// Firestoreに保存される、解析された色のデータ構造を表すクラス。
class ColorSwatch {
  /// CIELAB色空間のL*値 (明度)
  final double l;

  /// CIELAB色空間のa*値 (緑-赤)
  final double a;

  /// CIELAB色空間のb*値 (青-黄)
  final double b;

  /// 画像全体におけるこの色の構成比率 (%)
  final double percentage;

  ColorSwatch({
    required this.l,
    required this.a,
    required this.b,
    required this.percentage,
  });

  /// FirestoreのMapデータからColorSwatchオブジェクトを生成するファクトリコンストラクタ。
  factory ColorSwatch.fromMap(Map<String, dynamic> map) {
    return ColorSwatch(
      l: (map['L'] as num?)?.toDouble() ?? 0.0,
      a: (map['a'] as num?)?.toDouble() ?? 0.0,
      b: (map['b'] as num?)?.toDouble() ?? 0.0,
      percentage: (map['percentage'] as num?)?.toDouble() ?? 0.0,
    );
  }

  /// ColorSwatchオブジェクトをFirestoreに保存可能なMapに変換する。
  Map<String, dynamic> toMap() {
    return {'L': l, 'a': a, 'b': b, 'percentage': percentage};
  }
}
