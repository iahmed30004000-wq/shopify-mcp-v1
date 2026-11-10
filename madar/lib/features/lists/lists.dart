/// The shared list engine: a tick list inside **anything**.
///
/// Import `package:madar/features/lists/lists.dart`.
///
/// One engine, every host. A list hangs on a host record addressed by
/// `(hostTable, hostId)` – the pair `LifeRecordLinks` resolves – so the
/// shopping list under a budget envelope, a trip's list and (Part 5) the
/// kitchen pantry are the same rows, the same ticking, the same undo and
/// the same screens. A new host costs a tile on its own screen; it never
/// costs a second list implementation.
///
/// Where to start:
/// * [ListService] (`listServiceProvider`) – every read and write, each
///   write returning a [ListUndo];
/// * [ListHost] – which record a list belongs to;
/// * [ListLine] / [ListTotals] – one line and what a list adds up to,
///   pure and exact (prices are integer milli-units; a price × a quantity
///   is rounded once, half-up);
/// * [ListPostPlan] – what turning the ticked part into one money entry
///   would do, and why it cannot (`ListPostRefusal`). The money itself is
///   written by the Money package (`ShoppingPostService`), never here;
/// * [HostListsScreen] / [ListScreen] – the two screens every host reuses;
/// * [ListActions] – the sheets, the ticks and the undo toasts.
///
/// What it is not: it holds no tax, VAT, fee or zakat field, it never
/// writes to the ledger itself, and a fresh install starts with no list,
/// no suggested item and no sample.
library;

export 'data/list_providers.dart';
export 'data/list_service.dart';
export 'domain/list_money.dart';
export 'domain/list_posting.dart';
export 'domain/record_list.dart';
export 'presentation/list_actions.dart';
export 'presentation/list_screen.dart';
export 'presentation/list_texts.dart';
export 'presentation/widgets/list_widgets.dart';
