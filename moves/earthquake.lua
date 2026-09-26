local M = { id="EARTHQUAKE", name="Earthquake" }

-- Source-traced FireRed Move_EARTHQUAKE. FireRed shakes both the terrain and
-- all visible battlers with the same decaying horizontal task, then applies
-- two alternating black/white background palette pulses while the quake SFX
-- is playing.
M.soundIds = {227}

M.script = {
  { op="createvisualtask", task="AnimTask_HorizontalShake", priority=5, args={"terrain",10,50} },
  { op="createvisualtask", task="AnimTask_HorizontalShake", priority=5, args={"all_battlers",10,50} },
  { op="playsewithpan", sound=227, pan=0 }, -- SE_M_EARTHQUAKE
  { op="delay", frames=10 },
  { op="createsprite", template="gComplexPaletteBlendSpriteTemplate", anchor="attacker", priority=2,
    args={"bg",3,1,"black",14,"white",14} },
  { op="delay", frames=16 },
  { op="createsprite", template="gComplexPaletteBlendSpriteTemplate", anchor="attacker", priority=2,
    args={"bg",3,1,"black",14,"white",14} },
  { op="end" },
}

M.templates = {
  gComplexPaletteBlendSpriteTemplate = {
    controller=true, callback="AnimComplexPaletteBlend",
    oam={affine=false,objMode="normal",bpp=4,width=8,height=8},
    anim={kind="dummy",frames={{tileOffset=0,duration=1}}},
  },
}

return M
