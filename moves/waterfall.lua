local M = { id="WATERFALL", name="Waterfall" }

M.soundIds = {135,209}

-- Canonical FireRed Move_WATERFALL / RisingWaterHitEffect.
M.script = {
  { op="loadspritegfx", tag=10148 }, -- ANIM_TAG_WATER_IMPACT
  { op="loadspritegfx", tag=10155 }, -- ANIM_TAG_SMALL_BUBBLES
  { op="loadspritegfx", tag=10141 }, -- ANIM_TAG_ICE_CRYSTALS (small bubble pair)
  { op="monbg", battler="def_partner" },
  { op="setalpha", eva=12, evb=8 },
  { op="createvisualtask", task="AnimTask_ShakeMon", priority=5, args={"attacker",0,2,23,1} },
  { op="delay", frames=5 },

  { op="playsewithpan", sound=135, pan="attacker" },
  { op="createsprite", template="gSmallBubblePairSpriteTemplate", anchor="attacker", priority=2, args={10,10,25,"attacker"} },
  { op="delay", frames=4 },
  { op="playsewithpan", sound=135, pan="attacker" },
  { op="createsprite", template="gSmallBubblePairSpriteTemplate", anchor="attacker", priority=2, args={-15,0,25,"attacker"} },
  { op="delay", frames=4 },
  { op="playsewithpan", sound=135, pan="attacker" },
  { op="createsprite", template="gSmallBubblePairSpriteTemplate", anchor="attacker", priority=2, args={20,10,25,"attacker"} },
  { op="delay", frames=4 },
  { op="playsewithpan", sound=135, pan="attacker" },
  { op="createsprite", template="gSmallBubblePairSpriteTemplate", anchor="attacker", priority=2, args={0,-10,25,"attacker"} },
  { op="delay", frames=4 },
  { op="playsewithpan", sound=135, pan="attacker" },
  { op="createsprite", template="gSmallBubblePairSpriteTemplate", anchor="attacker", priority=2, args={-10,15,25,"attacker"} },
  { op="delay", frames=4 },
  { op="playsewithpan", sound=135, pan="attacker" },
  { op="createsprite", template="gSmallBubblePairSpriteTemplate", anchor="attacker", priority=2, args={25,20,25,"attacker"} },
  { op="delay", frames=4 },
  { op="playsewithpan", sound=135, pan="attacker" },
  { op="createsprite", template="gSmallBubblePairSpriteTemplate", anchor="attacker", priority=2, args={-20,20,25,"attacker"} },
  { op="delay", frames=4 },
  { op="playsewithpan", sound=135, pan="attacker" },
  { op="createsprite", template="gSmallBubblePairSpriteTemplate", anchor="attacker", priority=2, args={12,0,25,"attacker"} },
  { op="waitforvisualfinish" },
  { op="delay", frames=10 },
  { op="createsprite", template="gHorizontalLungeSpriteTemplate", anchor="attacker", priority=2, args={6,5} },
  { op="delay", frames=6 },
  { op="call", label="RisingWaterHitEffect" },
  { op="waitforvisualfinish" },
  { op="clearmonbg", battler="def_partner" },
  { op="blendoff" },
  { op="end" },
}

local rising = {}
local ys = {20,15,10,5,0,-5,-10,-15,-20}
for i,y in ipairs(ys) do
  if i == 1 then
    rising[#rising+1] = { op="playsewithpan", sound=209, pan="target" }
    rising[#rising+1] = { op="createvisualtask", task="AnimTask_ShakeMon2", priority=5, args={"target",4,0,17,1} }
  end
  rising[#rising+1] = { op="createsprite", template="gWaterHitSplatSpriteTemplate", anchor="attacker", priority=3, args={0,y,"target",1} }
  rising[#rising+1] = { op="createsprite", template="gSmallDriftingBubblesSpriteTemplate", anchor="attacker", priority=4, args={0,y} }
  rising[#rising+1] = { op="createsprite", template="gSmallDriftingBubblesSpriteTemplate", anchor="attacker", priority=4, args={0,y} }
  if i < #ys then rising[#rising+1] = { op="delay", frames=2 } end
end
rising[#rising+1] = { op="return" }
M.labels = { RisingWaterHitEffect = rising }

M.templates = {
  gSmallBubblePairSpriteTemplate = {
    tileTag=10141,paletteTag=10141,callback="AnimSmallBubblePair",
    oam={affine=false,objMode="normal",bpp=4,width=8,height=8},
    anim={kind="loop",frames={{tileOffset=12,duration=6},{tileOffset=13,duration=6}}},
  },
  gHorizontalLungeSpriteTemplate = {
    controller=true,callback="DoHorizontalLunge",
    oam={affine=false,objMode="normal",bpp=4,width=8,height=8},
    anim={kind="dummy",frames={}},
  },
  gWaterHitSplatSpriteTemplate = {
    tileTag=10148,paletteTag=10148,callback="AnimHitSplatBasic",
    oam={affine=true,objMode="blend",bpp=4,width=32,height=32},
    anim={kind="dummy",frames={{tileOffset=0,duration=1}}},
  },
  gSmallDriftingBubblesSpriteTemplate = {
    tileTag=10155,paletteTag=10155,callback="AnimSmallDriftingBubbles",
    oam={affine=false,objMode="normal",bpp=4,width=8,height=8},
    anim={kind="dummy",frames={{tileOffset=8,duration=1}}},
  },
}

return M
