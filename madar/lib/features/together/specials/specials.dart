/// The couple specials of Together Mode (spec M):
///
/// * "How well do you know me?" (قديش بتعرفني؟) – [KnowMeScreen] (set-up),
///   [KnowMeRoundScreen] (a pass-and-play round: private answers behind the
///   hand-off gate, the reveal, the verdicts, the result into the
///   head-to-head history and the Hall of Fame) and [QuestionBankScreen]
///   (60 generic default questions in six categories, all editable).
/// * The weekly shared challenge – [WeeklyChallengeScreen],
///   [ChallengeListScreen], [showSpecialsSettingsSheet] (week start).
/// * The cooperative goal – [CoopGoalScreen], [showGoalEditorSheet],
///   [GoalUnlockWatcher].
/// * [TogetherSpecialsSection] – the three on the Together home.
///
/// Everything is stored as bounded JSON in the encrypted KeyValues table
/// ([SpecialsRepository.allKeys]); nothing ever leaves the device.
library;

export 'data/specials_providers.dart';
export 'data/specials_repository.dart';
export 'domain/coop_goal.dart';
export 'domain/know_me_bank.dart';
export 'domain/know_me_catalogue.dart';
export 'domain/know_me_round.dart';
export 'domain/specials_bounds.dart';
export 'domain/specials_settings.dart';
export 'domain/weekly_challenge.dart';
export 'presentation/goal/coop_goal_screen.dart';
export 'presentation/know_me/know_me_round_screen.dart';
export 'presentation/know_me/know_me_screen.dart';
export 'presentation/know_me/question_bank_screen.dart';
export 'presentation/specials_section.dart';
export 'presentation/specials_texts.dart';
export 'presentation/specials_visuals.dart';
export 'presentation/weekly/challenge_list_screen.dart';
export 'presentation/weekly/weekly_challenge_screen.dart';
