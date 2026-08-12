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

## Next steps
- User playtest with the actual debrief questions (hypothesis check, best/
  worst moment, surprise, PROCEED/PIVOT/KILL verdict) — still not done. This
  is the gate the whole prototype exists to reach.
- Open design question from the SAT rewrite: triangles and circles now pack
  meaningfully tighter than squares, so shape choice is a real mechanical
  lever. Level capacity has to be derived per shape mix, not from area alone.
