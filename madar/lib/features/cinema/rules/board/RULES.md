# Madar Cinema – Tier 2 board games: rules, variants and assumptions

Pure-Dart rules engines and AI opponents for the Cinema's board games
(`lib/features/cinema/rules/board`). No Flutter, no UI strings: everything the
player reads is an enum / id the UI localises (`BoardGameId`, `GameEndReason`,
`…MoveKind`, `…Phase`, `AiLevel`).

Every item marked **☐ Confirm** below is an assumption made for the Jordanian
audience. Each one is a single option or default in code, so changing it is
cheap once confirmed.

---

## 0. Conventions shared by all games

| Topic | Decision |
|---|---|
| Interface | `BoardGameEngine` (`state`, `legalMoves([player])`, `apply(move)`, `isOver`, `result`, `currentPlayer`, `toJson` / `BoardGameEngine.fromJson`, `undo`) over pure `GameRules` (immutable state in, state out). `BoardAi.chooseMove(state, level, rng, budget)`. `boardGameKits[BoardGameId.x]` has everything a lobby needs. |
| Players | Integers `0..n-1`. Player 0 moves first unless a rule says otherwise (backgammon opening roll, dominoes highest double). |
| Chance | Dice and shuffles come from `BoardRng` (xoshiro128**, 32-bit, identical on every platform). Its state is **inside the game state**, so `seed + moves` replays a game exactly, `undo` rewinds the dice, and a saved game rolls the same dice after loading. |
| Explicit chance moves | Rolling is a move (`roll`) so the UI can animate it. A forced "no move" is also a move (`pass` / empty backgammon play); the UI may auto-apply a sole forced move. |
| Saving | `engine.toJson()` = `{game, v, initial, moves}`; `fromJson` replays and re-validates every move. Each state also has `toJson` / `fromJson`. |
| Hidden information | Domino hands live in the state (the UI must show only the viewer's hand). The AIs never read opponents' hidden tiles or the game RNG (tested: permuting hidden tiles / changing the dice seed does not change the AI's choice). |
| AI levels | `easy` = noticeably weak (random mistakes / shallow + noise), `medium` = sound but shallow, `hard` = strongest within the budget. |
| AI budget | `AiBudget(maxTime, maxNodes)`; default `AiBudget.phone` = 150 ms. `AiBudget.nodes(n)` is fully deterministic (used by tests). Every AI completes a minimal decision before honouring the budget, so it always returns a legal move. `chooseMoveInBackground(...)` runs any AI on an `Isolate`. |
| Platform | Chess Zobrist keys, checkers hashes and the four-in-a-row bitboards use 64-bit integers → Android/iOS/desktop (Dart VM/AOT). Not web-safe (the app has no web target). |
| Draw / end reasons | `GameResult{winners (empty = draw), reason, scores, ranking}`. |

---

## 1. Chess – الشطرنج

**Variant:** standard FIDE chess.

- Full rules: castling (both sides; not out of, through or into check),
  en passant, promotion to Q/R/B/N, check, checkmate, stalemate.
- **Draws are automatic** (no claim button): threefold repetition,
  fifty-move rule (100 half-moves without pawn move or capture), and dead
  positions by material: K v K, K+B v K, K+N v K, and any number of bishops
  all on one square colour. Checkmate on the 100th half-move wins.
  **☐ Confirm** automatic draws (FIDE makes threefold/fifty-move *claimable*;
  chess.com / most apps apply them automatically).
- Repetition compares placement, side to move, castling rights and an
  en-passant square **only when a pawn could pseudo-legally capture** (a
  pinned capturer still counts – a rare FIDE nuance not modelled).
- FEN import/export (`ChessState.fromFen`, `.fen`). Import normalises: castling
  rights without king/rook on their home squares are dropped; an en-passant
  square is kept only when a capture is possible (so export may show `-`).
  Malformed FENs (missing kings, side not to move in check, bad fields) throw
  `FormatException`.
- SAN export (`toSan`, `toSanLine`: `Nbd7`, `N1f3`, `Qh4e1`, `exd6`, `e8=Q+`,
  `O-O-O#`) and import (`fromSan`: tolerates `0-0`, missing `=`, `+#!?`
  suffixes, and UCI `e2e4`). Squares: 0..63, a1 = 0, h8 = 63.
- Perft verified on the six standard positions (start d4, Kiwipete d3,
  positions 3 (d4), 4 and its mirror, 5, 6 (d3)).

**AI:** negamax alpha-beta (PVS) + iterative deepening, transposition table
(2^16 entries ≈ 1 MB), null-move pruning, check extension, quiescence on
captures/promotions, ordering = TT move → MVV-LVA → killers → history.
Evaluation: material + Michniewski piece-square tables with a tapered king,
bishop pair, "mop-up" to finish won endings, dead-draw detection.
Levels: easy = 1-ply + quiescence with ±150 cp noise and 12 % random moves;
medium = 2-ply with ±30 cp noise; hard = full search within the budget
(~117 ms average under the 150 ms budget in tests).

---

## 2. Checkers / draughts – الداما (الضامة)

**☐ Confirm the default variant.** The brief asked for the variant commonly
played in Jordan, or – if unsure – American with a flying-kings option.
I am **not certain** what most Jordanian players expect: the game called
«الضامة» across the Levant and Egypt is often the *Turkish* (orthogonal)
game, while app players often know the diagonal game. So:

- **Default: English / American draughts** (`CheckersConfig.american`)
  – 8×8, 12 men each on the dark squares (a1 dark), player 0 on rows 0–2
  moves first.
  – Men move one square diagonally forward; kings one square in any
    diagonal direction.
  – Capturing is compulsory; any capture sequence may be chosen but it must
    be completed (no "maximum capture" rule); men capture forward only.
  – A man reaching the far row is crowned and **the move ends** there.
  – Captured pieces stay on the board until the move ends (cannot be jumped
    twice, they block).
- **Option: flying kings** (`CheckersConfig.americanFlyingKings`): kings move
  and capture any distance along a diagonal and may land on any empty square
  beyond the captured piece.
- **Preset: Turkish / Levantine Dama – الضامة التركية** (`CheckersConfig.turkish`):
  16 men each on rows 2–3 (7–6 for the opponent), **orthogonal** movement;
  men move/capture forward or sideways (never back); flying kings (rook-like);
  captured pieces are removed **immediately** (the capturer may cross their
  squares); the **maximum capture** is compulsory; a king may not reverse
  180° between two jumps; a man that reaches the far row mid-capture
  **keeps capturing as a man** and is crowned if it ends there
  (**☐ Confirm** this last point – sources differ).
- Other options on `CheckersConfig`: `menCaptureBackward`, `maximumCapture`,
  `removeCapturedImmediately`, `forbidReverseInCapture`,
  `promotionInCapture`, `noProgressLimit`.

End: a player with no legal move (no pieces or blocked) loses.
**☐ Confirm draw rules:** draw after **80 plies** (40 moves each) without a
capture or a man move, or on **threefold repetition**. Not implemented: draw
offers, the Turkish "lone king v lone man" shortcut, American "huffing".
Notation helper: `CheckersRules.squareNumber` gives standard 1–32 numbers.

**AI:** alpha-beta with iterative deepening and forced-capture extension;
evaluation = material (king ≈ 1.65 men, flying king ≈ 2.8), advancement,
back-rank guard, centre, and a trade-down bonus when ahead.

---

## 3. Backgammon – طاولة الزهر (الطاولة)

**Variant:** the standard game (known in the Levant as the "regular" /
«فرنجي» game – **☐ Confirm naming**), not محبوسة (Mahbusa, pinning) and not
other Levantine variants.

- 15 checkers each, standard start (2 on the 24-point, 5 on 13, 3 on 8,
  5 on 6). Board indices 0..23 from player 0's side; player 0 moves 23 → 0,
  player 1 moves 0 → 23.
- Hitting a blot sends it to the bar; a player with a checker on the bar
  must enter it first; 2+ opposing checkers block a point.
- Both dice must be used when possible; if only one can be used, the higher
  one must be (applies to bearing off too). Doubles play four times.
- Bearing off only with all 15 checkers home; a higher die may bear off
  from the highest occupied point.
- **Opening roll:** each player rolls one die until they differ; the higher
  die moves first **using both opening dice** (standard).
  Option `openingRollIsFirstMove: false`: the winner rolls afresh instead
  (**☐ Confirm** which one Jordanian players use).
- **Scoring:** single = 1; **مارس (gammon)** = 2 when the loser has borne
  off nothing; **backgammon** = 3 when additionally a loser's checker is on
  the bar or in the winner's home board. Options: `gammons`, `backgammons`
  (**☐ Confirm** whether the triple backgammon is counted locally – many
  coffee-house games count only مارس).
- **Doubling cube: optional, off by default** (`doublingCube`). When on:
  offer only before rolling, when centred or owned; the opponent takes
  (cube ×2, they own it) or drops (loses the current value). No Crawford /
  Jacoby rules, no beavers, no match play – a single game (a UI can sum
  `result.scores` across games for a match to 5 / 7).
- UI helpers: a `play` is a whole turn; `nextSteps(state, partial)` lists
  the next single-checker steps that can still complete a legal play, and
  `isLegal` accepts the steps in any order that reaches a legal position.

**AI:** hand-tuned evaluation in pips (pip count, exact blot-hit risk over
the 21 rolls, made points weighted by location, primes, anchors, bar and
closed-board pressure, stacking, race mode). easy = 35 % random, otherwise
1-ply with large noise, always rolls, always takes; medium = 1-ply;
hard = **2-ply expectiminimax** (best 6 candidates × all 21 opponent rolls ×
opponent's best reply) within the budget. Cube: double at ≥ 70 % estimated
wins, take at ≥ 24 %.

---

## 4. Dominoes – الدومينو

**Variant:** double-six (28 tiles), the line game, 2–4 players.
**☐ Confirm all of the following as "the Jordanian game":**

- 7 tiles each; with 2–3 players the rest form the boneyard (14 / 7 tiles);
  with 4 players nothing is left.
- **Draw game (سحب) by default:** a player who cannot play draws one tile at
  a time until able; with an empty boneyard they pass.
  Option `drawFromBoneyard: false` = **block game** (pass at once).
- **Opening:** round 1 is opened by the holder of the **highest double**, who
  must play it (4 players → always 6-6); if no double was dealt, the heaviest
  tile. Later rounds are opened by the **previous round's winner** with any
  tile (tied round → the next player after the previous opener).
  Option `highestDoubleEveryRound`.
- **Round end:** going out (دومينو) or blocked (every player passes in turn).
- **Scoring:** the round winner scores the pips left in **all opponents'**
  hands (partners' hands not counted). Blocked round: the side with the
  lowest pip total wins and scores the opponents' pips; a tie scores
  nothing. No "all fives" / multiples-of-5 scoring, no rounding.
- **Match:** first side to **101** points wins (`targetScore`; 0 = a single
  round). **☐ Confirm 101** (151 / 51 are also common).
- **Partnerships:** optional for 4 players (`teams: true`, 0 + 2 v 1 + 3).
- Voids: when a player passes (or draws), the numbers at the ends are
  recorded publicly as numbers they lack (`state.voids`) – the AI uses this
  exactly as an attentive human would.

**AI:** easy = random legal play; medium = heuristic (shed heavy tiles and
doubles, keep variety and control of the ends, block the next opponent's
known voids, avoid blocking a partner); hard = **determinised Monte-Carlo**:
unseen tiles are dealt at random (respecting public voids) into the other
hands and the boneyard, each candidate is played out with the medium policy,
best average round score wins.

---

## 5. Ludo – لودو

**Variant:** standard Ludo, 2–4 players, 4 tokens each, 52-square track,
6-square home column (5 squares + home). Two players sit opposite (seats 0
and 2).

Defaults (each is a `LudoConfig` option – **☐ Confirm the house rules**):

| Rule | Default | Option |
|---|---|---|
| Leave the yard | on a **6** | `exitRolls: [1, 6]` etc. |
| Extra turn | on a 6, on a capture, on reaching home | each switchable |
| Three sixes in a row | turn forfeited (no move) | `maxConsecutiveSixes` (0 = off) |
| Exact roll to reach home | required | `exactRollToFinish: false` = overshoot allowed |
| Safe squares | the four start squares + four star squares (start + 8) | `startOnly`, `none` |
| Landing on opponents | captures **all** opponent tokens on a non-safe square | – |
| Blockades (2+ tokens of one colour) | **off** (can be passed and captured) | `blockades: true` = cannot be passed or landed on |
| End | first player home wins | `playUntilLast` ranks everyone |

A six that cannot be used simply passes the turn. Entering the board lands on
one's own start square; while start squares are safe (default) it is shared
with any opponent there, otherwise opponents on it are captured.

**AI:** easy = random; medium = priorities (capture → home → leave yard →
escape danger → advance); hard = evaluates each resulting position (token
progress, exact number of opponent tokens that can hit each token next
roll, safe squares, captures, extra turns, strongest opponent's progress).

---

## 6. Mancala – المنقلة

**Default: Kalah(6,4) – كالاه** (`MancalaConfig.kalah`). 6 pits a side,
4 seeds each (option 3–6), stores.

- Sow counter-clockwise from any non-empty own pit, into one's own store,
  skipping the opponent's store.
- Last seed in one's own store → move again.
- Last seed in one's own empty pit → capture it and the seeds in the
  opposite pit, **only if the opposite pit is non-empty**
  (option `captureEmptyOpposite`). **☐ Confirm.**
- The game ends as soon as either side is empty **after any move**; each
  player then adds the seeds on their own side to their store.
  **☐ Confirm** (some rules check only at the empty player's turn).

**Option: Oware (Abapa) – أواري** (`MancalaConfig.oware`). No sowing into
stores; a lap of 12+ seeds skips the starting pit; captures when the last
seed makes 2 or 3 in an opponent pit, continuing backwards on the
opponent's side; **grand slam** (capturing all the opponent's seeds)
captures nothing (option `grandSlamCaptures`); a player must feed an empty
opponent if possible, otherwise the game ends and each player keeps their
side's seeds; more than 24 captured wins, 24–24 is a draw.

Both: to stop endless cycles, after `moveLimit` (200) plies without a
capture / store gain the game ends and each player keeps their side's
seeds. **Not implemented:** the traditional Levantine / Turkish منقلة
variants (e.g. 7-pit boards) – the brief asked for Kalah.

**AI:** alpha-beta with iterative deepening; extra turns keep the mover
(no depth spent); evaluation = store difference (+ seeds on one's side in
Kalah). easy = 40 % random, otherwise 1-ply with noise; medium = 4-ply.

---

## 7. Four in a row – أربعة في صف (كونكت فور)

7 columns × 6 rows, gravity, player 0 first, four in a row in any direction
wins, full board = draw. `state.winningLine` lists the winning cells.

**AI:** bitboards (49-bit), negamax alpha-beta, iterative deepening,
transposition table, never plays under an opponent's threat, answers forced
blocks, threat-count move ordering and evaluation. easy = 30 % random,
otherwise 2-ply with heavy noise; medium = 5-ply with light noise; hard =
full depth within the budget.

---

## 8. Tic-tac-toe – إكس-أو

3×3, X (player 0) first, three in a row wins, full board = draw.

**AI:** exact memoised minimax. hard = **perfect** (random choice among
equally optimal moves; quickest win / slowest loss) – tested never to lose
against every possible opponent strategy; medium = always wins/blocks when
possible, otherwise optimal half the time; easy = takes a win half the
time, otherwise random.

---

## Summary of decisions needing confirmation

1. Chess: automatic threefold / fifty-move draws (no claim).
2. Checkers: default American vs Turkish Dama (الضامة) as the Jordanian
   default; Turkish mid-capture crowning; 80-ply / threefold draws.
3. Backgammon: naming («فرنجي»); opening roll used as the first move vs
   re-roll; whether the triple backgammon counts; cube off by default.
4. Dominoes: draw game default, highest-double opening then winner leads,
   winner takes all opponents' pips, blocked-round rule and tie, target 101,
   optional partnerships.
5. Ludo: the house-rule table in §5 (six to leave, three-sixes forfeit,
   exact finish, safe stars, no blockades, stacks captured together).
6. Mancala: Kalah capture needs a non-empty opposite pit; end check after
   every move; 200-ply cycle limit.
