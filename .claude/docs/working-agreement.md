# Working Agreement

Standing rules for how Claude should work in this project. Edit this file
directly to add, sharpen, or remove a rule — it is loaded every session via
`CLAUDE.md`, so nothing here needs to be repeated in chat.

## 1. Ambiguous feedback is not an invitation to redesign

If a message could be read either as "here's a bug" or "here's a new
requirement," **state the interpretation back in one sentence before
implementing**, especially before a change that touches architecture (a
collision model, a data model, a core algorithm). Do not silently pick the
more sweeping interpretation and run with it.

- Why: round 7 of the nesting-blocks prototype read "the inner and outer
  bounding box should be the same, imagine it as one shared box" as a
  request to make every shape's *collision* a square bounding box. It was
  actually a bug report about one inconsistency (a circle occupied its
  drawn circle but held its bounding box). The result deleted the game's
  actual puzzle mechanic for two rounds before being caught and reverted.
  See `prototypes/nesting-blocks-concept/README.md`, round 8.
- How to apply: when a request could expand scope, name the narrow reading
  and the broad reading and ask which one, or default to the narrow one and
  say so ("I'm reading this as X, not Y — flag me if you meant Y").

## 2. Change exactly what was asked, nothing adjacent

Don't fold in "while I'm in here" improvements to code, UI, or mechanics
that weren't part of the request, even when they seem like an obvious
follow-on. Flag them separately instead of bundling them into the same edit.

- Why: several rounds on this prototype introduced unrequested behavior
  (auto-slide-to-nearest-slot, then the box model) alongside the fix that
  was actually asked for, which made it harder to tell what changed and why,
  and required a full extra round to disentangle.
- How to apply: if a fix naturally suggests a second improvement, say so and
  ask, rather than shipping both in one pass.

## 3. Verify by simulation, not by hand-derivation alone

Before claiming a level/config/layout works (or before shipping a change
that could break one that used to work), run it through the actual code
path — not just mental math — and show the result.

- Why: this project's QA-via-browser-console pattern has repeatedly caught
  real bugs that hand math would have missed or gotten subtly wrong (e.g.
  the round-6→7 canvas resize that silently clipped both blue pieces off
  the bottom of the screen; the round-8 circle-capacity math that needed
  confirming against the *new* mobile scale, not the original one).
  Keep doing this — it has been working. Don't regress to "should work."
- How to apply: for this prototype specifically, use `window.DBG` in the
  browser console (see `prototypes/nesting-blocks-concept/prototype.html`)
  and/or `./shot.sh` for a real screenshot before reporting a fix as done.

## 4. When in doubt about scope or interpretation, ask first

A short clarifying question before a multi-file or architectural change
costs one message. Guessing wrong costs a full round of rework plus the
user's trust that unattended changes stay in bounds.
