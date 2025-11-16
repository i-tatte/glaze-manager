import 'package:flutter/material.dart';
import 'package:glaze_manager/models/glaze.dart';
import 'package:glaze_manager/models/material.dart' as app;
import 'package:glaze_manager/screens/glaze_edit_screen.dart';
import 'package:glaze_manager/services/firestore_service.dart';
import 'package:glaze_manager/screens/glaze_detail_screen.dart';
import 'package:provider/provider.dart';

enum SortOption { name, createdAt }

class GlazeListScreen extends StatefulWidget {
  final PageStorageKey? pageStorageKey;
  const GlazeListScreen({super.key, this.pageStorageKey});

  @override
  State<GlazeListScreen> createState() => GlazeListScreenState();
}

class GlazeListScreenState extends State<GlazeListScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  late Stream<List<Glaze>> _glazesStream;
  late Stream<List<app.Material>> _materialsStream;

  SortOption _sortOption = SortOption.name;
  bool _isAscending = true;

  @override
  void initState() {
    super.initState();
    _loadStreams();
    _searchController.addListener(_onSearchChanged);
  }

  void _loadStreams() {
    final firestoreService = context.read<FirestoreService>();
    _glazesStream = firestoreService.getGlazes();
    _materialsStream = firestoreService.getMaterials();
  }

  Future<void> handleRefresh() async {
    setState(() {
      _loadStreams();
    });
  }

  void _onSearchChanged() {
    if (_searchQuery != _searchController.text) {
      setState(() {
        _searchQuery = _searchController.text;
      });
    }
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  List<Glaze> _filterAndSortGlazes(
    List<Glaze> allGlazes,
    Map<String, String> materialIdToNameMap,
  ) {
    List<Glaze> filtered = allGlazes;

    // フィルタリング
    if (_searchQuery.isNotEmpty) {
      final lowerCaseQuery = _searchQuery.toLowerCase();
      filtered = allGlazes.where((glaze) {
        // 釉薬名
        if (glaze.name.toLowerCase().contains(lowerCaseQuery)) {
          return true;
        }
        // 登録名
        if (glaze.registeredName?.toLowerCase().contains(lowerCaseQuery) ??
            false) {
          return true;
        }
        // タグ
        if (glaze.tags.any(
          (tag) => tag.toLowerCase().contains(lowerCaseQuery),
        )) {
          return true;
        }
        // 原料名
        if (glaze.recipe.keys.any((materialId) {
          final materialName = materialIdToNameMap[materialId] ?? '';
          return materialName.toLowerCase().contains(lowerCaseQuery);
        })) {
          return true;
        }
        return false;
      }).toList();
    }

    // ソート
    filtered.sort((a, b) {
      int comparison;
      switch (_sortOption) {
        case SortOption.name:
          comparison = a.name.compareTo(b.name);
          break;
        case SortOption.createdAt:
          comparison = a.createdAt.compareTo(b.createdAt);
          break;
      }
      return _isAscending ? comparison : -comparison;
    });

    return filtered;
  }

  void _showSortOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.sort_by_alpha),
              title: const Text('名前順'),
              trailing: _sortOption == SortOption.name
                  ? Icon(
                      _isAscending ? Icons.arrow_upward : Icons.arrow_downward,
                    )
                  : null,
              onTap: () {
                setState(() {
                  if (_sortOption == SortOption.name) {
                    _isAscending = !_isAscending;
                  } else {
                    _sortOption = SortOption.name;
                    _isAscending = true;
                  }
                });
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.calendar_today),
              title: const Text('追加日順'),
              trailing: _sortOption == SortOption.createdAt
                  ? Icon(
                      _isAscending ? Icons.arrow_upward : Icons.arrow_downward,
                    )
                  : null,
              onTap: () {
                setState(() {
                  if (_sortOption == SortOption.createdAt) {
                    _isAscending = !_isAscending;
                  } else {
                    _sortOption = SortOption.createdAt;
                    _isAscending = false; // デフォルトは降順（新しい順）
                  }
                });
                Navigator.pop(context);
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: '釉薬名, 登録名, タグ, 原料名で検索...',
                          prefixIcon: const Icon(Icons.search),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12.0),
                            borderSide: BorderSide.none,
                          ),
                          filled: true,
                          fillColor: Theme.of(
                            context,
                          ).colorScheme.surfaceContainerHighest,
                          contentPadding: EdgeInsets.zero,
                          suffixIcon: _searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear),
                                  onPressed: () => _searchController.clear(),
                                )
                              : null,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.sort),
                      onPressed: _showSortOptions,
                      tooltip: '並べ替え',
                    ),
                  ],
                ),
              ),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: handleRefresh,
                  child: StreamBuilder<List<app.Material>>(
                    stream: _materialsStream,
                    builder: (context, materialsSnapshot) {
                      return StreamBuilder<List<Glaze>>(
                        stream: _glazesStream,
                        builder: (context, glazesSnapshot) {
                          if (glazesSnapshot.connectionState ==
                                  ConnectionState.waiting ||
                              materialsSnapshot.connectionState ==
                                  ConnectionState.waiting) {
                            return const Center(
                              child: CircularProgressIndicator(),
                            );
                          }
                          if (glazesSnapshot.hasError ||
                              materialsSnapshot.hasError) {
                            return Center(
                              child: Text(
                                'Error: ${glazesSnapshot.error ?? materialsSnapshot.error}',
                              ),
                            );
                          }

                          final allGlazes = glazesSnapshot.data ?? [];
                          final allMaterials = materialsSnapshot.data ?? [];
                          final materialIdToNameMap = {
                            for (var m in allMaterials) m.id!: m.name,
                          };

                          final displayedGlazes = _filterAndSortGlazes(
                            allGlazes,
                            materialIdToNameMap,
                          );

                          if (displayedGlazes.isEmpty) {
                            return Center(
                              child: Text(
                                _searchQuery.isNotEmpty
                                    ? '検索結果が見つかりません。'
                                    : '釉薬が登録されていません。\n右下のボタンから追加してください。',
                                textAlign: TextAlign.center,
                              ),
                            );
                          }

                          return ListView.builder(
                            itemCount: displayedGlazes.length,
                            itemBuilder: (context, index) {
                              final glaze = displayedGlazes[index];
                              return ListTile(
                                title: Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        glaze.name,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    if (glaze.tags.isNotEmpty) ...[
                                      const SizedBox(width: 8),
                                      Flexible(
                                        child: Wrap(
                                          spacing: 4.0,
                                          runSpacing: 4.0,
                                          children: glaze.tags
                                              .map(
                                                (tag) => Chip(
                                                  label: Text(
                                                    tag,
                                                    style: const TextStyle(
                                                      color: Colors.white,
                                                    ),
                                                  ),
                                                  backgroundColor: Theme.of(
                                                    context,
                                                  ).colorScheme.primary,
                                                  visualDensity:
                                                      VisualDensity.compact,
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 4.0,
                                                      ),
                                                ),
                                              )
                                              .toList(),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                subtitle: Text(
                                  '${glaze.registeredName != null ? '[${glaze.registeredName}] ' : ''}${glaze.description ?? ''}',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                trailing: const Icon(Icons.chevron_right),
                                onTap: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          GlazeDetailScreen(glaze: glaze),
                                    ),
                                  );
                                },
                              );
                            },
                          );
                        },
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
          Positioned(
            bottom: 16.0,
            right: 16.0,
            child: FloatingActionButton(
              heroTag: 'glazeListFab',
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const GlazeEditScreen(),
                  ),
                );
              },
              child: const Icon(Icons.add),
            ),
          ),
        ],
      ),
    );
  }
}
