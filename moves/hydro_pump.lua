local M = { id="HYDRO_PUMP", name="Hydro Pump" }

M.soundIds = {157}

-- FireRed Move_HYDRO_PUMP. A dense stream of animated water orbs is emitted
-- from the attacker in paired sine waves while the attacker and defender shake.
-- Repeated water-hit splats land on the defender during the stream.
M.script = {
  { op="loadspritegfx", tag=10149 }, -- ANIM_TAG_WATER_ORB
  { op="loadspritegfx", tag=10148 }, -- ANIM_TAG_WATER_IMPACT
  { op="monbg", battler="def_partner" },
  { op="splitbgprio", battler="target" },
  { op="setalpha", eva=12, evb=8 },
  { op="createvisualtask", task="AnimTask_ShakeMon", priority=5, args={"attacker",0,2,40,1} },
  { op="delay", frames=6 },
  { op="panse", sound=157, from="attacker", to="target", increment=2, delay=0 }, -- SE_M_HYDRO_PUMP
  { op="createvisualtask", task="AnimTask_StartSinAnimTimer", priority=5, args={100} },

  -- HydroPumpBeams x3
  { op="createsprite", template="gHydroPumpOrbSpriteTemplate", anchor="attacker", priority=3, args={10,10,0,16} },
  { op="createsprite", template="gHydroPumpOrbSpriteTemplate", anchor="attacker", priority=3, args={10,10,0,-16} },
  { op="delay", frames=1 },
  { op="createsprite", template="gHydroPumpOrbSpriteTemplate", anchor="attacker", priority=3, args={10,10,0,16} },
  { op="createsprite", template="gHydroPumpOrbSpriteTemplate", anchor="attacker", priority=3, args={10,10,0,-16} },
  { op="delay", frames=1 },

  { op="createsprite", template="gHydroPumpOrbSpriteTemplate", anchor="attacker", priority=3, args={10,10,0,16} },
  { op="createsprite", template="gHydroPumpOrbSpriteTemplate", anchor="attacker", priority=3, args={10,10,0,-16} },
  { op="delay", frames=1 },
  { op="createsprite", template="gHydroPumpOrbSpriteTemplate", anchor="attacker", priority=3, args={10,10,0,16} },
  { op="createsprite", template="gHydroPumpOrbSpriteTemplate", anchor="attacker", priority=3, args={10,10,0,-16} },
  { op="delay", frames=1 },

  { op="createsprite", template="gHydroPumpOrbSpriteTemplate", anchor="attacker", priority=3, args={10,10,0,16} },
  { op="createsprite", template="gHydroPumpOrbSpriteTemplate", anchor="attacker", priority=3, args={10,10,0,-16} },
  { op="delay", frames=1 },
  { op="createsprite", template="gHydroPumpOrbSpriteTemplate", anchor="attacker", priority=3, args={10,10,0,16} },
  { op="createsprite", template="gHydroPumpOrbSpriteTemplate", anchor="attacker", priority=3, args={10,10,0,-16} },
  { op="delay", frames=1 },

  { op="createvisualtask", task="AnimTask_ShakeMon", priority=5, args={"target",3,0,37,1} },

  -- First impact pair.
  { op="createsprite", template="gWaterHitSplatSpriteTemplate", anchor="attacker", priority=4, args={0,15,"target",1} },
  { op="createsprite", template="gWaterHitSplatSpriteTemplate", anchor="attacker", priority=4, args={0,-15,"target",1} },

  -- Four cycles of two HydroPumpBeams calls followed by an impact pair.
  { op="createsprite", template="gHydroPumpOrbSpriteTemplate", anchor="attacker", priority=3, args={10,10,0,16} },
  { op="createsprite", template="gHydroPumpOrbSpriteTemplate", anchor="attacker", priority=3, args={10,10,0,-16} },
  { op="delay", frames=1 },
  { op="createsprite", template="gHydroPumpOrbSpriteTemplate", anchor="attacker", priority=3, args={10,10,0,16} },
  { op="createsprite", template="gHydroPumpOrbSpriteTemplate", anchor="attacker", priority=3, args={10,10,0,-16} },
  { op="delay", frames=1 },
  { op="createsprite", template="gHydroPumpOrbSpriteTemplate", anchor="attacker", priority=3, args={10,10,0,16} },
  { op="createsprite", template="gHydroPumpOrbSpriteTemplate", anchor="attacker", priority=3, args={10,10,0,-16} },
  { op="delay", frames=1 },
  { op="createsprite", template="gHydroPumpOrbSpriteTemplate", anchor="attacker", priority=3, args={10,10,0,16} },
  { op="createsprite", template="gHydroPumpOrbSpriteTemplate", anchor="attacker", priority=3, args={10,10,0,-16} },
  { op="delay", frames=1 },
  { op="createsprite", template="gWaterHitSplatSpriteTemplate", anchor="attacker", priority=4, args={0,15,"target",1} },
  { op="createsprite", template="gWaterHitSplatSpriteTemplate", anchor="attacker", priority=4, args={0,-15,"target",1} },

  { op="createsprite", template="gHydroPumpOrbSpriteTemplate", anchor="attacker", priority=3, args={10,10,0,16} },
  { op="createsprite", template="gHydroPumpOrbSpriteTemplate", anchor="attacker", priority=3, args={10,10,0,-16} },
  { op="delay", frames=1 },
  { op="createsprite", template="gHydroPumpOrbSpriteTemplate", anchor="attacker", priority=3, args={10,10,0,16} },
  { op="createsprite", template="gHydroPumpOrbSpriteTemplate", anchor="attacker", priority=3, args={10,10,0,-16} },
  { op="delay", frames=1 },
  { op="createsprite", template="gHydroPumpOrbSpriteTemplate", anchor="attacker", priority=3, args={10,10,0,16} },
  { op="createsprite", template="gHydroPumpOrbSpriteTemplate", anchor="attacker", priority=3, args={10,10,0,-16} },
  { op="delay", frames=1 },
  { op="createsprite", template="gHydroPumpOrbSpriteTemplate", anchor="attacker", priority=3, args={10,10,0,16} },
  { op="createsprite", template="gHydroPumpOrbSpriteTemplate", anchor="attacker", priority=3, args={10,10,0,-16} },
  { op="delay", frames=1 },
  { op="createsprite", template="gWaterHitSplatSpriteTemplate", anchor="attacker", priority=4, args={0,15,"target",1} },
  { op="createsprite", template="gWaterHitSplatSpriteTemplate", anchor="attacker", priority=4, args={0,-15,"target",1} },

  { op="createsprite", template="gHydroPumpOrbSpriteTemplate", anchor="attacker", priority=3, args={10,10,0,16} },
  { op="createsprite", template="gHydroPumpOrbSpriteTemplate", anchor="attacker", priority=3, args={10,10,0,-16} },
  { op="delay", frames=1 },
  { op="createsprite", template="gHydroPumpOrbSpriteTemplate", anchor="attacker", priority=3, args={10,10,0,16} },
  { op="createsprite", template="gHydroPumpOrbSpriteTemplate", anchor="attacker", priority=3, args={10,10,0,-16} },
  { op="delay", frames=1 },
  { op="createsprite", template="gHydroPumpOrbSpriteTemplate", anchor="attacker", priority=3, args={10,10,0,16} },
  { op="createsprite", template="gHydroPumpOrbSpriteTemplate", anchor="attacker", priority=3, args={10,10,0,-16} },
  { op="delay", frames=1 },
  { op="createsprite", template="gHydroPumpOrbSpriteTemplate", anchor="attacker", priority=3, args={10,10,0,16} },
  { op="createsprite", template="gHydroPumpOrbSpriteTemplate", anchor="attacker", priority=3, args={10,10,0,-16} },
  { op="delay", frames=1 },
  { op="createsprite", template="gWaterHitSplatSpriteTemplate", anchor="attacker", priority=4, args={0,15,"target",1} },
  { op="createsprite", template="gWaterHitSplatSpriteTemplate", anchor="attacker", priority=4, args={0,-15,"target",1} },

  { op="createsprite", template="gHydroPumpOrbSpriteTemplate", anchor="attacker", priority=3, args={10,10,0,16} },
  { op="createsprite", template="gHydroPumpOrbSpriteTemplate", anchor="attacker", priority=3, args={10,10,0,-16} },
  { op="delay", frames=1 },
  { op="createsprite", template="gHydroPumpOrbSpriteTemplate", anchor="attacker", priority=3, args={10,10,0,16} },
  { op="createsprite", template="gHydroPumpOrbSpriteTemplate", anchor="attacker", priority=3, args={10,10,0,-16} },
  { op="delay", frames=1 },
  { op="createsprite", template="gHydroPumpOrbSpriteTemplate", anchor="attacker", priority=3, args={10,10,0,16} },
  { op="createsprite", template="gHydroPumpOrbSpriteTemplate", anchor="attacker", priority=3, args={10,10,0,-16} },
  { op="delay", frames=1 },
  { op="createsprite", template="gHydroPumpOrbSpriteTemplate", anchor="attacker", priority=3, args={10,10,0,16} },
  { op="createsprite", template="gHydroPumpOrbSpriteTemplate", anchor="attacker", priority=3, args={10,10,0,-16} },
  { op="delay", frames=1 },
  { op="createsprite", template="gWaterHitSplatSpriteTemplate", anchor="attacker", priority=4, args={0,15,"target",1} },
  { op="createsprite", template="gWaterHitSplatSpriteTemplate", anchor="attacker", priority=4, args={0,-15,"target",1} },

  { op="delay", frames=1 },
  { op="delay", frames=1 },
  { op="createsprite", template="gWaterHitSplatSpriteTemplate", anchor="attacker", priority=4, args={0,15,"target",1} },
  { op="createsprite", template="gWaterHitSplatSpriteTemplate", anchor="attacker", priority=4, args={0,-15,"target",1} },

  { op="waitforvisualfinish" },
  { op="clearmonbg", battler="def_partner" },
  { op="blendoff" },
  { op="end" },
}

M.templates = {
  gHydroPumpOrbSpriteTemplate = {
    tileTag=10149,paletteTag=10149,callback="AnimToTargetInSinWave",
    oam={affine=false,objMode="blend",bpp=4,width=16,height=16},
    anim={kind="loop",frames={
      {tileOffset=0,duration=1},{tileOffset=4,duration=1},
      {tileOffset=8,duration=1},{tileOffset=12,duration=1},
    }},
  },
  gWaterHitSplatSpriteTemplate = {
    tileTag=10148,paletteTag=10148,callback="AnimHitSplatBasic",
    oam={affine=true,objMode="blend",bpp=4,width=32,height=32},
    anim={kind="dummy",frames={{tileOffset=0,duration=1}}},
  },
}

return M
