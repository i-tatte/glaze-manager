// 実機確認で、アプリ本体の画面を動かすための部品。
//
// image_picker の差し替えに image_picker_platform_interface を直接使う
// (image_picker が公開している差し替え口で、依存にはすでに含まれている)。
// ignore_for_file: depend_on_referenced_packages
import 'dart:io';
import 'dart:ui' as ui;

import 'package:crop_your_image/crop_your_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glaze_manager/main.dart'
    show GlazeManagerApp, scaffoldMessengerKey;
import 'package:glaze_manager/providers/data_providers.dart';
import 'package:glaze_manager/widgets/test_piece_card.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';
import 'package:path/path.dart' as p;

import 'emulator_env.dart';

final _screenKey = GlobalKey();

/// アプリ本体を起動する。main() との違いは、写真の送信先を Storage
/// エミュレータにしていることだけである。
Future<EmulatorStorageService> pumpGlazeManager(WidgetTester tester) async {
  final storage = EmulatorStorageService();
  await tester.pumpWidget(
    RepaintBoundary(
      key: _screenKey,
      child: ProviderScope(
        overrides: [
          storageServiceProvider.overrideWithValue(storage),
          uploadFailureReporterProvider.overrideWithValue(
            (message) => scaffoldMessengerKey.currentState?.showSnackBar(
              SnackBar(content: Text(message)),
            ),
          ),
        ],
        child: const GlazeManagerApp(),
      ),
    ),
  );
  return storage;
}

/// アプリの ProviderContainer (アップロード待ちの状態などを見るため)
ProviderContainer containerOf(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(GlazeManagerApp)));

bool exists(Finder finder) => finder.evaluate().isNotEmpty;

/// 条件が成り立つまで画面を進める。時間切れなら、その時点の画面を残して失敗する。
Future<void> pumpUntil(
  WidgetTester tester,
  bool Function() condition, {
  required String reason,
  Duration timeout = const Duration(seconds: 30),
}) async {
  final watch = Stopwatch()..start();
  while (true) {
    await tester.pump(const Duration(milliseconds: 100));
    if (condition()) return;
    if (watch.elapsed > timeout) {
      await screenshot(tester, 'timeout_${reason.hashCode.toRadixString(16)}');
      fail('時間切れ: $reason');
    }
  }
}

Future<void> waitFor(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 30),
}) => pumpUntil(
  tester,
  () => exists(finder),
  reason: '${finder.describeMatch(Plurality.one)} が現れる',
  timeout: timeout,
);

Future<void> waitGone(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 30),
}) => pumpUntil(
  tester,
  () => !exists(finder),
  reason: '${finder.describeMatch(Plurality.one)} が消える',
  timeout: timeout,
);

/// 画面の遷移やメニューの開閉が落ち着くのを待つ。
Future<void> settle(
  WidgetTester tester, [
  Duration duration = const Duration(milliseconds: 600),
]) => tester.pump(duration);

/// 現在の画面を PNG に残す (GM_REPORT_DIR/screens/)。
Future<void> screenshot(WidgetTester tester, String name) async {
  if (reportDir.isEmpty) return;
  await tester.pump(const Duration(milliseconds: 80));
  final boundary =
      _screenKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final image = await boundary.toImage();
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  final file = File(p.join(reportDir, 'screens', '$name.png'));
  await file.parent.create(recursive: true);
  await file.writeAsBytes(data!.buffer.asUint8List(), flush: true);
}

/// AppBar の戻るボタンを押す。tester.pageBack() は英語のツールチップ
/// 'Back' で探すので、日本語化したアプリでは見つからない。いちばん上の
/// 画面のボタンを押す (下の画面のボタンも同じ位置にあるので、押せるもの
/// だけに絞る)。
Future<void> goBack(WidgetTester tester) async {
  final back = find.byType(BackButton).hitTestable();
  expect(back, findsOneWidget, reason: '押せる戻るボタンが 1 つある');
  await tester.tap(back);
  await tester.pump(const Duration(milliseconds: 100));
}

/// 一覧のカードを、テストピースの ID で探す。
Finder cardOf(String testPieceId) => find.byWidgetPredicate(
  (w) => w is TestPieceCard && w.testPiece.id == testPieceId,
  description: 'TestPieceCard($testPieceId)',
);

/// 見えるところまで動かしてから押す。
Future<void> tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pump(const Duration(milliseconds: 250));
  await tester.tap(finder);
  await tester.pump(const Duration(milliseconds: 100));
}

/// 編集画面のフォーム (遅延して組み立てるリスト) を、[finder] が組み立てられて
/// 見えるところまで動かす。フォームの下のほうの部品は、動かすまで存在しない。
Future<void> scrollFormTo(WidgetTester tester, Finder finder) => _scrollTo(
  tester,
  finder,
  find.descendant(of: find.byType(Form), matching: find.byType(Scrollable)),
);

/// 編集画面の写真の欄 (横長の画面では右半分のリスト) を、[finder] が
/// 見えるところまで動かす。写真が大きいと、下のボタンは組み立てられない。
Future<void> scrollImagePaneTo(WidgetTester tester, Finder finder) => _scrollTo(
  tester,
  finder,
  find.ancestor(of: find.text('テストピース画像'), matching: find.byType(Scrollable)),
);

Future<void> _scrollTo(
  WidgetTester tester,
  Finder finder,
  Finder scrollable,
) async {
  await waitFor(tester, scrollable);
  await tester.scrollUntilVisible(
    finder,
    200,
    scrollable: scrollable.first,
    maxScrolls: 30,
  );
  await tester.pump(const Duration(milliseconds: 250));
}

/// 検索つきのドロップダウンを開いて、項目を選ぶ。
Future<void> chooseFromDropdown(
  WidgetTester tester,
  Finder dropdown,
  String itemText,
) async {
  await tapVisible(tester, dropdown);
  await settle(tester);
  await waitFor(tester, find.text(itemText));
  await tester.tap(find.text(itemText).last);
  await settle(tester);
}

/// 切り抜きの画面で、そのまま確定する。
Future<void> confirmCrop(WidgetTester tester) async {
  await waitFor(tester, find.text('画像をトリミング'));
  await pumpUntil(
    tester,
    () => find.byType(DotControl).evaluate().length >= 4,
    reason: '切り抜きの枠が出る',
  );
  await settle(tester, const Duration(milliseconds: 300));
  await tester.tap(find.byTooltip('完了'));
  await waitGone(
    tester,
    find.text('画像をトリミング'),
    timeout: const Duration(seconds: 60),
  );
  await settle(tester);
}

/// 写真の選択を差し替える (実機の選択ダイアログは自動で操作できない)。
/// 選択のあとの切り抜き・保存・送信は、本物の流れをそのまま通る。
class FakeImagePicker extends ImagePickerPlatform {
  /// 次に「選ばれる」写真
  final List<XFile> queue = [];

  @override
  Future<XFile?> getImageFromSource({
    required ImageSource source,
    ImagePickerOptions options = const ImagePickerOptions(),
  }) async => queue.isEmpty ? null : queue.removeAt(0);

  @override
  Future<List<XFile>> getMultiImageWithOptions({
    MultiImagePickerOptions options = const MultiImagePickerOptions(),
  }) async {
    final all = List<XFile>.of(queue);
    queue.clear();
    return all;
  }

  @override
  Future<LostDataResponse> getLostData() async => LostDataResponse.empty();
}

/// 色の違う JPEG を作って、選べる写真として返す。
Future<List<XFile>> makeTestPhotos(List<(int, int, int)> colors) async {
  final dir = await Directory(
    p.join(
      Directory.systemTemp.path,
      'gm_it_photos_${DateTime.now().microsecondsSinceEpoch}',
    ),
  ).create(recursive: true);
  final files = <XFile>[];
  for (var i = 0; i < colors.length; i++) {
    final (r, g, b) = colors[i];
    final image = img.Image(width: 640, height: 480);
    img.fill(image, color: img.ColorRgb8(r, g, b));
    // 単色にならないよう、隅に別の色を入れる
    img.fillRect(
      image,
      x1: 0,
      y1: 0,
      x2: 120,
      y2: 90,
      color: img.ColorRgb8(255 - r, 255 - g, 255 - b),
    );
    final file = File(p.join(dir.path, 'photo_$i.jpg'));
    await file.writeAsBytes(img.encodeJpg(image, quality: 90), flush: true);
    files.add(XFile(file.path));
  }
  return files;
}
