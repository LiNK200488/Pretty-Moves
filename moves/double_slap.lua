local M = { id="DOUBLESLAP", name="DoubleSlap", alternatingAnimTurn=true }

-- FireRed Move_DOUBLE_SLAP. Each landed multi-hit row selects one of two
-- choosetwoturnanim branches. FireRed itself draws only the impact splat
-- (no hand sprite), shifting it 8 px left/right on alternating hits, then
-- shakes the target and plays SE_M_DOUBLE_SLAP.
local turnX = { byAnimTurn={-8, 8} }

M.script = {
  { op="loadspritegfx", tag=10135 }, -- ANIM_TAG_IMPACT
  { op="monbg", battler="target" },
  { op="setalpha", eva=12, evb=8 },
  { op="createsprite", template="gBasicHitSplatSpriteTemplate", anchor="attacker", priority=2,
    args={turnX,0,"target",2} },
  { op="createvisualtask", task="AnimTask_ShakeMon", priority=2,
    args={"target",3,0,6,1} },
  { op="playsewithpan", sound=127, pan="target" }, -- SE_M_DOUBLE_SLAP
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
}

return M
