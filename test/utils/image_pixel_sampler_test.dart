import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:glaze_manager/utils/image_pixel_sampler.dart';

void main() {
  group('ImagePixelSampler.colorAt', () {
    // 2x2画像: (0,0)=赤, (1,0)=緑, (0,1)=青, (1,1)=半透明白
    final rgba = Uint8List.fromList([
      255, 0, 0, 255, //
      0, 255, 0, 255, //
      0, 0, 255, 255, //
      255, 255, 255, 128, //
    ]);
    final sampler = ImagePixelSampler.forTest(2, 2, rgba);

    test('各ピクセルの色を正しく読み取る', () {
      expect(sampler.colorAt(0, 0), const Color(0xFFFF0000));
      expect(sampler.colorAt(1, 0), const Color(0xFF00FF00));
      expect(sampler.colorAt(0, 1), const Color(0xFF0000FF));
      expect(sampler.colorAt(1, 1), const Color(0x80FFFFFF));
    });

    test('範囲外は null を返す', () {
      expect(sampler.colorAt(-1, 0), isNull);
      expect(sampler.colorAt(0, -1), isNull);
      expect(sampler.colorAt(2, 0), isNull);
      expect(sampler.colorAt(0, 2), isNull);
    });
  });

  group('scenePointToPixel', () {
    test('シーン座標を表示スケールで割ってピクセル座標にする', () {
      // 1000x500 の画像を 200x100 のチャイルドで表示 (スケール 1/5)
      final result = scenePointToPixel(
        const Offset(100, 50),
        const Size(200, 100),
        1000,
        500,
      );
      expect(result, const Offset(500, 250));
    });

    test('画像範囲外はクランプされる', () {
      final result = scenePointToPixel(
        const Offset(300, -10),
        const Size(200, 100),
        1000,
        500,
      );
      expect(result, const Offset(999, 0));
    });

    test('チャイルドサイズが不正なら null', () {
      expect(scenePointToPixel(Offset.zero, Size.zero, 1000, 500), isNull);
    });
  });

  group('pixelToScenePoint', () {
    test('scenePointToPixel の逆変換になっている', () {
      const childSize = Size(200, 100);
      const pixel = Offset(500, 250);
      final scene = pixelToScenePoint(pixel, childSize, 1000);
      expect(scene, const Offset(100, 50));
      expect(scenePointToPixel(scene, childSize, 1000, 500), pixel);
    });
  });
}
