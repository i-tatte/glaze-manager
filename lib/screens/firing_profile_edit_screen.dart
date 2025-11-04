import 'package:flutter/material.dart';
import 'package:glaze_manager/models/firing_profile.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:glaze_manager/services/firestore_service.dart';
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
  List<FlSpot> _spots = [];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.profile?.name ?? '');
    _curveDataController = TextEditingController(
      text: widget.profile?.curveData ?? '',
    );
    _nameController.addListener(_markAsDirty);
    _curveDataController.addListener(_onCurveDataChanged);

    // 初期データでグラフを更新
    _updateChartData(_curveDataController.text);
  }

  void _markAsDirty() {
    if (!_isDirty) setState(() => _isDirty = true);
  }

  void _onCurveDataChanged() {
    _markAsDirty();
    _updateChartData(_curveDataController.text);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _curveDataController.dispose();
    super.dispose();
  }

  void _updateChartData(String text) {
    final List<FlSpot> newSpots = [const FlSpot(0, 20)]; // 開始点 (室温20℃と仮定)
    double lastTime = 0;

    if (text.trim().isEmpty) {
      setState(() => _spots = []); // データがなければグラフをクリア
      return;
    }

    final lines = text.trim().split('\n');
    for (final line in lines) {
      final parts = line.trim().split(',');
      if (parts.length == 2) {
        final time = double.tryParse(parts[0].trim());
        final temp = double.tryParse(parts[1].trim());

        // 時間と温度が正しくパースでき、かつ前の値より大きい場合のみ追加
        if (time != null && temp != null && time > lastTime) {
          newSpots.add(FlSpot(time / 60.0, temp));
          lastTime = time;
        }
      }
    }

    // 2点以上ないとグラフは描画できない
    if (newSpots.length > 1) {
      setState(() => _spots = newSpots);
    }
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
  Widget build(BuildContext context) {
    return PopScope(
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
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.profile == null ? 'プリセットの新規作成' : 'プリセットの編集'),
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
        body: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16.0),
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'プリセット名'),
                validator: (value) =>
                    (value == null || value.isEmpty) ? '名前を入力してください' : null,
              ),
              const SizedBox(height: 24),
              _buildChart(), // グラフ表示ウィジェット
              const SizedBox(height: 24),
              TextFormField(
                controller: _curveDataController,
                decoration: const InputDecoration(
                  labelText: '焼成データ (焼成開始からの経過時間(分),温度)',
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
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChart() {
    if (_spots.length < 2) {
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

    return AspectRatio(
      aspectRatio: 2.0,
      child: Padding(
        padding: const EdgeInsets.only(right: 18.0, top: 10.0),
        child: LineChart(
          LineChartData(
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
            lineBarsData: [
              LineChartBarData(
                spots: _spots,
                isCurved: false,
                color: Theme.of(context).primaryColor,
                barWidth: 3,
                isStrokeCapRound: true,
                dotData: const FlDotData(show: true),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
