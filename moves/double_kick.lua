local M = { id="DOUBLE_KICK", name="Double Kick" }

-- FireRed Move_DOUBLE_KICK. Each landed row creates
-- gFistFootRandomPosSpriteTemplate on the target. AnimFistOrFootRandomPos
-- selects the wide-foot frame, chooses a fresh random point inside the target
-- sprite (with FireRed's -16 px player-side Y bias), creates a BasicHitSplat
-- at that exact point, holds both for 20 frames, then destroys both together.
M.script = {
  { op="loadspritegfx", tag=10143 }, -- ANIM_TAG_HANDS_AND_FEET
  { op="loadspritegfx", tag=10135 }, -- ANIM_TAG_IMPACT
  { op="monbg", battler="target" },
  { op="setalpha", eva=12, evb=8 },
  { op="createsprite", template="gFistFootRandomPosSpriteTemplate", anchor="target", priority=3,
    args={1,20,1} }, -- target, lifetime 20, wide-foot anim
  { op="createvisualtask", task="AnimTask_ShakeMon", priority=5,
    args={"target",4,0,6,1} },
  { op="playsewithpan", sound=207, pan="target" }, -- SE_M_VITAL_THROW2
  { op="waitforvisualfinish" },
  { op="clearmonbg", battler="target" },
  { op="blendoff" },
  { op="end" },
}

M.templates = {
  gFistFootRandomPosSpriteTemplate = {
    tileTag=10143,paletteTag=10143,callback="AnimFistOrFootRandomPos",
    oam={affine=false,objMode="normal",bpp=4,width=32,height=32},
    anim={kind="dummy",frames={{tileOffset=16,duration=1}}}, -- sAnims_HandsAndFeet[1]
  },
  -- Prepared because AnimFistOrFootRandomPos creates this child internally.
  gBasicHitSplatSpriteTemplate = {
    tileTag=10135,paletteTag=10135,callback="AnimHitSplatBasic",
    oam={affine=true,objMode="blend",bpp=4,width=32,height=32},
    anim={kind="dummy",frames={{tileOffset=0,duration=1}}},
  },
}

return M
