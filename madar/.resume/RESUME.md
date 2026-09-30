# Resume point (usage-limit checkpoint 07:20 UTC; refreshed after a container restart)

All agents were stopped deliberately at ~95 % of the 5-hour usage limit.
This commit is a WORK-IN-PROGRESS checkpoint (`[skip ci]`): several
packages below are PARTIAL and may not compile or pass tests yet. Nothing
here is "done" unless listed as done. Last verified, CI-green commit:
08f9cb1 (APK madar-apk-10 = c8ea1af + foundation; feature APK: madar-apk-9).

## Done and verified before this checkpoint
- Phases 0–3 (pushed, CI green).
- Phase 4 builders finished (not yet integrated/reviewed):
  meds (lib/features/health/meds), record (lib/features/health/record),
  wellbeing (lib/features/health/wellbeing).

## State (updated after Phase 4 shipped)
If a run below was interrupted, re-run it with
"a previous attempt left partial work in your folder: review it, verify
everything, finish what is missing; do not assume anything works".
Workflow scripts: scratchpad/*.js and ~/.claude/projects/*/workflows/scripts/.

| Work | Owned paths | State |
|---|---|---|
| Health (meds, record, wellbeing, hub) | lib/features/health/** | DONE, shipped 375be67 (APK #12) |
| Hotfix: auto fingerprint + orbit reset view | lock, orbit | DONE, shipped e2aa71a (APK #11) |
| Money ledger / budget / goals builders | lib/features/money/{ledger,budget,goals} | built + verified |
| Money integration + review | routing, app, settings, orbit planet, money/hub, a9_money_hub.json | RUNNING (phase5_integrate.js, wf_ad90daa6-564) |
| Work, Family, Travel, Growth, Body, Custom Modules builders | lib/features/{work,family,travel,growth,body,custom_modules} | built + verified; integration NOT started |
| Game rules: cards, board, puzzles, arcade, words/quiz | lib/features/cinema/rules/** | built + verified |
| Jordanian rules: board (dama, tawla ×3, dominoes, ludo) | cinema/rules/board/** | DONE (561 tests); open detail questions in board/RULES.md §9.2 |
| Jordanian rules: cards (Tarneeb/41, Trix/Complex, Hand/partners, Konkan, Basra, Baloot) + new Solitaire, Blackjack | cinema/rules/cards/** | DONE (977 tests); open owner questions in cards/RULES.md 'Still open' |
| Deps webview_flutter 4.14.1, nearby_connections 4.3.0, firebase_core/auth/database | pubspec | CI probe 008ccec GREEN (run #13); added to main pubspec |
| Film Reel Engine (Phase 7) | lib/features/cinema/engine etc., shaders/cinema | RUNNING (phase7_engine.js, wf_4495c71d-7d5) |
| Data export + encrypted backup | lib/features/data, d1_data.json | built + verified (report in scratchpad/phase9_packages.md); needs routing |
| AI chat (own Anthropic/OpenAI keys) | lib/features/ai_chat, d4_ai_chat.json | built + security-reviewed (163 tests); needs routes /ai, /ai/chats, /settings/ai, AskAi entries, AiKeyStore.deleteAll() in delete-all-data |
| Together Mode core + couple specials | lib/features/together, e1_together.json | RUNNING (wf_ab7dcc7b-712) |
| Saved Games (web games by URL, WebView) | lib/features/saved_games, e3_saved_games.json, android .../savedgames | built + reviewed (Dart 117 tests; Kotlin channel type-checked, registered in MainActivity); needs route + SavedGamesShelf in the cinema hall + savedGamesLegacyImportProvider read once |
| Home-screen widgets | lib/features/widgets, android .../widgets, res widget_*, e2_widgets.json | built + reviewed (89 tests, kotlinc type-check OK); manifest receivers + MainActivity register line already added; needs watchWidgetServices(ref) in AppServices, clearWidgetData() in delete-all, /settings/widgets route |
| Global search | lib/features/search, d2_search.json | built + reviewed (26 findings fixed, 183 tests); needs route + opener + launcher |
| Notification center | lib/features/notification_center, d3_notifications.json | built + safety-reviewed (24 fixes, 138 tests); needs wiring per scratchpad/phase9_packages.md (gate inside Suspending wrapper, meds background gate, AdhanEventHub.withholds, AppServices watch, reserve ids 160000–160999) |

## Container restart #2 (09:28 UTC)
All six runs were resumed with resumeFromRunId (completed agents replay from cache; interrupted ones re-run with a RESUMING note + strict memory rule): money review wf_ad90daa6-564 (scratchpad/phase5_integrate.js), engine wf_4495c71d-7d5 (scratchpad/phase7_engine.js; hall no longer builds Saved Games), cards wf_94413da5-0be (scratchpad/jordan_cards.js), together wf_ab7dcc7b-712, widgets wf_54ac8044-8f2, saved games wf_1fb242c0-188.

## Owner decisions
- EveryAyah recitations: approved (stream on play / download on request; credited).
- Card and board games: Jordanian rules as defaults.

## Next
1. Money integration green → snapshot build → APK.
2. Life integration + review (shared files one at a time); register
   assets/licenses/games_words_credits.txt in lib/app/licenses.dart.
3. Wire export/backup, search, notification center (Phase 9), then AI chat,
   widgets; Tier 1 games on the engine; Tier 2 UIs in batches of 5.
4. Delete this .resume folder once everything is integrated and green.
