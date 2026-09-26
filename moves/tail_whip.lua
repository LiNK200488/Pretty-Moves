local M = { id="TAIL_WHIP", name="Tail Whip" }

-- Exact FireRed Move_TAIL_WHIP choreography. Tail Whip has no separate OBJ
-- artwork: FireRed moves the attacker battler itself along an ellipse and plays
-- SE_M_TAIL_WHIP three times. The shared stat-change system owns the subsequent
-- Defense-drop feedback.
M.script = {
  { op="loopsewithpan", sound=160, pan="attacker", interval=24, count=3 }, -- SE_M_TAIL_WHIP
  { op="createvisualtask", task="AnimTask_TranslateMonEllipticalRespectSide", priority=2, args={"attacker",12,4,2,3} },
  { op="waitforvisualfinish" },
  { op="end" },
}

return M
