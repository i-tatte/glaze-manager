import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:glaze_manager/utils/image_pixel_sampler.dart';

/// スポイトの動作モード
enum ColorPickMode {
  /// 1色確定したら即座にその色を返して閉じる (テストピース詳細画面の検索用)
  single,

  /// 何色でも連続して追加でき、「完了」で色リストを返す (テスピ編集画面用)
  multi,
}

/// 画像から色をスポイトで選択する専用画面。
///
/// - 画像を一度だけデコードし、ピクセルバッファから直接サンプリングする
///   (画面のラスタライズは行わないため、UIやローディング表示の色を拾わない)。
/// - タッチ: 1本指のスワイプでマーカーを相対移動 (指で選択点が隠れないように
///   タップ位置へのジャンプはしない)。2本指でズーム/パン。「決定」で確定。
/// - マウス: ホバー中はポインタ位置がそのままマーカー。クリックで確定。
///   ドラッグでパン、ホイールでズーム。
/// - マーカー周辺のルーペと選択色は画面上部に常時表示する。
///
/// pop の戻り値: [ColorPickMode.single] は `Color?`(キャンセル時 null)、
/// [ColorPickMode.multi] は `List<Color>`(戻る操作でも追加済みリストを返す)。
class ColorPickScreen extends StatefulWidget {
  final ImageProvider imageProvider;
  final ColorPickMode mode;

  /// 呼び出し元で既に登録されている色。重複チェック用の参照表示のみで、
  /// この画面からは削除できない (削除は呼び出し元の責務)。
  final List<Color> existingColors;

  const ColorPickScreen({
    super.key,
    required this.imageProvider,
    required this.mode,
    this.existingColors = const [],
  });

  @override
  State<ColorPickScreen> createState() => _ColorPickScreenState();
}

class _ColorPickScreenState extends State<ColorPickScreen> {
  static const double _clickSlop = 6.0; // これ以下の移動はクリックとみなす
  static const double _panEdgeMargin = 48.0; // パンで画像が完全に画面外へ出ないための余白

  final TransformationController _controller = TransformationController();

  ImagePixelSampler? _sampler;
  Object? _loadError;

  /// マーカー位置 (画像ピクセル座標)
  Offset _markerPx = Offset.zero;

  /// multi モードで追加済みの色
  final List<Color> _picked = [];

  // 直近の build で計算したレイアウト情報 (ポインタイベントの座標変換に使う)
  Size? _childSize;
  Size? _viewportSize;

  // ポインタ状態
  int _touchPointerCount = 0;
  Offset? _mouseDownPosition;
  bool _mouseDragPanned = false;

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  Future<void> _loadImage() async {
    try {
      final sampler = await ImagePixelSampler.fromProvider(
        widget.imageProvider,
      );
      if (!mounted) return;
      setState(() {
        _sampler = sampler;
        // 初期マーカーは画像中央
        _markerPx = Offset(sampler.width / 2, sampler.height / 2);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadError = e);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Color? get _markerColor => _sampler?.colorAt(
    _markerPx.dx.round().clamp(0, (_sampler?.width ?? 1) - 1),
    _markerPx.dy.round().clamp(0, (_sampler?.height ?? 1) - 1),
  );

  // ---------------------------------------------------------------------------
  // 座標変換とマーカー操作
  // ---------------------------------------------------------------------------

  /// シーン座標系でのチャイルド (画像) の左上オフセット。
  /// InteractiveViewer の子は viewport と同サイズの Center ラッパーであり、
  /// 画像はその中央に置かれるため、シーン座標と画像座標はこの分ずれる。
  Offset? get _childOffset {
    final childSize = _childSize;
    final viewportSize = _viewportSize;
    if (childSize == null || viewportSize == null) return null;
    return Offset(
      (viewportSize.width - childSize.width) / 2,
      (viewportSize.height - childSize.height) / 2,
    );
  }

  /// ビューポート座標 → 画像ピクセル座標
  Offset? _viewportToPixel(Offset viewportPoint) {
    final sampler = _sampler;
    final childSize = _childSize;
    final childOffset = _childOffset;
    if (sampler == null || childSize == null || childOffset == null) {
      return null;
    }
    final scenePoint = _controller.toScene(viewportPoint) - childOffset;
    return scenePointToPixel(
      scenePoint,
      childSize,
      sampler.width,
      sampler.height,
    );
  }

  void _setMarkerFromViewport(Offset viewportPoint) {
    final pixel = _viewportToPixel(viewportPoint);
    if (pixel == null) return;
    setState(() => _markerPx = pixel);
  }

  /// タッチの相対移動: ビューポート上の移動量をピクセル座標系に換算して加算する
  void _moveMarkerBy(Offset viewportDelta) {
    final sampler = _sampler;
    final childSize = _childSize;
    if (sampler == null || childSize == null) return;
    final viewScale = _controller.value.getMaxScaleOnAxis();
    if (viewScale <= 0) return;
    final pixelDelta =
        viewportDelta * (sampler.width / childSize.width) / viewScale;
    setState(() {
      _markerPx = Offset(
        (_markerPx.dx + pixelDelta.dx).clamp(0.0, sampler.width - 1.0),
        (_markerPx.dy + pixelDelta.dy).clamp(0.0, sampler.height - 1.0),
      );
    });
  }

  /// マウスドラッグによるパン。画像が完全に画面外へ出る移動は無視する。
  void _panBy(Offset delta) {
    final childSize = _childSize;
    final viewportSize = _viewportSize;
    final childOffset = _childOffset;
    if (childSize == null || viewportSize == null || childOffset == null) {
      return;
    }
    final matrix = Matrix4.translationValues(delta.dx, delta.dy, 0)
      ..multiply(_controller.value);
    final contentRect = MatrixUtils.transformRect(
      matrix,
      childOffset & childSize,
    );
    if (contentRect.right < _panEdgeMargin ||
        contentRect.left > viewportSize.width - _panEdgeMargin ||
        contentRect.bottom < _panEdgeMargin ||
        contentRect.top > viewportSize.height - _panEdgeMargin) {
      return;
    }
    _controller.value = matrix;
  }

  // ---------------------------------------------------------------------------
  // ポインタイベント
  // ---------------------------------------------------------------------------

  bool _isTouchKind(PointerDeviceKind kind) =>
      kind == PointerDeviceKind.touch ||
      kind == PointerDeviceKind.stylus ||
      kind == PointerDeviceKind.invertedStylus;

  void _onPointerDown(PointerDownEvent event) {
    if (_isTouchKind(event.kind)) {
      _touchPointerCount++;
    } else if (event.kind == PointerDeviceKind.mouse) {
      _mouseDownPosition = event.localPosition;
      _mouseDragPanned = false;
    }
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (_isTouchKind(event.kind)) {
      // 1本指のときだけマーカーを相対移動。2本指以上は InteractiveViewer の
      // ズーム/パンに任せる (Listener はイベントを消費しないため両立する)。
      if (_touchPointerCount == 1) {
        _moveMarkerBy(event.delta);
      }
      return;
    }
    if (event.kind == PointerDeviceKind.mouse) {
      final downPosition = _mouseDownPosition;
      if (downPosition != null) {
        if (!_mouseDragPanned &&
            (event.localPosition - downPosition).distance > _clickSlop) {
          _mouseDragPanned = true;
        }
        if (_mouseDragPanned) {
          _panBy(event.delta);
        }
      }
      // ドラッグ中もホバー同様にポインタ位置を選択点として追従させる
      _setMarkerFromViewport(event.localPosition);
    }
  }

  void _onPointerUp(PointerUpEvent event) {
    if (_isTouchKind(event.kind)) {
      _touchPointerCount = (_touchPointerCount - 1).clamp(0, 100);
      return;
    }
    if (event.kind == PointerDeviceKind.mouse) {
      final wasClick = _mouseDownPosition != null && !_mouseDragPanned;
      _mouseDownPosition = null;
      _mouseDragPanned = false;
      if (wasClick) {
        _setMarkerFromViewport(event.localPosition);
        _confirm();
      }
    }
  }

  void _onPointerCancel(PointerCancelEvent event) {
    if (_isTouchKind(event.kind)) {
      _touchPointerCount = (_touchPointerCount - 1).clamp(0, 100);
    } else if (event.kind == PointerDeviceKind.mouse) {
      _mouseDownPosition = null;
      _mouseDragPanned = false;
    }
  }

  void _onHover(PointerHoverEvent event) {
    _setMarkerFromViewport(event.localPosition);
  }

  // ---------------------------------------------------------------------------
  // 確定
  // ---------------------------------------------------------------------------

  void _confirm() {
    final color = _markerColor;
    if (color == null) return;
    if (widget.mode == ColorPickMode.single) {
      Navigator.of(context).pop(color);
    } else {
      setState(() => _picked.add(color));
    }
  }

  void _finishMulti() {
    Navigator.of(context).pop(List<Color>.from(_picked));
  }

  // ---------------------------------------------------------------------------
  // build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final scaffold = Scaffold(
      appBar: AppBar(
        title: const Text('スポイトで色を選択'),
        actions: [
          if (widget.mode == ColorPickMode.multi)
            TextButton(onPressed: _finishMulti, child: const Text('完了')),
        ],
      ),
      body: _buildBody(),
    );

    if (widget.mode == ColorPickMode.single) {
      return scaffold;
    }
    // multi: 戻る操作でも追加済みの色を破棄せず返す (誤操作での全損防止)
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _finishMulti();
      },
      child: scaffold,
    );
  }

  Widget _buildBody() {
    if (_loadError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.broken_image, size: 48, color: Colors.grey),
              const SizedBox(height: 16),
              const Text('画像を読み込めませんでした。'),
              const SizedBox(height: 8),
              Text(
                'オフラインの場合は、オンラインで一度画像を表示してから再度お試しください。',
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }
    final sampler = _sampler;
    if (sampler == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      children: [
        _buildInfoPanel(sampler),
        Expanded(child: _buildImageArea(sampler)),
        _buildBottomBar(),
      ],
    );
  }

  /// ルーペ + 選択色を常時表示するパネル
  Widget _buildInfoPanel(ImagePixelSampler sampler) {
    final color = _markerColor;
    final hex = color == null
        ? '--'
        : '#${(color.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 120,
            height: 120,
            child: CustomPaint(
              painter: _LoupePainter(
                sampler: sampler,
                centerPixel: Offset(
                  _markerPx.dx.roundToDouble(),
                  _markerPx.dy.roundToDouble(),
                ),
              ),
            ),
          ),
          const SizedBox(width: 24),
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.black54, width: 1.0),
                ),
              ),
              const SizedBox(height: 8),
              Text(hex, style: Theme.of(context).textTheme.bodyMedium),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildImageArea(ImagePixelSampler sampler) {
    return ClipRect(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final viewportSize = Size(
            constraints.maxWidth,
            constraints.maxHeight,
          );
          _viewportSize = viewportSize;
          // 画像と同じアスペクト比で contain フィットするチャイルドサイズを決める。
          // チャイルド全面 = 画像全面 なので、シーン座標→ピクセル座標が単純な比例になる。
          final imageAspect = sampler.width / sampler.height;
          final viewportAspect = viewportSize.width / viewportSize.height;
          final childSize = imageAspect > viewportAspect
              ? Size(viewportSize.width, viewportSize.width / imageAspect)
              : Size(viewportSize.height * imageAspect, viewportSize.height);
          _childSize = childSize;

          return Listener(
            onPointerDown: _onPointerDown,
            onPointerMove: _onPointerMove,
            onPointerUp: _onPointerUp,
            onPointerCancel: _onPointerCancel,
            onPointerHover: _onHover,
            child: MouseRegion(
              cursor: SystemMouseCursors.precise,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  InteractiveViewer(
                    transformationController: _controller,
                    // 1本指ドラッグはマーカー移動に使うためパンは無効化する。
                    // 2本指のスケールジェスチャ (ズーム + 焦点移動によるパン) と
                    // マウスホイールのズームは InteractiveViewer が処理する。
                    panEnabled: false,
                    scaleEnabled: true,
                    minScale: 1.0,
                    maxScale: 20.0,
                    child: Center(
                      child: SizedBox(
                        width: childSize.width,
                        height: childSize.height,
                        child: Image(
                          image: widget.imageProvider,
                          fit: BoxFit.fill,
                          gaplessPlayback: true,
                        ),
                      ),
                    ),
                  ),
                  // マーカーは InteractiveViewer の外に描き、ズームしても
                  // 画面上のサイズが一定になるようにする
                  IgnorePointer(
                    child: AnimatedBuilder(
                      animation: _controller,
                      builder: (context, _) {
                        return CustomPaint(
                          painter: _MarkerPainter(
                            markerViewportPosition: _markerViewportPosition(
                              sampler,
                              childSize,
                              viewportSize,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  /// マーカーの画像ピクセル座標をビューポート座標へ変換する
  Offset _markerViewportPosition(
    ImagePixelSampler sampler,
    Size childSize,
    Size viewportSize,
  ) {
    // チャイルドは Center で配置されるが、InteractiveViewer の子は
    // viewport と同サイズの Center ラッパーなので、シーン座標系では
    // チャイルドが (viewport - child) / 2 だけオフセットされている。
    final childOffset = Offset(
      (viewportSize.width - childSize.width) / 2,
      (viewportSize.height - childSize.height) / 2,
    );
    final scenePoint =
        pixelToScenePoint(_markerPx, childSize, sampler.width) + childOffset;
    return MatrixUtils.transformPoint(_controller.value, scenePoint);
  }

  Widget _buildBottomBar() {
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'なぞってマーカーを移動 / 2本指でズーム。マウスはホバーで選択・クリックで確定。',
              style: theme.textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
            if (widget.existingColors.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Text('登録済みの色', style: theme.textTheme.labelSmall),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Wrap(
                      spacing: 8.0,
                      runSpacing: 8.0,
                      children: [
                        for (final color in widget.existingColors)
                          Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.black54,
                                width: 1.0,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
            if (widget.mode == ColorPickMode.multi && _picked.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text('追加する色', style: theme.textTheme.labelSmall),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Wrap(
                      spacing: 8.0,
                      runSpacing: 8.0,
                      children: [
                        for (var i = 0; i < _picked.length; i++)
                          Chip(
                            label: const SizedBox.shrink(),
                            avatar: CircleAvatar(
                              backgroundColor: _picked[i],
                              radius: 12,
                            ),
                            onDeleted: () =>
                                setState(() => _picked.removeAt(i)),
                            deleteIcon: const Icon(Icons.close, size: 16),
                            padding: const EdgeInsets.all(2),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: _markerColor != null ? _confirm : null,
              icon: const Icon(Icons.colorize),
              label: Text(
                widget.mode == ColorPickMode.single ? 'この色で決定' : 'この色を追加',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// マーカー (十字線 + 円) をビューポート座標に描く
class _MarkerPainter extends CustomPainter {
  final Offset markerViewportPosition;

  _MarkerPainter({required this.markerViewportPosition});

  @override
  void paint(Canvas canvas, Size size) {
    final p = markerViewportPosition;
    final outline = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;
    final line = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    const r = 10.0; // 円の半径
    const arm = 8.0; // 十字線の長さ (円の外側)

    for (final paint in [outline, line]) {
      canvas.drawCircle(p, r, paint);
      canvas.drawLine(
        p + const Offset(0, -r - arm),
        p + const Offset(0, -r),
        paint,
      );
      canvas.drawLine(
        p + const Offset(0, r),
        p + const Offset(0, r + arm),
        paint,
      );
      canvas.drawLine(
        p + const Offset(-r - arm, 0),
        p + const Offset(-r, 0),
        paint,
      );
      canvas.drawLine(
        p + const Offset(r, 0),
        p + const Offset(r + arm, 0),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_MarkerPainter oldDelegate) =>
      oldDelegate.markerViewportPosition != markerViewportPosition;
}

/// マーカー周辺のピクセルを拡大表示するルーペ。
/// 画面のレンダリング結果ではなくデコード済みバッファから直接描くため、
/// マーカーやローディング表示が写り込まない。
class _LoupePainter extends CustomPainter {
  static const int _cellCount = 13; // 奇数にして中心ピクセルを真ん中に置く

  final ImagePixelSampler sampler;
  final Offset centerPixel;

  _LoupePainter({required this.sampler, required this.centerPixel});

  @override
  void paint(Canvas canvas, Size size) {
    final cellSize = size.width / _cellCount;
    final half = _cellCount ~/ 2;
    final cx = centerPixel.dx.round();
    final cy = centerPixel.dy.round();

    final cellPaint = Paint();
    final outsidePaint = Paint()..color = Colors.grey.shade400;

    canvas.save();
    canvas.clipRRect(
      RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(8)),
    );
    for (var row = 0; row < _cellCount; row++) {
      for (var col = 0; col < _cellCount; col++) {
        final color = sampler.colorAt(cx + col - half, cy + row - half);
        final rect = Rect.fromLTWH(
          col * cellSize,
          row * cellSize,
          cellSize + 0.5, // 隙間のアンチエイリアス対策で僅かに重ねる
          cellSize + 0.5,
        );
        canvas.drawRect(
          rect,
          color == null ? outsidePaint : (cellPaint..color = color),
        );
      }
    }

    // 中心セルの強調枠
    final centerRect = Rect.fromLTWH(
      half * cellSize,
      half * cellSize,
      cellSize,
      cellSize,
    );
    canvas.drawRect(
      centerRect.inflate(1.0),
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0,
    );
    canvas.drawRect(
      centerRect,
      Paint()
        ..color = Colors.black
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0,
    );
    canvas.restore();

    // 外枠
    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(8)),
      Paint()
        ..color = Colors.black54
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0,
    );
  }

  @override
  bool shouldRepaint(_LoupePainter oldDelegate) =>
      oldDelegate.centerPixel != centerPixel || oldDelegate.sampler != sampler;
}
