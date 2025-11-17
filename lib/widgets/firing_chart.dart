import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

class FiringChart extends StatelessWidget {
  final String curveData;
  final double ymin = 0;
  final double ymax = 1400;
  final bool isReduction;
  final int? reductionStartTemp;
  final int? reductionEndTemp;
  // 傾きが急だと判断するしきい値 (°C/時間)。
  static const double steepSlopeThreshold = 200.0;

  const FiringChart({
    super.key,
    required this.curveData,
    this.isReduction = false,
    this.reductionStartTemp,
    this.reductionEndTemp,
  });

  List<FlSpot> _parseCurveData() {
    final List<FlSpot> spots = [const FlSpot(0, 20)]; // Start at room temp
    double lastTime = 0;

    final lines = curveData.trim().split('\n');
    for (final line in lines) {
      final parts = line.trim().split(',');
      if (parts.length == 2) {
        final time = double.tryParse(parts[0].trim());
        final temp = double.tryParse(parts[1].trim());

        if (time != null && temp != null && time > lastTime) {
          spots.add(FlSpot(time / 60.0, temp)); // Convert minutes to hours
          lastTime = time;
        }
      }
    }
    return spots.length > 1 ? spots : [];
  }

  /// 2点間の線形補間により、特定のy値に対応するx値を見つけるヘルパー関数
  double? _getInterpolatedX(double y, FlSpot p1, FlSpot p2) {
    // yが2点のy座標の範囲内にない場合は補間できない
    if ((y < p1.y || y > p2.y) && (y < p2.y || y > p1.y)) {
      return null;
    }
    // 垂直線の場合（時間は進むが温度が変わらない）
    if (p1.y == p2.y) {
      return (p1.x + p2.x) / 2; // 中間点を返すか、あるいはp1.xでも良い
    }
    // 線形補間でxを計算
    return p1.x + (y - p1.y) * (p2.x - p1.x) / (p2.y - p1.y);
  }

  /// 還元焼成の時間範囲を計算する
  ({double? start, double? end}) _getReductionTimeRange(List<FlSpot> spots) {
    if (!isReduction ||
        reductionStartTemp == null ||
        reductionEndTemp == null ||
        spots.length < 2) {
      return (start: null, end: null);
    }

    double? reductionStartTime;
    double? reductionEndTime;

    // 各線分をチェックして、開始温度と終了温度を通過する時間を見つける
    for (int i = 0; i < spots.length - 1; i++) {
      final p1 = spots[i];
      final p2 = spots[i + 1];

      // 開始時間を探す
      if (reductionStartTime == null) {
        reductionStartTime = _getInterpolatedX(
          reductionStartTemp!.toDouble(),
          p1,
          p2,
        );
      }
      // 終了時間を探す
      if (reductionEndTime == null) {
        reductionEndTime = _getInterpolatedX(
          reductionEndTemp!.toDouble(),
          p1,
          p2,
        );
      }
    }

    return (start: reductionStartTime, end: reductionEndTime);
  }

  /// 傾きに基づいて色分けされたLineChartBarDataのリストを生成します。
  List<LineChartBarData> _generateLineBars(
    BuildContext context,
    List<FlSpot> spots,
  ) {
    final List<LineChartBarData> lineBars = [];
    const steepColor = Colors.red;

    if (spots.length < 2) {
      return [
        LineChartBarData(
          spots: spots,
          isCurved: false,
          color: Theme.of(context).primaryColor,
          barWidth: 3,
          isStrokeCapRound: true,
          dotData: const FlDotData(show: true),
        ),
      ];
    }

    for (int i = 0; i < spots.length - 1; i++) {
      final p1 = spots[i];
      final p2 = spots[i + 1];
      final segmentSpots = [p1, p2];

      // 傾きを計算 (温度変化 / 時間変化)
      final slope = (p2.y - p1.y) / (p2.x - p1.x);

      lineBars.add(
        LineChartBarData(
          spots: segmentSpots,
          color: slope.abs() >= steepSlopeThreshold
              ? steepColor
              : Theme.of(context).primaryColor,
          barWidth: 3,
          isStrokeCapRound: true,
          dotData: const FlDotData(show: false), // 各線分での点は非表示
        ),
      );
    }
    return lineBars;
  }

  @override
  Widget build(BuildContext context) {
    final spots = _parseCurveData();
    if (spots.isEmpty) {
      return const SizedBox.shrink();
    }

    final reductionTimeRange = _getReductionTimeRange(spots);
    final lineTouchData = LineTouchData(
      handleBuiltInTouches: true, // デフォルトのタッチ挙動を有効にする
      getTouchedSpotIndicator:
          (LineChartBarData barData, List<int> spotIndexes) {
            // ホバー時のスポット強調表示を無効にする
            return spotIndexes.map((spotIndex) {
              return TouchedSpotIndicatorData(
                FlLine(color: Theme.of(context).primaryColor),
                const FlDotData(show: false),
              );
            }).toList();
          },
      touchTooltipData: LineTouchTooltipData(
        getTooltipItems: (touchedSpots) {
          if (touchedSpots.isEmpty) {
            return [];
          }

          // 複数の線が重なっている場合でも、最初のスポットに対してのみツールチップを生成する
          final spot = touchedSpots.first;
          final isInsideReduction =
              reductionTimeRange.start != null &&
              reductionTimeRange.end != null &&
              spot.x >= reductionTimeRange.start! &&
              spot.x <= reductionTimeRange.end!;

          String reductionText = '';
          if (isInsideReduction) {
            final start = reductionStartTemp ?? 0;
            final end = reductionEndTemp ?? 0;
            final tempText = start < end
                ? '$start℃ - $end℃'
                : '$end℃ - $start℃';
            reductionText = '\n還元火入れ中 ($tempText)';
          }

          String steepSlopeText = '';
          // ホバー位置の傾きを計算
          for (int i = 0; i < spots.length - 1; i++) {
            final p1 = spots[i];
            final p2 = spots[i + 1];
            // ホバーしているx座標がどの線分に含まれるかチェック
            if (spot.x >= p1.x && spot.x <= p2.x) {
              if (p2.x - p1.x != 0) {
                final slope = (p2.y - p1.y) / (p2.x - p1.x);
                if (slope.abs() >= steepSlopeThreshold) {
                  steepSlopeText = '\n【注意】温度勾配>$steepSlopeThreshold℃/h';
                }
              }
              break; // 対象の線分を見つけたらループを抜ける
            }
          }

          final tooltipText =
              '${(spot.x).toStringAsFixed(1)} 時間\n${spot.y.toStringAsFixed(0)} °C$reductionText$steepSlopeText';

          // touchedSpotsの各要素に対してLineTooltipItemを返す必要がある。
          // 2つ目以降は空のアイテムを返し、重複表示を防ぐ。
          final List<LineTooltipItem?> tooltipItems = [];
          for (int i = 0; i < touchedSpots.length; i++) {
            // 最初のスポットにのみツールチップを表示し、残りはnullにする
            if (i == 0) {
              tooltipItems.add(
                LineTooltipItem(
                  tooltipText,
                  const TextStyle(color: Colors.white),
                  textAlign: TextAlign.left,
                ),
              );
            } else {
              tooltipItems.add(null);
            }
          }
          return tooltipItems;
        },
      ),
    );

    return AspectRatio(
      aspectRatio: 1.5,
      child: Padding(
        padding: const EdgeInsets.only(right: 18.0, top: 10.0),
        child: LineChart(
          LineChartData(
            rangeAnnotations: RangeAnnotations(
              verticalRangeAnnotations: [
                if (reductionTimeRange.start != null &&
                    reductionTimeRange.end != null)
                  VerticalRangeAnnotation(
                    x1: reductionTimeRange.start!,
                    x2: reductionTimeRange.end!,
                    color: Colors.blue.withOpacity(0.2),
                  ),
              ],
              horizontalRangeAnnotations: [
                HorizontalRangeAnnotation(
                  y1: 100,
                  y2: 200,
                  color: Colors.lightGreen.withValues(alpha: 0.2),
                ),
                HorizontalRangeAnnotation(
                  y1: 800,
                  y2: 1200,
                  color: Colors.yellow.withValues(alpha: 0.2),
                ),
                HorizontalRangeAnnotation(
                  y1: 1200,
                  y2: 1300,
                  color: Colors.orange.withValues(alpha: 0.2),
                ),
                HorizontalRangeAnnotation(
                  y1: 1300,
                  y2: ymax,
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
            lineTouchData: lineTouchData,
            // 傾きによって色分けされた線のリストと、全ての点を表示するための線を重ねる
            lineBarsData: [
              ..._generateLineBars(context, spots),
              // 全てのデータ点を表示するための透明な線
              LineChartBarData(
                spots: spots,
                dotData: const FlDotData(show: true),
                color: Theme.of(context).primaryColor,
                barWidth: 0,
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
