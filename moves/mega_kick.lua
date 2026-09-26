local M = { id="MEGA_KICK", name="Mega Kick" }

-- Source-traced FireRed Move_MEGA_KICK. It shares Mega Punch's spinning/
-- shrinking impact choreography, but uses the wide foot animation variant and
-- adds SE_M_MEGA_KICK2 immediately before the impact background/hit.
M.script = {
  { op="loadspritegfx", tag=10135 }, -- ANIM_TAG_IMPACT
  { op="loadspritegfx", tag=10143 }, -- ANIM_TAG_HANDS_AND_FEET
  { op="monbg", battler="target" },
  { op="delay", frames=2 },
  { op="createsprite", template="gSimplePaletteBlendSpriteTemplate", anchor="attacker", priority=2,
    args={"bg",0,0,16,"black"} },
  { op="setalpha", eva=12, evb=8 },
  { op="playsewithpan", sound=133, pan="target" }, -- SE_M_MEGA_KICK
  { op="createsprite", template="gMegaPunchKickSpriteTemplate", anchor="target", priority=3,
    args={0,0,1,50} }, -- anim 1 = wide foot
  { op="createvisualtask", task="AnimTask_BlendBattleAnimPal", priority=10,
    args={"target",2,0,7,"white"} },
  { op="delay", frames=50 },
  { op="playsewithpan", sound=134, pan="target" }, -- SE_M_MEGA_KICK2
  { op="changebg", bg={byAttackerSide={player="impact_opponent",opponent="impact_player"}} },
  { op="delay", frames=2 },
  { op="createsprite", template="gBasicHitSplatSpriteTemplate", anchor="attacker", priority=2,
    args={0,0,"target",0} },
  { op="createvisualtask", task="AnimTask_ShakeMon2", priority=2,
    args={"target",4,0,22,1} },
  { op="createvisualtask", task="AnimTask_BlendBattleAnimPal", priority=10,
    args={"target",2,0,0,"white"} },
  { op="createsprite", template="gComplexPaletteBlendSpriteTemplate", anchor="attacker", priority=2,
    args={"all_and_bg",3,1,"black",8,"black",0} },
  { op="waitforvisualfinish" },
  { op="clearmonbg", battler="target" },
  { op="blendoff" },
  { op="delay", frames=2 },
  { op="restorebg" },
  { op="waitbgfadein" },
  { op="end" },
}

M.templates = {
  gSimplePaletteBlendSpriteTemplate = {
    controller=true,callback="AnimSimplePaletteBlend",
    oam={affine=false,objMode="normal",bpp=4,width=8,height=8},
    anim={kind="dummy",frames={{tileOffset=0,duration=1}}},
  },
  gMegaPunchKickSpriteTemplate = {
    tileTag=10143,paletteTag=10143,callback="AnimSpinningKickOrPunch",
    oam={affine=true,objMode="normal",bpp=4,width=32,height=32},
    anim={kind="once",frames={{tileOffset=0,duration=1}}},
  },
  gBasicHitSplatSpriteTemplate = {
    tileTag=10135,paletteTag=10135,callback="AnimHitSplatBasic",
    oam={affine=true,objMode="blend",bpp=4,width=32,height=32},
    anim={kind="dummy",frames={{tileOffset=0,duration=1}}},
  },
  gComplexPaletteBlendSpriteTemplate = {
    controller=true,callback="AnimComplexPaletteBlend",
    oam={affine=false,objMode="normal",bpp=4,width=8,height=8},
    anim={kind="dummy",frames={{tileOffset=0,duration=1}}},
  },
}

return M
