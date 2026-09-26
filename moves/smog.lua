local M = { id="SMOG", name="Smog" }

M.soundIds = {161, 141}

-- Exact FireRed Move_SMOG choreography.
M.script = {
  { op="loadspritegfx", tag=10172 }, -- ANIM_TAG_PURPLE_GAS_CLOUD
  { op="monbg", battler="def_partner" },
  { op="splitbgprio_all" },
  { op="setalpha", eva=12, evb=8 },
  { op="loopsewithpan", sound=161, pan="target", interval=17, count=10 }, -- SE_M_MIST

  { op="call", label="SmogCloud" },
  { op="call", label="SmogCloud" },
  { op="call", label="SmogCloud" },
  { op="call", label="SmogCloud" },
  { op="call", label="SmogCloud" },
  { op="call", label="SmogCloud" },
  { op="call", label="SmogCloud" },

  { op="delay", frames=120 },
  { op="loopsewithpan", sound=141, pan="target", interval=18, count=2 }, -- SE_M_TOXIC
  { op="createvisualtask", task="AnimTask_BlendColorCycle", priority=2,
    args={"target",2,2,0,12,{26,0,26}} },
  { op="delay", frames=10 },
  { op="createvisualtask", task="AnimTask_ShakeMon2", priority=2,
    args={"target",2,0,15,1} },
  { op="waitforvisualfinish" },
  { op="clearmonbg", battler="def_partner" },
  { op="blendoff" },
  { op="end" },
}

M.labels = {
  SmogCloud = {
    { op="createsprite", template="gSmogCloudSpriteTemplate", anchor="attacker", priority=2,
      args={0,-24,48,240,1,0} },
    { op="delay", frames=7 },
    { op="return" },
  },
}

M.templates = {
  gSmogCloudSpriteTemplate = {
    tileTag=10172,paletteTag=10172,callback="InitSwirlingFogAnim",
    oam={affine=false,objMode="blend",bpp=4,width=32,height=16},
    anim={kind="loop",frames={{tileOffset=0,duration=8},{tileOffset=8,duration=8}}},
  },
}

return M
