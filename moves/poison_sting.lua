local M = { id="POISON_STING", name="Poison Sting" }

-- FireRed Move_POISON_STING. One straight affine needle uses the shared
-- AnimTranslateStinger callback, then a normal impact/shake, followed by the
-- native six-bubble PoisonBubblesEffect. The bubble callback is the same
-- AnimBubbleEffect already used by BubbleBeam, with the poison palette/tag.
M.script = {
  { op="loadspritegfx", tag=10161 }, -- ANIM_TAG_NEEDLE
  { op="loadspritegfx", tag=10135 }, -- ANIM_TAG_IMPACT
  { op="loadspritegfx", tag=10150 }, -- ANIM_TAG_POISON_BUBBLE
  { op="monbg", battler="target" },
  { op="splitbgprio", battler="target" },
  { op="setalpha", eva=12, evb=8 },

  { op="playsewithpan", sound=153, pan="attacker" }, -- SE_M_RAZOR_WIND2
  { op="createsprite", template="gLinearStingerSpriteTemplate", anchor="target", priority=2,
    args={20,0,-8,0,20} },
  { op="waitforvisualfinish" },

  { op="createsprite", template="gBasicHitSplatSpriteTemplate", anchor="attacker", priority=3,
    args={0,0,"target",2} },
  { op="createvisualtask", task="AnimTask_ShakeMon2", priority=2,
    args={"target",2,0,5,1} },
  { op="playsewithpan", sound=159, pan="target" }, -- SE_M_HORN_ATTACK
  { op="waitforvisualfinish" },

  -- FireRed PoisonBubblesEffect.
  { op="createsprite", template="gPoisonBubbleSpriteTemplate", anchor="target", priority=2,
    args={10,10,0} },
  { op="playsewithpan", sound=141, pan="target" }, -- SE_M_TOXIC
  { op="delay", frames=6 },
  { op="createsprite", template="gPoisonBubbleSpriteTemplate", anchor="target", priority=2,
    args={20,-20,0} },
  { op="playsewithpan", sound=141, pan="target" },
  { op="delay", frames=6 },
  { op="createsprite", template="gPoisonBubbleSpriteTemplate", anchor="target", priority=2,
    args={-20,15,0} },
  { op="playsewithpan", sound=141, pan="target" },
  { op="delay", frames=6 },
  { op="createsprite", template="gPoisonBubbleSpriteTemplate", anchor="target", priority=2,
    args={0,0,0} },
  { op="playsewithpan", sound=141, pan="target" },
  { op="delay", frames=6 },
  { op="createsprite", template="gPoisonBubbleSpriteTemplate", anchor="target", priority=2,
    args={-20,-20,0} },
  { op="playsewithpan", sound=141, pan="target" },
  { op="delay", frames=6 },
  { op="createsprite", template="gPoisonBubbleSpriteTemplate", anchor="target", priority=2,
    args={16,-8,0} },
  { op="playsewithpan", sound=141, pan="target" },

  { op="waitforvisualfinish" },
  { op="clearmonbg", battler="target" },
  { op="blendoff" },
  { op="end" },
}

M.templates = {
  gLinearStingerSpriteTemplate = {
    tileTag=10161, paletteTag=10161, callback="AnimTranslateStinger",
    oam={affine=true,objMode="normal",bpp=4,width=16,height=16},
    anim={kind="dummy",frames={{tileOffset=0,duration=1}}},
  },
  gBasicHitSplatSpriteTemplate = {
    tileTag=10135, paletteTag=10135, callback="AnimHitSplatBasic",
    oam={affine=true,objMode="blend",bpp=4,width=32,height=32},
    anim={kind="dummy",frames={{tileOffset=0,duration=1}}},
  },
  gPoisonBubbleSpriteTemplate = {
    tileTag=10150, paletteTag=10150, callback="AnimBubbleEffect",
    oam={affine=true,objMode="normal",bpp=4,width=16,height=16},
    anim={kind="dummy",frames={{tileOffset=0,duration=1}}},
  },
}

return M
