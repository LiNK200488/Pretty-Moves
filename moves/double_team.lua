local M = { id="DOUBLE_TEAM", name="Double Team" }

-- Exact FireRed Move_DOUBLE_TEAM choreography. AnimTask_DoubleTeam creates two
-- dark blended clones of the attacker in opposite phases and drives their
-- horizontal offsets with FireRed's nested sine-table calculation for 130
-- callbacks. RBY evasion mechanics remain entirely host-owned.
M.script = {
  { op="monbg", battler="atk_partner" },
  { op="setalpha", eva=12, evb=8 },
  { op="createvisualtask", task="AnimTask_DoubleTeam", priority=2, args={} },
  { op="playsewithpan", sound=128, pan="attacker" }, -- SE_M_DOUBLE_TEAM
  { op="delay", frames=32 },
  { op="playsewithpan", sound=128, pan="attacker" },
  { op="delay", frames=24 },
  { op="playsewithpan", sound=128, pan="attacker" },
  { op="delay", frames=16 },
  { op="playsewithpan", sound=128, pan="attacker" },
  { op="delay", frames=8 },
  { op="playsewithpan", sound=128, pan="attacker" },
  { op="delay", frames=8 },
  { op="playsewithpan", sound=128, pan="attacker" },
  { op="delay", frames=8 },
  { op="playsewithpan", sound=128, pan="attacker" },
  { op="delay", frames=8 },
  { op="playsewithpan", sound=128, pan="attacker" },
  { op="delay", frames=8 },
  { op="playsewithpan", sound=128, pan="attacker" },
  { op="waitforvisualfinish" },
  { op="clearmonbg", battler="atk_partner" },
  { op="blendoff" },
  { op="delay", frames=1 },
  { op="end" },
}

return M
