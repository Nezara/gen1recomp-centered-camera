# Centered Camera

Puts the player on the **true horizontal centre** of the screen.

Works on every game gen1recomp runs:

| Games | What the mod does |
| --- | --- |
| Red / Blue / Yellow (Gen 1) | Fixes the 8px horizontal miss. |
| Gold / Silver / Crystal (Gen 2) | Fixes the same 8px miss: same camera, same 160x144 screen. |
| FireRed / LeafGreen / Ruby / Sapphire / Emerald (Gen 3) | Nothing to fix, because the GBA field is already centred on both axes. The nudges still work if you want a bias. |

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
| `Y NUDGE` | 0 | Optional extra, off by default. Corrects nothing — vanilla is already vertically centred — it just biases the view up or down if you want that. Applies on every game. |
| `GBA X NUDGE` | 0 | Gen 3 only. Optional left/right bias; positive moves the player right. `X CENTRE` is not used on Gen 3, which has no off-by-8. |

## Gen 3

The GBA field doesn't go through `src/render/Camera.lua`. Instead,
`src/core/game3/field_view.lua` frames it directly:

```lua
camX = floor(px + CELL / 2 - canvasW / 2)
camY = floor(py + CELL / 2 - canvasH / 2)
```

That puts the centre of the player's 16x16 cell exactly on the canvas centre.
240px is 15 cells, an odd number, so a middle column exists. Vertically, the
cart's `PLAYER_SCREEN_Y = 72` already splits the 10 rows evenly. So Gen 3 has
nothing to correct.

For the nudges, the mod wraps `FieldView.draw`. It adds its offset to
`FieldView.cameraPanX/Y` for the length of one draw and then restores the
value the cart's scripts set. That is the same seam the engine's own
`camera_object.lua` uses, so script camera pans, elevator shakes and
Emerald's camera object all keep working.

## Notes

- Gen 2 is covered by the same patch: `src/world/gen2/World.lua` uses the
  same `Camera` module and the same 160x144 framing. The manifest declares
  `"games": ["gen1", "gen2", "gen3"]`, so the loader runs the mod on all of them.
- 8 is a whole 8x8 tile, so the render stays perfectly pixel- and tile-aligned;
  there is no sub-pixel shimmer. What does change is 16x16 *block* alignment:
  the left and right edges now show a half-cut column of blocks. That is
  unavoidable — it is exactly what centring on an even-width screen means.
- Custom 3D render pipelines (e.g. PotatoVoxel) project through their own
  camera and are unaffected.
- Writes `centered_camera.log` in the save directory on load.
