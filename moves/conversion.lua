local M = { id="CONVERSION", name="Conversion" }

local CONVERSION_TAG = 10018

-- Clean source-faithful FireRed port. 16 conversion cells are spawned as a
-- 4x4 grid over the attacker. Each cell plays frames 3,2,1,0 for 5 ticks each,
-- then holds frame 0 until the shared yellow flash/fade releases the grid.
M.soundIds = {129, 122}

M.script = {
  { op="loadspritegfx", tag=CONVERSION_TAG },
  { op="monbg", battler="attacker_partner" },
  { op="splitbgprio", battler="attacker" },
  { op="setalpha", eva=16, evb=0 },
  { op="delay", frames=0 },

  { op="playsewithpan", sound=129, pan="attacker" },
  { op="createsprite", template="gConversionSpriteTemplate", anchor="attacker", priority=2, args={-24,-24} },
  { op="delay", frames=3 },
  { op="createsprite", template="gConversionSpriteTemplate", anchor="attacker", priority=2, args={-8,-24} },
  { op="delay", frames=3 },
  { op="createsprite", template="gConversionSpriteTemplate", anchor="attacker", priority=2, args={8,-24} },
  { op="delay", frames=3 },
  { op="createsprite", template="gConversionSpriteTemplate", anchor="attacker", priority=2, args={24,-24} },
  { op="delay", frames=3 },

  { op="playsewithpan", sound=129, pan="attacker" },
  { op="createsprite", template="gConversionSpriteTemplate", anchor="attacker", priority=2, args={-24,-8} },
  { op="delay", frames=3 },
  { op="createsprite", template="gConversionSpriteTemplate", anchor="attacker", priority=2, args={-8,-8} },
  { op="delay", frames=3 },
  { op="createsprite", template="gConversionSpriteTemplate", anchor="attacker", priority=2, args={8,-8} },
  { op="delay", frames=3 },
  { op="createsprite", template="gConversionSpriteTemplate", anchor="attacker", priority=2, args={24,-8} },
  { op="delay", frames=3 },

  { op="playsewithpan", sound=129, pan="attacker" },
  { op="createsprite", template="gConversionSpriteTemplate", anchor="attacker", priority=2, args={-24,8} },
  { op="delay", frames=3 },
  { op="createsprite", template="gConversionSpriteTemplate", anchor="attacker", priority=2, args={-8,8} },
  { op="delay", frames=3 },
  { op="createsprite", template="gConversionSpriteTemplate", anchor="attacker", priority=2, args={8,8} },
  { op="delay", frames=3 },
  { op="createsprite", template="gConversionSpriteTemplate", anchor="attacker", priority=2, args={24,8} },
  { op="delay", frames=3 },

  { op="playsewithpan", sound=129, pan="attacker" },
  { op="createsprite", template="gConversionSpriteTemplate", anchor="attacker", priority=2, args={-24,24} },
  { op="delay", frames=3 },
  { op="createsprite", template="gConversionSpriteTemplate", anchor="attacker", priority=2, args={-8,24} },
  { op="delay", frames=3 },
  { op="createsprite", template="gConversionSpriteTemplate", anchor="attacker", priority=2, args={8,24} },
  { op="delay", frames=3 },
  { op="createsprite", template="gConversionSpriteTemplate", anchor="attacker", priority=2, args={24,24} },
  { op="delay", frames=20 },

  { op="playsewithpan", sound=122, pan="attacker" },
  { op="createvisualtask", task="AnimTask_FlashAnimTagWithColor", priority=2,
    args={CONVERSION_TAG,1,1,{31,31,13},12,0,0} },
  { op="delay", frames=6 },
  { op="createvisualtask", task="AnimTask_ConversionAlphaBlend", priority=5, args={} },
  { op="waitforvisualfinish" },
  { op="delay", frames=1 },
  { op="clearmonbg", battler="attacker_partner" },
  { op="blendoff" },
  { op="end" },
}

M.templates = {
  gConversionSpriteTemplate = {
    tileTag=CONVERSION_TAG, paletteTag=CONVERSION_TAG, callback="AnimConversion",
    -- FireRed uses affine-double OBJ mode with sConversionAffineAnimCmds at
    -- 0x200/0x200. In the sprite affine animation API, 0x100 is 1x and 0x200
    -- displays this 8x8 tile at 2x (16x16), matching the script's 16 px grid spacing.
    oam={affine=true,doubleSize=true,objMode="blend",bpp=4,width=8,height=8},
    anim={kind="once",frames={
      {tileOffset=3,duration=5},
      {tileOffset=2,duration=5},
      {tileOffset=1,duration=5},
      {tileOffset=0,duration=5},
    }},
  },
}

return M
