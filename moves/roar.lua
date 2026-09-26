local M = { id="ROAR", name="Roar" }

-- FireRed Move_ROAR. Roar shares Growl's native two-wave noise-line visual,
-- but scales the attacker while roaring and then slides the target completely
-- off-screen. The target project's species-aware Gen-I move cry is preserved
-- through Gen1Recomp's Sound.playMoveCry using Roar's MoveSoundTable tempo.
M.script = {
  { op="loadspritegfx", tag=10053 }, -- ANIM_TAG_NOISE_LINE
  { op="monbg", battler="attacker" },
  { op="splitbgprio", battler="attacker" },
  { op="setalpha", eva=8, evb=8 },
  { op="playmovecry", tempo=0x40 }, -- Gen-I Roar MoveSoundTable tempo
  { op="createvisualtask", task="AnimTask_ScaleMonAndRestore", priority=5,
    args={-5,-5,10,"attacker",1} },

  -- FireRed RoarEffect: first wave.
  { op="createsprite", template="gRoarNoiseLineSpriteTemplate", anchor="attacker", priority=2, args={24,-8,0} },
  { op="createsprite", template="gRoarNoiseLineSpriteTemplate", anchor="attacker", priority=2, args={24, 0,2} },
  { op="createsprite", template="gRoarNoiseLineSpriteTemplate", anchor="attacker", priority=2, args={24, 8,1} },
  { op="delay", frames=15 },

  -- FireRed RoarEffect: second wave.
  { op="createsprite", template="gRoarNoiseLineSpriteTemplate", anchor="attacker", priority=2, args={24,-8,0} },
  { op="createsprite", template="gRoarNoiseLineSpriteTemplate", anchor="attacker", priority=2, args={24, 0,2} },
  { op="createsprite", template="gRoarNoiseLineSpriteTemplate", anchor="attacker", priority=2, args={24, 8,1} },

  { op="delay", frames=20 },
  { op="createvisualtask", task="AnimTask_SlideOffScreen", priority=5, args={"target",2} },
  { op="waitforvisualfinish" },
  { op="clearmonbg", battler="attacker" },
  { op="blendoff" },
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
