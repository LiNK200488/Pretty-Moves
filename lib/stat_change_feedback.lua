-- Shared FireRed stat-stage feedback bridge.
--
-- FireRed presents B_ANIM_STATS_CHANGE only after the move animation has
-- finished. Gen1Recomp mutates battler stage values while it is still building
-- the turn queue, so observing the value change is NOT itself a playback seam.
--
-- This bridge therefore has two separate jobs:
--   1. observe successful stage mutations and remember them;
--   2. bind that pending feedback to the move animation row and insert one
--      queue row immediately after it.
--
-- The second row is the only place allowed to start FireRed stat feedback.
-- There is deliberately no frame-count fallback: a guessed timeout can race
-- ahead of a long move animation, which is exactly the timing bug this module
-- exists to avoid.
local M={}; M.__index=M

local STAT_KEYS={"attack","defense","special","specialAttack","specialDefense","speed","accuracy","evasion"}
local STAT_PALETTE={
  attack=2, defense=1, accuracy=3, speed=4, evasion=6,
  special=7, specialAttack=7, specialDefense=8,
}

local function battlerKey(b)
  if not b then return nil end
  if b.isPlayer~=nil then return b.isPlayer and "player" or "enemy" end
  return tostring(b)
end

local function stagesFor(battle,battler)
  if type(battler)=="table" and type(battler.stages)=="table" then return battler.stages end
  local key=battlerKey(battler)
  if battle and type(battle.stages)=="table" and key and type(battle.stages[key])=="table" then return battle.stages[key] end
  return {}
end

local function copyStages(src)
  local out={}; src=type(src)=="table" and src or {}
  for _,k in ipairs(STAT_KEYS) do if type(src[k])=="number" then out[k]=src[k] end end
  for k,v in pairs(src) do if out[k]==nil and type(v)=="number" then out[k]=v end end
  return out
end

local function compare(previous,current,battle,battler)
  local out,seen={},{}
  for stat,now in pairs(current) do
    seen[stat]=true
    local before=previous[stat] or 0; local delta=now-before
    if delta~=0 then
      out[#out+1]={battle=battle,battler=battler,side=battlerKey(battler),stat=stat,before=before,after=now,delta=delta,direction=delta>0 and "up" or "down",sharply=math.abs(delta)>=2}
    end
  end
  for stat,before in pairs(previous) do
    if not seen[stat] and before~=0 then
      out[#out+1]={battle=battle,battler=battler,side=battlerKey(battler),stat=stat,before=before,after=0,delta=-before,direction=before<0 and "up" or "down",sharply=math.abs(before)>=2}
    end
  end
  return out
end

local function anchorFor(b)
  return (b and b.isPlayer) and {x=40,y=72,side="player"} or {x=120,y=40,side="opponent"}
end
local function panFor(b) return b and b.isPlayer and -64 or 63 end

local function queueIndex(battle,row)
  if not (battle and type(battle.queue)=="table" and row) then return nil end
  for i,candidate in ipairs(battle.queue) do if candidate==row then return i end end
  return nil
end

local function resolveMoveRow(action)
  if not (action and action.battle) then return nil end
  local b=action.battle
  if action.row and queueIndex(b,action.row) then return action.row end
  local published=b.moveAnimRow
  if type(published)=="table" and queueIndex(b,published) then
    action.row=published
    return published
  end
  -- battle.move_used can arrive one update before moveAnimRow is published.
  -- Prefer an exact move-id row when it exists, but keep this generic enough
  -- for called moves whose host row is only tagged later.
  if action.moveId then
    for _,candidate in ipairs(b.queue or {}) do
      if type(candidate)=="table" and candidate.anim==action.moveId then
        action.row=candidate
        return candidate
      end
    end
  end
  return nil
end

function M.new(opts)
  opts=opts or {}
  return setmetatable({
    playSound=assert(opts.playSound), log=opts.log, maskAssets=assert(opts.maskAssets), paletteRenderer=assert(opts.paletteRenderer), battleSpace=assert(opts.battleSpace, "stat_change_feedback: battleSpace is required"),
    snapshots={}, pending=nil, active=nil, action=nil, serial=0,
    stats={detected=0,bound=0,started=0,completed=0,dropped=0},
  },M)
end

function M:soundIds() return {232,238} end

function M:_snapshot(battle,battler)
  local key=battlerKey(battler); if key then self.snapshots[key]=copyStages(stagesFor(battle,battler)) end
end

function M:_detectFor(battle,battler)
  local key=battlerKey(battler); if not key then return {} end
  local cur=copyStages(stagesFor(battle,battler)); local prev=self.snapshots[key]
  if not prev then self.snapshots[key]=cur; return {} end
  local changes=compare(prev,cur,battle,battler)

  -- Gen I Rage raises Attack automatically when the locked-in Rage user is
  -- damaged, then reports that with the native "RAGE is building!" text.
  -- That is not a normal stat-change presentation event, so do not inject the
  -- shared FireRed stat-up mask/SFX for this specific +1 Attack mutation.
  -- Advance only the suppressed snapshot field so it cannot be detected again
  -- on the next update; all unrelated stage changes remain eligible.
  if battler and battler.rageMove then
    local kept={}
    for _,change in ipairs(changes) do
      if change.stat=="attack" and change.delta==1 then
        prev.attack=cur.attack
      else
        kept[#kept+1]=change
      end
    end
    changes=kept
  end

  return changes
end

function M:_detect(battle)
  local all={}
  for _,b in ipairs({battle and battle.player,battle and battle.enemy}) do
    for _,c in ipairs(self:_detectFor(battle,b)) do all[#all+1]=c end
  end
  return all
end

function M:beginBattle(battle)
  self:_snapshot(battle,battle and battle.player)
  self:_snapshot(battle,battle and battle.enemy)
end

-- Capture the semantic action that owns any stage mutation produced while the
-- turn is being built. This event is emitted before playback; it is metadata,
-- not permission to draw.
function M:onMoveUsed(ev)
  if not (ev and ev.battle and ev.move) then return end
  self.serial=self.serial+1
  self.action={
    serial=self.serial,battle=ev.battle,moveId=ev.move.id,row=ev.battle.moveAnimRow,
    user=ev.user,target=ev.target,bound=false,
  }
end

local function directionFor(change)
  -- The signed stage delta is the source of truth.  Do not let a stale or
  -- batch-derived direction flag recolor a decrease as an increase (or vice
  -- versa).  Gen1Recomp stores raised stages as positive values and lowered
  -- stages as negative values, so the observed delta maps directly to the
  -- presentation direction.
  return (tonumber(change and change.delta) or 0)<0 and "down" or "up"
end

local function splitChangeGroups(changes)
  -- One FireRed stat-mask pass has one affected battler and one scroll/color
  -- direction.  A single host update can contain several mutations, including
  -- mixed-direction self changes.  The old bridge collapsed the whole batch
  -- and inherited the first change's direction, so a later decrease could be
  -- shown with the green/up mask.  Keep same-direction changes together, but
  -- sequence opposite directions (and different battlers) independently.
  local groups={}
  for _,c in ipairs(changes or {}) do
    local direction=directionFor(c)
    local group
    for _,candidate in ipairs(groups) do
      if candidate.battler==c.battler and candidate.direction==direction then
        group=candidate; break
      end
    end
    if not group then
      group={battler=c.battler,direction=direction,changes={}}
      groups[#groups+1]=group
    end
    c.direction=direction
    group.changes[#group.changes+1]=c
  end
  return groups
end

local function choosePrimary(changes)
  local first=changes[1]
  local direction=directionFor(first); local sharply=first.sharply
  for _,c in ipairs(changes) do if c.sharply then sharply=true end end
  return {battler=first.battler,direction=direction,sharply=sharply,multiple=#changes>1,changes=changes,mixed=false,stat=(#changes==1 and first.stat or nil)}
end

function M:_maskFor(active,battler)
  if not active or battler~=active.affected then return nil end
  local f=active.frame; local max=active.profile.sharply and 13 or 10
  local hold=active.profile.sharply and 30 or 20
  local fadeFrames=max*2
  local amount
  if f<fadeFrames then amount=math.floor(f/2)/16
  elseif f<fadeFrames+hold then amount=max/16
  elseif f<fadeFrames+hold+fadeFrames then
    amount=(max-math.floor((f-(fadeFrames+hold))/2))/16
  else amount=0 end
  if amount<=0 then return nil end
  local down=active.profile.direction=="down"
  local pal=active.profile.multiple and 5 or (STAT_PALETTE[active.profile.stat] or 5)
  return {
    image=self.maskAssets:image(down,pal), amount=amount,
    coordinateSpace=self.battleSpace.SPACE_SCREEN, displayScale=self.battleSpace.displayScale(self.battleSpace.SPACE_SCREEN),
    x=down and 64 or 0, y=(down and -3 or 3)*f,
    -- Deliberate project presentation override: keep the FireRed mask art,
    -- tilemap, scrolling, blend amount, and sharp-change timing, but recolor
    -- raises green and drops red. The shared mask shader multiplies this color
    -- by the original ROM mask intensity, so the energy shading is preserved.
    color=down and {31,4,4} or {4,31,4},
  }
end

function M:start(battle,changes)
  if not changes or #changes==0 or self.active then return end
  local p=choosePrimary(changes); local affected=p.battler
  local max=p.sharply and 13 or 10; local hold=p.sharply and 30 or 20
  self.active={battle=battle,affected=affected,anchor=anchorFor(affected),frame=0,duration=max*4+hold,profile=p}
  local active=self.active; local owner=self
  active.maskToken=self.paletteRenderer:installMask(battle,function(battler) return owner:_maskFor(active,battler) end)
  self.stats.started=self.stats.started+1
  self:_snapshot(battle,battle.player); self:_snapshot(battle,battle.enemy)
  local sid=p.direction=="up" and 232 or 238
  local ok,err=self.playSound(sid,panFor(affected),battle)
  if not ok and self.log then self.log:warn("FireRed stat-change SFX %s failed: %s",tostring(sid),tostring(err)) end
  battle.waitFrames=math.max(tonumber(battle.waitFrames) or 0,self.active.duration)
end

function M:_clearActive()
  local a=self.active; if not a then return end
  if a.maskToken then self.paletteRenderer:clear(a.maskToken); a.maskToken=nil end
  self.active=nil
end

-- Insert a dedicated feedback row directly after the move animation row. The
-- move row cannot leave the queue until its native or FireRed replacement
-- animation has completed, so this gives both registered and unregistered
-- moves one deterministic post-animation seam.
function M:_bindPending()
  local p=self.pending; local action=self.action
  if not (p and action and p.battle==action.battle and not action.bound) then return false end
  local b=p.battle; local moveRow=resolveMoveRow(action); local idx=queueIndex(b,moveRow)
  if not idx then return false end

  local owner=self
  local groups=splitChangeGroups(p.changes)
  if #groups==0 then return false end
  local rows={}
  for groupIndex,group in ipairs(groups) do
    local changes=group.changes
    local isFirst=(groupIndex==1)
    local direction=group.direction
    local row={fireRedStatChange=true,fireRedStatDirection=direction,fn=function()
      -- Clear the pending/action ownership when the first feedback row starts.
      -- Any additional mixed-direction rows already own their captured change
      -- lists and remain queued behind the first row's wait.
      if isFirst then
        if owner.pending==p then owner.pending=nil end
        if owner.action==action then owner.action=nil end
      end
      owner:start(b,changes)
    end}
    rows[#rows+1]=row
    table.insert(b.queue,idx+groupIndex,row)
  end
  -- nextInsert is the queue-construction insertion cursor. If the host is still
  -- building this same action, account for every feedback row we inserted so
  -- later sayNext/actNext calls remain after them rather than overwriting their
  -- relative position.
  if type(b.nextInsert)=="number" and b.nextInsert>=idx+1 then b.nextInsert=b.nextInsert+#rows end
  action.bound=true; action.feedbackRow=rows[1]; action.feedbackRows=rows
  self.stats.bound=self.stats.bound+#rows
  return true
end

function M:beforeUpdate() end

function M:afterUpdate(battle)
  if self.active then
    self.active.frame=self.active.frame+1
    if self.active.frame>=self.active.duration then self:_clearActive(); self.stats.completed=self.stats.completed+1 end
    return
  end
  if not battle then return end

  if not self.pending then
    local changes=self:_detect(battle)
    if #changes>0 then
      self.stats.detected=self.stats.detected+#changes
      self.pending={battle=battle,changes=changes,serial=self.action and self.action.serial or nil}
    end
  end

  if self.pending then self:_bindPending() end

  -- Never start pending move-caused feedback from elapsed wall-clock time.
  -- If the owning move row disappears before we could bind it, discard the
  -- visual rather than showing it at an incorrect point in the turn.
  local p=self.pending; local action=self.action
  if p and action and p.battle==action.battle and action.bound and action.feedbackRow
     and not queueIndex(p.battle,action.feedbackRow) and not self.active then
    self.pending=nil; self.action=nil; self.stats.dropped=self.stats.dropped+1
  end
end

function M:draw(battle)
  -- FireRed B_ANIM_STATS_CHANGE is a scrolling ROM BG mask clipped through the
  -- battler OBJ window, not a foreground sprite. Rendering happens at the
  -- shared battler draw seam; there is intentionally no custom fallback art.
end

function M:reset()
  self:_clearActive()
  self.pending=nil; self.action=nil; self.snapshots={}
end

function M:info()
  return {
    active=self.active~=nil,pending=self.pending~=nil,action=self.action~=nil,
    detected=self.stats.detected,bound=self.stats.bound,started=self.stats.started,
    completed=self.stats.completed,dropped=self.stats.dropped,
  }
end
return M
