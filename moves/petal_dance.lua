local M = { id="PETAL_DANCE", name="Petal Dance" }

M.soundIds = {195,134} -- SE_M_PETAL_DANCE, SE_M_MEGA_KICK2

-- FireRed Move_PETAL_DANCE, source-faithful. Flowers orbit/fall around the
-- attacker while it traces the native elliptical dance, then the attacker
-- lunges into the target for the finishing impact.
M.script = {
  { op="loadspritegfx", tag=10159 }, -- ANIM_TAG_FLOWER
  { op="loadspritegfx", tag=10135 }, -- ANIM_TAG_IMPACT
  { op="monbg", battler="target" },
  { op="setalpha", eva=12, evb=8 },
  { op="playsewithpan", sound=195, pan="attacker" }, -- SE_M_PETAL_DANCE
  { op="createvisualtask", task="AnimTask_TranslateMonEllipticalRespectSide", priority=2, args={"attacker",12,6,6,3} },

  { op="createsprite", template="gPetalDanceBigFlowerSpriteTemplate", anchor="attacker", priority=2, args={0,-24,8,140} },
  { op="createsprite", template="gPetalDanceSmallFlowerSpriteTemplate", anchor="attacker", priority=2, args={16,-24,8,100} },
  { op="createsprite", template="gPetalDanceSmallFlowerSpriteTemplate", anchor="attacker", priority=2, args={-16,-24,8,100} },
  { op="delay", frames=15 },
  { op="createsprite", template="gPetalDanceBigFlowerSpriteTemplate", anchor="attacker", priority=2, args={0,-24,8,140} },
  { op="createsprite", template="gPetalDanceSmallFlowerSpriteTemplate", anchor="attacker", priority=2, args={32,-24,8,100} },
  { op="createsprite", template="gPetalDanceSmallFlowerSpriteTemplate", anchor="attacker", priority=2, args={-32,-24,8,100} },
  { op="delay", frames=15 },
  { op="createsprite", template="gPetalDanceBigFlowerSpriteTemplate", anchor="attacker", priority=2, args={0,-24,8,140} },
  { op="createsprite", template="gPetalDanceSmallFlowerSpriteTemplate", anchor="attacker", priority=2, args={24,-24,8,100} },
  { op="createsprite", template="gPetalDanceSmallFlowerSpriteTemplate", anchor="attacker", priority=2, args={-24,-24,8,100} },
  { op="delay", frames=30 },
  { op="createsprite", template="gPetalDanceSmallFlowerSpriteTemplate", anchor="attacker", priority=2, args={16,-24,0,100} },
  { op="createsprite", template="gPetalDanceSmallFlowerSpriteTemplate", anchor="attacker", priority=2, args={-16,-24,0,100} },
  { op="delay", frames=30 },
  { op="createsprite", template="gPetalDanceSmallFlowerSpriteTemplate", anchor="attacker", priority=2, args={20,-16,14,80} },
  { op="createsprite", template="gPetalDanceSmallFlowerSpriteTemplate", anchor="attacker", priority=2, args={-20,-14,16,80} },
  { op="waitforvisualfinish" },

  { op="createsprite", template="gSlideMonToOffsetSpriteTemplate", anchor="attacker", priority=2, args={0,24,0,0,5} },
  { op="delay", frames=3 },
  { op="playsewithpan", sound=134, pan="target" }, -- SE_M_MEGA_KICK2
  { op="createsprite", template="gBasicHitSplatSpriteTemplate", anchor="attacker", priority=3, args={0,0,"target",0} },
  { op="createvisualtask", task="AnimTask_ShakeMon", priority=2, args={"target",6,0,8,1} },
  { op="waitforvisualfinish" },
  { op="delay", frames=8 },
  { op="createsprite", template="gSlideMonToOriginalPosSpriteTemplate", anchor="attacker", priority=2, args={0,0,7} },
  { op="waitforvisualfinish" },
  { op="clearmonbg", battler="target" },
  { op="blendoff" },
  { op="end" },
}

M.templates = {
  gPetalDanceBigFlowerSpriteTemplate = {
    tileTag=10159, paletteTag=10159, callback="AnimPetalDanceBigFlower",
    oam={affine=false,objMode="normal",bpp=4,width=16,height=16},
    anim={kind="dummy",frames={{tileOffset=0,duration=1}}},
  },
  gPetalDanceSmallFlowerSpriteTemplate = {
    tileTag=10159, paletteTag=10159, callback="AnimPetalDanceSmallFlower",
    oam={affine=false,objMode="normal",bpp=4,width=8,height=8},
    anim={kind="dummy",frames={{tileOffset=4,duration=1}}},
  },
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
    tileTag=10135, paletteTag=10135, callback="AnimHitSplatBasic",
    oam={affine=true,objMode="blend",bpp=4,width=32,height=32},
    anim={kind="dummy",frames={{tileOffset=0,duration=1}}},
  },
}

return M
