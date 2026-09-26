-- Shared all-move precache manager.
-- Keeps first-use work out of individual move execution. Move files stay data-only.
local M = {}
M.__index = M

local function classicAnchors(userIsPlayer)
  local player = {x=40, y=64, yRaw=64, x2=40, yPicOffset=64, side="player", position="player_left"}
  local enemy  = {x=120,y=40, yRaw=40, x2=120,yPicOffset=40, side="opponent",position="opponent_left"}
  if userIsPlayer then return player,enemy end
  return enemy,player
end

function M.new(opts)
  opts=opts or {}
  local self=setmetatable({},M)
  self.registry=assert(opts.registry)
  self.visual=assert(opts.visual)
  self.visualAssets=assert(opts.visualAssets)
  self.log=opts.log
  self.plans={}
  self.chargePlans={}
  self.trapPlans={}
  self.stats={moves=0,textures=0,plans=0,visualFailures=0,audioWarmups=0,audioFailures=0}
  self.visualReady=false
  self.audioReady=false
  return self
end

function M:prepareVisuals()
  if self.visualReady then return true end
  for _,move in ipairs(self.registry:all()) do
    local ok,err=self.visualAssets:prepareMove(move)
    if not ok then
      self.stats.visualFailures=self.stats.visualFailures+1
      return nil,"visual precache failed for "..tostring(move.id)..": "..tostring(err)
    end
    self.stats.moves=self.stats.moves+1
    self.plans[move.id]={}
    for _,userIsPlayer in ipairs({true,false}) do
      local attacker,target=classicAnchors(userIsPlayer)
      local side=userIsPlayer and "player" or "enemy"
      if move.alternatingAnimTurn then
        self.plans[move.id][side]={}
        for animTurn=0,1 do
          local okPlan,plan=pcall(self.visual.compile,move,{attacker=attacker,target=target,animTurn=animTurn})
          if not okPlan or not plan or not plan.durationFrames or plan.durationFrames<1 then
            self.stats.visualFailures=self.stats.visualFailures+1
            return nil,"plan precache failed for "..tostring(move.id).." animation turn "..tostring(animTurn)
          end
          self.plans[move.id][side][animTurn]=plan
          self.stats.plans=self.stats.plans+1
        end
      else
        local okPlan,plan=pcall(self.visual.compile,move,{attacker=attacker,target=target})
        if not okPlan or not plan or not plan.durationFrames or plan.durationFrames<1 then
          self.stats.visualFailures=self.stats.visualFailures+1
          return nil,"plan precache failed for "..tostring(move.id)
        end
        self.plans[move.id][side]=plan
        self.stats.plans=self.stats.plans+1
      end
      if move.chargeFlattened then
        self.chargePlans[move.id]=self.chargePlans[move.id] or {}
        local okCharge,chargePlan=pcall(self.visual.compile,move,{attacker=attacker,target=target,phase="charge"})
        if not okCharge or not chargePlan or not chargePlan.durationFrames or chargePlan.durationFrames<1 then
          self.stats.visualFailures=self.stats.visualFailures+1
          return nil,"charge plan precache failed for "..tostring(move.id)
        end
        self.chargePlans[move.id][side]=chargePlan
        self.stats.plans=self.stats.plans+1
      end
      if move.trapContinuationFlattened then
        self.trapPlans[move.id]=self.trapPlans[move.id] or {}
        local okTrap,trapPlan=pcall(self.visual.compile,move,{attacker=attacker,target=target,phase="trap_continuation"})
        if not okTrap or not trapPlan or not trapPlan.durationFrames or trapPlan.durationFrames<1 then
          self.stats.visualFailures=self.stats.visualFailures+1
          return nil,"trap-continuation plan precache failed for "..tostring(move.id)
        end
        self.trapPlans[move.id][side]=trapPlan
        self.stats.plans=self.stats.plans+1
      end
    end
  end
  self.visualReady=true
  return true
end

function M:plan(move,userIsPlayer,animTurn)
  local byMove=self.plans[move and move.id]
  if byMove then
    local plan=byMove[userIsPlayer and "player" or "enemy"]
    if move and move.alternatingAnimTurn and type(plan)=="table" then
      plan=plan[(math.floor(tonumber(animTurn) or 0) % 2)]
    end
    if plan then return plan end
  end
  local attacker,target=classicAnchors(userIsPlayer)
  return self.visual.compile(move,{attacker=attacker,target=target,animTurn=animTurn})
end

function M:chargePlan(move,userIsPlayer)
  local byMove=self.chargePlans[move and move.id]
  local plan=byMove and byMove[userIsPlayer and "player" or "enemy"]
  if plan then return plan end
  local attacker,target=classicAnchors(userIsPlayer)
  return self.visual.compile(move,{attacker=attacker,target=target,phase="charge"})
end

function M:trapPlan(move,userIsPlayer)
  local byMove=self.trapPlans[move and move.id]
  local plan=byMove and byMove[userIsPlayer and "player" or "enemy"]
  if plan then return plan end
  local attacker,target=classicAnchors(userIsPlayer)
  return self.visual.compile(move,{attacker=attacker,target=target,phase="trap_continuation"})
end

function M:warmAudio(audio,data)
  if self.audioReady then return true end
  if not audio or type(audio.precache)~="function" then return nil,"audio precache unavailable" end
  local ok,err=audio.precache(data)
  if not ok then
    self.stats.audioFailures=self.stats.audioFailures+1
    return nil,err
  end
  self.audioReady=true
  self.stats.audioWarmups=self.stats.audioWarmups+1
  return true
end

function M:info()
  local i={}
  for k,v in pairs(self.stats) do i[k]=v end
  i.visualReady=self.visualReady
  i.audioReady=self.audioReady
  return i
end

return M
