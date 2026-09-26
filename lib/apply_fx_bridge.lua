-- Single owner of Gen1Recomp's battle.applyHitFx seam.
-- Feedback systems register ordered consumers. A consumer may return true to
-- suppress the native row completely, or "sound-only" to preserve only the
-- row's audio cue while suppressing its Gen1 visual. This avoids stacked
-- wrappers whose detach order could otherwise restore the wrong function.
local M={}; M.__index=M

local FIRE_RED_HIT_FRAMES = 32
local FIRE_RED_HIT_TOGGLE = 4

local function playHitSound(battle,hit)
  if not (battle and hit and hit.sfx) then return end
  local ok,Sound=pcall(require,"src.core.Sound")
  if not ok or not Sound then return end
  if type(hit.sfx)=="table" then
    if Sound.playMove then Sound.playMove(battle.data,hit.sfx) end
  elseif Sound.play then
    Sound.play(battle.data,hit.sfx)
  end
end

function M.new(opts)
  opts=opts or {}
  return setmetatable({consumers={},attached=setmetatable({},{__mode="k"}),flash=setmetatable({},{__mode="k"}),persistentHidden=setmetatable({},{__mode="k"}),log=opts.log},M)
end

function M:add(name,fn)
  assert(type(name)=="string" and name~="","apply-FX consumer needs a name")
  assert(type(fn)=="function","apply-FX consumer needs a function")
  self.consumers[#self.consumers+1]={name=name,fn=fn}
end

-- Shared FireRed damage reaction used both by registered move hit rows and
-- non-move damage seams such as confusion self-hit. Keep the sound and blink
-- choreography in one place so status code never invents its own hit effect.
function M:startFireRedHit(battle,target,hit)
  if not (battle and target) then return false end
  hit=hit or {sfx="Damage"}
  playHitSound(battle,hit)
  self.flash[battle]={target=target,age=0,frames=FIRE_RED_HIT_FRAMES}
  battle.waitFrames=math.max(battle.waitFrames or 0,FIRE_RED_HIT_FRAMES)
  return true
end

function M:attach(battle)
  if not battle or self.attached[battle] then return true end
  local original=battle.applyHitFx
  if type(original)~="function" then
    if self.log then self.log:warn("FireRed feedback unavailable: battle.applyHitFx missing") end
    return nil,"battle.applyHitFx missing"
  end
  local bridge=self
  local wrapper
  wrapper=function(b,hit)
    for _,c in ipairs(bridge.consumers) do
      local ok,consumed=pcall(c.fn,b,hit)
      if not ok then
        if bridge.log then bridge.log:warn("FireRed apply-FX consumer %s failed: %s",c.name,tostring(consumed)) end
      elseif consumed then
        if consumed=="sound-only" then
          playHitSound(b,hit)
        elseif consumed=="fire-red-hit" then
          local target=hit and hit.blink
          if target then
            bridge:startFireRedHit(b,target,hit)
          else
            playHitSound(b,hit)
          end
        end
        return
      end
    end
    return original(b,hit)
  end
  local originalHidden=battle.fxHidden
  local hiddenWrapper
  if type(originalHidden)=="function" then
    hiddenWrapper=function(b,battler)
      local h=bridge.persistentHidden[b]
      if h and h.battler==battler and h.mon==battler.mon and (h.allowSpriteRefresh or h.sprite==battler.sprite) then
        return true
      end
      local f=bridge.flash[b]
      if f and f.target==battler and f.age < f.frames then
        return (math.floor(f.age / FIRE_RED_HIT_TOGGLE) % 2) == 0
      end
      return originalHidden(b,battler)
    end
    battle.fxHidden=hiddenWrapper
  end
  battle.applyHitFx=wrapper
  self.attached[battle]={original=original,wrapper=wrapper,originalHidden=originalHidden,hiddenWrapper=hiddenWrapper}
  return true
end

-- Hold one exact battler picture hidden across Gen1Recomp's resetPicFx() calls.
-- FireRed Whirlwind/Roar slide the target beyond the display and leave it there;
-- the host otherwise clears pf.hidden at the next animation row, producing a
-- one-frame pop back to the origin. Identity snapshots ensure a replacement
-- Pokémon on the same side is never hidden by the old terminal state.
function M:holdBattlerHidden(battle,battler,opts)
  if not (battle and battler) then return false end
  opts=opts or {}
  self.persistentHidden[battle]={
    battler=battler, mon=battler.mon, sprite=battler.sprite,
    -- Teleport can rebuild the visual sprite object while the same battler/mon
    -- remains active.  In that case sprite identity is not a safe lifetime key.
    allowSpriteRefresh=opts.allowSpriteRefresh==true
  }
  return true
end

function M:releaseBattlerHidden(battle,battler)
  local h=battle and self.persistentHidden[battle]
  if h and (not battler or h.battler==battler) then self.persistentHidden[battle]=nil end
end

function M:detach(battle)
  local a=battle and self.attached[battle]
  if not a then return end
  -- Restore only if our wrapper still owns the seam. Another mod may have
  -- wrapped it after us; overwriting that wrapper during teardown would be rude.
  if battle.applyHitFx==a.wrapper then battle.applyHitFx=a.original end
  if a.hiddenWrapper and battle.fxHidden==a.hiddenWrapper then battle.fxHidden=a.originalHidden end
  self.flash[battle]=nil
  self.persistentHidden[battle]=nil
  self.attached[battle]=nil
end

function M:afterUpdate(battle)
  local h=battle and self.persistentHidden[battle]
  if h then
    local stillCurrent=(battle.player==h.battler or battle.enemy==h.battler)
    if not stillCurrent or h.battler.mon~=h.mon or (not h.allowSpriteRefresh and h.battler.sprite~=h.sprite) then
      self.persistentHidden[battle]=nil
    else
      -- resetPicFx() runs inside BattleState:update and clears ordinary
      -- pf.hidden state when a new animation/message row starts. Reassert the
      -- terminal Whirlwind/Roar disappearance *after* that host update so the
      -- very next draw cannot flash the battler back at its origin. This is
      -- intentionally active state, not just an fxHidden draw predicate: some
      -- host/compat draw paths consult picFx.hidden directly.
      local pf
      if type(battle.picFxFor)=="function" then
        local ok,v=pcall(battle.picFxFor,battle,h.battler)
        if ok and type(v)=="table" then pf=v end
      elseif battle.picFx then
        pf=battle.picFx[h.battler]
      end
      if pf then
        pf.hidden=true
        -- resetPicFx also zeros offsets. Once the FireRed slide has completed
        -- the target is already beyond the edge, so visibility is the only
        -- terminal state that must persist; do not resurrect a stale offset.
      end
    end
  end
  local f=battle and self.flash[battle]
  if not f then return end
  f.age=f.age+1
  if f.age>=f.frames then self.flash[battle]=nil end
end

return M
