/// The default questions of "How well do you know me?" (قديش بتعرفني؟).
///
/// Sixty generic, respectful questions in six categories – favourites,
/// habits, memories, dreams, personality and "which would I choose" – asked
/// in the first person by the player they are about ("What's my favourite
/// dish?"), so the Arabic never has to guess a gender. No intimate
/// questions, nothing that asks for personal data (numbers, addresses,
/// health, money) and no facts about anyone: the answers only ever exist in
/// the round being played. Every question and category can be edited,
/// reordered or removed; these are only the starting set.
library;

import 'specials_bounds.dart';

/// A default category.
final class KnowMeDefaultCategory {
  const KnowMeDefaultCategory(this.id, this.name, this.icon);

  final String id;
  final BiText name;

  /// Key of the category's icon ([KnowMeCatalogue.iconKeys]).
  final String icon;
}

/// A default question.
final class KnowMeDefaultQuestion {
  const KnowMeDefaultQuestion(this.id, this.category, this.text);

  final String id;
  final String category;
  final BiText text;
}

abstract final class KnowMeCatalogue {
  static const String favourites = 'fav';
  static const String habits = 'habits';
  static const String memories = 'memories';
  static const String dreams = 'dreams';
  static const String personality = 'me';
  static const String choose = 'choose';

  /// Icon keys a category can wear (the UI maps them to icons).
  static const List<String> iconKeys = [
    'heart',
    'sun',
    'album',
    'plane',
    'spark',
    'split',
    'star',
    'home',
    'book',
    'coffee',
    'leaf',
    'moon',
  ];

  static const List<KnowMeDefaultCategory> categories = [
    KnowMeDefaultCategory(favourites, BiText('المفضّلات', 'Favourites'), 'heart'),
    KnowMeDefaultCategory(habits, BiText('عاداتي', 'My habits'), 'sun'),
    KnowMeDefaultCategory(memories, BiText('ذكريات', 'Memories'), 'album'),
    KnowMeDefaultCategory(dreams, BiText('أحلام وخطط', 'Dreams & plans'), 'plane'),
    KnowMeDefaultCategory(personality, BiText('شخصيّتي', 'Who I am'), 'spark'),
    KnowMeDefaultCategory(choose, BiText('أيّهما أختار؟', 'Which would I pick?'), 'split'),
  ];

  static const List<KnowMeDefaultQuestion> questions = [
    // Favourites.
    KnowMeDefaultQuestion('fav.dish', favourites, BiText('ما طبقي المفضّل؟', "What's my favourite dish?")),
    KnowMeDefaultQuestion('fav.drink', favourites, BiText('ما مشروبي المفضّل؟', "What's my favourite drink?")),
    KnowMeDefaultQuestion('fav.dessert', favourites, BiText('ما الحلوى التي لا أقاومها؟', 'Which dessert can I never resist?')),
    KnowMeDefaultQuestion('fav.colour', favourites, BiText('ما لوني المفضّل؟', "What's my favourite colour?")),
    KnowMeDefaultQuestion('fav.season', favourites, BiText('ما أحبّ فصول السنة إليّ؟', 'Which season of the year do I love most?')),
    KnowMeDefaultQuestion('fav.fruit', favourites, BiText('ما فاكهتي المفضّلة؟', "What's my favourite fruit?")),
    KnowMeDefaultQuestion('fav.surah', favourites, BiText('ما السورة التي أحبّ أن أستمع إليها؟', 'Which surah do I love listening to?')),
    KnowMeDefaultQuestion('fav.time', favourites, BiText('ما أحبّ أوقات اليوم إليّ؟', 'Which time of day do I like best?')),
    KnowMeDefaultQuestion('fav.place', favourites, BiText('ما مكاني المفضّل للاسترخاء؟', "Where's my favourite place to relax?")),
    KnowMeDefaultQuestion('fav.game', favourites, BiText('ما لعبتي المفضّلة حين نلعب معًا؟', 'Which game do I like best when we play together?')),
    // Habits.
    KnowMeDefaultQuestion('habits.morning', habits, BiText('ما أوّل ما أفعله بعد أن أستيقظ؟', "What's the first thing I do after waking up?")),
    KnowMeDefaultQuestion('habits.tea', habits, BiText('كيف أحبّ شايي أو قهوتي؟', 'How do I like my tea or coffee?')),
    KnowMeDefaultQuestion('habits.stress', habits, BiText('ماذا أفعل عادةً حين أشعر بالضغط؟', 'What do I usually do when I feel stressed?')),
    KnowMeDefaultQuestion('habits.dayOff', habits, BiText('كيف أحبّ أن أقضي يوم العطلة؟', 'How do I like to spend a day off?')),
    KnowMeDefaultQuestion('habits.sleep', habits, BiText('في أيّ ساعة أنام عادةً؟', 'What time do I usually fall asleep?')),
    KnowMeDefaultQuestion('habits.neverWithout', habits, BiText('ما الشيء الذي لا أخرج من البيت من دونه؟', "What's the one thing I never leave home without?")),
    KnowMeDefaultQuestion('habits.snack', habits, BiText('ما وجبتي الخفيفة المفضّلة في السهرة؟', "What's my go-to evening snack?")),
    KnowMeDefaultQuestion('habits.chore', habits, BiText('ما المهمّة المنزلية التي لا أمانع القيام بها؟', "Which household chore don't I mind doing?")),
    KnowMeDefaultQuestion('habits.car', habits, BiText('إلامَ أستمع عادةً في السيارة؟', 'What do I usually listen to in the car?')),
    KnowMeDefaultQuestion('habits.market', habits, BiText('ما أوّل قسم أتّجه إليه في السوق؟', 'Which aisle do I head to first at the supermarket?')),
    // Memories.
    KnowMeDefaultQuestion('memories.firstMeeting', memories, BiText('أين كان أوّل لقاء بيننا؟', 'Where did we first meet?')),
    KnowMeDefaultQuestion('memories.childhoodGame', memories, BiText('ما لعبتي المفضّلة في طفولتي؟', 'What was my favourite game as a child?')),
    KnowMeDefaultQuestion('memories.bestTrip', memories, BiText('ما أجمل رحلة قمنا بها معًا في رأيي؟', 'Which trip together was the best, in my opinion?')),
    KnowMeDefaultQuestion('memories.funny', memories, BiText('ما الموقف الذي يُضحكني كلّما تذكّرته؟', 'Which moment makes me laugh every time I remember it?')),
    KnowMeDefaultQuestion('memories.firstGift', memories, BiText('ما أوّل هديّة أهديتني إيّاها؟', 'What was the first gift you gave me?')),
    KnowMeDefaultQuestion('memories.school', memories, BiText('ما المادّة التي كنت أحبّها في المدرسة؟', 'Which school subject did I love?')),
    KnowMeDefaultQuestion('memories.proud', memories, BiText('ما الإنجاز الذي أفخر به أكثر من غيره؟', 'Which achievement am I proudest of?')),
    KnowMeDefaultQuestion('memories.meal', memories, BiText('ما أطيب وجبة تناولناها معًا في رأيي؟', "What's the best meal we've had together, in my opinion?")),
    KnowMeDefaultQuestion('memories.eid', memories, BiText('ما أجمل ذكرى عيد عندي؟', "What's my favourite Eid memory?")),
    KnowMeDefaultQuestion('memories.grownUp', memories, BiText('ماذا كنت أريد أن أصبح حين أكبر؟', 'What did I want to be when I grew up?')),
    // Dreams and plans.
    KnowMeDefaultQuestion('dreams.country', dreams, BiText('ما البلد الذي أحلم بزيارته؟', 'Which country do I dream of visiting?')),
    KnowMeDefaultQuestion('dreams.skill', dreams, BiText('ما المهارة التي أتمنّى أن أتعلّمها؟', 'Which skill do I wish I could learn?')),
    KnowMeDefaultQuestion('dreams.home', dreams, BiText('كيف يبدو بيت أحلامي؟', 'What does my dream home look like?')),
    KnowMeDefaultQuestion('dreams.journey', dreams, BiText('ما الرحلة التي أتمنّى أن نقوم بها معًا؟', 'Which journey do I hope we will make together?')),
    KnowMeDefaultQuestion('dreams.book', dreams, BiText('ما الكتاب الذي أريد أن أقرأه قريبًا؟', 'Which book do I want to read soon?')),
    KnowMeDefaultQuestion('dreams.project', dreams, BiText('ما المشروع الذي أحلم أن أبدأه يومًا؟', 'What project do I dream of starting one day?')),
    KnowMeDefaultQuestion('dreams.perfectDay', dreams, BiText('كيف يكون يومي المثالي؟', 'What would my perfect day look like?')),
    KnowMeDefaultQuestion('dreams.hobby', dreams, BiText('ما الهواية التي أريد أن أجرّبها؟', 'Which hobby do I want to try?')),
    KnowMeDefaultQuestion('dreams.car', dreams, BiText('ما السيارة التي أحلم بها؟', "What's my dream car?")),
    KnowMeDefaultQuestion('dreams.wish', dreams, BiText('لو تحقّقت لي أمنية واحدة الآن، فماذا تكون؟', 'If one wish of mine came true now, what would it be?')),
    // Who I am.
    KnowMeDefaultQuestion('me.superpower', personality, BiText('لو امتلكت قدرة خارقة، فأيّها أختار؟', 'If I could have one superpower, which would I pick?')),
    KnowMeDefaultQuestion('me.littleFear', personality, BiText('ما الشيء الصغير الذي يُخيفني؟', 'What little thing scares me?')),
    KnowMeDefaultQuestion('me.petPeeve', personality, BiText('ما الذي يُزعجني بسرعة؟', 'What gets on my nerves quickly?')),
    KnowMeDefaultQuestion('me.compliment', personality, BiText('ما أجمل مديح يسعدني سماعه؟', 'Which compliment makes me happiest?')),
    KnowMeDefaultQuestion('me.animal', personality, BiText('لو كنت حيوانًا، فأيّ حيوان أكون؟', 'If I were an animal, which one would I be?')),
    KnowMeDefaultQuestion('me.laugh', personality, BiText('ما الذي يُضحكني دائمًا؟', 'What always makes me laugh?')),
    KnowMeDefaultQuestion('me.calm', personality, BiText('ما الذي يُهدّئني حين أغضب؟', "What calms me down when I'm upset?")),
    KnowMeDefaultQuestion('me.threeWords', personality, BiText('بأيّ ثلاث كلمات أصف نفسي؟', 'Which three words would I use to describe myself?')),
    KnowMeDefaultQuestion('me.talent', personality, BiText('ما موهبتي الخفيّة؟', "What's my hidden talent?")),
    KnowMeDefaultQuestion('me.gift', personality, BiText('ما الهديّة التي تُفرحني أكثر من غيرها؟', 'What kind of gift makes me happiest?')),
    // Which would I pick?
    KnowMeDefaultQuestion('choose.seaMountain', choose, BiText('أيّهما أختار: البحر أم الجبل؟', 'Which would I pick: the sea or the mountains?')),
    KnowMeDefaultQuestion('choose.teaCoffee', choose, BiText('أيّهما أختار: الشاي أم القهوة؟', 'Which would I pick: tea or coffee?')),
    KnowMeDefaultQuestion('choose.sunriseSunset', choose, BiText('أيّهما أحبّ: الشروق أم الغروب؟', 'Which do I love more: sunrise or sunset?')),
    KnowMeDefaultQuestion('choose.winterSummer', choose, BiText('أيّهما أحبّ: الشتاء أم الصيف؟', 'Which do I love more: winter or summer?')),
    KnowMeDefaultQuestion('choose.inOut', choose, BiText('أيّهما أختار: سهرة في البيت أم خروجًا؟', 'Which would I pick: an evening in or an evening out?')),
    KnowMeDefaultQuestion('choose.sweetSavoury', choose, BiText('أيّهما أختار: الحلو أم المالح؟', 'Which would I pick: sweet or savoury?')),
    KnowMeDefaultQuestion('choose.bookFilm', choose, BiText('أيّهما أختار: كتابًا أم فيلمًا وثائقيًا؟', 'Which would I pick: a book or a documentary?')),
    KnowMeDefaultQuestion('choose.cityCountry', choose, BiText('أيّهما أختار: المدينة أم الريف؟', 'Which would I pick: the city or the countryside?')),
    KnowMeDefaultQuestion('choose.cookOrder', choose, BiText('أيّهما أختار: نطبخ في البيت أم نطلب طعامًا؟', 'Which would I pick: cooking at home or ordering in?')),
    KnowMeDefaultQuestion('choose.planSurprise', choose, BiText('أيّهما أحبّ: خطّة مرتّبة أم مفاجأة؟', 'Which do I love more: a careful plan or a surprise?')),
  ];

  static final Map<String, KnowMeDefaultQuestion> _questions = {for (final q in questions) q.id: q};
  static final Map<String, KnowMeDefaultCategory> _categories = {for (final c in categories) c.id: c};

  static KnowMeDefaultQuestion? question(String id) => _questions[id];

  static KnowMeDefaultCategory? category(String id) => _categories[id];

  static bool isDefaultQuestion(String id) => _questions.containsKey(id);

  static bool isDefaultCategory(String id) => _categories.containsKey(id);
}
