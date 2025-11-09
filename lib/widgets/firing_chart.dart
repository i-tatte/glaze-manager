import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

class FiringChart extends StatelessWidget {
  final String curveData;
  final double ymin = 0;
  final double ymax = 1400;

  const FiringChart({super.key, required this.curveData});

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

  @override
  Widget build(BuildContext context) {
    final spots = _parseCurveData();
    if (spots.isEmpty) {
      return const SizedBox.shrink();
    }

    return AspectRatio(
      aspectRatio: 1.5,
      child: Padding(
        padding: const EdgeInsets.only(right: 18.0, top: 10.0),
        child: LineChart(
          LineChartData(
            rangeAnnotations: RangeAnnotations(
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
            lineTouchData: LineTouchData(
              touchTooltipData: LineTouchTooltipData(
                getTooltipItems: (touchedSpots) {
                  return touchedSpots.map((spot) {
                    return LineTooltipItem(
                      '${(spot.x * 60).toStringAsFixed(0)} 分\n${spot.y.toStringAsFixed(0)} °C',
                      const TextStyle(color: Colors.white),
                    );
                  }).toList();
                },
              ),
            ),
            lineBarsData: [
              LineChartBarData(
                spots: spots,
                isCurved: false,
                color: Theme.of(context).primaryColor,
                barWidth: 3,
                isStrokeCapRound: true,
                dotData: const FlDotData(show: true),
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
