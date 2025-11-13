import 'package:flutter/material.dart';
import 'package:glaze_manager/models/firing_profile.dart';
import 'package:glaze_manager/services/firestore_service.dart';
import 'package:glaze_manager/widgets/firing_chart.dart';
import 'package:provider/provider.dart';

class FiringProfileEditScreen extends StatefulWidget {
  final FiringProfile? profile;

  const FiringProfileEditScreen({super.key, this.profile});

  @override
  State<FiringProfileEditScreen> createState() =>
      _FiringProfileEditScreenState();
}

class _FiringProfileEditScreenState extends State<FiringProfileEditScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _curveDataController;
  bool _isLoading = false;
  bool _isDirty = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.profile?.name ?? '');
    _curveDataController = TextEditingController(
      text: widget.profile?.curveData ?? '',
    );
    _nameController.addListener(_markAsDirty);
    _curveDataController.addListener(_onCurveDataChanged);
  }

  void _markAsDirty() {
    if (!_isDirty) setState(() => _isDirty = true);
  }

  void _onCurveDataChanged() {
    _markAsDirty();
    setState(() {}); // テキストが変更されたらUIを再描画してグラフを更新
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);
    final navigator = Navigator.of(context);

    try {
      final firestoreService = context.read<FirestoreService>();
      final profile = FiringProfile(
        id: widget.profile?.id,
        name: _nameController.text,
        curveData: _curveDataController.text,
      );

      if (widget.profile == null) {
        await firestoreService.addFiringProfile(profile);
      } else {
        await firestoreService.updateFiringProfile(profile);
      }

      _isDirty = false;
      navigator.pop();
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

  @override
  void dispose() {
    _nameController.dispose();
    _curveDataController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // PopScopeのonPopInvokedはdidPopがfalseの時のみ呼ばれるため、
      // isDirtyがfalseの場合でも手動でpopを呼ぶ必要がある。
      // そのロジックを_onPopInvokedにまとめる。
      canPop: !_isDirty,
      onPopInvoked: (didPop) async {
        if (didPop) return;
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
      },
      child: _buildScaffold(),
    );
  }

  Widget _buildScaffold() {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.profile == null ? 'プロファイルの新規作成' : 'プロファイルの編集'),
        actions: [
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: CircularProgressIndicator(),
            )
          else
            IconButton(icon: const Icon(Icons.save), onPressed: _saveProfile),
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
          _buildChart(),
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
        // 右半分: グラフ
        Expanded(
          flex: 1,
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: _buildChart(),
            ),
          ),
        ),
      ],
    );
  }

  /// フォーム部分のウィジェットリストを生成
  List<Widget> _buildFormFields() {
    return [
      TextFormField(
        controller: _nameController,
        decoration: const InputDecoration(labelText: 'プロファイル名'),
        validator: (value) =>
            (value == null || value.isEmpty) ? '名前を入力してください' : null,
      ),
      const SizedBox(height: 24),
      TextFormField(
        controller: _curveDataController,
        decoration: const InputDecoration(
          labelText: '焼成データ (焼成開始からの経過時間(分),温度(℃)をカンマ区切りで入力)',
          hintText: '例(素焼き900℃炙りなし):\n240,400\n420,900\n480,900',
          alignLabelWithHint: true,
          border: OutlineInputBorder(),
        ),
        maxLines: 10,
        keyboardType: TextInputType.multiline,
        validator: (value) {
          if (value == null || value.trim().isEmpty) {
            return null; // 入力は任意
          }
          final lines = value.trim().split('\n');
          for (var i = 0; i < lines.length; i++) {
            final line = lines[i].trim();
            if (line.isEmpty) continue; // 空行は無視
            final parts = line.split(',');
            if (parts.length != 2 ||
                double.tryParse(parts[0].trim()) == null ||
                double.tryParse(parts[1].trim()) == null) {
              return '${i + 1}行目の形式が正しくありません (例: 30,100)';
            }
          }
          return null;
        },
      ),
    ];
  }

  Widget _buildChart() {
    final curveData = _curveDataController.text;

    if (curveData.trim().isEmpty) {
      return Container(
        height: 250,
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey[400]!),
        ),
        child: const Center(
          child: Text(
            '焼成データを入力すると\nここにグラフが表示されます',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey),
          ),
        ),
      );
    }

    // FiringChartウィジェットを再利用
    return FiringChart(curveData: curveData);
  }
}
