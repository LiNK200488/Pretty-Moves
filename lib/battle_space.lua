-- Shared FireRed -> Gen1Recomp battle-space conversion.
--
-- FireRed renders battle choreography in a 240 px wide GBA battle field while
-- Gen1Recomp presents the equivalent battle field at 160 px. Only geometry
-- authored in FireRed *screen/background space* gets the 2/3 presentation
-- conversion. Battler-local sprite sizes, OAM dimensions, and battler-relative
-- motion remain 1:1 unless FireRed source explicitly says otherwise.
local M = {}

M.FIRERED_BATTLE_WIDTH = 240
M.HOST_BATTLE_WIDTH = 160
M.SCREEN_SCALE = M.HOST_BATTLE_WIDTH / M.FIRERED_BATTLE_WIDTH -- 2/3

M.SPACE_SCREEN = "screen"
M.SPACE_BATTLER = "battler"

function M.scaleFor(space)
  if space == nil or space == M.SPACE_BATTLER then return 1 end
  if space == M.SPACE_SCREEN then return M.SCREEN_SCALE end
  error("unknown FireRed coordinate space: " .. tostring(space))
end

function M.length(value, space)
  return (tonumber(value) or 0) * M.scaleFor(space)
end

-- Use for an imported ROM image/composite whose complete presentation belongs
-- to FireRed screen/background space. This never resizes or redesigns the ROM
-- source asset; it only tells the renderer how large that source is presented.
function M.displayScale(space)
  return M.scaleFor(space)
end

-- ROM-derived OBJ/sprite art keeps its native GBA pixel size. Screen/background
-- geometry still uses SCREEN_SCALE, but move/status sprites have one global base
-- presentation rule: 1 FireRed OBJ pixel = 1 host battle-canvas pixel. Native
-- FireRed affine transforms are applied on top of this base scale by the renderer.
function M.spriteDisplayScale()
  return 1
end

return M
