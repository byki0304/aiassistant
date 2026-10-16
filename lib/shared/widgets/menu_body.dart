import 'package:flutter/material.dart';

import '../app_text.dart';
import '../errors.dart';
import '../theme/toon_widgets.dart';

/// Menu content: tools beside the records when the pane is wide, stacked when narrow,
/// and one scrolling column when the pane is too short to give the records their own room.
class MenuBody extends StatelessWidget {
  const MenuBody({
    super.key,
    required this.tools,
    required this.records,
    this.splitAt = 600,
    this.toolsShare = 0.42,
    this.scrollBelow = 560,
    this.sidePose,
  });

  final Widget tools;

  /// Must cope with unbounded height, as [SelectableList] does.
  final Widget records;
  final double splitAt;
  final double toolsShare;
  final double scrollBelow;

  /// Robot sticker shown under the tools only when there is room beside the records.
  final RobotPose? sidePose;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= splitAt) {
          return Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: constraints.maxWidth * toolsShare,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.only(bottom: 6, right: 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        tools,
                        if (sidePose != null && constraints.maxHeight > 360) ...[
                          const SizedBox(height: 22),
                          Center(child: RobotArt(sidePose!, height: 110, bob: true)),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(child: records),
              ],
            ),
          );
        }
        if (constraints.maxHeight < scrollBelow) {
          return ListView(padding: const EdgeInsets.fromLTRB(10, 10, 10, 8), children: [tools, const SizedBox(height: 10), records]);
        }
        return Padding(
          padding: const EdgeInsets.fromLTRB(10, 10, 10, 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              tools,
              const SizedBox(height: 10),
              Expanded(child: records),
            ],
          ),
        );
      },
    );
  }
}

class LoadFailure extends StatelessWidget {
  const LoadFailure(this.error, {super.key});

  final Object error;

  @override
  Widget build(BuildContext context) {
    final text = AppText.of(Localizations.localeOf(context));
    return ToonEmpty(explainError(error, text), pose: RobotPose.head, compact: true);
  }
}

void showToonMessage(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}
