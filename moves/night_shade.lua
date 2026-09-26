local M = { id="NIGHT_SHADE", name="Night Shade" }

-- FireRed Move_NIGHT_SHADE.
M.soundIds = {182, 185}

M.script = {
  { op="monbg", battler="attacker" },
  { op="splitbgprio", battler="attacker" },
  { op="playsewithpan", sound=182, pan="attacker" }, -- SE_M_PSYBEAM
  { op="fadetobg", bg="ghost" },
  { op="waitbgfadein" },
  { op="delay", frames=10 },
  { op="playsewithpan", sound=185, pan="attacker" }, -- SE_M_LEER
  { op="createvisualtask", task="AnimTask_NightShadeClone", priority=5, args={85} },
  { op="delay", frames=70 },
  { op="createvisualtask", task="AnimTask_ShakeMon2", priority=2, args={"target",2,0,12,1} },
  { op="createvisualtask", task="AnimTask_BlendColorCycle", priority=2, args={"target",0,2,0,13,{0,0,0}} },
  { op="waitforvisualfinish" },
  { op="clearmonbg", battler="attacker" },
  { op="delay", frames=1 },
  { op="restorebg" },
  { op="waitbgfadein" },
  { op="end" },
}

return M
