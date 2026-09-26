local M = { id="BITE", name="Bite" }

-- FireRed Move_BITE. The two 64x64 Sharp Teeth sprites close vertically on
-- the target for ten frames, reverse for ten frames, and overlap the impact.
M.script = {
  { op="loadspritegfx", tag=10139 }, -- ANIM_TAG_SHARP_TEETH
  { op="loadspritegfx", tag=10135 }, -- ANIM_TAG_IMPACT
  { op="monbg", battler="target" },
  { op="setalpha", eva=12, evb=8 },
  { op="playsewithpan", sound=154, pan="target" }, -- SE_M_BITE
  { op="createsprite", template="gSharpTeethSpriteTemplate", anchor="attacker", priority=2,
    args={0,-32,0,0,819,10} },
  { op="createsprite", template="gSharpTeethSpriteTemplate", anchor="attacker", priority=2,
    args={0,32,4,0,-819,10} },
  { op="delay", frames=10 },
  { op="createsprite", template="gBasicHitSplatSpriteTemplate", anchor="attacker", priority=2,
    args={0,0,"target",2} },
  { op="createvisualtask", task="AnimTask_ShakeMon", priority=5,
    args={"target",0,4,7,1} },
  { op="waitforvisualfinish" },
  { op="clearmonbg", battler="target" },
  { op="blendoff" },
  { op="end" },
}

M.templates = {
  gSharpTeethSpriteTemplate = {
    tileTag=10139,paletteTag=10139,callback="AnimBite",
    oam={affine=true,objMode="blend",bpp=4,width=64,height=64},
    anim={kind="once",frames={{tileOffset=0,duration=1}}},
  },
  gBasicHitSplatSpriteTemplate = {
    tileTag=10135,paletteTag=10135,callback="AnimHitSplatBasic",
    oam={affine=true,objMode="blend",bpp=4,width=32,height=32},
    anim={kind="dummy",frames={{tileOffset=0,duration=1}}},
  },
}

return M
