local M = { id="DEFENSE_CURL", name="Defense Curl" }

-- Source-faithful Pokemon FireRed Move_DEFENSE_CURL.
-- The attacker is turned grayscale while three 16-frame affine deform cycles
-- squash/stretch it, then the 32x32 eclipsing orb animates over the user before
-- the original palette is restored.
M.soundIds = {213}

M.script = {
  { op="loadspritegfx", tag=10234 }, -- ANIM_TAG_ECLIPSING_ORB
  { op="loopsewithpan", sound=213, pan="attacker", interval=18, count=3 }, -- SE_M_TRI_ATTACK
  { op="createvisualtask", task="AnimTask_SetGrayscaleOrOriginalPal", priority=5,
    args={"attacker",0} },
  { op="createvisualtask", task="AnimTask_DefenseCurlDeformMon", priority=5, args={} },
  { op="waitforvisualfinish" },
  { op="createsprite", template="gEclipsingOrbSpriteTemplate", anchor="attacker", priority=2,
    args={0,6,0,1} },
  { op="waitforvisualfinish" },
  { op="createvisualtask", task="AnimTask_SetGrayscaleOrOriginalPal", priority=5,
    args={"attacker",1} },
  { op="waitforvisualfinish" },
  { op="end" },
}

M.templates = {
  gEclipsingOrbSpriteTemplate = {
    tileTag=10234,paletteTag=10234,callback="AnimSpriteOnMonPos",
    oam={affine=false,objMode="normal",bpp=4,width=32,height=32},
    anim={kind="once",frames={
      {tileOffset=0,duration=3},{tileOffset=16,duration=3},
      {tileOffset=32,duration=3},{tileOffset=48,duration=3},
      {tileOffset=32,duration=3,hFlip=true},{tileOffset=16,duration=3,hFlip=true},
      {tileOffset=0,duration=3,hFlip=true},
      {tileOffset=0,duration=3},{tileOffset=16,duration=3},
      {tileOffset=32,duration=3},{tileOffset=48,duration=3},
      {tileOffset=32,duration=3,hFlip=true},{tileOffset=16,duration=3,hFlip=true},
      {tileOffset=0,duration=3,hFlip=true},
    }},
    extraTileOffsets={16,32,48},
  },
}

return M
