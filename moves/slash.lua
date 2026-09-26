local M = { id="SLASH", name="Slash" }

-- FireRed Move_SLASH. Two four-frame Slash slices are placed on opposite
-- horizontal sides of the target four frames apart, each with the native
-- Razor Wind contact SFX. The second slice overlaps the native 4 px shake.
M.script = {
  { op="loadspritegfx", tag=10183 }, -- ANIM_TAG_SLASH
  { op="createsprite", template="gSlashSliceSpriteTemplate", anchor="target", priority=2,
    args={-8,0,"target"} },
  { op="playsewithpan", sound=129, pan="target" }, -- SE_M_RAZOR_WIND
  { op="delay", frames=4 },
  { op="createsprite", template="gSlashSliceSpriteTemplate", anchor="target", priority=2,
    args={8,0,"target"} },
  { op="createvisualtask", task="AnimTask_ShakeMon2", priority=2,
    args={"target",4,0,18,1} },
  { op="playsewithpan", sound=129, pan="target" }, -- SE_M_RAZOR_WIND
  { op="waitforvisualfinish" },
  { op="end" },
}

M.templates = {
  gSlashSliceSpriteTemplate = {
    tileTag=10183,paletteTag=10183,callback="AnimSpriteOnMonPos",
    oam={affine=false,objMode="normal",bpp=4,width=32,height=32},
    anim={kind="once",frames={
      {tileOffset=0,duration=4},
      {tileOffset=16,duration=4},
      {tileOffset=32,duration=4},
      {tileOffset=48,duration=4},
    }},
  },
}

return M
