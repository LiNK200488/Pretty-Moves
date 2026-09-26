-- FireRed-style capture Poké Ball replacement.
--
-- Gen1Recomp remains authoritative for inventory, catch math, toss-chain
-- timing, target hide/show, caught/breakout flow and battle completion.  This
-- module listens to the semantic battle.ball_thrown event (which carries the
-- exact item id) and replaces the native Gen 1 ball sprites with the corresponding FireRed
-- ROM ball.  Gen1Recomp still owns the capture state machine and timing; this
-- module only filters its ball OAM and renders the selected FireRed ball in
-- the same place.
local M={}
M.__index=M

local TWO_PI=math.pi*2
local BALL_OPEN_SOUND=15 -- kept in soundIds for future full capture replacement

local BALLS={
  POKE_BALL    ={index=0, tag=55000, particleTag=55020},
  GREAT_BALL   ={index=1, tag=55001, particleTag=55021},
  SAFARI_BALL  ={index=2, tag=55002, particleTag=55022},
  ULTRA_BALL   ={index=3, tag=55003, particleTag=55023},
  MASTER_BALL  ={index=4, tag=55004, particleTag=55024},
  NET_BALL     ={index=5, tag=55005, particleTag=55025},
  DIVE_BALL    ={index=6, tag=55006, particleTag=55026},
  NEST_BALL    ={index=7, tag=55007, particleTag=55027},
  REPEAT_BALL  ={index=8, tag=55008, particleTag=55028},
  TIMER_BALL   ={index=9, tag=55009, particleTag=55029},
  LUXURY_BALL  ={index=10,tag=55010, particleTag=55030},
  PREMIER_BALL ={index=11,tag=55011, particleTag=55031},
}

local TOSS_ANIMS={TOSS_ANIM=true,GREATTOSS_ANIM=true,ULTRATOSS_ANIM=true}
local BALL_CHAIN_ANIMS={
  TOSS_ANIM=true,GREATTOSS_ANIM=true,ULTRATOSS_ANIM=true,
  POOF_ANIM=true,HIDEPIC_ANIM=true,SHAKE_ANIM=true,SHOWPIC_ANIM=true,
}
local PARTICLE_RADIUS_END=50
local PARTICLE_COUNT=16
local CAPTURE_TRAVEL_EXTRA=10
local STOCK_ITEM_USE_BEAT=20
-- Gen 1 toss rows contain eleven mode-0 frame blocks.  Mode 0 displays each
-- block for its row delay and then clears OAM for one extra frame.  Poke/Great
-- use delay 3 (11 * 4 = 44f); Ultra-tier uses delay 2 (11 * 3 = 33f).
local TOSS_ROW_FRAMES={TOSS_ANIM=44,GREATTOSS_ANIM=44,ULTRATOSS_ANIM=33}

local function layoutOffsetX(battle)
  if battle and battle.isWideBattleLayout and battle:isWideBattleLayout() then return 72 end
  return 0
end

local function drawCentered(g,img,x,y,angle,sx,sy)
  if not img then return end
  local w,h=img:getDimensions()
  g.draw(img,math.floor(x+0.5),math.floor(y+0.5),angle or 0,sx or 1,sy or sx or 1,w/2,h/2)
end

local function nativeSprites(battle, final)
  local p=battle and battle.animPlayer
  if not p then return nil end
  if final and p.finalSprites then
    local ok,res=pcall(p.finalSprites,p)
    if ok and res then return res end
  end
  local step=p.steps and p.steps[p.stepIndex]
  return step and step.sprites or nil
end

-- AnimPlayer keeps sprite coordinates in GBA OAM space. Convert the complete
-- current frame-block bounds back to screen space and use its centre. Toss and
-- SHAKE rows are ball-only frame blocks, so this puts the 16x16 FireRed ball
-- directly over the native Gen 1 ball instead of trying to guess its path.
local function centerFromSprites(battle,sprites)
  if not sprites or #sprites==0 then return nil end
  local minX,minY,maxX,maxY
  for _,s in ipairs(sprites) do
    if s.x and s.y and s.x>0 and s.x<168 and s.y>0 and s.y<160 then
      local x=s.x-8
      local y=s.y-16
      if not minX or x<minX then minX=x end
      if not minY or y<minY then minY=y end
      if not maxX or x+8>maxX then maxX=x+8 end
      if not maxY or y+8>maxY then maxY=y+8 end
    end
  end
  if not minX then return nil end
  local off=layoutOffsetX(battle)
  return (minX+maxX)/2+off,(minY+maxY)/2
end

local function nativeBallCenter(battle, final)
  return centerFromSprites(battle,nativeSprites(battle,final))
end

local function nativeTossDestination(battle)
  local p=battle and battle.animPlayer
  local steps=p and p.steps
  if not steps then return nil end
  for i=#steps,1,-1 do
    local x,y=centerFromSprites(battle,steps[i] and steps[i].sprites)
    if x then return x,y end
  end
  return nil
end

local function particleOffset(info,age)
  local i=info.index
  if i==4 then return 3 end -- Master
  if i==5 or i==6 then return 4 end -- Net / Dive
  if i==7 then return 5 end -- Nest
  if i==3 or i==8 or i==9 then return 7 end -- Ultra / Repeat / Timer
  if i==10 or i==11 then return (math.floor(age/4)%2==0) and 6 or 7 end
  local seq={0,1,2,0,2,1}
  return seq[(age%#seq)+1]
end

local function spawnParticle(st,index)
  local angle=((index%8)*32)*TWO_PI/256
  st.particles[#st.particles+1]={angle=angle,age=0,index=index}
  st.spawned=index+1
end

function M.new(opts)
  opts=opts or {}
  local self=setmetatable({},M)
  self.visualAssets=assert(opts.visualAssets,"pokeball_capture: visualAssets required")
  self.enabled=opts.enabled or function() return true end
  self.log=opts.log
  self.state=nil
  self.prepared=false
  self.patchedPlayer=nil
  self.originalDrawSprites=nil
  self.drawWrapper=nil
  self.stats={throws=0,ballSpecific=0,poofs=0,caught=0,breakouts=0,nativeSuppressed=0}
  return self
end

function M:soundIds() return {} end

function M:prepare()
  if self.prepared then return true end
  -- All twelve FireRed balls are separate compressed sheets/palettes. Prepare
  -- the three 16x16 ball frames and every 8x8 particle tile once at startup.
  for _,info in pairs(BALLS) do
    local ballDef={templates={captureBall={
      tileTag=info.tag,paletteTag=info.tag,oam={width=16,height=16,affine=true},
      anim={kind="once",frames={{tileOffset=0,duration=1},{tileOffset=4,duration=5},{tileOffset=8,duration=5}}},
      extraTileOffsets={0,4,8},
    }}}
    local ok,why=self.visualAssets:prepareDefinition(ballDef)
    if not ok then return nil,why end
    local particleDef={templates={captureParticle={
      tileTag=info.particleTag,paletteTag=info.particleTag,oam={width=8,height=8},
      extraTileOffsets={0,1,2,3,4,5,6,7},
    }}}
    ok,why=self.visualAssets:prepareDefinition(particleDef)
    if not ok then return nil,why end
  end
  self.prepared=true
  return true
end

local function replacementAnim(st,battle)
  if not st or st.battle~=battle or not st.tossStarted then return false end
  local anim=(battle.animPlaying and battle.animName) or nil
  return TOSS_ANIMS[anim] or anim=="POOF_ANIM" or anim=="SHAKE_ANIM" or (st.settled and anim==nil)
end

function M:detach()
  local p=self.patchedPlayer
  if p and self.drawWrapper and p.drawSprites==self.drawWrapper and self.originalDrawSprites then
    p.drawSprites=self.originalDrawSprites
  end
  self.patchedPlayer=nil
  self.originalDrawSprites=nil
  self.drawWrapper=nil
end

function M:ensureNativeFilter(battle)
  local p=battle and battle.animPlayer
  if not p or type(p.drawSprites)~="function" then return false end
  if self.patchedPlayer==p and self.drawWrapper and p.drawSprites==self.drawWrapper then return true end
  self:detach()
  local original=p.drawSprites
  local owner=self
  local wrapper
  wrapper=function(player,sprites,colorFn)
    if replacementAnim(owner.state,battle) then
      owner.stats.nativeSuppressed=owner.stats.nativeSuppressed+1
      return original(player,{},colorFn)
    end
    return original(player,sprites,colorFn)
  end
  p.drawSprites=wrapper
  self.patchedPlayer=p
  self.originalDrawSprites=original
  self.drawWrapper=wrapper
  return true
end

function M:reset()
  self.state=nil
  self:detach()
end

function M:onBallThrown(ev)
  if not self.enabled() or not ev or not ev.battle then return end
  local info=BALLS[ev.ball]
  if not info then
    -- Mod-added balls keep the native animation rather than being rendered as
    -- the wrong FireRed ball. The event still proves the hook is available.
    if self.log then self.log:warn("FireRed capture ball: unsupported ball id %s",tostring(ev.ball)) end
    return
  end
  self:ensureNativeFilter(ev.battle)
  -- `Ball_Toss` is played immediately before battle.ball_thrown is emitted.
  -- Start the FireRed ball on this same logic tick instead of inserting a
  -- pre-launch wait.  The current +10f tuning is preserved as
  -- extra TRAVEL time: the ball crosses the stock 20f ItemUseBall beat plus
  -- the native toss-row duration and arrives when the poof/capture beat begins.
  local predictedAnim=(ev.ball=="POKE_BALL" and "TOSS_ANIM")
      or (ev.ball=="GREAT_BALL" and "GREATTOSS_ANIM")
      or "ULTRATOSS_ANIM"
  local travelFrames=CAPTURE_TRAVEL_EXTRA+STOCK_ITEM_USE_BEAT+(TOSS_ROW_FRAMES[predictedAnim] or 44)
  self.state={
    battle=ev.battle,ball=ev.ball,info=info,caught=ev.caught and true or false,
    shakes=tonumber(ev.shakes) or 0,lastAnim=nil,animAge=0,totalAge=0,
    lastX=nil,lastY=nil,poofCount=0,poofAge=nil,particles={},spawned=0,
    settled=false,showSeen=false,tossStarted=false,
    predictedAnim=predictedAnim,travelFrames=travelFrames,
    arcStartX=32+layoutOffsetX(ev.battle),arcStartY=80,
    arcEndX=120+layoutOffsetX(ev.battle),arcEndY=34,
  }
  self.stats.throws=self.stats.throws+1
  self.stats.ballSpecific=self.stats.ballSpecific+1
  if self.state.caught then self.stats.caught=self.stats.caught+1 else self.stats.breakouts=self.stats.breakouts+1 end
end

local function beginPoof(self,st)
  st.poofCount=st.poofCount+1
  st.poofAge=0
  st.particles={}
  st.spawned=0
  spawnParticle(st,0)
  self.stats.poofs=self.stats.poofs+1
end

function M:afterHostUpdate(battle)
  local st=self.state
  if not st or st.battle~=battle then return end
  local anim=(battle.animPlaying and battle.animName) or nil
  if anim~=st.lastAnim then
    local prev=st.lastAnim
    st.lastAnim=anim
    st.animAge=0

    -- battle.ball_thrown fires before the stock ItemUseBall delay.  Do not
    -- let stale/previous animation state draw the replacement at the target
    -- before the actual toss row begins.  The first real toss row arms every
    -- capture visual from this point onward.
    if TOSS_ANIMS[anim] then
      st.tossStarted=true
      -- Now that AnimPlayer has compiled the real toss row, refine both the
      -- tier duration and exact destination.  This cannot create a jump: the
      -- arc is still continuous and only its remaining endpoint is corrected.
      st.predictedAnim=anim
      st.travelFrames=CAPTURE_TRAVEL_EXTRA+STOCK_ITEM_USE_BEAT+(TOSS_ROW_FRAMES[anim] or 44)
      local tx,ty=nativeTossDestination(battle)
      if tx then st.arcEndX,st.arcEndY=tx,ty end
    elseif not st.tossStarted then
      return
    end

    if anim=="POOF_ANIM" then
      beginPoof(self,st)
    elseif anim=="SHOWPIC_ANIM" then
      st.showSeen=true
      st.settled=false
    elseif anim=="SHAKE_ANIM" then
      st.settled=false
    elseif not anim and prev=="SHAKE_ANIM" and st.caught then
      -- Gen1Recomp intentionally leaves the captured ball's final OAM frame
      -- visible through the caught text. Keep our selected ball over it too.
      st.settled=true
    elseif not anim and prev=="SHOWPIC_ANIM" then
      self.state=nil
      return
    elseif not anim and prev=="POOF_ANIM" and not st.caught and st.shakes==0 then
      -- Clean miss: the ball chain ends after the first poof.
      if not st.poofAge or st.poofAge>PARTICLE_RADIUS_END/2+2 then self.state=nil return end
    end
  end
end

function M:afterUpdate()
  local st=self.state
  if not st then return end
  st.totalAge=st.totalAge+1
  st.animAge=st.animAge+1
  if st.poofAge~=nil then
    if st.spawned<PARTICLE_COUNT then spawnParticle(st,st.spawned) end
    st.poofAge=st.poofAge+1
    for i=#st.particles,1,-1 do
      local p=st.particles[i]
      p.age=p.age+1
      if math.max(0,p.age-1)*2>=PARTICLE_RADIUS_END then table.remove(st.particles,i) end
    end
    if #st.particles==0 and st.poofAge>PARTICLE_COUNT then st.poofAge=nil end
  end
  if st.lastAnim==nil and not st.caught and st.shakes==0
     and st.poofCount>=1 and st.poofAge==nil then
    self.state=nil
    return
  end
  -- Safety valve for cancelled/rebuilt battle queues.
  if st.totalAge>1200 then self.state=nil end
end

local function captureArcPosition(st)
  local frames=math.max(1,tonumber(st.travelFrames) or 1)
  local t=math.max(0,math.min(1,(tonumber(st.totalAge) or 0)/frames))
  local x=st.arcStartX+(st.arcEndX-st.arcStartX)*t
  local baseY=st.arcStartY+(st.arcEndY-st.arcStartY)*t
  -- FireRed uses a -40px horizontal-arc amplitude.  sin(pi*t) gives the
  -- same single upward bow while allowing the approved timing to be stretched.
  local y=baseY-math.sin(math.pi*t)*40
  return x,y,t
end

local function captureCenter(st,battle,anim)
  if not st.tossStarted or TOSS_ANIMS[anim] then
    local x,y=captureArcPosition(st)
    st.lastX,st.lastY=x,y
  elseif anim=="SHAKE_ANIM" then
    local x,y=nativeBallCenter(battle,false)
    if x then st.lastX,st.lastY=x,y end
  elseif st.settled then
    local x,y=nativeBallCenter(battle,true)
    if x then st.lastX,st.lastY=x,y end
  end
  -- FireRed capture arc ends at target Y-16. This is a sensible fallback on
  -- frames where the host has just switched animation rows and exposes no OAM.
  if not st.lastX then st.lastX=120+layoutOffsetX(battle) end
  if not st.lastY then st.lastY=24 end
  return st.lastX,st.lastY
end

-- Gen 1 SHAKE_ANIM is four 4-frame blocks at one coordinate:
-- rest, left-tilt, rest, right-tilt.  Each requested wobble also has a
-- 40-frame resting pause.  The native bitmap encoded the tilt in FRAMEBLOCK
-- 04/05, so a centre-following replacement needs to recreate that pose.
local function nativeShakePose(battle)
  local p=battle and battle.animPlayer
  local steps=p and p.steps
  local idx=p and p.stepIndex
  local cur=steps and idx and steps[idx]
  if not cur or cur.dur==40 then return 0,0 end

  -- Find the first non-pause step in this wobble.  This also handles the
  -- initial resting block that precedes the first 40-frame pause.
  local first=idx
  while first>1 do
    local prev=steps[first-1]
    if not prev or prev.dur==40 then break end
    first=first-1
  end
  local phase=((idx-first)%4)+1
  if phase==2 then return -2,-math.rad(18) end
  if phase==4 then return  2, math.rad(18) end
  return 0,0
end

local function ballTileFor(st,anim)
  if anim=="POOF_ANIM" and st.poofAge~=nil then
    local a=st.poofAge
    if a<5 then return 4 end
    if a<10 then return 8 end
  end
  return 0
end

function M:draw(battle)
  local st=self.state
  if not self.prepared or not st or st.battle~=battle or not (love and love.graphics) then return end
  local anim=(battle.animPlaying and battle.animName) or nil
  -- battle.ball_thrown follows Ball_Toss on the same logic tick, so the
  -- replacement is intentionally visible BEFORE the host toss row.  During
  -- that pre-row window it owns an explicit FireRed arc from the player side;
  -- this is what keeps launch locked to the sound without a target ghost.
  if st.tossStarted and anim and not BALL_CHAIN_ANIMS[anim] then return end
  local g=love.graphics
  local x,y=captureCenter(st,battle,anim)

  -- Ball-open particles are drawn first, matching the send-out layer's order.
  for _,p in ipairs(st.particles or {}) do
    local radius=math.min(48,math.max(0,p.age-1)*2)
    local px=x+math.sin(p.angle)*radius
    local py=(y-5)+math.cos(p.angle)*radius
    local off=particleOffset(st.info,p.age)
    local img=self.visualAssets:imageForTileOffset({tag=st.info.particleTag,paletteTag=st.info.particleTag},off)
    drawCentered(g,img,px,py,0,1,1)
  end

  local showBall=(not st.tossStarted) or TOSS_ANIMS[anim] or anim=="POOF_ANIM" or anim=="HIDEPIC_ANIM"
      or anim=="SHAKE_ANIM" or st.settled
  if showBall then
    local off=ballTileFor(st,anim)
    local img=self.visualAssets:imageForTileOffset({tag=st.info.tag,paletteTag=st.info.tag},off)
    local rot=0
    if not st.tossStarted or TOSS_ANIMS[anim] then
      rot=((st.totalAge*12)%360)*math.pi/180
    elseif anim=="SHAKE_ANIM" then
      local dx,wobble=nativeShakePose(battle)
      x=x+dx
      rot=wobble
    end
    drawCentered(g,img,x,y,rot,1,1)
  end
end

function M:info()
  local st=self.state
  return {
    prepared=self.prepared,enabled=self.enabled(),travelExtra=CAPTURE_TRAVEL_EXTRA,stats=self.stats,
    active=st and {ball=st.ball,caught=st.caught,shakes=st.shakes,lastAnim=st.lastAnim,
      animAge=st.animAge,totalAge=st.totalAge,travelFrames=st.travelFrames,poofCount=st.poofCount,settled=st.settled,tossStarted=st.tossStarted,x=st.lastX,y=st.lastY} or nil,
  }
end

return M
