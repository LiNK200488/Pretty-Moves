local M = { id="RAGE", name="Rage" }

-- Source-faithful Pokemon FireRed Move_RAGE.
-- The attacker pulses red while two native anger marks appear above its head,
-- then lunges into the target for the normal impact/shake finish.
M.soundIds = {187,207}

M.script = {
  { op="loadspritegfx", tag=10135 }, -- ANIM_TAG_IMPACT
  { op="loadspritegfx", tag=10087 }, -- ANIM_TAG_ANGER
  { op="monbg", target="target" },
  { op="setalpha", eva=12, evb=8 },

  { op="createvisualtask", task="AnimTask_BlendMonInAndOut", priority=3,
    args={"attacker",{31,0,0},10,0,2} },
  { op="createsprite", template="gAngerMarkSpriteTemplate", anchor="attacker", priority=2,
    args={0,-20,-18} },
  { op="playsewithpan", sound=187, pan="attacker" }, -- SE_M_SWAGGER2
  { op="delay", frames=20 },
  { op="createsprite", template="gAngerMarkSpriteTemplate", anchor="attacker", priority=2,
    args={0,20,-18} },
  { op="playsewithpan", sound=187, pan="attacker" }, -- SE_M_SWAGGER2
  { op="waitforvisualfinish" },

  { op="createsprite", template="gHorizontalLungeSpriteTemplate", anchor="attacker", priority=2,
    args={4,6} },
  { op="delay", frames=4 },
  { op="createsprite", template="gBasicHitSplatSpriteTemplate", anchor="attacker", priority=2,
    args={0,0,"target",2} },
  -- FireRed scales this shake from gAnimMoveDmg. The deterministic overlay has
  -- no damage value at compile time, so preserve the native 10-toggle/1-frame
  -- cadence with the minimum useful two-pixel horizontal presentation.
  { op="createvisualtask", task="AnimTask_ShakeTargetBasedOnMovePowerOrDmg", priority=2,
    args={true,1,10,1,0} },
  { op="playsewithpan", sound=207, pan="target" }, -- SE_M_VITAL_THROW2
  { op="waitforvisualfinish" },
  { op="clearmonbg", target="target" },
  { op="end" },
}

M.templates = {
  gAngerMarkSpriteTemplate = {
    tileTag=10087, paletteTag=10087, callback="AnimAngerMark",
    oam={affine=true,objMode="normal",bpp=4,width=16,height=16},
    anim={kind="dummy",frames={{tileOffset=0,duration=16}}},
    affineAnim={kind="anger_pulse",frames=16},
  },
  gHorizontalLungeSpriteTemplate = {
    controller=true, callback="DoHorizontalLunge",
    oam={affine=false,objMode="normal",bpp=4,width=8,height=8},
    anim={kind="dummy",frames={}},
  },
  gBasicHitSplatSpriteTemplate = {
    tileTag=10135, paletteTag=10135, callback="AnimHitSplatBasic",
    oam={affine=true,objMode="blend",bpp=4,width=32,height=32},
    anim={kind="dummy",frames={{tileOffset=0,duration=1}}},
  },
}

return M
