local M = { id="THRASH", name="Thrash" }

-- FireRed Move_THRASH, source-faithful. Two concurrent native battler tasks
-- drive the 84-frame thrash motion while three random hand/foot hits land.
M.script = {
  { op="loadspritegfx", tag=10135 }, -- ANIM_TAG_IMPACT
  { op="loadspritegfx", tag=10143 }, -- ANIM_TAG_HANDS_AND_FEET
  { op="createvisualtask", task="AnimTask_ThrashMoveMonHorizontal", priority=2 },
  { op="createvisualtask", task="AnimTask_ThrashMoveMonVertical", priority=2 },

  { op="createsprite", template="gFistFootRandomPosSpriteTemplate", anchor="target", priority=3, args={1,10,0} },
  { op="createvisualtask", task="AnimTask_ShakeMonInPlace", priority=2, args={"target",4,0,7,1} },
  { op="playsewithpan", sound=132, pan="target" }, -- SE_M_COMET_PUNCH
  { op="delay", frames=28 },

  { op="createsprite", template="gFistFootRandomPosSpriteTemplate", anchor="target", priority=3, args={1,10,1} },
  { op="createvisualtask", task="AnimTask_ShakeMonInPlace", priority=2, args={"target",4,0,7,1} },
  { op="playsewithpan", sound=116, pan="target" }, -- SE_M_VITAL_THROW2
  { op="delay", frames=28 },

  { op="createsprite", template="gFistFootRandomPosSpriteTemplate", anchor="target", priority=3, args={1,10,3} },
  { op="createvisualtask", task="AnimTask_ShakeMonInPlace", priority=2, args={"target",8,0,16,1} },
  { op="playsewithpan", sound=134, pan="target" }, -- SE_M_MEGA_KICK2
  { op="end" },
}

M.templates = {
  gFistFootRandomPosSpriteTemplate = {
    tileTag=10143,paletteTag=10143,callback="AnimFistOrFootRandomPos",
    oam={affine=false,objMode="normal",bpp=4,width=32,height=32},
    anim={kind="variants",variants={
      [0]={{tileOffset=0,duration=1}}, [1]={{tileOffset=16,duration=1}},
      [2]={{tileOffset=32,duration=1}}, [3]={{tileOffset=48,duration=1}},
      [4]={{tileOffset=48,duration=1,hFlip=true}},
    }},
  },
}

return M
