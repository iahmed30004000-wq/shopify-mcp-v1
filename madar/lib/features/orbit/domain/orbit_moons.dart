import 'dart:math' as math;
import 'dart:ui' show Color;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart' show HSLColor;

import '../../../core/design/themes.dart' show PlanetPalette;
import '../../../core/domain/enums.dart';

/// Surface look of a data moon – `data_moon.frag` `uExtra.x`.
enum MoonKind {
  /// Cratered rock (people around Family, custom modules).
  rocky,

  /// Blue-fresnel ice (trips around Travel).
  icy,

  /// Faceted metallic gem (wallets around Money).
  metallic,

  /// Warm lava-veined (boards around Work).
  lava;

  /// The value to write into `uExtra.x`.
  double get shaderLook => index.toDouble();
}

/// One sub-item orbiting its planet. Every moon maps to a real record
/// ([refTable] + [refId]) that tapping it opens.
@immutable
class OrbitMoon {
  const OrbitMoon({
    required this.planetKey,
    required this.refTable,
    required this.refId,
    required this.label,
    required this.color,
    required this.kind,
    required this.score,
    required this.size,
    required this.seed,
  });

  /// The planet it orbits.
  final String planetKey;

  /// SQL table of the record (`people`, `wallets`, `boards`, `trips`,
  /// `custom_modules`).
  final String refTable;
  final String refId;

  /// The item's name (person, wallet, board, trip destination, module).
  final String label;

  /// Item colour (straight sRGB) → `uColorA`.
  final Color color;
  final MoonKind kind;

  /// Item state 0 (overdue / neglected) … 1 (fresh) → `uScore`.
  final double score;

  /// Relative size 0..1 within its planet's moons (1 = the most important).
  final double size;

  /// Stable per-item noise seed → `uSeed`.
  final double seed;

  /// Stable identity across snapshots (`people:<id>`).
  String get id => '$refTable:$refId';

  @override
  bool operator ==(Object other) =>
      other is OrbitMoon &&
      other.planetKey == planetKey &&
      other.refTable == refTable &&
      other.refId == refId &&
      other.label == label &&
      other.color == color &&
      other.kind == kind &&
      other.score == score &&
      other.size == size;

  @override
  int get hashCode => Object.hash(planetKey, refTable, refId, label, color, kind, score, size);

  @override
  String toString() =>
      'OrbitMoon($id "$label" ${kind.name} score ${score.toStringAsFixed(2)} size ${size.toStringAsFixed(2)})';
}

/// The moons of one planet, capped, plus how many did not fit.
@immutable
class MoonSet {
  const MoonSet(this.moons, {this.overflow = 0});

  static const empty = MoonSet([]);

  final List<OrbitMoon> moons;

  /// Items that exist but are not shown as moons (beyond the cap).
  final int overflow;
}

// ------------------------------------------------------------------ inputs --

@immutable
class PersonMoonIn {
  const PersonMoonIn({
    required this.id,
    required this.name,
    this.color,
    this.rhythmDays,
    this.lastContact,
    required this.createdAt,
    this.showAsMoon = true,
  });
  final String id;
  final String name;
  final int? color;
  final int? rhythmDays;
  final DateTime? lastContact;
  final DateTime createdAt;
  final bool showAsMoon;
}

@immutable
class WalletMoonIn {
  const WalletMoonIn({required this.id, required this.name, this.color, required this.balanceBaseMilli, this.lastTx});
  final String id;
  final String name;
  final int? color;

  /// Current balance converted to the base currency.
  final int balanceBaseMilli;
  final DateTime? lastTx;
}

@immutable
class BoardMoonIn {
  const BoardMoonIn({
    required this.id,
    required this.name,
    this.color,
    this.open = 0,
    this.overdue = 0,
    this.doneRecent = 0,
    this.movedRecent = 0,
  });
  final String id;
  final String name;
  final int? color;

  /// Cards not in the done column.
  final int open;

  /// Open cards past their due date.
  final int overdue;

  /// Cards done in the last 7 days.
  final int doneRecent;

  /// Cards touched (created, moved, edited) in the last 7 days.
  final int movedRecent;
}

@immutable
class TripMoonIn {
  const TripMoonIn({
    required this.id,
    required this.destination,
    this.color,
    this.startDate,
    this.endDate,
    this.status = TripStatus.planned,
    this.itemsTotal = 0,
    this.itemsPacked = 0,
  });
  final String id;
  final String destination;
  final int? color;
  final DateTime? startDate;
  final DateTime? endDate;
  final TripStatus status;
  final int itemsTotal;
  final int itemsPacked;
}

@immutable
class ModuleMoonIn {
  const ModuleMoonIn({
    required this.id,
    required this.name,
    required this.color,
    required this.planetKey,
    this.lastEntry,
    required this.createdAt,
    this.tracker = true,
  });
  final String id;
  final String name;
  final int color;
  final String planetKey;
  final DateTime? lastEntry;
  final DateTime createdAt;

  /// Trackers go stale without entries; lists do not.
  final bool tracker;
}

/// Everything the moons are built from, gathered by the data layer (each
/// list already in the user's order).
@immutable
class MoonInputs {
  const MoonInputs({
    this.people = const [],
    this.wallets = const [],
    this.boards = const [],
    this.trips = const [],
    this.modules = const [],
  });
  final List<PersonMoonIn> people;
  final List<WalletMoonIn> wallets;
  final List<BoardMoonIn> boards;
  final List<TripMoonIn> trips;
  final List<ModuleMoonIn> modules;
}

// ------------------------------------------------------------------- rules --

/// Pure per-item state rules (0 overdue … 1 fresh).
abstract final class MoonRules {
  /// Moons shown per planet at most.
  static const maxPerPlanet = 12;

  /// Which planet hosts which kind of record.
  static const hostOf = <String, String>{'people': 'family', 'wallets': 'money', 'boards': 'work', 'trips': 'travel'};

  /// Fresh until half the rhythm has passed, 0.6 when the rhythm is due,
  /// fading to 0 at twice the rhythm. Without a rhythm: calm 0.85.
  static double personScore(PersonMoonIn p, DateTime now) {
    final rhythm = p.rhythmDays ?? 0;
    if (rhythm <= 0) return 0.85;
    final since = _days(p.lastContact ?? p.createdAt, now);
    final ratio = since / rhythm;
    if (ratio <= 0.5) return 1;
    if (ratio <= 1) return 1 - 0.4 * (ratio - 0.5) / 0.5;
    return math.max(0, 0.6 * (2 - ratio));
  }

  /// Overdrawn wallets look neglected; used wallets sparkle.
  static double walletScore(WalletMoonIn w, DateTime now) {
    if (w.balanceBaseMilli < 0) return 0.15;
    final last = w.lastTx;
    if (last == null) return 0.8;
    return 0.8 + 0.2 * _decay(_days(last, now), 7);
  }

  /// Share of open cards on time, plus a little momentum.
  static double boardScore(BoardMoonIn b) {
    if (b.open == 0) return 0.85 + 0.15 * math.min(1, b.doneRecent / 3);
    final onTime = 1 - b.overdue / b.open;
    return (0.15 + 0.75 * onTime + math.min(0.1, b.doneRecent * 0.03)).clamp(0.0, 1.0);
  }

  /// Packing progress against the last week before departure.
  static double tripScore(TripMoonIn t, DateTime now) {
    if (t.status == TripStatus.done) return 0.6;
    final start = t.startDate;
    if (start == null) return 0.9;
    // Calendar days until departure (0 = leaving today, still packing).
    final days = _days(now, start);
    if (days < 0) return 0.9;
    if (days > 14) return 0.95;
    final packed = t.itemsTotal == 0 ? 1.0 : t.itemsPacked / t.itemsTotal;
    final expected = ((7 - days) / 7).clamp(0.0, 1.0);
    final v = expected == 0 ? 1.0 : (packed / expected).clamp(0.0, 1.0);
    return 0.2 + 0.8 * v;
  }

  /// Trackers fade without entries (half-life 4 days); lists stay calm.
  static double moduleScore(ModuleMoonIn m, DateTime now) {
    if (!m.tracker) return 0.8;
    return 0.1 + 0.9 * _decay(_days(m.lastEntry ?? m.createdAt, now), 4);
  }

  /// Whole calendar days from [a] to [b].
  static int _days(DateTime a, DateTime b) {
    final da = DateTime(a.year, a.month, a.day);
    final db = DateTime(b.year, b.month, b.day);
    return (db.difference(da).inHours / 24).round();
  }

  static double _decay(int days, double halfLife) => days <= 0 ? 1.0 : math.pow(0.5, days / halfLife).toDouble();
}

/// Colours for moons without their own colour: variations of the parent
/// planet's palette, so a planet's moons read as one family.
abstract final class MoonColors {
  static const _hueSteps = [0.0, 16, -16, 32, -32, 8, -8, 24, -24, 40, -40, 48];

  /// The [i]-th variation of [base].
  static Color variant(Color base, int i) {
    final hsl = HSLColor.fromColor(base);
    final hue = (hsl.hue + _hueSteps[i % _hueSteps.length] + 360) % 360;
    final light = (hsl.lightness + (i.isEven ? 0.04 : -0.04)).clamp(0.3, 0.82);
    return hsl.withHue(hue).withLightness(light).toColor();
  }

  /// The gem tint for wallets: the Money surface, deepened (as the moon
  /// shader recommends).
  static Color walletGem(PlanetPalette money, int i) {
    final hsl = HSLColor.fromColor(variant(money.surface, i));
    return hsl.withLightness((hsl.lightness * 0.78).clamp(0.25, 0.7)).toColor();
  }
}

/// Builds every planet's moons from [MoonInputs].
abstract final class MoonBuilder {
  /// Moons per planet key. Only planets in [palettes] (the visible ones)
  /// receive moons. Each planet shows at most [cap] moons: the most urgent /
  /// important are kept and shown in the user's order; the rest are counted
  /// in [MoonSet.overflow].
  static Map<String, MoonSet> build(
    MoonInputs inp, {
    required DateTime now,
    required Map<String, PlanetPalette> palettes,
    int cap = MoonRules.maxPerPlanet,
  }) {
    final byPlanet = <String, List<_Candidate>>{};
    void add(String planet, _Candidate c) {
      if (palettes.containsKey(planet)) (byPlanet[planet] ??= []).add(c);
    }

    // People around Family.
    final family = MoonRules.hostOf['people']!;
    final people = palettes.containsKey(family)
        ? inp.people.where((p) => p.showAsMoon).toList()
        : const <PersonMoonIn>[];
    for (var i = 0; i < people.length; i++) {
      final p = people[i];
      final rhythm = p.rhythmDays ?? 0;
      final closeness = rhythm <= 0 ? 0.3 : (1 - (rhythm - 1) / 30).clamp(0.0, 1.0);
      final score = MoonRules.personScore(p, now);
      add(
        family,
        _Candidate(
          order: i,
          priority: 1 - score + closeness * 0.01,
          moon: OrbitMoon(
            planetKey: family,
            refTable: 'people',
            refId: p.id,
            label: p.name,
            color: p.color != null ? Color(p.color!) : MoonColors.variant(_surface(palettes, family), i),
            kind: MoonKind.rocky,
            score: score,
            size: 0.5 + 0.5 * closeness,
            seed: seedOf(p.id),
          ),
        ),
      );
    }

    // Wallets around Money, sized by their share of the positive balances.
    final money = MoonRules.hostOf['wallets']!;
    final walletList = palettes.containsKey(money) ? inp.wallets : const <WalletMoonIn>[];
    final positive = walletList.fold<int>(0, (a, w) => a + math.max(0, w.balanceBaseMilli));
    for (var i = 0; i < walletList.length; i++) {
      final w = walletList[i];
      final share = positive <= 0 || w.balanceBaseMilli <= 0 ? 0.0 : w.balanceBaseMilli / positive;
      add(
        money,
        _Candidate(
          order: i,
          priority: share + (w.balanceBaseMilli < 0 ? 1 : 0),
          moon: OrbitMoon(
            planetKey: money,
            refTable: 'wallets',
            refId: w.id,
            label: w.name,
            color: w.color != null ? Color(w.color!) : MoonColors.walletGem(palettes[money]!, i),
            kind: MoonKind.metallic,
            score: MoonRules.walletScore(w, now),
            size: w.balanceBaseMilli < 0 ? 0.35 : 0.35 + 0.65 * math.sqrt(share),
            seed: seedOf(w.id),
          ),
        ),
      );
    }

    // Boards around Work, sized by their open cards.
    final work = MoonRules.hostOf['boards']!;
    final boardList = palettes.containsKey(work) ? inp.boards : const <BoardMoonIn>[];
    final maxOpen = boardList.fold<int>(0, (a, b) => math.max(a, b.open));
    for (var i = 0; i < boardList.length; i++) {
      final b = boardList[i];
      add(
        work,
        _Candidate(
          order: i,
          priority: b.open + b.overdue * 2.0,
          moon: OrbitMoon(
            planetKey: work,
            refTable: 'boards',
            refId: b.id,
            label: b.name,
            color: b.color != null ? Color(b.color!) : MoonColors.variant(palettes[work]!.glow, i),
            kind: MoonKind.lava,
            score: MoonRules.boardScore(b),
            size: maxOpen == 0 ? 0.55 : 0.4 + 0.6 * math.sqrt(b.open / maxOpen),
            seed: seedOf(b.id),
          ),
        ),
      );
    }

    // Trips around Travel: upcoming first (soonest first), then active and
    // undated ones; finished trips are not moons.
    final travel = MoonRules.hostOf['trips']!;
    final today = DateTime(now.year, now.month, now.day);
    final trips = palettes.containsKey(travel)
        ? inp.trips
              .where((t) => t.status != TripStatus.done && (t.endDate == null || !t.endDate!.isBefore(today)))
              .toList()
        : const <TripMoonIn>[];
    final ordered = [
      ...trips.where((t) => t.startDate != null && !t.startDate!.isBefore(today)).toList()
        ..sort((a, b) => a.startDate!.compareTo(b.startDate!)),
      ...trips.where((t) => t.startDate == null || t.startDate!.isBefore(today)),
    ];
    for (var i = 0; i < ordered.length; i++) {
      final t = ordered[i];
      final span = t.startDate != null && t.endDate != null ? t.endDate!.difference(t.startDate!).inDays : 5;
      add(
        travel,
        _Candidate(
          order: i,
          priority: -i.toDouble(),
          moon: OrbitMoon(
            planetKey: travel,
            refTable: 'trips',
            refId: t.id,
            label: t.destination,
            color: t.color != null ? Color(t.color!) : MoonColors.variant(_surface(palettes, travel), i),
            kind: MoonKind.icy,
            score: MoonRules.tripScore(t, now),
            size: 0.5 + 0.5 * (span / 14).clamp(0.0, 1.0),
            seed: seedOf(t.id),
          ),
        ),
      );
    }

    // Custom modules around the planet they are attached to. The user
    // attached them on purpose, so under the cap they are kept before any
    // person / wallet / board / trip (stale trackers first).
    for (var i = 0; i < inp.modules.length; i++) {
      final m = inp.modules[i];
      final score = MoonRules.moduleScore(m, now);
      add(
        m.planetKey,
        _Candidate(
          order: 1000 + i,
          priority: 10 + (1 - score),
          moon: OrbitMoon(
            planetKey: m.planetKey,
            refTable: 'custom_modules',
            refId: m.id,
            label: m.name,
            color: Color(m.color),
            kind: MoonKind.rocky,
            score: score,
            size: 0.55,
            seed: seedOf(m.id),
          ),
        ),
      );
    }

    return {for (final e in byPlanet.entries) e.key: _cap(e.value, cap)};
  }

  static MoonSet _cap(List<_Candidate> all, int cap) {
    if (all.length <= cap) return MoonSet([for (final c in all) c.moon]);
    final kept =
        ([...all]..sort((a, b) {
              final p = b.priority.compareTo(a.priority);
              return p != 0 ? p : a.order.compareTo(b.order);
            }))
            .take(cap)
            .toList()
          ..sort((a, b) => a.order.compareTo(b.order));
    return MoonSet([for (final c in kept) c.moon], overflow: all.length - cap);
  }

  static Color _surface(Map<String, PlanetPalette> palettes, String key) => palettes[key]!.surface;

  /// A stable 0..100 seed from a record id (FNV-1a).
  static double seedOf(String id) {
    var h = 0x811c9dc5;
    for (final c in id.codeUnits) {
      h = ((h ^ c) * 0x01000193) & 0xffffffff;
    }
    return (h % 100000) / 1000.0;
  }
}

class _Candidate {
  _Candidate({required this.order, required this.priority, required this.moon});
  final int order;
  final double priority;
  final OrbitMoon moon;
}
