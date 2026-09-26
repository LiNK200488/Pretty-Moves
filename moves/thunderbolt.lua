local M = { id="THUNDERBOLT", name="Thunderbolt" }

-- FireRed Move_THUNDERBOLT, ported from pret/pokefirered's canonical battle
-- animation script. Secondary paralysis remains Gen1Recomp-owned.
M.script = {
  { op="loadspritegfx", tag=10001 }, -- ANIM_TAG_SPARK
  { op="loadspritegfx", tag=10282 }, -- ANIM_TAG_SHOCK_3
  { op="loadspritegfx", tag=10011 }, -- ANIM_TAG_SPARK_2
  { op="createvisualtask", task="AnimTask_BlendBattleAnimPal", priority=10, args={"bg",0,0,6,"black"} },
  { op="waitforvisualfinish" },
  { op="delay", frames=10 },
  { op="createvisualtask", task="AnimTask_ElectricBolt", priority=5, args={24,-52,0} },
  { op="playsewithpan", sound=111, pan="target" },
  { op="delay", frames=7 },
  { op="createvisualtask", task="AnimTask_ElectricBolt", priority=5, args={-24,-52,0} },
  { op="playsewithpan", sound=111, pan="target" },
  { op="delay", frames=7 },
  { op="createvisualtask", task="AnimTask_ElectricBolt", priority=5, args={0,-60,1} },
  { op="playsewithpan", sound=111, pan="target" },
  { op="delay", frames=9 },
  { op="createvisualtask", task="AnimTask_BlendBattleAnimPal", priority=10, args={"target",0,0,13,"black"} },
  { op="waitforvisualfinish" },
  { op="createvisualtask", task="AnimTask_BlendBattleAnimPal", priority=10, args={"target",0,13,0,"black"} },
  { op="waitforvisualfinish" },
  { op="delay", frames=20 },
  { op="createsprite", template="gThunderboltOrbSpriteTemplate", anchor="target", priority=3, args={44,0,0,3} },
  { op="createsprite", template="gSparkElectricityFlashingSpriteTemplate", anchor="target", priority=4, args={0,0,32,44,0,40,0,-32765} },
  { op="createsprite", template="gSparkElectricityFlashingSpriteTemplate", anchor="target", priority=4, args={0,0,32,44,64,40,1,-32765} },
  { op="createsprite", template="gSparkElectricityFlashingSpriteTemplate", anchor="target", priority=4, args={0,0,32,44,128,40,0,-32765} },
  { op="createsprite", template="gSparkElectricityFlashingSpriteTemplate", anchor="target", priority=4, args={0,0,32,44,192,40,2,-32765} },
  { op="createsprite", template="gSparkElectricityFlashingSpriteTemplate", anchor="target", priority=4, args={0,0,16,44,32,40,0,-32765} },
  { op="createsprite", template="gSparkElectricityFlashingSpriteTemplate", anchor="target", priority=4, args={0,0,16,44,96,40,1,-32765} },
  { op="createsprite", template="gSparkElectricityFlashingSpriteTemplate", anchor="target", priority=4, args={0,0,16,44,160,40,0,-32765} },
  { op="createsprite", template="gSparkElectricityFlashingSpriteTemplate", anchor="target", priority=4, args={0,0,16,44,224,40,2,-32765} },
  { op="playsewithpan", sound=208, pan="target" }, -- SE_M_HYPER_BEAM
  { op="createvisualtask", task="AnimTask_BlendBattleAnimPal", priority=10, args={"bg",0,2,2,"black"} },
  { op="delay", frames=6 },
  { op="createvisualtask", task="AnimTask_BlendBattleAnimPal", priority=10, args={"bg",0,6,6,"black"} },
  { op="delay", frames=6 },
  { op="createvisualtask", task="AnimTask_BlendBattleAnimPal", priority=10, args={"bg",0,2,2,"black"} },
  { op="delay", frames=6 },
  { op="createvisualtask", task="AnimTask_BlendBattleAnimPal", priority=10, args={"bg",0,6,6,"black"} },
  { op="waitforvisualfinish" },
  { op="delay", frames=20 },
  { op="playsewithpan", sound=112, pan="target" },
  { op="delay", frames=19 },
  { op="call", label="ElectricityEffect" },
  { op="waitforvisualfinish" },
  { op="delay", frames=20 },
  { op="createvisualtask", task="AnimTask_BlendBattleAnimPal", priority=10, args={"bg",0,6,0,"black"} },
  { op="waitforvisualfinish" },
  { op="end" },
}

M.labels = {
  ElectricityEffect = {
    { op="playsewithpan", sound=112, pan="target" },
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
    oam={width=8,height=16},anim={kind="dummy",frames={{tileOffset=0,duration=1}}},
    extraTileOffsets={1,2,3,4,5,6,7},
  },
  gThunderboltOrbSpriteTemplate = {
    tileTag=10282,paletteTag=10282,callback="AnimThunderboltOrb",
    oam={width=32,height=32,affine=true},
    anim={kind="loop",frames={{tileOffset=0,duration=6},{tileOffset=16,duration=6},{tileOffset=32,duration=6}}},
  },
  gSparkElectricityFlashingSpriteTemplate = {
    tileTag=10011,paletteTag=10011,callback="AnimSparkElectricityFlashing",
    oam={width=16,height=16,affine=true},
    anim={kind="dummy",frames={{tileOffset=0,duration=1}}},
    extraTileOffsets={4,8},
  },
  gElectricitySpriteTemplate = {
    tileTag=10011,paletteTag=10011,callback="AnimElectricity",
    oam={width=16,height=16},
    anim={kind="dummy",frames={{tileOffset=0,duration=1}}},
    extraTileOffsets={4,8},
  },
}

return M
