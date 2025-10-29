import 'package:flutter/material.dart';
import 'package:glaze_manager/screens/materials_list_screen.dart';
import 'package:glaze_manager/screens/glaze_list_screen.dart';
import 'package:glaze_manager/screens/test_piece_list_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // final authService = Provider.of<AuthService>(context, listen: false);

    return Scaffold(
      appBar: AppBar(
        title: const Text('釉薬レシピ管理'),
        // actions: [
        //   IconButton(
        //     icon: const Icon(Icons.logout),
        //     tooltip: 'サインアウト',
        //     onPressed: () async {
        //       // 確認ダイアログなどを表示しても良い
        //       final authService = Provider.of<AuthService>(context, listen: false);
        //       await authService.signOut();
        //     },
        //   ),
        // ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          _buildMenuCard(
            context,
            icon: Icons.science_outlined,
            title: '原料データベース管理',
            onTap: () {
              Navigator.of(context).push(MaterialPageRoute(
                builder: (context) => const MaterialsListScreen(),
              ));
            },
          ),
          const SizedBox(height: 16),
          _buildMenuCard(
            context,
            icon: Icons.color_lens_outlined,
            title: '釉薬レシピ管理',
            onTap: () {
              Navigator.of(context).push(MaterialPageRoute(
                builder: (context) => const GlazeListScreen(),
              ));
            },
          ),
          const SizedBox(height: 16),
          _buildMenuCard(
            context,
            icon: Icons.photo_library_outlined,
            title: 'テストピース管理',
            onTap: () {
              Navigator.of(context).push(MaterialPageRoute(
                builder: (context) => const TestPieceListScreen(),
              ));
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMenuCard(BuildContext context,
      {required IconData icon, required String title, required VoidCallback onTap}) {
    return Card(
      child: ListTile(
        leading: Icon(icon, size: 40),
        title: Text(title, style: Theme.of(context).textTheme.titleLarge),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}