local M = { id="WRAP", name="Wrap" }

-- FireRed Move_WRAP. The attacker traces a small ellipse twice, then shares
-- BindWrap's target squeeze choreography and SE_M_BIND sound.
M.script = {
  { op="createvisualtask", task="AnimTask_TranslateMonEllipticalRespectSide", priority=2,
    args={"attacker",6,4,2,4} },
  { op="playsewithpan", sound=163, pan="target" }, -- SE_M_BIND
  { op="createvisualtask", task="AnimTask_ScaleMonAndRestore", priority=5, args={10,-5,5,"target",0} },
  { op="delay", frames=16 },
  { op="createvisualtask", task="AnimTask_ScaleMonAndRestore", priority=5, args={10,-5,5,"target",0} },
  { op="delay", frames=16 },
  { op="waitforvisualfinish" },
  { op="end" },
}

-- FireRed General_TurnTrap routes both Bind and Wrap to Status_BindWrap.
-- Gen1Recomp replays the trapping move on continuation turns, so expose the
-- same visual-only continuation branch used by Bind without changing mechanics.
M.trapContinuationScript = {
  { op="loadspritegfx", tag=10186 }, -- ANIM_TAG_TENDRILS
  { op="loopsewithpan", sound=148, pan="target", interval=6, count=2 }, -- SE_M_SCRATCH
  { op="createsprite", template="gConstrictBindingSpriteTemplate", anchor="target", priority=4,
    args={0,16,0,1,30} },
  { op="delay", frames=7 },
  { op="createsprite", template="gConstrictBindingSpriteTemplate", anchor="target", priority=2,
    args={0,8,1,1,23} },
  { op="delay", frames=3 },
  { op="createvisualtask", task="AnimTask_ShakeMon2", priority=2, args={"target",2,0,8,1} },
  { op="delay", frames=20 },
  { op="playsewithpan", sound=163, pan="target" }, -- SE_M_BIND
  { op="waitforvisualfinish" },
  { op="end" },
}

M.templates = {
  gConstrictBindingSpriteTemplate = {
    tileTag=10186,paletteTag=10186,callback="AnimConstrictBinding",
    oam={affine=true,objMode="normal",bpp=4,width=64,height=32},
    anim={kind="once",frames={
      {tileOffset=0,duration=4},
      {tileOffset=32,duration=4},
      {tileOffset=64,duration=4},
      {tileOffset=96,duration=4},
    }},
  },
}

return M
