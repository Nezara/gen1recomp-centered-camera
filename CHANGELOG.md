# Changelog

## 1.1.0

- Gen 2 and Gen 3 support. The manifest now declares
  `"games": ["gen1", "gen2", "gen3"]`. Before this, the loader only ran the mod
  on Gen 1.
- Gen 2 (Gold/Silver/Crystal): the existing `Camera.follow` patch applies
  as-is, because the Gen 2 overworld uses the same camera and screen size.
- Gen 3 (FRLG/RSE): the GBA field is already truly centred, so nothing is
  corrected. A new `FieldView.draw` wrapper applies `Y NUDGE` and the new
  `GBA X NUDGE` option as a taste bias. The wrapper preserves the camera
  pans that scripts set.
- The mod checks which generation is booted and patches only the renderer
  that game uses.

## 1.0.1

- gen1recomp's mod sandbox stopped allowing `love.filesystem` (the debug log
  was the only use). Rewritten onto `mod.storage`, which needs a live game to
  resolve, so the logger now buffers in memory until one exists. No gameplay
  change -- this only affects where the diagnostic log file lives.

## 1.0.0

- Initial release. Wraps `Camera.follow` to move the camera 8px left, putting
  the player's tile on the true horizontal centre instead of the ROM's
  column-4 approximation.
- Options: `CENTERED CAM` (master toggle), `X CENTRE` (the correction, default
  8), `Y NUDGE` (optional taste bias, default 0 — the vertical framing was
  already correct and is not touched).
