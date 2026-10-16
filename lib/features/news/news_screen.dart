import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../shared/api/assistant_api.dart';
import '../../shared/app_text.dart';
import '../../shared/errors.dart';
import '../../shared/pdf_export.dart';
import '../../shared/state/providers.dart';
import '../../shared/theme/toon.dart';
import '../../shared/theme/toon_icons.dart';
import '../../shared/theme/toon_widgets.dart';
import '../../shared/widgets/menu_body.dart';
import '../../shared/widgets/selectable_list.dart';

class NewsScreen extends ConsumerStatefulWidget {
  const NewsScreen({super.key});

  @override
  ConsumerState<NewsScreen> createState() => _NewsScreenState();
}

class _NewsScreenState extends ConsumerState<NewsScreen> {
  String? _busy;

  Future<void> _load(AppText text, String country) async {
    setState(() => _busy = country);
    try {
      await ref.read(apiProvider).getNews(country);
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

  Future<void> _script(AppText text, NewsItem item) async {
    setState(() => _busy = item.id);
    try {
      final locale = Localizations.localeOf(context).languageCode;
      final script = await ref.read(apiProvider).scriptNews(newsId: item.id, locale: locale);
      await downloadScriptPdf(title: item.title, body: script);
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

    Widget countryButton(String country, String label, ToonGlyph flag, Color color) {
      return ToonButton(
        label: label,
        subtitle: _busy == country ? '…' : text.latestFive,
        glyph: flag,
        color: color,
        textColor: Toon.white,
        onPressed: _busy == null ? () => _load(text, country) : null,
      );
    }

    final tools = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ToonTitle(text.newsHeadline, dot: Toon.lilac, size: 14.5),
        const SizedBox(height: 10),
        LayoutBuilder(
          builder: (context, constraints) {
            final us = countryButton('USA', text.usNews, ToonGlyph.flagUs, Toon.navy);
            final jp = countryButton('JAPAN', text.jpNews, ToonGlyph.flagJp, Toon.red);
            if (constraints.maxWidth < 300) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [us, const SizedBox(height: 10), jp, const SizedBox(height: 14), const RobotArt(RobotPose.point, height: 90)],
              );
            }
            return Row(
              children: [
                Expanded(child: us),
                const SizedBox(width: 10),
                Expanded(child: jp),
              ],
            );
          },
        ),
      ],
    );

    final records = ref
        .watch(newsProvider)
        .when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => LoadFailure(error),
          data: (items) => SelectableList(
            title: text.newsArchive,
            dot: Toon.lilac,
            emptyPose: RobotPose.point,
            rows: [
              for (final item in items)
                SelectableRow(
                  id: item.id,
                  child: Row(
                    children: [
                      ToonIcon(item.country == 'JAPAN' ? ToonGlyph.flagJp : ToonGlyph.flagUs, size: 26),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            RowText(item.title, lines: 2, style: const TextStyle(fontWeight: FontWeight.w800, height: 1.3)),
                            RowText(
                              '${item.source} · ${DateFormat.MMMd(locale).add_Hm().format(item.publishedAt.toLocal())}',
                              style: const TextStyle(fontSize: 11.5, color: Toon.inkSoft, fontWeight: FontWeight.w600),
                            ),
                            if (item.summary.isNotEmpty)
                              RowMore(
                                child: Padding(
                                  padding: const EdgeInsets.only(top: 6),
                                  child: Text(
                                    item.summary,
                                    style: const TextStyle(fontSize: 12.5, height: 1.4, fontWeight: FontWeight.w600),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                      ToonButton(
                        label: text.script,
                        glyph: _busy == item.id ? ToonGlyph.cloudSync : ToonGlyph.news,
                        compact: true,
                        color: Toon.lilac,
                        onPressed: _busy == null ? () => _script(text, item) : null,
                      ),
                    ],
                  ),
                ),
            ],
            emptyText: text.emptyData,
            selectAllLabel: text.selectAll,
            deleteLabel: text.delete,
            onDelete: (ids) => ref.read(apiProvider).deleteByIds('news_items', ids),
          ),
        );

    return MenuBody(tools: tools, records: records, toolsShare: 0.34);
  }
}
