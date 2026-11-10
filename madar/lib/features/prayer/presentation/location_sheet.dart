import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/tokens.dart';
import '../../../core/design/widgets/widgets.dart';
import '../../../core/i18n/formatters.dart';
import '../../../core/i18n/gen/app_localizations.dart';
import '../../../core/interaction/interaction.dart';
import '../../../core/interaction/sheets/field_inputs.dart' show kitInputDecoration;
import '../../../core/motion/motion.dart';
import '../../../core/sound/sound_api.dart';
import '../../orbit/domain/prayer_schedule.dart';
import '../application/location_flow.dart';
import '../application/prayer_providers.dart';
import '../application/prayer_settings_controller.dart';
import '../domain/cities.dart';
import 'prayer_labels.dart';

/// Opens the location sheet: the current location, "use my current
/// location" (rationale → permission → fix, with graceful denied /
/// permanently-denied / services-off states) and the offline city picker.
/// A change shows an undo toast.
Future<void> showPrayerLocationSheet(BuildContext context) async {
  final container = ProviderScope.containerOf(context, listen: false);
  final before = container.read(prayerSettingsControllerProvider);
  final changed = await showInteractionSheet<bool>(context, builder: (_) => const PrayerLocationSheet());
  if (changed != true || !context.mounted) return;
  final after = container.read(prayerSettingsControllerProvider);
  if (after == before) return;
  final l = L10n.of(context);
  final lang = Localizations.localeOf(context).languageCode;
  final cities = container.read(cityDatabaseProvider).value;
  unawaited(
    showUndoToast(
      context,
      UndoableAction(
        label: l.ptLocationChanged(l.placeLabel(after, lang, cities: cities)),
        undo: () => container.read(prayerSettingsControllerProvider.notifier).restore(before),
      ),
    ),
  );
}

/// The body of [showPrayerLocationSheet] (pops `true` after a change).
class PrayerLocationSheet extends ConsumerStatefulWidget {
  const PrayerLocationSheet({super.key});

  @override
  ConsumerState<PrayerLocationSheet> createState() => _PrayerLocationSheetState();
}

class _PrayerLocationSheetState extends ConsumerState<PrayerLocationSheet> {
  AppLifecycleListener? _lifecycle;

  @override
  void initState() {
    super.initState();
    // Back from the system settings: pick up a newly granted permission or
    // services switched on.
    _lifecycle = AppLifecycleListener(onResume: () => ref.read(locationFlowProvider.notifier).recheck());
  }

  @override
  void dispose() {
    _lifecycle?.dispose();
    super.dispose();
  }

  Future<void> _chooseCity() async {
    final city = await showCityPickerSheet(context);
    if (city == null || !mounted) return;
    await ref.read(prayerSettingsControllerProvider.notifier).setCity(city);
    Fx.fire(Sfx.complete);
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final flow = ref.watch(locationFlowProvider);
    ref.listen<LocationFlowState>(locationFlowProvider, (prev, next) {
      if (next.stage == LocationFlowStage.located && prev?.stage != LocationFlowStage.located) {
        Fx.fire(Sfx.complete);
        final nav = Navigator.of(context);
        Future<void>.delayed(context.motion(MadarMotion.long), () {
          if (mounted) nav.pop(true);
        });
      }
    });
    return InteractionSheetFrame(
      title: l.ptLocationTitle,
      subtitle: l.ptLocationSubtitle,
      icon: Icons.location_on_outlined,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _CurrentLocationCard(),
          const SizedBox(height: Space.l),
          AnimatedSwitcher(
            duration: context.motion(MadarMotion.medium),
            switchInCurve: MadarMotion.decelerate,
            transitionBuilder: (child, anim) => FadeTransition(
              opacity: anim,
              child: SlideTransition(
                position: Tween(begin: const Offset(0, 0.04), end: Offset.zero).animate(anim),
                child: child,
              ),
            ),
            child: KeyedSubtree(key: ValueKey(flow.stage), child: _stageBody(context, flow)),
          ),
        ],
      ),
    );
  }

  Widget _stageBody(BuildContext context, LocationFlowState flow) {
    final l = L10n.of(context);
    final t = context.tokens;
    final notifier = ref.read(locationFlowProvider.notifier);
    final chooseCity = _ActionTile(
      icon: Icons.travel_explore_rounded,
      title: l.ptChooseCity,
      subtitle: l.ptChooseCityHint,
      onTap: _chooseCity,
    );
    switch (flow.stage) {
      case LocationFlowStage.idle:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _ActionTile(
              icon: Icons.my_location_rounded,
              title: l.ptUseCurrentLocation,
              subtitle: l.ptUseCurrentLocationHint,
              highlight: true,
              onTap: notifier.start,
            ),
            const SizedBox(height: Space.s),
            chooseCity,
          ],
        );
      case LocationFlowStage.rationale:
        return _Message(
          icon: Icons.shield_moon_outlined,
          color: t.accent,
          title: l.ptRationaleTitle,
          body: l.ptRationaleBody,
          actions: [
            SheetButton(
              label: l.ptRationaleAllow,
              primary: true,
              icon: Icons.my_location_rounded,
              onPressed: notifier.allow,
            ),
            SheetButton(label: l.ptChooseCity, icon: Icons.travel_explore_rounded, onPressed: _chooseCity),
          ],
        );
      case LocationFlowStage.requesting || LocationFlowStage.locating:
        return Padding(
          padding: const EdgeInsetsDirectional.symmetric(vertical: Space.xl),
          child: Column(
            children: [
              OrbitLoader(
                size: 44,
                semanticLabel: flow.stage == LocationFlowStage.locating ? l.ptLocating : l.ptRequesting,
              ),
              const SizedBox(height: Space.m),
              Text(
                flow.stage == LocationFlowStage.locating ? l.ptLocating : l.ptRequesting,
                style: Theme.of(context).textTheme.bodyLarge!.copyWith(color: t.textSecondary),
              ),
            ],
          ),
        );
      case LocationFlowStage.located:
        final lang = Localizations.localeOf(context).languageCode;
        final settings = ref.watch(prayerSettingsControllerProvider);
        final cities = ref.watch(cityDatabaseProvider).value;
        return _Message(
          icon: Icons.check_circle_rounded,
          color: t.success,
          title: l.ptLocationChanged(l.placeLabel(settings, lang, cities: cities)),
          body: l.ptLocationSubtitle,
        );
      case LocationFlowStage.denied:
        return _Message(
          icon: Icons.location_disabled_rounded,
          color: t.warning,
          title: l.ptDeniedTitle,
          body: l.ptDeniedBody,
          actions: [
            SheetButton(label: l.ptTryAgain, primary: true, icon: Icons.refresh_rounded, onPressed: notifier.allow),
            SheetButton(label: l.ptChooseCity, icon: Icons.travel_explore_rounded, onPressed: _chooseCity),
          ],
        );
      case LocationFlowStage.deniedForever:
        return _Message(
          icon: Icons.lock_outline_rounded,
          color: t.warning,
          title: l.ptDeniedForeverTitle,
          body: l.ptDeniedForeverBody,
          actions: [
            SheetButton(
              label: l.ptOpenAppSettings,
              primary: true,
              icon: Icons.settings_rounded,
              sfx: Sfx.navigate,
              onPressed: notifier.openAppSettings,
            ),
            SheetButton(label: l.ptChooseCity, icon: Icons.travel_explore_rounded, onPressed: _chooseCity),
          ],
        );
      case LocationFlowStage.serviceDisabled:
        return _Message(
          icon: Icons.location_off_rounded,
          color: t.warning,
          title: l.ptServiceOffTitle,
          body: l.ptServiceOffBody,
          actions: [
            SheetButton(
              label: l.ptOpenLocationSettings,
              primary: true,
              icon: Icons.settings_rounded,
              sfx: Sfx.navigate,
              onPressed: notifier.openLocationSettings,
            ),
            SheetButton(label: l.ptChooseCity, icon: Icons.travel_explore_rounded, onPressed: _chooseCity),
          ],
        );
      case LocationFlowStage.unsupported:
        return _Message(
          icon: Icons.location_off_rounded,
          color: t.textTertiary,
          title: l.ptFailedTitle,
          body: l.ptUnsupportedBody,
          actions: [
            SheetButton(
              label: l.ptChooseCity,
              primary: true,
              icon: Icons.travel_explore_rounded,
              onPressed: _chooseCity,
            ),
          ],
        );
      case LocationFlowStage.failed:
        return _Message(
          icon: Icons.gps_not_fixed_rounded,
          color: t.warning,
          title: l.ptFailedTitle,
          body: l.ptFailedBody,
          actions: [
            SheetButton(label: l.ptTryAgain, primary: true, icon: Icons.refresh_rounded, onPressed: notifier.start),
            SheetButton(label: l.ptChooseCity, icon: Icons.travel_explore_rounded, onPressed: _chooseCity),
          ],
        );
    }
  }
}

/// The stored location: name, source, coordinates and time zone.
class _CurrentLocationCard extends ConsumerWidget {
  const _CurrentLocationCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final l = L10n.of(context);
    final text = Theme.of(context).textTheme;
    final fmt = MadarFormatter.of(context);
    final lang = Localizations.localeOf(context).languageCode;
    final s = ref.watch(prayerSettingsControllerProvider);
    final cities = ref.watch(cityDatabaseProvider).value;
    final now = ref.watch(prayerClockProvider)();
    final source = switch (s.locationSource) {
      PrayerLocationSource.gps => l.ptSourceGps,
      PrayerLocationSource.city => l.ptSourceCity,
      PrayerLocationSource.defaultCity => l.ptSourceDefault,
    };
    final coords = l.ptCoordinates(
      BidiIsolate.ltr(fmt.formatNumber(s.latitude, decimals: 4, grouping: false)),
      BidiIsolate.ltr(fmt.formatNumber(s.longitude, decimals: 4, grouping: false)),
    );
    return Container(
      padding: const EdgeInsetsDirectional.all(Space.l),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(t.radiusL),
        gradient: LinearGradient(
          begin: AlignmentDirectional.topStart,
          end: AlignmentDirectional.bottomEnd,
          colors: [t.accentSoft, t.glassFill],
        ),
        border: Border.all(color: t.accent.withValues(alpha: 0.35), width: 0.9),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: t.accent.withValues(alpha: 0.14),
              border: Border.all(color: t.accent.withValues(alpha: 0.5), width: 0.9),
            ),
            child: Icon(
              s.locationSource == PrayerLocationSource.gps ? Icons.my_location_rounded : Icons.location_city_rounded,
              color: t.accent,
              size: 22,
            ),
          ),
          const SizedBox(width: Space.m),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l.placeLabel(s, lang, cities: cities), style: text.titleLarge),
                const SizedBox(height: Space.xxs),
                Text(source, style: text.bodySmall!.copyWith(color: t.accent)),
                const SizedBox(height: Space.xs),
                Text(coords, style: text.bodySmall!.copyWith(color: t.textTertiary)),
                Text(
                  l.ptTimeZoneLabel(l.zoneLabel(s, now, fmt)),
                  style: text.bodySmall!.copyWith(color: t.textTertiary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.highlight = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    return MadarPressable(
      onTap: onTap,
      semanticLabel: title,
      excludeChildSemantics: true,
      pressScale: 0.98,
      focusRadius: BorderRadius.circular(t.radiusM),
      child: Container(
        padding: const EdgeInsetsDirectional.fromSTEB(Space.l, Space.m, Space.m, Space.m),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(t.radiusM),
          color: highlight ? t.accent.withValues(alpha: 0.10) : t.glassFill,
          border: Border.all(color: highlight ? t.accent.withValues(alpha: 0.5) : t.glassBorder, width: 0.9),
        ),
        child: Row(
          children: [
            Icon(icon, color: t.accent, size: 24),
            const SizedBox(width: Space.m),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: text.titleMedium),
                  Text(subtitle, style: text.bodySmall!.copyWith(color: t.textTertiary)),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: t.textTertiary),
          ],
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({
    required this.icon,
    required this.color,
    required this.title,
    required this.body,
    this.actions = const [],
  });

  final IconData icon;
  final Color color;
  final String title;
  final String body;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          liveRegion: true,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(width: Space.m),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: text.titleMedium),
                    const SizedBox(height: Space.xxs),
                    Text(body, style: text.bodyMedium!.copyWith(color: t.textSecondary, height: 1.55)),
                  ],
                ),
              ),
            ],
          ),
        ),
        for (final a in actions) ...[const SizedBox(height: Space.s), a],
      ],
    );
  }
}

/// The offline city picker: Arabic / English search (diacritic- and
/// typo-tolerant) over the bundled list; suggestions when empty. Returns the
/// chosen city.
Future<City?> showCityPickerSheet(BuildContext context) =>
    showInteractionSheet<City>(context, builder: (_) => const CityPickerSheet());

class CityPickerSheet extends ConsumerStatefulWidget {
  const CityPickerSheet({super.key});

  @override
  ConsumerState<CityPickerSheet> createState() => _CityPickerSheetState();
}

class _CityPickerSheetState extends ConsumerState<CityPickerSheet> {
  final _query = TextEditingController();

  @override
  void initState() {
    super.initState();
    _query.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final lang = Localizations.localeOf(context).languageCode;
    final db = ref.watch(cityDatabaseProvider);
    final selectedId = ref.watch(prayerSettingsControllerProvider.select((s) => s.cityId));
    final q = _query.text;

    Widget body;
    if (db.value == null) {
      body = const Padding(
        padding: EdgeInsetsDirectional.symmetric(vertical: Space.xxl),
        child: Center(child: OrbitLoader(size: 40)),
      );
    } else {
      final cities = db.value!;
      final matches = cities.search(q, limit: 60);
      if (matches.isEmpty) {
        body = AnimatedEmptyState(
          kind: EmptyStateKind.noResults,
          title: l.ptCitySearchEmpty,
          body: l.ptCitySearchEmptyHint,
          illustrationSize: 110,
        );
      } else {
        body = ListView.builder(
          padding: const EdgeInsetsDirectional.fromSTEB(Space.gutter, 0, Space.gutter, Space.l),
          itemCount: matches.length + 1,
          itemBuilder: (context, i) {
            if (i == 0) {
              return Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(Space.xs, Space.s, Space.xs, Space.s),
                child: Text(
                  CityText.fold(q).isEmpty ? l.ptCitySuggestions : l.ptCityResults,
                  style: text.labelMedium!.copyWith(color: t.gold),
                ),
              );
            }
            final c = matches[i - 1].city;
            return _CityRow(
              city: c,
              country: cities.countryName(c.countryCode, lang),
              selected: c.id == selectedId,
              onTap: () => Navigator.of(context).pop(c),
            );
          },
        );
      }
    }

    return InteractionSheetFrame(
      title: l.ptChooseCity,
      subtitle: l.ptChooseCityHint,
      icon: Icons.travel_explore_rounded,
      scrollable: false,
      bodyPadding: EdgeInsetsDirectional.zero,
      toolbar: TextField(
        controller: _query,
        textInputAction: TextInputAction.search,
        decoration: kitInputDecoration(
          context,
          hint: l.ptCitySearchHint,
        ).copyWith(prefixIcon: Icon(Icons.search_rounded, color: t.textTertiary, size: 20), isDense: true),
      ),
      body: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.58,
        child: AnimatedSwitcher(
          duration: context.motion(MadarMotion.short),
          child: KeyedSubtree(key: ValueKey(q.isEmpty), child: body),
        ),
      ),
    );
  }
}

class _CityRow extends StatelessWidget {
  const _CityRow({required this.city, required this.country, required this.selected, required this.onTap});

  final City city;
  final String country;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final l = L10n.of(context);
    final lang = Localizations.localeOf(context).languageCode;
    final other = lang == 'ar' ? city.nameEn : city.nameAr;
    return Padding(
      padding: const EdgeInsetsDirectional.only(bottom: Space.xs),
      child: MadarPressable(
        onTap: onTap,
        // The pick is confirmed (Sfx.complete) once the location is saved.
        sfx: Sfx.tap,
        semanticLabel: l.ptPlaceWithCountry(city.name(lang), country),
        excludeChildSemantics: true,
        selected: selected,
        pressScale: 0.985,
        focusRadius: BorderRadius.circular(t.radiusM),
        child: Container(
          padding: const EdgeInsetsDirectional.fromSTEB(Space.m, Space.s + 2, Space.m, Space.s + 2),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(t.radiusM),
            color: selected ? t.accent.withValues(alpha: 0.12) : t.glassFill,
            border: Border.all(
              color: selected ? t.accent.withValues(alpha: 0.6) : t.glassBorder.withValues(alpha: 0.6),
              width: 0.8,
            ),
          ),
          child: Row(
            children: [
              Icon(
                city.capital ? Icons.account_balance_rounded : Icons.location_city_rounded,
                size: 20,
                color: selected ? t.accent : t.textTertiary,
              ),
              const SizedBox(width: Space.m),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(city.name(lang), style: text.titleMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
                    Text(
                      l.ptPlaceWithCountry(BidiIsolate.isolate(other), country),
                      style: text.bodySmall!.copyWith(color: t.textTertiary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (selected) Icon(Icons.check_circle_rounded, color: t.accent, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
