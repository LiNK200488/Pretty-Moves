local M = { id="DISABLE", name="Disable" }

M.soundIds = {202,163}

-- Exact FireRed Move_DISABLE choreography. The native SPARKLE_4 animation
-- appears beside the attacker, then AnimTask_GrowAndGrayscale holds the target
-- at the GBA affine matrix 0xD0/0xD0 (256/208 visual scale) and full grayscale
-- for 81 callbacks before restoring it.
M.script = {
  { op="loadspritegfx", tag=10071 }, -- ANIM_TAG_SPARKLE_4
  { op="monbg", battler="target" },
  { op="splitbgprio", battler="target" },
  { op="setalpha", eva=8, evb=8 },
  { op="playsewithpan", sound=202, pan="attacker" }, -- SE_M_DETECT
  { op="createsprite", template="gSpinningSparkleSpriteTemplate", anchor="attacker", priority=13, args={24,-16} },
  { op="waitforvisualfinish" },
  { op="createvisualtask", task="AnimTask_GrowAndGrayscale", priority=5, args={} },
  { op="loopsewithpan", sound=163, pan="target", interval=15, count=4 }, -- SE_M_BIND
  { op="waitforvisualfinish" },
  { op="delay", frames=1 },
  { op="clearmonbg", battler="target" },
  { op="blendoff" },
  { op="end" },
}

M.templates = {
  gSpinningSparkleSpriteTemplate = {
    tileTag=10071,paletteTag=10071,callback="AnimSpinningSparkle",
    oam={affine=false,objMode="normal",bpp=4,width=32,height=32},
    anim={kind="once",frames={
      {tileOffset=0,duration=3},
      {tileOffset=16,duration=3},
      {tileOffset=32,duration=3},
      {tileOffset=48,duration=3},
      {tileOffset=64,duration=3},
    }},
  },
}

return M
