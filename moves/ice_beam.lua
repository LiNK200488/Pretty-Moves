local M = { id="ICE_BEAM", name="Ice Beam" }

-- FireRed Move_ICE_BEAM. Freeze chance/status logic remains Gen1Recomp-owned;
-- this definition replaces only the move animation and its FireRed SFX.
M.script = {
  { op="loadspritegfx", tag=10141 }, -- ANIM_TAG_ICE_CRYSTALS
  { op="createsoundtask", task="SoundTask_LoopSEAdjustPanning", args={176,"attacker","target",4,4,0,10} },
  { op="createsprite", template="gIceBeamOuterCrystalSpriteTemplate", anchor="attacker", priority=2, args={20,12,0,12,20} },
  { op="createsprite", template="gIceBeamOuterCrystalSpriteTemplate", anchor="attacker", priority=2, args={20,-12,0,-12,20} },
  { op="delay", frames=1 },
  { op="call", label="IceBeamCreateCrystals" },
  { op="call", label="IceBeamCreateCrystals" },
  { op="call", label="IceBeamCreateCrystals" },
  -- FireRed impact phase: blend the target palette toward RGB(0,20,31)
  -- from 0 -> 7 while the remaining crystals strike and the target shakes.
  { op="createsprite", template="gSimplePaletteBlendSpriteTemplate", anchor="attacker", priority=2, args={"target",-31,0,7,{0,20,31}} },
  { op="createvisualtask", task="AnimTask_ShakeMon2", priority=2, args={"target",2,0,25,1} },
  { op="call", label="IceBeamCreateCrystals" }, { op="call", label="IceBeamCreateCrystals" },
  { op="call", label="IceBeamCreateCrystals" }, { op="call", label="IceBeamCreateCrystals" },
  { op="call", label="IceBeamCreateCrystals" }, { op="call", label="IceBeamCreateCrystals" },
  { op="call", label="IceBeamCreateCrystals" }, { op="call", label="IceBeamCreateCrystals" },
  { op="createsprite", template="gIceBeamInnerCrystalSpriteTemplate", anchor="attacker", priority=2, args={20,0,0,0,11} },
  { op="delay", frames=1 },
  { op="createsprite", template="gIceBeamInnerCrystalSpriteTemplate", anchor="attacker", priority=2, args={20,0,0,0,11} },
  { op="waitforvisualfinish" },
  { op="delay", frames=20 },
  { op="call", label="IceCrystalEffectShort" },
  { op="createsprite", template="gSimplePaletteBlendSpriteTemplate", anchor="attacker", priority=2, args={"target",5,7,0,{0,20,31}} },
  { op="waitforvisualfinish" },
  { op="blendoff" },
  { op="end" },
}
M.labels = {
IceBeamCreateCrystals = {
  { op="createsprite", template="gIceBeamOuterCrystalSpriteTemplate", anchor="attacker", priority=2, args={20,12,0,12,20} },
  { op="createsprite", template="gIceBeamOuterCrystalSpriteTemplate", anchor="attacker", priority=2, args={20,-12,0,-12,20} },
  { op="createsprite", template="gIceBeamInnerCrystalSpriteTemplate", anchor="attacker", priority=2, args={20,0,0,0,11} },
  { op="delay", frames=1 }, { op="return" },
},
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
  { op="createsprite", template="gIceCrystalHitSmallSpriteTemplate", anchor="target", priority=2, args={0,0,0} },
  { op="playsewithpan", sound=130, pan="target" },
  { op="delay", frames=4 },
  { op="createsprite", template="gIceCrystalHitLargeSpriteTemplate", anchor="target", priority=2, args={20,2,0} },
  { op="playsewithpan", sound=130, pan="target" },
  { op="return" },
},
}
M.templates = {
  gSimplePaletteBlendSpriteTemplate={controller=true,callback="AnimSimplePaletteBlend"},
  gIceBeamOuterCrystalSpriteTemplate={tileTag=10141,paletteTag=10141,callback="AnimIceBeamParticle",oam={width=8,height=8,objMode="blend"},anim={kind="dummy",frames={{tileOffset=6,duration=1}}}},
  gIceBeamInnerCrystalSpriteTemplate={tileTag=10141,paletteTag=10141,callback="AnimIceBeamParticle",oam={width=8,height=16,objMode="blend",affine=true},anim={kind="dummy",frames={{tileOffset=4,duration=1}}}},
  gIceCrystalHitLargeSpriteTemplate={tileTag=10141,paletteTag=10141,callback="AnimIceEffectParticle",oam={width=8,height=16,objMode="blend",affine=true},anim={kind="dummy",frames={{tileOffset=4,duration=1}}}},
  gIceCrystalHitSmallSpriteTemplate={tileTag=10141,paletteTag=10141,callback="AnimIceEffectParticle",oam={width=8,height=8,objMode="blend",affine=true},anim={kind="dummy",frames={{tileOffset=6,duration=1}}}},
}
return M
