local M = { id="ICE_PUNCH", name="Ice Punch" }

-- Source-traced FireRed Move_ICE_PUNCH / AnimIcePunchSwirlingParticle.
-- The target is tinted icy blue while the background fades toward black,
-- eight crystals spiral inward, then the fist lands and the standard short
-- ice-crystal impact sequence shatters across the target.
M.script = {
  { op="monbg", battler="target" },
  { op="setalpha", eva=12, evb=8 },
  { op="loadspritegfx", tag=10141 }, -- ANIM_TAG_ICE_CRYSTALS
  { op="loadspritegfx", tag=10135 }, -- ANIM_TAG_IMPACT
  { op="loadspritegfx", tag=10143 }, -- ANIM_TAG_HANDS_AND_FEET

  { op="createsprite", template="gSimplePaletteBlendSpriteTemplate", anchor="attacker", priority=2,
    args={"bg",1,0,7,"black"} },
  { op="createvisualtask", task="AnimTask_BlendBattleAnimPal", priority=10,
    args={"target",2,0,9,{12,26,31}} },
  { op="delay", frames=20 },

  { op="playsewithpan", sound=122, pan="target" }, -- SE_M_STRING_SHOT
  { op="createsprite", template="gIceCrystalSpiralInwardSmall", anchor="target", priority=2, args={0} },
  { op="createsprite", template="gIceCrystalSpiralInwardSmall", anchor="target", priority=2, args={64} },
  { op="createsprite", template="gIceCrystalSpiralInwardSmall", anchor="target", priority=2, args={128} },
  { op="createsprite", template="gIceCrystalSpiralInwardSmall", anchor="target", priority=2, args={192} },
  { op="delay", frames=5 },
  { op="createsprite", template="gIceCrystalSpiralInwardLarge", anchor="target", priority=2, args={32} },
  { op="createsprite", template="gIceCrystalSpiralInwardLarge", anchor="target", priority=2, args={96} },
  { op="createsprite", template="gIceCrystalSpiralInwardLarge", anchor="target", priority=2, args={160} },
  { op="createsprite", template="gIceCrystalSpiralInwardLarge", anchor="target", priority=2, args={224} },
  { op="delay", frames=17 },

  -- FireRed uses target-relative y=-10 for both fist and impact.
  -- Draw the lower-subpriority hit splat first so the fist remains on top.
  { op="createsprite", template="gBasicHitSplatSpriteTemplate", anchor="target", priority=3,
    args={0,-10,"target",1} },
  { op="createsprite", template="gFistFootSpriteTemplate", anchor="target", priority=4,
    args={0,-10,8,1,0} },
  { op="playsewithpan", sound=132, pan="target", overlap=true }, -- SE_M_COMET_PUNCH; preserve audible punch tail through host hit cue
  { op="delay", frames=2 },
  { op="createvisualtask", task="AnimTask_ShakeMon", priority=5, args={"target",0,5,3,1} },
  { op="waitforvisualfinish" },
  { op="delay", frames=15 },

  { op="call", label="IceCrystalEffectShort" },
  { op="delay", frames=5 },
  { op="createvisualtask", task="AnimTask_BlendBattleAnimPal", priority=10,
    args={"target",2,9,0,{12,26,31}} },
  { op="waitforvisualfinish" },
  { op="createsprite", template="gSimplePaletteBlendSpriteTemplate", anchor="attacker", priority=2,
    args={"bg",0,7,0,"black"} },
  { op="waitforvisualfinish" },
  { op="clearmonbg", battler="target" },
  { op="blendoff" },
  { op="end" },
}

M.labels = {
  IceCrystalEffectShort = {
    { op="createsprite", template="gIceCrystalHitLargeSpriteTemplate", anchor="target", priority=2, args={-10,-10,0} },
    { op="playsewithpan", sound=130, pan="target" },
    { op="delay", frames=4 },
    { op="createsprite", template="gIceCrystalHitSmallSpriteTemplate", anchor="target", priority=2, args={10,20,0} },
    { op="playsewithpan", sound=130, pan="target" },
    { op="delay", frames=4 },
    { op="createsprite", template="gIceCrystalHitLargeSpriteTemplate", anchor="target", priority=2, args={-5,10,0} },
    { op="playsewithpan", sound=130, pan="target" },
    { op="delay", frames=4 },
    { op="createsprite", template="gIceCrystalHitSmallSpriteTemplate", anchor="target", priority=2, args={17,-12,0} },
    { op="playsewithpan", sound=130, pan="target" },
    { op="delay", frames=4 },
    { op="createsprite", template="gIceCrystalHitSmallSpriteTemplate", anchor="target", priority=2, args={0,0,0} },
    { op="playsewithpan", sound=130, pan="target" },
    { op="delay", frames=4 },
    { op="createsprite", template="gIceCrystalHitLargeSpriteTemplate", anchor="target", priority=2, args={20,2,0} },
    { op="playsewithpan", sound=130, pan="target" },
    { op="return" },
  },
}

M.templates = {
  gSimplePaletteBlendSpriteTemplate={controller=true,callback="AnimSimplePaletteBlend"},
  gIceCrystalSpiralInwardSmall={
    tileTag=10141,paletteTag=10141,callback="AnimIcePunchSwirlingParticle",
    oam={width=8,height=8,objMode="blend"},
    anim={kind="dummy",frames={{tileOffset=6,duration=1}}},
  },
  gIceCrystalSpiralInwardLarge={
    tileTag=10141,paletteTag=10141,callback="AnimIcePunchSwirlingParticle",
    oam={width=8,height=16,objMode="blend",affine=true},
    anim={kind="dummy",frames={{tileOffset=4,duration=1}}},
  },
  gFistFootSpriteTemplate={
    tileTag=10143,paletteTag=10143,callback="AnimBasicFistOrFoot",
    oam={width=32,height=32},anim={kind="once",frames={{tileOffset=0,duration=1}}},
    extraTileOffsets={16,32,48},
  },
  gBasicHitSplatSpriteTemplate={
    tileTag=10135,paletteTag=10135,callback="AnimHitSplatBasic",
    oam={affine=true,objMode="blend",bpp=4,width=32,height=32},
    anim={kind="dummy",frames={{tileOffset=0,duration=1}}},
  },
  gIceCrystalHitLargeSpriteTemplate={
    tileTag=10141,paletteTag=10141,callback="AnimIceEffectParticle",
    oam={width=8,height=16,objMode="blend",affine=true},
    anim={kind="dummy",frames={{tileOffset=4,duration=1}}},
  },
  gIceCrystalHitSmallSpriteTemplate={
    tileTag=10141,paletteTag=10141,callback="AnimIceEffectParticle",
    oam={width=8,height=8,objMode="blend",affine=true},
    anim={kind="dummy",frames={{tileOffset=6,duration=1}}},
  },
}

return M
