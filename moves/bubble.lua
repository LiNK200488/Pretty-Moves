local M = { id="BUBBLE", name="Bubble" }

-- Canonical FireRed Move_BUBBLE choreography.
M.script = {
  { op="loadspritegfx", tag=10146 }, -- ANIM_TAG_BUBBLE
  { op="loadspritegfx", tag=10155 }, -- ANIM_TAG_SMALL_BUBBLES
  { op="monbg", battler="target" },
  { op="setalpha", eva=12, evb=8 },
  { op="delay", frames=1 },

  { op="createsprite", template="gWaterBubbleProjectileSpriteTemplate", anchor="attacker", priority=2, args={18,0,15,-15,10,128,100} },
  { op="playsewithpan", sound=117, pan="attacker" },
  { op="waitplaysewithpan", sound=118, pan="target", wait=100 },
  { op="delay", frames=6 },

  { op="createsprite", template="gWaterBubbleProjectileSpriteTemplate", anchor="attacker", priority=2, args={18,0,35,37,40,128,100} },
  { op="playsewithpan", sound=117, pan="attacker" },
  { op="waitplaysewithpan", sound=118, pan="target", wait=100 },
  { op="delay", frames=6 },

  { op="createsprite", template="gWaterBubbleProjectileSpriteTemplate", anchor="attacker", priority=2, args={18,0,10,-37,30,128,100} },
  { op="playsewithpan", sound=117, pan="attacker" },
  { op="waitplaysewithpan", sound=118, pan="target", wait=100 },
  { op="delay", frames=6 },

  { op="createsprite", template="gWaterBubbleProjectileSpriteTemplate", anchor="attacker", priority=2, args={18,0,30,10,15,128,100} },
  { op="playsewithpan", sound=117, pan="attacker" },
  { op="waitplaysewithpan", sound=118, pan="target", wait=100 },
  { op="delay", frames=6 },

  { op="createsprite", template="gWaterBubbleProjectileSpriteTemplate", anchor="attacker", priority=2, args={18,0,20,33,20,128,100} },
  { op="playsewithpan", sound=117, pan="attacker" },
  { op="waitplaysewithpan", sound=118, pan="target", wait=100 },
  { op="delay", frames=6 },

  { op="createsprite", template="gWaterBubbleProjectileSpriteTemplate", anchor="attacker", priority=2, args={18,0,25,-30,10,128,100} },
  { op="playsewithpan", sound=117, pan="attacker" },
  { op="waitplaysewithpan", sound=118, pan="target", wait=100 },
  { op="waitforvisualfinish" },

  -- FireRed WaterBubblesEffectLong.
  { op="createsprite", template="gWaterBubbleSpriteTemplate", anchor="attacker", priority=2, args={10,10,1} },
  { op="playsewithpan", sound=119, pan="target" },
  { op="delay", frames=6 },
  { op="createsprite", template="gWaterBubbleSpriteTemplate", anchor="attacker", priority=2, args={-28,-10,1} },
  { op="playsewithpan", sound=119, pan="target" },
  { op="delay", frames=6 },
  { op="createsprite", template="gWaterBubbleSpriteTemplate", anchor="attacker", priority=2, args={20,-20,1} },
  { op="playsewithpan", sound=119, pan="target" },
  { op="delay", frames=6 },
  { op="createsprite", template="gWaterBubbleSpriteTemplate", anchor="attacker", priority=2, args={-20,15,1} },
  { op="playsewithpan", sound=119, pan="target" },
  { op="delay", frames=6 },
  { op="createsprite", template="gWaterBubbleSpriteTemplate", anchor="attacker", priority=2, args={0,0,1} },
  { op="playsewithpan", sound=119, pan="target" },
  { op="delay", frames=6 },
  { op="createsprite", template="gWaterBubbleSpriteTemplate", anchor="attacker", priority=2, args={27,8,1} },
  { op="playsewithpan", sound=119, pan="target" },
  { op="delay", frames=6 },
  { op="createsprite", template="gWaterBubbleSpriteTemplate", anchor="attacker", priority=2, args={-20,-20,1} },
  { op="playsewithpan", sound=119, pan="target" },
  { op="delay", frames=6 },
  { op="createsprite", template="gWaterBubbleSpriteTemplate", anchor="attacker", priority=2, args={16,-8,1} },
  { op="playsewithpan", sound=119, pan="target" },

  { op="waitforvisualfinish" },
  { op="clearmonbg", battler="target" },
  { op="blendoff" },
  { op="end" },
}

M.templates = {
  gWaterBubbleProjectileSpriteTemplate = {
    tileTag=10146, paletteTag=10146, callback="AnimWaterBubbleProjectileHoldImpact",
    oam={affine=true,objMode="blend",bpp=4,width=16,height=16},
    anim={kind="dummy",frames={{tileOffset=0,duration=1}}},
    extraTileOffsets={4,8},
  },
  gWaterBubbleSpriteTemplate = {
    tileTag=10155, paletteTag=10155, callback="AnimBubbleEffect",
    oam={affine=true,objMode="blend",bpp=4,width=16,height=16},
    anim={kind="dummy",frames={{tileOffset=0,duration=1}}},
  },
}

return M
