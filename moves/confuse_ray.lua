local M = { id="CONFUSE_RAY", name="Confuse Ray" }

-- Confuse Ray owns two FireRed SFX: SE_M_CONFUSE_RAY (189), played from the
-- bounce sprite callback, and SE_M_STRING_SHOT2 (123), played when the spiral
-- begins. Declare both explicitly so the move audio contract is self-contained.
-- The registry also sees scripted playse commands, but keeping both here makes
-- callback/script ownership unambiguous and protects future script refactors.
M.soundIds = {189, 123}

-- FireRed Move_CONFUSE_RAY. Confusion itself remains owned by the shared
-- status bridge; this file contains only the move's own ray choreography.
M.script = {
  { op="loadspritegfx", tag=10013 }, -- ANIM_TAG_YELLOW_BALL
  { op="monbg", battler="def_partner" },
  { op="fadetobg", bg="ghost" },
  { op="waitbgfadein" },
  { op="createvisualtask", task="SoundTask_AdjustPanningVar", priority=2, args={"attacker","target",2,0} },
  { op="createvisualtask", task="AnimTask_BlendColorCycleByTag", priority=2, args={10013,0,6,0,14,{31,10,0}} },
  { op="createsprite", template="gConfuseRayBallBounceSpriteTemplate", anchor="target", priority=2, args={28,0,288} },
  { op="waitforvisualfinish" },
  { op="setalpha", eva=8, evb=8 },
  { op="playsewithpan", sound=123, pan="target" }, -- SE_M_STRING_SHOT2
  { op="createsprite", template="gConfuseRayBallSpiralSpriteTemplate", anchor="target", priority=2, args={0,-16} },
  { op="waitforvisualfinish" },
  { op="delay", frames=0 },
  { op="blendoff" },
  { op="clearmonbg", battler="def_partner" },
  { op="restorebg" },
  { op="waitbgfadein" },
  { op="end" },
}

M.templates = {
  gConfuseRayBallBounceSpriteTemplate = {
    tileTag=10013, paletteTag=10013, callback="AnimConfuseRayBallBounce",
    oam={affine=true,doubleSize=true,objMode="normal",bpp=4,width=16,height=16},
    anim={kind="dummy",frames={{tileOffset=0,duration=1}}},
  },
  gConfuseRayBallSpiralSpriteTemplate = {
    tileTag=10013, paletteTag=10013, callback="AnimConfuseRayBallSpiral",
    oam={affine=false,objMode="blend",bpp=4,width=16,height=16},
    anim={kind="dummy",frames={{tileOffset=0,duration=1}}},
  },
}

return M
