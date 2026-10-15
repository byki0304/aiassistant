import 'package:flutter/material.dart';

import '../theme/ink_icons.dart';

class SelectableRow {
  const SelectableRow({required this.id, required this.child});

  final String id;
  final Widget child;
}

class SelectableList extends StatefulWidget {
  const SelectableList({
    super.key,
    required this.title,
    required this.rows,
    required this.emptyText,
    required this.selectAllLabel,
    required this.deleteLabel,
    required this.selectedLabel,
    required this.confirmLabel,
    required this.cancelLabel,
    required this.onDelete,
  });

  final String title;
  final List<SelectableRow> rows;
  final String emptyText;
  final String selectAllLabel;
  final String deleteLabel;
  final String Function(int count) selectedLabel;
  final String Function(int count) confirmLabel;
  final String cancelLabel;
  final Future<void> Function(List<String> ids) onDelete;

  @override
  State<SelectableList> createState() => _SelectableListState();
}

class _SelectableListState extends State<SelectableList> {
  final Set<String> _selected = {};
  bool _busy = false;

  bool get _hasSelection => _selected.isNotEmpty;

  @override
  void didUpdateWidget(SelectableList oldWidget) {
    super.didUpdateWidget(oldWidget);
    final ids = widget.rows.map((row) => row.id).toSet();
    _selected.removeWhere((id) => !ids.contains(id));
  }

  Future<void> _onAction() async {
    if (!_hasSelection) {
      setState(() => _selected.addAll(widget.rows.map((row) => row.id)));
      return;
    }
    final count = _selected.length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        content: Text(widget.confirmLabel(count)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(widget.cancelLabel)),
          TextButton(onPressed: () => Navigator.pop(context, true), child: Text(widget.deleteLabel)),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }
    setState(() => _busy = true);
    try {
      await widget.onDelete(_selected.toList());
      if (mounted) {
        setState(_selected.clear);
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          color: InkPalette.blush,
          child: Row(
            children: [
              Expanded(child: Text(widget.title, style: const TextStyle(fontWeight: FontWeight.w700))),
              if (_hasSelection)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Text(widget.selectedLabel(_selected.length)),
                ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: _hasSelection ? InkPalette.coral : InkPalette.ink,
                ),
                onPressed: widget.rows.isEmpty || _busy ? null : _onAction,
                child: Text(_hasSelection ? widget.deleteLabel : widget.selectAllLabel),
              ),
            ],
          ),
        ),
        Expanded(
          child: widget.rows.isEmpty
              ? Center(child: Text(widget.emptyText, textAlign: TextAlign.center))
              : ListView.separated(
                  itemCount: widget.rows.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final row = widget.rows[index];
                    final checked = _selected.contains(row.id);
                    return Material(
                      color: checked ? InkPalette.mustard : InkPalette.cream,
                      child: InkWell(
                        onTap: () => setState(() {
                          if (checked) {
                            _selected.remove(row.id);
                          } else {
                            _selected.add(row.id);
                          }
                        }),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          child: Row(
                            children: [
                              Checkbox(
                                value: checked,
                                onChanged: (value) => setState(() {
                                  if (value == true) {
                                    _selected.add(row.id);
                                  } else {
                                    _selected.remove(row.id);
                                  }
                                }),
                              ),
                              Expanded(child: row.child),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
