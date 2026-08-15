# Changelog

## 1.0.0

- Initial release. Wraps `Camera.follow` to move the camera 8px left, putting
  the player's tile on the true horizontal centre instead of the ROM's
  column-4 approximation.
- Options: `CENTERED CAM` (master toggle), `X CENTRE` (the correction, default
  8), `Y NUDGE` (optional taste bias, default 0 — the vertical framing was
  already correct and is not touched).
