local M = { id="HORN_ATTACK", name="Horn Attack" }

-- FireRed Move_HORN_ATTACK. This shares Headbutt's three-stage BowMon
-- controller, but inserts the dedicated Horn Hit sprite during the attacker's
-- return phase. After the horn reaches the target, both battlers shake, the
-- attacker restores upright, and a flashing impact splat lands with
-- SE_M_HORN_ATTACK.
M.script = {
  { op="loadspritegfx", tag=10135 }, -- ANIM_TAG_IMPACT
  { op="loadspritegfx", tag=10020 }, -- ANIM_TAG_HORN_HIT
  { op="createsprite", template="gBowMonSpriteTemplate", anchor="attacker", priority=2, args={0} },
  { op="playsewithpan", sound=155, pan="attacker" }, -- SE_M_HEADBUTT
  { op="waitforvisualfinish" },
  { op="delay", frames=2 },
  { op="createsprite", template="gBowMonSpriteTemplate", anchor="attacker", priority=2, args={1} },
  { op="createsprite", template="gHornHitSpriteTemplate", anchor="target", priority=4, args={0,0,10} },
  { op="waitforvisualfinish" },
  { op="createvisualtask", task="AnimTask_ShakeMonInPlace", priority=2,
    args={"attacker",2,0,4,1} },
  { op="createvisualtask", task="AnimTask_ShakeMon", priority=2,
    args={"target",5,0,6,1} },
  { op="createsprite", template="gBowMonSpriteTemplate", anchor="attacker", priority=2, args={2} },
  { op="createsprite", template="gFlashingHitSplatSpriteTemplate", anchor="target", priority=3,
    args={0,0,"target",1} },
  { op="playsewithpan", sound=159, pan="target" }, -- SE_M_HORN_ATTACK
  { op="waitforvisualfinish" },
  { op="end" },
}

M.templates = {
  gHornHitSpriteTemplate = {
    tileTag=10020,paletteTag=10020,callback="AnimHornHit",
    oam={affine=false,objMode="normal",bpp=4,width=32,height=32},
    anim={kind="once",frames={{tileOffset=0,duration=1}}},
  },
  gFlashingHitSplatSpriteTemplate = {
    tileTag=10135,paletteTag=10135,callback="AnimFlashingHitSplat",
    oam={affine=true,objMode="normal",bpp=4,width=32,height=32},
    anim={kind="dummy",frames={{tileOffset=0,duration=1}}},
  },
}

return M
