local M = { id="DREAM_EATER", name="Dream Eater" }

M.soundIds = {182,197,186,172}

-- FireRed Move_DREAM_EATER. Reuses the confirmed Psychic background and
-- palette rotation, distorts the sleeping target, drains energy through the
-- native absorption-orb pattern, then finishes with the blue healing stars.
M.script = {
  { op="loadspritegfx", tag=10147 }, -- ANIM_TAG_ORBS
  { op="loadspritegfx", tag=10031 }, -- ANIM_TAG_BLUE_STAR
  { op="monbg", battler="def_partner" },
  { op="splitbgprio_foes", battler="target" },
  { op="playsewithpan", sound=182, pan="attacker" },
  { op="fadetobg", bg="psychic" },
  { op="waitbgfadeout" },
  { op="createvisualtask", task="AnimTask_SetPsychicBackground", priority=5 },
  { op="waitbgfadein" },
  { op="setalpha", eva=8, evb=8 },
  { op="playsewithpan", sound=197, pan="target" },
  { op="createvisualtask", task="AnimTask_ShakeMon", priority=2, args={"target",5,0,15,1} },
  { op="createvisualtask", task="AnimTask_ScaleMonAndRestore", priority=5, args={-6,-6,15,"target",1} },
  { op="waitforvisualfinish" },
  { op="setalpha", eva=12, evb=8 },
  { op="createvisualtask", task="AnimTask_ShakeMon", priority=2, args={"target",0,2,25,1} },
  { op="call", label="DreamEaterAbsorb" },
  { op="waitforvisualfinish" },
  { op="delay", frames=15 },
  { op="call", label="HealingEffect" },
  { op="waitforvisualfinish" },
  { op="clearmonbg", battler="def_partner" },
  { op="blendoff" },
  { op="delay", frames=1 },
  { op="restorebg" },
  { op="waitbgfadeout" },
  { op="setarg", index=7, value=0xFFFF },
  { op="waitbgfadein" },
  { op="end" },
}

M.labels = {
  DreamEaterAbsorb = {
    { op="playsewithpan", sound=186, pan="target" },
    { op="createsprite", template="gAbsorptionOrbSpriteTemplate", anchor="attacker", priority=3, args={0,5,8,26} },
    { op="createsprite", template="gAbsorptionOrbSpriteTemplate", anchor="attacker", priority=3, args={5,-18,-40,35} },
    { op="createsprite", template="gAbsorptionOrbSpriteTemplate", anchor="attacker", priority=3, args={-10,20,20,39} },
    { op="delay", frames=4 },
    { op="playsewithpan", sound=186, pan="target" },
    { op="createsprite", template="gAbsorptionOrbSpriteTemplate", anchor="attacker", priority=3, args={0,5,28,26} },
    { op="createsprite", template="gAbsorptionOrbSpriteTemplate", anchor="attacker", priority=3, args={10,-5,-8,26} },
    { op="createsprite", template="gAbsorptionOrbSpriteTemplate", anchor="attacker", priority=3, args={-10,20,40,39} },
    { op="delay", frames=4 },
    { op="playsewithpan", sound=186, pan="target" },
    { op="createsprite", template="gAbsorptionOrbSpriteTemplate", anchor="attacker", priority=3, args={10,-5,-8,26} },
    { op="createsprite", template="gAbsorptionOrbSpriteTemplate", anchor="attacker", priority=3, args={-5,15,16,33} },
    { op="createsprite", template="gAbsorptionOrbSpriteTemplate", anchor="attacker", priority=3, args={10,-5,-32,26} },
    { op="delay", frames=4 },
    { op="playsewithpan", sound=186, pan="target" },
    { op="createsprite", template="gAbsorptionOrbSpriteTemplate", anchor="attacker", priority=3, args={0,-15,-16,36} },
    { op="createsprite", template="gAbsorptionOrbSpriteTemplate", anchor="attacker", priority=3, args={0,5,8,26} },
    { op="createsprite", template="gAbsorptionOrbSpriteTemplate", anchor="attacker", priority=3, args={10,-5,-8,26} },
    { op="delay", frames=4 },
    { op="playsewithpan", sound=186, pan="target" },
    { op="createsprite", template="gAbsorptionOrbSpriteTemplate", anchor="attacker", priority=3, args={-5,15,16,33} },
    { op="createsprite", template="gAbsorptionOrbSpriteTemplate", anchor="attacker", priority=3, args={0,-15,-16,36} },
    { op="createsprite", template="gAbsorptionOrbSpriteTemplate", anchor="attacker", priority=3, args={0,5,8,26} },
    { op="delay", frames=4 },
    { op="playsewithpan", sound=186, pan="target" },
    { op="createsprite", template="gAbsorptionOrbSpriteTemplate", anchor="attacker", priority=3, args={0,5,8,26} },
    { op="createsprite", template="gAbsorptionOrbSpriteTemplate", anchor="attacker", priority=3, args={-5,15,16,33} },
    { op="createsprite", template="gAbsorptionOrbSpriteTemplate", anchor="attacker", priority=3, args={10,-5,-40,26} },
    { op="delay", frames=4 },
    { op="playsewithpan", sound=186, pan="target" },
    { op="createsprite", template="gAbsorptionOrbSpriteTemplate", anchor="attacker", priority=3, args={-5,15,36,33} },
    { op="createsprite", template="gAbsorptionOrbSpriteTemplate", anchor="attacker", priority=3, args={10,-5,-8,26} },
    { op="createsprite", template="gAbsorptionOrbSpriteTemplate", anchor="attacker", priority=3, args={-10,20,20,39} },
    { op="delay", frames=4 },
    { op="playsewithpan", sound=186, pan="target" },
    { op="createsprite", template="gAbsorptionOrbSpriteTemplate", anchor="attacker", priority=3, args={0,5,8,26} },
    { op="createsprite", template="gAbsorptionOrbSpriteTemplate", anchor="attacker", priority=3, args={0,5,8,26} },
    { op="createsprite", template="gAbsorptionOrbSpriteTemplate", anchor="attacker", priority=3, args={5,-18,-20,35} },
    { op="delay", frames=4 },
    { op="return" },
  },
  HealingEffect = {
    { op="playsewithpan", sound=172, pan="attacker" },
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
  gAbsorptionOrbSpriteTemplate = {
    tileTag=10147,paletteTag=10147,callback="AnimAbsorptionOrb",
    oam={width=16,height=16,objMode="blend",affine=true},
    anim={kind="dummy",frames={{tileOffset=8,duration=1}}},
  },
  gHealingBlueStarSpriteTemplate = {
    tileTag=10031,paletteTag=10031,callback="AnimSpriteOnMonPos",
    oam={width=32,height=32,objMode="normal"},
    anim={kind="once",frames={{tileOffset=0,duration=2},{tileOffset=16,duration=2},{tileOffset=32,duration=2},{tileOffset=48,duration=3}}},
  },
}

return M
