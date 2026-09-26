local M = { id="GROWTH", name="Growth" }

-- Exact FireRed Move_GROWTH choreography. GrowthEffect is called twice.
-- Each pass flashes the attacker palette toward white while scaling the battler
-- up and restoring it, accompanied by SE_M_TAKE_DOWN.
M.script = {
  { op="createvisualtask", task="AnimTask_BlendColorCycle", priority=2,
    args={"attacker",0,2,0,8,{31,31,31}} },
  { op="playsewithpan", sound=145, pan="attacker" }, -- SE_M_TAKE_DOWN
  { op="createvisualtask", task="AnimTask_ScaleMonAndRestore", priority=5,
    args={-3,-3,16,"attacker",0} },
  { op="waitforvisualfinish" },

  { op="createvisualtask", task="AnimTask_BlendColorCycle", priority=2,
    args={"attacker",0,2,0,8,{31,31,31}} },
  { op="playsewithpan", sound=145, pan="attacker" }, -- SE_M_TAKE_DOWN
  { op="createvisualtask", task="AnimTask_ScaleMonAndRestore", priority=5,
    args={-3,-3,16,"attacker",0} },
  { op="waitforvisualfinish" },
  { op="end" },
}

return M
