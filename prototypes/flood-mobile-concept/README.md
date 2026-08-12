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

### `levels/` — 50 pre-generated levels

A Perl script (`levels/_generate.pl`, no Node/Python available in this
environment) ported the exact same polyomino-tiling algorithm used by the
game to generate 50 standalone level files: 6 board sizes (3x3 through 8x8,
9/9/8/8/8/8 levels each) with color count ramping from 2 to 5 across the
sequence, and `maxMoves` computed from a formula validated against the game's
own 8x8/5-color default (18 moves). `levels/index.json` is a manifest of all
50. These are plain "normal"-only levels (no hidden/ice) and are **not**
wired into the gameplay pack automatically — load one via "Tải level JSON
khác…" to play it, or ask to have `buildStarterPack()` read from this folder
if you want them in the default Next/Back rotation.

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
- ✅ 50 pre-generated levels in `levels/` (3x3→8x8, ramping color count) —
  see above
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
  are same-group), left rounded everywhere else. Captured territory's white
  boundary is now drawn per-side (only where that side actually borders
  something outside the territory) instead of a uniform ring per cell.

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
