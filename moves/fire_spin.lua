local M = { id="FIRE_SPIN", name="Fire Spin" }

-- Declarative FireRed Fire Spin definition. Values mirror pret/pokefirered's
-- Move_FIRE_SPIN / FireSpinEffect script and gFireSpinSpriteTemplate exactly.
M.script = {
  { op="loadspritegfx", tag=10029 }, -- ANIM_TAG_SMALL_EMBER
  { op="playsewithpan", sound=143, pan="target" }, -- SE_M_SACRED_FIRE2
  { op="createvisualtask", task="AnimTask_ShakeMon", priority=5,
    args={"target", 0, 2, 47, 1} },
  { op="call", label="FireSpinEffect" },
  { op="call", label="FireSpinEffect" },
  { op="call", label="FireSpinEffect" },
  { op="waitforvisualfinish" },
  { op="end" },
}

M.labels = {
  FireSpinEffect = {
    { op="createsprite", template="gFireSpinSpriteTemplate", anchor="target", priority=2,
      args={0, 28, 528, 30, 13, 50, "target"} },
    { op="delay", frames=2 },
    { op="createsprite", template="gFireSpinSpriteTemplate", anchor="target", priority=2,
      args={0, 32, 480, 20, 16, -46, "target"} },
    { op="delay", frames=2 },
    { op="createsprite", template="gFireSpinSpriteTemplate", anchor="target", priority=2,
      args={0, 33, 576, 20, 8, 42, "target"} },
    { op="delay", frames=2 },
    { op="createsprite", template="gFireSpinSpriteTemplate", anchor="target", priority=2,
      args={0, 31, 400, 25, 11, -42, "target"} },
    { op="delay", frames=2 },
    { op="createsprite", template="gFireSpinSpriteTemplate", anchor="target", priority=2,
      args={0, 28, 512, 25, 16, 46, "target"} },
    { op="delay", frames=2 },
    { op="createsprite", template="gFireSpinSpriteTemplate", anchor="target", priority=2,
      args={0, 33, 464, 30, 15, -50, "target"} },
    { op="delay", frames=2 },
    { op="return" },
  },
}

M.templates = {
  gFireSpinSpriteTemplate = {
    tileTag=10029,
    paletteTag=10029,
    callback="AnimParticleInVortex",
    oam={affine=false,objMode="normal",bpp=4,width=32,height=32},
    anim={
      kind="loop",
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
