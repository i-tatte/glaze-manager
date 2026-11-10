import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:glaze_manager/models/clay.dart';
import 'package:glaze_manager/models/lab_color.dart';
import 'package:flutter/material.dart';
import 'package:glaze_manager/models/glaze.dart';
import 'package:glaze_manager/models/firing.dart';
import 'package:glaze_manager/models/firing_profile.dart';
import 'package:glaze_manager/models/firing_atmosphere.dart';
import 'package:glaze_manager/models/recipe_snapshot.dart';
import 'package:glaze_manager/models/test_piece.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart'
    show ConsumerStatefulWidget, ConsumerState, AsyncValueX;
import 'package:glaze_manager/providers/data_providers.dart';
import 'package:glaze_manager/screens/color_pick_screen.dart';
import 'package:glaze_manager/screens/firing_edit_screen.dart';
import 'package:glaze_manager/screens/image_crop_screen.dart';
import 'package:image_picker/image_picker.dart';
import 'package:dropdown_search/dropdown_search.dart';
import 'package:glaze_manager/widgets/firing_chart.dart';
import 'package:uuid/uuid.dart';
import 'package:path/path.dart' as p;
import 'package:glaze_manager/widgets/common/unsaved_changes_pop_scope.dart';
import 'package:glaze_manager/widgets/common/common_app_bar_actions.dart';
import 'package:glaze_manager/widgets/common/info_tile.dart';
import 'package:glaze_manager/widgets/common/rating_stars.dart';

class TestPieceEditScreen extends ConsumerStatefulWidget {
  final TestPiece? testPiece;

  /// 新規作成のときに最初から選んでおく焼成回 (焼成回の詳細画面から開くとき)
  final String? initialFiringId;

  const TestPieceEditScreen({super.key, this.testPiece, this.initialFiringId});

  @override
  ConsumerState<TestPieceEditScreen> createState() =>
      _TestPieceEditScreenState();
}

class _TestPieceEditScreenState extends ConsumerState<TestPieceEditScreen> {
  final _formKey = GlobalKey<FormState>();

  String? _selectedGlazeId;
  List<String> _additionalGlazeIds = [];
  String? _selectedClayId;
  String? _selectedFiringProfileId;
  String? _selectedFiringAtmosphereId;
  String? _selectedFiringId;
  final _noteController = TextEditingController();
  final _labelController = TextEditingController();
  int? _rating;

  // ドロップダウンの選択肢 (buildでプロバイダから更新される)
  List<FiringProfile> _availableFiringProfiles = [];
  List<FiringAtmosphere> _availableFiringAtmospheres = [];
  List<Clay> _availableClays = [];
  List<Glaze> _availableGlazes = [];
  List<Firing> _availableFirings = [];

  String? _newImageFileName; // 新しく生成されたファイル名
  Uint8List? _newImageBytes; // 新しく生成された画像のバイトデータ
  String? _networkImageUrl; // 既存の画像のURL
  List<LabColor> _colorData = []; // 編集用の色データ
  bool _colorsDirty = false; // 色を編集した、または新しい画像を選んだ

  bool _isDirty = false;
  // グラフ表示用の状態
  bool _isChartVisible = false;

  @override
  void initState() {
    super.initState();
    _selectedGlazeId = widget.testPiece?.glazeId;
    _additionalGlazeIds = widget.testPiece?.additionalGlazeIds.toList() ?? [];
    _selectedClayId = widget.testPiece?.clayId;
    _selectedFiringAtmosphereId = widget.testPiece?.firingAtmosphereId;
    _selectedFiringProfileId = widget.testPiece?.firingProfileId;
    _selectedFiringId = widget.testPiece != null
        ? widget.testPiece!.firingId
        : widget.initialFiringId;
    _networkImageUrl = widget.testPiece?.imageUrl;
    _colorData = List<LabColor>.from(widget.testPiece?.colorData ?? []);
    _noteController.text = widget.testPiece?.note ?? '';
    _labelController.text = widget.testPiece?.label ?? '';
    _rating = widget.testPiece?.rating;

    _noteController.addListener(_markAsDirty);
    _labelController.addListener(_markAsDirty);
  }

  void _markAsDirty() {
    if (!_isDirty) {
      setState(() => _isDirty = true);
    }
  }

  @override
  void dispose() {
    _noteController.dispose();
    _labelController.dispose();
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
      if (!mounted) return;
      // 画像選択後、トリミング画面に遷移
      // UUIDと元の拡張子を使って一意なファイル名を生成
      final uuid = const Uuid().v4();
      final extension = p.extension(image.name);
      final newFileName = '$uuid$extension';

      // ファイル名とバイトデータを受け取る
      final cropResult = await Navigator.of(context)
          .push<({String fileName, Uint8List bytes})>(
            MaterialPageRoute(
              builder: (context) =>
                  ImageCropScreen(image: image, outputFileName: newFileName),
            ),
          );

      if (cropResult != null) {
        setState(() {
          _newImageFileName = cropResult.fileName;
          _newImageBytes = cropResult.bytes;
          _networkImageUrl = null; // プレビューを新しい画像に切り替える
          // 旧画像の色は新画像には無意味なのでクリアする。
          // 保存時に空のままなら Cloud Functions が新画像の解析結果を書き込み、
          // スポイトで色を追加していればその色が優先される (colorData契約)。
          _colorData = [];
          _colorsDirty = true;
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

    final navigator = Navigator.of(context);
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    try {
      final firestoreService = ref.read(firestoreServiceProvider);
      final storageService = ref.read(storageServiceProvider);

      final hasNewImage = _newImageFileName != null && _newImageBytes != null;

      final docId =
          widget.testPiece?.id ?? firestoreService.createTestPieceId();

      String? imagePath;
      if (hasNewImage) {
        imagePath = storageService.getUploadPath(
          testPieceId: docId,
          name: _newImageFileName!,
        );
      } else {
        imagePath = widget.testPiece?.imagePath;
      }

      // 調合の写し。新規作成では常に取る。更新では釉薬・追加釉薬・素地土の
      // いずれかが変わったとき、または写しがまだないときだけ取り直す。
      final original = widget.testPiece;
      final needsSnapshot =
          original == null ||
          original.snapshot == null ||
          original.glazeId != _selectedGlazeId ||
          !listEquals(original.additionalGlazeIds, _additionalGlazeIds) ||
          original.clayId != _selectedClayId;
      final snapshot = needsSnapshot
          ? TestPieceSnapshot.capture(
              glazeId: _selectedGlazeId!,
              additionalGlazeIds: _additionalGlazeIds,
              clayId: _selectedClayId!,
              glazeMap: ref.read(glazeMapProvider),
              materialMap: ref.read(materialMapProvider),
              clayMap: ref.read(clayMapProvider),
              source: SnapshotSource.saved,
              previous: original?.snapshot,
            )
          : original.snapshot;

      final testPieceData = TestPiece(
        id: docId,
        glazeId: _selectedGlazeId!,
        additionalGlazeIds: _additionalGlazeIds,
        clayId: _selectedClayId!,
        imageUrl: widget.testPiece?.imageUrl,
        imagePath: imagePath,
        thumbnailUrl: widget.testPiece?.thumbnailUrl,
        // 焼成回を選んでいれば焼成の情報は焼成回を正とし、
        // テストピースごとの焼成雰囲気・焼成プロファイルは持たない
        firingAtmosphereId: _selectedFiringId == null
            ? _selectedFiringAtmosphereId
            : null,
        colorData: List<LabColor>.of(_colorData),
        firingProfileId: _selectedFiringId == null
            ? _selectedFiringProfileId
            : null,
        firingId: _selectedFiringId,
        note: _noteController.text.trim().isEmpty
            ? null
            : _noteController.text.trim(),
        createdAt: widget.testPiece?.createdAt ?? Timestamp.now(),
        snapshot: snapshot,
        rating: _rating,
        label: _labelController.text.trim().isEmpty
            ? null
            : _labelController.text.trim(),
      );

      // §2.3 順序制約: サーバーACK後にアップロード開始 (UIはブロックしない)
      final writeFuture = (widget.testPiece == null)
          ? firestoreService.setTestPiece(docId, testPieceData)
          : firestoreService.updateTestPieceFields(
              docId,
              testPieceData.toUpdateFields(
                includeImagePath: hasNewImage,
                includeColorData: _colorsDirty,
                includeSnapshot: needsSnapshot,
              ),
            );

      if (hasNewImage) {
        final fileName = _newImageFileName!;
        final bytes = _newImageBytes!;
        writeFuture
            .then(
              (_) => storageService.uploadTestPieceImage(
                testPieceId: docId,
                name: fileName,
                bytes: bytes,
                mimeType: 'image/jpeg',
              ),
            )
            .catchError((Object e) {
              scaffoldMessenger.showSnackBar(
                SnackBar(content: Text('保存に失敗しました: $e')),
              );
            });
      } else {
        writeFuture.catchError((Object e) {
          scaffoldMessenger.showSnackBar(
            SnackBar(content: Text('保存に失敗しました: $e')),
          );
        });
      }

      _isDirty = false;
      navigator.pop();
    } catch (e) {
      if (mounted) {
        scaffoldMessenger.showSnackBar(
          SnackBar(content: Text('保存に失敗しました: $e')),
        );
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
        final firestoreService = ref.read(firestoreServiceProvider);
        final storageService = ref.read(storageServiceProvider);

        // Storageから画像とサムネイルを削除 (並行処理)
        // 新形式 (docIdフォルダ) はフォルダごと、旧形式はURL指定で削除する
        final deleteFutures = <Future>[
          storageService.deleteAllTestPieceFiles(widget.testPiece!.id!),
        ];
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
        await Future.wait(deleteFutures);

        // Firestoreからドキュメントを削除
        await firestoreService.deleteTestPiece(widget.testPiece!.id!);

        if (mounted) {
          // 編集画面と詳細画面を閉じて一覧画面まで戻る
          int count = 0;
          navigator.popUntil((_) => count++ >= 2);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('削除に失敗しました: $e')));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // ドロップダウンの選択肢をプロバイダから取得 (データ更新で自動反映)
    _availableGlazes = ref.watch(glazesProvider).valueOrNull ?? [];
    _availableClays = ref.watch(claysProvider).valueOrNull ?? [];
    _availableFiringProfiles =
        ref.watch(firingProfilesProvider).valueOrNull ?? [];
    _availableFiringAtmospheres =
        ref.watch(firingAtmospheresProvider).valueOrNull ?? [];
    _availableFirings = ref.watch(firingsProvider).valueOrNull ?? [];
    // 保存時に調合の写しを作るため、原料の購読を保っておく
    ref.watch(materialMapProvider);

    return UnsavedChangesPopScope(isDirty: _isDirty, child: _buildScaffold());
  }

  Widget _buildScaffold() {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.testPiece == null ? 'テストピースの新規作成' : 'テストピースの編集'),
        actions: [
          CommonAppBarActions(
            onDelete: widget.testPiece != null ? _confirmDelete : null,
            onSave: _saveTestPiece,
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
          ..._buildImageSection(),
          const SizedBox(height: 24),
          ..._buildFormFields(),
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
              children: [..._buildFormFields()],
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
      // 番号
      TextFormField(
        controller: _labelController,
        decoration: const InputDecoration(
          labelText: '番号',
          hintText: '実物に書いた番号（任意）',
        ),
      ),
      const SizedBox(height: 16),
      // 評価
      Row(
        children: [
          Text('評価', style: Theme.of(context).textTheme.bodyLarge),
          const SizedBox(width: 16),
          RatingStars(
            rating: _rating,
            onChanged: (value) {
              setState(() => _rating = value);
              _markAsDirty();
            },
          ),
        ],
      ),
      const SizedBox(height: 16),
      // 焼成回
      DropdownButtonFormField<String?>(
        decoration: const InputDecoration(labelText: '焼成回'),
        initialValue: _selectedFiringId,
        isExpanded: true,
        items: [
          const DropdownMenuItem<String?>(value: null, child: Text('（なし）')),
          for (final firing in _availableFirings)
            DropdownMenuItem<String?>(
              value: firing.id,
              child: Text(firing.displayLabel),
            ),
          // 選択中の焼成回が選択肢にない (削除済み、または読み込み前) ときは
          // 「不明な焼成回」を足す。初期値が選択肢にないとアサーションで落ちるため
          if (_selectedFiringId != null &&
              !_availableFirings.any((f) => f.id == _selectedFiringId))
            DropdownMenuItem<String?>(
              value: _selectedFiringId,
              child: const Text('不明な焼成回'),
            ),
        ],
        onChanged: (value) {
          _markAsDirty();
          setState(() => _selectedFiringId = value);
        },
      ),
      Align(
        alignment: Alignment.centerLeft,
        child: TextButton(
          onPressed: _createFiring,
          child: const Text('焼成回を新規作成'),
        ),
      ),
      const SizedBox(height: 8),
      if (_selectedFiringId != null) ...[
        // 焼成回を選んでいるときは、焼成回の雰囲気とプロファイルを読み取り専用で出す
        InfoTile(label: '焼成雰囲気', value: _firingAtmosphereLabel()),
        InfoTile(label: '焼成プロファイル', value: _firingProfileLabel()),
        const SizedBox(height: 16),
      ] else ...[
        // 焼成雰囲気
        DropdownButtonFormField<String?>(
          decoration: const InputDecoration(labelText: '焼成雰囲気'),
          initialValue: _selectedFiringAtmosphereId,
          hint: const Text('焼成雰囲気を選択 (任意)'),
          isExpanded: true,
          items: atmosphereItems(
            _availableFiringAtmospheres,
            _selectedFiringAtmosphereId,
          ),
          onChanged: (value) {
            _markAsDirty();
            setState(() => _selectedFiringAtmosphereId = value);
          },
          validator: null,
        ),
        const SizedBox(height: 16),
        // 焼成プロファイル
        DropdownButtonFormField<String?>(
          decoration: const InputDecoration(labelText: '焼成プロファイル'),
          initialValue: _selectedFiringProfileId,
          hint: const Text('焼成プロファイルを選択 (任意)'),
          isExpanded: true,
          items: profileItems(
            _availableFiringProfiles,
            _selectedFiringProfileId,
          ),
          onChanged: (value) {
            _markAsDirty();
            setState(() => _selectedFiringProfileId = value);
          },
          validator: null,
        ),
        const SizedBox(height: 16),
      ],
      // 備考
      TextFormField(
        controller: _noteController,
        decoration: const InputDecoration(
          labelText: '備考\n\n\n',
          border: OutlineInputBorder(),
        ),
        maxLines: 3,
      ),
      const SizedBox(height: 16),
      // 色編集セクション
      ..._buildColorSection(),

      // グラフ表示エリア (焼成回を選んでいるときは出さない)
      if (_selectedFiringId == null &&
          selectedProfile?.curveData != null &&
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
          child: FiringChart.fromProfile(selectedProfile),
        ),
      ],
    ];
  }

  /// 焼成回をその場で作り、作った焼成回を選ぶ
  Future<void> _createFiring() async {
    final id = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (context) => const FiringEditScreen()),
    );
    if (id == null || !mounted) return;
    _markAsDirty();
    setState(() => _selectedFiringId = id);
  }

  Firing? get _selectedFiring =>
      _availableFirings.where((f) => f.id == _selectedFiringId).firstOrNull;

  /// 選んだ焼成回の雰囲気名。現存すれば現在の名前、なければ焼成回の写し
  String _firingAtmosphereLabel() {
    final firing = _selectedFiring;
    if (firing == null) return '不明';
    final name =
        _availableFiringAtmospheres
            .where((a) => a.id == firing.firingAtmosphereId)
            .firstOrNull
            ?.name ??
        firing.atmosphereName;
    return name ?? '未設定';
  }

  /// 選んだ焼成回のプロファイル名。現存すれば現在の名前、なければ焼成回の写し
  String _firingProfileLabel() {
    final firing = _selectedFiring;
    if (firing == null) return '不明';
    final name =
        _availableFiringProfiles
            .where((p) => p.id == firing.firingProfileId)
            .firstOrNull
            ?.name ??
        firing.profile?.name;
    return name ?? '未設定';
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
    final hasImage = _newImageBytes != null || _networkImageUrl != null;
    return [
      Text('テストピースの色', style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: 8),
      _buildLabColores(),
      const SizedBox(height: 8),
      OutlinedButton.icon(
        icon: const Icon(Icons.colorize),
        label: const Text('スポイトで追加'),
        onPressed: hasImage ? _pickColorsWithEyedropper : null,
      ),
      if (!hasImage)
        Padding(
          padding: const EdgeInsets.only(top: 4.0),
          child: Text(
            '画像を選択するとスポイトで色を追加できます。',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
    ];
  }

  /// 色見本ウィジェットを生成
  Widget _buildLabColores() {
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
              _colorsDirty = true;
              _markAsDirty();
            });
          },
          deleteIcon: const Icon(Icons.close, size: 16),
          padding: const EdgeInsets.all(2),
        );
      }).toList(),
    );
  }

  /// スポイト画面で画像から色を選び、色リストに追加する
  Future<void> _pickColorsWithEyedropper() async {
    final ImageProvider provider;
    if (_newImageBytes != null) {
      provider = MemoryImage(_newImageBytes!);
    } else if (_networkImageUrl != null) {
      provider = CachedNetworkImageProvider(_networkImageUrl!);
    } else {
      return;
    }

    final pickedColors = await Navigator.of(context).push<List<Color>>(
      MaterialPageRoute(
        builder: (context) => ColorPickScreen(
          imageProvider: provider,
          mode: ColorPickMode.multi,
          // 既存の色と被っていないか画面内で確認できるよう参照表示する
          existingColors: _colorData.map((lab) => lab.toColor()).toList(),
        ),
      ),
    );

    if (pickedColors == null || pickedColors.isEmpty || !mounted) return;

    setState(() {
      _colorsDirty = true;
      for (final color in pickedColors) {
        // RGB to Lab 変換。percentageは手動追加では0とする
        final lab = LabColor.fromColor(color);
        _colorData.add(LabColor(l: lab.l, a: lab.a, b: lab.b, percentage: 0));
      }
      _markAsDirty();
    });
  }
}
