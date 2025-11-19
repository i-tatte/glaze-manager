import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:glaze_manager/models/clay.dart';
import 'package:glaze_manager/models/color_swatch.dart';
import 'package:flutter/material.dart' hide ColorSwatch;
import 'package:glaze_manager/models/glaze.dart';
import 'package:glaze_manager/models/firing_profile.dart';
import 'package:glaze_manager/models/firing_atmosphere.dart';
import 'package:glaze_manager/models/test_piece.dart';
import 'package:glaze_manager/services/firestore_service.dart';
import 'package:glaze_manager/services/storage_service.dart';
import 'package:glaze_manager/screens/image_crop_screen.dart';
import 'package:image_picker/image_picker.dart';
import 'package:dropdown_search/dropdown_search.dart';
import 'package:provider/provider.dart';
import 'package:glaze_manager/widgets/firing_chart.dart';
import 'package:uuid/uuid.dart';
import 'package:path/path.dart' as p;

class TestPieceEditScreen extends StatefulWidget {
  final TestPiece? testPiece;

  const TestPieceEditScreen({super.key, this.testPiece});

  @override
  State<TestPieceEditScreen> createState() => _TestPieceEditScreenState();
}

class _TestPieceEditScreenState extends State<TestPieceEditScreen> {
  final _formKey = GlobalKey<FormState>();

  String? _selectedGlazeId;
  List<String> _additionalGlazeIds = [];
  String? _selectedClayId;
  String? _selectedFiringProfileId;
  String? _selectedFiringAtmosphereId;
  final _noteController = TextEditingController();

  List<FiringProfile> _availableFiringProfiles = [];
  List<FiringAtmosphere> _availableFiringAtmospheres = [];
  List<Clay> _availableClays = [];
  List<Glaze> _availableGlazes = [];

  String? _newImageFileName; // 新しく生成されたファイル名
  Uint8List? _newImageBytes; // 新しく生成された画像のバイトデータ
  String? _networkImageUrl; // 既存の画像のURL
  List<ColorSwatch> _colorData = []; // 編集用の色データ

  bool _isLoading = false;
  bool _isDirty = false;
  // グラフ表示用の状態
  bool _isChartVisible = false;

  @override
  void initState() {
    super.initState();
    _selectedGlazeId = widget.testPiece?.glazeId;
    _additionalGlazeIds =
        widget.testPiece?.additionalGlazeIds.toList() ?? [];
    _selectedClayId = widget.testPiece?.clayId;
    _selectedFiringAtmosphereId = widget.testPiece?.firingAtmosphereId;
    _selectedFiringProfileId = widget.testPiece?.firingProfileId;
    _networkImageUrl = widget.testPiece?.imageUrl;
    _colorData = List<ColorSwatch>.from(widget.testPiece?.colorData ?? []);
    _noteController.text = widget.testPiece?.note ?? '';

    _noteController.addListener(_markAsDirty);
    _loadDropdownData();
  }

  Future<void> _loadDropdownData() async {
    final firestoreService = Provider.of<FirestoreService>(
      context,
      listen: false,
    );
    _availableGlazes = await firestoreService.getGlazes().first;
    _availableClays = await firestoreService.getClays().first;
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
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    // 画像を読み込む際にリサイズし、処理負荷を軽減する
    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1500, // 最大幅を指定
      maxHeight: 1500, // 最大高さを指定
    );
    if (image != null) {
      // 画像選択後、トリミング画面に遷移
      // UUIDと元の拡張子を使って一意なファイル名を生成
      final uuid = const Uuid().v4();
      final extension = p.extension(image.name);
      final newFileName = '$uuid$extension';

      // ファイル名とバイトデータを受け取る
      final Map<String, dynamic>? cropResult = await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) =>
              ImageCropScreen(image: image, outputFileName: newFileName),
        ),
      );

      if (cropResult != null) {
        setState(() {
          _newImageFileName = cropResult['fileName'];
          _newImageBytes = cropResult['bytes'];
          _networkImageUrl = null; // プレビューを新しい画像に切り替える
          _markAsDirty();
        });
      }
    }
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
    if (_selectedClayId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('素地土名を選択してください。')));
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

      // --- パフォーマンス改善のためのロジック変更 ---
      // 1. 先にFirestoreにドキュメントを保存し、すぐに画面遷移させる
      // 2. 画像のアップロードは待たずにバックグラウンドで実行する

      String? imagePath;
      // 新規画像がある場合、アップロード先のパスを事前に決定
      if (_newImageFileName != null) {
        imagePath = storageService.getUploadPath(name: _newImageFileName!);
      } else {
        imagePath = widget.testPiece?.imagePath;
      }

      // 更新または作成するTestPieceオブジェクトを準備
      // この時点ではimageUrlとthumbnailUrlは未定
      final testPieceData = TestPiece(
        id: widget.testPiece?.id,
        glazeId: _selectedGlazeId!,
        additionalGlazeIds: _additionalGlazeIds,
        clayId: _selectedClayId!,
        imageUrl: widget.testPiece?.imageUrl, // 既存のURLを維持
        imagePath: imagePath,
        thumbnailUrl: widget.testPiece?.thumbnailUrl, // 既存のURLを維持
        firingAtmosphereId: _selectedFiringAtmosphereId,
        colorData: _colorData, // 編集された色データをセット
        firingProfileId: _selectedFiringProfileId,
        note: _noteController.text.trim().isEmpty ? null : _noteController.text.trim(),
        createdAt: widget.testPiece?.createdAt ?? Timestamp.now(),
      );

      // 新規画像がある場合のみ、アップロード処理を待たずに開始
      if (_newImageFileName != null && _newImageBytes != null) {
        storageService.uploadTestPieceImage(
          name: _newImageFileName!,
          bytes: _newImageBytes!,
          mimeType: 'image/jpeg',
        );
        // 新しい画像をアップロードした場合、Cloud Functionによる色解析を期待するため、
        // クライアント側の色データをクリアする
        setState(() => _colorData.clear());
      }

      // Firestoreへの書き込み処理
      if (widget.testPiece == null) {
        // 新規作成
        await firestoreService.addTestPiece(testPieceData);
        if (mounted) {
          _isDirty = false;
          navigator.pop(); // すぐに一覧に戻る
        }
      } else {
        // 更新
        await firestoreService.updateTestPiece(testPieceData);
        if (mounted) {
          _isDirty = false;
          navigator.pop(); // すぐに詳細画面に戻る
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
          ..._buildColorSection(),
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
              children: [
                ..._buildFormFields(),
                const SizedBox(height: 24),
                ..._buildColorSection(),
              ],
            ),
          ),
        ),
        const VerticalDivider(width: 1),
        // 右半分: 画像とグラフ
        Expanded(
          flex: 1,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 80.0),
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
      // 釉薬選択 (Primary)
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
          decoration: InputDecoration(labelText: "釉薬名 (メイン)"),
        ),
        validator: (Glaze? item) => item == null ? "釉薬を選択してください" : null,
        compareFn: (Glaze a, Glaze b) => a.id == b.id,
      ),
      const SizedBox(height: 16),
      
      // 追加の釉薬 (Additional)
      DropdownSearch<Glaze>.multiSelection(
        items: (f, cs) => _availableGlazes,
        itemAsString: (Glaze g) => g.name,
        selectedItems: _availableGlazes
            .where((g) => _additionalGlazeIds.contains(g.id))
            .toList(),
        onChanged: (List<Glaze> data) {
          _markAsDirty();
          setState(() {
            _additionalGlazeIds = data.map((g) => g.id!).toList();
          });
        },
        popupProps: PopupPropsMultiSelection.menu(
          showSearchBox: true,
          searchFieldProps: TextFieldProps(
            decoration: InputDecoration(
              border: const OutlineInputBorder(),
              contentPadding: const EdgeInsets.fromLTRB(12, 12, 8, 0),
              labelText: "追加の釉薬を検索",
              hintText: "釉薬名を入力...",
            ),
            autofocus: false,
          ),
        ),
        decoratorProps: const DropDownDecoratorProps(
          decoration: InputDecoration(labelText: "追加の釉薬 (重ね掛けなど)"),
        ),
        compareFn: (Glaze a, Glaze b) => a.id == b.id,
      ),
      const SizedBox(height: 16),

      // 素地土名選択
      DropdownSearch<Clay>(
        items: (f, cs) => _availableClays,
        itemAsString: (Clay c) => c.name,
        selectedItem: (_selectedClayId != null && _availableClays.isNotEmpty)
            ? _availableClays.where((c) => c.id == _selectedClayId).firstOrNull
            : null,
        onChanged: (Clay? data) {
          _markAsDirty();
          setState(() {
            _selectedClayId = data?.id;
          });
        },
        popupProps: PopupProps.menu(
          showSearchBox: true,
          searchFieldProps: TextFieldProps(
            decoration: InputDecoration(
              border: const OutlineInputBorder(),
              contentPadding: const EdgeInsets.fromLTRB(12, 12, 8, 0),
              labelText: "素地土名を検索",
              hintText: "素地土名を入力...",
            ),
            autofocus: true,
          ),
        ),
        decoratorProps: const DropDownDecoratorProps(
          decoration: InputDecoration(labelText: "素地土名"),
        ),
        validator: (Clay? item) => item == null ? "素地土名を選択してください" : null,
        compareFn: (Clay a, Clay b) => a.id == b.id,
      ),
      const SizedBox(height: 16),
      // 焼成雰囲気
      DropdownButtonFormField<String>(
        decoration: const InputDecoration(labelText: '焼成雰囲気'),
        initialValue: _selectedFiringAtmosphereId,
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
        initialValue: _selectedFiringProfileId,
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
      const SizedBox(height: 16),
      // 備考
      TextFormField(
        controller: _noteController,
        decoration: const InputDecoration(
          labelText: '備考',
          border: OutlineInputBorder(),
        ),
        maxLines: 3,
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
    if (_newImageBytes != null) {
      return Image.memory(_newImageBytes!, fit: BoxFit.contain);
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

  /// 色編集セクションのウィジェットリストを生成
  List<Widget> _buildColorSection() {
    return [
      Text('テストピースの色', style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: 8),
      _buildColorSwatches(),
      const SizedBox(height: 8),
      OutlinedButton.icon(
        icon: const Icon(Icons.add),
        label: const Text('色を追加'),
        onPressed: _addColor,
      ),
    ];
  }

  /// 色見本ウィジェットを生成
  Widget _buildColorSwatches() {
    if (_colorData.isEmpty) {
      return const Text('色が登録されていません。');
    }
    return Wrap(
      spacing: 8.0,
      runSpacing: 8.0,
      children: _colorData.map((swatch) {
        return Chip(
          label: const SizedBox.shrink(), // ラベルは不要
          avatar: CircleAvatar(backgroundColor: swatch.toColor(), radius: 12),
          onDeleted: () {
            setState(() {
              _colorData.remove(swatch);
              _markAsDirty();
            });
          },
          deleteIcon: const Icon(Icons.close, size: 16),
          padding: const EdgeInsets.all(2),
        );
      }).toList(),
    );
  }

  /// 色を追加する処理
  Future<void> _addColor() async {
    Color selectedColor = Colors.white;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('色の選択'),
          // 高機能なColorPickerに変更
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
              child: const Text('追加'),
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      // RGB to Lab 変換
      final lab = ColorSwatch.fromColor(selectedColor);
      setState(() {
        // percentageは手動追加では0とする
        _colorData.add(
          ColorSwatch(l: lab.l, a: lab.a, b: lab.b, percentage: 0),
        );
        _markAsDirty();
      });
    }
  }
}

