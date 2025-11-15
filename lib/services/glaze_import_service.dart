import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
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

/// 釉薬のインポート機能を提供するクラス
class GlazeImporter {
  final FirestoreService firestoreService;

  GlazeImporter({required this.firestoreService});

  /// Excelファイルから釉薬をインポートする
  Future<void> importFromExcel({
    required VoidCallback onStart,
    required Function(ImportResult result) onSuccess,
    required Function(String error) onError,
    required VoidCallback onDone,
  }) async {
    onStart();

    try {
      // 1. ファイルを選択
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx'],
      );

      if (result == null || result.files.single.path == null) {
        return; // ファイルが選択されなかった場合は終了
      }

      final bytes = await File(result.files.single.path!).readAsBytes();
      final excel = Excel.decodeBytes(bytes);

      if (excel.tables.keys.isEmpty) {
        throw Exception('ファイルにシートが含まれていません。');
      }

      final sheet = excel.tables[excel.tables.keys.first]!;
      if (sheet.maxRows < 2) {
        throw Exception('ファイルにデータが含まれていません。');
      }

      // 2. ヘッダーから原料リストを抽出し、未登録なら自動作成
      final headerRow = sheet.row(0);
      final materialNamesInHeader = headerRow
          .skip(2) // 1, 2列目は無視
          .map((cell) => cell?.value?.toString().trim() ?? '')
          .where((name) => name.isNotEmpty && name != '顔料' && name != '備考')
          .toList();

      final newlyAddedMaterials = await firestoreService.findOrCreateMaterials(
        materialNamesInHeader,
      );
      List<String> newlyAddedPigments = [];

      // 3. 既存の釉薬名リストと、全原料の名前->IDマップを作成
      final existingGlazes = await firestoreService.getGlazes().first;
      final existingGlazeNames = existingGlazes.map((g) => g.name).toSet();
      final allMaterials = await firestoreService.getMaterials().first;
      final materialIdMap = {for (var mat in allMaterials) mat.name: mat.id!};

      // 4. 釉薬データを作成
      final List<Glaze> importedGlazes = [];
      final List<String> skippedGlazes = [];

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
            row.length > headerRow.length - 1 &&
                row[headerRow.length - 1] != null
            ? row[headerRow.length - 1]!.value.toString().trim()
            : '';

        final recipe = <String, double>{};
        for (int j = 2; j < headerRow.length - 3; j++) {
          if (j >= headerRow.length) continue;
          final materialName = headerRow[j]?.value.toString().trim() ?? '';
          final materialId = materialIdMap[materialName];
          if (materialId == null) continue;

          final amount = row.length > j
              ? double.tryParse(row[j]?.value.toString() ?? '')
              : null;

          if (amount != null && amount > 0) {
            recipe[materialId] = amount;
          }
        }

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
                var pigmentId = await firestoreService.findOrCreatePigmentID(
                  pigmentName,
                );
                recipe[pigmentId] = amount;
                if (!newlyAddedPigments.contains(pigmentName)) {
                  newlyAddedPigments.add(pigmentName);
                }
              }
            }
          }
        }

        if (recipe.isNotEmpty) {
          importedGlazes.add(
            Glaze(
              name: glazeName,
              registeredName: regName.isNotEmpty ? regName : null,
              recipe: recipe,
              tags: ['インポート'],
              description: description.isNotEmpty ? description : null,
              createdAt: Timestamp.now(),
            ),
          );
        }
      }

      if (importedGlazes.isEmpty && skippedGlazes.isEmpty) {
        throw Exception('インポート対象のデータが見つかりませんでした。');
      }

      await firestoreService.addGlazesBatch(importedGlazes);

      final allNewMaterials = {...newlyAddedMaterials, ...newlyAddedPigments};

      onSuccess(
        ImportResult(
          importedCount: importedGlazes.length,
          skippedCount: skippedGlazes.length,
          newlyAddedMaterials: allNewMaterials.toList(),
        ),
      );
    } catch (e) {
      onError(e.toString());
    } finally {
      onDone();
    }
  }
}
