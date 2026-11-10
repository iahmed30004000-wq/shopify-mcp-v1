import 'story_script.dart';

/// «النجمة الصغيرة»: an original, short fable written for Madar. A little star
/// loses its light on a quiet night and finds a lantern to share it with. No
/// faces, no religion, nothing to be afraid of.
const StoryScript littleStarStory = StoryScript(
  id: 'little_star',
  title: LocalizedText(ar: 'حكاية النجمة', en: 'The Little Star'),
  starReason: 'story.little_star',
  beats: [
    StoryBeat(
      narration: LocalizedText(
        ar: 'في ليلة هادئة، كانت نجمة صغيرة تلمع فوق التلّ.',
        en: 'On a quiet night, a little star shone above the hill.',
      ),
      from: StoryPose(0.70, 0.22, 1),
      to: StoryPose(0.64, 0.24, 1),
      sparkles: 5,
    ),
    StoryBeat(
      narration: LocalizedText(
        ar: 'فجأة هبّت نسمة خفيفة، وضاع ضوء النجمة الصغيرة. صارت تتجوّل في العتمة.',
        en: 'Suddenly a soft breeze blew, and the little star lost its light. It drifted through the dark.',
      ),
      from: StoryPose(0.64, 0.24, 1),
      to: StoryPose(0.30, 0.36, 0.12),
      trail: true,
      sparkles: 3,
    ),
    StoryBeat(
      narration: LocalizedText(
        ar: 'النجمة الصغيرة ضاع ضوؤها. ساعدها لتجد الفانوس!',
        en: 'The little star lost its light. Help it find the lantern!',
      ),
      from: StoryPose(0.30, 0.36, 0.12),
      to: StoryPose(0.46, 0.32, 0.3),
      trail: true,
      sparkles: 2,
      say: SayPrompt(LocalizedText(ar: 'ضوء', en: 'light')),
    ),
    StoryBeat(
      narration: LocalizedText(
        ar: 'رأت النجمة فانوسًا صغيرًا على التلّ، لكنّه كان مطفأً.',
        en: 'The star saw a small lantern on the hill, but it was not lit.',
      ),
      from: StoryPose(0.46, 0.32, 0.3),
      to: StoryPose(0.70, 0.60, 0.5),
      trail: true,
      sparkles: 3,
    ),
    StoryBeat(
      narration: LocalizedText(
        ar: 'اقتربت النجمة من الفانوس وهمست له: هل نُضيء معًا؟',
        en: 'The star came close to the lantern and whispered: shall we shine together?',
      ),
      from: StoryPose(0.70, 0.60, 0.5),
      to: StoryPose(0.73, 0.64, 0.6),
      lanternFrom: 0,
      lanternTo: 0.5,
      sparkles: 5,
      say: SayPrompt(LocalizedText(ar: 'نور', en: 'glow')),
    ),
    StoryBeat(
      narration: LocalizedText(
        ar: 'أضاء الفانوس، وعاد الضوء إلى النجمة أجمل من قبل. وصارت الليلة كلّها نورًا.',
        en: 'The lantern lit up, and the star glowed again, brighter than before. The whole night was full of light.',
      ),
      from: StoryPose(0.73, 0.64, 0.6),
      to: StoryPose(0.50, 0.30, 1),
      lanternFrom: 0.5,
      lanternTo: 1,
      trail: true,
      sparkles: 14,
      motionMs: 3200,
    ),
  ],
);
