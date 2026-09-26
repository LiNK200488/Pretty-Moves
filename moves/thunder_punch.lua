local M = { id="THUNDERPUNCH", name="ThunderPunch" }

-- FireRed Move_THUNDER_PUNCH.
M.script = {
  { op="loadspritegfx", tag=10135 }, -- ANIM_TAG_IMPACT
  { op="loadspritegfx", tag=10143 }, -- ANIM_TAG_HANDS_AND_FEET
  { op="loadspritegfx", tag=10037 }, -- ANIM_TAG_LIGHTNING
  { op="monbg", battler="target" },
  { op="setalpha", eva=12, evb=8 },

  { op="createvisualtask", task="AnimTask_BlendBattleAnimPal", priority=2,
    args={"bg",2,0,16,"black"} },
  { op="waitforvisualfinish" },

  { op="playsewithpan", sound=132, pan="target" }, -- SE_M_COMET_PUNCH

  -- FireRed gives the fist subpriority 4 and the hit splat subpriority 3.
  -- Gen1Recomp's overlay renderer currently paints same-frame sprites in
  -- script order, so draw the lower-priority impact first and the fist last.
  -- This preserves the intended visual stacking: the fist remains readable.
  { op="createsprite", template="gBasicHitSplatSpriteTemplate", anchor="target", priority=3,
    args={0,0,"target",1} },
  { op="createsprite", template="gFistFootSpriteTemplate", anchor="target", priority=4,
    args={0,0,8,1,0} },

  { op="delay", frames=5 },
  { op="createvisualtask", task="AnimTask_InvertScreenColor", priority=2, args={257,257,257} },
  { op="delay", frames=1 },

  { op="createsprite", template="gLightningSpriteTemplate", anchor="target", priority=2, args={0,-48} },
  { op="delay", frames=1 },
  { op="createsprite", template="gLightningSpriteTemplate", anchor="attacker", priority=2, args={0,-16} },
  { op="delay", frames=1 },
  { op="createsprite", template="gLightningSpriteTemplate", anchor="attacker", priority=2, args={0,16} },

  { op="delay", frames=1 },
  { op="playsewithpan", sound=214, pan="target" }, -- SE_M_TRI_ATTACK2
  { op="createvisualtask", task="AnimTask_InvertScreenColor", priority=2, args={257,257,257} },
  { op="delay", frames=2 },

  { op="createvisualtask", task="AnimTask_ShakeMon", priority=2, args={"target",0,3,15,1} },
  { op="createsprite", template="gBasicHitSplatSpriteTemplate", anchor="attacker", priority=3,
    args={0,0,"target",2} },

  { op="delay", frames=1 },
  { op="createvisualtask", task="AnimTask_BlendBattleAnimPal", priority=2,
    args={"bg",2,16,0,"black"} },
  { op="delay", frames=20 },
  { op="waitforvisualfinish" },

  { op="clearmonbg", battler="target" },
  { op="blendoff" },
  { op="end" },
}

M.templates = {
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
  gLightningSpriteTemplate = {
    tileTag=10037,paletteTag=10037,callback="AnimLightning",
    oam={width=32,height=32},
    anim={kind="once",frames={
      {tileOffset=0,duration=5},
      {tileOffset=16,duration=5},
      {tileOffset=32,duration=8},
      {tileOffset=48,duration=5},
      {tileOffset=64,duration=5},
    }},
    extraTileOffsets={16,32,48,64},
  },
}

return M
