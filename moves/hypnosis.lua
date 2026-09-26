local M = { id="HYPNOSIS", name="Hypnosis" }

M.soundIds = {177}

-- FireRed Move_HYPNOSIS.
-- Reuses the shared Psychic background/palette rotation and Gold Ring sprite.
M.script = {
  { op="loadspritegfx", tag=10163 }, -- ANIM_TAG_GOLD_RING
  { op="fadetobg", bg="psychic" },
  { op="waitbgfadeout" },
  { op="createvisualtask", task="AnimTask_SetPsychicBackground", priority=5 },
  { op="waitbgfadein" },

  -- HypnosisRings x3: two rings per burst, one SFX per burst, 6f spacing.
  { op="playsewithpan", sound=177, pan="attacker" },
  { op="createsprite", template="gGoldRingSpriteTemplate", anchor="target", priority=2, args={0,8,0,8,27,0} },
  { op="createsprite", template="gGoldRingSpriteTemplate", anchor="target", priority=2, args={16,-8,0,-8,27,0} },
  { op="delay", frames=6 },

  { op="playsewithpan", sound=177, pan="attacker" },
  { op="createsprite", template="gGoldRingSpriteTemplate", anchor="target", priority=2, args={0,8,0,8,27,0} },
  { op="createsprite", template="gGoldRingSpriteTemplate", anchor="target", priority=2, args={16,-8,0,-8,27,0} },
  { op="delay", frames=6 },

  { op="playsewithpan", sound=177, pan="attacker" },
  { op="createsprite", template="gGoldRingSpriteTemplate", anchor="target", priority=2, args={0,8,0,8,27,0} },
  { op="createsprite", template="gGoldRingSpriteTemplate", anchor="target", priority=2, args={16,-8,0,-8,27,0} },
  { op="delay", frames=6 },

  { op="createvisualtask", task="AnimTask_BlendColorCycle", priority=2, args={"target",2,2,0,12,{31,18,31}} },
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
