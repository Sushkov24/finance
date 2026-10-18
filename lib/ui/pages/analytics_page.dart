import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:finance_tracker/core/constants/palette.dart';
import 'package:finance_tracker/core/theme/app_theme.dart';
import 'package:finance_tracker/core/utils/formatters.dart';
import 'package:finance_tracker/logic/analytics_calculator.dart';
import 'package:finance_tracker/logic/finance_view_model.dart';
import 'package:finance_tracker/ui/components/common_widgets.dart';
import 'package:finance_tracker/ui/components/stat_card.dart';

class AnalyticsPage extends StatefulWidget {
  const AnalyticsPage({super.key});

  @override
  State<AnalyticsPage> createState() => _AnalyticsPageState();
}

class _AnalyticsPageState extends State<AnalyticsPage> {
  Period _period = Period.month;
  DateTime _anchor = DateTime.now();

  String _rangeLabel(PeriodRange range) => switch (_period) {
        Period.day => Fmt.day(_anchor),
        Period.week => '${Fmt.dayShort(range.start)} – ${Fmt.dayShort(range.end.subtract(const Duration(days: 1)))}',
        Period.month => Fmt.monthYear(_anchor),
        Period.year => '${_anchor.year}',
      };

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<FinanceViewModel>();
    final result = vm.analytics(_period, _anchor);
    final range = AnalyticsCalculator.rangeFor(_period, _anchor);

    return Scaffold(
      appBar: AppBar(title: const Text('Аналітика')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          SegmentedButton<Period>(
            segments: const [
              ButtonSegment(value: Period.day, label: Text('День')),
              ButtonSegment(value: Period.week, label: Text('Тиждень')),
              ButtonSegment(value: Period.month, label: Text('Місяць')),
              ButtonSegment(value: Period.year, label: Text('Рік')),
            ],
            selected: {_period},
            onSelectionChanged: (s) => setState(() => _period = s.first),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              IconButton(
                tooltip: 'Попередній період',
                onPressed: () => setState(() => _anchor = AnalyticsCalculator.shift(_period, _anchor, -1)),
                icon: const Icon(Icons.chevron_left_rounded),
              ),
              Expanded(
                child: Text(
                  _rangeLabel(range),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
              IconButton(
                tooltip: 'Наступний період',
                onPressed: () => setState(() => _anchor = AnalyticsCalculator.shift(_period, _anchor, 1)),
                icon: const Icon(Icons.chevron_right_rounded),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: StatCard(
                  title: 'Доходи',
                  value: Fmt.money(result.income),
                  icon: Icons.arrow_downward_rounded,
                  color: AppColors.income,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: StatCard(
                  title: 'Витрати',
                  value: Fmt.money(result.expense),
                  icon: Icons.arrow_upward_rounded,
                  color: AppColors.expense,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const SectionHeader(title: 'Структура витрат'),
          if (result.categories.isEmpty)
            const EmptyNotice('Немає витрат за обраний період.')
          else
            _ChartCard(
              child: Column(
                children: [
                  SizedBox(
                    height: 200,
                    child: PieChart(
                      PieChartData(
                        centerSpaceRadius: 46,
                        sectionsSpace: 2,
                        sections: [
                          for (final c in result.categories)
                            PieChartSectionData(
                              value: c.amount,
                              color: colorFromHex(c.color),
                              title: '',
                              radius: 52,
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  for (final c in result.categories)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: colorFromHex(c.color),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(child: Text(c.name)),
                          Text(Fmt.percent(c.share), style: const TextStyle(fontWeight: FontWeight.w600)),
                          const SizedBox(width: 12),
                          Text(Fmt.money(c.amount)),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          const SizedBox(height: 20),
          const SectionHeader(title: 'Динаміка'),
          _ChartCard(
            child: SizedBox(
              height: 240,
              child: LineChart(_timelineData(context, result.timeline, _period)),
            ),
          ),
        ],
      ),
    );
  }

  static LineChartData _timelineData(
    BuildContext context,
    List<TimelinePoint> points,
    Period period,
  ) {
    final step = switch (period) {
      Period.day => 4,
      Period.week => 1,
      Period.month => 5,
      Period.year => 1,
    };
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;

    List<FlSpot> spots(double Function(TimelinePoint p) pick) => [
          for (var i = 0; i < points.length; i++) FlSpot(i.toDouble(), pick(points[i])),
        ];

    return LineChartData(
      minY: 0,
      gridData: const FlGridData(drawVerticalLine: false),
      borderData: FlBorderData(show: false),
      titlesData: FlTitlesData(
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 52,
            getTitlesWidget: (value, meta) => Text(
              value >= 1000 ? '${(value / 1000).toStringAsFixed(1)}k' : value.toStringAsFixed(0),
              style: TextStyle(fontSize: 10, color: muted),
            ),
          ),
        ),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            interval: step.toDouble(),
            getTitlesWidget: (value, meta) {
              final i = value.toInt();
              if (i < 0 || i >= points.length) return const SizedBox.shrink();
              return SideTitleWidget(
                meta: meta,
                child: Text(points[i].label, style: TextStyle(fontSize: 10, color: muted)),
              );
            },
          ),
        ),
      ),
      lineBarsData: [
        LineChartBarData(
          spots: spots((p) => p.income),
          isCurved: true,
          color: AppColors.income,
          barWidth: 3,
          dotData: const FlDotData(show: false),
          belowBarData: BarAreaData(show: false),
        ),
        LineChartBarData(
          spots: spots((p) => p.expense),
          isCurved: true,
          color: AppColors.expense,
          barWidth: 3,
          dotData: const FlDotData(show: false),
          belowBarData: BarAreaData(show: false),
        ),
      ],
    );
  }
}

class _ChartCard extends StatelessWidget {
  const _ChartCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
        child: child,
      ),
    );
  }
}
