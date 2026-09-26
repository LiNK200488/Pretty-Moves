local M = { id="SONICBOOM", name="SonicBoom" }

-- Exact FireRed Move_SONIC_BOOM choreography: three ANIM_TAG_AIR_WAVE
-- projectiles launch four frames apart, each rotates toward the target and
-- translates for 15 native ticks. The third launch is followed immediately
-- by the native target shake and impact splat.
M.script = {
  { op="loadspritegfx", tag=10003 }, -- ANIM_TAG_AIR_WAVE
  { op="loadspritegfx", tag=10135 }, -- ANIM_TAG_IMPACT
  { op="monbg", battler="def_partner" },
  { op="splitbgprio", battler="target" },
  { op="setalpha", eva=12, evb=8 },

  { op="playsewithpan", sound=153, pan="attacker" }, -- SE_M_RAZOR_WIND2
  { op="createsprite", template="gSonicBoomSpriteTemplate", anchor="target", priority=2, args={16,0,0,0,15} },
  { op="delay", frames=4 },
  { op="playsewithpan", sound=153, pan="attacker" },
  { op="createsprite", template="gSonicBoomSpriteTemplate", anchor="target", priority=2, args={16,0,0,0,15} },
  { op="delay", frames=4 },
  { op="playsewithpan", sound=153, pan="attacker" },
  { op="createsprite", template="gSonicBoomSpriteTemplate", anchor="target", priority=2, args={16,0,0,0,15} },
  { op="delay", frames=4 },

  { op="createvisualtask", task="AnimTask_ShakeMon", priority=2, args={"target",3,0,10,1} },
  { op="createsprite", template="gBasicHitSplatSpriteTemplate", anchor="target", priority=3, args={0,0,"target",2} },
  { op="delay", frames=4 },
  { op="waitforvisualfinish" },
  { op="clearmonbg", battler="def_partner" },
  { op="blendoff" },
  { op="end" },
}

M.templates = {
  gSonicBoomSpriteTemplate = {
    tileTag=10003, paletteTag=10003, callback="AnimSonicBoomProjectile",
    oam={affine=true,doubleSize=true,objMode="blend",bpp=4,width=32,height=16},
    anim={kind="dummy",frames={{tileOffset=0,duration=1}}},
  },
  gBasicHitSplatSpriteTemplate = {
    tileTag=10135, paletteTag=10135, callback="AnimHitSplatBasic",
    oam={affine=true,objMode="blend",bpp=4,width=32,height=32},
    anim={kind="dummy",frames={{tileOffset=0,duration=1}}},
  },
}

return M
