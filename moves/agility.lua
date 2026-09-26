local M = { id="AGILITY", name="Agility" }

-- FireRed Move_AGILITY choreography. Reuses the shared elliptical battler motion
-- and blended trace tasks already used by Quick Attack.
M.script = {
  { op="monbg", battler="atk_partner" },
  { op="setalpha", eva=12, evb=8 },
  { op="createvisualtask", task="AnimTask_TranslateMonEllipticalRespectSide", priority=2, args={"attacker",24,6,4,4} },
  { op="createvisualtask", task="AnimTask_TraceMonBlended", priority=2, args={0,4,7,10} },
  { op="playsewithpan", sound=128, pan="attacker" }, -- SE_M_DOUBLE_TEAM
  { op="delay", frames=12 },
  { op="playsewithpan", sound=128, pan="attacker" },
  { op="delay", frames=12 },
  { op="playsewithpan", sound=128, pan="attacker" },
  { op="delay", frames=12 },
  { op="playsewithpan", sound=128, pan="attacker" },
  { op="delay", frames=12 },
  { op="playsewithpan", sound=128, pan="attacker" },
  { op="delay", frames=12 },
  { op="waitforvisualfinish" },
  { op="clearmonbg", battler="atk_partner" },
  { op="blendoff" },
  { op="delay", frames=1 },
  { op="end" },
}

return M
