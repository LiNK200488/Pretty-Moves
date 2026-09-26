local M = { id="VICEGRIP", name="Vice Grip" }

-- FireRed Move_VICE_GRIP. Two 32x32 CUT pincers use AnimViceGripPincer:
-- each starts diagonally 32 px from the target, translates to a 16 px inner
-- offset over six native 8.8 fixed-point ticks, then remains there until the
-- 3/3/20-frame sprite animation ends. The inverted pincer uses H+V flip.
M.script = {
  { op="loadspritegfx", tag=10138 }, -- ANIM_TAG_CUT
  { op="loadspritegfx", tag=10135 }, -- ANIM_TAG_IMPACT
  { op="monbg", battler="def_partner" },
  { op="setalpha", eva=12, evb=8 },
  { op="playsewithpan", sound=149, pan="target" }, -- SE_M_VICEGRIP
  { op="createsprite", template="gViceGripSpriteTemplate", anchor="attacker", priority=2, args={0} },
  { op="createsprite", template="gViceGripSpriteTemplate", anchor="attacker", priority=2, args={1} },
  { op="delay", frames=9 },
  { op="createsprite", template="gBasicHitSplatSpriteTemplate", anchor="attacker", priority=1,
    args={0,0,"target",2} },
  { op="createvisualtask", task="AnimTask_ShakeMon2", priority=5,
    args={"target",2,0,5,1} },
  { op="waitforvisualfinish" },
  { op="clearmonbg", battler="def_partner" },
  { op="blendoff" },
  { op="end" },
}

M.templates = {
  gViceGripSpriteTemplate = {
    tileTag=10138,paletteTag=10138,callback="AnimViceGripPincer",
    oam={affine=false,objMode="blend",bpp=4,width=32,height=32},
    -- sViceGripAnimCmds1. Variant 1 uses the same tile sequence with H+V flip.
    anim={kind="once",frames={
      {tileOffset=0,duration=3},
      {tileOffset=16,duration=3},
      {tileOffset=32,duration=20},
    }},
  },
  gBasicHitSplatSpriteTemplate = {
    tileTag=10135,paletteTag=10135,callback="AnimHitSplatBasic",
    oam={affine=true,objMode="blend",bpp=4,width=32,height=32},
    anim={kind="dummy",frames={{tileOffset=0,duration=1}}},
  },
}

return M
