import 'package:flutter/material.dart';

import '../../design/themes.dart';

/// The curated colour swatches offered by colour fields: every planet's
/// surface and glow hue (theme-independent data, not UI styling).
abstract final class CuratedPalette {
  static final List<Color> colors = [
    for (final p in PlanetPalettes.byKey.values) p.surface,
    for (final p in PlanetPalettes.byKey.values) p.glow,
  ];
}

/// Curated icon set, addressed by stable string keys (stored in the database,
/// e.g. `Planets.icon`, `CustomModules.icon`). Resolve with [resolve].
abstract final class InteractionIcons {
  static const Map<String, IconData> curated = {
    'star': Icons.star_rounded,
    'mosque': Icons.mosque_rounded,
    'moon': Icons.dark_mode_rounded,
    'sun': Icons.wb_sunny_rounded,
    'twilight': Icons.wb_twilight_rounded,
    'book': Icons.menu_book_rounded,
    'heart': Icons.favorite_rounded,
    'family': Icons.family_restroom_rounded,
    'child': Icons.child_care_rounded,
    'elder': Icons.elderly_rounded,
    'people': Icons.groups_rounded,
    'person': Icons.person_rounded,
    'handshake': Icons.handshake_rounded,
    'charity': Icons.volunteer_activism_rounded,
    'briefcase': Icons.work_rounded,
    'laptop': Icons.laptop_rounded,
    'code': Icons.code_rounded,
    'folder': Icons.folder_rounded,
    'note': Icons.edit_note_rounded,
    'coins': Icons.paid_rounded,
    'wallet': Icons.account_balance_wallet_rounded,
    'savings': Icons.savings_rounded,
    'receipt': Icons.receipt_long_rounded,
    'cart': Icons.shopping_cart_rounded,
    'bag': Icons.shopping_bag_rounded,
    'sprout': Icons.grass_rounded,
    'leaf': Icons.eco_rounded,
    'tree': Icons.park_rounded,
    'school': Icons.school_rounded,
    'bulb': Icons.lightbulb_rounded,
    'mind': Icons.psychology_rounded,
    'meditate': Icons.self_improvement_rounded,
    'dumbbell': Icons.fitness_center_rounded,
    'run': Icons.directions_run_rounded,
    'bike': Icons.directions_bike_rounded,
    'swim': Icons.pool_rounded,
    'hike': Icons.hiking_rounded,
    'ball': Icons.sports_soccer_rounded,
    'pulse': Icons.monitor_heart_rounded,
    'pill': Icons.medication_rounded,
    'hospital': Icons.local_hospital_rounded,
    'water': Icons.water_drop_rounded,
    'spa': Icons.spa_rounded,
    'sleep': Icons.bedtime_rounded,
    'food': Icons.restaurant_rounded,
    'coffee': Icons.local_cafe_rounded,
    'cake': Icons.cake_rounded,
    'home': Icons.home_rounded,
    'car': Icons.directions_car_rounded,
    'fuel': Icons.local_gas_station_rounded,
    'plane': Icons.flight_rounded,
    'luggage': Icons.luggage_rounded,
    'hotel': Icons.hotel_rounded,
    'map': Icons.map_rounded,
    'explore': Icons.explore_rounded,
    'globe': Icons.language_rounded,
    'pet': Icons.pets_rounded,
    'music': Icons.music_note_rounded,
    'palette': Icons.palette_rounded,
    'camera': Icons.photo_camera_rounded,
    'brush': Icons.brush_rounded,
    'gift': Icons.card_giftcard_rounded,
    'party': Icons.celebration_rounded,
    'trophy': Icons.emoji_events_rounded,
    'flag': Icons.flag_rounded,
    'bolt': Icons.bolt_rounded,
    'fire': Icons.local_fire_department_rounded,
    'sparkle': Icons.auto_awesome_rounded,
    'phone': Icons.phone_rounded,
    'alarm': Icons.alarm_rounded,
    'calendar': Icons.event_rounded,
  };

  /// Icon for [key] (falls back to a star for unknown / null keys).
  static IconData resolve(String? key, {IconData fallback = Icons.star_rounded}) => curated[key] ?? fallback;
}
