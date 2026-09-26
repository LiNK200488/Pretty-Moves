local M = { id="SKY_ATTACK", name="Sky Attack" }

-- FireRed Move_SKY_ATTACK is a two-turn animation. In RBY there are no double
-- battles, so the charge turn always follows SkyAttackSetUpAgainstOpponent.
-- Gen1Recomp's charge seam remains authoritative for mechanics; this replaces
-- only the generic first-turn animation row and the release presentation.
M.chargeRowAnims = { player="XSTATITEM_ANIM", opponent="XSTATITEM_DUPLICATE_ANIM" }
M.soundIds = {232,231,134}

M.chargeScript = {
  { op="monbg", battler="def_partner" },
  { op="setalpha", eva=12, evb=11 },

  -- F_PAL_BG | F_PAL_ATK_SIDE | F_PAL_DEF_PARTNER. In a Gen 1 singles
  -- battle only BG + attacker are present from that selector.
  { op="createvisualtask", task="AnimTask_BlendBattleAnimPal", priority=10,
    args={"bg",1,0,12,"black"} },
  { op="createvisualtask", task="AnimTask_BlendBattleAnimPal", priority=10,
    args={"attacker",1,0,12,"black"} },
  { op="waitforvisualfinish" },
  { op="delay", frames=12 },

  { op="createvisualtask", task="AnimTask_BlendBattleAnimPal", priority=10,
    args={"attacker",1,8,0,"black"} },
  { op="createvisualtask", task="AnimTask_HorizontalShake", priority=5,
    args={"attacker",2,16} },
  { op="loopsewithpan", sound=232, pan="attacker", interval=4, count=8 }, -- SE_M_STAT_INCREASE
  { op="createvisualtask", task="AnimTask_BlendBattleAnimPal", priority=10,
    args={"attacker",1,0,15,"white"} },
  { op="delay", frames=20 },
  { op="createvisualtask", task="AnimTask_BlendBattleAnimPal", priority=10,
    args={"attacker",1,15,0,"white"} },
  { op="waitforvisualfinish" },

  -- F_PAL_BG | F_PAL_ATK_PARTNER | F_PAL_DEF_PARTNER -> BG only in RBY.
  { op="createvisualtask", task="AnimTask_BlendBattleAnimPal", priority=10,
    args={"bg",1,8,0,"black"} },
  { op="waitforvisualfinish" },
  { op="clearmonbg", battler="def_partner" },
  { op="blendoff" },
  { op="end" },
}

M.script = {
  { op="loadspritegfx", tag=10135 }, -- ANIM_TAG_IMPACT
  { op="loadspritegfx", tag=10284 }, -- ANIM_TAG_BIRD

  -- FireRed SetSkyBg (normal battle): BG_SKY + sliding BG task.
  { op="fadetobg", bg="in_air" },
  { op="waitbgfadeout" },
  { op="createvisualtask", task="AnimTask_StartSlidingBg", priority=5,
    args={-2304,768,1,-1} },
  { op="waitbgfadein" },

  { op="monbg", battler="attacker" },
  { op="createvisualtask", task="AnimTask_BlendBattleAnimPal", priority=10,
    args={"attacker",0,0,16,"white"} },
  { op="delay", frames=4 },
  { op="createvisualtask", task="AnimTask_AttackerFadeToInvisible", priority=5, args={0} },
  { op="waitforvisualfinish" },

  { op="playsewithpan", sound=231, pan="attacker" }, -- SE_M_SKY_UPPERCUT
  { op="createsprite", template="gSkyAttackBirdSpriteTemplate", anchor="target", priority=2 },
  { op="delay", frames=14 },
  { op="createvisualtask", task="AnimTask_ShakeMon2", priority=2,
    args={"target",10,0,18,1} },
  { op="playsewithpan", sound=134, pan="target" }, -- SE_M_MEGA_KICK2
  { op="delay", frames=20 },

  { op="createvisualtask", task="AnimTask_AttackerFadeFromInvisible", priority=5, args={1} },
  { op="delay", frames=2 },
  { op="createvisualtask", task="AnimTask_BlendBattleAnimPal", priority=10,
    args={"attacker",0,15,0,"white"} },
  { op="waitforvisualfinish" },
  { op="clearmonbg", battler="attacker" },

  -- FireRed UnsetSkyBg.
  { op="restorebg" },
  { op="waitbgfadeout" },
  { op="setarg", index=7, value=0xFFFF },
  { op="waitbgfadein" },
  { op="end" },
}

M.templates = {
  gSkyAttackBirdSpriteTemplate = {
    tileTag=10284,paletteTag=10284,callback="AnimSkyAttackBird",
    oam={affine=true,doubleSize=true,objMode="normal",bpp=4,width=64,height=64},
    anim={kind="dummy",frames={{tileOffset=0,duration=1}}},
  },
}

return M
