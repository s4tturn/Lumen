# MEMORY.md — Lumen

## Default Blob Constants

- **Layers**: 5
- **Opacity**: 0.5 (all states)
- **Blur**: 25 (inner layers only; outermost ring stays crisp)
- **Rims**: constant 0.7 solid white edge always on; separate 1.4 comet
  (glowing arc only, transparent elsewhere, swept along the outline itself)
  that melts into blur as the tint leaves excited and sharpens back on entry.
- **Tint**: white hardcoded for both states; no debug UI remains.
- **Morph duration**: 0.25 s (0.15 s under Reduce Motion)
- **Damping**: 80 (0 = 1:1 follow, 100 = pinned, cosine curve)

## Blob States (speed, displacement, radius fraction)

- **Neutral** (white): 0.5, 0.15, 0.25 — resting state, separate from cycle
- **A**: 0.8, 0.30, 0.30 — excited cycle base
- **B**: 1.3, 0.50, 0.15 — excited cycle peak
- Excited tint: user-picked color (8 swatches) blended from white via
  Blend slider (0 = white, 1 = full color); rim/track/arc follow the blend.

## Layout Guarantee

- Hitbox lives in `.overlay` + `.clipped`: it can overflow as the blob
  grows without ever contributing to layout size. Blob draws only
  (offset/Canvas never affect layout); the page scales on screen size alone.

## Hold & Cycle

- Still hold → 10 accelerating ticks (0.5 s) → 0.5 s pause → thump, state
  flips exactly on the thump → morph to excited + A (0.25 s). Cycle starts
  only on release: 4 s A→B, 7 s dwell, 8 s B→A, looping.
- Holding again at any point plays the mirror (10 decelerating ticks over
  0.5 s → pause → thump) and returns to neutral, killing the cycle.
- Tint/wobble/size ease on the render clock (Journey); speed is integrated.
- Purple commits set `isBreathing` + `Focus.hide(.ambient)`: paging locks,
  AmbientPlayer recedes (no hit-test/a11y), offscreen pages already stripped.
  White restores both.
