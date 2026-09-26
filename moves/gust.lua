local M = { id="GUST", name="Gust" }

-- FireRed Move_GUST choreography. The tornado uses FireRed's ROM-native Gust
-- sprite and 71-frame elliptical target orbit; palette entries 1..8 rotate
-- every two frames to reproduce AnimTask_AnimateGustTornadoPalette.
M.script = {
  { op="loadspritegfx", tag=10009 }, -- ANIM_TAG_GUST
  { op="loadspritegfx", tag=10135 }, -- ANIM_TAG_IMPACT
  { op="monbg", battler="def_partner" },
  { op="splitbgprio", battler="target" },
  { op="setalpha", eva=12, evb=8 },
  { op="playsewithpan", sound=125, pan="target" }, -- SE_M_GUST
  { op="createsprite", template="gEllipticalGustSpriteTemplate", anchor="attacker", priority=2, args={0,-16} },
  { op="createvisualtask", task="AnimTask_AnimateGustTornadoPalette", priority=5, args={1,70} },
  { op="waitforvisualfinish" },
  { op="createvisualtask", task="AnimTask_ShakeMon2", priority=5, args={"target",1,0,7,1} },
  { op="createsprite", template="gBasicHitSplatSpriteTemplate", anchor="attacker", priority=2, args={0,0,"target",2} },
  { op="playsewithpan", sound=126, pan="target" }, -- SE_M_GUST2
  { op="waitforvisualfinish" },
  { op="clearmonbg", battler="def_partner" },
  { op="blendoff" },
  { op="end" },
}

M.templates = {
  gEllipticalGustSpriteTemplate = {
    tileTag=10009, paletteTag=10009, callback="AnimEllipticalGust",
    oam={affine=false,objMode="normal",bpp=4,width=32,height=64},
    anim={kind="once",frames={{tileOffset=0,duration=71}}},
    paletteRotations=true,
  },
  gBasicHitSplatSpriteTemplate = {
    tileTag=10135, paletteTag=10135, callback="AnimHitSplatBasic",
    oam={affine=true,objMode="blend",bpp=4,width=32,height=32},
    anim={kind="dummy",frames={{tileOffset=0,duration=1}}},
  },
}

return M
