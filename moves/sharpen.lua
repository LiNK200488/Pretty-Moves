local M = { id="SHARPEN", name="Sharpen" }

-- Exact Pokemon FireRed Move_SHARPEN. The 32x32 sphere-to-cube sprite is
-- positioned 12 px above the attacker's picture-offset anchor. Its callback
-- progressively lengthens the visibility blink interval and plays
-- SE_M_SWAGGER2 on every second visible reappearance.
M.soundIds = {187}

M.script = {
  { op="loadspritegfx", tag=10185 }, -- ANIM_TAG_SPHERE_TO_CUBE
  { op="createsprite", template="gSharpenSphereSpriteTemplate", anchor="attacker", priority=2, args={} },
  -- AnimSharpenSphere callback sound ticks: 10, 28, 54, 88, 130, 180, 238.
  { op="delay", frames=10 },
  { op="playsewithpan", sound=187, pan="attacker" }, -- SE_M_SWAGGER2
  { op="delay", frames=18 },
  { op="playsewithpan", sound=187, pan="attacker" },
  { op="delay", frames=26 },
  { op="playsewithpan", sound=187, pan="attacker" },
  { op="delay", frames=34 },
  { op="playsewithpan", sound=187, pan="attacker" },
  { op="delay", frames=42 },
  { op="playsewithpan", sound=187, pan="attacker" },
  { op="delay", frames=50 },
  { op="playsewithpan", sound=187, pan="attacker" },
  { op="delay", frames=58 },
  { op="playsewithpan", sound=187, pan="attacker" },
  { op="waitforvisualfinish" },
  { op="end" },
}

M.templates = {
  gSharpenSphereSpriteTemplate = {
    tileTag=10185, paletteTag=10185, callback="AnimSharpenSphere",
    oam={affine=false,objMode="normal",bpp=4,width=32,height=32},
    anim={kind="once",frames={
      {tileOffset=0,duration=18},
      {tileOffset=0,duration=6},
      {tileOffset=16,duration=18},
      {tileOffset=0,duration=6},
      {tileOffset=16,duration=6},
      {tileOffset=32,duration=18},
      {tileOffset=16,duration=6},
      {tileOffset=32,duration=6},
      {tileOffset=48,duration=18},
      {tileOffset=32,duration=6},
      {tileOffset=48,duration=6},
      {tileOffset=64,duration=18},
      {tileOffset=48,duration=6},
      {tileOffset=64,duration=54},
    }},
  },
}

return M
