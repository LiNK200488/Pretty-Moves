local M = { id="SUPER_FANG", name="Super Fang" }

-- FireRed Move_SUPER_FANG, source-faithful choreography.
M.soundIds = {154,164}

M.script = {
  { op="loadspritegfx", tag=10192 }, -- ANIM_TAG_FANG_ATTACK
  { op="createvisualtask", task="AnimTask_ShakeMonInPlace", priority=2,
    args={"attacker",1,0,20,1} },
  { op="playsewithpan", sound=164, pan="attacker" }, -- SE_M_DRAGON_RAGE
  { op="waitforvisualfinish" },

  { op="createvisualtask", task="AnimTask_ShakeMonInPlace", priority=2,
    args={"attacker",3,0,48,1} },
  { op="createvisualtask", task="AnimTask_BlendMonInAndOut", priority=2,
    args={"attacker",{31,6,1},12,4,1} },
  { op="waitforvisualfinish" },
  { op="delay", frames=20 },

  { op="createsprite", template="gHorizontalLungeSpriteTemplate", anchor="attacker", priority=2,
    args={4,4} },
  { op="delay", frames=4 },
  { op="createsprite", template="gSuperFangSpriteTemplate", anchor="target", priority=2, args={} },
  { op="playsewithpan", sound=154, pan="target" }, -- SE_M_BITE
  { op="delay", frames=8 },
  { op="createsprite", template="gComplexPaletteBlendSpriteTemplate", anchor="attacker", priority=2,
    args={"bg",3,1,{31,2,2},14,"white",14} },
  { op="createvisualtask", task="AnimTask_ShakeMon", priority=2,
    args={"target",0,7,12,1} },
  { op="waitforvisualfinish" },
  { op="blendoff" },
  { op="end" },
}

M.templates = {
  gHorizontalLungeSpriteTemplate = {
    controller=true, callback="DoHorizontalLunge",
    oam={affine=false,objMode="normal",bpp=4,width=8,height=8},
    anim={kind="dummy",frames={}},
  },
  gSuperFangSpriteTemplate = {
    tileTag=10192, paletteTag=10192, callback="AnimSuperFang",
    oam={affine=false,objMode="normal",bpp=4,width=32,height=32},
    anim={kind="once",frames={
      {tileOffset=0,duration=2},
      {tileOffset=16,duration=2},
      {tileOffset=32,duration=2},
      {tileOffset=48,duration=2},
    }},
  },
  gComplexPaletteBlendSpriteTemplate = {
    controller=true, callback="AnimComplexPaletteBlend",
    oam={affine=false,objMode="normal",bpp=4,width=8,height=8},
    anim={kind="dummy",frames={{tileOffset=0,duration=1}}},
  },
}

return M
