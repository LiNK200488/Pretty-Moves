local M = { id="GROWL", name="Growl" }

-- FireRed Move_GROWL visual choreography, with the target project's Gen-I
-- species-aware move cry preserved through Gen1Recomp's Sound.playMoveCry.
M.script = {
  { op="loadspritegfx", tag=10053 }, -- ANIM_TAG_NOISE_LINE
  { op="playmovecry", tempo=0xC0 },  -- Gen-I Growl MoveSoundTable tempo

  -- RoarEffect, first wave.
  { op="createsprite", template="gRoarNoiseLineSpriteTemplate", anchor="attacker", priority=2, args={24,-8,0} },
  { op="createsprite", template="gRoarNoiseLineSpriteTemplate", anchor="attacker", priority=2, args={24, 0,2} },
  { op="createsprite", template="gRoarNoiseLineSpriteTemplate", anchor="attacker", priority=2, args={24, 8,1} },
  { op="delay", frames=15 },

  -- RoarEffect, second wave.
  { op="createsprite", template="gRoarNoiseLineSpriteTemplate", anchor="attacker", priority=2, args={24,-8,0} },
  { op="createsprite", template="gRoarNoiseLineSpriteTemplate", anchor="attacker", priority=2, args={24, 0,2} },
  { op="createsprite", template="gRoarNoiseLineSpriteTemplate", anchor="attacker", priority=2, args={24, 8,1} },
  { op="delay", frames=10 },

  { op="createvisualtask", task="AnimTask_ShakeMon2", priority=2, args={"target",1,0,9,1} },
  { op="waitforvisualfinish" },
  { op="end" },
}

M.templates = {
  gRoarNoiseLineSpriteTemplate = {
    tileTag=10053,paletteTag=10053,callback="AnimRoarNoiseLine",
    oam={affine=false,objMode="normal",bpp=4,width=32,height=32},
    anim={kind="loop",frames={
      {tileOffset=0,duration=3},{tileOffset=16,duration=3},
    }},
  },
}

return M
