local M = { id="SOFTBOILED", name="Soft-Boiled" }

-- Source-faithful FireRed Move_SOFT_BOILED.
-- Two BREAKING_EGG sprites arc/bounce at the user, split into the yolk/shell
-- phases driven by AnimSoftBoiledEgg, then the user receives two expanding
-- THIN_RING sprites, the native pale blue-white palette flash, and HealingEffect2.
M.soundIds = {160,159,172}

M.script = {
  { op="loadspritegfx", tag=10202 }, -- ANIM_TAG_BREAKING_EGG
  { op="loadspritegfx", tag=10203 }, -- ANIM_TAG_THIN_RING
  { op="loadspritegfx", tag=10031 }, -- ANIM_TAG_BLUE_STAR
  { op="monbg", battler="atk_partner" },
  { op="playsewithpan", sound=160, pan="attacker" }, -- SE_M_TAIL_WHIP
  { op="createvisualtask", task="AnimTask_ShakeMon", priority=2, args={"attacker",0,2,6,1} },
  { op="createsprite", template="gSoftBoiledEggSpriteTemplate", anchor="attacker", priority=4, args={0,16,0} },
  { op="createsprite", template="gSoftBoiledEggSpriteTemplate", anchor="attacker", priority=4, args={0,16,1} },
  { op="delay", frames=120 },
  { op="delay", frames=7 },
  { op="playsewithpan", sound=159, pan="attacker" }, -- SE_M_HORN_ATTACK
  { op="createsprite", template="gSimplePaletteBlendSpriteTemplate", anchor="attacker", priority=2,
    args={"all_and_bg",3,10,0,{12,24,30}} },
  { op="createsprite", template="gThinRingExpandingSpriteTemplate", anchor="attacker", priority=3,
    args={31,16,0,1} },
  { op="delay", frames=8 },
  { op="createsprite", template="gThinRingExpandingSpriteTemplate", anchor="attacker", priority=3,
    args={31,16,0,1} },
  { op="delay", frames=60 },
  { op="setarg", index=7, value=0xFFFF },
  { op="waitforvisualfinish" },
  { op="clearmonbg", battler="atk_partner" },
  { op="call", label="HealingEffect2" },
  { op="end" },
}

M.labels = {
  HealingEffect2 = {
    { op="playsewithpan", sound=172, pan="attacker" }, -- SE_M_ABSORB_2; Soft-Boiled self-target
    { op="createsprite", template="gHealingBlueStarSpriteTemplate", anchor="attacker", priority=2, args={0,-5,0,0} },
    { op="delay", frames=7 },
    { op="createsprite", template="gHealingBlueStarSpriteTemplate", anchor="attacker", priority=2, args={-15,10,0,0} },
    { op="delay", frames=7 },
    { op="createsprite", template="gHealingBlueStarSpriteTemplate", anchor="attacker", priority=2, args={-15,-15,0,0} },
    { op="delay", frames=7 },
    { op="createsprite", template="gHealingBlueStarSpriteTemplate", anchor="attacker", priority=2, args={10,-5,0,0} },
    { op="delay", frames=7 },
    { op="return" },
  },
}

M.templates = {
  gSoftBoiledEggSpriteTemplate = {
    tileTag=10202,paletteTag=10202,callback="AnimSoftBoiledEgg",
    oam={affine=true,doubleSize=true,objMode="blend",bpp=4,width=32,height=32},
    anim={kind="dummy",frames={{tileOffset=0,duration=1}}},
    -- AnimSoftBoiledEgg changes oam.tileNum by +16 / +32 at the crack.
    -- These frames are not referenced by the dummy anim table, so explicitly
    -- precache them or the egg disappears instead of splitting.
    extraTileOffsets={16,32},
  },
  gThinRingExpandingSpriteTemplate = {
    tileTag=10203,paletteTag=10203,callback="AnimSpriteOnMonPos",
    oam={affine=true,doubleSize=true,objMode="normal",bpp=4,width=64,height=64},
    anim={kind="dummy",frames={{tileOffset=0,duration=31}}},
    affineAnim={kind="linear_scale",start=16,delta=16,frames=30},
  },
  gHealingBlueStarSpriteTemplate = {
    tileTag=10031,paletteTag=10031,callback="AnimSpriteOnMonPos",
    oam={affine=false,objMode="normal",bpp=4,width=32,height=32},
    anim={kind="once",frames={
      {tileOffset=0,duration=2},{tileOffset=16,duration=2},
      {tileOffset=32,duration=2},{tileOffset=48,duration=3},
    }},
  },
  gSimplePaletteBlendSpriteTemplate = {controller=true,callback="AnimSimplePaletteBlend"},
}

return M
