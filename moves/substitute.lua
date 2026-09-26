local M={id="SUBSTITUTE",name="Substitute"}
-- SE_M_BUBBLE2 is callback-owned by AnimTask_MonToSubstituteDoll.
M.soundIds={118}
M.script={
  {op="playsewithpan",sound=219,pan="attacker"},
  {op="createvisualtask",task="AnimTask_MonToSubstitute",priority=2,args={}},
  {op="end"},
}
return M
