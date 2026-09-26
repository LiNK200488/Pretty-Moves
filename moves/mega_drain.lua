local M = { id="MEGA_DRAIN", name="Mega Drain" }

-- Exact FireRed Move_MEGA_DRAIN choreography.
-- Compared with Absorb, FireRed deepens the green background blend to 8,
-- uses impact variant 1, emits two absorption orbs per 4-frame beat, and
-- uses SE_M_BUBBLE3 for the drain stream.
M.soundIds = {173,119,172}

M.script = {
  { op="loadspritegfx", tag=10147 }, -- ANIM_TAG_ORBS
  { op="loadspritegfx", tag=10031 }, -- ANIM_TAG_BLUE_STAR
  { op="loadspritegfx", tag=10135 }, -- ANIM_TAG_IMPACT
  { op="monbg", battler="def_partner" },
  { op="splitbgprio_foes", battler="target" },
  { op="setalpha", eva=12, evb=8 },
  { op="createsprite", template="gSimplePaletteBlendSpriteTemplate", anchor="attacker", priority=2,
    args={"bg",1,0,8,{13,31,12}} },
  { op="waitforvisualfinish" },
  { op="playsewithpan", sound=173, pan="target" }, -- SE_M_ABSORB
  { op="createsprite", template="gBasicHitSplatSpriteTemplate", anchor="attacker", priority=2,
    args={0,0,"target",1} },
  { op="delay", frames=2 },
  { op="createvisualtask", task="AnimTask_ShakeMon", priority=5,
    args={"target",0,5,5,1} },
  { op="waitforvisualfinish" },
  { op="delay", frames=3 },
  { op="call", label="MegaDrainAbsorbEffect" },
  { op="waitforvisualfinish" },
  { op="delay", frames=15 },
  { op="call", label="HealingEffect" },
  { op="waitforvisualfinish" },
  { op="createsprite", template="gSimplePaletteBlendSpriteTemplate", anchor="attacker", priority=2,
    args={"bg",1,8,0,{13,31,12}} },
  { op="waitforvisualfinish" },
  { op="clearmonbg", battler="def_partner" },
  { op="blendoff" },
  { op="end" },
}

M.labels = {
  MegaDrainAbsorbEffect = {
    { op="playsewithpan", sound=119, pan="target" }, -- SE_M_BUBBLE3
    { op="createsprite", template="gAbsorptionOrbSpriteTemplate", anchor="attacker", priority=3, args={0,5,8,26} },
    { op="createsprite", template="gAbsorptionOrbSpriteTemplate", anchor="attacker", priority=3, args={5,-18,-20,35} },
    { op="delay", frames=4 },
    { op="playsewithpan", sound=119, pan="target" },
    { op="createsprite", template="gAbsorptionOrbSpriteTemplate", anchor="attacker", priority=3, args={10,-5,-8,26} },
    { op="createsprite", template="gAbsorptionOrbSpriteTemplate", anchor="attacker", priority=3, args={-10,20,20,39} },
    { op="delay", frames=4 },
    { op="playsewithpan", sound=119, pan="target" },
    { op="createsprite", template="gAbsorptionOrbSpriteTemplate", anchor="attacker", priority=3, args={-5,15,16,33} },
    { op="createsprite", template="gAbsorptionOrbSpriteTemplate", anchor="attacker", priority=3, args={10,-5,-8,26} },
    { op="delay", frames=4 },
    { op="playsewithpan", sound=119, pan="target" },
    { op="createsprite", template="gAbsorptionOrbSpriteTemplate", anchor="attacker", priority=3, args={0,-15,-16,36} },
    { op="createsprite", template="gAbsorptionOrbSpriteTemplate", anchor="attacker", priority=3, args={0,5,8,26} },
    { op="delay", frames=4 },
    { op="playsewithpan", sound=119, pan="target" },
    { op="createsprite", template="gAbsorptionOrbSpriteTemplate", anchor="attacker", priority=3, args={0,5,8,26} },
    { op="createsprite", template="gAbsorptionOrbSpriteTemplate", anchor="attacker", priority=3, args={0,-15,-16,36} },
    { op="delay", frames=4 },
    { op="playsewithpan", sound=119, pan="target" },
    { op="createsprite", template="gAbsorptionOrbSpriteTemplate", anchor="attacker", priority=3, args={10,-5,-8,26} },
    { op="createsprite", template="gAbsorptionOrbSpriteTemplate", anchor="attacker", priority=3, args={-5,15,16,33} },
    { op="delay", frames=4 },
    { op="playsewithpan", sound=119, pan="target" },
    { op="createsprite", template="gAbsorptionOrbSpriteTemplate", anchor="attacker", priority=3, args={-10,20,20,39} },
    { op="createsprite", template="gAbsorptionOrbSpriteTemplate", anchor="attacker", priority=3, args={10,-5,-8,26} },
    { op="delay", frames=4 },
    { op="playsewithpan", sound=119, pan="target" },
    { op="createsprite", template="gAbsorptionOrbSpriteTemplate", anchor="attacker", priority=3, args={0,5,8,26} },
    { op="createsprite", template="gAbsorptionOrbSpriteTemplate", anchor="attacker", priority=3, args={5,-18,-20,35} },
    { op="delay", frames=4 },
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
  gSimplePaletteBlendSpriteTemplate = {
    controller=true, callback="AnimSimplePaletteBlend",
  },
  gBasicHitSplatSpriteTemplate = {
    tileTag=10135, paletteTag=10135, callback="AnimHitSplatBasic",
    oam={affine=true,objMode="blend",bpp=4,width=32,height=32},
    anim={kind="dummy",frames={{tileOffset=0,duration=1}}},
  },
  gAbsorptionOrbSpriteTemplate = {
    tileTag=10147, paletteTag=10147, callback="AnimAbsorptionOrb",
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
