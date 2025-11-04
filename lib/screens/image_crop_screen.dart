import 'dart:io';
import 'dart:typed_data';
import 'package:crop_your_image/crop_your_image.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

class ImageCropScreen extends StatefulWidget {
  final XFile image;

  const ImageCropScreen({super.key, required this.image});

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
                child: CircularProgressIndicator(color: Colors.white),
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
                    // 一時ディレクトリに画像を保存
                    final tempDir = await getTemporaryDirectory();
                    final path =
                        '${tempDir.path}/cropped_${DateTime.now().millisecondsSinceEpoch}.png';
                    final file = await File(
                      path,
                    ).writeAsBytes((croppedData as CropSuccess).croppedImage);

                    if (mounted) {
                      Navigator.of(context).pop(XFile(file.path));
                    }
                  } catch (e) {
                    if (mounted) {
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
                // initialRectBuilder: InitialRectBuilder.withBuilder((
                //   viewportRect,
                //   imageRect,
                // ) {
                //   return Rect.fromLTRB(
                //     viewportRect.left + 20,
                //     viewportRect.top + 20,
                //     viewportRect.right - 20,
                //     viewportRect.bottom - 20,
                //   );
                // }),
                cornerDotBuilder: (size, edgeAlignment) =>
                    const DotControl(color: Colors.white),
                maskColor: Colors.black.withOpacity(0.5),
                baseColor: Colors.grey.shade900,
                progressIndicator: const CircularProgressIndicator(),
              ),
      ),
      // bottomNavigationBar: _imageData == null
      //     ? null
      //     : SafeArea(
      //         child: SizedBox(height: 56, child: _buildControlButtons(context)),
      //       ),
    );
  }

  // Widget _buildControlButtons(BuildContext context) {
  //   return Row(
  //     mainAxisAlignment: MainAxisAlignment.spaceAround,
  //     children: [
  //       IconButton(
  //         icon: const Icon(Icons.aspect_ratio),
  //         onPressed: () {
  //           _cropController.withCircleUi = !_cropController.withCircleUi;
  //         },
  //         tooltip: '円形/四角形 切り替え',
  //       ),
  //       IconButton(
  //         icon: const Icon(Icons.rotate_90_degrees_cw),
  //         onPressed: () => _cropController.rotate(clockwise: true),
  //         tooltip: '右に90度回転',
  //       ),
  //       IconButton(
  //         icon: const Icon(Icons.rotate_90_degrees_ccw),
  //         onPressed: () => _cropController.rotate(clockwise: false),
  //         tooltip: '左に90度回転',
  //       ),
  //     ],
  //   );
  // }
}
