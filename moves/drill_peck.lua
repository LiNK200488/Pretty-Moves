local M = { id="DRILL_PECK", name="Drill Peck" }

M.soundIds = {155,159}

-- FireRed Move_DRILL_PECK. The attacker performs the shared BowMon pose,
-- then eight circular impact splats strike the target while Horn Attack SFX
-- retrigger every 4 frames and the target shakes, before the attacker resets.
M.script = {
  { op="loadspritegfx", tag=10135 }, -- ANIM_TAG_IMPACT
  { op="loadspritegfx", tag=10162 }, -- ANIM_TAG_WHIRLWIND_LINES (loaded by FireRed script)
  { op="createsprite", template="gBowMonSpriteTemplate", anchor="attacker", priority=2, args={0} },
  { op="playsewithpan", sound=155, pan="attacker" }, -- SE_M_HEADBUTT
  { op="waitforvisualfinish" },
  { op="delay", frames=2 },
  { op="createsprite", template="gBowMonSpriteTemplate", anchor="attacker", priority=2, args={1} },
  { op="delay", frames=2 },
  { op="loopsewithpan", sound=159, pan="target", interval=4, count=8 }, -- SE_M_HORN_ATTACK
  { op="createvisualtask", task="AnimTask_DrillPeckHitSplats", priority=5 },
  { op="createvisualtask", task="AnimTask_ShakeMon2", priority=2, args={"target",4,0,18,1} },
  { op="waitforvisualfinish" },
  { op="createsprite", template="gBowMonSpriteTemplate", anchor="attacker", priority=2, args={2} },
  { op="waitforvisualfinish" },
  { op="end" },
}

M.templates = {
  gFlashingHitSplatSpriteTemplate = {
    tileTag=10135,paletteTag=10135,callback="AnimFlashingHitSplat",
    oam={affine=true,objMode="normal",bpp=4,width=32,height=32},
    anim={kind="dummy",frames={{tileOffset=0,duration=1}}},
  },
}

return M
