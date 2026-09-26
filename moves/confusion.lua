local M = { id="CONFUSION", name="Confusion" }

M.soundIds = {177}

-- FireRed Move_CONFUSION. Reuses the Psychic move background and its palette
-- rotation, then distorts the target with shake + scale while SE_M_SUPERSONIC
-- plays from the target side.
M.script = {
  { op="monbg", battler="def_partner" },
  { op="fadetobg", bg="psychic" },
  { op="waitbgfadeout" },
  { op="createvisualtask", task="AnimTask_SetPsychicBackground", priority=5 },
  { op="waitbgfadein" },
  { op="setalpha", eva=8, evb=8 },
  { op="createvisualtask", task="AnimTask_ShakeMon2", priority=2, args={"attacker",1,0,10,1} },
  { op="createvisualtask", task="AnimTask_BlendColorCycle", priority=2, args={"attacker",0,2,0,8,{31,31,31}} },
  { op="waitforvisualfinish" },
  { op="playsewithpan", sound=177, pan="target" },
  { op="createvisualtask", task="AnimTask_ShakeMon", priority=2, args={"target",3,0,15,1} },
  { op="createvisualtask", task="AnimTask_ScaleMonAndRestore", priority=5, args={-4,-4,15,"target",1} },
  { op="waitforvisualfinish" },
  { op="clearmonbg", battler="def_partner" },
  { op="blendoff" },
  { op="delay", frames=1 },
  { op="restorebg" },
  { op="waitbgfadeout" },
  { op="setarg", index=7, value=0xFFFF },
  { op="waitbgfadein" },
  { op="end" },
}


return M
