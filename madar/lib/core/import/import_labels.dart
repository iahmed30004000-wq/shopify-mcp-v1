import 'package:flutter/widgets.dart' show Locale;

import '../i18n/gen/app_localizations.dart';

/// User-visible names the importer has to invent (a wallet for transactions
/// that name none, kanban column labels …), taken from the app's
/// localisations so nothing is hard-coded.
class ImportLabels {
  const ImportLabels({
    required this.defaultWallet,
    required this.defaultBoard,
    required this.openingBalance,
    required this.columnTodo,
    required this.columnDoing,
    required this.columnDone,
  });

  factory ImportLabels.of(L10n l) => ImportLabels(
    defaultWallet: l.importDefaultWallet,
    defaultBoard: l.importDefaultBoard,
    openingBalance: l.importOpeningBalance,
    columnTodo: l.importColumnTodo,
    columnDoing: l.importColumnDoing,
    columnDone: l.importColumnDone,
  );

  /// Labels in [languageCode] (`ar` / `en`) without a BuildContext.
  factory ImportLabels.forLanguage(String languageCode) =>
      ImportLabels.of(lookupL10n(Locale(languageCode == 'en' ? 'en' : 'ar')));

  final String defaultWallet;
  final String defaultBoard;

  /// Note of the deposit created from a jar's saved amount.
  final String openingBalance;
  final String columnTodo;
  final String columnDoing;
  final String columnDone;

  /// Label of a well-known kanban column id.
  String? column(String id) => switch (id) {
    'todo' => columnTodo,
    'doing' => columnDoing,
    'done' => columnDone,
    _ => null,
  };
}
