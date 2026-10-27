# Daily Auction (Sàn Đấu Giá Hằng Ngày) — Concept Prototype

## Hypothesis
Modern Art's five auction types (open / once-around / sealed / fixed price /
double) plus its "top-3 categories gain cumulative value" market will hold up
as a short solo-vs-AI session (~10 min). A **daily season** where everyone
plays the same seeded deck against the same AI table will give a reason to
come back and replay the same day for a better score.

Riskiest assumption: the auction decisions stay readable for new players on
mobile (who pays whom, what an item is worth right now).

## How to run
Open `prototype.html` in any browser (double-click, no server needed).
- `?day=YYYY-MM-DD` plays a different day's season (same seed = same deck).
- `?nostart` skips the start screen (for testing).

## What's in it
- Rules adapted from Modern Art (Reiner Knizia): 4 players (you + 3 AI),
  5 collection lines with 12–16 cards each, deal 9/4/4/0, round ends on the 5th
  card of one line, top 3 lines get +30/+20/+10 cumulatively, items sold back
  to the bank. Highest money after 4 rounds wins.
- Simplification: in the open auction, passing removes you from that auction.
- Daily season: seed = local date. Leaderboard keeps each player's best score
  of the day and their attempt count; past seasons show champion + your rank.
- Leaderboard is `LeaderboardAPI` (localStorage + in-memory fallback), with
  8 🤖 entries = scores from AI-only games on the same seed. Swap its three
  methods (`submit`, `getSeason`, `listSeasons`) for a real backend/SDK.

## Verification
Browser console:
- `await DBG.simulate(200)` — 200 all-AI games: checks money conservation,
  no negative money, 4 rounds, no line past 5 cards. Last run: 0 errors,
  score min/median/max 177/298/558, ~27 auctions per game.
- `await DBG.determinism()` — same seed gives same result (true).
- A full human game was scripted through the UI (all 6 prompt types hit),
  replayed twice to check best-of-day and attempt counting.

## Status
In progress — not yet played by a human.

## Findings
_Pending playtest._
