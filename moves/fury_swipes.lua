local M = { id="FURY_SWIPES", name="Fury Swipes" }

-- FireRed Move_FURY_SWIPES. Two claw swipes land on opposite sides of the
-- target, each preceded by the native 5x5 horizontal attacker lunge. The
-- first swipe is horizontally flipped; the second uses the normal facing and stronger native shake.
M.script = {
  { op="loadspritegfx", tag=10222 }, -- ANIM_TAG_SWIPE

  { op="createsprite", template="gHorizontalLungeSpriteTemplate", anchor="attacker", priority=2,
    args={5,5} },
  { op="delay", frames=4 },
  { op="playsewithpan", sound=148, pan="target" }, -- SE_M_SCRATCH
  { op="createsprite", template="gFurySwipesSpriteTemplateFlipped", anchor="target", priority=2,
    args={16,0,"target"} },
  { op="createvisualtask", task="AnimTask_ShakeMon2", priority=2,
    args={"target",3,0,5,1} },

  { op="delay", frames=10 },
  { op="createsprite", template="gHorizontalLungeSpriteTemplate", anchor="target", priority=2,
    args={5,5} },
  { op="delay", frames=4 },
  { op="playsewithpan", sound=148, pan="target" }, -- SE_M_SCRATCH
  { op="createsprite", template="gFurySwipesSpriteTemplate", anchor="target", priority=2,
    args={-16,0,"target"} },
  { op="createvisualtask", task="AnimTask_ShakeMon2", priority=2,
    args={"target",4,0,7,1} },
  { op="end" },
}

M.templates = {
  gHorizontalLungeSpriteTemplate = {
    controller=true, callback="DoHorizontalLunge",
    oam={affine=false,objMode="normal",bpp=4,width=8,height=8},
    anim={kind="dummy",frames={}},
  },
  gFurySwipesSpriteTemplate = {
    tileTag=10222,paletteTag=10222,callback="AnimSpriteOnMonPos",
    oam={affine=false,objMode="normal",bpp=4,width=32,height=32},
    anim={kind="once",frames={
      {tileOffset=0,duration=4},
      {tileOffset=16,duration=4},
      {tileOffset=32,duration=4},
      {tileOffset=48,duration=4},
    }},
  },
  gFurySwipesSpriteTemplateFlipped = {
    tileTag=10222,paletteTag=10222,callback="AnimSpriteOnMonPos",
    oam={affine=false,objMode="normal",bpp=4,width=32,height=32},
    anim={kind="once",frames={
      {tileOffset=0,duration=4,hFlip=true},
      {tileOffset=16,duration=4,hFlip=true},
      {tileOffset=32,duration=4,hFlip=true},
      {tileOffset=48,duration=4,hFlip=true},
    }},
  },
}

return M
