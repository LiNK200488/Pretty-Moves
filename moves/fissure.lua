local M = { id="FISSURE", name="Fissure" }

-- FireRed Move_FISSURE, source-faithful. The battlefield and target undergo
-- the native long horizontal quake while three dirt-plume groups erupt around
-- the target. Two black/white BG palette pulses punctuate the plume sequence,
-- then FireRed's dedicated Fissure background is faded in and positioned on
-- the target before the normal battlefield is restored.
M.soundIds = {227,168} -- SE_M_EARTHQUAKE, SE_M_DIG

M.script = {
  { op="loadspritegfx", tag=10074 }, -- ANIM_TAG_MUD_SAND
  { op="createvisualtask", task="AnimTask_HorizontalShake", priority=3, args={"terrain",10,50} },
  { op="createvisualtask", task="AnimTask_HorizontalShake", priority=3, args={"target",10,50} },
  { op="playsewithpan", sound=227, pan="target" }, -- SE_M_EARTHQUAKE
  { op="delay", frames=8 },
  { op="call", label="FissureDirtPlumeFar" },
  { op="delay", frames=15 },
  { op="createsprite", template="gComplexPaletteBlendSpriteTemplate", anchor="attacker", priority=2,
    args={"bg",3,1,"black",14,"white",14} },
  { op="delay", frames=15 },
  { op="call", label="FissureDirtPlumeClose" },
  { op="delay", frames=15 },
  { op="createsprite", template="gComplexPaletteBlendSpriteTemplate", anchor="attacker", priority=2,
    args={"bg",3,1,"black",14,"white",14} },
  { op="delay", frames=15 },
  { op="call", label="FissureDirtPlumeFar" },
  { op="delay", frames=50 },
  { op="fadetobg", bg="fissure" },
  { op="waitbgfadeout" },
  { op="createvisualtask", task="AnimTask_PositionFissureBgOnBattler", priority=5, args={"target",5,-1} },
  { op="waitbgfadein" },
  { op="delay", frames=40 },
  { op="restorebg" },
  { op="waitbgfadeout" },
  { op="setarg", index=7, value=-1 },
  { op="waitbgfadein" },
  { op="end" },
}

M.labels = {
  FissureDirtPlumeFar = {
    { op="createsprite", template="gDirtPlumeSpriteTemplate", anchor="target", priority=2, args={1,0,12,-48,-16,24} },
    { op="createsprite", template="gDirtPlumeSpriteTemplate", anchor="target", priority=2, args={1,0,16,-16,-10,24} },
    { op="createsprite", template="gDirtPlumeSpriteTemplate", anchor="target", priority=2, args={1,1,14,-52,-18,24} },
    { op="createsprite", template="gDirtPlumeSpriteTemplate", anchor="target", priority=2, args={1,1,12,-32,-16,24} },
    { op="playsewithpan", sound=168, pan="target" }, -- SE_M_DIG
    { op="return" },
  },
  FissureDirtPlumeClose = {
    { op="createsprite", template="gDirtPlumeSpriteTemplate", anchor="target", priority=2, args={1,0,12,-24,-16,24} },
    { op="createsprite", template="gDirtPlumeSpriteTemplate", anchor="target", priority=2, args={1,0,16,-38,-10,24} },
    { op="createsprite", template="gDirtPlumeSpriteTemplate", anchor="target", priority=2, args={1,1,14,-20,-18,24} },
    { op="createsprite", template="gDirtPlumeSpriteTemplate", anchor="target", priority=2, args={1,1,12,-36,-16,24} },
    { op="playsewithpan", sound=168, pan="target" }, -- SE_M_DIG
    { op="return" },
  },
}

M.templates = {
  gDirtPlumeSpriteTemplate = {
    tileTag=10074,paletteTag=10074,callback="AnimDirtPlumeParticle",
    oam={affine=false,objMode="normal",bpp=4,width=8,height=8},
    anim={kind="dummy",frames={{tileOffset=0,duration=1}}},
  },
  gComplexPaletteBlendSpriteTemplate = {
    controller=true, callback="AnimComplexPaletteBlend",
    oam={affine=false,objMode="normal",bpp=4,width=8,height=8},
    anim={kind="dummy",frames={{tileOffset=0,duration=1}}},
  },
}

return M
