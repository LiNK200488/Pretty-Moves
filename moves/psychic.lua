local M = { id="PSYCHIC_M", name="Psychic" }

M.soundIds = {177}

-- FireRed Move_PSYCHIC. Reuses the Psychic background + palette rotation used
-- by Psybeam/Confusion, then applies the stronger Psychic-specific attacker
-- tint and target distortion while SE_M_SUPERSONIC loops from the target side.
M.script = {
  { op="monbg", battler="def_partner" },
  { op="fadetobg", bg="psychic" },
  { op="waitbgfadeout" },
  { op="createvisualtask", task="AnimTask_SetPsychicBackground", priority=5 },
  { op="waitbgfadein" },
  { op="setalpha", eva=8, evb=8 },
  { op="createvisualtask", task="AnimTask_ShakeMon2", priority=2, args={"attacker",1,0,10,1} },
  { op="createvisualtask", task="AnimTask_BlendColorCycle", priority=2, args={"attacker",0,2,0,8,{31,23,0}} },
  { op="waitforvisualfinish" },
  { op="loopsewithpan", sound=177, pan="target", interval=10, count=3 },
  { op="createvisualtask", task="AnimTask_ShakeMon", priority=2, args={"target",5,0,15,1} },
  { op="createvisualtask", task="AnimTask_ScaleMonAndRestore", priority=5, args={-6,-6,15,"target",1} },
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
