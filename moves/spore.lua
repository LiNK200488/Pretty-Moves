local M = { id="SPORE", name="Spore" }

-- Exact FireRed Move_SPORE choreography.
-- Three passes of three large spore particles orbit the target using
-- AnimSporeParticle, with the native Poison Powder SFX loop.
M.soundIds = {162}

M.script = {
  { op="loadspritegfx", tag=10158 }, -- ANIM_TAG_SPORE
  { op="monbg", battler="def_partner" },
  { op="setalpha", eva=12, evb=8 },
  { op="createvisualtask", task="AnimTask_SporeDoubleBattle", priority=2, args={} },
  { op="loopsewithpan", sound=162, pan="target", interval=16, count=11 }, -- SE_M_POISON_POWDER

  { op="createsprite", template="gSporeParticleSpriteTemplate", anchor="target", priority=2, args={0,-20,85,80,1} },
  { op="delay", frames=12 },
  { op="createsprite", template="gSporeParticleSpriteTemplate", anchor="target", priority=2, args={0,-10,170,80,1} },
  { op="delay", frames=12 },
  { op="createsprite", template="gSporeParticleSpriteTemplate", anchor="target", priority=2, args={0,-15,0,80,1} },
  { op="delay", frames=12 },

  { op="createsprite", template="gSporeParticleSpriteTemplate", anchor="target", priority=2, args={0,-20,85,80,1} },
  { op="delay", frames=12 },
  { op="createsprite", template="gSporeParticleSpriteTemplate", anchor="target", priority=2, args={0,-10,170,80,1} },
  { op="delay", frames=12 },
  { op="createsprite", template="gSporeParticleSpriteTemplate", anchor="target", priority=2, args={0,-15,0,80,1} },
  { op="delay", frames=12 },

  { op="createsprite", template="gSporeParticleSpriteTemplate", anchor="target", priority=2, args={0,-20,85,80,1} },
  { op="delay", frames=12 },
  { op="createsprite", template="gSporeParticleSpriteTemplate", anchor="target", priority=2, args={0,-10,170,80,1} },
  { op="delay", frames=12 },
  { op="createsprite", template="gSporeParticleSpriteTemplate", anchor="target", priority=2, args={0,-15,0,80,1} },
  { op="delay", frames=12 },

  { op="waitforvisualfinish" },
  { op="delay", frames=1 },
  { op="clearmonbg", battler="def_partner" },
  { op="blendoff" },
  { op="end" },
}

M.templates = {
  gSporeParticleSpriteTemplate = {
    tileTag=10158,paletteTag=10158,callback="AnimSporeParticle",
    oam={affine=false,objMode="normal",bpp=4,width=16,height=16},
    anim={kind="variants", variants={
      {frames={{tileOffset=0,duration=1}}},
      {frames={{tileOffset=4,duration=7}}},
    }},
  },
}

return M
