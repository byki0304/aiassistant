import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../shared/app_text.dart';
import '../../shared/errors.dart';
import '../../shared/logic/domain.dart';
import '../../shared/state/providers.dart';
import '../../shared/theme/toon.dart';
import '../../shared/theme/toon_icons.dart';
import '../../shared/theme/toon_widgets.dart';
import '../../shared/widgets/menu_body.dart';
import '../../shared/widgets/selectable_list.dart';

const _cityColors = [Toon.sky, Toon.pink, Toon.butter, Toon.leaf, Toon.lilac, Toon.coral];

class WeatherScreen extends ConsumerStatefulWidget {
  const WeatherScreen({super.key});

  @override
  ConsumerState<WeatherScreen> createState() => _WeatherScreenState();
}

class _WeatherScreenState extends ConsumerState<WeatherScreen> {
  String? _busy;

  Future<void> _search(AppText text, CityPreset city) async {
    setState(() => _busy = city.query);
    try {
      await ref.read(apiProvider).getWeather(cityName: city.label, cityQuery: city.query);
    } catch (error) {
      if (mounted) {
        showToonMessage(context, explainError(error, text));
      }
    } finally {
      if (mounted) {
        setState(() => _busy = null);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = AppText.of(Localizations.localeOf(context));
    final locale = Localizations.localeOf(context).toString();
    final asyncItems = ref.watch(weatherProvider);

    final tools = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ToonTitle(text.citySearch, dot: Toon.sky, size: 14.5),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (var i = 0; i < defaultCities.length; i++)
              ToonButton(
                label: defaultCities[i].label,
                glyph: _busy == defaultCities[i].query ? ToonGlyph.cloudSync : ToonGlyph.pin,
                compact: true,
                color: _cityColors[i % _cityColors.length],
                onPressed: _busy == null ? () => _search(text, defaultCities[i]) : null,
              ),
          ],
        ),
      ],
    );

    final records = asyncItems.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => LoadFailure(error),
      data: (items) => SelectableList(
        title: text.weatherHistory,
        dot: Toon.sky,
        emptyPose: RobotPose.point,
        emptyText: text.weatherEmpty,
        selectAllLabel: text.selectAll,
        deleteLabel: text.delete,
        onDelete: (ids) => ref.read(apiProvider).deleteByIds('weather_logs', ids),
        rows: [
          for (final item in items)
            SelectableRow(
              id: item.id,
              child: Row(
                children: [
                  ToonIcon(weatherGlyph(item.condition), size: 34),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        RowText(
                          '${item.cityName}  ${item.temperature.toStringAsFixed(1)}°C',
                          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14.5),
                        ),
                        RowText(
                          '${item.condition} · ${item.humidity}% · ${DateFormat.MMMd(locale).add_Hm().format(item.searchedAt.toLocal())}',
                          style: const TextStyle(fontSize: 11.5, color: Toon.inkSoft, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  ToonPill(text.remaining(remainingHours(item.expireAt, DateTime.now())), color: Toon.cream),
                ],
              ),
            ),
        ],
      ),
    );

    return MenuBody(tools: tools, records: records, toolsShare: 0.38, sidePose: RobotPose.wave);
  }
}
