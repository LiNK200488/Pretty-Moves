local M = { id="SPLASH", name="Splash" }

-- Exact FireRed Move_SPLASH. AnimTask_Splash performs three 38-callback
-- squash/stretch hops on the attacker.  The shared battler-affine renderer
-- preserves the lower edge as FireRed's SetBattlerSpriteYOffsetFromYScale does.
M.script = {
  { op="createvisualtask", task="AnimTask_Splash", priority=2, args={"attacker",3} },
  { op="delay", frames=8 },
  { op="loopsewithpan", sound=160, pan="attacker", interval=38, count=3 }, -- SE_M_TAIL_WHIP
  { op="waitforvisualfinish" },
  { op="end" },
}

return M
