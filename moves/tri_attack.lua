local M = { id="TRI_ATTACK", name="Tri Attack" }

-- FireRed Move_TRI_ATTACK. Status/result logic remains Gen1Recomp-owned;
-- this module replaces only the move animation and FireRed SFX choreography.
M.soundIds = {213,138,214,130}

M.script = {
  { op="loadspritegfx", tag=10230 }, -- ANIM_TAG_TRI_ATTACK_TRIANGLE
  { op="createsprite", template="gTriAttackTriangleSpriteTemplate", anchor="target", priority=2, args={16,0} },
  { op="playsewithpan", sound=213, pan="attacker" },
  { op="delay", frames=20 },
  { op="playsewithpan", sound=213, pan="attacker" },
  { op="delay", frames=20 },
  { op="createsoundtask", task="SoundTask_LoopSEAdjustPanning", args={213,"attacker","target",5,6,0,7} },
  { op="waitforvisualfinish" },

  { op="createsprite", template="gSimplePaletteBlendSpriteTemplate", anchor="attacker", priority=2,
    args={"bg",2,0,16,"black"} },
  { op="delay", frames=16 },

  { op="loadspritegfx", tag=10033 }, -- ANIM_TAG_FIRE
  { op="createsprite", template="gLargeFlameScatterSpriteTemplate", anchor="target", priority=2, args={0,0,30,30,-1,0} },
  { op="playsewithpan", sound=138, pan="target" },
  { op="createsprite", template="gLargeFlameScatterSpriteTemplate", anchor="target", priority=2, args={0,0,30,30,0,1} },
  { op="delay", frames=1 },
  { op="createsprite", template="gLargeFlameScatterSpriteTemplate", anchor="target", priority=2, args={0,0,30,30,-1,-1} },
  { op="delay", frames=1 },
  { op="createsprite", template="gLargeFlameScatterSpriteTemplate", anchor="target", priority=2, args={0,0,30,30,2,1} },
  { op="delay", frames=1 },
  { op="createsprite", template="gLargeFlameScatterSpriteTemplate", anchor="target", priority=2, args={0,0,30,30,1,-1} },
  { op="delay", frames=1 },
  { op="createsprite", template="gLargeFlameScatterSpriteTemplate", anchor="target", priority=2, args={0,0,30,30,-1,1} },
  { op="delay", frames=1 },
  { op="createsprite", template="gLargeFlameScatterSpriteTemplate", anchor="target", priority=2, args={0,0,30,30,1,-2} },
  { op="delay", frames=1 },
  { op="createsprite", template="gLargeFlameScatterSpriteTemplate", anchor="target", priority=2, args={0,0,30,30,3,1} },
  { op="delay", frames=2 },
  { op="createvisualtask", task="AnimTask_ShakeTargetInPattern", priority=2, args={20,3,true,1} },
  { op="waitforvisualfinish" },

  { op="loadspritegfx", tag=10037 }, -- ANIM_TAG_LIGHTNING
  { op="createvisualtask", task="AnimTask_InvertScreenColor", priority=2, args={257,257,257} },
  { op="playsewithpan", sound=214, pan="target" },
  { op="createsprite", template="gLightningSpriteTemplate", anchor="target", priority=2, args={0,-48} },
  { op="delay", frames=1 },
  { op="createsprite", template="gLightningSpriteTemplate", anchor="target", priority=2, args={0,-16} },
  { op="delay", frames=1 },
  { op="createsprite", template="gLightningSpriteTemplate", anchor="target", priority=2, args={0,16} },
  { op="delay", frames=20 },
  { op="createvisualtask", task="AnimTask_ShakeTargetInPattern", priority=2, args={20,3,true,0} },
  { op="delay", frames=2 },
  { op="createvisualtask", task="AnimTask_InvertScreenColor", priority=2, args={257,257,257} },
  { op="waitforvisualfinish" },

  { op="loadspritegfx", tag=10141 }, -- ANIM_TAG_ICE_CRYSTALS
  { op="call", label="IceCrystalEffectShort" },
  { op="createsprite", template="gSimplePaletteBlendSpriteTemplate", anchor="attacker", priority=2,
    args={"bg",2,16,0,"black"} },
  { op="waitforvisualfinish" },
  { op="end" },
}

M.labels = {
  IceCrystalEffectShort = {
    { op="createsprite", template="gIceCrystalHitLargeSpriteTemplate", anchor="target", priority=2, args={-10,-10,0} },
    { op="playsewithpan", sound=130, pan="target" },
    { op="delay", frames=4 },
    { op="createsprite", template="gIceCrystalHitSmallSpriteTemplate", anchor="target", priority=2, args={10,20,0} },
    { op="playsewithpan", sound=130, pan="target" },
    { op="delay", frames=4 },
    { op="createsprite", template="gIceCrystalHitLargeSpriteTemplate", anchor="target", priority=2, args={-5,10,0} },
    { op="playsewithpan", sound=130, pan="target" },
    { op="delay", frames=4 },
    { op="createsprite", template="gIceCrystalHitSmallSpriteTemplate", anchor="target", priority=2, args={17,-12,0} },
    { op="playsewithpan", sound=130, pan="target" },
    { op="delay", frames=4 },
    { op="createsprite", template="gIceCrystalHitSmallSpriteTemplate", anchor="target", priority=2, args={-15,15,0} },
    { op="playsewithpan", sound=130, pan="target" },
    { op="delay", frames=4 },
    { op="createsprite", template="gIceCrystalHitSmallSpriteTemplate", anchor="target", priority=2, args={0,0,0} },
    { op="playsewithpan", sound=130, pan="target" },
    { op="delay", frames=4 },
    { op="createsprite", template="gIceCrystalHitLargeSpriteTemplate", anchor="target", priority=2, args={20,2,0} },
    { op="playsewithpan", sound=130, pan="target" },
    { op="return" },
  },
}

M.templates = {
  gTriAttackTriangleSpriteTemplate = {
    tileTag=10230,paletteTag=10230,callback="AnimTriAttackTriangle",
    oam={affine=true,doubleSize=true,objMode="normal",bpp=4,width=64,height=64},
    anim={kind="once",frames={{tileOffset=0,duration=8}}},
  },
  gSimplePaletteBlendSpriteTemplate={controller=true,callback="AnimSimplePaletteBlend"},
  gLargeFlameScatterSpriteTemplate = {
    tileTag=10033,paletteTag=10033,callback="AnimLargeFlame",
    oam={affine=false,objMode="normal",bpp=4,width=32,height=32},
    anim={kind="loop",frames={
      {tileOffset=0,duration=3},{tileOffset=16,duration=3},{tileOffset=32,duration=3},{tileOffset=48,duration=3},
      {tileOffset=64,duration=3},{tileOffset=80,duration=3},{tileOffset=96,duration=3},{tileOffset=112,duration=3},
    }},
    extraTileOffsets={16,32,48,64,80,96,112},
  },
  gLightningSpriteTemplate = {
    tileTag=10037,paletteTag=10037,callback="AnimLightning",
    oam={width=32,height=32},
    anim={kind="once",frames={
      {tileOffset=0,duration=5},{tileOffset=16,duration=5},{tileOffset=32,duration=8},
      {tileOffset=48,duration=5},{tileOffset=64,duration=5},
    }},
    extraTileOffsets={16,32,48,64},
  },
  gIceCrystalHitLargeSpriteTemplate={tileTag=10141,paletteTag=10141,callback="AnimIceEffectParticle",oam={width=8,height=16,objMode="blend",affine=true},anim={kind="dummy",frames={{tileOffset=4,duration=1}}}},
  gIceCrystalHitSmallSpriteTemplate={tileTag=10141,paletteTag=10141,callback="AnimIceEffectParticle",oam={width=8,height=8,objMode="blend",affine=true},anim={kind="dummy",frames={{tileOffset=6,duration=1}}}},
}

return M
