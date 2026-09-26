local M = { id="STRUGGLE", name="Struggle" }

-- FireRed Move_STRUGGLE. The attacker shakes in place while a pair of
-- movement-wave sprites pulse on either side for two complete cycles. Once
-- that visual finishes, a basic impact splat lands on the target, the target
-- shakes, and SE_M_MEGA_KICK2 marks the hit.
M.script = {
  { op="loadspritegfx", tag=10135 }, -- ANIM_TAG_IMPACT
  { op="loadspritegfx", tag=10215 }, -- ANIM_TAG_MOVEMENT_WAVES
  { op="monbg", battler="target" },
  { op="setalpha", eva=12, evb=8 },
  { op="createvisualtask", task="AnimTask_ShakeMonInPlace", priority=2,
    args={"attacker",3,0,12,4} },
  { op="createsprite", template="gMovementWavesSpriteTemplate", anchor="attacker", priority=2,
    args={0,0,2} },
  { op="createsprite", template="gMovementWavesSpriteTemplate", anchor="attacker", priority=2,
    args={0,1,2} },
  { op="loopsewithpan", sound=155, pan="attacker", interval=12, count=4 }, -- SE_M_HEADBUTT
  { op="waitforvisualfinish" },
  { op="createsprite", template="gBasicHitSplatSpriteTemplate", anchor="attacker", priority=3,
    args={0,0,"target",2} },
  { op="createvisualtask", task="AnimTask_ShakeMonInPlace", priority=2,
    args={"target",3,0,6,1} },
  { op="playsewithpan", sound=134, pan="target" }, -- SE_M_MEGA_KICK2
  { op="waitforvisualfinish" },
  { op="clearmonbg", battler="target" },
  { op="blendoff" },
  { op="end" },
}

M.templates = {
  gMovementWavesSpriteTemplate = {
    tileTag=10215,paletteTag=10215,callback="AnimMovementWaves",
    oam={affine=false,objMode="normal",bpp=4,width=32,height=32},
    anim={kind="variants",variants={
      [0]={kind="once",frames={
        {tileOffset=0,duration=8},
        {tileOffset=16,duration=8},
        {tileOffset=32,duration=8},
        {tileOffset=16,duration=8},
      }},
      [1]={kind="once",frames={
        {tileOffset=16,duration=8,hFlip=true},
        {tileOffset=32,duration=8,hFlip=true},
        {tileOffset=16,duration=8,hFlip=true},
        {tileOffset=0,duration=8,hFlip=true},
      }},
    }},
  },
  gBasicHitSplatSpriteTemplate = {
    tileTag=10135,paletteTag=10135,callback="AnimHitSplatBasic",
    oam={affine=true,objMode="blend",bpp=4,width=32,height=32},
    anim={kind="dummy",frames={{tileOffset=0,duration=1}}},
  },
}

return M
