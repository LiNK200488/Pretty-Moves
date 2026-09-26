-- Shared FireRed status-feedback bridge.
-- Status events are emitted synchronously while Gen1Recomp constructs the turn.
-- A single battle-lifetime animNext owner marks the dedicated native status row
-- at creation time, before playback can begin; applyHitFx then becomes only the
-- timing seam that starts the FireRed status animation and SFX.
local M={}; M.__index=M

local function anchorFor(battler)
  if battler and battler.isPlayer then
    return {x=40,y=72,side="player"}
  end
  return {x=120,y=40,side="opponent"}
end


local HOST_RELATIVE_Y_SCALE=(64-40)/(80-40) -- shared FireRed -> host relative-Y scale
local function hostRelativeYDelta(v)
  return (tonumber(v) or 0)*HOST_RELATIVE_Y_SCALE
end

local function imageDimensions(img,scale)
  if not img then return nil,nil end
  local get=img.getDimensions
  if type(get)=="function" then
    local ok,w,h=pcall(get,img)
    if ok and w and h then
      scale=scale or 1
      return w*scale,h*scale
    end
  end
  local gw,gh=img.getWidth,img.getHeight
  if type(gw)=="function" and type(gh)=="function" then
    local okw,w=pcall(gw,img); local okh,h=pcall(gh,img)
    if okw and okh and w and h then
      scale=scale or 1
      return w*scale,h*scale
    end
  end
  return nil,nil
end

local function battlerSpriteDimensions(battle,battler)
  local function resolveImage(ref)
    if not ref then return nil end
    if battle and type(battle.picImage)=="function" then
      local ok,img=pcall(battle.picImage,battle,ref)
      if ok and img then return img end
    end
    return ref
  end
  local w,h
  if battler and battler.isPlayer and battle then
    w,h=imageDimensions(resolveImage(battle.playerBackPic),2)
  end
  if not w then w,h=imageDimensions(resolveImage(battler and battler.sprite),1) end
  if not w then
    if battler and battler.isPlayer then w,h=64,64 else w,h=56,56 end
  end
  return math.max(2,math.floor(w)),math.max(4,math.floor(h))
end

local function battlerLocalEffectY(battle,battler,anchor)
  local _,h=battlerSpriteDimensions(battle,battler)
  local bottom=((battler and battler.isPlayer) or (anchor and anchor.side=="player")) and 96 or 56
  local top=bottom-h
  return top+(h/4)
end

local function panFor(symbol, affected)
  if type(symbol)=="number" then return symbol end
  if symbol=="target" or symbol=="attacker" then return affected.side=="player" and -64 or 63 end
  return 0
end

local function statusSpriteAnim(animKind)
  if animKind=="basicFire" then
    return {kind="loop",frames={
      {tileOffset=0,duration=4},{tileOffset=16,duration=4},
      {tileOffset=32,duration=4},{tileOffset=48,duration=4},
      {tileOffset=64,duration=4},
    }}
  elseif animKind=="confusion" then
    -- FireRed sAnim_ConfusionDuck_0. The hFlip state is intentionally not
    -- baked into extraction; the important ROM frame sequence is exact here.
    return {kind="loop",frames={
      {tileOffset=0,duration=8},{tileOffset=4,duration=8},
      {tileOffset=0,duration=8},{tileOffset=8,duration=8},
    }}
  end
  return {kind="dummy",frames={{tileOffset=0,duration=1}}}
end

local function spriteEvent(tag,w,h,animKind)
  return {tag=tag,paletteTag=tag,oam={width=w,height=h},anim=statusSpriteAnim(animKind)}
end

function M.new(opts)
  local self=setmetatable({},M)
  self.battleSpace=assert(opts.battleSpace, "status_bridge: battleSpace is required")
  self.conditions=assert(opts.conditions)
  self.visualAssets=assert(opts.visualAssets)
  self.playSound=assert(opts.playSound)
  self.selfHitFeedback=opts.selfHitFeedback
  self.log=opts.log
  self.paletteRenderer=assert(opts.paletteRenderer)
  self.pending=nil; self.active=nil; self.confuseSeen=setmetatable({},{__mode="k"})
  self.stats={triggered=0,replaced=0,completed=0,timeouts=0,confusion=0}
  return self
end

function M:prepare()
  for _,def in ipairs(self.conditions:all()) do
    local fx=def.effect
    if fx and fx.tag then
      local holder
      if fx.kind=="freeze" and fx.subsprites then
        local templates={}
        for i,part in ipairs(fx.subsprites) do
          templates["freeze"..i]={
            tileTag=fx.tag,paletteTag=fx.tag,
            oam={width=part.width,height=part.height},
            anim={kind="dummy",frames={{tileOffset=part.tileOffset,duration=1}}},
          }
        end
        holder={templates=templates}
      else
        local animKind=(fx.kind=="burn") and "basicFire" or fx.kind
        holder={templates={status={tileTag=fx.tag,paletteTag=fx.tag,oam={width=fx.width,height=fx.height},anim=statusSpriteAnim(animKind)}}}
      end
      local ok,err=self.visualAssets:prepareDefinition(holder)
      if not ok then return nil,"status "..def.id.." asset: "..tostring(err) end
    end
  end
  return true
end

local function isStatusHitForPending(p,hit)
  if not (p and hit) then return false end
  if hit.fireRedStatus then return true end
  local t=hit.animType
  -- Gen1Recomp's dedicated status/applying rows use type 6 when the player
  -- affects the enemy and type 3 for the reverse direction. Do not consume
  -- the damaging move's earlier type 5/2 row: that was the bug that let the
  -- real native Burn/Poison/etc. row survive and play after our replacement.
  if t==6 or t==3 then return true end
  -- Burn/Freeze/Paralysis inflicted on the player have no later auxiliary
  -- status row in EffectRegistry; their added-effect damage row (type 2) is
  -- the only host timing seam, so consume that one for those conditions.
  local id=p.def and p.def.id
  if p.affected and p.affected.isPlayer and t==2
     and (id=="BRN" or id=="FRZ" or id=="PAR") then return true end
  return false
end

local function poisonPaletteBlend(active,battler)
  if not active or battler~=active.affected then return 0,nil end
  local fx=active.def and active.def.effect or nil
  local cycle=fx and fx.paletteCycle or nil
  if not cycle then return 0,nil end

  -- FireRed BeginNormalPaletteFade alternates BG/OBJ palette updates and uses
  -- deltaY=2. For an OBJ-only battler palette, delay=2 therefore presents a
  -- new blend level every four updates: 0,2,4,...12 and back to 0. This is
  -- AnimTask_BlendColorCycle's exact poison ramp rather than a smooth tint.
  local stepAmount=math.max(1,tonumber(cycle.stepAmount) or 2)
  local framesPerStep=(tonumber(cycle.delay) or 0)+2
  local start=tonumber(cycle.startAmount) or 0
  local target=tonumber(cycle.targetAmount) or 0
  local distance=math.abs(target-start)
  if distance==0 then return start/16,cycle.color end
  local steps=math.ceil(distance/stepAmount)
  local legFrames=(steps+1)*framesPerStep
  local f=active.frame or 0
  local amount
  if f<legFrames then
    local n=math.min(steps,math.floor(f/framesPerStep))
    amount=(target>=start) and math.min(target,start+n*stepAmount) or math.max(target,start-n*stepAmount)
  elseif f<legFrames*2 then
    local n=math.min(steps,math.floor((f-legFrames)/framesPerStep))
    amount=(target>=start) and math.max(0,target-n*stepAmount) or math.min(0,target+n*stepAmount)
  else
    amount=0
  end
  return math.max(0,math.min(16,amount))/16,cycle.color
end

function M:installPaletteHook(active)
  if not active or active.paletteHook then return end
  local fx=active.def and active.def.effect or nil
  if not (fx and fx.paletteCycle) then return end
  active.paletteHook=self.paletteRenderer:install(active.battle,function(battler)
    return poisonPaletteBlend(active,battler)
  end)
end

function M:clearPaletteHook(active)
  if not (active and active.paletteHook) then return end
  self.paletteRenderer:clear(active.paletteHook)
  active.paletteHook=nil
end

function M:startDefinition(battle,def,affected)
  if not (battle and def) then return end
  if self.active then self:clearMotion(); self:clearPaletteHook(self.active) end
  local anchor=anchorFor(affected or battle.enemy)
  self.active={battle=battle,def=def,affected=affected or battle.enemy,anchor=anchor,frame=0,played={}}
  self:installPaletteHook(self.active)
  battle.waitFrames=math.max(tonumber(battle.waitFrames) or 0,def.duration or 1)
  self.stats.replaced=self.stats.replaced+1
  self:fireSounds(0)
end

function M:consumeApplyHitFx(battle,hit)
  local p=self.pending
  if p and p.battle==battle and not self.active and isStatusHitForPending(p,hit) then
    self:startPending(battle,hit)
    return true
  end
  return false
end

-- Gen1Recomp emits battle.status_inflicted synchronously from StatusRegistry
-- *before* EffectRegistry queues the native secondary-status animation row.
-- Own battle.animNext once for the lifetime of the battle, then turn only that
-- immediately-following dedicated status row into a FireRed marker as it is
-- created. This is synchronous: the native row can never start before we see
-- it, unlike next-frame queue scanning.
local NATIVE_STATUS_ANIMS = {
  ENEMY_HUD_SHAKE_ANIM=true,
  SHAKE_SCREEN_ANIM=true,
}

-- Gen1Recomp has dedicated per-turn sleep rows, separate from the generic
-- applying/status rows above. FireRed uses the same shared Sleep status
-- animation whenever the sleeping battler is shown as asleep, so replace
-- these rows centrally instead of teaching individual sleep-causing moves
-- about them.
local NATIVE_SLEEP_ANIMS = {
  SLP_ANIM=true,
  SLP_PLAYER_ANIM=true,
}

-- Confusion has the same host split as Sleep: Gen1Recomp queues CONF_ANIM /
-- CONF_PLAYER_ANIM when a confused battler acts. Replace those centrally so
-- the FireRed duck-circle feedback is used on every confusion turn.
local NATIVE_CONFUSION_ANIMS = {
  CONF_ANIM=true,
  CONF_PLAYER_ANIM=true,
}

local function replaceRowWithStatus(owner,b,row,def,affected,pending)
  if type(row)~="table" or not def then return false end
  -- Replace the host animation row itself. updateQueue executes item.fn before
  -- considering anim/hit fields, so later host writes to animDelayed or hit
  -- cannot resurrect the native status animation.
  row.anim=nil
  row.hit=nil
  row.fn=function()
    if pending and owner.pending==pending then owner.pending=nil end
    owner:startDefinition(b,def,affected)
  end
  owner.stats.marked=(owner.stats.marked or 0)+1
  return true
end

local function isFullyParalyzedMessage(msg)
  local text=tostring(msg or ""):lower()
  return text:find("fully paralyzed",1,true)~=nil
end

-- Gen1Recomp has no animNext row for a fully-paralyzed turn. The semantic
-- seam is sayStatusMsg(): Status.beforeMove produces the message there after
-- deciding that PAR cancels the action. Queue FireRed Status_Paralysis
-- immediately after that message, independent of the move that inflicted PAR.
function M:attachStatusInterrupt(battle)
  if not battle or self.statusMsgOwner then return end
  local original=battle.sayStatusMsg
  if type(original)~="function" then
    if self.log then self.log:warn("FireRed paralysis feedback unavailable: battle.sayStatusMsg missing") end
    return
  end
  local owner=self
  local wrapper
  wrapper=function(b,user,msg,...)
    local result=original(b,user,msg,...)
    if user and user.mon and user.mon.status=="PAR" and isFullyParalyzedMessage(msg) then
      local def=owner.conditions:get("PAR")
      if def and type(b.actNext)=="function" then
        b:actNext(function() owner:startDefinition(b,def,user) end)
      end
    end
    return result
  end
  battle.sayStatusMsg=wrapper
  self.statusMsgOwner={battle=battle,original=original,wrapper=wrapper}
end

function M:detachStatusInterrupt(battle)
  local d=self.statusMsgOwner
  if not d then return end
  if (not battle or d.battle==battle) and d.battle.sayStatusMsg==d.wrapper then
    d.battle.sayStatusMsg=d.original
  end
  self.statusMsgOwner=nil
end

-- Gen1Recomp represents confusion self-damage by queueing the native POUND
-- animation from inside BattleState:statusInterrupt. Detect only that exact
-- call context, suppress the Gen1 POUND visual, and schedule the shared
-- FireRed hit flash + generic FireRed damage SFX at the same queue position.
function M:attachSelfHitInterrupt(battle)
  if not battle or self.selfHitOwner then return end
  local original=battle.statusInterrupt
  if type(original)~="function" then return end
  local owner=self
  local wrapper
  wrapper=function(b,...)
    owner.inStatusInterrupt=(owner.inStatusInterrupt or 0)+1
    local ok,r1,r2,r3,r4=pcall(original,b,...)
    owner.inStatusInterrupt=math.max(0,(owner.inStatusInterrupt or 1)-1)
    if not ok then error(r1,0) end
    return r1,r2,r3,r4
  end
  battle.statusInterrupt=wrapper
  self.selfHitOwner={battle=battle,original=original,wrapper=wrapper}
end

function M:detachSelfHitInterrupt(battle)
  local d=self.selfHitOwner
  if not d then return end
  if (not battle or d.battle==battle) and d.battle.statusInterrupt==d.wrapper then
    d.battle.statusInterrupt=d.original
  end
  self.selfHitOwner=nil
  self.inStatusInterrupt=0
end

function M:attach(battle)
  if not battle or self.animNextOwner then return true end
  local original=battle.animNext
  if type(original)~="function" then
    if self.log then self.log:warn("FireRed status feedback unavailable: battle.animNext missing") end
    return nil,"battle.animNext missing"
  end
  local owner=self
  local wrapper
  wrapper=function(b,name,isPlayer,...)
    local row=original(b,name,isPlayer,...)
    -- Status-infliction rows are created synchronously after
    -- battle.status_inflicted. Replace that exact row in place.
    local p=owner.pending

    -- Self-confusion is the only place Gen1Recomp queues POUND from inside
    -- statusInterrupt. A real Pound move is queued outside this wrapper
    -- context, so it remains completely untouched.
    if name=="POUND" and (owner.inStatusInterrupt or 0)>0 then
      local affected=isPlayer and b.enemy or b.player
      row.anim=nil
      row.hit=nil
      row.fn=function()
        if owner.selfHitFeedback then
          owner.selfHitFeedback(b,affected)
        end
      end
      owner.stats.selfHit=(owner.stats.selfHit or 0)+1
      return row
    end

    if p and p.battle==b and not owner.active and NATIVE_STATUS_ANIMS[name] then
      if replaceRowWithStatus(owner,b,row,p.def,p.affected,p) then
        p.queuedRow=row
        return row
      end
    end

    -- Gen1Recomp queues a dedicated sleep animation every turn a sleeping
    -- battler is unable to act. Replace it directly from the battler's live
    -- status, exactly like the residual burn/poison path below. This also
    -- suppresses the original Gen1 Z animation rather than layering over it.
    if NATIVE_SLEEP_ANIMS[name] then
      local affected=isPlayer and b.player or b.enemy
      local status=affected and affected.mon and affected.mon.status
      local def=owner.conditions:get(status)
      if def and def.id=="SLP" then
        replaceRowWithStatus(owner,b,row,def,affected,nil)
        return row
      end
    end

    if NATIVE_CONFUSION_ANIMS[name] then
      local affected=isPlayer and b.player or b.enemy
      local def=owner.conditions:get("CONFUSION")
      if def then
        replaceRowWithStatus(owner,b,row,def,affected,nil)
        return row
      end
    end

    -- Gen1Recomp uses BURN_PSN_ANIM for the end-of-turn residual tick of
    -- both burn and poison. FireRed instead executes `statusanimation` for
    -- the afflicted battler, i.e. the same status-specific animation/SFX
    -- used elsewhere. Derive the definition from the battler's live status
    -- and replace the residual row before the native animation can run.
    if name=="BURN_PSN_ANIM" then
      local affected=isPlayer and b.player or b.enemy
      local status=affected and affected.mon and affected.mon.status
      local def=owner.conditions:get(status)
      if def and (def.id=="BRN" or def.id=="PSN") then
        replaceRowWithStatus(owner,b,row,def,affected,nil)
      end
    end
    return row
  end
  battle.animNext=wrapper
  self.animNextOwner={battle=battle,original=original,wrapper=wrapper}
  self:attachStatusInterrupt(battle)
  self:attachSelfHitInterrupt(battle)
  return true
end

function M:detach(battle)
  local a=self.animNextOwner
  if not a then return end
  if (not battle or a.battle==battle) and a.battle.animNext==a.wrapper then
    a.battle.animNext=a.original
  end
  self.animNextOwner=nil
  self:detachStatusInterrupt(battle)
  self:detachSelfHitInterrupt(battle)
end

function M:onStatus(ev)
  if not ev or not ev.battle then return end
  local def=self.conditions:get(ev.status)
  if not def then return end
  -- FireRed Status_Paralysis is a turn-interrupt animation, not an extra
  -- infliction beat. Thunder Wave (or any other source) supplies its own
  -- move animation; the shared PAR feedback is triggered by sayStatusMsg.
  if def.id=="PAR" then return end
  self.stats.triggered=self.stats.triggered+1
  local p={battle=ev.battle,def=def,affected=ev.target or ev.user,age=0}
  self.pending=p

  -- Primary status moves (Sleep Powder, PoisonPowder, Thunder Wave, etc.)
  -- do not all receive a later dedicated native status-animation row in
  -- Gen1Recomp. Queue one generic fallback at the host's action seam. If a
  -- dedicated row is created synchronously after this event, attach() marks
  -- p.queuedRow and this fallback becomes a no-op; the exact row replacement
  -- remains authoritative. Damaging secondary statuses are deliberately not
  -- handled here so their existing applyHitFx/dedicated-row timing is kept.
  -- Every landed major status gets one generic action-seam fallback. Do not
  -- infer whether the inflicting move is primary from move-table metadata:
  -- Gen1Recomp does not guarantee that source can be resolved through the
  -- battle's move table for every status path (Thunder Wave exposed this).
  -- If the host creates a dedicated status row synchronously, attach() marks
  -- p.queuedRow and that exact row replacement remains authoritative. For a
  -- status path with no dedicated row, this fallback guarantees the shared
  -- FireRed status feedback still runs. This is status-wide, not move-specific.
  if type(ev.battle.actNext)=="function" then
    local owner=self
    ev.battle:actNext(function()
      if not p.queuedRow and not owner.active then
        if owner.pending==p then owner.pending=nil end
        owner:startDefinition(ev.battle,p.def,p.affected)
      end
    end)
    p.fallbackQueued=true
  end
end

function M:observeConfusion(battle)
  if not battle then return end
  local seen=self.confuseSeen[battle] or {}
  self.confuseSeen[battle]=seen
  for _,battler in ipairs({battle.player,battle.enemy}) do
    if battler then
      local count
      if type(battle.volatile)=="function" then
        local ok,v=pcall(battle.volatile,battle,battler)
        if ok and type(v)=="table" then count=v.confuseCount end
      end
      if count==nil and type(battler.volatile)=="table" then count=battler.volatile.confuseCount end
      local old=seen[battler]
      if count and not old then self:onConfusion({battle=battle,target=battler}) end
      seen[battler]=count and true or nil
    end
  end
end

function M:onConfusion(ev)
  if not ev or not ev.battle then return end
  local def=self.conditions:get("CONFUSION")
  self.stats.triggered=self.stats.triggered+1; self.stats.confusion=self.stats.confusion+1
  local p={battle=ev.battle,def=def,affected=ev.target or ev.user,age=0}
  self.pending=p

  -- Confusion is a volatile condition, so Gen1Recomp does not emit the major
  -- status_inflicted event that drives onStatus(). The transition observer is
  -- therefore responsible for scheduling the initial FireRed confusion beat.
  -- Use the same action seam as primary major statuses so it starts after the
  -- move row, not on top of Confuse Ray itself. A native CONF_* row, if one is
  -- created first, replaces the same pending intent and wins via queuedRow.
  if type(ev.battle.actNext)=="function" then
    local owner=self
    ev.battle:actNext(function()
      if not p.queuedRow and not owner.active then
        if owner.pending==p then owner.pending=nil end
        owner:startDefinition(ev.battle,p.def,p.affected)
      end
    end)
    p.fallbackQueued=true
  end
end

function M:startPending(battle,hit)
  local p=self.pending; if not p then return end
  local affected=p.affected or battle.enemy
  self.pending=nil
  -- Fallback seam for status flows that do not create a dedicated animNext
  -- row (notably BRN/FRZ/PAR inflicted on the player). Dedicated rows are
  -- replaced directly in attach() and never reach this path.
  self:startDefinition(battle,p.def,affected)
end

function M:beforeUpdate()
  local p=self.pending
  if p then
    p.age=p.age+1
    if p.age>240 then
      self.pending=nil; self.stats.timeouts=self.stats.timeouts+1
      if self.log then self.log:warn("FireRed status feedback timed out waiting for native applying-FX row") end
    end
  end
end

function M:fireSounds(frame)
  local a=self.active; if not a then return end
  for si,s in ipairs(a.def.sounds or {}) do
    local count=s.count or 1; local interval=s.interval or 0
    for n=0,count-1 do
      local at=(s.frame or 0)+n*interval
      local key=si..":"..n
      if at==frame and not a.played[key] then
        a.played[key]=true
        local ok,err=self.playSound(s.id,panFor(s.pan,a.anchor),a.battle,s.gain,s.overlap)
        if not ok and self.log then self.log:warn("FireRed status SFX %s failed: %s",tostring(s.id),tostring(err)) end
      end
    end
  end
end

function M:afterUpdate()
  local a=self.active; if not a then return end
  if not a.battle or a.battle.dead then self.active=nil; return end
  a.frame=a.frame+1; self:fireSounds(a.frame)
  if a.frame>=(a.def.duration or 1) then self:clearMotion(); self:clearPaletteHook(a); self.active=nil; self.stats.completed=self.stats.completed+1 end
end

local function drawCenteredImage(g,img,x,y,w,h,alpha,displayScale)
  if not img then return end
  local ds=displayScale or 1
  g.setColor(1,1,1,alpha or 1)
  g.draw(img,math.floor(x-(w*ds)/2+0.5),math.floor(y-(h*ds)/2+0.5),0,ds,ds)
  g.setColor(1,1,1,1)
end

-- FireRed's Sleep Z uses a 32x32 affine OBJ container, but the affine
-- animation immediately shrinks/rotates that container and continues
-- shrinking it for 24 frames. Draw around the same visual centre so the
-- OAM box size is not mistaken for the on-screen glyph size.
local function drawSleepZ(g,img,x,y,w,h,age,side,displayScale)
  if not img then return end
  local matrixScale=0x100 + 0x14 + math.min(age,24)*0x8
  local visualScale=0x100 / matrixScale
  local rotDeg=(side=="player") and (30-age) or (-30+age)
  local rot=rotDeg*math.pi/180
  -- Sleep's FireRed script positions the affine sprite directly from the
  -- battler coordinate plus args (4,-10). Unlike the older generic status
  -- helper, this is already the sprite centre in battle-screen space; applying
  -- the helper's extra -20px centre shift is what pushed the foe Z through
  -- the top edge. Keep the FireRed centre coordinate intact here.
  local cx=x
  local cy=y
  g.setColor(1,1,1,1)
  visualScale=visualScale*(displayScale or 1)
  g.draw(img,cx,cy,rot,visualScale,visualScale,w/2,h/2)
  g.setColor(1,1,1,1)
end

function M:draw(battle)
  local a=self.active; if not a or a.battle~=battle or not (love and love.graphics) then return end
  local g=love.graphics; local f=a.frame; local x,y=a.anchor.x,a.anchor.y
  local fx=a.def.effect or {}; local kind=fx.kind
  if kind=="poison" then
    -- FireRed shakes the afflicted mon for the visible poison beat. Battler
    -- motion itself is handled through the host picFx path below.
    return
  end
  local animKind=(kind=="burn") and "basicFire" or kind
  local ev=spriteEvent(fx.tag,fx.width or 16,fx.height or 16,animKind)
  local img=self.visualAssets:imageFor(ev,f)
  if kind=="burn" then
    -- FireRed Status_Burn uses gBurnFlameSpriteTemplate with (-24,+24) ->
    -- (+24,+24) around the target. AnimBurnFlame mirrors the X arguments,
    -- then delegates to AnimTravelDiagonally. Use the same host-local anchor
    -- and relative-Y conversion as target-local move effects; no legacy status
    -- draw offset is required.
    local localY=battlerLocalEffectY(a.battle,a.affected,a.anchor)
    local burnY=localY+hostRelativeYDelta(24)
    for _,start in ipairs({0,4,8}) do
      local age=f-start
      if age>=0 and age<20 then
        local t=age/20
        drawCenteredImage(g,img,x+24-48*t,burnY,fx.width,fx.height,1,self.battleSpace.spriteDisplayScale())
      end
    end
  elseif kind=="sleep" then
    -- Status_Sleep launches two identical Z sprites 30 frames apart with
    -- args (4,-10,16,0,0). AnimSleepLetterZ advances y by data0/0x28 with
    -- data0 += 16 each frame: exactly 0.4 px/frame upward. Its x drift is
    -- 0.2 px/frame, mirrored by battler side. The FireRed affine program
    -- handles the visible shrink/rotation in drawSleepZ above.
    local dir=(a.anchor.side=="player") and -1 or 1
    for _,start in ipairs({0,30}) do
      local age=f-start
      if age>=0 and age<30 then
        drawSleepZ(g,img,x+4+dir*(age*0.2),y-10-(age*0.4),fx.width,fx.height,age,a.anchor.side,self.battleSpace.spriteDisplayScale())
      end
    end
  elseif kind=="paralysis" then
    local pts={{5,0,0},{-5,10,2},{15,20,4},{-15,-10,6},{25,0,8},{-8,8,10},{2,-8,12},{-20,15,14}}
    for _,p in ipairs(pts) do
      local age=f-p[3]
      if age>=0 and age<5 and img then
        -- FireRed AnimElectricity uses target base coordinates directly and
        -- destroys each spark after its 5-frame timer. No generic -36 shift.
        g.setColor(1,1,1,1)
        local ds=self.battleSpace.spriteDisplayScale()
        g.draw(img,math.floor(x+p[1]-(fx.width*ds)/2+0.5),math.floor(y+p[2]-(fx.height*ds)/2+0.5),0,ds,ds)
      end
    end
  elseif kind=="freeze" then
    -- FireRed Status_Freeze does not use a single 32x32 icon.
    -- AnimTask_FrozenIceCube builds one 96x96 ice overlay from four ROM
    -- subsprites (64x64, 64x32, 32x64, 32x32) around the target. The task
    -- begins immediately; SE_M_HAIL is the delayed beat at frame 17.
    local alpha
    if f<10 then
      alpha=math.max(0,math.min(9,f+1))/16
    elseif f<40 then
      alpha=9/16
    elseif f<50 then
      alpha=math.max(0,49-f)/16
    end
    if alpha and alpha>0 then
      local evFreeze={tag=fx.tag,paletteTag=fx.tag}
      for _,part in ipairs(fx.subsprites or {}) do
        local ice=self.visualAssets:imageForTileOffset(evFreeze,part.tileOffset)
        if ice then
          local ds=self.battleSpace.spriteDisplayScale()
          g.setColor(1,1,1,alpha)
          g.draw(ice,math.floor(x+part.x*ds+0.5),math.floor(y+part.y*ds+0.5),0,ds,ds)
        end
      end
      g.setColor(1,1,1,1)
    end
  elseif kind=="confusion" then
    -- FireRed creates the ducks directly on ANIM_TARGET at y - 15 and then
    -- applies Cos(angle,30) / Sin(angle,10). Do not pass these coordinates
    -- through the generic burn renderer: confusion uses FireRed's own
    -- target-centre orbit geometry and therefore keeps its dedicated path.
    local phases={0,51,102,153,204}
    if f<90 then
      for i=1,5 do
        local phase=phases[i]
        local dir=(a.anchor.side=="player") and 3 or -3
        local angle=((phase+f*dir)%256)*math.pi*2/256
        local dx=math.cos(angle)*30
        local dy=math.sin(angle)*10
        local duck=self.visualAssets:imageFor(ev,f)
        if duck then
          g.setColor(1,1,1,1)
          local ds=self.battleSpace.spriteDisplayScale()
          g.draw(duck,
            math.floor(x+dx-((fx.width or 16)*ds)/2+0.5),
            math.floor(y-15+dy-((fx.height or 16)*ds)/2+0.5),
            0,ds,ds)
          g.setColor(1,1,1,1)
        end
      end
    end
  end
end

function M:applyBattlerMotion(battle)
  local a=self.active
  if not a or a.battle~=battle then return end
  local fx=a.def.effect or {}; if fx.kind~="poison" and fx.kind~="paralysis" then return end
  if type(battle.picFxFor)~="function" then return end
  local ok,pf=pcall(battle.picFxFor,battle,a.affected)
  if not ok or type(pf)~="table" then return end
  if a.baseOx==nil then a.baseOx=pf.ox or 0; a.baseOy=pf.oy or 0; a.picFx=pf end
  if a.frame<(fx.shakeDuration or 36) then
    local cadence=(fx.kind=="paralysis") and 1 or 2
    pf.ox=a.baseOx+((math.floor(a.frame/cadence)%2==0) and (fx.shakeX or 1) or -(fx.shakeX or 1))
  else pf.ox=a.baseOx end
end

function M:clearMotion()
  local a=self.active
  if a and a.picFx then a.picFx.ox=a.baseOx or 0; a.picFx.oy=a.baseOy or 0 end
end

function M:reset(battle)
  if self.active then self:clearPaletteHook(self.active) end
  self:clearMotion(); self.pending=nil; self.active=nil
  if battle then self.confuseSeen[battle]=nil end
end

function M:info()
  return {active=self.active~=nil,pending=self.pending~=nil,triggered=self.stats.triggered,marked=self.stats.marked or 0,replaced=self.stats.replaced,completed=self.stats.completed,timeouts=self.stats.timeouts,confusion=self.stats.confusion,selfHit=self.stats.selfHit or 0}
end

return M
