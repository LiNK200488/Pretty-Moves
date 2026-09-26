local M = { id="QUICK_ATTACK", name="Quick Attack" }

-- FireRed Move_QUICK_ATTACK choreography. The attacker ellipse/afterimage and
-- target shake are interpreted by the shared visual/battler-motion runtime.
M.script = {
  { op="loadspritegfx", tag=10135 }, -- ANIM_TAG_IMPACT
  { op="monbg", battler="atk_partner" },
  { op="setalpha", eva=12, evb=8 },
  { op="createvisualtask", task="AnimTask_TranslateMonEllipticalRespectSide", priority=2, args={"attacker",24,6,1,5} },
  { op="createvisualtask", task="AnimTask_TraceMonBlended", priority=2, args={0,4,7,3} },
  { op="playsewithpan", sound=134, pan="attacker" }, -- SE_M_JUMP_KICK
  { op="delay", frames=4 },
  { op="createvisualtask", task="AnimTask_ShakeMon", priority=2, args={"target",5,0,6,1} },
  { op="createsprite", template="gBasicHitSplatSpriteTemplate", anchor="target", priority=4, args={0,0,"target",1} },
  { op="playsewithpan", sound=207, pan="target" }, -- SE_M_VITAL_THROW2
  { op="waitforvisualfinish" },
  { op="clearmonbg", battler="atk_partner" },
  { op="blendoff" },
  { op="waitforvisualfinish" },
  { op="end" },
}

M.templates = {
  gBasicHitSplatSpriteTemplate = {
    tileTag=10135, paletteTag=10135, callback="AnimHitSplatBasic",
    oam={affine=true,objMode="blend",bpp=4,width=32,height=32},
    anim={kind="dummy",frames={{tileOffset=0,duration=1}}},
  },
}
return M
