# Madar Cinema – card game rules, as commonly played in Jordan

This file describes **exactly** what the code in `lib/features/cinema/rules/cards/` does, game by game, so that it can
be checked against how the games are played at home in Amman. The owner's ruling is that every card game follows
the rules **as commonly played in Jordan** by default. So in every game the `const` options (`TarneebOptions()`,
`TrixOptions()`, …) **are** the Jordanian game, and each class also has a `jordan()` preset that is identical. Other
regional ways of playing are named presets or single options, and every option is given by its code name in
`code`. **☐** marks a detail that is still to be confirmed with the owner (see "Still open" below). Everything here
is written in our own words; no app's text, names, art or code was copied (sources at the end).

## Games and variants

| Game (menu) | Arabic (UI) | Code: id and options | Players | Deck | Jordanian default | § |
|---|---|---|---|---|---|---|
| Tarneeb | طرنيب | `tarneeb`, `TarneebOptions()` | 4, two partnerships | 52 | bids 7–13, the bidder names trumps and leads; first team to **31** | 1 |
| Tarneeb to 41 | طرنيب 41 | `tarneeb`, `TarneebOptions(targetScore: 41)` | 4, two partnerships | 52 | the same game played to 41 (`targetChoices` 31 · 41 · 61) | 1 |
| Tarneeb presets | طرنيب سوري · لبناني · مزايدة مفتوحة | `TarneebOptions.syrianTrump()`, `.lebaneseAuction()`, `.openAuction()` | 4, two partnerships | 52 | off by default | 1.3 |
| 41 | ٤١ (طلب فردي) | `fortyOne`, `FortyOneOptions()` | 4; each bids alone, partners win together | 52 | hearts trumps; one partner at **41** with the other above 0 | 1b |
| 41 presets | ٤٠٠ · سوري ٤١ | `FortyOneOptions.lebanese400()`, `.syrian()` | 4 | 52 | off by default | 1b |
| Trix | تركس | `trix`, `TrixPreset.trix` = `TrixOptions()` | 4, each for himself | 52 | the 7♥ holder owns the first kingdom; 4 kingdoms × 5 contracts = **20 deals** | 2 |
| Trix, partners | تركس شراكة | `TrixPreset.trixPartnership` (`partnership: true`) | 4, two partnerships | 52 | 20 deals, team totals | 2 |
| Trix Complex | تركس كومبلكس | `TrixPreset.complex` (`mode: TrixMode.complex`) | 4, each for himself | 52 | 4 kingdoms × 2 contracts = **8 deals** | 2.5.6 |
| Complex, partners | كومبلكس شراكة | `TrixPreset.complexPartnership` | 4, two partnerships | 52 | 8 deals, team totals | 2.5.6 |
| Hand | هاند | `hand`, `RummyOptions.hand()` = `RummyOptions()` | 2–4 (default 4), each for himself | 2 × 52 + 2 jokers = 106 | 51 to open; **5 scored rounds**, lowest total wins | 3 |
| Hand, partners | هاند شراكة | `hand`, `RummyOptions.handPartnership()` | 4, two partnerships | 106 | 5 rounds; the winner's partner is not counted | 3.4 |
| Hand with the indicator card | هاند بورقة الكشف | `hand`, `RummyOptions.handIndicator()` | 2–4 | 106 | off by default (7 rounds when chosen) | 3.5 |
| Konkan | كونكان | `konkan`, `RummyOptions.konkan()` | 2–4 (default 4), each for himself | 106 | the Hand core; elimination: **over 301** is out, the last one left wins | 6 |
| Rummy (shared core) | – | `rummy/` (`RummyOptions`, `RummyRules`, `RummyAi`) | – | – | the engine behind Hand and Konkan; not a menu entry of its own | 3 |
| Basra | باصرة | `basra`, `BasraOptions()` | 4 (two partnerships), 3 or 2 | 52 | a basra is worth twice the card; first side to **101** | 4 |
| Basra presets | فلسطيني ٤٤ · مصري | `BasraOptions.palestinian44()`, `.egyptian()` | 4, 3 or 2 (44 cards: not 3) | 44 / 52 | off by default | 4 |
| Baloot | بلوت | `baloot`, `BalootOptions()` | 4, two partnerships | 32 (7 to A) | the Saudi rules; first team to **152** | 5 |
| Solitaire (Klondike) | سوليتير | `SolitaireGame`, `SolitaireOptions()` (no `CardGameId`) | 1 | 52 | draw one, unlimited passes, standard score; one deal = one game | 7 |
| Solitaire presets | سهل · صعب · خبير · كلاسيكي | `SolitaireOptions.easy()`, `.hard()`, `.expert()`, `.windowsClassic()` | 1 | 52 | off by default | 7 |
| Blackjack 21 | بلاك جاك ٢١ | `blackjack`, `BlackjackOptions()` | 1–3 seats (default 1) against the dealer | 6 × 52 = 312 | points only, **no wagering**; 20 rounds | 8 |
| Blackjack, European table | – | `BlackjackOptions.european()` | 1–3 | 312 | off by default | 8 |

`CardGames.newMatch(id, seed:, options:)` creates any game of the registry (`CardGameId`: `tarneeb`, `trix`,
`hand`, `basra`, `baloot`, `konkan`, `fortyOne`, `blackjack`); `options: null` gives the Jordanian default above.
`CardGames.fromJson` restores a save (its `game` key is the id's name) and `CardGames.ai(id)` gives the AI.
Variants are options of a game, never ids of their own. Solitaire is a one-player patience with its own
`SolitaireGame` (§7). The barrel `cards.dart` exports every game.

## Conventions shared by all games

- **Seats** are numbered 0–3. The next player is always `seat + 1` (mod the number of players). The UI draws the
  seats **counter-clockwise** (to the right), which is how these games go round in Jordan. In partnership games,
  partners are seats 0 & 2 and 1 & 3. When the owner and his wife play together against two AIs they sit at seats 0
  and 2; as rivals they sit at 0 and 1.
- **Dealer**: the first dealer is the last seat, so seat 0 (the human, normally) acts first (`firstDealer` where the
  game has it). After every scored deal the dealer moves to the next seat, with these exceptions: in Tarneeb, when
  all four pass, the same dealer deals again (§1, A2); in Hand and Konkan the seat with the most points in the round
  just scored deals next, and after a void round the same dealer deals again (§3.2, rule 4). There is no cut and no
  misdeal rule (a seeded shuffle cannot be faulty).
- **Shuffling** uses a deterministic, serialisable generator (xoshiro128**). The same seed gives the same deals,
  and the generator's state is saved with the match, so a resumed match continues with the same future deals.
- **Save / resume**: `engine.toJson()` holds the whole match (including the generator); `CardGames.fromJson`
  restores it. Options missing from an older save take their Jordanian default, except where a section says that an
  old save keeps its old rules.
- **After a deal is scored the next deal is dealt at once.** The deal summary is in the state (`results`) and in
  the events returned by `apply` (`roundScored`, then `dealt`), so the UI can show it before drawing the new
  hands.
- Nothing in the logic is user-facing text: phases, moves, events (`CardEventType`), contracts, projects and
  error ids (`IllegalMoveException.code`, e.g. `mustFollowSuit`) are enums / stable ids the UI localises.
  Events that reveal a card (e.g. `drewStock`) carry the card: **the UI must hide it from the other seats.**
- **Hidden information in saves.** `toJson()` holds every hand and the shuffle generator (which fixes the next
  deals). There is no per-seat view yet, so a game played on two phones must never show or send the raw save to a
  player.
- **Solitaire (§7) and Blackjack (§8)** do not follow the four-seat, rotating-dealer, partnership and "next deal
  dealt at once" conventions; see their sections.

## Decided by the owner's ruling

The owner ruled that card games follow the rules **as commonly played in Jordan** by default. Wherever regional
rule sets disagree, that ruling decided the default below; the other ways stay available as presets or options.

- **All games:** `const XOptions()` is the Jordanian game (identical to `XOptions.jordan()`); variants are named
  presets or options; a variant is never its own `CardGameId`.
- **Tarneeb (§1):** the partnership game with bids 7–13 and a final pass; the bidder names any suit as trumps and
  leads; no no-trump contract. A made bid scores the tricks taken; a failed bid costs the bid and gives the
  defenders their tricks. كبوت: 13 tricks on a lower bid = 16; bid 13 and made = 26, failed = −16. First to 31
  (41 and 61 as choices); no loss at −31.
- **The name "41":** «طرنيب 41» in Jordanian game lists is the partnership game played to 41. The individual-bid game
  is a separate game, «٤١ (طلب فردي)» (`fortyOne`).
- **41 (§1b):** hearts are always trumps; each player bids once for himself, 2–13, no pass; fewer than 11 in total
  throws the deal in; face value up to 6 and double from 7; a team wins with one partner at 41 and the other above 0.
- **Trix (§2):** the 7♥ holder of the first deal owns the first kingdom; doubles are given at the same time and stay
  hidden until everyone has answered; a doubler forced to take his own doubled card pays double and the trick's
  leader gains its value; four menu entries (تركس, تركس شراكة, تركس كومبلكس, كومبلكس شراكة).
- **Hand (§3):** 106 cards (two jokers); 14 cards and 15 for the starter, whose first turn is a discard only; nobody
  goes out on his first turn; 51 to open with the ace worth 11 (also in A-2-3); one wild per meld; the top discard
  only into a new meld with two of one's own cards; a full hand (هاند) only with one's own new melds; the round's
  biggest loser deals; 5 scored rounds.
- **Konkan (§6):** the corrected Hand core, nothing for going out, a joker left in hand costs 25, elimination over
  301.
- **Basra (§4):** 52 cards, four players in two partnerships; a basra is worth twice the capturing card (a queen or
  king 20, the 7♦ 14); a jack on a lone jack scores nothing; the 7♦ sweeps; most cards 3; first side to 101.
- **Baloot (§5):** Jordan plays the Saudi rules: Ashkal, Sun priority, the Hokom taker confirming or switching to
  Sun, locked / open doubling, the Saudi rule for a void player whose partner is winning, four of a kind beating a
  sequence, the fixed Sun and Hokom conversions, 152.
- **Solitaire (§7):** no Jordanian variant exists, so the default is the standard Klondike as met on phones: draw
  one, unlimited passes, standard scoring; no Vegas (money) scoring.
- **Blackjack 21 (§8):** no Jordanian variant exists, so the default is the standard six-pack table (dealer stands
  on soft 17 and peeks, double on any two and after a split, up to four hands, no surrender), kept as a points
  tally with no wagering and no insurance.

## Still open – confirm with the owner

The most important detail questions per game (defaults in brackets). Each game section has the full list.

- **Tarneeb:** (1) all four pass – the same dealer deals again [yes], or the deal passes on (`redealNextDealer`), or
  the dealer must bid 7 (`dealerTakesMinimum`)? (2) A failed bid of 13 – the defenders score double their tricks
  [double] or single (`kabootFailDefenders`)? (3) Are the "worthless hand" throw-in or the "lose at −31" rule ever
  played at home [both off]?
- **41:** (1) hearts always trumps [yes], or the Syrian exposed-card trump (`trumpMode`)? (2) Values doubled from 7
  [yes], or the 400 table with minimums that rise with the scores (`valueTable`, `risingMinimums`)? (3) Does a
  partner on exactly 0 count [no], and when both teams qualify does the higher team total win [yes] or the higher
  single score (`partnerRule`, `bothQualify`)?
- **Trix:** (1) partners – when your partner takes the card **you** doubled: −2× with nobody gaining [yes], the other
  team gains, or a normal card (`partnerCaptureRule`)? (2) Each for himself – a doubler forced to take his own card:
  does the trick's leader gain [yes], and if the doubler led it himself, normal value [yes] or double
  (`selfCaptureRule`)? (3) Doubling at the same time and hidden [yes] or one after another (`doublingReveal`)? Also:
  the King rules (heart lead, K♥ discard, K♥ on A♥) and which of the four entries is played most at home.
- **Hand:** (1) wild cards – only the two printed jokers [yes] or the indicator card (`wildIndicator`)? (2) A joker
  left in hand – 15 [yes] or 25 (`jokerPenalty`)? (3) Next dealer – the round's biggest loser [yes] or the next
  player (`dealerRule`)?
- **Konkan:** (1) at home, is Konkan a game of its own or another name for Hand? (2) How does it end – over 301 out
  [yes], 101, to 500, or a number of rounds (`matchEnd`, `eliminationScore`)? (3) Does the winner of a round score
  anything [0], and is a joker left in hand 25 [yes] or 50?
- **Basra:** (1) does the 7♦ sweep the table [yes] (`sevenDiamonds`; the least certain rule)? (2) A basra worth twice
  the card [yes] or a flat 10 (`basraValue`)? (3) A jack on a lone jack – nothing [yes], 20 or 30
  (`jackBasraPoints`)? Also: 52 cards or 44, and 101 or 151.
- **Baloot:** (1) when the taker fails, does his belote go to the winners [yes], stay with him, or vanish
  (`beloteOnLoss`)? (2) In a tripled or "four" deal, projects ×2 [yes] or ×3 / ×4 (`projectMultiplierCap`)? (3) Void
  with the partner winning – the Saudi rule [yes] or always trump (`partnerWinningVoid`)? Also: switching a Hokom to
  Sun, and who leads the first trick.
- **Solitaire:** (1) draw one [yes] or draw three by default (`drawCount`)? (2) The name – سوليتير [yes] or "الصبر"?
  (3) Timed scoring off [yes], and winnable deals only in the Easy preset [yes]?
- **Blackjack 21:** (1) is a points-only Blackjack acceptable at all, or should it be dropped or called «٢١»? (2)
  Late surrender off [yes] (`surrender`)? (3) 20 rounds per session [yes] (`sessionRounds`)?

---

## 1. Tarneeb – طرنيب

**As commonly played in Jordan.** Tarneeb is the partnership trick game that is played at home in Jordan, often in
the Ramadan evenings: four players, two teams, an auction from 7 to 13 tricks, and the winning bidder names the
trump suit (الطرنيب). `const TarneebOptions()` **is** the Jordanian game (also `TarneebOptions.jordan()`). Code:
`tarneeb/tarneeb_state.dart` (options, moves, state), `tarneeb/tarneeb_rules.dart` (rules, scoring),
`tarneeb/tarneeb_ai.dart` (AI).

Suit names for the UI, as said in Jordan: ♥ كبة · ♦ ديناري · ♠ بستوني · ♣ سباتي. A bid of 13 is called كبوت
(kaboot), and so is taking all 13 tricks.

**Named presets** (the Arabic labels of the non-default presets are suggestions for the UI)

| Preset | Arabic (UI) | What changes |
|---|---|---|
| `TarneebOptions()` = `TarneebOptions.jordan({targetScore})` | طرنيب | nothing: every default below |
| `TarneebOptions.syrianTrump({targetScore})` | طرنيب سوري | trumps come from the dealer's exposed card (A-opt-1) |
| `TarneebOptions.lebaneseAuction({targetScore})` | طرنيب لبناني | one call each; the dealer may equal the bid (A-opt-2) |
| `TarneebOptions.openAuction({targetScore})` | مزايدة مفتوحة | a pass is not final; the dealer must bid 7 after three passes (A-opt-5) |

Target chips for the UI: `TarneebOptions.targetChoices` = **31** · 41 · 61. "طرنيب 41" in Jordanian game lists
means **this** game played to 41 (it is not the individual game "41", see §1b).

### 1.1 Options (`TarneebOptions`)

| Option | Jordan default | Other values | Confidence |
|---|---|---|---|
| `targetScore` | **31** | 41, 61 (any int, e.g. 51) | high |
| `minBid` | **7** | any (6 is a house rule, not offered) | high |
| `passIsFinal` | **true** | false: open auction, see A-opt-5 | high |
| `oneRoundAuction` | **false** | true: Lebanese one-round auction, A-opt-2 | low (variant) |
| `allPass` (`TarneebAllPass`) | **`redealSameDealer`** | `redealNextDealer`; `dealerTakesMinimum` | medium (☐ confirm) |
| `madeScore` (`TarneebMadeScore`) | **`tricksTaken`** | `bid` | high |
| `defendersScoreWhenMade` | **false** | true | high |
| `failScore` (`TarneebFailScore`) | **`defendersTricks`** | `bid`, `nothing` | high |
| `kabootScore` (13 tricks on a bid of 7–12) | **16** | any int | high |
| `kabootBidMadeScore` (bid 13, took 13) | **26** | any int | high |
| `kabootBidFailPenalty` (bid 13, failed) | **16** (bidders score −16) | any int | high |
| `kabootFailDefenders` (`TarneebKabootFail`) | **`doubled`** (2 × their tricks) | `single` | medium (☐ confirm) |
| `trumpMode` (`TarneebTrumpMode`) | **`bidderChooses`** | `exposedCardSisterSuit` (Syrian, A-opt-1) | high |
| `bidderLeads` | **true** | false: the dealer's right leads | high |
| `firstLeadMustBeTrump` | **false** | true (A-opt-4) | high (default) |
| `worthlessHandRedeal` | **false** | true (A-opt-3) | high (default) |
| `loseAtNegativeTarget` | **false** | true: a team at or below −target after a deal loses | medium |
| `firstDealer` | **3** (so seat 0, the human, speaks first) | 0–3 | UX choice |

There is **no no-trump** contract (that belongs to the Egyptian bid-with-a-suit game, which is not played this
way in Jordan).

### 1.2 Rules

**A1. Players and deal.** Four players; partners sit opposite (seats 0 & 2 against 1 & 3). 52 cards, ace high.
Play goes to the right (counter-clockwise), which is `seat + 1` in the engine. All 52 cards are dealt, 13 each.
After every **scored** deal the dealer moves one seat to the right.

**A2. Auction (المزايدة / الطلب).**
1. The player on the dealer's right speaks first. Each player either **passes** or **bids** a whole number of
   tricks from **7 to 13**, higher than the standing bid. Overbidding your own partner is allowed.
2. **A pass is final**: that player takes no further part in this auction (`passIsFinal`).
3. The auction ends when every other player has passed after a bid, or **at once on a bid of 13**.
4. **All four pass**: nobody scores; the cards are gathered and **the same dealer** shuffles and deals again
   (`allPass: redealSameDealer`). The deal count (`dealNumber`) goes up, the count of played deals
   (`roundNumber`) does not, and the dealer's right speaks first again. Options: `redealNextDealer` (the deal
   passes on) or `dealerTakesMinimum` (after three passes the dealer has no pass and must bid at least 7;
   error id `dealerMustBid`).

**A3. Trump and first lead.** The winning bidder names any one of the four suits as trumps, then **leads the first
trick** (`bidderLeads`).

**A4. Play.** You must follow the suit led if you can (error id `mustFollowSuit`). If you cannot, you may play
**any** card: trumping is never compulsory and there is no duty to over-trump. The highest trump wins the trick;
with no trump in it, the highest card of the suit led wins. The winner leads the next trick. All 13 tricks are
always played, even once the result is certain.

**A5. Scoring (each deal).** `b` = the bid, `T` = the tricks the bidding team took, `D = 13 − T` = the defenders'
tricks.

| Case | Bidding team | Defenders |
|---|---|---|
| `b ≤ 12` and `b ≤ T ≤ 12` (made) | **+T** (`madeScore: tricksTaken`; option `bid`: +b) | **0** (option `defendersScoreWhenMade`: +D) |
| `b ≤ 12` and `T = 13` (كبوت without bidding it) | **+16** (`kabootScore`) | 0 (as above) |
| `b ≤ 12` and `T < b` (failed, «انكسر») | **−b** | **+D** (`failScore: defendersTricks`; options `bid`: +b, `nothing`: 0) |
| `b = 13` and `T = 13` (bid كبوت and made it) | **+26** (`kabootBidMadeScore`) | 0 (as above) |
| `b = 13` and `T < 13` (bid كبوت and failed) | **−16** (`kabootBidFailPenalty`) | **+2·D** (`kabootFailDefenders: doubled`; option `single`: +D) |

The bid-13 rows are their own rule: they ignore `failScore` (a documented choice). Worked examples with the
defaults: bid 8 took 10 → +10 / 0; bid 9 took 7 → −9 / +6; bid 7 took 13 → +16 / 0; bid 12 took 13 → +16 / 0;
bid 13 took 13 → +26 / 0; bid 13 took 12 → −16 / +2; bid 13 took 0 → −16 / +26.
Code: `TarneebRules.dealPoints(options, bidder, bid, tricksPerTeam)`.

**A6. Match.** Team totals run from deal to deal and **may go negative**. After each scored deal, a team at or
above `targetScore` (31) wins; the match never stops in the middle of a deal. There is **no loss at −31** unless
`loseAtNegativeTarget` is on. Bidding and making 13 does **not** win the match by itself. If both teams pass the
target in the same deal (impossible with the defaults, since only one team scores positively per deal) the
higher total wins, and an exact tie goes to the bidding team. Code: `TarneebRules.matchWinner`.

### 1.3 Variants (all off by default)

- **A-opt-1 Syrian trump (طرنيب سوري)** – `trumpMode: exposedCardSisterSuit`. The dealer's last dealt card is
  shown to everyone (`state.exposedCard`) and stays in the dealer's hand until played. Trumps are the **other suit
  of the same colour** (♥ ↔ ♦, ♠ ↔ ♣; `sisterSuit`). The auction is unchanged; the winner does not name trumps
  (there is no trump phase) but still leads. The AI keeps the exposed card with the dealer when it samples hidden
  hands.
- **A-opt-2 Lebanese auction** – `oneRoundAuction`. Everybody speaks exactly once, from the dealer's right; bids
  must be higher than the standing bid, except that the dealer, who speaks last, may **equal** it and so take the
  contract. A bid of 13 still ends the auction at once; all four passing follows `allPass`.
- **A-opt-3 worthless hand** – `worthlessHandRedeal`. A hand with **no ace, no king in a suit of
  2+ cards, no queen in a suit of 3+ and no jack in a suit of 4+** (`TarneebRules.isWorthlessHand`) may be thrown
  in with the move `TarneebMove.throwIn()` on the player's first turn to speak, **as long as nobody has bid yet**
  (earlier passes do not matter). Once someone has bid, the chance is gone: a bid shows strength, and a claim
  after it would let a player cancel a deal the other side is about to win. The hand is shown (the `redeal` event
  carries it, detail `worthlessHand`), nobody scores, and the **next** dealer deals. Error id when not allowed:
  `cannotThrowIn`.
- **A-opt-4** `firstLeadMustBeTrump` – the opening lead of the deal must be a trump when the leader holds one
  (error id `mustLeadTrump`); later leads are free.
- **A-opt-5 open auction** – `TarneebOptions.openAuction()`: `passIsFinal: false` (a player who passed may bid
  again; three passes in a row after a bid end the auction) with `allPass: dealerTakesMinimum`.
- `loseAtNegativeTarget` – a team at or below minus the target after a deal loses (the `matchOver` event's detail
  is `negativeTarget`; otherwise `target`).

**Events / ids for the UI.** `redeal` (detail `allPassed` or `worthlessHand`), `trumpChosen` (detail
`exposedCard` in the Syrian game), `roundScored`, `matchOver` (detail `target` / `negativeTarget`). Error ids:
`notYourTurn`, `matchOver`, `wrongPhase`, `bidTooLow`, `bidTooHigh` (above 13), `dealerMustBid`, `cannotThrowIn`,
`mustFollowSuit`, `mustLeadTrump`, `cardNotInHand`.

**Saved matches.** Options load with defaults for missing keys. A save from before these defaults (it has
`allTricksScore` and `allPass: "redeal"`) keeps its old rules: next-dealer redeal, 13 tricks = `allTricksScore`
for any bid, a failed 13 = −13 with the defenders' tricks counted once. (The old engine paid the defenders of a
failed 13 by its `failScore`; with the old default, `defendersTricks`, that is the same thing. A save that also
changed `failScore` to `bid` or `nothing` now pays their tricks instead. There are no such saves, since no UI has
shipped.)

### 1.4 Assumptions to confirm (☐)

1. ☐ All four pass → the **same dealer** deals again (published rule sets say so; some online tables pass the
   deal on – `redealNextDealer`; or the dealer must take 7 – `dealerTakesMinimum`).
2. ☐ A failed bid of 13: the defenders score **double** their tricks (`kabootFailDefenders`); the bidders lose 16
   either way.
3. Made = the tricks taken; the defenders score nothing when the contract is made.
4. Failed = minus the bid; the defenders score the tricks they took.
5. 13 tricks without bidding 13 = 16; bid 13 and made = 26 (not an instant win).
6. ☐ No "lose at −31" rule and no "worthless hand" throw-in by default (both are options).
7. The worthless-hand throw-in is claimed on a player's first turn to speak and only before anyone has bid (at
   a table it is announced right after the deal, before the auction; the engine keeps the turn order, and passes
   before the claim give almost nothing away).
8. The Lebanese auction ends at once on a bid of 13, like the standard one (the dealer cannot equal 13).

---

## 1b. 41 – ٤١ (طلب فردي)

**As commonly played around Jordan.** "41" is the Tarneeb-family game where every player bids **for themselves**,
with hearts as permanent trumps, and a team wins when one partner reaches **41** while the other partner is
**above zero**. In the lobby, show it as «٤١» with the subtitle «طلب فردي» – not «طرنيب 41», which in Jordanian game
lists means the partnership Tarneeb played to 41 (§1). Code: `tarneeb41/forty_one_state.dart`,
`tarneeb41/forty_one_rules.dart`, `tarneeb41/forty_one_ai.dart` (`FortyOneEngine`, `FortyOneOptions`,
`FortyOneAi`). It is in the registry as `CardGameId.fortyOne`
(`CardGames.newMatch`, `fromJson`, `ai`); the save's `game` key is `fortyOne`.

**Named presets**

| Preset | Arabic (UI) | What changes |
|---|---|---|
| `FortyOneOptions()` = `FortyOneOptions.jordan()` | ٤١ | nothing: every default below |
| `FortyOneOptions.lebanese400()` | ٤٠٠ (لبناني) / أربعمية | the 400 value table and minimums that rise with the scores |
| `FortyOneOptions.syrian()` | سوري ٤١ | trumps from the dealer's exposed card |

### 1b.1 Options (`FortyOneOptions`)

| Option | "41" (default) | "400" | "Syrian 41" | Values |
|---|---|---|---|---|
| `trumpMode` (`FortyOneTrumpMode`) | **`heartsFixed`** | `heartsFixed` | `exposedCardSisterSuit` | – |
| `minBid` | **2** | 2 (rising) | 2 | 1, 2 |
| `minTotal` | **11** | 11 (rising) | 11 | any int |
| `risingMinimums` | **false** | **true** | false | bool |
| `valueTable` (`FortyOneValueTable`) | **`doubleFrom7`** | **`levant400`** | `doubleFrom7` (☐) | `doubleFrom7`, `levant400`, `faceValue` |
| `levantTenPlus` (`FortyOneTenPlus`) | – | **`flat40`** | – | `flat40`, `times4` (40/44/48/52) |
| `target` | **41** | 41 | 41 | any int |
| `partnerRule` (`FortyOnePartnerRule`) | **`positive`** (> 0) | same | same | `positive`, `nonNegative` (≥ 0) |
| `bothQualify` (`FortyOneBothQualify`) | **`higherTeamTotal`** | same | same | `higherTeamTotal`, `higherIndividual` |
| `throwInRedeal` (`FortyOneThrowIn`) | **`nextDealer`** | same | same | `nextDealer`, `sameDealer` |
| `firstLead` (`FortyOneFirstLead`) | **`dealerRight`** | same | same | `dealerRight`, `highestBidder` |
| `bid13WinsMatch` | **false** | false | false | bool |
| `firstDealer` | **3** | 3 | 3 | 0–3 |

### 1b.2 Rules

**B1. Players and deal.** Four players, partners opposite (0 & 2 against 1 & 3). **Scores are kept per player**
(`state.playerScores`, `scores`); partnership matters only for winning. 52 cards, ace high, play to the right,
13 cards each. After every scored deal the deal passes to the right.

**B2. Bidding (الطلب).** Starting on the dealer's right and ending with the dealer, each player says **once** how
many tricks **they alone** will take, from `minBid` (2) to 13. There is **no pass**. A bid need not be higher than
the earlier ones, and the total may be more than 13. If the four bids add up to **less than `minTotal` (11)**,
nobody scores and the cards are thrown in; the next dealer deals (`throwInRedeal`; the `redeal` event has detail
`lowTotal` and the total as its value). The dealer is never forced to make the total up – bidding low as dealer is
how a player lets a deal be thrown in – but can always reach it (the others bid at least 2 each and the dealer may
bid up to 13). Error ids: `bidTooLow`, `bidTooHigh`.

**B3. Play.** Trumps are **hearts** (`heartsFixed`). The player on the dealer's right leads the first trick
(`firstLead: dealerRight`; option `highestBidder`, the earliest of equal highest bids). Follow suit if you can,
otherwise play any card – trumping is never compulsory. The highest trump wins, otherwise the highest card of the
suit led. Tricks count **per player**: a partner's tricks do not help you. All 13 tricks are played.

**B4. Scoring (each player, each deal).** Took at least your bid → **+value(bid)**; extra tricks are worth nothing.
Took fewer → **−value(bid)**.

| Bid | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 11 | 12 | 13 |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| `doubleFrom7` (default) | 1 | 2 | 3 | 4 | 5 | 6 | 14 | 16 | 18 | 20 | 22 | 24 | 26 |
| `levant400`, own score **below 30** at the start of the deal | 1 | 2 | 3 | 4 | 10 | 12 | 14 | 16 | 27 | 40 | 40 | 40 | 40 |
| `levant400`, own score **30 or more** | 1 | 2 | 3 | 4 | 5 | 6 | 14 | 16 | 27 | 40 | 40 | 40 | 40 |
| `faceValue` | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 11 | 12 | 13 |

(`levantTenPlus: times4` makes 10–13 in the 400 table worth 40 / 44 / 48 / 52.) Examples: `doubleFrom7`: bid 2
took 0 → −2; bid 7 took 9 → +14; bid 13 made → +26. `levant400` below 30: 5 made → +10, 9 made → +27, 9 failed →
−27; the same player on 34 bids 5 and makes it → +5. Code: `FortyOneOptions.value`, `FortyOneRules.dealPoints`.

**Rising minimums** (`risingMinimums`, the 400 preset). A player's own lowest bid depends on **their own** score:
below 30 → 2, 30–39 → 3, 40–49 → 4, 50 or more → 5. The minimum total depends on the **highest score at the
table**: below 30 → 11, 30–39 → 12, 40–49 → 13, 50 or more → 14. (`state.minBidFor(seat)`, `state.minTotalNow`.)

**B5. Winning.** Checked after each scored deal. A team **qualifies** when one partner is at **41 or more** and the
other partner is **above 0** (`partnerRule: positive`; option `nonNegative`: 0 or more). If one team qualifies it
wins. If both qualify after the same deal: the higher **team total** wins, then the higher single score, and if
still level another deal is played (`bothQualify: higherTeamTotal`; option `higherIndividual` compares the single
score first). A player at 41+ whose partner does not qualify simply plays on (and can drop back below 41). Scores
have no floor or ceiling. With `bid13WinsMatch`, bidding 13 and taking all 13 tricks wins the match at once
(`matchOver` detail `bid13`; otherwise `target`). Code: `FortyOneRules.qualifies`, `FortyOneRules.matchWinner`.

**Syrian 41** (`trumpMode: exposedCardSisterSuit`): the dealer's last dealt card is shown to everyone and stays in
the dealer's hand; trumps are the other suit of the same colour (♥ ↔ ♦, ♠ ↔ ♣). Everything else as in "41".

### 1b.3 Assumptions to confirm (☐)

1. ☐ Hearts always trumps (default) – or the Syrian exposed-card trump?
2. ☐ Values: face value to 6 and doubled from 7 (default), or the 400 table (5 = 10 … 9 = 27, 10+ = 40)? Do the
   minimums rise with the scores?
3. ☐ A partner on exactly 0: not enough by default (`nonNegative` allows it).
4. ☐ Both teams qualifying: the higher team total (default) or the higher single score?
5. ☐ After a throw-in the next dealer deals (default) or the same one.
6. The first lead comes from the dealer's right (not the highest bidder).
7. The 400 caps (minimum bid 5, minimum total 14 from 50 points) replace an unsourced "+1 per further 10".
8. The Syrian preset's value table is not known; it reuses `doubleFrom7`.
9. "Bid 13 and make it wins the match" is off (a house rule).

### 1b.4 How the rules are checked (Tarneeb and 41)

Besides a unit test for each rule and each scoring line above, a test (`tarneeb_model_test.dart`) holds a second,
independent model of both games, written from this section rather than from the engine. It plays fuzzed matches
over the presets and random option mixes, with the model following the same moves. After every move the seat to
act, the dealer, the deal counters, the legal moves, the error id of every illegal move and the scores must agree,
and at the end so must the winner. Saves are restored along the way.

---

## 2. Trix – تركس, and Trix Complex – تركس كومبلكس

**As commonly played in Jordan.** Trix is a four-player game of four "kingdoms" (ممالك). Each player owns one
kingdom and, in it, picks the order of its contracts. Classic Trix has five contracts per kingdom; Trix Complex
merges the four trick contracts into one deal. Both are played each for himself or in partnership (شراكة). The
lobby shows four entries (`TrixPreset`), all with the Jordanian rules:

| `TrixPreset` | Arabic (UI) | English | Options | Deals |
|---|---|---|---|---|
| `trix` (**default**) | «تركس» | Trix | `TrixOptions()` | 4 kingdoms × 5 = 20 |
| `trixPartnership` | «تركس شراكة» | Trix, partners | `TrixOptions(partnership: true)` | 20 |
| `complex` | «تركس كومبلكس» | Trix Complex | `TrixOptions(mode: TrixMode.complex)` | 4 × 2 = 8 |
| `complexPartnership` | «كومبلكس شراكة» | Trix Complex, partners | both | 8 |

When the owner and his wife play together against two AIs they sit at seats 0 and 2 (partners).

Code: `trix/trix_state.dart` (options, moves, state), `trix/trix_rules.dart` (legal moves, play, scoring),
`trix/trix_ai.dart` (three AI levels). Tests: `test/features/cinema/rules/cards/trix_test.dart` (one test per rule
and worked example below, named by its id) and `trix_play_test.dart` (self-play of every preset and house-rule set,
score invariants, an independent referee that re-derives turns, legal moves and every seat's points from this text
over random house rules, hidden-doubling fairness, replay, and the three AI levels in order).

**Defaults.** `const TrixOptions()` **is** the Jordanian preset (`TrixOptions.jordan()`; the two are identical).
`TrixOptions.openDoubling()` keeps the engine's earlier rules as a named house-rule set: seat 0 always owns the
first kingdom, each double is public the moment it is made, and a doubler who takes his own doubled card pays
double with no bonus. `copyWith` changes single options (the "قوانين البيت" screen).

### 2.1 Words for the UI

| Concept | Label | Other names |
|---|---|---|
| Hearts, diamonds, clubs, spades | كبة، ديناري، سباتي، بستوني | |
| King-of-hearts contract (`king`) | **شيخ الكبة** | الختيار (the K♥ itself, colloquial), الشيخ |
| Queens (`queens`) | **البنات** | |
| Diamonds (`diamonds`) | **الديناري** | |
| Tricks (`ltoush`) | **اللطوش** (one trick: لطش / أكلة) | |
| Layout (`trix`) | **التركس** | |
| Complex (`complex`) | **الكومبلكس** | |
| Kingdom / its owner | مملكة / صاحب المملكة | |
| Doubling / a doubled card | دبل، تدبيل / ورقة مدبّلة | |
| Partnership | شراكة | |
| Jack | ولد / شب | |
| Pass on the layout | باص (يباصي) | |
| The 7♥ | سبعة الكبة | |

### 2.2 Options (`TrixOptions`)

| Option | Jordan default | Other values | Confidence |
|---|---|---|---|
| `mode` (`TrixMode`) | `classic`: king, queens, diamonds, ltoush, trix | `complex`: complex, trix | high |
| `partnership` | `false` | `true`: seats 0 & 2 against 1 & 3, team totals | high |
| `firstOwnerRule` (`TrixFirstOwner`) | `sevenOfHearts`: the 7♥ holder of the first deal owns the first kingdom | `fixedSeat`: `firstOwner` owns it | high |
| `firstOwner` | 0 (used only with `fixedSeat`) | 0–3 | – |
| `doubling` | `true` | `false`: no doubling phase | high |
| `doublingReveal` (`TrixDoublingReveal`) | `simultaneous`: answers hidden until all four have answered (**☐ Confirm**) | `sequential`: each double public at once | low–medium |
| `selfCaptureRule` (`TrixSelfCapture`, individual game) | `leaderGains` (**☐ Confirm**) | `leaderGainsStrict`, `normalValue`, `doubleNoBonus` (see 2.7) | medium (forced) / low (self-led) |
| `partnerCaptureRule` (`TrixPartnerCapture`, partnership) | `noBonus` (**☐ Confirm**) | `opponentsGain`, `normalValue` (see 2.7) | medium-low |
| `noHeartLeadInKing` | `true` (**☐ Confirm**) | `false` | medium |
| `kingMustBeDiscarded` | `true` (**☐ Confirm**) | `false` | medium |
| `kingOnAceOfHearts` | `false` (**☐ Confirm**) | `true`: K♥ must go on a heart trick holding A♥ | uncertain |
| `kingRulesInComplex` | `true` (**☐ Confirm**) | `false`: the three king rules apply to the King contract only | low |
| `kingPenalty`, `queenPenalty`, `diamondPenalty`, `trickPenalty` | 75, 25, 10, 15 | any | high |
| `trixScores` | [200, 150, 100, 50] | any four values | high |

Saved options without a key (older saves) load that key's Jordanian default.

Fixed, not configurable: 4 players; one 52-card pack, A high down to 2, no trumps; 13 cards each and a fresh
shuffle for every contract; no bidding and no misdeal; turn order `seat + 1` (drawn counter-clockwise); the owner
chooses the contract after seeing the cards and leads / starts the layout; the King, Queens and Diamonds deals end
early; Trix: must play when able; the match is always 4 kingdoms with no target score.

### 2.3 Setup and kingdoms

| # | Rule |
|---|---|
| T-1 | Four players, one 52-card pack. |
| T-2 | Ace high down to 2. No trumps: the highest card of the led suit wins the trick. |
| T-3 | Every contract gets a fresh deal of 13 cards each. |
| T-4 | Play goes to the next seat (`seat + 1`), drawn counter-clockwise. |
| T-5 | No bidding and no misdeal: every deal starts with the owner choosing a contract. |
| K-1 | Four kingdoms, one per player. |
| K-2 | **The player holding the 7♥ in the first deal of the match owns the first kingdom** (`firstOwnerRule: sevenOfHearts`). Only the first deal decides; the rule is not re-applied in later kingdoms. |
| K-3 | When a kingdom's contracts are used up, the next seat (`owner + 1`) owns the next kingdom. |
| K-4 | The owner picks, for each deal, one contract of the kingdom not played yet, in any order, after seeing his cards. Error ids: `contractAlreadyPlayed`, `contractNotAvailable` (a contract of the other mode). |
| K-5 | On the first deal the 7♥ holder chooses at once, on those same cards. |
| K-6 | The owner leads the first trick, or places the first card of the layout. |
| K-7 | No compulsory order (Trix or King may come first). |

### 2.4 Trick play (every contract except Trix)

| # | Rule |
|---|---|
| P-1 | Follow the led suit if you can (`mustFollowSuit`); otherwise play any card, subject to the king rules (2.5.1). |
| P-2 | The highest card of the led suit wins; the winner leads the next trick. |
| P-3 | Taken tricks are kept by the winner; the state keeps every trick (`tricks`: leader, seats, cards), which the scoring of doubled cards needs. |

### 2.5 The contracts

#### 2.5.1 شيخ الكبة – King of hearts (`king`)

| # | Rule |
|---|---|
| P-K1 | Whoever takes K♥ loses **75**. |
| P-K2 | `kingMustBeDiscarded`: a player who cannot follow the led suit and holds K♥ must throw it (`mustDiscardKing`). A holder who can follow suit follows normally. |
| P-K3 | `noHeartLeadInKing`: the leader may not lead a heart while holding any other suit (`noHeartLead`). With only hearts he may lead any heart, K♥ included. |
| P-K4 | The deal ends as soon as the trick holding K♥ is won. |
| P-K5 | `kingOnAceOfHearts` (off): on a heart trick where A♥ is already played, the holder of K♥ must play it (`mustPlayKingOnAce`). |

Only K♥ can be doubled in this contract.

#### 2.5.2 البنات – Queens (`queens`)

| # | Rule |
|---|---|
| P-Q1 | Each queen taken costs **25** (−100 per deal). |
| P-Q2 | No lead or discard restrictions. |
| P-Q3 | The deal ends when the fourth queen is taken. Each queen may be doubled on its own. |

#### 2.5.3 الديناري – Diamonds (`diamonds`)

| # | Rule |
|---|---|
| P-D1 | Each diamond taken costs **10** (−130 per deal). |
| P-D2 | No restrictions. |
| P-D3 | The deal ends when the 13th diamond is taken. |
| P-D4 | Diamonds are never doubled (no doubling phase). |

#### 2.5.4 اللطوش – Tricks (`ltoush`)

| # | Rule |
|---|---|
| P-L1 | Each trick taken costs **15**; all 13 tricks are played (−195 per deal). |
| P-L2 | No restrictions, no doubling. |

#### 2.5.5 التركس – the layout (`trix`)

| # | Rule |
|---|---|
| X-1 | Each suit's row starts with its jack (ولد). |
| X-2 | A row grows one rank at a time, **down** to the 2 and **up** to the ace. Playable: any jack not yet down, the card just below a row's lowest card, the card just above its highest (`notPlayableOnLayout` otherwise). |
| X-3 | The owner plays first, then the seats in turn; players with no cards left are skipped. |
| X-4 | One card per turn. You **must** play if you can (`mustPlayWhenAble`); pass (باص) only with no playable card. A seat that passes is known not to hold any card that was then playable (`cannotHold`, used by the AI). |
| X-5 | Places score **+200 / +150 / +100 / +50**. In partnership the places stay individual and are added per team (350/150, 300/200 or 250/250). |
| X-6 | When the third player goes out the deal ends; the fourth is placed last (his cards complete the layout). Each player out emits `playerFinished` with his place (`value` 1–4); the fourth's event also carries the cards he still held. |
| X-7 | The layout cannot jam: the next card any unfinished row needs is always in an active player's hand. |
| X-8 | No bonus for the owner; nothing is doubled in Trix. |

#### 2.5.6 الكومبلكس – Complex (`complex`, mode `complex`)

| # | Rule |
|---|---|
| C-1 | Each kingdom has two contracts, Complex and Trix: 8 deals per match. |
| C-2 | Complex is one trick deal that scores K♥ −75, each queen −25, each diamond −10 and each trick −15 together. |
| C-3 | Penalties stack: Q♦ costs −25 and −10, and its trick another −15. |
| C-4 | All 13 tricks are always played. |
| C-5 | The deal totals −500, so a Complex kingdom (−500 + 500) sums to 0. |
| C-6 | Doubling works as in King and Queens (K♥ and each queen). |
| C-7 | The king rules (P-K2, P-K3, P-K5) apply in Complex too, unless `kingRulesInComplex: false`. They last the whole Complex deal: hearts may not be led while holding another suit even after K♥ has been taken (**☐ Confirm**). |

### 2.6 Doubling – الدبل (`doubling`)

| # | Rule |
|---|---|
| DB-1 | On by default. In King, Queens and Complex, after the contract is chosen and before the first lead, every seat answers once, starting with the owner and going round. |
| DB-2 | Only K♥ (King, Complex) and the queens (Queens, Complex) can be doubled. |
| DB-3 | A player doubles any subset of the doublable cards he holds (the legal moves are every subset; "no double" is the empty subset). Doubling a card he does not hold is `cardNotInHand`; any other card (a diamond, a queen in King, K♥ in Queens) is `notDoublable`. |
| DB-4 | Doubling happens after the contract and before the first lead. |
| DB-5 | `doublingReveal: simultaneous` (default): all four seats answer in turn, even a seat with nothing to double (its only move is "no double"; skipping it would reveal who holds K♥ or a queen). Nobody else sees an answer until the fourth; then every doubled card is shown at once. `sequential`: each double is public at once. |
| DB-6 | A doubled card stays public for the rest of the deal. |
| DB-7 | A doubled card may be led. |

**Events.** Simultaneous: each answer emits `CardEventType.doubled` **without cards**, `detail: 'doublingAnswered'`
(`TrixEventDetail.doublingAnswered`). It must be shown as "answered", never as a double. After the fourth answer, one
`doubled` event **with cards** per doubling seat, in seat order from the owner, `detail: 'doublingRevealed'`.
Sequential: `doubled` with cards, or `pass` for "no double". The hidden answers are in `state.pendingDoubles` (saved
with the match); the UI and the AIs may only show a seat its own entries (`state.doublesVisibleTo(seat)`).

### 2.7 Scoring

#### Per contract (undoubled)

| Contract | Unit | Value | Deal total | The deal ends |
|---|---|---|---|---|
| شيخ الكبة | K♥ | −75 | −75 | K♥ taken |
| البنات | each Q | −25 | −100 | 4th Q taken |
| الديناري | each ♦ | −10 | −130 | 13th ♦ taken |
| اللطوش | each trick | −15 | −195 | 13 tricks |
| التركس | place | +200 / +150 / +100 / +50 | +500 | 3 players out |
| الكومبلكس | all four, stacked | as above | −500 | 13 tricks |

A classic kingdom: −75 −100 −130 −195 +500 = **0**. A Complex kingdom: −500 +500 = **0**.
(`TrixOptions.undoubledTotal(contract)` gives the deal totals.)

#### A doubled card (`TrixRules.dealPoints`)

`v` = 75 (K♥) or 25 (Q). For a doubled card X: `d` is its doubler, `t` the seat that won the trick holding it, `L`
that trick's leader. **Self-led** means `L == d`: the doubler led that trick, so he led X. **Forced** means someone
else led and the doubler followed with X, which won.

| # | Case | Mode | Rule | t | Someone else |
|---|---|---|---|---|---|
| DB-S1 | not doubled | any | – | −v | – |
| DB-S2 / DB-P1 | an opponent of `d` took it (`team(t) != team(d)`) | any | – | **−2v** | **d +v** |
| DB-S3 | `t == d`, forced | individual | **`leaderGains`** (default) | −2v | **L +v** |
| | | | `leaderGainsStrict` | −2v | L +v |
| | | | `normalValue` | −v | – |
| | | | `doubleNoBonus` | −2v | – |
| DB-S4 | `t == d`, self-led | individual | **`leaderGains`** (default) | **−v** | – |
| | | | `leaderGainsStrict` | −2v | – |
| | | | `normalValue` | −v | – |
| | | | `doubleNoBonus` | −2v | – |
| DB-P2 / DB-P3 | `d` or his partner took it | partnership | **`noBonus`** (default) | **−2v** | – |
| | | | `opponentsGain` | −2v; but −v when `t == d` and self-led | +v to L if L is an opponent of `d`, else to `L + 1` (always an opponent); nobody in the −v case |
| | | | `normalValue` | −v | – |

In Complex the diamond (−10) and trick (−15) parts are added unchanged (never doubled).

#### Worked examples (defaults)

| # | Example |
|---|---|
| EX-1 | King. Seat 1 doubles K♥, seat 0 takes it: **0: −150, 1: +75**. |
| EX-2 | Queens, individual. Seat 3 doubles Q♣; seat 1 leads ♣4, seat 3 follows with Q♣ and nobody beats it: **3: −50, 1: +25**. |
| EX-3 | Queens, individual. Seat 3 doubles Q♣, later leads it himself and wins: **3: −25**. (Same for a self-led K♥: −75.) |
| EX-4 | Queens, partnership. Seat 0 doubles Q♠, his partner (seat 2) wins the trick: **2: −50, nobody gains** (team 0 loses 50). |
| EX-5 | Complex, individual. Seat 0 doubles Q♦; seat 1 takes it in a trick with no other penalty card: **1: −50 −10 −15 = −75; 0: +25**. |
| EX-6 | Complex, individual. Seat 2 doubles K♥ and must throw it (void) on seat 3's club lead, which seat 0 wins: **0: −150 −15 (and any other cards), 2: +75**. |

#### Invariants (checked by the self-play tests on every deal)

- **Individual, default options (and `normalValue`):** every deal sums to its undoubled total (−75, −100, −130,
  −195, −500 or +500), so every completed kingdom, and the match, sums to 0. With `leaderGainsStrict` a self-led
  doubled card, and with `doubleNoBonus` every doubler's own capture, takes another `v` out of the deal.
- **Partnership, default `noBonus`:** deal sum = undoubled total − Σ `v` over every doubled card taken by its
  doubler's own team. With `opponentsGain` or `normalValue` every deal sums to its undoubled total again.
- A Complex deal always takes all 13 tricks, 13 diamonds, 4 queens and K♥.

### 2.8 Match end

| # | Rule |
|---|---|
| M-1 | A fixed number of deals: 20 (classic) or 8 (Complex); no target score. The last deal emits `matchOver`. |
| M-2 | The highest total wins. |
| M-3 | Without doubles, or with the individual defaults, every completed kingdom and so the final totals add up to 0. |
| M-4 | Tied leaders all win, which is a draw (**☐ Confirm**: no source gives a tie-break). |
| M-5 | Partnership: partners share the team total (`scores`); negative totals are allowed. |

### 2.9 Edge cases

| # | Case |
|---|---|
| E-1 | The 7♥ owner rule applies to the first deal of the match only (`newMatch` and `withHands` alike). |
| E-2 | Every seat answers the doubling even with nothing to double (one legal move). Some seat always holds K♥ / a queen. |
| E-3 | Until the reveal only the doubling seat knows its answer. The AIs read only their own pending answer; the hard AI's sampled worlds re-draw the other seats' pending answers from their sampled hands and pin only **revealed** doubled cards to their doublers. |
| E-4 | The King deal ends on the K♥ trick; the scoring uses that trick's leader. |
| E-5 | A self-led doubled K♥ is only possible when the doubler has only hearts left (P-K3). Default: −75. |
| E-6 | A void K♥ holder must throw it; one who can follow suit follows normally (and, with `kingOnAceOfHearts`, must play K♥ onto A♥). |
| E-7 | A leader with only hearts may lead any heart, K♥ included. |
| E-8 | Trix: pass only with no playable card. |
| E-9 | Trix: the third player out ends the deal; the fourth takes the last place. |
| E-10 | Partnership Trix is scored per seat, then added per team. |
| E-11 | A tie at the end is a shared win (draw). |

### 2.10 Engine notes

- State: `owner`, `kingdom` (0–3), `used` (contracts played in this kingdom), `contract`, `doubled` (public),
  `pendingDoubles` (hidden, simultaneous only), `doublingAnswers`, `trick` / `tricks`, `taken`, `tricksTaken`,
  the layout (`layoutLow`, `layoutHigh`, `layoutCards`), `finished`, `cannotHold`, `seatScores`, `results`
  (`TrixDealResult`: owner, contract, points per seat).
- Moves (`TrixMove`): `contract`, `double(cards)` (empty = no double; the cards are kept sorted, also when read from
  JSON, so their order never matters), `play(card)`, `pass`.
- Error ids: `contractAlreadyPlayed`, `contractNotAvailable`, `cardNotInHand`, `notDoublable`, `mustFollowSuit`,
  `noHeartLead`, `mustDiscardKing`, `mustPlayKingOnAce`, `notPlayableOnLayout`, `mustPlayWhenAble`, `wrongPhase` (a
  move of another phase), plus the shared `notYourTurn` / `matchOver`.
- AI: see "AI opponents – Trix".

### 2.11 Assumptions to confirm (☐)

Ordered by impact.

1. ☐ **Partnership:** your partner takes the K♥ / queen **you** doubled: −2× with nobody gaining (default
   `noBonus`), the other team gains the value (`opponentsGain`), or it counts as a normal card (`normalValue`)?
2. ☐ **Individual:** a doubler forced to take his own doubled card: does the player who led that trick gain the value
   (default)? And if the doubler led it himself: normal value (default, `leaderGains`) or double
   (`leaderGainsStrict`)?
3. ☐ **Doubling:** at the same time and hidden (default), or one after another, seeing earlier doubles
   (`sequential`)?
4. ☐ **King:** heart leads banned while holding other suits? Must a void player throw K♥? Must K♥ be played onto A♥
   (default: no)? Do the same rules apply in Complex (default: yes), and in Complex does the heart-lead ban end once
   K♥ has been taken (default: no, it lasts the whole deal)?
5. ☐ Which is played most at home: تركس or كومبلكس, individual or شراكة? That decides the first menu entry.
6. ☐ Tie at the end: a draw (default), or a tie-break?

### 2.12 Variants not offered

- "Combine any contracts" (an international variant), and the app-specific "Complex CC": not Jordanian mainstream.
- The 7♥ holder re-chosen on every kingdom: breaks "each player owns one kingdom".
- A sixth "hearts" contract: one source only, never confirmed.
- A forced penalty discard in Queens / Diamonds: an international variant, not the Jordanian default.

---

## 3. Hand – هاند

**As commonly played in Jordan.** Hand is the Levantine rummy of Jordan, Lebanon and Palestine: two packs and two
jokers, 14 cards each, a first lay-down of at least 51, and a big reward for laying everything down in one turn
(the "hand" that gives the game its name). `const RummyOptions()` and `const RummyOptions.hand()` **are** the
Jordanian game. Code: `rummy/rummy_options.dart` (options), `rummy/rummy_meld.dart` (melds, wild cards, search),
`rummy/rummy_state.dart` (moves, state), `rummy/rummy_rules.dart` (rules, scoring), `rummy/rummy_ai.dart` (AI),
`hand/hand.dart` (`HandEngine`, `HandAi`). Konkan (§6) uses the same engine.

Words for the UI, as said at a Jordanian table: النزول (opening, the first lay-down), ضمون (a normal finish),
هاند (a full hand: everything down in one turn), ترقيع / تلزيق (laying off on a table meld), تبديل الجوكر (taking a
table joker by putting the card it stands for), الأرض (the discard pile), البادي (the starter, dealt 15 cards),
ورقة الكشف (the turned-up indicator card of the indicator option).

**Named presets** (the Arabic labels are suggestions for the UI)

| Preset | Arabic (UI) | What changes |
|---|---|---|
| `RummyOptions()` = `RummyOptions.hand({players, rounds, openingThreshold, jokerPenalty, partnership})` | هاند | nothing: every default below |
| `RummyOptions.handPartnership({rounds, openingThreshold})` | هاند شراكة | four players, partners opposite (§3.4) |
| `RummyOptions.handIndicator({players, rounds = 7})` | هاند بورقة الكشف | the indicator card makes one suit's aces wild (§3.5), 7 rounds, void when the stock runs down to the number of players (the Levantine home table described by pagat's Nablus / Amman informant) |

UI choice lists: `RummyOptions.roundChoices` = **5** · 7; `openingThresholdChoices` = **51** · 61 · 71 · 91;
`jokerPenaltyChoices` = **15** · 25 · 50. `RummyOptions.invalidReason` returns an error id for an unsupported
combination (and `newMatch` refuses it): other than 2–4 players, partnership with other than 4 players,
partnership with elimination, `maxWildsPerMeld` below 1, or above 1 with `setWildSwap: bothMissing`, the indicator
with other than 2 jokers, no pack or more than 4 jokers, and a hand size that leaves no stock.

### 3.1 Options (`RummyOptions`)

| Option | Jordan default | Other values | Confidence |
|---|---|---|---|
| `players` | **4** | 2, 3 | high |
| `decks` / `jokers` | **2 / 2** (106 cards) | `jokers` 0–4 (4 = the old engine) | high |
| `handSize` | **14** (the starter 15) | any that leaves a stock | high |
| `starterFirstTurnDiscardOnly` | **true** | false | high |
| `noGoOutOnFirstTurn` | **true** | false | high |
| `maxWildsPerMeld` | **1** | 2–4 (with fewer wilds than naturals; needs `anyMissingSuit`) | high |
| `wildIndicator` | **false** (the two printed jokers are the wilds, as on Jawaker) | true: §3.5 | medium (☐ §3.6 q1) |
| `openingThreshold` | **51** | 61, 71, 91 | high |
| `aceLowOpeningValue` / `aceHighOpeningValue` | **11 / 11** | 1 / 10 | high |
| `openingRequiresRun` | **false** | true | low (no source) |
| `openingMustBeatPrevious` | **false** | true: each later opening must beat the highest so far | high (as a variant) |
| `openingMustUseDiscard` | **false** | true (the Yemeni Konkan rule, §6) | low |
| `oneTurnFinishWaivesThreshold` | **true** | false | high |
| `discardUse` (`RummyDiscardUse`) | **`newMeldOnly`** | `any` (also lay-offs and swaps after opening) | high |
| `jokerSwap` | **true** | false | high |
| `setWildSwap` (`RummySetWildSwap`) | **`bothMissing`** | `anyMissingSuit` | high |
| `swappedWildMustBeUsed` | **false** | true | high |
| `fullHandOwnMeldsOnly` | **true** | false | high |
| `winnerScore` (ضمون) / `handWinnerScore` (هاند) / `handMultiplier` | **−30 / −60 / 2** | any | high |
| `notOpenedPenalty` | **100** (200 after a hand) | any | high |
| `acePenalty` | **11** | 10 | high |
| `jokerPenalty` | **15** | 25, 50 | medium (☐ §3.6 q2) |
| `bonusWildLastDiscard` / `bonusOneColour` / `bonusOneSuit` | **false** | true (Gulf / Egyptian tables) | high (as variants) |
| `partnership` / `partnerOfWinnerPays` | **false / false** | true | high |
| `matchEnd` (`RummyMatchEnd`) | **`rounds`** | `targetScore`; `elimination` (Konkan) | high |
| `rounds` / `targetScore` / `eliminationScore` | **5** / 500 / 301 | 7 rounds; any | high (5, Jawaker) |
| `voidRoundsCount` | **false** | true | medium |
| `tieBreak` (`RummyTieBreak`) / `maxTieBreakRounds` | **`extraRounds` / 3** | `shared` | medium |
| `dealerRule` (`RummyDealerRule`) | **`loserDeals`** | `rotate` | medium (☐ §3.6 q4) |
| `stockEnd` (`RummyStockEnd`) / `maxStockRecycles` | **`reshuffle` / 2** | `voidAtPlayers`, `flipNoShuffle` | medium |
| `pairsRedeal` | **true** | false | medium |

### 3.2 Rules

The IDs in brackets are the rule IDs used in the tests (`test/features/cinema/rules/cards/hand_rules_test.dart`,
`rummy_test.dart`), so each rule can be checked against its test. IDs such as [2.10], [§5] or [§6] name sections of
the Hand research spec (`hand_konkan_final.md`), not sections of this file.

**Table and deal**
1. [C1, C2] 2–4 players, each for themselves. Play and dealing go counter-clockwise (`seat + 1`).
2. [C6] Deck: two packs and **two jokers = 106 cards**; every natural card exists twice. There is no cut.
3. [C7] Everyone gets **14** cards; the seat after the dealer (the starter, البادي) gets **15**. The rest is the
   face-down stock; the discard pile starts empty. Stock: 77 / 63 / 49 cards with 2 / 3 / 4 players.
4. [C3] The first dealer is the seat before seat 0 (so the human starts). **The next dealer is the seat with the
   most points in the round just scored** (`dealerRule: loserDeals`); if several tie and the dealer is among them
   the dealer deals again, otherwise the first of them after the dealer. After a void round the same dealer deals
   again. Option `rotate`: the next seat deals.
5. [2.10] **Pairs redeal** (`pairsRedeal`): before the starter's first discard, a player dealt **four identical
   pairs**, or three identical pairs and a joker, or two identical pairs and both jokers, may throw the deal in
   (move `callRedeal`); the same dealer deals again and the deal does not count. It is optional (`keepHand`). The
   engine asks only the seats whose hand qualifies, in turn order from the starter (phase `redealOffer`).

**The turn**
6. [C8] The **starter's first turn is only a discard**: no draw, no lay-down.
7. [T1–T3] Every other turn: (a) draw the top stock card **or** take the top discard (rule 16); (b) optionally
   lay down: open, new melds, lay-offs, wild swaps, in any order the rules allow; (c) **discard** one card, which
   always ends the turn.
8. [O7, L4] You must keep a card for the discard: you can never lay down your last card, and with two cards
   you cannot meld them with a drawn third (`mustKeepOneCard`).
9. [G3] **Nobody goes out on their first turn** (`noGoOutOnFirstTurn`): on a seat's first turn its lay-downs must
   leave at least two cards (`noGoOutOnFirstTurn` error). The earliest finish is a seat's second turn.
10. [T6] Any card may be discarded, a joker too, even one that fits a table meld.

**Melds**
11. [M1] **Set**: 3 or 4 cards of one rank in different suits (never two identical cards).
12. [M2, M3] **Run (سيري)**: 3–13 cards in sequence in one suit; the ace is low (A-2-3) or high (Q-K-A), never
    round the corner (K-A-2 is not a run).
13. [J1, J2] **Wild cards**: the two jokers stand for any card, **at most one wild per meld**
    (`maxWildsPerMeld: 1`), so a meld always has at least two natural cards.
14. [J4] **Where a wild stands in a run is the player's choice**: 5♥ 6♥ 🃏 is 5-6-7 (the default, high end) or 4-5-6
    (move flag `wildLow` / lay-off flag `atLow`). From then on it **is** that card: cards are added beyond it by
    position, and only that natural card frees it. A wild in a gap has one meaning. In a set a wild stands for the
    missing suit(s).
15. [M6] Table melds are never split, rearranged or taken back; a wild moves only when it is swapped out.

**The top discard (الأرض)**
16. [T4, T5] Only the top card may be taken, and only to put it **this turn into a new meld with at least two
    cards from your hand** (`discardUse: newMeldOnly`) – never to lay it off or to swap a wild. The engine offers
    `takeDiscard` only when such a meld is possible, and you may not discard (nor lay down anything else) until
    the taken card has been melded. Before opening, that meld must be part of the opening (≥ 51) made this turn,
    or of a one-turn finish (rule 22). A joker on the pile follows the same rule. Option `any`: after opening the
    taken card may also be laid off or swapped in.

**Opening (النزول)**
17. [O1, O2] Your first lay-down in a round is one `open` move of one or more melds from your own hand (the drawn or
    taken card included) worth **at least 51** (`openingThreshold`).
18. [O4, J5] Opening values: 2–10 face value, J Q K 10, **the ace 11 everywhere, also in A-2-3** (A♠ 2♠ 3♠ = 16;
    Q♥ K♥ A♥ = 31; A♣ A♦ A♥ = 33); a wild counts as the card it stands for (5♥ 6♥ 🃏 = 18 as 7♥, 15 as 4♥). Options:
    `aceLowOpeningValue: 1` (A-2-3 = 6), `aceHighOpeningValue: 10` (an ace in a set stays 11).
19. [O3, O6] Before opening you may not lay off or swap (`notOpened`), and those never count toward 51. Right after
    opening, in the same turn, you may lay off, make more melds (any value) and swap.
20. [O8] Option `openingMustBeatPrevious`: each later opening in the round must total **more than** the highest
    opening so far (after 56, a 56 is refused and 57 accepted; `openingMustBeatPrevious` error). The bar is the
    value of the `open` move itself; melds added later in the same turn do not raise it.
21. [O9] Option `openingRequiresRun`: the opening must contain a run.
22. [O10] **One-turn finish below 51** (`oneTurnFinishWaivesThreshold`): a closed player who lays down every card
    but one in one turn and discards it needs no minimum (2-3-4 in three suits + 2-3-4-5-6♣ = 47 is legal). This is
    the atomic move `RummyMove.finish(melds, layoffs, discard)`; it ignores every opening condition. A plain `open`
    of 47 is still refused (`openingBelowThreshold`).

**Lay-offs (ترقيع) and wild swaps (تبديل الجوكر)**
23. [L1, M5] Only an opened player lays off, on **any** table meld (own, partner's, opponents'): the next card at
    either end of a run, the missing suit of a set.
24. [L3] A wild may be laid off on a meld that has none; the player picks the run end (`atLow`).
25. [S2] **A set of two naturals and a wild** (8♣ 8♥ 🃏) takes **both** missing naturals at once (8♠ and 8♦, move
    `swapJoker(card, target, card2:)`): it becomes four naturals and the wild goes to the player's hand. A single
    natural on it (making 8-8-8-🃏) is allowed only when the player will hold ≤ 2 cards after it (about to go out),
    inside a one-turn `finish`, or when another player holds exactly one card; otherwise `setNeedsBothSuits`. Option
    `setWildSwap: anyMissingSuit`: either missing suit frees the wild and a single natural may always be added.
26. [S2] **A set of three naturals and a wild**: the natural of the missing suit frees the wild (a second copy of a
    suit already there does not). **A run**: only the exact card of the wild's position frees it.
27. [S3] The freed wild goes to the hand (everyone saw it: it is public knowledge) and may stay there. Option
    `swappedWildMustBeUsed`: it must be laid down again before the discard (`mustUseFreedWild`). As soon as no
    lay-down can use it, the discard is free again; the player is never made to lay down other cards first.
28. [S5] A closed player may not swap, and a taken discard may not be used for a swap.

**Going out**
29. [G1, G2] You go out by discarding your last card; the round ends at once.
30. [H3] **ضمون**: any finish that is not a full hand.
31. [H4, G4] **هاند (full hand)**: the player had laid nothing down before this turn **and** gets rid of all their
    cards this turn **only in new melds of their own** (a lay-off on a meld made earlier in the same turn is fine;
    taking the top discard does not spoil it). A lay-off on, or a swap from, a meld that was on the table when the
    turn began makes it a ضمون (`fullHandOwnMeldsOnly`; off: any one-turn finish from a closed hand is a full hand).
32. [2.11] Every hand size is always visible, so the "one card / two cards" announcement is automatic and has no
    penalty.

**Empty stock**
33. [X1] When a player must draw and the stock is empty, all discards but the top one are shuffled into a new
    stock (`stockEnd: reshuffle`), at most `maxStockRecycles` = 2 times per round.
34. [X2] After that the round is **void**: nobody scores, it **does not count** toward the rounds
    (`voidRoundsCount: false`), and the same dealer deals again. Safety net (D): the third void in a row of the
    same round number is skipped with 0 points and counts as played.
35. [X1] Options: `voidAtPlayers` – the round is void as soon as the stock, at the end of a turn, holds no more
    cards than there are players; `flipNoShuffle` – the discards (all but the top) are turned over **without
    shuffling**, the bottom discard drawn first, as often as needed (the engine voids the round after 10
    turn-overs as a safety net).

### 3.3 Scoring and match

**One round (penalty points, lowest wins)**

| Player | ضمون | هاند |
|---|---|---|
| Went out | **−30** (`winnerScore`) | **−60** (`handWinnerScore`) |
| Opened, cards left | sum of the cards | **2 ×** sum (`handMultiplier`) |
| Never opened | **100** (`notOpenedPenalty`) | **200** |

[Pen.] Cards left: 2–10 face value, J Q K 10, ace **11** (`acePenalty`), joker **15** (`jokerPenalty`). Example:
P1 goes out; P2 has opened and holds K♠ 7♦ 🃏 = 32; P3 has opened and holds A♣ 3♥ = 14; P4 never opened = 100.
ضمون: −30, 32, 14, 100. هاند: −60, 64, 28, 200.

[§5] **Bonus options** (Gulf / Egyptian tables, off in Jordan) multiply a full hand's scores (the winner's and
everyone else's): `bonusWildLastDiscard` – the last discard is a wild, ×2 (−120, others ×4, unopened 400);
`bonusOneColour` – all non-wild cards of the finish in one colour, ×2; `bonusOneSuit` – all in one suit, ×4
(−240, ×8, 800; instead of the colour bonus). "The finish" is every card the winner put down in that turn: the new
melds, the last discard and, when `fullHandOwnMeldsOnly` is off, the cards laid on older melds. Bonuses multiply
together. `RummyRoundResult.multiplier` records it.

[H7, H9] **Match**: **5 scored rounds** (`rounds`; 7 is the other common length); void rounds do not count. The
lowest total wins; totals may be negative. Option `matchEnd: targetScore`: the match ends in the round where a
total reaches `targetScore`.

[H8] **Tie for the lowest total**: extra rounds between everyone, with the normal rules, until one player (team)
is alone lowest, at most 3 (`maxTieBreakRounds`), then a shared win. Option `tieBreak: shared`.

`RummyRoundResult`: `winner` (null: void), `handFinish`, `points` (added to the totals), `seatPoints` (each
seat's own points; decides the next dealer), `counted`, `multiplier`, `eliminated`. Events: `roundScored`
(`detail` `hand` / `void`), then `dealt` (with the indicator card, if any).

### 3.4 Partnership Hand (`partnership`, preset `handPartnership()`)

[P1–P8] Four players, partners opposite (seats 0 & 2, 1 & 3), no table talk. Each partner opens on their own
(51). Anyone may lay off on any meld, the partner's included. When a player goes out, **the winner's partner is
not counted**; the winning team scores −30 (−60 after a full hand); the other team scores the **sum** of both its
players' penalties (both doubled after a full hand: 400 if neither had opened). Both partners carry the team
total (`scores`). Option `partnerOfWinnerPays`: the partner's own penalty (not doubled) is added to the winning
team. Match length and ties as in §3.3.

### 3.5 The indicator card (ورقة الكشف), option `wildIndicator` (preset `handIndicator()`)

[§6] The usual Levantine home rule; off by default because Jordan's online tables (and pagat's own remark that
the jokers-only game plays the same) use two fixed jokers, and the indicator exists to stop players learning the
jokers' backs, which cannot happen in an app.
1. After the deal the top stock card is turned face up beside the stock for the whole round (`state.indicator`);
   it is never drawn or scored. A joker is put back in the middle of the stock and the next card turned.
2. A non-ace indicator of suit S makes the **two aces of S wild**; the two printed jokers become **natural aces
   of S**. An ace indicator leaves the printed jokers wild and all aces natural.
3. One wild per meld. A wild left in hand costs 15; a joker acting as a natural ace 11.
4. A wild ace taken from the discard pile may be used only as the natural ace of its own suit (in a set of aces
   missing that suit, or at the ace end of a run of that suit); a wild joker taken from the pile only as an ace.
5. The stock is one card smaller (76 / 62 / 48).

### 3.6 Assumptions to confirm (☐)

1. ☐ Wild cards: only the two printed jokers (default) or the indicator card? (`wildIndicator`)
2. ☐ A joker left in hand: 15 (default) or 25? (`jokerPenalty`)
3. ☐ The top discard only into a new meld with two of your own cards (default), or also to lay off? (`discardUse`)
4. ☐ Next dealer: the round's biggest loser (default) or the next player? (`dealerRule`)
5. ☐ Match: 5 rounds (default) or 7? A tie: extra rounds (default) or shared? (`rounds`, `tieBreak`)
6. ☐ Empty stock: reshuffle (default) or void? (`stockEnd`)
7. ☐ A set with a joker (8-8-🃏): both missing 8s together to free the joker (default)? (`setWildSwap`)
8. ☐ Partnership: the winner's partner pays nothing (default)? (`partnerOfWinnerPays`)
9. ☐ Gulf / Egyptian bonus doublings ever played at home? A real "Hand Saudi" to add as a preset?

---

## 4. Basra – باصرة

**As commonly played in Jordan.** Basra is the fishing game of Egypt and the Levant: play one card, take the table
cards it matches by rank or by sum, and score a *basra* for clearing the table. The core rules are the same all over
the region; what differs is the scoring. In Jordan a basra is worth **twice the card that made it** (a seven 14, a
queen or king 20), a jack taking a lone jack scores nothing, and taking the most cards is worth 3.
`const BasraOptions()` **is** the Jordanian game (also `BasraOptions.jordan()`). Code: `basra/basra_state.dart`
(options, moves, state), `basra/basra_rules.dart` (captures, scoring), `basra/basra_ai.dart` (AI).

Card names for the UI: the jack is الولد (or الشب), the 7♦ is سبعة الديناري (also called الكومي).

**Named presets** (the Arabic labels are suggestions for the games menu)

| Preset | Arabic (UI) | What changes |
|---|---|---|
| `BasraOptions()` = `BasraOptions.jordan({players, partnership, targetScore})` | باصرة (أردني) | nothing: every default below |
| `BasraOptions.palestinian44({players, partnership, targetScore})` | فلسطيني ٤٤ | no queens or kings (`deck: short44`), the 7♦ is an ordinary seven (`sevenDiamonds: normal`); four players get 5 cards a round; 3 players cannot play it |
| `BasraOptions.egyptian({players, partnership, targetScore})` | مصري | `basraValue: flat` (10), `jackBasraPoints: 20`, `majorityPoints: 30`, `majorityTie: carryOver` (43 points a deal plus basras) |

`BasraOptions.preset` tells the UI which of these a set of options is (`jordan`, `palestinian44`, `egyptian`,
`custom`; the number of players, the partnership and the target are ignored). Target chips:
`BasraOptions.targetChoices` = **101** · 121 · 151 (any number is accepted).

### 4.1 Options (`BasraOptions`)

| Option | Jordan default | Other values | Confidence |
|---|---|---|---|
| `players` | **4** | 2, 3 | high |
| `partnership` | **true** (4 players: opposite seats share one pile) | false: four individuals | high |
| `deck` (`BasraDeck`) | **`full52`** | `short44` (no Q, K) | medium (short44: Palestinian) |
| `handSize` | **null = automatic**: 4, or 5 for `short44` with 4 players | 4, 5 or 6, only when the pack splits into whole rounds: 6 with 52 cards and 2 or 4 players, 5 with 44 cards | high (4) |
| `targetScore` | **101** | 121, 151, any | high |
| `basraValue` (`BasraValueRule`) | **`twiceCard`** | `flat` | medium |
| `faceCardBasraBase` | **10** (a Q/K basra = 20) | any | medium |
| `basraPoints` (the flat value) | **10** (used only with `flat`) | any | high |
| `jackBasraPoints` (jack on a lone jack) | **0** | 10, 20 (Egypt), 30 | medium |
| `sevenDiamonds` (`BasraSevenDiamonds`) | **`sweep`** | `normal` | **low** (☐ confirm) |
| `sevenDiamondsBasraMaxSum` | **10** | any | high where the 7♦ sweeps |
| `basraOnLastCard` | **false** | true | low (☐ confirm) |
| `majorityPoints` | **3** | 30 (Egypt), any | high |
| `majorityTie` (`BasraMajorityTie`) | **`none`** | `carryOver` | medium |

`BasraOptions.configError` returns a stable id for a table that cannot be dealt, and `BasraState.newMatch` throws
an `ArgumentError` with it: `playerCount` (not 2–4), `shortDeckThreePlayers`, `handSize` (not 4, 5 or 6 cards a
round, or the pack does not split into whole rounds). An explicit `handSize` equal to the automatic one is the same
rule set (`BasraOptions(handSize: 4) == BasraOptions()`). Deal arithmetic, after the 4 table cards: 52 cards → 3
rounds of 4 (4 players), 4 rounds (3 players), 6 rounds (2 players), or 2 / 4 rounds of 6; 44 cards → 2 rounds of
**5** (4 players), 5 rounds of 4 (2 players), or 4 rounds of 5 (2 players); 44 cards cannot be shared by 3.

### 4.2 Rules

**A1. Players.** Two, three or four players. Four play as two partnerships (seats 0 & 2 against 1 & 3) sharing one
capture pile, unless `partnership` is off. Play goes to the right (`seat + 1`).

**A2. Deal.** The first dealer is the last seat, so seat 0 plays first. The dealer's right plays first; after every
deal the deal passes to the right.
1. Shuffle the 52 cards (44 with `short44`) and turn **four cards face up** on the table.
2. A **jack** turned up there goes back into the lower half of the pack and another card is turned; the same for the
   **7♦** when it sweeps (`sevenDiamonds: sweep`). So the table never starts with a jack (or a sweeping 7♦).
3. Deal `handSize` cards to each player, one at a time from the dealer's right.
4. When every hand is empty and cards remain, deal `handSize` more to each player. **No more cards go to the
   table.**

**A3. A turn.** The player plays exactly one card:
- **A numeral (A = 1 … 10)** takes every table numeral of the **same value** and every group of table numerals
  that **adds up to its value**. Groups are disjoint (a card is used once). The engine takes the family with the
  **most cards**; if several tie, the one with the most scoring cards (A, 2♣, 10♦), then the most card points. The
  player only chooses the card. A numeral never takes a Q, K or J.
- **A queen or king** takes every table card of the **same rank** (and nothing else).
- **A jack** takes **the whole table**, faces included.
- **The 7♦** with `sevenDiamonds: sweep` takes **the whole table**, like a jack. With `normal` it is an ordinary
  seven.
- A card that takes nothing, or is played to an empty table, **stays on the table** face up.
- The captured cards **and the capturing card** go to the player's side pile.

**A4. Basra (باصرة).** A capture that **clears the table** is a basra when
- the capturing card is a numeral, a queen or a king; or
- it is the sweeping 7♦ and every card it took was a numeral, adding up to at most `sevenDiamondsBasraMaxSum` (10);
  or
- it is a jack taking a **lone jack** and `jackBasraPoints` > 0 (0 in Jordan: never a basra).

Any other jack sweep (or 7♦ sweep) is not a basra. A basra is scored **at once** (a running tally), also on the
very first play of a deal, **except** a basra made with the **very last card of the deal**, which does not count
(`basraOnLastCard: false`).

**A5. Basra value** (`basraValue`).

| Capturing card | A | 2 | 3 | 4 | 5 | 6 | 7 (the 7♦ too) | 8 | 9 | 10 | Q | K | J on a lone J |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| Jordan (`twiceCard`) | 2 | 4 | 6 | 8 | 10 | 12 | 14 | 16 | 18 | 20 | 20 | 20 | 0 |
| Egypt (`flat`) | 10 | 10 | 10 | 10 | 10 | 10 | 10 | 10 | 10 | 10 | 10 | 10 | 20 |

Twice the card: A = 1, 2–10 their face value, Q and K = `faceCardBasraBase` (10), the 7♦ = 7. The jack value
(`jackBasraPoints`) is never doubled.

**A6. End of a deal.** After the last card, any cards left on the table go to the side that **captured last** (to
the dealer's side if nobody captured). This is never a basra. The deal is scored, and if the match goes on the next
dealer deals.

**A7. Scoring each deal.**

| Item | Points |
|---|---|
| Most cards (a single side with the most only) | **3** (`majorityPoints`) |
| Each jack | 1 |
| Each ace | 1 |
| 2♣ | 2 |
| 10♦ | 3 |
| Each basra | A5 |

That is 16 card points a deal (13 when the most cards are tied). On a tie for most cards nobody scores them
(`majorityTie: none`); with `carryOver` (Egypt) they are added to the next deal's most-cards points, and keep adding
up until a deal has a clear winner (the carried amount is saved as `BasraState.majorityCarry`). There is no "most
clubs" point and scores never go down. `BasraDealResult` holds each deal's points, cards taken, basras, the side
with the most cards (`majoritySide`), what it scored (`majorityAwarded`) and the amount carried on (`carry`).

**A8. Match.** The first side to reach **101** (`targetScore`) at the end of a deal wins. If several sides are over
it, the highest total wins; if the leaders are **equal** at or above the target, another deal is played.

**Worked example (a Jordanian deal).** Side A takes 28 cards with 3 jacks, 2 aces and the 2♣ and makes a 7 on a
lone 7 (14) and a 9 taking 4 + 5 (18). Side B takes 24 cards with 1 jack, 2 aces and the 10♦ and makes a queen on a
lone queen (20). A = 3 + 3 + 2 + 2 + 14 + 18 = **42**; B = 1 + 2 + 3 + 20 = **26**.

### 4.3 Assumptions to confirm (☐)

1. ☐ A basra is worth **twice the card** (Jordan), not a flat 10 (Egypt and most apps): `basraValue`.
2. ☐ The deck has queens and kings (52): `deck`.
3. ☐ The **7♦ sweeps** the table (the least certain Jordanian rule): `sevenDiamonds`.
4. ☐ A jack on a lone jack scores **nothing**: `jackBasraPoints`.
5. ☐ The match is to **101** (151 is also played): `targetScore`.
6. ☐ No basra with the last card of the deal: `basraOnLastCard`.
7. Captures are automatic and maximal (the most cards, then the most scoring cards); the player never chooses
   between two ways of capturing.
8. Leftover table cards go to the side that captured last (to the dealer's side if nobody did).
9. Jacks (and the sweeping 7♦) never start on the table: they are put back into the lower half of the pack.
10. A save made before these defaults (no `basraValue` key) keeps its flat basra value, so an old match finishes
    under the rules it started with.

---

## 5. Baloot – بلوت

**As commonly played in Jordan.** Baloot came to Jordan from Saudi Arabia and the Gulf, and Jordanian players use
the **Saudi rules**, as played in tournaments and on the Gulf apps. There is no separate Jordanian variant. Where
Saudi sources disagree the default follows the Saudi tournament rules; other behaviours reported for apps are
options. `const BalootOptions()` **is** this game (also `BalootOptions.jordan({targetScore})`). Code:
`baloot/baloot_state.dart` (options, moves, state), `baloot/baloot_rules.dart` (auction, play, scoring),
`baloot/baloot_ai.dart` (AI).

Words for the UI: صن (Sun, no trumps), حكم (Hokom, trumps), أشكل (Ashkal), بس (pass), دبل / ثري / فور / قهوة
(double / triple / four / gahwa), مقفول / مفتوح (locked / open), سرا / خمسين / مية / أربعمية (projects), بلوت
(belote), كبوت (kaboot), إكّه (Ekka), كوش (Kawesh), الصكة (the match to 152).

### 5.1 Options (`BalootOptions`)

| Option | Jordan default | Other values | Confidence |
|---|---|---|---|
| `targetScore` | **152** | any | high |
| `firstDealer` | **3** (seat 0 speaks and leads first) | 0–3 | UX choice |
| `firstLead` (`BalootFirstLead`) | **`dealerRight`** (always the dealer's right) | `taker` (reported app behaviour) | high |
| `sunPriority` | **true** | false: the first Sun wins | medium-high |
| `ashkal` | **true** | false | high |
| `ashkalOnAce` | **false** (no Ashkal on an up-turned Ace) | true | low-medium |
| `ashkalInRound2` | **false** | true (Riyadh) | high |
| `takerMaySwitchToSun` | **true** | false | medium-low |
| `kawesh` | **false** | true | variant |
| `aceThirdRound` | **false** | true | variant |
| `doubling` | **true** | false | high |
| `sunDoubleRule` (`BalootSunDoubleRule`) | **`takersOver100DoublersUnder100`** | `oneOver100OneUnder`, `always`, `never` | medium |
| `voidMustTrump` | **true** | false: a void player may always play any card | medium |
| `mustOvertrump` | **true** | false: any trump will do (house rule) | high |
| `trumpLedOvertrump` (`BalootTrumpLedOvertrump`) | **`againstOpponent`** | `always` | medium |
| `partnerWinningVoid` (`BalootPartnerWinningVoid`) | **`saudi`** | `alwaysTrump`, `free` | medium (☐ confirm) |
| `declareProjects` (`BalootDeclareProjects`) | **`auto`** | `manual` | app choice |
| `sequenceBeatsCarre` | **false** (four of a kind beats a sequence) | true | medium |
| `trumpSequencePriority` | **false** | true | variant |
| `beloteOnLoss` (`BalootBeloteOnLoss`) | **`toWinner`** | `keptByHolder`, `voided` | medium (☐ confirm) |
| `projectMultiplierCap` | **2** (projects doubled at most) | null = × the level | medium (☐ confirm) |

Older names still accepted by the constructor and by `fromJson`: `mustTrumpWhenPartnerWinning` (true →
`partnerWinningVoid: alwaysTrump`, false → `free`) and `sunDoubleOnlyWhenBehind` (true →
`takersOver100DoublersUnder100`, false → `always`); `buyerWinsTies` in an old save is ignored. Missing keys take the
defaults above.

### 5.2 Cards and deal

**B1. Players and cards.** Four players in two partnerships (seats 0 & 2 against 1 & 3); 32 cards (7 to A). Play
goes to the right (`seat + 1`). The speakers are called P1 = the dealer's right (`firstPlayer`), P2 = the dealer's
partner, P3 = the dealer's left, P4 = the dealer (`speakerIndex`).

**B2. Card order and points.**

| | Order (high → low) | Points |
|---|---|---|
| Sun, and side suits in Hokom | A 10 K Q J 9 8 7 | A 11, 10 10, K 4, Q 3, J 2 |
| Trumps (Hokom) | J 9 A 10 K Q 8 7 | J 20, 9 14, A 11, 10 10, K 4, Q 3 |

The last trick is worth 10 more. Total: **130** in Sun, **162** in Hokom.

**B3. Deal.** Five cards each (the engine deals them in one go; the table order of 3 + 2 does not change anything);
the 21st card is turned face up (الورقة المكشوفة, `upCard`; it stays public as `turnedUp`); eleven cards are kept
back. After the auction the **taker** (المشتري, `buyer`) takes the up card plus 2, everyone else 3, dealt from P1:
eight cards each.

### 5.3 Auction (الشراء)

**Round 1** – the up card's suit is the only Hokom suit.
1. *Pass-through* (`bidStage: open`). P1, P2, P3, P4 speak once each, in order:
   - nobody has bid yet → **pass (بس)**, **Hokom (حكم)** in the up card's suit, **Sun (صن)**, or **Ashkal (أشكل)** –
     only P3 and P4, only while every earlier speaker has passed, and not when the up card is an Ace (unless
     `ashkalOnAce`);
   - a Hokom stands → pass or Sun (only one Hokom per round, no Ashkal);
   - a Sun or Ashkal → the pass-through stops.
2. *Priority* (`bidStage: priority`), each asked "Sun or pass", earliest first; the first Sun wins and ends the
   auction:
   - after a Sun or Ashkal by P*j* (with `sunPriority`): P1 … P*j*−1, even those who passed or bid the Hokom;
   - after only a Hokom by P*h*: P1 … P*h*−1 (the later speakers already had their chance). This step happens
     with or without `sunPriority`.
   With `sunPriority` off a Sun ends the auction at once.
3. *Confirmation* (`bidStage: confirm`, with `takerMaySwitchToSun`): when a Hokom stands, its bidder **confirms** it
   (`BalootMove.confirm`) or **switches to Sun** (`BalootMove.sun`) – same taker, no new priority round.
4. Nobody bid → round 2.

**Ashkal** is a Sun in which the caller's **partner** is the taker and takes the up card (`bidder` = the caller,
`buyer` = the partner, `ashkal` = true). It ranks as a Sun. After P3's Ashkal, P1 (the partner) or P2 may still take
it as their own Sun in the priority step.

**Round 2** – every player passed in round 1.
1. P1 … P4 in order: pass, **Hokom in one of the three other suits** (the suit is part of the bid), or **Sun**. No
   Ashkal (unless `ashkalInRound2`, under the round-1 conditions).
2. A Sun (or Ashkal) **ends the auction at once**.
3. After a Hokom by P*h* only the **later** speakers (P*h*+1 … P4) may still say Sun; a player who has passed in
   round 2 cannot come back.
4. A Hokom that stands → the confirmation step.
5. All pass → the cards are thrown in, no score, and the **next dealer** deals (`redeal` event). There is no limit
   on redeals.

**Options.** `aceThirdRound`: when everybody passed twice and the up card is an Ace, P1 alone gets a third round and
may pass (redeal), bid Sun, or bid Hokom in any suit (no confirmation step). `kawesh` (كوش): in round 1, at their
turn in the pass-through, a player whose five cards are all 7s, 8s and 9s may annul the deal
(`BalootMove.kawesh`): no score, the next dealer deals.

### 5.4 Doubling (الدبل) and locked play

After the deal is complete and before the first card (`phase: doubling`):
- **Hokom.** The defenders are asked in order, the one after the taker first. Either may **Double** (×2) and says
  **locked** or **open** (`BalootMove.raise(locked: true / false)`). Then the **taker** may **Triple** (×3, always
  open), the **same doubler** may **Four** (×4, locked or open), and the **taker** may call **Gahwa** (قهوة, open):
  whoever wins that deal wins the match. Declining any step (pass) ends the ladder.
- **Sun / Ashkal.** A Double only (never locked, nothing after it), and only when, before this deal, the takers have
  **more than 100** and the defenders **less than 100** (`sunDoubleRule`). A Hokom switched to Sun follows this
  rule.
- **Locked play (مقفول, `locked`).** Nobody may **lead** a trump unless every card in their hand is a trump
  (`lockedTrumpLead`). Following to a trump lead is unchanged. The last call decides: after a Triple or a Gahwa play
  is open.
- `lastRaiserTeam`: the team that made the last call (Double / Four → the defenders, Triple / Gahwa → the takers).

### 5.5 Play: which cards may be played

The dealer's right (P1) leads the first trick, whoever bought (`firstLead: taker` for the taker). The winner of a
trick leads the next. Notation: L = the suit led, W = the player winning the trick so far.

| Situation | Cards you may play |
|---|---|
| Leading | any card; **locked**: no trump unless the hand is all trumps |
| You hold L, L is a side suit | any card of L (no need to beat) |
| You hold L, L is trumps, an **opponent** is winning | a higher trump than the best one played if you have one, else any trump |
| You hold L, L is trumps, your **partner** is winning | any trump (`trumpLedOvertrump: always` → must beat) |
| Void in L, Sun | any card |
| Void in L, Hokom, no trump | any card |
| Void in L, Hokom, an opponent is winning with a side card | any trump |
| Void in L, Hokom, an opponent is winning with a trump | a higher trump if you have one, **otherwise any card** (a lower trump is allowed, not required) |
| Void in L, Hokom, your partner is winning and you play **4th** | any card |
| Void in L, Hokom, your partner **led** and is winning, you play **3rd** | any card if the lead was an **Ace** or an **Ekka**; otherwise any trump |

**Ekka (إكّه).** In Hokom, a side-suit lead that is the **highest card of its suit not yet played** in an earlier
trick (an Ace always is). The engine recognises it automatically from the played cards (public information) and
marks the lead's `cardPlayed` event with `detail: 'ekka'`. Example: trumps ♥; the leader plays ♣K while the ♣10 is
still out – no Ekka – so the leader's partner, void in clubs, must trump even though the leader is winning.

Options: `partnerWinningVoid: alwaysTrump` – must trump (and over-trump) even when the partner is winning;
`free` – any card when the partner is winning; `voidMustTrump: false` – a void player may always play any card;
`mustOvertrump: false` – any trump will do. Error ids: `mustFollowSuit`, `mustTrump`, `mustOvertrump`,
`lockedTrumpLead`, `cardNotInHand`, `declareProjectsFirst`.

A player who cannot beat an opponent's trump is never forced to under-trump (the European rule is not played).

### 5.6 Projects (المشاريع) and belote (بلوت)

| Project | Cards | Sun | Hokom |
|---|---|---|---|
| Sira (سرا) | 3 in sequence, same suit | 4 | 2 |
| Fifty (خمسين) | 4 in sequence | 10 | 5 |
| Hundred (مية) | 5 in sequence, or four 10s / Js / Qs / Ks (four Aces in Hokom) | 20 | 10 |
| Four hundred (أربعمية) | four Aces, Sun only | 40 | – |

- Sequences use the natural order 7 8 9 10 J Q K A (A-K-Q is a sira, A-10-K is not). Four 9s, 8s or 7s are
  worth nothing. A card belongs to one project only, so a hand has at most two projects; the best set is taken (the
  highest total, then the strongest single project).
- **Declaring.** `declareProjects: auto` – every player's best set is declared when play starts. Only the types
  and the points are public at once (a `projectsDeclared` event per player with `detail` = the types, e.g.
  `hundred` or `fifty,sira`, `value` = the points, and no cards); the cards are shown when the first trick is
  complete (`projectsRevealed`; a `projectsDeclared` event per player with `detail: 'shown'` and the cards).
  `manual` – a player holding a project chooses, before their first card, to declare all of it
  (`BalootMove.declareProjects`, the same types-and-points event) or none (`BalootMove.skipProjects`); undeclared
  projects never score. The best set follows the comparison options (with `sequenceBeatsCarre` a player holding
  four queens and 10-J-Q-K-A declares the sequence).
- **Only one team scores projects**: the owner of the single best project scores **all** its team's projects; the
  other team's are cancelled. Best = higher value; among hundreds **four of a kind beats a five-card sequence**
  (`sequenceBeatsCarre` reverses it); then the higher top card (A K Q J 10 9 8 7); with `trumpSequencePriority`
  (Hokom) a trump sequence beats an equal side-suit one; then the player nearer P1.
- **Belote**: in Hokom only, the K and Q of trumps held in one hand when play starts (`belote` = that seat) are worth
  **2**, announced when the second of them is played (`belote` event). It is not a project (it does not take part in
  the comparison) and is **never multiplied**. It is **void** (event value 0, `detail: 'void'`) when the holder's
  team scores its projects and the holder's own **hundred** contains the trump K or the trump Q (four kings, four
  queens, or a trump sequence through the K or Q). Inside a sira or a fifty it counts **as well**.

### 5.7 Scoring a deal

Definitions: raw = card points of a team, the last trick included (162 / 130 in all); base = 16 (Hokom) / 26
(Sun); level = 1, 2, 3 or 4 (Gahwa: the figures of level 1).

1. **Kaboot (كبوت)** – one team took all eight tricks: it scores **25** (Hokom) / **44** (Sun) × level, plus its
   **own** counted projects × min(level, 2), plus its belote. The other team scores **0**; its projects and belote
   are void.
2. **Counting team** (`countingTeam`): with no double, the **defenders**; in a doubled deal, the opponents of the
   last raiser (Double or Four last → the taker's team counts; Triple or Gahwa last → the defenders count).
3. **Conversion** (`BalootRules.gamePoints`), for the counting team only:
   - Hokom: to the nearest ten, **a 5 rounding down**, ÷ 10 (56–65 → 6, 66–75 → 7 …);
   - Sun: to the nearest ten, **except that a total ending in 5 is kept**, ÷ 5 (56–64 → 12, 65 → 13, 66–74 → 14 …).
   The other team gets base minus that, so the two always add up to exactly 16 / 26.
4. **Totals** = game points + counted projects + counted belote.
5. **Winner** = the higher total. On a tie, the team that **lost more card points to rounding** (raw − game points
   × 10 / × 5) wins; if both lost the same, the **taker's team** wins.
6. **Points** (`BalootRules.scoreFigures`):
   - no double and the taker's team won → each team scores its own total;
   - otherwise (the taker lost, or any doubled deal) → the winner scores base × level + **all** counted projects ×
     min(level, `projectMultiplierCap`) + **every** counted belote (`beloteOnLoss: toWinner`); the loser scores 0.
     `keptByHolder`: each belote stays with its team; `voided`: a loser's belote is lost.

| Level | Hokom cards | Sun cards | Projects | Belote | Kaboot Hokom / Sun |
|---|---|---|---|---|---|
| 1 (the taker lost) | 16 | 26 | × 1 | 2 each, to the winner | 25 / 44 |
| Double | 32 | 52 | × 2 | 2 each | 50 / 88 |
| Triple | 48 | – | × 2 | 2 | 75 / – |
| Four | 64 | – | × 2 | 2 | 100 / – |
| Gahwa | the match | – | – | – | the match |

Each deal's `BalootRoundResult` holds the taker (`buyer`), the bidder, whether it was an Ashkal, mode, trump, raw
points, the counting team, card game points, counted projects and belote per team, the level (5 = gahwa), locked,
the kaboot team, the winner and the points scored.

**Worked examples** (all in the tests; A = the taker's team, B = the defenders):

| Deal | A / B |
|---|---|
| Hokom, A 105 / B 57: B counts 57 → 6, A 10 | 10 / 6 |
| Hokom, A 96 / B 66: B counts 66 → 7, A 9 | 9 / 7 |
| Hokom 81 / 81, A holds the belote: 8 vs 8 + 2 | 10 / 8 |
| Hokom, A 70 / B 92, A holds the belote: 9 each; B lost 2 to rounding, A 0 → B wins | 0 / 18 |
| Sun, A 73 / B 57: B counts 57 → 12, A 14 | 14 / 12 |
| Sun, A 66 / B 64 with a fifty: 12 + 10 vs 14 → A fails | 0 / 36 |
| Sun 65 / 65: 13 each, no rounding → the taker | 13 / 13 |
| Hokom doubled by B, A 76 / B 86, A a sira: A counts 76 → 8, B 8; 10 > 8 | 36 / 0 |
| Hokom tripled, A 76 / B 86, A the belote: B counts 86 → 9; A 7 + 2; A lost more to rounding | 50 / 0 |
| Hokom kaboot by A with a fifty and the belote | 32 / 0 |
| Sun kaboot by B; A's fifty had beaten B's sira | 0 / 44 |
| Hokom at Four by B, A 60 / B 102, B a fifty: A counts 60 → 6; B 10 + 5 | 0 / 74 |

### 5.8 Match

The first team to reach **152** (`targetScore`) after a deal wins; if both are over it the higher total wins; if they
are **exactly equal**, another deal is played. A **Gahwa** ends the match at once: the winner of that deal wins
(`results.last.level == 5`).

### 5.9 Assumptions to confirm (☐)

1. ☐ When the taker fails (or in any doubled deal) **the winners score every belote**, the taker's too
   (`beloteOnLoss`).
2. ☐ In a tripled or "four" deal projects are **doubled**, not tripled / quadrupled (`projectMultiplierCap`).
3. ☐ Void in the led suit with the partner winning: the Saudi rule (4th player free; 3rd player free after an Ace or
   an Ekka; otherwise must trump) (`partnerWinningVoid`).
4. ☐ The Hokom taker may switch to Sun when nobody overcalls (`takerMaySwitchToSun`).
5. ☐ The dealer's right leads the first trick, not the taker (`firstLead`).
6. ☐ Among hundreds four of a kind beats a sequence; no trump-sequence priority.
7. Ekka is recognised automatically (no separate "Ekka" call); the Ekka test uses only cards played in earlier
   tricks.
8. Projects are declared automatically (all of the best set) by default; with `manual` a player declares all or
   none – declaring one project and keeping another, or a partner showing an undeclared project at the second
   trick, is not modelled.
9. A belote is void inside the holder's own scored hundred whenever that hundred contains the trump K **or** Q (four
   kings, four queens, or a trump sequence through the K or the Q).
10. Kawesh may be called at the player's turn in the round-1 pass-through, whatever has been bid before; the Ace
    third round lets P1 bid Hokom in any suit or Sun.
11. The claim (سوا) and best-of-three matches are UI features, not rules.

---

## 6. Konkan – كونكان

**As commonly played in Jordan (low confidence).** Konkan is played on **the Hand engine with the corrected
Jordanian core** (§3.2: 106 cards, 14 / 15, the starter only discards first, nobody goes out on their first turn,
51 to open with the ace 11, one wild per meld, the top discard only into a new meld, both missing suits free a set's
wild, full hand only with one's own melds, reshuffle twice then void, pairs redeal, loser deals). Many Levantine
players use "Konkan" as another name for Hand; where a table treats it as its own game, these are the differences.
`const RummyOptions.konkan()` is the default; code `konkan/konkan.dart` (`KonkanEngine`, `KonkanAi`).

**Preset**: `RummyOptions.konkan({players, matchEnd = elimination, eliminationScore = 301, targetScore = 500,
rounds = 5, openingThreshold = 51, openingMustUseDiscard = false})` – Arabic label (UI): كونكان. There is no
partnership Konkan (`partnership` with `elimination` is refused by `invalidReason`).

| | Hand (§3) | Konkan |
|---|---|---|
| Going out (ضمون) | −30 | **0** (`winnerScore`) [K3] |
| One-turn finish from a closed hand (كونكان) | −60, others ×2 | **0, others ×2** (`handWinnerScore`, `handMultiplier`) [K4] |
| Joker left in hand | 15 | **25** (`jokerPenalty`) |
| Never opened | 100 (200) | 100 (200) [K5] |
| Match | 5 rounds | **elimination over 301** (`matchEnd: elimination`, `eliminationScore`) [K6] |

**Match: elimination (default)** [K6, K9]
1. After each scored round, every player still in whose total is **over 301** (302 or more) is **eliminated**
   (`state.eliminated`, event `playerFinished` with `detail: eliminated`). 301 stays in.
2. The others play on: only the players still in are dealt; turns and the deal skip eliminated seats; with
   `loserDeals` the deal goes to the highest scorer of the round among the players still in.
3. The **last player left wins**. With 2 players this is "the first over 301 loses".
4. If everyone still in crosses in the same round (only possible with a positive `winnerScore`), the lowest total
   among them wins; an exact tie is shared.
5. Void rounds eliminate nobody and do not count. Since the winner of a round scores 0 and everyone else pays at
   least 2, totals only go up and the match always ends.

Example (3 players): totals A 250, B 290, C 120. C goes out; A pays 60 → 310, out; B pays 10 → 300, stays. B and C
play on.

**Options** [K7, K8]: `eliminationScore: 101` (`RummyOptions.eliminationChoices` = **301** · 101);
`matchEnd: targetScore` (500, the lowest total wins when someone reaches it – the old default); `matchEnd: rounds`.
`openingMustUseDiscard` (the Yemeni rule: a closed player may open only in a turn where they took the top discard
and use it in the opening; a one-turn finish is exempt). Every Hand option (§3.1) also applies.

### 6.1 Assumptions to confirm (☐)

1. ☐ Konkan at home: a game of its own, or another name for Hand?
2. ☐ How does it end: over 301 is out (default), 101, to 500, or a number of rounds?
3. ☐ Does the winner of a round get anything (default 0), and does a one-turn "كونكان" double the others (default
   yes)?
4. ☐ A joker left in hand: 25 (default, a Middle-Eastern description) or 50 (the Yemeni one)?

---

## 7. Solitaire – سوليتير (Klondike, كلوندايك)

**As commonly played in Jordan.** No Jordanian rule set of Klondike exists: nothing in any Arabic source reached
describes a local variant, and people in Jordan meet the game on phones and on Windows. So the Jordanian default is
**the standard international Klondike as a Jordanian meets it on a phone**, with no money scoring (the old "Vegas"
mode is a buy-in and is not offered). `const SolitaireOptions()` **is** that game (also `SolitaireOptions.jordan()`).
It is a one-player patience game: it does **not** join `CardGameId` and has no `CardGameEngine`; it has the same
shape as the puzzles' `PuzzleBase` (apply, undo with 1000 snapshots, hint, isSolved, toJson) without depending on
the puzzle registry.

Code: `solitaire/solitaire_options.dart` (options, presets), `solitaire/solitaire_board.dart` (piles, actions, the
compact board holding every rule), `solitaire/solitaire_game.dart` (`SolitaireGame`: score, clock, undo, hint,
stuck, JSON), `solitaire/solitaire_ai.dart` (three-level auto-player, hint techniques),
`solitaire/solitaire_solver.dart` (exact stuck search, solver, winnable deals), `solitaire/solitaire_seeds.dart`
(bundled proven deals), `solitaire/solitaire_stats.dart` (statistics).

Suggested UI words (DES unless marked): سوليتير (subtitle كلوندايك; four Arabic localisations use سوليتير) ·
stock الرزمة · waste المكشوفة · columns الأعمدة · foundations الأساسات · draw one / three سحب ورقة / سحب ٣ أوراق
(never "التعادل") · recycle إعادة الرزمة · undo تراجع · hint تلميح · auto-complete إكمال تلقائي · winnable deal
توزيعة قابلة للحل · deal number رقم التوزيعة.

**Presets** (three levels, plus two)

| Preset | Arabic (UI suggestion) | What changes from the default |
|---|---|---|
| `SolitaireOptions()` = `SolitaireOptions.jordan()` ("Medium") | سوليتير | nothing |
| `SolitaireOptions.easy()` | سهل | `winnableOnly: true`, `autoCompleteWithStock: true` |
| `SolitaireOptions.hard()` | صعب | `drawCount: 3` |
| `SolitaireOptions.expert()` | خبير | `drawCount: 3`, `passLimit: 3` |
| `SolitaireOptions.windowsClassic()` | كلاسيكي | `drawCount: 3`, `timedScoring: true`, `autoMoveToFoundation: off` (the old desktop defaults) |

### 7.1 Options (`SolitaireOptions`)

| Option | Jordan default | Other values | Rule | Confidence |
|---|---|---|---|---|
| `drawCount` | **1** | 3 | S-20, S-21 | high (the rule), medium (default) |
| `passLimit` | **null** (unlimited) | 3, 1 (limit *n* = *n* − 1 recycles) | S-23 | high |
| `scoring` (`SolitaireScoring`) | **`standard`** | `none` | S-40, S-50 | high |
| `draw3PenaltyFromRecycle` | **3** | 1 (every recycle), 4 (Windows CE / ReactOS reading) | S-40g | medium |
| `timedScoring` | **false** (the clock is always shown) | true | S-45…S-47 | high (values), low (default) |
| `allowFoundationToTableau` | **true** | false | S-16 | high |
| `autoFlip` | **true** | false (the player turns cards with `flip`) | S-14 | high |
| `autoMoveToFoundation` (`SolitaireAutoMove`) | **`safeOnly`** | `off`, `always` | S-33 | low (design) |
| `autoCompleteWithStock` | **false** | true | S-32 | low (design) |
| `winnableOnly` | **false** | true | S-61 | low (design) |
| `solverHints` | **false** | true | S-37 | low (design) |
| `undoPenalty` | **0** | 2, 5 (any int ≥ 0) | S-35 | low (design) |
| `hintLevel` (`AiLevel`) | **`hard`** | `easy`, `medium` | S-36, S-75 | low (design) |

Not offered on purpose: Vegas scoring and a cumulative score across deals (both are wager mechanics).

### 7.2 The deal (S-1…S-5)

- **S-1** One 52-card pack, no jokers. Solitaire rank: A = 1 … K = 13 (`solitaireRank`); hearts and diamonds red
  (`isRedCard`). The shared `Rank.value` (ace 14) is not used.
- **S-2/S-3** Seven columns; column *i* (1–7) gets *i* cards, the last one face up. The other 24 cards are the
  face-down stock. Waste and the four foundations start empty.
- **S-4** Deal number `seed`: the pack is shuffled with `CardRng(seed)` (Fisher–Yates) and dealt **in rows**: row
  *r* gives one card to each column *r*…7, left to right; the card that lands on column *r* in row *r* is face up.
  The next card is the **top** of the stock. `SolitaireBoard.forSeed(seed)` / `SolitaireGame.newDeal(seed:)`.
- **S-5** Any ace starts any empty foundation. A tap-to-send (`SolitaireGame.sendHomeAction`) uses the leftmost
  empty place; dragging to another empty place is also legal.

### 7.3 Moves (S-10…S-17)

Actions (`SolitaireAction`): `draw`, `recycle`, `move(from, to, count)`, `flip(column)`, `autoComplete`. Piles
(`SolitairePile`): `waste`, `column(0–6)`, `foundation(0–3)`.
- **S-10** To a foundation: one card only (top of the waste or the last card of a column, never from another
  foundation). An empty place takes an ace; otherwise the same suit, one rank higher.
- **S-11/S-12** To a column: any run whose head is a **face-up** card (with everything below it), or the top waste
  card, or the top foundation card. The head must be one rank lower and of the other colour than the column's last
  card, which must be face up. Not onto its own column.
- **S-13** An empty column takes only a king (or a king-headed run), from anywhere.
- **S-14** A face-down card left at the end of a column turns up by itself (+5). With `autoFlip: false` it stays
  down until the player plays `flip(column)` (also +5); nothing can be placed on it meanwhile.
- **S-15** Only the top waste card plays. **S-16** Foundation → column: the top card only, onto an accepting column
  (`allowFoundationToTableau`). **S-17** Nothing returns to the stock or waste except by recycling.

Error ids (`SolitaireGame.validate`): `gameWon`, `stockEmpty`, `stockNotEmpty`, `wasteEmpty`, `noPassesLeft`,
`nothingToTurn`, `cannotAutoComplete`, `onlyTopWasteCard`, `emptyPile`, `faceDownCard`, `sameColumn`,
`foundationLocked`, `oneCardHome`, `doesNotFitFoundation`, `onlyKingOnEmpty`, `doesNotFitColumn`, `illegalMove`.

### 7.4 Stock, waste and passes (S-20…S-24)

- **S-20** Draw one: the top stock card goes face up onto the waste.
- **S-21** Draw three: the top three go over one at a time, the third ends on top; fewer when fewer remain. Only the
  top waste card plays; when it leaves, the one under it plays next. The UI fans the top three.
- **S-22** Recycle: with the stock empty, a tap turns the whole waste over, unshuffled (the first card that reached
  the waste is the new top). Stock and waste both empty: the tap does nothing (`tapStock()` returns false).
- **S-23** `passLimit`: unlimited, 3 or 1 passes (2 or 0 recycles).
- **S-24** No Vegas scoring (a buy-in and pay-per-card wager).

### 7.5 Winning, stuck, auto-complete, auto-move (S-30…S-33)

- **S-30** Won when all 52 cards are home; undo is then disabled.
- **S-31** `isStuck` is **exact**: a breadth-first search over every legal action (draws, recycles within the pass
  limit, every move including foundation → column), keyed on the whole position (column order ignored; recycles
  only when a pass limit makes them matter). Progress = more cards home than now, or a face-down card turned up; the
  search stops there, so it never looks past a face-down card. No reachable progress → stuck. More than 20 000
  positions → **not** stuck (unknown is never shown as stuck). With a pass limit it is false while some stock card
  is still unseen. Advisory only: the UI offers undo or a new deal.
- **S-32** Auto-complete (`canAutoComplete`, action `autoComplete`) is offered when no face-down card is left in the
  tableau **and** the stock and waste are empty; the win is then certain. It sends home the lowest-ranked playable
  card each step (ties: leftmost column), scoring normally. With `autoCompleteWithStock` (Easy preset) and **draw one
  with unlimited passes** it is also offered with cards left in the stock or waste: each step plays the waste card
  if it can go home, else the lowest column card that can, else draws, else recycles (−100 as usual).
- **S-33** `autoMoveToFoundation`: after every action the engine sends home, repeatedly, any exposed column card
  and, **in draw one only**, the top waste card that is **safe**: an ace or a two, or a card whose two other-colour
  foundations have reached rank − 1. `always` sends every card that fits (it can spoil a deal), still never the
  waste card in draw three; `off` sends none. Nothing moves by itself before the first action of a deal. Auto-moves
  score like manual ones (event `autoMoved`).

### 7.6 Undo, hints and the auto-player (S-35…S-37, S-75)

- **S-35** Unlimited undo (the last 1000 snapshots). It restores the cards, recycles, cards home and the move count,
  and the score **except** time deductions: score = max(0, snapshot score − 2 × deductions made since). The clock is
  never rewound. `undoPenalty` points are taken off per undo (floor 0).
- **S-36** `hint()` = the auto-player's choice at `hintLevel` (hard) with a technique id (`SolitaireTechnique`):
  `toFoundation`, `revealCard`, `emptyColumn`, `fromWaste`, `drawStock`, `recycle`, `noMoves`.
- **S-36a** What may be used: face-up cards, the foundations, the waste, and the **order of the stock only after the
  first recycle**. Never a face-down column card. Every level decides on `SolitaireBoard.masked()`, a copy in which
  those cards are unknown, so no level can peek.
- **S-37** `solverHints` in winnable-deal mode: while the solver still proves the position winnable, the hint is the
  first step of its plan (`SolitaireHint.fromSolver`, which the UI labels). The solver runs synchronously (up to
  `solverBudget` nodes, 50 000 by default); call it from an isolate.
- **S-75** Auto-player (`SolitaireAutoPlayer.choose`, for hints, a "watch" demo and the tests):
  - **easy** – a random productive move (a card home, a card turned up, the waste card played, or a column emptied
    while a king waits); otherwise draw or recycle; otherwise stop.
  - **medium** – the priority list: (1) a safe card home, (2) a move that turns a card up (the column with most
    face-down cards first), (3) empty a column when a king waits, (4) any other card home, (5) waste to column,
    (6) draw or recycle, (7) stop.
  - **hard** – the same candidates, chosen by a lookahead of up to 3 actions that counts cards turned up and cards
    home (a turned-up or unseen drawn card ends the lookahead); ties keep medium's order.
  - All levels draw or recycle only when it can help: some stock card is still unseen, or a card the stock will
    show can be played now. "Will show" means the rest of this pass and, when a recycle is left, the whole next
    pass: in draw three a recycle regroups the triples, so the next pass can bring up cards this pass skips. This
    shared stop rule keeps the easy level from cycling for ever.
  - Measured (200 draw-one deals, the same seeds): easy wins 57, medium 71, hard 75.

### 7.7 Scoring (S-40…S-50)

**Standard (`scoring: standard`).** Each event in order; the score is clamped at 0 after each one (**S-41**).

| Rule | Event | Points |
|---|---|---|
| S-40a | waste → column | +5 |
| S-40b | waste → foundation | +10 |
| S-40c | column → foundation | +10 |
| S-40d | a face-down column card turns up | +5 |
| S-40e | foundation → column | −15 |
| S-40f | recycle, draw one | −100 every recycle |
| S-40g | recycle, draw three | −20 from recycle number `draw3PenaltyFromRecycle` (default 3) on |
| S-40h | column → column, a draw, undo | 0 |

- **S-42** waste → column → foundation earns 15; foundation → column → foundation nets −5.
- **S-43** Untimed, the score always stays within 0…745 (52 × 10 + 21 × 5 + 24 × 5); tested with random play.
- **S-45** Clock (`advanceClock(duration)`, called by the UI): starts at the first action, the UI stops calling while
  the app is in the background or paused, stops at the win.
- **S-46** Timed (`timedScoring`): −2 each time the play time reaches a multiple of 10 s (floor 0).
- **S-47** At the win, with *t* whole seconds: if *t* ≥ 30, + ⌊700 000 / *t*⌋ (event `timeBonus`); otherwise
  nothing. **S-48** Example: 520 move points, won at 150 s → 520 − 30 + 4 666 = **5 156**.
- **S-49** Cards home 0–52, always tracked. **S-50** `scoring: none` hides the score (`displayScore` is null).

### 7.8 Winnable deals – توزيعات قابلة للحل (S-60…S-64)

- **S-60** (help text only) With every card known, about 90.5 % of draw-one and 81.9 % of draw-three deals can be
  won (CP 2025, refining Blake & Gent). Play with hidden cards wins far less.
- **S-61** `winnableOnly`: a deal is offered only if the solver proved it winnable under the **same** options.
  Safe auto-move never breaks the proof; `always` may.
- **S-62** `SolitaireDeals.winnable(streamSeed:, options:)`: candidate deal numbers come from a `CardRng` stream;
  each is dealt (S-4) and solved (200 000 nodes; run it in an isolate). Only **won** is accepted. After **25** tries
  the first unused seed of the bundled list for the rule set is used (`SolitaireSeeds`: draw one / draw three ×
  unlimited / 3 passes / 1 pass; 40 seeds each, 16 for draw three with one pass). Each bundled seed was solved and
  its plan replayed to the win through `SolitaireGame`, and a test solves and replays all 216 again. A list proved
  with fewer passes also serves more passes (a limit of 2 uses the one-pass list).
- **S-63** `SolitaireSolver`: depth-first, full knowledge, the engine's own rules and automatic moves, the stock
  handled as the waste positions it can reach (at most one recycle per step), a table of explored positions. It
  never moves a card back from a foundation, so its proofs hold with or without S-16, and with `autoMoveToFoundation:
  off` (the player can make the same moves). Result `won` (with the plan of engine actions), `lost` (the pruned
  search ran out; **not** a proof of a lost deal) or `unknown` (budget). Measured with 200 000 nodes: about 3 in 4
  draw-one deals and 3 in 5 to 4 in 5 draw-three deals proved; about 1 s per unproved deal on the test machine.
- **S-64** The seed is the deal number, the same on every device. Deal of the day: `SolitaireDeals.dayNumber(date)`
  = yyyymmdd.

### 7.9 Game end and statistics (S-71, S-72)

- **S-71** One deal = one game; it ends with the win or when the player starts another deal. `isOver` = won.
- **S-72** `SolitaireStats` per draw mode: played, won, win %, current and best streak (an abandoned deal is a
  loss), best score, best time and fewest moves (won deals only), average cards home. **Moves** = every draw,
  every recycle and every card movement, automatic ones included; turn-ups and undo are not moves.

Events (`SolitaireEvent.type`, `SolitaireEventType`): `stockDrawn`, `wasteRecycled`, `cardTurnedUp`, `cardsMoved`,
`toFoundation`, `fromFoundation`, `autoMoved`, `autoCompleted`, `won`, `timePenalty`, `timeBonus`, `undone`.
Save / resume: `SolitaireGame.toJson()` (`kind: solitaire`, config = seed + options, state, undo history) and
`SolitaireGame.fromJson`.

**Shared conventions that do not apply:** seats, dealer rotation, partnerships, `CardGameEngine`/`CardGameId`, and
"the next deal is dealt at once" (Solitaire deals on demand).

### 7.10 Assumptions to confirm (☐)

1. ☐ Draw one is the default (phone apps); draw three is the Hard preset (old Windows default).
2. ☐ Timed scoring is off by default; the clock is always shown.
3. ☐ Draw-three recycle penalty from the 3rd recycle (Windows desktop help); 4th (Windows CE) and every recycle are
   options.
4. ☐ Winnable deals only in the Easy preset.
5. Best score, best time and fewest moves count won deals only.
6. With unlimited passes the stuck search may use the stock order (the player can see it by cycling); with a pass
   limit it waits until every stock card has been seen.
7. ☐ Name: سوليتير (or "الصبر" if that is what is said at home).

---

## 8. Blackjack 21 – بلاك جاك ٢١ (points only)

**As commonly played in Jordan.** Jordan has no casinos and Blackjack is not part of Levantine home card play (it is
not واحد وثلاثين, 31); people meet it in apps and films. No Jordanian variant exists, so the default is **the
standard international table** (six packs, dealer stands on soft 17, dealer peek, double on any two, double after
split, re-split to four hands, no surrender) with Madar's hard requirement: **no wagering**. Results are kept as a
points tally; nothing is put up before a deal. `const BlackjackOptions()` **is** that game (also
`BlackjackOptions.jordan()`). Code: `blackjack/blackjack_state.dart` (options, moves, hands, table state),
`blackjack/blackjack_rules.dart` (rules, events, `BlackjackEngine`), `blackjack/blackjack_strategy.dart` (the chart
and the advisor), `blackjack/blackjack_ai.dart` (AI seats).

The game is in the registry as `CardGameId.blackjack` with `playerCount` = seats (1–3); the dealer (الموزّع) plays
inside `apply`. The save's `game` key is `blackjack`.

UI words (ARL2 = used by several Arabic localisations): dealer **الموزّع** (never التاجر) · deal **وزّع** · hit
**اسحب** · stand **اكتفِ** (short: قف) · double **ضاعِف** ("ورقة واحدة فقط، ونتيجة اليد تُحسب مرتين") · split
**قسّم** · surrender **انسحب** ("بنصف خسارة") · bust **تجاوزت ٢١** · push **تعادل** · natural **بلاك جاك!** ·
soft / hard **مرن / ثابت** · points **النقاط**.

**Presets**

| Preset | What changes |
|---|---|
| `BlackjackOptions()` = `BlackjackOptions.jordan({seats, sessionRounds})` | nothing |
| `BlackjackOptions.european({seats, sessionRounds, originalOnly})` | `holeCard: europeanNoHoleCard` |

### 8.1 Options (`BlackjackOptions`)

| Option | Jordan default | Other values | Rule | Confidence |
|---|---|---|---|---|
| `decks` | **6** | 1, 2, 4, 8 | B-1 | high |
| `penetration` | **0.75** | 0.50–0.85 | B-2 | medium |
| `burnCard` | **true** | false | B-3 | low |
| `continuousShuffle` | **false** | true | B-4 | medium |
| `holeCard` (`BlackjackHoleCard`) | **`peek`** | `europeanNoHoleCard` | B-22, B-25 | high |
| `originalOnly` | **false** (European table only) | true | B-25, B-61g | medium |
| `dealerHitsSoft17` | **false** (S17) | true (H17) | B-52 | high |
| `blackjackBonus` | **3** | 2 | B-60 | high |
| `doubleOn` (`BlackjackDoubleOn`) | **`any`** | `nineToEleven` | B-33 | high |
| `doubleAfterSplit` | **true** | false | B-34 | high |
| `maxHands` | **4** | 2, 3 | B-36 | high |
| `splitTensByRankOnly` | **false** | true | B-35 | high |
| `resplitAces` | **false** | true | B-38 | high |
| `hitSplitAces` | **false** | true | B-38 | high |
| `surrender` (`BlackjackSurrender`) | **`off`** | `late` (never on the European table) | B-40 | high (rule), low (default) |
| `autoStandOn21` | **true** | false | B-31 | low |
| `tally` (`BlackjackTally`) | **`net`** | `winsOnly` | B-62 | low (design) |
| `sessionRounds` | **20** | 10, 50, null (endless; ended with `endSession`) | B-64 | low (design) |
| `seats` | **1** | 2, 3 (each a person or an AI of any level; the table screen decides) | B-67 | low (design) |
| `advisor` (`BlackjackAdvisor`) | **`onRequest`** | `off`, `coach` | B-75 | low (design) |

Not offered, on purpose: insurance or "even money" of any kind (B-23), and — because no source says they are played in
Jordan — five-card Charlie, a 6:5 natural, early surrender, side bets and "dealer wins ties".

### 8.2 The shoe (B-1…B-5)

- **B-1** `decks` packs (`buildDeck(copies:)`) shuffled with the match's `CardRng`; copies are the same card value,
  so card conservation is checked as a multiset.
- **B-2** Before a round, if fewer than (1 − `penetration`) of the shoe remain (fewer than 78 of 312 by default),
  every card is shuffled back. A round in progress always finishes first.
- **B-3** After every such shuffle (and the first one), one card goes face down to the discards (`cardBurned`).
- **B-4** `continuousShuffle`: every card is shuffled back before every round, no burn.
- **B-5** A card needed from an empty shoe: the discards (never the cards on the table) are shuffled into a new
  shoe, without a burn (`shoeShuffled`, reason `emergency`). With no discards either, the hand that needs a card
  stands as it is (player: `stood`, reason `noCards`; dealer: stops drawing). Reachable with 1 pack and 3 seats.

### 8.3 Values (B-10…B-13)

- **B-10** 2–10 face value, J Q K 10, ace 1 or 11 (`blackjackCardValue`).
- **B-11** Total (`blackjackTotal`): the sum with aces as 1; with an ace and sum + 10 ≤ 21 the total is sum + 10 and
  **soft**, otherwise **hard**.
- **B-12** A natural: ace + 10-value as the first two cards of a hand that did **not** come from a split.
- **B-13** Above 21 = bust; a busted hand is settled as lost at once, even if the dealer busts later.

### 8.4 The round (B-20…B-26)

Phases (`BlackjackPhase`): `betweenRounds` (seat 0 has `deal`, plus `endSession` in an endless session),
`playerTurn` (the seat of the hand being played), `over`. The first round is **not** dealt at once.
- **B-20** The round starts with `deal` (وزّع). There is no stake step, ever.
- **B-21** One card up to each seat in order, one up to the dealer, a second up to each seat, the dealer's second
  face down. European table: the dealer gets only the up card now.
- **B-22** Peek: with an ace or 10-value up card the dealer checks the hole card (`dealerPeeked`, value 1 when
  found). A dealer natural is shown at once and ends the round: every hand loses (−2) except a player natural,
  which pushes (0). Nobody acts.
- **B-23** No insurance and no "even money": not implemented at all.
- **B-24** A player natural against a dealer without one is settled at once (+3) and needs no dealer card. On the
  European table with an ace or 10 up, it waits for the dealer's second card (both naturals → push).
- **B-25** European table: the dealer's second card comes after every seat has finished. A dealer natural then takes
  every hand's full value (a doubled hand −4); with `originalOnly` the **seat** loses exactly −2 in all, whatever it
  split or doubled; a player natural pushes. Surrender is not available.
- **B-26** Seats act in order, each hand to the end, then the dealer, then the settlement.

### 8.5 Player actions (B-30…B-41)

Moves (`BlackjackMove` / `BlackjackAction`): `deal`, `hit`, `stand`, `double`, `split`, `surrender`, `endSession`.
- **B-30** `hit` (اسحب): one card. **B-31** `autoStandOn21`: any 21 stands by itself. **B-32** `stand`.
- **B-33** `double` (ضاعِف): first decision on a two-card hand; exactly one more card, then the hand stands; its
  result counts twice. `doubleOn: any` or `nineToEleven` (hard 9, 10, 11).
- **B-34** `doubleAfterSplit` on a split hand's first decision, never on split aces.
- **B-35** `split` (قسّم): two cards of equal **value** (K + Q splits); `splitTensByRankOnly` → identical ranks only for
  10-value cards.
- **B-36** Re-split while the seat has fewer than `maxHands` hands.
- **B-37** Split hands are played left to right; each gets its second card when its turn comes (`cardToHand`).
- **B-38** Split aces get one card each and stand (unless `hitSplitAces`); never double; re-split only with
  `resplitAces`. A + A after a split is a soft 12 that stands.
- **B-39** A + 10 after a split is an ordinary 21 (+2, no bonus).
- **B-40** `surrender` (`late`): first decision on the **original** two-card hand only, after the peek; the hand ends
  at −1. Never after a hit, split or double; never on the European table.
- **B-41** The dealer never doubles, splits or surrenders.

Error ids: `matchOver`, `notYourTurn`, `roundInProgress`, `sessionHasRounds`, `noRoundInProgress`, `cannotHit`,
`cannotDouble`, `cannotSplit`, `cannotSurrender`, `illegalMove`.

### 8.6 The dealer (B-50…B-52)

- **B-50** The hole card is turned up (`holeRevealed`). If no hand of any seat is still live (all busted,
  surrendered or settled as naturals), the dealer draws nothing. (European table: the dealer takes the second card
  only when a hand is live or a natural waits for it.)
- **B-51** Otherwise the dealer hits 16 or less and stands on hard 17 or more (`BlackjackRules.dealerHits`).
- **B-52** Soft 17 (A-6, A-A-5): stands by default; `dealerHitsSoft17` makes it hit.

### 8.7 Settlement and points (B-55…B-67) – no wagering

Points are a **record of results**, never staked beforehand. Unit = 2, so the 3 : 2 bonus and the half-loss stay
whole numbers.

| Rule | Hand result (`BlackjackOutcome`) | `net` tally (default) | `winsOnly` tally | Counts as |
|---|---|---|---|---|
| B-60 | natural (`blackjack`) | +3 (+2 with `blackjackBonus: 2`) | same | won |
| B-61a | win | +2 | +2 | won |
| B-61b | doubled win | +4 | +4 | won |
| B-61c | push | 0 | 0 | pushed |
| B-61d | loss or bust | −2 | 0 | lost |
| B-61e | doubled loss | −4 | 0 | lost |
| B-61f | surrender | −1 | 0 | lost |
| B-61g | European table, dealer natural, `originalOnly` | −2 for the whole seat (event `lossCapped`) | 0 | each hand lost |

- **B-61g in the events.** Each hand's `handSettled` carries its own result (a doubled hand −4, a bust as it
  happened). When the per-seat rule then gives points back, one `lossCapped` event per seat carries them (always
  a positive value), so a seat's `handSettled` plus `lossCapped` values always add up to its round points. After
  the round the seat's first hand holds the −2 (or 0 with a natural) and its other hands 0.
- **B-55…B-59** Busted → lost even if the dealer busts. Dealer busts → every live hand wins. Otherwise the higher
  total wins and equal totals push. A player natural beats a dealer 21 of three or more cards. Each split hand is
  settled on its own.
- **B-62** The headline is hands won / hands played and points (`BlackjackSeat.points`).
- **B-63** Round result = the sum of its hand points (`lastRound.seatPoints`). A round above 0 extends the streak,
  below 0 breaks it, 0 leaves it. **ASSUMPTION:** the streak follows the **net** result even under `winsOnly`, so a
  lost round still breaks it.
- **B-64** Session: `sessionRounds` rounds (10, **20**, 50) or endless (`endSession` between rounds). The last round
  always finishes; `isOver` after it (`sessionOver`).
- **B-65** Per seat (`BlackjackSeat`): points, hands won / lost / pushed, naturals (every natural dealt, pushed ones
  included), busts, doubles won, splits, streak and best streak, advisor accuracy (`decisionsMatched / decisions`).
- **B-66** Owner-only fact (never in the UI): with the defaults, perfect play still loses about 0.4 % of a base unit
  per hand, so a long net tally drifts slightly below zero. The AI strength test measured −0.016 points per hand for
  the chart and −0.140 for dealer-like play over 20 000 hands. This is why hands won and streaks sit next to the
  points.
- **B-67** 1–3 seats against one dealer; everything except the hole card is face up, so pass-and-play hides nothing.
  Winners (`state.winners`): higher points, then more hands won, then more naturals, then fewer busts; seats still
  equal share the win. A single seat is always listed; `soloSessionWon` (points > 0) is for stats.

**Wording (hard requirement).** Never in UI text, stable ids, event details, achievements or store text:
bet, wager, stake, chips, money, cash, bankroll, payout, pays, odds, house, house edge, casino, win money, even
money, insurance; رهان، مراهنة، راهن، فيش، رقائق، مال، فلوس، أموال، رصيد، كازينو، ربح مالي، تأمين، دفعة،
التاجر (as "dealer"). The code uses `points`, `outcome`, `bonus`, `double`. No chips, coins, dollar signs or
roulette imagery (a table and a shoe are fine). A test scans every file of the package and every option, move,
outcome and event id for these words.

### 8.8 Basic strategy, the advisor and the AI seats (B-70…B-77)

`BlackjackStrategy` holds the standard chart for **4–8 packs, S17, double after split, peek**. Codes
(`BlackjackChartCode`): H hit, S stand, D double (else hit), Ds double (else stand), P split, Rh surrender (else
hit), Rs surrender (else stand), Rp surrender (else split). Dealer up card 2 … 10, A.

| Hard | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | A |
|---|---|---|---|---|---|---|---|---|---|---|
| 5–8 | H | H | H | H | H | H | H | H | H | H |
| 9 | H | D | D | D | D | H | H | H | H | H |
| 10 | D | D | D | D | D | D | D | D | H | H |
| 11 | D | D | D | D | D | D | D | D | D | H |
| 12 | H | H | S | S | S | H | H | H | H | H |
| 13–14 | S | S | S | S | S | H | H | H | H | H |
| 15 | S | S | S | S | S | H | H | H | Rh | H |
| 16 | S | S | S | S | S | H | H | Rh | Rh | Rh |
| 17+ | S | S | S | S | S | S | S | S | S | S |

| Soft | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | A |
|---|---|---|---|---|---|---|---|---|---|---|
| A,2 / A,3 | H | H | H | D | D | H | H | H | H | H |
| A,4 / A,5 | H | H | D | D | D | H | H | H | H | H |
| A,6 | H | D | D | D | D | H | H | H | H | H |
| A,7 | S | Ds | Ds | Ds | Ds | S | S | H | H | H |
| A,8 / A,9 | S | S | S | S | S | S | S | S | S | S |

| Pair | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | A |
|---|---|---|---|---|---|---|---|---|---|---|
| 2,2 / 3,3 | P | P | P | P | P | P | H | H | H | H |
| 4,4 | H | H | H | P | P | H | H | H | H | H |
| 5,5 | as hard 10 | | | | | | | | | |
| 6,6 | P | P | P | P | P | H | H | H | H | H |
| 7,7 | P | P | P | P | P | P | H | H | H | H |
| 8,8 | P | P | P | P | P | P | P | P | P | P |
| 9,9 | P | P | P | P | P | S | P | P | S | S |
| 10,10 | S | S | S | S | S | S | S | S | S | S |
| A,A | P | P | P | P | P | P | P | P | P | P |

- **H17** (medium): 11 vs A → D; A,7 vs 2 → Ds; A,8 vs 6 → Ds; 15 vs A → Rh; 17 vs A → Rs; 8,8 vs A → Rp.
- **No double after split** (low): 2,2 and 3,3 split only vs 4–7; 4,4 never; 6,6 only vs 3–6.
- **European table, all hands lost** (low): 11 vs 10 or A → H; 8,8 vs 10 or A → H; A,A vs A → H. These win over
  the H17 changes (European H17: 8,8 vs A → H, 11 vs A → H). With `originalOnly` the peek chart is used (H17 on
  that table: 8,8 vs A is Rp, which becomes P because surrender is never offered there).
- A cell that is not allowed falls back as coded (D → H, Ds → S, Rh → H, Rs → S, Rp → P or the total, P → the total);
  a pair that may not split (limit reached, aces not re-splittable) is played as its total (A,A as soft 12 → H).
- With 1–2 packs the same chart is used and the advice is marked `approximate`.

- **B-70 AI seats** (`BlackjackAi`, a `HeuristicAi` so the shared fairness test applies): **easy** plays like the
  dealer (hit to 16, soft 17 as the table's dealer rule; never double, split or surrender); **medium** follows the
  chart but plays like the dealer on a seeded random 15 % of its decisions; **hard** follows the chart exactly for
  the table's options. Between rounds every level deals. No level searches (the "sampled worlds" hard AI of the
  other games does not apply: the dealer's play is fixed, so the chart is the best fixed play without counting).
- **B-75 Advisor** `BlackjackEngine.advice()` (hint button, `onRequest`); in `coach` mode every decision that differs
  from the chart adds an `adviceGiven` event with the chart's action. Accuracy is kept for every seat.
- **B-76** The AIs and the advisor read only the hand being played, the up card and the options, never the hole card
  or the shoe; `BlackjackAi.determinize` re-shuffles the hole card with the undealt shoe, and a test checks no
  decision changes.
- **B-77** Strength test: over 20 000 hands on the same seeds, hard's points per hand beat easy's by more than
  0.05 (measured 0.124).

Events (`BlackjackEvent`, a `CardEvent` whose `detail` is the kind name; `BlackjackEventKind`): `shoeShuffled`
(reason `cutCard` / `continuous` / `emergency`), `cardBurned`, `dealt`, `dealerPeeked`, `holeRevealed`, `dealerDrew`,
`cardToHand`, `hit`, `stood` (reason `twentyOne` / `splitAces` / `noCards`), `handDoubled`, `split`, `surrendered`,
`bust`, `blackjack`, `handSettled` (`outcome`, value = points), `lossCapped` (B-61g, value = points given back),
`roundScored`, `sessionOver`, `adviceGiven`. `CardEventType` has a value of each of these names, so `event.type` is
the kind itself; the kind is also in `BlackjackEvent.kind` and `detail`.

**Shared conventions that do not apply:** four seats, rotating dealer, partnerships, "the next deal is dealt at
once" (Blackjack deals on `deal`), and the Monte Carlo hard AI.

### 8.9 Assumptions to confirm (☐)

1. ☐ A points-only Blackjack is acceptable to the owner at all (or drop it, or call it "٢١").
2. ☐ Surrender off by default; late surrender is an option.
3. ☐ 20 rounds per session.
4. The streak follows the net result even with the `winsOnly` tally.
5. "Naturals" in the summary count every natural dealt, including one pushed against a dealer natural.
6. One burn card after each shoe shuffle (authentic, harmless; low confidence).
7. Split hands are played in turn, each getting its second card when it is played (casino order).
8. ☐ Name: بلاك جاك ٢١ (or "٢١").

---

## AI opponents

Three levels per game, all behind `CardAi.chooseMove(state, player, level, rng, budget)`:
- **Easy** – simple heuristics (win the trick if you can, take the biggest capture, open as soon as possible…),
  and a random legal move 20 % of the time (in 41 only during the card play: a random bid would sink its score for
  good).
- **Medium** – full heuristics with **card counting** (cards played, master cards, known voids, cards taken from
  the discard pile), contract / bid evaluation, ducking in the negative Trix contracts, blocking on the Trix layout,
  not feeding the next Basra / rummy player, and **partner play**: not over-taking a partner who is winning,
  feeding points to a winning partner (Baloot), and a simple encouraging discard signal in Tarneeb (a discard of
  8 or higher asks the partner to lead that suit).
- **Hard** – information-set Monte Carlo: it samples many deals of the unseen cards consistent with what the
  player has seen (voids, passes on the Trix layout, revealed doubles, declared project types, picked-up discards,
  an exposed trump card), plays every candidate move in each sampled world and plays on with a fast heuristic
  policy – to the end of the deal in the trick games and Basra, for the next few turns in Hand / Konkan (then the
  hands are estimated) – and keeps the medium move unless another is better by more than two standard errors. The
  time budget is a parameter (`AiBudget.phone` = 150 ms); tests use a fixed number of simulations so they are
  deterministic.

Solitaire and Blackjack do not use sampled worlds: Solitaire's three levels are an auto-player on a masked board
(§7.6, S-75), and Blackjack's are fixed strategies read from a chart (§8.8, B-70).

**No peeking.** The AIs never look at hidden cards. `ai_fairness_test.dart` re-deals everything a seat cannot see,
for every game and every named preset (and the option sets that change what a seat may know), and checks that the
medium and hard decisions do not change; several games also check that the worlds the hard AI samples are
identical. **Level order.** `ai_strength_test.dart` checks on seeded matches that hard beats easy in Tarneeb, 41,
Trix, Trix Complex, Basra, Baloot, Hand, partnership Hand and Konkan (both partners hard in the partnership games);
each game's own tests also check medium over easy and, where the margin is clear, hard over medium.

### Tarneeb and 41

- **Tarneeb.** Easy: noisy bid, simple trick play, a random legal move 20 % of the time. Medium: bids from a hand
  estimate plus the partner's help, never overbids its partner without real extra strength, and **bids 13 only
  with a clear margin** (+26 against −16 and double to the defenders). With that margin it bids 13 at once rather
  than a cheap contract, because 13 tricks on a lower bid score only 16. It plays with card counting, voids, master
  cards and a partner discard signal. With Syrian trumps it values the hand with the known trump suit; with the
  worthless-hand option it throws such a hand in whenever it may (before anyone has bid). Hard: determinised Monte
  Carlo (the unseen cards are re-dealt consistently with voids and, in the Syrian game, with the dealer's exposed
  card). In the auction it compares pass, the cheapest bid, the medium bid, a bid of 13 (whenever the medium AI
  would bid at all) and the throw-in; in play it compares every legal card.
- **41.** Easy: its estimate with noise, rounded down; as dealer it makes the total up when that is within reach;
  its random slips are kept to the card play. Medium: chooses the bid with the best **expected value** (make chance
  from a hand estimate) plus the match situation – a bid that would let the team win if made (e.g. getting above 0
  while the partner is past 41) and caution when already at 41; as dealer it makes a close total up and lets a
  hopeless deal be thrown in. In play it works for its own bid, does not take tricks its partner still needs, and
  tries to set opponents who still need tricks. Hard: determinised Monte Carlo over the medium policy, comparing
  the medium bid, its neighbours and (for the dealer) the bid that makes up the total; the score is the team's
  points minus the opponents', plus a match-win bonus.
- Measured in seeded self-play, two partners of one level against two of the other: hard beats easy in every match
  (Tarneeb 8/8, Syrian 6/6, 41 8/8, 400 6/6); medium beats easy 8/8 in both games; with a phone-sized search (150
  rollouts a move) hard beats medium 5/6 in Tarneeb. In 41 hard is only slightly stronger than medium (5 of 8 in a
  150-rollout probe); with a tiny budget it keeps the medium move.

### Trix

**Easy** picks contracts with noise, does not double (except through its 20 % random moves), plays its lowest card,
throws its costliest card when void and plays the layout at random. **Medium** estimates each contract from its
hand, doubles K♥ when it holds at least five hearts (K♥ included) and a queen with three more cards of its suit and
neither its ace nor its king, ducks and counts cards, avoids feeding penalty cards, discards safely when its partner
is winning, and blocks on the layout. **Hard** is information-set Monte Carlo over sampled deals that respect voids,
layout passes, the king rules (a void seat that did not throw K♥, a heart played onto A♥ with `kingOnAceOfHearts`, a
heart lead that shows only hearts are left), **revealed** doubles only (hidden answers are re-drawn from the sampled
hands, never copied), and the owner's 7♥ in the first deal (public, since that is how he became owner). Measured on
seeded matches: hard beat easy (classic 4/4, Complex 4/8, Complex partnership 6/6), medium beat easy on points in all
four presets (8/8 in both partnership presets), and hard beat medium (classic partnership 6/6, Complex 3/6 with a
clear point edge).

### Hand and Konkan

**Easy** opens as soon as it can, lays down whatever fits, takes the discard half the time it may, and plays a
random legal move 20 % of the time. **Medium** goes out in one move whenever it can (a full hand before a finish
with lay-offs), opens as soon as possible, melds and lays off (a wild only when it is nearly out), swaps table
wilds, places an end wild where it is hardest to swap back (the freeing card already seen), throws in a weak hand
dealt with identical pairs, and discards the card that helps its hand least while not feeding the next player
cards that make a meld with what it is known to hold; near the Konkan elimination score it sheds high cards first.
**Hard** samples the unseen cards consistently with everything public (taken discards until melded, wilds taken by
swaps, the indicator, eliminated seats), and compares by rollouts the draw (stock or discard), opening now or
waiting for a full hand, and the four best discards. Hard beats easy in seeded self-play in both games
(`hand_play_test.dart`, `konkan_play_test.dart`); medium beats easy by about 76 points a match and hard beat medium
6 of 8 in a probe.

### Basra and Baloot

- **Basra.** Easy: the biggest capture (cards and basra points), with a random move now and then. Medium: the
  capture's value (card points, a weight per card that grows with `majorityPoints`, the basra at its real value)
  minus the risk left to the next opponent, counted from the unseen cards: a jack sweep, and every unseen card
  (the 7♦ included) that would clear the table, weighted by what that basra would be worth under the current rule
  set (after the last card of a round the next opponent counts with a new hand). Hard: determinised Monte Carlo
  to the end of the deal. Works for 2, 3 and 4 players, 52 or 44 cards and either scoring.
- **Baloot.** Bidding from hand strength for Sun and Hokom (with the up card), Ashkal for a strong Sun hand that
  does not need the up card, Sun priority (rarely over the partner), keeping or switching a Hokom in the
  confirmation step, Kawesh whenever allowed, the Ace third round with a lower threshold. Doubling on the top
  trumps, **locked** when the doubler holds the trump jack and three trumps. Manual declaration: declare unless an
  opponent has already declared a project of a higher value (the only thing public before the first trick; an
  equal value is declared). Play: card counting, masters, known voids, partner feeding; every legal move comes
  from the rules (the Saudi trumping rules and Ekka included). Hard: determinised Monte Carlo; the belote holder is
  re-sampled from the sampled hands until it is announced, so the AI never learns it early, and until the first
  trick is complete the other players' declared projects are placed at random, by their declared type, among the
  cards each of them may hold (never copied from the real deal).
- Measured: hard beats easy in both games (Basra 8/8 in matches to 61, Baloot 5/8 with a clear points edge at
  the 24-simulation test budget); medium beats easy clearly (Basra 96/100 Jordanian, Baloot 90/100). Hard's lead
  over medium in Baloot is thin at the test budget and clear with a larger search (11/16 at 160 simulations).

### Solitaire and Blackjack

Solitaire: the three-level auto-player (hints, a "watch" demo) decides on `SolitaireBoard.masked()`; measured over
the same 200 draw-one deals, easy wins 57, medium 71, hard 75 (§7.6). Blackjack: easy plays like the dealer, medium
follows the chart except on a seeded 15 % of its decisions, hard follows the chart exactly; over 20 000 hands hard
loses 0.016 points a hand and easy 0.140 (§8.8).

## Not implemented (known gaps)

- **All games:** the save (`toJson`) holds every hand and the shuffle generator that fixes the next deals. There is
  no per-seat (redacted) view yet, so a game played on two phones (Together) must not show or send the raw save to a
  player; the pairs-redeal offer in Hand (phase `redealOffer`) must likewise be shown only to the human's own seat.
- **Tarneeb:** the Egyptian bid-with-a-suit game (with no-trump) – not a Jordanian default.
- **41:** the Syrian preset's own value table (unknown; it reuses `doubleFrom7`); partnership bidding variants.
- **Trix:** "combine any contracts", the app-specific "Complex CC", the 7♥ holder re-chosen every kingdom, a sixth
  hearts contract and a forced penalty discard (§2.12). A hidden doubling answer is sent as `doubled` without cards
  (`detail: 'doublingAnswered'`); there is no dedicated event type for it. With custom penalty values the AI plays
  legally but chooses contracts less well. `TrixOptions` has no range checks (a `trixScores` list that is not four
  long, or `firstOwner` outside 0–3, fails only at run time).
- **Hand / Konkan:**
  - A one-turn finish **below 51** cannot include a wild swap (the `finish` move takes melds, lay-offs and the
    discard). A one-turn finish of 51 or more can, through the normal moves.
  - A taken discard is melded before any other lay-down of that turn (the engine's order of moves).
  - The Egyptian "two unused wilds discarded together" bonus (it needs two discards in one turn).
  - A preset called "Hand Saudi" is not defined (no source supports one); its likely combination is
    `openingMustBeatPrevious` + `bonusWildLastDiscard` + `bonusOneColour` (+ `bonusOneSuit`).
  - Partnership Konkan (refused with elimination by `invalidReason`).
  - `legalMoves` lists at most 12 openings and 6 one-move finishes of a hand (a listed finish lays off at most 3
    cards); `validate` accepts any legal lay-down.
  - With `openingMustUseDiscard` on and `oneTurnFinishWaivesThreshold` off, a closed player cannot go out in one
    turn after drawing from the stock (a non-default combination).
- **Basra:** choosing between alternative captures (the maximum is always taken); the Lebanese basra definition, the
  Yemeni 7♦ tests and the Syrian quarter-point values (no source ties them to Jordan).
- **Baloot:** declaring only some of one's projects, or a partner showing an undeclared project at the second trick;
  the "Sawa" bid (an app feature); a separate "Ekka" call (Ekka is recognised automatically).
- **Solitaire:** the solver is incomplete by design (a `lost` answer is not a proof), so winnable-deal mode rejects
  some winnable deals; `winnableOnly` is not applied by `SolitaireGame.newDeal` – the app picks the deal number with
  `SolitaireDeals.winnable` (§7.8); the app must run the solver, the solver hints and (in long searches) `isStuck`
  off the UI thread; statistics are kept by `SolitaireStats` but storing them is the app's job.
- **Blackjack:** personal bests per rule preset (B-65) are left to the app's stats store; no card-counting AI; the
  H17 and surrender chart cells are medium confidence and the European-table and no-double-after-split changes low;
  `BlackjackOptions` accepts any pack count from 1 to 8, although only 1, 2, 4, 6 and 8 are offered.

## Sources

Every source was used only as evidence of how the games are played; nothing (text, names, art or code) was copied
from any app or site, and the rules above are written in our own words. The research notes behind each game (the
rule-by-rule cross-check with confirmed / corrected / uncertain verdicts) are the Madar specs
`tarneeb_final.md`, `trix_final.md`, `hand_konkan_final.md`, `basra_baloot_final.md` and
`solitaire_blackjack_final.md`.

- **Tarneeb (§1):** the Jawaker Tarneeb rules page and blog; the VIP Jalsat help-centre Tarneeb rules; an archived
  full copy of the pagat.com Tarneeb page (bids 7–13, pass final, same-dealer redeal, 16 / 26 / −16 and double to
  the defenders, targets 31/41/51/61, the "some play" variants); bloob.io's Tarneeb help text (31 standard, 41 and
  61 longer, a bid of 13 worth 26 or costing 16); Arabic articles on Tarneeb in Jordan (mawdoo3, kayftal3ab,
  albawaabh, a Gerasa News column on "طرنيب أردني"); independent open-source Arabic implementations (the Warqnaa
  platform's game catalogue and rule notes, the vexo engine) as corroboration only. No Jordanian book or forum
  could be read directly, so every rule marked ☐ is an owner question.
- **41 (§1b):** the pagat.com "Forty-One" page (hearts trump, one bid each, total 11, 1–6 face / 7+ double, partner
  positive, higher total when both qualify); gamerules.com "Forty One"; the Jawaker rules for Syrian Tarneeb 41 and
  Tarneeb 400; the Wikipedia article on 400 and 400cards.com; an independent open-source 400 implementation
  (SamirMD0/tarneeb-400: the value table by the bidder's own score and the minimum total by the highest score) and
  the Warqnaa platform's rule notes (Syrian 41's exposed-card trump; "طرنيب 41" in its catalogue is the partnership
  game to 41) as corroboration only.
- **Trix (§2):** Jawaker (Amman) Trix, Trix Complex and partnership rules pages, and Maysalward (Amman) "How to play
  Trix" (search summaries); pagat.com "Trix" (standard rules and variants), Arabic Wikipedia «تركس (لعبة ورق)», the
  VIP Jalsat help pages and a Trix Complex guide blog (search summaries); open-source community scorekeepers and
  games by Arabic-speaking players, read for how they score: alooshxl/TrixScore, YourChaosChris/PaperGames PR #149,
  nasirseyfeddin-cmd/trix-tracker, mahzak914, Tirador1/Trix, AyhamSai/trix_tracker, Diab-software/Trix-app,
  Abdalrhman1989/Trix-Card-Game, Fouadmokdad/score, adnankmh/Warqnaa.
- **Hand (§3):** read through GitHub copies because the originals were blocked: pagat's "Hand" page, which
  describes the form played in Jordan, Lebanon and Palestine (its informant gives Nablus / Amman), read in a French
  translation; a Jordanian / Lebanese / Palestinian family's written Hand rules that mark which rules are standard
  (checked against pagat and Jawaker) and which are house rules; a summary of Jawaker's Hand rules (Jawaker is
  based in Amman); a fragment of Arabic Wikipedia ("الهاند أو الكونكان"). Confidence **medium**: three Levantine
  written descriptions agree on almost every rule.
- **Konkan (§6):** a Yemeni description of "regular" Konkan (the only written Konkan match rule found: elimination
  over 301; openings that must beat the previous one; joker 50); a "Middle Eastern" Concan description (106 cards,
  15 / 14, 51, joker 25); the Arabic Wikipedia fragment that calls the game "الهاند أو الكونكان". No Jordanian
  written description of Konkan was found: confidence **low**.
- **Basra (§4):** the rules pages on pagat.com (Basra, with its sections on the Jordanian, Egyptian, Yemeni and
  Lebanese ways of scoring) and the English Wikipedia article "Bastra" (its Egyptian, Palestinian, Jordanian, Syrian
  and Lebanese sections), read as archived copies; two open-source Basra engines used only to confirm how the
  Egyptian scoring is commonly applied. The two Jordan-specific write-ups go back to the same informant, so the
  Jordanian scoring is rated *medium*; the 7♦ sweep is rated *low* for Jordan.
- **Baloot (§5):** the Baloot page on pagat.com (built on the Saudi tournament rules and questions to Saudi
  players) and the English Wikipedia article "Baloot", read as archived copies; a Saudi-written Arabic ruleset with
  a table of majlis differences; a commercial Baloot rules specification describing the Gulf apps; an independent
  Baloot design document. A reference scorer written for the rules check reproduces all 23 worked examples of the
  Saudi sources; the same 23 examples are tests (`baloot_scoring_test.dart`).
- **Solitaire (§7):** Windows Solitaire help text ("Keeping Score", "Turning over the deck"), Windows CE Solitaire
  help, ReactOS Solitaire (values confirmed), independent Klondike clones (the 700 000 ÷ seconds bonus and its 30 s
  threshold), Dang, Gent, Nightingale, Ulrich-Oltean, Waller, *Constraint Models for Klondike*, CP 2025
  (winnability), Arabic interface translations (the name سوليتير).
- **Blackjack 21 (§8):** old Usenet / BBS blackjack texts (peek order, rule effects), a blackjack simulator's rules
  document (split aces, 21 after split, European "original bets only"), Wizard of Odds rule-effect figures as cited
  in open-source code (house edge by rule), an independent basic-strategy table (every no-surrender cell matched),
  Arabic interface translations (الموزّع، تعادل، تجاوزت، اسحب، قف).
