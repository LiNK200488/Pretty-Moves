local M = { id="FIRE_PUNCH", name="Fire Punch" }

-- Source-traced from pret/pokefirered Move_FIRE_PUNCH / FireSpreadEffect.
M.script = {
  { op="loadspritegfx", tag=10143 }, -- ANIM_TAG_HANDS_AND_FEET
  { op="loadspritegfx", tag=10029 }, -- ANIM_TAG_SMALL_EMBER
  { op="loadspritegfx", tag=10135 }, -- ANIM_TAG_IMPACT
  { op="monbg", battler="target" },
  { op="setalpha", eva=12, evb=8 },

  { op="createvisualtask", task="AnimTask_BlendBattleAnimPal", priority=10,
    args={"target",2,0,9,{31,0,0}} }, -- RGB_RED

  { op="createsprite", template="gFireSpiralInwardSpriteTemplate", anchor="target", priority=1, args={0} },
  { op="createsprite", template="gFireSpiralInwardSpriteTemplate", anchor="target", priority=1, args={64} },
  { op="createsprite", template="gFireSpiralInwardSpriteTemplate", anchor="target", priority=1, args={128} },
  { op="createsprite", template="gFireSpiralInwardSpriteTemplate", anchor="target", priority=1, args={196} },
  { op="playsewithpan", sound=137, pan="target" }, -- SE_M_FLAME_WHEEL
  { op="waitforvisualfinish" },

  -- Lower subpriority impact is emitted first because this renderer paints\n  -- same-frame sprites in script order; fist remains visually on top as on GBA.
  { op="createsprite", template="gBasicHitSplatSpriteTemplate", anchor="target", priority=2,
    args={0,0,"target",1} },
  { op="createsprite", template="gFistFootSpriteTemplate", anchor="target", priority=3,
    args={0,0,8,1,0} },
  { op="createvisualtask", task="AnimTask_ShakeMon", priority=2, args={"target",0,3,15,1} },
  { op="call", label="FireSpreadEffect" },
  { op="delay", frames=4 },
  { op="playsewithpan", sound=140, pan="target" }, -- SE_M_FIRE_PUNCH
  { op="waitforvisualfinish" },

  { op="createvisualtask", task="AnimTask_BlendBattleAnimPal", priority=10,
    args={"target",0,9,0,{31,0,0}} },
  { op="waitforvisualfinish" },
  { op="clearmonbg", battler="target" },
  { op="blendoff" },
  { op="end" },
}

M.labels = {
  FireSpreadEffect = {
    { op="createsprite", template="gFireSpreadSpriteTemplate", anchor="target", priority=1, args={0,10,192,176,40} },
    { op="createsprite", template="gFireSpreadSpriteTemplate", anchor="target", priority=1, args={0,10,-192,240,40} },
    { op="createsprite", template="gFireSpreadSpriteTemplate", anchor="target", priority=1, args={0,10,192,-160,40} },
    { op="createsprite", template="gFireSpreadSpriteTemplate", anchor="target", priority=1, args={0,10,-192,-112,40} },
    { op="createsprite", template="gFireSpreadSpriteTemplate", anchor="target", priority=1, args={0,10,160,48,40} },
    { op="createsprite", template="gFireSpreadSpriteTemplate", anchor="target", priority=1, args={0,10,-224,-32,40} },
    { op="return" },
  },
}

local fireAnim = {
  kind="loop",
  frames={
    {tileOffset=16,duration=4},
    {tileOffset=32,duration=4},
    {tileOffset=48,duration=4},
  },
}

M.templates = {
  gFireSpiralInwardSpriteTemplate = {
    tileTag=10029,paletteTag=10029,callback="AnimFireSpiralInward",
    oam={width=32,height=32},anim=fireAnim,extraTileOffsets={16,32,48},
  },
  gFireSpreadSpriteTemplate = {
    tileTag=10029,paletteTag=10029,callback="AnimFireSpread",
    oam={width=32,height=32},anim=fireAnim,extraTileOffsets={16,32,48},
  },
  gFistFootSpriteTemplate = {
    tileTag=10143,paletteTag=10143,callback="AnimBasicFistOrFoot",
    oam={width=32,height=32},
    anim={kind="once",frames={{tileOffset=0,duration=1}}},
    extraTileOffsets={16,32,48},
  },
  gBasicHitSplatSpriteTemplate = {
    tileTag=10135,paletteTag=10135,callback="AnimHitSplatBasic",
    oam={affine=true,objMode="blend",bpp=4,width=32,height=32},
    anim={kind="dummy",frames={{tileOffset=0,duration=1}}},
  },
}

return M
