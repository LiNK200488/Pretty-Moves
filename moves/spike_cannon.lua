local M = { id="SPIKE_CANNON", name="Spike Cannon" }

-- FireRed Move_SPIKE_CANNON. The attacker first performs the native
-- AnimTask_WindUpLunge, then slides back to its origin while three straight
-- affine needles launch together. Three matching inverted hit splats and a
-- 3 px target shake finish the volley.
M.script = {
  { op="loadspritegfx", tag=10161 }, -- ANIM_TAG_NEEDLE
  { op="loadspritegfx", tag=10135 }, -- ANIM_TAG_IMPACT
  { op="monbg", battler="target" },
  { op="splitbgprio", battler="target" },
  { op="setalpha", eva=12, evb=8 },

  { op="createvisualtask", task="AnimTask_WindUpLunge", priority=5,
    args={"attacker",-4,0,4,6,8,4} },
  { op="waitforvisualfinish" },

  { op="loopsewithpan", sound=153, pan="attacker", interval=5, count=3 }, -- SE_M_RAZOR_WIND2
  { op="createsprite", template="gSlideMonToOriginalPosSpriteTemplate", anchor="attacker", priority=2,
    args={0,0,5} },
  { op="createsprite", template="gLinearStingerSpriteTemplate", anchor="attacker", priority=2,
    args={10,-8,-8,-8,20} },
  { op="createsprite", template="gLinearStingerSpriteTemplate", anchor="attacker", priority=2,
    args={18,0,0,0,20} },
  { op="createsprite", template="gLinearStingerSpriteTemplate", anchor="attacker", priority=2,
    args={26,8,8,8,20} },
  { op="waitforvisualfinish" },

  { op="createsprite", template="gHandleInvertHitSplatSpriteTemplate", anchor="attacker", priority=3,
    args={-8,-8,"target",2} },
  { op="createsprite", template="gHandleInvertHitSplatSpriteTemplate", anchor="attacker", priority=3,
    args={0,0,"target",2} },
  { op="createsprite", template="gHandleInvertHitSplatSpriteTemplate", anchor="attacker", priority=3,
    args={8,8,"target",2} },
  { op="createvisualtask", task="AnimTask_ShakeMon2", priority=2,
    args={"target",3,0,7,1} },
  { op="loopsewithpan", sound=159, pan="target", interval=5, count=3 }, -- SE_M_HORN_ATTACK

  { op="waitforvisualfinish" },
  { op="clearmonbg", battler="target" },
  { op="blendoff" },
  { op="end" },
}

M.templates = {
  -- Dummy controller sprite from battle_anim_mon_movement.c.
  gSlideMonToOriginalPosSpriteTemplate = {
    controller=true, callback="SlideMonToOriginalPos",
    oam={affine=false,objMode="normal",bpp=4,width=8,height=8},
    anim={kind="dummy",frames={{tileOffset=0,duration=1}}},
  },
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
