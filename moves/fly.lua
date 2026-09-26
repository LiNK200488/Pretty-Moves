local M = { id="FLY", name="Fly" }

-- Gen1Recomp queues TELEPORT as the first-turn FLY_EFFECT charge animation.
-- The bridge replaces that row with FireRed FlySetUp while leaving the host's
-- two-turn/invulnerability mechanics authoritative.
M.chargeRowAnims = { player="TELEPORT", opponent="TELEPORT" }
M.chargeScript = {
  { op="loadspritegfx", tag=10156 }, -- ANIM_TAG_ROUND_SHADOW
  { op="playsewithpan", sound=151, pan="attacker" }, -- SE_M_FLY
  { op="battlervisibility", battler="attacker", visible=false },
  { op="createsprite", template="gFlyBallUpSpriteTemplate", anchor="attacker", priority=2,
    args={0,0,13,336} },
  { op="waitforvisualfinish" },
  { op="end" },
}

M.script = {
  { op="loadspritegfx", tag=10156 }, -- ANIM_TAG_ROUND_SHADOW
  { op="loadspritegfx", tag=10135 }, -- ANIM_TAG_IMPACT
  { op="monbg", battler="def_partner" },
  { op="setalpha", eva=12, evb=8 },
  { op="playsewithpan", sound=128, pan="attacker" }, -- SE_M_DOUBLE_TEAM
  { op="createsprite", template="gFlyBallAttackSpriteTemplate", anchor="attacker", priority=2, args={20} },
  { op="delay", frames=20 },
  { op="createsprite", template="gBasicHitSplatSpriteTemplate", anchor="attacker", priority=2,
    args={0,0,"target",0} },
  { op="createvisualtask", task="AnimTask_ShakeMon", priority=5, args={"target",6,0,8,1} },
  { op="playsewithpan", sound=129, pan="target" }, -- SE_M_RAZOR_WIND
  { op="waitforvisualfinish" },
  { op="battlervisibility", battler="attacker", visible=true },
  { op="clearmonbg", battler="def_partner" },
  { op="blendoff" },
  { op="end" },
}

M.templates = {
  gFlyBallUpSpriteTemplate = {
    tileTag=10156,paletteTag=10156,callback="AnimFlyBallUp",
    oam={affine=true,objMode="normal",bpp=4,width=64,height=64,doubleSize=true},
    anim={kind="dummy",frames={{tileOffset=0,duration=1}}},
  },
  gFlyBallAttackSpriteTemplate = {
    tileTag=10156,paletteTag=10156,callback="AnimFlyBallAttack",
    oam={affine=true,objMode="normal",bpp=4,width=64,height=64},
    anim={kind="dummy",frames={{tileOffset=0,duration=1}}},
  },
  gBasicHitSplatSpriteTemplate = {
    tileTag=10135,paletteTag=10135,callback="AnimHitSplatBasic",
    oam={affine=true,objMode="blend",bpp=4,width=32,height=32},
    anim={kind="dummy",frames={{tileOffset=0,duration=1}}},
  },
}
return M
