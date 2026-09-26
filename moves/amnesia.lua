local M = { id="AMNESIA", name="Amnesia" }

M.soundIds = {179} -- SE_M_METRONOME

-- FireRed Move_AMNESIA. SetPsychicBackground is expanded inline using the
-- same proven path as Psychic/Psybeam/Hypnosis. The question mark uses the
-- native Amnesia sheet and the source callback's size-aware attacker anchor.
M.script = {
  { op="loadspritegfx", tag=10093 }, -- ANIM_TAG_AMNESIA
  { op="fadetobg", bg="psychic" },
  { op="waitbgfadeout" },
  { op="createvisualtask", task="AnimTask_SetPsychicBackground", priority=5 },
  { op="waitbgfadein" },
  { op="delay", frames=8 },
  { op="createsprite", template="gQuestionMarkSpriteTemplate", anchor="attacker", priority=20, args={} },
  { op="playsewithpan", sound=179, pan="attacker" },
  { op="delay", frames=54 },
  { op="loopsewithpan", sound=179, pan="attacker", interval=16, count=3 },
  { op="waitforvisualfinish" },
  { op="restorebg" },
  { op="waitbgfadeout" },
  { op="setarg", index=7, value=0xFFFF },
  { op="waitbgfadein" },
  { op="end" },
}

M.templates = {
  gQuestionMarkSpriteTemplate = {
    tileTag=10093,paletteTag=10093,callback="AnimQuestionMark",
    oam={affine=true,objMode="normal",bpp=4,width=32,height=32},
    anim={kind="once",frames={
      {tileOffset=0,duration=6},
      {tileOffset=16,duration=6},
      {tileOffset=32,duration=6},
      {tileOffset=48,duration=6},
      {tileOffset=64,duration=6},
      {tileOffset=80,duration=6},
      {tileOffset=96,duration=18},
    }},
  },
}

return M
