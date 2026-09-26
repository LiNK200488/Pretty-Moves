local M = { id="SCREECH", name="Screech" }

M.soundIds = {174}

-- FireRed Move_SCREECH.
-- Two expanding purple rings travel from attacker to target at 2-frame spacing.
-- The attacker gives a short 3 px shake, then the target sways after a 16-frame
-- pause. The rings use the same native gGrowingRingAffineAnimTable as Supersonic.
M.script = {
  { op="loadspritegfx", tag=10164 }, -- ANIM_TAG_PURPLE_RING
  { op="createvisualtask", task="AnimTask_ShakeMon2", priority=2, args={"attacker",3,0,2,1} },

  { op="playsewithpan", sound=174, pan="attacker" },
  { op="createsprite", template="gScreechRingSpriteTemplate", anchor="target", priority=2, args={16,0,0,0,30,0} },
  { op="delay", frames=2 },

  { op="playsewithpan", sound=174, pan="attacker" },
  { op="createsprite", template="gScreechRingSpriteTemplate", anchor="target", priority=2, args={16,0,0,0,30,0} },
  { op="delay", frames=2 },

  { op="delay", frames=16 },
  { op="createvisualtask", task="AnimTask_SwayMon", priority=5, args={0,6,2048,2,"target"} },
  { op="waitforvisualfinish" },
  { op="end" },
}

M.templates = {
  gScreechRingSpriteTemplate = {
    tileTag=10164, paletteTag=10164, callback="TranslateAnimSpriteToTargetMonLocation",
    oam={affine=true,doubleSize=true,objMode="normal",bpp=4,width=16,height=32},
    -- FireRed gGrowingRingAffineAnimTable: start at 32/256 scale and grow by
    -- +7/256 per frame for 32 frames.
    affineAnim={kind="linear_scale",start=32,delta=7,frames=32},
    anim={kind="dummy",frames={{tileOffset=0,duration=1}}},
  },
}

return M
