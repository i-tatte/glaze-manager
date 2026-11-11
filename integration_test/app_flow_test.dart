// アプリ本体を実機 (Windows など) で起動し、試験ノート化で足した流れを通しで
// 確かめる。Firebase エミュレータ (auth, firestore, storage, functions) を
// 起動してから実行する。実プロジェクトには一切つながない。
//
//   flutter test integration_test/app_flow_test.dart -d windows
//
// GM_MODE で確かめる内容を切り替える。
//   online        (既定) 写しの埋め込み、連続登録、写真の送信と書き戻し、
//                 釉薬の編集と複製、焼成回、グループ表示、比較、書き出し
//   offline_save  Firestore と Storage に届かない状態で、写真つきで登録して終了する
//                 (GM_FIRESTORE_PORT と GM_STORAGE_PORT に、誰も待ち受けて
//                 いないポートを渡す)
//   after_restart offline_save のあとで起動し直し、記録と写真がサーバーに届く
//                 ことを確かめる
//
// ignore_for_file: depend_on_referenced_packages
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dropdown_search/dropdown_search.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glaze_manager/models/clay.dart';
import 'package:glaze_manager/models/glaze.dart';
import 'package:glaze_manager/providers/data_providers.dart';
import 'package:glaze_manager/services/data_exporter.dart';
import 'package:glaze_manager/services/glaze_import_service.dart';
import 'package:glaze_manager/widgets/common/app_network_image.dart';
import 'package:glaze_manager/widgets/test_piece_card.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/app_driver.dart';
import 'support/emulator_env.dart';

const _mode = String.fromEnvironment('GM_MODE', defaultValue: 'online');

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('app flow ($_mode)', (tester) async {
    // 実アプリの設定ファイルに触れない
    SharedPreferences.setMockInitialValues({});
    await initFirebaseForEmulators();
    final report = Report('app_flow_$_mode');
    try {
      switch (_mode) {
        case 'online':
          await _online(tester, report);
        case 'offline_save':
          await _offlineSave(tester, report);
        case 'after_restart':
          await _afterRestart(tester, report);
        default:
          fail('unknown GM_MODE: $_mode');
      }
      report.add('result', 'ok');
    } catch (_) {
      // 落ちた時点の画面を残す
      try {
        await screenshot(tester, 'failure');
      } catch (_) {}
      rethrow;
    } finally {
      await report.flush();
    }
  }, timeout: const Timeout(Duration(minutes: 20)));
}

DocumentReference<Map<String, dynamic>> _userDoc(String uid) =>
    FirebaseFirestore.instance.collection('users').doc(uid);

/// 原料・釉薬・素地土を書く。待たずに返すので、届かない状態でも使える。
List<Future<void>> _seedBaseData(String uid) {
  final user = _userDoc(uid);
  final now = Timestamp.now();
  return [
    user.collection('materials').doc('m1').set({
      'name': '長石',
      'order': 0,
      'components': <String, dynamic>{},
      'category': 'base',
    }),
    user.collection('materials').doc('m2').set({
      'name': '藁灰',
      'order': 1,
      'components': <String, dynamic>{},
      'category': 'base',
    }),
    user.collection('materials').doc('m3').set({
      'name': '酸化鉄',
      'order': 2,
      'components': <String, dynamic>{},
      'category': 'pigment',
    }),
    user.collection('glazes').doc('g1').set({
      'name': '青磁',
      'recipe': {'m1': 60, 'm2': 40, 'm3': 1.5},
      'tags': <String>[],
      'createdAt': now,
    }),
    user.collection('glazes').doc('g2').set({
      'name': '白萩',
      'recipe': {'m1': 30, 'm2': 70},
      'tags': <String>[],
      'createdAt': now,
    }),
    user.collection('clays').doc('c1').set({'name': '信楽白', 'order': 0}),
  ];
}

String _testPiecePath(String uid, String id) => 'users/$uid/test_pieces/$id';

Future<Map<String, dynamic>?> _serverPiece(String uid, String id) =>
    adminGetDoc(_testPiecePath(uid, id));

/// 一覧に出ているカードのテストピース ID
Set<String> _visibleCardIds() => {
  for (final w in find.byType(TestPieceCard).evaluate().map((e) => e.widget))
    (w as TestPieceCard).testPiece.id!,
};

Future<Directory> _pendingRoot() async => Directory(
  p.join((await getApplicationSupportDirectory()).path, 'pending_uploads'),
);

Future<void> _online(WidgetTester tester, Report report) async {
  final user = await signUpFreshUser();
  final uid = user.uid;
  report.add('uid', uid);
  await Future.wait(_seedBaseData(uid));

  // --- 試験ノート化より前からある記録 (写しを持たない) を、サーバーに直接置く ---
  final base = DateTime.now().toUtc();
  await adminSetDoc(_testPiecePath(uid, 'legacy-1'), {
    'glazeId': 'g1',
    'additionalGlazeIds': <String>[],
    'relatedGlazeIds': ['g1'],
    'clayId': 'c1',
    'createdAt': base.subtract(const Duration(days: 1)),
    'note': '以前の記録',
  });
  // 主たる釉薬が削除されている (写しを埋められない)
  await adminSetDoc(_testPiecePath(uid, 'legacy-2'), {
    'glazeId': 'deleted-glaze',
    'additionalGlazeIds': <String>[],
    'relatedGlazeIds': ['deleted-glaze'],
    'clayId': 'c1',
    'createdAt': base.subtract(const Duration(days: 2)),
  });
  // すでに写しを持っている (上書きしてはならない)
  await adminSetDoc(_testPiecePath(uid, 'legacy-3'), {
    'glazeId': 'g1',
    'additionalGlazeIds': <String>[],
    'relatedGlazeIds': ['g1'],
    'clayId': 'c1',
    'createdAt': base.subtract(const Duration(days: 3)),
    'snapshot': {
      'source': 'saved',
      'takenAt': base.subtract(const Duration(days: 3)),
      'clayName': '信楽白',
      'glaze': {
        'glazeId': 'g1',
        'name': '青磁',
        'registeredName': null,
        'lines': [
          {'materialId': 'm1', 'name': '長石', 'category': 'base', 'amount': 50},
          {'materialId': 'm2', 'name': '藁灰', 'category': 'base', 'amount': 50},
        ],
      },
      'additionalGlazes': <Object>[],
    },
  });

  final picker = FakeImagePicker();
  ImagePickerPlatform.instance = picker;

  // --- 起動 ---
  final storage = await pumpGlazeManager(tester);
  await waitFor(tester, find.text('テストピース一覧'));
  await pumpUntil(
    tester,
    () => _visibleCardIds().containsAll({'legacy-1', 'legacy-2', 'legacy-3'}),
    reason: '既存の 3 枚が一覧に出る',
  );

  // --- 起動時の写しの埋め込み ---
  final backfilled = await waitUntil(
    () async => (await _serverPiece(uid, 'legacy-1'))?['snapshot'] != null,
  );
  report.add('backfill_ms', backfilled?.inMilliseconds);
  expect(backfilled, isNotNull, reason: '写しのない記録に写しが埋まる');
  final legacy1 = (await _serverPiece(uid, 'legacy-1'))!;
  final legacy1Snapshot = legacy1['snapshot'] as Map;
  expect(legacy1Snapshot['source'], 'backfilled');
  expect(legacy1Snapshot['clayName'], '信楽白');
  expect([
    for (final l in (legacy1Snapshot['glaze'] as Map)['lines'] as List)
      '${(l as Map)['name']}:${l['amount']}',
  ], unorderedEquals(['長石:60.0', '藁灰:40.0', '酸化鉄:1.5']));
  expect(legacy1['note'], '以前の記録', reason: '埋め込みはほかの欄に触れない');
  expect(
    (await _serverPiece(uid, 'legacy-2'))!.containsKey('snapshot'),
    isFalse,
  );
  final legacy3Snapshot =
      (await _serverPiece(uid, 'legacy-3'))!['snapshot'] as Map;
  expect(legacy3Snapshot['source'], 'saved', reason: '既存の写しは上書きしない');
  expect(
    (((legacy3Snapshot['glaze'] as Map)['lines'] as List).first
        as Map)['amount'],
    50,
  );
  await screenshot(tester, '01_list_after_backfill');

  // 詳細画面に調合と注記が出る
  await tester.tap(cardOf('legacy-1'));
  await waitFor(tester, find.text('テストピース詳細'));
  await waitFor(tester, find.text('移行時に、その時点の釉薬の調合から埋めた記録です。'));
  expect(find.text('長石'), findsWidgets);
  await screenshot(tester, '02_detail_backfilled');
  await goBack(tester);
  await waitFor(tester, find.text('テストピース一覧'));
  await settle(tester);

  // --- 複数の写真を選んで連続登録 ---
  picker.queue.addAll(
    await makeTestPhotos([(200, 40, 40), (40, 180, 60), (40, 60, 200)]),
  );
  await tester.tap(find.byTooltip('テストピースを追加'));
  await waitFor(tester, find.text('テストピースの新規作成'));
  await settle(tester);
  await chooseFromDropdown(
    tester,
    find.byType(DropdownSearch<Glaze>).first,
    '青磁',
  );
  await chooseFromDropdown(tester, find.byType(DropdownSearch<Clay>), '信楽白');
  await tester.enterText(
    find.widgetWithText(TextFormField, '番号'),
    '20261111-01',
  );
  await settle(tester, const Duration(milliseconds: 200));
  await tapVisible(tester, find.byIcon(Icons.star_border).at(3));
  await tapVisible(tester, find.text('複数の写真を選んで連続登録'));
  await confirmCrop(tester);
  await scrollFormTo(tester, find.text('保存して次を登録（残り 2 枚）'));
  await screenshot(tester, '03_edit_first_of_three');

  final saveTimes = <DateTime>[];
  Future<void> saveAndContinue(String buttonText) async {
    // 押すと同時に送信が始まりうるので、押す前の時刻を取る
    saveTimes.add(DateTime.now());
    await tapVisible(tester, find.text(buttonText));
  }

  await saveAndContinue('保存して次を登録（残り 2 枚）');
  // 次の画面が開き、2 枚目の切り抜きが自動で始まる
  await confirmCrop(tester);
  // フォームの下にある連続登録のボタンは、動かすまで組み立てられない。
  // 上にある番号を先に確かめてから動かす
  expect(
    tester
        .widget<TextFormField>(find.widgetWithText(TextFormField, '番号'))
        .controller!
        .text,
    '20261111-02',
    reason: '番号の末尾が 1 つ進む',
  );
  expect(find.text('青磁'), findsWidgets, reason: '釉薬を引き継ぐ');
  expect(find.text('信楽白'), findsWidgets, reason: '素地土を引き継ぐ');
  await scrollFormTo(tester, find.text('保存して次を登録（残り 1 枚）'));
  await screenshot(tester, '04_edit_second_of_three');
  await saveAndContinue('保存して次を登録（残り 1 枚）');
  await confirmCrop(tester);
  expect(
    tester
        .widget<TextFormField>(find.widgetWithText(TextFormField, '番号'))
        .controller!
        .text,
    '20261111-03',
  );
  await scrollFormTo(tester, find.text('保存して次を登録'));
  // 最後の 1 枚は AppBar の保存で閉じる
  saveTimes.add(DateTime.now());
  await tester.tap(find.byTooltip('保存'));
  await waitFor(tester, find.text('テストピース一覧'));
  await settle(tester);

  // 一覧に 6 枚。新しい 3 枚の ID を得る
  await pumpUntil(
    tester,
    () => _visibleCardIds().length == 6,
    reason: '登録した 3 枚が一覧に出る',
  );
  final newIds = _visibleCardIds()
      .where((id) => !id.startsWith('legacy-'))
      .toList();
  expect(newIds, hasLength(3));
  await screenshot(tester, '05_list_just_after_saving');

  // --- 写真の送信と、Cloud Functions の書き戻し ---
  final uploaded = await waitUntil(
    () async => storage.uploads.length >= 3,
    timeout: const Duration(seconds: 90),
  );
  report.add('uploads_allSent_ms_afterLastSave', uploaded?.inMilliseconds);
  expect(uploaded, isNotNull, reason: '3 枚の写真が送られる');
  // 保存から送信までの時間 (保存の順と送信の順は同じ)
  final uploadTimes = storage.uploads.values.toList()..sort();
  final delays = [
    for (var i = 0; i < 3; i++)
      uploadTimes[i].difference(saveTimes[i]).inMilliseconds,
  ];
  report.add('saveToUpload_ms', delays);
  expect(
    delays.every((ms) => ms < 2000),
    isTrue,
    reason: '文書がサーバーに届いたら、同期待ちの試し直しを待たずにすぐ送る: $delays',
  );

  final labels = <String, String>{};
  for (final id in newIds) {
    final done = await waitUntil(
      () async => (await _serverPiece(uid, id))?['thumbnailUrl'] != null,
      timeout: const Duration(seconds: 90),
    );
    expect(done, isNotNull, reason: 'Functions がサムネイルの URL を書き戻す ($id)');
    final piece = (await _serverPiece(uid, id))!;
    labels[id] = piece['label'] as String;
    expect(piece['glazeId'], 'g1');
    expect(piece['clayId'], 'c1');
    expect((piece['snapshot'] as Map)['source'], 'saved');
    expect(piece['colorData'], isNotEmpty, reason: '色の解析結果が書かれる');
    expect(
      await adminListObjects('users/$uid/test_pieces/images/$id/'),
      hasLength(1),
    );
    expect(
      await adminListObjects('users/$uid/test_pieces/thumbnails/$id/'),
      hasLength(1),
    );
  }
  expect(
    labels.values,
    unorderedEquals(['20261111-01', '20261111-02', '20261111-03']),
  );
  final firstId = labels.entries.firstWhere((e) => e.value.endsWith('01')).key;
  final secondId = labels.entries.firstWhere((e) => e.value.endsWith('02')).key;
  expect((await _serverPiece(uid, firstId))!['rating'], 4);

  // 送り終えたら、待ちも端末内の写しも残らない
  final queue = containerOf(tester).read(uploadQueueProvider);
  await pumpUntil(tester, () => queue.pending.isEmpty, reason: 'アップロード待ちが空になる');
  for (final id in newIds) {
    expect(
      await Directory(p.join((await _pendingRoot()).path, id)).exists(),
      isFalse,
    );
  }
  // 一覧の表示が、端末内の画像からネットワークの画像に切り替わる
  await pumpUntil(
    tester,
    () =>
        !exists(find.byIcon(Icons.cloud_upload_outlined)) &&
        find
                .descendant(
                  of: cardOf(firstId),
                  matching: find.byType(AppNetworkImage),
                )
                .evaluate()
                .length ==
            1,
    reason: '送信待ちの印が消える',
  );
  await screenshot(tester, '06_list_after_upload');

  // --- 既存のテストピースの写真を差し替える ---
  picker.queue.addAll(await makeTestPhotos([(220, 200, 40)]));
  final beforeReplace = (await _serverPiece(uid, secondId))!;
  await tester.tap(cardOf(secondId));
  await waitFor(tester, find.text('テストピース詳細'));
  await settle(tester);
  await tester.tap(find.byTooltip('編集'));
  await waitFor(tester, find.text('テストピースの編集'));
  await settle(tester);
  await scrollImagePaneTo(tester, find.text('写真を選択'));
  await tapVisible(tester, find.text('写真を選択'));
  await confirmCrop(tester);
  final replaceAt = DateTime.now();
  await tester.tap(find.byTooltip('保存'));
  await waitFor(tester, find.text('テストピース詳細'));
  final replaced = await waitUntil(() async {
    final piece = await _serverPiece(uid, secondId);
    return piece != null &&
        piece['imagePath'] != beforeReplace['imagePath'] &&
        piece['imageUrl'] != beforeReplace['imageUrl'];
  }, timeout: const Duration(seconds: 90));
  report.add('replace_writeBack_ms', replaced?.inMilliseconds);
  expect(replaced, isNotNull, reason: '差し替えた写真の URL が書き戻される');
  final afterReplace = (await _serverPiece(uid, secondId))!;
  report.add(
    'replace_saveToUpload_ms',
    storage.uploads[afterReplace['imagePath']]!
        .difference(replaceAt)
        .inMilliseconds,
  );
  expect(
    Uri.decodeComponent(afterReplace['imageUrl'] as String),
    contains(afterReplace['imagePath'] as String),
  );
  final cleaned = await waitUntil(
    () async =>
        (await adminListObjects(
          'users/$uid/test_pieces/images/$secondId/',
        )).length ==
        1,
    timeout: const Duration(seconds: 60),
  );
  expect(cleaned, isNotNull, reason: '古い写真は Functions が片づける');
  expect(await adminListObjects('users/$uid/test_pieces/images/$secondId/'), [
    afterReplace['imagePath'],
  ]);
  expect(
    await adminListObjects('users/$uid/test_pieces/thumbnails/$secondId/'),
    hasLength(1),
  );
  // 差し替えは変更分だけの更新なので、ほかの欄は残る
  expect(afterReplace['label'], '20261111-02');
  expect((afterReplace['snapshot'] as Map)['source'], 'saved');
  await goBack(tester);
  await waitFor(tester, find.text('テストピース一覧'));
  await settle(tester);

  await _glazeFlows(tester, report, uid, firstId);
  await _firingAndGrouping(tester, report, uid, firstId, secondId);
  await _export(tester, report, uid);
}

/// 釉薬の調合を変えたときの確認、複製と派生。
Future<void> _glazeFlows(
  WidgetTester tester,
  Report report,
  String uid,
  String pieceId,
) async {
  Future<void> openGlazeEdit() async {
    await tester.tap(find.text('釉薬').last);
    await waitFor(tester, find.text('釉薬一覧'));
    await settle(tester);
    await tester.tap(find.text('青磁').first);
    await waitFor(tester, find.byTooltip('複製して新規作成'));
    await settle(tester);
    await tester.tap(find.byTooltip('編集'));
    await waitFor(tester, find.text('釉薬の編集'));
    await settle(tester);
  }

  Future<void> backToTestPieces() async {
    await goBack(tester);
    await waitFor(tester, find.text('釉薬一覧'));
    await settle(tester);
    await tester.tap(find.text('テストピース').last);
    await waitFor(tester, find.text('テストピース一覧'));
    await settle(tester);
  }

  double serverAmount(Map<String, dynamic> piece) =>
      ((((piece['snapshot'] as Map)['glaze'] as Map)['lines'] as List)
                  .cast<Map>()
                  .firstWhere((l) => l['materialId'] == 'm1')['amount']
              as num)
          .toDouble();

  // --- 調合を変えて「記録はそのまま」 ---
  await openGlazeEdit();
  final amounts = find.widgetWithText(TextFormField, '配合量 (g)');
  final firstAmount = tester.widget<TextFormField>(amounts.first).controller!;
  report.add('glazeEdit_firstAmountBefore', firstAmount.text);
  await tester.enterText(amounts.first, '55');
  await settle(tester, const Duration(milliseconds: 200));
  await tester.tap(find.byTooltip('保存'));
  await waitFor(tester, find.text('テストピースの記録の扱い'));
  // 写しに青磁を持つのは、埋め込んだ 1 枚、もとから写しのある 1 枚、登録した 3 枚
  expect(find.textContaining('5 件あります'), findsOneWidget);
  await screenshot(tester, '07_glaze_edit_dialog');
  await tester.tap(find.text('記録はそのまま'));
  await waitFor(tester, find.byTooltip('複製して新規作成'));
  await settle(tester);
  final kept = await waitUntil(() async {
    final glaze = await adminGetDoc('users/$uid/glazes/g1');
    return (glaze!['recipe'] as Map).values.contains(55);
  });
  expect(kept, isNotNull, reason: '釉薬の調合は変わる');
  expect(
    serverAmount((await _serverPiece(uid, pieceId))!),
    isNot(55),
    reason: '記録済みの調合は変わらない',
  );
  await backToTestPieces();
  await tester.tap(cardOf(pieceId));
  await waitFor(tester, find.text('テストピース詳細'));
  await waitFor(tester, find.text('釉薬の現在の調合とは異なります。'));
  await screenshot(tester, '08_detail_recipe_differs');
  await goBack(tester);
  await waitFor(tester, find.text('テストピース一覧'));
  await settle(tester);

  // --- もう一度変えて「記録も直す」 ---
  await openGlazeEdit();
  await tester.enterText(
    find.widgetWithText(TextFormField, '配合量 (g)').first,
    '58',
  );
  await settle(tester, const Duration(milliseconds: 200));
  await tester.tap(find.byTooltip('保存'));
  await waitFor(tester, find.text('記録も直す'));
  await tester.tap(find.text('記録も直す'));
  await waitFor(tester, find.byTooltip('複製して新規作成'));
  await settle(tester);
  final corrected = await waitUntil(() async {
    final piece = await _serverPiece(uid, pieceId);
    return (piece!['snapshot'] as Map)['source'] == 'corrected';
  });
  expect(corrected, isNotNull, reason: '記録済みの写しが直る');
  for (final id in ['legacy-1', 'legacy-3', pieceId]) {
    final piece = (await _serverPiece(uid, id))!;
    expect((piece['snapshot'] as Map)['source'], 'corrected', reason: id);
    final lines = ((piece['snapshot'] as Map)['glaze'] as Map)['lines'] as List;
    expect(
      lines.cast<Map>().map((l) => (l['amount'] as num).toDouble()),
      contains(58),
      reason: id,
    );
  }
  // 青磁を使っていない記録には触れない
  expect(
    (await _serverPiece(uid, 'legacy-2'))!.containsKey('snapshot'),
    isFalse,
  );

  // --- 複製して派生を作る ---
  await tester.tap(find.byTooltip('複製して新規作成'));
  await waitFor(tester, find.text('釉薬の複製'));
  await settle(tester);
  await tester.enterText(find.widgetWithText(TextFormField, '釉薬名'), '青磁 改');
  await tester.enterText(
    find.widgetWithText(TextFormField, '配合量 (g)').first,
    '70',
  );
  await settle(tester, const Duration(milliseconds: 200));
  await tester.tap(find.byTooltip('保存'));
  await waitFor(tester, find.byTooltip('複製して新規作成'));
  await waitFor(tester, find.text('派生した釉薬'));
  await settle(tester);
  await tapVisible(tester, find.text('青磁 改'));
  await waitFor(tester, find.text('派生元からの変更'));
  expect(find.text('派生元'), findsWidgets);
  await screenshot(tester, '09_glaze_derived');
  final glazeIds = await adminListDocIds('users/$uid/glazes');
  final derivedId = glazeIds.firstWhere((id) => id != 'g1' && id != 'g2');
  final derived = (await adminGetDoc('users/$uid/glazes/$derivedId'))!;
  expect(derived['name'], '青磁 改');
  expect(derived['parentGlazeId'], 'g1');
  expect((derived['parentSnapshot'] as Map)['name'], '青磁');
  expect(
    ((derived['parentSnapshot'] as Map)['lines'] as List).cast<Map>().map(
      (l) => (l['amount'] as num).toDouble(),
    ),
    contains(58),
    reason: '複製した時点の複製元の調合を持つ',
  );
  await goBack(tester);
  await waitFor(tester, find.byTooltip('複製して新規作成'));
  await settle(tester);
  await backToTestPieces();
}

/// 焼成回の作成、テストピースへの割り当て、グループ表示、比較。
Future<void> _firingAndGrouping(
  WidgetTester tester,
  Report report,
  String uid,
  String firstId,
  String secondId,
) async {
  // --- 焼成回を作る ---
  await tester.tap(find.byTooltip('焼成回'));
  await waitFor(tester, find.byTooltip('焼成回を追加'));
  await settle(tester);
  await tester.tap(find.byTooltip('焼成回を追加'));
  await waitFor(tester, find.text('焼成回の新規作成'));
  await settle(tester);
  await tester.enterText(find.widgetWithText(TextFormField, '窯 (任意)'), '電気窯');
  await tester.enterText(
    find.widgetWithText(TextFormField, '最高温度 (℃) (任意)'),
    '1230',
  );
  await settle(tester, const Duration(milliseconds: 200));
  await screenshot(tester, '10_firing_edit');
  await tester.tap(find.byTooltip('保存'));
  await waitFor(tester, find.byTooltip('焼成回を追加'));
  await waitFor(tester, find.textContaining('電気窯'));
  await settle(tester);
  final firingIds = await adminListDocIds('users/$uid/firings');
  expect(firingIds, hasLength(1));
  final firing = (await adminGetDoc('users/$uid/firings/${firingIds.single}'))!;
  expect(firing['kilnName'], '電気窯');
  expect(firing['peakTemp'], 1230);
  final firingLabel = tester
      .widget<Text>(find.textContaining('電気窯').first)
      .data!;
  report.add('firing_label', firingLabel);
  await goBack(tester);
  await waitFor(tester, find.text('テストピース一覧'));
  await settle(tester);

  // --- テストピースに焼成回を割り当てる ---
  await tester.tap(cardOf(firstId));
  await waitFor(tester, find.text('テストピース詳細'));
  await settle(tester);
  await tester.tap(find.byTooltip('編集'));
  await waitFor(tester, find.text('テストピースの編集'));
  await settle(tester);
  await tapVisible(tester, find.text('（なし）').first);
  await settle(tester);
  await tester.tap(find.text(firingLabel).last);
  await settle(tester);
  await screenshot(tester, '11_edit_with_firing');
  await tester.tap(find.byTooltip('保存'));
  await waitFor(tester, find.text('テストピース詳細'));
  final assigned = await waitUntil(
    () async =>
        (await _serverPiece(uid, firstId))!['firingId'] == firingIds.single,
  );
  expect(assigned, isNotNull, reason: '焼成回が保存される');
  final piece = (await _serverPiece(uid, firstId))!;
  expect(piece['thumbnailUrl'], isNotNull, reason: 'Functions が書いた値を消さない');
  expect(piece['imageUrl'], isNotNull);
  expect(piece['colorData'], isNotEmpty);
  await screenshot(tester, '12_detail_with_firing');
  await goBack(tester);
  await waitFor(tester, find.text('テストピース一覧'));
  await settle(tester);

  // --- グループ表示 ---
  Future<void> groupBy(String label) async {
    await tester.tap(find.byTooltip('グループ表示'));
    await settle(tester);
    // 開いたメニューの項目を押す (下の画面にも同じ文字がある)
    await tester.tap(
      find.ancestor(
        of: find.text(label),
        matching: find.byWidgetPredicate((w) => w is CheckedPopupMenuItem),
      ),
    );
    await settle(tester, const Duration(seconds: 1));
  }

  await groupBy('焼成回');
  expect(find.textContaining('電気窯'), findsWidgets);
  await screenshot(tester, '13_group_by_firing');
  await groupBy('評価');
  await screenshot(tester, '14_group_by_rating');
  await groupBy('なし');

  // --- 比較 ---
  await tester.longPress(cardOf(firstId));
  await settle(tester);
  await tester.tap(cardOf(secondId));
  await waitFor(tester, find.text('2 件選択'));
  await screenshot(tester, '15_selection');
  await tester.tap(find.byTooltip('比較'));
  await waitFor(tester, find.text('テストピースの比較'));
  await settle(tester, const Duration(seconds: 1));
  await screenshot(tester, '16_compare');
  await goBack(tester);
  await waitFor(tester, find.text('2 件選択'));
  await tester.tap(find.byTooltip('選択を解除'));
  await waitFor(tester, find.text('テストピース一覧'));
  await settle(tester);
}

/// 全データの書き出し。保存先を選ぶダイアログは自動で操作できないので、
/// 設定画面が呼ぶのと同じ書き出しの処理を、アプリの中で直接動かす。
Future<void> _export(WidgetTester tester, Report report, String uid) async {
  final container = containerOf(tester);
  final exporter = DataExporter(
    firestoreService: container.read(firestoreServiceProvider),
    uploadQueue: container.read(uploadQueueProvider),
    // Functions が書く URL は本番のホストを指す。エミュレータに読み替える
    httpClient: _EmulatorDownloadClient(),
  );
  final workDir = await Directory(
    p.join(
      (await getTemporaryDirectory()).path,
      'gm_it_export_${DateTime.now().microsecondsSinceEpoch}',
    ),
  ).create(recursive: true);
  try {
    final result = await exporter.export(workDir: workDir);
    report.add('export_testPieces', result.testPieceCount);
    report.add('export_missingImages', result.missingImageIds);
    expect(result.testPieceCount, 6);
    expect(result.missingImageIds, isEmpty, reason: '写真つきの 3 枚の写真が入る');

    final archive = ZipDecoder().decodeBytes(
      await result.zipFile.readAsBytes(),
    );
    final names = archive.files.map((f) => f.name).toList();
    report.add('export_files', names);
    expect(names, contains('data.json'));
    expect(names, contains('glaze_manager.xlsx'));
    // ZIP には images/ というディレクトリの項目も入るので、ファイルだけを数える
    final imageFiles = archive.files
        .where((f) => f.isFile && f.name.startsWith('images/'))
        .toList();
    expect(imageFiles, hasLength(3));
    expect(imageFiles.every((f) => f.size > 0), isTrue, reason: '写真の中身が入っている');

    final data =
        jsonDecode(
              utf8.decode(
                archive.files.firstWhere((f) => f.name == 'data.json').content,
              ),
            )
            as Map<String, dynamic>;
    final collections = data['collections'] as Map<String, dynamic>;
    expect(collections['testPieces'], hasLength(6));
    expect(collections['glazes'], hasLength(3));
    expect(collections['firings'], hasLength(1));

    // 書き出した Excel の先頭のシートは、釉薬の取り込みでそのまま読める
    final parsed = GlazeImporter.parseExcelBytes(
      archive.files.firstWhere((f) => f.name == 'glaze_manager.xlsx').content,
      existingGlazeNames: const {},
    );
    report.add('export_reimport_glazes', [for (final r in parsed.rows) r.name]);
    expect(parsed.rows.map((r) => r.name), containsAll(['青磁', '白萩', '青磁 改']));
    final celadon = parsed.rows.firstWhere((r) => r.name == '青磁');
    expect(celadon.amountsByMaterialName['長石'], 58);
    expect(celadon.amountsByPigmentName['酸化鉄'], 1.5);
  } finally {
    await workDir.delete(recursive: true);
  }
}

/// 本番のホストを指すダウンロード URL を、Storage エミュレータに読み替える。
class _EmulatorDownloadClient extends http.BaseClient {
  final _inner = http.Client();

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    final url = request.url;
    if (url.host != 'firebasestorage.googleapis.com') {
      return _inner.send(request);
    }
    final rewritten = http.Request(
      request.method,
      url.replace(scheme: 'http', host: emulatorHost, port: liveStoragePort),
    )..headers.addAll(request.headers);
    return _inner.send(rewritten);
  }
}

Future<void> _offlineSave(WidgetTester tester, Report report) async {
  expect(sdkFirestorePort, isNot(liveFirestorePort));
  expect(sdkStoragePort, isNot(liveStoragePort));
  final user = await signUpFreshUser();
  final uid = user.uid;
  report.add('uid', uid);
  // サーバーに届かないので、完了は待てない
  for (final write in _seedBaseData(uid)) {
    unawaited(write);
  }

  final picker = FakeImagePicker();
  ImagePickerPlatform.instance = picker;
  picker.queue.addAll(await makeTestPhotos([(180, 90, 30)]));

  final storage = await pumpGlazeManager(tester);
  await waitFor(tester, find.text('テストピース一覧'));
  await settle(tester);

  // --- 届かない状態で、写真つきで登録する ---
  await tester.tap(find.byTooltip('テストピースを追加'));
  await waitFor(tester, find.text('テストピースの新規作成'));
  await settle(tester);
  await chooseFromDropdown(
    tester,
    find.byType(DropdownSearch<Glaze>).first,
    '青磁',
  );
  await chooseFromDropdown(tester, find.byType(DropdownSearch<Clay>), '信楽白');
  await tester.enterText(find.widgetWithText(TextFormField, '番号'), 'OFF-01');
  await settle(tester, const Duration(milliseconds: 200));
  await tapVisible(tester, find.text('写真を選択'));
  await confirmCrop(tester);
  await tester.tap(find.byTooltip('保存'));
  await waitFor(tester, find.text('テストピース一覧'));
  await pumpUntil(
    tester,
    () => _visibleCardIds().length == 1,
    reason: '登録した 1 枚が一覧に出る',
  );
  final id = _visibleCardIds().single;
  report.add('testPieceId', id);

  // 端末内の写真と、送信待ちの印が出る
  await waitFor(tester, find.byIcon(Icons.cloud_upload_outlined));
  expect(
    find.descendant(of: cardOf(id), matching: find.byType(Image)),
    findsOneWidget,
  );
  // 送信を一度は試み、届かないと分かって止まるまで待つ
  await settle(tester, const Duration(seconds: 5));
  await screenshot(tester, '20_offline_list_pending');
  expect(storage.uploads, isEmpty, reason: '届かないあいだは送らない');
  expect(await _serverPiece(uid, id), isNull, reason: '記録はまだサーバーにない');

  // 待ちは端末内に保存されている
  final jobDir = Directory(p.join((await _pendingRoot()).path, id));
  final job =
      jsonDecode(await File(p.join(jobDir.path, 'job.json')).readAsString())
          as Map<String, dynamic>;
  expect(job['uid'], uid);
  expect(job['testPieceId'], id);
  expect(
    await File(p.join(jobDir.path, job['fileName'] as String)).exists(),
    isTrue,
  );
  report.add('pendingJob', job);

  // 詳細と編集でも、端末内の写真が出る
  await tester.tap(cardOf(id));
  await waitFor(tester, find.text('テストピース詳細'));
  await settle(tester);
  await screenshot(tester, '21_offline_detail_pending');
  await goBack(tester);
  await waitFor(tester, find.text('テストピース一覧'));

  await writeState('app_flow', {
    'uid': uid,
    'testPieceId': id,
    'storagePath': job['storagePath'],
  });
  await settle(tester, const Duration(seconds: 2));
}

Future<void> _afterRestart(WidgetTester tester, Report report) async {
  final state = await readState('app_flow');
  final uid = state['uid'] as String;
  final id = state['testPieceId'] as String;
  final storagePath = state['storagePath'] as String;

  final restored = await FirebaseAuth.instance.authStateChanges().first.timeout(
    const Duration(seconds: 30),
  );
  expect(restored?.uid, uid, reason: 'サインイン状態が残っている');

  final started = DateTime.now();
  final storage = await pumpGlazeManager(tester);
  await waitFor(tester, find.text('テストピース一覧'));
  await pumpUntil(
    tester,
    () => _visibleCardIds().contains(id),
    reason: '前回登録した 1 枚が一覧に出る',
  );
  await screenshot(tester, '30_restart_list');

  // 前回の書き込みがサーバーに届く
  final arrived = await waitUntil(
    () async => await _serverPiece(uid, id) != null,
    timeout: const Duration(seconds: 60),
  );
  report.add('restart_docArrived_ms', arrived?.inMilliseconds);
  expect(arrived, isNotNull, reason: 'オフラインで登録した記録が、再起動後に届く');
  expect((await _serverPiece(uid, id))!['label'], 'OFF-01');
  expect((await _serverPiece(uid, id))!['imagePath'], storagePath);

  // 待たせていた写真が送られ、Functions が書き戻す
  final uploaded = await waitUntil(
    () async => storage.uploads.containsKey(storagePath),
    timeout: const Duration(seconds: 120),
  );
  expect(uploaded, isNotNull, reason: '再起動後に写真が送られる');
  final launchToUpload = storage.uploads[storagePath]!
      .difference(started)
      .inMilliseconds;
  report.add('restart_launchToUpload_ms', launchToUpload);
  expect(
    launchToUpload < 10000,
    isTrue,
    reason:
        '起動直後の試行は前回の書き込みが届く前に走る。'
        '同期待ちの試し直しが短い間隔で効いていること: $launchToUpload ms',
  );
  final written = await waitUntil(
    () async => (await _serverPiece(uid, id))?['thumbnailUrl'] != null,
    timeout: const Duration(seconds: 90),
  );
  expect(written, isNotNull, reason: 'Functions がサムネイルの URL を書き戻す');
  expect(await adminListObjects('users/$uid/test_pieces/images/$id/'), [
    storagePath,
  ]);

  final queue = containerOf(tester).read(uploadQueueProvider);
  await pumpUntil(tester, () => queue.pending.isEmpty, reason: '待ちが空になる');
  expect(
    await Directory(p.join((await _pendingRoot()).path, id)).exists(),
    isFalse,
    reason: '送り終えたら端末内の写しを消す',
  );
  await pumpUntil(
    tester,
    () => !exists(find.byIcon(Icons.cloud_upload_outlined)),
    reason: '送信待ちの印が消える',
  );
  await screenshot(tester, '31_restart_after_upload');
}
