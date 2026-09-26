local M = { id="GLARE", name="Glare" }

-- Source-faithful Pokemon FireRed Move_GLARE.
M.soundIds = {193,185}

M.script = {
  { op="loadspritegfx", tag=10248 }, -- ANIM_TAG_SMALL_RED_EYE
  { op="loadspritegfx", tag=10218 }, -- ANIM_TAG_EYE_SPARKLE
  { op="createvisualtask", task="AnimTask_GlareEyeDots", priority=5, args={0} },
  { op="playsewithpan", sound=193, pan="attacker" }, -- SE_M_PSYBEAM2
  { op="waitforvisualfinish" },
  { op="createvisualtask", task="AnimTask_BlendBattleAnimPal", priority=5,
    args={"bg",0,0,16,"black"} },
  { op="waitforvisualfinish" },
  { op="createsprite", template="gEyeSparkleSpriteTemplate", anchor="attacker", priority=0,
    args={-16,-8} },
  { op="createsprite", template="gEyeSparkleSpriteTemplate", anchor="attacker", priority=0,
    args={16,-8} },
  { op="createvisualtask", task="AnimTask_ScaryFace", priority=5, args={} },
  { op="playsewithpan", sound=185, pan="attacker" }, -- SE_M_LEER
  { op="delay", frames=2 },
  { op="createvisualtask", task="AnimTask_ShakeTargetInPattern", priority=3,
    args={20,1,false,0} },
  { op="waitforvisualfinish" },
  { op="createvisualtask", task="AnimTask_BlendBattleAnimPal", priority=5,
    args={"bg",0,16,0,"black"} },
  { op="end" },
}

M.templates = {
  -- This template is registered so the shared ROM sprite cache prepares the
  -- task-created 8x8 dots. AnimTask_GlareEyeDots emits the actual instances.
  gGlareEyeDotSpriteTemplate = {
    tileTag=10248,paletteTag=10248,callback="SpriteCallbackDummy",deferredPrepare=true,
    oam={affine=false,objMode="normal",bpp=4,width=8,height=8},
    anim={kind="dummy",frames={{tileOffset=0,duration=1}}},
  },
  gEyeSparkleSpriteTemplate = {
    tileTag=10218,paletteTag=10218,callback="AnimEyeSparkle",deferredPrepare=true,
    oam={affine=false,objMode="normal",bpp=4,width=16,height=16},
    anim={kind="once",frames={
      {tileOffset=0,duration=4},{tileOffset=4,duration=4},{tileOffset=8,duration=4},
      {tileOffset=4,duration=4},{tileOffset=0,duration=4},
    }},
  },
}

return M
