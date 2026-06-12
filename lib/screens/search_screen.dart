import 'dart:ui' as ui;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart' hide ColorSwatch;
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart'
    show ConsumerStatefulWidget, ConsumerState, AsyncValueX;
import 'package:glaze_manager/providers/data_providers.dart';
import 'package:glaze_manager/models/clay.dart';
import 'package:glaze_manager/models/color_swatch.dart';
import 'package:glaze_manager/models/glaze.dart';
import 'package:glaze_manager/models/test_piece.dart';
import 'package:glaze_manager/models/firing_atmosphere.dart';
import 'package:glaze_manager/models/firing_profile.dart';
import 'package:glaze_manager/services/settings_service.dart';
import 'package:glaze_manager/widgets/test_piece_grid.dart';
import 'package:glaze_manager/widgets/tag_management_widget.dart';
import 'package:glaze_manager/widgets/test_piece_card.dart';
import 'package:glaze_manager/widgets/test_piece_list_tile.dart';
import 'package:glaze_manager/screens/test_piece_detail_screen.dart';
import 'package:provider/provider.dart';

class SearchScreen extends ConsumerStatefulWidget {
  final PageStorageKey? pageStorageKey;
  final Color? initialColor;
  const SearchScreen({super.key, this.pageStorageKey, this.initialColor});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _recentItemsController = ScrollController();

  // 検索関連の状態
  bool _isSearching = false;
  bool _isLoading = false;
  String _searchQuery = '';
  Color? _searchColor;
  double _deltaEThreshold = 30.0;
  final List<String> _selectedTags = [];

  List<TestPiece> _searchResults = [];
  bool _isGridView = true;
  bool _appliedInitialColor = false;

  // データはアプリスコープのプロバイダから都度参照する
  // (画面ローカルにスナップショットを持たないので、他画面での追加・編集が即反映される)
  List<TestPiece> get _allTestPieces =>
      ref.read(testPiecesProvider).valueOrNull ?? [];
  Map<String, Glaze> get _glazeMap => ref.read(glazeMapProvider);
  Map<String, Clay> get _clayMap => ref.read(clayMapProvider);
  Map<String, FiringAtmosphere> get _atmosphereMap =>
      ref.read(firingAtmosphereMapProvider);
  Map<String, FiringProfile> get _profileMap =>
      ref.read(firingProfileMapProvider);
  Map<String, String> get _materialMap => ref.read(materialNameMapProvider);
  List<String> get _allTags => ref.read(tagsProvider).valueOrNull ?? [];

  @override
  void initState() {
    super.initState();
    if (widget.initialColor != null) {
      _searchColor = widget.initialColor;
    }
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _recentItemsController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    // Rebuild to show suggestions
    setState(() {});

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

      final primaryMatches = <TestPiece>[];
      final materialMatches = <TestPiece>[];

      for (final tp in filtered) {
        final glaze = _glazeMap[tp.glazeId];
        if (glaze == null) continue;

        final clay = _clayMap[tp.clayId];
        final atmosphere = _atmosphereMap[tp.firingAtmosphereId];
        final profile = _profileMap[tp.firingProfileId];

        // 検索対象の文字列を結合して検索しやすくする
        final searchableText = [
          glaze.name,
          ...glaze.tags,
          clay?.name ?? '',
          atmosphere?.name ?? '',
          profile?.name ?? '',
        ].join(' ').toLowerCase();

        // 原料名の検索対象
        final materialNames = glaze.recipe.keys
            .map((id) => _materialMap[id] ?? '')
            .join(' ')
            .toLowerCase();

        // Negative Terms Check (Common)
        bool matchesNegative =
            negativeTerms.isNotEmpty &&
            negativeTerms.any(
              (term) =>
                  searchableText.contains(term) || materialNames.contains(term),
            );

        if (matchesNegative) continue;

        // Positive Terms Check
        bool matchesPrimary =
            positiveTerms.isEmpty ||
            positiveTerms.every((term) => searchableText.contains(term));

        bool matchesMaterial =
            positiveTerms.isEmpty ||
            positiveTerms.every((term) => materialNames.contains(term));

        if (matchesPrimary) {
          primaryMatches.add(tp);
        } else if (matchesMaterial) {
          materialMatches.add(tp);
        }
      }

      // プライマリマッチを優先、その後に原料マッチを追加
      filtered = [...primaryMatches, ...materialMatches];
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
        if (testPiece.colorData == null || testPiece.colorData!.isEmpty) {
          continue;
        }

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
                              // タグはプロバイダ経由でリアルタイム反映されるため
                              // 戻ってきた後の再読み込みは不要
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (context) =>
                                      const TagManagementWidget(),
                                ),
                              );
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
    final testPiecesAsync = ref.watch(testPiecesProvider);

    // データ更新で再ビルドさせるための監視。
    // (コールバック内からは getter 経由の ref.read で最新値を参照する)
    ref.watch(glazesProvider);
    ref.watch(claysProvider);
    ref.watch(firingAtmospheresProvider);
    ref.watch(firingProfilesProvider);
    ref.watch(materialsProvider);
    ref.watch(tagsProvider);

    // データが更新されたら検索結果も追従させる
    ref.listen(testPiecesProvider, (previous, next) {
      if (!next.hasValue) return;
      if (widget.initialColor != null && !_appliedInitialColor) {
        _appliedInitialColor = true;
        _applyFilters();
      } else if (_isSearching) {
        _applyFilters();
      }
    });

    final isDataLoading = testPiecesAsync.isLoading;

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
                              // \u300c-\u8a9e\u300d\u306f\u30de\u30a4\u30ca\u30b9\u691c\u7d22 (\u9664\u5916\u6761\u4ef6)
                              final isNegative =
                                  term.startsWith('-') && term.length > 1;
                              return Chip(
                                avatar: Icon(
                                  isNegative
                                      ? Icons.block
                                      : Icons.text_fields,
                                  size: 18,
                                  color: isNegative
                                      ? Theme.of(context).colorScheme.error
                                      : null,
                                ),
                                label: Text(
                                  isNegative
                                      ? '${term.substring(1)} \u3092\u9664\u5916'
                                      : term,
                                ),
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
                      if (_selectedTags.isNotEmpty ||
                          _searchColor != null ||
                          _searchQuery.isNotEmpty)
                        TextButton.icon(
                          onPressed: () {
                            setState(() {
                              _searchController.clear();
                              _searchQuery = '';
                              _searchColor = null;
                              _selectedTags.clear();
                            });
                            _applyFilters();
                          },
                          icon: const Icon(Icons.clear_all),
                          label: const Text('すべてクリア'),
                          style: TextButton.styleFrom(
                            foregroundColor: Theme.of(
                              context,
                            ).colorScheme.error,
                          ),
                        ),
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
              child: (_isLoading || isDataLoading)
                  ? const Center(child: CircularProgressIndicator())
                  : _isSearching
                  ? _buildSearchResults(crossAxisCount)
                  : _searchController.text.isNotEmpty
                  ? _buildSuggestions()
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

  Widget _buildSuggestions() {
    final query = _searchController.text.toLowerCase();
    if (query.isEmpty) return const SizedBox.shrink();

    final suggestions = <String>{}; // Use Set to avoid duplicates

    // Tags
    for (var tag in _allTags) {
      if (tag.toLowerCase().contains(query)) {
        suggestions.add(tag);
      }
    }

    // Glaze Names
    for (var glaze in _glazeMap.values) {
      if (glaze.name.toLowerCase().contains(query)) {
        suggestions.add(glaze.name);
      }
    }

    // Material Names
    for (var name in _materialMap.values) {
      if (name.toLowerCase().contains(query)) {
        suggestions.add(name);
      }
    }

    final suggestionList = suggestions.take(20).toList();

    return ListView.builder(
      itemCount: suggestionList.length,
      itemBuilder: (context, index) {
        final suggestion = suggestionList[index];
        return ListTile(
          leading: const Icon(Icons.search),
          title: Text(suggestion),
          onTap: () {
            _searchController.text = suggestion;
            _performTextSearch(suggestion);
            // Hide keyboard
            FocusScope.of(context).unfocus();
          },
        );
      },
    );
  }

  Widget _buildRecentTestPieces(int crossAxisCount) {
    final firestoreService = ref.read(firestoreServiceProvider);
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

        if (recentPieces.isEmpty) {
          return const Center(child: Text('最近見たテストピースはありません。'));
        }

        return Container(
          color: Theme.of(
            context,
          ).colorScheme.surfaceContainerLow, // 僅かに背景色を変える
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 12.0,
                ),
                child: Text(
                  '最近見たテストピース',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              SizedBox(
                height: 240, // カルーセルの高さ
                child: Listener(
                  onPointerSignal: (pointerSignal) {
                    if (pointerSignal is PointerScrollEvent) {
                      final newOffset =
                          _recentItemsController.offset +
                          pointerSignal.scrollDelta.dy;
                      if (newOffset >= 0 &&
                          newOffset <=
                              _recentItemsController.position.maxScrollExtent) {
                        _recentItemsController.jumpTo(newOffset);
                      }
                    }
                  },
                  child: ScrollConfiguration(
                    behavior: ScrollConfiguration.of(context).copyWith(
                      dragDevices: {
                        ui.PointerDeviceKind.touch,
                        ui.PointerDeviceKind.mouse,
                      },
                    ),
                    child: ListView.builder(
                      controller: _recentItemsController,
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 12.0),
                      itemCount: recentPieces.length,
                      itemBuilder: (context, index) {
                        final testPiece = recentPieces[index];
                        final glazeName =
                            _glazeMap[testPiece.glazeId]?.name ?? '不明な釉薬';
                        final clayName =
                            _clayMap[testPiece.clayId]?.name ?? '不明な素地';
                        final firingAtmosphere =
                            _atmosphereMap[testPiece.firingAtmosphereId];
                        final firingAtmosphereName =
                            firingAtmosphere?.name ?? '不明な雰囲気';
                        final firingAtmosphereType =
                            firingAtmosphere?.type ??
                            FiringAtmosphereType.other;
                        final firingProfileName =
                            _profileMap[testPiece.firingProfileId]?.name ??
                            '不明なプロファイル';

                        return SizedBox(
                          width: 160, // カードの幅
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4.0,
                              vertical: 6.0,
                            ),
                            child: TestPieceCard(
                              testPiece: testPiece,
                              glazeName: glazeName,
                              clayName: clayName,
                              firingAtmosphereName: firingAtmosphereName,
                              firingAtmosphereType: firingAtmosphereType,
                              firingProfileName: firingProfileName,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('検索結果', style: Theme.of(context).textTheme.titleLarge),
              IconButton(
                icon: Icon(_isGridView ? Icons.view_list : Icons.grid_view),
                tooltip: _isGridView ? 'リスト表示に切り替え' : 'グリッド表示に切り替え',
                onPressed: () {
                  setState(() {
                    _isGridView = !_isGridView;
                  });
                },
              ),
            ],
          ),
        ),
        Expanded(
          child: _searchResults.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.search_off,
                        size: 48,
                        color: Colors.grey,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        '条件に一致する結果はありません。',
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        '条件を変えてみてください',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                )
              : _isGridView
              ? TestPieceGrid(
                  testPieces: _searchResults,
                  glazeMap: _glazeMap,
                  clayMap: _clayMap,
                  firingAtmosphereMap: _atmosphereMap,
                  firingProfileMap: _profileMap,
                  crossAxisCount: crossAxisCount,
                )
              : ListView.builder(
                  itemCount: _searchResults.length,
                  itemBuilder: (context, index) {
                    final testPiece = _searchResults[index];
                    final glazeName =
                        _glazeMap[testPiece.glazeId]?.name ?? '不明な釉薬';
                    final clayName =
                        _clayMap[testPiece.clayId]?.name ?? '不明な素地';
                    final firingAtmosphere =
                        _atmosphereMap[testPiece.firingAtmosphereId];
                    final firingAtmosphereName =
                        firingAtmosphere?.name ?? '不明な雰囲気';
                    final firingAtmosphereType =
                        firingAtmosphere?.type ?? FiringAtmosphereType.other;
                    final firingProfileName =
                        _profileMap[testPiece.firingProfileId]?.name ??
                        '不明なプロファイル';

                    return TestPieceListTile(
                      testPiece: testPiece,
                      glazeName: glazeName,
                      clayName: clayName,
                      firingAtmosphereName: firingAtmosphereName,
                      firingAtmosphereType: firingAtmosphereType,
                      firingProfileName: firingProfileName,
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) =>
                                TestPieceDetailScreen(testPiece: testPiece),
                          ),
                        );
                      },
                    );
                  },
                ),
        ),
      ],
    );
  }
}
