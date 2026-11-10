/// «الحفظ» · every word and every colour the plan's screens use (Part 14,
/// step 2).
///
/// One place, so the morning screen, the drills, the map and the goals can
/// never disagree about what a band is called or what a colour means. It
/// builds nothing religious: a range's name comes from the Quran catalogue
/// through the wird's own [WirdTexts], and a verse's letters only ever come
/// from the verified text through the engines.
library;

import 'package:flutter/material.dart';

import '../../../../core/design/tokens.dart';
import '../../../../core/domain/enums.dart';
import '../../../../core/i18n/formatters.dart';
import '../../../../core/i18n/gen/app_localizations.dart';
import '../../../../core/quran/ayah.dart';
import '../../../../core/quran/quran_catalog.dart';
import '../../../wird/presentation/wird_labels.dart';
import '../../domain/hifz_daily_plan.dart';
import '../../domain/hifz_goals.dart';
import '../../domain/hifz_modes.dart';
import '../../domain/hifz_strength.dart';

/// Texts and colours for «الحفظ»'s screens.
class HifzPlanTexts {
  HifzPlanTexts(this.l, this.fmt, this.t, {this.catalog});

  factory HifzPlanTexts.of(BuildContext context, {QuranCatalog? catalog}) =>
      HifzPlanTexts(L10n.of(context), MadarFormatter.of(context), context.tokens, catalog: catalog);

  final L10n l;
  final MadarFormatter fmt;
  final MadarTokens t;
  final QuranCatalog? catalog;

  WirdTexts? get _quran => catalog == null ? null : WirdTexts(l, fmt, catalog!);

  // ------------------------------------------------------------- ranges ----

  /// `الملك ١–٥`, or the bare numbers before the catalogue has loaded.
  String range(AyahRange r) =>
      _quran?.range(r) ?? '${fmt.formatInt(r.first.surah, grouping: false)}:'
          '${fmt.formatInt(r.first.ayah, grouping: false)}'
          '–${fmt.formatInt(r.last.ayah, grouping: false)}';

  /// `ص ٥٦٢`.
  String? pages(AyahRange r) => _quran?.pages(r);

  String ayahRef(AyahRef a) => _quran?.ayah(a) ?? '${a.surah}:${a.ayah}';

  String surah(int number) => _quran?.surah(number) ?? fmt.formatInt(number, grouping: false);

  /// `٥ آيات`.
  String ayat(int count) => fmt.localizeDigits(l.hifzAyatCount(count));

  String portions(int count) => fmt.localizeDigits(l.hifzPortionsCount(count));

  String days(int count) => fmt.localizeDigits(l.hifzBacklogDaysCount(count));

  String pagesCount(int count) => fmt.localizeDigits(l.hifzPagesCount(count));

  String times(int count) => fmt.localizeDigits(l.hifzPlanRepeatTimes(count));

  // -------------------------------------------------------------- modes ----

  String method(HifzMethod m) => switch (m) {
    HifzMethod.listenRepeat => l.hifzMethodListenRepeat,
    HifzMethod.chunking => l.hifzMethodChunking,
    HifzMethod.progressiveHiding => l.hifzMethodHiding,
    HifzMethod.blanks => l.hifzMethodBlanks,
    HifzMethod.writing => l.hifzMethodWriting,
    HifzMethod.linking => l.hifzMethodLinking,
    HifzMethod.reciting => l.hifzMethodReciting,
  };

  IconData methodIcon(HifzMethod m) => switch (m) {
    HifzMethod.listenRepeat => Icons.headphones_rounded,
    HifzMethod.chunking => Icons.view_agenda_outlined,
    HifzMethod.progressiveHiding => Icons.visibility_off_outlined,
    HifzMethod.blanks => Icons.space_bar_rounded,
    HifzMethod.writing => Icons.edit_note_rounded,
    HifzMethod.linking => Icons.link_rounded,
    HifzMethod.reciting => Icons.mic_none_rounded,
  };

  /// The one plain line under a mode that cannot run as it should – never a
  /// dead button, never silence.
  String? blocker(HifzMethodState s) {
    if (s.blocker == HifzMethodBlocker.audioNotDownloaded) return l.hifzMethodNoAudio;
    return switch (s.status) {
      HifzMethodStatus.ready => null,
      HifzMethodStatus.typedOnly => l.hifzMethodTypedOnly,
      HifzMethodStatus.unavailable => l.hifzMethodNoRecogniser,
    };
  }

  String stage(HidingStage s) => switch (s) {
    HidingStage.full => l.hifzStageFull,
    HidingStage.firstLetters => l.hifzStageFirstLetters,
    HidingStage.hidden => l.hifzStageHidden,
  };

  String chunkLevel(ChunkLevel level) => switch (level) {
    ChunkLevel.ayah => l.hifzChunkLevelAyah,
    ChunkLevel.group => l.hifzChunkLevelGroup,
    ChunkLevel.page => l.hifzChunkLevelPage,
  };

  // ------------------------------------------------------------- tracks ----

  String track(HifzTrack track) => switch (track) {
    HifzTrack.fresh => l.hifzTrackFresh,
    HifzTrack.near => l.hifzTrackNear,
    HifzTrack.far => l.hifzTrackFar,
  };

  String? trackNote(HifzTrack track) => switch (track) {
    HifzTrack.fresh => null,
    HifzTrack.near => l.hifzTrackNearNote,
    HifzTrack.far => l.hifzTrackFarNote,
  };

  IconData trackIcon(HifzTrack track) => switch (track) {
    HifzTrack.fresh => Icons.auto_awesome_rounded,
    HifzTrack.near => Icons.history_rounded,
    HifzTrack.far => Icons.all_inclusive_rounded,
  };

  // -------------------------------------------------------------- bands ----

  String band(StrengthBand b) => switch (b) {
    StrengthBand.unknown => l.hifzBandUnknown,
    StrengthBand.weak => l.hifzBandWeak,
    StrengthBand.shaky => l.hifzBandShaky,
    StrengthBand.firm => l.hifzBandFirm,
    StrengthBand.solid => l.hifzBandSolid,
    StrengthBand.skipped => l.hifzBandSkipped,
  };

  /// The one colour scale of «الحفظ». «ما انختبرت» is deliberately **not**
  /// a warm colour: it is the absence of a result, not a bad one.
  Color bandColor(StrengthBand b) => switch (b) {
    StrengthBand.unknown => t.textTertiary,
    StrengthBand.weak => t.danger,
    StrengthBand.shaky => t.warning,
    StrengthBand.firm => t.accent,
    StrengthBand.solid => t.success,
    StrengthBand.skipped => t.dust,
  };

  /// The bands a legend shows, in the order they are read.
  static const List<StrengthBand> legendBands = [
    StrengthBand.unknown,
    StrengthBand.weak,
    StrengthBand.shaky,
    StrengthBand.firm,
    StrengthBand.solid,
    StrengthBand.skipped,
  ];

  // ------------------------------------------------------------ backlog ----

  /// «غبت ٧ أيام، و٣٥٩ آية رجعت لدورها» – and never swallowed.
  String backlog(HifzBacklog b) => fmt.localizeDigits(
    l.hifzBacklogBody(days(b.missedDays), ayat(b.todayAyat), ayat(b.droppedAyat)),
  );

  /// The stretches the backlog names, joined for one line.
  String backlogRanges(HifzBacklog b, {int limit = 6}) {
    final shown = b.dropped.take(limit).map(range).join(l.commonFactSeparator);
    if (b.dropped.length <= limit) return l.hifzBacklogDropped(shown);
    return l.hifzBacklogDropped('$shown…');
  }

  /// What a plan note says, or null when it needs no line of its own.
  String? note(HifzPlanNote n) => switch (n) {
    HifzPlanNote.nothingMemorised => l.hifzPlanEmpty,
    HifzPlanNote.noNewPortion => l.hifzPlanNoNewPortion,
    HifzPlanNote.firstDay => l.hifzPlanFirstDay,
    HifzPlanNote.recitingUnavailable => l.hifzMethodNoRecogniser,
    HifzPlanNote.backlogDropped => null, // the backlog card says it in full
    HifzPlanNote.everythingSkipped => l.hifzPlanAllSkipped,
  };

  // -------------------------------------------------------------- goals ----

  String goalKind(HifzGoalKind k) => switch (k) {
    HifzGoalKind.rangeOnWeekday => l.hifzGoalKindWeekday,
    HifzGoalKind.rangeReview => l.hifzGoalKindReview,
    HifzGoalKind.amountPerDay => l.hifzGoalKindAmount,
  };

  /// `٣ صفحات`, `آيتان` – the wird's own unit words, so the two features
  /// never count in different language.
  String amount(WirdUnit u, int n) => fmt.localizeDigits(switch (u) {
    WirdUnit.pages => l.wirdUnitPages(n),
    WirdUnit.juz => l.wirdUnitJuz(n),
    WirdUnit.hizb => l.wirdUnitHizb(n),
    WirdUnit.ayat => l.wirdUnitAyat(n),
  });

  /// `٣ آيات من ٨ آيات`.
  String goalProgress(HifzGoalProgress p) {
    final u = p.goal.kind == HifzGoalKind.amountPerDay ? p.goal.unit : WirdUnit.ayat;
    return fmt.localizeDigits(l.hifzGoalProgressLine(amount(u, p.done), amount(u, p.target)));
  }

  /// `الإثنين` … – Monday first, from the shared list.
  String weekday(int weekday) {
    final names = l.dataSumWeekdays.split(',');
    final i = (weekday - DateTime.monday) % 7;
    return i >= 0 && i < names.length ? names[i].trim() : '';
  }

  /// Every weekday, Monday first, paired with `DateTime.monday … sunday`.
  List<(int, String)> get weekdays => [
    for (var d = DateTime.monday; d <= DateTime.sunday; d++) (d, weekday(d)),
  ];
}
