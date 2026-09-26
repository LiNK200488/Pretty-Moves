local M = { id="METRONOME", name="Metronome" }

-- FireRed Move_METRONOME, source-faithful. The called random move is handled
-- by Gen1Recomp after this pre-cast gesture; this file owns only the gesture.
M.script = {
  { op="loadspritegfx", tag=10064 }, -- ANIM_TAG_FINGER
  { op="loadspritegfx", tag=10209 }, -- ANIM_TAG_THOUGHT_BUBBLE
  { op="createsprite", template="gThoughtBubbleSpriteTemplate", anchor="attacker", priority=11,
    args={0,100} },
  { op="playsewithpan", sound=179, pan="attacker" }, -- SE_M_METRONOME
  { op="delay", frames=6 },
  { op="createsprite", template="gMetronomeFingerSpriteTemplate", anchor="attacker", priority=12,
    args={0} },
  { op="delay", frames=24 },
  { op="loopsewithpan", sound=160, pan="attacker", interval=22, count=3 }, -- SE_M_TAIL_WHIP
  { op="waitforvisualfinish" },
  { op="end" },
}

M.templates = {
  gThoughtBubbleSpriteTemplate = {
    tileTag=10209,paletteTag=10209,callback="AnimThoughtBubble",
    oam={affine=false,objMode="normal",bpp=4,width=32,height=32},
    anim={kind="dummy",frames={{tileOffset=0,duration=1}}},
    -- FireRed's thought-bubble sheet contains four 32x32 frames at tile
    -- offsets 0/16/32/48.  The callback selects them manually, so make sure
    -- the shared asset cache decodes all four instead of only frame 0.
    extraTileOffsets={16,32,48},
  },
  gMetronomeFingerSpriteTemplate = {
    tileTag=10064,paletteTag=10064,callback="AnimMetronomeFinger",
    oam={affine=true,objMode="normal",bpp=4,width=32,height=32},
    anim={kind="dummy",frames={{tileOffset=0,duration=1}}},
  },
}

return M
