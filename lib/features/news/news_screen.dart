import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../shared/api/assistant_api.dart';
import '../../shared/app_text.dart';
import '../../shared/errors.dart';
import '../../shared/pdf_export.dart';
import '../../shared/state/providers.dart';
import '../../shared/widgets/selectable_list.dart';

class NewsScreen extends ConsumerWidget {
  const NewsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = AppText.of(Localizations.localeOf(context));
    final asyncItems = ref.watch(newsProvider);
    final locale = Localizations.localeOf(context).toString();
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            children: [
              Expanded(child: FilledButton(onPressed: () => _load(context, ref, text, 'USA'), child: Text(text.usNews))),
              const SizedBox(width: 8),
              Expanded(child: FilledButton(onPressed: () => _load(context, ref, text, 'JAPAN'), child: Text(text.jpNews))),
            ],
          ),
        ),
        Expanded(
          child: asyncItems.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => Center(child: Text(explainError(error, text))),
            data: (items) => SelectableList(
              title: text.menuName('news'),
              rows: [
                for (final item in items)
                  SelectableRow(
                    id: item.id,
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(item.title, maxLines: 2, overflow: TextOverflow.ellipsis),
                              Text('${item.country} · ${item.source} · ${DateFormat.MMMd(locale).format(item.publishedAt.toLocal())}', style: const TextStyle(fontSize: 12)),
                            ],
                          ),
                        ),
                        TextButton(onPressed: () => _script(context, ref, text, item), child: Text(text.script)),
                      ],
                    ),
                  ),
              ],
              emptyText: text.emptyData,
              selectAllLabel: text.selectAll,
              deleteLabel: text.delete,
              selectedLabel: text.selectedCount,
              confirmLabel: text.deleteConfirm,
              cancelLabel: text.cancel,
              onDelete: (ids) => ref.read(apiProvider).deleteByIds('news_items', ids),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _load(BuildContext context, WidgetRef ref, AppText text, String country) async {
    try {
      await ref.read(apiProvider).getNews(country);
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(explainError(error, text))));
      }
    }
  }

  Future<void> _script(BuildContext context, WidgetRef ref, AppText text, NewsItem item) async {
    try {
      final locale = Localizations.localeOf(context).languageCode;
      final script = await ref.read(apiProvider).scriptNews(newsId: item.id, locale: locale);
      await downloadScriptPdf(title: item.title, body: script);
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(explainError(error, text))));
      }
    }
  }
}
