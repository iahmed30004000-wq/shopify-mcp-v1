import 'dart:ui';

import '../core/era.dart';
import '../core/era_skin.dart';

// Per-era stage dressing and title-card tables. Owner: stage agent (tune
// freely – pure const data, import only core types).

StageStyle eraStage(Era era) => switch (era) {
  Era.silent => const StageStyle(proscenium: ProsceniumStyle.picturePalace, curtainFolds: 6, footlightFlicker: 0.5),
  Era.rubberHose => const StageStyle(proscenium: ProsceniumStyle.artDeco),
  Era.noir => const StageStyle(
    proscenium: ProsceniumStyle.noirArch,
    curtainFolds: 8,
    footlights: 7,
    footlightFlicker: 0.15,
  ),
  Era.technicolor => const StageStyle(proscenium: ProsceniumStyle.atomic, footlights: 11),
  Era.grindhouse => const StageStyle(
    proscenium: ProsceniumStyle.marquee,
    curtain: CurtainKind.tattered,
    footlightFlicker: 0.6,
  ),
  Era.vhs => const StageStyle(
    proscenium: ProsceniumStyle.neon,
    curtain: CurtainKind.neon,
    footlights: 13,
    footlightFlicker: 0.1,
    spotlight: false,
  ),
};

TitleStyle eraTitles(Era era) => switch (era) {
  Era.silent => const TitleStyle(fontFamily: 'Amiri', frame: TitleFrame.ornate),
  Era.rubberHose => const TitleStyle(fontFamily: 'ReemKufi', frame: TitleFrame.artDeco),
  Era.noir => const TitleStyle(
    fontFamily: 'ReemKufi',
    weight: FontWeight.w500,
    frame: TitleFrame.plain,
    letterSpacing: 1,
    irisShape: IrisShape.keyhole,
  ),
  Era.technicolor => const TitleStyle(fontFamily: 'ReemKufi', frame: TitleFrame.artDeco, irisShape: IrisShape.star),
  Era.grindhouse => const TitleStyle(
    fontFamily: 'PlexArabic',
    weight: FontWeight.w700,
    frame: TitleFrame.marquee,
    transition: EraTransition.burn,
  ),
  Era.vhs => const TitleStyle(
    fontFamily: 'PlexArabic',
    weight: FontWeight.w600,
    frame: TitleFrame.osd,
    letterSpacing: 2,
    transition: EraTransition.glitch,
  ),
};
