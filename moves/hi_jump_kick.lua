local M = { id="HI_JUMP_KICK", name="Hi Jump Kick" }

-- Source-traced FireRed Move_HI_JUMP_KICK. The attacker first rises 24 px over
-- 8 native frames, pauses, then snaps back toward its original position while
-- the wide-foot Jump Kick sprite travels diagonally into the target. On impact
-- the target is knocked 28 px away, shakes in place for 11 frames, then
-- returns to its original position over 6 frames.
M.soundIds = {136,207}

M.script = {
  { op="loadspritegfx", tag=10143 }, -- ANIM_TAG_HANDS_AND_FEET
  { op="loadspritegfx", tag=10135 }, -- ANIM_TAG_IMPACT
  { op="monbg", battler="def_partner" },
  { op="setalpha", eva=12, evb=8 },
  { op="createsprite", template="gSlideMonToOffsetSpriteTemplate", anchor="attacker", priority=2,
    args={0,-24,0,0,8} },
  { op="waitforvisualfinish" },
  { op="delay", frames=10 },
  { op="createsprite", template="gSlideMonToOriginalPosSpriteTemplate", anchor="attacker", priority=2,
    args={0,0,3} },
  { op="delay", frames=2 },
  { op="createsprite", template="gJumpKickSpriteTemplate", anchor="attacker", priority=2,
    args={-16,8,0,0,10,"target",1,1} },
  { op="playsewithpan", sound=136, pan="target" }, -- SE_M_JUMP_KICK
  { op="waitforvisualfinish" },
  { op="createsprite", template="gBasicHitSplatSpriteTemplate", anchor="attacker", priority=2,
    args={0,0,"target",1} },
  { op="playsewithpan", sound=207, pan="target" }, -- SE_M_VITAL_THROW2
  { op="createsprite", template="gSlideMonToOffsetSpriteTemplate", anchor="attacker", priority=2,
    args={1,-28,0,0,3} },
  { op="delay", frames=3 },
  { op="createvisualtask", task="AnimTask_ShakeMonInPlace", priority=2,
    args={"target",3,0,11,1} },
  { op="waitforvisualfinish" },
  { op="delay", frames=5 },
  { op="createsprite", template="gSlideMonToOriginalPosSpriteTemplate", anchor="attacker", priority=2,
    args={1,0,6} },
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
  gJumpKickSpriteTemplate = {
    tileTag=10143,paletteTag=10143,callback="AnimJumpKick",
    oam={affine=false,objMode="normal",bpp=4,width=32,height=32},
    anim={kind="once",frames={{tileOffset=0,duration=1}}},
  },
  gBasicHitSplatSpriteTemplate = {
    tileTag=10135,paletteTag=10135,callback="AnimHitSplatBasic",
    oam={affine=true,objMode="blend",bpp=4,width=32,height=32},
    anim={kind="dummy",frames={{tileOffset=0,duration=1}}},
  },
}

return M
