local M = { id="SLAM", name="Slam" }

-- FireRed Move_SLAM. The attacker dips downward, the dedicated Slam Hit
-- graphic cracks across the target, then the target is shoved diagonally
-- before shaking and returning to its original position.
M.script = {
  { op="loadspritegfx", tag=10056 }, -- ANIM_TAG_SLAM_HIT
  { op="loadspritegfx", tag=10135 }, -- ANIM_TAG_IMPACT
  { op="monbg", battler="target" },
  { op="setalpha", eva=12, evb=8 },

  { op="playsewithpan", sound=132, pan="attacker" }, -- SE_M_COMET_PUNCH
  { op="createsprite", template="gSlideMonToOffsetSpriteTemplate", anchor="attacker", priority=2,
    args={0,20,3,0,4} },
  { op="delay", frames=1 },
  { op="createsprite", template="gSlamHitSpriteTemplate", anchor="attacker", priority=2,
    args={0,0} },
  { op="delay", frames=3 },

  { op="playsewithpan", sound=134, pan="target" }, -- SE_M_MEGA_KICK2
  { op="createsprite", template="gBasicHitSplatSpriteTemplate", anchor="attacker", priority=3,
    args={0,0,"target",1} },
  { op="createsprite", template="gSlideMonToOffsetSpriteTemplate", anchor="attacker", priority=2,
    args={1,-12,10,0,3} },
  { op="createsprite", template="gSlideMonToOriginalPosSpriteTemplate", anchor="attacker", priority=2,
    args={0,0,5} },
  { op="delay", frames=3 },
  { op="createvisualtask", task="AnimTask_ShakeMonInPlace", priority=2,
    args={"target",0,3,6,1} },
  { op="waitforvisualfinish" },
  { op="delay", frames=5 },
  { op="createsprite", template="gSlideMonToOriginalPosSpriteTemplate", anchor="attacker", priority=2,
    args={1,0,6} },
  { op="waitforvisualfinish" },

  { op="clearmonbg", battler="target" },
  { op="blendoff" },
  { op="end" },
}

M.templates = {
  gSlideMonToOffsetSpriteTemplate = {
    controller=true, callback="SlideMonToOffset",
    oam={affine=false,objMode="normal",bpp=4,width=8,height=8},
    anim={kind="dummy",frames={{tileOffset=0,duration=1}}},
  },
  gSlideMonToOriginalPosSpriteTemplate = {
    controller=true, callback="SlideMonToOriginalPos",
    oam={affine=false,objMode="normal",bpp=4,width=8,height=8},
    anim={kind="dummy",frames={{tileOffset=0,duration=1}}},
  },
  gSlamHitSpriteTemplate = {
    tileTag=10056, paletteTag=10056, callback="AnimWhipHit",
    oam={affine=false,objMode="normal",bpp=4,width=32,height=32},
    -- FireRed sAnim_Whip for Slam Hit uses the second four 32x32 frames
    -- from the 0x1000-byte sheet: tile offsets 64, 80, 96, 112.
    anim={kind="once",frames={
      {tileOffset=64,duration=3},
      {tileOffset=80,duration=3},
      {tileOffset=96,duration=3},
      {tileOffset=112,duration=6},
    }},
  },
  gBasicHitSplatSpriteTemplate = {
    tileTag=10135, paletteTag=10135, callback="AnimHitSplatBasic",
    oam={affine=true,objMode="blend",bpp=4,width=32,height=32},
    anim={kind="dummy",frames={{tileOffset=0,duration=1}}},
  },
}

return M
