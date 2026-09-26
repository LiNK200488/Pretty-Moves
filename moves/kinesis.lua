local M = { id="KINESIS", name="Kinesis" }

-- Source-faithful Pokemon FireRed Move_KINESIS.
-- The native animation places a bent spoon beside the attacker, two zap-energy
-- strips beside it, then lets the spoon run its full 187-frame bend sequence
-- over the standard Psychic background with the original sound choreography.
M.soundIds = {182,189,169,187}

M.script = {
  { op="loadspritegfx", tag=10075 }, -- ANIM_TAG_ALERT
  { op="loadspritegfx", tag=10097 }, -- ANIM_TAG_BENT_SPOON
  { op="playsewithpan", sound=182, pan="attacker" }, -- SE_M_PSYBEAM

  { op="fadetobg", bg="psychic" },
  { op="waitbgfadeout" },
  { op="createvisualtask", task="AnimTask_SetPsychicBackground", priority=5 },
  { op="waitbgfadein" },

  { op="createsprite", template="gBentSpoonSpriteTemplate", anchor="attacker", priority=20, args={} },
  { op="createsprite", template="gKinesisZapEnergySpriteTemplate", anchor="attacker", priority=19, args={22,-8,0} },
  { op="createsprite", template="gKinesisZapEnergySpriteTemplate", anchor="attacker", priority=19, args={22,16,1} },
  { op="loopsewithpan", sound=189, pan="attacker", interval=21, count=2 }, -- SE_M_CONFUSE_RAY
  { op="delay", frames=60 },
  { op="playsewithpan", sound=169, pan="attacker" }, -- SE_M_DIZZY_PUNCH
  { op="delay", frames=30 },
  { op="loopsewithpan", sound=169, pan="attacker", interval=20, count=2 },
  { op="delay", frames=70 },
  { op="playsewithpan", sound=187, pan="attacker" }, -- SE_M_SWAGGER2
  { op="waitforvisualfinish" },

  { op="restorebg" },
  { op="waitbgfadeout" },
  { op="setarg", index=7, value=0xFFFF },
  { op="waitbgfadein" },
  { op="end" },
}

local spoonPlayer = {
  {tileOffset=8,duration=60,hFlip=true},
  {tileOffset=16,duration=5,hFlip=true},
  {tileOffset=8,duration=5,hFlip=true},
  {tileOffset=0,duration=5,hFlip=true},
  {tileOffset=8,duration=22,hFlip=true},
  -- ANIMCMD_LOOP(0) marks the beginning of the following loop section.
  {tileOffset=16,duration=5,hFlip=true},
  {tileOffset=8,duration=5,hFlip=true},
  {tileOffset=0,duration=5,hFlip=true},
  {tileOffset=8,duration=5,hFlip=true},
  -- ANIMCMD_LOOP(1): repeat the preceding four-frame section once.
  {tileOffset=16,duration=5,hFlip=true},
  {tileOffset=8,duration=5,hFlip=true},
  {tileOffset=0,duration=5,hFlip=true},
  {tileOffset=8,duration=5,hFlip=true},
  {tileOffset=8,duration=22,hFlip=true},
  {tileOffset=24,duration=3,hFlip=true},
  {tileOffset=32,duration=3,hFlip=true},
  {tileOffset=40,duration=22,hFlip=true},
}
local spoonOpponent={}
for i,f in ipairs(spoonPlayer) do
  spoonOpponent[i]={tileOffset=f.tileOffset,duration=f.duration}
end

local function zapFrames(h,v)
  local t={}
  for _,off in ipairs({0,8,16,24,32,40,48,0,8,16,24,32,40,48}) do
    t[#t+1]={tileOffset=off,duration=3,hFlip=h or nil,vFlip=v or nil}
  end
  return t
end

M.templates = {
  gBentSpoonSpriteTemplate = {
    tileTag=10097,paletteTag=10097,callback="AnimBentSpoon",deferredPrepare=true,
    oam={affine=false,objMode="normal",bpp=4,width=16,height=32},
    anim={kind="variants",variants={
      [0]={kind="once",frames=spoonPlayer},
      [1]={kind="once",frames=spoonOpponent},
    }},
  },
  gKinesisZapEnergySpriteTemplate = {
    tileTag=10075,paletteTag=10075,callback="AnimKinesisZapEnergy",deferredPrepare=true,
    oam={affine=false,objMode="normal",bpp=4,width=32,height=16},
    anim={kind="variants",variants={
      [0]={kind="once",frames=zapFrames(true,false)},
      [1]={kind="once",frames=zapFrames(true,true)},
      [2]={kind="once",frames=zapFrames(false,false)},
      [3]={kind="once",frames=zapFrames(false,true)},
    }},
  },
}

return M
