# Madar Cinema – card game rules (as implemented)

This file describes **exactly** what the code in `lib/features/cinema/rules/cards/` does for the six Tier 2 card
games, so it can be checked against how the games are played at home in Jordan. Every point marked
**ASSUMPTION** is a choice made where house rules differ; most of them are an option you can switch without
touching the code (option names are given in `code`).

| Game | Arabic | Players | Deck | Match (default) |
|---|---|---|---|---|
| Tarneeb | طرنيب | 4, two partnerships | 52 | first team to 31 (or 41) |
| Trix | تركس | 4, individual (partnership option) | 52 | 4 kingdoms × 5 contracts = 20 deals |
| Hand | هاند | 2–4, individual | 2 × 52 + 4 jokers = 108 | 5 rounds, lowest total wins |
| Basra | باصرة | 4 (two partnerships) or 2 | 52 | first side to 101 |
| Baloot | بلوت | 4, two partnerships | 32 (7 to A) | first team to 152 |
| Konkan | كونكان | 2–4, individual | 2 × 52 + 2 jokers = 106 | until someone reaches 500, lowest wins |

## Conventions shared by all games

- **Seats** are numbered 0–3. The next player is always `seat + 1` (mod the number of players). The UI draws the
  seats **counter-clockwise** (to the right), which is how these games go round in Jordan. In partnership games,
  partners are seats 0 & 2 and 1 & 3.
- **Dealer**: the first dealer is the last seat, so seat 0 (the human, normally) acts first. After every deal the
  dealer moves to the next seat. There is no cut and no misdeal rule (a seeded shuffle cannot be faulty).
- **Shuffling** uses a deterministic, serialisable generator (xoshiro128**). The same seed gives the same deals,
  and the generator's state is saved with the match, so a resumed match continues with the same future deals.
- **Save / resume**: `engine.toJson()` holds the whole match (including the generator); `CardGames.fromJson`
  restores it.
- **After a deal is scored the next deal is dealt at once.** The deal summary is in the state (`results`) and in
  the events returned by `apply` (`roundScored`, then `dealt`), so the UI can show it before drawing the new
  hands.
- Nothing in the logic is user-facing text: phases, moves, events (`CardEventType`), contracts, projects and
  error ids (`IllegalMoveException.code`, e.g. `mustFollowSuit`) are enums / stable ids the UI localises.
  Events that reveal a card (e.g. `drewStock`) carry the card: **the UI must hide it from the other seats.**

---

## 1. Tarneeb – طرنيب

**Players / deal.** Four players in two partnerships, 13 cards each.

**Auction (المزايدة).**
1. The player after the dealer speaks first. Each player either **passes** or **bids** a number of tricks from
   **7** (`minBid`) to **13**, higher than the current bid.
2. **A pass is final**: the player takes no further part in this auction (`passIsFinal`; if off, a player who
   passed may bid again and the auction ends after three passes in a row following a bid).
3. The auction ends when every other player has passed after a bid, or at once when someone bids 13.
4. If all four pass, the cards are thrown in and the **next dealer deals again** (`allPass: redeal`). Option:
   `dealerTakesMinimum` – the dealer may not pass and must bid the minimum.

**Trump (الطرنيب).** The highest bidder names any of the four suits as trumps (there is no no-trump contract).

**Play.**
- The **winning bidder leads** the first trick (`bidderLeads`; off → the player after the dealer leads).
- You must follow the suit led. If you cannot, you may play **any** card: there is no obligation to trump or to
  over-trump.
- The highest trump wins the trick, otherwise the highest card of the suit led (ace high). The winner leads next.
- All 13 tricks are always played.

**Scoring (each deal).**
| Result | Bidding team | Defenders |
|---|---|---|
| Made (tricks ≥ bid) | the **tricks it took** (`madeScore: tricksTaken`; option `bid`) | 0 (option `defendersScoreWhenMade`: their tricks) |
| All 13 tricks (كبوت) | **16** (`allTricksScore`) | 0 |
| Failed | **minus the bid** | **the tricks they took** (`failScore: defendersTricks`; options `bid`, `nothing`) |

**Match.** The first team to reach **31** wins (`targetScore`, 41 is the other common target). Scores may go
negative. If both teams pass the target in the same deal (only possible with the options above) the higher total
wins, and an exact tie goes to the bidding team.

**ASSUMPTIONS to confirm**
1. A pass is final, and the bidder leads the first trick.
2. All four passing → redeal (not "dealer must take 7").
3. Made contract scores the tricks taken (not just the bid); the defenders then score nothing.
4. Failed contract: bidders lose their bid, defenders score the tricks they took.
5. 13 tricks = 16 points, whatever the bid; a failed 13 bid loses 13 (not 16).
6. No rule ends the game at a negative score (e.g. −31), and no "bid 13 and make it wins the game at once".
7. "41" here is the same partnership game played to 41. The Syrian *Tarneeb 41* (individual bids, hearts always
   trumps) is a different game and is not implemented.

---

## 2. Trix – تركس

**Players / deal.** Four players, each for themselves (`partnership: true` → seats 0 & 2 and 1 & 3 add their
scores). A new 13-card deal for every contract.

**Kingdoms (الممالك).** There are four kingdoms, one per player, starting with seat 0 (`firstOwner`), then the next
seat. In their kingdom the owner, after seeing the cards, chooses **each deal** one contract they have not played
yet in this kingdom, and the owner leads the first trick (or starts the layout).
- Classic (`mode: classic`, default): five contracts per kingdom → **20 deals**:
  King of hearts (ملك الكبة / الشيخ), Queens (البنات), Diamonds (الديناري), Collections (اللطوش), Trix (تركس).
- Complex (`mode: complex`): two contracts per kingdom → 8 deals: Complex (كومبلكس) and Trix.

**Trick contracts** (no trumps, follow suit if you can, otherwise any card; highest card of the suit led wins;
the winner leads):
| Contract | Penalty | The deal ends |
|---|---|---|
| King of hearts | taker of K♥ **−75** | as soon as K♥ is taken |
| Queens | each queen **−25** | when all four queens are taken |
| Diamonds | each diamond **−10** | when all 13 diamonds are taken |
| Collections (لطوش) | each trick **−15** | after 13 tricks |
| Complex | all four together (Q♦ is both a queen and a diamond: −35) | after 13 tricks |

Special rules in **King** and **Complex**:
- Hearts may not be led while the leader holds another suit (`noHeartLeadInKing`).
- The holder of K♥ who cannot follow suit **must** throw K♥ (`kingMustBeDiscarded`).

**Doubling (الدبل)** (`doubling`). In King, Queens and Complex, after the contract is chosen each player in turn,
starting with the owner, may double any of the K♥ / queens they hold (this reveals them). A doubled card costs its
taker **double** (K♥ −150, queen −50) and, when the taker is someone else (not the doubler's partner in the
partnership game), the doubler **gains** the normal value (+75 / +25). Taking your own doubled card just costs
double.

**Trix (layout).** The four jacks start four rows. On each row cards are added one at a time **down** from the
jack (10, 9 … 2) and **up** (Q, K, A) in the jack's suit. The owner plays first. On your turn you **must** play a
card if you can, otherwise you pass. Finishing places score **200 / 150 / 100 / 50**; when three players are out
the last one gets 50.

**Match.** After the four kingdoms the highest total wins (tied leaders all win).

**ASSUMPTIONS to confirm**
1. Seat 0 owns the first kingdom (not "the holder of the 7♥"); kingdoms go round in seat order.
2. The owner chooses the next contract after seeing the new cards, and always leads / starts.
3. King: the two special rules above; there is no rule forcing K♥ onto a trick won by A♥.
4. Queens and diamonds have no leading restrictions and no forced discards.
5. Doubled card taken by someone else: taker −2×, doubler +1× (in partnership: no bonus when the partner takes
   it). Doubling happens in Complex too.
6. Trix: must play when able; no bonus for the kingdom owner; places 200/150/100/50.
7. Complex (when enabled) keeps both the king rules and the doubling.

---

## 3. Hand – هاند

**Players / deal.** 2–4 players (`players`, default 4), each for themselves. Two packs and **4 jokers** (108
cards). Everyone gets **14** cards; the player after the dealer gets **15** and starts the round by discarding
(no draw). The rest is the face-down stock; the discard pile starts empty.

**A turn.** (1) Draw the top card of the stock **or** take the top discard; (2) lay down if you can and want;
(3) discard one card, which ends the turn.

**Melds.**
- **Set**: 3 or 4 cards of one rank, all different suits.
- **Run (سيري)**: 3 or more consecutive cards of one suit. The ace is low (A-2-3) or high (Q-K-A), never both
  (no K-A-2).
- **Jokers** replace any card. A meld needs at least two natural cards and **fewer jokers than natural cards**.
- **Values** (for opening): 2–10 face value, J Q K 10, A 11 (1 in A-2-3), a joker the value of the card it
  replaces.

**Opening (النزول).** Your first lay-down is one move of one or more melds worth **at least 51** in total
(`openingThreshold`). After opening (already in the same turn) you may lay down more melds, **add cards to any meld
on the table** (yours or another player's), and **swap a joker**: put the natural card a table joker stands for in
its place and take the joker into your hand (`jokerSwap`).

**The discard pile.** You may take the top discard **only to use it at once** (`discardMustBeUsed`): before
opening, in an opening that contains it; after opening, in a new meld, a lay-off or a joker swap. You cannot
discard until you have used it.

**Going out.** You must always keep a card to discard; you go out by **discarding your last card**.

**Empty stock.** The discard pile (except its top card) is shuffled into a new stock – at most twice
(`maxStockRecycles`); after that the round is abandoned and nobody scores.

**Scoring (penalty points – lowest total wins).**
| Player | Points |
|---|---|
| Went out | **−30** (`winnerScore`) |
| Went out with a **hand** (هاند): had not opened before this turn and laid everything down in one turn | **−60** (`handWinnerScore`) and every other player's points are **doubled** (`handMultiplier`) |
| Opened, cards left | sum of the cards left: 2–10 face value, J Q K 10, A **11** (`acePenalty`), joker **25** (`jokerPenalty`) |
| Never opened | **100** (`notOpenedPenalty`; 200 after a hand) |

**Match.** **5 rounds** (`rounds`); the lowest total wins (`matchEnd: targetScore` ends it instead when someone
reaches `targetScore`).

**ASSUMPTIONS to confirm**
1. 4 jokers; 14 cards, 15 for the first player who starts by discarding; empty discard pile at the start.
2. Opening 51, in one go, with any mix of sets and runs (`openingRequiresRun: false`); jokers allowed in the
   opening; no "each later opener must beat the previous opening" rule.
3. Jokers: fewer jokers than natural cards in a meld; a joker in the hand at the end costs 25; a joker may be
   discarded.
4. The top discard may only be taken to meld it at once (also after opening).
5. Joker swap allowed after opening; the taken joker goes to the hand with no obligation to use it at once.
6. Ace in hand counts 11.
7. Match length 5 rounds (not a points limit).
8. No partnership variant of Hand.

---

## 4. Basra – باصرة

**Players / deal.** Four players in two partnerships (`partnership`; off → four individuals) or two players
(`players: 2`). Four cards go **face up on the table** – a jack or the 7♦ turned up there goes back into the
lower half of the pack and another card is turned – and **four cards to each player**. When every hand is empty,
everyone gets four more from the pack (no more cards to the table) until the pack is used up (3 rounds with four
players, 6 with two).

**A turn: play one card.**
- **Numerals** (A = 1 … 10) take every table numeral of the **same rank** and every group of table numerals that
  **adds up to their value**. The largest possible capture is taken automatically – the player only chooses the
  card.
- **Queens and kings** take only the table cards of the same rank.
- **Jacks (الولد)** sweep the whole table. This is **not** a basra – except a jack taking a **lone jack**, which is
  a basra worth **20** (`jackBasraPoints`, 0 disables).
- **7♦ (سبعة الديناري / الكومي)** (`sevenDiamonds: sweep`) sweeps the whole table like a jack; it is a **basra when
  every table card is a numeral and they add up to 10 or less** (`sevenDiamondsBasraMaxSum`). Option `normal`:
  an ordinary seven.
- A card that takes nothing (or is played to an empty table) stays on the table.
- **Basra**: clearing the table with a numeral, queen or king = **10 points** (`basraPoints`). A basra made with
  **the very last card of the deal does not count** (`basraOnLastCard`).
- At the end of the deal the cards left on the table go to the side that **took last**.

**Scoring (each deal).** Most cards **3** (nobody on a tie; `majorityPoints`); each jack **1**; each ace **1**;
2♣ **2**; 10♦ **3**; plus basras. That is 16 points per deal plus basras.

**Match.** First side to **101** (`targetScore`); if the leaders are tied at or above it, another deal is played.

**ASSUMPTIONS to confirm**
1. Captures are automatic and maximal (no choosing which cards to take).
2. Jack = sweep without basra; jack on a lone jack = basra 20.
3. 7♦ = sweep, basra only when the table is all numerals totalling ≤ 10.
4. No basra with the last card of the deal.
5. Table cards left at the end go to the last side that captured (to the dealer's side if nobody did).
6. Four players play as two partnerships by default.
7. Jacks and the 7♦ may not start on the table (they are re-buried and replaced).

---

## 5. Baloot – بلوت

The Saudi-style game as played in Jordan (Sun / Hokom).

**Players / deal.** Four players in two partnerships, 32 cards (7 to A). Five cards each; the next card is turned
face up (الورقة المكشوفة); eleven stay for later.

**Card order and points.**
| | Order (high → low) | Points |
|---|---|---|
| Sun, and side suits in Hokom | A 10 K Q J 9 8 7 | A 11, 10 10, K 4, Q 3, J 2 |
| Trumps (Hokom) | J 9 A 10 K Q 8 7 | J 20, 9 14, A 11, 10 10, K 4, Q 3 |

The last trick is worth 10 more. Total: **130** in Sun, **162** in Hokom.

**Auction (الشراء).**
1. **Round 1**, starting after the dealer: each player says **pass (بس)**, **Hokom (حكم)** – trumps are the suit
   of the turned card – or **Sun (صن)**.
2. **Sun ends the auction at once.** After a Hokom, each of the other three players (including those who had
   passed) may still turn it into Sun or pass; if none does, the Hokom stands.
3. If all four pass, **round 2**: Hokom in **another suit** (any of the three), Sun, or pass, with the same
   override.
4. If all pass again, the next dealer deals again.
5. The buyer takes the turned card **plus two**; everyone else three: eight cards each.

**Doubling (الدبل)** (`doubling`).
- Hokom: the defenders (the one after the buyer first, then the other) may **double (×2)**; the buyer may then
  **triple (×3)**; the doubler may **four (×4)**; the buyer may then call **gahwa (قهوة)**: whoever wins that deal
  wins the whole match.
- Sun: the defenders may double (×2) only when the buyers have **more than 100 and the defenders less than 100**
  (`sunDoubleOnlyWhenBehind`); nothing further.

**Projects (المشاريع)** are declared automatically for every player at the start of play (the best
non-overlapping set; a card counts in one project only):
| Project | Cards | Sun | Hokom |
|---|---|---|---|
| Sira (سرا) | 3 in sequence, same suit | 4 | 2 |
| Fifty (خمسين) | 4 in sequence | 10 | 5 |
| Hundred (مية) | 5 in sequence, or four 10s / Ks / Qs / Js (four aces in Hokom) | 20 | 10 |
| Four hundred (أربعمية) | four aces, Sun only | 40 | – |

Sequences use the natural order 7 8 9 10 J Q K A. **Only the team with the single best project scores
projects** (compare value, then the highest card, then the player nearer the first player); the other team's
projects are cancelled. Projects are public after the first trick.

**Belote (بلوت).** In Hokom, K and Q of trumps in one hand: **2 points** to that team, never cancelled or
multiplied, even when the contract fails.

**Play.** The player after the dealer leads.
- Follow suit if you can.
- Hokom, trump led: you must play a **higher trump** than the best one in the trick if you can (`mustOvertrump`).
- Hokom, void in a side suit: you **must trump** (even when your partner is winning –
  `mustTrumpWhenPartnerWinning`), over-trumping a trump already played if you can; if you cannot over-trump you
  may play **any card**.
- Sun: no trumps, just follow suit.

**Scoring (game points).**
- The buyers' card points become game points: Hokom **÷10** (a half rounds **down**), Sun **÷5** (rounded). The
  defenders get the rest of **16** (Hokom) / **26** (Sun).
- Add projects and belote. The buyers **make** it when their total is **greater** than the defenders' (a tie is a
  failure – `buyerWinsTies`). Then each team scores its own total.
- **Failure (خسارة)**: the defenders score 16 / 26 plus **all** counted projects; the buyers score only their
  belote.
- **Kaboot (كبوت)**, all eight tricks: **25** (Hokom) / **44** (Sun) plus all counted projects to that team.
- **Doubled**: the team that wins the deal (as above) scores (16 / 26 or kaboot, plus all projects) × the level
  (2, 3 or 4); the other team scores only its belote.

**Match.** First team to **152** (`targetScore`); if both pass it the higher total wins; a tie goes to the buyers.
Gahwa ends the match at once.

**ASSUMPTIONS to confirm**
1. No **Ashkal (أشكال)** bid, and no "first in turn has priority on Sun" rule: the first Sun simply wins.
2. After a Hokom, all three other players may still call Sun.
3. Doubling order and the Sun double condition as above; a Sun double cannot be raised.
4. Projects are always declared, automatically, all of them; a card belongs to one project only.
5. Belote always counts for its holder's team.
6. Void: must trump even when the partner is winning; must over-trump when able; free when unable to over-trump.
7. Rounding: Hokom halves round down, Sun is exact or rounds to the nearest; the defenders get the remainder.
8. A tie between buyers and defenders is a failure.
9. Kaboot 25 / 44; doubled deals are winner-takes-all.

---

## 6. Konkan – كونكان

Konkan uses the same engine and rules as **Hand** (melds, jokers, 51 to open, taking the top discard only to meld
it, lay-offs, joker swaps, going out by discarding the last card), with these differences:

| | Hand | Konkan |
|---|---|---|
| Jokers | 4 (108 cards) | **2 (106 cards)** |
| Going out | −30 | **0** |
| Going out in one turn from a closed hand | −60, others ×2 | **0, others ×2** |
| Match | 5 rounds | **until someone reaches 500; lowest total wins** (`matchEnd: rounds` for a fixed number) |

Cards left: 2–10 face value, J Q K 10, A 11, joker 25; never opened: 100.

**ASSUMPTIONS to confirm**
1. 2 jokers; 14 cards, 15 for the first player.
2. Opening 51, any mix of sets and runs (`openingRequiresRun` exists if a run is required).
3. No reward for going out beyond making everybody else pay; a one-turn finish doubles the others.
4. The match ends when someone reaches 500 (elimination play – dropping out at 101 and continuing – is not
   implemented).

---

## AI opponents

Three levels per game, all behind `CardAi.chooseMove(state, player, level, rng, budget)`:
- **Easy** – simple heuristics (win the trick if you can, take the biggest capture, open as soon as possible…),
  and a random legal move 20 % of the time.
- **Medium** – full heuristics with **card counting** (cards played, master cards, known voids, cards taken from
  the discard pile), contract / bid evaluation, ducking in the negative Trix contracts, blocking on the Trix layout,
  not feeding the next Basra / rummy player, and **partner play**: not over-taking a partner who is winning,
  feeding points to a winning partner (Baloot), and a simple encouraging discard signal in Tarneeb (a discard of
  8 or higher asks the partner to lead that suit).
- **Hard** – information-set Monte Carlo: it samples many deals of the unseen cards consistent with what the
  player has seen (voids, passes on the Trix layout, doubled and project cards, picked-up discards), plays every
  candidate move in each sampled world and plays on with a fast heuristic policy – to the end of the deal in the
  trick games and Basra, for the next few turns in Hand / Konkan (then the hands are estimated) – and keeps the
  medium move unless another is better by more than two standard errors. The time budget is a parameter
  (`AiBudget.phone` = 150 ms); tests use a fixed number of simulations so they are deterministic.

The AIs never look at hidden cards: a test re-deals everything a seat cannot see and checks the decision does not
change.

## Not implemented (known gaps)

- Tarneeb: Syrian Tarneeb 41; negative-score loss rule.
- Trix: "7♥ holder owns the first kingdom"; forced K♥ on A♥.
- Baloot: Ashkal, Sun priority by seat order, choosing not to declare a project, the rule where belote is
  cancelled by a 100 project containing K+Q.
- Hand / Konkan: partnership Hand; "later openers must beat the previous opening"; elimination at 101; a
  chosen joker position when a run could place it at either end (the engine puts it at the high end).
- Basra: choosing between alternative captures (the maximum is always taken).
