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

/// How a Quran session was spent (feeds the daily wird and the Faith planet).
enum QuranSessionMode { read, listen, review }

/// Unit a daily wird is measured in.
enum WirdUnit { pages, juz, hizb, ayat }

/// What a Hifz item holds: a Quran ayah range, a hadith, or free text.
enum HifzKind { ayat, hadith, custom }

/// What one of the user's own food rules matches (schema v3, Nutrition).
///
/// Never a medical judgement of ours: the user writes the rule himself and
/// picks what it matches.
enum FoodRuleTarget {
  /// One food of his library.
  food,

  /// One of his own tags («مقلي»، «ملح عالي»).
  tag,

  /// Anything eaten (used with a time window or a daily count, e.g.
  /// "anything after 22:00").
  anyFood,
}

/// How heavily one of the user's own food rules weighs on a condition – his
/// choice, in his words («خفيف / متوسط / عالي»).
enum RiskWeight { low, medium, high }

// ------------------------------------------- the AI bridge (schema v4) ----

/// How a «خطة مدار» JSON reached the phone (Part 3's AI bridge). Never a
/// network fetch: Madar only ever reads a file, a share intent or the
/// clipboard.
enum PlanOrigin {
  /// Picked with the file picker.
  file,

  /// Pasted into the import box.
  paste,

  /// Arrived through the Android share sheet.
  share,

  /// Came back through the optional own-key AI chat.
  chat,
}

/// What the user decided about one suggestion of an imported plan.
enum PlanItemState {
  /// Shown, not decided yet.
  pending,

  /// Approved and written to his data.
  applied,

  /// He said no (or the validator refused it).
  rejected,

  /// Applied and then undone.
  undone,

  /// A kind this version cannot apply yet (a recipe, a pantry item): kept
  /// in the history so nothing is lost.
  deferred,
}
