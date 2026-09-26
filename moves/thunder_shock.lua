local M = { id="THUNDERSHOCK", name="ThunderShock" }

-- FireRed Move_THUNDER_SHOCK, ported from pret/pokefirered's canonical
-- battle animation script. Secondary paralysis remains Gen1Recomp-owned.
M.script = {
  { op="loadspritegfx", tag=10001 }, -- ANIM_TAG_SPARK
  { op="loadspritegfx", tag=10011 }, -- ANIM_TAG_SPARK_2

  { op="createvisualtask", task="AnimTask_BlendBattleAnimPal", priority=10, args={"bg",0,0,6,"black"} },
  { op="waitforvisualfinish" },
  { op="delay", frames=10 },

  { op="createvisualtask", task="AnimTask_ElectricBolt", priority=5, args={0,-44,0} },
  { op="playsewithpan", sound=111, pan="target" }, -- SE_M_THUNDERBOLT
  { op="delay", frames=9 },

  { op="createvisualtask", task="AnimTask_BlendBattleAnimPal", priority=10, args={"target",0,0,13,"black"} },
  { op="waitforvisualfinish" },
  { op="createvisualtask", task="AnimTask_BlendBattleAnimPal", priority=10, args={"target",0,13,0,"black"} },
  { op="waitforvisualfinish" },

  { op="delay", frames=20 },
  { op="call", label="ElectricityEffect" },
  { op="waitforvisualfinish" },
  { op="delay", frames=20 },

  { op="createvisualtask", task="AnimTask_BlendBattleAnimPal", priority=10, args={"bg",0,6,0,"black"} },
  { op="waitforvisualfinish" },
  { op="end" },
}

M.labels = {
  ElectricityEffect = {
    { op="playsewithpan", sound=112, pan="target" }, -- SE_M_THUNDERBOLT2
    { op="createsprite", template="gElectricitySpriteTemplate", anchor="target", priority=2, args={5,0,5,0} },
    { op="delay", frames=2 },
    { op="createsprite", template="gElectricitySpriteTemplate", anchor="target", priority=2, args={-5,10,5,1} },
    { op="delay", frames=2 },
    { op="createsprite", template="gElectricitySpriteTemplate", anchor="target", priority=2, args={15,20,5,2} },
    { op="delay", frames=2 },
    { op="createsprite", template="gElectricitySpriteTemplate", anchor="target", priority=2, args={-15,-10,5,0} },
    { op="delay", frames=2 },
    { op="createsprite", template="gElectricitySpriteTemplate", anchor="target", priority=2, args={25,0,5,1} },
    { op="delay", frames=2 },
    { op="createsprite", template="gElectricitySpriteTemplate", anchor="target", priority=2, args={-8,8,5,2} },
    { op="delay", frames=2 },
    { op="createsprite", template="gElectricitySpriteTemplate", anchor="target", priority=2, args={2,-8,5,0} },
    { op="delay", frames=2 },
    { op="createsprite", template="gElectricitySpriteTemplate", anchor="target", priority=2, args={-20,15,5,1} },
    { op="return" },
  },
}

M.templates = {
  gElectricBoltSegmentSpriteTemplate = {
    tileTag=10001,paletteTag=10001,callback="AnimElectricBoltSegment",
    oam={width=8,height=16},
    anim={kind="dummy",frames={{tileOffset=0,duration=1}}},
    extraTileOffsets={1,2,3,4,5,6,7},
  },
  gElectricitySpriteTemplate = {
    tileTag=10011,paletteTag=10011,callback="AnimElectricity",
    oam={width=16,height=16},
    anim={kind="dummy",frames={{tileOffset=0,duration=1}}},
    extraTileOffsets={4,8},
  },
}

return M
