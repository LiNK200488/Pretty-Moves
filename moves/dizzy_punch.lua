local M = { id="DIZZY_PUNCH", name="Dizzy Punch" }

-- Exact FireRed Move_DIZZY_PUNCH choreography.
-- Two attacker lunges, each followed by a fist + hit splat and six native
-- duck sprites using AnimDizzyPunchDuck's fixed-point horizontal drift and
-- small vertical sine wave around the target.
M.soundIds = {132,116}

M.script = {
  { op="loadspritegfx", tag=10073 }, -- ANIM_TAG_DUCK
  { op="loadspritegfx", tag=10143 }, -- ANIM_TAG_HANDS_AND_FEET
  { op="loadspritegfx", tag=10135 }, -- ANIM_TAG_IMPACT
  { op="monbg", battler="target" },
  { op="setalpha", eva=12, evb=8 },

  { op="createsprite", template="gHorizontalLungeSpriteTemplate", anchor="attacker", priority=2, args={6,4} },
  { op="delay", frames=6 },
  { op="createvisualtask", task="AnimTask_ShakeMon2", priority=2, args={"target",3,0,7,1} },
  { op="createsprite", template="gFistFootSpriteTemplate", anchor="target", priority=5, args={16,8,20,1,0} },
  { op="createsprite", template="gBasicHitSplatSpriteTemplate", anchor="target", priority=4, args={16,0,"target",1} },
  { op="playsewithpan", sound=132, pan="target" }, -- SE_M_COMET_PUNCH
  { op="createsprite", template="gDizzyPunchDuckSpriteTemplate", anchor="target", priority=3, args={16,8,160,-32} },
  { op="createsprite", template="gDizzyPunchDuckSpriteTemplate", anchor="target", priority=3, args={16,8,-256,-40} },
  { op="createsprite", template="gDizzyPunchDuckSpriteTemplate", anchor="target", priority=3, args={16,8,128,-16} },
  { op="createsprite", template="gDizzyPunchDuckSpriteTemplate", anchor="target", priority=3, args={16,8,416,-38} },
  { op="createsprite", template="gDizzyPunchDuckSpriteTemplate", anchor="target", priority=3, args={16,8,-128,-22} },
  { op="createsprite", template="gDizzyPunchDuckSpriteTemplate", anchor="target", priority=3, args={16,8,-384,-31} },
  { op="delay", frames=10 },

  { op="createsprite", template="gHorizontalLungeSpriteTemplate", anchor="attacker", priority=2, args={6,4} },
  { op="delay", frames=6 },
  { op="createvisualtask", task="AnimTask_ShakeMon2", priority=2, args={"target",3,0,7,1} },
  { op="createsprite", template="gFistFootSpriteTemplate", anchor="target", priority=5, args={-16,-8,20,1,0} },
  { op="createsprite", template="gBasicHitSplatSpriteTemplate", anchor="target", priority=4, args={-16,-16,"target",1} },
  { op="playsewithpan", sound=116, pan="target" }, -- SE_M_VITAL_THROW2
  { op="createsprite", template="gDizzyPunchDuckSpriteTemplate", anchor="target", priority=3, args={-16,-8,160,-32} },
  { op="createsprite", template="gDizzyPunchDuckSpriteTemplate", anchor="target", priority=3, args={-16,-8,-256,-40} },
  { op="createsprite", template="gDizzyPunchDuckSpriteTemplate", anchor="target", priority=3, args={-16,-8,128,-16} },
  { op="createsprite", template="gDizzyPunchDuckSpriteTemplate", anchor="target", priority=3, args={-16,-8,416,-38} },
  { op="createsprite", template="gDizzyPunchDuckSpriteTemplate", anchor="target", priority=3, args={-16,-8,-128,-22} },
  { op="createsprite", template="gDizzyPunchDuckSpriteTemplate", anchor="target", priority=3, args={-16,-8,-384,-31} },
  { op="waitforvisualfinish" },
  { op="clearmonbg", battler="target" },
  { op="blendoff" },
  { op="end" },
}

M.templates = {
  gHorizontalLungeSpriteTemplate = {
    controller=true, callback="DoHorizontalLunge",
    oam={affine=false,objMode="normal",bpp=4,width=8,height=8},
    anim={kind="dummy",frames={{tileOffset=0,duration=1}}},
  },
  gFistFootSpriteTemplate = {
    tileTag=10143,paletteTag=10143,callback="AnimBasicFistOrFoot",
    oam={affine=false,objMode="normal",bpp=4,width=32,height=32},
    anim={kind="once",frames={{tileOffset=0,duration=1}}},
  },
  gBasicHitSplatSpriteTemplate = {
    tileTag=10135,paletteTag=10135,callback="AnimHitSplatBasic",
    oam={affine=true,objMode="blend",bpp=4,width=32,height=32},
    anim={kind="dummy",frames={{tileOffset=0,duration=1}}},
  },
  gDizzyPunchDuckSpriteTemplate = {
    tileTag=10073,paletteTag=10073,callback="AnimDizzyPunchDuck",
    oam={affine=false,objMode="normal",bpp=4,width=16,height=16},
    anim={kind="dummy",frames={{tileOffset=0,duration=1}}},
  },
}

return M
