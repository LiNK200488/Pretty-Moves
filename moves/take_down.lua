local M = { id="TAKE_DOWN", name="Take Down" }

-- FireRed Move_TAKE_DOWN. The attacker performs the native wind-up lunge,
-- then the impact darkens the scene, shoves the target backward, shakes it,
-- and returns both battlers to their original positions.
M.script = {
  { op="loadspritegfx", tag=10135 }, -- ANIM_TAG_IMPACT
  { op="monbg", battler="def_partner" },
  { op="setalpha", eva=12, evb=8 },

  { op="playsewithpan", sound=145, pan="attacker" }, -- SE_M_TAKE_DOWN
  { op="createvisualtask", task="AnimTask_WindUpLunge", priority=5,
    args={"attacker",-24,8,23,10,40,10} },
  { op="delay", frames=35 },

  { op="createsprite", template="gComplexPaletteBlendSpriteTemplate", anchor="attacker", priority=2,
    args={"all_and_bg",3,1,"black",10,"black",0} },
  { op="createsprite", template="gBasicHitSplatSpriteTemplate", anchor="attacker", priority=4,
    args={-10,0,"target",0} },
  { op="playsewithpan", sound=134, pan="target" }, -- SE_M_MEGA_KICK2
  { op="delay", frames=1 },

  { op="createsprite", template="gSlideMonToOffsetSpriteTemplate", anchor="attacker", priority=2,
    args={1,-16,0,0,4} },
  { op="waitforvisualfinish" },
  { op="createvisualtask", task="AnimTask_ShakeMonInPlace", priority=2,
    args={"target",4,0,12,1} },
  { op="waitforvisualfinish" },
  { op="delay", frames=2 },

  { op="createsprite", template="gSlideMonToOriginalPosSpriteTemplate", anchor="attacker", priority=2,
    args={0,0,5} },
  { op="delay", frames=3 },
  { op="createsprite", template="gSlideMonToOriginalPosSpriteTemplate", anchor="attacker", priority=2,
    args={1,0,7} },
  { op="waitforvisualfinish" },

  { op="clearmonbg", battler="def_partner" },
  { op="blendoff" },
  { op="end" },
}

M.templates = {
  gComplexPaletteBlendSpriteTemplate = {
    controller=true, callback="AnimComplexPaletteBlend",
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
