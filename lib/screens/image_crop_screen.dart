import 'package:crop_your_image/crop_your_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;

class ImageCropScreen extends StatefulWidget {
  final XFile image;
  final String outputFileName; // 保存するファイル名を外部から受け取る

  const ImageCropScreen({
    super.key,
    required this.image,
    required this.outputFileName,
  });

  @override
  State<ImageCropScreen> createState() => _ImageCropScreenState();
}

class _ImageCropScreenState extends State<ImageCropScreen> {
  final _cropController = CropController();
  bool _isCropping = false;
  Uint8List? _imageData;

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  Future<void> _loadImage() async {
    final data = await widget.image.readAsBytes();
    setState(() => _imageData = data);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('画像をトリミング'),
        actions: [
          if (_isCropping)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.check),
              onPressed: () {
                setState(() => _isCropping = true);
                _cropController.crop();
              },
              tooltip: '完了',
            ),
        ],
      ),
      body: Center(
        child: _imageData == null
            ? const CircularProgressIndicator()
            : Crop(
                controller: _cropController,
                image: _imageData!,
                onCropped: (croppedData) async {
                  try {
                    // 画像処理をバックグラウンドで実行
                    final jpegBytes = await compute(
                      _encodeToJpeg,
                      (croppedData as CropSuccess).croppedImage,
                    );

                    if (context.mounted) {
                      // ファイル名とバイトデータをMapで返す
                      Navigator.of(context).pop({
                        'fileName': widget.outputFileName,
                        'bytes': jpegBytes,
                      });
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('画像の保存に失敗しました: $e')),
                      );
                      setState(() {
                        _isCropping = false;
                      });
                    }
                  }
                },
                aspectRatio: 1.0, // 正方形に固定
                cornerDotBuilder: (size, edgeAlignment) =>
                    const DotControl(color: Colors.white),
                maskColor: Colors.black.withValues(alpha: 0.5),
                baseColor: Colors.grey.shade900,
                progressIndicator: const CircularProgressIndicator(),
              ),
      ),
    );
  }

  /// 画像データをJPEGにエンコードするトップレベル関数 (computeで使用)
  static Future<Uint8List> _encodeToJpeg(Uint8List imageData) async {
    final image = img.decodeImage(imageData);
    if (image == null) {
      throw Exception('画像のデコードに失敗しました。');
    }
    // 品質85でJPEGにエンコード
    return Uint8List.fromList(img.encodeJpg(image, quality: 85));
  }
}
