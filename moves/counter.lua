local M = { id="COUNTER", name="Counter" }

-- FireRed Move_COUNTER. The attacker winds up elliptically, lunges toward the
-- target, then lands three fist hits while the target shakes continuously.
M.script = {
  { op="loadspritegfx", tag=10135 }, -- ANIM_TAG_IMPACT
  { op="loadspritegfx", tag=10143 }, -- ANIM_TAG_HANDS_AND_FEET
  { op="monbg", battler="def_partner" },
  { op="setalpha", eva=12, evb=8 },

  { op="createvisualtask", task="AnimTask_TranslateMonEllipticalRespectSide", priority=2,
    args={"attacker",18,6,1,4} },
  { op="playsewithpan", sound=115, pan="attacker" }, -- SE_M_VITAL_THROW
  { op="waitforvisualfinish" },

  { op="createsprite", template="gSlideMonToOffsetSpriteTemplate", anchor="attacker", priority=2,
    args={0,20,0,0,4} },
  { op="delay", frames=4 },

  { op="createsprite", template="gBasicHitSplatSpriteTemplate", anchor="attacker", priority=2,
    args={-15,18,"target",0} },
  { op="playsewithpan", sound=116, pan="target" }, -- SE_M_VITAL_THROW2
  { op="delay", frames=1 },
  { op="createvisualtask", task="AnimTask_ShakeMon", priority=2,
    args={"target",5,0,25,1} },
  { op="createsprite", template="gFistFootSpriteTemplate", anchor="attacker", priority=3,
    args={-15,18,8,1,0} },
  { op="delay", frames=3 },

  { op="createsprite", template="gBasicHitSplatSpriteTemplate", anchor="attacker", priority=2,
    args={0,-4,"target",0} },
  { op="playsewithpan", sound=116, pan="target" },
  { op="delay", frames=1 },
  { op="createsprite", template="gFistFootSpriteTemplate", anchor="attacker", priority=3,
    args={0,-4,8,1,0} },
  { op="delay", frames=3 },

  { op="createsprite", template="gBasicHitSplatSpriteTemplate", anchor="attacker", priority=2,
    args={15,9,"target",0} },
  { op="playsewithpan", sound=116, pan="target" },
  { op="delay", frames=1 },
  { op="createsprite", template="gFistFootSpriteTemplate", anchor="attacker", priority=3,
    args={15,9,8,1,0} },
  { op="delay", frames=5 },

  { op="createsprite", template="gSlideMonToOriginalPosSpriteTemplate", anchor="attacker", priority=2,
    args={0,0,5} },
  { op="waitforvisualfinish" },
  { op="clearmonbg", battler="def_partner" },
  { op="blendoff" },
  { op="end" },
}

M.templates = {
  gSlideMonToOffsetSpriteTemplate = {
    controller=true, callback="SlideMonToOffset",
    oam={affine=false,objMode="normal",bpp=4,width=8,height=8},
    anim={kind="dummy",frames={{tileOffset=0,duration=1}}},
  },
  gSlideMonToOriginalPosSpriteTemplate = {
    controller=true, callback="SlideMonToOriginalPos",
    oam={affine=false,objMode="normal",bpp=4,width=8,height=8},
    anim={kind="dummy",frames={{tileOffset=0,duration=1}}},
  },
  gBasicHitSplatSpriteTemplate = {
    tileTag=10135,paletteTag=10135,callback="AnimHitSplatBasic",
    oam={affine=true,objMode="blend",bpp=4,width=32,height=32},
    anim={kind="dummy",frames={{tileOffset=0,duration=1}}},
  },
  gFistFootSpriteTemplate = {
    tileTag=10143,paletteTag=10143,callback="AnimBasicFistOrFoot",
    oam={affine=false,objMode="normal",bpp=4,width=32,height=32},
    anim={kind="once",frames={{tileOffset=0,duration=1}}},
  },
}

return M
