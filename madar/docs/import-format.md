# Importing the prototype export

Madar can import the JSON file exported by its HTML prototype. Because the
prototype's exact keys are not fixed, the importer is **tolerant**: it
recognises many plausible shapes and spellings (English, Arabic, camelCase,
snake_case, singular/plural), maps everything it can into Madar's tables,
turns unknown lists into custom modules and keeps everything else, verbatim,
in the import archive. **Nothing is ever lost**, and the preview says exactly
what will happen before a single row is written.

Code: `lib/core/import/` (`PrototypeImporter`), screen: `lib/features/import/`.
Test fixtures showing two very different shapes:
`test/fixtures/import/prototype_nested_en.json` and
`test/fixtures/import/prototype_flat_ar.json`.

---

## 1. Guarantees

| | |
|---|---|
| Two steps | `analyze(json)` is pure (no database writes) and returns a plan + report; `commit(db, plan)` writes it. |
| One transaction | `commit` writes every table, the settings and the archive row in a single transaction – all or nothing. |
| Never overwrites | Rows are inserted with *insert-or-ignore*: a row whose stable id (or unique key) already exists is left exactly as it is, including any edits made in Madar since. |
| Idempotent | Ids are stable (see §8), so importing the same file again adds nothing. The file's SHA-256 (of canonical JSON – key order and whitespace do not matter) is stored in `import_archive.summary.hash`; `analyze` flags a file imported before and `commit` refuses it unless `allowDuplicate: true` (the screen asks "Import anyway"). |
| Nothing lost | The whole raw file is stored in `import_archive.raw`; lists of objects nobody claims become custom modules; every other unmapped value is listed in the report and in `import_archive.summary.leftovers`. |

---

## 2. Accepted shapes

All of these are recognised, and may be mixed within one file.

### 2.1 Containers

```jsonc
{"data": {...}, "logs": {...}}          // the prototype's export ("data + logs")
{"data": {...}}                         // data only
{"logs": {...}}  or  {"logs": [...]}    // logs only
{"meds": [...], "budget": {...}}        // plain sections at the top level
[{"type": "pain", ...}, ...]            // a bare array of typed records
```

Data containers: `data`, `state`, `store`, `db`, `database`, `payload`,
`content`, `بيانات`. Log containers: `logs`, `log`, `history`, `journal`,
`daily`, `dailyLogs`, `days`, `entries`, `سجل`, `سجلات`, `يوميات`.
Export metadata (`version`, `schemaVersion`, `exportedAt`, `app`, `source`,
`timestamp`, `الإصدار`, `تاريخ التصدير` …) is shown in the report and kept.

### 2.2 Grouped by area (nested by domain)

Sections may sit inside area objects at any depth:

```json
{"data": {"health": {"meds": [...], "labs": [...]}, "money": {"budget": {...}}}}
```

Area keys (they also set the planet of generated modules): `health`,
`medical`, `wellness`, `صحة`, `money`, `finance`, `مال`, `مالية`, `family`,
`social`, `عائلة`, `work`, `career`, `business`, `عمل`, `growth`,
`learning`, `نمو`, `تعلم`, `body`, `fitness`, `جسد`, `لياقة`, `travel`, `سفر`,
`faith`, `worship`, `إيمان`, `عبادة`, `home`, `life` … Any other object is
walked into as well, so `data.settings.rates` or `data.x.y.meds` are found.

### 2.3 Collections

Every section accepts:

```jsonc
"meds": [{"id": "m1", "name": "Vitamin D"}, ...]          // array of objects
"meds": {"m1": {"name": "Vitamin D"}, "m2": {...}}         // keyed by id (the key becomes the source id)
"labs": {"HbA1c": {"unit": "%", "readings": [...]}}        // keyed by name (the key becomes the name)
"avoid": ["Heavy lifting", "Running on concrete"]          // array of strings (the text field)
"meds": {"morning": [{"name": "A"}], "bedtime": ["B"]}     // grouped: the group key is kept as a hint
"budget": {"items": [...], "weeksPerMonth": 4}             // generic container + section settings
```

Generic container keys: `items`, `list`, `entries`, `records`, `rows`,
`data`, `values`, `all`, `عناصر`, `قائمة`, `بيانات`. Group hints are used
where they mean something: medication slot (`morning` → 08:00,
`bedtime` → taken at bedtime), person relation, lab/habit category, trip
item category, task prayer window.

### 2.4 Logs keyed by day

```json
"logs": {
  "2026-09-01": {"pain": 4, "mood": 3, "stress": 6, "sleep": 7, "water": 8,
                 "prayers": {"fajr": true, "dhuhr": "late"}, "notes": "Long day"},
  "2026-09-02": {"pain": {"score": 2, "location": "neck"}, "mood": "good"}
}
```

Any map whose keys are dates is read this way, at any level
(`"water": {"2026-09-01": 6}`, `"history": {"2026-02-01": 22}` inside a lab
test, `"log": {"2026-08-30": true}` inside a habit). Mood-type scalars of one
day (`mood`, `stress`, `anxiety`, `energy`, `sleep`, `caffeine`, plus a day
note) merge into **one** mood entry. Prayer names directly inside a day
(`"fajr": true`) are prayer-log rows.

### 2.5 Log variants

Under a log container or a day, definition sections become their log table:
`meds` → dose log, `labs` → lab readings, `habits` → habit log, `people` →
contact log, `goals` → goal log, `exercises`/`workouts` → workout log, `jars`
→ jar deposits, `debts` → debt payments. A dated record under `workouts` in
`data` is also treated as a workout log (and its exercise is created by name).

### 2.6 Typed event lists

```json
"logs": [{"type": "pain", "date": "2026-01-01", "score": 3},
         {"type": "water", "date": "2026-01-01", "ml": 500},
         {"kind": "expense", "date": "2026-01-02", "amount": 7}]
```

A list is dispatched by type when at least 60 % of its objects carry a
`type` / `kind` / `section` / `event` / `module` / `entity` / `table` /
`نوع` whose value is a section alias.

### 2.7 Nested children

Children can be nested inside their parent **or** kept in a flat list that
references the parent by id or by name – both work, even in the same file.

| Parent | Child table | Keys inside the parent record |
|---|---|---|
| `labTests` | `labReadings` | `readings`, `values`, `history`, `results`, `log`, `logs`, `entries`, `measurements`, `data`, `قراءات`, `نتائج`, `سجل`, `قيم` |
| `medications` | `medDoses` | `doses`, `log`, `logs`, `history`, `intake`, `جرعات`, `سجل` |
| `habits` | `habitLogs` | `log`, `logs`, `history`, `days`, `dates`, `checks`, `checkins`, `completed`, `completions`, `doneDates`, `record`, `سجل`, `أيام` |
| `people` | `contactLogs` | `contacts`, `contactLog`, `log`, `logs`, `history`, `calls`, `interactions`, `سجل`, `تواصل` |
| `projects` | `projectItems` | `items`, `tasks`, `todos`, `steps`, `milestones`, `checklist`, `subtasks`, `مهام`, `خطوات`, `مراحل`, `عناصر` |
| `boards` | `boardCards` | `cards`, `tasks`, `items`, `todos`, `مهام`, `بطاقات` |
| `trips` | `tripItems` | `items`, `packing`, `packingList`, `checklist`, `todo`, `تجهيز`, `قائمة`, `أغراض` |
| `learningGoals` | `goalLogs` | `log`, `logs`, `history`, `sessions`, `entries`, `سجل` |
| `exercises` | `workoutLogs` | `log`, `logs`, `history`, `sessions`, `سجل` |
| `jars` | `jarDeposits` | `deposits`, `history`, `log`, `transactions`, `entries`, `إيداعات`, `سجل` |
| `debts` | `debtPayments` | `payments`, `repayments`, `history`, `log`, `دفعات`, `سداد` |
| `budgetItems` | `budgetItems` | `children`, `items`, `sub`, `subs`, `subItems`, `subcategories`, `categories`, `lines`, `بنود`, `فرعية`, `تفرعات`, `عناصر` |
| `wallets` | `transactions` | `transactions`, `history`, `entries`, `txns`, `حركات`, `معاملات` |
| `appointments` | `doctorQuestions` | `questions`, `أسئلة` |

Kanban cards may also be listed under column keys of a board
(`"todo": [...]`, `"doing": [...]`, `"done": [...]`, Arabic `جديد`, `قيد
التنفيذ`, `منجز`, `للعمل` …) or in `"columns": [{"id", "label", "cards": [...]}]`.
Boards keyed by country (`"work": {"Jordan": [cards…], "Egypt": {"todo": [...]}}`)
become one board per key. A budget item's unknown keys whose value is an
amount or an object are its children (`{"Home food": {"amount": 200,
"Proteins": 100, "Spices": 20}}`).

---

## 3. How keys are matched

Every key and alias is normalised before comparison (`ImportText.key`):
Arabic-Indic digits folded, lower-cased, every separator removed
(`taken_with` = `takenWith` = `Taken With`), Arabic diacritics and tatweel
removed, `أ إ آ ٱ` → `ا`, `ة` → `ه`, `ى` → `ي`, `ؤ` → `و`, `ئ` → `ي`, and a
leading article `ال` dropped (`الميزانية` = `ميزانية`). Section keys may also
carry a plural `s` or a `List`/`Data`/`Items`/`Entries`/`Records`/`Tracker`
suffix (`habitsList`, `painData`); `…Log` spellings are listed explicitly.

## 4. Section aliases

| Madar table | Keys (any case / `_` / `-` / spaces; plural `s` optional) |
|---|---|
| `healthAlerts` | `alerts`, `alert`, `healthAlerts`, `criticalAlerts`, `medicalAlerts`, `healthWarnings`, `redFlags`, `تنبيهات`, `تنبيهات صحية`, `تحذيرات`, `تحذيرات صحية`, `تنبيه` |
| `conditions` | `conditions`, `condition`, `diagnoses`, `diagnosis`, `diseases`, `illnesses`, `chronic`, `chronicConditions`, `medicalHistory`, `أمراض`, `حالات`, `حالات صحية`, `تشخيصات`, `تشخيص`, `أمراض مزمنة` |
| `medications` | `meds`, `med`, `medications`, `medication`, `medicines`, `medicine`, `drugs`, `pills`, `medsList`, `prescriptions`, `supplements` → *supplement*, `supplement` → *supplement*, `vitamins` → *supplement*, `أدوية`, `دواء`, `علاج`, `علاجات`, `مكملات` → *supplement*, `مكملات غذائية` → *supplement*, `فيتامينات` → *supplement* |
| `medDoses` | `doses`, `doseLog`, `doseLogs`, `medLog`, `medLogs`, `medsLog`, `medicationLog`, `medicationLogs`, `intake`, `intakeLog`, `takenLog`, `pillLog`, `جرعات`, `سجل الأدوية`, `سجل الجرعات` |
| `labTests` | `labs`, `lab`, `labTests`, `labTest`, `tests`, `bloodTests`, `bloodwork`, `analyses`, `labPanel`, `labPanels`, `تحاليل`, `تحليل`, `فحوصات`, `مختبر`, `تحاليل طبية` |
| `labReadings` | `readings`, `labReadings`, `labResults`, `results`, `labLog`, `labLogs`, `labHistory`, `testResults`, `نتائج`, `قراءات`, `نتائج التحاليل` |
| `appointments` | `appointments`, `appointment`, `visits`, `doctorVisits`, `appts`, `مواعيد`, `مواعيد الطبيب`, `زيارات`, `موعد` |
| `doctorQuestions` | `questions`, `doctorQuestions`, `questionsForDoctor`, `askDoctor`, `أسئلة`, `أسئلة للطبيب`, `أسئلة الطبيب` |
| `painEntries` | `pain`, `pains`, `painLog`, `painLogs`, `painEntries`, `painJournal`, `painDiary`, `ألم`, `آلام`, `سجل الألم` |
| `moodEntries` | `mood`, `moods`, `moodLog`, `moodLogs`, `moodEntries`, `feelings`, `wellbeing`, `checkins`, `stress` → *stress*, `stressLog` → *stress*, `stressLogs` → *stress*, `stressLevel` → *stress*, `anxiety` → *anxiety*, `energy` → *energy*, `sleep` → *sleep*, `sleepLog` → *sleep*, `sleepHours` → *sleep*, `caffeine` → *caffeine*, `coffee` → *caffeine*, `مزاج`, `سجل المزاج`, `مشاعر`, `توتر` → *stress*, `ضغط نفسي` → *stress*, `قلق` → *anxiety*, `طاقة` → *energy*, `نوم` → *sleep*, `ساعات النوم` → *sleep*, `قهوة` → *caffeine*, `كافيين` → *caffeine* |
| `habits` | `habits`, `habit`, `habitList`, `routines`, `عادات`, `روتين`, `عادات يومية` |
| `habitLogs` | `habitLog`, `habitLogs`, `habitChecks`, `habitHistory`, `سجل العادات` |
| `worries` | `worries`, `worry`, `worryList`, `worryWindow`, `parkedWorries`, `concerns`, `مخاوف`, `هموم`, `همومي`, `مخاوفي` |
| `currencies` | `currencies`, `rates`, `exchangeRates`, `fx`, `fxRates`, `currencyRates`, `عملات`, `أسعار الصرف`, `سعر الصرف` |
| `wallets` | `wallets`, `wallet`, `accounts`, `account`, `محافظ`, `محفظة`, `حسابات`, `حساب` |
| `budgetItems` | `budget`, `budgets`, `budgetItems`, `budgetTree`, `categories`, `budgetCategories`, `envelopes`, `ميزانية`, `بنود الميزانية`, `فئات`, `تصنيفات` |
| `transactions` | `transactions`, `transaction`, `txns`, `txs`, `ledger`, `spending`, `purchases`, `moneyLog`, `expenses` → *expense*, `expense` → *expense*, `income` → *income*, `incomes` → *income*, `earnings` → *income*, `معاملات`, `حركات`, `مصاريف` → *expense*, `مصروفات` → *expense*, `نفقات` → *expense*, `دخل` → *income*, `مدخول` → *income* |
| `jars` | `jars`, `jar`, `savings`, `savingsJars`, `savingJars`, `piggyBanks`, `funds`, `sinkingFunds`, `حصالات`, `حصالة`, `ادخار`, `مدخرات`, `توفير` |
| `jarDeposits` | `deposits`, `jarDeposits`, `savingsLog`, `إيداعات` |
| `debts` | `debts`, `debt`, `loans`, `loan`, `ious`, `iou`, `ديون`, `قروض`, `سلف`, `ديون وقروض` |
| `debtPayments` | `debtPayments`, `repayments`, `تسديدات`, `سداد` |
| `obligations` | `obligations`, `recurring`, `recurringPayments`, `bills`, `subscriptions`, `fixedExpenses`, `fixedCosts`, `commitments`, `التزامات`, `فواتير`, `اشتراكات`, `مصاريف ثابتة`, `دفعات دورية` |
| `people` | `people`, `persons`, `contacts`, `family`, `friends`, `relatives`, `circle`, `network`, `loved ones`, `أشخاص`, `عائلة`, `أهل`, `أقارب`, `أصدقاء`, `جهات اتصال`, `ناس` |
| `contactLogs` | `contactLog`, `contactLogs`, `callLog`, `calls`, `interactions`, `contactHistory`, `سجل التواصل`, `تواصل`, `مكالمات` |
| `projects` | `projects`, `project`, `مشاريع`, `مشروع` |
| `projectItems` | `projectItems`, `milestones`, `projectTasks`, `مراحل` |
| `boards` | `boards`, `board`, `work`, `kanban`, `kanbans`, `business`, `businesses`, `countries`, `workBoards`, `عمل`, `لوحات`, `أعمال`, `كانبان` |
| `boardCards` | `cards`, `boardCards`, `workTasks`, `kanbanCards`, `بطاقات` |
| `trips` | `trips`, `trip`, `travel`, `travels`, `journeys`, `سفر`, `رحلات`, `رحلة`, `أسفار` |
| `tripItems` | `packing`, `packingList`, `tripItems`, `تجهيز`, `قائمة التجهيز`, `حقيبة السفر` |
| `travelDocuments` | `documents`, `docs`, `travelDocuments`, `passports`, `visas`, `papers`, `وثائق`, `مستندات`, `جوازات`, `أوراق` |
| `learningGoals` | `goals`, `goal`, `learning`, `learningGoals`, `studies`, `courses`, `أهداف`, `هدف`, `تعلم`, `دراسة` |
| `goalLogs` | `goalLogs`, `goalLog`, `progressLog`, `learningLog`, `studyLog`, `سجل التعلم` |
| `exercises` | `exercises`, `exercise`, `workouts`, `workout`, `gym`, `training`, `fitness`, `تمارين`, `رياضة`, `جيم`, `تمرين` |
| `workoutLogs` | `workoutLog`, `workoutLogs`, `gymLog`, `trainingLog`, `exerciseLog`, `exerciseLogs`, `سجل التمارين` |
| `avoidItems` | `avoid`, `avoidList`, `avoidItems`, `avoids`, `donts`, `doNot`, `forbidden`, `restrictions`, `ممنوعات`, `ممنوع`, `تجنب`, `تجنبات`, `محظورات` |
| `fastingSessions` | `fasting`, `fasts`, `fastingLog`, `fastingSessions`, `fastLog`, `صيام`, `صوم` |
| `waterLogs` | `water`, `waterLog`, `waterLogs`, `hydration`, `waterIntake`, `ماء`, `مياه`, `شرب الماء`, `سجل الماء` |
| `prayerLogs` | `prayers`, `prayer`, `prayerLog`, `prayerLogs`, `salah`, `salat`, `namaz`, `صلاة`, `صلوات`, `سجل الصلاة` |
| `tasks` | `tasks`, `task`, `todos`, `todo`, `toDoList`, `dayPlan`, `agenda`, `windows` → *windows*, `prayerWindows` → *windows*, `مهام`, `مهمة`, `واجبات`, `خطة اليوم`, `أوقات الصلاة` → *windows* |

A hint after `→` changes the default of that table (e.g. `supplements` →
medication kind *supplement*; `expenses`/`income` → transaction kind;
`stress`/`sleep` → which mood column a bare `value` fills; `windows` →
tasks grouped by prayer window).

## 5. Field aliases (columns)

Only the most important columns are listed; the full lists live in
`lib/core/import/import_mapper.dart` and `import_aliases.dart`.

| Column | Accepted keys |
|---|---|
| id (any table) | `id`, `_id`, `uid`, `uuid`, `key`, `ref`, `معرف` |
| name / title | `name`, `title`, `label`, `text`, `اسم`, `عنوان` (+ `body`, `message`, `question`, `destination`, `person` where fitting) |
| notes | `notes`, `note`, `comment(s)`, `description`, `desc`, `details`, `memo`, `ملاحظات`, `ملاحظة`, `وصف`, `تفاصيل` |
| date / time of a log | `date`, `at`, `datetime`, `timestamp`, `ts`, `day`, `when`, `on`, `loggedAt`, `createdAt`, `time`, `تاريخ`, `يوم`, `وقت` (a separate `time`/`hour`/`ساعة` clock is combined with a date-only value; a log inside a day uses that day) |
| medication dose | `dose`, `dosage`, `strength`, `amount`, `جرعة`, `عيار` (+ `doseAmount`/`quantity`, `doseUnit`/`unit`; `"10 mg"` is split into 10 + mg) |
| medication times | `times`, `time`, `schedule`, `hours`, `at`, `when`, `slots`, `doseTimes`, `مواعيد`, `أوقات`, `وقت` – string `"08:00, 20:00"`, `"8am و 8pm"`, array, numbers, or `[{"time": …}]` |
| taken with | `takenWith`, `with`, `timing`, `take`, `instructions`, `meal`, `food`, `how`, `مع`, `التوقيت`, `طريقة`, `تعليمات` (non-exact wording is kept in `takenWithNote`) |
| medication kind / stock | `kind`, `type`, `category`, `form`, `نوع`; `stock`, `count`, `remaining`, `left`, `pills`, `المتبقي`; `refillAt`, `refill`, `reorder` |
| dose status | `status`, `taken`, `done`, `state`, `حالة` (boolean or word; default *taken*) + `scheduledAt`, `takenAt` |
| lab range | `low`/`min`/`refLow`/`lower`/`minimum`/`الأدنى`, `high`/`max`/`refHigh`/`upper`/`الأعلى`, or `range`/`ref`/`reference`/`normal`/`normalRange`/`المعدل الطبيعي` as `"3.5-5"`, `"< 5.7"`, `"> 40"`, `[lo, hi]`, `{low, high}` |
| lab unit / category | `unit`, `units`, `uom`, `وحدة`; `category`, `group`, `panel`, `فئة` |
| reading value | `value`, `result`, `reading`, `val`, `level`, `amount`, `قيمة`, `النتيجة` (numbers → `value`, words such as "negative" → `valueText`) |
| reading's test | nested, or `test`, `testId`, `testName`, `lab`, `analysis`, `marker`, `name`, `تحليل`, `فحص`; a missing test is created by name. Panels `{"date": …, "values": {"HbA1c": 5.4, "LDL": 120}}` fan out into one reading per test |
| pain | `score`/`pain`/`level`/`value`/`intensity`/`severity`/`rating`/`شدة`/`درجة`; `locations`/`location`/`where`/`area`/`site`/`bodyPart`/`مكان`/`موضع`; `triggers`/`trigger`/`cause`/`reason`/`محفز`/`سبب` |
| mood | `mood`/`feeling`/`مزاج` (1–5 or words: great/good/ok/bad/awful, ممتاز/جيد/عادي/سيء), `stress`/`توتر`/`ضغط`, `anxiety`/`قلق`, `energy`/`طاقة`, `sleep`/`sleepHours`/`نوم`, `caffeine`/`coffee`/`قهوة`, `factors`/`tags`/`عوامل` |
| amount (money) | `amount`, `value`, `sum`, `total`, `price`, `cost`, `planned`, `limit`, `budget`, `مبلغ`, `قيمة`, `السعر` |
| currency | `currency`, `cur`, `ccy`, `currencyCode`, `عملة` (or written in the amount: `"200 JOD"`, `"$12"`, `"١٢٫٥ د.أ"`, `"300 ج.م"`) |
| budget percent | `percent`, `pct`, `%`, `percentage`, `share`, `ratio`, `نسبة`, or an amount written `"50%"`; base `percentOf`/`of`/`base`/`من`: `parent`/`total` (default: parent for children, total for roots) |
| budget parent | nested (`children`, `items`, `sub`, `subcategories`, `بنود`, `فرعية`) or `parent`, `parentId`, `parentName`, `group`, `under`, `الأب`, `تابع`, `ضمن` (id or name) |
| budget period | `period`, `per`, `frequency`, `cycle`, `every`, `الفترة`, `دورة`: `weekly`/`week`/`أسبوعي`, `monthly`/`شهري`; also `weekly: true` or an amount such as `"5/week"`, `"5 per week"`, `"5 أسبوعيًا"` |
| transaction | kind `type`/`kind`/`direction`/`نوع` (expense/income/transfer/adjustment, مصروف/دخل/تحويل/تسوية – without one: negative = expense, and in a signed ledger positive = income); wallet `wallet`/`walletId`/`account`/`from`/`محفظة`/`حساب`; category `category`/`budget`/`budgetItem`/`envelope`/`item`/`بند`/`فئة` (id or name; unknown ones become a tag); `toWallet`/`to`, `toAmount`; note `note`/`description`/`payee`/`merchant`/`البيان` |
| wallet | `currency`; opening `opening`/`openingBalance`/`initial`/`start`/`رصيد افتتاحي`; or `balance`/`current`/`رصيد` = balance **after** the file's transactions (opening = balance − their net) |
| jar | `target`/`goal`/`targetAmount`/`هدف`; `saved`/`current`/`balance`/`progress`/`المدخر` (becomes an "Opening balance" deposit when there are no deposits); `deadline`/`due`/`by` |
| debt | person `person`/`name`/`who`/`with`/`شخص`; direction `direction`/`type`/`side`: *i owe*/owe/borrowed/علي/اقترضت, *owed to me*/lent/لي/أقرضت; `settled`/`paid` or `settledAt`; `dueDate`/`due` |
| obligation | `frequency`/`period`/`recurrence`/`repeat`/`تكرار` (weekly/monthly/yearly); `nextDue`/`due`/`dueDate`/`next`, or `dayOfMonth`/`day`/`يوم` (next occurrence); `interval` |
| person | `relation`/`relationship`/`role`/`صلة القرابة`; rhythm `rhythmDays`/`rhythm`/`every`/`everyDays`/`contactEvery`/`frequency`/`التواصل كل` (days, or daily/weekly/biweekly/monthly/yearly); `lastContact`/`آخر تواصل`; `phone`/`mobile`/`هاتف`/`جوال`; `birthday`/`dob`/`تاريخ الميلاد` |
| contact log | `channel`/`type`/`via`/`how`/`method`: call/visit/message (اتصال/زيارة/رسالة/واتساب) |
| card | column `column`/`status`/`stage`/`list`/`state`/`lane`/`عمود`/`حالة` (todo/doing/done synonyms, other names become extra columns); `assignee`/`owner`; `due`; `top3`/`focus`/`important`; `window` (prayer window) |
| trip | `destination`/`place`/`city`/`to`/`وجهة`; `start`/`startDate`/`from`/`departure`/`ذهاب`; `end`/`endDate`/`return`/`until`/`عودة`; `lat`/`lng`; status planned/active/done (derived from the dates when absent) |
| travel document | `name`/`type`/`document`; `holder`; `number`; `expiry`/`expires`/`validUntil`/`تاريخ الانتهاء`; `remindDaysBefore` |
| learning goal | `target`/`goal`/`total`/`هدف`; `unit`; `initial`/`start`, or `current`/`progress`/`done` (= initial + Σ logs); `deadline`. Logs: `amount`/`value`/`progress`/`pages`/`minutes` |
| exercise | `weekdays`/`days`/`schedule`/`أيام` (names in English/Arabic, ISO 1–7, or JavaScript 0–6 when a 0 appears); `sets`, `reps`, `duration`/`minutes`/`مدة`, `weight`/`kg`/`وزن` |
| fasting | `start`/`from`/`date`, `end`/`to`, `targetHours`/`target`/`hours` (default: the duration, else 16 h – reported) |
| water | `ml`/`amount`/`volume`/`value`; `glasses`/`cups`/`أكواب` (×250 ml); `liters`/`لتر` (×1000); `"1.5 L"`, `"3 glasses"`; a bare number ≤ 20 is read as glasses (reported) |
| prayer log | `prayer`/`name`/`salah`/`صلاة` + `status`/`done`/`prayed`/`حالة`, or one key per prayer (`{"date": …, "fajr": true, "dhuhr": "late"}`); `jamaah`/`congregation`/`جماعة`; `mosque`/`مسجد` |
| task | `window`/`prayerWindow`/`slot`/`after`/`وقت`/`بعد` (or listed under a window key); `date`/`due`; `done`; `priority` (number or high/medium/low); `top3`; `planet`/`area`; `project`, `card` |
| colour / icon | `color`/`colour`/`لون` (ARGB int or `#RRGGBB`), `icon`/`emoji` |

## 6. Value formats

**Dates** – ISO 8601 (`2026-01-10`, `2026-01-10T08:30`, `…Z` → local time),
epoch milliseconds or seconds (numbers or digit strings), `yyyyMMdd`,
`yyyy/MM/dd`, `dd/MM/yyyy`, `dd-MM-yy`, `dd.MM.yyyy` (day first; `MM/dd` only
when the second part is > 12), month names in English and Arabic
(`10 Jan 2026`, `١٠ يناير ٢٠٢٦`, `10 كانون الثاني 2026`), each optionally
followed by a clock time. Arabic-Indic and Persian digits everywhere.

**Clock times** – `08:00`, `8`, `8:30 pm`, `٨:٣٠ م` (ص = am, م = pm),
`20h`, `0830`, `20.5` (= 20:30); several separated by `,` `،` `;` `|` `/` `+`
`and` `و` or spaces. Words become default times and are reported:
morning/breakfast/صباحًا → 08:00, noon/ظهرًا → 12:00, lunch/غداء → 13:00,
afternoon/عصرًا → 16:00, evening/dinner/مساءً → 19:00, night/bedtime/قبل
النوم → 22:00.

**Numbers and money** – numbers, or text such as `1,234.5`, `1٬234٫5`,
`١٢٫٥`, `1.234,5`, `(12.50)` (negative), with an optional currency code,
sign or Arabic name. Money is stored in **milli-units** (amount × 1000) with
exact integer arithmetic and one half-up rounding; see
`lib/core/domain/money.dart`.

**Booleans** – `true/false`, `1/0`, `yes/no`, `done`, `✓/✗`, `نعم/لا`, `تم`.

**Enum words** (English and Arabic, matched as whole words):

| Column | Values |
|---|---|
| taken with | *empty stomach* (empty stomach, fasting, before food/breakfast, على الريق, معدة فارغة, قبل الأكل), *breakfast* (with/after breakfast, مع/بعد الفطور), *lunch* (غداء), *dinner* (supper, مع/بعد العشاء), *bedtime* (before bed/sleep, night, قبل/عند النوم), *per course* (as prescribed, حسب الكورس), *anytime* (any time, أي وقت), *other* |
| severity | *critical* (high, danger, severe, red, urgent, خطير, حرج), *warning* (medium, moderate, orange, caution, تحذير, متوسط), *info* (low, note, معلومة, منخفض) |
| prayer | fajr/subh/الفجر/الصبح, dhuhr/zuhr/الظهر, asr/العصر, maghrib/المغرب, isha/العشاء, duha/الضحى, witr/الوتر, qiyam/tahajjud/قيام الليل, sunnah fajr/سنة الفجر … |
| prayer status | *prayed* (true, done, on time, صليت, تم), *late* (delayed, متأخرة), *missed* (false, no, فائتة, لم أصل), *qada* (made up, قضاء); a status mentioning jamaah/جماعة or mosque/مسجد also sets those flags |
| prayer window | after fajr/بعد الفجر, duha/morning/الضحى, dhuhr/noon/الظهر, asr/afternoon/العصر, maghrib/evening/المغرب, isha/night/العشاء, anytime/أي وقت |
| project / trip status | active/ongoing/نشط/جاري, paused/on hold/متوقف, done/completed/منجز/مكتمل; planned/upcoming/قادم, active/current/حالي, done/past/منتهية |
| wallet kind | personal/شخصي, business/work/company/تجاري/عمل |

## 7. Budget

Each item is set by an **amount** (in its own period and currency) or by a
**percent** of its parent or of the whole budget; the other value is derived
by `BudgetMath` (`lib/core/domain/budget_math.dart`). Weekly items convert
with the configurable weeks-per-month (`weeksPerMonth`, default 4; e.g.
4.345): 5/week = 20.000 at 4 and 21.725 at 4.345. A parent without its own
amount is the sum of its children. The preview shows the monthly total and
every check (children under/over their parent, percents over 100 %,
circular percents, broken parents, missing rates). A `weeksPerMonth` found in
the file is stored under the key `money.budget.weeksPerMonth` (only when not
set yet).

```jsonc
"budget": {"weeksPerMonth": 4, "items": [
  {"name": "Home food", "amount": 200, "children": [
    {"name": "Proteins", "amount": 100}, {"name": "Spices", "amount": 20},
    {"name": "Treats", "amount": 30}, {"name": "Fruit & vegetables", "amount": 50}]},
  {"name": "Car fuel", "amount": 100},
  {"name": "Emergency", "amount": "30 JOD"},
  {"name": "Wife's allowance", "amount": 5, "period": "weekly"}]}
// the same, as nested maps:
"الميزانية": {"طعام البيت": {"المبلغ": 200, "بروتينات": 100, "بهارات": 20, "حلويات": 30, "خضار وفواكه": 50},
              "بنزين السيارة": 100, "طوارئ": "30", "مصروف الزوجة": "5 أسبوعيًا"}
```

Both give a monthly total of 350.000 with *Proteins* = 50 % of *Home food*.

## 8. Currencies and wallets

* Amounts without a currency use the file's `baseCurrency` (settings keys
  `baseCurrency`, `base`, `mainCurrency`, `defaultCurrency`, `currency`,
  `العملة الأساسية`) or else the database's base currency.
* Rates: `"rates"` / `"exchangeRates"` / `"currencies"` as
  `{"USD": 0.709}` or `[{"code": "USD", "rate": 0.709}]` (1 unit = rate
  base units). Missing currencies are added with the file's rate, or with 1
  and a *missing rate* warning. The file's rates replace the seeded
  placeholder rates only while the user has never set a rate.
* Nothing is ever converted silently: a transaction in another currency than
  its wallet goes to a companion wallet "‹wallet› · USD"; transactions without
  a wallet go to a "Main wallet" per currency (names are localised).

## 9. Ids and references

* A record with a source id (`id`, `_id`, … or its key in an id-keyed map)
  gets the id `imp.<table>.<source id>` – e.g. `imp.medications.m1`. A second
  record with the same source id in the same table gets a `~2` suffix (and a
  warning).
* A record without one gets `imp.<table>.<fingerprint>`: a SHA-256 of the
  table, its parent and its **name** for things (medications, tests, people,
  budget items …), or of its **content** for log entries – stable across
  re-imports.
* References are remapped consistently: reading → test, dose → medication,
  card → board, item → project/trip, log → habit/goal/exercise/person,
  transaction → wallet/budget item, question → appointment, entry → module.
  Flat lists may reference by source id **or by name**; a reading, dose,
  habit log, contact log, project item or goal log that names a missing
  parent creates it by name (reported as *created*).

## 10. What happens to unknown data

* **Lists of objects** under a key no section claims become a **custom
  module** named after the key (`readingList` → "Reading list",
  `قائمة_الكتب` → "قائمة الكتب") with one entry per object. Field types are
  inferred per key: `checkbox` (booleans / yes-no), `number`, `rating`
  (whole numbers 0–10 under rating/stars/score/تقييم), `date`, `time`
  (`HH:mm`), `multiSelect` (lists of words, options collected), `text`
  (anything else; objects as JSON). A date-like key becomes the entry date
  (tracker module, with a line chart of the first number field), a
  done/completed/finished/تم key becomes the entry's done flag; every field
  keeps its original key as `sourceKey`.
* **Scalars, lists of scalars and empty lists** that nothing claims are
  listed in the report ("Kept in the archive") and stored in
  `import_archive.summary.leftovers` (path → value).
* **Record fields** a table has no column for are listed with their count.
* The **complete original file** is always stored in `import_archive.raw`.

## 11. The report

`ImportReport` (shown by the import screen, stored in the archive summary):
detected shape (container, key style, domains, day-keyed logs, typed events,
id-keyed maps, export metadata), rows per table (planned / written / already
present / skipped), the budget total, generated modules, unmapped values and
issues:

| Code | Meaning |
|---|---|
| `invalidJson`, `emptyInput`, `notAnObject` | Nothing could be analysed. |
| `unparsedDate` / `unparsedAmount` / `unparsedTime` / `unparsedNumber` | A value could not be read (the raw value is in `detail`). |
| `inferredTime` | A word became a default clock time. |
| `missingRequired` | A row lacked a required value and was not imported (it stays in the archive). |
| `unresolvedReference` | A reference pointed nowhere (e.g. an unknown budget category – kept as a transaction tag). |
| `createdReference` | A referenced parent was created by name. |
| `unknownValue` | An enum word was not recognised; the default was used. |
| `assumedGlasses`, `assumedFastingTarget`, `assumedDate`, `assumedValue` | A missing or ambiguous value was assumed (glasses of water, fasting target, a bill's next due date, a goal target). |
| `currencyWallet` | A companion wallet was created for another currency. |
| `missingRate` | A currency was added with rate 1. |
| `duplicateSourceId` | Two records shared a source id. |
| `budget` | A `BudgetMath` check (`args`: kind, name, milli, percent, currency). |
| `duplicateFile` | The same file was imported before. |
| `settingRead` | A setting was read (weeks per month, base currency, rates). |

## 12. For developers

```dart
final importer = PrototypeImporter(labels: ImportLabels.of(L10n.of(context)));
final plan = await PrototypeImporter.analyzeFor(db, json, labels: labels, fileName: name);
// or, fully pure: importer.analyze(json, knownImports: await PrototypeImporter.knownImports(db));
print(plan.report.count(ImportSection.labReadings));
print(plan.budget.totalMonthlyMilli);
final report = await importer.commit(db, plan, allowDuplicate: false, onProgress: print);
```

When adding an alias, add it to `import_aliases.dart` (or the column list in
`import_mapper.dart`), extend a fixture and a test, and update this file.
