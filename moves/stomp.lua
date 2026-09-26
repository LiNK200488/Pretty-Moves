local M = { id="STOMP", name="Stomp" }

-- FireRed Move_STOMP. The wide foot waits above the target, drops over six
-- frames, then holds briefly while the impact and target shake land.
M.script = {
  { op="loadspritegfx", tag=10143 }, -- ANIM_TAG_HANDS_AND_FEET
  { op="loadspritegfx", tag=10135 }, -- ANIM_TAG_IMPACT
  { op="monbg", battler="target" },
  { op="setalpha", eva=12, evb=8 },
  { op="playsewithpan", sound=128, pan="target" }, -- SE_M_DOUBLE_TEAM
  { op="createsprite", template="gStompFootSpriteTemplate", anchor="attacker", priority=3,
    args={0,-32,15} },
  { op="delay", frames=19 },
  { op="createsprite", template="gBasicHitSplatSpriteTemplate", anchor="attacker", priority=2,
    args={0,-8,"target",1} },
  { op="createvisualtask", task="AnimTask_ShakeMon", priority=2,
    args={"target",0,4,9,1} },
  { op="playsewithpan", sound=134, pan="target" }, -- SE_M_MEGA_KICK2
  { op="waitforvisualfinish" },
  { op="clearmonbg", battler="target" },
  { op="blendoff" },
  { op="end" },
}

M.templates = {
  gStompFootSpriteTemplate = {
    tileTag=10143,paletteTag=10143,callback="AnimStompFoot",
    oam={affine=false,objMode="normal",bpp=4,width=32,height=32},
    anim={kind="once",frames={{tileOffset=16,duration=1}}},
  },
  gBasicHitSplatSpriteTemplate = {
    tileTag=10135,paletteTag=10135,callback="AnimHitSplatBasic",
    oam={affine=true,objMode="blend",bpp=4,width=32,height=32},
    anim={kind="dummy",frames={{tileOffset=0,duration=1}}},
  },
}

return M
