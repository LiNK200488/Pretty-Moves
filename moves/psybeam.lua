local M = { id="PSYBEAM", name="Psybeam" }

M.soundIds = {182, 193}

-- FireRed Move_PSYBEAM rebuilt directly on the v0.47.0 runtime.
-- BG_PSYCHIC uses the same shared fadetobg/restorebg path as Confuse Ray.
M.script = {
  { op="loadspritegfx", tag=10163 }, -- ANIM_TAG_GOLD_RING
  { op="playsewithpan", sound=182, pan="attacker" },
  { op="fadetobg", bg="psychic" },
  { op="waitbgfadeout" },
  { op="createvisualtask", task="AnimTask_SetPsychicBackground", priority=5 },
  { op="waitbgfadein" },
  { op="createsoundtask", task="SoundTask_LoopSEAdjustPanning", priority=2, args={193,"attacker","target",3,4,0,15} },

  { op="createsprite", template="gGoldRingSpriteTemplate", anchor="target", priority=2, args={16,0,0,0,13,0} },
  { op="delay", frames=4 },
  { op="createsprite", template="gGoldRingSpriteTemplate", anchor="target", priority=2, args={16,0,0,0,13,0} },
  { op="delay", frames=4 },

  { op="createvisualtask", task="AnimTask_SwayMon", priority=5, args={0,6,2048,4,"target"} },
  { op="createvisualtask", task="AnimTask_BlendColorCycle", priority=2, args={"target",2,2,0,12,{31,18,31}} },

  { op="createsprite", template="gGoldRingSpriteTemplate", anchor="target", priority=2, args={16,0,0,0,13,0} },
  { op="delay", frames=4 },
  { op="createsprite", template="gGoldRingSpriteTemplate", anchor="target", priority=2, args={16,0,0,0,13,0} },
  { op="delay", frames=4 },
  { op="createsprite", template="gGoldRingSpriteTemplate", anchor="target", priority=2, args={16,0,0,0,13,0} },
  { op="delay", frames=4 },
  { op="createsprite", template="gGoldRingSpriteTemplate", anchor="target", priority=2, args={16,0,0,0,13,0} },
  { op="delay", frames=4 },
  { op="createsprite", template="gGoldRingSpriteTemplate", anchor="target", priority=2, args={16,0,0,0,13,0} },
  { op="delay", frames=4 },
  { op="createsprite", template="gGoldRingSpriteTemplate", anchor="target", priority=2, args={16,0,0,0,13,0} },
  { op="delay", frames=4 },
  { op="createsprite", template="gGoldRingSpriteTemplate", anchor="target", priority=2, args={16,0,0,0,13,0} },
  { op="delay", frames=4 },
  { op="createsprite", template="gGoldRingSpriteTemplate", anchor="target", priority=2, args={16,0,0,0,13,0} },
  { op="delay", frames=4 },
  { op="createsprite", template="gGoldRingSpriteTemplate", anchor="target", priority=2, args={16,0,0,0,13,0} },

  { op="waitforvisualfinish" },
  { op="delay", frames=1 },
  { op="restorebg" },
  { op="waitbgfadeout" },
  { op="setarg", index=7, value=0xFFFF },
  { op="waitbgfadein" },
  { op="end" },
}

M.templates = {
  gGoldRingSpriteTemplate = {
    tileTag=10163, paletteTag=10163, callback="TranslateAnimSpriteToTargetMonLocation",
    oam={affine=false,objMode="normal",bpp=4,width=16,height=32},
    anim={kind="dummy",frames={{tileOffset=0,duration=1}}},
  },
}

return M
