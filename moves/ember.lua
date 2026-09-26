local M = { id="EMBER", name="Ember" }

-- Declarative FireRed Ember definition. No runtime/playback logic belongs here.
-- Values mirror pret/pokefirered's Move_EMBER script exactly.
M.script = {
  { op = "loadspritegfx", tag = 10029 },
  { op = "loopsewithpan", sound = 144, pan = "attacker", interval = 5, count = 2 },
  { op = "createsprite", template = "gEmberSpriteTemplate", anchor = "target", priority = 2,
    args = {20, 0, -16, 24, 20, 1} },
  { op = "delay", frames = 4 },
  { op = "createsprite", template = "gEmberSpriteTemplate", anchor = "target", priority = 2,
    args = {20, 0, 0, 24, 20, 1} },
  { op = "delay", frames = 4 },
  { op = "createsprite", template = "gEmberSpriteTemplate", anchor = "target", priority = 2,
    args = {20, 0, 16, 24, 20, 1} },
  { op = "delay", frames = 16 },
  { op = "playsewithpan", sound = 137, pan = "target" },
  { op = "call", label = "EmberFireHit" },
  { op = "call", label = "EmberFireHit" },
  { op = "call", label = "EmberFireHit" },
  { op = "end" },
}

M.labels = {
  EmberFireHit = {
    { op = "createsprite", template = "gEmberFlareSpriteTemplate", anchor = "target", priority = 2,
      args = {-24, 24, 24, 24, 20, "target", 1} },
    { op = "delay", frames = 4 },
    { op = "return" },
  }
}

-- Known template/resource facts used for validation and renderer work.
M.templates = {
  gEmberSpriteTemplate = {
    tileTag = 10029,
    paletteTag = 10029,
    callback = "TranslateAnimSpriteToTargetMonLocation",
    oam = { affine = false, objMode = "normal", bpp = 4, width = 32, height = 32 },
    anim = { kind = "dummy", frames = { { tileOffset = 0, duration = nil } } },
  },
  gEmberFlareSpriteTemplate = {
    tileTag = 10029,
    paletteTag = 10029,
    callback = "AnimEmberFlare",
    oam = { affine = false, objMode = "normal", bpp = 4, width = 32, height = 32 },
    anim = {
      kind = "loop",
      frames = {
        { tileOffset = 0, duration = 4 },
        { tileOffset = 16, duration = 4 },
        { tileOffset = 32, duration = 4 },
        { tileOffset = 48, duration = 4 },
        { tileOffset = 64, duration = 4 },
      },
    },
  },
}


return M
