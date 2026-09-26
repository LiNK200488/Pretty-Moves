local M = { id="RECOVER", name="Recover" }

-- Exact FireRed Move_RECOVER choreography. Three passes of seven power-
-- absorption orbs collapse into the attacker while its palette cycles toward
-- pale yellow, followed by the shared four-star healing finish.
M.soundIds = {133,172}

M.script = {
  { op="loadspritegfx", tag=10147 }, -- ANIM_TAG_ORBS
  { op="loadspritegfx", tag=10031 }, -- ANIM_TAG_BLUE_STAR
  { op="monbg", battler="atk_partner" },
  { op="setalpha", eva=12, evb=8 },
  { op="loopsewithpan", sound=133, pan="attacker", interval=13, count=3 }, -- SE_M_MEGA_KICK
  { op="createvisualtask", task="AnimTask_BlendColorCycle", priority=2,
    args={"attacker",0,6,0,11,{31,31,11}} },
  { op="call", label="RecoverAbsorbEffect" },
  { op="call", label="RecoverAbsorbEffect" },
  { op="call", label="RecoverAbsorbEffect" },
  { op="waitforvisualfinish" },
  { op="clearmonbg", battler="atk_partner" },
  { op="blendoff" },
  { op="delay", frames=1 },
  { op="call", label="HealingEffect" },
  { op="waitforvisualfinish" },
  { op="end" },
}

M.labels = {
  RecoverAbsorbEffect = {
    { op="createsprite", template="gPowerAbsorptionOrbSpriteTemplate", anchor="attacker", priority=2, args={40,-10,13} },
    { op="delay", frames=3 },
    { op="createsprite", template="gPowerAbsorptionOrbSpriteTemplate", anchor="attacker", priority=2, args={-35,-10,13} },
    { op="delay", frames=3 },
    { op="createsprite", template="gPowerAbsorptionOrbSpriteTemplate", anchor="attacker", priority=2, args={15,-40,13} },
    { op="delay", frames=3 },
    { op="createsprite", template="gPowerAbsorptionOrbSpriteTemplate", anchor="attacker", priority=2, args={-10,-32,13} },
    { op="delay", frames=3 },
    { op="createsprite", template="gPowerAbsorptionOrbSpriteTemplate", anchor="attacker", priority=2, args={25,-20,13} },
    { op="delay", frames=3 },
    { op="createsprite", template="gPowerAbsorptionOrbSpriteTemplate", anchor="attacker", priority=2, args={-40,-20,13} },
    { op="delay", frames=3 },
    { op="createsprite", template="gPowerAbsorptionOrbSpriteTemplate", anchor="attacker", priority=2, args={5,-40,13} },
    { op="delay", frames=3 },
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
  gPowerAbsorptionOrbSpriteTemplate = {
    tileTag=10147,paletteTag=10147,callback="AnimPowerAbsorptionOrb",
    oam={affine=true,objMode="blend",bpp=4,width=16,height=16},
    anim={kind="dummy",frames={{tileOffset=8,duration=1}}},
  },
  gHealingBlueStarSpriteTemplate = {
    tileTag=10031,paletteTag=10031,callback="AnimSpriteOnMonPos",
    oam={affine=false,objMode="normal",bpp=4,width=32,height=32},
    anim={kind="once",frames={
      {tileOffset=0,duration=2},{tileOffset=16,duration=2},
      {tileOffset=32,duration=2},{tileOffset=48,duration=3},
    }},
  },
}

return M
