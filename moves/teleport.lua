local M = { id="TELEPORT", name="Teleport" }

M.soundIds = {196}

-- FireRed Move_TELEPORT. SetPsychicBackground is expanded inline so the shared
-- background/palette path remains identical to Psychic/Psybeam. The Teleport
-- visual task keeps running while the background begins restoring after 15f.
M.script = {
  { op="fadetobg", bg="psychic" },
  { op="waitbgfadeout" },
  { op="createvisualtask", task="AnimTask_SetPsychicBackground", priority=5 },
  { op="waitbgfadein" },

  { op="createvisualtask", task="AnimTask_Teleport", priority=2 },
  { op="playsewithpan", sound=196, pan="attacker" },
  { op="delay", frames=15 },

  { op="restorebg" },
  { op="waitbgfadeout" },
  { op="setarg", index=7, value=0xFFFF },
  { op="waitbgfadein" },
  { op="waitforvisualfinish" },
  { op="end" },
}

return M
