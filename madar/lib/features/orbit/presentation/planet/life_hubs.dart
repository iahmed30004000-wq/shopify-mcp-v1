import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/widgets.dart';
import '../../../../core/i18n/gen/app_localizations.dart';
import '../../../../core/motion/motion_kit.dart';
import '../../../../core/routing/cinema_route_pages.dart';
import '../../../../core/routing/life_route_pages.dart';
import '../../../../core/sound/sound_api.dart';
import '../../../body/body.dart' show BodyTab, BodyTodayCard, FastingCard, WaterCard;
import '../../../custom_modules/custom_modules.dart' show CustomModulesCard, customPlanetModulesProvider;
import '../../../family/family.dart' show FamilyActions, FamilyTodayCard;
import '../../../growth/growth.dart' show GrowthTodayCard;
import '../../../travel/travel.dart' show TravelTab, TravelTodayCard;
import '../../../work/work.dart' show Top3Card, WorkTodayCard;
import 'cinema_entry_card.dart';

/// The Phase 6 life worlds' own page content (the hubs under the balance
/// ring of Work, Family, Travel, Growth and Body): the packages' compact
/// "today" cards, then a row of tools. Every screen opens as its route
/// ([LifeNav]); every part is a [StaggerItem] of the planet page's
/// entrance.
abstract final class LifeHubs {
  static const Set<String> keys = {'work', 'family', 'travel', 'growth', 'body'};

  /// Whether [planetKey] has a life hub.
  static bool has(String planetKey) => keys.contains(planetKey);

  /// The hub of [planetKey] (one of [keys]).
  static Widget of(String planetKey, {int firstIndex = 1}) => switch (planetKey) {
    'work' => WorkHub(firstIndex: firstIndex),
    'family' => FamilyHub(firstIndex: firstIndex),
    'travel' => TravelHub(firstIndex: firstIndex),
    'growth' => GrowthHub(firstIndex: firstIndex),
    _ => BodyHub(firstIndex: firstIndex),
  };
}

/// Builds a hub's column: cards in the gutter, a gap between them, and
/// titled groups (a title rises with its first card).
class _HubColumn {
  _HubColumn(this.index);

  int index;
  final List<Widget> children = [];

  void card(Widget child) {
    if (children.isNotEmpty && children.last is! _Header) children.add(const SizedBox(height: Space.m));
    children.add(
      StaggerItem(
        index: index++,
        child: Padding(
          padding: const EdgeInsetsDirectional.symmetric(horizontal: Space.gutter),
          child: child,
        ),
      ),
    );
  }

  void header(String title) => children.add(_Header(index: index, title: title));

  /// The planet sheet has no Material above it: the cards the packages
  /// bring would otherwise inherit the debug fallback text style.
  Widget build() => Material(
    type: MaterialType.transparency,
    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
  );
}

/// Work: today's Top 3 (cards and tasks, the morning carry-over), what is
/// due on the boards and placed in today's prayer windows, then the
/// boards and the projects.
class WorkHub extends StatelessWidget {
  const WorkHub({super.key, this.firstIndex = 1});

  /// Stagger index of the first card.
  final int firstIndex;

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final hub = _HubColumn(firstIndex)
      ..card(const Top3Card(compact: true))
      ..card(const WorkTodayCard(onOpen: LifeNav.work))
      ..header(l.lifeHubToolsTitle)
      ..card(
        _LifeTools(
          tools: [
            (Icons.view_kanban_rounded, l.workBoards, l.lifeHubToolBoardsHint, () => LifeNav.work(context)),
            (Icons.rocket_launch_outlined, l.workProjects, l.lifeHubToolProjectsHint, () => LifeNav.projects(context)),
          ],
        ),
      );
    return hub.build();
  }
}

/// Family: who is due a call or a visit, the birthdays of the next two
/// weeks, then everyone and the reach-out reminders.
class FamilyHub extends ConsumerWidget {
  const FamilyHub({super.key, this.firstIndex = 1});

  /// Stagger index of the first card.
  final int firstIndex;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L10n.of(context);
    final hub = _HubColumn(firstIndex)
      ..card(const FamilyTodayCard(onOpen: LifeNav.family, onOpenPerson: LifeNav.person))
      ..header(l.lifeHubToolsTitle)
      ..card(
        _LifeTools(
          tools: [
            (Icons.people_alt_rounded, l.lifeHubPeople, l.lifeHubToolPeopleHint, () => LifeNav.family(context)),
            (
              Icons.notifications_active_rounded,
              l.familyRemindersTitle,
              l.lifeHubToolRemindersHint,
              () => unawaited(FamilyActions.openSettings(context, ref)),
            ),
          ],
          sfx: const [Sfx.navigate, Sfx.sheetOpen],
        ),
      );
    return hub.build();
  }
}

/// Travel: the next or current trip with its countdown and packing, the
/// documents that need attention, then the trips, the documents and the
/// packing lists.
class TravelHub extends StatelessWidget {
  const TravelHub({super.key, this.firstIndex = 1});

  /// Stagger index of the first card.
  final int firstIndex;

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final hub = _HubColumn(firstIndex)
      ..card(const TravelTodayCard(onOpen: LifeNav.travel, onOpenTrip: LifeNav.trip))
      ..header(l.lifeHubToolsTitle)
      ..card(
        _LifeTools(
          tools: [
            (Icons.flight_takeoff_rounded, l.travelTabTrips, l.lifeHubToolTripsHint, () => LifeNav.travel(context)),
            (
              Icons.badge_rounded,
              l.travelTabDocuments,
              l.lifeHubToolDocumentsHint,
              () => LifeNav.travel(context, tab: TravelTab.documents),
            ),
            (
              Icons.luggage_rounded,
              l.travelTabTemplates,
              l.lifeHubSettingsTemplatesHint,
              () => LifeNav.travel(context, tab: TravelTab.templates),
            ),
          ],
        ),
      );
    return hub.build();
  }
}

/// Growth: the learning goals in progress with their pace, the door to
/// Madar Cinema (the games live under Growth), then all goals and the
/// projects (a project can belong to Growth and feed its balance).
class GrowthHub extends StatelessWidget {
  const GrowthHub({super.key, this.firstIndex = 1});

  /// Stagger index of the first card.
  final int firstIndex;

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final hub = _HubColumn(firstIndex)
      ..card(const GrowthTodayCard(onOpen: LifeNav.growth))
      ..card(const CinemaEntryCard(onOpen: CinemaNav.hall))
      ..header(l.lifeHubToolsTitle)
      ..card(
        _LifeTools(
          tools: [
            (Icons.school_rounded, l.growthCardOpenAll, l.lifeHubToolGoalsHint, () => LifeNav.growth(context)),
            (Icons.rocket_launch_outlined, l.workProjects, l.lifeHubToolProjectsHint, () => LifeNav.projects(context)),
          ],
        ),
      );
    return hub.build();
  }
}

/// Body: today's session, water and the fasting clock at a glance, the
/// fast and the water compact, then the training plan and the avoid list.
class BodyHub extends StatelessWidget {
  const BodyHub({super.key, this.firstIndex = 1});

  /// Stagger index of the first card.
  final int firstIndex;

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final hub = _HubColumn(firstIndex)
      ..card(BodyTodayCard(onOpen: () => LifeNav.body(context)))
      ..card(FastingCard(compact: true, onOpen: () => LifeNav.body(context, tab: BodyTab.fasting)))
      ..card(WaterCard(compact: true, onOpen: () => LifeNav.body(context, tab: BodyTab.water)))
      ..header(l.lifeHubToolsTitle)
      ..card(
        _LifeTools(
          tools: [
            (
              Icons.event_note_rounded,
              l.bodyTabPlan,
              l.lifeHubToolPlanHint,
              () => LifeNav.body(context, tab: BodyTab.plan),
            ),
            (
              Icons.do_not_disturb_on_outlined,
              l.bodyTabAvoid,
              l.lifeHubToolAvoidHint,
              () => LifeNav.body(context, tab: BodyTab.avoid),
            ),
          ],
        ),
      );
    return hub.build();
  }
}

/// The user's own trackers and lists attached to [planetKey], on every
/// world's page (custom worlds included). Faith, Health and Money are
/// already dense: they list their trackers but show no empty "create one"
/// prompt; every other world does.
class PlanetModulesSection extends ConsumerWidget {
  const PlanetModulesSection({super.key, required this.planetKey});

  final String planetKey;

  /// Worlds that show nothing while they have no tracker.
  static const Set<String> quietWhenEmpty = {'faith', 'health', 'money'};

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final modules = ref.watch(customPlanetModulesProvider(planetKey)).value;
    final showWhenEmpty = !quietWhenEmpty.contains(planetKey);
    if (modules == null || (modules.isEmpty && !showWhenEmpty)) return const SizedBox.shrink();
    return Material(
      type: MaterialType.transparency,
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(Space.gutter, Space.m, Space.gutter, 0),
        child: CustomModulesCard(
          planetKey: planetKey,
          onOpenModule: LifeNav.module,
          onSeeAll: () => LifeNav.modules(context),
          showWhenEmpty: showWhenEmpty,
        ),
      ),
    );
  }
}

/// A group's title, rising with its first card.
class _Header extends StatelessWidget {
  const _Header({required this.index, required this.title});

  final int index;
  final String title;

  @override
  Widget build(BuildContext context) => StaggerItem(
    index: index,
    child: SectionHeader(
      title: title,
      padding: const EdgeInsetsDirectional.fromSTEB(Space.gutter, Space.l, Space.gutter, Space.s),
    ),
  );
}

/// Icon, name, hint (for screen readers) and where it leads.
typedef _Tool = (IconData, String, String, VoidCallback);

/// A world's tools: one row of equal tiles (the Faith, Health and Money
/// tools' seal) – a tile per screen the hub leads to.
class _LifeTools extends StatelessWidget {
  const _LifeTools({required this.tools, this.sfx = const []});

  final List<_Tool> tools;

  /// The sound of each tile (default: navigate).
  final List<Sfx> sfx;

  @override
  Widget build(BuildContext context) => IntrinsicHeight(
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < tools.length; i++) ...[
          if (i > 0) const SizedBox(width: Space.s),
          Expanded(
            child: _ToolTile(tool: tools[i], sfx: i < sfx.length ? sfx[i] : Sfx.navigate),
          ),
        ],
      ],
    ),
  );
}

class _ToolTile extends StatelessWidget {
  const _ToolTile({required this.tool, required this.sfx});

  final _Tool tool;
  final Sfx sfx;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final (icon, title, hint, onTap) = tool;
    return MadarPressable(
      onTap: onTap,
      sfx: sfx,
      semanticLabel: '$title. $hint',
      excludeChildSemantics: true,
      focusRadius: BorderRadius.circular(t.radiusM),
      child: GlassCard(
        glow: false,
        padding: const EdgeInsetsDirectional.fromSTEB(Space.xs, Space.m, Space.xs, Space.m),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _Seal(icon: icon),
            const SizedBox(height: Space.s),
            Text(
              title,
              maxLines: 2,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: text.titleSmall!.copyWith(color: t.textPrimary, height: 1.25),
            ),
          ],
        ),
      ),
    );
  }
}

/// A brass eight-point seal holding a tool's icon.
class _Seal extends StatelessWidget {
  const _Seal({required this.icon});

  final IconData icon;

  static const double size = 44;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return SizedBox.square(
      dimension: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          IslamicStar(size: size, color: t.accentSoft),
          IslamicStar(size: size, filled: false, color: t.brass.withValues(alpha: 0.8), strokeWidth: 1.2),
          Icon(icon, size: 20, color: t.accent),
        ],
      ),
    );
  }
}
