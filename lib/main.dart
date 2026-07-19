import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'firebase_options.dart';
import 'package:glaze_manager/providers/data_providers.dart';
import 'package:glaze_manager/screens/auth_wrapper.dart';
import 'package:glaze_manager/theme/app_theme.dart';
import 'package:glaze_manager/widgets/common/mouse_back_listener.dart';

/// マウスの戻るボタンからNavigatorを操作するためのルートNavigatorキー
final _rootNavigatorKey = GlobalKey<NavigatorState>();

void main() async {
  // Flutterのウィジェットバインディングを初期化
  WidgetsFlutterBinding.ensureInitialized();

  // Firebaseを初期化
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // ★★★ Firestoreのオフライン永続化を有効化 ★★★
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
  );

  runApp(const ProviderScope(child: GlazeManagerApp()));
}

class GlazeManagerApp extends ConsumerWidget {
  const GlazeManagerApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsServiceProvider);
    return MaterialApp(
      title: 'Glaze Manager',
      navigatorKey: _rootNavigatorKey,
      builder: (context, child) => MouseBackListener(
        navigatorKey: _rootNavigatorKey,
        child: child!,
      ),
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: settings.themeMode,
      home: const AuthWrapper(),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('ja', 'JP')],
    );
  }
}
