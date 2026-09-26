local M = { id="LIGHT_SCREEN", name="Light Screen" }

-- Exact FireRed Move_LIGHT_SCREEN choreography.
M.script = {
  { op="loadspritegfx", tag=10070 }, -- ANIM_TAG_SPARKLE_3
  { op="loadspritegfx", tag=10166 }, -- ANIM_TAG_GREEN_LIGHT_WALL
  { op="setalpha", eva=0, evb=16 },
  { op="waitplaysewithpan", sound=200, pan="attacker", wait=15 }, -- SE_M_REFLECT
  { op="createsprite", template="gLightScreenWallSpriteTemplate", anchor="attacker", priority=1,
    args={24,0,10166} },
  { op="delay", frames=10 },
  { op="createsprite", template="gSpecialScreenSparkleSpriteTemplate", anchor="attacker", priority=2,
    args={23,0,0,1} },
  { op="delay", frames=6 },
  { op="createsprite", template="gSpecialScreenSparkleSpriteTemplate", anchor="attacker", priority=2,
    args={31,-8,0,1} },
  { op="delay", frames=5 },
  { op="createsprite", template="gSpecialScreenSparkleSpriteTemplate", anchor="attacker", priority=2,
    args={30,20,0,1} },
  { op="delay", frames=7 },
  { op="createsprite", template="gSpecialScreenSparkleSpriteTemplate", anchor="attacker", priority=2,
    args={10,-15,0,1} },
  { op="delay", frames=6 },
  { op="createsprite", template="gSpecialScreenSparkleSpriteTemplate", anchor="attacker", priority=2,
    args={20,10,0,1} },
  { op="delay", frames=6 },
  { op="createsprite", template="gSpecialScreenSparkleSpriteTemplate", anchor="attacker", priority=2,
    args={10,18,0,1} },
  { op="waitforvisualfinish" },
  { op="delay", frames=1 },
  { op="blendoff" },
  { op="end" },
}

M.templates = {
  gLightScreenWallSpriteTemplate = {
    tileTag=10166,paletteTag=10166,callback="AnimDefensiveWall",
    oam={affine=false,objMode="blend",bpp=4,width=64,height=64},
    anim={kind="dummy",frames={{tileOffset=0,duration=1}}},
  },
  gSpecialScreenSparkleSpriteTemplate = {
    tileTag=10070,paletteTag=10070,callback="AnimWallSparkle",
    oam={affine=false,objMode="normal",bpp=4,width=16,height=16},
    anim={kind="sequence",frames={
      {tileOffset=0,duration=5},{tileOffset=4,duration=5},
      {tileOffset=8,duration=5},{tileOffset=12,duration=5},
    }},
  },
}

return M
