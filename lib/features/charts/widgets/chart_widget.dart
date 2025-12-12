import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../core/constants/app_constants.dart';
import '../models/chart_data.dart';

class ChartWidget extends StatelessWidget {
  final String chartType;
  final List<ChartDataPoint> data;

  const ChartWidget({
    super.key,
    required this.chartType,
    required this.data,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.spacingL),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _getChartTitle(),
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: AppConstants.spacingL),
            Expanded(
              child: _buildChart(),
            ),
          ],
        ),
      ),
    );
  }

  String _getChartTitle() {
    switch (chartType) {
      case AppConstants.chartTypePie:
        return 'Expense Distribution';
      case AppConstants.chartTypeBar:
        return 'Expenses by Category';
      case AppConstants.chartTypeLine:
        return 'Expense Trends';
      default:
        return 'Chart';
    }
  }

  Widget _buildChart() {
    switch (chartType) {
      case AppConstants.chartTypePie:
        return _buildPieChart();
      case AppConstants.chartTypeBar:
        return _buildBarChart();
      case AppConstants.chartTypeLine:
        return _buildLineChart();
      default:
        return const Center(child: Text('Unknown chart type'));
    }
  }

  Widget _buildPieChart() {
    if (data.isEmpty) {
      return const Center(child: Text('No data available'));
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        // Calculate responsive size based on available space
        final availableSize = constraints.maxWidth < constraints.maxHeight
            ? constraints.maxWidth
            : constraints.maxHeight;
        // Use 70% of available space, with a minimum of 100 and maximum of 150
        final chartSize = (availableSize * 0.7).clamp(100.0, 150.0);
        final radius = chartSize / 2;
        final centerSpaceRadius = radius * 0.3; // 30% of radius for center space

        return PieChart(
          PieChartData(
            sections: data.asMap().entries.map((entry) {
              final dataPoint = entry.value;
              final total = data.fold(0.0, (sum, d) => sum + d.value);
              final percentage = (dataPoint.value / total * 100).toStringAsFixed(1);

              return PieChartSectionData(
                value: dataPoint.value,
                title: '$percentage%',
                color: dataPoint.color,
                radius: radius,
                titleStyle: TextStyle(
                  fontSize: radius * 0.12, // Responsive font size
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              );
            }).toList(),
            sectionsSpace: 2,
            centerSpaceRadius: centerSpaceRadius,
          ),
        );
      },
    );
  }

  Widget _buildBarChart() {
    if (data.isEmpty) {
      return const Center(child: Text('No data available'));
    }

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: data.map((d) => d.value).reduce((a, b) => a > b ? a : b) * 1.2,
        barTouchData: const BarTouchData(enabled: true),
        titlesData: FlTitlesData(
          show: true,
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                if (value.toInt() >= 0 && value.toInt() < data.length) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      data[value.toInt()].label,
                      style: const TextStyle(fontSize: 10),
                    ),
                  );
                }
                return const Text('');
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              getTitlesWidget: (value, meta) {
                return Text(
                  '\$${value.toInt()}',
                  style: const TextStyle(fontSize: 10),
                );
              },
            ),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
        ),
        gridData: const FlGridData(show: true),
        borderData: FlBorderData(show: false),
        barGroups: data.asMap().entries.map((entry) {
          return BarChartGroupData(
            x: entry.key,
            barRods: [
              BarChartRodData(
                toY: entry.value.value,
                color: entry.value.color,
                width: 20,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(6),
                  topRight: Radius.circular(6),
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildLineChart() {
    if (data.isEmpty) {
      return const Center(child: Text('No data available'));
    }

    return LineChart(
      LineChartData(
        gridData: const FlGridData(show: true),
        titlesData: FlTitlesData(
          show: true,
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                if (value.toInt() >= 0 && value.toInt() < data.length) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      data[value.toInt()].label,
                      style: const TextStyle(fontSize: 10),
                    ),
                  );
                }
                return const Text('');
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              getTitlesWidget: (value, meta) {
                return Text(
                  '\$${value.toInt()}',
                  style: const TextStyle(fontSize: 10),
                );
              },
            ),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: data.asMap().entries.map((entry) {
              return FlSpot(entry.key.toDouble(), entry.value.value);
            }).toList(),
            isCurved: true,
            color: data.isNotEmpty ? data[0].color : Colors.blue,
            barWidth: 3,
            dotData: const FlDotData(show: true),
            belowBarData: BarAreaData(
              show: true,
              color: data.isNotEmpty
                  ? data[0].color.withOpacity(0.3)
                  : Colors.blue.withOpacity(0.3),
            ),
          ),
        ],
      ),
    );
  }
}
