local M = { id="BONE_CLUB", name="Bone Club" }

-- Source-traced FireRed Move_BONE_CLUB. A spinning bone approaches the
-- target from upper-left, then impact + shake + black palette pulse coincide.
M.script = {
  { op="loadspritegfx", tag=10000 }, -- ANIM_TAG_BONE
  { op="loadspritegfx", tag=10135 }, -- ANIM_TAG_IMPACT
  { op="monbg", battler="def_partner" },
  { op="splitbgprio", battler="target" },
  { op="setalpha", eva=12, evb=8 },
  { op="playsewithpan", sound=180, pan="target" }, -- SE_M_BONEMERANG
  { op="createsprite", template="gSpinningBoneSpriteTemplate", anchor="attacker", priority=2,
    args={-42,-25,0,0,15} },
  { op="delay", frames=12 },
  { op="createsprite", template="gBasicHitSplatSpriteTemplate", anchor="attacker", priority=2,
    args={0,0,"target",1} },
  { op="createvisualtask", task="AnimTask_ShakeMon", priority=5, args={"target",0,5,5,1} },
  { op="createsprite", template="gComplexPaletteBlendSpriteTemplate", anchor="attacker", priority=2,
    args={"all_and_bg",5,1,"black",10,"black",0} },
  { op="playsewithpan", sound=207, pan="target" }, -- SE_M_VITAL_THROW2
  { op="waitforvisualfinish" },
  { op="clearmonbg", battler="def_partner" },
  { op="blendoff" },
  { op="end" },
}

M.templates = {
  gSpinningBoneSpriteTemplate = {
    tileTag=10000,paletteTag=10000,callback="AnimBoneHitProjectile",
    oam={affine=true,objMode="normal",bpp=4,width=32,height=32},
    anim={kind="dummy",frames={{tileOffset=0,duration=1}}},
  },
  gBasicHitSplatSpriteTemplate = {
    tileTag=10135,paletteTag=10135,callback="AnimHitSplatBasic",
    oam={affine=true,objMode="blend",bpp=4,width=32,height=32},
    anim={kind="dummy",frames={{tileOffset=0,duration=1}}},
  },
  gComplexPaletteBlendSpriteTemplate = {
    controller=true, callback="AnimComplexPaletteBlend",
    oam={affine=false,objMode="normal",bpp=4,width=8,height=8},
    anim={kind="dummy",frames={{tileOffset=0,duration=1}}},
  },
}

return M
