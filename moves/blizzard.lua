local M = { id="BLIZZARD", name="Blizzard" }

-- FireRed Move_BLIZZARD. Damage/accuracy/freeze logic remains Gen1Recomp-owned.
M.script = {
  { op="loadspritegfx", tag=10141 }, -- ANIM_TAG_ICE_CRYSTALS
  { op="monbg", battler="def_partner" },
  { op="fadetobg", bg={byAttackerSide={player="highspeed_opponent",opponent="highspeed_player"}} },
  { op="waitbgfadeout" },
  { op="createvisualtask", task="AnimTask_StartSlidingBg", priority=5, args={-2304,0,1,-1} },
  { op="waitbgfadein" },
  { op="waitforvisualfinish" },
  { op="panse", sound=146, from="attacker", to="target", increment=2, delay=0 },
  { op="call", label="BlizzardIceCrystals" },
  { op="call", label="BlizzardIceCrystals" },
  { op="playsewithpan", sound=147, pan="target" },
  { op="waitforvisualfinish" },
  { op="call", label="IceCrystalEffectLong" },
  { op="waitforvisualfinish" },
  { op="clearmonbg", battler="def_partner" },
  { op="delay", frames=20 },
  { op="restorebg" },
  { op="waitbgfadeout" },
  { op="setarg", index=7, value=0xFFFF },
  { op="waitbgfadein" },
  { op="end" },
}

local pairs = {
  {-10,  0},
  {-15,-10},
  { -5, 10},
  {-10,-20},
  {-20, 15},
  {-15,-20},
  {-25, 20},
}
local beam={}
for _,p in ipairs(pairs) do
  beam[#beam+1]={op="createsprite",template="gSwirlingSnowballSpriteTemplate",anchor="attacker",priority=40,args={0,p[1],0,p[1],72,1}}
  beam[#beam+1]={op="createsprite",template="gBlizzardIceCrystalSpriteTemplate",anchor="attacker",priority=40,args={0,p[2],0,p[2],80,0,0,1}}
  beam[#beam+1]={op="delay",frames=3}
end
beam[#beam+1]={op="return"}

local hitCoords = {
  {"gIceCrystalHitLargeSpriteTemplate",-10,-10},
  {"gIceCrystalHitSmallSpriteTemplate", 10, 20},
  {"gIceCrystalHitLargeSpriteTemplate",-29,  0},
  {"gIceCrystalHitSmallSpriteTemplate", 29,-20},
  {"gIceCrystalHitLargeSpriteTemplate", -5, 10},
  {"gIceCrystalHitSmallSpriteTemplate", 17,-12},
  {"gIceCrystalHitLargeSpriteTemplate",-20,  0},
  {"gIceCrystalHitSmallSpriteTemplate",-15, 15},
  {"gIceCrystalHitSmallSpriteTemplate", 26, -5},
  {"gIceCrystalHitSmallSpriteTemplate",  0,  0},
  {"gIceCrystalHitLargeSpriteTemplate", 20,  2},
}
local hits={}
for i,p in ipairs(hitCoords) do
  hits[#hits+1]={op="createsprite",template=p[1],anchor="target",priority=2,args={p[2],p[3],1}}
  hits[#hits+1]={op="playsewithpan",sound=130,pan="target"}
  if i<#hitCoords then hits[#hits+1]={op="delay",frames=4} end
end
hits[#hits+1]={op="return"}

M.labels={BlizzardIceCrystals=beam,IceCrystalEffectLong=hits}
M.templates={
  gSwirlingSnowballSpriteTemplate={tileTag=10141,paletteTag=10141,callback="AnimSwirlingSnowball",oam={width=8,height=8},anim={kind="dummy",frames={{tileOffset=7,duration=1}}}},
  gBlizzardIceCrystalSpriteTemplate={tileTag=10141,paletteTag=10141,callback="AnimMoveParticleBeyondTarget",oam={width=16,height=16},anim={kind="dummy",frames={{tileOffset=8,duration=1}}}},
  gIceCrystalHitLargeSpriteTemplate={tileTag=10141,paletteTag=10141,callback="AnimIceEffectParticle",oam={width=8,height=16,objMode="blend",affine=true},anim={kind="dummy",frames={{tileOffset=4,duration=1}}}},
  gIceCrystalHitSmallSpriteTemplate={tileTag=10141,paletteTag=10141,callback="AnimIceEffectParticle",oam={width=8,height=8,objMode="blend",affine=true},anim={kind="dummy",frames={{tileOffset=6,duration=1}}}},
}
return M
