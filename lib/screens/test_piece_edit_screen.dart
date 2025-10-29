import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:glaze_manager/models/glaze.dart';
import 'package:glaze_manager/models/test_piece.dart';
import 'package:glaze_manager/services/firestore_service.dart';
import 'package:glaze_manager/services/storage_service.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

class TestPieceEditScreen extends StatefulWidget {
  final TestPiece? testPiece;

  const TestPieceEditScreen({super.key, this.testPiece});

  @override
  State<TestPieceEditScreen> createState() => _TestPieceEditScreenState();
}

class _TestPieceEditScreenState extends State<TestPieceEditScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _clayNameController;
  late TextEditingController _firingCurveController;

  String? _selectedGlazeId;
  List<Glaze> _availableGlazes = [];

  XFile? _imageFile; // 選択された画像ファイル
  String? _networkImageUrl; // 既存の画像のURL

  bool _isLoading = false;
  bool _isDirty = false;

  @override
  void initState() {
    super.initState();
    _clayNameController = TextEditingController(text: widget.testPiece?.clayName ?? '');
    _firingCurveController = TextEditingController(text: widget.testPiece?.firingCurve ?? '');
    _selectedGlazeId = widget.testPiece?.glazeId;
    _networkImageUrl = widget.testPiece?.imageUrl;

    _clayNameController.addListener(_markAsDirty);
    _firingCurveController.addListener(_markAsDirty);

    _loadGlazes();
  }

  Future<void> _loadGlazes() async {
    final firestoreService = Provider.of<FirestoreService>(context, listen: false);
    _availableGlazes = await firestoreService.getGlazes().first;
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
    _firingCurveController.dispose();
    super.dispose();
    _clayNameController.removeListener(_markAsDirty);
    _firingCurveController.removeListener(_markAsDirty);
  }

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        _imageFile = image;
        _markAsDirty(); // 画像が選択されたらダーティ
      });
    }
  }

  Future<void> _saveTestPiece() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    if (_selectedGlazeId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('釉薬を選択してください。')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final firestoreService = Provider.of<FirestoreService>(context, listen: false);
      final storageService = Provider.of<StorageService>(context, listen: false);
      String? imageUrl = _networkImageUrl;

      // 新しい画像が選択されていればアップロード
      if (_imageFile != null) {
        imageUrl = await storageService.uploadTestPieceImage(_imageFile!);
      }

      final testPiece = TestPiece(
        id: widget.testPiece?.id,
        glazeId: _selectedGlazeId!,
        clayName: _clayNameController.text,
        firingCurve: _firingCurveController.text,
        imageUrl: imageUrl,
        createdAt: widget.testPiece?.createdAt ?? Timestamp.now(),
      );

      if (widget.testPiece == null) {
        await firestoreService.addTestPiece(testPiece);
      } else {
        await firestoreService.updateTestPiece(testPiece);
      }

      if (mounted) {
        _isDirty = false; // 保存成功でダーティ状態をリセット
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('保存に失敗しました: $e')));
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
        if (didPop) return; // canPop: true の場合
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('変更を破棄しますか？'),
            content: const Text('入力中の内容は保存されません。'),
            actions: [
              TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('キャンセル')),
              TextButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('破棄', style: TextStyle(color: Colors.red))),
            ],
          ),
        );
        if (confirmed == true && mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.testPiece == null ? 'テストピースの新規作成' : 'テストピースの編集'),
          actions: [
            if (_isLoading)
              const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.black)))
            else
              IconButton(icon: const Icon(Icons.save), onPressed: _saveTestPiece),
          ],
        ),
        body: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16.0),
            children: [
              // 釉薬選択
              DropdownButtonFormField<String>(
                value: _selectedGlazeId,
                hint: const Text('関連する釉薬を選択'),
                isExpanded: true,
                items: _availableGlazes
                    .map((glaze) => DropdownMenuItem(value: glaze.id, child: Text(glaze.name)))
                    .toList(),
                onChanged: (value) {
                  _markAsDirty(); // 釉薬選択が変更されたらダーティ
                  setState(() {
                    _selectedGlazeId = value;
                  });
                },
                validator: (value) => value == null ? '釉薬を選択してください' : null,
              ),
              const SizedBox(height: 16),
              // 素地土名
              TextFormField(
                controller: _clayNameController,
                decoration: const InputDecoration(labelText: '素地土名'),
                validator: (value) => (value == null || value.isEmpty) ? '素地土名を入力してください' : null,
              ),
              const SizedBox(height: 16),
              // 焼成温度曲線
              TextFormField(
                controller: _firingCurveController,
                decoration: const InputDecoration(labelText: '焼成温度曲線 (任意)', hintText: 'CSVデータやメモなど'),
                maxLines: 3,
              ),
              const SizedBox(height: 24),
              // 画像選択
              Text('テストピース画像', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              _buildImagePreview(),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                icon: const Icon(Icons.photo_library),
                label: const Text('ギャラリーから画像を選択'),
                onPressed: _pickImage,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImagePreview() {
    // 新しい画像が選択されている場合
    if (_imageFile != null) {
      return Image.file(
        File(_imageFile!.path),
        height: 200,
        fit: BoxFit.cover,
      );
    }
    // 既存の画像URLがある場合
    if (_networkImageUrl != null) {
      return Image.network(
        _networkImageUrl!,
        height: 200,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return const Center(heightFactor: 3, child: CircularProgressIndicator());
        },
        errorBuilder: (context, error, stackTrace) {
          return const Center(heightFactor: 3, child: Icon(Icons.error, color: Colors.red));
        },
      );
    }
    // どちらもない場合
    return Container(
      height: 150,
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