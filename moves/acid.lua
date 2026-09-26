local M = { id="ACID", name="Acid" }

M.soundIds = {117,119}

-- FireRed Move_ACID. Three arcing poison bubbles travel from the attacker to
-- the defender at five-frame spacing. On impact the defender shakes and cycles
-- toward the native purple blend while five poison droplets fall across it.
M.script = {
  { op="loadspritegfx", tag=10150 }, -- ANIM_TAG_POISON_BUBBLE
  { op="monbg", battler="def_partner" },

  { op="createsprite", template="gAcidPoisonBubbleSpriteTemplate", anchor="target", priority=2,
    args={20,0,40,1,0,0} },
  { op="playsewithpan", sound=119, pan="attacker" }, -- SE_M_BUBBLE3
  { op="delay", frames=5 },
  { op="createsprite", template="gAcidPoisonBubbleSpriteTemplate", anchor="target", priority=2,
    args={20,0,40,1,24,0} },
  { op="playsewithpan", sound=119, pan="attacker" },
  { op="delay", frames=5 },
  { op="createsprite", template="gAcidPoisonBubbleSpriteTemplate", anchor="target", priority=2,
    args={20,0,40,1,-24,0} },
  { op="playsewithpan", sound=119, pan="attacker" },
  { op="delay", frames=15 },

  { op="createvisualtask", task="AnimTask_ShakeMon2", priority=5,
    args={"target",2,0,10,1} },
  { op="createvisualtask", task="AnimTask_ShakeMon2", priority=5,
    args={"def_partner",2,0,10,1} },
  { op="createvisualtask", task="AnimTask_BlendColorCycle", priority=2,
    args={"target",2,2,0,12,{30,0,31}} },

  { op="createsprite", template="gAcidPoisonDropletSpriteTemplate", anchor="target", priority=2,
    args={0,-22,0,15,55} },
  { op="playsewithpan", sound=117, pan="target" }, -- SE_M_BUBBLE
  { op="delay", frames=10 },
  { op="createsprite", template="gAcidPoisonDropletSpriteTemplate", anchor="target", priority=2,
    args={-26,-24,0,15,55} },
  { op="playsewithpan", sound=117, pan="target" },
  { op="delay", frames=10 },
  { op="createsprite", template="gAcidPoisonDropletSpriteTemplate", anchor="target", priority=2,
    args={15,-27,0,15,50} },
  { op="playsewithpan", sound=117, pan="target" },
  { op="delay", frames=10 },
  { op="createsprite", template="gAcidPoisonDropletSpriteTemplate", anchor="target", priority=2,
    args={-15,-17,0,10,45} },
  { op="playsewithpan", sound=117, pan="target" },
  { op="delay", frames=10 },
  { op="createsprite", template="gAcidPoisonDropletSpriteTemplate", anchor="target", priority=2,
    args={27,-22,0,15,50} },
  { op="playsewithpan", sound=117, pan="target" },

  { op="waitforvisualfinish" },
  { op="clearmonbg", battler="def_partner" },
  { op="end" },
}

M.templates = {
  gAcidPoisonBubbleSpriteTemplate = {
    tileTag=10150,paletteTag=10150,callback="AnimAcidPoisonBubble",
    oam={affine=true,doubleSize=true,objMode="normal",bpp=4,width=16,height=16},
    anim={kind="dummy",frames={{tileOffset=0,duration=1}}},
  },
  gAcidPoisonDropletSpriteTemplate = {
    tileTag=10150,paletteTag=10150,callback="AnimAcidPoisonDroplet",
    oam={affine=true,doubleSize=true,objMode="normal",bpp=4,width=16,height=16},
    anim={kind="dummy",frames={{tileOffset=4,duration=1}}},
  },
}

return M
