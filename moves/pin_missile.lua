local M = { id="PIN_MISSILE", name="Pin Missile" }

-- FireRed Move_PIN_MISSILE. Unlike the per-landed-hit contact moves, the
-- original script is a self-contained barrage: three staggered needle
-- launches, each converging on a slightly different point, followed by impact
-- splats and short target shakes.
M.script = {
  { op="loadspritegfx", tag=10161 }, -- ANIM_TAG_NEEDLE
  { op="loadspritegfx", tag=10135 }, -- ANIM_TAG_IMPACT
  { op="monbg", battler="target" },
  { op="splitbgprio", battler="target" },
  { op="setalpha", eva=12, evb=8 },

  { op="playsewithpan", sound=136, pan="attacker" }, -- SE_M_JUMP_KICK
  { op="createsprite", template="gPinMissileSpriteTemplate", anchor="attacker", priority=2,
    args={20,-8,-8,-8,20,-32} },

  { op="delay", frames=15 },
  { op="createsprite", template="gPinMissileSpriteTemplate", anchor="attacker", priority=2,
    args={20,-8,8,8,20,-40} },

  { op="delay", frames=4 },
  { op="playsewithpan", sound=159, pan="target" }, -- SE_M_HORN_ATTACK
  { op="createsprite", template="gBasicHitSplatSpriteTemplate", anchor="attacker", priority=3,
    args={-8,-8,"target",2} },
  { op="createvisualtask", task="AnimTask_ShakeMon2", priority=2,
    args={"target",3,0,2,1} },

  { op="delay", frames=9 },
  { op="createsprite", template="gPinMissileSpriteTemplate", anchor="attacker", priority=2,
    args={20,-8,0,0,20,-32} },

  { op="delay", frames=4 },
  { op="playsewithpan", sound=159, pan="target" }, -- SE_M_HORN_ATTACK
  { op="createsprite", template="gBasicHitSplatSpriteTemplate", anchor="attacker", priority=3,
    args={8,8,"target",2} },
  { op="createvisualtask", task="AnimTask_ShakeMon2", priority=2,
    args={"target",3,0,2,1} },

  { op="delay", frames=14 },
  { op="playsewithpan", sound=159, pan="target" }, -- SE_M_HORN_ATTACK
  { op="createsprite", template="gBasicHitSplatSpriteTemplate", anchor="attacker", priority=3,
    args={0,0,"target",2} },
  { op="createvisualtask", task="AnimTask_ShakeMon2", priority=2,
    args={"target",3,0,2,1} },

  { op="waitforvisualfinish" },
  { op="clearmonbg", battler="target" },
  { op="blendoff" },
  { op="end" },
}

M.templates = {
  gPinMissileSpriteTemplate = {
    tileTag=10161, paletteTag=10161, callback="AnimMissileArc",
    oam={affine=true,objMode="normal",bpp=4,width=16,height=16},
    anim={kind="dummy",frames={{tileOffset=0,duration=1}}},
  },
  gBasicHitSplatSpriteTemplate = {
    tileTag=10135, paletteTag=10135, callback="AnimHitSplatBasic",
    oam={affine=true,objMode="blend",bpp=4,width=32,height=32},
    anim={kind="dummy",frames={{tileOffset=0,duration=1}}},
  },
}

return M
