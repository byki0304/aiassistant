import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../logic/domain.dart';

class ChartBlock extends StatelessWidget {
  const ChartBlock({super.key, required this.chart});

  final ChartModel chart;

  @override
  Widget build(BuildContext context) {
    if (chart.isEmpty) {
      return const SizedBox.shrink();
    }
    return SizedBox(
      height: 180,
      child: Padding(
        padding: const EdgeInsets.only(top: 8),
        child: switch (chart.type) {
          'line' => _line(),
          'pie' => _pie(),
          _ => _bar(),
        },
      ),
    );
  }

  Widget _bar() {
    return BarChart(
      BarChartData(
        borderData: FlBorderData(show: false),
        gridData: const FlGridData(show: false),
        barGroups: [
          for (var i = 0; i < chart.values.length; i++)
            BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: chart.values[i],
                  width: 14,
                  color: const Color(0xFF0F4C5C),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                ),
              ],
            ),
        ],
        titlesData: _titles(),
      ),
    );
  }

  Widget _line() {
    return LineChart(
      LineChartData(
        borderData: FlBorderData(show: false),
        gridData: const FlGridData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: [
              for (var i = 0; i < chart.values.length; i++) FlSpot(i.toDouble(), chart.values[i]),
            ],
            color: const Color(0xFF0F4C5C),
            barWidth: 3,
            dotData: const FlDotData(show: true),
          ),
        ],
        titlesData: _titles(),
      ),
    );
  }

  Widget _pie() {
    const colors = [Color(0xFF0F4C5C), Color(0xFF1D7A72), Color(0xFFC2410C), Color(0xFFCA8A04)];
    return PieChart(
      PieChartData(
        sections: [
          for (var i = 0; i < chart.values.length; i++)
            PieChartSectionData(
              value: chart.values[i].abs() == 0 ? 0.01 : chart.values[i].abs(),
              title: chart.labels[i],
              radius: 58,
              color: colors[i % colors.length],
              titleStyle: const TextStyle(fontSize: 10, color: Colors.white),
            ),
        ],
      ),
    );
  }

  FlTitlesData _titles() {
    return FlTitlesData(
      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 36)),
      bottomTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          getTitlesWidget: (value, meta) {
            final index = value.toInt();
            if (index < 0 || index >= chart.labels.length) {
              return const SizedBox.shrink();
            }
            return Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(chart.labels[index], style: const TextStyle(fontSize: 10)),
            );
          },
        ),
      ),
    );
  }
}

class TableBlock extends StatelessWidget {
  const TableBlock({super.key, required this.table});

  final TableModel table;

  @override
  Widget build(BuildContext context) {
    if (table.isEmpty) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Table(
          defaultColumnWidth: const IntrinsicColumnWidth(),
          border: TableBorder.all(color: const Color(0xFFD5DDD4)),
          children: [
            TableRow(
              decoration: const BoxDecoration(color: Color(0xFFF3F8F1)),
              children: [for (final header in table.headers) _cell(header, true)],
            ),
            for (final row in table.rows)
              TableRow(children: [for (final cell in row) _cell(cell, false)]),
          ],
        ),
      ),
    );
  }

  Widget _cell(String text, bool header) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Text(text, style: TextStyle(fontWeight: header ? FontWeight.w700 : FontWeight.w500, fontSize: 12)),
    );
  }
}
