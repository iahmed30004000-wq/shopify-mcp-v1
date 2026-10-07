# Madar Cinema – the Film Reel Engine

50 original games on one procedural engine (Flame 1.38). Every pixel is code,
every note is synthesised: **zero image or audio files**. Each game is an
homage to films of its era: 1920s silent, 1930s rubber-hose cartoons, 1940s
noir, 1950s Technicolor, 1970s grindhouse, 1980s VHS.

**Quality bar:** a hand-inked 1930s cartoon look (the style Cuphead
popularised, at the level of the web game "Double Feature"): film grain,
halftone shading, stage curtains and footlights framing the play area,
expressive animated bosses, a polished HUD. Fun and polished, never
"informational".

Games import one file: `package:madar/features/cinema/engine/cinema_engine.dart`.

---

## 1. Folder layout and ownership

Work in parallel **without touching each other's files**. Everything outside
your row is read-only for you. Need a change elsewhere? See §10.

| Path | Owner | What |
|---|---|---|
| `engine/core/**` | **architect** | Contracts (interfaces, data types, uniform writers, CinemaGame, tweens). Frozen, additive changes only (§10). |
| `engine/cinema_engine.dart`, `engine/cinema_game_view.dart` | architect | Barrel, standard kit, providers, the Flutter host widget. |
| `engine/fx/**` + `shaders/cinema/{film_grade,vhs,halftone,crosshatch,ink_line,paper,iris,burn}.frag` + `shaders/cinema/lib/cinema.glsl` | **FX agent** | FilmFx, the post and material shader bodies, `fx/era_grades.dart` (grade, halftone and hatching tables). |
| `engine/rig/**` | **rig agent** | The procedural rubber-hose rig (RigCharacter), boss builders, `rig/era_inks.dart`. |
| `engine/audio/**` | **audio agent** | MusicDirector, SfxBank, synthesis, `audio/era_scores.dart`. |
| `engine/stage/**` + `shaders/cinema/{curtain,spotlight}.frag` | **stage agent** | StageFrame, HudKit and items, CinemaTransitions (iris, burn, intertitles), pause and results overlays, `stage/era_stages.dart`. |
| `hall/**` | hall (a later agent; the architect's skeleton for now) | The Madar Cinema hub, posters, best scores, Saved Games. |
| `games/<id>/**` | that game's agent | One folder per game: `<id>_entry.dart` + everything else. |
| `games/catalog.dart` | architect | Registry: one import and one line per game. |
| `rules/**` | rules agents | Pure-Dart Tier 2 rules and AI (cards, board games, puzzles). No Flutter or Flame imports. |
| `test/features/cinema/<same path>` | same owner as the code | `test/features/cinema/{core,shaders,demo,hall}` + `cinema_fakes.dart` are the architect's. |
| `lib/core/i18n/arb_parts/c0_cinema.json` | architect | Shared strings (hub, overlays, eras, Tier 1 names). |
| `c1_cinema_fx.json` · `c2_cinema_rig.json` · `c3_cinema_audio.json` · `c1_cinema_hall.json` (hall + stage) · `c6…cZ_cinema_<game>.json` | one per agent / game | Key prefixes: `cinemaFx…`, `cinemaRig…`, `cinemaAudio…`, `cinemaHall…` and `cinemaStage…` (both in the hall file), `cinema<Game>…`. |
| `pubspec.yaml` | architect | Shader registration only. All 10 slots are registered already. |

**Entry points.** The standard kit imports only these symbols from the agent
folders. Each is a one-line factory that returns a placeholder today. Swap in
your implementation there. You may delete your placeholder files; nothing
else imports them.

```dart
// engine/fx/fx_entry.dart
FilmFx createFilmFx(CinemaEnv env);
// engine/rig/rig_entry.dart
RigCharacter createRig(RigSpec spec);
// engine/audio/audio_entry.dart
MusicDirector createMusicDirector(CinemaAudioContext context);
SfxBank createSfxBank(CinemaAudioContext context);
// engine/stage/stage_entry.dart
StageFrame createStage(CinemaEnv env);
HudKit createHudKit(CinemaEnv env);
CinemaTransitions createTransitions(CinemaEnv env);
Map<String, CinemaOverlayBuilder> createOverlays(); // keys: CinemaOverlays.all
```

The **era tables** (`fx/era_grades.dart`, `rig/era_inks.dart`,
`audio/era_scores.dart`, `stage/era_stages.dart`) are pure const data that
import only core types. `core/era_skins.dart` assembles them into `EraSkin`s.
Tune your own table freely.

---

## 2. How a frame is made

```
Flame GameLoop (the ONE ticker) ──▶ CinemaGame.update(dt ≤ 1/20 s)
   clock.advance · film.decay · filmFx.update · stage.update ·
   transitions.update · music.update · component tree (world frozen when paused)
   · onGameplayUpdate (only while playing)

CinemaGame.render(canvas)
   record ─▶ [-1000 input] [-100 stage.paintBack] [0 camera → world (clipped to playRect)]
             [100 stage.paintFront] [200 HUD slots] [300 transitions.paint]
   ─▶ Picture.toImageSync(size × dpr × filmFx.resolutionScale)
   ─▶ filmFx.apply(canvas, image, …)   // film_grade.frag or vhs.frag samples the image
Flutter overlays (pause / results cards) sit above, ungraded, with real buttons.
```

* Screen space = the game widget's logical px. World space = `worldSize`
  design units (default 360×640; the demo uses 360×800 to match a phone's
  play area). The camera fits `worldSize` into `stage.playRect` ("contain"),
  so on other aspect ratios some world beyond the bounds shows. Paint
  backgrounds generously.
* The whole frame (world, curtains, HUD, iris, intertitles) goes through the
  one film pass. Grain dances on the black and on the title cards, like a real
  print.
* **Why not `ImageFilter.shader`?** It only works on Impeller. Recording to an
  image and sampling it in a `FragmentShader` works on Skia (`flutter test`
  screenshots, fallback) and on Impeller.

---

## 3. Core contracts (`engine/core/`)

### Era and skin: `era.dart`, `era_skin.dart`, `era_skins.dart`, `era_palettes.dart`, `era_labels.dart`
* `enum Era { silent, rubberHose, noir, technicolor, grindhouse, vhs }` with
  `decade` and `isMonochrome`. `era.label(l10n)` gives the localised name.
* `EraSkin { era, palette, grade, halftone, hatch, ink, score, stage, titles }`
  comes from `EraSkins.of(era)` (cached). `copyWith` makes per-game variants.
* `EraPalette { ink, paper, shadow, midtone, highlight, accent, accent2, backdrop, curtain, curtainShade, footlight }`.
  Use `resolve(PaletteRole)` so art names a *role*, not a colour, and
  re-skins per era.
* `FilmGrade` (FX): `process` (film or vhs), `projectionFps` (18 silent,
  24 film, 30 video), saturation (0 = ink→paper duotone), tint, contrast,
  brightness, posterize, grain and size, flicker, vignette, gate weave, dust,
  scratches, halation, plus VHS scanlines, chroma shift and bleed, tracking,
  wobble. `scaled(a)` scales only the damage effects.
* `HalftoneStyle`, `CrosshatchStyle` (FX); `InkStyle` (rig: line width, taper,
  boil amplitude, **boilFps**, shading mode, dryness, glow); `ScoreStyle`
  (audio: `MusicStyle`, tempo, swing, root, minor, lo-fi, crackle);
  `StageStyle` and `TitleStyle` (stage: proscenium, curtain kind and folds,
  footlights, spotlight, title font, frame, transition, iris shape).
* Music style by era: ragtime (1920s), swing (1930s), noir jazz (1940s), big
  band (1950s), funk (1970s), synthwave (1980s).
* Title fonts: bundled families only (`Amiri`, `ReemKufi`, `PlexArabic`).

### Clock and per-frame film state: `film_clock.dart`, `film_fx.dart`
* `FilmClock`: `time`, `tick`, `filmFrame` (at `projectionFps`), `boilFrame`
  (at `boilFps`, 12 = "on twos") and `boilChanged`. **Everything that boils
  seeds its jitter from `boilFrame`**, so all drawings re-ink together.
  Rebuild cached paths only when `boilChanged`. It keeps running while paused.
* `FilmFrame` (one mutable instance: `game.film`): `flash`, `shake`, `damage`
  (decaying `kick(...)`), `fade`, `intensity`, `reduceFlicker`
  (accessibility: no exposure flicker, `safeFlash` capped at 0.35, damage
  halved).
* `FilmFx` (FX agent):
  `isReady`, `load()`, `resolutionScale` (LOD), `update(dt, clock)`,
  `apply(Canvas, ui.Image frame, Rect dst, FilmClock, FilmFrame)`, `dispose()`.

### Shaders: `cinema_shaders.dart`, `shader_uniforms.dart`, `shaders/cinema/*.frag`

| Slot (`CinemaShader`) | File | Kind | Floats | Samplers | Owner |
|---|---|---|---|---|---|
| `filmGrade` | film_grade.frag | full-frame post (1920s–70s) | 36 | 1 (`uFrame`) | FX |
| `vhs` | vhs.frag | full-frame post (1980s) | 24 | 1 | FX |
| `halftone` | halftone.frag | material: dot shading on a ramp | 16 | 0 | FX |
| `crosshatch` | crosshatch.frag | material: pen hatching on a ramp | 16 | 0 | FX |
| `inkLine` | ink_line.frag | material: dry-brush ink for strokes and fills | 8 | 0 | FX |
| `paper` | paper.frag | material: aged card for intertitles, posters, plaques | 16 | 0 | FX |
| `iris` | iris.frag | overlay: iris mask (circle, heart, 8-point star, keyhole) | 16 | 0 | FX |
| `burn` | burn.frag | overlay: film burning in the gate | 16 | 0 | FX |
| `curtain` | curtain.frag | material: velvet folds and the valance | 24 | 0 | stage |
| `spotlight` | spotlight.frag | overlay (additive): follow-spot with motes | 16 | 0 | stage |

* Each `.frag` header documents its uniform layout. `shader_uniforms.dart`
  has one writer per shader (`FilmGradeUniforms.write(...)`, …) that sets
  floats **in declaration order** and asserts the count. Never call
  `setFloat` by hand. `test/features/cinema/shaders/shader_contract_test.dart`
  checks every compiled program against `CinemaShader.floats`.
* The first-pass bodies work (the demo shows them). The owners replace them
  but **keep the uniform list** unless the contract is changed (§10). Every
  declared uniform must stay *used*, or the compiler strips it and the
  indices shift.
* Material shaders work in the canvas' **local** coordinates. Pass
  `pixelScale` (logical px per local unit, e.g. `RigPaintContext.pixelScale`)
  so the dot and hatch pitch stays constant on screen under camera zoom.
* `CinemaShaders.preload()` runs once. After the first load it returns a
  `SynchronousFuture`. `CinemaShaders.program(slot)` returns `null` if a
  program failed: **always keep a plain-Canvas fallback**.
* `ShaderPool(slot)`: one `FragmentShader` per draw per tick (a shader's
  uniforms are shared by every draw recorded that frame). No allocations in
  steady state.
* SkSL rules (`bash tool/check_shaders.sh` must pass): no sampler function
  parameters, no `saturate` builtin (use `cn_sat`), constant loop bounds, no
  derivatives, premultiplied output, `#include "lib/cinema.glsl"`. The
  library is ALU only, so a post shader's sampler 0 is always its input.
  Frame-sampling UV goes through `cn_frame_uv` (the GLES y-flip lives there).

### Rig: `rig.dart`, `rig_component.dart`
* `RigSpec { id, body (bean/ball/egg/pear/tall), height, bodyWidth, limbLength, limbWidth, fill/trim/accent: PaletteRole, eyes (pieCut/round/dots), gloves, shoes, bounciness, seed }`.
* `RigCharacter`: `act(RigAction, {restart})`, `expression`, `facing`,
  `speed`, `lookAt(Offset?)`, `squash(amount)` (volume-preserving spring),
  `update(dt)`, `paint(Canvas, RigPaintContext)`, `bounds`, `dispose()`.
  The origin is between the feet and y points down.
* `RigPaintContext { skin, clock, pixelScale }`: one per game
  (`game.rigPaint`).
* `RigComponent(rig:, position:)` puts a rig in a Flame world (anchor
  bottom-centre = feet) and disposes it when removed.
* Bosses and special silhouettes: the rig agent publishes richer builders in
  `engine/rig/`. They still implement `RigCharacter`.

### Audio: `audio.dart`
* `MusicDirector`: `prepare()` (background isolate), `cue(MusicMood, {intensity, fade})`,
  `setIntensity`, `stinger(Stinger)`, `setDucked` (pause menu),
  `setPrayerMuted`, `pause`/`resume`, `update(dt)` (beat scheduling from the
  game loop, with no Timer churn), `stop`, `dispose`.
* `SfxBank`: `prepare()`, `play(CinemaSound, {volume, pitch, pan})`,
  `setPrayerMuted`, `dispose`. `cinemaSoundHaptics` pairs each sound with a
  `Haptic`, and `game.feedback(sound)` fires both.
* `CinemaAudioContext { sound: SoundService, era, score: ScoreStyle, seed }`.
  Play on the **games bus**. With `SoloudSoundService` use `loadClip` and
  `playClip(category: SoundCategory.games)` / `stopClip`, or a SoLoud buffer
  stream gated by `busGain(SoundCategory.games)`. The global sound switch,
  the games volume and **PrayerMute** (games auto-mute during the adhan and
  prayer) then apply automatically. Any other `SoundService` (tests) means
  silence.
* Every composition is original and procedurally generated in period style,
  with **no quotations** of existing tunes (prefer none, even public-domain
  ones).

### Stage, HUD, transitions: `stage.dart`
* `StageFrame`: `layout(Size, EdgeInsets safe)`, `playRect` (the camera
  viewport), `hudRect`, `curtainOpen`, `openCurtains`/`closeCurtains`,
  `spotlight(Offset?)`, `pulse(amount)`, `update`, `paintBack`,
  `paintFront`, `dispose`.
* HUD: `HudSlot { topStart, topCenter, topEnd, bottomStart, bottomCenter, bottomEnd }`
  follows the reading direction (start = right in Arabic). `HudModel`
  (score, best, lives, maxLives, bossHealth, bossName, progress, timeLeft,
  combo) is written by gameplay and read by items every frame.
  `HudItem { layoutSize, update, paint, interactive, onTap, dispose }`.
  `HudKit { score(), lives(), bossBar(), timer(), progress(), pauseButton(cb), label(textFn) }`.
* `CinemaTransitions`: `irisIn`/`irisOut({focus, duration})`,
  `intertitle(IntertitleCard, {hold})`, `cover()`, `clear()`, `coverage`,
  `isActive`, `layout`, `update`, `paint`, `dispose`. Futures run on game
  time. `IntertitleCard { text, subtitle, kind }` holds text the game has
  already localised.
* **Transitions freeze with the show.** While the game is paused or the app
  is in the background (`game.isTransitionFrozen`), `CinemaGame` updates
  the transitions with `dt = 0`: an iris stops where it was, and a card
  opened just before the Intermission keeps its full reading time and is
  still there when the player resumes. The film clock, curtains and HUD keep
  rolling.
* Overlays: `CinemaOverlays.pause` ("Intermission": resume, restart, leave)
  and `CinemaOverlays.results` (score, play again, leave) are Flutter
  widgets built by `CinemaOverlayBuilder(context, game)`.
* **Text direction.** Every line on the stage follows the game's reading
  direction (`env.direction`, right-to-left in Arabic): the HUD and the
  intertitle painters lay out with it, and the Flutter overlays wrap their
  card in `OverlayScene.directed` because Flame's `GameWidget` puts its
  overlays in a left-to-right `Directionality` whatever the app language
  (which moved the Arabic "." and "!" to the start of the line). A custom
  overlay must do the same. Only clock digits (`١:٠٥`) stay left-to-right.
* **Implementations (stage agent, `engine/stage/`, toolkit barrel
  `stage/stage_kit.dart`):** `ReelStage` (velvet curtains on physics:
  `CurtainMotion` hauls a rope, the leading edge follows on a spring, the
  hem swings, the tie-back gathers the drape; festoon valance with fringe;
  the era's proscenium from `ProsceniumPainter`, recorded once per layout;
  chasing marquee bulbs and footlight halos batched by `BulbAtlas`, two
  atlas draws; follow-spot; `beat`, a `StageBeat` that ticks every update so
  Flutter overlays repaint on game time with no second ticker).
  `ReelHudKit` (rolling-odometer score with a best tab, lives as film reels
  that unspool when lost, the boss bar as a burning film strip, a
  stopwatch, a film-strip progress bar, era plaques via `HudPlaque`).
  `ReelTransitions` (iris in the era's shape; the 1970s print burns
  through; 1980s tape-glitch bands; the FX agent's `IntertitlePainter`
  cards). Overlays: `ProjectorBoothOverlay` (pause) and
  `ResultsMarqueeOverlay` (results; it irises back onto the stage and
  closes the house curtains behind the card). Shared house style:
  `StageMaterials.of(skin)` (gilt, wall, bulbs, neon per era) and
  `Ornaments` (orbit emblem, sunburst, stars, laurels, neon tubes).

### The game: `cinema_game.dart`, `cinema_kit.dart`, `cinema_context.dart`, `cinema_env.dart`
`abstract class CinemaGame extends FlameGame<CinemaWorld>`:

* **Implement:** `String get gameId`, `Future<void> onSceneLoad()` (add
  components to `world`).
* **Optional hooks:** `worldSize`, `openingCard()`, `endingCard(result)`,
  `openingMood`, `buildHud()` (default: score at top-start, lives at
  top-center, pause at top-end), `onSceneStart()`, `onGameplayUpdate(dt)`,
  `onScreenTapDown/Up(worldPoint, screenPoint)`, `onScreenTapCancel()`,
  `onScreenDrag`, `onScreenDragCancel()`, `onScreenDragEnd` (input nobody
  else handled), `releaseInput()`.
* **Input contract.** Every tap down ends with exactly one
  `onScreenTapUp` or `onScreenTapCancel` (the finger slid into a drag, the
  system took the pointer); every drag ends with exactly one
  `onScreenDragEnd`, and a cancelled drag gets `onScreenDragCancel` just
  before it. `pauseGame()` calls `releaseInput()`, which cancels every open
  tap and drag that way and drops the rest of those gestures (moves, the
  lift behind the Intermission card). Override `releaseInput` to let go of
  your own held state too, and call `super`. The cancel hooks default to
  doing nothing.
* **Call:** `addScore(n)`, `hud.*`, `feedback(CinemaSound)`,
  `kick(flash:, shake:, damage:)`, `music.cue(...)`, `stage.spotlight(...)`,
  `pauseGame()`/`resumeGame()`, `endScene(won:, stats:)`,
  `screenToWorld`/`worldToScreen`, `requestRestart()`, `requestExit()`.
* **Read:** `skin`, `era`, `l10n`, `clock`, `film`, `rigPaint`,
  `sceneState` (a `ValueNotifier<SceneState>`), `isPlaying`,
  `isWorldFrozen`, `result`, `playRect`.
* **Scene flow:** loading → opening (intertitle, curtains, iris-in) →
  playing ⇄ paused (world frozen, projector rolling, music ducked) → ending
  (stinger, iris-out, end card, `ScoreSink.submit`, `onResult`) → ended
  (results overlay). Backgrounding the app pauses the game and the music.
  Back pauses; back again resumes.
* `CinemaKit` bundles the factories; `CinemaEngine.standardKit` wires the
  entry points. Tests use `kit.copyWith(...)` with fakes.
* `CinemaGameView(builder:, kit?, scoreSink?, onResult?, onExit?, skipOpening, seed)`
  builds the game with the app's `SoundService`, haptics, `L10n`, direction
  and reduced motion. It wires `prayerMuteProvider`, handles restart with a
  fresh game and disposes everything.

### Catalog and scores: `catalog.dart`, `score.dart`, `games/catalog.dart`
* `GameCatalogEntry { id, title(l10n), tagline(l10n), homage?(l10n), era, tier (feature | short), genre, builder? }`.
  `builder == null` means "coming soon".
* **Adding a game:** create `games/<id>/<id>_entry.dart`, then ask the
  architect to add one import and one line to `games/catalog.dart`. Tier 1
  stubs already exist (flappy_orbit, metropolis_machine, caravan_dash,
  noir_rooftops, neon_souk_racer); set their `builder`.
* `GameResult { gameId, score, won, playTime, stats }` is sent to a
  `ScoreSink { submit, best }`. `MemoryScoreSink` is the default; the hall
  uses `KvCinemaRecordsStore` (encrypted key/value store, key
  `cinema.records`: best, plays, wins and play time per game; the old
  `cinema.best` map is folded in once. `KvScoreSink` remains as a typedef).

### Hall and Saved Games: `hall/` (barrel `hall/hall.dart`)
* `CinemaHallScreen` – the movie-palace lobby: marquee sign, **Now
  Showing** (Tier 1 poster cases), the full programme with era / kind /
  ready-to-play filters and locked "coming attraction" slots, the ticket
  book (`cinemaRecordsProvider`), and the Saved Games shelf. Posters are
  `PosterPainter` one-sheets drawn per era, starring each game's rig-cast
  member (`CastMember.gameId`).
* `CinemaGameScreen(gameId: …)` (`CinemaGameScreen.route(id)` opens it
  through an iris): immersive portrait session with the screen kept on,
  best score on the HUD, results into the records store, pauses and puts
  the engine to sleep when covered (adhan, pushed page), a prayer-mute
  badge; an unknown or unplayable id shows `NotOpenYetStage`.
* Saved Games are built by the Saved Games feature
  (`lib/features/saved_games`): the hall hosts its `SavedGamesShelf` and
  re-exports `SavedGamesScreen`. The hall's first list (`cinema.savedGames`)
  is migrated into that store once.
* Hall and stage strings: `c1_cinema_hall.json` (prefixes `cinemaHall…`,
  `cinemaStage…`).
* **Rule:** a saved game always runs from its original link. Madar stores
  only the title and URL and never copies, caches or bundles third-party
  game code.

---

## 4. The demo (`games/demo/`)

`DemoGame` ("Rehearsal", بروفة) is the engine's 30-second vignette, one per
era, and the reference for how a Tier 1 game composes the pieces:

* **Cast.** The era's star from the rig cast is the hero (`DemoHero.build`:
  Habba 1920s, Nujaym 1930s, Mishmish 1940s, Zajil 1950s, a 70s stunt bean,
  Sarab 1980s); Baron Zunbruk is the mini boss in every era (he re-skins).
* **Set** (`demo_sets.dart`). A sky plane (plain canvas, cached gradients:
  searchlights, rain, stars, a grid) plus parallax `SetLayer`s of cached
  `InkProp`s on a repeating tile: every flat is inked with the rig toolkit
  (`InkSketch` / `InkBuild`), so scenery boils, shades (halftone, hatch,
  cel, neon) and re-colours like the cast. Six sets: a machine hall,
  cartoon countryside, rooftops at night, a Technicolor desert, a desert
  highway at sundown, a neon souk.
* **Script** (`DemoAct`): opening card → iris in (curtains part) → act
  one (pooled `Hazard` rollers, one design per era; progress film strip)
  → chapter card while the Baron rolls on → act two (boss bar, wind-up
  tell, slam shockwave + screen shake, a lobbed gear, each dodge knocks a
  phase off him) → curtain call (cheer, follow-spot) → iris out → end card
  → results marquee. Tap to jump; `autoplay` is the attract mode.
* **Feedback.** `feedback()` sounds + haptics, `kick()` flash / shake /
  print damage, `stage.pulse`, `stage.spotlight`, music moods and stingers
  (`adventure` → `boss` → `victory`), `PuffPool` dust for landings and
  stomps.

Tests: `test/features/cinema/demo/demo_game_test.dart` plays every era
through headlessly (`runUntil` drives game time without rendering) and
measures update / recording cost; the screenshot test renders chosen
*moments* through the real kit: `demo_<era>_play.png` (mid-jump) and
`demo_<era>_boss.png` (the slam) for every era, and the whole arc on the
1930s reel (`card`, `iris`, `hit`, `chapter`, `taunt`, `blast`, `bosshurt`,
`finale`, `irisout`, `end`, `results`). **Look at them after every engine
change.** `CinemaDemoScreen(initialEra, autoplay, showEraPicker)` hosts it
with an era switcher.

Critic's notes for the Tier 1 agents (lessons from the vignette):

* **Count attacks where they launch.** Pick the next attack (slam / blast /
  …) and bump the counter at the wind-up → attack transition, never in the
  recover step: recover also runs after the intro and after every hit, and
  the parity drifts (the Baron blasted forever and never slammed).
* **Dark sets need HUD contrast checked per era.** Anything inked `m.ink`
  on a dark plaque (noir) vanishes; use `HudPlaque.textColor` /
  `m.plaqueText` for glyphs on plaques and look at the noir screenshot.
* **No per-frame geometry.** Scale a `const` unit rect / oval with
  `canvas.scale` instead of building a `Rect` every frame (the hero
  shadow), keep `Paint`s and `Path`s as fields, cache `worldToScreen`
  results until `onGameResize`.
* **Screenshot the moments, not the start.** Drive the game headlessly
  (`runUntil`) to a precise state (`boss.actionTime` window, a hit frame,
  iris coverage) and capture there; a timeout in such a wait is a real
  regression signal, not flakiness.

---

## 5. Performance budget (60 fps on a mid-range phone, 120 Hz friendly)

| Stage | Budget per frame |
|---|---|
| `update` (all systems + gameplay) | ≤ 2 ms UI thread |
| scene recording (`render` before the grade) | ≤ 3 ms UI thread |
| film pass (one offscreen + one full-screen draw) | ≤ 2.5 ms GPU at `resolutionScale` 1; LOD 0.75 on mid-range |
| material shader draws | ≤ 40 per frame (`ShaderPool` default cap 64 per slot) |
| audio synthesis | never on the UI isolate; the era's music ready ≤ 1.5 s after scene start |

* **One loop:** Flame's GameLoop. No extra Tickers, Timers or
  `AnimationController`s inside a game. Use `CinemaTween`/`CinemaDelay` on
  game time.
* **No per-frame allocation:** reuse `Paint`, `Path` (`reset()`),
  `TextPainter` (re-layout only when the text changes), `FragmentShader`
  (`ShaderPool`), vectors and lists. Pool entities (see the demo's barrels).
  The one offscreen image per frame is inherent to the film pass.
* Rebuild boil paths only on `clock.boilChanged` (12 Hz, not 60 or 120).
* Animate with `dt`, never per frame. `dt` is clamped to 1/20 s.
* Cull off-screen components; keep LOD knobs (`resolutionScale`, fewer
  halftone draws, `FilmFrame.intensity`).
* Screen-space effects never read back pixels (`toByteData`) at runtime.

---

## 6. Originality and legal (hard rule)

* Only **original** characters, names, logos, art and music. Evoke an era's
  *style* (rubber-hose limbs, pie-cut eyes, halftone, iris wipes, title
  cards, swing), never a specific property.
* Never reproduce Cuphead, "Double Feature", "VolleyRush" or any existing
  franchise's code, characters, logos, music or assets. No cup-headed or
  mug-headed heroes, no mouse or cat mascots from famous studios, no famous
  catchphrases or title-card typography.
* Homages name the film in the catalog's `homage` line (for example
  "Metropolis" (1927), which is public domain). Designs echo the film's
  *mood*; they don't copy shots or characters.
* Music is composed procedurally. Stay out of recognisable melodies,
  including public-domain ones.
* Saved Games play from the original URL only (§3, Hall).

---

## 7. i18n, accessibility, feedback

* Strings live only in ARB parts (§1); Arabic is primary. Run
  `dart run tool/merge_arb.dart && flutter gen-l10n`. Numbers on the HUD use
  Arabic-Indic digits in Arabic. The HUD mirrors in RTL (start = right).
* `CinemaEnv.reducedMotion` becomes `FilmFrame.reduceFlicker`: no flicker,
  capped flashes, less damage. Keep gameplay readable with the film pass off
  (`game.filmEnabled = false`).
* The Flutter overlays carry semantics. `CinemaGameView` exposes a "pause"
  custom semantics action. Every sound has a paired haptic
  (`cinemaSoundHaptics`).

---

## 8. Testing

* Run only your own tests while building:
  `flutter test test/features/cinema/<yours> -j 2`.
* `test/features/cinema/cinema_fakes.dart` provides `TestKit` (the standard
  stage, HUD, transitions and rig plus recording audio and a counting
  FilmFx), `RecordingMusic`, `RecordingSfx`, `CountingFilmFx` and
  `RecordingHaptics`.
* Screenshot tests carry `@Tags(['screenshot'])` and write PNGs to
  `screenshots/cinema/<area>/`.
* Preload with `CinemaShaders.preload()` in `setUpAll`.
* After tapping a Flame game, pump about 1 s so the tap recognizer's timers
  drain before the test ends.

## 9. Gotchas found while building the skeleton

* Flame gives the camera **max priority**. `CinemaGame` pins it to 0 so the
  stage, HUD and transitions paint above the world.
* Never `await add(...)` or `addAll(...)` inside the root game's `onLoad`:
  children load only after the root mounts, so it deadlocks.
* An `await` on a future created in another zone (such as `setUpAll` or
  `runAsync`) resumes on that zone's microtask queue. That is why
  `CinemaShaders.preload()` returns a `SynchronousFuture` once loaded.
* Accumulated float time loses the last frame (120 × 1/120 < 1). The clock
  and the tweens snap with an epsilon.
* `Picture.toImageSync` textures on Impeller GLES may be stored bottom-up.
  `cn_frame_uv` flips them; verify on a GLES device.

## 10. Changing a contract

Core is frozen for the agents. If you need something:
1. Prefer an addition inside your own folder (a richer builder, an extra
   helper).
2. Otherwise ask the architect (via the orchestrator) for an **additive**
   core change: a new optional parameter, a new enum value at the end, or a
   new method with a default in an abstract class. The architect updates
   core, this document and the contract tests together. A uniform layout
   changes in three places at once: the `.frag` header,
   `shader_uniforms.dart` and `CinemaShader.floats`.
