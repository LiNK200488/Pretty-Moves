local M = { id="HORN_DRILL", name="Horn Drill" }

-- FireRed Move_HORN_DRILL. The dedicated drill background scrolls diagonally
-- while the attacker uses the shared BowMon wind-up. A horn sprite reaches
-- the target, SE_BANG marks the drill contact, both battlers shake for 40
-- frames, and eleven flashing impact splats step across/around the target at
-- four-frame intervals before the attacker restores upright.
M.script = {
  { op="loadspritegfx", tag=10135 }, -- ANIM_TAG_IMPACT
  { op="loadspritegfx", tag=10020 }, -- ANIM_TAG_HORN_HIT
  { op="fadetobg", bg="drill" },
  { op="waitbgfadeout" },
  { op="createvisualtask", task="AnimTask_StartSlidingBg", priority=5,
    args={-2304,768,1,-1} },
  { op="waitbgfadein" },
  { op="setalpha", eva=12, evb=8 },
  { op="createsprite", template="gBowMonSpriteTemplate", anchor="attacker", priority=2, args={0} },
  { op="playsewithpan", sound=155, pan="attacker" }, -- SE_M_HEADBUTT
  { op="waitforvisualfinish" },
  { op="delay", frames=2 },
  { op="createsprite", template="gBowMonSpriteTemplate", anchor="attacker", priority=2, args={1} },
  { op="createsprite", template="gHornHitSpriteTemplate", anchor="target", priority=4, args={0,0,12} },
  { op="waitforvisualfinish" },
  { op="playsewithpan", sound=20, pan=0 }, -- SE_BANG (FireRed playse, centered)
  { op="createvisualtask", task="AnimTask_ShakeMonInPlace", priority=2,
    args={"attacker",2,0,40,1} },
  { op="createvisualtask", task="AnimTask_ShakeMonInPlace", priority=2,
    args={"target",10,0,40,1} },

  { op="createsprite", template="gFlashingHitSplatSpriteTemplate", anchor="target", priority=3,
    args={0,0,"target",3} },
  { op="playsewithpan", sound=159, pan="target" },
  { op="delay", frames=4 },
  { op="createsprite", template="gFlashingHitSplatSpriteTemplate", anchor="target", priority=3,
    args={0,2,"target",3} },
  { op="playsewithpan", sound=159, pan="target" },
  { op="delay", frames=4 },
  { op="createsprite", template="gFlashingHitSplatSpriteTemplate", anchor="target", priority=3,
    args={-4,3,"target",3} },
  { op="playsewithpan", sound=159, pan="target" },
  { op="delay", frames=4 },
  { op="createsprite", template="gFlashingHitSplatSpriteTemplate", anchor="target", priority=3,
    args={-8,-5,"target",3} },
  { op="playsewithpan", sound=159, pan="target" },
  { op="delay", frames=4 },
  { op="createsprite", template="gFlashingHitSplatSpriteTemplate", anchor="target", priority=3,
    args={4,-12,"target",3} },
  { op="playsewithpan", sound=159, pan="target" },
  { op="delay", frames=4 },
  { op="createsprite", template="gFlashingHitSplatSpriteTemplate", anchor="target", priority=3,
    args={16,0,"target",3} },
  { op="playsewithpan", sound=159, pan="target" },
  { op="delay", frames=4 },
  { op="createsprite", template="gFlashingHitSplatSpriteTemplate", anchor="target", priority=3,
    args={5,18,"target",3} },
  { op="playsewithpan", sound=159, pan="target" },
  { op="delay", frames=4 },
  { op="createsprite", template="gFlashingHitSplatSpriteTemplate", anchor="target", priority=3,
    args={-17,12,"target",2} },
  { op="playsewithpan", sound=159, pan="target" },
  { op="delay", frames=4 },
  { op="createsprite", template="gFlashingHitSplatSpriteTemplate", anchor="target", priority=3,
    args={-21,-15,"target",2} },
  { op="playsewithpan", sound=159, pan="target" },
  { op="delay", frames=4 },
  { op="createsprite", template="gFlashingHitSplatSpriteTemplate", anchor="target", priority=3,
    args={8,-27,"target",2} },
  { op="playsewithpan", sound=159, pan="target" },
  { op="delay", frames=4 },
  { op="createsprite", template="gFlashingHitSplatSpriteTemplate", anchor="target", priority=3,
    args={32,0,"target",2} },
  { op="playsewithpan", sound=159, pan="target" },
  { op="delay", frames=4 },

  { op="createsprite", template="gBowMonSpriteTemplate", anchor="attacker", priority=2, args={2} },
  { op="waitforvisualfinish" },
  { op="restorebg" },
  { op="waitbgfadeout" },
  { op="setarg", index=7, value=0xFFFF },
  { op="waitbgfadein" },
  { op="end" },
}

M.templates = {
  gHornHitSpriteTemplate = {
    tileTag=10020,paletteTag=10020,callback="AnimHornHit",
    oam={affine=false,objMode="normal",bpp=4,width=32,height=32},
    anim={kind="once",frames={{tileOffset=0,duration=1}}},
  },
  gFlashingHitSplatSpriteTemplate = {
    tileTag=10135,paletteTag=10135,callback="AnimFlashingHitSplat",
    oam={affine=true,objMode="normal",bpp=4,width=32,height=32},
    anim={kind="dummy",frames={{tileOffset=0,duration=1}}},
  },
}

return M
