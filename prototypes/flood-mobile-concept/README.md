# Flood Mobile — Concept Prototype

## Hypothesis

If the player taps color buttons to flood-fill from the top-left region on a
small board (8x8 cells tiled into irregular polyomino pieces, 5 colors, large
touch targets), they will understand the rules instantly without instructions
— confirmed if a first-time player solves puzzle #1 within the move limit
without explanation and wants to try again.

**Riskiest assumption**: shrinking the grid/color count for mobile still
leaves enough strategic depth to feel like a real puzzle, not something
trivial.

## How to Run

Open `prototype.html` directly in any browser (double-click the file, or
drag it into a browser window). No server, no build step, no install.

- Tap a color swatch to flood the captured territory (white-outlined region,
  starting from the level's start point) with that color. Dimmed swatches are
  genuinely disabled — no adjacent unclaimed piece has that color, so picking
  it couldn't grow your territory; it can't be tapped and costs no move.
- Adjacent pieces of the new color merge into the territory automatically.
- Fill the whole board in one color before moves run out.
- **Chơi lại** — retry the exact same level (same piece shapes/colors reset).
- **Next** / **Back** — page through the built-in 5-level pack generated at
  page load (clamped at both ends, no wraparound).
- **Mở Editor** — opens `editor.html` in a new tab (level authoring lives
  there now, not on the gameplay UI).
- **Tải level JSON khác…** (small link below the controls) — load a
  hand-authored or Editor-exported level; it's inserted right after your
  current spot in the pack so Next/Back keep working afterward.

There is no "Ngẫu nhiên" (random) button on the gameplay page anymore — that
moved into the Editor, where it quick-generates a random board on the
current width/height as a starting point to hand-edit.

Level authoring is a separate tool: open `editor.html` directly (or via the
"Mở Editor" link in the gameplay page). Set width/height, "Ngẫu nhiên" for a
random starting layout or paint polyomino pieces cell-by-cell with a chosen
color and mechanic (see below), erase, set the flood start point, then
"Xuất JSON" to download a level file — load it back in `prototype.html` via
"Tải level JSON khác…". Schema documented in `docs/mechanics.md`.

### Block mechanics (authored in the Editor, not random-generated)

- **Ẩn màu / hidden** — the piece conceals its real color (shows a neutral
  gray cell with "?" at its center) until your territory becomes adjacent to
  it, at which point it reveals its real color (still has to be captured
  normally afterward — revealing isn't capturing).
- **Băng / ice** — the piece is frozen for a set number of moves (shown as a
  frost tint + countdown at its center); it cannot be captured by the flood
  fill while frozen even if the color matches, and its color doesn't count
  as a useful pick in the palette until it thaws. The countdown decrements
  on every real move made anywhere on the board; a piece that hits 0 thaws
  immediately and becomes capturable that same move.

### `levels/` — 44 pre-built levels (this is what gameplay actually loads)

`prototype.html` fetches `levels/index.json` on load and pulls in all 44
levels in parallel as its Next/Back pack — there's no more runtime random
generation as the primary path.

- **Levels 1-7**: hand-authored tutorials (built and exported from
  `editor.html`), sizes ramping 2x2 → 5x5; tutorials 4-5 introduce the
  hidden-color mechanic. `_generate.pl` knows about them via a hardcoded
  `@TUTORIALS` metadata table (so it can write correct `index.json` entries)
  but never overwrites their files.
- **Levels 8-44**: a Perl script (`levels/_generate.pl`, no Node/Python
  available in this environment) ports the game's own polyomino-tiling
  algorithm to generate 37 levels: 5 board sizes (4x4 through 8x8 — 3x3 was
  dropped and 4x4 cut down per user request, removing what were the old
  "levels 8-20") with color count ramping 2→5 (tier size computed from the
  actual level count so the ramp always reaches 5 colors by the end, however
  many levels there are), `maxMoves` from a formula validated against the
  game's own 8x8/5-color default (18 moves), and greedy graph-coloring so no
  two touching pieces share a color (mirrors the Editor's `randomizeGrid()`
  fix — see below).

If `fetch()` can't reach `levels/` (browser-dependent — typically only an
issue opening the `.html` file directly with a browser that blocks
same-origin `file://` fetches), gameplay silently falls back to the old
5-level runtime-random pack (`buildRandomStarterPack()`) with a console
warning, rather than breaking.

## Current Status

In-progress. Core loop (flood-fill, move limit, win/lose) is implemented and
manually verified in-browser at mobile viewport (375x812) and via DOM/console
inspection. Iterating on mechanics per user feedback:
- ✅ Polyomino-shaped pieces (1x1 up to tetromino-sized, mixed) replacing
  plain per-cell coloring
- ✅ White outline around captured territory (dark piece-boundary lines were
  added then removed again per feedback — colors alone tell pieces apart now)
- ✅ JSON level load/export
- ✅ Level Editor split into its own page (`editor.html`), off the gameplay UI,
  including its own "Ngẫu nhiên" random-generate button
- ✅ Fixed white-outline corner artifacts and non-square cells — root cause
  was fractional (non-integer) CSS pixel sizing from `%`/`aspect-ratio`;
  fixed by computing exact integer `cellSize` in JS (`layoutBoard()`) and
  applying it to both grid axes
- ✅ Palette genuinely disables (not just dims) colors that wouldn't grow the
  territory this turn — fixed a rules bug where dimmed colors were still
  clickable and still cost a move despite doing nothing
- ✅ Gameplay "Ngẫu nhiên" button removed; replaced with a 5-level starter
  pack + Next/Back navigation, matching the requested button layout
  (Chơi lại / Next / Back / Mở Editor)
- ✅ 44 pre-built levels in `levels/` (7 hand-authored tutorials + 37
  generated, 2x2→8x8, ramping color count) — see above
- ✅ Removed the old levels 8-20 (all nine 3x3s + the first four 4x4s) per
  user request — 3x3 dropped from `_generate.pl`'s size list entirely, 4x4
  cut from 9 to 5; everything renumbered so there are no gaps (37 generated
  levels total now, landing at 8-44). Tier size for the color ramp is now
  computed from the actual generated count instead of a fixed "13 levels per
  tier" divisor, so it still reaches 5 colors by the last level.
- ✅ Two new block mechanics: hidden-color (`?` until territory-adjacent)
  and ice (frozen N moves, blocks capture and palette usefulness until
  thawed) — authorable in the Editor, engine-level support in gameplay
- ✅ Reverted gameplay's cell visual to the original rounded-tile look
  (`border-radius: 6px` + `3px` gap between cells) per user feedback that it
  looked nicer than the later zero-gap/zero-radius "seamless blob" style.
  `layoutBoard()` was updated to account for the gap when computing integer
  cell size, so cells are still exactly square. (Editor.html's board
  intentionally keeps its zero-gap/piece-outline style — that tool needs to
  show exact piece shapes while authoring, a different job than gameplay.)
- ✅ Same-group cells (a piece's own cells, or the whole captured territory)
  now visually merge into one seamless rounded shape instead of staying
  separate rounded tiles: small filler rectangles (`.bridge`) bridge the
  gap between same-group neighbors, and each cell's corner radii are
  computed individually — flattened wherever that corner is strictly
  interior to the group (both orthogonal neighbors + the diagonal neighbor
  are same-group), left rounded everywhere else.
- ✅ **Fixed the bug that made merging never actually work**: absolutely
  positioned children of `#board` are placed relative to its *padding box*,
  so bridge coordinates had to include `BOARD_PADDING`. Without it every
  bridge landed 6px up-and-left — inside the cell (invisible, same color)
  rather than in the gap, leaving the real gaps dark. This is why several
  rounds of "merge" work still looked like separate tiles with rough
  joints. Confirmed by measurement: cell 0 spans 6→45px, the gap is
  45→48px, and bridges were being drawn at 39→42px.
- ✅ Captured region is outlined by a single continuous white line that
  wraps its entire true perimeter (including around bridges and into
  concave notches), replacing the per-cell CSS border that necessarily
  broke at every grid gap. Implemented by redrawing the region as one
  composite shape on `#territoryLayer` and applying four chained white
  `drop-shadow()` filters (±3px on each axis), which dilates the composite
  shape's alpha into an even outline that follows the rounded corners.
- ✅ Start-point cell marked with "★"; hidden-piece "?" and ice countdown
  glyphs repeat on every cell of the piece (not just one) so the whole
  block reads at a glance regardless of which part you're looking at.
- ✅ Ice blocks got a real "sheet of ice" texture (diagonal crystal streaks,
  frost gradient, bright top edge) instead of a flat tint overlay, applied
  to both cells and the bridges between them so a multi-cell frozen block
  freezes as one visual sheet.
- ✅ Win overlay now offers "Level tiếp theo →" alongside "Chơi lại" instead
  of trapping the player behind a full-screen overlay with no way to reach
  the Next button underneath — fixed a self-inflicted regression in the
  same round where cells (needed above `#territoryLayer` for the ★ mark)
  were also painting over the overlay; overlay now has an explicit higher
  z-index.
- ✅ Editor's "Ngẫu nhiên" no longer lets two touching pieces share a color
  (greedy graph-coloring, same fix ported into `levels/_generate.pl`'s
  random 50), and the Editor now shows a real minimum-moves-to-solve stat
  (exact via BFS over the "which pieces are captured" state space, capped
  and falling back to a lower-bound estimate on very large boards).
- ✅ Gameplay palette only shows colors the current level actually uses
  (was always showing all 5 slots even for a 2-color level).
- ✅ Gameplay now loads its Next/Back pack from `levels/` (`fetch()` +
  `Promise.all`) instead of generating levels at runtime — 7 hand-built
  tutorial levels (introducing hidden-color partway through) followed by
  the 37 generated ones, 44 total (see the levels-8-20-removal bullet
  above). Falls back to the old 5-level random pack if `fetch()` can't
  reach the files (browser/context dependent).

Verified via DOM/computed-style + simulated-click checks, and this round also
with real screenshots: cells render as exact integer-px squares, disabled
swatches truly block clicks and moves, Next/Back clamp correctly at both pack
ends, the Editor's random button fills 100% of cells with no gaps. The
hidden/ice mechanics were verified with a hand-built 3x3 test level exercising
a full scripted move sequence (reveal-on-adjacency without capture, frozen
piece excluded from the palette and from flood capture despite a color match,
thaw-and-immediately-capturable on the move the counter hits 0) — every step
matched the expected state exactly, ending in a win.

The rounded-cell revert and the group-merge/bridge system were both verified
structurally via DOM (correct `.style.borderRadius` per cell reflecting
interior vs. exterior corners, correct `.bridge` element count/position/color
growing as territory grows, correct per-side white border only on true
territory boundaries, hidden/ice mechanics re-tested and still working after
the `renderBoard()` rewrite) but **not with an actual screenshot** — the
Browser pane wasn't compositing in this session (same "pane not displayed"
issue noted before; a clone of a live cell node computed styles correctly
while the in-place node didn't, pointing at a tool-side quirk rather than a
real CSS bug, but this is inference, not a look-at-it confirmation). A live
visual check from the user is worth doing on the next open.

Not yet run through the full Phase 6 playtest debrief (hypothesis
confirm/refute, PROCEED/PIVOT/KILL verdict) — still adding mechanics per
user request before that formal check.

## Findings

_(to be filled in once the playtest debrief happens — see
`.claude/skills/prototype/SKILL.md` Phase 6-7)_
