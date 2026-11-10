# «مدار الصغار» — Kids section: design for approval

Status: **design only, nothing is built.** PLAN.md Part 16 requires the owner to approve this
picture first (DoD blocker 2). Overview: `png/00-board.png`. One PNG per screen in `png/`
(720 x 1560, 2x of a 360 x 780 phone). HTML sources in `html/`; the generator in `tools/`
(`node tools/build.js && node tools/render.js`) rebuilds everything with the app's own fonts.

## 0. Read this first (religious content)

* **No Quran verse, hadith, dhikr, surah name, prayer or wudu wording was written by the designer.**
  Every such place is a gold dashed placeholder, e.g. «[نص السورة من مصحف المدينة]»,
  «[اسم السورة]», «[نص الذكر من مصدر موثّق]», «[وصف الخطوة — بعد مراجعة الشيخ]», «[اسم النبيّ]».
* All religious text and audio will come later **only from verified, licensed sources** (the same
  Tanzil / Madinah mushaf pipeline the Quran feature already uses), each item carrying source +
  reviewer sign-off, and will stay **hidden behind a flag until the owner's named sheikh approves**
  (Part 16 blocker 1). The build must fail if an item lacks its source or sign-off.
* Counts, step lists, number of wudu steps, number of beads, surah lists: all shown are layout
  stand-ins, not facts.
* **Needs the sheikh's review:** the whole prayer & wudu screen (05), including the *idea* of
  illustrating wudu with abstract water and hands; the prophets' stories (06), including whether a
  column of light is acceptable as a symbol of a prophet's presence (see open question 1).

## 1. Design principles

1. **A planet, not a menu.** Ten small worlds the child can see all at once, no scrolling to find
   the Quran.
2. **Identity = Islamic geometry.** One shape repeats everywhere: the *khatam* (8-point star = two
   squares) as medallion, star-count, reward and bullet; a girih-style lattice as a quiet
   background. Drawn in SVG, so it scales and stays crisp.
3. **Warm and calm, never loud.** Sunrise gold, soft teal, rose, deep indigo night. Paper-cream
   cards. No neon, no cartoon mascot, no franchise look. The adult app is dark "lapis + brass
   glass"; kids is light paper + indigo night, so the child sees at once he is somewhere else.
4. **Big and forgiving.** Every touch target >= 64 px (main actions 76-88). Body 20 px, titles
   26-38 px. Generous space; one main action per screen.
5. **A child is never told he is wrong.** Doubt = soft amber + «ما سمعت منيح، عيد». No red anywhere
   in the section; no "wrong", no cross, no sad sound.
6. **Works without reading.** Every text has a speaker button; icons carry meaning alone.
7. **Safe by construction.** One-way lock, own shell, no network (section 5).
8. **Reduced motion respected;** all motion in the mock-ups (light, water, trail) has a still
   equivalent. Text scale up to 1.3 keeps layouts (cards grow, no fixed-height text).

## 2. Palette (exact values)

| Token | Hex | Use |
|---|---|---|
| night900 | `#17143F` | deepest night, text on gold |
| night800 | `#221E5A` | main indigo, cards on dark, star-count chip |
| night700 | `#2F2A78` | gradients |
| night500 / 300 / 100 | `#5650B0` / `#A9A5E6` / `#E6E4FA` | accents, soft indigo tints |
| sun500 (gold) | `#F5B431` | primary action, current word, stars |
| sun300 / 100 | `#FFD479` / `#FFF0CC` | soft gold, highlights |
| sun700 | `#A8680F` | placeholder text only |
| teal700 / 500 / 200 / 100 | `#17706C` / `#2FA59C` / `#B6E6DF` / `#E2F5F1` | success, "go", water |
| rose500 / 300 / 100 | `#E26A89` / `#F6A9BC` / `#FCE3EA` | mic, colouring, warmth |
| rose700 | `#A93556` | text on rose tints |
| retry (amber) | `#F7A94B`, fill `#FFEBD0`, text `#8A4B05` | the soft "عيد" state; replaces any red |
| paper / sand / sand2 | `#FFF8EA` / `#F7E9CF` / `#EBD5A8` | surfaces |
| ink / ink2 | `#26214F` / `#5A5482` | text |

Contrast (computed): ink on paper 14.1, night900 on gold 9.5, white on teal700 5.9, white on
night800 15.0, retry text on retry fill 5.8, ink2 on paper 6.6, teal800 on teal100 7.6. Placeholder
gold-on-gold is 4.0 on purpose: it is a temporary marker, not content.

## 3. Type scale

Fonts are the repo's own (`assets/fonts`): **ReemKufi** (headings, geometric, matches the
khatam), **IBM Plex Sans Arabic** (reading, 500/700), **Amiri / AmiriQuran** (Quran-like text and
letter shapes; the real Quran text will use the mushaf font the Quran feature already uses).

| Role | Font | Size / line |
|---|---|---|
| Display | ReemKufi 700 | 36-38 / 1.25 (word-spacing .18em: Reem's native word gap is too tight) |
| Title | ReemKufi 700 | 26-32 / 1.3 |
| Subtitle | ReemKufi 600 | 22 / 1.35 |
| Body | Plex 500 | 20 / 1.6 |
| Small | Plex 500 | 16 / 1.5 (never below 15; 14 only on 64 px button labels) |
| Quran-like words | AmiriQuran | 25-30 / 1.55 |
| Letters | Amiri 700 | 38-100 |
| Numbers in sums | ReemKufi 700 | 40-64 |

All numerals Arabic-Indic (٠١٢٣٤٥٦٧٨٩), also on the keypad and in clocks. Sums are drawn with
left-to-right digits (٣ × ٤ = ؟) as in Jordanian school books.

## 4. Components the build would need

`KidsShell` (own navigator + route guard) · `KidsTopBar` (home, title, star chip) ·
`ParentGateSheet` (PIN pad + fingerprint) · `PinOfferSheet` · `WorldTile` / `WorldMedallion`
(khatam medallion) · `KhatamStar`, `GirihBackground` (painters, cached, no per-frame allocation) ·
`BigButton` (gold / teal / rose / paper / ghost, min 64) · `RoundIconButton` (64) · `SegmentedTabs`
(64) · `MushafWordCard` + `WordHighlight` (word-timed highlight, reduced-motion = colour only) ·
`ListeningOrb` (mic, listening / soft-retry / heard-well states) · `SoftRetryCard` ·
`StepIllustration` (wudu/prayer, abstract) · `StoryScene` (layered SVG scene: sky, dunes, light,
objects) · `LetterCard` + `LetterForms` · `MathQuestion` (dot array, answer buttons, fraction pie) ·
`ColouringGallery`, `ImportCard`, `ColouringCanvas` (tap-to-fill regions, palette, undo, eraser) ·
`VoiceStoryPlayer`, `VoiceRecorderRow` (record / stop / re-record / delete) · `InteractiveStoryStage`
(Cinema engine host, mic + tap) · `GameCard` · `LanternShelf`, `StarCounter` · `ScreenTimeEndScene`
· `TasbihCounter` · `PlaceholderTag` (shows the gold dashed marker while a religious item is
unapproved; in release the whole item is simply absent).

## 5. Safety and lock rules (restated; the design only shows their face)

* **One-way lock.** Entering = one tap. Leaving = the parent's PIN **or** fingerprint, every time
  (PIN only if no fingerprint is enrolled). Own shell: no deep link, notification tap, share intent,
  back gesture or recents entry reaches the rest of Madar.
* **Six areas locked out, invisible and unreachable** (route, deep link, notification tap, search):
  **health, medication, the wallet, the family planet, the chat, the work board.** Beyond them,
  also money, settings and the notification centre.
* **No free chat with a model, ever.** Any model use is scripted over verified content only. The
  voice mic only *listens to the child recite/answer* on the device; it never produces a free answer.
* **No network call at all, no ads, no accounts.** Nothing leaves the device (colouring files,
  recordings, stars).
* **Screen time:** limit set by the parent, enforced, ends gently (screen 12).
* **Android app pinning** offered on entry with one plain sentence (screen 1b).
* **Imports and recording happen in the parent corner**, behind the gate, because Android's file
  picker and microphone permission are outside the kids shell.
* **A low-confidence hearing marks nothing:** no mistake row, no broken streak (screen 4a).
* **Reviewer flag:** every religious item is hidden until the named sheikh signs it off.

## 6. Screens

Plan reference = PLAN.md Part 16. English with short Arabic captions.

**1a — الدخول بلمسة وحدة** (`01a-entry-main-app.png`). The adult app (dark lapis, schematic: its real
layout is not copied) with one bright card «مدار الصغار / ادخل» and the plain line «الدخول بلمسة
وحدة. الخروج بالرقم السري أو البصمة فقط.» The other planets shown are the ones that will be
locked out. Satisfies: entering is one tap.

**1b — تثبيت الشاشة** (`01b-entry-pinning-offer.png`). Welcome rosette, bottom sheet marked «للأهل»:
«تثبيت الشاشة بيخلّي الجوال على مدار الصغار فقط، وما بيطلع منه إلا الأهل.» Buttons «ثبّت الشاشة»
and «مش هلأ، كمّل بدون تثبيت». Android then shows its own pinning dialog. Satisfies: app pinning
offered and explained.

**1c — بوابة الأهل** (`01c-parent-gate.png`). Calm dusk, lock in a khatam, «اكتب الرقم السري أو المس
البصمة عشان تطلع من مدار الصغار», 4 dots, big Arabic-Indic keypad, fingerprint key, and the
friendly default «رجوع للّعب». No shaking, no red on a wrong PIN: the dots empty and the line
«جرّب مرّة ثانية» fades in. Satisfies: leaving demands PIN or fingerprint.

**2 — الرئيسية** (`02-kids-home.png`). Sunrise sky over a patterned planet; greeting «أهلاً يا نجم!»;
Quran as the wide featured tile, then nine worlds: الصلاة والوضوء، القصص، الأخلاق، الحروف، الحساب،
التلوين، الألعاب، جوائزي، الأذكار. Bottom: star count and time left. Small lock top-left = the
parent gate. Satisfies: every section present and usable. (The name is generic, never personal.)

**3 — جزء عمّ** (`03-juz-amma-reading.png`). Mushaf-like framed page, placeholder words, current word
in gold with glow, finished words teal, a listening bar, play/pause 84, «عيد الآية», «جرّب أنت»
(opens the check), reciter placeholder. Satisfies: surah listened to with the word highlighted;
kids version of Part 14 memorisation.

**4a — ما سمعت منيح، عيد** (`04a-recitation-soft-retry.png`). Amber, not red; mic orb at rest; big
«عيد» button 80 px; line «نجومك محفوظة زي ما هي». **4b — أحسنت!** (`04b-…heard-well.png`) for
contrast: teal, star bursts, «الكلمة الجاية». Speaker button hears the word for a child who cannot
read it yet. Satisfies: kid-level «التسميع» (Part 13), «ما سمعت منيح، عيد» with no mistake row and
no broken streak; "child taps عيد ten times" = the same card, no penalty.

**5 — الصلاة والوضوء** (`05-prayer-wudu.png`). Tabs الوضوء | الصلاة; step badge; abstract water
stream, two hands built from rounded rectangles with a khatam on each palm, light and ripples;
progress dots; title/description placeholders; banner «محتوى مؤقّت · بانتظار مراجعة الشيخ قبل
الظهور للطفل». Prayer tab will use a mat and a moving point of light, never a body. **No faces, no
human figures. Needs the sheikh's review.** Satisfies: prayer and wudu step by step.

**6 — القصص** (`06-prophet-story.png`). Dusk desert: dunes, palms, a lantern, a path of light, a
column of light with a khatam. Chips نور / مكان / أغراض; narration button. **No face and no figure
of any prophet or companion.** Satisfies: prophets' stories told with places, light, objects; also
the template for «الأخلاق» (manners), which reuses this layout.

**7a — الحروف** (`07a-arabic-letters.png`). Letter strip, big letter «ع» with its four forms
(وحدها / أول / وسط / آخر الكلمة), a word with a picture (عِنَب) where the letter is gold, speaker
buttons, «اكتب الحرف بإصبعك» (finger tracing). Letter/word examples are non-religious samples.
**7b — الحساب** (`07b-maths.png`). Tabs الضرب | القسمة | الكسور; ٣ × ٤ = ؟ with a colour-coded dot
array showing what multiplication means; three answer buttons; previews of ١٢ ÷ ٣ (sharing into
groups) and ٣/٤ (pie). A wrong answer uses the same soft amber «جرّب مرّة ثانية», never red.
Satisfies: letters + maths at a nine-year-old's level.

**8a — التلوين: معرض** (`08a-colouring-import.png`). Import card «أضيف صورة من جوالي — بتضلّ على
جوالك، وما بتروح لأي مكان», marked «للأهل» (opens behind the gate); «صوري» (his files) and «صور المدار».
**8b — صفحة ملوّنة** (`08b-colouring-page.png`). Girih-style page part-coloured, 64 px colour
swatches, undo, eraser, «خلصت». Satisfies: his own colouring files import and open offline and never
leave the phone; edge cases (huge or non-image file) are answered with a soft «هالملف ما زبط» card,
not drawn here.

**9a — حكايات بابا** (`09a-voice-stories-child.png`). Child's player: waveform ring, «بصوت بابا»
tag (the label is editable text), play/pause, list of stories. **9b — ركن الأهل: التسجيل**
(`09b-…parent-corner.png`): one story recorded (play / record again / delete), one recording (stop &
save, cancel, timer), one empty («سجّل بصوتك»), plus «التسجيلات بتضلّ على هالجوال فقط. إذا اجتك مكالمة،
التسجيل بيوقف وبيتحفظ.» Story titles are examples; the parent names them. Satisfies: record,
re-record, delete, play offline; a call interrupting a recording keeps what was said.

**9c — قصة تفاعلية** (`09c-interactive-story.png`). Original non-religious fable (a little star that
lost its light), motion trail with ghost frames, sparkles, narration, mic «قُل: ضوء!», replay. The
star has **no face** (kept abstract to stay clear of cartoon tropes). Weak GPU: trail and glow drop
first, the story still works. Satisfies: interactive story with voice and motion (Cinema engine).

**10 — الألعاب** (`10-game-card.png`). Featured game card «أزواج النجوم» (a calm memory game with
khatam cards), difficulty stars, ~3 minutes, «العب» 76 px; two more small cards. Satisfies: games on
the Cinema engine; time limit applies inside games.

**11 — جوائزي** (`11-rewards.png`). Star counter, progress to the next lantern, a shelf of
lanterns (lit = earned, silhouettes = still to come), «نجومك محفوظة على جوالك». Stars are written the
moment they are earned, so a dying battery loses nothing. Satisfies: rewards recorded on the device.

**12 — انتهى وقت اللعب** (`12-screen-time-end.png`). Dusk, crescent, dimmed lanterns; «خلص وقت اللعب
اليوم / أخذت استراحة حلوة. منكمّل بكرا!»; stars saved; one big «تمام»; «للأهل: زيادة الوقت» behind the
gate. A gentle 5-minute warning (a small pill, not drawn) precedes it; a lesson in progress is
saved, never cut mid-save. Satisfies: screen time ends gently.

**13 — الأذكار** (`13-adhkar.png`). Tabs الصباح | المساء, placeholder card, a tasbih circle that
fills with beads as the child taps, count «٧ من [العدد]», speaker, next. Satisfies: kids-sized
adhkar. Dhikr wording, counts and which adhkar are for a child: sheikh's decision.

## 7. What is NOT drawn, and why

* **Any face or figure of a prophet or companion** (rule). Also no human faces in wudu/prayer,
  no human body shapes; the light/hands are abstract. Even the light symbol is flagged (Q1).
* **Manners («الأخلاق») and the prayer tab** as their own screens: same templates as 6 and 5; their
  content is the sheikh's.
* **Wrong-PIN, no-fingerprint (PIN only), pinned-vs-unpinned variants, the 5-minute warning,
  low-battery and phone-call interruptions, large-file error cards:** small variants of drawn
  components, to be specified at build time.
* **Settings for parents** (limit, PIN change, import): they live in the adult app / parent corner,
  not in the child's world.
* **Real Quran, hadith and dhikr text, real reciter names, real audio:** see section 0.
* **Animations:** shown as frozen frames (trail, glow, ripples, sparkle).
* **No mascot/character, no leaderboard, no timers that pressure, no purchases, no ads.**

## 8. Open questions for the owner (max 5)

1. **Light as the stand-in for a prophet in stories.** Some scholars avoid even symbolic light.
   Recommended: keep the light column in the mock-up, show it to the sheikh, and if he declines,
   tell the stories with places and objects only (the scene still works without the beam).
2. **Who is "بابا"?** The label «بصوت بابا» is shown. Recommended: the recorder types the label
   once («بصوت بابا»، «بصوت ماما»، «بصوت جدّو») so it is never hard-coded.
3. **Should the child be able to open «أضيف صورة» himself?** Recommended: no; it sits behind the
   parent gate (as drawn), because Android's file picker leaves the kids shell.
4. **Stars, lanterns, and what they unlock.** Recommended: stars are only a collection (lanterns,
   colouring pages), never a lock on learning content and never lost.
5. **PIN length and fingerprint-only parents.** Recommended: reuse the app's existing PIN as is
   (drawn with 4 dots), PIN-only when no fingerprint is enrolled, and a 30-second calm cooldown after
   three wrong tries, with no message that blames the child.

## 9. Files

`png/00-board.png` (board) · `01a, 01b, 01c, 02, 03, 04a, 04b, 05, 06, 07a, 07b, 08a, 08b, 09a, 09b,
09c, 10, 11, 12, 13` PNGs (names as above) · `html/*.html` sources (fonts via relative file paths to
`assets/fonts`) · `tools/` generator (Node + Playwright).
