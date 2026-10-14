/// The daily chat: one place where he types his day in his own Jordanian
/// Arabic, and Madar files each piece where it belongs – after he confirms it.
///
/// Import `package:madar/features/day_chat/day_chat.dart`.
///
/// What this package is and is not:
/// * it **reads text and proposes**. Nothing is written until he applies one
///   piece, by hand, one at a time – there is deliberately no "apply all";
/// * it is offline: no network call anywhere in it, and no AI. The AI round
///   trip for a sentence it could not read is Part 3's bridge, on his
///   explicit tap, from the chat screen;
/// * it never guesses in silence: every piece carries the exact span of his
///   own words it came from, a confidence, and what it could not resolve –
///   and a piece it could not read at all is itself a proposal («ما فهمت
///   هاي») he can turn into a note;
/// * medicine stays his doctor's: a sentence carrying a dose or a diagnosis
///   is kept as his own note and nothing else (`HealthGuard`).
///
/// Where to start (the chat screen builds on these):
/// * `dayChatServiceProvider` – `read` a line, `apply` / `applyEdited` /
///   `reject` one piece (each with an undo), `summary` for «شو صار اليوم؟»;
/// * `dayChatReadingProvider(text)` – the proposals of one line, live;
/// * `dayChatDayProvider(day)` – his lines and his decisions, live;
/// * `dayChatSummaryProvider(day)` – his day in facts;
/// * `DayChatTexts` – every sentence, in his language and his digits.
library;

export 'data/day_chat_providers.dart';
export 'data/day_chat_service.dart';
export 'data/day_chat_store.dart';
export 'domain/day_chat_journal.dart';
export 'domain/day_chat_piece.dart';
export 'domain/day_chat_reader.dart';
export 'domain/day_chat_segmenter.dart';
export 'domain/day_chat_text.dart';
export 'domain/day_chat_vocabulary.dart';
export 'domain/day_summary.dart';
export 'presentation/day_chat_texts.dart';
