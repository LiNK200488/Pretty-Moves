local M = { id="SCRATCH", name="Scratch" }

-- FireRed Move_SCRATCH choreography. This definition is data-only; the shared
-- visual/audio runtimes own ROM extraction, playback, caching, and battle glue.
M.script = {
  { op="loadspritegfx", tag=10137 }, -- ANIM_TAG_SCRATCH
  { op="monbg", battler="target" },
  { op="setalpha", eva=12, evb=8 },
  { op="playsewithpan", sound=148, pan="target" }, -- SE_M_SCRATCH
  { op="createsprite", template="gScratchSpriteTemplate", anchor="attacker", priority=2, args={0,0,1,0} },
  { op="createvisualtask", task="AnimTask_ShakeMon", priority=2, args={"target",3,0,6,1} },
  { op="waitforvisualfinish" },
  { op="clearmonbg", battler="target" },
  { op="blendoff" },
  { op="waitforvisualfinish" },
  { op="end" },
}

M.templates = {
  gScratchSpriteTemplate = {
    tileTag=10137,
    paletteTag=10137,
    callback="AnimSpriteOnMonPos",
    oam={affine=false,objMode="blend",bpp=4,width=32,height=32},
    -- FireRed sScratchAnimCmds: five 32x32 frames, four GBA frames each.
    anim={
      kind="once",
      frames={
        {tileOffset=0,duration=4},
        {tileOffset=16,duration=4},
        {tileOffset=32,duration=4},
        {tileOffset=48,duration=4},
        {tileOffset=64,duration=4},
      },
    },
  },
}

return M
