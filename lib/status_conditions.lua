-- Declarative FireRed status-condition feedback.
-- Major status ids use Gen1Recomp's names; aliases normalize readable/mod ids.
-- Choreography mirrors gBattleAnims_StatusConditions. Rendering/playback stays
-- in status_bridge.lua so move definitions never need status-specific logic.
local M = {}
M.__index = M

local function normalize(status)
  if type(status)=="table" then status=status.id or status.key or status.name or status.label end
  if status==nil then return nil end
  return tostring(status):upper():gsub("[%s%-]+","_")
end

local defs = {
  PSN = {
    id="PSN", name="Poison", duration=78,
    sounds={{id=141,frame=0,interval=13,count=6,pan="target"}}, -- SE_M_TOXIC
    effect={kind="poison", shakeX=1, shakeDuration=36,
      -- Status_Poison: AnimTask_BlendColorCycle, F_PAL_ATTACKER,
      -- delay 2, 2 blends, 0 -> 12 -> 0, RGB(30,0,31).
      paletteCycle={delay=2,numBlends=2,startAmount=0,targetAmount=12,stepAmount=2,color={30,0,31}}},
  },
  BRN = {
    id="BRN", name="Burn", duration=28,
    sounds={{id=137,frame=0,pan="target"}}, -- SE_M_FLAME_WHEEL
    effect={kind="burn", tag=10029, width=32, height=32}, -- ANIM_TAG_SMALL_EMBER
  },
  SLP = {
    id="SLP", name="Sleep", duration=60,
    sounds={{id=190,frame=0,pan="target"}}, -- SE_M_SNORE
    effect={kind="sleep", tag=10228, width=32, height=32}, -- ANIM_TAG_LETTER_Z
  },
  PAR = {
    id="PAR", name="Paralysis", duration=20,
    sounds={{id=112,frame=0,pan="target"}}, -- ElectricityEffect / SE_M_THUNDERBOLT2
    effect={kind="paralysis", tag=10011, width=16, height=16, shakeX=1, shakeDuration=10},
  },
  FRZ = {
    id="FRZ", name="Freeze", duration=50,
    sounds={{id=130,frame=0,pan=0},{id=235,frame=17,pan="target"}}, -- SE_M_ICY_WIND, SE_M_HAIL
    effect={kind="freeze", tag=10010, width=96, height=96, subsprites={
      {tileOffset=0,width=64,height=64,x=-48,y=-52},
      {tileOffset=64,width=64,height=32,x=-48,y=12},
      {tileOffset=96,width=32,height=64,x=16,y=-52},
      {tileOffset=128,width=32,height=32,x=16,y=12},
    }}, -- ANIM_TAG_ICE_CUBE composite from FireRed subsprite table
  },
  CONFUSION = {
    id="CONFUSION", name="Confusion", duration=90,
    sounds={{id=169,frame=0,interval=13,count=6,pan="target",overlap=true}}, -- SE_M_DIZZY_PUNCH; FireRed loopsewithpan retriggers without cutting the previous tail
    effect={kind="confusion", tag=10073, width=16, height=16}, -- ANIM_TAG_DUCK
  },
}

local aliases = {
  POISON="PSN", TOXIC="PSN", BURN="BRN", SLEEP="SLP",
  PRZ="PAR", PARALYSIS="PAR", PARALYZE="PAR", FREEZE="FRZ", FROZEN="FRZ",
  CONFUSED="CONFUSION",
}

function M.new()
  return setmetatable({},M)
end

function M:get(status)
  local key=normalize(status)
  key=aliases[key] or key
  return key and defs[key] or nil,key
end

function M:all()
  return {defs.PSN,defs.BRN,defs.SLP,defs.PAR,defs.FRZ,defs.CONFUSION}
end

function M:soundIds()
  local out,seen={},{}
  for _,def in ipairs(self:all()) do
    for _,s in ipairs(def.sounds or {}) do
      if s.id and not seen[s.id] then seen[s.id]=true; out[#out+1]=s.id end
    end
  end
  table.sort(out)
  return out
end

return M
