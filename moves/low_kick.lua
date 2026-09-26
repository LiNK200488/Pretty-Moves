local M = { id="LOW_KICK", name="Low Kick" }

-- FireRed Move_LOW_KICK. The attacker slides 20 px downward while a wide
-- foot sprite sweeps 40 px across the target over 8 native frames. At frame 4
-- the basic impact splat appears, the target tips sideways for six frames and
-- restores over six more, and SE_M_VITAL_THROW2 plays at the target.
M.soundIds = {207}

M.script = {
  { op="loadspritegfx", tag=10143 }, -- ANIM_TAG_HANDS_AND_FEET
  { op="loadspritegfx", tag=10135 }, -- ANIM_TAG_IMPACT
  { op="createsprite", template="gSlideMonToOffsetSpriteTemplate", anchor="attacker", priority=2,
    args={0,20,0,0,4} },
  { op="createsprite", template="gSlidingKickSpriteTemplate", anchor="target", priority=2,
    args={-24,12,40,8,160,0} },
  { op="delay", frames=4 },
  { op="createsprite", template="gBasicHitSplatSpriteTemplate", anchor="target", priority=2,
    args={-8,16,"target",2} },
  { op="createvisualtask", task="AnimTask_RotateMonSpriteToSide", priority=2,
    args={6,384,"target",2} },
  { op="playsewithpan", sound=207, pan="target" },
  { op="waitforvisualfinish" },
  { op="createsprite", template="gSlideMonToOriginalPosSpriteTemplate", anchor="attacker", priority=2,
    args={0,1,4} },
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
  gSlidingKickSpriteTemplate = {
    tileTag=10143,paletteTag=10143,callback="AnimSlidingKick",
    oam={affine=false,objMode="normal",bpp=4,width=32,height=32},
    anim={kind="once",frames={{tileOffset=16,duration=1}}},
  },
  gBasicHitSplatSpriteTemplate = {
    tileTag=10135,paletteTag=10135,callback="AnimHitSplatBasic",
    oam={affine=true,objMode="blend",bpp=4,width=32,height=32},
    anim={kind="dummy",frames={{tileOffset=0,duration=1}}},
  },
}

return M
