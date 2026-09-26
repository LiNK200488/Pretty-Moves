local M = { id="BUBBLEBEAM", name="BubbleBeam" }

-- Canonical FireRed Move_BUBBLE_BEAM choreography. All positioning/scaling
-- uses the shared battle-space renderer; there are no move-specific offsets.
M.script = {
  { op="loadspritegfx", tag=10146 }, -- ANIM_TAG_BUBBLE
  { op="loadspritegfx", tag=10155 }, -- ANIM_TAG_SMALL_BUBBLES
  { op="monbg", battler="target" },
  { op="splitbgprio", battler="target" },
  { op="setalpha", eva=12, evb=8 },
  { op="delay", frames=1 },

  -- BulbblebeamCreateBubbles, called three times by FireRed.
  { op="createsprite", template="gWaterBubbleProjectileSpriteTemplate", anchor="attacker", priority=2, args={18,0,35,70,0,256,50} },
  { op="playsewithpan", sound=117, pan="attacker" },
  { op="delay", frames=3 },
  { op="createsprite", template="gWaterBubbleProjectileSpriteTemplate", anchor="attacker", priority=2, args={18,0,20,40,-10,256,50} },
  { op="playsewithpan", sound=117, pan="attacker" },
  { op="delay", frames=3 },
  { op="createsprite", template="gWaterBubbleProjectileSpriteTemplate", anchor="attacker", priority=2, args={18,0,10,-60,0,256,50} },
  { op="playsewithpan", sound=117, pan="attacker" },
  { op="delay", frames=3 },
  { op="createsprite", template="gWaterBubbleProjectileSpriteTemplate", anchor="attacker", priority=2, args={18,0,15,-15,10,256,50} },
  { op="playsewithpan", sound=117, pan="attacker" },
  { op="delay", frames=3 },
  { op="createsprite", template="gWaterBubbleProjectileSpriteTemplate", anchor="attacker", priority=2, args={18,0,30,10,-10,256,50} },
  { op="playsewithpan", sound=117, pan="attacker" },
  { op="delay", frames=3 },
  { op="createsprite", template="gWaterBubbleProjectileSpriteTemplate", anchor="attacker", priority=2, args={18,0,25,-30,10,256,50} },
  { op="playsewithpan", sound=117, pan="attacker" },
  { op="delay", frames=3 },

  { op="createvisualtask", task="AnimTask_SwayMon", priority=5, args={0,3,3072,8,"target"} },

  -- Second group.
  { op="createsprite", template="gWaterBubbleProjectileSpriteTemplate", anchor="attacker", priority=2, args={18,0,35,70,0,256,50} },
  { op="playsewithpan", sound=117, pan="attacker" },
  { op="delay", frames=3 },
  { op="createsprite", template="gWaterBubbleProjectileSpriteTemplate", anchor="attacker", priority=2, args={18,0,20,40,-10,256,50} },
  { op="playsewithpan", sound=117, pan="attacker" },
  { op="delay", frames=3 },
  { op="createsprite", template="gWaterBubbleProjectileSpriteTemplate", anchor="attacker", priority=2, args={18,0,10,-60,0,256,50} },
  { op="playsewithpan", sound=117, pan="attacker" },
  { op="delay", frames=3 },
  { op="createsprite", template="gWaterBubbleProjectileSpriteTemplate", anchor="attacker", priority=2, args={18,0,15,-15,10,256,50} },
  { op="playsewithpan", sound=117, pan="attacker" },
  { op="delay", frames=3 },
  { op="createsprite", template="gWaterBubbleProjectileSpriteTemplate", anchor="attacker", priority=2, args={18,0,30,10,-10,256,50} },
  { op="playsewithpan", sound=117, pan="attacker" },
  { op="delay", frames=3 },
  { op="createsprite", template="gWaterBubbleProjectileSpriteTemplate", anchor="attacker", priority=2, args={18,0,25,-30,10,256,50} },
  { op="playsewithpan", sound=117, pan="attacker" },
  { op="delay", frames=3 },

  -- Third group.
  { op="createsprite", template="gWaterBubbleProjectileSpriteTemplate", anchor="attacker", priority=2, args={18,0,35,70,0,256,50} },
  { op="playsewithpan", sound=117, pan="attacker" },
  { op="delay", frames=3 },
  { op="createsprite", template="gWaterBubbleProjectileSpriteTemplate", anchor="attacker", priority=2, args={18,0,20,40,-10,256,50} },
  { op="playsewithpan", sound=117, pan="attacker" },
  { op="delay", frames=3 },
  { op="createsprite", template="gWaterBubbleProjectileSpriteTemplate", anchor="attacker", priority=2, args={18,0,10,-60,0,256,50} },
  { op="playsewithpan", sound=117, pan="attacker" },
  { op="delay", frames=3 },
  { op="createsprite", template="gWaterBubbleProjectileSpriteTemplate", anchor="attacker", priority=2, args={18,0,15,-15,10,256,50} },
  { op="playsewithpan", sound=117, pan="attacker" },
  { op="delay", frames=3 },
  { op="createsprite", template="gWaterBubbleProjectileSpriteTemplate", anchor="attacker", priority=2, args={18,0,30,10,-10,256,50} },
  { op="playsewithpan", sound=117, pan="attacker" },
  { op="delay", frames=3 },
  { op="createsprite", template="gWaterBubbleProjectileSpriteTemplate", anchor="attacker", priority=2, args={18,0,25,-30,10,256,50} },
  { op="playsewithpan", sound=117, pan="attacker" },
  { op="delay", frames=3 },

  { op="waitforvisualfinish" },

  -- WaterBubblesEffectShort.
  { op="createsprite", template="gWaterBubbleSpriteTemplate", anchor="attacker", priority=2, args={10,10,0} },
  { op="playsewithpan", sound=119, pan="target" },
  { op="delay", frames=6 },
  { op="createsprite", template="gWaterBubbleSpriteTemplate", anchor="attacker", priority=2, args={20,-20,0} },
  { op="playsewithpan", sound=119, pan="target" },
  { op="delay", frames=6 },
  { op="createsprite", template="gWaterBubbleSpriteTemplate", anchor="attacker", priority=2, args={-20,15,0} },
  { op="playsewithpan", sound=119, pan="target" },
  { op="delay", frames=6 },
  { op="createsprite", template="gWaterBubbleSpriteTemplate", anchor="attacker", priority=2, args={0,0,0} },
  { op="playsewithpan", sound=119, pan="target" },
  { op="delay", frames=6 },
  { op="createsprite", template="gWaterBubbleSpriteTemplate", anchor="attacker", priority=2, args={-20,-20,0} },
  { op="playsewithpan", sound=119, pan="target" },
  { op="delay", frames=6 },
  { op="createsprite", template="gWaterBubbleSpriteTemplate", anchor="attacker", priority=2, args={16,-8,0} },
  { op="playsewithpan", sound=119, pan="target" },
  { op="waitforvisualfinish" },
  { op="clearmonbg", battler="target" },
  { op="blendoff" },
  { op="end" },
}

M.templates = {
  gWaterBubbleProjectileSpriteTemplate = {
    tileTag=10146, paletteTag=10146, callback="AnimWaterBubbleProjectile",
    oam={affine=true,objMode="blend",bpp=4,width=16,height=16},
    -- Native animation is paused during travel; callback releases it on impact.
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
