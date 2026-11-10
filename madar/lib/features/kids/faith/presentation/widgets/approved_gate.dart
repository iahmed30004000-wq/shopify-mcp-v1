import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/faith_providers.dart';
import '../../domain/kids_religious_item.dart';
import 'kids_faith_ui.dart';

/// Builds [builder] with the approved items of [kinds]; shows the calm
/// «قريبًا» while loading, on error, when the gate is shut and when nothing
/// is approved. This is the ONLY way the item screens reach religious text.
class KidsApprovedItems extends ConsumerWidget {
  const KidsApprovedItems({super.key, required this.kinds, required this.builder, this.dark = false});

  final Set<KidsReligiousKind> kinds;
  final Widget Function(BuildContext context, List<KidsReligiousItem> items) builder;
  final bool dark;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(kidsApprovedItemsProvider).value ?? const <KidsReligiousItem>[];
    final mine = [for (final i in items) if (kinds.contains(i.kind)) i];
    if (mine.isEmpty) return KidsSoonState(dark: dark);
    return builder(context, mine);
  }
}
