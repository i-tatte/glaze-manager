import 'dart:ffi';
import 'dart:io' show Platform, exit, pid;

import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';

/// アプリを終了する共通実装。
///
/// - モバイル: SystemNavigator.pop (OS標準の終了)
/// - Windows: 自ウィンドウに WM_CLOSE を送り、×ボタンと完全に同じ経路で閉じる。
///   ウィンドウは即座に消え、プラグインの終了処理 (Firebaseのテアダウン等) は
///   通常のクローズ手順として裏で完了する。
/// - その他のプラットフォーム / WM_CLOSE送信に失敗した場合: exit(0)
Future<void> exitApp() async {
  if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
    await SystemNavigator.pop();
    return;
  }
  if (!kIsWeb && Platform.isWindows && _closeOwnWindow()) {
    return;
  }
  exit(0);
}

const _wmClose = 0x0010;

// トップレベルのfinalは初回参照時に遅延評価されるため、
// Windows以外のプラットフォームで user32.dll が開かれることはない。
final _user32 = DynamicLibrary.open('user32.dll');

final _getForegroundWindow = _user32
    .lookupFunction<IntPtr Function(), int Function()>('GetForegroundWindow');

final _getWindowThreadProcessId = _user32.lookupFunction<
    Uint32 Function(IntPtr, Pointer<Uint32>),
    int Function(int, Pointer<Uint32>)>('GetWindowThreadProcessId');

final _postMessage = _user32.lookupFunction<
    Int32 Function(IntPtr, Uint32, IntPtr, IntPtr),
    int Function(int, int, int, int)>('PostMessageW');

/// フォアグラウンドウィンドウが自プロセスのものであれば WM_CLOSE を送る。
/// 送れなかった場合は false を返す (呼び出し側で exit にフォールバック)。
bool _closeOwnWindow() {
  final hwnd = _getForegroundWindow();
  if (hwnd == 0) return false;

  // 他アプリのウィンドウを誤って閉じないよう、所有プロセスを確認する
  final pidPtr = calloc<Uint32>();
  try {
    _getWindowThreadProcessId(hwnd, pidPtr);
    if (pidPtr.value != pid) return false;
  } finally {
    calloc.free(pidPtr);
  }

  return _postMessage(hwnd, _wmClose, 0, 0) != 0;
}
