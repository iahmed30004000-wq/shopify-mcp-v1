/// Three sample entries that prove the shape of the guide, and the resolver
/// that reads their text from the generated localisations. The real content
/// of every screen is authored later by adding specs (and ARB keys) beside
/// these.
library;

import '../../../core/i18n/gen/app_localizations.dart';
import 'guide_entry.dart';

abstract final class GuideSamples {
  static const GuideEntrySpec today = GuideEntrySpec(
    id: 'today',
    titleKey: 'guideTodayTitle',
    purposeKey: 'guideTodayPurpose',
    exampleKey: 'guideTodayExample',
    doKeys: ['guideTodayDo1', 'guideTodayDo2', 'guideTodayDo3'],
    relatedIds: ['add.expense', 'planet.faith'],
    keywordsKey: 'guideTodayKeywords',
    tourId: 'today',
  );

  static const GuideEntrySpec faith = GuideEntrySpec(
    id: 'planet.faith',
    titleKey: 'guideFaithTitle',
    purposeKey: 'guideFaithPurpose',
    exampleKey: 'guideFaithExample',
    doKeys: ['guideFaithDo1', 'guideFaithDo2', 'guideFaithDo3'],
    relatedIds: ['today'],
    keywordsKey: 'guideFaithKeywords',
  );

  static const GuideEntrySpec addExpense = GuideEntrySpec(
    id: 'add.expense',
    titleKey: 'guideExpenseTitle',
    purposeKey: 'guideExpensePurpose',
    exampleKey: 'guideExpenseExample',
    doKeys: ['guideExpenseDo1', 'guideExpenseDo2', 'guideExpenseDo3'],
    relatedIds: ['today'],
    keywordsKey: 'guideExpenseKeywords',
  );

  static const List<GuideEntrySpec> all = [today, faith, addExpense];

  static GuideRegistry registry() => GuideRegistry(all);
}

/// Reads guide text from the generated localisations by ARB key. The
/// generated class has no lookup by name, so every key a spec uses is listed
/// here; the integrator adds a line per new key (a test fails on a spec key
/// missing from this map, so nothing ships blank).
GuideTextResolver guideResolverFor(L10n l10n) {
  final texts = <String, String>{
    'guideTodayTitle': l10n.guideTodayTitle,
    'guideTodayPurpose': l10n.guideTodayPurpose,
    'guideTodayExample': l10n.guideTodayExample,
    'guideTodayDo1': l10n.guideTodayDo1,
    'guideTodayDo2': l10n.guideTodayDo2,
    'guideTodayDo3': l10n.guideTodayDo3,
    'guideTodayKeywords': l10n.guideTodayKeywords,
    'guideFaithTitle': l10n.guideFaithTitle,
    'guideFaithPurpose': l10n.guideFaithPurpose,
    'guideFaithExample': l10n.guideFaithExample,
    'guideFaithDo1': l10n.guideFaithDo1,
    'guideFaithDo2': l10n.guideFaithDo2,
    'guideFaithDo3': l10n.guideFaithDo3,
    'guideFaithKeywords': l10n.guideFaithKeywords,
    'guideExpenseTitle': l10n.guideExpenseTitle,
    'guideExpensePurpose': l10n.guideExpensePurpose,
    'guideExpenseExample': l10n.guideExpenseExample,
    'guideExpenseDo1': l10n.guideExpenseDo1,
    'guideExpenseDo2': l10n.guideExpenseDo2,
    'guideExpenseDo3': l10n.guideExpenseDo3,
    'guideExpenseKeywords': l10n.guideExpenseKeywords,
  };
  return (key) => texts[key] ?? (throw ArgumentError('No guide text for key "$key"'));
}
