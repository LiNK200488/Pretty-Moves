local M = { id="STRING_SHOT", name="String Shot" }

-- Exact FireRed Move_STRING_SHOT choreography. Eighteen WEB_THREAD sprites
-- launch one frame apart from attacker to target with the native sine-wave
-- callback, then three STRING wrap sprites flicker on the target for 51 ticks.
M.soundIds = {122,123}

M.script = {
  { op="loadspritegfx", tag=10179 }, -- ANIM_TAG_STRING
  { op="loadspritegfx", tag=10180 }, -- ANIM_TAG_WEB_THREAD
  { op="monbg", battler="def_partner" },
  { op="delay", frames=0 },
  { op="createsprite", template="gSimplePaletteBlendSpriteTemplate", anchor="attacker", priority=5,
    args={"bg",2,0,9,"black"} },
  { op="waitforvisualfinish" },
  { op="loopsewithpan", sound=122, pan="attacker", interval=9, count=6 }, -- SE_M_STRING_SHOT
  { op="createsprite", template="gWebThreadSpriteTemplate", anchor="target", priority=2, args={20,0,512,20,1} },
  { op="delay", frames=1 },
  { op="createsprite", template="gWebThreadSpriteTemplate", anchor="target", priority=2, args={20,0,512,20,1} },
  { op="delay", frames=1 },
  { op="createsprite", template="gWebThreadSpriteTemplate", anchor="target", priority=2, args={20,0,512,20,1} },
  { op="delay", frames=1 },
  { op="createsprite", template="gWebThreadSpriteTemplate", anchor="target", priority=2, args={20,0,512,20,1} },
  { op="delay", frames=1 },
  { op="createsprite", template="gWebThreadSpriteTemplate", anchor="target", priority=2, args={20,0,512,20,1} },
  { op="delay", frames=1 },
  { op="createsprite", template="gWebThreadSpriteTemplate", anchor="target", priority=2, args={20,0,512,20,1} },
  { op="delay", frames=1 },
  { op="createsprite", template="gWebThreadSpriteTemplate", anchor="target", priority=2, args={20,0,512,20,1} },
  { op="delay", frames=1 },
  { op="createsprite", template="gWebThreadSpriteTemplate", anchor="target", priority=2, args={20,0,512,20,1} },
  { op="delay", frames=1 },
  { op="createsprite", template="gWebThreadSpriteTemplate", anchor="target", priority=2, args={20,0,512,20,1} },
  { op="delay", frames=1 },
  { op="createsprite", template="gWebThreadSpriteTemplate", anchor="target", priority=2, args={20,0,512,20,1} },
  { op="delay", frames=1 },
  { op="createsprite", template="gWebThreadSpriteTemplate", anchor="target", priority=2, args={20,0,512,20,1} },
  { op="delay", frames=1 },
  { op="createsprite", template="gWebThreadSpriteTemplate", anchor="target", priority=2, args={20,0,512,20,1} },
  { op="delay", frames=1 },
  { op="createsprite", template="gWebThreadSpriteTemplate", anchor="target", priority=2, args={20,0,512,20,1} },
  { op="delay", frames=1 },
  { op="createsprite", template="gWebThreadSpriteTemplate", anchor="target", priority=2, args={20,0,512,20,1} },
  { op="delay", frames=1 },
  { op="createsprite", template="gWebThreadSpriteTemplate", anchor="target", priority=2, args={20,0,512,20,1} },
  { op="delay", frames=1 },
  { op="createsprite", template="gWebThreadSpriteTemplate", anchor="target", priority=2, args={20,0,512,20,1} },
  { op="delay", frames=1 },
  { op="createsprite", template="gWebThreadSpriteTemplate", anchor="target", priority=2, args={20,0,512,20,1} },
  { op="delay", frames=1 },
  { op="createsprite", template="gWebThreadSpriteTemplate", anchor="target", priority=2, args={20,0,512,20,1} },
  { op="delay", frames=1 },
  { op="waitforvisualfinish" },
  { op="playsewithpan", sound=123, pan="target" }, -- SE_M_STRING_SHOT2
  { op="createsprite", template="gStringWrapSpriteTemplate", anchor="target", priority=2, args={0,10} },
  { op="delay", frames=4 },
  { op="createsprite", template="gStringWrapSpriteTemplate", anchor="target", priority=2, args={0,-2} },
  { op="delay", frames=4 },
  { op="createsprite", template="gStringWrapSpriteTemplate", anchor="target", priority=2, args={0,22} },
  { op="waitforvisualfinish" },
  { op="clearmonbg", battler="def_partner" },
  { op="delay", frames=1 },
  { op="waitforvisualfinish" },
  { op="createsprite", template="gSimplePaletteBlendSpriteTemplate", anchor="attacker", priority=5,
    args={"bg",2,9,0,"black"} },
  { op="end" },
}

M.templates = {
  gSimplePaletteBlendSpriteTemplate = {
    controller=true, callback="AnimSimplePaletteBlend",
  },
  gWebThreadSpriteTemplate = {
    tileTag=10180, paletteTag=10180, callback="AnimTranslateWebThread",
    oam={affine=false,objMode="normal",bpp=4,width=8,height=8},
    anim={kind="dummy",frames={{tileOffset=0,duration=1}}},
  },
  gStringWrapSpriteTemplate = {
    tileTag=10179, paletteTag=10179, callback="AnimStringWrap",
    oam={affine=false,objMode="normal",bpp=4,width=64,height=32},
    anim={kind="dummy",frames={{tileOffset=0,duration=1}}},
  },
}

return M
