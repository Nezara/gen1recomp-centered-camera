-- Centered Camera
--
-- THIS IS AN X-AXIS FIX.  The Game Boy overworld is 10 tiles wide and 9 tall.
-- Nine is odd, so row 4 IS the middle row and the vertical framing is already
-- true -- there is nothing to correct there and the mod leaves it alone.  Ten
-- is even -- there is no middle column -- and the ROM resolves that by parking
-- the player in column 4 rather than the (non-existent) column 4.5.  That is
-- the whole source of the off-by-8: the player's tile sits at screen x 64..80,
-- centred on 72, while the screen's centre line is 80.
--
-- Y NUDGE exists only as an optional extra for anyone who wants to bias the
-- view up or down as a matter of taste.  It defaults to 0 and is not part of
-- the centring: vertically there is no error to fix.
--
-- src/render/Camera.lua does exactly that, generalised to any view size:
--
--   self.x = px - (viewW / 2 - 16)      -- tile centre lands on viewW/2 - 8
--   self.y = py - (viewH / 2 - 8)       -- tile centre lands on viewH/2
--
-- so the miss is a flat 8px left at EVERY view width -- 160, a wheel zoom-out,
-- a tilted view, a phone's window-filling world pass -- and one constant fixes
-- all of them.  Moving the camera 8px left moves the world (and the player
-- with it) 8px right, onto the centre line.
--
-- Patching Camera.follow rather than the overworld's call site is deliberate:
-- Camera instances are `setmetatable({}, Camera)` with `Camera.__index =
-- Camera`, so one patch reaches every camera ever made, before or after, and
-- that includes Gen 2's world (src/world/gen2/World.lua uses the same module
-- and the same 160x144 framing).  Gen 3 has its own renderer and is already
-- centred; see the Gen 3 section at the bottom.
--
-- Everything else in the overworld draws relative to cam.x/cam.y -- tiles,
-- border fill, connected-map strips, NPCs, ghosts, emotes, palette zones --
-- so they all move together and nothing needs a matching offset.  The one
-- place that looks like it hardcodes the old framing, the heal-machine light
-- show, is safe: it converts the cart's fixed OAM screen coordinates into
-- WORLD positions relative to the player's cell (`ha.px - 64`), then draws
-- those through the camera, so the overlay rides the shift along with the
-- machine tiles it has to stay glued to.

local mod = ...

-- gen1recomp's mod sandbox no longer exposes love.filesystem at all (the
-- engine author: mods that touch it stop loading outright in the next
-- release, with no permission that reopens it). The supported replacement,
-- mod.storage, needs a live game with a resolved playthrough -- which does
-- not exist yet at entry-chunk time, where this mod's own first log line
-- fires -- so log() buffers in memory and flushes opportunistically once a
-- game shows up. Read the log at
-- <savedir>/mod_storage/<version>/<playthroughId>/centered_camera/log.bin.
local LOG_KEY = "log"
local LOG_MAX_BYTES = 32 * 1024

local liveGame
local logBuf, logBytes, logLoaded = {}, 0, false

-- Declared as a local ahead of log() so log() can close over it as an
-- upvalue; assigned further down. A Lua local must exist before the code
-- that NAMES it, not merely before that code runs.
local flushLog

local function log(fmt, ...)
  local ok, msg = pcall(string.format, fmt, ...)
  if not ok then msg = tostring(fmt) end
  -- no `os` in the mod sandbox; love.timer is the available clock
  local line = string.format("[%8.2f] %s\n", love.timer.getTime(), msg)
  logBuf[#logBuf + 1] = line
  logBytes = logBytes + #line
  -- Trim in memory too, in case a game never shows up in this run (a boot
  -- that never gets past the launcher) so a long session still can't grow
  -- without bound.
  while logBytes > LOG_MAX_BYTES * 2 and #logBuf > 1 do
    logBytes = logBytes - #logBuf[1]
    table.remove(logBuf, 1)
  end
  flushLog()
end

flushLog = function()
  if not liveGame then return end
  local okCtx, ctx = pcall(function() return mod.storage:context(liveGame) end)
  if not (okCtx and ctx) then return end -- no playthrough resolved yet
  if not logLoaded then
    -- carry the previous session's tail across so the log stays continuous
    local okPrev, prev = pcall(function()
      return mod.storage:readBytes(liveGame, LOG_KEY)
    end)
    logLoaded = true
    if okPrev and type(prev) == "string" and prev ~= "" then
      table.insert(logBuf, 1, prev)
      logBytes = logBytes + #prev
    end
  end
  local body = table.concat(logBuf)
  if #body > LOG_MAX_BYTES then body = body:sub(-LOG_MAX_BYTES) end
  local ok = pcall(function()
    return mod.storage:writeBytes(liveGame, LOG_KEY, body)
  end)
  if ok then logBuf, logBytes = { body }, #body end
end

mod.events:on("game.ready", function(ev)
  liveGame = (ev and ev.game) or liveGame
  flushLog()
end)

log("entry: main.lua start")

-- ---------------------------------------------------------------- options --

local DEFAULTS = { enabled = true, shift_x = 8, shift_y = 0, gba_x = 0 }

-- live values, refreshed out of the options store rather than read per frame
local opts = { enabled = true, shift_x = 8, shift_y = 0, gba_x = 0 }

-- ONE define call: mod.options:define REPLACES the whole set every time it is
-- called, it does not merge.
mod.options:define({
  { key = "enabled", label = "CENTERED CAM", type = "toggle",
    default = DEFAULTS.enabled },
  -- The mod's actual job.  Positive = camera moves left = the player sits
  -- further RIGHT than vanilla.  8 is the true centre, 0 is the ROM's framing.
  { key = "shift_x", label = "X CENTRE", type = "number",
    default = DEFAULTS.shift_x, min = -16, max = 16, step = 1 },
  -- Optional extra, off by default: vanilla is already vertically centred, so
  -- this corrects nothing -- it is purely a taste bias up or down.
  { key = "shift_y", label = "Y NUDGE", type = "number",
    default = DEFAULTS.shift_y, min = -16, max = 16, step = 1 },
  -- Gen 3 only. The GBA field is already truly centred on both axes, so
  -- there is nothing to correct and this defaults to 0 -- it is a taste
  -- bias like Y NUDGE. Positive = the player sits further right.
  { key = "gba_x", label = "GBA X NUDGE", type = "number",
    default = DEFAULTS.gba_x, min = -16, max = 16, step = 1 },
})

local function number(value, fallback)
  value = tonumber(value)
  if not value or value ~= value then return fallback end -- also rejects NaN
  return value
end

local function refresh()
  local ok, err = pcall(function()
    opts.enabled = mod.options:get("enabled")
    if opts.enabled == nil then opts.enabled = DEFAULTS.enabled end
    opts.shift_x = number(mod.options:get("shift_x"), DEFAULTS.shift_x)
    opts.shift_y = number(mod.options:get("shift_y"), DEFAULTS.shift_y)
    opts.gba_x = number(mod.options:get("gba_x"), DEFAULTS.gba_x)
  end)
  if not ok then
    log("options refresh failed: %s", tostring(err))
    return
  end
  log("options: enabled=%s shift_x=%s shift_y=%s gba_x=%s",
      tostring(opts.enabled), tostring(opts.shift_x), tostring(opts.shift_y),
      tostring(opts.gba_x))
end

-- Read once now, then again at each point the stored values could have landed
-- or changed: the manager writes them back after the mod chunk has run.
refresh()
mod.events:on("mod.options_changed", function() refresh() end)
mod.events:on("mods.loaded", function() refresh() end)
mod.events:on("game.ready", function() refresh() end)

-- ------------------------------------------------------------- the patch --

-- Which generation is booted decides which renderer gets patched. The loader
-- gates mods per game, so by the time this chunk runs the version is set.
local generation = 1
do
  local okGV, GameVersion = pcall(require, "src.core.GameVersion")
  if okGV and type(GameVersion) == "table" and GameVersion.generation then
    local okGen, gen = pcall(GameVersion.generation)
    if okGen and tonumber(gen) then generation = tonumber(gen) end
  end
end
log("booted generation %d", generation)

-- Gen 1 and Gen 2 (Red/Blue/Yellow, Gold/Silver/Crystal) -------------------
--
-- Both overworlds -- src/world/OverworldController.lua and
-- src/world/gen2/World.lua -- build their camera from src.render.Camera and
-- frame the same 160x144 screen, so they share the off-by-8 and one patch
-- fixes both.

local function patchGameBoy()
  local ok, Camera = pcall(require, "src.render.Camera")
  if not ok or type(Camera) ~= "table" or type(Camera.follow) ~= "function" then
    log("FAILED: could not reach src.render.Camera (%s) -- GB patch inert",
        tostring(Camera))
    return
  end

  local baseFollow = Camera.follow

  function Camera:follow(px, py, viewW, viewH)
    baseFollow(self, px, py, viewW, viewH)
    if opts.enabled then
      -- left is negative x: a smaller camera x draws the world further right,
      -- carrying the player onto the centre line
      self.x = self.x - opts.shift_x
      self.y = self.y - opts.shift_y
    end
  end

  log("patched Camera.follow")
end

-- Gen 3 (FireRed/LeafGreen, Ruby/Sapphire/Emerald) --------------------------
--
-- The GBA field does not use src.render.Camera. src/core/game3/field_view.lua
-- frames it directly:
--
--   camX = floor(px + CELL / 2 - canvasW / 2)
--   camY = floor(py + CELL / 2 - canvasH / 2)
--
-- i.e. the player's 16x16 cell centre lands exactly on the canvas centre on
-- BOTH axes (240x160 is 15 cells wide -- odd -- and the cart's
-- PLAYER_SCREEN_Y of 72 already splits the even 10 rows). There is no
-- off-by-8 to correct, so X CENTRE does nothing here and the player stays
-- where the cart put them. The nudges still apply, as the same taste bias.
--
-- The only knob into that framing is FieldView.cameraPanX/Y, which cart
-- scripts own (camera pans, elevator shake, Emerald's camera object). So the
-- nudge is added for the duration of one draw and the scripts' value put
-- back afterwards -- the same seam src/core/game3/camera_object.lua uses.
-- Pan is camera-space: +pan moves the world left, so the sign is flipped to
-- keep "positive = player moves right / down" consistent with the GB games.

local gbaPatched = false

local function patchGba()
  if gbaPatched then return true end
  local ok, FieldView = pcall(require, "src.core.game3.field_view")
  if not ok or type(FieldView) ~= "table" or type(FieldView.draw) ~= "function" then
    log("could not reach src.core.game3.field_view (%s) -- will retry",
        tostring(FieldView))
    return false
  end

  local baseDraw = FieldView.draw

  FieldView.draw = function(game, canvasW, canvasH, drawOpts)
    local dx = opts.enabled and -opts.gba_x or 0
    local dy = opts.enabled and -opts.shift_y or 0
    if dx == 0 and dy == 0 then
      return baseDraw(game, canvasW, canvasH, drawOpts)
    end
    local bx = FieldView.cameraPanX or 0
    local by = FieldView.cameraPanY or 0
    FieldView.cameraPanX, FieldView.cameraPanY = bx + dx, by + dy
    local okDraw, err = pcall(baseDraw, game, canvasW, canvasH, drawOpts)
    -- only restore if nothing inside the draw re-set the pan itself
    if FieldView.cameraPanX == bx + dx then FieldView.cameraPanX = bx end
    if FieldView.cameraPanY == by + dy then FieldView.cameraPanY = by end
    if not okDraw then error(err, 0) end
  end

  gbaPatched = true
  log("patched FieldView.draw")
  return true
end

if generation >= 3 then
  if not patchGba() then
    mod.events:on("game.ready", function() patchGba() end)
  end
else
  patchGameBoy()
end

log("main.lua done")
