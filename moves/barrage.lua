local M = { id="BARRAGE", name="Barrage" }

-- Exact FireRed Move_BARRAGE choreography. The projectile itself is spawned
-- by AnimTask_BarrageBall, which performs a 16-step arc, slows the first half,
-- then flickers the RED_BALL sprite out after impact.
M.soundIds = {186,207}

M.script = {
  { op="loadspritegfx", tag=10254 }, -- ANIM_TAG_RED_BALL
  { op="createvisualtask", task="AnimTask_BarrageBall", priority=3, args={} },
  { op="playsewithpan", sound=186, pan="attacker" }, -- SE_M_SWAGGER
  { op="delay", frames=24 },
  { op="createsprite", template="gShakeMonOrTerrainSpriteTemplate", anchor="attacker", priority=2,
    args={8,1,40,1} },
  { op="createvisualtask", task="AnimTask_ShakeMon", priority=3, args={"target",0,4,20,1} },
  { op="createvisualtask", task="AnimTask_ShakeMon", priority=3, args={"def_partner",0,4,20,1} },
  { op="loopsewithpan", sound=207, pan="target", interval=8, count=2 }, -- SE_M_STRENGTH
  { op="end" },
}

M.templates = {
  -- Created by AnimTask_BarrageBall rather than by a createsprite opcode.
  gBarrageBallSpriteTemplate = {
    tileTag=10254, paletteTag=10254, callback="SpriteCallbackDummy",
    oam={affine=true,objMode="normal",bpp=4,width=32,height=32},
    anim={kind="dummy",frames={{tileOffset=0,duration=1}}},
  },
  gShakeMonOrTerrainSpriteTemplate = {
    controller=true, callback="AnimShakeMonOrBattleTerrain",
    oam={affine=false,objMode="normal",bpp=4,width=8,height=8},
    anim={kind="dummy",frames={{tileOffset=0,duration=1}}},
  },
}

return M
