import 'parser.dart';

/// One chip of the quick-add live preview.
enum QuickAddFacet { kind, amount, water, score, date, time, window, planet }

/// The preview chips to show for [intent], in display order (pure – unit
/// tested). Empty input shows nothing; the planet is only shown where it
/// adds information (money / health kinds imply theirs).
List<QuickAddFacet> quickAddFacets(QuickAddIntent intent) {
  if (intent.raw.trim().isEmpty) return const [];
  final k = intent.kind;
  final money = k == QuickAddKind.expense || k == QuickAddKind.income;
  final scored = k == QuickAddKind.pain || k == QuickAddKind.mood;
  final free = k == QuickAddKind.task || k == QuickAddKind.note || k == QuickAddKind.contact;
  return [
    QuickAddFacet.kind,
    if (money && intent.amountMilli != null) QuickAddFacet.amount,
    if (k == QuickAddKind.water && intent.amountMilli != null) QuickAddFacet.water,
    if (scored && intent.amountMilli != null) QuickAddFacet.score,
    if (intent.date != null) QuickAddFacet.date,
    if (intent.time != null) QuickAddFacet.time,
    if (intent.window != null) QuickAddFacet.window,
    if (free && intent.planetKey != null) QuickAddFacet.planet,
  ];
}
