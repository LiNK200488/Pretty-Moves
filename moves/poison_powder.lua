local M = { id="POISONPOWDER", name="PoisonPowder" }

-- FireRed Move_POISON_POWDER choreography. The move is status-only; the
-- resulting poison feedback is handled separately by the shared status bridge.
M.script = {
  { op = "loadspritegfx", tag = 10065 }, -- ANIM_TAG_POISON_POWDER
  { op = "loadspritegfx", tag = 10150 }, -- ANIM_TAG_POISON_BUBBLE (preloaded by FireRed script)
  { op = "loopsewithpan", sound = 162, pan = "target", interval = 10, count = 6 },

  { op = "createsprite", template = "gPoisonPowderParticleSpriteTemplate", anchor = "target", priority = 2,
    args = {-30, -22, 117, 80, 5, 1} },
  { op = "createsprite", template = "gPoisonPowderParticleSpriteTemplate", anchor = "target", priority = 2,
    args = {10, -22, 117, 80, -5, 1} },
  { op = "createsprite", template = "gPoisonPowderParticleSpriteTemplate", anchor = "target", priority = 2,
    args = {-25, -22, 117, 112, 5, 3} },
  { op = "delay", frames = 15 },

  { op = "createsprite", template = "gPoisonPowderParticleSpriteTemplate", anchor = "target", priority = 2,
    args = {-5, -22, 117, 80, -5, 1} },
  { op = "createsprite", template = "gPoisonPowderParticleSpriteTemplate", anchor = "target", priority = 2,
    args = {5, -22, 117, 96, 5, 1} },
  { op = "createsprite", template = "gPoisonPowderParticleSpriteTemplate", anchor = "target", priority = 2,
    args = {0, -22, 117, 69, -5, 1} },
  { op = "createsprite", template = "gPoisonPowderParticleSpriteTemplate", anchor = "target", priority = 2,
    args = {-15, -22, 117, 112, 5, 2} },
  { op = "delay", frames = 30 },

  { op = "createsprite", template = "gPoisonPowderParticleSpriteTemplate", anchor = "target", priority = 2,
    args = {-15, -22, 117, 112, 5, 2} },
  { op = "createsprite", template = "gPoisonPowderParticleSpriteTemplate", anchor = "target", priority = 2,
    args = {15, -22, 117, 80, -5, 1} },
  { op = "createsprite", template = "gPoisonPowderParticleSpriteTemplate", anchor = "target", priority = 2,
    args = {-10, -22, 117, 96, 7, 2} },
  { op = "createsprite", template = "gPoisonPowderParticleSpriteTemplate", anchor = "target", priority = 2,
    args = {-5, -22, 117, 90, -8, 0} },
  { op = "delay", frames = 20 },

  { op = "createsprite", template = "gPoisonPowderParticleSpriteTemplate", anchor = "target", priority = 2,
    args = {-10, -22, 117, 80, -5, 1} },
  { op = "createsprite", template = "gPoisonPowderParticleSpriteTemplate", anchor = "target", priority = 2,
    args = {0, -22, 117, 89, 5, 2} },
  { op = "createsprite", template = "gPoisonPowderParticleSpriteTemplate", anchor = "target", priority = 2,
    args = {20, -22, 117, 112, -8, 2} },
  { op = "createsprite", template = "gPoisonPowderParticleSpriteTemplate", anchor = "target", priority = 2,
    args = {5, -22, 117, 80, 5, 1} },
  { op = "waitforvisualfinish" },
  { op = "end" },
}

M.templates = {
  gPoisonPowderParticleSpriteTemplate = {
    tileTag = 10065,
    paletteTag = 10065,
    callback = "AnimMovePowderParticle",
    oam = { affine = false, objMode = "normal", bpp = 4, width = 8, height = 16 },
    anim = {
      kind = "loop",
      frames = {
        { tileOffset = 0, duration = 5 },
        { tileOffset = 2, duration = 5 },
        { tileOffset = 4, duration = 5 },
        { tileOffset = 6, duration = 5 },
        { tileOffset = 8, duration = 5 },
        { tileOffset = 10, duration = 5 },
        { tileOffset = 12, duration = 5 },
        { tileOffset = 14, duration = 5 },
      },
    },
  },
}

return M
