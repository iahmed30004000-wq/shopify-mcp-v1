import 'package:drift/drift.dart';

import 'converters.dart';

// ------------------------------------------------ tick lists (v5) ----
//
// Part 3b: one list engine for the whole app. The owner's words
// (2026-10-10): «لما احط بالميزانية البقالة ما بقدر اعمل قائمة للاغراض» –
// a tick list inside **anything**, not only inside an AI plan.
//
// A list hangs on a host record, addressed the way `LifeRecordLinks`
// addresses records everywhere else: an SQL table name plus that row's id
// (`budget_items` + the «بقالة» envelope, `trips` + a trip, later the
// kitchen pantry of Part 5). Nothing here knows what a host *is*, so a new
// host costs a screen, never a second list implementation.
//
// Money: a line's price is in **milli-units**, the same unit the ledger
// stores (`*_milli`), so a price typed as «٨» is 8 000 and the ticked part
// of a list adds up to the exact fils. Posting that total to the ledger is
// the Money package's job ([ShoppingPostService]) – these tables only
// record **that** it was posted and which entry it wrote, which is what
// makes posting twice impossible instead of merely unlikely.
//
// No tax, VAT, fee or zakat column exists here, and none ever will.

/// One list of a host record.
@DataClassName('RecordListRow')
class RecordLists extends Table with Entity, Ordered {
  /// SQL table of the record this list belongs to (`budget_items`,
  /// `trips` …) – the same pair `LifeRecordLinks` resolves.
  TextColumn get hostTable => text()();

  /// Id of that record. The row may be gone (nothing cascades here): a
  /// list whose host was deleted still reads, and simply has no host.
  TextColumn get hostId => text()();

  /// His own name for the list («أغراض البقالة», «شنطة عمّان»).
  TextColumn get name => text()();

  /// The currency every price on this list is in (null = the base
  /// currency). Resolved once, when the list is created, from the host –
  /// a budget envelope's own currency – so no amount on a list is ever
  /// converted behind his back.
  TextColumn get currency => text().nullable()();

  TextColumn get note => text().nullable()();

  /// When the ticked part of this list was turned into one ledger entry
  /// (null while it was never posted). A posted list says so and refuses
  /// to post again, so he can never be charged twice for one shop.
  DateTimeColumn get postedAt => dateTime().nullable()();

  /// The `transactions` row that posting wrote (null when never posted,
  /// or after an undo).
  TextColumn get postedTxId => text().nullable()();

  /// What was posted, kept here so the list can say «٣ أغراض — ٨٫٠٠٠ د.أ»
  /// without reading the ledger back.
  IntColumn get postedAmountMilli => integer().nullable()();
  IntColumn get postedItemCount => integer().nullable()();
}

/// One line of a list: what he wrote, how much of it, what it costs, and
/// whether he has ticked it off.
@DataClassName('RecordListItemRow')
class RecordListItems extends Table with Entity, Ordered {
  TextColumn get listId => text()();

  /// His own words («رز», «جواز»).
  TextColumn get title => text()();

  /// How much (2 kg, 3 pieces); null when he gave none.
  RealColumn get quantity => real().nullable()();

  /// His own unit word («كيلو», «علبة»); never a list we invent.
  TextColumn get unit => text().nullable()();

  /// Price in milli-units of the list's currency: **per [unit]** when a
  /// [quantity] is given, else the price of the whole line. Null when he
  /// gave no price (a packing list has none).
  IntColumn get priceMilli => integer().nullable()();

  /// Ticked off (bought, packed …).
  BoolColumn get done => boolean().withDefault(const Constant(false))();

  /// When he ticked it (null while it is open).
  DateTimeColumn get doneAt => dateTime().nullable()();

  TextColumn get note => text().nullable()();
}
