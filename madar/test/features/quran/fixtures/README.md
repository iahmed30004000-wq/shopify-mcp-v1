Recorded Quran.com API v4 answers (shapes as documented at
https://api-docs.quran.com – the API is not reachable from the build machine,
so these were written from the documented shapes and must be re-recorded
against the live API on a device):

- qurancom_tajweed_chapter_1.json – GET /quran/verses/uthmani_tajweed?chapter_number=1
- qurancom_tajweed_page_1.json – GET /quran/verses/uthmani_tajweed?page_number=1 (no verse_key)
- qurancom_translation_20_chapter_1.json – GET /quran/translations/20?chapter_number=1&fields=verse_key
- qurancom_translation_20_page_1.json – GET /quran/translations/20?page_number=1 (no verse_key)

Translation: Saheeh International (resource 20), used here only as a test
fixture of Al-Fatihah.
