-- Declarative mapping from Gen1Recomp's generic battle hit-feedback SFX ids
-- to exact FireRed SFX ids. Keep this separate from per-move choreography.
-- Gen1Recomp exposes exactly three generic hit cues: Damage / Super / NotVery.
local M = {}

M.overrides = {
  Damage  = { soundId = 13, pan = 0 }, -- FireRed SE_EFFECTIVE
  Super   = { soundId = 14, pan = 0 }, -- FireRed SE_SUPER_EFFECTIVE
  NotVery = { soundId = 12, pan = 0 }, -- FireRed SE_NOT_EFFECTIVE
}

return M
