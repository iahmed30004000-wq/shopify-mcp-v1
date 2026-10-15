import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/widgets.dart';
import '../../../../core/i18n/gen/app_localizations.dart';
import '../../../../core/motion/motion_kit.dart';
import '../../data/day_chat_providers.dart';
import '../day_chat_texts.dart';

/// «شو صار اليوم؟» – his own day read back to him, out of his own data.
///
/// Everything here is counted on the phone: no AI, no network, nothing that
/// is not already in his database. A day with nothing in it says exactly
/// that in one sentence and is not decorated: an empty day is a fact, not
/// an occasion for an illustration.
class DaySummaryView extends ConsumerWidget {
  const DaySummaryView({super.key, required this.day});

  final DateTime day;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L10n.of(context);
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final tx = DayChatTexts.of(context);
    final summary = ref.watch(dayChatSummaryProvider(day)).value;
    if (summary == null) return const Center(child: OrbitLoader());
    final lines = tx.summary(summary);

    return EntranceChoreo(
      id: ('dayChat.summary', day),
      child: ListView(
        key: const ValueKey('dayChat.summary'),
        padding: const EdgeInsetsDirectional.fromSTEB(Space.gutter, Space.s, Space.gutter, 120),
        children: [
          StaggerItem(
            index: 0,
            child: GlassPanel(
              seed: 7.1,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Semantics(
                    header: true,
                    child: Text(
                      tx.summaryTitle(summary.day),
                      style: text.titleLarge?.copyWith(color: t.textPrimary),
                    ),
                  ),
                  const SizedBox(height: Space.m),
                  for (final line in lines)
                    Padding(
                      padding: const EdgeInsetsDirectional.only(bottom: Space.s),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsetsDirectional.only(top: 7, end: Space.s),
                            child: Container(
                              width: 5,
                              height: 5,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: summary.isEmpty ? t.textTertiary : t.accent,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              line,
                              style: text.bodyMedium?.copyWith(
                                color: summary.isEmpty ? t.textSecondary : t.textPrimary,
                                height: 1.6,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (!summary.isEmpty) ...[
                    const SizedBox(height: Space.s),
                    Row(
                      children: [
                        Icon(Icons.wifi_off_rounded, size: 14, color: t.textTertiary),
                        const SizedBox(width: Space.xs),
                        Expanded(
                          child: Text(
                            l.dayChatSummaryOffline,
                            style: text.bodySmall?.copyWith(color: t.textTertiary, height: 1.45),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
