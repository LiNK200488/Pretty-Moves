local M = { id="SUPERSONIC", name="Supersonic" }

M.soundIds = {177}

-- FireRed Move_SUPERSONIC.
-- Six expanding gold rings travel from attacker to target at 2-frame spacing
-- while the attacker shakes. The ring uses gGrowingRingAffineAnimTable.
M.script = {
  { op="loadspritegfx", tag=10163 }, -- ANIM_TAG_GOLD_RING
  { op="monbg", battler="atk_partner" },
  { op="splitbgprio_foes", battler="attacker" },
  { op="setalpha", eva=12, evb=8 },
  { op="createvisualtask", task="AnimTask_ShakeMon2", priority=2, args={"attacker",2,0,8,1} },

  { op="playsewithpan", sound=177, pan="attacker" },
  { op="createsprite", template="gSupersonicRingSpriteTemplate", anchor="target", priority=2, args={16,0,0,0,30,0} },
  { op="delay", frames=2 },

  { op="playsewithpan", sound=177, pan="attacker" },
  { op="createsprite", template="gSupersonicRingSpriteTemplate", anchor="target", priority=2, args={16,0,0,0,30,0} },
  { op="delay", frames=2 },

  { op="playsewithpan", sound=177, pan="attacker" },
  { op="createsprite", template="gSupersonicRingSpriteTemplate", anchor="target", priority=2, args={16,0,0,0,30,0} },
  { op="delay", frames=2 },

  { op="playsewithpan", sound=177, pan="attacker" },
  { op="createsprite", template="gSupersonicRingSpriteTemplate", anchor="target", priority=2, args={16,0,0,0,30,0} },
  { op="delay", frames=2 },

  { op="playsewithpan", sound=177, pan="attacker" },
  { op="createsprite", template="gSupersonicRingSpriteTemplate", anchor="target", priority=2, args={16,0,0,0,30,0} },
  { op="delay", frames=2 },

  { op="playsewithpan", sound=177, pan="attacker" },
  { op="createsprite", template="gSupersonicRingSpriteTemplate", anchor="target", priority=2, args={16,0,0,0,30,0} },
  { op="delay", frames=2 },

  { op="waitforvisualfinish" },
  { op="clearmonbg", battler="atk_partner" },
  { op="blendoff" },
  { op="end" },
}

M.templates = {
  gSupersonicRingSpriteTemplate = {
    tileTag=10163, paletteTag=10163, callback="TranslateAnimSpriteToTargetMonLocation",
    oam={affine=true,doubleSize=true,objMode="normal",bpp=4,width=16,height=32},
    -- FireRed gGrowingRingAffineAnimTable: 32/256 initial scale, then +7/256
    -- each frame for 32 frames. This is the same native affine growth used by
    -- Psywave, but applied to the gold Supersonic ring.
    affineAnim={kind="linear_scale",start=32,delta=7,frames=32},
    anim={kind="dummy",frames={{tileOffset=0,duration=1}}},
  },
}

return M
