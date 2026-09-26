local M = { id="BIDE", name="Bide" }

-- FireRed Move_BIDE chooses BideSetUp on the storing turn and BideUnleash on
-- release. Gen1Recomp exposes those as two different host rows, so the bridge
-- uses chargeScript for the first-turn XSTATITEM row and script for BIDE itself.
M.chargeScript = {
  { op="loopsewithpan", sound=145, pan="attacker", interval=9, count=2 }, -- SE_M_TAKE_DOWN
  { op="createvisualtask", task="AnimTask_BlendColorCycle", priority=2,
    args={"attacker",2,2,0,11,{31,0,0}} },
  { op="createvisualtask", task="AnimTask_ShakeMon2", priority=2,
    args={"attacker",1,0,32,1} },
  { op="waitforvisualfinish" },
  { op="end" },
}

M.script = {
  { op="loadspritegfx", tag=10135 }, -- ANIM_TAG_IMPACT
  { op="monbg", battler="def_partner" },
  { op="setalpha", eva=12, evb=8 },
  { op="loopsewithpan", sound=145, pan="attacker", interval=9, count=2 }, -- SE_M_TAKE_DOWN
  { op="createvisualtask", task="AnimTask_BlendBattleAnimPal", priority=10,
    args={"attacker",2,0,11,{31,0,0}} },
  { op="createvisualtask", task="AnimTask_ShakeMon2", priority=2,
    args={"attacker",1,0,32,1} },
  { op="waitforvisualfinish" },

  { op="createsprite", template="gSlideMonToOffsetSpriteTemplate", anchor="attacker", priority=2,
    args={0,24,0,0,4} },
  { op="waitforvisualfinish" },
  { op="createvisualtask", task="AnimTask_ShakeMonInPlace", priority=2,
    args={"attacker",2,0,12,1} },
  { op="createvisualtask", task="AnimTask_ShakeMon2", priority=2,
    args={"target",3,0,16,1} },

  { op="playsewithpan", sound=132, pan="target" }, -- SE_M_COMET_PUNCH
  { op="createsprite", template="gBasicHitSplatSpriteTemplate", anchor="attacker", priority=1,
    args={18,-8,"target",1} },
  { op="delay", frames=5 },
  { op="playsewithpan", sound=132, pan="target" },
  { op="createsprite", template="gBasicHitSplatSpriteTemplate", anchor="attacker", priority=1,
    args={-18,8,"target",1} },
  { op="delay", frames=5 },
  { op="playsewithpan", sound=132, pan="target" },
  { op="createsprite", template="gBasicHitSplatSpriteTemplate", anchor="attacker", priority=1,
    args={-8,-5,"target",1} },
  { op="waitforvisualfinish" },
  { op="delay", frames=5 },

  { op="createsprite", template="gSlideMonToOriginalPosSpriteTemplate", anchor="attacker", priority=2,
    args={0,0,7} },
  { op="waitforvisualfinish" },
  { op="createvisualtask", task="AnimTask_BlendBattleAnimPal", priority=10,
    args={"attacker",2,11,0,{31,0,0}} },
  { op="waitforvisualfinish" },
  { op="clearmonbg", battler="def_partner" },
  { op="blendoff" },
  { op="end" },
}

M.templates = {
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
  gBasicHitSplatSpriteTemplate = {
    tileTag=10135,paletteTag=10135,callback="AnimHitSplatBasic",
    oam={affine=true,objMode="blend",bpp=4,width=32,height=32},
    anim={kind="dummy",frames={{tileOffset=0,duration=1}}},
  },
}

return M
