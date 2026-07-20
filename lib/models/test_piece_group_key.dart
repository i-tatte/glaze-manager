/// テストピース一覧のグループ表示キー
enum TestPieceGroupKey {
  /// グループ化しない (従来の単一グリッド表示)。デフォルト
  none('なし'),
  clay('素地土'),
  firingAtmosphere('焼成雰囲気'),
  firingProfile('焼成プロファイル'),
  colorHue('色味');

  const TestPieceGroupKey(this.label);

  /// UI 表示用ラベル
  final String label;

  /// 永続化された名前から enum を復元する。
  /// enum の並び替えに耐えるよう index ではなく name 文字列で照合し、
  /// 未知の値は [none] にフォールバックする。
  static TestPieceGroupKey fromName(String? name) =>
      values.firstWhere((e) => e.name == name, orElse: () => none);
}
