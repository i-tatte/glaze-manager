import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glaze_manager/services/glaze_import_service.dart';

/// テスト用のxlsxバイト列を生成する
List<int> buildXlsx(List<List<String>> rows) {
  final excel = Excel.createExcel();
  final sheet = excel[excel.getDefaultSheet()!];
  for (final row in rows) {
    sheet.appendRow(row.map<CellValue?>((v) => TextCellValue(v)).toList());
  }
  return excel.save()!;
}

void main() {
  group('GlazeImporter.parseExcelBytes', () {
    // 形式: 釉薬名, 登録名, 原料…, 顔料, (任意列), 備考
    final header = ['釉薬名', '登録名', '長石', '珪石', '石灰', '顔料', 'メモ', '備考'];

    test('正常な形式をパースできる', () {
      final bytes = buildXlsx([
        header,
        ['新透明釉', 'T-1', '70', '20', '10', '', '', 'よく溶ける'],
        ['鉄赤釉', '', '60', '25', '15', '弁柄8, ベンガラ2', '', ''],
      ]);

      final parsed = GlazeImporter.parseExcelBytes(
        bytes,
        existingGlazeNames: {},
      );

      expect(parsed.rows.length, 2);
      expect(parsed.skipped, isEmpty);
      expect(parsed.materialNames, ['長石', '珪石', '石灰']);

      final first = parsed.rows[0];
      expect(first.name, '新透明釉');
      expect(first.registeredName, 'T-1');
      expect(first.description, 'よく溶ける');
      expect(first.amountsByMaterialName, {'長石': 70, '珪石': 20, '石灰': 10});
      expect(first.amountsByPigmentName, isEmpty);

      final second = parsed.rows[1];
      expect(second.registeredName, isNull);
      expect(second.amountsByPigmentName, {'弁柄': 8, 'ベンガラ': 2});
    });

    test('既存の釉薬名はスキップされる', () {
      final bytes = buildXlsx([
        header,
        ['既存釉', '', '50', '50', '', '', '', ''],
        ['新規釉', '', '50', '50', '', '', '', ''],
      ]);

      final parsed = GlazeImporter.parseExcelBytes(
        bytes,
        existingGlazeNames: {'既存釉'},
      );

      expect(parsed.rows.map((r) => r.name), ['新規釉']);
      expect(parsed.skipped, ['既存釉']);
    });

    test('ヘッダー形式が不正なら FormatException', () {
      // 「顔料」「備考」列がないヘッダー
      final bytes = buildXlsx([
        ['名前', '何か', '長石', '珪石'],
        ['新規釉', '', '50', '50'],
      ]);

      expect(
        () => GlazeImporter.parseExcelBytes(bytes, existingGlazeNames: {}),
        throwsA(isA<FormatException>()),
      );
    });

    test('数値でない配合量や0以下は無視される', () {
      final bytes = buildXlsx([
        header,
        ['新規釉', '', 'abc', '-5', '30', '', '', ''],
      ]);

      final parsed = GlazeImporter.parseExcelBytes(
        bytes,
        existingGlazeNames: {},
      );

      expect(parsed.rows.single.amountsByMaterialName, {'石灰': 30});
    });
  });
}
