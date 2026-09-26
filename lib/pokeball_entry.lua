-- Optional FireRed-style Poké Ball send-out presentation for trainer-owned
-- battlers.  The host keeps ownership of battle flow, cries, HUD timing,
-- switching and the actual battler grow-in.  This bridge only replaces the
-- player-side Gen 1 POOF row with FireRed's throw/open presentation and inserts
-- FireRed's 16-frame opponent-ball hold immediately before the host reveal.
local M={}
M.__index=M

local BALL_TAG=55000
local PARTICLE_TAG=55020
-- SpriteCB_PlayerMonSendOut_1 seeds a 25-step linear translation, but
-- SpriteCB_PlayerMonSendOut_2 intentionally runs the middle of that arc at
-- one-third speed.  Replaying that callback gives 43 visible flight frames;
-- the following callback opens the ball immediately (no landed hold).
local PLAYER_TRANSLATION_STEPS=25
local PLAYER_THROW_FRAMES=43
local PLAYER_ARC_STEP=math.floor(0x8000/PLAYER_TRANSLATION_STEPS)
local PLAYER_ARC_SLOW_STEP=math.floor(PLAYER_ARC_STEP/3)
local OPPONENT_HOLD_FRAMES=16
local BALL_FADE_FRAMES=14
local RELEASE_VISUAL_HEADSTART=3 -- keep the clearer v0.46.7 release tint onset
local PLAYER_ENTRY_TIMELINE_DELAY_FRAMES=24 -- user-tuned +24 total versus original timing
local OPPONENT_ENTRY_TIMELINE_DELAY_FRAMES=54 -- user-tuned +54 total versus original timing
local PARTICLE_SPAWN_FRAMES=16
local PARTICLE_RADIUS_END=50
local BALL_OPEN_SOUND=15 -- SE_BALL_OPEN
local TWO_PI=math.pi*2

local BALL_DEF={
  templates={
    gEntryPokeBall={
      tileTag=BALL_TAG,paletteTag=BALL_TAG,oam={width=16,height=16,affine=true},
      anim={kind="once",frames={
        {tileOffset=0,duration=1}, -- closed
        {tileOffset=4,duration=5}, -- opening 1
        {tileOffset=8,duration=5}, -- opening 2
      }},
    },
  },
}

local PARTICLE_DEF={
  templates={
    gEntryPokeBallParticle={
      tileTag=PARTICLE_TAG,paletteTag=PARTICLE_TAG,oam={width=8,height=8},
      anim={kind="loop",frames={
        {tileOffset=0,duration=1},
        {tileOffset=1,duration=1},
        {tileOffset=2,duration=1},
      }},
      extraTileOffsets={0,1,2},
    },
  },
}

local function clamp(v,a,b)
  if v<a then return a elseif v>b then return b end
  return v
end

local function lerp(a,b,t) return a+(b-a)*t end

local function buildPlayerThrowTimeline()
  local out={{progress=0,angle=0,rotateFrames=0}}
  local remaining=PLAYER_TRANSLATION_STEPS
  local angle=0
  local slowClock=0
  local rotating=false
  local rotateFrames=0
  local progress=0

  -- Mirrors SpriteCB_PlayerMonSendOut_2.  Outside arc angles 35..79 the
  -- translation advances one normal step per frame.  In that middle band,
  -- the callback divides the X/Y deltas by 3 and only lets the 25-step
  -- duration counter fall once every third frame.
  while remaining>0 do
    local hi=math.floor(angle/256)%256
    if hi>=35 and hi<80 then
      progress=progress+(1/(PLAYER_TRANSLATION_STEPS*3))
      angle=angle+PLAYER_ARC_SLOW_STEP
      slowClock=slowClock+1
      if not rotating then rotating=true end
      rotateFrames=rotateFrames+1
      if slowClock%3==0 then remaining=remaining-1 end
    else
      progress=progress+(1/PLAYER_TRANSLATION_STEPS)
      remaining=remaining-1
      angle=angle+PLAYER_ARC_STEP
      if rotating then rotateFrames=rotateFrames+1 end
    end
    out[#out+1]={
      progress=clamp(progress,0,1),
      angle=math.floor(angle/256)%256,
      rotateFrames=rotateFrames,
    }
  end
  return out
end

local PLAYER_THROW_TIMELINE=buildPlayerThrowTimeline()

local function queueContains(q,row)
  for _,v in ipairs(q or {}) do if v==row then return true end end
  return false
end

local function firstUnclaimedPoof(b)
  for _,row in ipairs(b.queue or {}) do
    if type(row)=="table" and row.anim=="POOF_ANIM" and not row._fireRedEntryClaimed then
      return row
    end
  end
end

local function firstRevealActIndex(b)
  for i,row in ipairs(b.queue or {}) do
    if type(row)=="table" and type(row.fn)=="function" and not row._fireRedEntrySkip then
      return i
    end
  end
end

local function isTrainerOpponent(b)
  if not b then return false end
  -- Wild encounters must never manufacture a Poké Ball around a wild mon.
  -- Link/trainer battles expose enemySendingOut but may not both carry .trainer.
  if b.safari or b.demo then return false end
  if b.kind=="wild" and not b.trainer then return false end
  return b.trainer~=nil or b.kind=="trainer" or b.kind=="link"
end

function M.new(opts)
  opts=opts or {}
  local self=setmetatable({},M)
  self.visualAssets=assert(opts.visualAssets,"pokeball_entry: visualAssets required")
  self.paletteRenderer=assert(opts.paletteRenderer,"pokeball_entry: paletteRenderer required")
  self.playSound=assert(opts.playSound,"pokeball_entry: playSound required")
  self.enabled=opts.enabled or function() return true end
  self.timelineDelay=opts.timelineDelay
  self.log=opts.log
  self.battle=nil
  self.states={}
  self.prepared=false
  self.stats={scheduled=0,player=0,opponent=0,opened=0,completed=0,cancelled=0}
  return self
end

function M:soundIds() return {BALL_OPEN_SOUND} end

function M:prepare()
  if self.prepared then return true end
  local ok,why=self.visualAssets:prepareDefinition(BALL_DEF)
  if not ok then return nil,why end
  ok,why=self.visualAssets:prepareDefinition(PARTICLE_DEF)
  if not ok then return nil,why end
  self.prepared=true
  return true
end

function M:attach(battle)
  if self.battle and self.battle~=battle then self:reset("new battle") end
  self.battle=battle
end

local function clearState(self,key,completed)
  local s=self.states[key]
  if not s then return end
  if s.paletteToken then self.paletteRenderer:clear(s.paletteToken) end
  if completed then self.stats.completed=self.stats.completed+1
  else self.stats.cancelled=self.stats.cancelled+1 end
  self.states[key]=nil
end

function M:reset(reason)
  for key in pairs(self.states) do clearState(self,key,false) end
  self.states={}
  self.battle=nil
end

local function classicTarget(side)
  -- FireRed uses different Y sources on the two sides:
  --   player:   BATTLER_COORD_Y_PIC_OFFSET + 24
  --   opponent: BATTLER_COORD_Y + 24
  -- Gen1Recomp grounds the classic 64 px player back pic at y=96, so its
  -- picture centre is y=64 and the FireRed-equivalent release point is 88.
  -- The opponent classic anchor is y=40, matching FireRed directly: 40+24=64.
  if side=="player" then return 40,88 end
  return 120,64
end

local function layoutOffsetX(battle)
  -- WideBattle keeps the 160px classic arena centred inside 304px.  The move
  -- bridge currently targets classic layout, but this harmless centring keeps
  -- the entry effect aligned should the option be used there.
  if battle and battle.isWideBattleLayout and battle:isWideBattleLayout() then
    return 72
  end
  return 0
end

local function makeState(b,side,battler,row,phase)
  local tx,ty=classicTarget(side)
  tx=tx+layoutOffsetX(b)
  return {
    battle=b,side=side,battler=battler,row=row,phase=phase,age=0,
    targetX=tx,targetY=ty,openAge=nil,particles={},spawned=0,
  }
end

function M:schedulePlayer(b)
  if self.states.player or not b.sendingOut or not b.player then return false end
  local row=firstUnclaimedPoof(b)
  if not row then return false end -- starter Pikachu / non-standard entrance
  row._fireRedEntryClaimed=true
  row._fireRedEntryOriginalAnim=row.anim
  row.anim=nil
  row.wait=PLAYER_THROW_FRAMES
  local s=makeState(b,"player",b.player,row,"pending")
  self.states.player=s
  self.stats.scheduled=self.stats.scheduled+1
  self.stats.player=self.stats.player+1
  return true
end

function M:scheduleOpponent(b)
  if self.states.enemy or not b.enemySendingOut or not b.enemy or not isTrainerOpponent(b) then return false end
  -- The reveal act is queued after _TrainerSentOutText.  Insert the FireRed
  -- opponent send-out hold directly before that act so the host keeps the mon
  -- hidden for the same 16 frames as SpriteCB_OpponentMonSendOut.
  local idx=firstRevealActIndex(b)
  if not idx then return false end
  local row={wait=OPPONENT_HOLD_FRAMES,_fireRedEntryOpponent=true}
  table.insert(b.queue,idx,row)
  local s=makeState(b,"opponent",b.enemy,row,"pending")
  self.states.enemy=s
  self.stats.scheduled=self.stats.scheduled+1
  self.stats.opponent=self.stats.opponent+1
  return true
end

local function startPendingIfFront(s,b)
  if s.phase~="pending" then return end
  if b.queue and b.queue[1]==s.row then
    s.phase=(s.side=="player") and "throw" or "hold"
    s.age=0
  elseif not queueContains(b.queue,s.row) and not b.waitFrames then
    -- The host cancelled/rebuilt the queue before this send-out reached the
    -- front.  The caller will discard this stale state.
    s.stale=true
  end
end

local function spawnParticle(s,index)
  local angle=((index%8)*32)*TWO_PI/256
  s.particles[#s.particles+1]={angle=angle,age=0,index=index}
  s.spawned=index+1
end

local function entryTimelineDelay(self,s)
  local base=(s and s.side=="opponent") and OPPONENT_ENTRY_TIMELINE_DELAY_FRAMES
      or PLAYER_ENTRY_TIMELINE_DELAY_FRAMES
  if self and type(self.timelineDelay)=="function" then
    local ok,value=pcall(self.timelineDelay,s and s.side or nil,s and s.battle or nil,base)
    value=ok and tonumber(value) or nil
    if value then return math.max(0,math.floor(value)) end
  end
  return base
end

local function startOpen(self,s,b)
  if s.openAge~=nil then return end
  s.phase="open"
  s.openAge=0
  s.age=0
  s.spawned=0
  s.particles={}
  -- SpriteCB_ReleaseMonFromBall launches the first particle task on the same
  -- callback that starts the opening frames and SE_BALL_OPEN.
  spawnParticle(s,0)
  self.stats.opened=self.stats.opened+1
  pcall(self.playSound,BALL_OPEN_SOUND,s.side=="player" and -64 or 63,b,1,true)
  s.paletteToken=self.paletteRenderer:install(b,function(battler)
    if battler~=s.battler or s.openAge==nil then return 0,nil end
    local visibleAge=(s.openAge or 0)+RELEASE_VISUAL_HEADSTART
    local amount=clamp(1-(visibleAge/BALL_FADE_FRAMES),0,1)
    return amount,{31,22,30} -- FireRed sBallOpenFadeColors[BALL_POKE]
  end)
end

function M:beforeUpdate(b)
  if not b then return end
  if self.battle~=b then self:attach(b) end

  -- Active send-outs finish even if the option is toggled off mid-animation;
  -- the option is sampled when the next send-out is scheduled.
  if self.enabled() then
    self:schedulePlayer(b)
    self:scheduleOpponent(b)
  end

  for key,s in pairs(self.states) do
    if s.battle~=b or s.battler==nil then
      clearState(self,key,false)
    else
      startPendingIfFront(s,b)
      if s.stale then
        clearState(self,key,false)
      end
    end
  end
end

-- Called immediately after the host battle update. The reveal act creates
-- growIn during that update; observing it here starts the FireRed ball-open
-- layer on the same rendered frame instead of one fixed step later.
function M:afterHostUpdate(b)
  if not b or b~=self.battle then return end
  for _,s in pairs(self.states) do
    local limit=(s.side=="player") and PLAYER_THROW_FRAMES or OPPONENT_HOLD_FRAMES
    local openAt=limit+entryTimelineDelay(self,s)
    if s.openAge==nil and (s.phase=="throw" or s.phase=="hold")
       and s.age>openAt and b.growIn and b.growIn.battler==s.battler then
      startOpen(self,s,b)
    end
  end
end

function M:afterUpdate()
  local completed={}
  for key,s in pairs(self.states) do
    if s.phase=="throw" or s.phase=="hold" then
      s.age=s.age+1
      local limit=(s.side=="player") and PLAYER_THROW_FRAMES or OPPONENT_HOLD_FRAMES
      -- Keep Gen1Recomp's native reveal timing untouched. The player keeps
      -- Current user tuning: player +24 total, trainer/link opponent +54 total.
      -- Opening, sparkles and SE_BALL_OPEN
      -- stay locked together within each side's timeline.
      if s.age>limit+entryTimelineDelay(self,s) then startOpen(self,s,s.battle) end
    elseif s.phase=="open" then
      -- Particle 0 is launched by startOpen on the opening callback itself;
      -- FireRed then creates one additional particle per frame through 15.
      if s.spawned<PARTICLE_SPAWN_FRAMES then spawnParticle(s,s.spawned) end
      s.openAge=s.openAge+1
      for i=#s.particles,1,-1 do
        local p=s.particles[i]
        p.age=p.age+1
        -- Step1 consumes one frame; Step2 grows radius by 2 until 50.
        if math.max(0,p.age-1)*2>=PARTICLE_RADIUS_END then table.remove(s.particles,i) end
      end
      if s.openAge>BALL_FADE_FRAMES and #s.particles==0 then
        completed[#completed+1]=key
      end
    end
  end
  for _,key in ipairs(completed) do clearState(self,key,true) end
end

local function ballFrameFor(s)
  if s.phase~="open" then return 0 end
  local a=s.openAge or 0
  if a<5 then return 4 end
  if a<10 then return 8 end
  return nil
end

local function ballPosition(s)
  if s.side~="player" or s.phase~="throw" then return s.targetX,s.targetY,0 end
  local visualAge=math.max(0,(s.age or 0)-entryTimelineDelay(self,s))
  local idx=math.floor(clamp(visualAge,0,PLAYER_THROW_FRAMES))
  local sample=PLAYER_THROW_TIMELINE[idx+1] or PLAYER_THROW_TIMELINE[#PLAYER_THROW_TIMELINE]
  local t=sample.progress
  local sx=32+layoutOffsetX(s.battle)
  local sy=70
  local x=lerp(sx,s.targetX,t)
  local y=lerp(sy,s.targetY,t)+math.sin((sample.angle or 0)*TWO_PI/256)*-30
  -- FireRed starts affine anim 4 (25/256 turn per frame) on entering the
  -- slowed middle segment and keeps it running until the ball opens.
  local rot=((sample.rotateFrames or 0)*25%256)*TWO_PI/256
  return x,y,rot
end
local PARTICLE_OFFSETS={0,1,2,0,2,1}
local function drawCentered(g,img,x,y,angle,sx,sy)
  if not img then return end
  local w,h=img:getDimensions()
  g.draw(img,math.floor(x+0.5),math.floor(y+0.5),angle or 0,sx or 1,sy or sx or 1,w/2,h/2)
end

function M:draw(b)
  if not self.prepared or b~=self.battle or not (love and love.graphics) then return end
  local g=love.graphics
  for _,key in ipairs({"enemy","player"}) do
    local s=self.states[key]
    if s and s.phase~="pending" then
      local timelineVisible = s.phase=="open" or (s.age or 0)>=entryTimelineDelay(self,s)
      if timelineVisible then
      -- Ball-open particles use the FireRed 8x8 particle sheet and the exact
      -- eight-direction radial callback: radius += 2 until 50 pixels.
      for _,p in ipairs(s.particles) do
        local radius=math.min(48,math.max(0,p.age-1)*2)
        local x=s.targetX+math.sin(p.angle)*radius
        local y=(s.targetY-5)+math.cos(p.angle)*radius
        local seq=((p.age-1)%6)+1
        local off=PARTICLE_OFFSETS[seq]
        local img=self.visualAssets:imageForTileOffset({tag=PARTICLE_TAG,paletteTag=PARTICLE_TAG},off)
        local flip=(seq==4) and -1 or 1
        drawCentered(g,img,x,y,0,flip,1)
      end

      local off=ballFrameFor(s)
      if off~=nil then
        local img=self.visualAssets:imageForTileOffset({tag=BALL_TAG,paletteTag=BALL_TAG},off)
        local x,y,rot=ballPosition(s)
        drawCentered(g,img,x,y,rot,1,1)
      end
      end
    end
  end
end

function M:info()
  local active={}
  for key,s in pairs(self.states) do
    active[key]={phase=s.phase,age=s.age,openAge=s.openAge,particles=#(s.particles or {}),targetX=s.targetX,targetY=s.targetY}
  end
  return {
    prepared=self.prepared,enabled=self.enabled(),active=active,
    stats=self.stats,ballTag=BALL_TAG,particleTag=PARTICLE_TAG,
    playerThrowFrames=PLAYER_THROW_FRAMES,playerTranslationSteps=PLAYER_TRANSLATION_STEPS,
    opponentHoldFrames=OPPONENT_HOLD_FRAMES,playerEntryTimelineDelayFrames=PLAYER_ENTRY_TIMELINE_DELAY_FRAMES,
    opponentEntryTimelineDelayFrames=OPPONENT_ENTRY_TIMELINE_DELAY_FRAMES,
    activePlayerEntryTimelineDelayFrames=self.states.player and entryTimelineDelay(self,self.states.player) or nil,
    activeOpponentEntryTimelineDelayFrames=self.states.enemy and entryTimelineDelay(self,self.states.enemy) or nil,
    releaseVisualHeadstart=RELEASE_VISUAL_HEADSTART,
  }
end

return M
