# Madar Cinema – word & knowledge games: content

Pure-Dart rules live in this folder (`words.dart` exports everything); the
content lives in `assets/games/` and is rebuilt by
`python3 assets/games/source/build_games_words.py` (pinned, checksummed
sources; report in `assets/games/source/verification_log.txt`, which must end
with `RESULT PASS`). The build's Python modules `content_*.py` are the
editable source of all self-authored content. Credits:
`assets/licenses/games_words_credits.txt`.

## Files, counts, sources, licences

| Asset | Content | Source / licence |
|---|---|---|
| `arabic_lexicon.txt` (1.1 MB) | 86,118 words of 3–8 letters, most frequent first (rank = line order); 1,957 carry a vowelled form | Arabic Wikipedia word counts from IlyaSemenov/wikipedia-word-frequency @ 325f669 (MIT) + Madar's curated words (own) |
| `arabic_word_filter.json` | 70 blocked, 59 sensitive, 14 allowed look-alikes, clitic rules | LDNOOBW `ar` @ 5faf2ba (CC BY 4.0) + Madar additions |
| `word_guess_answers.json` | answers: 570 × 4, 471 × 5, 215 × 6 letters, all vowelled | own |
| `word_search_themes.json` | 29 themes, 727 words (fruits, cities, prophets, colours, surahs …) | own |
| `crossword_clues.json` | 565 original Arabic clue/answer pairs (212 easy, 260 medium, 93 hard) | own |
| `islamic_quiz.json` | 377 questions (ar + en): quran 105, prophets 100, seerah 51, pillars 48, manners 47, companions 26; levels 147 / 191 / 39; 233 Quran, 152 hadith, 42 mushaf-structure citations | own wording; facts from the cited Quran / hadith |
| `countries.json` | 193 UN members + 2 observers (Holy See, Palestine): names, capitals, other capitals, continent, code-drawn flag spec (763 elements) | own compilation |
| `typing_passages.json` | 203 passages: 90 original, 20 fully vowelled, 51 proverbs / public-domain verses, 42 Quran references | own; proverbs & verse public domain; Quran by reference to the bundled Tanzil text |

Hadith numbers were verified (not bundled) against fawazahmed0/hadith-api
@ df57907 (The Unlicense): al-Bukhari standard numbering, Muslim by Muhammad
Fu'ad 'Abd al-Baqi, at-Tirmidhi and Abu Dawud standard numbering.

## How accuracy is enforced

* **Quiz citations.** Every question has ≥ 1 source. A Quran source names
  sura:ayah and a key phrase that must occur in that ayah's letter skeleton in
  `assets/quran/quran-uthmani.txt` (checked by the build *and* by
  `content_validation_test.dart`). A hadith source names collection + number
  + key phrase, checked by the build against the hadith editions above. A
  "meta" source is a fact of the mushaf's structure (ayah counts,
  Makki/Madani, juz starts, 604 pages, the longest ayah …) recomputed from
  `quran-meta.json` / the text by the build and the tests.
* **Scope.** Quran facts, prophets, seerah, pillars, companions and manners –
  consensus topics only. No questions on contested fiqh (rak'at details,
  what breaks a fast, madhhab differences), on the number of sajdat or on
  which surah was revealed last.
* **Quran text is never altered or copied** into game assets: typing
  passages store references; the text is read verbatim at run time. Ayah 1
  of a sura (Tanzil prefixes the basmala) is avoided except Al-Fatihah.
* **Family-friendly words.** Blocked words are removed from the lexicon and
  refused as guesses; sensitive words are never answers and never appear by
  accident in generated grids (the word-search generator re-rolls filler
  letters until no blocked / sensitive sequence of 3+ letters reads in any of
  the 8 directions).

## Arabic rules (documented in code)

* Letters are counted without tashkeel/tatweel; `ArabicText.plain` stores,
  `fold` compares (ا/أ/إ/آ one letter, ى = ي, ة = ه), `lookupKey`
  additionally merges ؤ ئ with ء for dictionary lookups.
* **Word Guess ("Mufrada" – suggested original name, مُفْرَدة):** feedback on
  folded letters; hamza seats ء ؤ ئ stay distinct letters; standard two-pass
  duplicate handling; hard mode; keyboard colours per folded class; daily
  word = seeded permutation per cycle from day 0 = 2026-01-01 (no repeat
  within a cycle, same word for everyone on a date); endless mode avoids
  recent words; stats with daily streaks.
* **Grids (Word Search, Crossword)** use logical columns: column 0 is the
  start of a line = the right edge in RTL; "forward"/"across" = right to
  left on screen (`visualColumn` maps for LTR painters). Flags, by contrast,
  are absolute (hoist on the left) and never mirrored.
* **Typing:** a unit is a letter (or letter + harakat in strict mode),
  space or punctuation; tashkeel never inflates WPM. Lenient mode forgives
  hamza-seat / alef / taa-marbuta slips (use it for Quran passages, whose
  Uthmani spelling – e.g. الصلوٰة, لَآ – differs from everyday spelling).

## Assumptions

* Continents follow the UN M49 regions (Cyprus, the Caucasus and Türkiye in
  Asia; Russia in Europe); Central America and the Caribbean are in North
  America.
* Capitals as of 2026-09: Astana, Gitega, Sri Jayawardenepura Kotte,
  Naypyidaw, Dodoma, Yamoussoukro, Porto-Novo, Sucre, Amsterdam, Pretoria and
  Bern are the primary capitals, with the other seats in `altCapitals`.
* Flags: current official designs (Syria 2025, Mauritania 2017, Honduras
  2022 turquoise, Kyrgyzstan 2023); coats of arms, eagles, texts other than
  the Saudi shahada and Iraqi takbir are approximated by simple shapes.
* Word-frequency ranks reflect Wikipedia (encyclopaedic MSA); everyday
  words rank lower than in speech.

## Please review before shipping

1. **Political / recent facts** (`review: true` or `capitalDisputed` in
   countries.json):
   * Israel and Palestine – both have `capitalDisputed` (Jerusalem) and are
     excluded from capital questions; Palestine is listed as a UN observer
     state with Ramallah as administrative centre. Confirm this matches
     Madar's editorial stance.
   * Afghanistan – drawn as the black-red-green tricolour still used at the
     UN; the authorities in Kabul use a white shahada flag.
   * Equatorial Guinea – capital set to Ciudad de la Paz (decree of January
     2026), Malabo kept as an alternative. Verify.
   * Indonesia – Jakarta kept (Nusantara pending a presidential decree).
2. **Hadith gradings:** at-Tirmidhi 413 (first deed judged is prayer) and
   2317 ("leaving what does not concern him", also Nawawi's 40 #12) carry
   mixed gradings in the edition (Sahih/Hasan by al-Albani, Da'if by one
   grader). Keep or drop per your scholarly reviewer.
3. **Vowelled forms** (answers, themes, crossword displays, vowelled typing
   passages) were written by hand for Madar – a native reviewer should
   spot-check tashkeel. A few answers are everyday rather than strict MSA
   (تعبان، شوربة، بوظة).
4. **Sensitive-topic questions:** e.g. "Which uncle protected the Prophet ﷺ
   and was angered for him?" (Abu Talib, Bukhari 3883); "Who made the calf"
   (as-Samiri). Accurate and sourced, but review tone for your audience.
5. **Proxy facts:** "Which prophet is named in the most ayat?" (Musa) counts
   ayat containing each name in the bundled text; the Makki/Madani and
   ayah-count questions follow Tanzil's metadata (Kufan count used by Hafs).
6. **Verse attribution:** the al-Shabbi line uses the wording
   «ومن لا يحب صعود الجبال …» (a popular variant reads «ومن يتهيّب …»).
7. **Flag drawings** are approximations – review them visually once a
   painter exists (Brazil's stars, coats of arms, Kenya's shield, Nepal's
   outline).
8. **Licence of the lexicon:** frequency data is MIT-licensed statistics of
   Arabic Wikipedia (whose prose is CC BY-SA); only word forms and ranks are
   used. Confirm with legal if needed.
9. `lib/app/licenses.dart` (not owned here) should list
   `assets/licenses/games_words_credits.txt` on Settings › About.

### Sample of quiz questions for review

| id | category | level | question | answer | source |
|---|---|---|---|---|---|
| qur-43cb6862 | quran | 1 | كم عدد آيات سورة الملك؟ | ٣٠ | mushaf structure |
| qur-cff77431 | quran | 1 | ما السورة التي ذكرت أصحاب الفيل؟ | الفيل | Quran 105:1 |
| qur-843281af | quran | 2 | بماذا تحدّى القرآن الكريم المكذبين في سورة البقرة؟ | أن يأتوا بسورة من مثله | Quran 2:23 |
| qur-d93253f5 | quran | 2 | أي هذه السور مدنية؟ | النور | mushaf structure |
| pro-d1900ee6 | prophets | 1 | أي نبي صنع السفينة بأمر الله؟ | نوح | Quran 11:38 |
| pro-95e14b0f | prophets | 2 | أي نبي دعا: «رب لا تذر على الأرض من الكافرين ديارًا»؟ | نوح | Quran 71:26 |
| pro-f869efdc | prophets | 3 | ما الذي دلّ الجن على موت سليمان عليه السلام؟ | دابة الأرض تأكل منسأته | Quran 34:14 |
| pro-cddec36d | prophets | 1 | ما آية صالح عليه السلام لقومه؟ | الناقة | Quran 7:73 |
| see-36a99885 | seerah | 2 | أين بايع الصحابة النبي ﷺ بيعة الرضوان كما في سورة الفتح؟ | تحت الشجرة | Quran 48:18 |
| see-40196a15 | seerah | 2 | ما المعجزة التي ذكرتها سورة القمر في أولها؟ | انشقاق القمر | Quran 54:1; Bukhari 3637 |
| see-0efbd26f | seerah | 1 | كم كان عمر النبي ﷺ حين تُوفّي؟ | ثلاثًا وستين سنة | Bukhari 3902 |
| pil-8dc777eb | pillars | 3 | أي الأعمال أول ما يُحاسب به العبد يوم القيامة؟ | الصلاة | Tirmidhi 413 |
| pil-27a20dd2 | pillars | 2 | متى أمر النبي ﷺ أن تؤدّى زكاة الفطر؟ | قبل خروج الناس إلى صلاة العيد | Bukhari 1503 |
| pil-ade7cd79 | pillars | 1 | أي هذه من أركان الإسلام؟ | إيتاء الزكاة | Bukhari 8 |
| man-a4b59b06 | manners | 1 | من كان يؤمن بالله واليوم الآخر فليقل خيرًا أو ... | ليصمت | Bukhari 6018 |
| man-bbb7ee99 | manners | 2 | من حسن إسلام المرء ... | تركه ما لا يعنيه | Tirmidhi 2317 |
| man-29f938a5 | manners | 2 | أكمل الحديث: «دع ما يريبك إلى ...» | ما لا يريبك | Tirmidhi 2518 |
| com-14bd3094 | companions | 2 | أي خليفة أرسل إلى حفصة يطلب الصحف ونسخ منها المصاحف إلى الأمصار؟ | عثمان بن عفان | Bukhari 4987 |
| com-1bdb0df7 | companions | 2 | لمن قال النبي ﷺ: «أما ترضى أن تكون مني بمنزلة هارون من موسى»؟ | علي بن أبي طالب | Bukhari 3706 |
| com-bee278b8 | companions | 3 | لأي صحابي قال النبي ﷺ: «إن الله أمرني أن أقرأ عليك»؟ | أبي بن كعب | Bukhari 4959 |

## Updating content

Edit `assets/games/source/content_*.py`, run the build (it downloads the
pinned sources once into a temp cache and fails on any broken check), then
run `flutter test test/features/cinema/rules/words`. Changing the Word Guess
answer list re-deals future daily words (see `WordGuessBank.dailySalt`).
Question ids are hashes of the Arabic question text, so editing a question's
wording gives it a new id (players may see it again).
