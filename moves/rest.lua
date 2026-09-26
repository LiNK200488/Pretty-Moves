local M = { id="REST", name="Rest" }

M.soundIds = {190}

-- FireRed Move_REST.
-- SE_M_SNORE plays from the attacker, then three native LETTER_Z sprites are
-- launched from the attacker at 20-frame intervals. AnimSleepLetterZ owns the
-- side-aware drift and affine shrink/rotation.
M.script = {
  { op="playsewithpan", sound=190, pan="attacker" }, -- SE_M_SNORE
  { op="loadspritegfx", tag=10228 }, -- ANIM_TAG_LETTER_Z
  { op="createsprite", template="gSleepLetterZSpriteTemplate", anchor="attacker", priority=2, args={4,-10,16,0,0} },
  { op="delay", frames=20 },
  { op="createsprite", template="gSleepLetterZSpriteTemplate", anchor="attacker", priority=2, args={4,-10,16,0,0} },
  { op="delay", frames=20 },
  { op="createsprite", template="gSleepLetterZSpriteTemplate", anchor="attacker", priority=2, args={4,-10,16,0,0} },
  { op="waitforvisualfinish" },
  { op="end" },
}

M.templates = {
  gSleepLetterZSpriteTemplate = {
    tileTag=10228, paletteTag=10228, callback="AnimSleepLetterZ",
    oam={affine=true,doubleSize=false,objMode="normal",bpp=4,width=32,height=32},
    anim={kind="dummy",frames={{tileOffset=0,duration=40}}},
  },
}

return M
