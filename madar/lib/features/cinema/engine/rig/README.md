# Rig kit: rubber-hose characters, cast and props

Owner: the rig agent. Games import `engine/cinema_engine.dart` (contracts) and
`engine/rig/rig_kit.dart` (everything below). Every character implements
`RigCharacter` and goes into a Flame world with `RigComponent`; every prop
goes in with `PropComponent`. Model sheets live in
`screenshots/cinema/rig/*.png` (`flutter test --tags screenshot test/features/cinema/rig`).

## Characters

| Builder | Who | Designed for | Notes |
|---|---|---|---|
| `createRig(spec)` → `ToonRig` | any biped from a `RigSpec` | the standard kit | bean / ball / egg one-piece bodies, pear / tall with a separate head. Optional `ToonLook` (hair, hat, bow tie, ears, buttons, lashes). |
| `RigCast.bean()` | Habba (حبّة) | demo | the default `ToonRig` look. |
| `RigCast.starBird()` → `StarBird` | Nujaym (نُجيم) | Flappy Orbit, 1930s | lives in the air: `jump` = one flap (call it on each tap), `fall` = wings up, `run` = dash, `cheer` = loop-the-loop, `hurt` pops feathers. `pitch` (rad, + nose down) can follow the vertical speed. |
| `RigCast.clockworkBoss()` → `ClockworkBoss` | Baron Zunbruk (البارون زُنبُرك) | Metropolis Machine, 1920s | `phase` 0..2 (pristine → dented, steam → plating off, gears, spring). `attack = BossAttack.slam/punch/blast` then `act(RigAction.attack)`. `windUp` 0..1 is the tell. Hit boxes: `fistAnchor(i)`, `mouthAnchor`, `coreAnchor` (character space, updated each drawing). |
| `RigCast.camelCourier()` → `CamelCourier` | Zajil (زاجل) | Caravan Dash, 1950s | quadruped: `walk` is a camel's pace, `run` a gallop; `cheer` rears up, `attack` bucks. Origin under the middle of the body. |
| `RigCast.detectiveCat()` → `DetectiveCat` | Inspector Mishmish (المفتش مِشمِش) | Noir Rooftops, 1940s | a `ToonRig`: `walk` = tiptoe sneak, `jump` = rooftop leap, `cheer` tips the fedora. |
| `RigCast.neonRider()` → `NeonRider` | Sarab (سراب) | Neon Souk Racer, 1980s | rider + hover-bike; origin on the ground under the bike. `lean` (−1..1) banks, `throttle` sizes the flame, `attack` = boost, `cheer` = wheelie. |

`RigCast.all` lists the cast with localised `name(l10n)` / `role(l10n)`
(`c2_cinema_rig.json`, keys `cinemaRig…`) and default heights.

### Driving a character

```dart
final hero = RigComponent(rig: RigCast.starBird(height: 90), position: Vector2(120, 400));
world.add(hero);
final bird = hero.rig as StarBird;
bird.act(RigAction.jump, restart: true);   // every tap
bird.pitch = (vy / 900).clamp(-0.5, 0.8);  // optional
bird.expression = RigExpression.scared;
bird.lookAt(const Offset(1, 0.3));          // character space; null = idle glances
bird.squash(0.3);                          // any extra impact
bird.flash();                              // hit flash (fills go white)
```

* Actions: loops (`idle`, `walk`, `run`, `cheer`, `taunt`, `talk`) play until
  changed; `jump`/`fall`/`defeated` hold; `land`, `hurt`, `attack` are
  one-shots that return to `idle` (games that run in place re-`act(run)`
  when they see `idle`, like the demo). `act(a, restart: true)` replays.
* `speed` sets the walk/run cadence and lean. `facing` flips through a
  squashed front view. `HoseRig.tempo` (bpm) sets the idle bounce; by
  default it is the era's score tempo, so the cast bounces on the music.
* `setHand(i, HandShape.point)` overrides a glove; `talkLevel` 0..1 moves
  the mouth while a game plays a voice; `emanata = false` hides stars,
  sweat, speed lines and dust.

## Props

`InkCloud`, `InkStar` (twinkling, optional face via `PropMood`), `InkGear`
(`speed` rad/s), `InkCrate` (`hit()` squashes it; origin = bottom centre),
`InkMoon` (sleepy "zz"), `InkPuff` (pooled smoke: `restart()`, `done`).
Set `shaded = false` on small or distant props: the material shader is
replaced by a flat tone.

## How a drawing is made (and why it is cheap)

* **Drawing cache.** A rig builds a *drawing* into a retained display list
  (`InkBuild` → `InkList`) only when something changes: a new pose drawing,
  a new boil frame, a new skin or zoom. Frames in between replay the list.
  Paths, paints and shader instances are pooled; nothing is allocated per
  frame. `RigTiming.auto` draws loops that stay in place **on twos** (12/s)
  and anything that travels or hits **on ones** (24/s); video eras draw at
  30/s. Each rig's drawing clock is staggered by a sub-frame phase so a full
  cast never rebuilds on the same tick.
* **Ink.** Shapes of a layer are stroked in ink first (2× line width,
  nudged toward the shadow side, so the line is heavy underneath and thin
  on top), then filled: overlapping shapes merge into one inked silhouette.
  Details (brows, mouths, creases, whiskers) are tapered brush ribbons.
  Contours wobble on the 12 fps boil with low-frequency noise seeded from
  the boil frame (all drawings re-ink together). Line width and boil scale
  with √size, like an inker's pen.
* **Shading.** Each form gets a crescent mask on its shadow side (no clip,
  no path booleans), filled per era: halftone dots (1930s, grindhouse),
  pen hatching (1920s, noir), a flat cel tone (Technicolor), none under
  neon. One material shader instance per character.
* **Era looks.** Colours come from palette roles through `InkColors`: neon
  (1980s) sinks fills toward the dark and turns the ink into glowing
  tubes; eras with a dark backdrop (noir) get a pale rim light on the lit
  side so black silhouettes read against the night.
* **Rubber hose.** Limbs are one quadratic of fixed length that bows into
  an arc when its ends come closer (sagitta from the arc length) and thins
  when stretched; the middle is pushed by the hand's velocity for
  follow-through. Hands, feet, heads, tails, scarves and tassels ride
  damped springs (sub-stepped at 1/120 s), so everything overshoots and
  settles like rubber.

## Budget (measured in `rig_budget_test.dart`)

~50–200 draw ops per drawing per character, a stable path pool, 24
drawings/s (film) or 30 (video). Replay is a fraction of a millisecond;
a rebuild is the main cost, spread over ticks by the stagger.

## Originality

All designs are original. No cup- or mug-headed heroes, no mouse or black
cat mascots, no existing franchise's characters, logos or silhouettes. The
boss's ten-hour dial nods to the *mood* of "Metropolis" (1927, public
domain) without copying any design from it.
