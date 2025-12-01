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
  final Color? initialColor;
  const SearchScreen({super.key, this.pageStorageKey, this.initialColor});

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
  double _deltaEThreshold = 30.0;
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
    if (widget.initialColor != null) {
      _searchColor = widget.initialColor;
    }
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
        _allTags = tags;
        _isLoading = false;
      });
      if (widget.initialColor != null) {
        _applyFilters();
      }
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

    // 1. テキスト検索 (Positive & Negative)
    if (_searchQuery.isNotEmpty) {
      final terms = _searchQuery
          .split(RegExp(r'\s+'))
          .where((t) => t.isNotEmpty);
      final positiveTerms = terms
          .where((t) => !t.startsWith('-'))
          .map((t) => t.toLowerCase())
          .toList();
      final negativeTerms = terms
          .where((t) => t.startsWith('-') && t.length > 1)
          .map((t) => t.substring(1).toLowerCase())
          .toList();

      filtered = filtered.where((tp) {
        final glaze = _glazeMap[tp.glazeId];
        if (glaze == null) return false;

        // 検索対象の文字列を結合して検索しやすくする
        final clay = _clayMap[tp.clayId];
        final atmosphere = _atmosphereMap[tp.firingAtmosphereId];
        final profile = _profileMap[tp.firingProfileId];

        final searchableText = [
          glaze.name,
          ...glaze.tags,
          clay?.name ?? '',
          atmosphere?.name ?? '',
          profile?.name ?? '',
        ].join(' ').toLowerCase();

        // Positive Terms (AND)
        bool matchesPositive =
            positiveTerms.isEmpty ||
            positiveTerms.every((term) => searchableText.contains(term));

        // Negative Terms (AND NOT)
        bool matchesNegative =
            negativeTerms.isNotEmpty &&
            negativeTerms.any((term) => searchableText.contains(term));

        return matchesPositive && !matchesNegative;
      }).toList();
    }

    // 2. タグフィルタ (AND検索)
    if (_selectedTags.isNotEmpty) {
      filtered = filtered.where((tp) {
        final glaze = _glazeMap[tp.glazeId];
        if (glaze == null) return false;
        return _selectedTags.every((tag) => glaze.tags.contains(tag));
      }).toList();
    }

    // 3. 色検索 & ソート
    if (_searchColor != null) {
      final targetColorSwatch = ColorSwatch.fromColor(_searchColor!);
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

        if (minDeltaE <= _deltaEThreshold) {
          matchedPieces.add((testPiece, minDeltaE));
        }
      }

      // 色に近い順にソート
      matchedPieces.sort((a, b) => a.$2.compareTo(b.$2));
      filtered = matchedPieces.map((e) => e.$1).toList();
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
      body: SafeArea(
        child: Column(
          children: [
            _buildSearchBar(),
            if (_selectedTags.isNotEmpty ||
                _searchColor != null ||
                _searchQuery.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: SizedBox(
                  width: double.infinity,
                  child: Wrap(
                    spacing: 8.0,
                    alignment: WrapAlignment.start,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      if (_searchQuery.isNotEmpty)
                        ..._searchQuery
                            .split(RegExp(r'[ \u3000]+'))
                            .where((t) => t.isNotEmpty)
                            .map((term) {
                              return Chip(
                                avatar: const Icon(Icons.text_fields, size: 18),
                                label: Text(term),
                                onDeleted: () {
                                  final terms = _searchQuery
                                      .split(RegExp(r'[ \u3000]+'))
                                      .where((t) => t.isNotEmpty)
                                      .toList();
                                  terms.remove(term);
                                  final newQuery = terms.join(' ');
                                  _searchController.text = newQuery;
                                  _performTextSearch(newQuery);
                                },
                              );
                            }),
                      if (_searchColor != null)
                        Chip(
                          avatar: const Icon(Icons.palette, size: 18),
                          label: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 12,
                                height: 12,
                                decoration: BoxDecoration(
                                  color: _searchColor,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.grey),
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Text('に近い'),
                            ],
                          ),
                          onDeleted: () {
                            setState(() {
                              _searchColor = null;
                            });
                            _applyFilters();
                          },
                        ),
                      ..._selectedTags.map((tag) {
                        return Chip(
                          avatar: const Icon(Icons.label, size: 18),
                          label: Text(tag),
                          onDeleted: () {
                            setState(() {
                              _selectedTags.remove(tag);
                            });
                            _applyFilters();
                          },
                        );
                      }),
                    ],
                  ),
                ),
              ),
            if (_searchColor != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Row(
                  children: [
                    const Text('色差許容値 (ΔE):'),
                    Expanded(
                      child: Slider(
                        value: _deltaEThreshold,
                        min: 5.0,
                        max: 50.0,
                        label: _deltaEThreshold.round().toString(),
                        onChanged: (value) {
                          setState(() {
                            _deltaEThreshold = value;
                          });
                          _applyFilters();
                        },
                      ),
                    ),
                    Text(_deltaEThreshold.round().toString()),
                  ],
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
      ),
    );
  }

  Widget _buildSearchBar() {
    final canPop = Navigator.canPop(context);
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Row(
        children: [
          if (canPop)
            IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => Navigator.of(context).pop(),
            ),
          Expanded(
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: '釉薬名、タグで検索...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.0),
                  borderSide: const BorderSide(
                    width: 0,
                    style: BorderStyle.none,
                  ),
                ),
                filled: true,
                fillColor: Theme.of(
                  context,
                ).colorScheme.surfaceContainerHighest,
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
                          });
                          _applyFilters();
                        },
                        tooltip: 'クリア',
                      ),
                    IconButton(
                      icon: Icon(
                        Icons.color_lens_outlined,
                        color: _searchColor,
                      ),
                      onPressed: _openColorPicker,
                      tooltip: '色で検索',
                    ),
                    IconButton(
                      icon: Icon(
                        _selectedTags.isEmpty
                            ? Icons.label_outline
                            : Icons.label,
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
          ),
        ],
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
              Text('検索結果', style: Theme.of(context).textTheme.titleLarge),
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
