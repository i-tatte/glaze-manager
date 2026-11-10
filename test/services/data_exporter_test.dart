import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive_io.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glaze_manager/models/clay.dart';
import 'package:glaze_manager/models/firing.dart';
import 'package:glaze_manager/models/glaze.dart';
import 'package:glaze_manager/models/material.dart';
import 'package:glaze_manager/models/test_piece.dart';
import 'package:glaze_manager/services/data_exporter.dart';
import 'package:glaze_manager/services/glaze_import_service.dart';
import 'package:glaze_manager/services/pending_upload_store.dart';
import 'package:glaze_manager/services/upload_queue.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mockito/mockito.dart';
import 'package:path/path.dart' as p;

import '../screens/main_tab_screen_test.mocks.dart';

Material mat(String id, String name, MaterialCategory category, int order) =>
    Material(
      id: id,
      name: name,
      order: order,
      components: {'SiO2': 50.5},
      category: category,
    );

void main() {
  group('toJsonSafe', () {
    test('Timestamp を ISO 8601 (UTC) の文字列にし、入れ子の Map と List も変える', () {
      final ts = Timestamp.fromDate(DateTime.utc(2026, 11, 10, 6, 30));
      final result = toJsonSafe({
        'a': ts,
        'nested': {
          'list': [
            ts,
            {'deep': ts},
          ],
        },
        'n': 3,
        'd': 1.5,
        's': 'x',
        'z': null,
      });
      expect(result, {
        'a': '2026-11-10T06:30:00.000Z',
        'nested': {
          'list': [
            '2026-11-10T06:30:00.000Z',
            {'deep': '2026-11-10T06:30:00.000Z'},
          ],
        },
        'n': 3,
        'd': 1.5,
        's': 'x',
        'z': null,
      });
      expect(() => jsonEncode(result), returnsNormally);
    });
  });

  group('buildExportWorkbook', () {
    final materials = [
      mat('m1', '長石', MaterialCategory.base, 0),
      mat('m2', '土灰', MaterialCategory.base, 1),
      mat('m3', '弁柄', MaterialCategory.pigment, 2),
      mat('m4', '顔料1', MaterialCategory.pigment, 3),
      mat('m5', '未使用', MaterialCategory.base, 4),
    ];
    final glazes = [
      Glaze(
        id: 'g1',
        name: '透明釉',
        registeredName: 'T-1',
        recipe: {'m1': 70, 'm2': 12.5, 'm3': 8, 'm4': 2},
        tags: ['透明', 'つや'],
        description: 'よく溶ける',
        createdAt: Timestamp.now(),
      ),
      Glaze(
        id: 'g2',
        name: '長石釉',
        recipe: {'m1': 100},
        tags: [],
        createdAt: Timestamp.now(),
      ),
    ];

    Uint8List build() => buildExportWorkbook(
      materials: materials,
      glazes: glazes,
      clays: [Clay(id: 'c1', name: '信楽', order: 0)],
      firingProfiles: [],
      firingAtmospheres: [],
      firings: [],
      testPieces: [],
    );

    test('先頭のシートが「釉薬」で、既存の取り込みで同じ釉薬名と調合が得られる', () {
      final bytes = build();
      final excel = Excel.decodeBytes(bytes);
      expect(excel.tables.keys.first, '釉薬');
      expect(excel.tables.keys, containsAll(['テストピース', '原料', '焼成回']));
      expect(excel.tables.keys, isNot(contains('Sheet1')));

      final parsed = GlazeImporter.parseExcelBytes(
        bytes,
        existingGlazeNames: {},
      );
      expect(parsed.materialNames, ['長石', '土灰']);
      expect(parsed.rows.map((r) => r.name), ['透明釉', '長石釉']);
      final first = parsed.rows[0];
      expect(first.registeredName, 'T-1');
      expect(first.description, 'よく溶ける');
      expect(first.amountsByMaterialName, {'長石': 70, '土灰': 12.5});
      expect(first.amountsByPigmentName, {'弁柄': 8, '顔料1': 2});
      expect(parsed.rows[1].amountsByMaterialName, {'長石': 100});
      expect(parsed.rows[1].amountsByPigmentName, isEmpty);
    });

    test('顔料の列は「名前 量」をカンマで区切った書式になる', () {
      expect(
        formatPigmentCell([
          const MapEntry('弁柄', 8.0),
          const MapEntry('顔料1', 2.5),
        ]),
        '弁柄 8, 顔料1 2.5',
      );
      final excel = Excel.decodeBytes(build());
      final sheet = excel.tables['釉薬']!;
      final header = sheet.row(0).map((c) => c?.value.toString()).toList();
      expect(header, ['釉薬名', '登録名', '長石', '土灰', '顔料', 'タグ', '備考']);
      expect(sheet.row(1)[4]!.value.toString(), '弁柄 8, 顔料1 2');
      expect(sheet.row(1)[5]!.value.toString(), '透明、つや');
    });
  });

  group('DataExporter.export', () {
    late Directory tempDir;
    late MockFirestoreService firestore;
    late UploadQueue queue;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('data_exporter_test');
      firestore = MockFirestoreService();
      queue = UploadQueue(
        store: PendingUploadStore(baseDirectory: () async => tempDir),
        currentUid: () => 'me',
        checkDocument: (_) async => UploadDocState.ready,
        upload: (job, bytes) async {},
      );
      when(
        firestore.getMaterialsOnce(),
      ).thenAnswer((_) async => [mat('m1', '長石', MaterialCategory.base, 0)]);
      when(firestore.getGlazesOnce()).thenAnswer(
        (_) async => [
          Glaze(
            id: 'g1',
            name: '透明釉',
            recipe: {'m1': 100},
            tags: [],
            createdAt: Timestamp.now(),
          ),
        ],
      );
      when(
        firestore.getClaysOnce(),
      ).thenAnswer((_) async => [Clay(id: 'c1', name: '信楽', order: 0)]);
      when(firestore.getFiringProfilesOnce()).thenAnswer((_) async => []);
      when(firestore.getFiringAtmospheresOnce()).thenAnswer((_) async => []);
      when(firestore.getFiringsOnce()).thenAnswer((_) async => <Firing>[]);
      when(firestore.getTagsOnce()).thenAnswer((_) async => ['透明']);
      when(firestore.getTestPiecesOnce()).thenAnswer(
        (_) async => [
          TestPiece(
            id: 'ok',
            glazeId: 'g1',
            clayId: 'c1',
            imageUrl: 'https://example.com/ok.jpg',
            createdAt: Timestamp.now(),
          ),
          TestPiece(
            id: 'ng',
            glazeId: 'g1',
            clayId: 'c1',
            imageUrl: 'https://example.com/ng.jpg',
            createdAt: Timestamp.now(),
          ),
          TestPiece(
            id: 'nophoto',
            glazeId: 'g1',
            clayId: 'c1',
            createdAt: Timestamp.now(),
          ),
        ],
      );
    });

    tearDown(() async {
      if (await tempDir.exists()) await tempDir.delete(recursive: true);
    });

    test('取得できなかった写真は missingImages に入り、ZIP の中身が揃う', () async {
      final client = MockClient((request) async {
        if (request.url.path.endsWith('ok.jpg')) {
          return http.Response.bytes([1, 2, 3], 200);
        }
        return http.Response('not found', 404);
      });
      final exporter = DataExporter(
        firestoreService: firestore,
        uploadQueue: queue,
        httpClient: client,
      );
      final workDir = Directory(p.join(tempDir.path, 'work'));
      await workDir.create();
      final messages = <String>[];

      final result = await exporter.export(
        workDir: workDir,
        now: DateTime(2026, 11, 10, 15, 30),
        onProgress: (e) => messages.add(e.message),
      );

      expect(result.missingImageIds, ['ng']);
      expect(result.missingImageCount, 1);
      expect(result.testPieceCount, 3);
      expect(messages, contains('写真を取得しています (2/2)'));
      expect(
        p.basename(result.zipFile.path),
        'glaze_manager_export_20261110_1530.zip',
      );
      expect(p.dirname(result.zipFile.path), workDir.path);

      final archive = ZipDecoder().decodeBytes(
        await result.zipFile.readAsBytes(),
      );
      final names = archive.files.where((f) => f.isFile).map((f) => f.name);
      expect(names.toSet(), {
        'data.json',
        'glaze_manager.xlsx',
        'images/ok.jpg',
        'missing_images.txt',
      });

      final dataFile = archive.files.firstWhere((f) => f.name == 'data.json');
      final data =
          jsonDecode(utf8.decode(dataFile.content as List<int>))
              as Map<String, dynamic>;
      expect(data['formatVersion'], 1);
      expect(data['missingImages'], ['ng']);
      final collections = data['collections'] as Map<String, dynamic>;
      expect(collections.keys, [
        'materials',
        'glazes',
        'clays',
        'firingProfiles',
        'firingAtmospheres',
        'firings',
        'tags',
        'testPieces',
      ]);
      expect((collections['testPieces'] as List).length, 3);
      expect((collections['glazes'] as List).first['id'], 'g1');
      expect(collections['tags'], ['透明']);
    });

    test('取得できない写真がなければ missing_images.txt を作らない', () async {
      final client = MockClient((_) async => http.Response.bytes([1], 200));
      final exporter = DataExporter(
        firestoreService: firestore,
        uploadQueue: queue,
        httpClient: client,
      );
      final workDir = Directory(p.join(tempDir.path, 'work2'));
      await workDir.create();
      final result = await exporter.export(workDir: workDir);
      expect(result.missingImageIds, isEmpty);
      final archive = ZipDecoder().decodeBytes(
        await result.zipFile.readAsBytes(),
      );
      expect(archive.files.any((f) => f.name == 'missing_images.txt'), isFalse);
    });
  });
}
