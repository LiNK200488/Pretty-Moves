local M = { id="WHIRLWIND", name="Whirlwind" }

-- FireRed Move_WHIRLWIND: six staggered Whirlwind Line sprites sweep the
-- target, then the target shakes, follows the native elliptical displacement,
-- and is pushed completely off-screen.
M.script = {
  { op="loadspritegfx", tag=10162 }, -- ANIM_TAG_WHIRLWIND_LINES
  { op="createsprite", template="gWhirlwindLineSpriteTemplate", anchor="attacker", priority=2, args={0,-8,"target",60,0} },
  { op="createsprite", template="gWhirlwindLineSpriteTemplate", anchor="attacker", priority=2, args={0,0,"target",60,1} },
  { op="createsprite", template="gWhirlwindLineSpriteTemplate", anchor="attacker", priority=2, args={0,8,"target",60,2} },
  { op="createsprite", template="gWhirlwindLineSpriteTemplate", anchor="attacker", priority=2, args={0,16,"target",60,3} },
  { op="createsprite", template="gWhirlwindLineSpriteTemplate", anchor="attacker", priority=2, args={0,24,"target",60,4} },
  { op="createsprite", template="gWhirlwindLineSpriteTemplate", anchor="attacker", priority=2, args={0,32,"target",60,0} },
  { op="delay", frames=5 },
  { op="loopsewithpan", sound=128, pan="target", interval=10, count=4 }, -- SE_M_DOUBLE_TEAM
  { op="createvisualtask", task="AnimTask_ShakeMon2", priority=2, args={"target",4,0,15,1} },
  { op="delay", frames=29 },
  { op="createvisualtask", task="AnimTask_TranslateMonEllipticalRespectSide", priority=2,
    args={"target",12,6,1,5} },
  { op="delay", frames=7 },
  { op="playsewithpan", sound=122, pan="target" }, -- SE_M_STRING_SHOT
  { op="createvisualtask", task="AnimTask_SlideOffScreen", priority=5, args={"target",8} },
  { op="waitforvisualfinish" },
  { op="end" },
}

M.templates = {
  gWhirlwindLineSpriteTemplate = {
    tileTag=10162,paletteTag=10162,callback="AnimWhirlwindLine",
    oam={affine=false,objMode="normal",bpp=4,width=32,height=16},
    anim={kind="once",frames={
      {tileOffset=0,duration=1},{tileOffset=8,duration=1},{tileOffset=16,duration=1},
      {tileOffset=8,duration=1,hFlip=true},{tileOffset=0,duration=1,hFlip=true},
    }},
  },
}
return M
