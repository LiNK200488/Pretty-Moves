local M = { id="CRABHAMMER", name="Crabhammer" }

-- Source-traced FireRed Move_CRABHAMMER. A water impact opens the move,
-- the scene pulses blue/black while the attacker lunges forward and returns,
-- then the target shakes under three Crabhammer SFX while eight pairs of
-- tiny bubbles rise and sway around it.
M.script = {
  { op="loadspritegfx", tag=10141 }, -- ANIM_TAG_ICE_CRYSTALS (contains small bubble-pair art)
  { op="loadspritegfx", tag=10148 }, -- ANIM_TAG_WATER_IMPACT
  { op="monbg", battler="def_partner" },
  { op="setalpha", eva=12, evb=8 },

  { op="createsprite", template="gWaterHitSplatSpriteTemplate", anchor="target", priority=4,
    args={0,0,"target",0} },
  { op="playsewithpan", sound=207, pan="target" }, -- SE_M_VITAL_THROW2
  { op="delay", frames=1 },
  { op="createsprite", template="gComplexPaletteBlendSpriteTemplate", anchor="attacker", priority=2,
    args={"all_and_bg",3,1,{13,21,31},10,"black",0} },
  { op="createsprite", template="gSlideMonToOffsetSpriteTemplate", anchor="attacker", priority=2,
    args={1,-24,0,0,4} },
  { op="waitforvisualfinish" },
  { op="delay", frames=8 },
  { op="waitforvisualfinish" },
  { op="createsprite", template="gSlideMonToOriginalPosSpriteTemplate", anchor="attacker", priority=2,
    args={1,0,4} },
  { op="waitforvisualfinish" },

  { op="loopsewithpan", sound=135, pan="target", interval=20, count=3 }, -- SE_M_CRABHAMMER
  { op="createvisualtask", task="AnimTask_ShakeMon", priority=5, args={"target",0,4,8,1} },
  { op="createsprite", template="gSmallBubblePairSpriteTemplate", anchor="target", priority=2, args={10,10,20,"target"} },
  { op="delay", frames=4 },
  { op="createsprite", template="gSmallBubblePairSpriteTemplate", anchor="target", priority=2, args={20,-20,20,"target"} },
  { op="delay", frames=4 },
  { op="createsprite", template="gSmallBubblePairSpriteTemplate", anchor="target", priority=2, args={-15,15,20,"target"} },
  { op="delay", frames=4 },
  { op="createsprite", template="gSmallBubblePairSpriteTemplate", anchor="target", priority=2, args={0,0,20,"target"} },
  { op="delay", frames=4 },
  { op="createsprite", template="gSmallBubblePairSpriteTemplate", anchor="target", priority=2, args={-10,-20,20,"target"} },
  { op="delay", frames=4 },
  { op="createsprite", template="gSmallBubblePairSpriteTemplate", anchor="target", priority=2, args={16,-8,20,"target"} },
  { op="delay", frames=4 },
  { op="createsprite", template="gSmallBubblePairSpriteTemplate", anchor="target", priority=2, args={5,8,20,"target"} },
  { op="delay", frames=4 },
  { op="createsprite", template="gSmallBubblePairSpriteTemplate", anchor="target", priority=2, args={-16,0,20,"target"} },

  { op="waitforvisualfinish" },
  { op="clearmonbg", battler="def_partner" },
  { op="blendoff" },
  { op="end" },
}

M.templates = {
  gWaterHitSplatSpriteTemplate = {
    tileTag=10148, paletteTag=10148, callback="AnimHitSplatBasic",
    oam={affine=true,objMode="blend",bpp=4,width=32,height=32},
    anim={kind="dummy",frames={{tileOffset=0,duration=1}}},
  },
  gComplexPaletteBlendSpriteTemplate = {
    controller=true, callback="AnimComplexPaletteBlend",
    oam={affine=false,objMode="normal",bpp=4,width=8,height=8},
    anim={kind="dummy",frames={{tileOffset=0,duration=1}}},
  },
  gSlideMonToOffsetSpriteTemplate = {
    controller=true, callback="SlideMonToOffset",
    oam={affine=false,objMode="normal",bpp=4,width=8,height=8},
    anim={kind="dummy",frames={{tileOffset=0,duration=1}}},
  },
  gSlideMonToOriginalPosSpriteTemplate = {
    controller=true, callback="SlideMonToOriginalPos",
    oam={affine=false,objMode="normal",bpp=4,width=8,height=8},
    anim={kind="dummy",frames={{tileOffset=0,duration=1}}},
  },
  gSmallBubblePairSpriteTemplate = {
    tileTag=10141, paletteTag=10141, callback="AnimSmallBubblePair",
    oam={affine=false,objMode="normal",bpp=4,width=8,height=8},
    anim={kind="loop",frames={{tileOffset=12,duration=6},{tileOffset=13,duration=6}}},
  },
}

return M
