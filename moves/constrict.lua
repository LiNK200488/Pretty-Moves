local M = { id="CONSTRICT", name="Constrict" }

-- Exact FireRed Move_CONSTRICT choreography.
-- Four target-relative tendril sprites are staged at offsets +16, 0, +8 and -8,
-- with the two affine variants matching the native left/right squeeze geometry.
-- FireRed keeps their affine animation paused until shared anim arg 7 is set to
-- 0xFFFF at script frame 42; the runtime-only fifth argument below records each
-- sprite's remaining wait from its own creation frame so planning is deterministic.
M.soundIds = {148,163}

M.script = {
  { op="loadspritegfx", tag=10186 }, -- ANIM_TAG_TENDRILS
  { op="loopsewithpan", sound=148, pan="target", interval=6, count=4 }, -- SE_M_SCRATCH
  { op="createsprite", template="gConstrictBindingSpriteTemplate", anchor="target", priority=4,
    args={0,16,0,2,42} },
  { op="delay", frames=7 },
  { op="createsprite", template="gConstrictBindingSpriteTemplate", anchor="target", priority=3,
    args={0,0,0,2,35} },
  { op="createsprite", template="gConstrictBindingSpriteTemplate", anchor="target", priority=2,
    args={0,8,1,2,35} },
  { op="delay", frames=7 },
  { op="createsprite", template="gConstrictBindingSpriteTemplate", anchor="target", priority=3,
    args={0,-8,1,2,28} },
  { op="delay", frames=8 },
  { op="createvisualtask", task="AnimTask_ShakeMon2", priority=2,
    args={"target",3,0,6,1} },
  { op="delay", frames=20 },
  { op="playsewithpan", sound=163, pan="target" }, -- SE_M_BIND; source setarg 7,0xFFFF occurs here
  { op="waitforvisualfinish" },
  { op="end" },
}

M.templates = {
  gConstrictBindingSpriteTemplate = {
    tileTag=10186,paletteTag=10186,callback="AnimConstrictBinding",
    oam={affine=true,objMode="normal",bpp=4,width=64,height=32},
    anim={kind="once",frames={
      {tileOffset=0,duration=4},
      {tileOffset=32,duration=4},
      {tileOffset=64,duration=4},
      {tileOffset=96,duration=4},
    }},
  },
}

return M
