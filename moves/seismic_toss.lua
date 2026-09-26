local M = { id="SEISMIC_TOSS", name="Seismic Toss" }

-- FireRed Move_SEISMIC_TOSS. The original selects weak/medium/strong rock
-- scatter density from gAnimMoveDmg. Gen1Recomp does not expose that transient
-- FireRed damage value to the animation bridge, so use the canonical medium
-- sequence (the 33..65 damage branch) while preserving the native in-air BG,
-- scroll, impact timing, rocks, shake and SFX.
M.soundIds = {231,145,124}

M.script = {
  { op="loadspritegfx", tag=10135 }, -- ANIM_TAG_IMPACT
  { op="loadspritegfx", tag=10058 }, -- ANIM_TAG_ROCKS
  { op="monbg", battler="def_partner" },
  { op="setalpha", eva=12, evb=8 },
  { op="waitforvisualfinish" },
  { op="fadetobg", bg="in_air" },
  { op="waitbgfadeout" },
  { op="createvisualtask", task="AnimTask_MoveSeismicTossBg", priority=3, args={} },
  { op="playsewithpan", sound=231, pan=0 }, -- SE_M_SKY_UPPERCUT
  { op="waitbgfadein" },
  { op="waitforvisualfinish" },
  { op="createvisualtask", task="AnimTask_SeismicTossBgAccelerateDownAtEnd", priority=3, args={} },

  -- FireRed SeismicTossMedium.
  { op="createsprite", template="gBasicHitSplatSpriteTemplate", anchor="target", priority=3,
    args={-10,-8,"target",1} },
  { op="playsewithpan", sound=145, pan="target" }, -- SE_M_STRENGTH
  { op="createvisualtask", task="AnimTask_ShakeMon", priority=2, args={"target",0,3,5,1} },
  { op="createsprite", template="gRockScatterSpriteTemplate", anchor="target", priority=2, args={-12,27,2,3} },
  { op="createsprite", template="gRockScatterSpriteTemplate", anchor="target", priority=2, args={8,28,3,4} },
  { op="createsprite", template="gRockScatterSpriteTemplate", anchor="target", priority=2, args={-4,30,2,3} },
  { op="createsprite", template="gRockScatterSpriteTemplate", anchor="target", priority=2, args={12,25,4,4} },
  { op="delay", frames=14 },

  { op="createsprite", template="gBasicHitSplatSpriteTemplate", anchor="target", priority=3,
    args={10,-8,"target",1} },
  { op="playsewithpan", sound=124, pan="target" }, -- SE_M_ROCK_THROW
  { op="createvisualtask", task="AnimTask_ShakeMon", priority=2, args={"target",0,3,5,1} },
  { op="createsprite", template="gRockScatterSpriteTemplate", anchor="target", priority=2, args={-12,32,3,4} },
  { op="createsprite", template="gRockScatterSpriteTemplate", anchor="target", priority=2, args={8,31,2,2} },
  { op="createsprite", template="gRockScatterSpriteTemplate", anchor="target", priority=2, args={-4,28,2,3} },
  { op="createsprite", template="gRockScatterSpriteTemplate", anchor="target", priority=2, args={12,30,4,3} },
  { op="delay", frames=14 },

  { op="createsprite", template="gBasicHitSplatSpriteTemplate", anchor="target", priority=3,
    args={-10,-8,"target",1} },
  { op="playsewithpan", sound=145, pan="target" },
  { op="createvisualtask", task="AnimTask_ShakeMon", priority=2, args={"target",0,3,5,1} },
  { op="createsprite", template="gRockScatterSpriteTemplate", anchor="target", priority=2, args={-12,27,2,3} },
  { op="createsprite", template="gRockScatterSpriteTemplate", anchor="target", priority=2, args={8,28,3,4} },
  { op="createsprite", template="gRockScatterSpriteTemplate", anchor="target", priority=2, args={-4,30,2,3} },
  { op="createsprite", template="gRockScatterSpriteTemplate", anchor="target", priority=2, args={12,25,4,4} },

  { op="restorebg" },
  { op="waitbgfadeout" },
  { op="setarg", index=7, value=0xFFF },
  { op="waitbgfadein" },
  { op="clearmonbg", battler="def_partner" },
  { op="blendoff" },
  { op="end" },
}

M.templates = {
  gBasicHitSplatSpriteTemplate = {
    tileTag=10135,paletteTag=10135,callback="AnimHitSplatBasic",
    oam={affine=true,objMode="blend",bpp=4,width=32,height=32},
    anim={kind="dummy",frames={{tileOffset=0,duration=1}}},
  },
  gRockScatterSpriteTemplate = {
    tileTag=10058,paletteTag=10058,callback="AnimRockScatter",
    oam={affine=true,objMode="normal",bpp=4,width=32,height=32},
    anim={kind="dummy",frames={{tileOffset=0,duration=1}}},
    extraTileOffsets={16,32,48,64,80},
  },
}
return M
