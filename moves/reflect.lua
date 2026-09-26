local M = { id="REFLECT", name="Reflect" }

-- FireRed Move_REFLECT choreography, with the established host-layout wall
-- placement correction (X +24 instead of the GBA script's raw +40).
M.script = {
  { op="loadspritegfx", tag=10071 }, -- ANIM_TAG_SPARKLE_4
  { op="loadspritegfx", tag=10167 }, -- ANIM_TAG_BLUE_LIGHT_WALL
  { op="setalpha", eva=0, evb=16 },
  { op="waitplaysewithpan", sound=200, pan="attacker", wait=15 }, -- SE_M_REFLECT
  { op="createsprite", template="gReflectWallSpriteTemplate", anchor="attacker", priority=1,
    args={24,0,10167} },
  { op="delay", frames=20 },
  { op="createsprite", template="gReflectSparkleSpriteTemplate", anchor="attacker", priority=2,
    args={30,0,0,1} },
  { op="delay", frames=7 },
  { op="createsprite", template="gReflectSparkleSpriteTemplate", anchor="attacker", priority=2,
    args={19,-12,0,1} },
  { op="delay", frames=7 },
  { op="createsprite", template="gReflectSparkleSpriteTemplate", anchor="attacker", priority=2,
    args={10,20,0,1} },
  { op="waitforvisualfinish" },
  { op="delay", frames=1 },
  { op="blendoff" },
  { op="end" },
}

M.templates = {
  gReflectWallSpriteTemplate = {
    tileTag=10167,paletteTag=10167,callback="AnimDefensiveWall",
    oam={affine=false,objMode="blend",bpp=4,width=64,height=64},
    anim={kind="dummy",frames={{tileOffset=0,duration=1}}},
  },
  gReflectSparkleSpriteTemplate = {
    tileTag=10071,paletteTag=10071,callback="AnimWallSparkle",
    oam={affine=false,objMode="normal",bpp=4,width=32,height=32},
    anim={kind="sequence",frames={
      {tileOffset=0,duration=3},{tileOffset=16,duration=3},
      {tileOffset=32,duration=3},{tileOffset=48,duration=3},
      {tileOffset=64,duration=3},
    }},
  },
}

return M
