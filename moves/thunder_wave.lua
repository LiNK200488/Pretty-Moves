local M = { id="THUNDER_WAVE", name="Thunder Wave" }

-- FireRed Move_THUNDER_WAVE. The resulting paralysis feedback is owned by the
-- shared status bridge, not by this move definition.
M.script = {
  { op="loadspritegfx", tag=10001 }, -- ANIM_TAG_SPARK
  { op="loadspritegfx", tag=10011 }, -- ANIM_TAG_SPARK_2
  { op="loadspritegfx", tag=10173 }, -- ANIM_TAG_SPARK_H
  { op="createvisualtask", task="AnimTask_BlendBattleAnimPal", priority=10, args={"bg",0,0,6,"black"} },
  { op="waitforvisualfinish" },
  { op="delay", frames=10 },
  { op="createvisualtask", task="AnimTask_ElectricBolt", priority=5, args={0,-48,0} },
  { op="playsewithpan", sound=131, pan="target" }, -- SE_M_THUNDER_WAVE
  { op="delay", frames=20 },
  { op="loopsewithpan", sound=112, pan="target", interval=10, count=4 },
  { op="createsprite", template="gThunderWaveSpriteTemplate", anchor="target", priority=2, args={-16,-16} },
  { op="delay", frames=4 },
  { op="createsprite", template="gThunderWaveSpriteTemplate", anchor="target", priority=2, args={-16,0} },
  { op="delay", frames=4 },
  { op="createsprite", template="gThunderWaveSpriteTemplate", anchor="target", priority=2, args={-16,16} },
  { op="waitforvisualfinish" },
  { op="createvisualtask", task="AnimTask_BlendBattleAnimPal", priority=10, args={"bg",0,6,0,"black"} },
  { op="waitforvisualfinish" },
  { op="end" },
}

M.templates = {
  gThunderWaveSpriteTemplate = {
    tileTag=10173, paletteTag=10173, callback="AnimThunderWave",
    oam={width=32,height=16}, anim={kind="dummy",frames={{tileOffset=0,duration=1}}},
    extraTileOffsets={8}, -- FireRed creates the right 32x16 half with tileNum += 8
  },
  -- Asset holder for the 8x8/8x16 bolt segment task. The task itself is
  -- compiled centrally by visual_runtime.
  gElectricBoltSegmentSpriteTemplate = {
    tileTag=10001, paletteTag=10001, callback="AnimElectricBoltSegment",
    oam={width=8,height=16}, anim={kind="dummy",frames={{tileOffset=0,duration=1}}},
  },
}

return M
