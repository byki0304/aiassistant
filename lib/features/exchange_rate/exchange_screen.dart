import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../shared/app_text.dart';
import '../../shared/errors.dart';
import '../../shared/logic/domain.dart';
import '../../shared/state/providers.dart';

class ExchangeScreen extends ConsumerWidget {
  const ExchangeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = AppText.of(Localizations.localeOf(context));
    final asyncItems = ref.watch(exchangeProvider);
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
              for (final currency in currencies)
                ActionChip(
                  label: Text(text.currencyLabel(currency)),
                  onPressed: () => _search(context, ref, text, currency),
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
                return Center(child: Text(text.exchangeEmpty, textAlign: TextAlign.center));
              }
              return ListView.separated(
                itemCount: items.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final item = items[index];
                  final rate = item.currencyCode == 'JPY' && item.ratePerHundred != null
                      ? '1 JPY ${item.rateToKrw.toStringAsFixed(2)} / 100 JPY ${item.ratePerHundred!.toStringAsFixed(2)}'
                      : '1 ${item.currencyCode} ${item.rateToKrw.toStringAsFixed(2)}';
                  return ListTile(
                    title: Text('${item.currencyLabel}  $rate'),
                    subtitle: Text(DateFormat.yMMMd(locale).add_Hm().format(item.searchedAt.toLocal())),
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

  Future<void> _search(BuildContext context, WidgetRef ref, AppText text, CurrencyPreset currency) async {
    try {
      await ref.read(apiProvider).getExchange(
            currencyCode: currency.code,
            currencyLabel: text.currencyLabel(currency),
          );
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(explainError(error, text))));
      }
    }
  }
}
