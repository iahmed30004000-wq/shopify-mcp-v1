/// Hifz: memorising ayat, hadith and your own texts with SM-2 spaced
/// repetition.
///
/// Screens: [HifzScreen], [HifzReviewScreen]; the compact [HifzTodayCard]
/// for the Faith planet page. Other features add ayat through
/// [hifzImportProvider] (`addAyahRangeToHifz`) or
/// [HifzActions.addAyahRangeToHifz] (with the undo toast).
library;

export 'data/hifz_providers.dart';
export 'data/hifz_service.dart';
export 'domain/hadith_collection.dart';
export 'domain/hifz_models.dart';
export 'domain/hifz_reveal.dart';
export 'domain/hifz_session.dart';
export 'domain/sm2.dart';
export 'presentation/hifz_actions.dart';
export 'presentation/hifz_labels.dart';
export 'presentation/hifz_navigation.dart';
export 'presentation/hifz_review_screen.dart';
export 'presentation/hifz_screen.dart';
export 'presentation/hifz_sheets.dart';
export 'presentation/hifz_today_card.dart';
export 'presentation/widgets/hifz_grade_bar.dart';
export 'presentation/widgets/hifz_reveal_text.dart';
export 'presentation/widgets/hifz_segmented.dart';
export 'presentation/widgets/hifz_widgets.dart';
