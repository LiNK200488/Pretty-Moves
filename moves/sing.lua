local M = { id="SING", name="Sing", quietBgm=true }

M.soundIds = {165}

-- FireRed Move_SING.
-- Twelve wavy notes travel from attacker to target while cycling through the
-- native four-palette rainbow set. FireRed marks Sing as a quiet-BGM move.
M.script = {
  { op="loadspritegfx", tag=10072 }, -- ANIM_TAG_MUSIC_NOTES
  { op="monbg", battler="def_partner" },
  { op="createvisualtask", task="AnimTask_MusicNotesRainbowBlend", priority=2 },
  { op="waitforvisualfinish" },
  { op="panse", sound=165, from="attacker", to="target", increment=2, delay=0 },

  { op="createsprite", template="gWavyMusicNotesSpriteTemplate", anchor="target", priority=2, args={7,0,12} },
  { op="delay", frames=5 },
  { op="createsprite", template="gWavyMusicNotesSpriteTemplate", anchor="target", priority=2, args={6,1,12} },
  { op="delay", frames=5 },
  { op="createsprite", template="gWavyMusicNotesSpriteTemplate", anchor="target", priority=2, args={1,2,12} },
  { op="delay", frames=5 },
  { op="createsprite", template="gWavyMusicNotesSpriteTemplate", anchor="target", priority=2, args={2,3,12} },
  { op="delay", frames=5 },
  { op="createsprite", template="gWavyMusicNotesSpriteTemplate", anchor="target", priority=2, args={3,0,12} },
  { op="delay", frames=4 },
  { op="createsprite", template="gWavyMusicNotesSpriteTemplate", anchor="target", priority=2, args={2,1,12} },
  { op="delay", frames=4 },
  { op="createsprite", template="gWavyMusicNotesSpriteTemplate", anchor="target", priority=2, args={5,2,12} },
  { op="delay", frames=4 },
  { op="createsprite", template="gWavyMusicNotesSpriteTemplate", anchor="target", priority=2, args={6,3,12} },
  { op="delay", frames=4 },
  { op="createsprite", template="gWavyMusicNotesSpriteTemplate", anchor="target", priority=2, args={2,0,12} },
  { op="delay", frames=4 },
  { op="createsprite", template="gWavyMusicNotesSpriteTemplate", anchor="target", priority=2, args={2,1,12} },
  { op="delay", frames=4 },
  { op="createsprite", template="gWavyMusicNotesSpriteTemplate", anchor="target", priority=2, args={1,2,12} },
  { op="delay", frames=4 },
  { op="createsprite", template="gWavyMusicNotesSpriteTemplate", anchor="target", priority=2, args={5,3,12} },
  { op="delay", frames=4 },

  { op="waitforvisualfinish" },
  { op="clearmonbg", battler="def_partner" },
  { op="createvisualtask", task="AnimTask_MusicNotesClearRainbowBlend", priority=2 },
  { op="waitforvisualfinish" },
  { op="end" },
}

M.templates = {
  gWavyMusicNotesSpriteTemplate = {
    tileTag=10072, paletteTag=10072, callback="AnimWavyMusicNotes",
    oam={affine=true,doubleSize=true,objMode="normal",bpp=4,width=16,height=16},
    -- FireRed has eight note animation variants at tile offsets 0,4,8,12,16,20
    -- (variants 6/7 vertically flip the first two). The callback selects one.
    anim={kind="dummy",frames={{tileOffset=0,duration=1}}},
    extraTileOffsets={4,8,12,16,20},
    -- AnimTask_MusicNotesRainbowBlend writes these exact BGR555 colors into
    -- four palettes. Palette entry 0 remains transparent.
    customPaletteVariants={
      {{31,31,31},{31,26,28},{31,22,26},{31,17,24},{31,13,22}},
      {{31,31,31},{25,31,26},{20,31,21},{15,31,16},{10,31,12}},
      {{31,31,31},{31,31,24},{31,31,17},{31,31,10},{31,31,3}},
      {{31,31,31},{26,28,31},{21,26,31},{16,24,31},{12,22,31}},
    },
  },
}

return M
