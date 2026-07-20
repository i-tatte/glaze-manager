import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// デコード済み画像のピクセルバッファを保持し、座標指定で色を読み取る。
///
/// スポイト機能の基盤。画面のラスタライズ結果ではなく画像そのものを
/// サンプリングするため、UIオーバーレイの影響を受けず原寸解像度で色を拾える。
class ImagePixelSampler {
  final int width;
  final int height;
  final Uint8List _rgba; // rawRgba形式 (4バイト/ピクセル)

  ImagePixelSampler._(this.width, this.height, this._rgba);

  @visibleForTesting
  ImagePixelSampler.forTest(this.width, this.height, Uint8List rgba)
    : _rgba = rgba;

  /// 指定ピクセルの色を返す。範囲外は null。
  Color? colorAt(int x, int y) {
    if (x < 0 || y < 0 || x >= width || y >= height) return null;
    final offset = (y * width + x) * 4;
    return Color.fromARGB(
      _rgba[offset + 3],
      _rgba[offset],
      _rgba[offset + 1],
      _rgba[offset + 2],
    );
  }

  /// [ui.Image] からサンプラーを生成する。
  static Future<ImagePixelSampler> fromImage(ui.Image image) async {
    final byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (byteData == null) {
      throw StateError('画像のピクセルデータを取得できませんでした');
    }
    return ImagePixelSampler._(
      image.width,
      image.height,
      byteData.buffer.asUint8List(byteData.offsetInBytes, byteData.lengthInBytes),
    );
  }

  /// [ImageProvider] を解決してサンプラーを生成する。
  /// デコード失敗・タイムアウトは例外として伝播する。
  static Future<ImagePixelSampler> fromProvider(
    ImageProvider provider, {
    Duration timeout = const Duration(seconds: 15),
  }) async {
    final image = await _resolveImage(provider).timeout(timeout);
    try {
      return await fromImage(image);
    } finally {
      image.dispose();
    }
  }

  static Future<ui.Image> _resolveImage(ImageProvider provider) {
    final completer = Completer<ui.Image>();
    final stream = provider.resolve(ImageConfiguration.empty);
    late final ImageStreamListener listener;
    listener = ImageStreamListener(
      (ImageInfo info, bool _) {
        if (!completer.isCompleted) {
          completer.complete(info.image.clone());
        }
        info.dispose();
        stream.removeListener(listener);
      },
      onError: (Object error, StackTrace? stackTrace) {
        if (!completer.isCompleted) {
          completer.completeError(error, stackTrace ?? StackTrace.current);
        }
        stream.removeListener(listener);
      },
    );
    stream.addListener(listener);
    return completer.future;
  }
}

/// InteractiveViewer のシーン座標 (= コンテンツの論理座標) を画像ピクセル座標へ変換する。
///
/// コンテンツは画像と同じアスペクト比の [childSize] いっぱいに表示されている前提。
/// 結果は画像範囲内にクランプされる。childSize が不正 (幅0等) なら null。
Offset? scenePointToPixel(
  Offset scenePoint,
  Size childSize,
  int imageWidth,
  int imageHeight,
) {
  if (childSize.width <= 0 || childSize.height <= 0) return null;
  if (imageWidth <= 0 || imageHeight <= 0) return null;
  final scale = imageWidth / childSize.width;
  return Offset(
    (scenePoint.dx * scale).clamp(0.0, imageWidth - 1.0),
    (scenePoint.dy * scale).clamp(0.0, imageHeight - 1.0),
  );
}

/// [scenePointToPixel] の逆変換。マーカー描画位置の算出に使う。
Offset pixelToScenePoint(
  Offset pixel,
  Size childSize,
  int imageWidth,
) {
  final scale = childSize.width / imageWidth;
  return Offset(pixel.dx * scale, pixel.dy * scale);
}
