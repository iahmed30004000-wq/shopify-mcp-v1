/// Groups the database tables into the areas of life shown in a restore
/// preview ("Health · 1,234 records"). Pure Dart.
library;

enum DataArea { faith, health, money, family, work, growth, body, travel, custom, other }

abstract final class DataAreas {
  static const Map<String, DataArea> _byTable = {
    'prayer_logs': DataArea.faith,
    'quran_bookmarks': DataArea.faith,
    'quran_sessions': DataArea.faith,
    'wird_plans': DataArea.faith,
    'hifz_items': DataArea.faith,
    'hifz_reviews': DataArea.faith,
    'health_alerts': DataArea.health,
    'conditions': DataArea.health,
    'medications': DataArea.health,
    'med_courses': DataArea.health,
    'med_rules': DataArea.health,
    'med_doses': DataArea.health,
    'lab_tests': DataArea.health,
    'lab_readings': DataArea.health,
    'appointments': DataArea.health,
    'doctor_questions': DataArea.health,
    'pain_entries': DataArea.health,
    'mood_entries': DataArea.health,
    'habits': DataArea.health,
    'habit_logs': DataArea.health,
    'worries': DataArea.health,
    'currencies': DataArea.money,
    'wallets': DataArea.money,
    'budget_items': DataArea.money,
    'transactions': DataArea.money,
    'jars': DataArea.money,
    'jar_deposits': DataArea.money,
    'debts': DataArea.money,
    'debt_payments': DataArea.money,
    'obligations': DataArea.money,
    'obligation_payments': DataArea.money,
    'people': DataArea.family,
    'contact_logs': DataArea.family,
    'tasks': DataArea.work,
    'projects': DataArea.work,
    'project_items': DataArea.work,
    'boards': DataArea.work,
    'board_cards': DataArea.work,
    'learning_goals': DataArea.growth,
    'goal_logs': DataArea.growth,
    'exercises': DataArea.body,
    'workout_logs': DataArea.body,
    'avoid_items': DataArea.body,
    'fasting_sessions': DataArea.body,
    'water_logs': DataArea.body,
    'foods': DataArea.body,
    'food_logs': DataArea.body,
    'meal_plans': DataArea.body,
    'meal_slots': DataArea.body,
    'meal_slot_foods': DataArea.body,
    'food_rules': DataArea.body,
    'trips': DataArea.travel,
    'trip_items': DataArea.travel,
    'packing_templates': DataArea.travel,
    'travel_documents': DataArea.travel,
    'custom_modules': DataArea.custom,
    'custom_entries': DataArea.custom,
  };

  /// The area of an SQL table (settings, reminders, activity history and
  /// import archives are [DataArea.other]).
  static DataArea of(String table) => _byTable[table] ?? DataArea.other;

  /// Records per area (every area present, zero when empty).
  static Map<DataArea, int> totals(Map<String, int> counts) {
    final out = {for (final a in DataArea.values) a: 0};
    for (final MapEntry(:key, :value) in counts.entries) {
      out[of(key)] = out[of(key)]! + value;
    }
    return out;
  }
}
