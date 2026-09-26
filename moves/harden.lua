local M = { id="HARDEN", name="Harden" }

-- Exact FireRed Move_HARDEN choreography. There is no custom OBJ art: FireRed
-- runs AnimTask_MetallicShine using the ROM-native metal_shine BG mask while
-- the attacker palette is converted to grayscale, and plays SE_M_HARDEN twice.
-- The shared stat-change system owns the subsequent Defense +1 feedback.
M.script = {
  { op="loopsewithpan", sound=113, pan="attacker", interval=28, count=2 }, -- SE_M_HARDEN
  { op="createvisualtask", task="AnimTask_MetallicShine", priority=5, args={0,0,0} },
  { op="waitforvisualfinish" },
  { op="end" },
}

return M
