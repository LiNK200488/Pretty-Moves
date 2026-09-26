local M = { id="KARATE_CHOP", name="Karate Chop" }

-- FireRed Move_KARATE_CHOP. gKarateChopSpriteTemplate uses the real
-- AnimSlideHandOrFootToTarget callback, which selects hand-left (anim 3),
-- clears arg6, then delegates to AnimTravelDiagonally for one setup frame plus a 10-tick native
-- 8.8 fixed-point approach into the target.
M.script = {
  { op="loadspritegfx", tag=10143 }, -- ANIM_TAG_HANDS_AND_FEET
  { op="loadspritegfx", tag=10135 }, -- ANIM_TAG_IMPACT
  { op="monbg", battler="def_partner" },
  { op="splitbgprio", battler="target" },
  { op="setalpha", eva=12, evb=8 },
  { op="playsewithpan", sound=128, pan="target" }, -- SE_M_DOUBLE_TEAM
  { op="createsprite", template="gKarateChopSpriteTemplate", anchor="attacker", priority=2,
    args={-16,0,0,0,10,1,3,0} },
  { op="waitforvisualfinish" },
  { op="playsewithpan", sound=132, pan="target" }, -- SE_M_COMET_PUNCH
  { op="createsprite", template="gBasicHitSplatSpriteTemplate", anchor="attacker", priority=3,
    args={0,0,"target",2} },
  { op="createvisualtask", task="AnimTask_ShakeMon", priority=5,
    args={"target",4,0,6,1} },
  { op="waitforvisualfinish" },
  { op="clearmonbg", battler="def_partner" },
  { op="blendoff" },
  { op="end" },
}

M.templates = {
  gKarateChopSpriteTemplate = {
    tileTag=10143,paletteTag=10143,callback="AnimSlideHandOrFootToTarget",
    oam={affine=false,objMode="normal",bpp=4,width=32,height=32},
    -- sAnims_HandsAndFeet[3] = sAnim_HandLeft = tile offset 48, no flips.
    anim={kind="once",frames={{tileOffset=48,duration=1}}},
  },
  gBasicHitSplatSpriteTemplate = {
    tileTag=10135,paletteTag=10135,callback="AnimHitSplatBasic",
    oam={affine=true,objMode="blend",bpp=4,width=32,height=32},
    anim={kind="dummy",frames={{tileOffset=0,duration=1}}},
  },
}

return M
