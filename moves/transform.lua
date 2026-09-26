local M = { id="TRANSFORM", name="Transform" }

M.soundIds = {196,197}

-- Exact FireRed Move_TRANSFORM intro. The animation task applies the native
-- OBJ mosaic ramp to the attacker; the battle engine remains responsible for
-- the actual Transform species/state change.
M.script = {
  { op="monbg", battler="attacker" },
  { op="playsewithpan", sound=196, pan="attacker" }, -- SE_M_TELEPORT
  { op="waitplaysewithpan", sound=197, pan="attacker", wait=48 }, -- SE_M_MINIMIZE
  { op="createvisualtask", task="AnimTask_TransformMon", priority=2, args={0} },
  { op="waitforvisualfinish" },
  { op="clearmonbg", battler="attacker" },
  { op="end" },
}

return M
