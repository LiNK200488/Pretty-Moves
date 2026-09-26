local M = { id="BONEMERANG", name="Bonemerang" }

-- Source-traced FireRed Move_BONEMERANG. A spinning bone arcs from attacker
-- to target, turns around at impact, then returns to the attacker on a mirrored
-- arc. The attacker lunges as the returning bone reaches home.
M.script = {
  { op="loadspritegfx", tag=10000 }, -- ANIM_TAG_BONE
  { op="loadspritegfx", tag=10135 }, -- ANIM_TAG_IMPACT
  { op="monbg", battler="def_partner" },
  { op="splitbgprio", battler="target" },
  { op="setalpha", eva=12, evb=8 },
  { op="playsewithpan", sound=180, pan="attacker" }, -- SE_M_BONEMERANG
  { op="createsprite", template="gBonemerangSpriteTemplate", anchor="attacker", priority=2, args={} },
  { op="delay", frames=20 },
  { op="playsewithpan", sound=159, pan="target" }, -- SE_M_HORN_ATTACK
  { op="createsprite", template="gBasicHitSplatSpriteTemplate", anchor="attacker", priority=2,
    args={0,0,"target",1} },
  { op="createvisualtask", task="AnimTask_ShakeMon", priority=5, args={"target",5,0,5,1} },
  { op="delay", frames=17 },
  { op="playsewithpan", sound=206, pan="attacker" }, -- SE_M_VITAL_THROW
  { op="createsprite", template="gHorizontalLungeSpriteTemplate", anchor="attacker", priority=2, args={6,-4} },
  { op="waitforvisualfinish" },
  { op="clearmonbg", battler="def_partner" },
  { op="blendoff" },
  { op="end" },
}

M.templates = {
  gBonemerangSpriteTemplate = {
    tileTag=10000,paletteTag=10000,callback="AnimBonemerangProjectile",
    oam={affine=true,objMode="normal",bpp=4,width=32,height=32},
    anim={kind="dummy",frames={{tileOffset=0,duration=1}}},
  },
  gBasicHitSplatSpriteTemplate = {
    tileTag=10135,paletteTag=10135,callback="AnimHitSplatBasic",
    oam={affine=true,objMode="blend",bpp=4,width=32,height=32},
    anim={kind="dummy",frames={{tileOffset=0,duration=1}}},
  },
  gHorizontalLungeSpriteTemplate = {
    controller=true, callback="DoHorizontalLunge",
    oam={affine=false,objMode="normal",bpp=4,width=8,height=8},
    anim={kind="dummy",frames={}},
  },
}

return M
