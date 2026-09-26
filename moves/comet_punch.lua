local M = { id="COMET_PUNCH", name="Comet Punch", alternatingAnimTurn=true }

-- FireRed Move_COMET_PUNCH. Each landed hit gets its own animation row.
-- choosetwoturnanim alternates the target-relative X offset: left, right, left...
local turnX = { byAnimTurn={-8, 8} }

M.script = {
  { op="loadspritegfx", tag=10135 }, -- ANIM_TAG_IMPACT
  { op="loadspritegfx", tag=10143 }, -- ANIM_TAG_HANDS_AND_FEET
  { op="monbg", battler="target" },
  { op="setalpha", eva=12, evb=8 },
  { op="createsprite", template="gBasicHitSplatSpriteTemplate", anchor="attacker", priority=2,
    args={turnX,-8,"target",2} },
  { op="createsprite", template="gFistFootSpriteTemplate", anchor="attacker", priority=3,
    args={turnX,0,8,1,0} },
  { op="createvisualtask", task="AnimTask_ShakeMon", priority=2,
    args={"target",3,0,6,1} },
  { op="playsewithpan", sound=132, pan="target" }, -- SE_M_COMET_PUNCH
  { op="waitforvisualfinish" },
  { op="clearmonbg", battler="target" },
  { op="blendoff" },
  { op="end" },
}

M.templates = {
  gBasicHitSplatSpriteTemplate = {
    tileTag=10135,paletteTag=10135,callback="AnimHitSplatBasic",
    oam={affine=true,objMode="blend",bpp=4,width=32,height=32},
    anim={kind="dummy",frames={{tileOffset=0,duration=1}}},
  },
  gFistFootSpriteTemplate = {
    tileTag=10143,paletteTag=10143,callback="AnimBasicFistOrFoot",
    oam={affine=false,objMode="normal",bpp=4,width=32,height=32},
    anim={kind="once",frames={{tileOffset=0,duration=1}}}, -- fist frame
  },
}

return M
