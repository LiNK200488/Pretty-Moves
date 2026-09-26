local M = { id="CLAMP", name="Clamp" }

-- FireRed Move_CLAMP. Two 64x64 affine clamp jaws use the shared AnimBite
-- callback: they start 32 px to either side of the target, move inward for
-- ten frames with signed 8.8 step values, then reverse back outward. The
-- impact splat and target shake begin at the ten-frame meeting point.
M.script = {
  { op="loadspritegfx", tag=10145 }, -- ANIM_TAG_CLAMP
  { op="loadspritegfx", tag=10135 }, -- ANIM_TAG_IMPACT
  { op="monbg", battler="target" },
  { op="setalpha", eva=12, evb=8 },
  { op="playsewithpan", sound=149, pan="target" }, -- SE_M_VICEGRIP
  { op="createsprite", template="gClampJawSpriteTemplate", anchor="attacker", priority=2,
    args={-32,0,2,819,0,10} },
  { op="createsprite", template="gClampJawSpriteTemplate", anchor="attacker", priority=2,
    args={32,0,6,-819,0,10} },
  { op="delay", frames=10 },
  { op="createsprite", template="gBasicHitSplatSpriteTemplate", anchor="attacker", priority=2,
    args={0,0,"target",2} },
  { op="createvisualtask", task="AnimTask_ShakeMon", priority=5,
    args={"target",3,0,5,1} },
  { op="waitforvisualfinish" },
  { op="clearmonbg", battler="target" },
  { op="blendoff" },
  { op="waitforvisualfinish" },
  { op="end" },
}

M.templates = {
  gClampJawSpriteTemplate = {
    tileTag=10145,paletteTag=10145,callback="AnimBite",
    oam={affine=true,objMode="blend",bpp=4,width=64,height=64},
    anim={kind="dummy",frames={{tileOffset=0,duration=1}}},
  },
  gBasicHitSplatSpriteTemplate = {
    tileTag=10135,paletteTag=10135,callback="AnimHitSplatBasic",
    oam={affine=true,objMode="blend",bpp=4,width=32,height=32},
    anim={kind="dummy",frames={{tileOffset=0,duration=1}}},
  },
}

return M
