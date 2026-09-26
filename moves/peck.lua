local M = { id="PECK", name="Peck" }

M.soundIds = {159}

-- FireRed Move_PECK: play the horn-attack impact SFX, tilt the target for
-- three callbacks, restore over three callbacks, and flash one impact splat.
M.script = {
  { op="loadspritegfx", tag=10135 }, -- ANIM_TAG_IMPACT
  { op="playsewithpan", sound=159, pan="target" }, -- SE_M_HORN_ATTACK
  { op="createvisualtask", task="AnimTask_RotateMonToSideAndRestore", priority=2,
    args={3,-768,"target",2} },
  { op="createsprite", template="gFlashingHitSplatSpriteTemplate", anchor="target", priority=3,
    args={-12,0,"target",3} },
  { op="waitforvisualfinish" },
  { op="end" },
}

M.templates = {
  gFlashingHitSplatSpriteTemplate = {
    tileTag=10135,paletteTag=10135,callback="AnimFlashingHitSplat",
    oam={affine=true,objMode="normal",bpp=4,width=32,height=32},
    anim={kind="dummy",frames={{tileOffset=0,duration=1}}},
  },
}

return M
