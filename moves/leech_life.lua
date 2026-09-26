local M = { id="LEECH_LIFE", name="Leech Life" }

-- Exact FireRed Move_LEECH_LIFE choreography.
-- The initial 16x16 needle is placed relative to the target, then translated
-- into the target over 12 frames. The target is hit/shaken, the battlefield
-- fades to black, fourteen power-absorption orbs converge on the attacker,
-- and the normal four-star healing sequence closes the move.
M.soundIds = {173,172}

M.script = {
  { op="loadspritegfx", tag=10161 }, -- ANIM_TAG_NEEDLE
  { op="loadspritegfx", tag=10147 }, -- ANIM_TAG_ORBS
  { op="delay", frames=1 },
  { op="loadspritegfx", tag=10031 }, -- ANIM_TAG_BLUE_STAR
  { op="loadspritegfx", tag=10135 }, -- ANIM_TAG_IMPACT
  { op="monbg", battler="def_partner" },
  { op="splitbgprio_foes", battler="target" },
  { op="setalpha", eva=12, evb=8 },
  { op="delay", frames=1 },

  { op="createsprite", template="gLeechLifeNeedleSpriteTemplate", anchor="attacker", priority=2,
    args={-20,15,12} },
  { op="waitforvisualfinish" },

  { op="createsprite", template="gBasicHitSplatSpriteTemplate", anchor="attacker", priority=2,
    args={0,0,"target",2} },
  { op="playsewithpan", sound=173, pan="target" }, -- SE_M_ABSORB
  { op="delay", frames=2 },
  { op="createvisualtask", task="AnimTask_ShakeMon", priority=5,
    args={"target",0,5,5,1} },
  { op="waitforvisualfinish" },

  { op="createsprite", template="gSimplePaletteBlendSpriteTemplate", anchor="attacker", priority=2,
    args={"bg",1,0,7,{0,0,0}} },
  { op="waitforvisualfinish" },
  { op="call", label="AbsorbEffect" },
  { op="waitforvisualfinish" },
  { op="delay", frames=15 },
  { op="call", label="HealingEffect" },
  { op="waitforvisualfinish" },
  { op="createsprite", template="gSimplePaletteBlendSpriteTemplate", anchor="attacker", priority=2,
    args={"bg",1,7,0,{0,0,0}} },
  { op="waitforvisualfinish" },
  { op="clearmonbg", battler="def_partner" },
  { op="blendoff" },
  { op="end" },
}

M.labels = {
  AbsorbEffect = {
    { op="createsprite", template="gPowerAbsorptionOrbSpriteTemplate", anchor="attacker", priority=2, args={40,40,16} },
    { op="delay", frames=2 },
    { op="createsprite", template="gPowerAbsorptionOrbSpriteTemplate", anchor="attacker", priority=2, args={-40,-40,16} },
    { op="delay", frames=2 },
    { op="createsprite", template="gPowerAbsorptionOrbSpriteTemplate", anchor="attacker", priority=2, args={0,40,16} },
    { op="delay", frames=2 },
    { op="createsprite", template="gPowerAbsorptionOrbSpriteTemplate", anchor="attacker", priority=2, args={0,-40,16} },
    { op="delay", frames=2 },
    { op="createsprite", template="gPowerAbsorptionOrbSpriteTemplate", anchor="attacker", priority=2, args={40,-20,16} },
    { op="delay", frames=2 },
    { op="createsprite", template="gPowerAbsorptionOrbSpriteTemplate", anchor="attacker", priority=2, args={40,20,16} },
    { op="delay", frames=2 },
    { op="createsprite", template="gPowerAbsorptionOrbSpriteTemplate", anchor="attacker", priority=2, args={-40,-20,16} },
    { op="delay", frames=2 },
    { op="createsprite", template="gPowerAbsorptionOrbSpriteTemplate", anchor="attacker", priority=2, args={-40,20,16} },
    { op="delay", frames=2 },
    { op="createsprite", template="gPowerAbsorptionOrbSpriteTemplate", anchor="attacker", priority=2, args={-20,30,16} },
    { op="delay", frames=2 },
    { op="createsprite", template="gPowerAbsorptionOrbSpriteTemplate", anchor="attacker", priority=2, args={20,-30,16} },
    { op="delay", frames=2 },
    { op="createsprite", template="gPowerAbsorptionOrbSpriteTemplate", anchor="attacker", priority=2, args={-20,-30,16} },
    { op="delay", frames=2 },
    { op="createsprite", template="gPowerAbsorptionOrbSpriteTemplate", anchor="attacker", priority=2, args={20,30,16} },
    { op="delay", frames=2 },
    { op="createsprite", template="gPowerAbsorptionOrbSpriteTemplate", anchor="attacker", priority=2, args={-40,0,16} },
    { op="delay", frames=2 },
    { op="createsprite", template="gPowerAbsorptionOrbSpriteTemplate", anchor="attacker", priority=2, args={40,0,16} },
    { op="delay", frames=2 },
    { op="return" },
  },
  HealingEffect = {
    { op="playsewithpan", sound=172, pan="attacker" }, -- SE_M_ABSORB_2
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
  gLeechLifeNeedleSpriteTemplate = {
    tileTag=10161, paletteTag=10161, callback="AnimLeechLifeNeedle",
    oam={affine=true,objMode="normal",bpp=4,width=16,height=16},
    anim={kind="dummy",frames={{tileOffset=0,duration=1}}},
  },
  gBasicHitSplatSpriteTemplate = {
    tileTag=10135, paletteTag=10135, callback="AnimHitSplatBasic",
    oam={affine=true,objMode="blend",bpp=4,width=32,height=32},
    anim={kind="dummy",frames={{tileOffset=0,duration=1}}},
  },
  gSimplePaletteBlendSpriteTemplate = {
    controller=true, callback="AnimSimplePaletteBlend",
  },
  gPowerAbsorptionOrbSpriteTemplate = {
    tileTag=10147, paletteTag=10147, callback="AnimPowerAbsorptionOrb",
    oam={affine=true,objMode="blend",bpp=4,width=16,height=16},
    anim={kind="dummy",frames={{tileOffset=8,duration=1}}},
  },
  gHealingBlueStarSpriteTemplate = {
    tileTag=10031, paletteTag=10031, callback="AnimSpriteOnMonPos",
    oam={affine=false,objMode="normal",bpp=4,width=32,height=32},
    anim={kind="once",frames={
      {tileOffset=0,duration=2},{tileOffset=16,duration=2},
      {tileOffset=32,duration=2},{tileOffset=48,duration=3},
    }},
  },
}

return M
