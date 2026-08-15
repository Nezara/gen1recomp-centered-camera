# Centered Camera

Puts the player on the **true horizontal centre** of the screen.

## The off-by-8

The Game Boy overworld is 10 tiles wide and 9 tall.

- **9 rows is odd**, so row 4 genuinely is the middle row. The vertical framing
  was always correct, and this mod does not touch it.
- **10 columns is even**, so there is no middle column at all. The ROM has to
  pick a side, and it picks column 4 — putting the player's tile at screen
  x 64..80, centred on 72, when the screen's centre line is 80.

That is the entire 8-pixel miss, and it is a resolution artefact rather than a
design choice: on a 10-column screen there is no column to be centred in.

## The fix

`src/render/Camera.lua` generalises the ROM's framing to any view size:

```lua
self.x = px - (viewW / 2 - 16)   -- player's tile centre -> viewW/2 - 8
self.y = py - (viewH / 2 - 8)    -- player's tile centre -> viewH/2
```

The horizontal miss is therefore a flat 8px at **every** view width — the
plain 160px view, a wheel zoom-out, a tilted view, a phone's window-filling
world pass — so one constant corrects all of them. The mod wraps
`Camera.follow` and subtracts the offset after the engine's own follow has run,
which is why it survives zoom, tilt and window changes for free.

Moving the camera 8px left moves the world, and the player with it, 8px right.

## Options

| Option | Default | What it does |
| --- | --- | --- |
| `CENTERED CAM` | ON | Master toggle. OFF restores vanilla framing exactly. |
| `X CENTRE` | 8 | The correction. **8 = true centre**, 0 = the ROM's own framing. |
| `Y NUDGE` | 0 | Optional extra, off by default. Corrects nothing — vanilla is already vertically centred — it just biases the view up or down if you want that. |

## Notes

- Applies to Gold as well as Red/Blue: `src/world/gen2/World.lua` uses the same
  `Camera` module and the same 160x144 framing.
- 8 is a whole 8x8 tile, so the render stays perfectly pixel- and tile-aligned;
  there is no sub-pixel shimmer. What does change is 16x16 *block* alignment:
  the left and right edges now show a half-cut column of blocks. That is
  unavoidable — it is exactly what centring on an even-width screen means.
- Custom 3D render pipelines (e.g. PotatoVoxel) project through their own
  camera and are unaffected.
- Writes `centered_camera.log` in the save directory on load.
