local M = { id="RAZOR_LEAF", name="Razor Leaf" }

-- FireRed Move_RAZOR_LEAF choreography, using the ROM-native leaf and
-- razor-leaf OBJ graphics. Positioning/scaling remains entirely shared.
M.script = {
  { op="loadspritegfx", tag=10063 }, -- ANIM_TAG_LEAF
  { op="loadspritegfx", tag=10160 }, -- ANIM_TAG_RAZOR_LEAF
  { op="loadspritegfx", tag=10135 }, -- ANIM_TAG_IMPACT
  { op="monbg", battler="def_partner" },
  { op="setalpha", eva=12, evb=8 },
  { op="delay", frames=1 },
  { op="loopsewithpan", sound=162, pan="attacker", interval=10, count=5 }, -- SE_M_POISON_POWDER
  { op="createsprite", template="gRazorLeafParticleSpriteTemplate", anchor="attacker", priority=2, args={-3,-2,10} },
  { op="delay", frames=2 },
  { op="createsprite", template="gRazorLeafParticleSpriteTemplate", anchor="attacker", priority=2, args={-1,-1,15} },
  { op="delay", frames=2 },
  { op="createsprite", template="gRazorLeafParticleSpriteTemplate", anchor="attacker", priority=2, args={-4,-4,7} },
  { op="delay", frames=2 },
  { op="createsprite", template="gRazorLeafParticleSpriteTemplate", anchor="attacker", priority=2, args={3,-3,11} },
  { op="delay", frames=2 },
  { op="createsprite", template="gRazorLeafParticleSpriteTemplate", anchor="attacker", priority=2, args={-1,-6,8} },
  { op="delay", frames=2 },
  { op="createsprite", template="gRazorLeafParticleSpriteTemplate", anchor="attacker", priority=2, args={2,-1,12} },
  { op="delay", frames=2 },
  { op="createsprite", template="gRazorLeafParticleSpriteTemplate", anchor="attacker", priority=2, args={-3,-4,13} },
  { op="delay", frames=2 },
  { op="createsprite", template="gRazorLeafParticleSpriteTemplate", anchor="attacker", priority=2, args={4,-5,7} },
  { op="delay", frames=2 },
  { op="createsprite", template="gRazorLeafParticleSpriteTemplate", anchor="attacker", priority=2, args={2,-6,11} },
  { op="delay", frames=2 },
  { op="createsprite", template="gRazorLeafParticleSpriteTemplate", anchor="attacker", priority=2, args={-3,-5,8} },
  { op="delay", frames=60 },
  { op="playsewithpan", sound=153, pan="attacker" }, -- SE_M_RAZOR_WIND2
  { op="createsprite", template="gRazorLeafCutterSpriteTemplate", anchor="target", priority=3, args={20,-10,20,0,22,20,1} },
  { op="createsprite", template="gRazorLeafCutterSpriteTemplate", anchor="target", priority=3, args={20,-10,20,0,22,-20,1} },
  { op="delay", frames=20 },
  { op="playsewithpan", sound=129, pan="target" }, -- SE_M_RAZOR_WIND
  { op="createvisualtask", task="AnimTask_ShakeMon2", priority=2, args={"target",2,0,8,1} },
  { op="createvisualtask", task="AnimTask_ShakeMon2", priority=2, args={"def_partner",2,0,8,1} },
  { op="waitforvisualfinish" },
  { op="clearmonbg", battler="def_partner" },
  { op="blendoff" },
  { op="end" },
}

M.templates = {
  gRazorLeafParticleSpriteTemplate = {
    tileTag=10063, paletteTag=10063, callback="AnimRazorLeafParticle",
    oam={affine=false,objMode="normal",bpp=4,width=16,height=16},
    -- FireRed's spinning leaf loop used by gRazorLeafParticleSpriteTemplate.
    anim={kind="loop",frames={
      {tileOffset=0,duration=5},{tileOffset=4,duration=5},{tileOffset=8,duration=5},
      {tileOffset=12,duration=5},{tileOffset=16,duration=5},{tileOffset=20,duration=5},
      {tileOffset=16,duration=5},{tileOffset=12,duration=5},{tileOffset=8,duration=5},
      {tileOffset=4,duration=5},
    }},
  },
  gRazorLeafCutterSpriteTemplate = {
    tileTag=10160, paletteTag=10160, callback="AnimTranslateLinearSingleSineWave",
    oam={affine=false,objMode="normal",bpp=4,width=32,height=16},
    -- FireRed rotates the same 32x16 cutter by H/V flipping every 3 frames.
    anim={kind="loop",frames={
      {tileOffset=0,duration=3},
      {tileOffset=0,duration=3,hFlip=true},
      {tileOffset=0,duration=3,hFlip=true,vFlip=true},
      {tileOffset=0,duration=3,vFlip=true},
    }},
  },
}

return M
