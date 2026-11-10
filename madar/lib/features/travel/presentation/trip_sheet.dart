import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/database.dart';
import '../../../core/design/tokens.dart';
import '../../../core/design/widgets/widgets.dart';
import '../../../core/domain/enums.dart';
import '../../../core/i18n/formatters.dart';
import '../../../core/i18n/gen/app_localizations.dart';
import '../../../core/interaction/interaction.dart';
import '../../../core/interaction/sheets/field_inputs.dart'
    show FieldShell, InlineDatePicker, PickerButton, SwatchPicker, kitInputDecoration;
import '../../../core/motion/motion.dart';
import '../../../core/sound/sound_api.dart';
import '../../prayer/domain/cities.dart';
import '../../prayer/domain/time_zones.dart';
import '../../prayer/presentation/prayer_labels.dart';
import '../data/travel_providers.dart';
import '../data/travel_service.dart';
import '../domain/destination_prayer.dart';
import '../domain/trip_timeline.dart';
import '../travel_texts.dart';

/// Opens the trip editor: a new trip, or [trip] (with [manualStatus] when
/// its status was set by hand). Returns the draft to save, or null.
Future<TripDraft?> showTripSheet(BuildContext context, {TripRow? trip, TripStatus? manualStatus}) =>
    showInteractionSheet<TripDraft>(
      context,
      builder: (_) => TripSheet(trip: trip, manualStatus: manualStatus),
    );

/// The trip editor: destination (a city of the offline list – with its
/// coordinates and zone, so the trip gets prayer times and the qibla – or
/// any place typed freely), departure and return, status (from the dates or
/// by hand), colour and notes.
class TripSheet extends ConsumerStatefulWidget {
  const TripSheet({super.key, this.trip, this.manualStatus});

  final TripRow? trip;
  final TripStatus? manualStatus;

  @override
  ConsumerState<TripSheet> createState() => _TripSheetState();
}

enum _Picker { none, start, end }

class _TripSheetState extends ConsumerState<TripSheet> {
  late final TextEditingController _destination = TextEditingController(text: widget.trip?.destination ?? '');
  late final TextEditingController _notes = TextEditingController(text: widget.trip?.notes ?? '');
  final FocusNode _destinationFocus = FocusNode();
  City? _city;
  bool _cityResolved = false;

  /// The chosen city's card is swapped for the search field.
  bool _editing = false;
  late DateTime? _start = widget.trip?.startDate;
  late DateTime? _end = widget.trip?.endDate;
  late TripStatus? _status = widget.manualStatus;
  late int? _color = widget.trip?.color;
  _Picker _picker = _Picker.none;
  bool _submitted = false;

  /// Coordinates kept from a stored trip whose city is not in the list.
  double? _keptLat, _keptLon;
  String? _keptCountry;

  @override
  void initState() {
    super.initState();
    _keptLat = widget.trip?.latitude;
    _keptLon = widget.trip?.longitude;
    _keptCountry = widget.trip?.country;
    _destination.addListener(_onDestinationChanged);
    _destinationFocus.addListener(() {
      setState(() {
        if (!_destinationFocus.hasFocus) _editing = false;
      });
    });
  }

  @override
  void dispose() {
    _destination.dispose();
    _notes.dispose();
    _destinationFocus.dispose();
    super.dispose();
  }

  void _resolveInitialCity(CityDatabase? cities) {
    if (_cityResolved || cities == null) return;
    _cityResolved = true;
    final t = widget.trip;
    if (t == null) return;
    _city = TripPlace.resolve(latitude: t.latitude, longitude: t.longitude, cities: cities)?.city;
  }

  void _onDestinationChanged() {
    final c = _city;
    final text = _destination.text.trim();
    if (c != null && text != c.nameAr && text != c.nameEn) {
      // Renaming a listed city keeps it only while the text still names it.
      setState(() => _city = null);
    } else {
      setState(() {});
    }
    if (text.isEmpty) {
      _keptLat = _keptLon = null;
      _keptCountry = null;
    }
  }

  void _pickCity(City city, String lang) {
    Fx.fire(Sfx.toggleOn);
    _destination.text = city.name(lang);
    setState(() {
      _city = city;
      _keptLat = _keptLon = null;
      _keptCountry = null;
    });
    _destinationFocus.unfocus();
  }

  void _useTyped() {
    Fx.fire(Sfx.tap);
    setState(() {
      _city = null;
      _keptLat = _keptLon = null;
      _keptCountry = null;
    });
    _destinationFocus.unfocus();
  }

  void _togglePicker(_Picker p) {
    Fx.fire(Sfx.tap);
    FocusScope.of(context).unfocus();
    setState(() => _picker = _picker == p ? _Picker.none : p);
  }

  bool get _endBeforeStart => _start != null && _end != null && TravelDates.daysBetween(_start!, _end!) < 0;

  String? get _destinationError => _destination.text.trim().isEmpty ? L10n.of(context).travelDestinationRequired : null;

  void _save() {
    setState(() => _submitted = true);
    if (_destinationError != null || _endBeforeStart) {
      Fx.fire(Sfx.error);
      if (_destinationError != null) _destinationFocus.requestFocus();
      return;
    }
    final c = _city;
    Fx.fire(Sfx.complete);
    Navigator.of(context).pop(
      TripDraft(
        destination: _destination.text.trim(),
        country: c?.countryCode ?? _keptCountry,
        latitude: c?.latitude ?? _keptLat,
        longitude: c?.longitude ?? _keptLon,
        startDate: _start,
        endDate: _end,
        notes: _notes.text,
        color: _color,
        status: _status,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final t = context.tokens;
    final tx = TravelTexts.of(context);
    final text = Theme.of(context).textTheme;
    final lang = Localizations.localeOf(context).languageCode;
    final cities = ref.watch(travelCitiesProvider);
    final now = ref.watch(travelNowProvider);
    _resolveInitialCity(cities);
    final today = TravelDates.day(now);
    final derived = TripTimeline(start: _start, end: _end).derive(TravelToday.same(today));

    final destination = FieldShell(
      label: l.travelFieldDestination,
      icon: Icons.place_rounded,
      error: _submitted ? _destinationError : null,
      child: _DestinationInput(
        controller: _destination,
        focus: _destinationFocus,
        city: _city,
        cities: cities,
        lang: lang,
        now: now,
        error: _submitted && _destinationError != null,
        onPick: (c) => _pickCity(c, lang),
        onUseTyped: _useTyped,
        editing: _editing,
        onChange: () {
          setState(() => _editing = true);
          _destination.selection = TextSelection(baseOffset: 0, extentOffset: _destination.text.length);
          _destinationFocus.requestFocus();
        },
      ),
    );

    String dateText(DateTime? d) => d == null
        ? l.travelNoDate
        : tx.fmt.formatDate(d, style: d.year == now.year ? MadarDateStyle.dayMonth : MadarDateStyle.medium);

    final dates = FieldShell(
      label: l.travelTripDates,
      icon: Icons.event_rounded,
      error: _endBeforeStart ? l.travelEndBeforeStart : null,
      trailing: _start != null && _end != null && !_endBeforeStart
          ? Text(tx.days(TravelDates.daysBetween(_start!, _end!) + 1), style: text.labelMedium!.copyWith(color: t.gold))
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _LabeledPicker(
                  label: l.travelFieldStart,
                  child: PickerButton(
                    icon: Icons.flight_takeoff_rounded,
                    text: dateText(_start),
                    placeholder: _start == null,
                    active: _picker == _Picker.start,
                    semanticLabel: l.travelFieldStart,
                    onTap: () => _togglePicker(_Picker.start),
                  ),
                ),
              ),
              const SizedBox(width: Space.s),
              Expanded(
                child: _LabeledPicker(
                  label: l.travelFieldEnd,
                  child: PickerButton(
                    icon: Icons.flight_land_rounded,
                    text: dateText(_end),
                    placeholder: _end == null,
                    active: _picker == _Picker.end,
                    error: _endBeforeStart,
                    semanticLabel: l.travelFieldEnd,
                    onTap: () => _togglePicker(_Picker.end),
                  ),
                ),
              ),
            ],
          ),
          AnimatedSize(
            duration: context.motion(MadarMotion.medium),
            curve: MadarMotion.standard,
            alignment: AlignmentDirectional.topCenter,
            child: switch (_picker) {
              _Picker.none => const SizedBox(width: double.infinity),
              _Picker.start => InlineDatePicker(
                key: const ValueKey('start'),
                value: _start,
                now: now,
                onChanged: (d) => setState(() {
                  _start = d;
                  if (d != null && _end != null && TravelDates.daysBetween(d, _end!) < 0) _end = null;
                  if (d != null) _picker = _Picker.end;
                }),
              ),
              _Picker.end => Column(
                key: const ValueKey('end'),
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  InlineDatePicker(
                    value: _end,
                    now: now,
                    firstDate: _start,
                    onChanged: (d) => setState(() {
                      _end = d;
                      if (d != null) _picker = _Picker.none;
                    }),
                  ),
                  Text(l.travelFieldEndHint, style: text.bodySmall!.copyWith(color: t.textTertiary)),
                ],
              ),
            },
          ),
        ],
      ),
    );

    final status = FieldShell(
      label: l.travelFieldStatus,
      icon: Icons.flag_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ChoicePills<TripStatus?>.single(
            options: [
              ChoiceOption(value: null, label: l.travelStatusAuto, icon: Icons.auto_mode_rounded),
              ChoiceOption(value: TripStatus.planned, label: l.travelStatusPlanned),
              ChoiceOption(value: TripStatus.active, label: l.travelStatusActive),
              ChoiceOption(value: TripStatus.done, label: l.travelStatusDone),
            ],
            selected: _status,
            dense: true,
            onChanged: (s) => setState(() => _status = s),
          ),
          const SizedBox(height: Space.xs),
          Text(
            _status == null ? l.travelStatusAutoHint(tx.status(derived)) : l.travelStatusManualHint,
            style: text.bodySmall!.copyWith(color: t.textTertiary),
          ),
        ],
      ),
    );

    final color = FieldShell(
      label: l.travelFieldColor,
      icon: Icons.palette_rounded,
      optional: true,
      child: SwatchPicker(
        colors: CuratedPalette.colors,
        value: _color,
        onChanged: (c) => setState(() => _color = c == _color ? null : c),
      ),
    );

    final notes = FieldShell(
      label: l.travelFieldNotes,
      icon: Icons.notes_rounded,
      optional: true,
      child: TextField(
        controller: _notes,
        minLines: 2,
        maxLines: 5,
        textInputAction: TextInputAction.newline,
        decoration: kitInputDecoration(context, hint: l.travelFieldNotesHint),
      ),
    );

    return InteractionSheetFrame(
      title: widget.trip == null ? l.travelSheetNewTitle : l.travelSheetEditTitle,
      subtitle: l.travelSheetSubtitle,
      icon: Icons.flight_takeoff_rounded,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          destination,
          const SizedBox(height: Space.l),
          dates,
          const SizedBox(height: Space.l),
          status,
          const SizedBox(height: Space.l),
          color,
          const SizedBox(height: Space.l),
          notes,
        ],
      ),
      footer: SheetButton(
        label: widget.trip == null ? l.travelCreate : l.travelSave,
        primary: true,
        icon: Icons.check_rounded,
        sfx: null,
        onPressed: _save,
      ),
    );
  }
}

class _LabeledPicker extends StatelessWidget {
  const _LabeledPicker({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.only(start: Space.xs, bottom: Space.xs),
          child: Text(label, style: Theme.of(context).textTheme.labelMedium!.copyWith(color: t.textSecondary)),
        ),
        child,
      ],
    );
  }
}

/// The destination search: suggestions from the offline list while typing
/// (featured cities when empty), "use as typed", and the chosen city's card.
class _DestinationInput extends StatelessWidget {
  const _DestinationInput({
    required this.controller,
    required this.focus,
    required this.city,
    required this.cities,
    required this.lang,
    required this.now,
    required this.error,
    required this.onPick,
    required this.onUseTyped,
    required this.onChange,
    required this.editing,
  });

  final bool editing;
  final TextEditingController controller;
  final FocusNode focus;
  final City? city;
  final CityDatabase? cities;
  final String lang;
  final DateTime now;
  final bool error;
  final ValueChanged<City> onPick;
  final VoidCallback onUseTyped;
  final VoidCallback onChange;

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final fmt = MadarFormatter.of(context);
    final query = controller.text.trim();
    final c = city;

    if (c != null && !editing) {
      final db = cities;
      final country = db?.countryName(c.countryCode, lang) ?? c.countryCode;
      final offset = l.zoneOffset(MadarTimeZones.offsetAt(now, MadarTimeZones.find(c.timeZone)), fmt);
      return GlassCard(
        glow: false,
        padding: const EdgeInsetsDirectional.fromSTEB(Space.m, Space.m, Space.s, Space.m),
        child: Row(
          children: [
            Icon(Icons.location_on_rounded, color: t.accent, size: 22),
            const SizedBox(width: Space.m),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l.ptPlaceWithCountry(fmt.isolate(c.name(lang)), country), style: text.titleMedium),
                  const SizedBox(height: 2),
                  Text(
                    l.travelDestinationCity(offset),
                    style: text.bodySmall!.copyWith(color: t.textSecondary),
                  ),
                ],
              ),
            ),
            MadarButton(
              label: l.travelDestinationChange,
              variant: MadarButtonVariant.ghost,
              size: MadarButtonSize.small,
              onPressed: onChange,
            ),
          ],
        ),
      );
    }

    final suggestions = <City>[];
    final db = cities;
    if (db != null && focus.hasFocus) {
      for (final m in db.search(query, limit: 5)) {
        suggestions.add(m.city);
      }
    }
    final showTyped = focus.hasFocus && query.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: controller,
          focusNode: focus,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => onUseTyped(),
          decoration: kitInputDecoration(context, hint: l.travelFieldDestinationHint, error: error).copyWith(
            prefixIcon: Icon(Icons.travel_explore_rounded, color: t.textTertiary, size: 20),
          ),
        ),
        AnimatedSize(
          duration: context.motion(MadarMotion.medium),
          curve: MadarMotion.standard,
          alignment: AlignmentDirectional.topCenter,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (suggestions.isNotEmpty || showTyped) const SizedBox(height: Space.s),
              for (final s in suggestions)
                _SuggestionRow(
                  icon: Icons.location_city_rounded,
                  title: s.name(lang),
                  subtitle: db!.countryName(s.countryCode, lang),
                  onTap: () => onPick(s),
                ),
              if (showTyped)
                _SuggestionRow(
                  icon: Icons.edit_location_alt_rounded,
                  title: l.travelDestinationFree(fmt.isolate(query)),
                  subtitle: l.travelDestinationFreeHint,
                  muted: true,
                  onTap: onUseTyped,
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SuggestionRow extends StatelessWidget {
  const _SuggestionRow({required this.icon, required this.title, required this.subtitle, required this.onTap, this.muted = false});

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsetsDirectional.only(bottom: Space.xs),
      child: MadarPressable(
        onTap: onTap,
        sfx: null,
        semanticLabel: title,
        excludeChildSemantics: true,
        focusRadius: BorderRadius.circular(t.radiusM),
        child: Container(
          padding: const EdgeInsetsDirectional.symmetric(horizontal: Space.m, vertical: Space.s),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(t.radiusM),
            color: t.glassFill,
            border: Border.all(color: t.glassBorder.withValues(alpha: 0.6)),
          ),
          child: Row(
            children: [
              Icon(icon, size: 18, color: muted ? t.textTertiary : t.accent),
              const SizedBox(width: Space.m),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: text.bodyMedium),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.bodySmall!.copyWith(color: t.textTertiary),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
