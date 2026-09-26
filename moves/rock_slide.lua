local M = { id="ROCK_SLIDE", name="Rock Slide" }

-- Source-traced FireRed Move_ROCK_SLIDE. Twenty native falling-rock sprites
-- rain around the target in a dense 2-frame cadence while the target side
-- shakes for 50 frames. FireRed also runs gShakeMonOrTerrainSpriteTemplate
-- with args {7,1,11,1}, vertically shaking BG3 during the opening barrage.
M.script = {
  { op="loadspritegfx", tag=10058 }, -- ANIM_TAG_ROCKS
  { op="monbg", battler="def_partner" },

  { op="createsprite", template="gShakeMonOrTerrainSpriteTemplate", anchor="attacker", priority=2, args={7,1,11,1} },
  { op="createsprite", template="gFallingRockSpriteTemplate", anchor="target", priority=2, args={-5,1,-5,1} },
  { op="playsewithpan", sound=124, pan="target" },
  { op="delay", frames=2 },
  { op="createsprite", template="gFallingRockSpriteTemplate", anchor="target", priority=2, args={5,0,6,1} },
  { op="playsewithpan", sound=124, pan="target" },
  { op="delay", frames=2 },
  { op="createsprite", template="gFallingRockSpriteTemplate", anchor="target", priority=2, args={19,1,10,1} },
  { op="playsewithpan", sound=124, pan="target" },
  { op="delay", frames=2 },
  { op="createsprite", template="gFallingRockSpriteTemplate", anchor="target", priority=2, args={-23,2,-10,1} },
  { op="playsewithpan", sound=124, pan="target" },
  { op="createvisualtask", task="AnimTask_ShakeMon", priority=2, args={"target",0,5,50,1} },
  { op="createvisualtask", task="AnimTask_ShakeMon", priority=2, args={"def_partner",0,5,50,1} },
  { op="delay", frames=2 },

  { op="createsprite", template="gFallingRockSpriteTemplate", anchor="target", priority=2, args={-20,0,-10,1} },
  { op="playsewithpan", sound=124, pan="target" },
  { op="delay", frames=2 },
  { op="createsprite", template="gFallingRockSpriteTemplate", anchor="target", priority=2, args={28,1,10,1} },
  { op="playsewithpan", sound=124, pan="target" },
  { op="delay", frames=2 },
  { op="createsprite", template="gFallingRockSpriteTemplate", anchor="target", priority=2, args={-10,1,-5,1} },
  { op="playsewithpan", sound=124, pan="target" },
  { op="delay", frames=2 },
  { op="createsprite", template="gFallingRockSpriteTemplate", anchor="target", priority=2, args={10,0,6,1} },
  { op="playsewithpan", sound=124, pan="target" },
  { op="delay", frames=2 },
  { op="createsprite", template="gFallingRockSpriteTemplate", anchor="target", priority=2, args={24,1,10,1} },
  { op="playsewithpan", sound=124, pan="target" },
  { op="delay", frames=2 },
  { op="createsprite", template="gFallingRockSpriteTemplate", anchor="target", priority=2, args={-32,2,-10,1} },
  { op="playsewithpan", sound=124, pan="target" },
  { op="delay", frames=2 },
  { op="createsprite", template="gFallingRockSpriteTemplate", anchor="target", priority=2, args={-20,0,-10,1} },
  { op="playsewithpan", sound=124, pan="target" },
  { op="delay", frames=2 },
  { op="createsprite", template="gFallingRockSpriteTemplate", anchor="target", priority=2, args={30,2,10,1} },
  { op="playsewithpan", sound=124, pan="target" },
  { op="delay", frames=2 },

  { op="createsprite", template="gFallingRockSpriteTemplate", anchor="target", priority=2, args={-20,0,-10,1} },
  { op="playsewithpan", sound=124, pan="target" },
  { op="delay", frames=2 },
  { op="createsprite", template="gFallingRockSpriteTemplate", anchor="target", priority=2, args={28,1,10,1} },
  { op="playsewithpan", sound=124, pan="target" },
  { op="delay", frames=2 },
  { op="createsprite", template="gFallingRockSpriteTemplate", anchor="target", priority=2, args={-10,1,-5,1} },
  { op="playsewithpan", sound=124, pan="target" },
  { op="delay", frames=2 },
  { op="createsprite", template="gFallingRockSpriteTemplate", anchor="target", priority=2, args={10,0,6,1} },
  { op="playsewithpan", sound=124, pan="target" },
  { op="delay", frames=2 },
  { op="createsprite", template="gFallingRockSpriteTemplate", anchor="target", priority=2, args={24,1,10,1} },
  { op="playsewithpan", sound=124, pan="target" },
  { op="delay", frames=2 },
  { op="createsprite", template="gFallingRockSpriteTemplate", anchor="target", priority=2, args={-32,2,-10,1} },
  { op="playsewithpan", sound=124, pan="target" },
  { op="delay", frames=2 },
  { op="createsprite", template="gFallingRockSpriteTemplate", anchor="target", priority=2, args={-20,0,-10,1} },
  { op="playsewithpan", sound=124, pan="target" },
  { op="delay", frames=2 },
  { op="createsprite", template="gFallingRockSpriteTemplate", anchor="target", priority=2, args={30,2,10,1} },
  { op="playsewithpan", sound=124, pan="target" },
  { op="delay", frames=2 },

  { op="waitforvisualfinish" },
  { op="clearmonbg", battler="def_partner" },
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
