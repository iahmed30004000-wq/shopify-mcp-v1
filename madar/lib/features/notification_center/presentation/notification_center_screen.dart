import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/tokens.dart';
import '../../../core/design/widgets/widgets.dart';
import '../../../core/motion/motion_kit.dart';
import '../../../core/notifications/notification_providers.dart';
import '../../../core/sound/sound_api.dart';
import '../data/center_controller.dart';
import '../domain/center_models.dart';
import '../domain/center_texts.dart';
import 'center_actions.dart';
import 'widgets/group_section.dart';
import 'widgets/notification_settings_summary.dart';

/// The center's two lists.
enum CenterTab { upcoming, recent }

/// The notification center: **Upcoming** (the next seven days, by group)
/// and **Recent** (what arrived, by group, newest first), with a group's
/// mute a tap away and every group's reminder settings behind the tune
/// button.
///
/// Opens on Recent when something is new, else on Upcoming. What is new
/// stays highlighted while the Recent tab is on screen and counts as seen
/// once the user leaves it.
class NotificationCenterScreen extends ConsumerStatefulWidget {
  const NotificationCenterScreen({super.key, this.initialTab, this.animateBackdrop = true});

  /// Null: Recent when something is new, else Upcoming.
  final CenterTab? initialTab;

  /// Pass false in battery-saver mode.
  final bool animateBackdrop;

  @override
  ConsumerState<NotificationCenterScreen> createState() => _NotificationCenterScreenState();
}

class _NotificationCenterScreenState extends ConsumerState<NotificationCenterScreen> {
  late CenterTab _tab;
  bool _sawRecent = false;

  /// The tab is still the screen's own choice (made once the first look
  /// is done), not the user's.
  bool _autoTab = false;
  late final NotificationCenterController _controller;

  @override
  void initState() {
    super.initState();
    _controller = ref.read(notificationCenterProvider.notifier);
    final s = ref.read(notificationCenterProvider);
    _tab = widget.initialTab ?? (s.unread > 0 ? CenterTab.recent : CenterTab.upcoming);
    _sawRecent = _tab == CenterTab.recent;
    _autoTab = widget.initialTab == null && !s.loaded;
    if (_autoTab) {
      ref.listenManual(notificationCenterProvider, (_, next) {
        if (!_autoTab || !next.loaded || !mounted) return;
        _autoTab = false;
        if (next.unread > 0 && _tab != CenterTab.recent) {
          setState(() {
            _tab = CenterTab.recent;
            _sawRecent = true;
          });
        }
      });
    }
    unawaited(_controller.refresh());
  }

  @override
  void dispose() {
    if (_sawRecent) unawaited(_controller.markSeen());
    super.dispose();
  }

  void _select(CenterTab tab) {
    _autoTab = false;
    if (_tab == CenterTab.recent && tab != CenterTab.recent) unawaited(_controller.markSeen());
    setState(() {
      _tab = tab;
      if (tab == CenterTab.recent) _sawRecent = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final tx = CenterTexts.of(context);
    final l = tx.l;
    final s = ref.watch(notificationCenterProvider);
    return MadarScaffold(
      title: l.ncTitle,
      backdropSeed: 5.3,
      animateBackdrop: widget.animateBackdrop,
      actions: [
        MadarButton.icon(
          icon: Icons.tune_rounded,
          semanticLabel: l.ncOpenSettings,
          variant: MadarButtonVariant.ghost,
          sfx: Sfx.sheetOpen,
          onPressed: () => showNotificationSettingsSheet(context, ref),
        ),
      ],
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(Space.gutter, Space.xs, Space.gutter, Space.s),
            child: CenterTabBar(value: _tab, upcoming: s.upcoming.length, unread: s.unread, onChanged: _select),
          ),
          if (s.loaded && !s.permitted) const _PermissionBanner(),
          if (s.mutes.isNotEmpty) _MuteStrip(mutes: s.mutes),
          Expanded(
            child: _FadeStack(
              index: _tab.index,
              children: const [
                _EdgeFade(child: _UpcomingList(key: ValueKey('nc.upcoming'))),
                _EdgeFade(child: _RecentList(key: ValueKey('nc.recent'))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _UpcomingList extends ConsumerWidget {
  const _UpcomingList({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(notificationCenterProvider);
    final tx = CenterTexts.of(context);
    final l = tx.l;
    if (!s.loaded) return const SizedBox.shrink();
    if (s.upcoming.isEmpty) {
      return _Empty(kind: EmptyStateKind.noData, title: l.ncUpcomingEmptyTitle, body: l.ncUpcomingEmptyBody);
    }
    final sections = s.upcomingSections;
    return EntranceChoreo(
      id: 'nc.upcoming',
      child: ListView(
        padding: const EdgeInsetsDirectional.fromSTEB(Space.gutter, Space.xs, Space.gutter, 120),
        children: [
          _Caption(text: tx.digits(l.ncUpcomingCount(s.upcoming.length))),
          for (var i = 0; i < sections.length; i++)
            StaggerItem(
              index: i,
              blur: false,
              child: CenterGroupSection(key: ValueKey('up.${sections[i].group.name}'), section: sections[i]),
            ),
        ],
      ),
    );
  }
}

class _RecentList extends ConsumerWidget {
  const _RecentList({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(notificationCenterProvider);
    final tx = CenterTexts.of(context);
    final l = tx.l;
    if (!s.loaded) return const SizedBox.shrink();
    if (s.recent.isEmpty) {
      return _Empty(kind: EmptyStateKind.emptyList, title: l.ncRecentEmptyTitle, body: l.ncRecentEmptyBody);
    }
    final sections = s.recentSections;
    final caption = tx.digits([l.ncRecentCount(s.recent.length), if (s.unread > 0) l.ncNewCount(s.unread)].join(' · '));
    return EntranceChoreo(
      id: 'nc.recent',
      child: ListView(
        padding: const EdgeInsetsDirectional.fromSTEB(Space.gutter, 0, Space.gutter, 120),
        children: [
          Row(
            children: [
              Expanded(child: _Caption(text: caption)),
              MadarButton(
                label: l.ncClearAll,
                icon: Icons.clear_all_rounded,
                variant: MadarButtonVariant.ghost,
                size: MadarButtonSize.small,
                sfx: Sfx.tap,
                onPressed: () => CenterActions.clearAll(context, ref),
              ),
            ],
          ),
          for (var i = 0; i < sections.length; i++)
            StaggerItem(
              index: i,
              blur: false,
              child: CenterGroupSection(key: ValueKey('recent.${sections[i].group.name}'), section: sections[i]),
            ),
        ],
      ),
    );
  }
}

class _Caption extends StatelessWidget {
  const _Caption({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(Space.xs, Space.s, 0, 0),
      child: Text(text, style: Theme.of(context).textTheme.bodySmall!.copyWith(color: t.textTertiary)),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.kind, required this.title, required this.body});

  final EmptyStateKind kind;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) => SingleChildScrollView(
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: c.maxHeight),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 80),
            child: AnimatedEmptyState(kind: kind, title: title, body: body),
          ),
        ),
      ),
    ),
  );
}

/// "Madar's notifications are off in the phone's settings" + Turn on.
class _PermissionBanner extends ConsumerWidget {
  const _PermissionBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final l = CenterTexts.of(context).l;
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(Space.gutter, 0, Space.gutter, Space.s),
      child: GlassCard(
        borderColor: t.warning.withValues(alpha: 0.5),
        padding: const EdgeInsetsDirectional.fromSTEB(Space.m, Space.m, Space.m, Space.m),
        child: Row(
          children: [
            Icon(Icons.notifications_off_rounded, color: t.warning),
            const SizedBox(width: Space.m),
            Expanded(
              child: Text(l.ncPermissionOff, style: text.bodySmall!.copyWith(color: t.textPrimary)),
            ),
            const SizedBox(width: Space.s),
            MadarButton(
              label: l.ncPermissionTurnOn,
              size: MadarButtonSize.small,
              onPressed: () async {
                await ref.read(notificationServiceProvider).requestNotifications();
                await ref.read(notificationCenterProvider.notifier).refresh();
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// The muted groups, each a chip that unmutes it.
class _MuteStrip extends ConsumerWidget {
  const _MuteStrip({required this.mutes});

  final Map<NotificationGroup, DateTime> mutes;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tx = CenterTexts.of(context);
    final now = ref.watch(notificationCenterProvider.select((s) => s.now));
    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsetsDirectional.fromSTEB(Space.gutter, 0, Space.gutter, Space.xs),
        children: [
          for (final e in mutes.entries) ...[
            MadarChip(
              label: '${tx.group(e.key)} · ${tx.l.ncOptionUntil(tx.until(e.value, now))}',
              icon: Icons.notifications_paused_rounded,
              selected: true,
              dense: true,
              sfx: null,
              onSelected: (_) => CenterActions.unmute(context, ref, e.key),
            ),
            const SizedBox(width: Space.s),
          ],
        ],
      ),
    );
  }
}

/// A glass segmented control – Upcoming (count) / Recent (new) – whose
/// thumb springs between the tabs, following the reading direction.
class CenterTabBar extends StatelessWidget {
  const CenterTabBar({
    super.key,
    required this.value,
    required this.upcoming,
    required this.unread,
    required this.onChanged,
  });

  final CenterTab value;
  final int upcoming;
  final int unread;
  final ValueChanged<CenterTab> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final tx = CenterTexts.of(context);
    final l = tx.l;
    final dir = Directionality.of(context);
    const tabs = CenterTab.values;
    String label(CenterTab tab) => tab == CenterTab.upcoming ? l.ncTabUpcoming : l.ncTabRecent;
    int count(CenterTab tab) => tab == CenterTab.upcoming ? upcoming : unread;
    return Semantics(
      container: true,
      explicitChildNodes: true,
      child: Container(
        // 48 dp tabs inside the 1 dp border and 4 dp inset.
        height: 58,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(99),
          color: t.glassFill,
          border: Border.all(color: t.glassBorder),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final w = constraints.maxWidth / tabs.length;
            return Stack(
              children: [
                SpringBuilder(
                  value: value.index.toDouble(),
                  spring: MadarMotion.snappy,
                  builder: (context, v, _) {
                    final x = dir == TextDirection.rtl ? constraints.maxWidth - w * (v + 1) : w * v;
                    return Positioned(
                      left: x,
                      top: 0,
                      bottom: 0,
                      width: w,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(99),
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Color.lerp(t.accent, t.starTint, 0.18)!, t.accent],
                          ),
                          boxShadow: t.isDark
                              ? [BoxShadow(color: t.accentGlow.withValues(alpha: 0.35), blurRadius: 14)]
                              : null,
                        ),
                      ),
                    );
                  },
                ),
                Row(
                  children: [
                    for (final tab in tabs)
                      Expanded(
                        child: MadarPressable(
                          onTap: tab == value ? null : () => onChanged(tab),
                          sfx: Sfx.navigate,
                          selected: tab == value,
                          semanticLabel: count(tab) > 0
                              ? l.ncTabWithCount(label(tab), tx.count(count(tab)))
                              : label(tab),
                          excludeChildSemantics: true,
                          focusRadius: BorderRadius.circular(99),
                          child: Center(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Flexible(
                                  child: AnimatedDefaultTextStyle(
                                    duration: context.motion(MadarMotion.short),
                                    style: text.labelLarge!.copyWith(
                                      color: tab == value ? t.textOnAccent : t.textSecondary,
                                      height: 1.2,
                                    ),
                                    child: Text(label(tab), maxLines: 1, overflow: TextOverflow.ellipsis),
                                  ),
                                ),
                                if (count(tab) > 0) ...[
                                  const SizedBox(width: 6),
                                  _TabCount(
                                    label: tx.count(count(tab)),
                                    selected: tab == value,
                                    highlight: tab == CenterTab.recent,
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _TabCount extends StatelessWidget {
  const _TabCount({required this.label, required this.selected, required this.highlight});

  final String label;
  final bool selected;

  /// New notifications (accent) rather than a plain count.
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final bg = selected
        ? t.textOnAccent.withValues(alpha: 0.18)
        : highlight
        ? t.accent
        : t.textSecondary.withValues(alpha: 0.16);
    final fg = selected
        ? t.textOnAccent
        : highlight
        ? t.textOnAccent
        : t.textSecondary;
    return AnimatedContainer(
      duration: context.motion(MadarMotion.short),
      constraints: const BoxConstraints(minWidth: 20),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(99)),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: text.labelSmall!.copyWith(color: fg, fontWeight: FontWeight.w700, height: 1.3),
      ),
    );
  }
}

/// Softens the top edge where a list scrolls under the tab bar.
class _EdgeFade extends StatelessWidget {
  const _EdgeFade({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => ShaderMask(
    blendMode: BlendMode.dstIn,
    shaderCallback: (rect) => LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: const [Color(0x00FFFFFF), Color(0xFFFFFFFF)],
      stops: [0, (14 / rect.height).clamp(0.0, 1.0)],
    ).createShader(rect),
    child: child,
  );
}

/// Keeps both lists alive and cross-fades to [index] (the hidden one stops
/// ticking and ignores input).
class _FadeStack extends StatelessWidget {
  const _FadeStack({required this.index, required this.children});

  final int index;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final duration = context.motion(MadarMotion.medium);
    return Stack(
      fit: StackFit.expand,
      children: [
        for (var i = 0; i < children.length; i++)
          IgnorePointer(
            ignoring: i != index,
            child: ExcludeSemantics(
              excluding: i != index,
              child: AnimatedOpacity(
                opacity: i == index ? 1 : 0,
                duration: duration,
                curve: MadarMotion.standard,
                child: AnimatedSlide(
                  offset: i == index ? Offset.zero : const Offset(0, 0.015),
                  duration: duration,
                  curve: MadarMotion.decelerate,
                  child: TickerMode(enabled: i == index, child: children[i]),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
