// «القصص» (design 06) and «الأخلاق»: pages driven only by approved items.
//
// A story page is told with PLACES, LIGHT and OBJECTS ([KidsSceneArt] over the
// closed [KidsArt] list): never a face or a figure of a prophet or a companion.
import 'package:flutter/material.dart';

import '../../../../core/i18n/formatters.dart';
import '../../../../core/i18n/gen/app_localizations.dart';
import '../application/faith_providers.dart';
import '../domain/kids_religious_item.dart';
import 'widgets/approved_gate.dart';
import 'widgets/kids_faith_ui.dart';
import 'widgets/kids_scene_art.dart';

class StoriesScreen extends StatefulWidget {
  const StoriesScreen({super.key});

  @override
  State<StoriesScreen> createState() => _StoriesScreenState();
}

class _StoriesScreenState extends State<StoriesScreen> {
  String? _selected;

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    return PopScope(
      canPop: _selected == null,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) setState(() => _selected = null);
      },
      child: KidsFaithScaffold(
        title: l.kidsFaithStoriesTitle,
        dark: true,
        background: const BoxDecoration(
          gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [KP.night900, KP.night700]),
        ),
        child: KidsApprovedItems(
          dark: true,
          kinds: const {KidsReligiousKind.story},
          builder: (context, items) {
            final stories = _groups(kidsItemsOfKind(items, KidsReligiousKind.story));
            final keys = stories.keys.toList();
            final sel = _selected ?? (keys.length == 1 ? keys.single : null);
            if (sel == null || !stories.containsKey(sel)) {
              return _StoryList(stories: stories, onPick: (k) => setState(() => _selected = k));
            }
            final pages = stories[sel]!;
            return KidsPager(
              count: pages.length,
              pageBuilder: (context, i) => _StoryPage(page: pages[i], number: i + 1, total: pages.length),
            );
          },
        ),
      ),
    );
  }

  Map<String, List<KidsReligiousItem>> _groups(List<KidsReligiousItem> sorted) {
    final m = <String, List<KidsReligiousItem>>{};
    for (final i in sorted) {
      (m[i.group ?? ''] ??= []).add(i);
    }
    return m;
  }
}

class _StoryList extends StatelessWidget {
  const _StoryList({required this.stories, required this.onPick});

  final Map<String, List<KidsReligiousItem>> stories;
  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final fmt = MadarFormatter.of(context);
    var n = 0;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Center(child: Text(l.kidsFaithStoryPicker, style: const TextStyle(fontFamily: KP.heading, fontSize: 26, color: Colors.white))),
        const SizedBox(height: 12),
        for (final e in stories.entries)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: KidsBigButton(
              label: _title(e.value) ?? fmt.formatInt(++n),
              onPressed: () => onPick(e.key),
              icon: Icons.auto_stories_rounded,
            ),
          ),
      ],
    );
  }

  String? _title(List<KidsReligiousItem> pages) {
    for (final p in pages) {
      if (p.title != null && p.title!.trim().isNotEmpty) return p.title;
    }
    return null;
  }
}

class _StoryPage extends StatelessWidget {
  const _StoryPage({required this.page, required this.number, required this.total});

  final KidsReligiousItem page;
  final int number;
  final int total;

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final fmt = MadarFormatter.of(context);
    return Column(
      children: [
        KidsSceneArt(art: page.art, height: 280),
        const SizedBox(height: 12),
        DecoratedBox(
          decoration: BoxDecoration(color: KP.paper, borderRadius: BorderRadius.circular(32)),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(l.kidsFaithPageOfTotal(fmt.formatInt(number), fmt.formatInt(total)), style: const TextStyle(fontFamily: KP.body, fontSize: 16, color: KP.ink2)),
                ),
                if (page.title != null && page.title!.trim().isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(page.title!, textAlign: TextAlign.center, style: const TextStyle(fontFamily: KP.heading, fontSize: 28, color: KP.night900)),
                ],
                const SizedBox(height: 8),
                Text(page.arabicText, textAlign: TextAlign.center, style: const TextStyle(fontFamily: KP.body, fontWeight: FontWeight.w500, fontSize: 22, height: 1.7, color: KP.ink)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// «الأخلاق»: one card per approved manner.
class MannersScreen extends StatelessWidget {
  const MannersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final fmt = MadarFormatter.of(context);
    return KidsFaithScaffold(
      title: l.kidsFaithMannersTitle,
      background: const BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [KP.sun100, KP.paper]),
      ),
      child: KidsApprovedItems(
        kinds: const {KidsReligiousKind.manner},
        builder: (context, items) {
          final manners = kidsItemsOfKind(items, KidsReligiousKind.manner);
          return KidsPager(
            count: manners.length,
            pageBuilder: (context, i) {
              final m = manners[i];
              return Column(
                children: [
                  if (m.art.isNotEmpty) KidsSceneArt(art: m.art, height: 200, dayTone: true),
                  const SizedBox(height: 12),
                  Text(l.kidsFaithPageOfTotal(fmt.formatInt(i + 1), fmt.formatInt(manners.length)), style: const TextStyle(fontFamily: KP.body, fontSize: 16, color: KP.ink2)),
                  if (m.title != null && m.title!.trim().isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(m.title!, textAlign: TextAlign.center, style: const TextStyle(fontFamily: KP.heading, fontSize: 30, color: KP.night900)),
                  ],
                  const SizedBox(height: 8),
                  Text(m.arabicText, textAlign: TextAlign.center, style: const TextStyle(fontFamily: KP.body, fontWeight: FontWeight.w500, fontSize: 22, height: 1.7, color: KP.ink)),
                ],
              );
            },
          );
        },
      ),
    );
  }
}
