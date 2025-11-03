import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:glaze_manager/screens/login_screen.dart';
import 'package:glaze_manager/screens/main_tab_screen.dart';
import 'package:glaze_manager/services/auth_service.dart';
import 'package:provider/provider.dart';

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);

    return StreamBuilder<User?>(
      stream: authService.user,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasData) {
          // ログイン済み
          return const MainTabScreen();
        }
        // 未ログイン
        return const LoginScreen();
      },
    );
  }
}
