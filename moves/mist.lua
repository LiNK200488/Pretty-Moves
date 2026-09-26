local M = { id="MIST", name="Mist" }

M.soundIds = {161}

-- FireRed Move_MIST. Seven translucent mist clouds are emitted around the
-- attacker at seven-frame spacing. Each cloud swirls while drifting 48 pixels
-- over 240 native callbacks. SE_M_MIST is retriggered every 20 frames for 15
-- plays, then the attacker's side palette cycles toward white and back.
M.script = {
  { op="loadspritegfx", tag=10144 }, -- ANIM_TAG_MIST_CLOUD
  { op="monbg", battler="atk_partner" },
  { op="setalpha", eva=12, evb=8 },
  { op="loopsewithpan", sound=161, pan="attacker", interval=20, count=15 }, -- SE_M_MIST

  { op="createsprite", template="gMistCloudSpriteTemplate", anchor="attacker", priority=2, args={0,-24,48,240,0,1} },
  { op="delay", frames=7 },
  { op="createsprite", template="gMistCloudSpriteTemplate", anchor="attacker", priority=2, args={0,-24,48,240,0,1} },
  { op="delay", frames=7 },
  { op="createsprite", template="gMistCloudSpriteTemplate", anchor="attacker", priority=2, args={0,-24,48,240,0,1} },
  { op="delay", frames=7 },
  { op="createsprite", template="gMistCloudSpriteTemplate", anchor="attacker", priority=2, args={0,-24,48,240,0,1} },
  { op="delay", frames=7 },
  { op="createsprite", template="gMistCloudSpriteTemplate", anchor="attacker", priority=2, args={0,-24,48,240,0,1} },
  { op="delay", frames=7 },
  { op="createsprite", template="gMistCloudSpriteTemplate", anchor="attacker", priority=2, args={0,-24,48,240,0,1} },
  { op="delay", frames=7 },
  { op="createsprite", template="gMistCloudSpriteTemplate", anchor="attacker", priority=2, args={0,-24,48,240,0,1} },

  { op="delay", frames=32 },
  { op="createvisualtask", task="AnimTask_BlendColorCycle", priority=2,
    args={"attacker",8,2,0,14,{31,31,31}} },
  { op="waitforvisualfinish" },
  { op="clearmonbg", battler="atk_partner" },
  { op="blendoff" },
  { op="end" },
}

M.templates = {
  gMistCloudSpriteTemplate = {
    tileTag=10144,paletteTag=10144,callback="InitSwirlingFogAnim",
    oam={affine=false,objMode="blend",bpp=4,width=32,height=16},
    anim={kind="loop",frames={{tileOffset=0,duration=8},{tileOffset=8,duration=8}}},
  },
}

return M
