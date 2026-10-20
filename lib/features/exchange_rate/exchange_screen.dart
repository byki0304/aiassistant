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

const _currencyColors = [Toon.coral, Toon.sky, Toon.butter, Toon.leaf, Toon.lilac, Toon.pink];

class ExchangeScreen extends ConsumerStatefulWidget {
  const ExchangeScreen({super.key});

  @override
  ConsumerState<ExchangeScreen> createState() => _ExchangeScreenState();
}

class _ExchangeScreenState extends ConsumerState<ExchangeScreen> {
  String? _busy;

  Future<void> _search(AppText text, CurrencyPreset currency) async {
    setState(() => _busy = currency.code);
    try {
      await ref.read(apiProvider).getExchange(currencyCode: currency.code, currencyLabel: text.currencyLabel(currency));
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
    final asyncItems = ref.watch(exchangeProvider);
    final number = NumberFormat('#,##0.00', locale);

    final tools = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ToonTitle(text.currencySearch, dot: Toon.coral, size: 14.5),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (var i = 0; i < currencies.length; i++)
              ToonButton(
                label: text.currencyLabel(currencies[i]),
                glyph: _busy == currencies[i].code ? ToonGlyph.cloudSync : ToonGlyph.money,
                compact: true,
                color: _currencyColors[i % _currencyColors.length],
                onPressed: _busy == null ? () => _search(text, currencies[i]) : null,
              ),
          ],
        ),
      ],
    );

    final records = asyncItems.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => LoadFailure(error),
      data: (items) => SelectableList(
        title: text.exchangeHistory,
        dot: Toon.coral,
        emptyPose: RobotPose.point,
        emptyText: text.exchangeEmpty,
        selectAllLabel: text.selectAll,
        deleteLabel: text.delete,
        onDelete: (ids) => ref.read(apiProvider).deleteByIds('exchange_logs', ids),
        rows: [
          for (final item in items)
            SelectableRow(
              id: item.id,
              child: Row(
                children: [
                  const ToonIcon(ToonGlyph.exchange, size: 32),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        RowText(
                          item.currencyCode == 'JPY' && item.ratePerHundred != null
                              ? '100 JPY = ${number.format(item.ratePerHundred)} KRW'
                              : '1 ${item.currencyCode} = ${number.format(item.rateToKrw)} KRW',
                          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14.5),
                        ),
                        RowText(
                          item.rateDate == null
                              ? '${item.currencyLabel} · ${DateFormat.MMMd(locale).add_Hm().format(item.searchedAt.toLocal())}'
                              : '${item.currencyLabel} · ${DateFormat.yMMMd(locale).format(DateTime.parse(item.rateDate!))}',
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

    return MenuBody(tools: tools, records: records, toolsShare: 0.38, sidePose: RobotPose.run);
  }
}
