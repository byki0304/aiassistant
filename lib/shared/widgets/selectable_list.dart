import 'package:flutter/material.dart';

import '../app_text.dart';
import '../errors.dart';
import '../theme/toon.dart';
import '../theme/toon_icons.dart';
import '../theme/toon_widgets.dart';

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
    final rows = widget.rows;
    final size = widget.pageSize;
    final visible = size == null ? rows : rows.skip(_page * size).take(size).toList();
    return Column(
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
        Expanded(
          child: rows.isEmpty
              ? ToonEmpty(widget.emptyText, pose: widget.emptyPose, compact: true)
              : ListView.builder(
                  padding: const EdgeInsets.only(bottom: 8),
                  itemCount: visible.length,
                  itemBuilder: (context, index) {
                    final row = visible[index];
                    final checked = _selected.contains(row.id);
                    final heading = row.group != null && (index == 0 || visible[index - 1].group != row.group) ? row.group : null;
                    final item = Padding(
                      padding: const EdgeInsets.only(bottom: 7),
                      child: Semantics(
                        container: true,
                        checked: checked,
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => _toggle(row.id),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            padding: const EdgeInsets.fromLTRB(8, 8, 10, 8),
                            decoration: BoxDecoration(
                              color: checked ? Toon.cream : Toon.white,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: Toon.ink, width: checked ? 2.2 : 1.6),
                            ),
                            child: Row(
                              children: [
                                ToonCheck(checked: checked),
                                const SizedBox(width: 10),
                                Expanded(child: row.child),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                    return heading == null
                        ? item
                        : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [_groupHeading(heading), item]);
                  },
                ),
        ),
        if (_pageCount > 1)
          PageNumbers(count: _pageCount, current: _page, onSelect: (page) => setState(() => _page = page), label: widget.pageLabel),
      ],
    );
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
