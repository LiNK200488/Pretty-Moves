local M = { id="LEECH_SEED", name="Leech Seed" }

-- Exact FireRed Move_LEECH_SEED choreography from data/battle_anim_scripts.s.
-- No extra impact sprites, target shake, or invented planting effect.
M.script = {
  { op="loadspritegfx", tag=10006 }, -- ANIM_TAG_SEED
  { op="playsewithpan", sound=162, pan="attacker" }, -- SE_M_POISON_POWDER
  { op="createsprite", template="gLeechSeedSpriteTemplate", anchor="target", priority=2,
    args={15,0,0,24,35,-32} },
  { op="delay", frames=8 },
  { op="playsewithpan", sound=162, pan="attacker" },
  { op="createsprite", template="gLeechSeedSpriteTemplate", anchor="target", priority=2,
    args={15,0,-16,24,35,-40} },
  { op="delay", frames=8 },
  { op="playsewithpan", sound=162, pan="attacker" },
  { op="createsprite", template="gLeechSeedSpriteTemplate", anchor="target", priority=2,
    args={15,0,16,24,35,-37} },
  { op="delay", frames=12 },
  { op="loopsewithpan", sound=160, pan="target", interval=10, count=8 }, -- SE_M_TAIL_WHIP
  { op="waitforvisualfinish" },
  { op="end" },
}

M.templates = {
  gLeechSeedSpriteTemplate = {
    tileTag=10006, paletteTag=10006, callback="AnimLeechSeed",
    oam={affine=false,objMode="normal",bpp=4,width=16,height=16},
    -- Native anim 0 is the seed. On landing the callback waits 10 frames then
    -- starts anim 1, alternating sprout frames 4/8 every 7 frames for 60 frames.
    anim={kind="once",frames={{tileOffset=0,duration=1}}},
    -- AnimLeechSeedSprouts switches to anim 1 after the 10-frame hidden pause.
    -- These frames must be resident even though the script starts on anim 0.
    extraTileOffsets={4,8},
  },
}

return M
