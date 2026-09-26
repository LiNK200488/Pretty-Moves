local M = { id="HAZE", name="Haze" }

M.soundIds = {239}

-- FireRed Move_HAZE: start the horizontally scrolling fog BG, play SE_M_HAZE,
-- darken both battlers after 30 frames, hold, then restore them.  The fog task
-- owns its native fade-in/hold/fade-out timing independently.
M.script = {
  { op="waitforvisualfinish" },
  { op="playsewithpan", sound=239, pan=0 }, -- SE_M_HAZE
  { op="createvisualtask", task="AnimTask_HazeScrollingFog", priority=5 },
  { op="delay", frames=30 },
  { op="createvisualtask", task="AnimTask_BlendBattleAnimPal", priority=10,
    args={"both",2,0,16,"black"} },
  { op="delay", frames=90 },
  { op="createvisualtask", task="AnimTask_BlendBattleAnimPal", priority=10,
    args={"both",1,16,0,"black"} },
  { op="end" },
}

return M
