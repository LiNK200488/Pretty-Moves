local M = { id="PSYWAVE", name="Psywave" }

M.soundIds = {182, 196}

-- FireRed Move_PSYWAVE.
-- Uses the shared Psychic background, a synchronized sine-wave timer for the
-- blue rings, panning SE_M_TELEPORT pulses, and a target palette cycle.
M.script = {
  { op="loadspritegfx", tag=10165 }, -- ANIM_TAG_BLUE_RING
  { op="playsewithpan", sound=182, pan="attacker" },
  { op="fadetobg", bg="psychic" },
  { op="waitbgfadeout" },
  { op="createvisualtask", task="AnimTask_SetPsychicBackground", priority=5 },
  { op="waitbgfadein" },
  { op="createvisualtask", task="AnimTask_StartSinAnimTimer", priority=5, args={100} },
  { op="createsoundtask", task="SoundTask_LoopSEAdjustPanning", priority=2, args={196,"attacker","target",2,9,0,10} },

  -- PsywaveRings x2 before the palette cycle.
  { op="createsprite", template="gPsywaveRingSpriteTemplate", anchor="target", priority=3, args={10,10,0,16} },
  { op="delay", frames=4 },
  { op="createsprite", template="gPsywaveRingSpriteTemplate", anchor="target", priority=3, args={10,10,0,16} },
  { op="delay", frames=4 },
  { op="createsprite", template="gPsywaveRingSpriteTemplate", anchor="target", priority=3, args={10,10,0,16} },
  { op="delay", frames=4 },
  { op="createsprite", template="gPsywaveRingSpriteTemplate", anchor="target", priority=3, args={10,10,0,16} },
  { op="delay", frames=4 },

  { op="createvisualtask", task="AnimTask_BlendColorCycle", priority=2, args={"target",1,4,0,12,{31,18,31}} },

  -- Four more PsywaveRings calls: eight additional rings.
  { op="createsprite", template="gPsywaveRingSpriteTemplate", anchor="target", priority=3, args={10,10,0,16} },
  { op="delay", frames=4 },
  { op="createsprite", template="gPsywaveRingSpriteTemplate", anchor="target", priority=3, args={10,10,0,16} },
  { op="delay", frames=4 },
  { op="createsprite", template="gPsywaveRingSpriteTemplate", anchor="target", priority=3, args={10,10,0,16} },
  { op="delay", frames=4 },
  { op="createsprite", template="gPsywaveRingSpriteTemplate", anchor="target", priority=3, args={10,10,0,16} },
  { op="delay", frames=4 },
  { op="createsprite", template="gPsywaveRingSpriteTemplate", anchor="target", priority=3, args={10,10,0,16} },
  { op="delay", frames=4 },
  { op="createsprite", template="gPsywaveRingSpriteTemplate", anchor="target", priority=3, args={10,10,0,16} },
  { op="delay", frames=4 },
  { op="createsprite", template="gPsywaveRingSpriteTemplate", anchor="target", priority=3, args={10,10,0,16} },
  { op="delay", frames=4 },
  { op="createsprite", template="gPsywaveRingSpriteTemplate", anchor="target", priority=3, args={10,10,0,16} },
  { op="delay", frames=4 },

  { op="waitforvisualfinish" },
  { op="delay", frames=1 },
  { op="restorebg" },
  { op="waitbgfadeout" },
  { op="setarg", index=7, value=0xFFFF },
  { op="waitbgfadein" },
  { op="end" },
}

M.templates = {
  gPsywaveRingSpriteTemplate = {
    tileTag=10165, paletteTag=10165, callback="AnimToTargetInSinWave",
    oam={affine=true,doubleSize=true,objMode="normal",bpp=4,width=16,height=32},
    -- FireRed gGrowingRingAffineAnimTable: start at 32/256 scale and add
    -- 7/256 per frame for 32 frames, ending at normal size.
    affineAnim={kind="linear_scale",start=32,delta=7,frames=32},
    anim={kind="dummy",frames={{tileOffset=0,duration=1}}},
  },
}

return M
