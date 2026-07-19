import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// マウスの「戻る」サイドボタン (XButton1) でNavigatorの戻る操作を行う。
///
/// MaterialApp.builder でアプリ全体を包んで使う。maybePop なので
/// PopScope による制御 (MainTabScreenのタブ戻り・2回戻るで終了) もそのまま効く。
class MouseBackListener extends StatelessWidget {
  final GlobalKey<NavigatorState> navigatorKey;
  final Widget child;

  const MouseBackListener({
    super.key,
    required this.navigatorKey,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (event) {
        if (event.kind == PointerDeviceKind.mouse &&
            event.buttons & kBackMouseButton != 0) {
          navigatorKey.currentState?.maybePop();
        }
      },
      child: child,
    );
  }
}
