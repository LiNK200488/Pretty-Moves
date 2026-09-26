local M = { id="BODY_SLAM", name="Body Slam" }

-- FireRed Move_BODY_SLAM. The attacker performs the native vertical dip,
-- drives forward with SlideMonToOffset, shoves the target backward on impact,
-- then both battlers return to their original positions. The shared runtime
-- preserves the controller callbacks' signed 8.8 fixed-point stepping.
M.script = {
  { op="loadspritegfx", tag=10135 }, -- ANIM_TAG_IMPACT
  { op="monbg", battler="def_partner" },
  { op="setalpha", eva=12, evb=8 },

  { op="playsewithpan", sound=145, pan="attacker" }, -- SE_M_TAKE_DOWN
  { op="createsprite", template="gVerticalDipSpriteTemplate", anchor="attacker", priority=2,
    args={6,1,"attacker"} },
  { op="waitforvisualfinish" },
  { op="delay", frames=11 },

  { op="createsprite", template="gSlideMonToOffsetSpriteTemplate", anchor="attacker", priority=2,
    args={0,26,0,0,5} },
  { op="delay", frames=6 },
  { op="createsprite", template="gBasicHitSplatSpriteTemplate", anchor="attacker", priority=4,
    args={-10,0,"target",0} },
  { op="loopsewithpan", sound=134, pan="target", interval=10, count=2 }, -- SE_M_MEGA_KICK2
  { op="delay", frames=1 },

  { op="createsprite", template="gSlideMonToOffsetSpriteTemplate", anchor="attacker", priority=2,
    args={1,-28,0,0,3} },
  { op="waitforvisualfinish" },
  { op="createvisualtask", task="AnimTask_ShakeMonInPlace", priority=2,
    args={"target",4,0,12,1} },
  { op="waitforvisualfinish" },
  { op="delay", frames=10 },

  { op="createsprite", template="gSlideMonToOriginalPosSpriteTemplate", anchor="attacker", priority=2,
    args={0,0,6} },
  { op="delay", frames=5 },
  { op="createsprite", template="gSlideMonToOriginalPosSpriteTemplate", anchor="attacker", priority=2,
    args={1,0,6} },
  { op="waitforvisualfinish" },

  { op="clearmonbg", battler="def_partner" },
  { op="blendoff" },
  { op="end" },
}

M.templates = {
  gVerticalDipSpriteTemplate = {
    controller=true, callback="DoVerticalDip",
    oam={affine=false,objMode="normal",bpp=4,width=8,height=8},
    anim={kind="dummy",frames={{tileOffset=0,duration=1}}},
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
