import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../shared/app_text.dart';
import '../../shared/errors.dart';
import '../../shared/logic/domain.dart';
import '../../shared/state/providers.dart';

class WeatherScreen extends ConsumerWidget {
  const WeatherScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = AppText.of(Localizations.localeOf(context));
    final asyncItems = ref.watch(weatherProvider);
    final locale = Localizations.localeOf(context).toString();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(8),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final city in defaultCities)
                ActionChip(
                  label: Text(city.label),
                  onPressed: () => _search(context, ref, text, city),
                ),
            ],
          ),
        ),
        Expanded(
          child: asyncItems.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => Center(child: Text(explainError(error, text))),
            data: (items) {
              if (items.isEmpty) {
                return Center(child: Text(text.weatherEmpty, textAlign: TextAlign.center));
              }
              return ListView.separated(
                itemCount: items.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final item = items[index];
                  return ListTile(
                    title: Text('${item.cityName}  ${item.temperature.toStringAsFixed(1)}°C  ${item.condition}'),
                    subtitle: Text('${DateFormat.yMMMd(locale).add_Hm().format(item.searchedAt.toLocal())}  ${item.humidity}%'),
                    trailing: Text(text.remaining(remainingHours(item.expireAt, DateTime.now()))),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Future<void> _search(BuildContext context, WidgetRef ref, AppText text, CityPreset city) async {
    try {
      await ref.read(apiProvider).getWeather(cityName: city.label, cityQuery: city.query);
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(explainError(error, text))));
      }
    }
  }
}
