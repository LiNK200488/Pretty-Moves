local M = { id="TOXIC", name="Toxic" }

-- Exact FireRed Move_TOXIC choreography.
-- Two four-bubble Toxic passes use the dedicated 16x32 Toxic bubble sheet,
-- followed by FireRed's shared six-bubble poison effect.
M.script = {
  { op="loadspritegfx", tag=10151 }, -- ANIM_TAG_TOXIC_BUBBLE
  { op="loadspritegfx", tag=10150 }, -- ANIM_TAG_POISON_BUBBLE
  { op="call", label="ToxicBubbles" },
  { op="call", label="ToxicBubbles" },
  { op="waitforvisualfinish" },
  { op="delay", frames=15 },
  { op="call", label="PoisonBubblesEffect" },
  { op="waitforvisualfinish" },
  { op="end" },
}

M.labels = {
  ToxicBubbles = {
    { op="createsprite", template="gToxicBubbleSpriteTemplate", anchor="target", priority=2, args={-24,16,1,1} },
    { op="playsewithpan", sound=141, pan="target" }, -- SE_M_TOXIC
    { op="delay", frames=15 },
    { op="createsprite", template="gToxicBubbleSpriteTemplate", anchor="target", priority=2, args={8,16,1,1} },
    { op="playsewithpan", sound=141, pan="target" },
    { op="delay", frames=15 },
    { op="createsprite", template="gToxicBubbleSpriteTemplate", anchor="target", priority=2, args={-8,16,1,1} },
    { op="playsewithpan", sound=141, pan="target" },
    { op="delay", frames=15 },
    { op="createsprite", template="gToxicBubbleSpriteTemplate", anchor="target", priority=2, args={24,16,1,1} },
    { op="playsewithpan", sound=141, pan="target" },
    { op="delay", frames=15 },
    { op="return" },
  },

  PoisonBubblesEffect = {
    { op="createsprite", template="gPoisonBubbleSpriteTemplate", anchor="target", priority=2, args={10,10,0} },
    { op="playsewithpan", sound=141, pan="target" },
    { op="delay", frames=6 },
    { op="createsprite", template="gPoisonBubbleSpriteTemplate", anchor="target", priority=2, args={20,-20,0} },
    { op="playsewithpan", sound=141, pan="target" },
    { op="delay", frames=6 },
    { op="createsprite", template="gPoisonBubbleSpriteTemplate", anchor="target", priority=2, args={-20,15,0} },
    { op="playsewithpan", sound=141, pan="target" },
    { op="delay", frames=6 },
    { op="createsprite", template="gPoisonBubbleSpriteTemplate", anchor="target", priority=2, args={0,0,0} },
    { op="playsewithpan", sound=141, pan="target" },
    { op="delay", frames=6 },
    { op="createsprite", template="gPoisonBubbleSpriteTemplate", anchor="target", priority=2, args={-20,-20,0} },
    { op="playsewithpan", sound=141, pan="target" },
    { op="delay", frames=6 },
    { op="createsprite", template="gPoisonBubbleSpriteTemplate", anchor="target", priority=2, args={16,-8,0} },
    { op="playsewithpan", sound=141, pan="target" },
    { op="return" },
  },
}

M.templates = {
  gToxicBubbleSpriteTemplate = {
    tileTag=10151, paletteTag=10151, callback="AnimSpriteOnMonPos",
    oam={affine=false,objMode="normal",bpp=4,width=16,height=32},
    anim={kind="sequence",frames={
      {tileOffset=0,duration=5},
      {tileOffset=8,duration=5},
      {tileOffset=16,duration=5},
      {tileOffset=24,duration=5},
    }},
  },
  gPoisonBubbleSpriteTemplate = {
    tileTag=10150, paletteTag=10150, callback="AnimBubbleEffect",
    oam={affine=true,objMode="normal",bpp=4,width=16,height=16},
    anim={kind="dummy",frames={{tileOffset=0,duration=1}}},
  },
}

return M
