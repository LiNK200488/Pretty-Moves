local M = { id="CUT", name="Cut" }

-- FireRed Move_CUT. gCuttingSliceSpriteTemplate is a four-frame 32x32 CUT
-- sprite driven by AnimCuttingSlice. It begins at target+(40,-32), sweeps
-- diagonally across the target, and overlaps the native target shake.
M.script = {
  { op="loadspritegfx", tag=10138 }, -- ANIM_TAG_CUT
  { op="monbg", battler="target" },
  { op="setalpha", eva=12, evb=8 },
  { op="playsewithpan", sound=121, pan="target" }, -- SE_M_CUT
  { op="createsprite", template="gCuttingSliceSpriteTemplate", anchor="attacker", priority=2,
    args={40,-32,0} },
  { op="delay", frames=5 },
  { op="createvisualtask", task="AnimTask_ShakeMon", priority=2,
    args={"target",0,3,10,1} },
  { op="waitforvisualfinish" },
  { op="clearmonbg", battler="target" },
  { op="blendoff" },
  { op="waitforvisualfinish" },
  { op="end" },
}

M.templates = {
  gCuttingSliceSpriteTemplate = {
    tileTag=10138,paletteTag=10138,callback="AnimCuttingSlice",
    oam={affine=false,objMode="blend",bpp=4,width=32,height=32},
    anim={kind="once",frames={
      {tileOffset=0,duration=5},{tileOffset=16,duration=5},
      {tileOffset=32,duration=5},{tileOffset=48,duration=5},
    }},
  },
}

return M
