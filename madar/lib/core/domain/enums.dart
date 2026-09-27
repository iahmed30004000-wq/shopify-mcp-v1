/// Domain enums persisted by name (drift `textEnum`). Never rename a value –
/// only append – because stored rows reference the names.
library;

/// The six windows of the day, anchored on the five prayers.
enum PrayerWindow {
  fajr, // Fajr → sunrise ("after Fajr")
  duha, // sunrise → Dhuhr
  dhuhr, // Dhuhr → Asr
  asr, // Asr → Maghrib
  maghrib, // Maghrib → Isha
  isha, // Isha → next Fajr ("after Isha")
  anytime, // not bound to a window
}

/// Obligatory prayers plus voluntary ones tracked by the prayer tracker.
enum Prayer { fajr, dhuhr, asr, maghrib, isha, duha, witr, qiyam, sunnahFajr, sunnahDhuhr, sunnahMaghrib, sunnahIsha }

enum PrayerStatus { prayed, late, missed, qada }

enum Severity { info, warning, critical }

enum MedKind { medication, supplement, injection, other }

/// "Taken with" slot for a medication / supplement.
enum TakenWith { emptyStomach, breakfast, lunch, dinner, bedtime, other, perCourse, anytime }

/// Timing rules the dose scheduler enforces.
enum MedRuleKind {
  /// Keep A and B at least [minutes] apart.
  separate,

  /// Take A [minutes] before food.
  beforeFood,

  /// Take A [minutes] after food.
  afterFood,

  /// Take A with food.
  withFood,

  /// Free-form rule shown as a note.
  custom,
}

enum DoseStatus { taken, skipped, snoozed, missed }

enum CourseFrequency { daily, weekly, monthly }

enum TagKind { painLocation, painTrigger, moodFactor, habitCategory, generic }

enum WalletKind { personal, business }

enum TxKind { expense, income, transfer, adjustment }

enum BudgetMode { amount, percent }

enum PercentBase { parent, total }

enum BudgetPeriod { monthly, weekly }

enum DebtDirection { iOwe, owedToMe }

enum Recurrence { weekly, monthly, yearly }

enum ContactChannel { call, visit, message, other }

enum ProjectStatus { active, paused, done }

enum TripStatus { planned, active, done }

enum CustomModuleKind { tracker, list }

/// Custom module field types (Custom Modules Builder).
enum FieldType { text, number, date, time, checkbox, singleSelect, multiSelect, rating, currency }

/// Built-in planet archetypes (procedural world style on the Astrolabe Orbit).
enum PlanetArchetype {
  faith, // golden engraved celestial-dome world
  ocean, // bioluminescent ocean (Health)
  terracotta, // warm world with people-moons (Family)
  industrial, // city-lights night side (Work)
  crystal, // crystalline with gold veins (Money)
  verdant, // expanding forests (Growth)
  volcanic, // energy rivers (Body)
  gasGiant, // ringed giant with ships (Travel)
  ice, // extra styles for user-added planets
  desert,
}
