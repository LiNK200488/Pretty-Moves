local M = { id="FLAMETHROWER", name="Flamethrower" }

M.soundIds = {139}

-- FireRed Move_FLAMETHROWER / FlamethrowerCreateFlames.
-- Twenty-two animated flame sprites leave the attacker in a synchronized
-- sine wave, two frames apart, while the SE pans toward the target.
M.script = {
  { op="loadspritegfx", tag=10029 }, -- ANIM_TAG_SMALL_EMBER
  { op="monbg", target="def_partner" },
  { op="splitbgprio", target="target" },
  { op="setalpha", eva=12, evb=8 },
  { op="createvisualtask", task="AnimTask_ShakeMon", priority=5,
    args={"attacker",0,2,46,1} },
  { op="delay", frames=6 },
  { op="createvisualtask", task="AnimTask_StartSinAnimTimer", priority=5, args={100} },
  { op="panse", sound=139, from="attacker", to="target", increment=2, delay=0 },

  { op="call", label="FlamethrowerCreateFlames" },
  { op="call", label="FlamethrowerCreateFlames" },
  { op="call", label="FlamethrowerCreateFlames" },
  { op="createvisualtask", task="AnimTask_ShakeMon", priority=5,
    args={"target",3,0,43,1} },
  { op="call", label="FlamethrowerCreateFlames" },
  { op="call", label="FlamethrowerCreateFlames" },
  { op="call", label="FlamethrowerCreateFlames" },
  { op="call", label="FlamethrowerCreateFlames" },
  { op="call", label="FlamethrowerCreateFlames" },
  { op="call", label="FlamethrowerCreateFlames" },
  { op="call", label="FlamethrowerCreateFlames" },
  { op="call", label="FlamethrowerCreateFlames" },

  { op="waitforvisualfinish" },
  { op="clearmonbg", target="def_partner" },
  { op="blendoff" },
  { op="end" },
}

M.labels = {
  FlamethrowerCreateFlames = {
    { op="createsprite", template="gFlamethrowerFlameSpriteTemplate", anchor="attacker", priority=3,
      args={10,10,0,16} },
    { op="delay", frames=2 },
    { op="createsprite", template="gFlamethrowerFlameSpriteTemplate", anchor="attacker", priority=3,
      args={10,10,0,16} },
    { op="delay", frames=2 },
    { op="return" },
  },
}

M.templates = {
  gFlamethrowerFlameSpriteTemplate = {
    tileTag=10029,
    paletteTag=10029,
    callback="AnimToTargetInSinWave",
    oam={affine=false,objMode="normal",bpp=4,width=32,height=32},
    anim={
      kind="loop",
      frames={
        {tileOffset=16,duration=2},
        {tileOffset=32,duration=2},
        {tileOffset=48,duration=2},
      },
    },
  },
}

return M
