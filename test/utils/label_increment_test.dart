import 'package:flutter_test/flutter_test.dart';
import 'package:glaze_manager/utils/label_increment.dart';

void main() {
  group('nextLabel', () {
    test('末尾の数字を 1 増やし、桁数を保つ', () {
      expect(nextLabel('1108-03'), '1108-04');
      expect(nextLabel('A1'), 'A2');
      expect(nextLabel('7'), '8');
    });

    test('繰り上がりでも桁数を保つ', () {
      expect(nextLabel('1108-09'), '1108-10');
      expect(nextLabel('1108-099'), '1108-100');
    });

    test('桁が足りなくなれば桁を増やす', () {
      expect(nextLabel('1108-99'), '1108-100');
      expect(nextLabel('9'), '10');
    });

    test('末尾が数字でなければ null', () {
      expect(nextLabel('1108-a'), isNull);
      expect(nextLabel('テスト'), isNull);
      expect(nextLabel('12 '), isNull);
    });

    test('null と空文字列は null', () {
      expect(nextLabel(null), isNull);
      expect(nextLabel(''), isNull);
    });
  });
}
