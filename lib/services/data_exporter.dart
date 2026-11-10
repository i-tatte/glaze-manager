import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:excel/excel.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:glaze_manager/models/clay.dart';
import 'package:glaze_manager/models/firing.dart';
import 'package:glaze_manager/models/firing_atmosphere.dart';
import 'package:glaze_manager/models/firing_profile.dart';
import 'package:glaze_manager/models/glaze.dart';
import 'package:glaze_manager/models/material.dart';
import 'package:glaze_manager/models/recipe_snapshot.dart';
import 'package:glaze_manager/models/test_piece.dart';
import 'package:glaze_manager/services/firestore_service.dart';
import 'package:glaze_manager/services/upload_queue.dart';
import 'package:glaze_manager/utils/date_format.dart';
import 'package:glaze_manager/utils/test_piece_display.dart';
import 'package:glaze_manager/widgets/common/recipe_table.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

/// data.json の形式の版
const int exportFormatVersion = 1;

/// Firestore の値を JSON にできる値へ変える。
/// Timestamp / DateTime は ISO 8601 (UTC) の文字列にする。Map と List は再帰的に変える。
Object? toJsonSafe(Object? value) {
  if (value is Timestamp) return value.toDate().toUtc().toIso8601String();
  if (value is DateTime) return value.toUtc().toIso8601String();
  if (value is Map) {
    return {
      for (final entry in value.entries)
        entry.key.toString(): toJsonSafe(entry.value),
    };
  }
  if (value is Iterable) return [for (final item in value) toJsonSafe(item)];
  if (value is double && (value.isNaN || value.isInfinite)) return null;
  return value;
}

/// 文書の toFirestore() の Map に id を足したもの。
Map<String, dynamic> _withId(String? id, Map<String, dynamic> data) {
  return toJsonSafe({'id': id, ...data}) as Map<String, dynamic>;
}

/// data.json の中身を作る。
Map<String, dynamic> buildExportJson({
  required DateTime exportedAt,
  required List<Material> materials,
  required List<Glaze> glazes,
  required List<Clay> clays,
  required List<FiringProfile> firingProfiles,
  required List<FiringAtmosphere> firingAtmospheres,
  required List<Firing> firings,
  required List<String> tags,
  required List<TestPiece> testPieces,
  required List<String> missingImages,
}) {
  return {
    'formatVersion': exportFormatVersion,
    'exportedAt': exportedAt.toUtc().toIso8601String(),
    'collections': {
      'materials': [for (final d in materials) _withId(d.id, d.toFirestore())],
      'glazes': [for (final d in glazes) _withId(d.id, d.toFirestore())],
      'clays': [for (final d in clays) _withId(d.id, d.toFirestore())],
      'firingProfiles': [
        for (final d in firingProfiles) _withId(d.id, d.toFirestore()),
      ],
      'firingAtmospheres': [
        for (final d in firingAtmospheres) _withId(d.id, d.toFirestore()),
      ],
      'firings': [for (final d in firings) _withId(d.id, d.toFirestore())],
      'tags': List<String>.of(tags),
      'testPieces': [
        for (final d in testPieces) _withId(d.id, d.toFirestore()),
      ],
    },
    'missingImages': List<String>.of(missingImages),
  };
}

TextCellValue _text(String value) => TextCellValue(value);

CellValue? _textOrNull(String? value) =>
    (value == null || value.isEmpty) ? null : TextCellValue(value);

CellValue _number(double value) {
  // NaN や無限大は数値のセルにできない。1 件の値で書き出し全体を失敗させない
  if (!value.isFinite) return TextCellValue(value.toString());
  return value == value.roundToDouble()
      ? IntCellValue(value.toInt())
      : DoubleCellValue(value);
}

/// 顔料の列の値。「弁柄 8, 呉須 2」のように、名前・半角スペース・量をカンマで区切る。
/// スペースがないと、数字で終わる名前の顔料が取り込みで往復しない。
String formatPigmentCell(List<MapEntry<String, double>> pigments) {
  return pigments
      .map((e) => '${e.key} ${RecipeTable.formatAmount(e.value)}')
      .join(', ');
}

String _formatSnapshotLines(GlazeSnapshot snapshot) => snapshot.lines
    .map((l) => '${l.name} ${RecipeTable.formatAmount(l.amount)}')
    .join(' / ');

/// テストピースのシートの「調合」の列。写しがなければ空。
/// 追加釉薬があるときは、釉薬ごとに名前を付けて改行でつなぐ。
String _formatPieceRecipe(TestPiece piece) {
  final snapshot = piece.snapshot;
  if (snapshot == null) return '';
  final glazes = [
    if (snapshot.glaze != null) snapshot.glaze!,
    ...snapshot.additionalGlazes,
  ];
  if (glazes.isEmpty) return '';
  if (glazes.length == 1) return _formatSnapshotLines(glazes.first);
  return glazes.map((g) => '${g.name}: ${_formatSnapshotLines(g)}').join('\n');
}

/// 書き出し用のブックを作る (ファイルの入出力はしない)。
///
/// 先頭のシート「釉薬」は既存の釉薬の取り込みがそのまま読める形にする。
/// [imageFileNames] はテストピース ID → ZIP 内の画像のファイル名 (images/ 以下)。
Uint8List buildExportWorkbook({
  required List<Material> materials,
  required List<Glaze> glazes,
  required List<Clay> clays,
  required List<FiringProfile> firingProfiles,
  required List<FiringAtmosphere> firingAtmospheres,
  required List<Firing> firings,
  required List<TestPiece> testPieces,
  Map<String, String> imageFileNames = const {},
}) {
  final excel = Excel.createExcel();
  // createExcel は既定のシート「Sheet1」を持つ。改名して釉薬のシートにする。
  final defaultSheet = excel.getDefaultSheet()!;
  excel.rename(defaultSheet, '釉薬');

  final materialById = {
    for (final m in materials)
      if (m.id != null) m.id!: m,
  };

  // --- 釉薬 ---
  final usedMaterialIds = <String>{for (final g in glazes) ...g.recipe.keys};
  final baseMaterials = [
    for (final m in materials)
      if (m.id != null &&
          m.category != MaterialCategory.pigment &&
          usedMaterialIds.contains(m.id))
        m,
  ];
  final glazeSheet = excel['釉薬'];
  glazeSheet.appendRow([
    _text('釉薬名'),
    _text('登録名'),
    for (final m in baseMaterials) _text(m.name),
    _text('顔料'),
    _text('タグ'),
    _text('備考'),
  ]);
  for (final glaze in glazes) {
    final pigments = <MapEntry<String, double>>[];
    for (final entry in glaze.recipe.entries) {
      final material = materialById[entry.key];
      if (material != null && material.category == MaterialCategory.pigment) {
        pigments.add(MapEntry(material.name, entry.value));
      }
    }
    glazeSheet.appendRow([
      _text(glaze.name),
      _textOrNull(glaze.registeredName),
      for (final m in baseMaterials)
        glaze.recipe[m.id] == null ? null : _number(glaze.recipe[m.id]!),
      _textOrNull(formatPigmentCell(pigments)),
      _textOrNull(glaze.tags.join('、')),
      _textOrNull(glaze.description),
    ]);
  }

  // --- テストピース ---
  final glazeMap = {
    for (final g in glazes)
      if (g.id != null) g.id!: g,
  };
  final clayMap = {
    for (final c in clays)
      if (c.id != null) c.id!: c,
  };
  final firingMap = {
    for (final f in firings)
      if (f.id != null) f.id!: f,
  };
  final atmosphereMap = {
    for (final a in firingAtmospheres)
      if (a.id != null) a.id!: a,
  };
  final profileMap = {
    for (final f in firingProfiles)
      if (f.id != null) f.id!: f,
  };

  final pieceSheet = excel['テストピース'];
  pieceSheet.appendRow([
    for (final h in [
      '番号',
      '釉薬',
      '追加釉薬',
      '素地土',
      '焼成日',
      '窯',
      '焼成雰囲気',
      '焼成プロファイル',
      '評価',
      '備考',
      '登録日',
      '画像のファイル名',
      '調合',
    ])
      _text(h),
  ]);
  for (final piece in testPieces) {
    final resolved = resolveFiring(
      piece,
      firingMap: firingMap,
      atmosphereMap: atmosphereMap,
      profileMap: profileMap,
    );
    final missing = resolved.firingMissing;
    final firedOn = resolved.firedOn;
    pieceSheet.appendRow([
      _textOrNull(piece.label),
      _text(glazeDisplayName(piece, glazeMap)),
      _textOrNull(
        piece.additionalGlazeIds
            .map((id) => additionalGlazeDisplayName(piece, id, glazeMap))
            .join('、'),
      ),
      _text(clayDisplayName(piece, clayMap)),
      _textOrNull(firedOn == null ? null : formatDate(firedOn)),
      _textOrNull(resolved.kilnName),
      _textOrNull(missing ? '不明' : resolved.atmosphereName),
      _textOrNull(missing ? '不明' : resolved.profileName),
      piece.rating == null ? null : IntCellValue(piece.rating!),
      _textOrNull(piece.note),
      _text(formatDate(piece.createdAt.toDate())),
      _textOrNull(imageFileNames[piece.id]),
      _textOrNull(_formatPieceRecipe(piece)),
    ]);
  }

  // --- 原料 ---
  final componentNames = <String>[];
  for (final m in materials) {
    for (final name in m.components.keys) {
      if (!componentNames.contains(name)) componentNames.add(name);
    }
  }
  final materialSheet = excel['原料'];
  materialSheet.appendRow([
    _text('名前'),
    _text('カテゴリ'),
    for (final c in componentNames) _text(c),
  ]);
  for (final m in materials) {
    materialSheet.appendRow([
      _text(m.name),
      _text(m.category.displayName),
      for (final c in componentNames)
        m.components[c] == null ? null : _number(m.components[c]!),
    ]);
  }

  // --- 焼成回 ---
  final firingSheet = excel['焼成回'];
  firingSheet.appendRow([
    for (final h in ['焼成日', '窯', '焼成雰囲気', '焼成プロファイル', '最高温度', 'コーン', '所感'])
      _text(h),
  ]);
  for (final f in firings) {
    firingSheet.appendRow([
      _text(formatDate(f.firedOn.toDate())),
      _textOrNull(f.kilnName),
      _textOrNull(
        atmosphereMap[f.firingAtmosphereId]?.name ?? f.atmosphereName,
      ),
      _textOrNull(profileMap[f.firingProfileId]?.name ?? f.profile?.name),
      f.peakTemp == null ? null : IntCellValue(f.peakTemp!),
      _textOrNull(f.cone),
      _textOrNull(f.note),
    ]);
  }

  return Uint8List.fromList(excel.save()!);
}

/// 書き出しの進行
class ExportProgress {
  final String message; // 例: '写真を取得しています (12/87)'
  const ExportProgress(this.message);
}

/// 書き出しの結果
class ExportResult {
  final File zipFile;
  final int testPieceCount;

  /// 取得できなかった写真のテストピース ID
  final List<String> missingImageIds;

  const ExportResult({
    required this.zipFile,
    required this.testPieceCount,
    required this.missingImageIds,
  });

  int get missingImageCount => missingImageIds.length;
}

/// 全データを ZIP に書き出す。
class DataExporter {
  DataExporter({
    required FirestoreService firestoreService,
    required UploadQueue uploadQueue,
    http.Client? httpClient,
    FirebaseStorage? storage,
  }) : _firestore = firestoreService,
       _uploadQueue = uploadQueue,
       _http = httpClient,
       _storage = storage;

  final FirestoreService _firestore;
  final UploadQueue _uploadQueue;
  final http.Client? _http;
  final FirebaseStorage? _storage;

  static const _requestTimeout = Duration(seconds: 60);

  /// getData の上限 (既定の 10MB だと原寸の写真が取得できない)
  static const _maxStorageBytes = 200 * 1024 * 1024;

  /// [workDir] の下に ZIP を作って返す。
  /// ZIP は `workDir/glaze_manager_export_yyyyMMdd_HHmm.zip`。
  Future<ExportResult> export({
    required Directory workDir,
    void Function(ExportProgress)? onProgress,
    DateTime? now,
  }) async {
    final exportedAt = now ?? DateTime.now();
    onProgress?.call(const ExportProgress('データを取得しています'));

    final materials = await _firestore.getMaterialsOnce();
    final glazes = await _firestore.getGlazesOnce();
    final clays = await _firestore.getClaysOnce();
    final firingProfiles = await _firestore.getFiringProfilesOnce();
    final firingAtmospheres = await _firestore.getFiringAtmospheresOnce();
    final firings = await _firestore.getFiringsOnce();
    final tags = await _firestore.getTagsOnce();
    final testPieces = await _firestore.getTestPiecesOnce();

    final contentDir = Directory(p.join(workDir.path, 'content'));
    final imagesDir = Directory(p.join(contentDir.path, 'images'));
    await imagesDir.create(recursive: true);

    // --- 写真 ---
    final pending = _uploadQueue.pending;
    final withPhoto = [
      for (final piece in testPieces)
        if (piece.id != null &&
            (pending.containsKey(piece.id) || !isAwaitingPhoto(piece)))
          piece,
    ];
    final imageFileNames = <String, String>{};
    final missingImageIds = <String>[];
    final client = _http ?? http.Client();
    try {
      for (var i = 0; i < withPhoto.length; i++) {
        final piece = withPhoto[i];
        onProgress?.call(
          ExportProgress('写真を取得しています (${i + 1}/${withPhoto.length})'),
        );
        final id = piece.id!;
        final job = pending[id];
        final extension = _extensionOf(job?.localPath ?? piece.imagePath);
        final fileName = '$id$extension';
        final target = File(p.join(imagesDir.path, fileName));
        final ok = await _fetchImage(
          piece: piece,
          localPath: job?.localPath,
          target: target,
          client: client,
        );
        if (ok) {
          imageFileNames[id] = fileName;
        } else {
          missingImageIds.add(id);
        }
      }
    } finally {
      if (_http == null) client.close();
    }

    // --- data.json / xlsx / missing_images.txt ---
    onProgress?.call(const ExportProgress('ファイルを作成しています'));
    final json = buildExportJson(
      exportedAt: exportedAt,
      materials: materials,
      glazes: glazes,
      clays: clays,
      firingProfiles: firingProfiles,
      firingAtmospheres: firingAtmospheres,
      firings: firings,
      tags: tags,
      testPieces: testPieces,
      missingImages: missingImageIds,
    );
    await File(
      p.join(contentDir.path, 'data.json'),
    ).writeAsString(const JsonEncoder.withIndent('  ').convert(json));
    await File(p.join(contentDir.path, 'glaze_manager.xlsx')).writeAsBytes(
      buildExportWorkbook(
        materials: materials,
        glazes: glazes,
        clays: clays,
        firingProfiles: firingProfiles,
        firingAtmospheres: firingAtmospheres,
        firings: firings,
        testPieces: testPieces,
        imageFileNames: imageFileNames,
      ),
    );
    if (missingImageIds.isNotEmpty) {
      await File(
        p.join(contentDir.path, 'missing_images.txt'),
      ).writeAsString('${missingImageIds.join('\n')}\n');
    }

    // --- ZIP ---
    // 出力先が圧縮するディレクトリの中にあると archive は FormatException を
    // 投げるので、content の隣 (workDir の直下) に出す。
    onProgress?.call(const ExportProgress('ZIP を作成しています'));
    final zipPath = p.join(
      workDir.path,
      'glaze_manager_export_${_stamp(exportedAt)}.zip',
    );
    await ZipFileEncoder().zipDirectoryAsync(contentDir, filename: zipPath);

    return ExportResult(
      zipFile: File(zipPath),
      testPieceCount: testPieces.length,
      missingImageIds: missingImageIds,
    );
  }

  /// 端末内の画像 → imageUrl → imagePath の順に取得して [target] に書く。
  Future<bool> _fetchImage({
    required TestPiece piece,
    required String? localPath,
    required File target,
    required http.Client client,
  }) async {
    if (localPath != null) {
      try {
        final local = File(localPath);
        if (await local.exists()) {
          await local.copy(target.path);
          return true;
        }
      } catch (e) {
        debugPrint('Export: failed to copy pending image $localPath: $e');
      }
    }

    final url = piece.imageUrl;
    if (url != null && url.isNotEmpty) {
      try {
        final response = await client
            .get(Uri.parse(url))
            .timeout(_requestTimeout);
        if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
          await target.writeAsBytes(response.bodyBytes);
          return true;
        }
      } catch (e) {
        debugPrint('Export: failed to download ${piece.id}: $e');
      }
    }

    final path = piece.imagePath;
    if (path != null && path.isNotEmpty) {
      try {
        final storage = _storage ?? FirebaseStorage.instance;
        final bytes = await storage
            .ref(path)
            .getData(_maxStorageBytes)
            .timeout(_requestTimeout);
        if (bytes != null && bytes.isNotEmpty) {
          await target.writeAsBytes(bytes);
          return true;
        }
      } catch (e) {
        debugPrint('Export: failed to read storage $path: $e');
      }
    }
    return false;
  }

  static String _extensionOf(String? path) {
    if (path == null) return '.jpg';
    final ext = p.extension(path).toLowerCase();
    return RegExp(r'^\.[a-z0-9]{1,5}$').hasMatch(ext) ? ext : '.jpg';
  }

  static String _stamp(DateTime t) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${t.year}${two(t.month)}${two(t.day)}_${two(t.hour)}${two(t.minute)}';
  }
}
