local M = { id="EGG_BOMB", name="Egg Bomb" }

-- FireRed Move_EGG_BOMB (move 121): throw one large fresh egg in a 25-frame
-- horizontal arc, then shake the target while five native explosion sprites
-- burst around it at 3-frame intervals.
M.soundIds = {160,170}

M.script = {
  { op="loadspritegfx", tag=10198 }, -- ANIM_TAG_EXPLOSION
  { op="loadspritegfx", tag=10175 }, -- ANIM_TAG_LARGE_FRESH_EGG
  { op="playsewithpan", sound=160, pan="attacker" }, -- SE_M_TAIL_WHIP
  { op="createsprite", template="gEggThrowSpriteTemplate", anchor="target", priority=2,
    args={10,0,0,0,25,-32} },
  { op="waitforvisualfinish" },
  { op="createvisualtask", task="AnimTask_ShakeMon2", priority=2, args={"target",4,0,16,1} },
  { op="createsprite", template="gExplosionSpriteTemplate", anchor="target", priority=4,
    args={6,5,"target",0} },
  { op="playsewithpan", sound=170, pan="target" }, -- SE_M_SELF_DESTRUCT
  { op="delay", frames=3 },
  { op="createsprite", template="gExplosionSpriteTemplate", anchor="target", priority=4,
    args={-16,-15,"target",0} },
  { op="playsewithpan", sound=170, pan="target" },
  { op="delay", frames=3 },
  { op="createsprite", template="gExplosionSpriteTemplate", anchor="target", priority=4,
    args={16,-5,"target",0} },
  { op="playsewithpan", sound=170, pan="target" },
  { op="delay", frames=3 },
  { op="createsprite", template="gExplosionSpriteTemplate", anchor="target", priority=4,
    args={-12,18,"target",0} },
  { op="playsewithpan", sound=170, pan="target" },
  { op="delay", frames=3 },
  { op="createsprite", template="gExplosionSpriteTemplate", anchor="target", priority=4,
    args={0,5,"target",0} },
  { op="playsewithpan", sound=170, pan="target" },
  { op="delay", frames=3 },
  { op="waitforvisualfinish" },
  { op="end" },
}

M.templates = {
  gEggThrowSpriteTemplate = {
    tileTag=10175, paletteTag=10175, callback="AnimThrowProjectile",
    oam={affine=false,objMode="normal",bpp=4,width=16,height=16},
    anim={kind="dummy",frames={{tileOffset=0,duration=1}}},
  },
  gExplosionSpriteTemplate = {
    tileTag=10198, paletteTag=10198, callback="AnimSpriteOnMonPos",
    oam={affine=false,objMode="normal",bpp=4,width=32,height=32},
    anim={kind="once",frames={
      {tileOffset=0,duration=5},
      {tileOffset=16,duration=5},
      {tileOffset=32,duration=5},
      {tileOffset=48,duration=5},
    }},
  },
}

return M
