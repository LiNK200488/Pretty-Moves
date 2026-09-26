local M = { id="JUMP_KICK", name="Jump Kick" }

-- Source-traced FireRed Move_JUMP_KICK. The attacker performs a short
-- horizontal lunge, then a wide foot sprite travels diagonally into the target
-- over 10 native frames. The hit splat and 7-frame target shake follow after
-- the foot finishes, with the native Jump Kick and Comet Punch SFX timings.
M.soundIds = {136,132}

M.script = {
  { op="loadspritegfx", tag=10143 }, -- ANIM_TAG_HANDS_AND_FEET
  { op="loadspritegfx", tag=10135 }, -- ANIM_TAG_IMPACT
  { op="monbg", battler="def_partner" },
  { op="setalpha", eva=12, evb=8 },
  { op="createsprite", template="gHorizontalLungeSpriteTemplate", anchor="attacker", priority=2,
    args={4,4} },
  { op="delay", frames=3 },
  { op="createsprite", template="gJumpKickSpriteTemplate", anchor="attacker", priority=2,
    args={-16,8,0,0,10,"target",1,1} },
  { op="playsewithpan", sound=136, pan="target" }, -- SE_M_JUMP_KICK
  { op="waitforvisualfinish" },
  { op="createsprite", template="gBasicHitSplatSpriteTemplate", anchor="attacker", priority=1,
    args={0,0,"target",1} },
  { op="createvisualtask", task="AnimTask_ShakeMon", priority=5,
    args={"target",5,0,7,1} },
  { op="playsewithpan", sound=132, pan="target" }, -- SE_M_COMET_PUNCH
  { op="waitforvisualfinish" },
  { op="clearmonbg", battler="def_partner" },
  { op="blendoff" },
  { op="end" },
}

M.templates = {
  gHorizontalLungeSpriteTemplate = {
    controller=true, callback="DoHorizontalLunge",
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
