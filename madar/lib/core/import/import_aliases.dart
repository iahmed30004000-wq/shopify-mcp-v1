/// Alias tables of the prototype importer: which JSON keys mean which Madar
/// table, which keys mean which column, and which words mean which enum
/// value. Every alias is compared after [ImportText.key] (keys) or
/// [ImportText.words] (values), so case, `_`, `-`, spaces, Arabic diacritics,
/// hamza forms and a leading `ال` never matter. Documented in
/// `docs/import-format.md` – keep both in sync.
library;

import '../domain/enums.dart';
import 'import_text.dart';

/// Every destination of imported data (one per Drift table, plus the
/// auto-generated custom modules for sections nothing else claims).
enum ImportSection {
  healthAlerts,
  conditions,
  medications,
  medDoses,
  labTests,
  labReadings,
  appointments,
  doctorQuestions,
  painEntries,
  moodEntries,
  habits,
  habitLogs,
  worries,
  currencies,
  wallets,
  budgetItems,
  transactions,
  jars,
  jarDeposits,
  debts,
  debtPayments,
  obligations,
  people,
  contactLogs,
  projects,
  projectItems,
  boards,
  boardCards,
  trips,
  tripItems,
  travelDocuments,
  learningGoals,
  goalLogs,
  exercises,
  workoutLogs,
  avoidItems,
  fastingSessions,
  waterLogs,
  prayerLogs,
  tasks,
  customModules,
  customEntries;

  /// The log table records of this section become when they sit under
  /// `logs` or in a day-keyed map (`logs.meds` = dose log).
  ImportSection get logVariant => switch (this) {
    medications => medDoses,
    labTests => labReadings,
    habits => habitLogs,
    people => contactLogs,
    learningGoals => goalLogs,
    exercises => workoutLogs,
    jars => jarDeposits,
    debts => debtPayments,
    _ => this,
  };

  /// Planet the section belongs to (used for custom modules found next to
  /// it and for the report grouping).
  String get planetKey => switch (this) {
    healthAlerts ||
    conditions ||
    medications ||
    medDoses ||
    labTests ||
    labReadings ||
    appointments ||
    doctorQuestions ||
    painEntries ||
    moodEntries ||
    habits ||
    habitLogs ||
    worries => 'health',
    currencies ||
    wallets ||
    budgetItems ||
    transactions ||
    jars ||
    jarDeposits ||
    debts ||
    debtPayments ||
    obligations => 'money',
    people || contactLogs => 'family',
    projects || projectItems || learningGoals || goalLogs => 'growth',
    boards || boardCards => 'work',
    trips || tripItems || travelDocuments => 'travel',
    exercises || workoutLogs || avoidItems || fastingSessions || waterLogs => 'body',
    prayerLogs || tasks => 'faith',
    customModules || customEntries => 'growth',
  };
}

/// A matched section key plus an optional hint (e.g. `stress` inside the
/// mood table, `income` for transactions, `supplement` for medications).
typedef SectionMatch = ({ImportSection section, String? hint});

abstract final class ImportAliases {
  // ------------------------------------------------------------ sections --

  /// Raw aliases per section. `alias:hint` attaches a hint.
  static const Map<ImportSection, List<String>> sectionAliases = {
    ImportSection.healthAlerts: [
      'alerts', 'alert', 'healthAlerts', 'criticalAlerts', 'medicalAlerts', 'healthWarnings', 'redFlags', //
      'تنبيهات', 'تنبيهات صحية', 'تحذيرات', 'تحذيرات صحية', 'تنبيه',
    ],
    ImportSection.conditions: [
      'conditions', 'condition', 'diagnoses', 'diagnosis', 'diseases', 'illnesses', 'chronic', //
      'chronicConditions', 'medicalHistory', 'أمراض', 'حالات', 'حالات صحية', 'تشخيصات', 'تشخيص', 'أمراض مزمنة',
    ],
    ImportSection.medications: [
      'meds', 'med', 'medications', 'medication', 'medicines', 'medicine', 'drugs', 'pills', 'medsList', //
      'prescriptions', 'supplements:supplement', 'supplement:supplement', 'vitamins:supplement',
      'أدوية', 'دواء', 'علاج', 'علاجات', 'مكملات:supplement', 'مكملات غذائية:supplement', 'فيتامينات:supplement',
    ],
    ImportSection.medDoses: [
      'doses', 'doseLog', 'doseLogs', 'medLog', 'medLogs', 'medsLog', 'medicationLog', 'medicationLogs', 'intake', //
      'intakeLog', 'takenLog', 'pillLog', 'جرعات', 'سجل الأدوية', 'سجل الجرعات',
    ],
    ImportSection.labTests: [
      'labs', 'lab', 'labTests', 'labTest', 'tests', 'bloodTests', 'bloodwork', 'analyses', 'labPanel', //
      'labPanels', 'تحاليل', 'تحليل', 'فحوصات', 'مختبر', 'تحاليل طبية',
    ],
    ImportSection.labReadings: [
      'readings', 'labReadings', 'labResults', 'results', 'labLog', 'labLogs', 'labHistory', 'testResults', //
      'نتائج', 'قراءات', 'نتائج التحاليل',
    ],
    ImportSection.appointments: [
      'appointments', 'appointment', 'visits', 'doctorVisits', 'appts', 'مواعيد', 'مواعيد الطبيب', 'زيارات', 'موعد',
    ],
    ImportSection.doctorQuestions: [
      'questions', 'doctorQuestions', 'questionsForDoctor', 'askDoctor', 'أسئلة', 'أسئلة للطبيب', 'أسئلة الطبيب',
    ],
    ImportSection.painEntries: [
      'pain', 'pains', 'painLog', 'painLogs', 'painEntries', 'painJournal', 'painDiary', 'ألم', 'آلام', 'سجل الألم',
    ],
    ImportSection.moodEntries: [
      'mood', 'moods', 'moodLog', 'moodLogs', 'moodEntries', 'feelings', 'wellbeing', 'checkins', //
      'stress:stress', 'stressLog:stress', 'stressLogs:stress', 'stressLevel:stress', 'anxiety:anxiety',
      'energy:energy', 'sleep:sleep', 'sleepLog:sleep', 'sleepHours:sleep', 'caffeine:caffeine', 'coffee:caffeine',
      'مزاج', 'سجل المزاج', 'مشاعر', 'توتر:stress', 'ضغط نفسي:stress', 'قلق:anxiety', 'طاقة:energy', 'نوم:sleep',
      'ساعات النوم:sleep', 'قهوة:caffeine', 'كافيين:caffeine',
    ],
    ImportSection.habits: ['habits', 'habit', 'habitList', 'routines', 'عادات', 'روتين', 'عادات يومية'],
    ImportSection.habitLogs: ['habitLog', 'habitLogs', 'habitChecks', 'habitHistory', 'سجل العادات'],
    ImportSection.worries: [
      'worries', 'worry', 'worryList', 'worryWindow', 'parkedWorries', 'concerns', 'مخاوف', 'هموم', 'همومي', 'مخاوفي',
    ],
    ImportSection.currencies: [
      'currencies', 'rates', 'exchangeRates', 'fx', 'fxRates', 'currencyRates', 'عملات', 'أسعار الصرف', 'سعر الصرف',
    ],
    ImportSection.wallets: ['wallets', 'wallet', 'accounts', 'account', 'محافظ', 'محفظة', 'حسابات', 'حساب'],
    ImportSection.budgetItems: [
      'budget', 'budgets', 'budgetItems', 'budgetTree', 'categories', 'budgetCategories', 'envelopes', //
      'ميزانية', 'بنود الميزانية', 'فئات', 'تصنيفات',
    ],
    ImportSection.transactions: [
      'transactions', 'transaction', 'txns', 'txs', 'ledger', 'spending', 'purchases', 'moneyLog', //
      'expenses:expense', 'expense:expense', 'income:income', 'incomes:income', 'earnings:income',
      'معاملات', 'حركات', 'مصاريف:expense', 'مصروفات:expense', 'نفقات:expense', 'دخل:income', 'مدخول:income',
    ],
    ImportSection.jars: [
      'jars', 'jar', 'savings', 'savingsJars', 'savingJars', 'piggyBanks', 'funds', 'sinkingFunds', //
      'حصالات', 'حصالة', 'ادخار', 'مدخرات', 'توفير',
    ],
    ImportSection.jarDeposits: ['deposits', 'jarDeposits', 'savingsLog', 'إيداعات'],
    ImportSection.debts: ['debts', 'debt', 'loans', 'loan', 'ious', 'iou', 'ديون', 'قروض', 'سلف', 'ديون وقروض'],
    ImportSection.debtPayments: ['debtPayments', 'repayments', 'تسديدات', 'سداد'],
    ImportSection.obligations: [
      'obligations', 'recurring', 'recurringPayments', 'bills', 'subscriptions', 'fixedExpenses', 'fixedCosts', //
      'commitments', 'التزامات', 'فواتير', 'اشتراكات', 'مصاريف ثابتة', 'دفعات دورية',
    ],
    ImportSection.people: [
      'people', 'persons', 'contacts', 'family', 'friends', 'relatives', 'circle', 'network', 'loved ones', //
      'أشخاص', 'عائلة', 'أهل', 'أقارب', 'أصدقاء', 'جهات اتصال', 'ناس',
    ],
    ImportSection.contactLogs: [
      'contactLog', 'contactLogs', 'callLog', 'calls', 'interactions', 'contactHistory', 'سجل التواصل', 'تواصل', //
      'مكالمات',
    ],
    ImportSection.projects: ['projects', 'project', 'مشاريع', 'مشروع'],
    ImportSection.projectItems: ['projectItems', 'milestones', 'projectTasks', 'مراحل'],
    ImportSection.boards: [
      'boards', 'board', 'work', 'kanban', 'kanbans', 'business', 'businesses', 'countries', 'workBoards', //
      'عمل', 'لوحات', 'أعمال', 'كانبان',
    ],
    ImportSection.boardCards: ['cards', 'boardCards', 'workTasks', 'kanbanCards', 'بطاقات'],
    ImportSection.trips: ['trips', 'trip', 'travel', 'travels', 'journeys', 'سفر', 'رحلات', 'رحلة', 'أسفار'],
    ImportSection.tripItems: ['packing', 'packingList', 'tripItems', 'تجهيز', 'قائمة التجهيز', 'حقيبة السفر'],
    ImportSection.travelDocuments: [
      'documents', 'docs', 'travelDocuments', 'passports', 'visas', 'papers', 'وثائق', 'مستندات', 'جوازات', 'أوراق',
    ],
    ImportSection.learningGoals: [
      'goals', 'goal', 'learning', 'learningGoals', 'studies', 'courses', 'أهداف', 'هدف', 'تعلم', 'دراسة',
    ],
    ImportSection.goalLogs: ['goalLogs', 'goalLog', 'progressLog', 'learningLog', 'studyLog', 'سجل التعلم'],
    ImportSection.exercises: [
      'exercises', 'exercise', 'workouts', 'workout', 'gym', 'training', 'fitness', 'تمارين', 'رياضة', 'جيم', 'تمرين',
    ],
    ImportSection.workoutLogs: [
      'workoutLog', 'workoutLogs', 'gymLog', 'trainingLog', 'exerciseLog', 'exerciseLogs', 'سجل التمارين',
    ],
    ImportSection.avoidItems: [
      'avoid', 'avoidList', 'avoidItems', 'avoids', 'donts', 'doNot', 'forbidden', 'restrictions', //
      'ممنوعات', 'ممنوع', 'تجنب', 'تجنبات', 'محظورات',
    ],
    ImportSection.fastingSessions: ['fasting', 'fasts', 'fastingLog', 'fastingSessions', 'fastLog', 'صيام', 'صوم'],
    ImportSection.waterLogs: [
      'water', 'waterLog', 'waterLogs', 'hydration', 'waterIntake', 'ماء', 'مياه', 'شرب الماء', 'سجل الماء',
    ],
    ImportSection.prayerLogs: [
      'prayers', 'prayer', 'prayerLog', 'prayerLogs', 'salah', 'salat', 'namaz', 'صلاة', 'صلوات', 'سجل الصلاة',
    ],
    ImportSection.tasks: [
      'tasks', 'task', 'todos', 'todo', 'toDoList', 'dayPlan', 'agenda', 'windows:windows', 'prayerWindows:windows', //
      'مهام', 'مهمة', 'واجبات', 'خطة اليوم', 'أوقات الصلاة:windows',
    ],
  };

  static final Map<String, SectionMatch> _sections = () {
    final out = <String, SectionMatch>{};
    for (final e in sectionAliases.entries) {
      for (final raw in e.value) {
        final i = raw.lastIndexOf(':');
        final alias = i > 0 ? raw.substring(0, i) : raw;
        final hint = i > 0 ? raw.substring(i + 1) : null;
        out.putIfAbsent(ImportText.key(alias), () => (section: e.key, hint: hint));
      }
    }
    return out;
  }();

  /// The section a JSON key names, or null. Tries the exact normalised key,
  /// then without a plural `s` / a `list`/`log` suffix.
  static SectionMatch? sectionFor(String rawKey) {
    final k = ImportText.key(rawKey);
    if (k.isEmpty) return null;
    final direct = _sections[k];
    if (direct != null) return direct;
    for (final suffix in const ['list', 'data', 'items', 'entries', 'records', 'tracker']) {
      if (k.length > suffix.length + 2 && k.endsWith(suffix)) {
        final base = _sections[k.substring(0, k.length - suffix.length)];
        if (base != null) return base;
      }
    }
    if (k.length > 3 && k.endsWith('s')) return _sections[k.substring(0, k.length - 1)];
    return null;
  }

  // ------------------------------------------------------------- domains --

  /// Keys that group sections by area (`data.health.meds`) → planet key.
  static final Map<String, String> _domains = {
    for (final e in const {
      'health': 'health', 'medical': 'health', 'wellness': 'health', 'wellbeing': 'health', 'صحة': 'health', //
      'طبي': 'health', 'money': 'money', 'finance': 'money', 'finances': 'money', 'مال': 'money', 'مالية': 'money',
      'family': 'family', 'social': 'family', 'relationships': 'family', 'عائلة': 'family', 'علاقات': 'family',
      'work': 'work', 'career': 'work', 'business': 'work', 'عمل': 'work', 'أعمال': 'work',
      'growth': 'growth', 'learning': 'growth', 'نمو': 'growth', 'تطوير': 'growth', 'تعلم': 'growth',
      'body': 'body', 'fitness': 'body', 'جسد': 'body', 'جسم': 'body', 'لياقة': 'body',
      'travel': 'travel', 'سفر': 'travel', 'faith': 'faith', 'deen': 'faith', 'worship': 'faith', 'عبادة': 'faith',
      'إيمان': 'faith', 'دين': 'faith', 'home': 'family', 'life': 'growth', 'حياة': 'growth',
    }.entries)
      ImportText.key(e.key): e.value,
  };

  static String? domainFor(String rawKey) => _domains[ImportText.key(rawKey)];

  /// Keys that hold an export's log half (`{"data":…, "logs":…}`).
  static final Set<String> logContainers = {
    for (final k in const ['logs', 'log', 'history', 'journal', 'daily', 'dailyLogs', 'days', 'entries', 'سجل', 'سجلات', 'يوميات'])
      ImportText.key(k),
  };

  /// Keys that hold an export's data half.
  static final Set<String> dataContainers = {
    for (final k in const ['data', 'state', 'store', 'db', 'database', 'payload', 'content', 'بيانات']) ImportText.key(k),
  };

  /// Export metadata (kept in the archive, shown in the report).
  static final Set<String> metaKeys = {
    for (final k in const [
      'version', 'schemaVersion', 'schema', 'exportedAt', 'exported', 'exportDate', 'createdAt', 'updatedAt', //
      'savedAt', 'lastSaved', 'app', 'appName', 'generator', 'source', 'format', 'backupDate', 'timestamp', 'device',
      'الإصدار', 'تاريخ التصدير',
    ])
      ImportText.key(k),
  };

  /// Keys whose list value holds the records of the enclosing section
  /// (`"budget": {"items": [...], "weeksPerMonth": 4}`).
  static final Set<String> genericContainers = {
    for (final k in const ['items', 'list', 'entries', 'records', 'rows', 'data', 'values', 'all', 'عناصر', 'قائمة', 'بيانات'])
      ImportText.key(k),
  };

  // ------------------------------------------------------ nested children --

  /// Child sections found *inside* a record: `labs[].readings`,
  /// `habits[].log`, `boards[].cards`, `budget[].children` …
  static const Map<ImportSection, (ImportSection, List<String>)> childAliases = {
    ImportSection.labTests: (ImportSection.labReadings, [
      'readings', 'values', 'history', 'results', 'log', 'logs', 'entries', 'measurements', 'data', //
      'قراءات', 'نتائج', 'سجل', 'قيم',
    ]),
    ImportSection.medications: (ImportSection.medDoses, ['doses', 'log', 'logs', 'history', 'intake', 'جرعات', 'سجل']),
    ImportSection.habits: (ImportSection.habitLogs, [
      'log', 'logs', 'history', 'days', 'dates', 'checks', 'checkins', 'completed', 'completions', 'doneDates', //
      'record', 'سجل', 'أيام',
    ]),
    ImportSection.people: (ImportSection.contactLogs, [
      'contacts', 'contactLog', 'log', 'logs', 'history', 'calls', 'interactions', 'سجل', 'تواصل',
    ]),
    ImportSection.projects: (ImportSection.projectItems, [
      'items', 'tasks', 'todos', 'steps', 'milestones', 'checklist', 'subtasks', 'مهام', 'خطوات', 'مراحل', 'عناصر',
    ]),
    ImportSection.boards: (ImportSection.boardCards, ['cards', 'tasks', 'items', 'todos', 'مهام', 'بطاقات']),
    ImportSection.trips: (ImportSection.tripItems, [
      'items', 'packing', 'packingList', 'checklist', 'todo', 'تجهيز', 'قائمة', 'أغراض',
    ]),
    ImportSection.learningGoals: (ImportSection.goalLogs, ['log', 'logs', 'history', 'sessions', 'entries', 'سجل']),
    ImportSection.exercises: (ImportSection.workoutLogs, ['log', 'logs', 'history', 'sessions', 'سجل']),
    ImportSection.jars: (ImportSection.jarDeposits, [
      'deposits', 'history', 'log', 'transactions', 'entries', 'إيداعات', 'سجل',
    ]),
    ImportSection.debts: (ImportSection.debtPayments, ['payments', 'repayments', 'history', 'log', 'دفعات', 'سداد']),
    ImportSection.budgetItems: (ImportSection.budgetItems, [
      'children', 'items', 'sub', 'subs', 'subItems', 'subcategories', 'categories', 'lines', 'بنود', 'فرعية', //
      'تفرعات', 'عناصر',
    ]),
    ImportSection.wallets: (ImportSection.transactions, ['transactions', 'history', 'entries', 'txns', 'حركات', 'معاملات']),
    ImportSection.appointments: (ImportSection.doctorQuestions, ['questions', 'أسئلة']),
  };

  static final Map<ImportSection, (ImportSection, Set<String>)> _children = {
    for (final e in childAliases.entries) e.key: (e.value.$1, {for (final a in e.value.$2) ImportText.key(a)}),
  };

  /// The child section a key of a [parent] record holds, or null.
  static ImportSection? childFor(ImportSection parent, String rawKey) {
    final c = _children[parent];
    if (c == null) return null;
    return c.$2.contains(ImportText.key(rawKey)) ? c.$1 : null;
  }

  // ------------------------------------------------------ kanban columns --

  static final Map<String, String> _columns = {
    for (final e in const {
      'todo': 'todo', 'toDo': 'todo', 'to do': 'todo', 'backlog': 'todo', 'new': 'todo', 'pending': 'todo', //
      'open': 'todo', 'next': 'todo', 'جديد': 'todo', 'قيد الانتظار': 'todo', 'للعمل': 'todo', 'مطلوب': 'todo',
      'doing': 'doing', 'inProgress': 'doing', 'progress': 'doing', 'wip': 'doing', 'active': 'doing',
      'current': 'doing', 'started': 'doing', 'جاري': 'doing', 'قيد التنفيذ': 'doing', 'قيد العمل': 'doing',
      'done': 'done', 'completed': 'done', 'complete': 'done', 'finished': 'done', 'closed': 'done',
      'منجز': 'done', 'مكتمل': 'done', 'تم': 'done', 'منتهي': 'done',
    }.entries)
      ImportText.key(e.key): e.value,
  };

  /// `todo` / `doing` / `done` for a well-known column name, else null.
  static String? knownColumn(String raw) => _columns[ImportText.key(raw)];

  // -------------------------------------------------------- field aliases --

  static const id = ['id', '_id', 'uid', 'uuid', 'key', 'ref', 'معرف', 'رقم تعريف'];
  static const name = ['name', 'title', 'label', 'text', 'اسم', 'عنوان', 'الاسم', 'العنوان'];
  static const notes = [
    'notes', 'note', 'comment', 'comments', 'description', 'desc', 'details', 'memo', 'remarks', //
    'ملاحظات', 'ملاحظة', 'وصف', 'تفاصيل', 'تعليق',
  ];
  static const date = [
    'date', 'at', 'datetime', 'dateTime', 'timestamp', 'ts', 'day', 'when', 'on', 'loggedAt', 'recordedAt', //
    'created', 'createdAt', 'time', 'تاريخ', 'التاريخ', 'يوم', 'وقت', 'متى',
  ];
  static const clock = ['time', 'hour', 'clock', 'وقت', 'الوقت', 'ساعة'];
  static const active = ['active', 'enabled', 'isActive', 'current', 'نشط', 'فعال'];
  static const inactive = ['archived', 'stopped', 'inactive', 'paused', 'disabled', 'مؤرشف', 'متوقف'];
  static const done = [
    'done', 'completed', 'complete', 'checked', 'finished', 'isDone', 'status', 'تم', 'منجز', 'مكتمل', 'حالة',
  ];
  static const amount = [
    'amount', 'value', 'sum', 'total', 'price', 'cost', 'money', 'planned', 'plan', 'limit', 'budget', //
    'allocated', 'مبلغ', 'قيمة', 'المبلغ', 'السعر', 'تكلفة', 'مخصص',
  ];
  static const percent = ['percent', 'pct', '%', 'percentage', 'share', 'ratio', 'نسبة', 'النسبة', 'بالمئة', 'بالمية'];
  static const currency = ['currency', 'cur', 'ccy', 'curr', 'currencyCode', 'عملة', 'العملة'];
  static const parent = [
    'parent', 'parentId', 'parentName', 'parentKey', 'group', 'under', 'belongsTo', 'الأب', 'تابع', 'ضمن', 'تابع ل',
  ];
  static const period = ['period', 'per', 'frequency', 'cycle', 'every', 'interval', 'الفترة', 'دورة', 'كل', 'تكرار'];
  static const weeksPerMonth = ['weeksPerMonth', 'weeksInMonth', 'weekFactor', 'أسابيع الشهر', 'عدد الأسابيع'];
  static const baseCurrency = [
    'baseCurrency', 'base', 'mainCurrency', 'defaultCurrency', 'homeCurrency', 'currency', 'العملة الأساسية', 'عملة',
  ];

  // --------------------------------------------------------- enum aliases --

  static Map<String, T> _enumTable<T>(Map<String, T> raw) => {
    for (final e in raw.entries) ImportText.words(e.key): e.value,
  };

  static final takenWith = _enumTable<TakenWith>({
    'empty stomach': TakenWith.emptyStomach, 'emptystomach': TakenWith.emptyStomach, 'empty': TakenWith.emptyStomach, //
    'fasting': TakenWith.emptyStomach, 'before food': TakenWith.emptyStomach, 'before breakfast': TakenWith.emptyStomach,
    'before meal': TakenWith.emptyStomach, 'before meals': TakenWith.emptyStomach, 'على الريق': TakenWith.emptyStomach,
    'الريق': TakenWith.emptyStomach, 'معدة فارغة': TakenWith.emptyStomach, 'قبل الأكل': TakenWith.emptyStomach,
    'قبل الفطور': TakenWith.emptyStomach, 'صائم': TakenWith.emptyStomach,
    'breakfast': TakenWith.breakfast, 'with breakfast': TakenWith.breakfast, 'after breakfast': TakenWith.breakfast,
    'فطور': TakenWith.breakfast, 'مع الفطور': TakenWith.breakfast, 'بعد الفطور': TakenWith.breakfast,
    'الإفطار': TakenWith.breakfast, 'مع الإفطار': TakenWith.breakfast,
    'lunch': TakenWith.lunch, 'with lunch': TakenWith.lunch, 'after lunch': TakenWith.lunch, 'غداء': TakenWith.lunch,
    'مع الغداء': TakenWith.lunch, 'بعد الغداء': TakenWith.lunch,
    'dinner': TakenWith.dinner, 'supper': TakenWith.dinner, 'with dinner': TakenWith.dinner,
    'after dinner': TakenWith.dinner, 'عشاء': TakenWith.dinner, 'مع العشاء': TakenWith.dinner,
    'بعد العشاء': TakenWith.dinner,
    'bedtime': TakenWith.bedtime, 'bed': TakenWith.bedtime, 'before bed': TakenWith.bedtime,
    'before sleep': TakenWith.bedtime, 'night': TakenWith.bedtime, 'at night': TakenWith.bedtime,
    'قبل النوم': TakenWith.bedtime, 'عند النوم': TakenWith.bedtime, 'النوم': TakenWith.bedtime, 'ليلا': TakenWith.bedtime,
    'other': TakenWith.other, 'أخرى': TakenWith.other, 'غير ذلك': TakenWith.other,
    'per course': TakenWith.perCourse, 'percourse': TakenWith.perCourse, 'course': TakenWith.perCourse,
    'as prescribed': TakenWith.perCourse, 'حسب الكورس': TakenWith.perCourse, 'كورس': TakenWith.perCourse,
    'حسب الوصفة': TakenWith.perCourse,
    'anytime': TakenWith.anytime, 'any time': TakenWith.anytime, 'any': TakenWith.anytime,
    'whenever': TakenWith.anytime, 'أي وقت': TakenWith.anytime, 'في أي وقت': TakenWith.anytime,
  });

  static final medKind = _enumTable<MedKind>({
    'medication': MedKind.medication, 'med': MedKind.medication, 'medicine': MedKind.medication, //
    'drug': MedKind.medication, 'rx': MedKind.medication, 'prescription': MedKind.medication,
    'دواء': MedKind.medication, 'علاج': MedKind.medication,
    'supplement': MedKind.supplement, 'vitamin': MedKind.supplement, 'mineral': MedKind.supplement,
    'herbal': MedKind.supplement, 'مكمل': MedKind.supplement, 'مكملات': MedKind.supplement,
    'فيتامين': MedKind.supplement, 'معدن': MedKind.supplement,
    'injection': MedKind.injection, 'shot': MedKind.injection, 'jab': MedKind.injection, 'حقنة': MedKind.injection,
    'ابرة': MedKind.injection, 'إبرة': MedKind.injection,
    'other': MedKind.other, 'أخرى': MedKind.other,
  });

  static final severity = _enumTable<Severity>({
    'critical': Severity.critical, 'high': Severity.critical, 'danger': Severity.critical, 'severe': Severity.critical, //
    'red': Severity.critical, 'urgent': Severity.critical, 'خطير': Severity.critical, 'حرج': Severity.critical,
    'عالي': Severity.critical, 'مهم جدا': Severity.critical,
    'warning': Severity.warning, 'warn': Severity.warning, 'medium': Severity.warning, 'moderate': Severity.warning,
    'orange': Severity.warning, 'yellow': Severity.warning, 'caution': Severity.warning, 'تحذير': Severity.warning,
    'متوسط': Severity.warning, 'انتباه': Severity.warning,
    'info': Severity.info, 'low': Severity.info, 'note': Severity.info, 'blue': Severity.info, 'green': Severity.info,
    'معلومة': Severity.info, 'منخفض': Severity.info, 'ملاحظة': Severity.info,
  });

  static final txKind = _enumTable<TxKind>({
    'expense': TxKind.expense, 'expenses': TxKind.expense, 'spend': TxKind.expense, 'spent': TxKind.expense, //
    'out': TxKind.expense, 'debit': TxKind.expense, 'purchase': TxKind.expense, 'payment': TxKind.expense,
    'مصروف': TxKind.expense, 'مصاريف': TxKind.expense, 'صرف': TxKind.expense, 'شراء': TxKind.expense,
    'دفع': TxKind.expense, 'خرج': TxKind.expense,
    'income': TxKind.income, 'in': TxKind.income, 'credit': TxKind.income, 'salary': TxKind.income,
    'earning': TxKind.income, 'received': TxKind.income, 'deposit': TxKind.income, 'دخل': TxKind.income,
    'راتب': TxKind.income, 'وارد': TxKind.income, 'قبض': TxKind.income, 'إيداع': TxKind.income,
    'transfer': TxKind.transfer, 'move': TxKind.transfer, 'تحويل': TxKind.transfer, 'نقل': TxKind.transfer,
    'adjustment': TxKind.adjustment, 'adjust': TxKind.adjustment, 'correction': TxKind.adjustment,
    'تسوية': TxKind.adjustment, 'تعديل': TxKind.adjustment,
  });

  static final budgetPeriod = _enumTable<BudgetPeriod>({
    'monthly': BudgetPeriod.monthly, 'month': BudgetPeriod.monthly, 'mo': BudgetPeriod.monthly, //
    'per month': BudgetPeriod.monthly, 'm': BudgetPeriod.monthly, 'شهري': BudgetPeriod.monthly,
    'شهريا': BudgetPeriod.monthly, 'شهر': BudgetPeriod.monthly, 'بالشهر': BudgetPeriod.monthly,
    'weekly': BudgetPeriod.weekly, 'week': BudgetPeriod.weekly, 'wk': BudgetPeriod.weekly, 'w': BudgetPeriod.weekly,
    'per week': BudgetPeriod.weekly, 'أسبوعي': BudgetPeriod.weekly, 'أسبوعيا': BudgetPeriod.weekly,
    'أسبوع': BudgetPeriod.weekly, 'بالأسبوع': BudgetPeriod.weekly, 'اسبوعي': BudgetPeriod.weekly,
  });

  static final percentBase = _enumTable<PercentBase>({
    'parent': PercentBase.parent, 'of parent': PercentBase.parent, 'الأب': PercentBase.parent, //
    'من الأب': PercentBase.parent, 'الأصل': PercentBase.parent,
    'total': PercentBase.total, 'of total': PercentBase.total, 'all': PercentBase.total, 'income': PercentBase.total,
    'whole': PercentBase.total, 'الإجمالي': PercentBase.total, 'من الكل': PercentBase.total, 'الكل': PercentBase.total,
    'المجموع': PercentBase.total, 'الدخل': PercentBase.total,
  });

  static final debtDirection = _enumTable<DebtDirection>({
    'iowe': DebtDirection.iOwe, 'i owe': DebtDirection.iOwe, 'owe': DebtDirection.iOwe, 'borrowed': DebtDirection.iOwe, //
    'borrow': DebtDirection.iOwe, 'payable': DebtDirection.iOwe, 'debt': DebtDirection.iOwe, 'mine': DebtDirection.iOwe,
    'علي': DebtDirection.iOwe, 'دين علي': DebtDirection.iOwe, 'اقترضت': DebtDirection.iOwe,
    'مستحق علي': DebtDirection.iOwe, 'علي دين': DebtDirection.iOwe,
    'owedtome': DebtDirection.owedToMe, 'owed to me': DebtDirection.owedToMe, 'owed': DebtDirection.owedToMe,
    'lent': DebtDirection.owedToMe, 'lend': DebtDirection.owedToMe, 'loaned': DebtDirection.owedToMe,
    'receivable': DebtDirection.owedToMe, 'they owe': DebtDirection.owedToMe, 'owes me': DebtDirection.owedToMe,
    'لي': DebtDirection.owedToMe, 'لي عند': DebtDirection.owedToMe, 'مستحق لي': DebtDirection.owedToMe,
    'اقرضت': DebtDirection.owedToMe, 'أقرضت': DebtDirection.owedToMe, 'سلفت': DebtDirection.owedToMe,
    'مدين لي': DebtDirection.owedToMe,
  });

  static final recurrence = _enumTable<Recurrence>({
    'weekly': Recurrence.weekly, 'week': Recurrence.weekly, 'أسبوعي': Recurrence.weekly, 'أسبوعيا': Recurrence.weekly, //
    'monthly': Recurrence.monthly, 'month': Recurrence.monthly, 'شهري': Recurrence.monthly, 'شهريا': Recurrence.monthly,
    'yearly': Recurrence.yearly, 'annual': Recurrence.yearly, 'annually': Recurrence.yearly, 'year': Recurrence.yearly,
    'سنوي': Recurrence.yearly, 'سنويا': Recurrence.yearly,
  });

  static final contactChannel = _enumTable<ContactChannel>({
    'call': ContactChannel.call, 'phone': ContactChannel.call, 'voice': ContactChannel.call, 'اتصال': ContactChannel.call, //
    'مكالمة': ContactChannel.call, 'هاتف': ContactChannel.call,
    'visit': ContactChannel.visit, 'meet': ContactChannel.visit, 'meeting': ContactChannel.visit,
    'in person': ContactChannel.visit, 'زيارة': ContactChannel.visit, 'لقاء': ContactChannel.visit,
    'message': ContactChannel.message, 'text': ContactChannel.message, 'sms': ContactChannel.message,
    'whatsapp': ContactChannel.message, 'chat': ContactChannel.message, 'رسالة': ContactChannel.message,
    'واتساب': ContactChannel.message,
    'other': ContactChannel.other, 'أخرى': ContactChannel.other,
  });

  static final projectStatus = _enumTable<ProjectStatus>({
    'active': ProjectStatus.active, 'ongoing': ProjectStatus.active, 'in progress': ProjectStatus.active, //
    'open': ProjectStatus.active, 'نشط': ProjectStatus.active, 'جاري': ProjectStatus.active,
    'paused': ProjectStatus.paused, 'on hold': ProjectStatus.paused, 'hold': ProjectStatus.paused,
    'stopped': ProjectStatus.paused, 'متوقف': ProjectStatus.paused, 'معلق': ProjectStatus.paused,
    'done': ProjectStatus.done, 'complete': ProjectStatus.done, 'completed': ProjectStatus.done,
    'finished': ProjectStatus.done, 'closed': ProjectStatus.done, 'منجز': ProjectStatus.done,
    'مكتمل': ProjectStatus.done, 'منتهي': ProjectStatus.done,
  });

  static final tripStatus = _enumTable<TripStatus>({
    'planned': TripStatus.planned, 'upcoming': TripStatus.planned, 'future': TripStatus.planned, //
    'مخطط': TripStatus.planned, 'قادم': TripStatus.planned, 'قادمة': TripStatus.planned,
    'active': TripStatus.active, 'ongoing': TripStatus.active, 'current': TripStatus.active, 'now': TripStatus.active,
    'جاري': TripStatus.active, 'حالي': TripStatus.active, 'حالية': TripStatus.active,
    'done': TripStatus.done, 'past': TripStatus.done, 'completed': TripStatus.done, 'finished': TripStatus.done,
    'منتهي': TripStatus.done, 'منتهية': TripStatus.done, 'سابق': TripStatus.done, 'سابقة': TripStatus.done,
  });

  static final prayerWindow = _enumTable<PrayerWindow>({
    'fajr': PrayerWindow.fajr, 'after fajr': PrayerWindow.fajr, 'subh': PrayerWindow.fajr, 'dawn': PrayerWindow.fajr, //
    'فجر': PrayerWindow.fajr, 'بعد الفجر': PrayerWindow.fajr, 'الصبح': PrayerWindow.fajr,
    'duha': PrayerWindow.duha, 'forenoon': PrayerWindow.duha, 'morning': PrayerWindow.duha, 'ضحى': PrayerWindow.duha,
    'الضحى': PrayerWindow.duha, 'صباحا': PrayerWindow.duha,
    'dhuhr': PrayerWindow.dhuhr, 'zuhr': PrayerWindow.dhuhr, 'duhr': PrayerWindow.dhuhr, 'noon': PrayerWindow.dhuhr,
    'after dhuhr': PrayerWindow.dhuhr, 'ظهر': PrayerWindow.dhuhr, 'بعد الظهر': PrayerWindow.dhuhr,
    'asr': PrayerWindow.asr, 'after asr': PrayerWindow.asr, 'afternoon': PrayerWindow.asr, 'عصر': PrayerWindow.asr,
    'بعد العصر': PrayerWindow.asr,
    'maghrib': PrayerWindow.maghrib, 'after maghrib': PrayerWindow.maghrib, 'sunset': PrayerWindow.maghrib,
    'evening': PrayerWindow.maghrib, 'مغرب': PrayerWindow.maghrib, 'بعد المغرب': PrayerWindow.maghrib,
    'isha': PrayerWindow.isha, 'after isha': PrayerWindow.isha, 'night': PrayerWindow.isha, 'عشاء': PrayerWindow.isha,
    'بعد العشاء': PrayerWindow.isha, 'ليلا': PrayerWindow.isha,
    'anytime': PrayerWindow.anytime, 'any time': PrayerWindow.anytime, 'any': PrayerWindow.anytime,
    'أي وقت': PrayerWindow.anytime, 'في أي وقت': PrayerWindow.anytime,
  });

  static final prayer = _enumTable<Prayer>({
    'fajr': Prayer.fajr, 'subh': Prayer.fajr, 'فجر': Prayer.fajr, 'صبح': Prayer.fajr, 'الصبح': Prayer.fajr, //
    'dhuhr': Prayer.dhuhr, 'zuhr': Prayer.dhuhr, 'duhr': Prayer.dhuhr, 'ظهر': Prayer.dhuhr,
    'asr': Prayer.asr, 'عصر': Prayer.asr,
    'maghrib': Prayer.maghrib, 'مغرب': Prayer.maghrib,
    'isha': Prayer.isha, 'ishaa': Prayer.isha, 'عشاء': Prayer.isha,
    'duha': Prayer.duha, 'ضحى': Prayer.duha, 'الضحى': Prayer.duha,
    'witr': Prayer.witr, 'وتر': Prayer.witr, 'الوتر': Prayer.witr,
    'qiyam': Prayer.qiyam, 'tahajjud': Prayer.qiyam, 'qiyam al layl': Prayer.qiyam, 'قيام': Prayer.qiyam,
    'قيام الليل': Prayer.qiyam, 'تهجد': Prayer.qiyam,
    'sunnah fajr': Prayer.sunnahFajr, 'sunnahfajr': Prayer.sunnahFajr, 'سنة الفجر': Prayer.sunnahFajr,
    'sunnah dhuhr': Prayer.sunnahDhuhr, 'sunnahdhuhr': Prayer.sunnahDhuhr, 'سنة الظهر': Prayer.sunnahDhuhr,
    'sunnah maghrib': Prayer.sunnahMaghrib, 'sunnahmaghrib': Prayer.sunnahMaghrib, 'سنة المغرب': Prayer.sunnahMaghrib,
    'sunnah isha': Prayer.sunnahIsha, 'sunnahisha': Prayer.sunnahIsha, 'سنة العشاء': Prayer.sunnahIsha,
  });

  static final prayerStatus = _enumTable<PrayerStatus>({
    'prayed': PrayerStatus.prayed, 'done': PrayerStatus.prayed, 'on time': PrayerStatus.prayed, //
    'ontime': PrayerStatus.prayed, 'yes': PrayerStatus.prayed, 'true': PrayerStatus.prayed, '1': PrayerStatus.prayed,
    'صليت': PrayerStatus.prayed, 'تم': PrayerStatus.prayed, 'في وقتها': PrayerStatus.prayed, 'نعم': PrayerStatus.prayed,
    'late': PrayerStatus.late, 'delayed': PrayerStatus.late, 'متأخر': PrayerStatus.late, 'متأخرة': PrayerStatus.late,
    'missed': PrayerStatus.missed, 'no': PrayerStatus.missed, 'false': PrayerStatus.missed, '0': PrayerStatus.missed,
    'فائتة': PrayerStatus.missed, 'فاتت': PrayerStatus.missed, 'لم أصل': PrayerStatus.missed, 'لا': PrayerStatus.missed,
    'qada': PrayerStatus.qada, 'made up': PrayerStatus.qada, 'makeup': PrayerStatus.qada, 'قضاء': PrayerStatus.qada,
  });

  static final doseStatus = _enumTable<DoseStatus>({
    'taken': DoseStatus.taken, 'yes': DoseStatus.taken, 'true': DoseStatus.taken, 'done': DoseStatus.taken, //
    '1': DoseStatus.taken, 'أخذت': DoseStatus.taken, 'تم': DoseStatus.taken, 'نعم': DoseStatus.taken,
    'skipped': DoseStatus.skipped, 'skip': DoseStatus.skipped, 'تخطي': DoseStatus.skipped, 'تجاوز': DoseStatus.skipped,
    'snoozed': DoseStatus.snoozed, 'snooze': DoseStatus.snoozed, 'later': DoseStatus.snoozed, 'تأجيل': DoseStatus.snoozed,
    'missed': DoseStatus.missed, 'no': DoseStatus.missed, 'false': DoseStatus.missed, '0': DoseStatus.missed,
    'فائتة': DoseStatus.missed, 'لا': DoseStatus.missed, 'نسيت': DoseStatus.missed,
  });

  static final walletKind = _enumTable<WalletKind>({
    'personal': WalletKind.personal, 'private': WalletKind.personal, 'شخصي': WalletKind.personal, //
    'business': WalletKind.business, 'work': WalletKind.business, 'company': WalletKind.business,
    'عمل': WalletKind.business, 'تجاري': WalletKind.business, 'شركة': WalletKind.business,
  });

  /// Mood words on the 1..5 scale.
  static final moodWords = _enumTable<int>({
    'great': 5, 'excellent': 5, 'amazing': 5, 'very good': 5, 'ممتاز': 5, 'رائع': 5, 'سعيد جدا': 5, //
    'good': 4, 'happy': 4, 'fine': 4, 'جيد': 4, 'سعيد': 4, 'منيح': 4, 'كويس': 4,
    'ok': 3, 'okay': 3, 'neutral': 3, 'meh': 3, 'normal': 3, 'عادي': 3, 'متوسط': 3,
    'bad': 2, 'low': 2, 'sad': 2, 'down': 2, 'سيء': 2, 'سيئ': 2, 'حزين': 2, 'تعبان': 2,
    'awful': 1, 'terrible': 1, 'very bad': 1, 'horrible': 1, 'سيء جدا': 1, 'سيئ جدا': 1, 'حزين جدا': 1,
  });
}
