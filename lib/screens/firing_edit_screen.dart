import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart'
    show ConsumerStatefulWidget, ConsumerState, AsyncValueX;
import 'package:glaze_manager/models/firing.dart';
import 'package:glaze_manager/models/firing_atmosphere.dart';
import 'package:glaze_manager/models/firing_profile.dart';
import 'package:glaze_manager/providers/data_providers.dart';
import 'package:glaze_manager/utils/date_format.dart';
import 'package:glaze_manager/widgets/common/common_app_bar_actions.dart';
import 'package:glaze_manager/widgets/common/unsaved_changes_pop_scope.dart';
import 'package:glaze_manager/widgets/firing_chart.dart';

/// 焼成回の新規作成・編集。
///
/// 新規作成のときは、保存した焼成回の ID を `Navigator.pop` の戻り値として返す
/// (テストピースの編集画面から焼成回をその場で作る流れで使う)。
class FiringEditScreen extends ConsumerStatefulWidget {
  final Firing? firing;

  const FiringEditScreen({super.key, this.firing});

  @override
  ConsumerState<FiringEditScreen> createState() => _FiringEditScreenState();
}

class _FiringEditScreenState extends ConsumerState<FiringEditScreen> {
  final _formKey = GlobalKey<FormState>();
  late DateTime _firedOn;
  late final TextEditingController _dateController;
  late String _kilnName;
  String? _selectedAtmosphereId;
  String? _selectedProfileId;
  late final TextEditingController _peakTempController;
  late final TextEditingController _coneController;
  late final TextEditingController _noteController;
  bool _isDirty = false;

  @override
  void initState() {
    super.initState();
    final firing = widget.firing;
    _firedOn = firing?.firedOn.toDate() ?? DateTime.now();
    _dateController = TextEditingController(text: formatDate(_firedOn));
    _kilnName = firing?.kilnName ?? '';
    _selectedAtmosphereId = firing?.firingAtmosphereId;
    _selectedProfileId = firing?.firingProfileId;
    _peakTempController = TextEditingController(
      text: firing?.peakTemp?.toString() ?? '',
    );
    _coneController = TextEditingController(text: firing?.cone ?? '');
    _noteController = TextEditingController(text: firing?.note ?? '');

    _peakTempController.addListener(_markAsDirty);
    _coneController.addListener(_markAsDirty);
    _noteController.addListener(_markAsDirty);
  }

  @override
  void dispose() {
    _dateController.dispose();
    _peakTempController.dispose();
    _coneController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _markAsDirty() {
    if (!_isDirty) setState(() => _isDirty = true);
  }

  static String? _trimmedOrNull(String text) {
    final trimmed = text.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _firedOn,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _firedOn = picked;
      _dateController.text = formatDate(picked);
    });
    _markAsDirty();
  }

  void _saveFiring() {
    if (!_formKey.currentState!.validate()) return;

    final navigator = Navigator.of(context);
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    try {
      final firestoreService = ref.read(firestoreServiceProvider);
      final original = widget.firing;

      // 雰囲気はその時点の名前と種類を写す。選択を変えておらず雰囲気が
      // 削除されている場合は、既存の写しを保つ
      String? atmosphereName;
      String? atmosphereType;
      final atmosphere = ref.read(
        firingAtmosphereMapProvider,
      )[_selectedAtmosphereId];
      if (atmosphere != null) {
        atmosphereName = atmosphere.name;
        atmosphereType = atmosphere.type.name;
      } else if (_selectedAtmosphereId != null &&
          _selectedAtmosphereId == original?.firingAtmosphereId) {
        atmosphereName = original?.atmosphereName;
        atmosphereType = original?.atmosphereType;
      }

      // プロファイルの写しは、新規作成またはプロファイルの選択を変えたときに
      // 現在の内容から作る。選択を変えていない編集では既存の写しを保つ
      final FiringProfileSnapshot? profileSnapshot;
      if (original == null || original.firingProfileId != _selectedProfileId) {
        final profile = ref.read(firingProfileMapProvider)[_selectedProfileId];
        profileSnapshot = profile == null
            ? null
            : FiringProfileSnapshot.capture(profile);
      } else {
        profileSnapshot = original.profile;
      }

      final id = original?.id ?? firestoreService.createFiringId();
      final firing = Firing(
        id: id,
        firedOn: Firing.noonOf(_firedOn),
        kilnName: _trimmedOrNull(_kilnName),
        firingProfileId: _selectedProfileId,
        profile: profileSnapshot,
        firingAtmosphereId: _selectedAtmosphereId,
        atmosphereName: atmosphereName,
        atmosphereType: atmosphereType,
        peakTemp: int.tryParse(_peakTempController.text.trim()),
        cone: _trimmedOrNull(_coneController.text),
        note: _trimmedOrNull(_noteController.text),
        createdAt: original?.createdAt ?? Timestamp.now(),
      );

      final writeFuture = original == null
          ? firestoreService.setFiring(id, firing)
          : firestoreService.updateFiring(firing);
      writeFuture.catchError((Object e) {
        scaffoldMessenger.showSnackBar(
          SnackBar(content: Text('保存に失敗しました: $e')),
        );
      });

      _isDirty = false;
      navigator.pop(original == null ? id : null);
    } catch (e) {
      if (mounted) {
        scaffoldMessenger.showSnackBar(
          SnackBar(content: Text('保存に失敗しました: $e')),
        );
      }
    }
  }

  Future<void> _confirmDelete() async {
    final firing = widget.firing;
    if (firing == null) return;

    // この焼成回を参照するテストピースの数を集計して警告に含める
    final testPieces = await ref.read(testPiecesProvider.future);
    final usedCount = testPieces.where((tp) => tp.firingId == firing.id).length;
    final warning = usedCount > 0
        ? '\n\nこの焼成回は$usedCount件のテストピースで使用されています。\n削除すると、それらの焼成の情報は「不明」になります。'
        : '';

    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('削除の確認'),
        content: Text('「${firing.displayLabel}」を本当に削除しますか？$warning'),
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
    if (confirmed != true || !mounted) return;

    final navigator = Navigator.of(context);
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    try {
      // 画面遷移はサーバーの応答を待たない。失敗は SnackBar で知らせる
      ref.read(firestoreServiceProvider).deleteFiring(firing.id!).catchError((
        Object e,
      ) {
        scaffoldMessenger.showSnackBar(
          SnackBar(content: Text('削除に失敗しました: $e')),
        );
      });
      _isDirty = false;
      // 編集画面と焼成回の詳細画面を閉じる
      int count = 0;
      navigator.popUntil((_) => count++ >= 2);
    } catch (e) {
      scaffoldMessenger.showSnackBar(SnackBar(content: Text('削除に失敗しました: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return UnsavedChangesPopScope(isDirty: _isDirty, child: _buildScaffold());
  }

  Widget _buildScaffold() {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.firing == null ? '焼成回の新規作成' : '焼成回の編集'),
        actions: [
          CommonAppBarActions(
            onDelete: widget.firing != null ? _confirmDelete : null,
            onSave: _saveFiring,
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: _buildFormFields(),
        ),
      ),
    );
  }

  List<Widget> _buildFormFields() {
    final atmospheres = ref.watch(firingAtmospheresProvider).valueOrNull ?? [];
    final profiles = ref.watch(firingProfilesProvider).valueOrNull ?? [];
    final firings = ref.watch(firingsProvider).valueOrNull ?? [];
    final kilnNames = <String>{
      for (final f in firings)
        if (f.kilnName != null) f.kilnName!,
    }.toList();

    return [
      TextFormField(
        controller: _dateController,
        decoration: const InputDecoration(labelText: '焼成日'),
        readOnly: true,
        onTap: _pickDate,
      ),
      const SizedBox(height: 16),
      Autocomplete<String>(
        initialValue: TextEditingValue(text: _kilnName),
        optionsBuilder: (value) {
          final query = value.text.trim().toLowerCase();
          if (query.isEmpty) return kilnNames;
          return kilnNames.where((n) => n.toLowerCase().contains(query));
        },
        onSelected: (value) {
          _kilnName = value;
          _markAsDirty();
        },
        fieldViewBuilder: (context, controller, focusNode, onSubmitted) {
          return TextFormField(
            controller: controller,
            focusNode: focusNode,
            decoration: const InputDecoration(labelText: '窯 (任意)'),
            onChanged: (value) {
              _kilnName = value;
              _markAsDirty();
            },
            onFieldSubmitted: (_) => onSubmitted(),
          );
        },
      ),
      const SizedBox(height: 16),
      DropdownButtonFormField<String?>(
        decoration: const InputDecoration(labelText: '焼成雰囲気'),
        initialValue: _selectedAtmosphereId,
        isExpanded: true,
        items: [
          const DropdownMenuItem<String?>(value: null, child: Text('（なし）')),
          ...atmosphereItems(atmospheres, _selectedAtmosphereId),
        ],
        onChanged: (value) {
          _markAsDirty();
          setState(() => _selectedAtmosphereId = value);
        },
      ),
      const SizedBox(height: 16),
      DropdownButtonFormField<String?>(
        decoration: const InputDecoration(labelText: '焼成プロファイル'),
        initialValue: _selectedProfileId,
        isExpanded: true,
        items: [
          const DropdownMenuItem<String?>(value: null, child: Text('（なし）')),
          ...profileItems(profiles, _selectedProfileId),
        ],
        onChanged: (value) {
          _markAsDirty();
          setState(() => _selectedProfileId = value);
        },
      ),
      ..._buildProfilePreview(profiles),
      const SizedBox(height: 16),
      TextFormField(
        controller: _peakTempController,
        decoration: const InputDecoration(labelText: '最高温度 (℃) (任意)'),
        keyboardType: TextInputType.number,
        validator: (value) {
          if (value == null || value.trim().isEmpty) return null;
          return int.tryParse(value.trim()) == null ? '整数を入力してください' : null;
        },
      ),
      const SizedBox(height: 16),
      TextFormField(
        controller: _coneController,
        decoration: const InputDecoration(labelText: 'コーン (任意)'),
      ),
      const SizedBox(height: 16),
      TextFormField(
        controller: _noteController,
        decoration: const InputDecoration(
          labelText: '所感',
          alignLabelWithHint: true,
          border: OutlineInputBorder(),
        ),
        maxLines: 4,
      ),
    ];
  }

  /// 選んだプロファイルのチャートのプレビュー。
  /// プロファイルが削除されていて選択を変えていなければ、焼成回の写しから描く。
  List<Widget> _buildProfilePreview(List<FiringProfile> profiles) {
    final profile = profiles
        .where((p) => p.id == _selectedProfileId)
        .firstOrNull;
    final FiringChart? chart;
    if (profile != null) {
      chart = (profile.curveData?.isNotEmpty ?? false)
          ? FiringChart.fromProfile(profile)
          : null;
    } else {
      final snapshot = widget.firing?.profile;
      chart =
          (_selectedProfileId != null &&
              _selectedProfileId == widget.firing?.firingProfileId &&
              snapshot != null &&
              (snapshot.curveData?.isNotEmpty ?? false))
          ? FiringChart(
              curveData: snapshot.curveData!,
              isReduction: snapshot.isReduction,
              reductionStartTemp: snapshot.reductionStartTemp,
              reductionEndTemp: snapshot.reductionEndTemp,
            )
          : null;
    }
    if (chart == null) return const [];
    return [const SizedBox(height: 16), chart];
  }
}

/// 焼成雰囲気の選択肢。選択中の ID が選択肢にない (削除済み、または読み込み前)
/// ときは、その ID を値とする「不明な焼成雰囲気」を足す。
/// DropdownButtonFormField は初期値が選択肢にないとアサーションで落ちるため。
List<DropdownMenuItem<String?>> atmosphereItems(
  List<FiringAtmosphere> atmospheres,
  String? selectedId,
) {
  return [
    for (final a in atmospheres)
      DropdownMenuItem<String?>(value: a.id, child: Text(a.name)),
    if (selectedId != null && !atmospheres.any((a) => a.id == selectedId))
      DropdownMenuItem<String?>(
        value: selectedId,
        child: const Text('不明な焼成雰囲気'),
      ),
  ];
}

/// 焼成プロファイルの選択肢。選択中の ID が選択肢にないときは
/// 「不明な焼成プロファイル」を足す ([atmosphereItems] と同じ理由)。
List<DropdownMenuItem<String?>> profileItems(
  List<FiringProfile> profiles,
  String? selectedId,
) {
  return [
    for (final p in profiles)
      DropdownMenuItem<String?>(value: p.id, child: Text(p.name)),
    if (selectedId != null && !profiles.any((p) => p.id == selectedId))
      DropdownMenuItem<String?>(
        value: selectedId,
        child: const Text('不明な焼成プロファイル'),
      ),
  ];
}
