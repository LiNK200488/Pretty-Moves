local M = { id="SKULL_BASH", name="Skull Bash" }

-- FireRed Move_SKULL_BASH. Gen1Recomp remains authoritative for the RBY
-- two-turn charge/release mechanics; this replaces only the two visual phases.
M.chargeRowAnims = { player="XSTATITEM_ANIM", opponent="XSTATITEM_DUPLICATE_ANIM" }
M.soundIds = {20,134,145}

M.chargeScript = {
  -- FireRed SkullBashSetUp calls the same head-down sequence twice.
  { op="call", label="SkullBashSetUpHeadDown" },
  { op="call", label="SkullBashSetUpHeadDown" },
  { op="waitforvisualfinish" },
  { op="end" },
}

M.script = {
  { op="loadspritegfx", tag=10135 }, -- ANIM_TAG_IMPACT
  { op="createvisualtask", task="AnimTask_SkullBashPosition", priority=2, args={0} },
  { op="playsewithpan", sound=145, pan="attacker" }, -- SE_M_TAKE_DOWN
  { op="waitforvisualfinish" },

  { op="playsewithpan", sound=20, pan=0 }, -- SE_BANG
  { op="createsprite", template="gComplexPaletteBlendSpriteTemplate", anchor="attacker", priority=2,
    args={"bg",3,1,"black",14,"white",14} },
  { op="createvisualtask", task="AnimTask_ShakeMonInPlace", priority=2,
    args={"attacker",2,0,40,1} },
  { op="createvisualtask", task="AnimTask_ShakeMonInPlace", priority=2,
    args={"target",10,0,40,1} },
  { op="createsprite", template="gFlashingHitSplatSpriteTemplate", anchor="target", priority=4,
    args={0,0,"target",0} },
  { op="loopsewithpan", sound=134, pan="target", interval=8, count=3 }, -- SE_M_MEGA_KICK2
  { op="waitforvisualfinish" },

  { op="createvisualtask", task="AnimTask_SkullBashPosition", priority=2, args={1} },
  { op="waitforvisualfinish" },
  { op="end" },
}

M.labels = {
  SkullBashSetUpHeadDown = {
    -- Native gSlideMonToOffsetAndBack: first motion leaves the battler at the
    -- -24 px offset. SlideMonToOriginalPos reproduces the second +24 px leg and
    -- the native cleanup, including side mirroring in normal battles.
    { op="createsprite", template="gSlideMonToOffsetSpriteTemplate", anchor="attacker", priority=2,
      args={0,-24,0,0,10} },
    { op="playsewithpan", sound=145, pan="attacker" }, -- SE_M_TAKE_DOWN
    { op="waitforvisualfinish" },
    { op="createvisualtask", task="AnimTask_RotateMonSpriteToSide", priority=2,
      args={16,96,"attacker",2} },
    { op="waitforvisualfinish" },
    { op="createsprite", template="gSlideMonToOriginalPosSpriteTemplate", anchor="attacker", priority=2,
      args={0,0,10} },
    { op="waitforvisualfinish" },
    { op="return" },
  },
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
  gComplexPaletteBlendSpriteTemplate = {
    controller=true, callback="AnimComplexPaletteBlend",
    oam={affine=false,objMode="normal",bpp=4,width=8,height=8},
    anim={kind="dummy",frames={{tileOffset=0,duration=1}}},
  },
  gFlashingHitSplatSpriteTemplate = {
    tileTag=10135,paletteTag=10135,callback="AnimFlashingHitSplat",
    oam={affine=true,objMode="normal",bpp=4,width=32,height=32},
    anim={kind="dummy",frames={{tileOffset=0,duration=1}}},
  },
}

return M
