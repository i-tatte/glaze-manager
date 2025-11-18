import 'package:flutter/material.dart' hide ColorSwatch;
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:glaze_manager/models/clay.dart';
import 'package:glaze_manager/models/color_swatch.dart';
import 'package:glaze_manager/models/glaze.dart';
import 'package:glaze_manager/models/test_piece.dart';
import 'package:glaze_manager/models/firing_atmosphere.dart';
import 'package:glaze_manager/models/firing_profile.dart';
import 'package:glaze_manager/services/firestore_service.dart';
import 'package:glaze_manager/services/settings_service.dart';
import 'package:glaze_manager/widgets/test_piece_grid.dart';
import 'package:provider/provider.dart';

class SearchScreen extends StatefulWidget {
  final PageStorageKey? pageStorageKey;
  const SearchScreen({super.key, this.pageStorageKey});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();

  // 検索関連の状態
  bool _isSearching = false;
  bool _isLoading = false;
  String _searchQuery = '';
  Color? _searchColor;

  // データ
  List<TestPiece> _allTestPieces = [];
  Map<String, Glaze> _glazeMap = {};
  Map<String, Clay> _clayMap = {};
  Map<String, FiringAtmosphere> _atmosphereMap = {};
  Map<String, FiringProfile> _profileMap = {};
  List<TestPiece> _searchResults = [];

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _loadInitialData();
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    final firestoreService = context.read<FirestoreService>();
    // 全ての釉薬とテストピースを一度だけ取得
    final results = await Future.wait([
      firestoreService.getGlazes().first,
      firestoreService.getTestPieces().first,
      firestoreService.getFiringAtmospheres().first,
      firestoreService.getFiringProfiles().first,
      firestoreService.getClays().first,
    ]);

    final glazes = results[0] as List<Glaze>;
    final testPieces = results[1] as List<TestPiece>;
    final atmospheres = results[2] as List<FiringAtmosphere>;
    final profiles = results[3] as List<FiringProfile>;
    final clays = results[4] as List<Clay>;

    if (mounted) {
      setState(() {
        _glazeMap = {for (var item in glazes) item.id!: item};
        _clayMap = {for (var item in clays) item.id!: item};
        _atmosphereMap = {for (var item in atmospheres) item.id!: item};
        _profileMap = {for (var item in profiles) item.id!: item};
        _allTestPieces = testPieces;
        _isLoading = false;
      });
    }
  }

  void _onSearchChanged() {
    if (_searchController.text.isEmpty && _isSearching) {
      setState(() {
        _isSearching = false;
        _searchResults.clear();
        _searchQuery = '';
        _searchColor = null;
      });
    }
  }

  void _performTextSearch(String query) {
    if (query.isEmpty) {
      _onSearchChanged();
      return;
    }

    setState(() {
      _isLoading = true;
      _isSearching = true;
      _searchQuery = query;
      _searchColor = null;
    });

    final lowerQuery = query.toLowerCase();

    // クライアントサイドでのフィルタリング
    _searchResults = _allTestPieces.where((tp) {
      final glaze = _glazeMap[tp.glazeId];
      if (glaze == null) return false;

      // 釉薬名での部分一致
      bool glazeNameMatch = glaze.name.toLowerCase().contains(lowerQuery);

      // タグでの部分一致
      bool tagMatch = glaze.tags.any(
        (tag) => tag.toLowerCase().contains(lowerQuery),
      );

      // 素地土名での部分一致
      final clay = _clayMap[tp.clayId];
      bool clayNameMatch =
          clay?.name.toLowerCase().contains(lowerQuery) ?? false;

      // 焼成雰囲気名での部分一致
      final atmosphere = _atmosphereMap[tp.firingAtmosphereId];
      bool atmosphereMatch =
          atmosphere?.name.toLowerCase().contains(lowerQuery) ?? false;

      // 焼成プロファイル名での部分一致
      final profile = _profileMap[tp.firingProfileId];
      bool profileMatch =
          profile?.name.toLowerCase().contains(lowerQuery) ?? false;

      return glazeNameMatch ||
          tagMatch ||
          clayNameMatch ||
          atmosphereMatch ||
          profileMatch;
    }).toList();

    setState(() => _isLoading = false);
  }

  Future<void> _openColorPicker() async {
    Color selectedColor = _searchColor ?? Colors.grey;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('色の選択'),
          content: SingleChildScrollView(
            child: ColorPicker(
              pickerColor: selectedColor,
              onColorChanged: (color) => selectedColor = color,
              enableAlpha: false,
              displayThumbColor: true,
              hexInputBar: true,
            ),
          ),
          actions: [
            TextButton(
              child: const Text('キャンセル'),
              onPressed: () => Navigator.of(context).pop(false),
            ),
            TextButton(
              child: const Text('検索'),
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      _performColorSearch(selectedColor);
    }
  }

  void _performColorSearch(Color color) {
    setState(() {
      _isLoading = true;
      _isSearching = true;
      _searchQuery = ''; // テキスト検索クエリはクリア
      _searchColor = color;
    });

    // 検索対象の色をLab値に変換
    final targetColorSwatch = ColorSwatch.fromColor(color);
    const double deltaEThreshold = 30.0; // 色差のしきい値

    final List<(TestPiece, double)> matchedPieces = [];

    for (final testPiece in _allTestPieces) {
      if (testPiece.colorData == null || testPiece.colorData!.isEmpty) continue;

      double minDeltaE = double.infinity;

      // テストピース内の各色との色差を計算し、最小値を取得
      for (final swatch in testPiece.colorData!) {
        final deltaE = targetColorSwatch.deltaE(swatch);
        if (deltaE < minDeltaE) {
          minDeltaE = deltaE;
        }
      }

      // しきい値以下の色差であれば、結果に追加
      if (minDeltaE <= deltaEThreshold) {
        matchedPieces.add((testPiece, minDeltaE));
      }
    }

    // 色差が小さい順にソート
    matchedPieces.sort((a, b) => a.$2.compareTo(b.$2));
    _searchResults = matchedPieces.map((e) => e.$1).toList();

    setState(() => _isLoading = false);
  }

  void _openTagSelector() {
    // TODO: Implement tag selector and search logic
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('タグ検索は未実装です。')));
  }

  @override
  Widget build(BuildContext context) {
    // SettingsServiceからグリッド列数を取得
    final crossAxisCount = context.watch<SettingsService>().gridCrossAxisCount;

    return Scaffold(
      // AppBarはMainTabScreenで管理されるため、ここでは不要
      body: Column(
        children: [
          // 検索バー
          _buildSearchBar(),
          // メインコンテンツ
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _isSearching
                ? _buildSearchResults(crossAxisCount)
                : _buildRecentTestPieces(crossAxisCount),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: '釉薬名、タグで検索...',
          prefixIcon: const Icon(Icons.search),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12.0),
            borderSide: const BorderSide(width: 0, style: BorderStyle.none),
          ),
          filled: true,
          fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
          suffixIcon: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_isSearching)
                IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () => _searchController.clear(),
                  tooltip: 'クリア',
                ),
              IconButton(
                icon: const Icon(Icons.color_lens_outlined),
                onPressed: _openColorPicker,
                tooltip: '色で検索',
              ),
              IconButton(
                icon: const Icon(Icons.label_outline),
                onPressed: _openTagSelector,
                tooltip: 'タグで検索',
              ),
            ],
          ),
        ),
        onSubmitted: _performTextSearch,
      ),
    );
  }

  Widget _buildRecentTestPieces(int crossAxisCount) {
    final firestoreService = context.read<FirestoreService>();
    return StreamBuilder<List<String>>(
      stream: firestoreService.getRecentTestPieceIds(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Text('最近見たテストピースはありません。'));
        }

        final recentIds = snapshot.data!;
        // IDの順序を保持したまま、対応するTestPieceオブジェクトのリストを作成
        final recentPieces = <TestPiece>[];
        for (final id in recentIds) {
          try {
            final piece = _allTestPieces.firstWhere((p) => p.id == id);
            recentPieces.add(piece);
          } catch (e) {
            // _allTestPieces内にIDが見つからない場合は何もしない (無視する)
          }
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 8.0,
              ),
              child: Text(
                '最近見たテストピース',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            Expanded(
              child: TestPieceGrid(
                testPieces: recentPieces,
                glazeMap: _glazeMap,
                clayMap: _clayMap,
                crossAxisCount: crossAxisCount,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSearchResults(int crossAxisCount) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 0),
          child: Row(
            children: [
              if (_searchColor != null) ...[
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: _searchColor,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.grey),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Text(
                _searchColor != null ? 'に近い色の検索結果' : '"$_searchQuery"の検索結果',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ],
          ),
        ),
        Expanded(
          child: _searchResults.isEmpty
              ? Center(child: Text('「$_searchQuery」に一致する結果はありません。'))
              : TestPieceGrid(
                  testPieces: _searchResults,
                  glazeMap: _glazeMap,
                  clayMap: _clayMap,
                  crossAxisCount: crossAxisCount,
                ),
        ),
      ],
    );
  }
}
