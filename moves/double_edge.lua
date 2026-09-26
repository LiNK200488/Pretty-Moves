local M = { id="DOUBLE_EDGE", name="Double-Edge" }

-- Source-traced FireRed Move_DOUBLE_EDGE. The attacker flashes white/black,
-- spins elliptically, rushes into the target, then both battlers tilt and shake
-- on impact before returning to their original positions.
M.script = {
  { op="loadspritegfx", tag=10135 }, -- ANIM_TAG_IMPACT

  { op="playsewithpan", sound=199, pan="attacker" }, -- SE_M_SWIFT
  { op="createsprite", template="gComplexPaletteBlendSpriteTemplate", anchor="attacker", priority=2,
    args={"attacker",4,2,"white",10,"black",0} },
  { op="waitforvisualfinish" },
  { op="delay", frames=10 },

  { op="playsewithpan", sound=186, pan="attacker" }, -- SE_M_SWAGGER
  { op="playsewithpan", sound=186, pan="attacker" }, -- waitplaysewithpan ... 8
  { op="delay", frames=8 },
  { op="createvisualtask", task="AnimTask_TranslateMonEllipticalRespectSide", priority=2,
    args={"attacker",18,6,2,4} },
  { op="waitforvisualfinish" },

  { op="createsprite", template="gSimplePaletteBlendSpriteTemplate", anchor="attacker", priority=2,
    args={"bg",0,16,16,"white"} },
  { op="createsprite", template="gSlideMonToOffsetSpriteTemplate", anchor="attacker", priority=2,
    args={0,20,0,0,4} },
  { op="delay", frames=3 },
  { op="waitforvisualfinish" },

  { op="playsewithpan", sound=134, pan="target" }, -- SE_M_MEGA_KICK2
  { op="createsprite", template="gBasicHitSplatSpriteTemplate", anchor="target", priority=4,
    args={-10,0,"target",0} },
  { op="createsprite", template="gSlideMonToOffsetSpriteTemplate", anchor="attacker", priority=2,
    args={1,-32,0,0,3} },
  { op="waitforvisualfinish" },

  { op="createvisualtask", task="AnimTask_RotateMonSpriteToSide", priority=2,
    args={8,-256,"attacker",0} },
  { op="createvisualtask", task="AnimTask_RotateMonSpriteToSide", priority=2,
    args={8,-256,"target",0} },
  { op="createvisualtask", task="AnimTask_ShakeMonInPlace", priority=2,
    args={"attacker",4,0,12,1} },
  { op="createvisualtask", task="AnimTask_ShakeMonInPlace", priority=2,
    args={"target",4,0,12,1} },
  { op="createsprite", template="gSimplePaletteBlendSpriteTemplate", anchor="attacker", priority=2,
    args={"bg",2,16,0,"white"} },
  { op="waitforvisualfinish" },

  { op="createvisualtask", task="AnimTask_RotateMonSpriteToSide", priority=2,
    args={8,-256,"attacker",1} },
  { op="createvisualtask", task="AnimTask_RotateMonSpriteToSide", priority=2,
    args={8,-256,"target",1} },
  { op="waitforvisualfinish" },

  { op="createsprite", template="gSlideMonToOriginalPosSpriteTemplate", anchor="attacker", priority=2,
    args={0,0,5} },
  { op="delay", frames=3 },
  { op="createsprite", template="gSlideMonToOriginalPosSpriteTemplate", anchor="attacker", priority=2,
    args={1,0,7} },
  { op="waitforvisualfinish" },
  { op="end" },
}

M.templates = {
  gComplexPaletteBlendSpriteTemplate = {
    controller=true, callback="AnimComplexPaletteBlend",
    oam={affine=false,objMode="normal",bpp=4,width=8,height=8},
    anim={kind="dummy",frames={{tileOffset=0,duration=1}}},
  },
  gSimplePaletteBlendSpriteTemplate = {
    controller=true, callback="AnimSimplePaletteBlend",
    oam={affine=false,objMode="normal",bpp=4,width=8,height=8},
    anim={kind="dummy",frames={{tileOffset=0,duration=1}}},
  },
  gBasicHitSplatSpriteTemplate = {
    tileTag=10135, paletteTag=10135, callback="AnimHitSplatBasic",
    oam={affine=true,objMode="blend",bpp=4,width=32,height=32},
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
}

return M
