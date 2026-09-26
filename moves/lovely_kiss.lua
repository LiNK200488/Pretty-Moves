local M = { id="LOVELY_KISS", name="Lovely Kiss" }

-- Source-faithful Pokemon FireRed Move_LOVELY_KISS.
-- Devil orbits/flickers around the target, then four pink hearts drift and fall.
M.soundIds = {193,219}

M.script = {
  { op="loadspritegfx", tag=10219 }, -- ANIM_TAG_PINK_HEART
  { op="loadspritegfx", tag=10221 }, -- ANIM_TAG_DEVIL
  { op="createsprite", template="gDevilSpriteTemplate", anchor="target", priority=2, args={0,-24} },
  { op="playsewithpan", sound=193, pan="target" }, -- SE_M_PSYBEAM2
  { op="waitforvisualfinish" },
  { op="playsewithpan", sound=219, pan="target" }, -- SE_M_ATTRACT
  { op="createsprite", template="gPinkHeartSpriteTemplate", anchor="target", priority=3, args={-256,-42} },
  { op="createsprite", template="gPinkHeartSpriteTemplate", anchor="target", priority=3, args={128,-14} },
  { op="createsprite", template="gPinkHeartSpriteTemplate", anchor="target", priority=3, args={416,-38} },
  { op="createsprite", template="gPinkHeartSpriteTemplate", anchor="target", priority=3, args={-128,-22} },
  { op="end" },
}

M.templates = {
  gDevilSpriteTemplate = {
    tileTag=10221, paletteTag=10221, callback="AnimDevil",
    oam={affine=false,objMode="normal",bpp=4,width=32,height=32},
    anim={kind="loop",frames={{tileOffset=0,duration=3}}},
  },
  gPinkHeartSpriteTemplate = {
    tileTag=10219, paletteTag=10219, callback="AnimPinkHeart",
    oam={affine=false,objMode="normal",bpp=4,width=16,height=16},
    anim={kind="dummy",frames={{tileOffset=0,duration=1}}},
  },
}

return M
