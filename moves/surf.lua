local M = { id="SURF", name="Surf" }

M.soundIds = {156}

-- Canonical FireRed Move_SURF. The visual task owns the ROM-native moving
-- water layer; the sound starts after the native 24-frame script delay.
M.script = {
  { op="createvisualtask", task="AnimTask_CreateSurfWave", priority=2, args={false} },
  { op="delay", frames=24 },
  { op="panse", sound=156, from="attacker", to="target", increment=2, delay=0 },
  { op="waitforvisualfinish" },
  { op="end" },
}

return M
