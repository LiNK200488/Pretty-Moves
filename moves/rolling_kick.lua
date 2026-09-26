local M = { id="ROLLING_KICK", name="Rolling Kick" }

-- FireRed Move_ROLLING_KICK. The attacker performs the native side-aware
-- elliptical roll, accompanied by two SE_M_DOUBLE_TEAM cues, then drops 20 px
-- as a wide foot sweeps across the target. The hit lands after five frames with
-- SE_M_VITAL_THROW2, a basic impact splat, and a six-frame target shake.
M.soundIds = {128,207}

M.script = {
  { op="loadspritegfx", tag=10143 }, -- ANIM_TAG_HANDS_AND_FEET
  { op="loadspritegfx", tag=10135 }, -- ANIM_TAG_IMPACT
  { op="monbg", battler="target" },
  { op="setalpha", eva=12, evb=8 },
  { op="createvisualtask", task="AnimTask_TranslateMonEllipticalRespectSide", priority=2,
    args={"attacker",18,6,1,4} },
  { op="playsewithpan", sound=128, pan="attacker" },
  { op="delay", frames=6 },
  { op="playsewithpan", sound=128, pan="attacker" },
  { op="waitforvisualfinish" },
  { op="createsprite", template="gSlideMonToOffsetSpriteTemplate", anchor="attacker", priority=2,
    args={0,20,0,0,4} },
  { op="createsprite", template="gSlidingKickSpriteTemplate", anchor="target", priority=2,
    args={-24,0,48,10,160,0} },
  { op="delay", frames=5 },
  { op="playsewithpan", sound=207, pan="target" },
  { op="createsprite", template="gBasicHitSplatSpriteTemplate", anchor="target", priority=2,
    args={-8,0,"target",2} },
  { op="createvisualtask", task="AnimTask_ShakeMon", priority=2,
    args={"target",5,0,6,1} },
  { op="waitforvisualfinish" },
  { op="createsprite", template="gSlideMonToOriginalPosSpriteTemplate", anchor="attacker", priority=2,
    args={0,1,8} },
  { op="clearmonbg", battler="target" },
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
  gSlidingKickSpriteTemplate = {
    tileTag=10143,paletteTag=10143,callback="AnimSlidingKick",
    oam={affine=false,objMode="normal",bpp=4,width=32,height=32},
    anim={kind="once",frames={{tileOffset=16,duration=1}}},
  },
  gBasicHitSplatSpriteTemplate = {
    tileTag=10135,paletteTag=10135,callback="AnimHitSplatBasic",
    oam={affine=true,objMode="blend",bpp=4,width=32,height=32},
    anim={kind="dummy",frames={{tileOffset=0,duration=1}}},
  },
}

return M
