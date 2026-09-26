local M = { id="LICK", name="Lick" }

-- Exact FireRed Move_LICK choreography. The tongue plays its five 2-frame
-- animation cells on the target, then AnimLick flickers it five times at the
-- native 3-callback cadence and five more times at the 5-callback cadence
-- before destroying the sprite.
M.soundIds = {181}

M.script = {
  { op="loadspritegfx", tag=10177 }, -- ANIM_TAG_LICK
  { op="delay", frames=15 },
  { op="playsewithpan", sound=181, pan="target" }, -- SE_M_LICK
  { op="createsprite", template="gLickSpriteTemplate", anchor="target", priority=2, args={0,0} },
  { op="createvisualtask", task="AnimTask_ShakeMon2", priority=2, args={"target",1,0,16,1} },
  { op="waitforvisualfinish" },
  { op="end" },
}

M.templates = {
  gLickSpriteTemplate = {
    tileTag=10177, paletteTag=10177, callback="AnimLick",
    oam={affine=false,objMode="normal",bpp=4,width=16,height=32},
    anim={kind="once",frames={
      {tileOffset=0,duration=2},
      {tileOffset=8,duration=2},
      {tileOffset=16,duration=2},
      {tileOffset=24,duration=2},
      {tileOffset=32,duration=2},
    }},
  },
}

return M
