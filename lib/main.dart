// main.dart
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:glaze_manager/screens/auth_wrapper.dart';
import 'package:glaze_manager/services/auth_service.dart';
import 'package:glaze_manager/services/firestore_service.dart';
import 'package:glaze_manager/services/storage_service.dart';
import 'firebase_options.dart'; // flutterfire configure で生成されたファイル
import 'package:provider/provider.dart';

void main() async {
  // Flutterのウィジェットバインディングを初期化
  WidgetsFlutterBinding.ensureInitialized();

  // Firebaseを初期化
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // ★★★ Firestoreのオフライン永続化を有効化 ★★★
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
  );

  runApp(const AppProviders());
}

class AppProviders extends StatelessWidget {
  const AppProviders({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<AuthService>(
          create: (_) => AuthService(),
        ),
        Provider<FirestoreService>(
          create: (_) => FirestoreService(),
        ),
        Provider<StorageService>(
          create: (_) => StorageService(),
        ),
      ],
      child: MaterialApp(
        title: 'Glaze Recipe App',
        theme: ThemeData(
          primarySwatch: Colors.blue,
        ),
        home: const AuthWrapper(), // 認証状態に応じて表示を切り替えるWidget (screens/auth_wrapper.dart)
      ),
    );
  }
}
