# Madar Cinema – Tier 2 board games: rules, modes and decisions

Pure-Dart rules engines and AI opponents for the Cinema's board games
(`lib/features/cinema/rules/board`). No Flutter, no UI strings: everything the
player reads is an enum / id the UI localises (`BoardGameId`, `BoardVariantId`,
`GameEndReason`, `…GameEnd`, `…MoveKind`, `…Phase`, `AiLevel`).

**The owner's decision, for every section below:** each board game starts
with its rules **as commonly played in Jordan**. Other regional and
international rule sets stay available as presets (lobby modes) or options.
Chess (FIDE), Mancala (Kalah), Four in a row and Tic-tac-toe keep their
standard rules. An item still marked **☐** is a detail of local practice that
the research could not pin down. Each one is a single option or default in
code, so changing it is cheap. §9 lists the decisions and the open items
together; §10 lists the sources.

---

## 0. Conventions shared by all games

| Topic | Decision |
|---|---|
| Interface | `BoardGameEngine` (`state`, `legalMoves([player])`, `apply(move)`, `isOver`, `result`, `currentPlayer`, `toJson` / `BoardGameEngine.fromJson`, `undo`) over pure `GameRules` (immutable state in, state out). `BoardAi.chooseMove(state, level, rng, budget)`. A `BoardGameKit` has everything a lobby needs for one mode. |
| Modes | `BoardVariantId` names every lobby mode (table below). `boardVariantKits[mode]` is a kit whose `newGame` starts that mode; `boardGameKits[game]` is the game's default mode, as commonly played in Jordan. `boardVariantKitsOf(game)` lists a game's modes, default first. All modes of a game share its rules object and AI, so any of them restores any save of that game. `kit.engine()` without `players` uses `kit.minPlayers`. Option mixes beyond the presets go through each game's config and `…State.initial(config: …)`. |
| Players | Integers `0..n-1`. Player 0 moves first unless a rule says otherwise: tawla (the opening roll; later games of a match the previous winner), dominoes (the highest double; later rounds the previous winner) and Ludo (a random first player drawn from the seed). |
| Chance | Dice and shuffles come from `BoardRng` (xoshiro128**, 32-bit, identical on every platform). Its state is **inside the game state**, so `seed + moves` replays a game exactly, `undo` rewinds the dice, and a saved game rolls the same dice after loading. |
| Explicit chance moves | Rolling is a move (`roll`) so the UI can animate it. A forced "no move" is also a move (`pass` / empty backgammon play); the UI may auto-apply a sole forced move. |
| Matches | Dominoes (rounds to 101, or 150 in All Fives) and tawla (games to 5, or 31 in ٣١) are matches inside one game state. Between rounds / games the phase is `roundOver` / `gameOver` and the only move is `nextRound` / `nextGame`; `result` is set when the match ends. `targetScore: 0` / `matchTarget: 0` plays a single round / game. |
| Saving | `engine.toJson()` = `{game, v, initial, moves}`; `fromJson` replays and re-validates every move. Each state also has `toJson` / `fromJson`. The Dama, dominoes and Ludo configs read the keys added in this round as optional, so earlier saves still load (§2.3, §4.3, §5.2); the tawla config requires every key, since no tawla save existed before it. |
| Hidden information | Domino hands live in the state (the UI must show only the viewer's hand). The AIs never read opponents' hidden tiles or the game RNG (tested: permuting hidden tiles / changing the dice seed does not change the AI's choice). |
| AI levels | `easy` = noticeably weak (random mistakes / shallow + noise), `medium` = sound but shallow, `hard` = strongest within the budget. |
| AI budget | `AiBudget(maxTime, maxNodes)`; default `AiBudget.phone` = 150 ms. `AiBudget.nodes(n)` is fully deterministic (used by tests). Every AI completes a minimal decision before honouring the budget, so it always returns a legal move. `chooseMoveInBackground(...)` runs any AI on an `Isolate`. |
| Platform | Chess Zobrist keys, checkers hashes and the four-in-a-row bitboards use 64-bit integers → Android/iOS/desktop (Dart VM/AOT). Not web-safe (the app has no web target). |
| Draw / end reasons | `GameResult{winners (empty = draw), reason, scores, ranking}`. Games with finer endings also keep the exact one: `CheckersState.end` (`CheckersGameEnd`), `BackgammonState.lastGame.end` (`TawlaGameEnd`) and `DominoState.lastRound` (`DominoRoundSummary`). Every `CheckersGameEnd` and `TawlaGameEnd` has a `GameEndReason` of the same name (`checkersEndReason`, `tawlaEndReason`). |
| Tests | `test/features/cinema/rules/board`. `self_play_test.dart` and `strength_test.dart` run **every mode** in `boardVariantKits`: random and AI self-play with invariants, JSON round trips, determinism, undo and cross-mode restore; hard beats easy with fixed seeds and node budgets (tawla modes as single games). Each game also has its own rule tests, named after the rule ids used below. |

**Modes** (`BoardVariantId`; the UI localises the names):

| Game (`BoardGameId`) | Default mode – as commonly played in Jordan | Other modes | Players |
|---|---|---|---|
| `chess` – الشطرنج | `chess` (FIDE) | – | 2 |
| `checkers` – الضامة | `damaJordan` | `damaTurkish`, `draughtsAmerican`, `draughtsAmericanFlyingKings` | 2 |
| `backgammon` – طاولة الزهر | `tawlaSheshBesh` (a match to 5) | `tawlaMahbusa` (a match to 5), `tawla31` (a match to 31), `backgammonInternational` (one game) | 2 |
| `dominoes` – دومينو | `dominoesJordan` | `dominoesAllFives`, `dominoesBlock`, `dominoesPlayOutLock` | 2–4 |
| `ludo` – لودو | `ludoJordan` | `ludoTeams` (partners) | 2–4 (partners: 4) |
| `mancala` – المنقلة | `mancalaKalah` | `mancalaOware` | 2 |
| `connectFour` – أربعة في صف | `connectFour` | – | 2 |
| `ticTacToe` – إكس-أو | `ticTacToe` | – | 2 |

---

## 1. Chess – الشطرنج

**Variant:** standard FIDE chess (mode `BoardVariantId.chess`).

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

## 2. Dama / checkers – الضامة (الداما)

**Default: «الضامة» as commonly played in Jordan** (`CheckersConfig.jordan`,
`CheckersVariant.jordan`). In Jordan and the rest of the Levant, «الضامة / الداما»
is the **orthogonal** game from the Turkish family: 16 men each, pieces move
along rows and columns only, and kings fly like rooks. The diagonal 12-man
game that many app players know is offered as a separate preset.
`CheckersState.initial()` and `boardGameKits[BoardGameId.checkers].newGame`
both start the Jordanian game. The older rule sets stay available as presets
(`CheckersVariant` / `CheckersConfig.x`). Lobby modes: `BoardVariantId.damaJordan`
(default), `damaTurkish`, `draughtsAmerican` and `draughtsAmericanFlyingKings`.

Coordinates: squares are `row * 8 + col`; a–h = columns 0–7, 1–8 = rows 0–7.
Row 0 is player 0's back row. Player 0 is **white** and moves first.

### 2.1 Rules of the Jordanian default

Rule numbers match the tests in `test/features/cinema/rules/board/dama_test.dart`
(`rule N: …`).

**Setup and turns**
1. 8×8 board, all 64 squares used. Each side has **16 men (حجر)** on its 2nd
   and 3rd rows (player 0: a2–h3, player 1: a6–h7). The nearest row and the two
   middle rows start empty.
2. White (player 0) moves first. Players alternate one move each; passing is
   not allowed.
3. So the opening has exactly **8 legal moves**: each front-row man steps
   forward.

**Men**
4. A man steps **one square forward, left or right** onto an empty square.
   It never steps backward or diagonally.
5. A man captures an orthogonally adjacent enemy piece (man or king) **in
   front of it or beside it** by jumping to the empty square straight beyond.
   It never captures backward.

**Kings (شيخ / ضامة – ☐ name)**
6. A king moves any number of empty squares along its row or column, forward
   or backward (`flyingKings`).
7. A king captures an enemy piece on its row or column from any distance
   (only empty squares between), and lands on **any** empty square of the run
   straight beyond it (subject to rule 10).
8. No piece may jump two adjacent pieces at once, or a piece of its own side.

**Capture obligations**
9. If any capture exists, the player must capture.
10. **Majority rule** (`maximumCapture`): only the sequences that take the
    greatest **number** of pieces are legal, counted over all the player's
    pieces. A king counts as one piece, like a man. Ties are a free choice of
    piece, route and landing square. Routes that take the same pieces with
    the same piece and end on the same square leave the same position, so
    `legalMoves` lists each such result **once**, with the first route found.
    For example, a flying king taking two pieces on one line may pause on any
    empty square between them. The UI should match a route the player taps
    by its start square, end square and captured pieces.
11. A sequence goes on while the same piece can capture again. Captured pieces
    **leave the board at once** (`removeCapturedImmediately`), so their squares
    can be crossed or landed on later in the same move.
12. Between two jumps a piece may go straight on or turn 90°, but **not turn
    back 180°** (`forbidReverseInCapture`). A later jump may reuse the old line
    after a 90° turn.

**Promotion**
13. A man whose move **ends** on the far row becomes a king, with king powers
    from its next turn.
14. A man that reaches the far row **during** a capture and can capture again
    keeps capturing **as a man** (sideways along that row) and is crowned when
    the move ends (`promotionInCapture: continueAsMan`, TÜDAF rule R5).
15. A quiet step onto the far row ends the move, even beside an enemy piece.

**Winning** (checked for the side about to move, right after each move)
16. You win when the opponent, on their turn, has no piece left or no legal
    move (`CheckersGameEnd.noLegalMoves`).
17. **Kings against a lone king** (`kingsBeatLoneKing`): if one side has
    **two or more kings** (men may also remain) and the other side has only a
    **single king**, the kings' side wins (`CheckersGameEnd.kingsVsLoneKing`).
    Exception: not while the lone king's side is to move and has a capture –
    that capture is forced and play goes on.
18. Resigning loses (a UI action; the engine has no resign move).

**Draws**
19. **One piece each** (`onePieceEachDraw`): a draw when each side has exactly
    one piece of any kind and the side to move has **no** capture
    (`CheckersGameEnd.onePieceEach`). If it has one, it must take the last
    piece and wins by rule 16.
20. **Repetition**: the same position with the same side to move for the third
    time since the last irreversible move (`CheckersGameEnd.threefoldRepetition`).
21. **No progress** (`noProgressLimit: 50`): 50 plies (25 moves each) in a row
    with no capture and no man stepping **forward** (`CheckersGameEnd.noProgress`).
    King moves and **sideways** man steps count toward the 50. Irreversible
    moves (`CheckersMoveGen.isIrreversible`) are exactly captures and forward
    man steps; only they reset the count and the repetition history. (A
    sideways step can be undone at once, so counting it as progress would let
    a game run forever.)
22. Draw by agreement: human games only, a UI dialog. The engine has no
    draw-offer move.

Order of the checks after each move (`CheckersRules.apply`, shared with the AI
through `CheckersMoveGen.adjudicate`): no legal move → Samara option → one
piece each → kings v lone king → no progress → repetition. The one-piece-each
draw is skipped while the side to move must capture. Kings v a lone king (and
the Samara option) is skipped while the lone piece's side is to move and must
capture. When the stronger side is to move it wins at once, since any capture
it has would take the last piece anyway. Every game ends: there are at most
31 captures and 176 forward man steps, with at most 50 plies between two of
them.

**Scoring.** A game is a win, draw or loss; `GameResult.scores` stays empty.
The match tally is kept by the UI (win 1, draw ½, loss 0, or W/D/L counters).

### 2.2 Presets (`CheckersVariant` → `CheckersConfig`)

| Variant (UI label idea) | Config | Differences from `jordan` |
|---|---|---|
| **«الضامة» – as commonly played in Jordan** (default) | `CheckersConfig.jordan` | – |
| «الضامة التركية» – Turkish federation rules | `CheckersConfig.turkish` | `kingsBeatLoneKing: false`: 2+ kings v a lone king is played out (to the 50-ply draw if not won). TÜDAF itself sets no move count; 50 is the app's rule. |
| «الداما القُطرية» – English/American draughts | `CheckersConfig.american` | Diagonal, 12 men each on the dark squares (a1 dark); men move and capture diagonally forward; kings move one square; any capture sequence (no majority rule) but it must be completed; captured pieces stay until the move ends (they block and cannot be jumped twice); crowning ends the move; draw after 80 plies with no capture or man move, or threefold; no material adjudication. The UI draws player 0 **dark** here, since dark moves first in these rules. |
| Diagonal with flying kings (house rule, not an established variant) | `CheckersConfig.americanFlyingKings` | As `american`, but kings move and capture any distance along a diagonal. |

`CheckersConfig.variant` returns the matching preset, or `null` for a custom
mix of options. Notation helper for the diagonal game:
`CheckersRules.squareNumber` gives the standard 1–32 numbers.

### 2.3 Options (`CheckersConfig` fields; `copyWith` builds a custom mix)

| Option | Field | Jordan default | Notes / source |
|---|---|---|---|
| Two or more kings beat a lone king | `kingsBeatLoneKing` | **on** | Off in `turkish`. Jawaker adjudicates it; with correct play it is always a win anyway (Wikipedia). |
| One piece each is a draw | `onePieceEachDraw` | **on** | Skipped while the side to move can capture (pydraughts' reading of the official rule). |
| King against a lone man wins ("Samara" rule, Palestinian) | `kingBeatsLoneMan` | off | Murray, via Wikipedia; the usual convention is a draw. Skipped while the man's side is to move and must capture. End: `CheckersGameEnd.kingVsLoneMan`. |
| Crowning mid-capture ends the move | `promotionInCapture: endsMove` | off (`continueAsMan`) | One dissenting implementation. ☐ Confirm family practice. |
| Draw after N quiet plies | `noProgressLimit` | **50** | 32 / 80 / 100 are one number away. ☐ Confirm. |
| Free choice of capture (no majority rule) | `maximumCapture: false` | off | One outlier source only. |
| Men capture backward | `menCaptureBackward` | off | Not a Jordanian rule; kept for completeness. |
| Captured pieces stay until the move ends | `removeCapturedImmediately: false` | off | The diagonal games' rule. |
| 180° turns between jumps allowed | `forbidReverseInCapture: false` | off | The diagonal games' rule. |
| Geometry / flying kings | `geometry`, `flyingKings` | orthogonal, on | Preset-defining. |

JSON: `CheckersConfig.toJson` writes every field. The three adjudication flags
are read as `false` when missing, so saves from before they existed still load.

### 2.4 Game ends (`CheckersGameEnd`, kept exactly in `CheckersState.end`)

| `CheckersGameEnd` | Result | Shared `GameEndReason` |
|---|---|---|
| `noLegalMoves` | the side to move loses | `noLegalMoves` |
| `onePieceEach` | draw | `onePieceEach` |
| `kingsVsLoneKing` | the kings' side wins | `kingsVsLoneKing` |
| `kingVsLoneMan` | the king's side wins (option) | `kingVsLoneMan` |
| `noProgress` | draw | `noProgress` |
| `threefoldRepetition` | draw | `threefoldRepetition` |

`checkersEndReason(end)` maps each end to the shared `GameEndReason` of the
same name (`core_test.dart` checks that every end has one). The UI can read
either `result.reason` or `CheckersState.end`. `CheckersVariant`,
`CheckersGameEnd` and `checkersEndReason` live in
`checkers/checkers_rules.dart` and are exported by `board_games.dart`.

### 2.5 AI

A single `CheckersAi` serves every preset and option: negamax alpha-beta with
iterative deepening and a forced-capture extension.

- It sees every game end the rules adjudicate, through the shared
  `CheckersMoveGen.adjudicate`: the one-piece-each draw, kings v a lone king,
  the Samara option, no progress (with the new irreversibility rule) and
  repetition. Inside the search, a position that repeats once already counts
  as a draw.
- A small contempt (a draw scores slightly below an even position) stops it
  from settling for a repetition in a balanced game.
- Evaluation: material (a king is worth about 1.65 men, a flying king about
  2.8), advancement (6 per row in Dama), the back-rank guard in the diagonal
  games, the centre, and a trade-down bonus when ahead.
- Levels:
  - `easy`: 15 % random moves, otherwise a depth-2 search with heavy noise.
  - `medium`: depth 4 with light noise. Noise never touches a proven win or
    loss, so it always takes the fastest win.
  - `hard`: iterative deepening within the budget.
- Budget: `AiBudget.phone` (150 ms) by default; tests use deterministic node
  budgets. With `AiBudget.nodes(4000)` (seeds from 900, alternating seats):
  - hard scored 5.5/6 against easy in the Jordanian game, 3.5/4 in
    `turkish`, and 4/4 in both diagonal presets;
  - in the Jordanian game, medium scored 4/4 against easy and hard 5.5/8
    against medium.

  `dama_test.dart` checks hard > easy for three presets and medium > easy
  for `jordan`; `strength_test.dart` plays hard against easy in all four
  presets (measured: 5.5/6, 3.5/4, 4/4 and 4/4).

### 2.6 Rules card for the rules screen (Arabic, own wording)

1. لكل لاعب ١٦ حجراً في صفّيه الثاني والثالث، والصف الأقرب إليه فارغ. الأبيض يبدأ.
2. الحجر يتقدّم خانة واحدة للأمام أو يميناً أو يساراً، ولا يرجع للخلف ولا يمشي بشكل مائل.
3. الحجر يأكل قطعة ملاصقة له من الأمام أو الجانب بالقفز فوقها إلى الخانة الفارغة خلفها، ويكمل الأكل ما دام يستطيع.
4. الأكل إجباري، ويجب أخذ أكبر عدد ممكن من القطع (الشيخ يُحسب قطعة واحدة كالحجر). عند التساوي تختار بحرية.
5. القطعة المأكولة تُرفع فوراً، ولا يجوز الرجوع بعكس الاتجاه مباشرة بين أكلتين.
6. الحجر الذي ينهي نقلته في الصف الأخير يصير شيخاً. إن وصله أثناء الأكل يكمل الأكل كحجر ثم يُرقّى.
7. الشيخ يتحرك أي مسافة في خط مستقيم للأمام أو الخلف أو الجانبين، ويأكل من بعيد وينزل في أي خانة فارغة بعد القطعة المأكولة.
8. تفوز إذا لم يبقَ لخصمك قطع أو لم يستطع الحركة. شيخان أو أكثر ضد شيخ وحيد فوز، إلا إذا كان على الشيخ الوحيد أكل إجباري.
9. التعادل: قطعة مقابل قطعة (إلا إذا كان صاحب الدور يستطيع أكل الأخيرة)، أو تكرار الوضع نفسه ثلاث مرات، أو ٢٥ نقلة لكل لاعب دون أكل ودون تقدّم أي حجر للأمام.

### 2.7 Open questions – ☐ Confirm with the owner

1. What the king is called on screen: «شيخ» (Gulf usage, the researcher's
   pick) or «ضامة» (Palestinian/Levantine: "the stone becomes a ضامة").
   No Jordanian source was found. The engine is unaffected.
2. Crowning mid-capture (rule 14). The Turkish federation says the man goes on
   capturing as a man; the family game might stop there instead. That is the
   `promotionInCapture: endsMove` toggle.
3. No-progress limit: 50 plies, or 32 / 80 / 100.
4. Whether "two kings beat a lone king" (rule 17) stays on by default.
5. Who starts the next game: alternate, or the loser starts (UI).
6. "White moves first" is high confidence for the formal rules but low for
   folk play. The UI chooses which person is player 0.

---

## 3. Tawla – طاولة الزهر: شيش بيش / محبوسة / ٣١

**As commonly played in Jordan.** In Jordan the tawla board carries three
games, and the lobby shows them as one entry, «طاولة الزهر», with three
modes:

| Mode (`TawlaVariant`) | Arabic (UI) | English | In short |
|---|---|---|---|
| `sheshBesh` (**default**) | «شيش بيش», subtitle «الطاولة العادية» | Shesh Besh (the hitting game, backgammon family) | hit lone checkers to the bar |
| `mahbusa` | «محبوسة» | Mahbusa (the pinning game, Plakoto/Tapa family) | land on a lone checker to pin it |
| `tawla31` | «٣١», subtitle «واحد وثلاثين» | Tawla 31 (the blocking race, Fevga/Moultezim family) | any checker blocks a point; match to 31 |

`BoardGameId.backgammon` is unchanged. Lobby modes:
`BoardVariantId.tawlaSheshBesh` (default), `tawlaMahbusa`, `tawla31` and
`backgammonInternational`. Code:
`backgammon/backgammon_rules.dart` (config, state, match layer, end tests),
`backgammon/backgammon_board.dart` (move generation shared with the AI),
`backgammon/backgammon_ai.dart`.

**Defaults.** `BackgammonConfig()` **is** the Jordanian default
(`BackgammonConfig.jordan`): شيش بيش, the opening winner rolls afresh,
«مارس» = 2, no triple, no cube, a match to 5 whose later games are started
by the previous winner. Named presets: `BackgammonConfig.mahbusa`,
`BackgammonConfig.tawla31`, and `BackgammonConfig.international` (the
engine's earlier behaviour: the opening dice are the first move, the triple
counts, a single game, an opening roll every game).
`boardGameKits[BoardGameId.backgammon]` starts the Jordanian default,
`boardVariantKits` has a kit for each named preset, and other option mixes
go through `BackgammonState.initial(seed: …, config: …)`.

### 3.1 Options (`BackgammonConfig`)

| Option | Jordanian default | Other values | Applies to |
|---|---|---|---|
| `variant` | `sheshBesh` | `mahbusa`, `tawla31` | all |
| `openingRollIsFirstMove` | `false`: the winner of the opening roll rolls both dice afresh | `true`: he plays the two opening dice (international) | all |
| `nextGameStarter` | `previousWinner`: he rolls at once, no opening roll (**☐ Confirm**) | `openingRoll` every game | all |
| `matchTarget` | `null` = 5 (شيش بيش, محبوسة) or 31 (٣١ and count-scored محبوسة) (**☐ Confirm 5**) | `0` = a single game; any other target (3, 7, 11 …) | all |
| `gammons` | `true`: «مارس» (the loser bore off nothing) = 2 | `false` | شيش بيش |
| `triple` (`TawlaTriple`) | `none`: «مارس» is the biggest win | `barOnly`: 3 when the loser also has a checker on the bar; `standard`: 3 when he has one on the bar or in the winner's home board | شيش بيش |
| `doublingCube` | `false` | `true`: offer before rolling, take or drop, the owner redoubles, no Crawford/Jacoby/beavers | شيش بيش only (rejected for the others) |
| `maxCube` | 64 | any value ≥ 1: a double that would take the cube above it is refused | شيش بيش + cube |
| `motherRule` | `false` (**☐ Confirm**) | `true`: see M10 | محبوسة |
| `mahbusaScoring` (`MahbusaScoring`) | `points`: 1 or «مارس» 2 | `checkersTo31`: the loser gives up his checkers left, match to 31 (historical) | محبوسة |
| `layout31` (`Tawla31Layout`) | `contrary`: both stacks on the own 24-point, facing each other (**☐ Confirm – most important open question**) | `parallel`: Fevga/Moultezim start in opposite corners, both moving the same way round | ٣١ |
| `runnerTarget` (`Tawla31RunnerTarget`) | `opponentStartQuadrant`: own pip ≤ 6 (contrary) / ≤ 12 (parallel) (**☐ Confirm**) | `opponentHalf`: own pip ≤ 12 | ٣١ |
| `noFullPrime` | `false` | `true`: see T10 | ٣١ |
| `maxTurns` | 2000 | engine guard only (E2) | all |

Fixed, not configurable: 15 checkers each and two dice; doubles are played
four times; the maximum-dice and higher-die rules; bearing off is never
compulsory; a tied opening roll is rolled again; the game ends the moment
the 15th checker is off; in محبوسة a pinned own checker forbids bearing
off; in ٣١ the runner rule applies.

`BackgammonConfig.fromJson` refuses what the constructor only asserts, with
a `FormatException`: the cube outside شيش بيش, a negative `matchTarget`,
`maxCube` below 1 and `maxTurns` below 1 (a turn cap of 0 would void every
game of a match, so the match could never end).

### 3.2 Board, turn and state

- Board indices 0..23 are the 24 points from player 0's side: index `i` is
  player 0's point `i + 1`. Player 0 moves 23 → 0 and bears off from 0..5.
  Player 1 moves 0 → 23 and bears off from 18..23 (his point `n` is index
  `24 − n`). In the parallel ٣١ layout player 1's point `n` is index
  `(n + 11) mod 24`: he starts on index 11, runs 11 → 0 → 23 → 12 and bears
  off from 12..17. `config.indexOf(player, pip)` / `config.pipOf(player,
  index)` convert for the UI.
- `points[i]` counts free checkers (`> 0` player 0, `< 0` player 1);
  `pinned[i]` is the owner of a checker pinned underneath (محبوسة), or −1.
  `pipCount` and every checker count include pinned checkers.
- Turn: `roll` (or `offerDouble`) → one `play` of up to four steps (an empty
  play is the forced pass; the UI may auto-apply it) → the other player.
  `nextSteps(state, partial)` lists the single-checker steps that can still
  complete a legal play, and `isLegal` accepts any step order that reaches a
  legal final position.
- Match state: `matchScores`, `gameNumber`, `turns` (plays in this game),
  `lastGame` (`TawlaGameSummary{number, winner|null, points, end}`) and the
  phase `gameOver`, whose only move is `nextGame`.

### 3.3 Rules shared by the three games

| # | Rule |
|---|---|
| G3 | **Opening roll.** Each player rolls one die; a tie is rolled again. The higher die starts. `openingRolls` keeps the pairs for animation. |
| G4 | The starter then **rolls both dice afresh** (`openingRollIsFirstMove: false`, default). With `true` he plays the two opening dice. |
| G5 | One checker moves by each die, or one checker by both dice in turn; the intermediate point must be a legal landing point. |
| G6 | Doubles are played four times. |
| G7 | Use as many dice as possible. If only one die of a non-double can be used, it must be the higher one when that is possible. Legality includes every variant's restriction (bar, pins, runner rule, bear-off conditions). With no legal play the turn passes. |
| G8 | Bearing off needs all 15 checkers in the home board (plus محبوسة's M8). A die equal to a point bears off from it; a die higher than the highest occupied point bears off from that point; otherwise the die must be played inside the board. |
| G9 | Bearing off is never compulsory. |
| G10 / E4 | The game ends the moment the 15th checker is off. **A play that bears off the 15th checker is complete even with dice left and counts as using every die**: with the last checker on the 6-point and 6-5, both `6/off` and `6/1 1/off` are legal (the engine used to refuse the first). |
| X1 | **Match.** The winner of a game adds its points to `matchScores`; the first to reach `matchTarget` wins the match (overshoot allowed) with `GameResult(winners: [w], reason: targetScoreReached, scores: matchScores)`. Otherwise the phase is `gameOver` and the only move is `nextGame`. |
| X2 | Targets: 5 for شيش بيش and محبوسة (**☐ Confirm**), 31 for ٣١; `matchTarget: 0` = a single game whose own `GameResult` is final. |
| X3 | `nextGame` resets the board and the cube (1, centred). The previous winner starts and rolls at once (`previousWinner`, **☐ Confirm**), or every game opens with an opening roll (`openingRoll`). After a void game there is always an opening roll. |
| X4 | No Crawford rule. A dropped double scores the cube value toward the match. |
| X5 | A match can never be tied: only a game's winner scores. **Void games** (E1, E2, E5) score 0–0 and are replayed; as a single game they are `GameResult.draw(reason, scores: [0, 0])`. |

### 3.4 شيش بيش – the default game

| # | Rule |
|---|---|
| S1 | Start (each side, own points): 2 on 24, 5 on 13, 3 on 8, 5 on 6 (pip count 167). |
| S2 | A point with two or more opposing checkers is closed. |
| S3 | Landing on a lone opposing checker hits it to the bar; one checker can hit on each step of its move. |
| S4 | A player with checkers on the bar must enter all of them (die `d` → own point `25 − d`) before any other move; if none can enter the turn passes; if one enters and the other die cannot be used, it is lost. |
| S5 | A checker hit while its owner is bearing off must re-enter and come home before bearing off resumes. |
| S6 | Single win = 1; **«مارس»** (the loser has borne off nothing) = 2; × cube. |
| S7 | Triple: none by default (`triple: none`, as in coffee-house play); options `barOnly` and `standard` (§3.1). |
| S8 | Cube off by default (`doublingCube`). |
| S10 | Ties are impossible (a mutual close-out cannot arise). |

### 3.5 محبوسة – Mahbusa

| # | Rule |
|---|---|
| M1 | Start: all 15 on the own 24-point (player 0 index 23, player 1 index 0); the stacks face each other at one end and move in opposite directions (pip count 360). |
| M2 | Opening as G3/G4. |
| M3 | No hitting and no bar. |
| M4 | A point is **open** to the mover when it is empty, his own, holds exactly one **unpinned** opposing checker, or is a point he controls (his checkers on top of a pinned opposing checker). It is **closed** when it holds two or more opposing checkers or the opponent controls it. |
| M5 | **Pinning («حبس»).** Landing on a lone opposing checker pins it under the mover's checker. The pinner may add checkers; the pinned side may not land there. A point holds at most one pinned checker. |
| M6 | **Release.** When the last pinner leaves the point (moved on, even with the second die of the same play, or borne off) the pinned checker is free again and can be pinned again later. |
| M7 | A pinned checker cannot move. With nothing movable the turn passes. |
| M8 | **Bearing off** needs all 15 home **and none of the mover's checkers pinned anywhere**, checked before every bear-off step: a pin that arrives after bearing off began stops it again. |
| M9 | Score 1, or «مارس» 2 when the loser has borne off nothing. No triple, no cube. Option `mahbusaScoring: checkersTo31`: the loser's checkers left, match to 31. |
| M10 | **Mother rule** (`motherRule`, default **off**, **☐ Confirm**). The *mother* is a player's pinned checker on his own start point (it is always his last one there). With the option on, after each play: if the opponent's mother is pinned and the mover has no checker left on his own start point, the mover wins a «مارس» at once (2, or 15 under `checkersTo31`; `TawlaGameEnd.motherPinned`); the symmetric test runs as a safety net. Off (default) the game is played out; a pinned mother nearly always ends in «مارس» anyway, because its owner can never bear off. |
| M11 / E5 | **Both mothers pinned** (always on, whatever `motherRule` says): neither player can ever bear off again, so the game ends at once as a **void, 0–0** (`bothMothersPinned`) and is replayed from an opening roll. |
| M12 | End tests after each play, in order: 15 off → both mothers pinned → the mother rule (if on) → after a forced pass, the frozen test E1 → the turn cap E2. |
| M13 | A start point still holding two or more checkers is simply closed; only the last checker there can be pinned. |

### 3.6 ٣١ – Tawla 31 (واحد وثلاثين)

| # | Rule |
|---|---|
| T1 | Start (`layout31: contrary`, default, **☐ Confirm first**): as محبوسة, 15 on the own 24-point, the stacks facing each other. Option `parallel` (Fevga/Moultezim): player 1 starts on index 11 (player 0's 12-point) and both run the same way round; the two sides' pip numbers are then related by `m ↔ m ± 12` instead of `m ↔ 25 − m`. |
| T2 | No hitting, no pinning: **any** opposing checker closes a point. A checker lands only on an empty point or on its own checkers. The opponent's stack on the own 1-point keeps that point closed while any of it remains. |
| T3 | **Runner rule («أول حجر»).** While the mover has borne nothing off and has no checker on or past the target (`runnerTarget`: own pip ≤ 6 contrary, ≤ 12 parallel; option `opponentHalf` = ≤ 12), only one checker may travel: from the full start any one of the 15, afterwards only that runner. The rule lifts the moment the runner arrives, even for the remaining dice of the same roll, and never comes back. A blocked runner means the turn passes. Consequence: with 6-6 on the very first turn the runner is home after three sixes and the fourth six may bring a second checker off the start. |
| T4 | Maximum dice use and the higher-die rule apply **with** the runner rule. |
| T5 | Bearing off as G8 (all 15 home). |
| T6 | Round score = the loser's checkers not yet borne off (1–15), reason `bearOffCount`; no multiplier. |
| T7 | Match to 31 (two perfect rounds give only 30, so at least three round wins are needed). |
| T8 | Next round's starter as X3. |
| T9 | Ties are impossible in normal play. |
| T10 | Option `noFullPrime` (default off): a play may not leave the mover holding six consecutive points (any count) with no opposing checker past them; if every maximal play would, the rule is waived for that turn. |

### 3.7 Engine guards (not traditional rules)

| # | Guard |
|---|---|
| E1 | After a forced pass in محبوسة or ٣١: if neither player has a legal play for any of the 21 rolls, the position can never change → void 0–0 (`positionFrozen`), replayed. In محبوسة every frozen position has both mothers pinned, so E5 has already ended the game: when both sides are stuck, every free checker of each side is on its own 1-point (a checker further back could step onto it, and a blockade of two or more opposing points lets its owner move within it), so each side's bear-off ban comes from a pinned checker, which can only lie under the other side's 1-point cluster – on its own start point, i.e. it is its mother. In ٣١ a frozen position cannot arise at all: one side can be stuck (with everything home a 6 always bears off, so it needs a checker – or its runner – behind six consecutive opposing points), but the owner of those six points then has its runner rule lifted and can always step within them. So E1 never fires in practice; it stays as a guard. |
| E2 | After `maxTurns` (2000) plays in one game, passes included → void 0–0 (`moveLimit`). A bug guard only. |
| E3 | All dice come from `BoardRng` inside the state, so seed + moves replays a whole match, including later opening rolls; `undo` rewinds across game boundaries. |

### 3.8 End reasons and names

**End reasons.** `lastGame.end` is a `TawlaGameEnd`: `bearOffSingle`,
`bearOffGammon` («مارس»), `bearOffBackgammon` (triple), `doubleDeclined`,
`motherPinned`, `bearOffCount` (٣١), and the voids `bothMothersPinned`,
`positionFrozen`, `moveLimit`. `GameResult.reason` uses the shared
`GameEndReason` of the same name (`tawlaEndReason`); a finished match uses
`targetScoreReached`.

**UI flavour (optional, ☐ Confirm).** Dice are called larger die first:
يك 1, دو 2, سي 3, جهار 4, بيش/بنج 5, شيش 6 («شيش بيش» = 6-5, «سي يك» = 3-1).
Aliases «عادي» / «إفرنجي» for شيش بيش, and the doubles' café names, only
after the owner confirms them. The engine itself has no strings.

**Not implemented:** «يهودية» / Gioul / Gul bara (known in the Levant, but
not one of Jordan's three standard games).

### 3.9 AI

**`BackgammonAi`** (all variants, never reads the dice RNG): a
hand-tuned evaluation in pips per variant –
شيش بيش: pip count, exact blot-hit risk over the 21 rolls, made points by
location, primes, bar and closed-board pressure, stacking, race mode;
محبوسة: pip count, pinned checkers (own −, opponent +, weighted by how far
from home they are stuck), the mothers, points held in front of opposing
checkers and blocks, and the exact risk of a lone checker being pinned;
٣١: pip race, points held in the opponent's path and blocks, the runner rule
for both sides, stacking. easy = 35 % random, otherwise 1-ply with large
noise, always rolls and takes; medium = 1-ply; hard = **2-ply
expectiminimax** (best 6 candidates × all 21 opponent rolls × the
opponent's best reply) within the budget. A play that ends the game by
any rule (15 off, the mother rule, a void game; `BackgammonRules.playEnd`,
the same test `apply` uses) is valued by its outcome rather than by its
position: a win at 1000 + 100 × its points, a void at 0 (the game is
replayed). So hard takes a winning play at once, and medium and hard pick
the finish that scores most (with `triple: barOnly`, hitting on the way
off turns 2 points into 3). Cube (شيش بيش only): double at ≥ 70 % estimated
wins, take at ≥ 24 %; a double is never offered past `maxCube`. In seeded
tests with `AiBudget.nodes(2000)`, hard beats easy 15/16 (شيش بيش), 16/16
(محبوسة) and 16/16 (٣١), and medium beats easy 13/16, 16/16 and 15/16.
`strength_test.dart` also plays single games of all four tawla modes
(international: hard 15/16 in a probe).

### 3.10 Open questions – ☐ Confirm with the owner

Most important first:

1. **٣١ start layout** (T1): both stacks at the same end, facing each other
   (`contrary`, the default), or in opposite corners going the same way round
   (`parallel`, Fevga style)?
2. **محبوسة mother rule** (M10): off (the default), or does pinning the
   opponent's last start-point checker win a «مارس» at once?
3. **Match length** for شيش بيش and محبوسة: 5 (the default)?
4. **Who starts game 2, 3, …** of a match: the previous winner (the
   default), or a new opening roll?
5. **٣١ runner target** (T3): the opponent's start quarter (the default) or
   the opponent's half?
6. **Screen names and dice call-outs** (§3.8, UI only).

---

## 4. Dominoes – الدومينو («دومينو»)

**Default: «دومينو» as commonly played in Jordan.** It is the double-six line
game with count scoring to 101: the draw game for 2–3 players and partners
for 4. `DominoConfig.jordan(players: n)` is the same as `DominoConfig(players: n)`.
Both `DominoState.initial()` and `boardGameKits[BoardGameId.dominoes].newGame`
start this game. The other ways to play are presets (§4.2) or options (§4.3).
Lobby modes: `BoardVariantId.dominoesJordan` (default), `dominoesAllFives`,
`dominoesBlock` and `dominoesPlayOutLock`, one per preset.

Seats: players are `0..n-1`. The engine's next player is `p + 1`. The UI
draws that player **to the right**, so play goes counter-clockwise (D-10).
Hands are part of the state, so the UI must show only the viewer's hand.

### 4.1 Rules of the Jordanian default

Rule ids match the test names in
`test/features/cinema/rules/board/dominoes_jordan_test.dart` (for example
`D-19, E-5: …`).

**Tiles and deal**
- **D-1–D-3:** The set is double-six: 28 tiles and 168 pips. Each player gets
  7 tiles. The rest form the stock («الكومة»): 14 tiles with 2 players, 7
  with 3, and none with 4.
- **N4 / D-4:** With four players, partners sit opposite (0 + 2 against
  1 + 3). `teams` defaults to `players == 4`.

**Who leads**
- **D-5, D-6, E-1:** In round 1, whoever holds the highest double (6-6, then
  5-5, and so on down) leads with it and must play it. With four players this
  is always 6-6.
- **D-7, E-2:** If nobody was dealt a double, the heaviest tile leads. On
  equal pips the higher number wins, so 6-3 beats 5-4. This happens in about
  0.3 % of 2-player deals.
- **D-8:** Later rounds are led by the previous round's winner, with any
  tile.
- **D-9:** After a tied blocked round, the player after the previous leader
  leads.

**A turn**
- **D-11–D-13:** Play one tile that matches an end, choosing the tile and the
  end. The line has two ends; there is no spinner. A player who can play must
  play, and may not draw instead.
- **D-14, E-3:** A player who cannot play draws one tile at a time until they
  can play, then plays.
- **E-4:** With an empty stock, the player passes («دق»).
- **Voids:** After a pass, the numbers at the two ends are added to that
  player's public voids (`state.voids`). A draw replaces them with the two
  end numbers, because the drawn tiles are unknown and may carry numbers the
  player lacked before. The AI uses them the way an attentive player would.
- **D-15:** In the block game (option), a player who cannot play passes at
  once.
- **D-16:** No reserve. Every tile of the stock may be drawn.

**The round ends**
- **D-17: going out («دومينو»).** A player plays their last tile.
- **D-18: blocked.** Every player passes in turn.
- **D-19, E-5, E-13: locked («قفلت»).** The round is blocked **at once**,
  even while tiles remain in the stock, and nobody draws. The line is locked
  exactly when both ends show the same number `v` and all seven tiles
  carrying `v` are in the line (`DominoState.lineLocked`).
  - Why this check is enough: every number is on 8 half-tiles. Inside the
    line they pair up at the joints, so when all 7 tiles of `v` are in the
    line, `v` shows at both ends or at neither.
  - If the ends differ, the line is never locked.
  - A test checks this against a brute-force "nothing outside the line
    matches" check on self-play states.
- **E-6:** If the last tile also locks the line, it counts as going out.
- **E-14:** With four players there is no stock. A lock then gives the same
  result as four passes; it only ends the round sooner.
- The summary records the lock: `DominoRoundSummary.locked` and
  `DominoRoundSummary.stockLeft`. The UI can then show «قفلت».

**Scoring (count)**
- **D-20, E-7: going out.** The winner's side scores the pips left in every
  opponent's hand. The partner's hand and the stock are not counted.
- **D-21:** There is no rounding.
- **D-22: blocked.** The side with the lowest pip total wins. Partners' pips
  are added together. The winning side scores the opponents' pips. The next
  round is led by that side's lightest hand (the first seat on equal pips).
- **D-23, E-8, E-9:** A tie for the lowest total scores nothing.
- **D-24:** Scores only go up, and only one side scores in a round.
- **E-10:** If the opponent holds only [0|0], the winner scores 0 but still
  wins the round and leads the next one.

**Match**
- **D-25, E-11:** The first side to reach **101** wins. This is checked only
  at the end of a round.
- **D-26:** `targetScore: 0` plays a single round.
- **E-17:** Every round ends: at most 28 plays and the stock's draws, and `n`
  passes in a row end it. Matches end with probability 1; a test plays
  seeded matches of every variant to the end.

### 4.2 Presets

| Preset | Config | Differences from the default |
|---|---|---|
| **«دومينو» – Jordan** (default) | `DominoConfig.jordan(players: n)` | – |
| «الخمسات» – All Fives on a line | `DominoConfig.allFives(players: n)` | `scoring: allFives`, target **150**, hand pips rounded to 5 (§4.4) |
| Block game («بلوك») | `DominoConfig.block(players: n)` | `drawFromBoneyard: false` |
| Lock played out (the engine's old behaviour, as in several Arab-market apps) | `DominoConfig.playOutLock(players: n)` | `endWhenLocked: false`: the player to move draws the whole stock, then everyone passes. |

`DominoConfig.copyWith` builds a custom mix. If `players` changes and `teams`
is not given, `teams` becomes `players == 4` again.

### 4.3 Options (`DominoConfig` fields)

| Field (JSON key) | Jordan default | Missing key | Values / meaning |
|---|---|---|---|
| `players` (`players`) | lobby: 2 (2–4) | required | – |
| `teams` (`teams`) | `players == 4` | required | 0+2 against 1+3 |
| `drawFromBoneyard` (`draw`) | `true` | required | `false` = block game (D-27) |
| `handSize` (`hand`) | 7 | required | 5 = the Gulf deal for 3–4 players (D-3′) |
| `targetScore` (`target`) | **101** (All Fives: **150**) | required | presets 51 / 101 / 151 / 201; All Fives 100 / 150 / 250; 0 = one round |
| `highestDoubleEveryRound` (`doubleEveryRound`) | `false` | required | D-28: every round opens with the highest double |
| `endWhenLocked` (`lockEnds`) | **`true`** | `false` | D-19; `false` = the lock is played out |
| `noDoubleOpening` (`noDouble`) | `heaviestTile` | `heaviestTile` | `reshuffle`: deal again from the game RNG until a double is dealt (deterministic) |
| `stockReserve` (`reserve`) | 0 | 0 | 2 = the last two stock tiles are never drawn (D-16, E-15) |
| `scoring` (`scoring`) | `count` | `count` | `allFives` (§4.4) |
| `rounding` (`round`) | `none` | `none` | `nearestFive` = `round5` on hand points (All Fives always rounds) |
| `blockedScoring` (`blockedScore`) | `opponentsPips` | `opponentsPips` | `difference` = the opponents' pips minus your own side's, never below 0 (with `lowestPlayer` the winning side can hold the larger total; it then scores 0 but still wins the round and leads next, D-24); `allHands` = every hand, your own included (D-29) |
| `blockedTie` (`blockedTie`) | `noScore` | `noScore` | `lockerLoses` (D-30): if exactly two sides tie for the lowest and one of them played the last tile, the other side wins and scores as an outright winner. Every other tie scores nothing. |
| `blockedCompare` (`blockedCompare`) | `sideTotal` | `sideTotal` | `lowestPlayer`: the side of the single lightest hand wins (it matters only with partners) |

`round5(x) = ((x + 2) ~/ 5) * 5`, so 2 → 0, 3 → 5, 7 → 5, 8 → 10, 12 → 10
and 13 → 15 (`DominoRules.round5`).

The settlement rule is `DominoRules.settle(config, pips, outPlayer,
lastMover)`. The engine and the AI's simulations both use it.

**Save compatibility (E-16).** Keys added after the first release are
optional. An old save without `lockEnds` loads with `endWhenLocked: false`,
so the saved moves still replay legally. New state fields are also optional
in JSON: `last` (the last mover) and `endPts` (All Fives points this round).
So are the new summary fields: `endPts`, `stock` and `locked`.

### 4.4 Option «الخمسات» (All Fives, line game)

The deal, the lead, drawing, passing, locking and blocking are the same as in
§4.1.
- **F-1: end count.** An empty line counts 0. One tile counts its pips
  (5-5 → 10, 6-4 → 10). Otherwise, add the two exposed numbers; a double at
  an end counts both halves. So `[5|5][5|3]` = 13, and a line with doubles at
  both ends, `[6|6] … [4|4]`, = 20. See `DominoState.endCountOf`.
- **F-2:** After every play, if the end count is a multiple of 5 (and above
  0), the mover's side scores it at once.
- **E-11 (fives):** If that takes the mover's side to the target, the match
  ends there, in mid-round. The summary's `end` is `targetReached`, and no
  going-out bonus follows.
- **F-3:** Going out adds `round5(opponents' pips)`, after the last tile's
  end count.
- **F-5:** A blocked round, locked or not, adds `round5(opponents' pips)` to
  the lowest side. A tie scores nothing.
- **F-6:** The target is 150. Every score is a multiple of 5, so 151 would
  play exactly like 155. With target 0 (one round), the side with more points
  wins.
- `DominoRoundSummary.endPoints` holds each side's end-count points for the
  round. The UI may show scores ÷ 5; the engine keeps real points.
- **Not implemented:** the spinner (the first double opening four ways). It is
  the US form, not the Jordanian line game.

### 4.5 AI (`DominoAi`, every preset and option)

- **easy:** a random legal play.
- **medium:** a heuristic.
  - It sheds heavy tiles and doubles.
  - It keeps a variety of numbers and control of the ends.
  - It blocks the next opponent's known voids and avoids blocking a
    partner's.
  - In All Fives it takes end counts (1.5 × the points).
  - Before a play that would lock the line, it estimates every hidden hand
    as average unseen tiles, using only public information. It locks only if
    its own side is likely the lighter one.
  - Under `playOutLock` it counts the stock that the next player would have
    to draw.
- **hard:** determinised Monte-Carlo.
  - Unseen tiles are dealt at random into the other hands and the stock,
    respecting public voids.
  - Each candidate play is played out with a fast medium-like policy under
    the config's exact rules: locks, reserve, end counts and settlement.
  - It picks the play with the best average points for its side, minus the
    opponents' average.
- **Budget:** `AiBudget.phone` by default.
- **Measured strength:** with `AiBudget.nodes(3000)`, seeds 900–907 and
  alternating seats, hard scored 8/8 against easy in jordan, fives, block,
  playOutLock and jordan partners, and 7/8 in fives partners. Against medium
  it scored 8/12 (jordan) and 57–75 % in a 40-game probe per variant.
  `strength_test.dart` plays 8 seeded two-player matches of hard against
  easy in each of the four presets.

### 4.6 Rules card for the rules screen (Arabic, own wording)

1. تُلعب بطقم «دبل ستة» من ٢٨ حجراً. لكل لاعب ٧ أحجار، والباقي «كومة» للسحب عند اللعب باثنين أو ثلاثة.
2. في الجولة الأولى يبدأ صاحب أعلى دبل (الدوشيش أولاً) ويجب أن يلعبه. إن لم يُوزَّع أي دبل يبدأ صاحب أثقل حجر. في الجولات التالية يبدأ الفائز بالجولة السابقة بأي حجر.
3. تضع حجراً يطابق رقم أحد طرفَي الخط. إن كان معك حجر يصلح فيجب أن تلعبه.
4. إن لم تستطع اللعب تسحب من الكومة حجراً بعد حجر حتى تستطيع، فإن فرغت الكومة «تدقّ» ويمرّ الدور.
5. من يُنهي أحجاره أولاً يربح الجولة ويأخذ مجموع نقاط أحجار خصومه. أحجار الشريك والكومة لا تُحسب.
6. إذا «قفلت» اللعبة، أي صار الطرفان على الرقم نفسه ونزلت كل الأحجار السبعة التي تحمله، تنتهي الجولة فوراً ولا يسحب أحد. وتنتهي كذلك إذا دقّ الجميع بالتتابع.
7. في الجولة المقفولة يربح الطرف الأقل مجموعاً (لاعباً أو فريقاً) ويأخذ نقاط خصومه، وإذا تساوى الأقل فلا نقاط لأحد.
8. عند اللعب بأربعة يكون كل اثنين متقابلين شريكين.
9. أول من يصل إلى ١٠١ نقطة يربح المباراة.

### 4.7 Open questions – ☐ Confirm with the owner

1. **Locked line (D-19).** When the line locks with tiles still in the pile,
   do you stop and count at once (the default), or does the next player draw
   the whole pile (`playOutLock`)?
2. **Two players.** 7 tiles each, drawing one at a time, and the whole pile
   may be drawn (D-14, D-16)? What do you call the pile? The UI label is
   «الكومة».
3. **Target.** 101 (the default), or 51, 151 or 201 (D-25)?
4. **Blocked round.** Does the lighter hand take the other's pips (the
   default) or the difference? Is a tie worth nothing (D-22, D-23)?
5. **No double dealt.** The heaviest tile (the default), or a re-deal (D-7)?
6. **«الخمسات».** Is it ever played? If so, to 150 (F-6)?
7. **Four players.** Partners by default (D-4)?
8. **Tied round.** The player after the previous leader leads (D-9). No
   source contradicts this.

---

## 5. Ludo – لودو

**Default: «لودو» as commonly played in Jordan.** It is the app-style game.
`LudoConfig.jordan(players: n)` is the same as `LudoConfig(players: n)`. Both
`LudoState.initial()` and `boardGameKits[BoardGameId.ludo].newGame` start it.
Lobby modes: `BoardVariantId.ludoJordan` (default, 2–4 players) and
`ludoTeams` (`LudoConfig(players: 4, teams: true)`, exactly 4 players, L-29).
Every other option in §5.2 is set through `LudoConfig`.

**Board**
- There are 52 shared squares. Seat `s` enters on absolute square `13 s`.
- A token's progress is:

  | Progress | Where the token is |
  |---|---|
  | −1 | yard |
  | 0–50 | shared track, counted from its own start |
  | 51–55 | its own home column |
  | 56 | home |
  | 57 (`kLudoBeforeStart`) | the shared square just before its own start; only with `captureToEnterHome` |

- Two players use seats 0 and 2 (opposite). Three players use seats 0, 1
  and 2.
- Turn order follows the direction tokens travel. For the Arab
  "to the right" habit, the UI may mirror the whole board; the rules stay the
  same (L-3).

### 5.1 Rules of the Jordanian default

Rule ids match the test names in
`test/features/cinema/rules/board/ludo_jordan_test.dart`.

**Setup and turns**
- **L-1, L-2:** 2–4 players, 4 tokens each, all starting in the yard.
- **L-3: first player.** The first player is chosen at random, which is the
  same as a roll-off. The draw comes from a separate generator salted from
  the seed (`BoardRng(seed ^ 0x9E3779B9)`), so the dice stream is untouched.
  The chosen seat is stored in the initial state, so replays are exact.
  `firstPlayer: seat0` gives the old behaviour.
- **L-4, L-5:** One die. A player who can move must move.

**Leaving the yard**
- **L-6:** Only a **6** brings a token out, onto its own start square. The
  whole roll is used.
- **L-7:** A 6 may move a token that is already out instead.
- **L-8:** With every token in the yard, the player gets one roll
  (`yardRollAttempts: 1`).

**Extra rolls**
- **L-9:** A 6 earns another roll.
- **L-10:** A capture earns another roll.
- **L-11:** A token reaching home earns another roll.
- **L-12:** A move earns **at most one** extra roll, even if it is a 6 that
  also captures.
- **L-13: third six.** A third 6 in a row ends the turn with no move, and the
  moves made with the first two sixes stand. An extra roll earned by
  anything other than a 6 breaks the run of sixes.
- **L-14, E-L2′:** A 6 that no token can use passes the turn. There is no
  bonus roll, and the run of sixes resets.

**Moving and capturing**
- **L-15:** A token goes one lap, then turns into its own home column.
- **L-16:** Tokens capture only by **landing**. Passing over a token does
  nothing.
- **L-17: safe squares.** The 4 start squares and the 4 stars, 8 squares
  after each start: absolute 0, 8, 13, 21, 26, 34, 39 and 47. Nobody is
  captured there.
- **L-18, E-L6′:** Landing on a non-safe square sends **every** opponent
  token there back to its yard, pairs included. Tokens of one colour have no
  extra power. ☐ The sources disagree on this rule.
- **L-19:** No blockades.
- **L-20:** The home column is private. Nothing can land on or capture a
  token there.
- **L-21:** A token entering onto a safe start square shares it with any
  opponent already there.

**Finishing**
- **L-22:** A token needs the **exact** roll to reach home.
- **L-23:** The first player to bring all 4 tokens home wins. The result
  lists `ranking: [winner]` and `scores` = tokens home per player.

### 5.2 Options (`LudoConfig` fields)

| Field (JSON key) | Jordan default | Missing key | Values / meaning |
|---|---|---|---|
| `players` (`players`) | lobby: 2 (2–4) | required | – |
| `tokensPerPlayer` (`tokens`) | 4 | required | – |
| `exitRolls` (`exitRolls`) | `[6]` | required | `[1, 6]` = the house rule where a 1 also brings a token out (L-25) |
| `extraTurnOnSix` (`sixAgain`) | `true` | required | – |
| `maxConsecutiveSixes` (`maxSixes`) | 3 | required | 0 = no limit |
| `extraTurnOnCapture` (`captureAgain`) | `true` | required | – |
| `extraTurnOnHome` (`homeAgain`) | `true` | required | – |
| `exactRollToFinish` (`exact`) | `true` | required | `false` = an overshoot still reaches home (L-26) |
| `safeSquares` (`safe`) | `startAndStars` | required | `startOnly`, `none` (L-27) |
| `blockades` (`blockades`) | `false` | required | `true` = two or more tokens of one colour can be neither passed nor landed on (L-19). This also stops an opponent's exit onto that start square (E-L11). |
| `playUntilLast` (`untilLast`) | `false` | required | play on for 2nd and 3rd place (L-24); ignored with `teams` |
| `safePairs` (`safePairs`) | `false` ☐ | `false` | `true` = two or more tokens of one colour on a non-safe square cannot be captured, but can be passed, and an opponent may land and share the square. `blockades` implies it. |
| `firstPlayer` (`first`) | `random` | `seat0` | L-3 |
| `yardRollAttempts` (`yardTries`) | 1 ☐ | 1 | 3 = the family rule: three rolls per turn while none of your tokens is on the board. A 6 on any try exits as usual (E-L12). The count is `state.yardTries`, JSON `tries`. |
| `bonusRollOnUnusableSix` (`unusableSixAgain`) | `false` ☐ | `false` | An unusable 6 still earns another roll, as long as a 6 earns one at all (`extraTurnOnSix`). The run of sixes is kept, so the third 6 still ends the turn. |
| `captureToEnterHome` (`mustCapture`) | `false` | `false` | L-28, see below |
| `teams` (`teams`) | `false` | `false` | L-29, see below |

**`captureToEnterHome` (L-28, E-L13).** A player's tokens may enter their
home column only after that player has captured at least once
(`state.captured`, JSON `captured`). Until then, a token that would pass
square 50 keeps lapping.
- From 50, a roll of 1 goes to `57`: the shared square just before its own
  start, which is not safe and can be captured. A roll of 2 goes to its own
  start square (progress 0), and so on.
- From 57, a roll of `d` goes to `d − 1`.
- A token never gets stuck.
- A token already past its entrance laps once more, even after the capture.

**`teams` (L-29, 4 players, 0 + 2 against 1 + 3).**
- Partners never capture or block each other.
- A player whose tokens are all home still rolls on their turn and moves the
  **partner's** tokens (`state.movingPlayer`; `LudoMove.move(t)` always means
  token `t` of the moving player).
- The team wins when all 8 tokens are home. The result lists both partners as
  winners and as the ranking.

**Deferred.** Two colours per player (L-30) is a lobby feature. Run it as a
4-player game in which one person controls two opposite seats; it needs no
engine rule.

**Save compatibility (L-C4).** Every new key is optional, and a missing key
takes the value in the table above.

### 5.3 AI (`LudoAi`, every option)

- **easy:** random.
- **medium:** priorities, in this order: capture, reach home, leave the yard,
  escape danger, advance.
- **hard:** a lookahead over the dice (expectimax).
  - For each candidate, it averages over the 6 faces of the next roll. That
    roll is the next player's, or its own after a bonus roll.
  - For each face, the player on roll picks their best move by a one-ply
    evaluation.
  - With two players, or with partners, it looks one roll ahead. In a
    free-for-all with 3–4 players it then deepens through the following
    opponents' rolls, up to `players − 1` rolls, until it is its own turn
    again, while the budget lasts. A depth cut short by the budget is
    discarded, so the deepest complete search decides.
  - The result is scored on: token progress; the exact number of opponent
    tokens (and yard exits) that can hit each token; safe squares and safe
    pairs; captures, worth more while a capture is still needed to open the
    column; and the strongest opponent's progress. Partners count as one
    side.
  - If the budget runs out before the first roll is searched, it keeps the
    one-ply choice.
- **Measured strength:** with `AiBudget.nodes(500)`, over 24 seeded games per
  variant with alternating seats, hard beat easy 21–24 times. Over 60 games,
  hard beat medium 35 times (jordan). In a 200-game probe, hard beat medium
  54–68 % in every 2-player and partnership variant, and beat easy about
  90–98 %.
- **Four players, free-for-all:** one hard AI against three medium ones won
  38 of 120 seeded games (seeds 500–619, a fair share is 30; the test
  requires 34). Over 700 probe games it won 29.9 %, against a fair share of
  25 %. A one-roll lookahead only matched medium there (25.1 %). With three
  players, hard wins about 36 % against a fair share of 33 %, with or
  without the deeper search.
- **Speed:** with `AiBudget.phone` a 4-player decision takes about 6 ms on
  average and stays within the 150 ms budget.
- `strength_test.dart` plays hard against easy in both modes: 24 two-player
  games of `ludoJordan` and 12 partnership games of `ludoTeams` (the two
  seat parities are the two teams; hard won 24/24 and 12/12).

### 5.4 Rules card for the rules screen (Arabic, own wording)

1. لكل لاعب ٤ أحجار تبدأ في «البيت». يُختار من يبدأ بالقرعة ثم يدور الدور.
2. لا يخرج حجر من البيت إلا برمية ٦، ويوضع على خانة البداية.
3. الـ٦ تعطيك رمية إضافية، وكذلك أكل حجر للخصم أو إيصال حجر إلى النهاية. النقلة الواحدة تعطي رمية إضافية واحدة فقط.
4. إذا رميت ٦ ثلاث مرات متتالية تنتهي نوبتك بلا حركة، وما لعبته بالستتين الأوليين يبقى كما هو.
5. إن لم تستطع استخدام الرمية ينتقل الدور، ولو كانت ٦.
6. إذا وقف حجرك على خانة فيها أحجار للخصم في غير الخانات الآمنة، ترجع كلها إلى بيتها. المرور فوقها لا يأكلها.
7. الخانات الآمنة: خانات البداية الأربع والنجوم الأربع (الخانة الثامنة بعد كل بداية).
8. بعد دورة كاملة يدخل الحجر ممرّه الملوّن، ولا يصل إلى النهاية إلا بالرقم المضبوط.
9. أول من يوصل أحجاره الأربعة إلى النهاية يربح.

### 5.5 Open questions – ☐ Confirm with the owner

1. **Two of your own tokens on one square (L-18).** Are both captured (the
   default), are they safe (`safePairs`), or do they block the way
   (`blockades`)? The sources disagree. **Ask this first.**
2. **Extra rolls (L-10, L-11).** Do a capture and a token reaching home each
   give another roll?
3. **Who starts (L-3).** A random first player (the default)?
4. **All tokens in the yard (L-8).** One try for a 6, or three?
5. **Unusable 6 (L-14).** The turn simply passes (the default)?
6. **3–4 players (L-24).** Stop at the first winner, or play on for places?

---

## 6. Mancala – المنقلة

**Default: Kalah(6,4) – كالاه** (`MancalaConfig.kalah`, mode
`BoardVariantId.mancalaKalah`). 6 pits a side, 4 seeds each (option 3–6),
stores.

- Sow counter-clockwise from any non-empty own pit, into one's own store,
  skipping the opponent's store.
- Last seed in one's own store → move again.
- Last seed in one's own empty pit → capture it and the seeds in the
  opposite pit, **only if the opposite pit is non-empty**
  (option `captureEmptyOpposite`). **☐ Confirm.**
- The game ends as soon as either side is empty **after any move**; each
  player then adds the seeds on their own side to their store.
  **☐ Confirm** (some rules check only at the empty player's turn).

**Option: Oware (Abapa) – أواري** (`MancalaConfig.oware`, mode
`BoardVariantId.mancalaOware`). No sowing into stores; a lap of 12+ seeds
skips the starting pit; captures when the last seed makes 2 or 3 in an
opponent pit, continuing backwards on the opponent's side; **grand slam**
(capturing all the opponent's seeds) captures nothing (option
`grandSlamCaptures`); a player must feed an empty opponent if possible,
otherwise the game ends and each player keeps their side's seeds; more than
24 captured wins, 24–24 is a draw.

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

## 9. Decisions and open questions

### 9.1 Decided

The owner ruled that every board game follows the rules **as commonly played
in Jordan** by default, with other regional variants kept as options. That
settles every "which game is the default" question of the previous version
of this file:

1. **Dama / checkers.** The default is the orthogonal «الضامة» of the
   Turkish family (`damaJordan`), not American draughts. Its game ends
   replace the old "80 plies or threefold" draw: no legal move loses; two or
   more kings against a lone king win; one piece each, threefold repetition
   and 50 plies without a capture or forward man step draw (§2.1). A man
   crowned mid-capture keeps capturing as a man (TÜDAF). The Turkish
   federation rules and American draughts, with and without flying kings,
   stay as modes.
2. **Tawla / backgammon.** «طاولة الزهر» is three games on one engine:
   «شيش بيش» (the default; the previous version of this file called it
   «فرنجي»), «محبوسة» and «٣١». The
   opening roll only decides who starts, and the starter then rolls both
   dice. «مارس» counts 2 and there is no triple. There is no doubling cube
   by default. Games are played as a match (to 5, or 31 in ٣١).
   International backgammon (opening dice played, triple counted, one game)
   stays as a mode.
3. **Dominoes.** The default is the Jordanian «دومينو»: the double-six line
   draw game, 7 tiles each, count scoring to 101, the highest double opening
   round 1 and the previous winner leading later rounds, the winner scoring
   every opponent's pips (not the partner's, not the stock), the lighter side
   winning a blocked round and a tie scoring nothing, and partners with four.
   New: a locked line («قفلت») ends the round at once. All Fives, the block
   game and the played-out lock stay as modes.
4. **Ludo.** The default is the app-style game: a 6 to leave the yard;
   another roll for a 6, a capture or a token reaching home, at most one per
   move; the third 6 in a row ends the turn while earlier moves stand; the
   exact roll to finish; safe start and star squares; landing captures every
   opponent token there; no blockades; the first winner ends the game. New:
   a random first player. Partnerships are a mode; the other house rules are
   options.
5. **Chess, Mancala (Kalah), Four in a row, Tic-tac-toe** are unchanged.

### 9.2 Still open – ☐ Confirm with the owner

> **Owner ruling (2026-10-02):** confirmed as proposed – Ludo pairs are captured whole (`safePairs: false`, `blockades: false`); Tawla 31 `layout31: contrary`; dominoes locked line ends the round at once; the 101 target stays a per-match choice. These items are no longer open.

Each item is one option or default in code; the most important come first
within each game.

1. **Chess:** automatic threefold / fifty-move draws, with no claim button
   (§1).
2. **Dama (§2.7):** the king's name on screen («شيخ» or «ضامة»); whether a
   man crowned mid-capture stops there instead; the 50-ply no-progress
   limit; keeping "two kings beat a lone king" on; who starts the next game;
   which person plays white.
3. **Tawla (§3.10):** the ٣١ start layout (the most important); the محبوسة
   mother rule; the match length (5); who starts game 2 and later; the ٣١
   runner target; screen names and dice call-outs.
4. **Dominoes (§4.7):** the locked line (stop at once, or draw the stock);
   the two-player deal and the name of the pile; the target (101); blocked
   scoring and ties; no double dealt (heaviest tile or re-deal); whether
   «الخمسات» is played; partners with four; the leader after a tied round.
5. **Ludo (§5.5):** two own tokens on one square (captured together, safe,
   or a blockade) – ask this first; extra rolls for a capture and for
   reaching home; the random first player; one or three tries while every
   token is in the yard; the unusable 6; stopping at the first winner with
   3–4 players.
6. **Mancala (§6):** a Kalah capture needs a non-empty opposite pit; the end
   check after every move; the 200-ply cycle limit.

---

## 10. Sources

The rules of traditional games are not copyrighted. Every source below was
used only to learn how people play. Every sentence in this file and every
name in the code is our own wording, and no app's text, names, art or code
was copied.

### Dama (§2)

- **Game identity (Jordan / Levant).** These sources place the game in the
  region:
  - English Wikipedia "Turkish draughts", which lists Jordan among the
    countries;
  - the older Wikipedia "Draughts" article, which calls it "a common form in
    the Middle East, known as Dama";
  - Jawaker's Dama rules (an Amman-founded platform; seen as search summaries
    only);
  - WAFA and Al-Hadath on Palestinian folk games (16 stones on the 2nd and
    3rd rows);
  - an Amman-published Arabic novel that shows «الضامة» in village life.
- **Movement, capture, promotion and the 180° rule.** These rules are
  confirmed by:
  - Wikipedia "Turkish draughts";
  - Ludii's Dama definition (after Murray 1951);
  - the Turkish federation (TÜDAF) rulebook v3/v4.0 and its 2024 tournament
    rules, as summarised by an open-source implementation;
  - the open-source `kish`, `pydraughts`, `dama-logic-python` and
    `boardgamecollection` implementations.
- **Draws and adjudications.**
  - TÜDAF-based rules: one piece each and threefold repetition, with no fixed
    no-progress count.
  - `pydraughts`: the one-piece-each draw applies only when no capture is
    forced.
  - `kish`: a 50-ply no-progress draw.
  - Jawaker: two kings against a lone king.
  - Wikipedia: two kings always beat a lone king, and the Samara (Murray)
    note.
- **Engine checks.**
  - A probe showed that counting every man move as progress let a sideways
    shuffle go on forever. This is fixed by rule 21's irreversibility rule.
  - `dama_test.dart` checks move generation against an independent reference
    written from these rules on 1,500 random positions, comparing the
    results reached rather than the routes.

### Tawla (§3)

- **Jordan and the Levant:** Jawaker and Quirkat game lists and rule pages
  (Amman); Al-Rai «طاولة الزهر.. شيش بيش سي يك»; a Levantine-Arabic teaching
  blog; Yalla Elaab's tawla pages (the same three games).
- **Regional and background:** Egyptian Streets / Egypt Independent;
  Wikipedia (Tables game, Fevga); Ludii's "Mahbouseh" ruleset; R. Rognlie's
  Plakoto and Moultezim rules; the "10 Tawla" app's developer pages; a
  board-game database entry for Fevga; the hermes-trictrac README.
- **Engine checks:** probes of this engine, and
  `backgammon_reference_test.dart`, which compares move generation with an
  independent brute-force reference written from these rules.
- None of the newest sources is Jordan-specific; every default that rests
  only on regional practice is marked ☐.

### Dominoes (§4)

- **No Jordanian source could be reached** during research. The web search
  budget was used up, and the rules sites were blocked. Still to check once
  the web is back: a Jordanian source such as Jawaker's dominoes page or an
  Al-Rai / Al-Ghad article, for D-19, the partnership default and the target.
- **Two independent Arab-market projects** model every core rule above in the
  same way: 7 tiles each; the 6-6 or highest-double opening, otherwise the
  heaviest tile; the winner leads later rounds; the partner's hand and the
  stock are not counted; the lighter side wins a blocked round and a tie
  scores 0; the match is to 101.
  - An Egyptian/Levantine "street domino" party-games project (its domino
    rules module).
  - A Gulf games hub (its dominoes component).
- **Self-play probes** of this engine (the `xcheck_dl_probe` scripts in the
  research notes, 1,200 matches):
  - Under the literal "draw after a lock" rule, the player to move in a
    locked round with stock won only 16 % (2 players) or 4 % (3 players), and
    the winner scored about double. Ending the round at once brings this back
    to 43–45 %.
  - The lock check had no counter-example in 1,848 blocked rounds.
- Background knowledge for the All Fives count and the names of the doubles
  («دوشيش» … «هبيك»).

### Ludo (§5)

As for dominoes, no Jordanian source was reachable during research.

- **Four independent open-source Ludo projects**, a mix of rules code and
  design notes, agree on the app-style core:
  - a 6 to exit onto the start square;
  - another roll for a 6, a capture or reaching home;
  - the third 6 voids the turn while earlier moves stand;
  - the exact roll to finish;
  - safe stars 8 squares after each start.
- **They disagree on stacks.** One makes a same-colour pair an uncrossable
  block (on by default). One lets only single tokens be captured. Two list
  blocks as a rule. The default here follows the big-app classic mode:
  stacks are captured together and can be passed. This is background
  knowledge, and it is why `safePairs` exists.
- **Self-play probe** of this engine (700 games): every game ended, even with
  blockades on (at most 1,778 plies). There is no meaningful first-mover edge
  (seat 0 won 151 v 149 with 2 players).

### Chess, Mancala, Four in a row, Tic-tac-toe (§1, §6–§8)

The standard published rules (the FIDE Laws of Chess; the usual Kalah(6,4)
and Oware (Abapa) rules). Nothing new was researched for them in this round.
Chess move generation is checked against the published perft counts of the
six standard test positions.
