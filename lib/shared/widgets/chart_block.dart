import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../logic/domain.dart';
import '../theme/toon.dart';

const _palette = [Toon.sky, Toon.coral, Toon.leaf, Toon.lilac, Toon.butter, Toon.pink];

class ChartBlock extends StatelessWidget {
  const ChartBlock({super.key, required this.chart, this.height = 170});

  final ChartModel chart;
  final double height;

  @override
  Widget build(BuildContext context) {
    if (chart.isEmpty) {
      return const SizedBox.shrink();
    }
    return Container(
      height: height,
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.fromLTRB(6, 12, 12, 4),
      decoration: BoxDecoration(
        color: Toon.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Toon.ink, width: 1.8),
      ),
      child: switch (chart.type) {
        'line' => _line(),
        'pie' => _pie(),
        _ => _bar(),
      },
    );
  }

  Widget _bar() {
    return BarChart(
      BarChartData(
        borderData: FlBorderData(
          show: true,
          border: const Border(bottom: BorderSide(color: Toon.ink, width: 1.6)),
        ),
        gridData: const FlGridData(show: false),
        barTouchData: BarTouchData(enabled: true),
        barGroups: [
          for (var i = 0; i < chart.values.length; i++)
            BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: chart.values[i],
                  width: 22,
                  color: _palette[i % _palette.length],
                  borderSide: const BorderSide(color: Toon.ink, width: 1.4),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(5)),
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
        borderData: FlBorderData(
          show: true,
          border: const Border(bottom: BorderSide(color: Toon.ink, width: 1.6)),
        ),
        gridData: const FlGridData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: [for (var i = 0; i < chart.values.length; i++) FlSpot(i.toDouble(), chart.values[i])],
            color: Toon.navy,
            barWidth: 3,
            isCurved: true,
            belowBarData: BarAreaData(show: true, color: Toon.sky.withValues(alpha: 0.35)),
            dotData: const FlDotData(show: true),
          ),
        ],
        titlesData: _titles(),
      ),
    );
  }

  Widget _pie() {
    return PieChart(
      PieChartData(
        sectionsSpace: 2,
        sections: [
          for (var i = 0; i < chart.values.length; i++)
            PieChartSectionData(
              value: chart.values[i].abs() == 0 ? 0.01 : chart.values[i].abs(),
              title: chart.labels[i],
              radius: 56,
              color: _palette[i % _palette.length],
              borderSide: const BorderSide(color: Toon.ink, width: 1.4),
              titleStyle: const TextStyle(fontSize: 10, color: Toon.ink, fontWeight: FontWeight.w800),
            ),
        ],
      ),
    );
  }

  FlTitlesData _titles() {
    return FlTitlesData(
      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      leftTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 40,
          getTitlesWidget: (value, meta) => Text(meta.formattedValue, style: const TextStyle(fontSize: 9.5, color: Toon.inkSoft)),
        ),
      ),
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
              child: Text(chart.labels[index], style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700)),
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
    return Container(
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        color: Toon.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Toon.ink, width: 1.8),
      ),
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Table(
          defaultColumnWidth: const IntrinsicColumnWidth(),
          border: TableBorder(
            horizontalInside: BorderSide(color: Toon.ink.withValues(alpha: 0.25)),
            verticalInside: BorderSide(color: Toon.ink.withValues(alpha: 0.25)),
          ),
          children: [
            TableRow(
              children: [
                for (var i = 0; i < table.headers.length; i++)
                  ColoredBox(color: _palette[(i + 4) % _palette.length].withValues(alpha: 0.75), child: _cell(table.headers[i], true)),
              ],
            ),
            for (var r = 0; r < table.rows.length; r++)
              TableRow(
                decoration: BoxDecoration(color: r.isOdd ? Toon.cream.withValues(alpha: 0.5) : Toon.white),
                children: [for (var c = 0; c < table.headers.length; c++) _cell(c < table.rows[r].length ? table.rows[r][c] : '', false)],
              ),
          ],
        ),
      ),
    );
  }

  Widget _cell(String text, bool header) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: Text(text, style: TextStyle(fontWeight: header ? FontWeight.w900 : FontWeight.w600, fontSize: 12)),
    );
  }
}
