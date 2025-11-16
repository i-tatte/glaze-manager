import 'dart:io';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:glaze_manager/models/glaze.dart';
import 'package:glaze_manager/models/firing_profile.dart';
import 'package:glaze_manager/models/firing_atmosphere.dart';
import 'package:glaze_manager/models/test_piece.dart';
import 'package:glaze_manager/services/firestore_service.dart';
import 'package:glaze_manager/services/storage_service.dart';
import 'package:glaze_manager/screens/image_crop_screen.dart';
import 'package:image_picker/image_picker.dart';
import 'package:glaze_manager/widgets/firing_chart.dart';
import 'package:dropdown_search/dropdown_search.dart';
import 'package:image/image.dart' as img;
import 'package:provider/provider.dart';

class TestPieceEditScreen extends StatefulWidget {
  final TestPiece? testPiece;

  const TestPieceEditScreen({super.key, this.testPiece});

  @override
  State<TestPieceEditScreen> createState() => _TestPieceEditScreenState();
}

class _TestPieceEditScreenState extends State<TestPieceEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _clayNameController = TextEditingController();

  String? _selectedGlazeId;
  String? _selectedFiringProfileId;
  String? _selectedFiringAtmosphereId;
  List<FiringProfile> _availableFiringProfiles = [];
  List<FiringAtmosphere> _availableFiringAtmospheres = [];
  List<Glaze> _availableGlazes = [];

  XFile? _imageFile; // 選択された画像ファイル
  String? _networkImageUrl; // 既存の画像のURL
  String? _networkThumbnailUrl; // 既存のサムネイルURL
  XFile? _thumbnailFile; // 生成されたサムネイルファイル

  bool _isLoading = false;
  bool _isDirty = false;
  // グラフ表示用の状態
  bool _isChartVisible = false;

  @override
  void initState() {
    super.initState();
    _clayNameController.text = widget.testPiece?.clayName ?? '';
    _selectedGlazeId = widget.testPiece?.glazeId;
    _selectedFiringAtmosphereId = widget.testPiece?.firingAtmosphereId;
    _selectedFiringProfileId = widget.testPiece?.firingProfileId;
    _networkImageUrl = widget.testPiece?.imageUrl;
    _networkThumbnailUrl = widget.testPiece?.thumbnailUrl;

    _clayNameController.addListener(_markAsDirty);

    _loadDropdownData();
  }

  Future<void> _loadDropdownData() async {
    final firestoreService = Provider.of<FirestoreService>(
      context,
      listen: false,
    );
    _availableGlazes = await firestoreService.getGlazes().first;
    _availableFiringProfiles = await firestoreService.getFiringProfiles().first;
    _availableFiringAtmospheres = await firestoreService
        .getFiringAtmospheres()
        .first;
    // 初回ロード時はダーティ状態にしない
    setState(() {});
  }

  void _markAsDirty() {
    if (!_isDirty) {
      setState(() => _isDirty = true);
    }
  }

  @override
  void dispose() {
    _clayNameController.dispose();
    super.dispose();
    _clayNameController.removeListener(_markAsDirty);
  }

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      // 画像選択後、トリミング画面に遷移
      final XFile? croppedImage = await Navigator.of(context).push(
        MaterialPageRoute(builder: (context) => ImageCropScreen(image: image)),
      );

      if (croppedImage != null) {
        setState(() => _isLoading = true); // 画像処理中のインジケーター表示
        try {
          // 画像処理をバックグラウンドで実行
          final results = await compute(_processImage, croppedImage.path);

          setState(() {
            _imageFile = croppedImage;
            _thumbnailFile = results['thumbnailFile'];
            _markAsDirty();
          });
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text('画像処理に失敗しました: $e')));
          }
        } finally {
          if (mounted) {
            setState(() => _isLoading = false);
          }
        }
      }
    }
  }

  /// 画像処理(BlurHashとサムネイル生成)をまとめたトップレベル関数 (computeで使用するため)
  static Future<Map<String, dynamic>> _processImage(String imagePath) async {
    final imageBytes = await File(imagePath).readAsBytes();
    final image = img.decodeImage(imageBytes);

    if (image == null) {
      throw Exception('画像のデコードに失敗しました。');
    }

    // サムネイルの生成 (幅30px)
    final thumbnail = img.copyResize(image, width: 30);
    final thumbnailFile = XFile.fromData(
      Uint8List.fromList(img.encodeJpg(thumbnail, quality: 85)),
      name: 'thumb_${DateTime.now().millisecondsSinceEpoch}.jpg',
      mimeType: 'image/jpeg',
    );

    return {'thumbnailFile': thumbnailFile};
  }

  Future<void> _saveTestPiece() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    if (_selectedGlazeId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('釉薬を選択してください。')));
      return;
    }

    setState(() => _isLoading = true);

    final navigator = Navigator.of(context);
    try {
      final firestoreService = Provider.of<FirestoreService>(
        context,
        listen: false,
      );
      final storageService = Provider.of<StorageService>(
        context,
        listen: false,
      );
      String? imageUrl = _networkImageUrl;
      String? thumbnailUrl = _networkThumbnailUrl;

      // 新しい画像が選択されていればアップロード
      if (_imageFile != null && _thumbnailFile != null) {
        try {
          // サムネイルと本画像を並行でアップロード
          final results = await Future.wait([
            storageService.uploadTestPieceImage(_imageFile!),
            storageService.uploadTestPieceImage(
              _thumbnailFile!,
              isThumbnail: true,
            ),
          ]).timeout(const Duration(seconds: 30));

          imageUrl = results[0];
          thumbnailUrl = results[1];
        } on TimeoutException {
          throw '画像のアップロードがタイムアウトしました。ネットワーク接続を確認してください。';
        }
      }
      final testPiece = TestPiece(
        id: widget.testPiece?.id,
        glazeId: _selectedGlazeId!,
        clayName: _clayNameController.text,
        firingAtmosphereId: _selectedFiringAtmosphereId,
        firingProfileId: _selectedFiringProfileId,
        imageUrl: imageUrl,
        thumbnailUrl: thumbnailUrl,
        blurHash: null, // BlurHashは保存しない
        createdAt: widget.testPiece?.createdAt ?? Timestamp.now(),
      );

      if (widget.testPiece == null) {
        await firestoreService.addTestPiece(testPiece);
        if (mounted) {
          _isDirty = false;
          navigator.pop(); // 新規作成時は一覧に戻る
        }
      } else {
        await firestoreService.updateTestPiece(testPiece);
        if (mounted) {
          _isDirty = false;
          navigator.pop(); // 更新時は詳細画面に戻る
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('保存に失敗しました: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _confirmDelete() async {
    // 新規作成時は何もしない
    if (widget.testPiece == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('削除の確認'),
        content: const Text('このテストピースを本当に削除しますか？\nこの操作は元に戻せません。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('削除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final navigator = Navigator.of(context);
      try {
        final firestoreService = context.read<FirestoreService>();
        final storageService = context.read<StorageService>();

        // Storageから画像とサムネイルを削除 (並行処理)
        final deleteFutures = <Future>[];
        if (widget.testPiece!.imageUrl != null) {
          deleteFutures.add(
            storageService.deleteTestPieceImage(widget.testPiece!.imageUrl!),
          );
        }
        if (widget.testPiece!.thumbnailUrl != null) {
          deleteFutures.add(
            storageService.deleteTestPieceImage(
              widget.testPiece!.thumbnailUrl!,
            ),
          );
        }
        if (deleteFutures.isNotEmpty) {
          await Future.wait(deleteFutures);
        }

        // Firestoreからドキュメントを削除
        await firestoreService.deleteTestPiece(widget.testPiece!.id!);

        if (mounted) {
          // 編集画面と詳細画面を閉じて一覧画面まで戻る
          int count = 0;
          navigator.popUntil((_) => count++ >= 2);
        }
      } catch (e) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('削除に失敗しました: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_isDirty,
      onPopInvoked: _onPopInvoked,
      child: _buildScaffold(),
    );
  }

  /// 画面を離れる際に未保存の変更があるか確認する
  Future<void> _onPopInvoked(bool didPop) async {
    if (didPop) return;

    if (_isDirty) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('変更を破棄しますか？'),
          content: const Text('入力中の内容は保存されません。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('キャンセル'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('破棄', style: TextStyle(color: Colors.red)),
            ),
          ],
        ),
      );
      if (confirmed == true && mounted) {
        Navigator.of(context).pop();
      }
    } else {
      Navigator.of(context).pop();
    }
  }

  Widget _buildScaffold() {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.testPiece == null ? 'テストピースの新規作成' : 'テストピースの編集'),
        actions: [
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(color: Colors.black),
              ),
            )
          else
            Row(
              children: [
                if (widget.testPiece != null)
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    tooltip: '削除',
                    onPressed: _confirmDelete,
                  ),
                IconButton(
                  icon: const Icon(Icons.save),
                  tooltip: '保存',
                  onPressed: _saveTestPiece,
                ),
              ],
            ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          // アスペクト比が1.2より大きい場合を横長画面とみなす
          if (constraints.maxWidth / constraints.maxHeight > 1.2) {
            return _buildWideLayout();
          } else {
            return _buildNarrowLayout();
          }
        },
      ),
    );
  }

  /// 縦長レイアウト (スマートフォンなど)
  Widget _buildNarrowLayout() {
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          ..._buildFormFields(),
          const SizedBox(height: 24),
          ..._buildImageSection(),
        ],
      ),
    );
  }

  /// 横長レイアウト (PCなど)
  Widget _buildWideLayout() {
    return Row(
      children: [
        // 左半分: フォーム
        Expanded(
          flex: 1,
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(16.0),
              children: _buildFormFields(),
            ),
          ),
        ),
        const VerticalDivider(width: 1),
        // 右半分: 画像とグラフ
        Expanded(
          flex: 1,
          child: ListView(
            padding: const EdgeInsets.all(16.0),
            children: _buildImageSection(),
          ),
        ),
      ],
    );
  }

  /// フォーム部分のウィジェットリストを生成
  List<Widget> _buildFormFields() {
    final selectedProfile = _selectedFiringProfileId != null
        ? _availableFiringProfiles
              .where((p) => p.id == _selectedFiringProfileId)
              .firstOrNull
        : null;

    return [
      // 釉薬選択
      DropdownSearch<Glaze>(
        items: (f, cs) => _availableGlazes,
        itemAsString: (Glaze g) => g.name,
        selectedItem: (_selectedGlazeId != null && _availableGlazes.isNotEmpty)
            ? _availableGlazes
                  .where((g) => g.id == _selectedGlazeId)
                  .firstOrNull
            : null,
        onChanged: (Glaze? data) {
          _markAsDirty();
          setState(() {
            _selectedGlazeId = data?.id;
          });
        },
        popupProps: PopupProps.menu(
          showSearchBox: true,
          searchFieldProps: TextFieldProps(
            decoration: InputDecoration(
              border: const OutlineInputBorder(),
              contentPadding: const EdgeInsets.fromLTRB(12, 12, 8, 0),
              labelText: "釉薬を検索",
              hintText: "釉薬名を入力...",
            ),
            autofocus: true,
          ),
        ),
        decoratorProps: const DropDownDecoratorProps(
          decoration: InputDecoration(labelText: "釉薬名"),
        ),
        validator: (Glaze? item) => item == null ? "釉薬を選択してください" : null,
        compareFn: (Glaze a, Glaze b) => a.id == b.id,
      ),
      const SizedBox(height: 16),
      // 素地土名
      TextFormField(
        controller: _clayNameController,
        decoration: const InputDecoration(labelText: '素地土名'),
        validator: (value) =>
            (value == null || value.isEmpty) ? '素地土名を入力' : null,
      ),
      const SizedBox(height: 16),
      // 焼成雰囲気
      DropdownButtonFormField<String>(
        decoration: const InputDecoration(labelText: '焼成雰囲気'),
        value: _selectedFiringAtmosphereId,
        hint: const Text('焼成雰囲気を選択 (任意)'),
        isExpanded: true,
        items: _availableFiringAtmospheres
            .map(
              (atmosphere) => DropdownMenuItem(
                value: atmosphere.id,
                child: Text(atmosphere.name),
              ),
            )
            .toList(),
        onChanged: (value) {
          _markAsDirty();
          setState(() => _selectedFiringAtmosphereId = value);
        },
        validator: null,
      ),
      const SizedBox(height: 16),
      // 焼成プロファイル
      DropdownButtonFormField<String>(
        decoration: const InputDecoration(labelText: '焼成プロファイル'),
        value: _selectedFiringProfileId,
        hint: const Text('焼成プロファイルを選択 (任意)'),
        isExpanded: true,
        items: _availableFiringProfiles
            .map(
              (profile) => DropdownMenuItem(
                value: profile.id,
                child: Text(profile.name),
              ),
            )
            .toList(),
        onChanged: (value) {
          _markAsDirty();
          setState(() => _selectedFiringProfileId = value);
        },
        validator: null,
      ),
      // グラフ表示エリア
      if (selectedProfile?.curveData != null &&
          selectedProfile!.curveData!.isNotEmpty) ...[
        const Divider(),
        const SizedBox(height: 8),
        TextButton.icon(
          icon: Icon(_isChartVisible ? Icons.visibility_off : Icons.visibility),
          label: Text(_isChartVisible ? '焼成温度曲線を隠す' : '焼成温度曲線を表示'),
          onPressed: () {
            setState(() => _isChartVisible = !_isChartVisible);
          },
        ),
        Visibility(
          visible: _isChartVisible,
          child: FiringChart(curveData: selectedProfile.curveData!),
        ),
      ],
    ];
  }

  /// 画像部分のウィジェットリストを生成
  List<Widget> _buildImageSection() {
    return [
      Text('テストピース画像', style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: 8),
      _buildImagePreview(),
      const SizedBox(height: 8),
      OutlinedButton.icon(
        icon: const Icon(Icons.photo_library),
        label: const Text('ギャラリーから画像を選択'),
        onPressed: _pickImage,
      ),
      const SizedBox(height: 16),
    ];
  }

  Widget _buildImagePreview() {
    // 新しい画像が選択されている場合
    if (_imageFile != null) {
      if (kIsWeb) {
        return Image.network(_imageFile!.path, fit: BoxFit.contain);
      } else {
        return Image.file(File(_imageFile!.path), fit: BoxFit.contain);
      }
    }
    // 既存の画像URLがある場合
    if (_networkImageUrl != null) {
      return Image.network(
        _networkImageUrl!,
        fit: BoxFit.contain,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return const Center(
            heightFactor: 3,
            child: CircularProgressIndicator(),
          );
        },
        errorBuilder: (context, error, stackTrace) {
          return const Center(
            heightFactor: 3,
            child: Icon(Icons.error, color: Colors.red),
          );
        },
      );
    }
    // どちらもない場合
    return Container(
      height: 200,
      decoration: BoxDecoration(
        color: Colors.grey[200],
        border: Border.all(color: Colors.grey[400]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Center(
        child: Icon(Icons.camera_alt, color: Colors.grey, size: 50),
      ),
    );
  }
}
