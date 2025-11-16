import 'package:flutter/material.dart';
import 'package:glaze_manager/models/glaze.dart';
import 'package:glaze_manager/models/test_piece.dart';
import 'package:glaze_manager/services/firestore_service.dart';
import 'package:glaze_manager/services/settings_service.dart';
import 'package:glaze_manager/widgets/test_piece_card.dart';
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

  // データ
  List<TestPiece> _allTestPieces = [];
  Map<String, Glaze> _glazeMap = {};
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
    final glazes = await firestoreService.getGlazes().first;
    final testPieces = await firestoreService.getTestPieces().first;

    if (mounted) {
      setState(() {
        _glazeMap = {for (var g in glazes) g.id!: g};
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
    });

    final lowerQuery = query.toLowerCase();

    // クライアントサイドでのフィルタリング
    _searchResults = _allTestPieces.where((tp) {
      final glaze = _glazeMap[tp.glazeId];
      if (glaze == null) return false;

      // 釉薬名での部分一致
      final glazeNameMatch = glaze.name.toLowerCase().contains(lowerQuery);
      // タグでの部分一致
      final tagMatch = glaze.tags.any(
        (tag) => tag.toLowerCase().contains(lowerQuery),
      );

      return glazeNameMatch || tagMatch;
    }).toList();

    setState(() => _isLoading = false);
  }

  void _openColorPicker() {
    // TODO: Implement color picker and search logic
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('色味検索は未実装です。')));
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
    // TODO: 「最近見たテストピース」のロジックを実装する。
    // ここでは最新のテストピースを代わりに表示します。
    final recentPieces = _allTestPieces.take(20).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Text(
            '最近のテストピース', // 仕様では「最近見た」だが、実装の都合上「最近の」とする
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
        Expanded(
          child: recentPieces.isEmpty
              ? const Center(child: Text('テストピースがありません。'))
              : _buildGridView(recentPieces, crossAxisCount),
        ),
      ],
    );
  }

  Widget _buildSearchResults(int crossAxisCount) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Text('検索結果', style: Theme.of(context).textTheme.titleLarge),
        ),
        Expanded(
          child: _searchResults.isEmpty
              ? Center(child: Text('「$_searchQuery」に一致する結果はありません。'))
              : _buildGridView(_searchResults, crossAxisCount),
        ),
      ],
    );
  }

  Widget _buildGridView(List<TestPiece> pieces, int crossAxisCount) {
    // 画面の幅から、1アイテムあたりのおおよその幅を計算
    final screenWidth = MediaQuery.of(context).size.width;
    const padding = 8.0;
    const spacing = 8.0;
    final maxCardWidth =
        (screenWidth - (padding * 2) - (spacing * (crossAxisCount - 1))) /
        crossAxisCount;

    return GridView.builder(
      padding: const EdgeInsets.all(padding),
      gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: maxCardWidth, // 各アイテムの最大幅
        mainAxisSpacing: spacing, // アイテム間の垂直方向のスペース
        crossAxisSpacing: spacing, // アイテム間の水平方向のスペース
        // 画像を正方形にし、その下にテキストの高さを加える
        // テキスト部分のおおよその高さを60と仮定 (TestPieceCardの実装に依存)
        childAspectRatio: maxCardWidth / (maxCardWidth + 60),
      ),
      itemCount: pieces.length,
      itemBuilder: (context, index) {
        final testPiece = pieces[index];
        final glazeName = _glazeMap[testPiece.glazeId]?.name ?? '不明な釉薬';
        return TestPieceCard(testPiece: testPiece, glazeName: glazeName);
      },
    );
  }
}
