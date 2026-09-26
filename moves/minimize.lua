local M = { id="MINIMIZE", name="Minimize" }

M.soundIds = {197}

-- Exact FireRed Move_MINIMIZE choreography. AnimTask_Minimize performs three
-- 32-callback shrink passes. Each pass leaves three 16-frame translucent
-- battler traces, then the third pass holds the tiny attacker before growing
-- it smoothly back to normal.
M.script = {
  { op="setalpha", eva=10, evb=8 },
  { op="createvisualtask", task="AnimTask_Minimize", priority=2, args={} },
  { op="loopsewithpan", sound=197, pan="attacker", interval=34, count=3 }, -- SE_M_MINIMIZE
  { op="waitforvisualfinish" },
  { op="blendoff" },
  { op="end" },
}

return M
