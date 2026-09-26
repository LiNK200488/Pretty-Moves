local M = { id="THUNDER", name="Thunder" }

-- FireRed Move_THUNDER.
M.script = {
  { op="loadspritegfx", tag=10037 }, -- ANIM_TAG_LIGHTNING
  { op="fadetobg", bg="thunder" },
  { op="waitbgfadeout" },
  { op="createvisualtask", task="AnimTask_StartSlidingBg", priority=5, args={-256,0,1,-1} },
  { op="waitbgfadein" },

  { op="createvisualtask", task="AnimTask_BlendBattleAnimPal", priority=2,
    args={"bg",2,0,16,"black"} },
  { op="delay", frames=16 },

  { op="createvisualtask", task="AnimTask_InvertScreenColor", priority=2, args={257,257,257} },
  { op="playsewithpan", sound=131, pan="target" },
  { op="delay", frames=1 },
  { op="createsprite", template="gLightningSpriteTemplate", anchor="target", priority=2, args={16,-36} },
  { op="delay", frames=1 },
  { op="createsprite", template="gLightningSpriteTemplate", anchor="target", priority=2, args={16,-20} },
  { op="delay", frames=1 },
  { op="createsprite", template="gLightningSpriteTemplate", anchor="target", priority=2, args={16,12} },

  { op="delay", frames=20 },
  { op="createsprite", template="gLightningSpriteTemplate", anchor="target", priority=6, args={-16,-32} },
  { op="playsewithpan", sound=131, pan="target" },
  { op="delay", frames=1 },
  { op="createsprite", template="gLightningSpriteTemplate", anchor="target", priority=6, args={-16,-16} },
  { op="delay", frames=1 },
  { op="createsprite", template="gLightningSpriteTemplate", anchor="target", priority=6, args={-16,16} },
  { op="playsewithpan", sound=131, pan="target" },

  { op="delay", frames=5 },
  { op="createvisualtask", task="AnimTask_InvertScreenColor", priority=2, args={257,257,257} },
  { op="delay", frames=1 },
  { op="createsprite", template="gLightningSpriteTemplate", anchor="target", priority=2, args={24,-32} },
  { op="delay", frames=1 },
  { op="createsprite", template="gLightningSpriteTemplate", anchor="target", priority=2, args={24,-16} },
  { op="delay", frames=1 },
  { op="createsprite", template="gLightningSpriteTemplate", anchor="target", priority=2, args={24,16} },

  { op="delay", frames=30 },
  { op="createvisualtask", task="AnimTask_InvertScreenColor", priority=2, args={257,257,257} },
  { op="delay", frames=5 },
  { op="createvisualtask", task="AnimTask_InvertScreenColor", priority=2, args={257,257,257} },
  { op="delay", frames=1 },

  { op="createsprite", template="gLightningSpriteTemplate", anchor="target", priority=2, args={0,-32} },
  { op="playsewithpan", sound=214, pan="target" }, -- SE_M_TRI_ATTACK2
  { op="delay", frames=1 },
  { op="createsprite", template="gLightningSpriteTemplate", anchor="target", priority=2, args={0,-16} },
  { op="delay", frames=1 },
  { op="createsprite", template="gLightningSpriteTemplate", anchor="target", priority=2, args={0,16} },

  { op="delay", frames=10 },
  { op="createvisualtask", task="AnimTask_InvertScreenColor", priority=2, args={257,257,257} },
  { op="delay", frames=1 },
  { op="createvisualtask", task="AnimTask_ShakeTargetInPattern", priority=2, args={30,3,true,0} },
  { op="delay", frames=2 },
  { op="createvisualtask", task="AnimTask_InvertScreenColor", priority=2, args={257,257,257} },
  { op="delay", frames=1 },

  { op="createvisualtask", task="AnimTask_BlendBattleAnimPal", priority=2,
    args={"bg",2,16,0,"black"} },
  { op="waitforvisualfinish" },
  { op="restorebg" },
  { op="waitbgfadeout" },
  { op="setarg", index=7, value=0xFFFF },
  { op="waitbgfadein" },
  { op="end" },
}

M.templates = {
  gLightningSpriteTemplate = {
    tileTag=10037,paletteTag=10037,callback="AnimLightning",
    oam={width=32,height=32},
    anim={kind="once",frames={
      {tileOffset=0,duration=5},
      {tileOffset=16,duration=5},
      {tileOffset=32,duration=8},
      {tileOffset=48,duration=5},
      {tileOffset=64,duration=5},
    }},
    extraTileOffsets={16,32,48,64},
  },
}

return M
