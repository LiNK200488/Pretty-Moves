local M = { id="SOLARBEAM", name="Solar Beam" }

-- FireRed Move_SOLAR_BEAM uses choosetwoturnanim. Gen1Recomp's CHARGE_EFFECT
-- presents XSTATITEM_ANIM (duplicate row for the enemy) on the real first turn,
-- so replace that host presentation while leaving mechanics/PP/damage native.
M.chargeRowAnims = { player="XSTATITEM_ANIM", opponent="XSTATITEM_DUPLICATE_ANIM" }
M.soundIds = {134,194}

M.chargeScript = {
  { op="loadspritegfx", tag=10147 }, -- ANIM_TAG_ORBS
  { op="monbg", battler="atk_partner" },
  { op="setalpha", eva=12, evb=8 },
  { op="createvisualtask", task="AnimTask_BlendColorCycle", priority=2,
    args={"attacker",1,4,0,11,{31,31,11}} },
  { op="playsewithpan", sound=134, pan="attacker" }, -- SE_M_MEGA_KICK
  { op="call", label="SolarBeamAbsorbEffect" },
  { op="waitforvisualfinish" },
  { op="clearmonbg", battler="atk_partner" },
  { op="blendoff" },
  { op="end" },
}

M.script = {
  { op="loadspritegfx", tag=10147 }, -- ANIM_TAG_ORBS
  { op="fadetobg", bg={byAttackerSide={player="solar_beam_opponent",opponent="solar_beam_player"}} },
  { op="waitbgfadein" },
  { op="panse", sound=194, from="attacker", to="target", increment=2 }, -- SE_M_SOLAR_BEAM
  { op="createvisualtask", task="AnimTask_CreateSmallSolarBeamOrbs", priority=5 },
  { op="createsprite", template="gSolarBeamBigOrbSpriteTemplate", anchor="target", priority=3,
    args={15,0,20,0} },
  { op="delay", frames=4 },
  { op="createsprite", template="gSolarBeamBigOrbSpriteTemplate", anchor="target", priority=3,
    args={15,0,20,1} },
  { op="delay", frames=4 },
  { op="createvisualtask", task="AnimTask_BlendBattleAnimPal", priority=10,
    args={"target",1,0,10,{25,31,0}} },
  { op="createsprite", template="gSolarBeamBigOrbSpriteTemplate", anchor="target", priority=3,
    args={15,0,20,2} },
  { op="delay", frames=4 },
  { op="createvisualtask", task="AnimTask_ShakeMon2", priority=5,
    args={"target",2,0,65,1} },
  { op="createsprite", template="gSolarBeamBigOrbSpriteTemplate", anchor="target", priority=3,
    args={15,0,20,3} },
  { op="delay", frames=4 },
  { op="createsprite", template="gSolarBeamBigOrbSpriteTemplate", anchor="target", priority=3,
    args={15,0,20,4} },
  { op="delay", frames=4 },
  { op="createsprite", template="gSolarBeamBigOrbSpriteTemplate", anchor="target", priority=3,
    args={15,0,20,5} },
  { op="delay", frames=4 },
  { op="createsprite", template="gSolarBeamBigOrbSpriteTemplate", anchor="target", priority=3,
    args={15,0,20,6} },
  { op="delay", frames=4 },
  { op="call", label="SolarBeamUnleash1" },
  { op="call", label="SolarBeamUnleash1" },
  { op="waitforvisualfinish" },
  { op="createvisualtask", task="AnimTask_BlendBattleAnimPal", priority=10,
    args={"target",1,10,0,{25,31,0}} },
  { op="restorebg" },
  { op="waitbgfadein" },
  { op="end" },
}

M.labels = {
  SolarBeamAbsorbEffect = {
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
  SolarBeamUnleash1 = {
    { op="createsprite", template="gSolarBeamBigOrbSpriteTemplate", anchor="target", priority=3, args={15,0,20,0} },
    { op="delay", frames=4 },
    { op="createsprite", template="gSolarBeamBigOrbSpriteTemplate", anchor="target", priority=3, args={15,0,20,1} },
    { op="delay", frames=4 },
    { op="createsprite", template="gSolarBeamBigOrbSpriteTemplate", anchor="target", priority=3, args={15,0,20,2} },
    { op="delay", frames=4 },
    { op="createsprite", template="gSolarBeamBigOrbSpriteTemplate", anchor="target", priority=3, args={15,0,20,3} },
    { op="delay", frames=4 },
    { op="createsprite", template="gSolarBeamBigOrbSpriteTemplate", anchor="target", priority=3, args={15,0,20,4} },
    { op="delay", frames=4 },
    { op="createsprite", template="gSolarBeamBigOrbSpriteTemplate", anchor="target", priority=3, args={15,0,20,5} },
    { op="delay", frames=4 },
    { op="createsprite", template="gSolarBeamBigOrbSpriteTemplate", anchor="target", priority=3, args={15,0,20,6} },
    { op="delay", frames=4 },
    { op="return" },
  },
}

M.templates = {
  gPowerAbsorptionOrbSpriteTemplate = {
    tileTag=10147,paletteTag=10147,callback="AnimPowerAbsorptionOrb",
    oam={affine=true,objMode="blend",bpp=4,width=16,height=16},
    anim={kind="dummy",frames={{tileOffset=8,duration=1}}},
  },
  gSolarBeamBigOrbSpriteTemplate = {
    tileTag=10147,paletteTag=10147,callback="AnimSolarBeamBigOrb",
    oam={affine=false,objMode="normal",bpp=4,width=8,height=8},
    anim={kind="dummy",frames={{tileOffset=0,duration=1}}},
  },
  gSolarBeamSmallOrbSpriteTemplate = {
    tileTag=10147,paletteTag=10147,callback="AnimSolarBeamSmallOrb",
    oam={affine=false,objMode="normal",bpp=4,width=8,height=8},
    anim={kind="dummy",frames={{tileOffset=7,duration=1}}},
  },
}

return M
