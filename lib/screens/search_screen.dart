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
import 'package:glaze_manager/widgets/tag_management_widget.dart';
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
  List<String> _selectedTags = [];

  // データ
  List<TestPiece> _allTestPieces = [];
  Map<String, Glaze> _glazeMap = {};
  Map<String, Clay> _clayMap = {};
  Map<String, FiringAtmosphere> _atmosphereMap = {};
  Map<String, FiringProfile> _profileMap = {};
  List<TestPiece> _searchResults = [];
  List<String> _allTags = [];

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
      firestoreService.getTags().first,
    ]);

    final glazes = results[0] as List<Glaze>;
    final testPieces = results[1] as List<TestPiece>;
    final atmospheres = results[2] as List<FiringAtmosphere>;
    final profiles = results[3] as List<FiringProfile>;
    final clays = results[4] as List<Clay>;
    final tags = results[5] as List<String>;

    if (mounted) {
      setState(() {
        _glazeMap = {for (var item in glazes) item.id!: item};
        _clayMap = {for (var item in clays) item.id!: item};
        _atmosphereMap = {for (var item in atmospheres) item.id!: item};
        _profileMap = {for (var item in profiles) item.id!: item};
        _allTestPieces = testPieces;
        _allTags = tags;
        _isLoading = false;
      });
    }
  }

  void _onSearchChanged() {
    if (_searchController.text.isEmpty &&
        _isSearching &&
        _searchColor == null &&
        _selectedTags.isEmpty) {
      setState(() {
        _isSearching = false;
        _searchResults.clear();
        _searchQuery = '';
      });
    }
  }

  void _applyFilters() {
    setState(() {
      _isLoading = true;
      _isSearching = true;
    });

    List<TestPiece> filtered = _allTestPieces;

    // 1. 色検索 (優先)
    if (_searchColor != null) {
      final targetColorSwatch = ColorSwatch.fromColor(_searchColor!);
      const double deltaEThreshold = 30.0;
      final List<(TestPiece, double)> matchedPieces = [];

      for (final testPiece in filtered) {
        if (testPiece.colorData == null || testPiece.colorData!.isEmpty)
          continue;
        double minDeltaE = double.infinity;
        for (final swatch in testPiece.colorData!) {
          final deltaE = targetColorSwatch.deltaE(swatch);
          if (deltaE < minDeltaE) {
            minDeltaE = deltaE;
          }
        }
        if (minDeltaE <= deltaEThreshold) {
          matchedPieces.add((testPiece, minDeltaE));
        }
      }
      matchedPieces.sort((a, b) => a.$2.compareTo(b.$2));
      filtered = matchedPieces.map((e) => e.$1).toList();
    }

    // 2. テキスト検索
    if (_searchQuery.isNotEmpty) {
      final lowerQuery = _searchQuery.toLowerCase();
      filtered = filtered.where((tp) {
        final glaze = _glazeMap[tp.glazeId];
        if (glaze == null) return false;

        bool glazeNameMatch = glaze.name.toLowerCase().contains(lowerQuery);
        bool tagMatch = glaze.tags.any(
          (tag) => tag.toLowerCase().contains(lowerQuery),
        );
        final clay = _clayMap[tp.clayId];
        bool clayNameMatch =
            clay?.name.toLowerCase().contains(lowerQuery) ?? false;
        final atmosphere = _atmosphereMap[tp.firingAtmosphereId];
        bool atmosphereMatch =
            atmosphere?.name.toLowerCase().contains(lowerQuery) ?? false;
        final profile = _profileMap[tp.firingProfileId];
        bool profileMatch =
            profile?.name.toLowerCase().contains(lowerQuery) ?? false;

        return glazeNameMatch ||
            tagMatch ||
            clayNameMatch ||
            atmosphereMatch ||
            profileMatch;
      }).toList();
    }

    // 3. タグフィルタ (AND検索)
    if (_selectedTags.isNotEmpty) {
      filtered = filtered.where((tp) {
        final glaze = _glazeMap[tp.glazeId];
        if (glaze == null) return false;
        return _selectedTags.every((tag) => glaze.tags.contains(tag));
      }).toList();
    }

    setState(() {
      _searchResults = filtered;
      _isLoading = false;
      if (_searchQuery.isEmpty &&
          _searchColor == null &&
          _selectedTags.isEmpty) {
        _isSearching = false;
      }
    });
  }

  void _performTextSearch(String query) {
    setState(() {
      _searchQuery = query;
      _searchColor = null; // テキスト検索時は色検索をクリア
    });
    _applyFilters();
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
      setState(() {
        _searchColor = selectedColor;
        _searchQuery = ''; // 色検索時はテキスト検索をクリア
      });
      _applyFilters();
    }
  }

  void _openTagSelector() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return DraggableScrollableSheet(
              initialChildSize: 0.6,
              minChildSize: 0.4,
              maxChildSize: 0.9,
              expand: false,
              builder: (context, scrollController) {
                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'タグで絞り込み',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                              Navigator.pop(context);
                              Navigator.of(context)
                                  .push(
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          const TagManagementWidget(),
                                    ),
                                  )
                                  .then(
                                    (_) => _loadInitialData(),
                                  ); // タグ管理から戻ったらデータを再読み込み
                            },
                            child: const Text('タグ管理'),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    Expanded(
                      child: _allTags.isEmpty
                          ? const Center(child: Text('タグが登録されていません'))
                          : ListView.builder(
                              controller: scrollController,
                              itemCount: _allTags.length,
                              itemBuilder: (context, index) {
                                final tag = _allTags[index];
                                final isSelected = _selectedTags.contains(tag);
                                return CheckboxListTile(
                                  title: Text(tag),
                                  value: isSelected,
                                  onChanged: (bool? value) {
                                    setModalState(() {
                                      if (value == true) {
                                        _selectedTags.add(tag);
                                      } else {
                                        _selectedTags.remove(tag);
                                      }
                                    });
                                    // 親のStateも更新して即時反映
                                    _applyFilters();
                                  },
                                );
                              },
                            ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () {
                                setModalState(() {
                                  _selectedTags.clear();
                                });
                                _applyFilters();
                              },
                              child: const Text('クリア'),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: FilledButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('完了'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final crossAxisCount = context.watch<SettingsService>().gridCrossAxisCount;

    return Scaffold(
      body: Column(
        children: [
          _buildSearchBar(),
          if (_selectedTags.isNotEmpty)
            SizedBox(
              height: 40,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _selectedTags.length,
                separatorBuilder: (context, index) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final tag = _selectedTags[index];
                  return Chip(
                    label: Text(tag),
                    onDeleted: () {
                      setState(() {
                        _selectedTags.remove(tag);
                      });
                      _applyFilters();
                    },
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                  );
                },
              ),
            ),
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
                  onPressed: () {
                    _searchController.clear();
                    setState(() {
                      _searchQuery = '';
                      _searchColor = null;
                      _selectedTags.clear();
                    });
                    _applyFilters();
                  },
                  tooltip: 'クリア',
                ),
              IconButton(
                icon: Icon(Icons.color_lens_outlined, color: _searchColor),
                onPressed: _openColorPicker,
                tooltip: '色で検索',
              ),
              IconButton(
                icon: Icon(
                  _selectedTags.isEmpty ? Icons.label_outline : Icons.label,
                  color: _selectedTags.isNotEmpty
                      ? Theme.of(context).colorScheme.primary
                      : null,
                ),
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
        final recentPieces = <TestPiece>[];
        for (final id in recentIds) {
          try {
            final piece = _allTestPieces.firstWhere((p) => p.id == id);
            recentPieces.add(piece);
          } catch (e) {
            // ignore
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
              ? Center(child: Text('条件に一致する結果はありません。'))
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
