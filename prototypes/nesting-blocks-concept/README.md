# Nesting Blocks — Concept Prototype

## Hypothesis
If the player drags smaller same-tier blocks into a bigger container block
(color/size encodes tier: green 1x1 -> blue 2.5x2.5 -> orange 5x5, Russian-doll
style nesting, with "skip-tier" placement also allowed directly into the
biggest container), the nesting/packing logic will feel satisfying and clear.
Confirmed if a player can fully pack a level (all pieces resolved, no
instructions beyond color/size cues) without being told the exact solution.

Riskiest assumption: whether "skip-tier" packing (mixed shapes, exact-fit
container) creates confusing overlap/space logic for the player.

## How to run
Open `prototype.html` in any browser (double-click, no server needed).
Drag green pieces into a blue piece to nest them (Russian-doll style), or
straight onto the orange board (skip-tier). Nesting works anywhere, including
while the blue piece is still in the tray, so a whole assembly can be built
outside the board and carried in. Pieces can also be parked freely in the
tray area, and anything already placed can be dragged back out. Level is
complete when every piece is resolved (on the board, or nested inside
something that is).

## Screenshots
`./shot.sh [scenario] [level] [hitbox]` captures a PNG into `shots/` using
headless Chrome or Edge — no install, no dev server:

```bash
./shot.sh                # level 1, empty tray
./shot.sh nest 1         # greens pre-nested into blues, still in the tray
./shot.sh solved 2       # level 2 fully solved
./shot.sh nest 1 hitbox  # with the real-hitbox overlay on
./shot.sh guide 1        # shows the container clearance guide
```

The same scenarios are reachable in the browser via query params:
`prototype.html?scenario=solved&level=2&hitbox=1`. Scenarios are defined in
`SCENARIOS` in the page, so screenshots are deterministic and repeatable.

## Current status
In progress — 2 levels implemented (8 and 12 green pieces, both with 2 blue
pieces; level 2 cannot be solved without nesting). Geometry rewritten to
SVG + shape-accurate collision. Core loop playable and solvable, not yet
playtested end-to-end by the user with a formal debrief.

## Architecture note (post-rewrite)
Collision uses SAT (separating axis theorem) over convex shapes, with
circles handled analytically. The SVG path and the collision shape are
generated from the same local definition (`localPath` / `geomOf`), so the
drawn shape *is* the hitbox — verified automatically (max delta 0.00px
across all pieces). Toggle "Hien hitbox that" in the UI to overlay the exact
collision geometry.

Pieces live in a flat world-coordinate space with a logical parent/child
relation; nesting does NOT use DOM nesting, which is what previously
introduced silent coordinate offsets.

## Findings so far
- **Bug found and fixed:** free-hand mouse dragging could not reliably hit
  the exact pixel-flush alignment needed for a tight fit (e.g. two 150px
  blue pieces side-by-side in a 300px board leaves zero slack). A few
  pixels of drift made a visually-obvious fit register as invalid. Fixed by
  adding a 30px snap-to-grid (GCD of the 60/150/300px piece sizes) applied
  on every drag, so pieces "click" into flush alignment automatically.
- **Design constraint discovered:** green piece capacity is NOT simply
  `(board area - blue area) / green area`. Because blue (150px) is not a
  clean multiple of green (60px), the geometry caps packable green pieces
  at 10 per 2-blue board, not the 12 that pure area math would suggest
  (verified by grid-cell packing simulation, see code comment above
  `LEVELS` in `prototype.html`). Any future level design that changes piece
  counts must re-derive this ceiling, not just check total area.
- Nesting (green -> blue) and skip-tier (green -> board directly) both work
  and can be freely mixed; un-nesting (dragging an already-nested green back
  out) also works and restores correctly on an invalid drop.
- **Bug found and fixed:** the 30px snap made dragging feel chunky/jumpy.
  Fixed by only snapping at drop time (`onPointerUp`) -- the piece follows
  the raw cursor smoothly during the drag, and only locks to the grid the
  moment it's released. The valid/invalid border preview during drag still
  reflects what the snapped drop would do.
- **Bug found and fixed:** `#board` was `box-sizing: border-box`, so
  `checkBoardValidity`'s bounds (`board.offsetLeft/offsetWidth`, i.e. the
  outer edge of the 4px border) let pieces snap flush against the border's
  *outside*, rendering on top of the border stroke (visible as pieces
  looking "cut off" at the board edge/corners). Fixed by switching `#board`
  to `box-sizing: content-box` and deriving `boardRect()` from
  `clientWidth`/`clientHeight` plus the border width, so the logical
  300x300 play area sits fully inside the border with no overlap.

### Geometry rewrite (round 4) — hitbox correctness

Reported symptom: "the bounding box of the square still feels wrong". Root
cause was not one bug but four, all from approximating geometry with CSS
boxes:

1. **All shapes used their axis-aligned bounding box as the hitbox.** A
   circle claimed the ~22% of its box that it doesn't visually occupy, and a
   triangle claimed ~50%. Two circles could be visually well clear of each
   other and still be rejected. Fixed with true shape-accurate SAT collision.
2. **Triangles were invisible.** `.shape-triangle` set
   `background: none !important; border: none !important`, which overrode the
   colour class — the pieces existed and collided but drew nothing. Fixed by
   rendering real SVG polygons.
3. **Nested pieces were offset by 2px.** Nested greens were DOM children of
   the blue element, so CSS positioned them against the parent's *padding
   box* (inside its 2px border), while the collision maths assumed the
   parent's outer box. Fixed by dropping DOM nesting entirely — pieces are
   flat in the SVG with a logical parent/child relation.
4. **Containment inside a circular container used a rectangle test**, so a
   green could be "inside" a blue circle while visually poking out of it.
   Fixed with proper circle/polygon containment.

Drop targeting also now hit-tests the real shape: hovering the empty corner
of a circular container's bounding box no longer grabs that container.

Snap grid changed 30px -> 15px. 30px is too coarse to reach valid positions
inside a circular container (two greens side by side only fit at 15/75
offsets); 15 still divides every size in play (60/150/300) so every
flush-packed position remains reachable.

Level 2 raised from 10 to 12 greens: shape-accurate collision plus nesting
(4 in the blue square, 2 in the blue circle) makes 12 solvable, where the
old AABB board-strip-only ceiling was 10.

### Automated QA performed on the rewrite
All passing, run through the real drop pipeline
(`resolveTarget` -> `targetIsValid` -> commit):
- Rendered SVG geometry vs analytic collision geometry: max delta 0.00px
- Flush/adjacent shapes do not collide; genuine penetration does
- Diagonally-offset circles with overlapping bounding boxes correctly do NOT
  collide (the case AABB got wrong)
- Board bounds: flush at every edge valid, 1px past any edge invalid
- Circle container rejects a corner placement, accepts a centred one, and
  accepts two greens side by side
- Square container enforces the INSET clearance
- Shape-accurate drop targeting (bbox corner of a circle misses it)
- Full solve of level 1 (8 greens, no nesting needed) and level 2 (12 greens,
  6 nested) reaching the win state
- Parent drag carries children with the correct offset; DOM transform matches
  the computed world position
- Detach preserves world position; re-nest works; occupied cells rejected;
  flush-adjacent accepted
- All 10 pieces render visible pixels (regression test for the invisible
  triangles)

### Round 5 — dead zones, free staging, screenshot tooling

1. **Invisible dead band around container walls (reported as "the blue
   square's hitbox feels strange").** The maths was correct, but a 150px
   container only accepts pieces in `[15, 135]` once the INSET clearance and
   the snap grid are applied — and nothing on screen said so. Dragging a
   green toward the wall produced ~4 grid steps of unexplained red. Fixed
   two ways:
   - `bestSlot()` now searches outward from the pointer for the nearest
     valid grid slot (up to `SLOT_RINGS`), so the piece slides into the
     closest legal position instead of being rejected.
   - A dashed guide outlines the container's usable interior while dragging,
     making the clearance rule visible. It is exact for square and circular
     containers (the only ones in play); the polygon-shrink path is
     approximate and would need revisiting if triangular containers are added.
2. **Free staging outside the board.** Placement now resolves as
   nest -> board -> stage. Anything dropped outside the board parks there
   (grid-snapped, no overlaps, clear of the board's stroke), so assemblies
   can be built in the tray before being carried in.
3. **Could not drag placed pieces back out** — same root cause as (2): the
   only two outcomes used to be "valid board/nest position" or "snap back to
   where it was", so a placed piece was effectively glued down. Staging gives
   the drop a third legal outcome and the piece comes free.
4. **Screenshot tooling** (`shot.sh` + `?scenario=` URL params). The Browser
   pane has been unable to composite frames for several sessions; headless
   Chrome/Edge sidesteps it entirely and gives deterministic, repeatable
   captures. This round is the first that is **visually verified**, not just
   DOM-verified.

Note on rules: sibling pieces inside a container may sit flush against each
other (only the container wall enforces INSET). Requiring clearance between
siblings too would halve capacity at the current grid and break level 2 —
worth a deliberate design decision rather than leaving it implicit.

### Round 6 — container capacity = bounding box; snapping reverted

Both changes requested by the user.

1. **A container's interior is now its full bounding box, not its drawn
   outline** (`containerBox()`, `INSET = 0`). A blue circle therefore holds
   exactly as much as a blue square of the same size — a full 2x2 of greens
   instead of 2. Drop targeting uses the bbox too, so the circle's bbox
   corners are grabbable.
   **Visual consequence, deliberate:** pieces placed in a circular
   container's corners visibly extend past the drawn circle (see
   `shots/nest-l1.png`). Capacity is defined by the box, not the silhouette.
   Piece-vs-piece collision is still fully shape-accurate — only container
   capacity changed.
2. **Reverted the "slide into the nearest free slot" behaviour** added in
   round 5. That was invented, not requested. A piece now goes exactly where
   it is aimed (grid-snapped) or nowhere: an invalid aim shows red and the
   piece bounces back to where it came from, even when a free neighbouring
   cell exists. Verified: aiming at an occupied cell, past a container wall,
   or half-off the board are all rejected outright rather than relocated.

The dead band that motivated the round-5 slot search is gone anyway — with
bbox capacity and zero clearance, every grid position from the container
wall inward is valid, so there is nothing left to compensate for.

### Round 7 — one box model, portrait mobile layout

1. **Every piece is a box; inner and outer are the same box.** Round 6 left
   an inconsistency: a circle *occupied* its drawn circle (shape-accurate)
   but *held* its bounding box. Now `geomOf()` returns the square box for
   every shape, and it is the single source for occupation, containment and
   drop targeting alike. The circle/triangle/square art is a motif drawn
   inside the box.
   - The box is now **drawn** (translucent fill + outline) so the model is
     visible rather than implied. The debug overlay draws the same box.
   - **Trade-off to be aware of:** two diagonally-offset circles now collide
     even though the drawn circles clearly miss each other — the boxes
     overlap. This is the exact opposite of the round-4 behaviour, and it
     follows necessarily from "one shared box". Reverting is a one-line
     change: return the shape path from `geomOf()` — the SAT overlap and
     containment code still handles arbitrary convex shapes and circles.
2. **Portrait mobile-web layout.** SVG user space is a fixed 1080x1780
   canvas that scales to any screen (`preserveAspectRatio` + a flex stage),
   with `getScreenCTM()` used for pointer mapping so touch coordinates stay
   correct under any scaling. Touch targets are >=44px, `touch-action: none`
   stops scroll/zoom hijacking, and the page never scrolls.

**Bug caught by QA, not by eye:** at the old sizes the level-2 tray needed a
third row of greens, which pushed the blue row to y=1600..2000 — past the
1920 canvas bottom, silently clipping both blue pieces. Sizes were refit
(board 640, blue 320, green 160, canvas height 1780) so every level fits,
and there is now an automated check that no piece spills outside the canvas
on any level. Board and piece sizes still divide cleanly (640 = 4 greens =
2 blues), so flush packing is exact.

### Automated QA on rounds 6-7
- Every shape produces an identical box geometry (inner == outer)
- Circle and triangle containers hold the same 2x2 as the square container
- Flush neighbours do not collide; overlapping boxes do, for every shape
- Aiming at an occupied cell / past a container wall / half-off the board is
  rejected outright — no auto-relocation to a free neighbour
- No piece spills outside the canvas on any level
- `svgPoint()` round-trips screen <-> SVG coordinates under the responsive
  transform; the whole canvas is on screen; the page does not scroll
- Buttons meet the 44px touch minimum
- Both levels still solve (level 2: 8 nested + 4 on the board)

### Round 8 — reverted the box model; shape-accurate collision restored

**This was a misreading of feedback that needs to be flagged, not just
fixed.** Round 7's "every piece is a box" model was never requested — the
user's round-6/7 message was pointing out an *inconsistency* (a circle
occupied its drawn circle but held its bounding box), not asking for
everything to become a square. Turning collision into pure box-packing
removed the actual puzzle: with every shape colliding as its bounding box, a
circle and a triangle are just a square with a picture on them, and shape
choice stops mattering. The user caught this immediately ("what's left of
the puzzle-solving element?").

Reverted: `geomOf()` returns the real shape path again (circle geometry for
circles, the true polygon for square/triangle) — the same single function
that is now the entire collision model, so occupation, containment, and
drop-targeting are shape-accurate everywhere without needing three separate
fixes. The translucent "box" rendering is gone; the drawn shape and the
debug hitbox overlay are the same path again (see `shots/nest-l1-hitbox.png`
— dashed magenta traces the circle as a circle, the triangle as a triangle).

**Consequence, re-verified by simulation, not assumed:** at the current
mobile scale (green 160px, blue 320px — exactly 2x, tighter than the
original 2.5x ratio), a blue circle container can fit one centred green
comfortably (~113px from centre) but NOT two side by side (~179px from
centre, past the 160px radius). The blue *square* container still takes a
full 2x2 with zero slack (square-in-square has no diagonal loss). Level 2 is
solved using exactly this: 4 nested in the square, 0 in the circle, 8 on the
board — still 12/12, still verified via `autoSolve()` + `checkWin()`, not
just claimed.

Kept from round 7 (not reverted, not implicated in this bug): the portrait
mobile layout, `getScreenCTM()` touch mapping, and the exact-aim-or-bounce
drop behavior from round 6.

**Process note for next time:** when a user's phrasing is ambiguous between
"here's a bug" and "here's a new requirement," the round-4/5 pattern (state
the interpretation back in one sentence before implementing, e.g. "so you
want container capacity to equal the piece's bounding box, confirm?") would
have caught this before two rounds of work went the wrong way. See the new
project doc `docs/working-agreement.md` for the standing rule this produced.

### Round 9 — rotation, added on top of shape-accurate collision

Piece rotation in 90-degree steps (`piece.rotation`), so shape choice isn't
just "which silhouette" but "which silhouette, which way" — two triangles in
different orientations pack differently against neighbours.

- **Geometry**: `geomOf()` rotates the local shape path around its own
  centre before translating to world position; a circle ignores rotation
  (rotationally symmetric by definition), a square looks the same at 90/180/
  270 (harmless no-op), a triangle genuinely changes footprint. Rendering
  applies the identical `rotate(deg, cx, cy)` before `translate(...)` in the
  SVG transform, so drawn shape and hitbox can't drift apart.
- **Interaction**: tap-to-rotate, drag-to-move, sharing one pointer gesture
  (no separate rotate button/handle). Below `TAP_THRESHOLD` (12 real screen
  px) of movement, release rotates the piece 90 degrees in place; past it,
  the gesture becomes a normal drag and rotation never fires. A rotation is
  rejected (piece stays exactly as it was — no fallback repositioning) if
  the rotated shape would no longer fit in its current context (nested,
  on-board, or staged), checked with the same `validInside`/`validOnBoard`/
  `validStaged` functions everything else uses.

QA: rotated hitbox differs from unrotated and matches the rendered bbox
exactly; a point inside a triangle's tip before rotation is outside after a
90-degree turn (proves the collision shape actually turns, not just the
pixels); rotation succeeds when unobstructed and four quarter-turns return
to 0; rotation is rejected for a nested piece when it would poke out of its
container (re-validated on every single quarter-turn, not just the target
angle); a real drag (past the tap threshold) never rotates; both levels
still solve unmodified (default `rotation: 0` reproduces round-8 geometry
exactly, verified, not assumed).

### Round 10 — free (continuous) rotation, replacing the 90-degree tap

The user tried the quarter-turn tap-to-rotate from round 9 and asked for
free rotation instead ("I think that'll be much better"). Implemented as a
**separate drag handle**, not an extension of the tap gesture:

- A small knob + stem renders above each **green** piece (blue containers
  deliberately excluded — see below). Dragging the knob rotates the piece
  continuously by tracking the angle from the piece's centre to the
  pointer; dragging the piece body still moves it, exactly as before. The
  two are different DOM targets (`e.stopPropagation()` on the knob's
  pointerdown stops it from also bubbling into the move-drag), so there's
  no gesture ambiguity or shared threshold logic to get wrong.
- No angle snapping — genuinely continuous, per the request. Live feedback
  (green/red outline) previews validity while dragging, but nothing is
  blocked mid-drag; only the release angle is checked, and an invalid
  release reverts to the rotation the piece had before that specific drag
  (not to 0) — confirmed by sweeping a full 360-degree circle through the
  real event pipeline on a piece nested in a container corner: some angles
  reject-and-revert, others accept, and the piece never gets un-nested by a
  rotation attempt regardless of outcome.
- The math (`geomOf`'s rotation, unchanged since round 9) already supported
  arbitrary angles — SAT and point-in-polygon don't care about the angle
  being a multiple of 90. Free rotation only required new *interaction*
  code, not new *collision* code.
- **Scoped to green pieces only.** Rotating a blue container would require
  its nested children's world position to rotate around the container's own
  centre along with it, which `worldPos()` doesn't do (it just adds a fixed
  local offset) — correct compounding is straightforward but adds real
  complexity, and it's out of scope for "let me rotate the pieces I'm
  trying to fit." Flagging this per the working agreement rather than
  silently deciding it doesn't matter.

**QA methodology bug caught and fixed, not just the feature:** the first
verification pass compared `element.getBBox()` (which ignores the element's
OWN ancestor transforms) against `geomOf()`'s world-space output, and
"passed" at round 9's 90-degree angles only by coincidence — a triangle
inscribed in a square has the same axis-aligned bbox at every 90-degree
multiple, so the flawed comparison couldn't tell rotation was being ignored.
At a free angle (127 degrees) it failed loudly (32px off), which is what
caught it. Fixed by comparing in actual screen space via
`element.getScreenCTM()` on both the expected and rendered points — 0.00px
delta at eight tested angles including 37/127/233/311 degrees. Lesson: a
test that only ever runs at 90-degree-symmetric angles isn't testing
rotation, it's testing translation. Re-verify test methodology itself when
extending a feature's range, not just the feature.

### Round 11 — long-press to rotate, replacing the drag handle

The round-10 handle (small knob above each piece) was reported hard to hit
on a phone. Replaced with a long-press gesture on the piece itself — no
small target required:

- **pending** (just touched down) -> **moving** if the finger travels past
  `MOVE_THRESHOLD` (10 client px) before the timer fires, or ->
  **rotate-armed** if it holds still for `LONG_PRESS_MS` (380ms). A
  `navigator.vibrate(15)` tick fires on arming where supported, plus a
  yellow outline flash (`.rotate-armed`), since there's no handle position
  left to signal "you're now in rotate mode."
- Once armed, the finger must clear `ROTATE_DEADZONE` (24 world px) from the
  piece's centre before angle tracking starts — a press near dead-centre
  gives an unstable `atan2` reference otherwise. Rotation is **relative**:
  the angle the finger traces from wherever tracking started is added to
  whatever rotation the piece already had, not mapped to an absolute
  "up = 0" the way the old handle was (there's no fixed reference point
  anymore since press location varies).
- Same accept/reject rule as round 10: free spin during the drag, validity
  checked only at release, revert to the pre-drag rotation on a bad release
  or a `pointercancel`.

**Real bug found and fixed while re-verifying this round (not a test
artifact):** `beginMove()` was capturing the finger-to-piece offset (`dx`,
`dy`) from the *first move event that crossed the threshold* instead of
from the original `pointerdown`. If the finger had already travelled some
distance during the "pending" wait before crossing the threshold, the piece
would silently re-anchor to that later point — a visible jump on grab in
exactly the case that matters most here, since pending now waits for either
threshold-or-long-press instead of starting the drag immediately. Fixed by
capturing the down-point's SVG coordinates at `pointerdown` time and having
`beginMove()` read that stored value. Caught by testing the offset
explicitly (grab 20px off-corner, drag to a known target, assert the piece
lands with that same 20px offset preserved) rather than only checking "did
it move at all," which the bug would have passed.

QA: quick drag (moves before long-press fires) enters `moving`, never
rotates, and preserves the exact grab offset; long-press (real elapsed
time, not simulated) enters `rotate-armed`, produces zero visible jump on
the angle-establishing move, then rotates on subsequent motion while
position stays fixed; a plain tap released before `LONG_PRESS_MS` has zero
side effects and the pending timer doesn't fire late after release;
`pointercancel` reverts a move mid-drag and reverts a rotation mid-drag,
independently; a rotation attempt on a piece nested at a container corner
leaves the piece nested and geometrically valid regardless of accept/
reject outcome; both levels still solve unmodified.

### Round 12 — rotating a container now carries its contents with it

Reported: rotating the big cell (a blue container) didn't rotate the cells
nested inside it. Root cause: `localX`/`localY` were a flat world-space
delta captured once at nest time, reapplied unconditionally — correct for
the container *translating* (moving it and its children by the same amount
preserves their relationship regardless of rotation), but wrong for
*rotating*, since a rotation has to swing the children around the
container's centre, not leave them at a fixed offset.

Fixed by treating this as a standard parent/child transform, the same way
any scene graph does it:
- `localX`/`localY` are defined in the container's own **unrotated** local
  frame (the same frame `motifPath` uses for a piece at rotation 0), not in
  world space. `worldPos()` now rotates that local offset by the parent's
  *current* rotation, around the parent's centre, before translating by the
  parent's world position (`nestAtWorld` performs the inverse conversion at
  nest/re-nest time).
- A piece's own `.rotation` is relative to its parent (or to world space,
  if it has none) -- its **effective** rotation, used for both drawing and
  collision, is its own rotation plus every ancestor's (`effectiveRotation`,
  recursive though nesting is only ever 1 level deep here). `geomOf()` and
  `render()` both switched from reading `piece.rotation` directly to
  calling this.
- `detach()` (picking a nested piece up) now resolves `effectiveRotation`
  into an absolute value *before* clearing `parent`, so grabbing a piece out
  of a rotated container doesn't snap its visible angle.
- The blue-only restriction from round 10/11 is gone -- containers now use
  exactly the same long-press-to-rotate gesture as any other piece. It was
  never a deliberate design boundary, just the missing math; now that the
  math is correct, there's no remaining reason to exclude them.

**No extra validity check was needed for "does rotating a container still
fit its children."** Local-frame storage makes this invariant automatically:
if a child fit inside the container's shape before rotating, the same
*rigid* rotation of container-plus-child together still fits, by
construction -- rotating changes nothing about their relative geometry.
`checkRotationValid()` for a container only needs to check the container's
own shape against the board/siblings (already excluding its own children
via the `other.parent` check in `collidesWithOthers`), which was already
correct.

QA: rotating a container by a raw angle assignment moves its children to
positions matching the `rotatePt` formula exactly (not just "somewhere
different"); the *rendered* SVG position of a child inside a rotated parent
matches computed world geometry to sub-pixel precision; the same result
holds through the real long-press-and-arc gesture on the container itself,
including that children visibly move *during* the drag, not just after
release; picking up a child nested in an already-rotated container preserves
its absolute rotation exactly (no jump); rejecting an invalid drop re-nests
the child back at the exact pre-pickup world position; a container blocked
by a neighbour at some rotation angles and clear at others produces exactly
that pattern through the real gesture, with the child staying correctly
nested and the container staying board-valid regardless of outcome; both
levels still solve unmodified. See `shots/spun-l1-hitbox.png`.

### Round 13 — level-design system

Levels went from a single number (`{ green: 8 }`, shapes auto-cycling
square/circle/triangle) to explicit per-level composition:

```js
{
  name: 'Level 1',
  blues: ['square', 'circle'],   // exactly 2 -- see below
  greens: [
    { shape: 'square',   count: 3 },
    { shape: 'circle',   count: 3 },
    { shape: 'triangle', count: 2 },
  ],
}
```

**Structural rule, not a level-design choice:** exactly 2 blue containers.
The board is exactly `2*BLUE` wide and `buildLevel()` lays them out side by
side spanning it; a different count needs a layout change, not just a data
edit. Everything else is free: which shape each of the 2 blues is (Level 3
below uses two squares instead of one square + one circle), and the green
shape mix and total.

**`autoSolve()` is now a real feasibility check, not just a screenshot
helper.** It nests into both blue containers up to their known capacity
(`CONTAINER_SLOTS`: square = a zero-slack 2x2 = 4, circle = 1 centred --
both derived and verified in round 8), places the blues on the board, fills
the board strip (8 slots), and returns `{ won, unplacedCount, unplaced }`
instead of assuming success. Verified it correctly reports failure (not a
silent wrong success) on a deliberately-broken level asking for 20 greens
against a 13-capacity blue pair: `unplacedCount: 7`, `won: false`, and the
exact 7 leftover pieces listed.

**Capacity budget**, so a new level can be sized without guessing (all at
the current scale, GREEN=160 / BLUE=320 / BOARD=640):

| Source | Capacity |
|---|---|
| Board strip (below the 2 blues) | 8 (4 cols x 2 rows) |
| A SQUARE container | 4 (zero-slack 2x2) |
| A CIRCLE container | 1 (centred only) |
| A TRIANGLE container | *not pre-computed* -- see below |

Max total greens = 8 + (per-blue capacity by shape). Two squares -> 16
(Level 3). Square + circle -> 13 (Level 2 sits at 12, one under). Two
circles -> 10.

**Deliberate gap: no `triangle` entry in `CONTAINER_SLOTS`.** The
containment math (`shapeContains`) handles a triangle container correctly
-- nothing breaks -- but no known-good packed-slot layout has been derived
for one, so `autoSolve()` silently nests 0 pieces into it (empty slots
array) and treats its capacity as 0. A level wanting a triangle container is
possible today but must be **hand-verified** via the DBG console (drag
manually or compute slots the way round 8 did for the circle) before
shipping, not assumed solvable from the table above.

#### Adding a level

1. Append an entry to `LEVELS` with `name`, `blues` (array of exactly 2
   shapes), `greens` (array of `{shape, count}`).
2. Check it's within budget using the table above (or just run step 3 --
   it'll tell you).
3. Reload, then in the browser console:
   ```js
   DBG.level = <index>;
   DBG.autoSolve();   // -> { won: true, unplacedCount: 0, unplaced: [] }
   ```
   `won: false` means the level is over capacity (or uses an unhandled
   shape combination) -- shrink `greens` or change a blue's shape.
4. `./shot.sh solved <level-number-1-indexed>` for a visual sanity check.

This is the same verify-by-simulation discipline as every other round in
this file, just packaged as a reusable check instead of one-off console
snippets.

## Next steps
- User playtest with the actual debrief questions (hypothesis check, best/
  worst moment, surprise, PROCEED/PIVOT/KILL verdict) — still not done. This
  is the gate the whole prototype exists to reach.
- Open design question from the SAT rewrite: triangles and circles now pack
  meaningfully tighter than squares, so shape choice is a real mechanical
  lever. Level capacity has to be derived per shape mix, not from area alone.
