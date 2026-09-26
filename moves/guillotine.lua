local M = { id="GUILLOTINE", name="Guillotine" }

-- FireRed Move_GUILLOTINE. Unlike Vice Grip, AnimGuillotinePincer closes each
-- 32x32 CUT jaw in six fixed-point ticks, pauses it at the inner point, then
-- reverses the translation and restarts the opposite flip-state on release.
-- FireRed also fades to its dedicated Guillotine battle background and layers
-- target/all-palette black blends around the two impact/shake phases.
M.script = {
  { op="loadspritegfx", tag=10138 }, -- ANIM_TAG_CUT
  { op="loadspritegfx", tag=10135 }, -- ANIM_TAG_IMPACT
  { op="monbg", battler="def_partner" },
  { op="setalpha", eva=12, evb=8 },
  { op="fadetobg", bg={byAttackerSide={player="guillotine_opponent",opponent="guillotine_player"}} },
  { op="waitbgfadein" },
  { op="playsewithpan", sound=149, pan="target" }, -- SE_M_VICEGRIP
  { op="createsprite", template="gGuillotineSpriteTemplate", anchor="attacker", priority=2, args={0} },
  { op="createsprite", template="gGuillotineSpriteTemplate", anchor="attacker", priority=2, args={1} },
  { op="createvisualtask", task="AnimTask_BlendBattleAnimPal", priority=10,
    args={"target",2,0,16,"black"} },
  { op="delay", frames=9 },
  { op="createvisualtask", task="AnimTask_ShakeMon2", priority=5,
    args={"target",2,0,23,1} },
  { op="delay", frames=46 },
  { op="createvisualtask", task="AnimTask_ShakeMon2", priority=5,
    args={"target",4,0,8,1} },
  { op="createsprite", template="gBasicHitSplatSpriteTemplate", anchor="attacker", priority=3,
    args={0,0,"target",0} },
  { op="createsprite", template="gComplexPaletteBlendSpriteTemplate", anchor="attacker", priority=2,
    args={"all_and_bg",3,1,"black",8,"black",0} },
  { op="playsewithpan", sound=129, pan="target" }, -- SE_M_RAZOR_WIND
  { op="waitforvisualfinish" },
  { op="clearmonbg", battler="def_partner" },
  { op="blendoff" },
  { op="restorebg" },
  { op="waitbgfadein" },
  { op="end" },
}

M.templates = {
  gGuillotineSpriteTemplate = {
    tileTag=10138,paletteTag=10138,callback="AnimGuillotinePincer",
    oam={affine=false,objMode="blend",bpp=4,width=32,height=32},
    anim={kind="once",frames={{tileOffset=0,duration=2},{tileOffset=16,duration=2},{tileOffset=32,duration=1}}},
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
