import 'dart:io';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
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

  bool _isLoading = false;
  bool _isDirty = false;
  // グラフ表示用の状態
  bool _isChartVisible = false;
  List<FlSpot> _spots = [];

  @override
  void initState() {
    super.initState();
    _clayNameController.text = widget.testPiece?.clayName ?? '';
    _selectedGlazeId = widget.testPiece?.glazeId;
    _selectedFiringAtmosphereId = widget.testPiece?.firingAtmosphereId;
    _selectedFiringProfileId = widget.testPiece?.firingProfileId;
    _networkImageUrl = widget.testPiece?.imageUrl;

    _clayNameController.addListener(_markAsDirty);

    _loadDropdownData().then((_) {
      // 初期データでグラフを更新
      _updateChartDataForSelectedProfile(_selectedFiringProfileId);
    });
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

  void _updateChartDataForSelectedProfile(String? profileId) {
    if (profileId == null) {
      setState(() => _spots = []);
      return;
    }
    try {
      final selectedProfile = _availableFiringProfiles.firstWhere(
        (p) => p.id == profileId,
      );
      _updateChartData(selectedProfile.curveData);
    } catch (e) {
      // プロファイルが見つからない場合など
      setState(() => _spots = []);
    }
  }

  void _updateChartData(String? text) {
    final List<FlSpot> newSpots = [const FlSpot(0, 20)]; // 開始点 (室温20℃と仮定)
    if (text == null || text.trim().isEmpty) {
      setState(() => _spots = []);
      return;
    }

    double lastTime = 0;
    final lines = text.trim().split('\n');
    for (final line in lines) {
      final parts = line.trim().split(',');
      if (parts.length == 2) {
        final time = double.tryParse(parts[0].trim());
        final temp = double.tryParse(parts[1].trim());

        if (time != null && temp != null && time > lastTime) {
          newSpots.add(FlSpot(time / 60.0, temp)); // 分を時間に変換
          lastTime = time;
        }
      }
    }

    setState(() => _spots = newSpots.length > 1 ? newSpots : []);
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
        setState(() {
          _imageFile = croppedImage;
          _markAsDirty(); // トリミングされた画像が設定されたらダーティ
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

      // 新しい画像が選択されていればアップロード
      if (_imageFile != null) {
        try {
          imageUrl = await storageService
              .uploadTestPieceImage(_imageFile!)
              .timeout(const Duration(seconds: 15));
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
        createdAt: widget.testPiece?.createdAt ?? Timestamp.now(),
      );

      if (widget.testPiece == null) {
        firestoreService.addTestPiece(testPiece);
      } else {
        firestoreService.updateTestPiece(testPiece);
      }

      if (mounted) {
        _isDirty = false; // 保存成功でダーティ状態をリセット
      }
      navigator.pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('保存に失敗しました: $e')));
      }
      // エラー発生時は一覧画面に戻る
      navigator.pop();
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
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
            IconButton(icon: const Icon(Icons.save), onPressed: _saveTestPiece),
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
    return [
      // 釉薬選択
      DropdownSearch<Glaze>(
        items: (f, cs) => _availableGlazes,
        itemAsString: (Glaze g) => g.name,
        selectedItem: _selectedGlazeId != null
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
          _updateChartDataForSelectedProfile(value);
        },
        validator: null,
      ),
      // グラフ表示エリア
      if (_selectedFiringProfileId != null && _spots.isNotEmpty) ...[
        const Divider(),
        const SizedBox(height: 8),
        TextButton.icon(
          icon: Icon(_isChartVisible ? Icons.visibility_off : Icons.visibility),
          label: Text(_isChartVisible ? '焼成温度曲線を隠す' : '焼成温度曲線を表示'),
          onPressed: () {
            setState(() => _isChartVisible = !_isChartVisible);
          },
        ),
        Visibility(visible: _isChartVisible, child: _buildChart()),
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
      return Image.file(File(_imageFile!.path), fit: BoxFit.contain);
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

  Widget _buildChart() {
    final double ymax = 1400;
    final double ymin = 0;
    return AspectRatio(
      aspectRatio: 1.5,
      child: Padding(
        padding: const EdgeInsets.only(right: 18.0, top: 24.0, bottom: 12.0),
        child: LineChart(
          LineChartData(
            rangeAnnotations: RangeAnnotations(
              horizontalRangeAnnotations: [
                // 100-200℃の領域(炙り領域)
                HorizontalRangeAnnotation(
                  y1: 100,
                  y2: 200,
                  color: Colors.lightGreen.withValues(alpha: 0.2),
                ),
                // 800-1200℃の領域(素焼き領域)
                HorizontalRangeAnnotation(
                  y1: 800,
                  y2: 1200,
                  color: Colors.yellow.withValues(alpha: 0.2),
                ),
                // 1200-1300℃の領域(本焼き領域)
                HorizontalRangeAnnotation(
                  y1: 1200,
                  y2: 1300, // グラフの最大Y値より大きい値を設定
                  color: Colors.orange.withValues(alpha: 0.2),
                ),
                // 1300℃以上の領域(高温領域)
                HorizontalRangeAnnotation(
                  y1: 1300,
                  y2: ymax, // グラフの最大Y値と同じ値を設定
                  color: Colors.red.withValues(alpha: 0.2),
                ),
              ],
            ),
            gridData: FlGridData(
              show: true,
              drawVerticalLine: true,
              getDrawingHorizontalLine: (value) =>
                  const FlLine(color: Colors.black12, strokeWidth: 1),
              getDrawingVerticalLine: (value) =>
                  const FlLine(color: Colors.black12, strokeWidth: 1),
            ),
            titlesData: const FlTitlesData(
              rightTitles: AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(showTitles: true, reservedSize: 30),
                axisNameWidget: Text("時間 (h)"),
              ),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(showTitles: true, reservedSize: 40),
                axisNameWidget: Text("温度 (°C)"),
                axisNameSize: 24,
              ),
            ),
            borderData: FlBorderData(
              show: true,
              border: Border.all(color: const Color(0xff37434d), width: 1),
            ),
            lineTouchData: LineTouchData(
              touchTooltipData: LineTouchTooltipData(
                getTooltipItems: (touchedSpots) {
                  return touchedSpots.map((spot) {
                    return LineTooltipItem(
                      '${(spot.x).toStringAsFixed(0)} 時間\n${spot.y.toStringAsFixed(0)} °C',
                      const TextStyle(color: Colors.white),
                    );
                  }).toList();
                },
              ),
            ),
            lineBarsData: [
              LineChartBarData(
                spots: _spots,
                isCurved: false,
                color: Theme.of(context).primaryColor,
                barWidth: 3,
                dotData: const FlDotData(show: true),
              ),
            ],
            minY: ymin,
            maxY: ymax,
          ),
        ),
      ),
    );
  }
}
