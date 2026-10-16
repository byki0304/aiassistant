import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../app_text.dart';
import '../errors.dart';
import '../theme/toon.dart';
import '../theme/toon_icons.dart';
import '../theme/toon_widgets.dart';

/// Phones expand a row with one tap; mouse screens need a double click so a stray click does nothing.
bool get _expandsOnTap => defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS;

/// Tells [RowText] below it whether its row shows everything.
class RowExpansion extends InheritedWidget {
  const RowExpansion({super.key, required this.expanded, required super.child});

  final bool expanded;

  static bool of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<RowExpansion>()?.expanded ?? false;

  @override
  bool updateShouldNotify(RowExpansion oldWidget) => expanded != oldWidget.expanded;
}

/// Row text cut to [lines] lines, shown in full while its row is expanded.
class RowText extends StatelessWidget {
  const RowText(this.text, {super.key, this.style, this.lines = 1, this.textAlign});

  final String text;
  final TextStyle? style;
  final int lines;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) {
    final expanded = RowExpansion.of(context);
    return Text(
      text,
      style: style,
      textAlign: textAlign,
      maxLines: expanded ? null : lines,
      overflow: expanded ? TextOverflow.visible : TextOverflow.ellipsis,
    );
  }
}

/// Part of a row shown only while the row is expanded.
class RowMore extends StatelessWidget {
  const RowMore({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => RowExpansion.of(context) ? child : const SizedBox.shrink();
}

/// A list row that grows to show all of its [RowText] on a tap (phones) or a double click (mouse screens).
class RowToggle extends StatelessWidget {
  const RowToggle({super.key, required this.expanded, required this.onToggle, required this.child});

  final bool expanded;
  final VoidCallback onToggle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final text = AppText.of(Localizations.localeOf(context));
    return Semantics(
      container: true,
      expanded: expanded,
      onTapHint: expanded ? text.collapseRow : text.expandRow,
      onTap: onToggle,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _expandsOnTap ? onToggle : null,
        onDoubleTap: _expandsOnTap ? null : onToggle,
        child: AnimatedSize(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: RowExpansion(expanded: expanded, child: child),
        ),
      ),
    );
  }
}

/// The only place a row can be checked: taps elsewhere on the row expand it instead.
class RowCheck extends StatelessWidget {
  const RowCheck({super.key, required this.checked, required this.onChanged, required this.label, this.size = 22});

  final bool checked;
  final VoidCallback? onChanged;
  final String label;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      checked: checked,
      label: label,
      onTap: onChanged,
      excludeSemantics: true,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onChanged,
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: ToonCheck(checked: checked, size: size),
          ),
        ),
      ),
    );
  }
}

class SelectableRow {
  const SelectableRow({required this.id, required this.child, this.group});

  final String id;
  final Widget child;

  /// Heading shown above the first row of each run of equal groups, such as a date.
  final String? group;
}

class SelectableList extends StatefulWidget {
  const SelectableList({
    super.key,
    required this.title,
    required this.rows,
    required this.emptyText,
    required this.selectAllLabel,
    required this.deleteLabel,
    required this.onDelete,
    this.dot = Toon.sun,
    this.emptyPose = RobotPose.run,
    this.pageSize,
    this.pageLabel,
  });

  final String title;
  final List<SelectableRow> rows;
  final String emptyText;
  final String selectAllLabel;
  final String deleteLabel;
  final Future<void> Function(List<String> ids) onDelete;
  final Color dot;
  final RobotPose emptyPose;

  /// Rows per page; null shows every row in one scrolling list.
  final int? pageSize;
  final String Function(int page)? pageLabel;

  @override
  State<SelectableList> createState() => _SelectableListState();
}

class _SelectableListState extends State<SelectableList> {
  final Set<String> _selected = {};
  final Set<String> _expanded = {};
  bool _busy = false;
  int _page = 0;

  int get _pageCount {
    final size = widget.pageSize;
    return size == null || widget.rows.isEmpty ? 1 : (widget.rows.length / size).ceil();
  }

  @override
  void didUpdateWidget(SelectableList oldWidget) {
    super.didUpdateWidget(oldWidget);
    final ids = widget.rows.map((row) => row.id).toSet();
    _selected.removeWhere((id) => !ids.contains(id));
    _expanded.removeWhere((id) => !ids.contains(id));
    final oldIds = oldWidget.rows.map((row) => row.id).toSet();
    if (oldIds.length != ids.length || !oldIds.containsAll(ids)) {
      _page = 0;
    }
    _page = _page.clamp(0, _pageCount - 1);
  }

  void _toggle(String id) {
    setState(() => _selected.contains(id) ? _selected.remove(id) : _selected.add(id));
  }

  Future<void> _delete() async {
    setState(() => _busy = true);
    try {
      await widget.onDelete(_selected.toList());
      if (mounted) {
        setState(_selected.clear);
      }
    } catch (error) {
      if (mounted) {
        final text = AppText.of(Localizations.localeOf(context));
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(explainError(error, text))));
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Widget _groupHeading(String label) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 6),
      child: Row(
        children: [
          ToonDot(color: widget.dot, size: 10),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w900, color: Toon.ink),
          ),
          const SizedBox(width: 8),
          Expanded(child: Container(height: 1.5, color: Toon.ink.withValues(alpha: 0.15))),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) => _content(fill: constraints.maxHeight.isFinite));
  }

  /// [fill] takes the given height and scrolls inside it; otherwise every row is laid out for an outer scroll view.
  Widget _content({required bool fill}) {
    final rows = widget.rows;
    final size = widget.pageSize;
    final visible = size == null ? rows : rows.skip(_page * size).take(size).toList();
    final body = rows.isEmpty
        ? ToonEmpty(widget.emptyText, pose: widget.emptyPose, compact: true)
        : ListView.builder(
            shrinkWrap: !fill,
            physics: fill ? null : const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.only(bottom: 8),
            itemCount: visible.length,
            itemBuilder: (context, index) => _row(visible, index),
          );
    return Column(
      mainAxisSize: fill ? MainAxisSize.max : MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 2, 2, 8),
          child: ToonTitle(
            '${widget.title} (${rows.length})',
            dot: widget.dot,
            size: 14.5,
            trailing: rows.isEmpty
                ? null
                : _selected.isEmpty
                ? ToonButton(
                    label: widget.selectAllLabel,
                    glyph: ToonGlyph.check,
                    compact: true,
                    onPressed: _busy ? null : () => setState(() => _selected.addAll(rows.map((row) => row.id))),
                  )
                : ToonButton(
                    label: widget.deleteLabel,
                    glyph: ToonGlyph.trash,
                    compact: true,
                    color: Toon.coral,
                    onPressed: _busy ? null : _delete,
                  ),
          ),
        ),
        if (fill) Expanded(child: body) else body,
        if (_pageCount > 1)
          PageNumbers(count: _pageCount, current: _page, onSelect: (page) => setState(() => _page = page), label: widget.pageLabel),
      ],
    );
  }

  Widget _row(List<SelectableRow> visible, int index) {
    final row = visible[index];
    final checked = _selected.contains(row.id);
    final expanded = _expanded.contains(row.id);
    final heading = row.group != null && (index == 0 || visible[index - 1].group != row.group) ? row.group : null;
    final text = AppText.of(Localizations.localeOf(context));
    final item = Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.fromLTRB(2, 2, 10, 2),
        decoration: BoxDecoration(
          color: checked ? Toon.cream : Toon.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Toon.ink, width: checked ? 2.2 : 1.6),
        ),
        child: Row(
          crossAxisAlignment: expanded ? CrossAxisAlignment.start : CrossAxisAlignment.center,
          children: [
            RowCheck(checked: checked, label: text.selectEntry, onChanged: _busy ? null : () => _toggle(row.id)),
            const SizedBox(width: 4),
            Expanded(
              child: RowToggle(
                expanded: expanded,
                onToggle: () => setState(() => expanded ? _expanded.remove(row.id) : _expanded.add(row.id)),
                child: Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: row.child),
              ),
            ),
          ],
        ),
      ),
    );
    return heading == null ? item : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [_groupHeading(heading), item]);
  }
}

/// Numbered page buttons under a paged list; [current] is zero-based.
class PageNumbers extends StatelessWidget {
  const PageNumbers({super.key, required this.count, required this.current, required this.onSelect, this.label});

  final int count;
  final int current;
  final ValueChanged<int> onSelect;
  final String Function(int page)? label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 2),
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 6,
        runSpacing: 6,
        children: [
          for (var page = 0; page < count; page++)
            Pressable(
              label: label?.call(page + 1) ?? '${page + 1}',
              selected: page == current,
              onTap: () => onSelect(page),
              child: Container(
                width: 30,
                height: 30,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: page == current ? Toon.sun : Toon.white,
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(color: Toon.ink, width: page == current ? 2.2 : 1.6),
                ),
                child: Text('${page + 1}', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w900)),
              ),
            ),
        ],
      ),
    );
  }
}
