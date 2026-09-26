local M = { id="ROCK_THROW", name="Rock Throw" }

-- Source-traced FireRed Move_ROCK_THROW. Five rocks fall around the target
-- in three native rock variants, staggered six frames apart. FireRed also
-- starts gShakeMonOrTerrainSpriteTemplate with args {6,1,15,1}, which shakes
-- the battle terrain vertically while leaving the falling rocks on their
-- native coordinates.
M.script = {
  { op="loadspritegfx", tag=10058 }, -- ANIM_TAG_ROCKS
  { op="createsprite", template="gShakeMonOrTerrainSpriteTemplate", anchor="target", priority=2, args={6,1,15,1} },
  { op="createsprite", template="gFallingRockSpriteTemplate", anchor="target", priority=2, args={0,1,0,0} },
  { op="playsewithpan", sound=124, pan="target" }, -- SE_M_ROCK_THROW
  { op="delay", frames=6 },
  { op="createsprite", template="gFallingRockSpriteTemplate", anchor="target", priority=2, args={19,1,10,0} },
  { op="playsewithpan", sound=124, pan="target" },
  { op="delay", frames=6 },
  { op="createsprite", template="gFallingRockSpriteTemplate", anchor="target", priority=2, args={-23,2,-10,0} },
  { op="playsewithpan", sound=124, pan="target" },
  { op="createvisualtask", task="AnimTask_ShakeMon", priority=2, args={"target",0,5,20,1} },
  { op="delay", frames=6 },
  { op="createsprite", template="gFallingRockSpriteTemplate", anchor="target", priority=2, args={-15,1,-10,0} },
  { op="playsewithpan", sound=124, pan="target" },
  { op="delay", frames=6 },
  { op="createsprite", template="gFallingRockSpriteTemplate", anchor="target", priority=2, args={23,2,10,0} },
  { op="playsewithpan", sound=124, pan="target" },
  { op="waitforvisualfinish" },
  { op="end" },
}

M.templates = {
  gShakeMonOrTerrainSpriteTemplate = {
    controller=true, callback="AnimShakeMonOrBattleTerrain",
    oam={affine=false,objMode="normal",bpp=4,width=8,height=8},
    anim={kind="dummy",frames={{tileOffset=0,duration=1}}},
  },
  gFallingRockSpriteTemplate = {
    tileTag=10058,paletteTag=10058,callback="AnimFallingRock",
    oam={affine=false,objMode="normal",bpp=4,width=32,height=32},
    anim={kind="dummy",frames={{tileOffset=32,duration=1}}},
    extraTileOffsets={48,64},
  },
}

return M
