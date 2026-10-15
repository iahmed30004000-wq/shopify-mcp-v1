# Madar Cinema – Tier 2 puzzles & arcade rules

Pure-Dart rules for the Tier 2 **puzzles** (`rules/puzzles/**`) and **arcade
simulations** (`rules/arcade/**`). No Flutter imports, no rendering and no
user-facing text: every enum value, technique id and cause id is a stable
identifier that the UI localises. Board games live in `rules/board`, card
games in `rules/cards` (other teams).

Entry points:

* `rules/puzzles/puzzles.dart` – exports every puzzle plus
  `newPuzzle(kind, difficulty, seed)`, `puzzleFromJson(json)` and
  `puzzleActionFromJson(kind, json)`.
* `rules/arcade/arcade.dart` – exports every simulation, `Vec2`/`Aabb` and
  the swept-collision helpers.

Tests: `flutter test test/features/cinema/rules/puzzles test/features/cinema/rules/arcade -j 1`.

---

## 1. Shared contracts

### Determinism

All randomness comes from `SeededRng` (`puzzles/core/seeded_rng.dart`):
xoshiro128** seeded through SplitMix32 with 32-bit-only arithmetic, so a seed
produces the same sequence on the VM, AOT and the web. Puzzles that draw
random numbers *during play* (2048 spawns, Souk Jewels refills, Mahjong
shuffles, Falling Blocks bags) keep the four RNG words **inside their state
snapshot**, so undo, save/restore and replays reproduce the same future.

### `PuzzleGame<S, A>`

```dart
abstract interface class PuzzleGame<S extends PuzzleState, A extends PuzzleAction> {
  PuzzleKind get kind;
  S get state;                 // immutable snapshot
  bool apply(A action);        // false (and no change) when illegal
  bool get isSolved;
  bool get isOver;             // solved or lost / stuck
  PuzzleHint<A>? hint();       // action + technique id + focus cells
  bool get canUndo;
  bool undo();
  Map<String, Object?> toJson();   // {kind, v, config, state, history}
}
```

* `PuzzleBase` implements the plumbing: states are immutable snapshots, every
  legal `apply` pushes the previous snapshot onto a bounded undo stack
  (1000 entries by default), `toJson` stores configuration, state and history.
  Every game has `XGame.fromJson`; `puzzleFromJson` dispatches on `kind`.
* Actions are immutable values with `==` and `toJson`/`fromJson`, so an
  action log replays deterministically on a fresh game from the same config.
* `PuzzleHint.technique` ids (localise these): see each puzzle below.
  `focus` lists game-specific cell indices worth highlighting.
* `PuzzleDifficulty { easy, medium, hard, expert }` is shared; each puzzle
  documents what it changes.

### `ArcadeSim<S, I>`

```dart
abstract interface class ArcadeSim<S, I> {
  ArcadeKind get kind;
  S get state;          // live state (read-only by convention)
  int get score;
  bool get isOver;
  int get tick;         // fixed ticks simulated
  double get tickSeconds;
  double get alpha;     // leftover fraction of a tick, for interpolation
  void step(double dt, I input);
  Map<String, Object?> snapshot();  // JSON-friendly, for replays/tests
}
```

`FixedStepSim` accumulates the frame `dt` and runs whole ticks (60 Hz;
Pinball 120 Hz). Frames longer than `maxTicksPerStep` ticks are clamped (no
spiral of death); NaN/negative `dt` counts as 0. **One-shot inputs** (launch,
drop, hop, hyperspace, a snake turn, blade points) are delivered to exactly one
tick: later ticks of the same frame get `heldOnly(input)`, and a frame too
short to tick carries the event to the next one (`mergeInput`). Same seed +
same `(dt, input)` sequence ⇒ identical `snapshot()`. `runTicks(n, input)`
advances exactly `n` ticks (tests, AI, replays). `ArcadeLevel { easy, medium,
hard }` tunes pacing / AI.

---

## 2. Puzzles

### 2048 (`merge/merge_2048.dart`)
* Boards 4×4 (default), 5×5, 6×6 (3–8 accepted).
* Tiles slide as far as possible; equal tiles merge from the leading edge,
  each tile at most once per move (`[2,2,2,2]→[4,4,0,0]`,
  `[4,4,8,0]→[8,8,0,0]`). Score += value of each merged tile.
* A move that changes nothing is illegal and spawns nothing. Each legal move
  spawns a 2 (or a 4 with probability `fourPermille/1000`) on a random empty
  cell.
* Win: reach `target`; the game pauses (`isOver`) until the
  `keepPlaying` action. Lose: no legal move.
* Difficulty: target 512 / 1024 / 2048 / 4096; 4-chance 5 % / 10 % / 10 % / 20 %.
* Hint `expectimax`: depth-2 expectimax (move → sampled spawns → move) with a
  heuristic (empty cells, monotonic lines, smoothness, max tile in a corner);
  `keepPlaying` when paused on a win. It reaches 512 reliably.

### Sudoku (`sudoku/`)
* `SudokuSolver`: bitmask backtracking with minimum-remaining-values; counts
  solutions up to a limit (uniqueness = exactly one).
* `SudokuLogic`: candidate-based human techniques applied easiest first.
  Tiers (the puzzle's difficulty is the tier of the hardest technique needed):
  * **easy** – `nakedSingle`, `hiddenSingle`;
  * **medium** – `pointing`, `claiming`, `nakedPair`, `hiddenPair`,
    `nakedTriple`, `hiddenTriple`;
  * **hard** – `xWing`, `xyWing`, `swordfish`, `xyzWing`, `nakedQuad`,
    `hiddenQuad`;
  * **expert** – `beyondLogic`: not solvable with the above (needs chains /
    forcing); still has a unique solution.
* Generator: random full grid → remove clues in 180°-symmetric pairs while the
  solution stays unique (minimal puzzle) → grade. Too hard: add solution clues
  at the cells where the target-tier solver gets stuck until the grade equals
  the target. Too easy: discard. Expert: a short clue-swap hill climb (keeps
  uniqueness) pushes a hard puzzle beyond the hard tier. Easy puzzles are
  topped up to ≥ 32 clues. Every generated puzzle is verified unique and
  graded exactly at its level (tests: 12 seeds × 4 levels).
* Game actions: `place`, `erase`, `toggleNote`, `autoNotes`. Givens are
  locked. Placing removes that digit from peers' notes. `conflicts()` (house
  duplicates) and `mistakes()` (vs. the unique solution); `state.mistakes`
  counts wrong placements.
* Hints: `mistake` (erase a wrong entry) first; otherwise the next placement
  found by the logical solver, with `technique` = hardest technique used on
  the way and `focus` = the cells that justify it; when stuck (expert) the
  most constrained cell is revealed (`beyondLogic`).

### Minesweeper (`minesweeper/minesweeper.dart`)
* Sizes: 9×9/10, 16×16/40, 30×16/99, 30×24/180 (custom sizes accepted).
* Mines are laid on the **first reveal**, never on the clicked cell and –
  when at least 9 cells remain – never on its neighbours, so the first click
  always opens an area. Zeros flood-fill.
* Flags toggle; flagged cells cannot be revealed. **Chording** a revealed
  number whose adjacent flag count equals it reveals the other hidden
  neighbours (a wrong flag means revealing a mine). Win: every safe cell
  revealed (mines then auto-flag). Loss: a mine revealed. Undo can take a
  loss back.
* `MinesweeperSolver.deduce`: single-constraint, pairwise subset/overlap and
  global-count reasoning from the visible numbers (sound – tested against the
  real mines).
* Optional `noGuess`: retry layouts until the deducer clears the board from
  the first click, within an attempt budget (300 on ≤ 256 cells, 25 on larger
  boards up to 21 % density, 12 above). `state.logicOnly` records whether the
  dealt board was verified; the dense 30×24/180 board usually falls back to an
  ordinary layout (logic-only layouts at 25 % density are very rare).
* Hints: `opening` (first click), `safeReveal`, `wrongFlag`, `certainMine`,
  else `guess` (lowest local mine estimate).

### Nonogram (`nonogram/nonogram.dart`)
* Cell codes: 0 unknown, 1 filled, 2 crossed.
* `NonogramLineSolver.solveLine`: exact per-line DP (prefix/suffix
  feasibility of block placements) returning every forced cell, or null on
  contradiction; `solveNonogram` propagates rows/columns to a fixpoint.
* Generator (5×5 … 15×15): random grid at a difficulty density (62 / 58 / 55 /
  52 % filled; default sizes 5, 10, 12, 15) → run the line solver → flip an
  undetermined cell and repeat until the line solver solves everything. A
  puzzle the line solver completes has exactly one solution and never needs
  guessing (cross-checked by brute force on 5×5).
* Solved when the filled cells equal the solution (crosses are optional).
* Hints: `mistake` (fix a wrong mark) first, else the first cell deduced by
  one line-solver sweep over the player's marks (`lineLogic`, prefers fills;
  focus = the line).

### Mahjong Solitaire (`mahjong/`)
* Layouts: the traditional 144-tile **turtle**, an original stepped
  **pyramid** (132) and **twin minarets** (78, two towers joined by a
  bridge). Positions use half-tile units so offsets like the turtle's end
  tiles and top tile are exact.
* A tile is **free** when nothing lies on it (any overlapping tile one layer
  up) and its left or right side is open (no tile on the same layer directly
  beside it with overlapping rows).
* 144 faces: 34 kinds × 4, plus 4 flowers and 4 seasons; any flower matches
  any flower and any season any season. Smaller layouts use a random subset
  of the 72 matching pairs.
* **Deals are solvable by reverse construction**: starting from the full
  structure, remove two currently free slots at a time (biased towards high
  tiles) and give them a matching pair; restart on a dead end. The removal
  order, replayed forwards, clears the board (tested by replay on 25 seeds per
  layout). The same construction re-deals the remaining tiles on **shuffle**,
  so a shuffle is always solvable. Difficulty = shuffles allowed
  (5 / 3 / 1 / 0).
* `isStuck` = no free matching pair; `isOver` = solved or stuck with no
  shuffles left.
* Hint `solver`: while every removal so far took a pair of the dealer's plan,
  the plan (minus those pairs) still clears the board – removing tiles early
  only frees others – and its next pair is returned. Otherwise a depth-first
  search with memoisation, safe-move pruning (a group whose remaining tiles
  are all free) and dead-end pruning (the last two tiles of a group stacked on
  each other) runs within a node budget (`heuristic` fallback); `shuffle` when
  stuck.

### Sliding Tiles (`sliding/sliding_tiles.dart`)
* 3×3, 4×4 (15-puzzle), 5×5; tile `k` belongs at index `k − 1`, blank last.
* Only solvable permutations: odd width ⇒ even inversions; even width ⇒
  inversions + blank row (from the bottom, 1-based) is odd. Easy/medium are
  random walks of 3n²/8n² blank moves, hard 40n², expert a uniformly random
  permutation fixed up by swapping two tiles if needed.
* Tapping a tile in the blank's row/column slides the whole run; `moves`
  counts tiles moved.
* Solver: IDA* with Manhattan distance + linear conflicts (admissible:
  2 × tiles to remove per line, via longest increasing subsequence) – always
  optimal on 3×3 (31-move worst cases verified); on 4×4/5×5 it runs within a
  node budget (60 k / 20 k) and otherwise the **staged** solver places the top
  row and left column group by group (BFS over the blank and the group's
  tiles, the last two tiles of a line placed together), then finishes the last
  3×3 optimally. Hint technique: `optimal` or `staged`.

### Lights Out (`lights_out/lights_out.dart`)
* Pressing toggles the light and its orthogonal neighbours; clear the board.
  Default 5×5, any rows×cols up to 400 cells.
* The press matrix `A` is row-reduced over GF(2) once per size (bit vectors
  in 32-bit words). Boards are generated as `A·x` for a random press vector
  (4 / 8 / 12 presses, expert: every cell with p = ½), hence always solvable.
  `isSolvable` checks orthogonality to the null space (dimension 2 on 5×5,
  4 on 4×4, 0 on 3×3); `solve` returns the minimum-press solution by trying
  every null-space combination. `par` = that minimum for the dealt board.
* Hint `linearAlgebra`: the first press of the minimal solution (focus = all
  presses). Following hints solves in exactly `par` presses.

### Pipe Connect (`pipes/pipe_connect.dart`)
* Masks: up 1, right 2, down 4, left 8. Generation grows a random spanning
  tree from the centre (randomised Prim, avoiding 4-way crosses), then turns
  each tile by a random number of quarter turns (never already solved).
  Sizes 5×5 / 7×7 / 9×9 / 11×11 with wrap-around edges on expert.
* Actions: rotate a tile (1–3 quarter turns), lock/unlock a tile (locked
  tiles do not rotate).
* **Win detection is rule-based**: every pipe end meets a matching end and
  every tile is powered from the source – any arrangement satisfying the rules
  wins. `powered()` exposes the lit tiles.
* Hint `rotate` (turns needed to reach the generated orientation, powered
  tiles first) or `unlock`.

### Tangram (`tangram/`)
* The seven tans with the square's side as the unit: two large triangles
  (legs 2), a medium (legs √2), two small (legs 1), the square (1×1) and the
  parallelogram (sides 1 and √2) – total area 8.
* **Exact geometry**: every edge is at a multiple of 45°, so coordinates live
  in Z[√2]. They are stored scaled by 4 as `a + b√2` with integer `a, b`
  (`Surd`, `SPoint`). Rotations are `k × 45°`, the parallelogram can be
  flipped. Signs are decided exactly, polygon intersections use exact
  line–line formulas for the four 45° line families, so overlap areas and
  coverage are exact (no tolerances).
* **Snapping**: `snapPlacement` / `TangramGame.snap` moves a dragged piece so
  that its nearest vertex coincides with a silhouette or placed-piece vertex
  within 0.2 units, otherwise to a half-unit grid. Placements must be on this
  lattice (`place` rejects others).
* **Silhouettes** are drawn as art on the integer lattice: each cell is full
  (`#`), empty (`.`) or half filled along a diagonal (`◤ ◥ ◣ ◢`, the filled
  corner). Each cell splits into four quarter triangles, every lattice-aligned
  tan covers whole quarters, so the library is validated by an **exact-cover
  search** over the 32 quarters (area 8) that also yields the reference
  solution. Library (original designs): easy – rhombus, rectangle,
  bigTriangle, house, tent; medium – parallelogram, trapezoid, letterT, boot,
  arrow; hard – minaret, mushroom, dhow, gate, chair; expert – swallow, cat,
  plus seeded **abstract** figures (the tans laid edge to edge, then
  re-validated). The UI localises figures by `id`.
* Win: all seven placed, pairwise non-overlapping, and each tan's area inside
  the reference tans equals its own area (so the union equals the
  silhouette). Equivalent arrangements (swapped twins, alternative tilings)
  win too.
* Hint `referenceTan`: places the next reference tan not yet occupied by a
  piece of its shape.
* The classic square with irrational coordinates (tested): with
  `c = (√2, √2)` and `P1 = (1.5√2, 0.5√2)`: large tans at `c` with
  rotations 5 and 3, medium at `(2√2, 2√2)` rotation 4, small tans at `P1`
  rotation 7 and at `c` rotation 1, the square at `P1` rotation 1 and the
  parallelogram at `(0, 2√2)` rotation 7 tile `[0, 2√2]²` exactly.

### Star Memory (`memory/star_memory.dart`)
* Boards 3×4, 4×4, 4×5, 6×6; each star id twice.
* Flip one card, then a second: a match stays up; a mismatch stays visible
  until the next flip or `conceal`. A move = a pair of flips.
* `score = pairs×100 + max(0, par − moves)×20 − max(0, moves − pairs)×5 −
  seconds`, clamped at 0, `par = 2·pairs − 1`. Time is added by the UI with
  `addTime` (not undoable).
* Hints use only cards the player has already seen: `knownPair` else
  `explore` (an unseen card).

### Souk Jewels (`jewels/souk_jewels.dart`)
* 8×8, 5 / 6 / 6 / 7 colours; moves and target score: 30/1000, 25/1500,
  22/2000, 20/2200.
* A swap of orthogonal neighbours is legal only if it lines up 3+ of one
  colour through a swapped cell, or involves a star gem.
* Runs clear; a run of 4 makes a line gem (horizontal run → column clearer,
  vertical run → row clearer), an L/T crossing makes a bomb (3×3), 5+ makes a
  star gem (on the swapped cell when it is in the run, else mid-run). Cleared
  specials detonate (chains); a swapped star clears every gem of the other
  gem's colour (two stars: the whole board); a star caught in a blast clears
  the most common colour.
* Gravity + seeded refill; cascades score `10 × gems × cascade index` plus
  special bonuses (line 20, bomb 30, star 50). `state.lastSteps` lists the
  waves for animation.
* Boards never start with a match, always offer a move, and are reshuffled
  (seeded; specials kept) whenever no legal swap remains.
* Hint `bestSwap`: exact simulation (real RNG copy) of every legal swap.

### Falling Blocks (`blocks/falling_blocks.dart`)
* An original-named implementation of the public falling-block mechanics:
  shapes `bar, box, tee, skewRight, skewLeft, hookLeft, hookRight`; 10 wide,
  20 visible rows + 2 hidden spawn rows.
* Seeded 7-bag, 5-piece preview, hold once per piece.
* Four rotation states with the widely documented five-test wall-kick
  offsets (separate table for the bar; no kicks on 180° turns, which the
  action set does not offer).
* Gravity: seconds per row = `(0.8 − (level−1)·0.007)^(level−1)` at 60 fps;
  soft drop 1 point/row, hard drop 2 points/row; 30-frame lock delay with up to
  15 move/rotate resets (reset when the piece reaches a new lowest row).
* Line clears: 100 / 300 / 500 / 800 × level; level +1 every 10 lines, start
  level 1 / 4 / 8 / 12 by difficulty.
* Game over when a spawn overlaps or a piece locks entirely in the hidden
  rows. The game is endless (`isSolved` is always false).
* Timing: `apply(FallingAction.tick)` advances one frame; `advance(seconds)`
  plays whole frames for real time. **Undo** returns to the spawn of the
  previously locked piece (ticks are not recorded individually).
* Hint `placement`: a feature-weighted search over every rotation × column
  (landing height, cleared rows, row/column transitions, holes, wells); the
  hint is the next input towards it (focus = the target cells). It survives
  150+ pieces.

---

## 3. Arcade simulations

Units are abstract screen units (y grows downwards) unless noted; every sim
exposes its live state for rendering and `snapshot()` for replays.

| Sim | Rules / notes | Input |
|---|---|---|
| **Snake** | Grid 20×20 (configurable), walls or wrap. One cell every `interval` ticks (10/8/6 by level, −1 per 5 foods, floor 3). Two queued turns per cell; reversing is ignored. Food on a random free cell; filling the board wins. | `SnakeInput(turn)` one-shot |
| **Brick Breaker** | 240×320 field, paddle width 52/42/34. Swept circle-vs-box against walls, paddle and every brick with up to 8 contacts per tick – no tunnelling at any speed (tested at 30 000 u/s). Paddle bounce angle ±60° by hit position; bricks 1–3 hp or unbreakable; ball speeds up per hit; next level on clearing; 3 lives. | `targetX` or `axis`, `launch` one-shot |
| **Star Hunter** | Waves fly in to a swaying formation, then dive at the player; formation and divers fire aimed shots (rates scale with level and wave). Player bullets are swept along their path. Enemy types scout/fighter/bomber (1/2/4 hp). A hit costs a life + 2 s invulnerability. | `dx, dy`, `fire` held |
| **Asteroid Belt** | 320×240 torus. Rotate, thrust (drag, speed cap), fire (6 bullets, 0.9 s life), hyperspace (3 s cooldown). Rocks 22/12/6 radius split in two; 20/50/100 points; wave `n` has `3+n` large rocks (≤ 11) spawned ≥ 80 units away. Respawn waits for a clear centre. | `turn, thrust, fire` held; `hyperspace` one-shot |
| **Paddle Duel** | 320×200, first to 11. Swept ball; bounce angle ±50°; +12 u/s per return. AI profiles: easy (react every 14 ticks, 150 u/s, chases the ball's height), medium (7 ticks, 200 u/s, predicts bounces, random aim), hard (2 ticks, 280 u/s, predicts, aims away from the opponent). Error is drawn once per approaching ball and grows with ball speed, so rallies end. Measured: hard beats easy 100 %, medium beats easy 100 %, hard beats medium ≈ 75 %. `leftAi` enables attract mode. | `targetY` or `axis` |
| **Stack Tower** | A block slides over the tower; drop trims the overhang (debris kept for rendering), a drop within the perfect tolerance (4/3/2 units) snaps and keeps the width; 3 perfect in a row widen by 4 (up to the base). A miss ends the game; speed grows with height. Score +1 per block, +2 per perfect. | `drop` one-shot |
| **Fruit Slice** | 320×480, gravity 400. Seeded waves of fruit/bombs (bomb chance 6/12/18 %). Blade = pointer points per frame; each segment is tested against every object at its start, middle and end position of the tick. ≥ 3 fruit in one swipe: +count bonus. A fruit falling back unsliced is a strike; 3 strikes or a bomb end the game. | `FruitInput(blade points)` |
| **Sky Jumper** | Altitude grows upwards; bounce 520 u/s under 900 u/s² (apex ≈ 150). Swept landing (feet crossing a platform top while falling). Platforms normal / moving / crumbling (break, no bounce) / spring (×1.6). Generated with the gap between consecutive **solid** platforms capped at 55/70/80 % of the apex, so a solid step is always reachable (horizontal reach ≈ 184 u > half the wrapped width). Falling 200 u below the best height ends the run; score = best altitude. | `SkyInput(axis)` |
| **Maze Chase** | 21×23 tiles. Perfect maze on the left half (DFS), mirrored, joined across the centre, then **every dead end opened** (verified: symmetric, connected, ≥ 2 exits everywhere). Original chasers: Ember (targets the runner), Tide (4 tiles ahead), Moss (flanker: mirror of Ember through the tile 2 ahead), Dusk (chases beyond 8 tiles, else its corner). Decisions only at tile centres, no reversing, straight-line distance to the target. Scatter/chase schedule 7-20-7-20-5-20-5 s then chase; power pellets frighten (slow, random turns, 200/400/800/1600 chain) for `max(1.5, 7 − level)` s; eaten chasers return to the den; mode changes reverse chasers; release from the den every 2.5 s. | `MazeInput(direction)` held |
| **Road Crossing** | 9 columns, endless rows generated per row from the seed: grass (trees never close a lane: ≥ 3 open cells, ≥ 2 shared with a grass lane below), roads (vehicles 1–2 cells, gaps ≥ 2.5 cells, speed and density rise with distance), rivers (logs 1–4 cells; water drowns, riding off-screen kills). Vehicles and logs are closed-form functions of time. A storm line creeps forward (0.35 rows/s + distance) once the player has moved, never more than 6 rows behind; falling behind it ends the run. Score = best row; `state.cause` ∈ `vehicle`, `water`, `edge`, `storm`. | `RoadInput(hop)` one-shot |
| **Pinball** | Table 20×36, gravity 20 (tilt), ball r = 0.5. 120 Hz × 4 substeps; speed cap 45 u/s keeps travel per substep ≈ 0.09 < r, flipper tip speed ≈ 0.21 per substep < contact radius – no tunnelling (tested over minutes of random flipping: clearance to every wall and bumper). Contacts: projection + impulse on the relative normal velocity (walls e = 0.45, flippers e = 0.35 with surface velocity `ω × r`). Two flippers (28 rad/s up, 16 down), three pop bumpers (kick 22, 100 pts), two slingshots (kick 16, 10 pts), three rollovers (all lit: 1000 × multiplier, multiplier +1 up to 5), plunger lane (launch power 0..1). 3 balls. | `left, right` held; `launch` one-shot + `power` |

Tic-tac-toe lives in `rules/board`.

---

## 4. Performance

Measured on the development container (4 cores, Dart JIT via `dart run`
and `flutter test`); budgets asserted in tests use medians with a 200 ms
limit.

| Generator / operation | Median | Worst seen |
|---|---|---|
| Sudoku hard | 17 ms | 110 ms |
| Sudoku expert | 10–15 ms | 71 ms |
| Nonogram 15×15 expert | 4 ms | 17 ms |
| Mahjong turtle deal | 2 ms | 47 ms |
| Mahjong pyramid / twin minarets | 1 ms / 0.1 ms | 5 ms / 2 ms |
| Minesweeper expert (first click) | 0.4 ms | 5 ms |
| Minesweeper hard no-guess (25-attempt cap) | 32–41 ms | ≈ 170 ms |
| Minesweeper expert no-guess (12-attempt cap) | ≈ 120 ms | ≈ 130 ms |
| Sliding 5×5 expert first hint | 14 ms | ≈ 170 ms |
| Tangram abstract figure | 7 ms | 39 ms |
| 2048, Lights Out, Pipes, Star Memory, Jewels | < 1 ms | < 8 ms |
| Falling Blocks hint / Jewels hint | 7 ms / 1 ms | 24 ms / 10 ms |

---

## 5. Assumptions and known gaps

* Sudoku "expert" means *beyond the implemented hard technique set*
  (chains/forcing needed); the hint then reveals a cell instead of explaining
  a chain.
* Minesweeper no-guess layouts are best effort on dense boards (see
  `logicOnly`).
* Mahjong hint search is budgeted; after the player leaves the dealer's plan
  it may return a `heuristic` pair on very hard positions.
* Sliding Tiles hints on 4×4/5×5 are optimal only when IDA* fits its budget;
  otherwise they follow the staged (non-optimal) plan.
* Tangram library figures use lattice-aligned tans; players may still use any
  45° orientation, and any exact cover wins.
* Pipe Connect hints steer towards the generated orientation even when an
  alternative valid arrangement exists.
* Falling Blocks has no T-spin / back-to-back bonuses and no 180° rotation.
* Arcade simulations expose `snapshot()` for replays and tests but have no
  `fromJson` restore (mid-game save of arcade runs is not supported).
* Road Crossing and Sky Jumper difficulty ramps are simple functions of
  distance; balance values (speeds, scores, targets) are first-pass numbers for
  the UI team to tune.
