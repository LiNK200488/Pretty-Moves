local M = { id="MEDITATE", name="Meditate" }

M.soundIds = {155,145}

-- FireRed Move_MEDITATE. SetPsychicBackground is expanded inline so the
-- shared psychic-background path matches Psychic/Teleport. The attacker then
-- runs the exact 40-frame native affine sequence from
-- sAffineAnim_MeditateStretchAttacker: (-8,+10)x16, (+18,-18)x16,
-- (-20,+16)x8, with the original two sound cues.
M.script = {
  { op="fadetobg", bg="psychic" },
  { op="waitbgfadeout" },
  { op="createvisualtask", task="AnimTask_SetPsychicBackground", priority=5 },
  { op="waitbgfadein" },

  { op="createvisualtask", task="AnimTask_MeditateStretchAttacker", priority=2 },
  { op="playsewithpan", sound=155, pan="attacker" }, -- SE_M_HEADBUTT
  { op="delay", frames=16 },
  { op="playsewithpan", sound=145, pan="attacker" }, -- SE_M_TAKE_DOWN
  { op="waitforvisualfinish" },

  { op="restorebg" },
  { op="waitbgfadeout" },
  { op="setarg", index=7, value=0xFFFF },
  { op="waitbgfadein" },
  { op="end" },
}

return M
