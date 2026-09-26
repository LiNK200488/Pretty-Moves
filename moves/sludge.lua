local M = { id="SLUDGE", name="Sludge" }

M.soundIds = {119,141}

-- Exact FireRed Move_SLUDGE choreography.
M.script = {
  { op="loadspritegfx", tag=10150 }, -- ANIM_TAG_POISON_BUBBLE
  { op="playsewithpan", sound=119, pan="attacker" }, -- SE_M_BUBBLE3
  { op="createsprite", template="gSludgeProjectileSpriteTemplate", anchor="target", priority=2,
    args={20,0,40,0} },
  { op="waitforvisualfinish" },
  { op="createvisualtask", task="AnimTask_ShakeMon", priority=5,
    args={"target",3,0,5,1} },
  { op="createvisualtask", task="AnimTask_BlendColorCycle", priority=2,
    args={"target",1,2,0,12,{30,0,31}} },
  { op="call", label="PoisonBubblesEffect" },
  { op="waitforvisualfinish" },
  { op="end" },
}

M.labels = {
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
  gSludgeProjectileSpriteTemplate = {
    tileTag=10150,paletteTag=10150,callback="AnimSludgeProjectile",
    oam={affine=true,doubleSize=true,objMode="normal",bpp=4,width=16,height=16},
    anim={kind="dummy",frames={{tileOffset=0,duration=1}}},
  },
  gPoisonBubbleSpriteTemplate = {
    tileTag=10150,paletteTag=10150,callback="AnimBubbleEffect",
    oam={affine=true,objMode="normal",bpp=4,width=16,height=16},
    anim={kind="dummy",frames={{tileOffset=0,duration=1}}},
  },
}

return M
