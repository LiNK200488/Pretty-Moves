local M = { id="STRENGTH", name="Strength" }

-- FireRed Move_STRENGTH. The attacker braces by shaking and sinking, then the
-- target spins elliptically while three offset impact splats land with
-- SE_M_MEGA_KICK2. A final short shake completes the hit.
M.soundIds = {145,134}

M.script = {
  { op="loadspritegfx", tag=10135 }, -- ANIM_TAG_IMPACT
  { op="monbg", battler="def_partner" },
  { op="setalpha", eva=12, evb=8 },
  { op="playsewithpan", sound=145, pan="attacker" }, -- SE_M_TAKE_DOWN
  { op="createvisualtask", task="AnimTask_ShakeAndSinkMon", priority=5,
    args={"attacker",2,0,96,30} },
  { op="waitforvisualfinish" },
  { op="delay", frames=10 },
  { op="createsprite", template="gSlideMonToOriginalPosSpriteTemplate", anchor="attacker", priority=2,
    args={0,0,4} },
  { op="createvisualtask", task="AnimTask_TranslateMonEllipticalRespectSide", priority=2,
    args={"target",18,6,2,4} },
  { op="delay", frames=4 },
  { op="playsewithpan", sound=134, pan="target" },
  { op="createsprite", template="gBasicHitSplatSpriteTemplate", anchor="attacker", priority=3,
    args={16,12,"target",1} },
  { op="delay", frames=4 },
  { op="playsewithpan", sound=134, pan="target" },
  { op="createsprite", template="gBasicHitSplatSpriteTemplate", anchor="attacker", priority=3,
    args={-16,-12,"target",1} },
  { op="delay", frames=4 },
  { op="playsewithpan", sound=134, pan="target" },
  { op="createsprite", template="gBasicHitSplatSpriteTemplate", anchor="attacker", priority=3,
    args={3,4,"target",1} },
  { op="waitforvisualfinish" },
  { op="createvisualtask", task="AnimTask_ShakeMon2", priority=2,
    args={"target",2,0,8,1} },
  { op="waitforvisualfinish" },
  { op="clearmonbg", battler="def_partner" },
  { op="blendoff" },
  { op="end" },
}

M.templates = {
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
