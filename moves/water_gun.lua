local M = { id="WATER_GUN", name="Water Gun" }

-- Declarative FireRed Water Gun definition. Values mirror pret/pokefirered's
-- Move_WATER_GUN script and ROM sprite-template metadata.
M.script = {
  { op="loadspritegfx", tag=10155 }, -- ANIM_TAG_SMALL_BUBBLES
  { op="loadspritegfx", tag=10148 }, -- ANIM_TAG_WATER_IMPACT
  { op="monbg", battler="def_partner" },
  { op="splitbgprio", battler="target" },
  { op="setalpha", eva=12, evb=8 },
  { op="createsprite", template="gWaterGunProjectileSpriteTemplate", anchor="attacker", priority=2,
    args={20,0,0,0,40,-25} },
  { op="playsewithpan", sound=117, pan="attacker" }, -- SE_M_BUBBLE
  { op="waitforvisualfinish" },
  { op="createvisualtask", task="AnimTask_ShakeMon2", priority=5, args={"target",1,0,8,1} },
  { op="createsprite", template="gWaterHitSplatSpriteTemplate", anchor="attacker", priority=4,
    args={0,0,"target",2} },
  { op="createsprite", template="gWaterGunDropletSpriteTemplate", anchor="attacker", priority=2,
    args={0,-15,0,15,55} },
  { op="playsewithpan", sound=135, pan="target" }, -- SE_M_CRABHAMMER
  { op="delay", frames=10 },
  { op="createsprite", template="gWaterGunDropletSpriteTemplate", anchor="attacker", priority=2,
    args={15,-20,0,15,50} },
  { op="playsewithpan", sound=135, pan="target" },
  { op="delay", frames=10 },
  { op="createsprite", template="gWaterGunDropletSpriteTemplate", anchor="attacker", priority=2,
    args={-15,-10,0,10,45} },
  { op="playsewithpan", sound=135, pan="target" },
  { op="waitforvisualfinish" },
  { op="clearmonbg", battler="def_partner" },
  { op="blendoff" },
  { op="end" },
}

M.templates = {
  gWaterGunProjectileSpriteTemplate = {
    tileTag=10155, paletteTag=10155, callback="AnimThrowProjectile",
    oam={affine=false,objMode="blend",bpp=4,width=16,height=16},
    anim={kind="dummy",frames={{tileOffset=0,duration=1}}},
  },
  gWaterHitSplatSpriteTemplate = {
    tileTag=10148, paletteTag=10148, callback="AnimHitSplatBasic",
    oam={affine=true,objMode="blend",bpp=4,width=32,height=32},
    anim={kind="dummy",frames={{tileOffset=0,duration=1}}},
  },
  gWaterGunDropletSpriteTemplate = {
    tileTag=10155, paletteTag=10155, callback="AnimWaterGunDroplet",
    oam={affine=true,doubleSize=true,objMode="blend",bpp=4,width=16,height=16},
    anim={kind="dummy",frames={{tileOffset=4,duration=1}}},
  },
}

return M
