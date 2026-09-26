local M = { id="WING_ATTACK", name="Wing Attack" }

-- FireRed Move_WING_ATTACK. Two Gust sprites widen for 24 affine ticks before
-- translating into the target, while the attacker circles, lunges forward,
-- lands twin impact splats, then slides back to its original position.
M.script = {
  { op="loadspritegfx", tag=10009 }, -- ANIM_TAG_GUST
  { op="loadspritegfx", tag=10135 }, -- ANIM_TAG_IMPACT
  { op="monbg", battler="def_partner" },
  { op="splitbgprio", battler="target" },
  { op="setalpha", eva=12, evb=8 },
  { op="loopsewithpan", sound=150, pan="attacker", interval=20, count=2 }, -- SE_M_WING_ATTACK
  { op="createvisualtask", task="AnimTask_TranslateMonElliptical", priority=2,
    args={"attacker",12,4,1,4} },
  { op="createvisualtask", task="AnimTask_AnimateGustTornadoPalette", priority=5, args={1,70} },
  { op="createsprite", template="gGustToTargetSpriteTemplate", anchor="attacker", priority=2,
    args={-25,0,0,0,20} },
  { op="createsprite", template="gGustToTargetSpriteTemplate", anchor="attacker", priority=2,
    args={25,0,0,0,20} },
  { op="delay", frames=24 },
  { op="createsprite", template="gSlideMonToOffsetSpriteTemplate", anchor="attacker", priority=2,
    args={0,24,0,0,9} },
  { op="delay", frames=17 },
  { op="createsprite", template="gBasicHitSplatSpriteTemplate", anchor="attacker", priority=2,
    args={16,0,"target",1} },
  { op="createsprite", template="gBasicHitSplatSpriteTemplate", anchor="attacker", priority=2,
    args={-16,0,"target",1} },
  { op="loopsewithpan", sound=127, pan="target", interval=5, count=2 }, -- SE_M_DOUBLE_SLAP
  { op="waitforvisualfinish" },
  { op="createsprite", template="gSlideMonToOriginalPosSpriteTemplate", anchor="attacker", priority=2,
    args={0,0,11} },
  { op="waitforvisualfinish" },
  { op="clearmonbg", battler="def_partner" },
  { op="blendoff" },
  { op="end" },
}

M.templates = {
  gGustToTargetSpriteTemplate = {
    tileTag=10009,paletteTag=10009,callback="AnimGustToTarget",
    oam={affine=true,objMode="normal",bpp=4,width=32,height=64},
    anim={kind="dummy",frames={{tileOffset=0,duration=1}}},
    paletteRotations=true,
  },
  gSlideMonToOffsetSpriteTemplate = {
    controller=true,callback="SlideMonToOffset",
    oam={affine=false,objMode="normal",bpp=4,width=8,height=8},
    anim={kind="dummy",frames={{tileOffset=0,duration=1}}},
  },
  gSlideMonToOriginalPosSpriteTemplate = {
    controller=true,callback="SlideMonToOriginalPos",
    oam={affine=false,objMode="normal",bpp=4,width=8,height=8},
    anim={kind="dummy",frames={{tileOffset=0,duration=1}}},
  },
  gBasicHitSplatSpriteTemplate = {
    tileTag=10135,paletteTag=10135,callback="AnimHitSplatBasic",
    oam={affine=true,objMode="blend",bpp=4,width=32,height=32},
    anim={kind="dummy",frames={{tileOffset=0,duration=1}}},
  },
}
return M
