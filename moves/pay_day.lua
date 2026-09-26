local M = { id="PAY_DAY", name="Pay Day" }

-- Exact FireRed Move_PAY_DAY choreography. A spinning coin is launched from
-- the attacker toward the target at the native 0x480 (4.5 px/frame) speed.
-- After it arrives, the target is struck and shaken while a second coin falls
-- in two shrinking sine-bounce cycles.
M.soundIds = {153,167}

M.script = {
  { op="loadspritegfx", tag=10100 }, -- ANIM_TAG_COIN
  { op="loadspritegfx", tag=10135 }, -- ANIM_TAG_IMPACT
  { op="monbg", battler="target" },
  { op="splitbgprio", battler="target" },
  { op="setalpha", eva=12, evb=8 },
  { op="playsewithpan", sound=153, pan="attacker" }, -- SE_M_RAZOR_WIND2
  { op="createsprite", template="gCoinThrowSpriteTemplate", anchor="attacker", priority=2,
    args={20,0,0,0,1152} },
  { op="waitforvisualfinish" },
  { op="playsewithpan", sound=167, pan="target" }, -- SE_M_PAY_DAY
  { op="createsprite", template="gBasicHitSplatSpriteTemplate", anchor="attacker", priority=1,
    args={0,0,"target",2} },
  { op="createsprite", template="gFallingCoinSpriteTemplate", anchor="attacker", priority=2, args={} },
  { op="createvisualtask", task="AnimTask_ShakeMon2", priority=2, args={"target",1,0,6,1} },
  { op="waitforvisualfinish" },
  { op="clearmonbg", battler="target" },
  { op="blendoff" },
  { op="end" },
}

M.templates = {
  gCoinThrowSpriteTemplate = {
    tileTag=10100,paletteTag=10100,callback="AnimCoinThrow",
    oam={affine=true,objMode="normal",bpp=4,width=16,height=16},
    anim={kind="dummy",frames={{tileOffset=8,duration=1}}},
  },
  gFallingCoinSpriteTemplate = {
    tileTag=10100,paletteTag=10100,callback="AnimFallingCoin",
    oam={affine=true,objMode="normal",bpp=4,width=16,height=16},
    anim={kind="dummy",frames={{tileOffset=8,duration=1}}},
  },
  gBasicHitSplatSpriteTemplate = {
    tileTag=10135,paletteTag=10135,callback="AnimHitSplatBasic",
    oam={affine=true,objMode="blend",bpp=4,width=32,height=32},
    anim={kind="dummy",frames={{tileOffset=0,duration=1}}},
  },
}

return M
