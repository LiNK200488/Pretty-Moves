local M = { id="TWINEEDLE", name="Twineedle" }

-- FireRed Move_TWINEEDLE. Two straight affine needles launch together, each
-- pre-rotated by AnimTranslateStinger to point along its exact 20-frame path.
-- On impact FireRed uses gHandleInvertHitSplatSpriteTemplate twice at 50%
-- affine size, with the second impact one frame after the first.
M.script = {
  { op="loadspritegfx", tag=10161 }, -- ANIM_TAG_NEEDLE
  { op="loadspritegfx", tag=10135 }, -- ANIM_TAG_IMPACT
  { op="monbg", battler="target" },
  { op="splitbgprio", battler="target" },
  { op="setalpha", eva=12, evb=8 },

  { op="loopsewithpan", sound=153, pan="attacker", interval=6, count=2 }, -- SE_M_RAZOR_WIND2
  { op="createsprite", template="gLinearStingerSpriteTemplate", anchor="target", priority=2,
    args={10,-4,0,-4,20} },
  { op="createsprite", template="gLinearStingerSpriteTemplate", anchor="target", priority=2,
    args={20,12,10,12,20} },

  { op="delay", frames=20 },
  { op="createvisualtask", task="AnimTask_ShakeMon2", priority=2,
    args={"target",2,0,5,1} },
  { op="createsprite", template="gHandleInvertHitSplatSpriteTemplate", anchor="attacker", priority=3,
    args={0,-4,"target",3} },
  { op="loopsewithpan", sound=159, pan="target", interval=5, count=2 }, -- SE_M_HORN_ATTACK
  { op="delay", frames=1 },
  { op="createsprite", template="gHandleInvertHitSplatSpriteTemplate", anchor="attacker", priority=3,
    args={10,12,"target",3} },

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
  gHandleInvertHitSplatSpriteTemplate = {
    tileTag=10135, paletteTag=10135, callback="AnimHitSplatHandleInvert",
    oam={affine=true,objMode="blend",bpp=4,width=32,height=32},
    anim={kind="dummy",frames={{tileOffset=0,duration=1}}},
  },
}

return M
