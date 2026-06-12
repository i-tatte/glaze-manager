import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:glaze_manager/models/glaze.dart';
import 'package:glaze_manager/services/firestore_service.dart';

/// 釉薬インポート処理の結果を格納するクラス
class ImportResult {
  final int importedCount;
  final int skippedCount;
  final List<String> newlyAddedMaterials;

  ImportResult({
    required this.importedCount,
    required this.skippedCount,
    required this.newlyAddedMaterials,
  });
}

/// Excelの1行分をパースした中間データ (原料・顔料は名前のまま保持)
class ParsedGlazeRow {
  final String name;
  final String? registeredName;
  final String? description;
  final Map<String, double> amountsByMaterialName;
  final Map<String, double> amountsByPigmentName;

  ParsedGlazeRow({
    required this.name,
    this.registeredName,
    this.description,
    required this.amountsByMaterialName,
    required this.amountsByPigmentName,
  });
}

/// パース結果のプレビュー。
/// この時点ではFirestoreへの書き込みは一切行われていない。
/// 内容をユーザーに確認させてから [GlazeImporter.commit] で確定する。
class GlazeImportPreview {
  /// インポート対象の行
  final List<ParsedGlazeRow> rows;

  /// 既存釉薬と名前が重複するためスキップされる釉薬名
  final List<String> skippedGlazes;

  /// ヘッダーに含まれる原料名 (commit時に未登録なら自動作成される)
  final List<String> materialNamesInHeader;

  /// 新規作成されることになる原料名 (プレビュー表示用)
  final List<String> newMaterialNames;

  /// 新規作成されることになる顔料名 (プレビュー表示用)
  final List<String> newPigmentNames;

  GlazeImportPreview({
    required this.rows,
    required this.skippedGlazes,
    required this.materialNamesInHeader,
    required this.newMaterialNames,
    required this.newPigmentNames,
  });

  int get importCount => rows.length;
}

/// 釉薬のインポート機能を提供するクラス
class GlazeImporter {
  final FirestoreService firestoreService;

  GlazeImporter({required this.firestoreService});

  /// Excelのバイト列をパースして中間データに変換する (Firestoreアクセスなし)。
  ///
  /// 期待するシート形式 (1行目がヘッダー):
  ///   1列目=釉薬名, 2列目=登録名, 3列目〜=原料…,
  ///   末尾から3列目=「顔料」, 末尾列=「備考」
  /// 形式が異なる場合は [FormatException] (日本語メッセージ) を投げる。
  static ({List<ParsedGlazeRow> rows, List<String> skipped, List<String> materialNames})
  parseExcelBytes(
    List<int> bytes, {
    required Set<String> existingGlazeNames,
  }) {
    final excel = Excel.decodeBytes(bytes);

    if (excel.tables.keys.isEmpty) {
      throw const FormatException('ファイルにシートが含まれていません。');
    }

    final sheet = excel.tables[excel.tables.keys.first]!;
    if (sheet.maxRows < 2) {
      throw const FormatException('ファイルにデータが含まれていません。');
    }

    // --- ヘッダー検証 ---
    final headerRow = sheet.row(0);
    String headerText(int index) =>
        (index >= 0 && index < headerRow.length)
        ? (headerRow[index]?.value?.toString().trim() ?? '')
        : '';

    if (headerRow.length < 6 ||
        headerText(headerRow.length - 3) != '顔料' ||
        headerText(headerRow.length - 1) != '備考') {
      final found = [
        for (int i = 0; i < headerRow.length; i++) headerText(i),
      ].join(', ');
      throw FormatException(
        'ヘッダー行の形式が想定と異なります。\n'
        '期待: 釉薬名, 登録名, 原料…, 顔料, (任意列), 備考\n'
        '検出: $found',
      );
    }

    // 原料列は3列目〜「顔料」列の手前まで。
    // (顔料と備考の間の任意列を原料として誤登録しないよう、範囲で限定する)
    final materialNamesInHeader = [
      for (int j = 2; j < headerRow.length - 3; j++) headerText(j),
    ].where((name) => name.isNotEmpty).toList();

    // --- データ行のパース ---
    final parsedRows = <ParsedGlazeRow>[];
    final skippedGlazes = <String>[];

    for (int i = 1; i < sheet.maxRows; i++) {
      final row = sheet.row(i);
      if (row.isEmpty || row.first == null) continue;

      final glazeName = row.first!.value.toString().trim();
      if (glazeName.isEmpty || glazeName == 'null') continue;

      // 釉薬名の重複チェック
      if (existingGlazeNames.contains(glazeName)) {
        skippedGlazes.add(glazeName);
        continue;
      }

      final regName = row.length > 1 && row[1] != null
          ? row[1]!.value.toString().trim()
          : '';
      final description =
          row.length > headerRow.length - 1 && row[headerRow.length - 1] != null
          ? row[headerRow.length - 1]!.value.toString().trim()
          : '';

      final amountsByMaterialName = <String, double>{};
      for (int j = 2; j < headerRow.length - 3; j++) {
        final materialName = headerText(j);
        if (materialName.isEmpty) continue;

        final amount = row.length > j
            ? double.tryParse(row[j]?.value.toString() ?? '')
            : null;

        if (amount != null && amount > 0) {
          amountsByMaterialName[materialName] = amount;
        }
      }

      final amountsByPigmentName = <String, double>{};
      final pigmentCellIndex = headerRow.length - 3;
      if (row.length > pigmentCellIndex && row[pigmentCellIndex] != null) {
        final pigmentData = row[pigmentCellIndex]!.value.toString().trim();
        final pigmentEntries = pigmentData
            .split(',')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty);

        for (final entry in pigmentEntries) {
          final re = RegExp(r'^(.*?)([\d.]+)$');
          final match = re.firstMatch(entry);

          if (match != null) {
            final pigmentName = match.group(1)!.trim();
            final amount = double.tryParse(match.group(2)!);

            if (pigmentName.isNotEmpty && amount != null && amount > 0) {
              amountsByPigmentName[pigmentName] = amount;
            }
          }
        }
      }

      parsedRows.add(
        ParsedGlazeRow(
          name: glazeName,
          registeredName: regName.isNotEmpty ? regName : null,
          description: description.isNotEmpty ? description : null,
          amountsByMaterialName: amountsByMaterialName,
          amountsByPigmentName: amountsByPigmentName,
        ),
      );
    }

    return (
      rows: parsedRows,
      skipped: skippedGlazes,
      materialNames: materialNamesInHeader,
    );
  }

  /// ファイル選択 → パースしてプレビューを返す (Firestoreへの書き込みなし)。
  /// ファイル選択がキャンセルされた場合は null。
  /// 形式エラーは [FormatException] を投げる。
  Future<GlazeImportPreview?> pickAndParse() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx'],
    );

    if (result == null || result.files.single.path == null) {
      return null; // ファイルが選択されなかった
    }

    final bytes = await File(result.files.single.path!).readAsBytes();
    final existingGlazes = await firestoreService.getGlazesOnce();
    final parsed = parseExcelBytes(
      bytes,
      existingGlazeNames: existingGlazes.map((g) => g.name).toSet(),
    );

    if (parsed.rows.isEmpty && parsed.skipped.isEmpty) {
      throw const FormatException('インポート対象のデータが見つかりませんでした。');
    }

    // 新規作成される原料・顔料をプレビュー用に算出
    final existingMaterials = await firestoreService.getMaterialsOnce();
    final existingMaterialNames = existingMaterials.map((m) => m.name).toSet();

    final newMaterialNames = parsed.materialNames
        .where((name) => !existingMaterialNames.contains(name))
        .toSet()
        .toList();
    final newPigmentNames = parsed.rows
        .expand((r) => r.amountsByPigmentName.keys)
        .where((name) => !existingMaterialNames.contains(name))
        .toSet()
        .toList();

    return GlazeImportPreview(
      rows: parsed.rows,
      skippedGlazes: parsed.skipped,
      materialNamesInHeader: parsed.materialNames,
      newMaterialNames: newMaterialNames,
      newPigmentNames: newPigmentNames,
    );
  }

  /// プレビュー内容をFirestoreに書き込んで確定する。
  Future<ImportResult> commit(GlazeImportPreview preview) async {
    // 1. 未登録の原料・顔料を一括作成
    final newlyAddedMaterials = await firestoreService.findOrCreateMaterials(
      preview.materialNamesInHeader,
    );
    final newlyAddedPigments = await firestoreService.findOrCreatePigments(
      preview.rows.expand((r) => r.amountsByPigmentName.keys).toSet().toList(),
    );

    // 2. 最新の原料 名前->ID マップを1回だけ構築し、名前をIDに解決
    final allMaterials = await firestoreService.getMaterialsOnce();
    final materialIdMap = {for (var mat in allMaterials) mat.name: mat.id!};

    final importedGlazes = <Glaze>[];
    for (final parsed in preview.rows) {
      final recipe = <String, double>{};
      parsed.amountsByMaterialName.forEach((name, amount) {
        final id = materialIdMap[name];
        if (id != null) recipe[id] = amount;
      });
      parsed.amountsByPigmentName.forEach((name, amount) {
        final id = materialIdMap[name];
        if (id != null) recipe[id] = amount;
      });

      if (recipe.isNotEmpty) {
        importedGlazes.add(
          Glaze(
            name: parsed.name,
            registeredName: parsed.registeredName,
            recipe: recipe,
            tags: ['インポート'],
            description: parsed.description,
            createdAt: Timestamp.now(),
          ),
        );
      }
    }

    await firestoreService.addGlazesBatch(importedGlazes);

    return ImportResult(
      importedCount: importedGlazes.length,
      skippedCount: preview.skippedGlazes.length,
      newlyAddedMaterials: {
        ...newlyAddedMaterials,
        ...newlyAddedPigments,
      }.toList(),
    );
  }
}
