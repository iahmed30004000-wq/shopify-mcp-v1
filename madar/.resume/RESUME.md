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
| Money integration + review | routing, app, settings, orbit planet, money/hub, a9_money_hub.json | DONE (review fixes: net worth w/ archived jars, rebase keeps budget, goals decimals, AA contrast, 96 screenshots) |
| Money APK release | release commit 6bd956e | DONE – CI run #14 green, artifact madar-apk-14 (id 11105002945) sent to the owner |
| Integration plans (read-only) | scratchpad/integration_plan_{life,system}.md, integration_conflicts.md | DONE |
| Life + System integration (Life integrate → 2 finders → fix → System integrate → 2 finders → fix) | shared files (routing, app, settings, home, orbit, manifest) | RUNNING again (wf_73ea237d-651); earlier attempt was mid-way (partial edits on disk, nothing cached). Resume: add a RESUMING note to the life:integrate prompt in scratchpad/life_system_integration.js, then Workflow({scriptPath}) |
| Work, Family, Travel, Growth, Body, Custom Modules builders | lib/features/{work,family,travel,growth,body,custom_modules} | built + verified; integration NOT started |
| Game rules: cards, board, puzzles, arcade, words/quiz | lib/features/cinema/rules/** | built + verified |
| Jordanian rules: board (dama, tawla ×3, dominoes, ludo) | cinema/rules/board/** | DONE (561 tests); open detail questions in board/RULES.md §9.2 |
| Jordanian rules: cards (Tarneeb/41, Trix/Complex, Hand/partners, Konkan, Basra, Baloot) + new Solitaire, Blackjack | cinema/rules/cards/** | DONE (977 tests); open owner questions in cards/RULES.md 'Still open' |
| Deps webview_flutter 4.14.1, nearby_connections 4.3.0, firebase_core/auth/database | pubspec | CI probe 008ccec GREEN (run #13); added to main pubspec |
| Film Reel Engine (Phase 7) | lib/features/cinema/engine, hall, shaders/cinema | DONE: core, fx, rig, audio, stage+hall, critic (reports: scratchpad/phase7_engine_packages.md). Needs wiring: /cinema route → CinemaHallScreen, SavedGames route/tile; full-suite chunks before the next release |
| Data export + encrypted backup | lib/features/data, d1_data.json | built + verified (report in scratchpad/phase9_packages.md); needs routing |
| AI chat (own Anthropic/OpenAI keys) | lib/features/ai_chat, d4_ai_chat.json | built + security-reviewed (163 tests); needs routes /ai, /ai/chats, /settings/ai, AskAi entries, AiKeyStore.deleteAll() in delete-all-data |
| Together Mode core + couple specials | lib/features/together, e1_together.json | DONE (core reviewed: 17 fixes; specials: know-me quiz, weekly challenge, co-op goal; 162+ tests) – needs wiring later (route, settings tile, SpecialsRepository.allKeys in delete-all) |
| Together transports (Nearby + optional Firebase online) + FLAG_SECURE channel | lib/features/together/{transport,pairing}, e4_together_net.json, android .../together | DONE + reviewed (226 tests; 3 real defects fixed incl. open-database guard). Needs wiring: togetherTransportOverrides(), manifest Nearby permissions (text in scratchpad/phase10_packages.md '# together transports' → manifest_needs), turn-alert id block 170000–170999 documented, together route/settings tile, SpecialsRepository.allKeys + together keys in delete-all |
| Saved Games (web games by URL, WebView) | lib/features/saved_games, e3_saved_games.json, android .../savedgames | built + reviewed (Dart 117 tests; Kotlin channel type-checked, registered in MainActivity); needs route + SavedGamesShelf in the cinema hall + savedGamesLegacyImportProvider read once |
| Home-screen widgets | lib/features/widgets, android .../widgets, res widget_*, e2_widgets.json | built + reviewed (89 tests, kotlinc type-check OK); manifest receivers + MainActivity register line already added; needs watchWidgetServices(ref) in AppServices, clearWidgetData() in delete-all, /settings/widgets route |
| Global search | lib/features/search, d2_search.json | built + reviewed (26 findings fixed, 183 tests); needs route + opener + launcher |
| Notification center | lib/features/notification_center, d3_notifications.json | built + safety-reviewed (24 fixes, 138 tests); needs wiring per scratchpad/phase9_packages.md (gate inside Suspending wrapper, meds background gate, AdhanEventHub.withholds, AppServices watch, reserve ids 160000–160999) |

## Container restart #2 (09:28 UTC)
All six runs were resumed with resumeFromRunId (completed agents replay from cache; interrupted ones re-run with a RESUMING note + strict memory rule): money review wf_ad90daa6-564 (scratchpad/phase5_integrate.js), engine wf_4495c71d-7d5 (scratchpad/phase7_engine.js; hall no longer builds Saved Games), cards wf_94413da5-0be (scratchpad/jordan_cards.js), together wf_ab7dcc7b-712, widgets wf_54ac8044-8f2, saved games wf_1fb242c0-188.

## WRAP-UP FOR THE OWNER'S PREVIEW (2026-10-07, owner: «finish the right things, then stop until next week»)
Running now:
1. scratchpad/wrapup_life_cinema.js (wf_2352f0e4-20e): Life integrate (resume) → 2 finders → fix → wire /cinema, /cinema/game/:id, /saved-games + Growth hub card.
2. scratchpad/wrapup_games.js (wf_88b3ab12-7ae): Metropolis Machine critic; Flappy Orbit build (resume, ~4k lines on disk) → critic.
Then: release prep (snapshot + full suite through scratchpad/ft, exclude unfinished caravan_dash/noir/neon if they break analyze) → CI APK → send link → STOP.
NEXT WEEK: system integration (search, notification center + gate, backup/export, AI chat, widgets, Together wiring + manifest Nearby permissions) via life_system_integration.js's System part; Caravan Dash (partial ~1.2k lines), Noir Rooftops, Neon Souk Racer; then Tier 2 game UIs in batches of 5.

## Session limit hit 2026-10-07 ~04:30 (reset 06:00); resumed 06:06
- Life+System integration: relaunched fresh again (RESUMING note; ~5 h of partial work on disk and committed).
- Tier 1 games: build:metropolis_machine DONE (cached); caravan_dash / flappy_orbit / noir_rooftops / neon_souk_racer builds and the MM critic re-run with RESUMING notes via resumeFromRunId wf_ab3e4411-e23 (script copy scratchpad/tier1_games.js).

## Weekly usage limit hit 2026-10-02 22:41 (reset Oct 6); resumed 2026-10-07 01:10
- Life+System integration: relaunched fresh (wf_8e85fa56-570); the earlier 2-hour partial work (life_route_pages, life_services, life_hubs, life_settings_section …) is on disk and committed.
- Engine: audio + hall DONE (reports in scratchpad/phase7_engine_packages.md); critic re-run via resumeFromRunId wf_4495c71d-7d5.
- Tier 1 games started (owner: «والالعاب نفسها مع المحرك»): wf_ab3e4411-e23, script copy scratchpad/tier1_games.js – flappy_orbit, metropolis_machine, caravan_dash, noir_rooftops, neon_souk_racer, each build → critic, 2 at a time; each game owns games/<id>/**, test/features/cinema/games/<id>/**, c5–c9 ARB parts.

## Container restart #3 (20:33 UTC, three agents running tests at once). All test runs now go through scratchpad/ft (flock-serialised, -j 1, memory wait). Life+System integration relaunched fresh (little lost: its work was in 47b2644); engine audio+hall re-run with resumeFromRunId.

## Resumed 2026-10-02 on the owner's «كمل»: Life+System integration (new run wf_73ea237d-651), Together transports review (wf_7135f615-749), engine audio+hall (wf_4495c71d-7d5) – all RUNNING with RESUMING notes.

## Talking to the owner (standing rule)
Every decision or report to the owner: plain Jordanian Arabic, no technical words, one concrete example per item. Decisions: think first, ask only what needs him, put the BEST answer first with a detailed why, then every other option with details, mark the current one, short answer format. Full rule + example in /CLAUDE.md.

## Owner decisions
- EveryAyah recitations: approved (stream on play / download on request; credited).
- Card and board games: Jordanian rules as defaults.
- 2026-10-02: owner accepted all 9 proposed rule defaults (Tarneeb all-pass same dealer, Trix partner double no bonus, Hand joker 15 / printed jokers only, Konkan own game to 301, Basra 7♦ sweeps, Ludo pairs captured, Tawla 31 contrary layout, dominoes lock ends round). No code change needed – all were already the defaults.

## Next
1. Money integration green → snapshot build → APK.
2. Life integration + review (shared files one at a time); register
   assets/licenses/games_words_credits.txt in lib/app/licenses.dart.
3. Wire export/backup, search, notification center (Phase 9), then AI chat,
   widgets; Tier 1 games on the engine; Tier 2 UIs in batches of 5.
4. Delete this .resume folder once everything is integrated and green.
