local M = { id="SWIFT", name="Swift" }

-- Canonical FireRed Move_SWIFT choreography. Five native yellow stars travel
-- from the attacker to the target on short sine-wave paths while SE_M_SWIFT
-- is retriggered for each launch. The target shake begins with the third star.
M.script = {
  { op="loadspritegfx", tag=10174 }, -- ANIM_TAG_YELLOW_STAR
  { op="loadspritegfx", tag=10135 }, -- ANIM_TAG_IMPACT (loaded by FireRed script)
  { op="monbg", battler="def_partner" },
  { op="setalpha", eva=12, evb=8 },
  { op="playsewithpan", sound=199, pan="attacker" }, -- SE_M_SWIFT
  { op="createsprite", template="gSwiftStarSpriteTemplate", anchor="target", priority=3, args={20,-10,20,0,22,20,1} },
  { op="delay", frames=5 },
  { op="playsewithpan", sound=199, pan="attacker" },
  { op="createsprite", template="gSwiftStarSpriteTemplate", anchor="target", priority=3, args={20,-10,20,5,22,-18,1} },
  { op="delay", frames=5 },
  { op="playsewithpan", sound=199, pan="attacker" },
  { op="createsprite", template="gSwiftStarSpriteTemplate", anchor="target", priority=3, args={20,-10,20,-10,22,15,1} },
  { op="createvisualtask", task="AnimTask_ShakeMon2", priority=2, args={"target",2,0,18,1} },
  { op="createvisualtask", task="AnimTask_ShakeMon2", priority=2, args={"def_partner",2,0,18,1} },
  { op="delay", frames=5 },
  { op="playsewithpan", sound=199, pan="attacker" },
  { op="createsprite", template="gSwiftStarSpriteTemplate", anchor="target", priority=3, args={20,-10,20,0,22,-20,1} },
  { op="delay", frames=5 },
  { op="playsewithpan", sound=199, pan="attacker" },
  { op="createsprite", template="gSwiftStarSpriteTemplate", anchor="target", priority=3, args={20,-10,20,0,22,12,1} },
  { op="delay", frames=5 },
  { op="waitforvisualfinish" },
  { op="clearmonbg", battler="def_partner" },
  { op="blendoff" },
  { op="end" },
}

M.templates = {
  gSwiftStarSpriteTemplate = {
    tileTag=10174, paletteTag=10174, callback="AnimTranslateLinearSingleSineWave",
    oam={affine=true,objMode="normal",bpp=4,width=32,height=32},
    anim={kind="dummy",frames={{tileOffset=0,duration=1}}},
  },
}

return M
