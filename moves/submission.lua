local M = { id="SUBMISSION", name="Submission" }

-- FireRed Move_SUBMISSION. Alternating Double Team / Comet Punch SFX are
-- scheduled across the wind-up, then attacker and target orbit in opposite
-- directions while three groups of three impact splats strike the target.
M.script = {
  { op="loadspritegfx", tag=10135 }, -- ANIM_TAG_IMPACT
  { op="monbg", battler="def_partner" },
  { op="setalpha", eva=12, evb=8 },

  { op="playsewithpan", sound=128, pan="attacker" }, -- SE_M_DOUBLE_TEAM
  { op="waitplaysewithpan", sound=132, pan="target", wait=10 }, -- SE_M_COMET_PUNCH
  { op="waitplaysewithpan", sound=128, pan="attacker", wait=20 },
  { op="waitplaysewithpan", sound=132, pan="target", wait=30 },
  { op="waitplaysewithpan", sound=128, pan="attacker", wait=40 },
  { op="waitplaysewithpan", sound=132, pan="target", wait=50 },
  { op="waitplaysewithpan", sound=128, pan="attacker", wait=60 },
  { op="waitplaysewithpan", sound=132, pan="target", wait=70 },
  { op="waitplaysewithpan", sound=128, pan="attacker", wait=80 },
  { op="waitplaysewithpan", sound=132, pan="target", wait=90 },

  { op="createvisualtask", task="AnimTask_TranslateMonElliptical", priority=2,
    args={"attacker",-18,6,6,4} },
  { op="createvisualtask", task="AnimTask_TranslateMonElliptical", priority=2,
    args={"target",18,6,6,4} },

  { op="call", label="SubmissionHit" },
  { op="call", label="SubmissionHit" },
  { op="call", label="SubmissionHit" },

  { op="waitforvisualfinish" },
  { op="clearmonbg", battler="def_partner" },
  { op="blendoff" },
  { op="end" },
}

M.labels = {
  SubmissionHit = {
    { op="createsprite", template="gBasicHitSplatSpriteTemplate", anchor="attacker", priority=3,
      args={0,-12,"target",1} },
    { op="delay", frames=8 },
    { op="createsprite", template="gBasicHitSplatSpriteTemplate", anchor="attacker", priority=3,
      args={-12,8,"target",1} },
    { op="delay", frames=8 },
    { op="createsprite", template="gBasicHitSplatSpriteTemplate", anchor="attacker", priority=3,
      args={12,0,"target",1} },
    { op="delay", frames=8 },
    { op="return" },
  },
}

M.templates = {
  gBasicHitSplatSpriteTemplate = {
    tileTag=10135,paletteTag=10135,callback="AnimHitSplatBasic",
    oam={affine=true,objMode="blend",bpp=4,width=32,height=32},
    anim={kind="dummy",frames={{tileOffset=0,duration=1}}},
  },
}

return M
