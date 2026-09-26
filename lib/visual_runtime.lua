-- FireRed battle-animation visual planner.

local CONVERSION_TAG = 10018
local CONVERSION_FLASH_BLEND = 12
local CONVERSION_PROVISIONAL_DURATION = 1000000
-- Shared FireRed battle-animation planner. Move choreography is declarative.
local BattleSpace
local M = {}

function M.configure(opts)
  opts=opts or {}
  BattleSpace=assert(opts.battleSpace, "visual_runtime: battleSpace is required")
  return M
end

M.GBA_FPS = 59.727500569606

-- FireRed single-battle battler anchors are Y=80 (player) and Y=40 (foe).
-- Gen1Recomp's corrected host anchors are Y=64 and Y=40. Relative Y deltas
-- authored by callbacks such as TranslateAnimSpriteToTargetMonLocation therefore
-- need the same 24/40 vertical-span conversion instead of a move-specific nudge.
local HOST_RELATIVE_Y_SCALE = (64 - 40) / (80 - 40) -- 0.6
local function hostRelativeYDelta(v)
  return (tonumber(v) or 0) * HOST_RELATIVE_Y_SCALE
end

-- FireRed callbacks that explicitly use BATTLER_COORD_Y use battler-local
-- offsets. Keep those deltas 1:1: scaling them globally compresses authored
-- multi-sprite geometry (String Shot bands, Thunder Wave, electric arcs, etc.).
-- Moves that need a host-specific placement correction should do so locally.
local RAW_BATTLER_Y_HOST_SHIFT = -16

local function rawBattlerY(battler, nativeOffset)
  local base=battler.yRaw or battler.y or battler.yPicOffset or 0
  return base+RAW_BATTLER_Y_HOST_SHIFT+(tonumber(nativeOffset) or 0)
end

-- Compatibility alias for callbacks whose raw-Y arguments explicitly describe
-- a multi-sprite pattern. rawBattlerY is now also 1:1 globally.
local function rawBattlerYPattern(battler, nativeOffset)
  return rawBattlerY(battler, nativeOffset)
end

local function animBattler(v)
  if v == "target" then return 1 end
  if v == "attacker" then return 0 end
  return v or 0
end

local function clone(t)
  local o = {}
  for k,v in pairs(t or {}) do o[k] = v end
  return o
end

-- FireRed choosetwoturnanim selects between two script branches using the
-- current animation turn. Move data can express the branch-only numeric
-- differences as { byAnimTurn={first,second} } so the shared planner remains
-- declarative and reusable for multi-hit animations such as Comet Punch.
local function resolveArg(v,ctx)
  if type(v)=="table" and type(v.byAttackerSide)=="table" then
    local attackerSide=(ctx and ctx.attacker and ctx.attacker.side)=="player" and "player" or "opponent"
    local chosen=v.byAttackerSide[attackerSide]
    if chosen==nil then chosen=v.byAttackerSide.default end
    return resolveArg(chosen,ctx)
  end
  if type(v)=="table" and type(v.byTargetSide)=="table" then
    local targetSide=(ctx and ctx.target and ctx.target.side)=="player" and "player" or "opponent"
    local chosen=v.byTargetSide[targetSide]
    if chosen==nil then chosen=v.byTargetSide.default end
    return resolveArg(chosen,ctx)
  end
  if type(v)=="table" and type(v.byAnimTurn)=="table" then
    local a=v.byAnimTurn
    local n=#a
    if n<1 then return nil end
    local turn=math.floor(tonumber(ctx and ctx.animTurn) or 0)
    return resolveArg(a[(turn % n)+1],ctx)
  end
  return v
end

local function resolveArgs(args,ctx)
  local out={}
  for k,v in pairs(args or {}) do out[k]=resolveArg(v,ctx) end
  return out
end

local function signAdjustedXOffset(attacker, target, xOffset)
  if attacker.x > target.x then return -xOffset end
  if attacker.x < target.x then return xOffset end
  return attacker.side == "player" and xOffset or -xOffset
end

local function pos(battler, respectPicOffsets)
  if respectPicOffsets then
    return battler.x2 or battler.x, battler.yPicOffset or battler.y
  end
  -- FireRed BATTLER_COORD_Y is the fixed battler-slot coordinate, distinct
  -- from the species-adjusted Y_PIC_OFFSET. In the Gen1Recomp host mapping,
  -- those fixed FireRed slot anchors resolve to Y=64 (player) and Y=40 (foe).
  return battler.x or battler.x2, battler.yRaw or battler.y or battler.yPicOffset
end

local function initOn(battler, attacker, target, respectPicOffsets, xOffset, yOffset)
  local x,y = pos(battler, respectPicOffsets)
  x = x + signAdjustedXOffset(attacker, target, xOffset)
  y = y + (respectPicOffsets and yOffset or hostRelativeYDelta(yOffset))
  return x,y
end

-- Equivalent geometry for TranslateAnimSpriteToTargetMonLocation.
function M.translateToTarget(args, ctx)
  local a,t = assert(ctx.attacker), assert(ctx.target)
  local flags = args[6] or 0
  local respectPicOffsets = math.floor(flags / 0x100) % 0x100 == 0
  local targetUsesPicOffset = flags % 0x100 == 0
  local startYOffset = respectPicOffsets and hostRelativeYDelta(args[2]) or (args[2] or 0)
  local sx,sy = initOn(a, a, t, respectPicOffsets, args[1] or 0, startYOffset)
  local txoff = args[3] or 0
  if a.side ~= "player" then txoff = -txoff end
  local tx = (t.x2 or t.x) + txoff
  local targetBaseY
  local targetYOffset
  if targetUsesPicOffset then
    targetBaseY = t.yPicOffset or t.y
    targetYOffset = hostRelativeYDelta(args[4])
  else
    -- Raw BATTLER_COORD_Y is still a target-hit destination. In the compressed
    -- host, preserve FireRed's relative offset semantics by converting the Y
    -- delta through the same shared vertical scale as target-local impact
    -- callbacks. The live endpoint itself is rebased at instantiation time.
    targetBaseY = t.yRaw or t.y
    targetYOffset = hostRelativeYDelta(args[4])
  end
  local ty = targetBaseY + targetYOffset
  return { startX=sx, startY=sy, endX=tx, endY=ty, duration=args[5] or 0,
           respectPicOffsets=respectPicOffsets, targetUsesPicOffset=targetUsesPicOffset,
           -- Only raw-Y target-hit mode uses the host projectile->impact handoff.
           -- Y_PIC_OFFSET beams/rings keep their established centerline.
           liveTargetEndpointY=false, liveRawYBattler=(not targetUsesPicOffset) and "target" or nil, liveRawYKeys={"endY"} }
end

-- Equivalent geometry for AnimEmberFlare -> AnimTravelDiagonally.
-- Exact geometry for gKarateChopSpriteTemplate -> AnimSlideHandOrFootToTarget
-- -> AnimTravelDiagonally. The callback selects the requested hand/foot frame,
-- clears arg6, then delegates to AnimTravelDiagonally. With Karate Chop's
-- arg5=1 and respect-pic-offset mode, InitSpritePosToAnimTarget is therefore
-- applied twice; the -16 X offset becomes a native 32 px approach.
function M.slideHandOrFootToTarget(args, ctx)
  local a,t = assert(ctx.attacker), assert(ctx.target)
  local aa={}
  for i=1,8 do aa[i]=args[i] or 0 end

  -- AnimSlideHandOrFootToTarget's optional opponent-side Y mirroring.
  if aa[8] == 1 and a.side ~= "player" then
    aa[2] = -aa[2]
    aa[4] = -aa[4]
  end
  local animVariant=aa[7]
  -- StartSpriteAnim(sprite, arg6); arg6 = 0; AnimTravelDiagonally(sprite).
  aa[7]=0
  local respectPicOffsets=true

  -- Karate Chop uses arg5=1, so AnimTravelDiagonally first target-initializes
  -- and then executes its unconditional target initialization a second time.
  local sx,sy=initOn(t,a,t,respectPicOffsets,aa[1],aa[2])
  if aa[6] ~= 0 then
    sx=sx+signAdjustedXOffset(a,t,aa[1])
    sy=sy+aa[2]
  end

  local coordBattler=(aa[6]==0) and a or t
  local txoff=aa[3]
  if a.side ~= "player" then txoff=-txoff end
  local tx=(coordBattler.x2 or coordBattler.x)+txoff
  local ty=(coordBattler.yPicOffset or coordBattler.y)+(aa[4] or 0)
  local nativeDuration=math.max(1,math.floor(tonumber(aa[5]) or 1))
  return {kind="anim_linear_fixed",startX=sx,startY=sy,endX=tx,endY=ty,
    -- AnimSlideHandOrFootToTarget is one visible setup callback. The next
    -- callback (StartAnimLinearTranslation) performs movement step 1.
    duration=nativeDuration+1,nativeDuration=nativeDuration,
    animVariant=animVariant,respectPicOffsets=respectPicOffsets,
    coordinateBattler=(aa[6]==0 and "attacker" or "target")}
end



-- FireRed AnimBoneHitProjectile (Bone Club). The bone starts target-relative
-- at the scripted offset, then linearly translates to the target-relative
-- destination over arg4 frames while its affine animation spins +20 units
-- per callback.
function M.boneHitProjectile(args, ctx)
  local a,t=assert(ctx.attacker),assert(ctx.target)
  local sx,sy=initOn(t,a,t,true,args[1] or 0,args[2] or 0)
  local txoff=tonumber(args[3]) or 0
  if a.side ~= "player" then txoff=-txoff end
  local tx=(t.x2 or t.x)+txoff
  local ty=(t.yPicOffset or t.y)+(tonumber(args[4]) or 0)
  local nativeDuration=math.max(1,math.floor(tonumber(args[5]) or 1))
  return {kind="bone_hit_projectile",startX=sx,startY=sy,endX=tx,endY=ty,
    duration=nativeDuration+1,nativeDuration=nativeDuration,affineRotationStep=20}
end

-- FireRed AnimBonemerangProjectile. The same bone sprite follows two native
-- 20-frame horizontal arcs: attacker -> target with -40 height, then target ->
-- attacker with +40 height. Its affine animation rotates +15 units per frame.
function M.bonemerangProjectile(args, ctx)
  local a,t=assert(ctx.attacker),assert(ctx.target)
  local sx=(a.x2 or a.x)
  local sy=(a.yPicOffset or a.y)
  local mx=(t.x2 or t.x)
  local my=(t.yPicOffset or t.y)
  return {kind="bonemerang_projectile",startX=sx,startY=sy,midX=mx,midY=my,
    endX=sx,endY=sy,outDuration=20,returnDuration=20,duration=41,
    outArc=-40,returnArc=40,affineRotationStep=15}
end


-- FireRed AnimFallingRock (Rock Throw). Each rock starts target-relative at
-- (arg0, +14), drops through a 16-callback vertical ellipse, then switches
-- into a 32-callback finishing ellipse with arg2 horizontal amplitude.
function M.fallingRock(args, ctx)
  local a,t=assert(ctx.attacker),assert(ctx.target)
  local xoff=tonumber(args[1]) or 0
  local baseX=(t.x2 or t.x)+xoff
  local useAverageRaw=(tonumber(args[4]) or 0)~=0
  local baseY=(useAverageRaw and rawBattlerY(t,14) or (t.yPicOffset or t.y)+14)
  local horiz=tonumber(args[3]) or 0
  return {kind="falling_rock",startX=baseX,startY=baseY,endX=baseX+horiz,endY=baseY,
    duration=50,animVariant=math.floor(tonumber(args[2]) or 0),
    phase1Duration=16,phase2Duration=32,horizAmplitude=horiz,
    liveRawYBattler=useAverageRaw and "target" or nil}
end

function M.rockScatter(args, ctx)
  local t=assert(ctx.target)
  local xoff=args[1] or 0
  local yoff=args[2] or 0
  local y=rawBattlerY(t,yoff)
  return {kind="rock_scatter",startX=(t.x or t.x2)+xoff,startY=y,
    endX=(t.x or t.x2)+xoff,endY=y,duration=18,
    xImpulse=xoff,sineAmplitude=args[3] or 0,animVariant=args[4] or 0,liveRawYBattler="target"}
end

-- FireRed AnimDirtScatter (Sand Attack / Mud-Slap). The sprite begins
-- attacker-relative and uses the engine RNG only to scatter its endpoint by
-- the same signed 5-bit offsets as the original callback. The deterministic
-- seed here preserves that geometry without coupling presentation to battle RNG.
function M.dirtScatter(args, ctx, seed)
  local a,t=assert(ctx.attacker),assert(ctx.target)
  local sx,sy=initOn(a,a,t,true,tonumber(args[1]) or 0,hostRelativeYDelta(tonumber(args[2]) or 0))
  local state=math.floor(tonumber(seed) or 1)%65536
  local function next5()
    state=(state*1103515245+12345)%2147483648
    local n=math.floor(state/65536)%32
    if n>16 then n=16-n end
    return n
  end
  local tx=(t.x2 or t.x)+next5()
  local ty=(t.yPicOffset or t.y)+hostRelativeYDelta(next5())
  local d=math.max(1,math.floor(tonumber(args[3]) or 1))
  return {kind="anim_linear_fixed",startX=sx,startY=sy,endX=tx,endY=ty,
    duration=d+1,nativeDuration=d}
end

-- FireRed AnimDirtPlumeParticle (Dig / Fissure).
function M.dirtPlumeParticle(args, ctx)
  local battler=((tonumber(args[1]) or 0)==0) and assert(ctx.attacker) or assert(ctx.target)
  local side=tonumber(args[2]) or 0
  local xoff=(side==1) and -24 or 24
  local dx=tonumber(args[3]) or 0
  if side==1 then dx=-dx end
  local sx=(battler.x2 or battler.x)+xoff
  local sy=rawBattlerY(battler,30)
  local d=math.max(1,math.floor(tonumber(args[6]) or 1))
  return {kind="dirt_plume",startX=sx,startY=sy,endX=sx+dx,
    endY=sy+(tonumber(args[4]) or 0),duration=d,nativeDuration=d,
    arcAmplitude=tonumber(args[5]) or 0,
    liveRawYBattler=((tonumber(args[1]) or 0)==0) and "attacker" or "target",
    liveElevationBattler=((tonumber(args[1]) or 0)==0) and "attacker" or "target"}
end

-- FireRed AnimDigDirtMound. Two 32x16 sprites form the complete mound.
function M.digDirtMound(args, ctx)
  local battler=((tonumber(args[1]) or 0)==0) and assert(ctx.attacker) or assert(ctx.target)
  local half=math.max(0,math.min(1,math.floor(tonumber(args[2]) or 0)))
  local d=math.max(1,math.floor(tonumber(args[3]) or 1))
  local y=rawBattlerY(battler,32)
  return {kind="dig_dirt_mound",startX=(battler.x or battler.x2)-16+half*32,
    startY=y,
    endX=(battler.x or battler.x2)-16+half*32,
    endY=y,duration=d,nativeDuration=d,tileHalf=half,
    liveRawYBattler=((tonumber(args[1]) or 0)==0) and "attacker" or "target",
    liveElevationBattler=((tonumber(args[1]) or 0)==0) and "attacker" or "target"}
end

function M.emberFlare(args, ctx)
  local a,t = assert(ctx.attacker), assert(ctx.target)
  local aa = {}
  for i=1,7 do aa[i] = args[i] or 0 end
  aa[6] = animBattler(aa[6])
  aa[7] = animBattler(aa[7])

  -- FireRed's special double-battle orientation correction.
  if a.side == t.side and (a.position == "player_right" or a.position == "opponent_right") then
    aa[3] = -aa[3]
  end

  local respectPicOffsets = aa[7] == 0
  local coordBattler = aa[6] == 0 and a or t
  -- AnimTravelDiagonally always performs InitSpritePosToAnimTarget after it
  -- chooses battlerId, so the final start position is target-relative.
  -- In the compressed Gen1 host, raw BATTLER_COORD_Y has two distinct uses:
  -- cross-battler trajectory endpoints use fixed slot-space (yRaw), while a
  -- raw target-local initialization still starts in the target's local sprite
  -- coordinate space. Keep those semantics separate so lifting raw trajectory
  -- endpoints does not also lift local target effects.
  local sx,sy
  if respectPicOffsets then
    sx,sy = initOn(t, a, t, true, aa[1], hostRelativeYDelta(aa[2]))
  else
    sx = (t.x or t.x2) + signAdjustedXOffset(a, t, aa[1])
    sy = (t.yRaw or t.y or t.yPicOffset) + hostRelativeYDelta(aa[2])
  end
  local txoff = aa[3]
  if a.side ~= "player" then txoff = -txoff end
  local tx = (coordBattler.x2 or coordBattler.x) + txoff
  local tybase = respectPicOffsets and (coordBattler.yPicOffset or coordBattler.y) or (coordBattler.yRaw or coordBattler.y)
  local ty = tybase + hostRelativeYDelta(aa[4])
  return { startX=sx, startY=sy, endX=tx, endY=ty, duration=aa[5],
           respectPicOffsets=respectPicOffsets, coordinateBattler=(aa[6] == 0 and "attacker" or "target"),
           liveLocalYBattler=respectPicOffsets and "target" or nil,
           liveRawYBattler=(not respectPicOffsets and aa[6] ~= 0) and "target" or nil }
end


-- Equivalent geometry for AnimMovePowderParticle. FireRed starts each particle
-- at the target, applies a fixed sub-pixel vertical velocity, and overlays a
-- horizontal sine wave whose amplitude/speed come from the move script.
-- FireRed AnimSlidingKick (Rolling Kick / Low Kick). The foot starts at the
-- target using the normal target-relative X mirroring, then translates
-- horizontally for arg3 pixels over arg4 native frames. arg5 advances the
-- sine phase and arg6 is its vertical amplitude.
function M.slidingKick(args, ctx)
  local a,t=assert(ctx.attacker),assert(ctx.target)
  local sx,sy=initOn(t,a,t,true,args[1] or 0,args[2] or 0)
  local dx=tonumber(args[3]) or 0
  if a.side ~= "player" then dx=-dx end
  local nativeDuration=math.max(1,math.floor(tonumber(args[4]) or 1))
  return {kind="sliding_kick",startX=sx,startY=sy,endX=sx+dx,endY=sy,
    duration=nativeDuration+1,nativeDuration=nativeDuration,
    phaseStep=tonumber(args[5]) or 0,amplitude=tonumber(args[6]) or 0}
end

-- FireRed AnimSpinningKickOrPunch, used by Mega Punch/Mega Kick. The sprite
-- is target-relative, uses the requested fist/foot frame, and runs the native
-- shrinking/rotating affine loop for arg3 frames. The callback then resets to
-- full size, holds for 20 frames, and destroys.
function M.spinningKickOrPunch(args, ctx)
  local a,t=assert(ctx.attacker),assert(ctx.target)
  local sx,sy=initOn(t,a,t,true,args[1] or 0,args[2] or 0)
  local spinDuration=math.max(0,math.floor(tonumber(args[4]) or 0))
  return {kind="spinning_kick_or_punch",startX=sx,startY=sy,endX=sx,endY=sy,
    duration=spinDuration+21,spinDuration=spinDuration,animVariant=tonumber(args[3]) or 0}
end

function M.powderParticle(args, ctx)
  local a,t = assert(ctx.attacker), assert(ctx.target)
  local sx,sy = initOn(t, a, t, true, args[1] or 0, args[2] or 0)
  return {
    kind="powder_particle", startX=sx, startY=sy,
    duration=args[3] or 0, verticalSpeed=(args[4] or 0)/256,
    amplitude=args[5] or 0, waveSpeed=args[6] or 0,
    -- Cmd_createsprite places every animation sprite on the target's
    -- X_2/Y_PIC_OFFSET before the callback runs. AnimMovePowderParticle keeps
    -- that target-local origin and only adds its script offsets. Rebase the
    -- cached synthetic target point to the live rendered battler center.
    liveLocalYBattler="target",
  }
end

-- FireRed Confuse Ray's first yellow orb travels from attacker to target with
-- a 10x15 trig wobble. arg3 is the linear speed (8.8 fixed-point).
function M.confuseRayBounce(args, ctx)
  local a,t=assert(ctx.attacker),assert(ctx.target)
  local sx,sy=initOn(a,a,t,true,args[1] or 0,args[2] or 0)
  local tx,ty=(t.x2 or t.x),(t.yPicOffset or t.y)
  local speed=math.max(1,args[3] or 288)/256
  -- InitAnimLinearTranslationWithSpeed derives its duration from the dominant
  -- axis, not Euclidean distance. Using Euclidean distance made the orb linger
  -- in the opening +15px cosine dip, which read as an exaggerated downward jump.
  local span=math.max(math.abs(tx-sx),math.abs(ty-sy))
  local travelDuration=math.max(1,math.ceil(span/speed))

  -- FireRed keeps AnimConfuseRayBallBounce alive after the translation ends
  -- until UpdateConfuseRayBallBlend finishes the current fade-out/hold cycle.
  -- Simulate the callback-owned blend state so waitforvisualfinish observes the
  -- same lifetime instead of destroying the orb at the end of its flight.
  local blendAmount=16
  local rising=false
  local function updateBlend()
    if blendAmount > 0xFF then
      blendAmount=blendAmount+1
      if blendAmount==0x10D then blendAmount=0 end
      return
    end
    blendAmount=blendAmount+(rising and 1 or -1)
    if blendAmount==0 or blendAmount==16 then rising=not rising end
    if blendAmount==0 then blendAmount=0x100 end
  end
  for _=1,travelDuration do updateBlend() end
  local tail=0
  while blendAmount~=0 and tail<128 do
    updateBlend()
    tail=tail+1
  end
  -- Step2 destroys on the first callback tick that sees blendAmount == 0.
  local duration=travelDuration+tail
  return {kind="confuse_ray_bounce",startX=sx,startY=sy,endX=tx,endY=ty,
          duration=duration,travelDuration=travelDuration,
          affineScaleDelta=0x1E,affineRotationStep=10,affineHalfPeriod=5,
          dynamicBlend=true}
end

-- The second orb is target-centered and circles at radius 32x8. FireRed's
-- callback is intentionally persistent; cap it to one full 256-angle cycle so
-- waitforvisualfinish has a deterministic equivalent in this renderer.
function M.confuseRaySpiral(args, ctx)
  local a,t=assert(ctx.attacker),assert(ctx.target)
  local sx,sy=initOn(t,a,t,true,args[1] or 0,args[2] or 0)
  return {kind="confuse_ray_spiral",startX=sx,startY=sy,endX=sx,endY=sy,duration=61}
end


-- FireRed AnimEllipticalGust: target-relative tornado centered 20 px below the
-- initialized position, orbiting 32x8 from angle 191 for exactly 71 frames.
function M.ellipticalGust(args, ctx)
  local a,t=assert(ctx.attacker),assert(ctx.target)
  local sx,sy=initOn(t,a,t,false,args[1] or 0,args[2] or 0)
  return {kind="elliptical_gust",startX=sx,startY=sy+hostRelativeYDelta(20),endX=sx,endY=sy+hostRelativeYDelta(20),liveRawYBattler="target",
          duration=71,startAngle=191,angleStep=5,paletteCycleDelay=1}
end

-- FireRed AnimCoinThrow. InitSpritePosToAnimAttacker(..., TRUE) provides
-- the launch point, args 2/3 are the target-relative destination offsets, and
-- arg 4 is an 8.8 speed value rather than a duration. The coin is rotated once
-- at creation so its vertical source art points along the travel vector.
function M.coinThrow(args, ctx)
  local a,t=assert(ctx.attacker),assert(ctx.target)
  local sx,sy=initOn(a,a,t,true,args[1] or 0,args[2] or 0)
  local txoff=tonumber(args[3]) or 0
  if a.side ~= "player" then txoff=-txoff end
  local tx=(t.x2 or t.x)+txoff
  local ty=(t.yPicOffset or t.y)+(tonumber(args[4]) or 0)
  local speed=math.max(1,tonumber(args[5]) or 1) / 256
  local dx,dy=tx-sx,ty-sy
  local distance=math.sqrt(dx*dx+dy*dy)
  local duration=math.max(1,math.ceil(distance/speed))
  return {kind="coin_throw",startX=sx,startY=sy,endX=tx,endY=ty,duration=duration,
          speed=speed,rotation=math.atan2(dy,dx)+math.pi/2}
end

-- FireRed AnimFallingCoin. Cmd_createsprite supplies the target-center starting
-- position for this callback; it shifts down 8 px, then performs two 26-tick
-- sine bounces while drifting horizontally by floor(n/2) pixels. The second
-- bounce uses half the first amplitude. Its affine animation spins +10 GBA
-- angle units every frame for the full lifetime.
function M.fallingCoin(args, ctx)
  local a,t=assert(ctx.attacker),assert(ctx.target)
  local sx=(t.x2 or t.x)
  local sy=(t.yPicOffset or t.y)+8
  return {kind="falling_coin",startX=sx,startY=sy,endX=sx,endY=sy,duration=52,
          driftSign=(a.side=="player") and -1 or 1,spinStep=10}
end

-- FireRed AnimThrowProjectile: attacker-relative start, target-relative end,
-- 40-frame linear travel for Water Gun with a sinusoidal arc amplitude in arg 6.
function M.throwProjectile(args, ctx)
  local a,t=assert(ctx.attacker),assert(ctx.target)
  local sx,sy=initOn(a,a,t,true,args[1] or 0,args[2] or 0)
  local txoff=args[3] or 0
  if a.side ~= "player" then txoff=-txoff end
  local tx=(t.x2 or t.x)+txoff
  local ty=(t.yPicOffset or t.y)+(args[4] or 0)
  return {kind="throw_projectile",startX=sx,startY=sy,endX=tx,endY=ty,
          duration=math.max(1,args[5] or 1),arcAmplitude=args[6] or 0}
end

-- FireRed AnimWaterGunDroplet initializes on the target, then performs a
-- linear drip. In the original callback arg 4 is the translation duration and
-- also the destination Y delta; arg 3 supplies the destination X delta.
function M.waterGunDroplet(args, ctx)
  local a,t=assert(ctx.attacker),assert(ctx.target)
  local sx,sy=initOn(t,a,t,true,args[1] or 0,args[2] or 0)
  local duration=math.max(1,args[5] or 1)
  return {kind="water_gun_droplet",startX=sx,startY=sy,
          endX=sx+(args[3] or 0),endY=sy+(args[5] or 0),duration=duration,
          -- InitSpritePosToAnimTarget(..., TRUE): this is a target-local effect,
          -- not a projectile endpoint in synthetic battle space.
          liveLocalYBattler="target",
          -- gAffineAnims_Droplet: (-0x10,+0x10) for six frames, then the
          -- inverse for six frames, looping for the full drip.
          affineCycle=12,affineHalfPeriod=6,affineDelta=0x10}
end

-- FireRed AnimAcidPoisonBubble. The projectile starts at the attacker, then
-- uses the shared horizontal arc translator to the average defender position.
-- arg2 is the travel duration; arg4/arg5 are target-relative offsets.
function M.acidPoisonBubble(args, ctx)
  local a,t=assert(ctx.attacker),assert(ctx.target)
  local sx,sy=initOn(a,a,t,true,args[1] or 0,args[2] or 0)
  local txoff=tonumber(args[5]) or 0
  if a.side ~= "player" then txoff=-txoff end
  local tx=(t.x2 or t.x)+txoff
  local ty=(t.yPicOffset or t.y)+(tonumber(args[6]) or 0)
  return {kind="acid_poison_bubble",startX=sx,startY=sy,endX=tx,endY=ty,
          duration=math.max(1,tonumber(args[3]) or 1),arcAmplitude=-30}
end

-- FireRed AnimSludgeProjectile. The 16x16 poison bubble starts at the
-- attacker with script offsets, travels to target X2/Y_PIC_OFFSET over arg2
-- frames on the native -30 horizontal arc, and pulses from 0x160 scale by
-- -0x0A/+0x0A every ten frames.
function M.sludgeProjectile(args, ctx)
  local a,t=assert(ctx.attacker),assert(ctx.target)
  local sx,sy=initOn(a,a,t,true,args[1] or 0,args[2] or 0)
  local tx=(t.x2 or t.x)
  local ty=(t.yPicOffset or t.y)
  return {kind="sludge_projectile",startX=sx,startY=sy,endX=tx,endY=ty,
          duration=math.max(1,tonumber(args[3]) or 1),arcAmplitude=-30,
          affineStartScale=0x160/256,affinePulseDelta=0x0A/256,affinePulseHalf=10}
end

-- FireRed AnimAcidPoisonDroplet. The droplet is placed on the average
-- defender position and linearly falls by arg4 pixels over arg4 frames.
-- The initial X offset mirrors with attacker side, matching the native callback.
function M.acidPoisonDroplet(args, ctx)
  local a,t=assert(ctx.attacker),assert(ctx.target)
  local xoff=tonumber(args[1]) or 0
  if a.side ~= "player" then xoff=-xoff end
  local sx=(t.x2 or t.x)+xoff
  local sy=(t.yPicOffset or t.y)+(tonumber(args[2]) or 0)
  local duration=math.max(1,tonumber(args[5]) or 1)
  return {kind="acid_poison_droplet",startX=sx,startY=sy,
          endX=sx+(tonumber(args[3]) or 0),endY=sy+duration,duration=duration,
          affineCycle=12,affineHalfPeriod=6,affineDelta=0x10}
end


-- FireRed InitSwirlingFogAnim / AnimSwirlingFogAnim. Mist creates each cloud
-- on the attacker side, drifts it vertically for arg3 callbacks, and overlays
-- a 32x6 elliptical orbit whose phase begins at 64 and advances by 3.
function M.swirlingFog(args, ctx)
  local a,t=assert(ctx.attacker),assert(ctx.target)
  local onTarget=(tonumber(args[5]) or 0)~=0
  local b=onTarget and t or a
  local xoff=tonumber(args[1]) or 0
  local yoff=tonumber(args[2]) or 0
  -- Mist passes arg5=1 (average-side placement). Gen I battles are single, so
  -- the average side coordinate is the battler coordinate itself. Mirror the
  -- script X offset exactly by the selected battler's side.
  if b.side~="player" then xoff=-xoff end
  local sx=(b.x or b.x2)+xoff
  local sy=rawBattlerY(b,yoff)
  -- Native InitSwirlingFogAnim applies this correction based on the target side.
  if t.side=="player" then sy=sy+hostRelativeYDelta(8) end
  local nativeDuration=math.max(1,math.floor(tonumber(args[4]) or 1))
  return {kind="swirling_fog",startX=sx,startY=sy,endX=sx,
    endY=sy+(tonumber(args[3]) or 0),duration=nativeDuration+1,liveRawYBattler=onTarget and "target" or "attacker",
    nativeDuration=nativeDuration,setupFrames=1,angleStart=64,angleStep=3,
    orbitX=32,orbitY=-6}
end

-- FireRed AnimPetalDanceBigFlower. Starts from the attacker using raw slot
-- coordinates, translates vertically over arg3 ticks, and overlays the native
-- 32x5 elliptical orbit (angle starts at 0x40 and advances by 5).
function M.petalDanceBigFlower(args, ctx)
  local a,t=assert(ctx.attacker),assert(ctx.target)
  local sx,sy=initOn(a,a,t,false,tonumber(args[1]) or 0,tonumber(args[2]) or 0)
  local ty=(a.yPicOffset or a.y)+(tonumber(args[3]) or 0)
  return {kind="petal_dance_big",startX=sx,startY=sy,endX=sx,endY=ty,
    duration=math.max(1,math.floor(tonumber(args[4]) or 1)),angleStart=0x40,angleStep=5}
end

-- FireRed AnimPetalDanceSmallFlower. Starts from the attacker picture
-- coordinate, floats vertically over arg3 ticks and sways 8 px left/right.
function M.petalDanceSmallFlower(args, ctx)
  local a,t=assert(ctx.attacker),assert(ctx.target)
  local sx,sy=initOn(a,a,t,true,tonumber(args[1]) or 0,tonumber(args[2]) or 0)
  local ty=(a.yPicOffset or a.y)+(tonumber(args[3]) or 0)
  return {kind="petal_dance_small",startX=sx,startY=sy,endX=sx,endY=ty,
    duration=math.max(1,math.floor(tonumber(args[4]) or 1)),angleStart=0x40,angleStep=5}
end

-- FireRed AnimRazorLeafParticle. The leaf moves by the script's X/Y deltas
-- for arg2 frames, pauses one callback tick while switching phase, then sways
-- horizontally while drifting down one pixel every other frame. The native
-- callback destroys it after the falling counter exceeds 80.
function M.razorLeafParticle(args, ctx)
  local a,t=assert(ctx.attacker),assert(ctx.target)
  local sx,sy=pos(a,true)
  local launch=math.max(0,args[3] or 0)
  local launchDY=args[2] or 0
  return {kind="razor_leaf_particle",startX=sx,startY=sy,
          launchDX=args[1] or 0,launchDY=launchDY,launchDuration=launch,
          phase2Start=launch+1,duration=launch+82,
          phase2Angle=(launchDY % 2 ~= 0) and 0x80 or 0,
          swaySign=(a.side=="player") and 1 or -1}
end

-- FireRed AnimTranslateLinearSingleSineWave. Args 0/1 are attacker-relative
-- start offsets, 2/3 target-relative offsets, 4 duration, 5 wave amplitude.
function M.translateLinearSingleSineWave(args, ctx)
  local a,t=assert(ctx.attacker),assert(ctx.target)
  local sx,sy=initOn(a,a,t,true,args[1] or 0,args[2] or 0)
  local txoff=args[3] or 0
  if a.side ~= "player" then txoff=-txoff end
  local tx=(t.x2 or t.x)+txoff
  local ty=(t.yPicOffset or t.y)+(args[4] or 0)
  return {kind="linear_single_sine",startX=sx,startY=sy,endX=tx,endY=ty,
          duration=math.max(1,args[5] or 1),waveAmplitude=args[6] or 0}
end


-- FireRed AnimDragonFireToTarget / StartDragonFireTranslation. Dragon Rage
-- launches its ember from attacker picture coordinates to target picture
-- coordinates over arg4 frames. The native callback uses a different X launch
-- offset on the opponent side and selects the mirrored affine variant there.
function M.dragonFireToTarget(args, ctx)
  local a,t=assert(ctx.attacker),assert(ctx.target)
  local sx=(a.x2 or a.x)
  local sy=(a.yPicOffset or a.y)
  local tx=(t.x2 or t.x)
  local ty=(t.yPicOffset or t.y)
  local opponent=a.side ~= "player"
  if opponent then
    sx=sx-(tonumber(args[2]) or 0)
    sy=sy+(tonumber(args[2]) or 0)
    tx=tx-(tonumber(args[3]) or 0)
    ty=ty+(tonumber(args[4]) or 0)
  else
    sx=sx+(tonumber(args[1]) or 0)
    sy=sy+(tonumber(args[2]) or 0)
    tx=tx+(tonumber(args[3]) or 0)
    ty=ty+(tonumber(args[4]) or 0)
  end
  return {kind="dragon_fire_to_target",startX=sx,startY=sy,endX=tx,endY=ty,
    duration=math.max(1,math.floor(tonumber(args[5]) or 1)),opponent=opponent}
end

-- FireRed AnimDragonRageFirePlume. The plume is placed on attacker or target
-- using BATTLER_COORD_X/Y, receives the side-aware native X offset, and dies
-- when its five-frame-by-five-step sprite animation finishes.
function M.dragonRageFirePlume(args, ctx)
  local a,t=assert(ctx.attacker),assert(ctx.target)
  local useTarget=(tonumber(args[1]) or 0)~=0
  local b=useTarget and t or a
  local xoff=tonumber(args[2]) or 0
  if a.side ~= "player" then xoff=-xoff end
  local sx=(b.x or b.x2)+xoff
  local sy=rawBattlerYPattern(b,tonumber(args[3]) or 0)
  return {kind="dragon_rage_fire_plume",startX=sx,startY=sy,endX=sx,endY=sy,duration=25,
    liveRawYBattler=useTarget and "target" or "attacker"}
end

-- FireRed AnimWaterBubbleProjectile. During its 50-frame travel the bubble's
-- sprite animation is paused while a linear translation is combined with a
-- sine/cosine orbit whose amplitudes and phase come from the script. On
-- arrival the native callback releases the 0/4/8 tile animation, then waits
-- ten more frames before destruction.
function M.waterBubbleProjectile(args, ctx)
  local a,t=assert(ctx.attacker),assert(ctx.target)
  local sx,sy=pos(a,true)
  local xoff=args[1] or 0
  if a.side ~= "player" then xoff=-xoff end
  sx=sx+xoff
  sy=sy+(args[2] or 0)
  local tx,ty=(t.x2 or t.x),(t.yPicOffset or t.y)
  local travel=math.max(1,args[7] or 1)
  return {kind="water_bubble_projectile",startX=sx,startY=sy,endX=tx,endY=ty,
          duration=travel+21,travelDuration=travel,
          waveX=args[3] or 0,waveY=args[4] or 0,
          startAngle=args[5] or 0,angleStep=(args[6] or 0)/256,
          -- This is a discrete projectile that visually hands off to target-local
          -- bubble impacts. Rebase only its destination into the same live
          -- target-local coordinate space; the launch point stays attacker-based.
          liveTargetEndpointY=true}
end


-- FireRed AnimFireSpiralInward (Fire Punch lead-in). The sprite is created at
-- the target picture center. The callback immediately starts a 30-tick growing
-- circle with radius 60, angle step 9, and signed 8.8 radius delta -0x200,
-- which makes the ember spiral inward by 2 px per tick.
function M.fireSpiralInward(args, ctx)
  local t=assert(ctx.target)
  local sx=(t.x2 or t.x)
  local sy=(t.yPicOffset or t.y)
  return {
    kind="fire_spiral_inward",startX=sx,startY=sy,endX=sx,endY=sy,
    duration=30,initialAngle=tonumber(args[1]) or 0,
    initialRadius=60,angleStep=9,radiusSpeed=-0x200,
  }
end

-- FireRed AnimFireSpread (Fire Punch impact burst). Creation is target-relative;
-- the first callback tick begins on the next frame and adds signed 8.8 X/Y
-- velocities for arg4 ticks before destruction.
function M.fireSpread(args, ctx)
  local a,t=assert(ctx.attacker),assert(ctx.target)
  local xoff=tonumber(args[1]) or 0
  if (a.x2 or a.x) > (t.x2 or t.x) then xoff=-xoff
  elseif (a.x2 or a.x) == (t.x2 or t.x) and a.side ~= "player" then xoff=-xoff end
  local sx=(t.x2 or t.x)+xoff
  local sy=(t.yPicOffset or t.y)+(tonumber(args[2]) or 0)
  local nativeDuration=math.max(0,math.floor(tonumber(args[5]) or 0))
  return {
    kind="fire_spread",startX=sx,startY=sy,endX=sx,endY=sy,
    duration=nativeDuration+1,nativeDuration=nativeDuration,
    speedX=tonumber(args[3]) or 0,speedY=tonumber(args[4]) or 0,
  }
end

-- FireRed AnimParticleInVortex, used by Fire Spin (and Sand Tomb). The
-- sprite is initialized on attacker or target according to arg6, then rises
-- using signed 8.8 fixed-point Y velocity while orbiting horizontally with a
-- GBA 256-step sine wave. The first callback tick performs setup only; motion
-- begins on the following tick.
function M.particleInVortex(args, ctx)
  local a,t=assert(ctx.attacker),assert(ctx.target)
  local useTarget=not (args[7]==0 or args[7]=="attacker")
  local base=useTarget and t or a
  local sx,sy=initOn(base,a,t,false,args[1] or 0,args[2] or 0)
  local nativeDuration=math.max(0,math.floor(tonumber(args[4]) or 0))
  return {
    kind="particle_in_vortex",startX=sx,startY=sy,endX=sx,endY=sy,liveRawYBattler=((tonumber(args[7]) or 0)==0) and "attacker" or "target",
    -- One visible setup frame plus nativeDuration motion frames. The callback
    -- destroys on the following decrement to -1.
    duration=nativeDuration+1,nativeDuration=nativeDuration,
    verticalSpeed=tonumber(args[3]) or 0,
    phaseStep=tonumber(args[5]) or 0,amplitude=tonumber(args[6]) or 0,
    anchor=useTarget and "target" or "attacker",
  }
end

-- FireRed AnimBubbleEffect, shared by Bubble/BubbleBeam and poison-bubble
-- after-effects. The bubble rises, sways 4px side-to-side and scales from
-- 0x9C to 0x100 over 20 frames.
-- FireRed AnimSmallBubblePair, used by Crabhammer. The tiny two-bubble
-- sprite starts target- or attacker-relative, sways 4 px horizontally while
-- rising in signed 8.8 fixed-point steps of 48, and lives for arg2+1 ticks.
function M.smallBubblePair(args, ctx)
  local a,t=assert(ctx.attacker),assert(ctx.target)
  local useTarget=not (args[4]=="attacker" or args[4]==0)
  local base=useTarget and t or a
  local sx,sy=initOn(base,a,t,true,args[1] or 0,args[2] or 0)
  local nativeDuration=math.max(0,math.floor(tonumber(args[3]) or 0))
  return {kind="small_bubble_pair",startX=sx,startY=sy,endX=sx,endY=sy,
    duration=nativeDuration+1,nativeDuration=nativeDuration}
end

-- FireRed AnimSmallDriftingBubbles. The sprite initializes on the target
-- with script x/y offsets, switches to the small-bubble tile at +8, then
-- receives a fresh random horizontal 8.8 speed/sign and downward 8.8 speed
-- for this move execution. Random values are resolved when the cached plan is
-- instantiated so repeated uses do not freeze the same drift pattern.
function M.smallDriftingBubbles(args, ctx)
  local a,t=assert(ctx.attacker),assert(ctx.target)
  local sx,sy=initOn(t,a,t,true,args[1] or 0,args[2] or 0)
  return {kind="small_drifting_bubbles",startX=sx,startY=sy,endX=sx,endY=sy,
    duration=21,randomDrift=true}
end

function M.bubbleEffect(args, ctx)
  local a,t=assert(ctx.attacker),assert(ctx.target)
  local sx,sy=initOn(t,a,t,true,args[1] or 0,args[2] or 0)
  -- FireRed AnimBubbleEffect is target-picture-relative and applies only the
  -- script-provided offsets. No side-specific host Y correction belongs here.
  return {kind="bubble_effect",startX=sx,startY=sy,endX=sx,endY=sy,duration=20}
end

-- FireRed AnimAbsorptionOrb. Starts on the target with script offsets,
-- travels to the attacker over arg3 frames, and uses arg2 as the horizontal
-- arc amplitude. The sprite itself shrinks by 5/256 each frame.
function M.absorptionOrb(args, ctx)
  local a,t=assert(ctx.attacker),assert(ctx.target)
  local sx,sy=initOn(t,a,t,true,args[1] or 0,args[2] or 0)
  local ex,ey=(a.x2 or a.x),(a.yPicOffset or a.y)
  local duration=math.max(1,math.floor(tonumber(args[4]) or 1))
  return {kind="absorption_orb",startX=sx,startY=sy,endX=ex,endY=ey,
    duration=duration,arcAmplitude=tonumber(args[3]) or 0,
    affineScaleDelta=-5/256}
end

-- FireRed AnimHyperBeamOrb. Each 8x8 orb starts 20 px in front of the
-- attacker, picks a native-style random speed/phase/tile, then travels toward
-- the target while oscillating vertically with a 12 px cosine wave.
function M.hyperBeamOrb(args, ctx, seed)
  local a,t=assert(ctx.attacker),assert(ctx.target)
  local sx=(a.x2 or a.x)+((a.side=="player") and 20 or -20)
  local sy=(a.yPicOffset or a.y)
  local ex,ey=(t.x2 or t.x),(t.yPicOffset or t.y)
  seed=math.floor(tonumber(seed) or 0)
  local speed=64+(seed%32)
  local distance=math.sqrt((ex-sx)^2+(ey-sy)^2)
  local duration=math.max(1,math.floor(distance*16/speed+0.5))
  return {kind="hyper_beam_orb",startX=sx,startY=sy,endX=ex,endY=ey,
    duration=duration,phase=(seed*37)%256,phaseStep=24,waveAmplitude=12,
    tileOffset=seed%8}
end


-- FireRed AnimPowerAbsorptionOrb. Starts at an attacker-relative script offset
-- and translates straight back to the attacker over arg2 native frames while
-- shrinking by 5/256 each callback.
function M.powerAbsorptionOrb(args, ctx)
  local a,t=assert(ctx.attacker),assert(ctx.target)
  local sx,sy=initOn(a,a,t,true,args[1] or 0,args[2] or 0)
  local ex,ey=(a.x2 or a.x),(a.yPicOffset or a.y)
  local duration=math.max(1,math.floor(tonumber(args[3]) or 1))
  return {kind="power_absorption_orb",startX=sx,startY=sy,endX=ex,endY=ey,
    duration=duration,affineScaleDelta=-5/256,tileOffset=8}
end

-- FireRed AnimSolarBeamBigOrb. One of seven 8x8 orb frames travels in a
-- straight line from attacker + script offset to the target over arg2 frames.
function M.solarBeamBigOrb(args, ctx)
  local a,t=assert(ctx.attacker),assert(ctx.target)
  local sx,sy=initOn(a,a,t,true,args[1] or 0,args[2] or 0)
  local ex,ey=(t.x2 or t.x),(t.yPicOffset or t.y)
  local duration=math.max(1,math.floor(tonumber(args[3]) or 1))
  local tile=math.max(0,math.min(6,math.floor(tonumber(args[4]) or 0)))
  return {kind="solar_beam_big_orb",startX=sx,startY=sy,endX=ex,endY=ey,
    duration=duration,tileOffset=tile}
end

-- FireRed AnimSolarBeamSmallOrb. The small secondary orb translates linearly
-- attacker->target while orbiting the beam line with Sin(phase,5)/Cos(phase,14).
function M.solarBeamSmallOrb(args, ctx)
  local a,t=assert(ctx.attacker),assert(ctx.target)
  local sx,sy=initOn(a,a,t,true,args[1] or 0,args[2] or 0)
  local ex,ey=(t.x2 or t.x),(t.yPicOffset or t.y)
  local duration=math.max(1,math.floor(tonumber(args[3]) or 1))
  return {kind="solar_beam_small_orb",startX=sx,startY=sy,endX=ex,endY=ey,
    duration=duration,phase=math.floor(tonumber(args[4]) or 0)%256,
    phaseStep=15,xAmplitude=5,yAmplitude=14,tileOffset=7}
end

-- FireRed AnimToTargetInSinWave. Used by Psywave's blue rings and shared by
-- several undulating beam effects. The sprite travels linearly from attacker
-- to target over 30 native callbacks while a sine offset is added to Y.
-- phaseStart is supplied by AnimTask_StartSinAnimTimer (gBattleAnimArgs[7]).
function M.toTargetInSinWave(args, ctx, phaseStart)
  local a,t=assert(ctx.attacker),assert(ctx.target)
  local sx,sy=initOn(a,a,t,true,args[1] or 0,args[2] or 0)
  local ex,ey=(t.x2 or t.x),(t.yPicOffset or t.y)
  return {kind="sin_wave_to_target",startX=sx,startY=sy,endX=ex,endY=ey,
    duration=30,nativeDuration=30,waveAmplitude=tonumber(args[4]) or 0,
    phaseStart=(math.floor(tonumber(phaseStart) or 0))%256,phaseStep=7}
end


-- FireRed AnimFireRing, used by Fire Blast. The ember orbits the attacker for
-- 18 callbacks, travels to the target over 25 callbacks while retaining a
-- 28px rotating offset, then orbits the target for 31 callbacks.
function M.fireBlastRing(args, ctx)
  local a,t=assert(ctx.attacker),assert(ctx.target)
  local sx,sy=initOn(a,a,t,true,args[1] or 0,args[2] or 0)
  local tx,ty=(t.x2 or t.x),(t.yPicOffset or t.y)
  return {kind="fire_blast_ring",startX=sx,startY=sy,targetX=tx,targetY=ty,
    duration=75,initialAngle=tonumber(args[3]) or 0,radius=28,angleStep=20,
    orbitIn=18,travelDuration=25,orbitOut=31}
end

-- FireRed AnimFireCross. Starts target-relative and moves by whole-pixel
-- deltas for the requested number of TranslateSpriteLinear callbacks.
function M.fireBlastCross(args, ctx)
  local t=assert(ctx.target)
  local sx=(t.x2 or t.x)+(tonumber(args[1]) or 0)
  local sy=(t.yPicOffset or t.y)+(tonumber(args[2]) or 0)
  local d=math.max(1,math.floor(tonumber(args[3]) or 1))
  return {kind="fire_blast_cross",startX=sx,startY=sy,endX=sx,endY=sy,
    duration=d+1,nativeDuration=d,dx=tonumber(args[4]) or 0,dy=tonumber(args[5]) or 0}
end

-- FireRed AnimMimicOrb. The orb appears on the target after one setup
-- callback, grows from a zero affine matrix for 14 frames, then travels to the
-- attacker over 25 frames while its affine matrix decreases by 16 per frame.
function M.mimicOrb(args, ctx)
  local a,t=assert(ctx.attacker),assert(ctx.target)
  local xoff=tonumber(args[1]) or 0
  if t.side=="player" then xoff=-xoff end
  local sx=(t.x2 or t.x)+xoff
  local sy=(t.yPicOffset or t.y)+(tonumber(args[2]) or 0)
  local ex=(a.x2 or a.x)
  local ey=(a.yPicOffset or a.y)
  return {kind="mimic_orb",startX=sx,startY=sy,endX=ex,endY=ey,
    growFrames=14,travelDuration=25,duration=41}
end

-- FireRed AnimSoftBoiledEgg. The egg begins at the attacker + script offsets,
-- follows the native fixed-point hop for 51 callbacks, pauses for 21 callbacks,
-- then performs the squash/crack sequence. The shell/yolk variant is selected by
-- arg2. Both remain owned by the callback until script arg 7 releases them.
function M.softBoiledEgg(args, ctx)
  local a=assert(ctx.attacker)
  local sx=(a.x2 or a.x)+(tonumber(args[1]) or 0)
  local sy=(a.yPicOffset or a.y)+(tonumber(args[2]) or 0)
  return {kind="soft_boiled_egg",startX=sx,startY=sy,playerSide=(a.side=="player"),
    variant=math.floor(tonumber(args[3]) or 0),hopFrames=51,holdFrames=21,
    crackFrame=104,releaseFrame=195,duration=196}
end

local function frameAnim(template)
  return clone(template.anim)
end

local function addSprite(out, frame, templateName, template, args, ctx, subpriorityAnchor, priorityModifier, alphaBlend, runtimeState)
  if template.controller and template.callback == "AnimSimplePaletteBlend" then
    local startAmount=tonumber(args[3]) or 0
    local endAmount=tonumber(args[4]) or 0
    local delay=math.max(0,math.floor(tonumber(args[2]) or 0))
    local steps=math.abs(endAmount-startAmount)
    -- BeginNormalPaletteFade advances one blend step every (delay + 1)
    -- frames, then remains active through the final target amount update.
    local duration=math.max(1,steps*(delay+1)+1)
    out[#out+1]={
      kind="palette_blend", frame=frame, selector=args[1] or "target",
      delay=delay, startAmount=startAmount, endAmount=endAmount,
      color=args[5] or {0,0,0}, duration=duration, destroyFrame=frame+duration,
      effectEndFrame=nil,
    }
    return
  end
  if template.controller and template.callback == "AnimComplexPaletteBlend" then
    -- FireRed applies amountA/colorA immediately, then after each delay window
    -- alternates to amountB/colorB and back for `cycles` state changes. These
    -- are discrete BlendPalettes calls, not a continuous color interpolation.
    local selector=args[1] or "all_and_bg"
    local delay=math.max(0,math.floor(tonumber(args[2]) or 0))
    local cycles=math.max(0,math.floor(tonumber(args[3]) or 0))
    local colorA=args[4] or "black"
    local amountA=math.max(0,math.min(16,tonumber(args[5]) or 0))
    local colorB=args[6] or colorA
    local amountB=math.max(0,math.min(16,tonumber(args[7]) or 0))
    local hold=delay+1
    local paletteSteps={{start=0,finish=hold,amount=amountA,color=colorA}}
    for n=1,cycles do
      local useB=(n%2)==1
      paletteSteps[#paletteSteps+1]={start=n*hold,finish=(n+1)*hold,
        amount=useB and amountB or amountA,color=useB and colorB or colorA}
    end
    local duration=math.max(1,(cycles+1)*hold+1)
    local function emit(target)
      out[#out+1]={kind="palette_blend",frame=frame,target=target,
        color=colorA,startAmount=amountA,endAmount=0,duration=duration,
        paletteSteps=paletteSteps,destroyFrame=frame+duration,
        effectEndFrame=frame+duration}
    end
    if selector=="all_and_bg" then emit("all"); emit("bg") else emit(selector) end
    return
  end
  if template.controller and template.callback == "DoHorizontalLunge" then
    local duration=(args[1] or 0)*2
    out[#out+1]={kind="battler_motion",motionKind="horizontal_lunge",battler="attacker",frame=frame,duration=duration,delta=args[2] or 0,destroyFrame=frame+duration}
    return
  end
  if template.controller and template.callback == "DoVerticalDip" then
    -- FireRed DoVerticalDip: one setup callback, N one-pixel steps in one
    -- direction, one callback to reverse direction, N steps back, then the
    -- controller destroys on the following callback.
    local battler=args[3] or "attacker"
    local dipDuration=math.max(1,math.floor(tonumber(args[1]) or 1))
    local duration=dipDuration*2+3
    out[#out+1]={kind="battler_motion",motionKind="vertical_dip",battler=battler,
      frame=frame,dipDuration=dipDuration,deltaY=tonumber(args[2]) or 0,
      duration=duration,destroyFrame=frame+duration}
    return
  end
  if template.controller and template.callback == "SlideMonToOffset" then
    -- FireRed SlideMonToOffset writes a signed 8.8 translation directly to
    -- the battler's x2/y2. The controller dies after the translation but the
    -- resulting battler offset persists until a later explicit return.
    local battler=((args[1] or 0)==1) and "target" or "attacker"
    local moveDuration=math.max(1,math.floor(tonumber(args[5]) or 1))
    -- A newer absolute slide replaces an older held offset for this battler.
    for i=#out,1,-1 do
      local prior=out[i]
      if prior.kind=="battler_motion"
          and (prior.motionKind=="slide_to_offset" or prior.motionKind=="shake_and_sink")
          and prior.battler==battler and not prior.holdUntilFrame then
        prior.holdUntilFrame=frame
        break
      end
    end
    local controllerDuration=moveDuration+2 -- setup + N translate ticks + destroy
    out[#out+1]={kind="battler_motion",motionKind="slide_to_offset",battler=battler,
      frame=frame,targetX=tonumber(args[2]) or 0,targetY=tonumber(args[3]) or 0,
      mirrorY=((tonumber(args[4]) or 0)==1),moveDuration=moveDuration,
      duration=controllerDuration,destroyFrame=frame+controllerDuration}
    return
  end
  if template.controller and template.callback == "SlideMonToOriginalPos" then
    -- FireRed dummy controller sprite. Capture the battler's live x2/y2 when
    -- this sprite begins, then linearly return the requested axes to zero.
    -- The extra frame models the native callback's final data[0] == 0 cleanup.
    local battler=((args[1] or 0)==1) and "target" or "attacker"
    local direction=tonumber(args[2]) or 0
    local duration=math.max(1,math.floor(tonumber(args[3]) or 1))
    for i=#out,1,-1 do
      local prior=out[i]
      if prior.kind=="battler_motion"
          and (prior.motionKind=="slide_to_offset" or prior.motionKind=="shake_and_sink")
          and prior.battler==battler and not prior.holdUntilFrame then
        prior.holdUntilFrame=frame
        break
      end
    end
    out[#out+1]={kind="battler_motion",motionKind="slide_to_original",battler=battler,
      frame=frame,direction=direction,duration=duration+1,slideDuration=duration,
      destroyFrame=frame+duration+1}
    return
  end
  local motion
  if template.callback == "AnimSleepLetterZ" then
    -- FireRed AnimSleepLetterZ: start from attacker coordinates. Player-side
    -- Z uses +arg0 and positive horizontal drift; opponent-side mirrors both.
    -- data[1] runs 0..60, so the native callback owns 61 visible ticks.
    local a=assert(ctx.attacker)
    local playerSide=(a.isPlayer==true or a.side=="player")
    local x=(a.x2 or a.x)+(playerSide and (args[1] or 0) or -(args[1] or 0))
    local y=(a.yPicOffset or a.y)+(args[2] or 0)
    motion={kind="sleep_letter_z",startX=x,startY=y,endX=x,endY=y,duration=61,
      playerSide=playerSide}
  elseif template.callback == "TranslateAnimSpriteToTargetMonLocation" then
    motion = M.translateToTarget(args, ctx)
  elseif template.callback == "AnimEmberFlare" then
    motion = M.emberFlare(args, ctx)
  elseif template.callback == "AnimSlideHandOrFootToTarget" then
    motion = M.slideHandOrFootToTarget(args, ctx)
  elseif template.callback == "AnimJumpKick" then
    -- FireRed AnimJumpKick only adds contest-specific sign flips before
    -- delegating to AnimSlideHandOrFootToTarget. Contests are not used by
    -- this battle bridge, so normal battles use the shared native path.
    motion = M.slideHandOrFootToTarget(args, ctx)
  elseif template.callback == "AnimMovePowderParticle" then
    motion = M.powderParticle(args, ctx)
  elseif template.callback == "AnimSlidingKick" then
    motion = M.slidingKick(args, ctx)
  elseif template.callback == "AnimSpinningKickOrPunch" then
    motion = M.spinningKickOrPunch(args, ctx)
  elseif template.callback == "AnimAbsorptionOrb" then
    motion = M.absorptionOrb(args, ctx)
  elseif template.callback == "AnimHyperBeamOrb" then
    local seed=(frame*131 + (#out+1)*17 + (priorityModifier or 0)*7) % 65536
    motion = M.hyperBeamOrb(args, ctx, seed)
  elseif template.callback == "AnimPowerAbsorptionOrb" then
    motion = M.powerAbsorptionOrb(args, ctx)
  elseif template.callback == "AnimMimicOrb" then
    motion = M.mimicOrb(args, ctx)
  elseif template.callback == "AnimSoftBoiledEgg" then
    motion = M.softBoiledEgg(args, ctx)
  elseif template.callback == "AnimConversion" then
    local a=assert(ctx.attacker)
    local x=(a.x or a.x2)+(tonumber(args[1]) or 0)
    local y=(a.y or a.yPicOffset)+(tonumber(args[2]) or 0)
    -- Native AnimConversion has no movement and survives until the shared
    -- alpha task sets arg7=0xFFFF. Keep it alive well past the fade.
    motion={kind="conversion_particle",startX=x,startY=y,endX=x,endY=y,duration=CONVERSION_PROVISIONAL_DURATION}
  elseif template.callback == "AnimMovementWaves" then
    -- FireRed AnimMovementWaves. Args: battler selector, side, repeat count.
    -- Struggle creates two 32x32 wave sprites 32 px to either side of the
    -- attacker, each replaying its 32-frame animation twice.
    local a,t=assert(ctx.attacker),assert(ctx.target)
    local useTarget=(args[1] or 0)~=0
    local b=useTarget and t or a
    local side=math.floor(tonumber(args[2]) or 0)
    local repeats=math.max(0,math.floor(tonumber(args[3]) or 0))
    local x=(b.x2 or b.x)+(side==0 and 32 or -32)
    local y=(b.yPicOffset or b.y)
    -- Each native wave animation is exactly 32 frames (4 x 8), and
    -- AnimMovementWaves restarts it until the requested repeat count expires.
    local duration=(repeats==0) and 1 or (32*repeats)
    motion={kind="movement_waves",startX=x,startY=y,endX=x,endY=y,
      duration=duration,animVariant=side,repeats=repeats}
  elseif template.callback == "AnimSharpenSphere" then
    -- FireRed AnimSharpenSphere: fixed at attacker X_2 / Y_PIC_OFFSET - 12.
    -- The callback owns a 287-tick accelerating blink cadence after the
    -- 192-frame sphere-to-cube tile animation has completed.
    local a=assert(ctx.attacker)
    local x=(a.x2 or a.x)
    local y=(a.yPicOffset or a.y)-12
    motion={kind="sharpen_sphere",startX=x,startY=y,endX=x,endY=y,duration=287}
  elseif template.callback == "AnimSolarBeamBigOrb" then
    motion = M.solarBeamBigOrb(args, ctx)
  elseif template.callback == "AnimSolarBeamSmallOrb" then
    motion = M.solarBeamSmallOrb(args, ctx)
  elseif template.callback == "AnimToTargetInSinWave" then
    local timerStart=runtimeState and runtimeState.sinAnimTimerStartFrame
    local phaseStart=timerStart and (((frame-timerStart)*3)%256) or 0
    motion = M.toTargetInSinWave(args, ctx, phaseStart)
  elseif template.callback == "AnimConfuseRayBallBounce" then
    motion = M.confuseRayBounce(args, ctx)
  elseif template.callback == "AnimConfuseRayBallSpiral" then
    motion = M.confuseRaySpiral(args, ctx)
  elseif template.callback == "AnimAuroraBeamRings" then
    -- FireRed AnimAuroraBeamRings: start 20 px in front of the attacker,
    -- linearly reach the target in 17 frames, while the shared ring palette
    -- rotates every three frames. Once gBattleAnimArgs[7] becomes 0xFFFF the
    -- ring switches to tile 4 and runs its two-frame 1.0 -> 1.375 affine grow.
    local a,t=assert(ctx.attacker),assert(ctx.target)
    local sx,sy=initOn(a,a,t,true,args[1] or 0,args[2] or 0)
    local txoff=args[3] or 0
    if a.side ~= "player" then txoff=-txoff end
    local tx=(t.x2 or t.x)+txoff
    local ty=(t.yPicOffset or t.y)+(args[4] or 0)
    motion={kind="aurora_beam_ring",startX=sx,startY=sy,endX=tx,endY=ty,
      duration=args[5] or 17,nativeDuration=args[5] or 17,
      paletteCycleStartFrame=runtimeState and runtimeState.auroraPaletteStartFrame or frame,
      transformFrame=(runtimeState and runtimeState.arg7ffffFrame) or nil}
  elseif template.callback == "AnimIcePunchSwirlingParticle" then
    -- FireRed AnimIcePunchSwirlingParticle immediately enters
    -- TranslateSpriteInGrowingCircle with radius 60, angle step 9 and
    -- signed 8.8 radius delta -0x200 for 30 callbacks. The large 8x16
    -- crystal also rotates by +40 affine units per frame.
    local t=assert(ctx.target)
    local sx=(t.x2 or t.x)
    local sy=(t.yPicOffset or t.y)
    motion={kind="ice_punch_swirl",startX=sx,startY=sy,endX=sx,endY=sy,duration=30,
      initialAngle=tonumber(args[1]) or 0,initialRadius=60,angleStep=9,radiusSpeed=-0x200,
      affineRotationStep=(template.oam and template.oam.affine) and 40 or 0}
  elseif template.callback == "AnimIceBeamParticle" then
    local a,t=assert(ctx.attacker),assert(ctx.target)
    local sx,sy=initOn(a,a,t,true,args[1] or 0,args[2] or 0)
    local txoff=args[3] or 0
    if a.side ~= "player" then txoff=-txoff end
    local tx=(t.x2 or t.x)+txoff
    local ty=(t.yPicOffset or t.y)+(args[4] or 0)
    motion={kind="ice_beam_particle",startX=sx,startY=sy,endX=tx,endY=ty,
      duration=args[5] or 1,
      -- Only the 8x16 inner crystal uses sAffineAnim_IceBeamInnerCrystal:
      -- +10 rotation units every frame, looping for the sprite lifetime.
      affineRotationStep=(template.oam and template.oam.affine) and 10 or 0}
  elseif template.callback == "AnimIceEffectParticle" then
    local t=assert(ctx.target)
    local x=(t.x2 or t.x)+(args[1] or 0)
    local y=(t.yPicOffset or t.y)+(args[2] or 0)
    -- FireRed sAffineAnim_IceCrystalHit: scale starts at 0xCE, grows by 5
    -- for 10 frames, holds for 6, then flickers for 20 frames.
    motion={kind="ice_effect_particle",startX=x,startY=y,endX=x,endY=y,duration=36,
      affineFrames=16,flickerStart=16,startScale=0xCE/256,scaleStep=5/256,scaleStepFrames=10}
  elseif template.callback == "AnimSwirlingSnowball" then
    -- FireRed Blizzard/Icy Wind snowball: derive the fast-linear speed from
    -- attacker->target X distance, extend the same line off both screen edges,
    -- then orbit the target for 32 callbacks before continuing off-screen.
    local a,t=assert(ctx.attacker),assert(ctx.target)
    local sx,sy=initOn(a,a,t,true,args[1] or 0,args[2] or 0)
    local txoff=args[3] or 0
    if a.side ~= "player" then txoff=-txoff end
    local tx=(t.x2 or t.x)+txoff
    local ty=(t.yPicOffset or t.y)+(args[4] or 0)
    local speed=math.max(1,tonumber(args[5]) or 72)
    local baseFrames=math.max(1,math.floor((math.abs(tx-sx)*16)/speed))
    local dx=(tx-sx)/baseFrames; local dy=(ty-sy)/baseFrames
    local function extend(x,y,dir)
      local n=0
      while n<512 and x>=-16 and x<=256 and y>=-16 and y<=160 do
        x=x+dx*dir; y=y+dy*dir; n=n+1
      end
      return x,y,n
    end
    local ox,oy,inFrames=extend(sx,sy,-1)
    local ex,ey,outFrames=extend(tx,ty,1)
    motion={kind="swirling_snowball",startX=ox,startY=oy,targetX=tx,targetY=ty,
      endX=ex,endY=ey,inFrames=inFrames+baseFrames,orbitFrames=32,outFrames=outFrames,
      orbitX=(a.side=="player") and -20 or 20,orbitY=15,
      duration=inFrames+baseFrames+32+outFrames+2}
  elseif template.callback == "AnimMoveParticleBeyondTarget" then
    -- FireRed AnimMoveParticleBeyondTarget. The native helper derives the
    -- translation duration as abs(dx)*16/speed, then extends that same vector
    -- backward and forward until the particle is outside the GBA viewport.
    local a,t=assert(ctx.attacker),assert(ctx.target)
    local sx,sy=initOn(a,a,t,true,args[1] or 0,args[2] or 0)
    local txoff=args[3] or 0
    if a.side ~= "player" then txoff=-txoff end
    local tx=(t.x2 or t.x)+txoff
    local ty=(t.yPicOffset or t.y)+(args[4] or 0)
    local speed=math.max(1,tonumber(args[5]) or 80)
    local baseFrames=math.max(1,math.floor((math.abs(tx-sx)*16)/speed))
    local dx=(tx-sx)/baseFrames; local dy=(ty-sy)/baseFrames
    local function extend(x,y,dir)
      local n=0
      while n<512 and x>=-16 and x<=256 and y>=-16 and y<=160 do
        x=x+dx*dir; y=y+dy*dir; n=n+1
      end
      return x,y,n
    end
    local ox,oy,inFrames=extend(sx,sy,-1)
    local ex,ey,outFrames=extend(tx,ty,1)
    motion={kind="move_particle_beyond_target",startX=ox,startY=oy,targetX=tx,targetY=ty,
      endX=ex,endY=ey,inFrames=inFrames+baseFrames,outFrames=outFrames,
      waveAmplitude=tonumber(args[6]) or 0,waveFrequency=tonumber(args[7]) or 0,
      duration=inFrames+baseFrames+outFrames+2}
  elseif template.callback == "AnimHornHit" then
    -- FireRed AnimHornHit. Args: target-relative X/Y offset and travel time.
    -- Player-side attackers launch from 40 px left / 20 px below the final
    -- point; enemy attackers launch from 40 px right / 20 px above and flip.
    local t=assert(ctx.target)
    local ex=(t.x2 or t.x)+(args[1] or 0)
    local ey=(t.yPicOffset or t.y)+(args[2] or 0)
    local duration=math.max(2,math.min(127,args[3] or 10))
    local playerAttacker=(ctx.attacker.side=="player")
    local sx=ex+(playerAttacker and -40 or 40)
    local sy=ey+(playerAttacker and 20 or -20)
    motion={kind="horn_hit",startX=sx,startY=sy,endX=ex,endY=ey,duration=duration,
      hFlip=not playerAttacker,vFlip=not playerAttacker}
  elseif template.callback == "AnimFlashingHitSplat" then
    -- FireRed AnimFlashingHitSplat uses the same affine variants as the basic
    -- hit splat, then toggles visibility every callback tick for 14 frames.
    local who=(args[3]=="attacker" or args[3]==0) and assert(ctx.attacker) or assert(ctx.target)
    local x=(who.x2 or who.x)+(args[1] or 0)
    local y=(who.yPicOffset or who.y)+(args[2] or 0)
    motion={kind="flashing_hit_splat",startX=x,startY=y,endX=x,endY=y,duration=14,
      affineVariant=args[4] or 0}
  elseif template.callback == "AnimViceGripPincer" then
    -- FireRed AnimViceGripPincer. The non-inverted pincer starts at
    -- target+(32,-32) and moves to target+(16,-16); the inverted pincer
    -- uses the opposite offsets and the H+V-flipped sprite animation.
    -- The translation lasts six native 8.8 fixed-point ticks, while the
    -- sprite animation itself lasts 3+3+20 = 26 frames.
    local t=assert(ctx.target)
    local inverted=(args[1] or 0)~=0
    local sxoff,syoff,exoff,eyoff=32,-32,16,-16
    if inverted then sxoff,syoff,exoff,eyoff=-32,32,-16,16 end
    local bx=(t.x2 or t.x)
    local by=(t.yPicOffset or t.y)
    motion={kind="vice_grip_pincer",startX=bx+sxoff,startY=by+syoff,
      endX=bx+exoff,endY=by+eyoff,duration=26,nativeDuration=6,
      hFlip=inverted,vFlip=inverted}
  elseif template.callback == "AnimGuillotinePincer" then
    -- FireRed AnimGuillotinePincer. The jaw closes using the same 6-tick
    -- fixed translation as Vice Grip, pauses at the inner point, then flips
    -- its velocity signs and retracts. The short 2/2/1 animation is paused
    -- while closed and restarted on the reverse phase.
    local t=assert(ctx.target)
    local inverted=(args[1] or 0)~=0
    local sxoff,syoff,exoff,eyoff=32,-32,16,-16
    if inverted then sxoff,syoff,exoff,eyoff=-32,32,-16,16 end
    local bx=(t.x2 or t.x)
    local by=(t.yPicOffset or t.y)
    motion={kind="guillotine_pincer",startX=bx+sxoff,startY=by+syoff,
      endX=bx+exoff,endY=by+eyoff,duration=56,nativeDuration=6,
      closeFrame=6,reverseFrame=49,reverseDuration=6,
      hFlip=inverted,vFlip=inverted}
  elseif template.callback == "AnimGustToTarget" then
    -- FireRed AnimGustToTarget. The 32x64 Gust OBJ first runs its 24-frame
    -- horizontal affine expansion, then translates from the attacker-relative
    -- start point to the target over arg4 native linear-translation ticks.
    local a,t=assert(ctx.attacker),assert(ctx.target)
    local sx,sy=initOn(a,a,t,true,args[1] or 0,args[2] or 0)
    local txoff=args[3] or 0
    if a.side ~= "player" then txoff=-txoff end
    local tx=(t.x2 or t.x)+txoff
    local ty=(t.yPicOffset or t.y)+(args[4] or 0)
    local travel=math.max(1,math.floor(tonumber(args[5]) or 1))
    motion={kind="gust_to_target",startX=sx,startY=sy,endX=tx,endY=ty,
      affineDuration=24,nativeDuration=travel,duration=24+travel+1,paletteCycleDelay=1}
  elseif template.callback == "AnimWhirlwindLine" then
    -- FireRed AnimWhirlwindLine. The line starts 32 px left of its selected
    -- battler, seeks into one of the five one-frame line states, and advances
    -- 0x0CCC subpixels (12 px) per callback. Every sixth state it snaps back
    -- and restarts the line animation, producing the repeating wind sweep.
    local a,t=assert(ctx.attacker),assert(ctx.target)
    local base=(args[3]=="attacker" or args[3]==0) and a or t
    local sx,sy=initOn(base,a,t,false,args[1] or 0,args[2] or 0)
    if base.side=="player" then sx=sx+8 end
    local seek=math.max(0,math.floor(tonumber(args[5]) or 0))
    sx=sx-32+12*seek
    local lifetime=math.max(1,math.floor(tonumber(args[4]) or 1))
    motion={kind="whirlwind_line",startX=sx,startY=sy,endX=sx,endY=sy,liveRawYBattler="attacker",
      initialState=seek,duration=lifetime}
  elseif template.callback == "AnimFlyBallUp" then
    -- FireRed FlySetUp: the Round Shadow begins on the attacker, waits arg2
    -- frames, then accelerates upward by arg3 signed 8.8 subpixels each tick.
    local a,t=assert(ctx.attacker),assert(ctx.target)
    local sx,sy=initOn(a,a,t,true,args[1] or 0,args[2] or 0)
    local wait=math.max(0,math.floor(tonumber(args[3]) or 0))
    local accel=tonumber(args[4]) or 0
    local vel=0; local yy=sy; local moving=0
    while yy>=-32 and moving<240 do
      moving=moving+1; vel=vel+accel; yy=yy-math.floor(vel/256)
    end
    motion={kind="fly_ball_up",startX=sx,startY=sy,endX=sx,endY=yy,
      waitFrames=wait,acceleration=accel,duration=wait+moving+1}
  elseif template.callback == "AnimFlyBallAttack" then
    -- FireRed FlyUnleash: enter diagonally from above the attacker's side,
    -- cross the target in arg0 ticks, then keep the same vector until the ball
    -- exits the battle canvas. The attacker picture is restored when it exits.
    local a,t=assert(ctx.attacker),assert(ctx.target)
    local player=(a.side=="player")
    local sx=player and -32 or 192
    local sy=-32
    local tx=(t.x2 or t.x)
    local ty=(t.yPicOffset or t.y)
    local travel=math.max(1,math.floor(tonumber(args[1]) or 1))
    local vx=(tx-sx)/travel; local vy=(ty-sy)/travel
    local duration=travel
    local x,y=tx,ty
    while x>=-32 and x<=192 and y<=176 and duration<160 do
      duration=duration+1; x=x+vx; y=y+vy
    end
    motion={kind="fly_ball_attack",startX=sx,startY=sy,endX=tx,endY=ty,
      nativeDuration=travel,velocityX=vx,velocityY=vy,duration=duration,
      rotationUnits=player and 50 or -40}
  elseif template.callback == "AnimSkyAttackBird" then
    -- FireRed AnimSkyAttackBird: the sprite is created at the target, then the
    -- callback snaps it to the attacker's X_2/Y_PIC_OFFSET and preserves the
    -- original target point as its flight vector.  It reaches that point in
    -- 12 callbacks and keeps travelling along the same vector until offscreen.
    local a,t=assert(ctx.attacker),assert(ctx.target)
    local sx=(a.x2 or a.x)
    local sy=(a.yPicOffset or a.y)
    local tx=(t.x2 or t.x)
    local ty=(t.yPicOffset or t.y)
    local travel=12
    local vx=(tx-sx)/travel
    local vy=(ty-sy)/travel
    local duration=travel
    local x,y=tx,ty
    while x>=-45 and x<=205 and y>=-45 and y<=157 and duration<160 do
      duration=duration+1; x=x+vx; y=y+vy
    end
    local dx,dy=tx-sx,ty-sy
    local rotationUnits=(((-math.atan(dy,dx)/(2*math.pi))*256)+192+128)%256
    motion={kind="sky_attack_bird",startX=sx,startY=sy,endX=tx,endY=ty,
      nativeDuration=travel,velocityX=vx,velocityY=vy,duration=duration,
      rotationUnits=rotationUnits}
  elseif template.callback == "AnimSonicBoomProjectile" then
    -- FireRed AnimSonicBoomProjectile. In normal battles an opponent-side
    -- attacker first negates args 1..3, then InitSpritePosToAnimAttacker
    -- applies its normal side-aware X offset. The sprite is rotated toward
    -- the final target point and StartAnimLinearTranslation runs for arg4 ticks.
    local a,t=assert(ctx.attacker),assert(ctx.target)
    local x1,y1,x2,y2=args[1] or 0,args[2] or 0,args[3] or 0,args[4] or 0
    if a.side ~= "player" then x1,y1,x2=-x1,-y1,-x2 end
    local sx,sy=initOn(a,a,t,true,x1,y1)
    local tx=(t.x2 or t.x)+x2
    local ty=(t.yPicOffset or t.y)+y2
    local nativeDuration=math.max(1,math.floor(tonumber(args[5]) or 1))
    local dx,dy=tx-sx,ty-sy
    -- ArcTan2Neg(dx,dy) + 0xF000, converted from GBA 16-bit angle units
    -- to this renderer's 256-unit turn representation.
    local rotationUnits=(((-math.atan(dx,dy)/(2*math.pi))*256)+240)%256
    motion={kind="sonic_boom_projectile",startX=sx,startY=sy,endX=tx,endY=ty,
      nativeDuration=nativeDuration,duration=nativeDuration+1,rotationUnits=rotationUnits}
  elseif template.callback == "AnimTranslateWebThread" then
    -- FireRed AnimTranslateWebThread. This named path is used only by the
    -- String Shot WEB_THREAD template. Native speed conversion uses horizontal
    -- distance (8.8 fixed-point), then each translation tick adds a sine-wave
    -- X offset with phase += 13.
    local a,t=assert(ctx.attacker),assert(ctx.target)
    local sx,sy=initOn(a,a,t,true,tonumber(args[1]) or 0,tonumber(args[2]) or 0)
    local tx,ty=(t.x2 or t.x),(t.yPicOffset or t.y)
    local speed=math.max(1,math.abs(tonumber(args[3]) or 1))
    local nativeDuration=math.max(1,math.floor(math.abs(tx-sx)*256/speed))
    motion={kind="string_shot_web_thread",startX=sx,startY=sy,endX=tx,endY=ty,
      nativeDuration=nativeDuration,duration=nativeDuration+1,
      amplitude=tonumber(args[4]) or 0,phaseStep=13}
  elseif template.callback == "AnimStringWrap" then
    -- FireRed AnimStringWrap. This named path is used only by String Shot's
    -- 64x32 STRING bands. They remain target-centered, toggle visibility every
    -- three callbacks, and are destroyed on callback 51.
    local a,t=assert(ctx.attacker),assert(ctx.target)
    local x=(t.x2 or t.x)
    if a.side ~= "player" then x=x-(tonumber(args[1]) or 0) else x=x+(tonumber(args[1]) or 0) end
    local y=rawBattlerYPattern(t,(tonumber(args[2]) or 0)+((t.side=="player") and 8 or 0))
    motion={kind="string_shot_wrap",startX=x,startY=y,endX=x,endY=y,duration=51,blinkEvery=3,liveRawYBattler="target"}
  elseif template.callback == "AnimAirWaveCrescent" then
    -- FireRed AnimAirWaveCrescent. Opponent-side attackers negate all four
    -- script offsets, then the crescent uses StartAnimLinearTranslation for
    -- arg4 ticks. arg5 seeks into its four 3-frame flip states.
    local a,t=assert(ctx.attacker),assert(ctx.target)
    local x1,y1,x2,y2=args[1] or 0,args[2] or 0,args[3] or 0,args[4] or 0
    if a.side ~= "player" then x1,y1,x2,y2=-x1,-y1,-x2,-y2 end
    local sx=(a.x2 or a.x)+x1
    local sy=(a.yPicOffset or a.y)+y1
    local tx=(t.x2 or t.x)+x2
    local ty=(t.yPicOffset or t.y)+y2
    local nativeDuration=math.max(1,math.floor(tonumber(args[5]) or 1))
    motion={kind="air_wave_crescent",startX=sx,startY=sy,endX=tx,endY=ty,
      nativeDuration=nativeDuration,duration=nativeDuration+1,animSeek=args[6] or 0}
  elseif template.callback == "AnimSwordsDanceBlade" then
    -- FireRed: the sword starts on the attacker, runs the 44-frame affine
    -- grow/hold sequence, then rises 32 px over six linear-translation ticks.
    local a=assert(ctx.attacker)
    local x=(a.x2 or a.x)+(args[1] or 0)
    local y=rawBattlerY(a,args[2] or 0)
    motion={kind="swords_dance_blade",startX=x,startY=y,endX=x,endY=y-32,
      affineDuration=44,riseDuration=6,duration=51,liveRawYBattler="attacker"}
  elseif template.callback == "AnimCuttingSlice" then
    -- FireRed AnimCuttingSlice: target-centered diagonal cut. The normal
    -- 0/16/32/48 CUT frames last five ticks each while the callback sweeps
    -- across the target from the supplied initial offset.
    local t=assert(ctx.target)
    local bx=(t.x2 or t.x)
    local by=rawBattlerY(t,(t.side=="player") and 8 or 0)
    local xoff=args[1] or 0
    local yoff=args[2] or 0
    local dir=(args[3] or 0)~=0
    local sx=bx+xoff
    local sy=by+yoff
    -- CUT's canonical script uses (40,-32,0): traverse 80x64 diagonally
    -- through the target over the 20-frame sprite animation.
    local ex=bx+(dir and 40 or -40)
    local ey=by+32
    motion={kind="cutting_slice",startX=sx,startY=sy,endX=ex,endY=ey,
      duration=20,hFlip=dir,liveRawYBattler="target"}
  elseif template.callback == "AnimBite" then
    -- FireRed AnimBite: x/y local offset, static affine orientation, then a
    -- signed 8.8 fixed-point step inward for N frames and back for N frames.
    local t=assert(ctx.target)
    local x=(t.x2 or t.x)+(args[1] or 0)
    local y=(t.yPicOffset or t.y)+(args[2] or 0)
    local steps=math.max(1,args[6] or 1)
    motion={kind="bite",startX=x,startY=y,endX=x,endY=y,duration=steps*2,
      affineVariant=args[3] or 0,stepX=args[4] or 0,stepY=args[5] or 0,steps=steps}
  elseif template.callback == "AnimStompFoot" then
    -- FireRed waits arg2+1 frames above the target, translates to the target
    -- over six frames, then holds for fifteen frames.
    local t=assert(ctx.target)
    local tx=(t.x2 or t.x)
    local ty=(t.yPicOffset or t.y)
    local sx=tx+(args[1] or 0)
    local sy=ty+(args[2] or 0)
    local waitFrames=math.max(0,(args[3] or 0)+1)
    local travelFrames=6
    local holdFrames=15
    motion={kind="stomp_foot",startX=sx,startY=sy,endX=tx,endY=ty,
      waitFrames=waitFrames,travelFrames=travelFrames,holdFrames=holdFrames,
      duration=waitFrames+travelFrames+holdFrames}
  elseif template.callback == "AnimFistOrFootRandomPos" then
    -- FireRed AnimFistOrFootRandomPos: choose the requested battler, select the
    -- hand/foot anim, pick a fresh random point inside that battler's sprite,
    -- and create a BasicHitSplat at the exact same point for the same lifetime.
    -- Position randomization is deferred until plan instantiation so cached
    -- plans do not freeze Random() to one point forever.
    local useTarget=not (args[1]==0 or args[1]=="attacker")
    local base=useTarget and assert(ctx.target) or assert(ctx.attacker)
    local group="fistfoot:"..tostring(frame)..":"..tostring(#out+1)
    motion={kind="fist_foot_random_pos",startX=(base.x2 or base.x),startY=(base.yPicOffset or base.y),
      endX=(base.x2 or base.x),endY=(base.yPicOffset or base.y),duration=math.max(1,args[2] or 1),
      animVariant=args[3] or 0,randomGroup=group,randomBattler=useTarget and "target" or "attacker"}
  elseif template.callback == "AnimBasicFistOrFoot" then
    -- FireRed args: xOff, yOff, duration, useTarget, animNum.
    local useTarget=(args[4]==1 or args[4]==true)
    local base=useTarget and assert(ctx.target) or assert(ctx.attacker)
    local x=(base.x2 or base.x)+(args[1] or 0)
    local y=(base.yPicOffset or base.y)+(args[2] or 0)
    motion={
      kind="static",startX=x,startY=y,endX=x,endY=y,
      duration=math.max(1,args[3] or 1),
      tileVariant=args[5] or 0,
    }
  elseif template.callback == "AnimLightning" then
    local t=assert(ctx.target)

    -- FireRed creates lightning at the target's picture center and the callback
    -- only applies its local offsets. Sprite-local offsets remain 1:1, matching
    -- the global native-GBA OBJ presentation rule used by this test build.
    local ox=(args[1] or 0)
    local oy=(args[2] or 0)

    local x=(t.x2 or t.x)+ox
    local y=(t.yPicOffset or t.y)+oy
    motion={kind="lightning",startX=x,startY=y,endX=x,endY=y,duration=28}
  elseif template.callback == "AnimThunderboltOrb" then
    local a,t=assert(ctx.attacker),assert(ctx.target)
    local ox=args[2] or 0
    if t.isPlayer then ox=-ox end
    local x=(t.x2 or t.x)+ox
    local y=(t.yPicOffset or t.y)+(args[3] or 0)
    motion={kind="thunderbolt_orb",startX=x,startY=y,endX=x,endY=y,
      duration=(args[1] or 44)+1,blinkDelay=args[4] or 3}
  elseif template.callback == "AnimSparkElectricityFlashing" then
    local a,t=assert(ctx.attacker),assert(ctx.target)
    local xoff=args[1] or 0
    if t.isPlayer then xoff=-xoff end
    local x=(t.x2 or t.x)+xoff
    local y=(t.yPicOffset or t.y)+(args[2] or 0)
    motion={kind="spark_electricity_flashing",startX=x,startY=y,endX=x,endY=y,
      radius=args[3] or 0,duration=(args[4] or 0)+1,angle=args[5] or 0,
      angleStep=args[6] or 0,flashDiv=((args[8] or 0)%0x8000)}
  elseif template.callback == "AnimElectricity" then
    local a,t=assert(ctx.attacker),assert(ctx.target)
    local x=(t.x2 or t.x)+(args[1] or 0)
    local y=rawBattlerYPattern(t,args[2] or 0)
    motion={kind="electricity_arc",startX=x,startY=y,endX=x,endY=y,
      duration=(args[3] or 5)+1,variant=args[4] or 0,liveRawYBattler="target"}
  elseif template.callback == "AnimThunderWave" then
    local a,t=assert(ctx.attacker),assert(ctx.target)
    local xoff=signAdjustedXOffset(a,t,args[1] or 0)
    local sx=(t.x or t.x2)+xoff
    local sy=rawBattlerYPattern(t,args[2] or 0)
    motion={kind="thunder_wave_band",startX=sx,startY=sy,endX=sx,endY=sy,duration=51}
  elseif template.callback == "AnimElectricBoltSegment" then
    motion={kind="electric_bolt_segment",startX=0,startY=0,endX=0,endY=0,duration=15}
  elseif template.callback == "AnimEllipticalGust" then
    motion = M.ellipticalGust(args, ctx)
  elseif template.callback == "AnimRazorWindTornado" then
    -- FireRed AnimRazorWindTornado. InitSpritePosToAnimAttacker applies the
    -- attacker-relative 32 px setup offset; player-side sprites receive the
    -- callback's additional +16 Y correction. Args 4/5/6 are the initial
    -- phase, phase step, and lifetime. Arg 3 is unused by the native callback.
    local a,t=assert(ctx.attacker),assert(ctx.target)
    local sx,sy=initOn(a,a,t,false,args[1] or 0,args[2] or 0)
    if a.side == "player" then sy=sy+hostRelativeYDelta(16) end
    motion={kind="razor_wind_tornado",startX=sx,startY=sy,endX=sx,endY=sy,liveRawYBattler="attacker",
      radius=args[3] or 0,initialAngle=args[5] or 0,angleStep=args[6] or 0,
      duration=math.max(1,args[7] or 1),affineStart=16/256,affineStep=4/256,affineGrowFrames=40}
  elseif template.callback == "AnimLeechLifeNeedle" then
    -- FireRed AnimLeechLifeNeedle. The needle begins at target X_2/Y_PIC_OFFSET
    -- plus (-20,+15), then StartAnimLinearTranslation converges on the target
    -- over 12 callbacks. When the target is on the player side both script
    -- offsets are negated. Native affine animation 0 applies 33 host-render rotation units for the source-faithful visual orientation.
    local a,t=assert(ctx.attacker),assert(ctx.target)
    local xoff=tonumber(args[1]) or 0
    local yoff=tonumber(args[2]) or 0
    local duration=math.max(1,math.floor(tonumber(args[3]) or 1))
    if t.side == "player" then xoff,yoff=-xoff,-yoff end
    local sx=(t.x2 or t.x)+xoff
    local sy=(t.yPicOffset or t.y)+hostRelativeYDelta(yoff)
    local tx=(t.x2 or t.x)
    local ty=(t.yPicOffset or t.y)
    motion={kind="leech_life_needle",startX=sx,startY=sy,endX=tx,endY=ty,
      duration=duration+1,nativeDuration=duration,rotationUnits=(33)%256}
  elseif template.callback == "AnimTranslateStinger" then
    -- FireRed AnimTranslateStinger. The 16x16 affine needle travels linearly
    -- from an attacker-relative launch point to a target-relative endpoint.
    -- The callback rotates the OBJ once at creation so its vertical needle art
    -- points along that line. Opponent-side use mirrors the script's Y offsets
    -- as well as its target X offset.
    local a,t=assert(ctx.attacker),assert(ctx.target)
    local aa={}
    for i=1,5 do aa[i]=args[i] or 0 end
    if a.side ~= "player" then
      aa[3] = -aa[3]
      aa[2] = -aa[2]
      aa[4] = -aa[4]
    end
    -- FireRed also corrects same-side targets in doubles. Preserve it when
    -- position metadata is available, even though Gen1Recomp is normally 1v1.
    if a.side == t.side and (t.position=="player_left" or t.position=="opponent_left") then
      aa[3] = -aa[3]
      aa[1] = -aa[1]
    end
    local sx,sy=initOn(a,a,t,true,aa[1],aa[2])
    local tx=(t.x2 or t.x)+aa[3]
    local ty=(t.yPicOffset or t.y)+aa[4]
    motion={kind="linear_stinger",startX=sx,startY=sy,endX=tx,endY=ty,
      duration=math.max(1,aa[5])}
  elseif template.callback == "AnimHitSplatHandleInvert" then
    -- FireRed: when the attacker is on the opponent side, invert only the Y
    -- offset, then delegate to AnimHitSplatBasic. InitSpritePosToAnimTarget
    -- also applies SetAnimSpriteInitialXOffset, so X is mirrored by battler
    -- orientation rather than added blindly.
    local a,t=assert(ctx.attacker),assert(ctx.target)
    local xoff=args[1] or 0
    local yoff=args[2] or 0
    if a.side ~= "player" then yoff=-yoff end
    local x=(t.x2 or t.x)+signAdjustedXOffset(a,t,xoff)
    local y=(t.yPicOffset or t.y)+yoff
    motion={kind="hit_splat_handle_invert",startX=x,startY=y,endX=x,endY=y,duration=8,
      affineVariant=args[4] or 0}
  elseif template.callback == "AnimLeechSeed" then
    -- FireRed AnimLeechSeed (battle_anim_effects_1.c). Starts from the
    -- attacker picture coordinate, arcs for arg4 frames to the target's RAW
    -- BATTLER_COORD_X/Y, hides for 10 frames, then switches to sprout anim 1
    -- for 60 frames at the exact landing point.
    local a,t=assert(ctx.attacker),assert(ctx.target)
    local sx,sy=initOn(a,a,t,true,args[1] or 0,args[2] or 0)
    local txoff=tonumber(args[3]) or 0
    if a.side ~= "player" then txoff=-txoff end
    local tx,ty=pos(t,false)
    tx=tx+txoff
    ty=ty+hostRelativeYDelta(args[4] or 0)
    local travel=math.max(1,math.floor(tonumber(args[5]) or 1))
    motion={kind="leech_seed",startX=sx,startY=sy,endX=tx,endY=ty,
      duration=travel+10+60,travelDuration=travel,
      hiddenDuration=10,sproutDuration=60,arcAmplitude=tonumber(args[6]) or 0,
      liveRawYBattler="target",liveRawYKeys={"endY"}}
  elseif template.callback == "AnimMissileArc" then
    -- FireRed AnimMissileArc: attacker-relative launch, target-relative end,
    -- GBA arc translation using arg5 as signed wave height. The native
    -- callback hides the sprite for its setup tick, then rotates the affine
    -- OBJ each frame so the needle points along the current tangent.
    local a,t=assert(ctx.attacker),assert(ctx.target)
    local sx,sy=initOn(a,a,t,true,args[1] or 0,args[2] or 0)
    local txoff=args[3] or 0
    if a.side ~= "player" then txoff=-txoff end
    local tx=(t.x2 or t.x)+txoff
    local ty=(t.yPicOffset or t.y)+(args[4] or 0)
    motion={kind="missile_arc",startX=sx,startY=sy,endX=tx,endY=ty,
      duration=math.max(1,args[5] or 1),arcAmplitude=args[6] or 0,hideSetupFrame=true}
  elseif template.callback == "AnimBoneHitProjectile" then
    motion = M.boneHitProjectile(args, ctx)
  elseif template.callback == "AnimBonemerangProjectile" then
    motion = M.bonemerangProjectile(args, ctx)
  elseif template.callback == "AnimFallingRock" then
    motion = M.fallingRock(args, ctx)
  elseif template.callback == "AnimRockScatter" then
    motion = M.rockScatter(args, ctx)
  elseif template.callback == "AnimDirtScatter" then
    local seed=(frame*131 + (#out+1)*17 + (priorityModifier or 0)*7) % 65536
    motion = M.dirtScatter(args, ctx, seed)
  elseif template.callback == "AnimDirtPlumeParticle" then
    motion = M.dirtPlumeParticle(args, ctx)
  elseif template.callback == "AnimDigDirtMound" then
    motion = M.digDirtMound(args, ctx)
  elseif template.callback == "AnimCoinThrow" then
    motion = M.coinThrow(args, ctx)
  elseif template.callback == "AnimFallingCoin" then
    motion = M.fallingCoin(args, ctx)
  elseif template.callback == "AnimThrowProjectile" then
    motion = M.throwProjectile(args, ctx)
  elseif template.callback == "AnimWaterGunDroplet" then
    motion = M.waterGunDroplet(args, ctx)
  elseif template.callback == "AnimAcidPoisonBubble" then
    motion = M.acidPoisonBubble(args, ctx)
  elseif template.callback == "AnimSludgeProjectile" then
    motion = M.sludgeProjectile(args, ctx)
  elseif template.callback == "AnimAcidPoisonDroplet" then
    motion = M.acidPoisonDroplet(args, ctx)
  elseif template.callback == "AnimPetalDanceBigFlower" then
    motion = M.petalDanceBigFlower(args, ctx)
  elseif template.callback == "AnimPetalDanceSmallFlower" then
    motion = M.petalDanceSmallFlower(args, ctx)
  elseif template.callback == "AnimRazorLeafParticle" then
    motion = M.razorLeafParticle(args, ctx)
  elseif template.callback == "AnimTranslateLinearSingleSineWave" then
    motion = M.translateLinearSingleSineWave(args, ctx)
  elseif template.callback == "AnimDragonFireToTarget" then
    motion = M.dragonFireToTarget(args, ctx)
  elseif template.callback == "AnimDragonRageFirePlume" then
    motion = M.dragonRageFirePlume(args, ctx)
  elseif template.callback == "AnimWaterBubbleProjectile" then
    motion = M.waterBubbleProjectile(args, ctx)
  elseif template.callback == "AnimWaterBubbleProjectileHoldImpact" then
    motion = M.waterBubbleProjectile(args, ctx)
    motion.preserveArrivalOrbit = true
  elseif template.callback == "AnimBubbleEffect" then
    motion = M.bubbleEffect(args, ctx)
  elseif template.callback == "AnimSmallBubblePair" then
    motion = M.smallBubblePair(args, ctx)
  elseif template.callback == "AnimSmallDriftingBubbles" then
    motion = M.smallDriftingBubbles(args, ctx)
  elseif template.callback == "AnimFireSpiralInward" then
    motion = M.fireSpiralInward(args, ctx)
  elseif template.callback == "AnimFireSpread" then
    motion = M.fireSpread(args, ctx)
  elseif template.callback == "AnimFireRing" then
    motion = M.fireBlastRing(args, ctx)
  elseif template.callback == "AnimFireCross" then
    motion = M.fireBlastCross(args, ctx)
  elseif template.callback == "AnimParticleInVortex" then
    motion = M.particleInVortex(args, ctx)
  elseif template.callback == "AnimThoughtBubble" then
    -- FireRed AnimThoughtBubble: place beside the selected battler's head,
    -- play the four 2-frame opening tiles, hold for arg1 callback ticks, then
    -- play the same four tiles in reverse and destroy.
    local who=(args[1]==1) and assert(ctx.target) or assert(ctx.attacker)
    local x=(who.x2 or who.x)
    local y=(who.yPicOffset or who.y)
    motion={kind="metronome_thought_bubble",startX=x,startY=y,endX=x,endY=y,
      duration=116,holdTicks=math.max(1,math.floor(tonumber(args[2]) or 100)),
      playerSide=(who.isPlayer==true or who.side=="player"),liveNextToHeadBattler=(who==ctx.attacker and "attacker" or "target")}
  elseif template.callback == "AnimMetronomeFinger" then
    -- FireRed AnimMetronomeFinger: grow from native scale 16 to 256 over 8
    -- frames, hold while the callback counts 17 ticks, then run affine anim 1:
    -- +4 rotation units for 11 frames, -4 for 11, repeated three cycles, and
    -- finally shrink by 30 scale units for 8 frames. No target-facing rotation.
    local who=(args[1]==1) and assert(ctx.target) or assert(ctx.attacker)
    local x=(who.x2 or who.x)
    local y=(who.yPicOffset or who.y)
    motion={kind="metronome_finger",startX=x,startY=y,endX=x,endY=y,duration=99,
      playerSide=(who.isPlayer==true or who.side=="player"),liveNextToHeadBattler=(who==ctx.attacker and "attacker" or "target")}
  elseif template.callback == "AnimLick" then
    -- FireRed AnimLick: target-relative sprite, 10-frame tongue animation,
    -- then callback-controlled visibility flicker. Native callback lifetime:
    -- 15 ticks for five fast toggles, 25 for five slow toggles, then destroy.
    local t=assert(ctx.target)
    local x=(t.x2 or t.x)+(args[1] or 0)
    local y=(t.yPicOffset or t.y)+(args[2] or 0)
    motion={kind="lick",startX=x,startY=y,endX=x,endY=y,duration=51,animEnd=10}
  elseif template.callback == "AnimHitSplatBasic" then
    local who=(args[3]=="attacker" or args[3]==0) and assert(ctx.attacker) or assert(ctx.target)
    local x=(who.x2 or who.x)+(args[1] or 0)
    local y=(who.yPicOffset or who.y)+(args[2] or 0)
    motion={kind="hit_splat",startX=x,startY=y,endX=x,endY=y,duration=8,
      affineVariant=args[4] or 0}
  elseif template.callback == "AnimDizzyPunchDuck" then
    -- FireRed AnimDizzyPunchDuck: setup on frame 0 at a target-relative
    -- position, then add signed 8.8 X velocity each tick while tracing a
    -- small sine wave vertically. data[3] advances by 3 until >120.
    local t=assert(ctx.target)
    local x=(t.x2 or t.x)+(args[1] or 0)
    local y=(t.yPicOffset or t.y)+(args[2] or 0)
    motion={kind="dizzy_punch_duck",startX=x,startY=y,endX=x,endY=y,duration=42,
      velocityX=tonumber(args[3]) or 0,sineAmplitude=tonumber(args[4]) or 0}
  elseif template.callback == "AnimSporeParticle" then
    -- FireRed AnimSporeParticle: target-relative origin, then a 32px sine
    -- orbit in X while Y follows Cos(angle,-3) plus a +24/256 px/tick drift.
    -- The callback is invoked once immediately at initialization and then
    -- advances its angle by 2 native units per callback for arg3+1 ticks.
    local t=assert(ctx.target)
    local x=(t.x2 or t.x)+(args[1] or 0)
    local y=(t.yPicOffset or t.y)+(args[2] or 0)
    motion={kind="spore_particle",startX=x,startY=y,endX=x,endY=y,
      initialAngle=tonumber(args[3]) or 0,nativeDuration=math.max(0,math.floor(tonumber(args[4]) or 0)),
      animVariant=tonumber(args[5]) or 0,duration=math.max(0,math.floor(tonumber(args[4]) or 0))+1,
      liveLocalYBattler="target"}
  elseif template.callback == "AnimConstrictBinding" then
    -- FireRed AnimConstrictBinding (battle_anim_effects_1.c). The 64x32
    -- tendril sprite is target-relative and waits, with its affine animation
    -- paused, until the shared script arg 7 is set to 0xFFFF. The status
    -- script does that 30 frames after the first sprite and 23 after the
    -- second. After release the selected 12-frame affine squeeze runs once
    -- (Status_BindWrap passes num squeezes = 1), then the sprite is destroyed.
    local t=assert(ctx.target)
    local x=(t.x2 or t.x)+(args[1] or 0)
    local y=rawBattlerYPattern(t,args[2] or 0)
    local releaseAfter=math.max(0,math.floor(tonumber(args[5]) or 0))
    local squeezes=math.max(1,math.floor(tonumber(args[4]) or 1))
    motion={kind="constrict_binding",startX=x,startY=y,endX=x,endY=y,
      affineVariant=tonumber(args[3]) or 0,releaseAfter=releaseAfter,liveRawYBattler="target",
      squeezes=squeezes,duration=releaseAfter+12*squeezes+1}
  elseif template.callback == "AnimBentSpoon" then
    -- FireRed AnimBentSpoon. The spoon is placed 40 px to the battler-facing
    -- side of the attacker and 10 px vertically, with a side-specific sprite
    -- animation. Its complete native anim lasts 187 frames.
    local a=assert(ctx.attacker)
    local playerSide=(a.isPlayer==true or a.side=="player")
    local x=(a.x2 or a.x)+(playerSide and 40 or -40)
    local y=(a.yPicOffset or a.y)+(playerSide and -10 or 10)
    motion={kind="kinesis_spoon",startX=x,startY=y,endX=x,endY=y,duration=187,
      animVariant=playerSide and 0 or 1,liveLocalYBattler="attacker"}
  elseif template.callback == "AnimKinesisZapEnergy" then
    -- FireRed AnimKinesisZapEnergy. Both 32x16 strips sit beside the attacker;
    -- X is mirrored by battler side and the second strip is vertically flipped.
    -- sKinesisZapEnergyAnimCmds runs seven 3-frame tiles twice = 42 frames.
    local a=assert(ctx.attacker)
    local playerSide=(a.isPlayer==true or a.side=="player")
    local xoff=tonumber(args[1]) or 0
    local yoff=tonumber(args[2]) or 0
    local vflip=(tonumber(args[3]) or 0)~=0
    local x=(a.x2 or a.x)+(playerSide and xoff or -xoff)
    local y=(a.yPicOffset or a.y)+yoff
    local variant=(playerSide and 0 or 2)+(vflip and 1 or 0)
    motion={kind="kinesis_zap",startX=x,startY=y,endX=x,endY=y,duration=42,
      animVariant=variant,liveLocalYBattler="attacker"}
  elseif template.callback == "AnimWhipHit" then
    local t=assert(ctx.target)
    local x=(t.x2 or t.x)+(args[1] or 0)
    local y=(t.yPicOffset or t.y)+(args[2] or 0)
    motion={kind="whip_hit",startX=x,startY=y,endX=x,endY=y,duration=16}
  elseif template.callback == "AnimWavyMusicNotes" then
    -- FireRed AnimWavyMusicNotes. The sprite starts on the attacker and uses
    -- signed fixed-point velocity derived from a native X speed factor of 40
    -- (2.5 px/tick on the usual 80 px classic-battle separation). It never
    -- stops at the target: it continues on the same line until leaving the
    -- 240x160 GBA animation bounds, with a 15 px vertical sine wave.
    local a,t=assert(ctx.attacker),assert(ctx.target)
    local sx,sy=(a.x2 or a.x),(a.yPicOffset or a.y)
    local tx,ty=(t.x2 or t.x),(t.yPicOffset or t.y)
    local dx,dy=tx-sx,ty-sy
    local factor=(dx<0) and -40 or 40
    local function cdiv(n,d)
      if d==0 then return 0 end
      local q=n/d
      return q>=0 and math.floor(q) or math.ceil(q)
    end
    local time=cdiv(dx*256,factor)
    if time==0 then time=1 end
    local vxNative=cdiv(dx*256,time)
    local vyNative=cdiv(dy*256,time)
    local vx,vy=vxNative/16,vyNative/16
    local duration=1
    for n=1,180 do
      local xx=sx+vx*n
      local yy=sy+vy*n
      duration=n+1
      if xx < -16 or xx > 256 or yy < -16 or yy > 128 then break end
    end
    motion={kind="wavy_music_note",startX=sx,startY=sy,
      endX=sx+vx*duration,endY=sy+vy*duration,duration=duration,
      velocityX=vx,velocityY=vy,noteVariant=math.floor(tonumber(args[1]) or 0),
      paletteStart=math.floor(tonumber(args[2]) or 0)%4,
      paletteCycleTime=math.max(0,math.floor(tonumber(args[3]) or 0))}
  elseif template.callback == "AnimRoarNoiseLine" then
    -- FireRed AnimRoarNoiseLine: start from the attacker's BATTLER_COORD_X/Y,
    -- then advance by 0x280 (2.5 px) per callback for 14 callbacks. Direction
    -- 0 rises, 1 falls, and 2 is horizontal using sprite anim variant 1.
    local a=assert(ctx.attacker)
    local xoff=tonumber(args[1]) or 0
    if a.side ~= "player" then xoff=-xoff end
    local dir=math.floor(tonumber(args[3]) or 0)
    local sx=(a.x or a.x2)+xoff
    local sy=rawBattlerY(a,tonumber(args[2]) or 0)
    local vx=(a.side=="player") and 2.5 or -2.5
    local vy=(dir==0 and -2.5) or (dir==1 and 2.5) or 0
    motion={kind="roar_noise_line",startX=sx,startY=sy,
      endX=sx+vx*14,endY=sy+vy*14,duration=14,
      velocityX=vx,velocityY=vy,direction=dir,liveRawYBattler="attacker",
      hFlip=(a.side~="player"),vFlip=(dir==1)}
  elseif template.callback == "AnimEndureEnergy" then
    -- FireRed AnimEndureEnergy. Args are battler selector, X/Y offsets, and
    -- the per-sprite rise cadence. Focus Energy passes attacker (0) for every
    -- instance and uses BATTLER_COORD_X/Y rather than PIC_OFFSET.
    local who=((tonumber(args[1]) or 0)==0) and assert(ctx.attacker) or assert(ctx.target)
    local x=(who.x or who.x2)+(tonumber(args[2]) or 0)
    local y=rawBattlerY(who,tonumber(args[3]) or 0)
    motion={kind="endure_energy",startX=x,startY=y,endX=x,endY=y,duration=24,
      riseCadence=math.max(0,math.floor(tonumber(args[4]) or 0)),
      liveRawYBattler=(who==ctx.attacker) and "attacker" or "target"}
  elseif template.callback == "InitPoisonGasCloudAnim" then
    -- FireRed InitPoisonGasCloudAnim / MovePoisonGasCloud. The cloud starts
    -- at attacker X_2/Y_PIC_OFFSET, translates for 64 callbacks to a point
    -- offset from target RAW X/Y while wavering horizontally, circles the
    -- target for 80 callbacks while descending 29 px, then exits horizontally
    -- at the native 3 px/callback linear-translation speed.
    local a,t=assert(ctx.attacker),assert(ctx.target)
    local duration=math.max(1,math.floor(tonumber(args[1]) or 64))
    local xoff1=tonumber(args[2]) or 0
    local yoff1=tonumber(args[3]) or 0
    local xoff2=tonumber(args[4]) or 0
    local yoff2=tonumber(args[5]) or 0
    if t.side=="player" then xoff1=-xoff1; xoff2=-xoff2 end
    local sx=(a.x2 or a.x)
    local sy=(a.yPicOffset or a.y)
    local tx=(t.x or t.x2)+xoff2
    local ty=rawBattlerY(t,yoff2)
    local exitX=(t.side=="player") and -16 or 256
    local exitFrames=math.max(1,math.ceil(math.abs(exitX-(t.x or t.x2))/3))
    motion={kind="poison_gas_cloud",startX=sx,startY=sy,firstEndX=tx,firstEndY=ty,
      travelDuration=duration,orbitDuration=80,exitX=exitX,exitFrames=exitFrames,
      duration=duration+80+exitFrames,targetX=(t.x or t.x2),targetSide=t.side,
      swirlReverse=(t.side=="player")}
  elseif template.callback == "AnimDevil" then
    -- FireRed AnimDevil (Lovely Kiss): target-relative 32x32 devil, offset by
    -- the script args, orbiting on a shrinking ellipse for 91 callbacks. It
    -- flickers during the first 9 and final 11 callbacks.
    local t=assert(ctx.target)
    local x=(t.x2 or t.x)+(tonumber(args[1]) or 0)
    local y=(t.yPicOffset or t.y)+(tonumber(args[2]) or 0)
    motion={kind="lovely_kiss_devil",startX=x,startY=y,endX=x,endY=y,duration=91}
  elseif template.callback == "AnimEyeSparkle" then
    -- FireRed AnimEyeSparkle: InitSpritePosToAnimAttacker(TRUE), then keep the
    -- sprite fixed until its 5-frame 4-tick animation ends (20 frames total).
    local a,t=assert(ctx.attacker),assert(ctx.target)
    local x,y=initOn(a,a,t,true,args[1] or 0,args[2] or 0)
    motion={kind="glare_eye_sparkle",startX=x,startY=y,endX=x,endY=y,duration=20}
  elseif template.callback == "AnimPinkHeart" then
    -- FireRed AnimPinkHeart (Lovely Kiss): fixed-point horizontal drift plus
    -- vertical sine for the first phase, then a short downward wobble/flicker.
    local t=assert(ctx.target)
    local x=(t.x2 or t.x)
    local y=(t.yPicOffset or t.y)
    local seed=(frame*131 + (#out+1)*37 + (priorityModifier or 0)*11) % 180
    motion={kind="lovely_kiss_heart",startX=x,startY=y,endX=x,endY=y,duration=56,
      velocity=tonumber(args[1]) or 0,amplitude=tonumber(args[2]) or 0,randomPhase=seed}
  elseif template.callback == "AnimAngerMark" then
    -- FireRed AnimAngerMark: choose attacker/target from arg0, mirror the X
    -- offset for an opponent-side battler, add the Y offset to PIC_OFFSET,
    -- clamp to y=8, and live for the native 8+8 affine pulse.
    local who=((args[1] or 0)==0) and assert(ctx.attacker) or assert(ctx.target)
    local xoff=tonumber(args[2]) or 0
    if who.side ~= "player" then xoff=-xoff end
    local x=(who.x2 or who.x)+xoff
    local y=(who.yPicOffset or who.y)+(tonumber(args[3]) or 0)
    if y<8 then y=8 end
    motion={kind="anger_mark",startX=x,startY=y,endX=x,endY=y,duration=16}
  elseif template.callback == "AnimDefensiveWall" then
    -- FireRed defensive wall (Light Screen / Reflect / Mirror Coat / Barrier).
    local a=assert(ctx.attacker)
    local xoff=tonumber(args[1]) or 0
    if a.side ~= "player" then xoff=-xoff end
    local x=(a.x or a.x2)+xoff
    local y=rawBattlerY(a,tonumber(args[2]) or 0)
    motion={kind="defensive_wall",startX=x,startY=y,endX=x,endY=y,duration=61,
      liveRawYBattler="attacker",wallTag=tonumber(args[3])}
  elseif template.callback == "AnimWallSparkle" then
    -- FireRed SpecialScreenSparkle uses raw attacker/target coords when arg3 is TRUE.
    local who=(args[3]==1 or args[3]=="target") and assert(ctx.target) or assert(ctx.attacker)
    local ignoreOffsets=(args[4]==true or args[4]==1)
    local x=(who.x2 or who.x)+(tonumber(args[1]) or 0)
    local baseY=ignoreOffsets and rawBattlerY(who,0) or (who.yPicOffset or who.y)
    local y=baseY+(tonumber(args[2]) or 0)
    local total=0
    for _,af in ipairs((template.anim and template.anim.frames) or {}) do total=total+(af.duration or 1) end
    motion={kind="wall_sparkle",startX=x,startY=y,endX=x,endY=y,duration=math.max(1,total)}
  elseif template.callback == "AnimSpinningSparkle" then
    -- FireRed AnimSpinningSparkle (Detect/Disable): start at the attacker,
    -- mirror arg0 by battler side, add arg1, and die with the 5x3-frame anim.
    local a=assert(ctx.attacker)
    local xoff=tonumber(args[1]) or 0
    if a.side ~= "player" then xoff=-xoff end
    local x=(a.x2 or a.x)+xoff
    local y=(a.yPicOffset or a.y)+(tonumber(args[2]) or 0)
    local total=0
    for _,af in ipairs((template.anim and template.anim.frames) or {}) do
      total=total+(af.duration or 1)
    end
    motion={kind="spinning_sparkle",startX=x,startY=y,endX=x,endY=y,duration=math.max(1,total)}
  elseif template.callback == "AnimQuestionMark" then
    -- FireRed AnimQuestionMark: starts at the outer/top edge of the attacker's
    -- actual sprite bounds. The 7-frame native animation lasts 54 ticks, then
    -- a 48-tick three-cycle affine wobble plays, followed by a 19-tick hold.
    -- Final live placement is corrected from real host battler dimensions in
    -- battle_bridge.instantiatePlan.
    local a=assert(ctx.attacker)
    local x=(a.x2 or a.x)+((a.side=="player") and 28 or -28)
    local y=(a.yPicOffset or a.y)-28
    if y<16 then y=16 end
    motion={kind="question_mark",startX=x,startY=y,endX=x,endY=y,duration=121,
      liveQuestionMarkBattler="attacker",playerSide=(a.side=="player")}
  elseif template.callback == "AnimLeer" then
    -- FireRed AnimLeer: place the 32x32 Leer sprite on the attacker, mirror
    -- the script X offset with attacker side, add the Y offset, and destroy
    -- when the native five-frame animation sequence (5 x 3 ticks) ends.
    local a=assert(ctx.attacker)
    local xoff=tonumber(args[1]) or 0
    if a.side ~= "player" then xoff=-xoff end
    local x=(a.x2 or a.x)+xoff
    local y=(a.yPicOffset or a.y)+(tonumber(args[2]) or 0)
    local total=0
    for _,af in ipairs((template.anim and template.anim.frames) or {}) do total=total+(af.duration or 1) end
    motion={kind="leer",startX=x,startY=y,endX=x,endY=y,duration=math.max(1,total)}
  elseif template.callback == "AnimFang" then
    -- FireRed AnimFang itself only waits for the sprite animation to finish.
    -- Cmd_createsprite has already anchored this template to the target, so
    -- keep the fang centered there for the complete native 8+16+4+4 frame
    -- sequence. The template's generic linear_scale affine animation handles
    -- the 0x200 -> 0x100 shrink during the opening eight frames.
    local t=assert(ctx.target)
    local x=(t.x2 or t.x)
    local y=(t.yPicOffset or t.y)
    local total=0
    for _,af in ipairs((template.anim and template.anim.frames) or {}) do total=total+(af.duration or 1) end
    motion={kind="fang",startX=x,startY=y,endX=x,endY=y,duration=math.max(1,total)}
  elseif template.callback == "AnimSuperFang" then
    -- FireRed AnimSuperFang only waits for its native 4 x 2-frame sprite
    -- animation to finish. Cmd_createsprite anchors it on ANIM_TARGET.
    local t=assert(ctx.target)
    local x=(t.x2 or t.x)
    local y=(t.yPicOffset or t.y)
    local total=0
    for _,af in ipairs((template.anim and template.anim.frames) or {}) do total=total+(af.duration or 1) end
    motion={kind="super_fang",startX=x,startY=y,endX=x,endY=y,duration=math.max(1,total)}
  elseif template.callback == "AnimTriAttackTriangle" then
    -- FireRed AnimTriAttackTriangle: initialize on the attacker's RAW battler
    -- coordinate, blink every callback until data[0] reaches 30, remain solid
    -- through callback 60, then linearly translate to target Y_PIC_OFFSET over
    -- 20 native ticks. The affine table continuously rotates the triangle.
    local a,t=assert(ctx.attacker),assert(ctx.target)
    local sx,sy=initOn(a,a,t,false,args[1] or 0,args[2] or 0)
    local tx=(t.x2 or t.x)
    local ty=(t.yPicOffset or t.y)
    motion={kind="tri_attack_triangle",startX=sx,startY=sy,endX=tx,endY=ty,
      holdFrames=60,nativeDuration=20,duration=81,liveRawYBattler="attacker",
      liveRawYKeys={"startY"}}
  elseif template.callback == "AnimLargeFlame" then
    -- FireRed AnimLargeFlame. Cmd_createsprite supplies the target center; the
    -- callback applies local offsets, then moves x2/y2 for callbacks 1..29 and
    -- destroys on callback 30. Horizontal velocity mirrors with attacker side.
    local a,t=assert(ctx.attacker),assert(ctx.target)
    local xoff=tonumber(args[1]) or 0
    if a.side ~= "player" then xoff=-xoff end
    local sx=(t.x2 or t.x)+xoff
    local sy=(t.yPicOffset or t.y)+(tonumber(args[2]) or 0)
    local vx=tonumber(args[5]) or 0
    if a.side=="player" then vx=-vx end
    local vy=tonumber(args[6]) or 0
    motion={kind="large_flame",startX=sx,startY=sy,endX=sx+vx*29,endY=sy+vy*29,
      duration=30,velocityX=vx,velocityY=vy,moveFrames=29}
  elseif template.callback == "InitSwirlingFogAnim" then
    motion=M.swirlingFog(args,ctx)
  elseif template.callback == "AnimBlackSmoke" then
    -- FireRed AnimBlackSmoke: Cmd_createsprite starts on the target center.
    -- Apply the local x/y offsets, then flicker every callback while x2 drifts
    -- by signed 8.8 velocity arg2 for arg4 callbacks. arg3 flips direction.
    local t=assert(ctx.target)
    local sx=(t.x2 or t.x)+(tonumber(args[1]) or 0)
    local sy=(t.yPicOffset or t.y)+(tonumber(args[2]) or 0)
    local vx=(tonumber(args[3]) or 0)/256
    if (tonumber(args[4]) or 0)~=0 then vx=-vx end
    local duration=math.max(1,math.floor(tonumber(args[5]) or 1))
    motion={kind="black_smoke",startX=sx,startY=sy,endX=sx+vx*(duration-1),endY=sy,
      duration=duration,velocityX=vx,flicker=true}
  elseif template.callback == "AnimSpriteOnMonPos" then
    -- FireRed AnimSpriteOnMonPos:
    --   arg2 selects attacker (0) / target (non-zero)
    --   arg3 selects picture-offset coords (0) / raw BATTLER_COORD_X/Y (non-zero).
    -- Raw BATTLER_COORD_Y uses a 1:1 battler-local offset. The shared raw-Y
    -- anchor is shifted upward by 16 host pixels; move-local offsets remain native.
    local who=(args[3]=="attacker" or args[3]==0) and ctx.attacker or ctx.target
    local respectPicOffsets=(tonumber(args[4]) or 0)==0
    local x=((respectPicOffsets and (who.x2 or who.x)) or who.x)+(args[1] or 0)
    local y
    if respectPicOffsets then
      y=(who.yPicOffset or who.y)+(args[2] or 0)
    else
      y=rawBattlerY(who,args[2] or 0)
    end
    local total=0
    for _,af in ipairs((template.anim and template.anim.frames) or {}) do total=total+(af.duration or 1) end
    motion={startX=x,startY=y,endX=x,endY=y,duration=math.max(1,total)}
  else
    error("unsupported FireRed visual callback: " .. tostring(template.callback))
  end
  local ev = {
    kind = "sprite",
    frame = frame,
    template = templateName,
    tag = template.tileTag,
    paletteTag = template.paletteTag,
    oam = clone(template.oam),
    anim = frameAnim(template),
    affineAnim = clone(template.affineAnim),
    coordinateSpace = template.coordinateSpace or BattleSpace.SPACE_BATTLER,
    displayScale = BattleSpace.spriteDisplayScale(),
    motion = motion,
    -- FireRed Cmd_createsprite is target/attacker-relative for subpriority only;
    -- sprite coordinates themselves begin at target center before callback init.
    subpriorityAnchor = subpriorityAnchor,
    priorityModifier = priorityModifier or 0,
    alphaBlend = alphaBlend and clone(alphaBlend) or nil,
    destroyFrame = frame + motion.duration,
  }
  if template.callback == "AnimFistOrFootRandomPos" then
    -- The callback-created splat has subpriority + 1, i.e. behind the hand or
    -- foot. Emit it first in this overlay renderer, then the parent sprite.
    out[#out+1] = {
      kind="sprite",frame=frame,template="gBasicHitSplatSpriteTemplate(callback-child)",
      tag=10135,paletteTag=10135,
      oam={affine=true,objMode="blend",bpp=4,width=32,height=32},
      anim={kind="dummy",frames={{tileOffset=0,duration=1}}},
      coordinateSpace=template.coordinateSpace or BattleSpace.SPACE_BATTLER,
      displayScale=BattleSpace.spriteDisplayScale(),
      motion={kind="linked_hit_splat",startX=motion.startX,startY=motion.startY,
        endX=motion.endX,endY=motion.endY,duration=motion.duration,affineVariant=0,
        randomGroup=motion.randomGroup,randomBattler=motion.randomBattler},
      subpriorityAnchor=subpriorityAnchor,priorityModifier=(priorityModifier or 0)+1,
      alphaBlend=alphaBlend and clone(alphaBlend) or nil,
      destroyFrame=frame+motion.duration,
    }
  end
  out[#out+1] = ev
end

-- Compile the exact Ember script into a renderer-facing timeline. This preserves
-- FireRed's script-frame delays; sounds are represented as events so the visual
-- and already-completed audio layers can be driven from one clock.
function M.compile(move, ctx)
  assert(ctx and ctx.attacker and ctx.target, "attacker/target coordinates required")
  local backgroundsEnabled = ctx.backgroundsEnabled ~= false
  local out = { events={}, durationFrames=0, fps=M.GBA_FPS, moveId=move.id }
  local frame = 0
  -- FireRed Task_FadeToBg uses BeginHardwarePaletteFade with delay 0.
  -- UpdateHardwarePaletteFade takes 17 updates for 0->16 and another 17
  -- for 16->0 (the 17th update is the hardware-fade finishing step).
  local BG_FADE_HALF_FRAMES = 17
  -- Task_FadeToBg spends one task update in state 2 at full black before the
  -- following update swaps/loads the requested background and starts fade-in.
  local BG_FADE_SWITCH_HOLD_FRAMES = 1
  local plannedBg = nil
  local lastBgTransition = nil
  -- FireRed tracks outstanding visual sprites/tasks with gAnimVisualTaskCount.
  -- For our deterministic planner, the equivalent is the latest destruction
  -- frame among visuals that have been launched so far.
  local visualFinishFrame = 0
  local alphaBlend = nil
  local customPanTask = nil
  local runtimeState = {}
  local commands
  if ctx.phase=="charge" then commands=move.chargeFlattened
  elseif ctx.phase=="trap_continuation" then commands=move.trapContinuationFlattened
  else commands=move.flattened end
  assert(type(commands)=="table", "move has no compiled command stream for phase "..tostring(ctx.phase or "release"))
  for _,cmd in ipairs(commands) do
    if cmd.op == "loadspritegfx" then
      out.events[#out.events+1] = {kind="loadspritegfx", frame=frame, tag=cmd.tag}
      -- FireRed Cmd_loadspritegfx switches gAnimScriptCallback to
      -- WaitAnimFrameCount with sAnimFramesToWait=1.  On successive animation
      -- updates that callback decrements 1->0, then hands control back to
      -- RunAnimScriptCommand, and only the following update executes the next
      -- command.  Preserve that native three-update interpreter stall.
      frame = frame + 3
    elseif cmd.op == "loopsewithpan" then
      for i=0,(cmd.count or 1)-1 do
        out.events[#out.events+1] = {kind="sound", frame=frame + i*(cmd.interval or 0), sound=cmd.sound, pan=cmd.pan}
      end
    elseif cmd.op == "playsewithpan" then
      out.events[#out.events+1] = {kind="sound", frame=frame, sound=cmd.sound, pan=cmd.pan, overlap=cmd.overlap==true}
    elseif cmd.op == "waitplaysewithpan" then
      -- FireRed command 0x1D creates a sound task that waits the requested
      -- number of animation frames, then plays through the secondary SE lane.
      out.events[#out.events+1] = {kind="sound", frame=frame + math.max(0,cmd.wait or 0),
        sound=cmd.sound, pan=cmd.pan, overlap=true}
    elseif cmd.op == "panse" then
      -- FireRed pans this one Source continuously from attacker to target. The
      -- mod audio transport stores directional L/R renders rather than a live
      -- pan-controllable Source, so launch it from the native starting side;
      -- visual timing remains exact and the sound is not retriggered.
      out.events[#out.events+1] = {kind="sound", frame=frame, sound=cmd.sound, pan=cmd.from or "attacker",
        panTo=cmd.to or "target", panIncrement=cmd.increment or 2}
    elseif cmd.op == "playmovecry" then
      -- Growl/Roar are cry moves in both Gen I and FireRed. Route them through
      -- the host's species-aware cry engine because claiming the native move
      -- animation row also suppresses its built-in move-cry playback.
      out.events[#out.events+1] = {kind="move_cry", frame=frame, tempo=cmd.tempo or 0x80}
    elseif cmd.op == "createsoundtask" and cmd.task == "SoundTask_FireBlast" then
      -- FireRed's dedicated Fire Blast task retriggers SE_M_FLAME_WHEEL every
      -- 11 task ticks for 111 ticks while panning attacker->target, then plays
      -- SE_M_FLAME_WHEEL2 twice six ticks apart at target pan.
      local a=cmd.args or {}
      local loopSound=a[1]; local endSound=a[2]
      for i=0,9 do
        local sf=frame+i*11
        local frac=i/9
        out.events[#out.events+1]={kind="sound",frame=sf,sound=loopSound,
          pan={from="attacker",to="target",t=frac},overlap=true}
      end
      out.events[#out.events+1]={kind="sound",frame=frame+117,sound=endSound,pan="target",overlap=true}
      out.events[#out.events+1]={kind="sound",frame=frame+123,sound=endSound,pan="target",overlap=true}
    elseif cmd.op == "createsoundtask" and cmd.task == "SoundTask_LoopSEAdjustPanning" then
      local a=cmd.args or {}
      local sound=a[1]; local from=a[2] or "attacker"; local to=a[3] or "target"
      local steps=math.max(1,a[4] or 1); local count=math.max(1,a[5] or 1); local interval=(a[7] or 0)+1
      for i=0,count-1 do
        local frac=math.min(1,(i*interval)/math.max(1,steps*interval))
        out.events[#out.events+1]={kind="sound",frame=frame+i*interval,sound=sound,pan={from=from,to=to,t=frac}}
      end
    elseif cmd.op == "createvisualtask" and (cmd.task == "AnimTask_MusicNotesRainbowBlend" or cmd.task == "AnimTask_MusicNotesClearRainbowBlend") then
      -- Palette allocation/free are represented by ROM-derived custom palette
      -- variants in visual_assets. FireRed destroys both tasks immediately.
    elseif cmd.op == "createvisualtask" and cmd.task == "SoundTask_AdjustPanningVar" then
      -- FireRed runs this visual task immediately when it is created, then once
      -- per animation tick. It does not play a sound; callbacks such as
      -- AnimConfuseRayBallBounce read gAnimCustomPanning from it.
      local a=cmd.args or {}
      customPanTask={
        startFrame=frame,
        from=a[1] or "attacker",
        to=a[2] or "target",
        increment=math.max(1,math.abs(tonumber(a[3]) or 1)),
        delay=math.max(0,tonumber(a[4]) or 0),
      }
    elseif cmd.op == "setalpha" then
      alphaBlend = {eva=cmd.eva or 16, evb=cmd.evb or 0}
    elseif cmd.op == "blendoff" then
      alphaBlend = nil
      for _,e in ipairs(out.events) do
        if e.kind=="palette_blend" and not e.effectEndFrame then e.effectEndFrame=frame end
      end
    elseif cmd.op == "fadetobg" then
      if backgroundsEnabled then
        -- FireRed Task_FadeToBg fades the current BG to black, swaps the move
        -- background while fully black, then fades the new BG back in.
        local nextBg=resolveArg(cmd.bg,ctx)
        local e={kind="battle_bg_transition",frame=frame,
          midpointFrame=frame+BG_FADE_HALF_FRAMES,
          swapFrame=frame+BG_FADE_HALF_FRAMES+BG_FADE_SWITCH_HOLD_FRAMES,
          endFrame=frame+BG_FADE_HALF_FRAMES*2+BG_FADE_SWITCH_HOLD_FRAMES,
          fromBg=plannedBg,toBg=nextBg}
        out.events[#out.events+1]=e
        lastBgTransition=e
        plannedBg=nextBg
      end
    elseif cmd.op == "changebg" then
      if backgroundsEnabled then
        -- FireRed Cmd_changebg swaps the animation background and loads that
        -- background's own palette immediately. Any palette blend that was
        -- affecting the previous BG is therefore replaced at this exact
        -- frame. Mega Punch relies on this: its normal battle BG is driven
        -- fully black during the fist wind-up, then the impact BG appears
        -- with a fresh palette rather than inheriting that black blend.
        for _,e in ipairs(out.events) do
          local target=e.target or e.selector
          if e.kind=="palette_blend" and (target=="bg" or target=="background")
              and not e.effectEndFrame then
            e.effectEndFrame=frame
          end
        end
        -- Unlike fadetobg, changebg performs no brightness fade. Represent it
        -- as a zero-duration transition so the shared renderer and restorebg
        -- logic keep one background state model.
        local nextBg=resolveArg(cmd.bg,ctx)
        local e={kind="battle_bg_transition",frame=frame,midpointFrame=frame,
          swapFrame=frame,endFrame=frame,fromBg=plannedBg,toBg=nextBg}
        out.events[#out.events+1]=e
        lastBgTransition=e
        plannedBg=nextBg
      end
    elseif cmd.op == "restorebg" then
      if backgroundsEnabled then
        local e={kind="battle_bg_transition",frame=frame,
          midpointFrame=frame+BG_FADE_HALF_FRAMES,
          swapFrame=frame+BG_FADE_HALF_FRAMES+BG_FADE_SWITCH_HOLD_FRAMES,
          endFrame=frame+BG_FADE_HALF_FRAMES*2+BG_FADE_SWITCH_HOLD_FRAMES,
          fromBg=plannedBg,toBg=nil}
        out.events[#out.events+1]=e
        lastBgTransition=e
        plannedBg=nil
      end
    elseif cmd.op == "waitbgfadeout" then
      -- When move backgrounds are disabled, their fade wait is disabled too.
      if backgroundsEnabled and lastBgTransition and lastBgTransition.midpointFrame>frame then
        frame=lastBgTransition.midpointFrame
      end
    elseif cmd.op == "waitbgfadein" then
      -- Cmd_waitbgfadein resumes only after the second hardware fade has
      -- finished and sAnimBackgroundFadeState returns to 0.
      if backgroundsEnabled and lastBgTransition and lastBgTransition.endFrame>frame then
        frame=lastBgTransition.endFrame
      end
    elseif cmd.op == "battlervisibility" then
      out.events[#out.events+1]={kind="battler_visibility",frame=frame,
        battler=cmd.battler or "attacker",visible=cmd.visible~=false}
    elseif cmd.op == "createsprite" and cmd.template == "gShakeMonOrTerrainSpriteTemplate" then
      -- FireRed invisible controller used by Rock Throw / Rock Slide and
      -- similar moves. Args: amplitude, delay, lifetime, coord selector.
      -- Selector 1 targets BG3_Y (vertical terrain shake).
      local a=resolveArgs(cmd.args,ctx)
      local amplitude=math.abs(math.floor(tonumber(a[1]) or 0))
      local delay=math.max(0,math.floor(tonumber(a[2]) or 0))
      local lifetime=math.max(0,math.floor(tonumber(a[3]) or 0))
      local selector=math.floor(tonumber(a[4]) or 0)
      local duration=lifetime+1 -- one final callback restores the original coord
      local finish=frame+duration
      out.events[#out.events+1]={kind="terrain_controller_shake",frame=frame,
        amplitude=amplitude,delay=delay,lifetime=lifetime,selector=selector,
        duration=duration,destroyFrame=finish}
      if finish > visualFinishFrame then visualFinishFrame=finish end
    elseif cmd.op == "createsprite" and cmd.template == "gBowMonSpriteTemplate" then
      -- FireRed gBowMonSpriteTemplate is an invisible stateful controller used
      -- by Headbutt / Horn Attack / Drill Peck. Its three script modes are NOT
      -- independent tilt-and-restore animations:
      --   0: move 12 px away, bow over 4 callbacks, and leave both states latched
      --   1: move 12 px back over 4 callbacks while preserving the bow
      --   2: wait 9 callbacks, then unbow over 3 callbacks and reset affine state
      -- Keep the controller lifetime finite for waitforvisualfinish, while the
      -- battler pose itself is reconstructed persistently by battle_bridge.
      local a=resolveArgs(cmd.args,ctx)
      local mode=math.floor(tonumber(a[1]) or 0)
      local duration=(mode==0) and 14 or ((mode==1) and 8 or ((mode==2) and 14 or 2))
      local finish=frame+duration
      out.events[#out.events+1]={kind="battler_bow",battler="attacker",frame=frame,
        bowMode=mode,duration=duration,destroyFrame=finish}
      if finish > visualFinishFrame then visualFinishFrame=finish end
    elseif cmd.op == "createsprite" then
      local template = assert(move.templates[cmd.template], "unknown template")
      local before = #out.events
      addSprite(out.events, frame, cmd.template, template, resolveArgs(cmd.args,ctx), ctx, cmd.anchor, cmd.priority, alphaBlend, runtimeState)
      if cmd.template == "gConfuseRayBallBounceSpriteTemplate" then
        local ev=out.events[#out.events]
        -- CreateSprite does not run the callback immediately. The first tick
        -- runs AnimConfuseRayBallBounce (setup only); the following tick runs
        -- AnimConfuseRayBallBounce_Step1, where SE_M_CONFUSE_RAY is first
        -- played. The old planner fired it on the create-sprite frame, two
        -- ticks early. Preserve the native callback cadence here.
        for af=0,(ev.motion.duration or 1)-1 do
          local prev=(af*5)%256; local nxt=((af+1)*5)%256
          if (prev==0 or prev>196) and nxt>0 then
            local soundFrame=frame+af+2
            local pan="target"
            if customPanTask then
              local calls=math.floor((soundFrame-customPanTask.startFrame)/(customPanTask.delay+1))+1
              local span=127 -- FireRed SOUND_PAN_ATTACKER (-64) -> TARGET (+63)
              local frac=math.min(1,(calls*customPanTask.increment)/span)
              pan={from=customPanTask.from,to=customPanTask.to,t=frac}
            end
            out.events[#out.events+1]={kind="sound",frame=soundFrame,sound=189,pan=pan}
          end
        end
      end
      for i=before+1,#out.events do
        local ev = out.events[i]
        local finish = ev.destroyFrame
        -- AnimConversion sprites are callback-owned and intentionally use a
        -- large provisional lifetime until AnimTask_ConversionAlphaBlend
        -- supplies their real shared release frame. Do not let that sentinel
        -- lifetime poison waitforvisualfinish; the alpha task below owns the
        -- actual visual completion time, matching FireRed.
        local provisionalConversion = ev.kind=="sprite" and ev.motion
          and ev.motion.kind=="conversion_particle"
        if not provisionalConversion and finish and finish > visualFinishFrame then
          visualFinishFrame = finish
        end
      end
    elseif cmd.op == "createvisualtask" and cmd.task == "AnimTask_AnimateGustTornadoPalette" then
      local a=cmd.args or {}
      local duration=math.max(1,math.floor(tonumber(a[2]) or 1))
      local finish=frame+duration
      out.events[#out.events+1]={kind="gust_palette_task",frame=frame,
        delay=math.max(0,math.floor(tonumber(a[1]) or 0)),duration=duration,destroyFrame=finish}
      if finish>visualFinishFrame then visualFinishFrame=finish end
    elseif cmd.op == "createvisualtask" and cmd.task == "AnimTask_CreateSurfWave" then
      local attackerSide=(ctx.attacker and ctx.attacker.side) or "player"
      local side=(attackerSide=="player") and "player" or "opponent"
      -- FireRed increments its Surf fade counter every two task callbacks.
      -- It reaches 13/16 blend, holds, then fades to zero after counter 54.
      local duration=136
      local finish=frame+duration
      out.events[#out.events+1]={kind="surf_wave",frame=frame,duration=duration,destroyFrame=finish,side=side}
      if finish>visualFinishFrame then visualFinishFrame=finish end
    elseif cmd.op == "createvisualtask" and cmd.task == "AnimTask_MoveSeismicTossBg" then
      local duration=120
      local finish=frame+duration
      out.events[#out.events+1]={kind="seismic_toss_bg_rise",frame=frame,duration=duration,destroyFrame=finish}
      if finish>visualFinishFrame then visualFinishFrame=finish end
    elseif cmd.op == "createvisualtask" and cmd.task == "AnimTask_SeismicTossBgAccelerateDownAtEnd" then
      out.events[#out.events+1]={kind="seismic_toss_bg_drop",frame=frame}
    elseif cmd.op == "createvisualtask" and cmd.task == "AnimTask_StartSlidingBg" then
      local a=cmd.args or {}
      out.events[#out.events+1]={
        kind="battle_bg_scroll",frame=frame,
        dx=a[1] or 0,dy=a[2] or 0,priority=a[3] or 0,
        stopArg=a[4] or -1
      }
    elseif cmd.op == "createvisualtask" and cmd.task == "AnimTask_InvertScreenColor" then
      local a=cmd.args or {}
      out.events[#out.events+1]={
        kind="screen_invert_toggle",frame=frame,
        bg=((tonumber(a[1]) or 0) % 512) >= 256,
        attacker=((tonumber(a[2]) or 0) % 512) >= 256,
        target=((tonumber(a[3]) or 0) % 512) >= 256,
      }
    elseif cmd.op == "createvisualtask" and cmd.task == "AnimTask_GlareEyeDots" then
      -- FireRed battle_anim_effects_3.c: create 13 pairs of 8x8 red eye dots
      -- every four callbacks along the attacker->target line. Each dot lives
      -- for 37 callbacks. Normal battles offset the pair by (-3,-3)/(+3,+3).
      local a,t=assert(ctx.attacker),assert(ctx.target)
      local nominalHeight=56
      local startX=(a.x2 or a.x)+((a.side=="player") and math.floor(nominalHeight/4) or -math.floor(nominalHeight/4))
      local startY=(a.yPicOffset or a.y)-math.floor(nominalHeight/4)
      local endX=(t.x2 or t.x); local endY=(t.yPicOffset or t.y)
      for pair=0,12 do
        local x,y
        if pair==0 then x,y=startX,startY
        elseif pair>=12 then x,y=endX,endY
        else
          local den=11
          x=math.floor(startX + pair*(endX-startX)/den)
          y=math.floor(startY + pair*(endY-startY)/den)
        end
        local sf=frame+(pair+1)*4
        for _,off in ipairs({-3,3}) do
          out.events[#out.events+1]={kind="sprite",frame=sf,template="gGlareEyeDotSpriteTemplate(task)",
            tag=10248,paletteTag=10248,oam={affine=false,objMode="normal",bpp=4,width=8,height=8},
            anim={kind="dummy",frames={{tileOffset=0,duration=1}}},
            coordinateSpace=BattleSpace.SPACE_BATTLER,displayScale=BattleSpace.spriteDisplayScale(),
            motion={kind="static",startX=x+off,startY=y+off,endX=x+off,endY=y+off,duration=37},
            subpriorityAnchor="target",priorityModifier=35,destroyFrame=sf+37}
        end
      end
      local finish=frame+52+37
      if finish>visualFinishFrame then visualFinishFrame=finish end
    elseif cmd.op == "createvisualtask" and cmd.task == "AnimTask_ScaryFace" then
      -- FireRed AnimTask_ScaryFace: BG1 alpha 0->14 one step every two frames,
      -- hold 21 callbacks, then 14->0 one step every two frames.
      local side=(ctx.target and ctx.target.side)=="opponent" and "player" or "opponent"
      local duration=78
      local finish=frame+duration
      out.events[#out.events+1]={kind="scary_face_bg",frame=frame,side=side,
        fadeIn=28,hold=21,fadeOut=28,duration=duration,destroyFrame=finish}
      if finish>visualFinishFrame then visualFinishFrame=finish end
    elseif cmd.op == "createvisualtask" and cmd.task == "AnimTask_ShakeTargetInPattern" then
      local a=cmd.args or {}
      local duration=math.max(1,tonumber(a[1]) or 1)
      local finish=frame+duration
      out.events[#out.events+1]={
        kind="battler_motion",motionKind="pattern_shake",battler="target",
        frame=frame,duration=duration,destroyFrame=finish,
        amplitude=tonumber(a[2]) or 3,vertical=(a[3]==true or a[3]==1),
        pattern=tonumber(a[4]) or 0
      }
      if finish>visualFinishFrame then visualFinishFrame=finish end
    elseif cmd.op == "createvisualtask" and cmd.task == "AnimTask_ElectricBolt" then
      local aa=cmd.args or {}
      local t=ctx.target
      local bx=(t.x or t.x2)+(aa[1] or 0)
      local by=rawBattlerY(t,aa[2] or 0)
      -- FireRed creates five bolt segments every two frames at +16..+80 Y;
      -- each segment lives 15 frames. Mode 0 uses the vertical 8x16 shapes.
      for i=1,5 do
        local start=frame+(i-1)*2
        local finish=start+15
        out.events[#out.events+1]={kind="electric_bolt_segment",frame=start,tag=10001,paletteTag=10001,
          oam={width=8,height=16},anim={kind="dummy",frames={{tileOffset=(i==2 and 1 or i==3 and 2 or i==4 and 3 or 0),duration=1}}},
          coordinateSpace=BattleSpace.SPACE_SCREEN,
          displayScale=BattleSpace.spriteDisplayScale(),
          x=bx,y=by+i*BattleSpace.length(16,BattleSpace.SPACE_SCREEN),duration=15,destroyFrame=finish,liveRawYBattler="target"}
        if finish>visualFinishFrame then visualFinishFrame=finish end
      end
    elseif cmd.op == "createvisualtask" and cmd.task == "AnimTask_SmokescreenImpact" then
      -- FireRed SmokescreenImpact creates four 16x16 sprites around
      -- (target X_2 + 8, target Y_PIC_OFFSET + 8). Each quadrant runs the
      -- dedicated three-frame 4/4/4-tick animation with matching flips.
      local t=assert(ctx.target)
      local finish=frame+12
      out.events[#out.events+1]={kind="smokescreen_impact",frame=frame,duration=12,destroyFrame=finish,
        x=(t.x2 or t.x)+8,y=(t.yPicOffset or t.y)+8}
      if finish>visualFinishFrame then visualFinishFrame=finish end
    elseif cmd.op == "createvisualtask" and cmd.task == "AnimTask_MonToSubstitute" then
      local swapFrame=frame+10
      local finish=swapFrame+57
      out.events[#out.events+1]={
        kind="battler_affine_sequence",sequence="substitute",
        battler="attacker",frame=frame,duration=10,destroyFrame=swapFrame
      }
      local a=assert(ctx.attacker)
      out.events[#out.events+1]={
        kind="sprite",
        frame=swapFrame,duration=57,destroyFrame=finish,
        customImageKey=(a.side=="player") and "substitute_back" or "substitute_front",
        oam={width=64,height=64},
        displayScale=1,
        x=(a.side=="player") and 40 or 120,
        y=(a.side=="player") and 80 or 40,
        anim={kind="once",frames={{tileOffset=0,duration=57}}},
        motion={
          kind="substitute_doll_bounce",
          duration=57,
          startX=(a.side=="player") and 40 or 120,
          startY=(a.side=="player") and 80 or 40,
        }
      }
      -- FireRed AnimTask_MonToSubstituteDoll:
      -- first landing on task callback 31, second landing / destroy on 56.
      out.events[#out.events+1]={
        kind="sound",frame=swapFrame+31,sound=118,pan="attacker",overlap=true
      }
      out.events[#out.events+1]={
        kind="sound",frame=swapFrame+56,sound=118,pan="attacker",overlap=true
      }
      if finish>visualFinishFrame then visualFinishFrame=finish end
    elseif cmd.op == "createvisualtask" and cmd.task == "AnimTask_DoubleTeam" then
      -- FireRed battle_anim_effects_1.c::AnimTask_DoubleTeam. Two battler
      -- clones use a palette blended 11/16 toward black and start 128 sine
      -- units apart. data[0] advances every second callback and both the
      -- amplitude and angular velocity are derived from gSineTable[data[0]].
      -- The clones destroy when data[0] advances past 64: 130 callbacks.
      local duration=130
      local finish=frame+duration
      out.events[#out.events+1]={kind="double_team_clones",battler="attacker",
        frame=frame,duration=duration,destroyFrame=finish,
        cloneAlpha=12/16,darkMul=5/16}
      if finish>visualFinishFrame then visualFinishFrame=finish end
    elseif cmd.op == "createvisualtask" and cmd.task == "AnimTask_TransformMon" then
      -- FireRed battle_anim_effects_3.c::AnimTask_TransformMon. REG_MOSAIC
      -- grows from 0 to 15 one step every three callbacks, the engine swaps
      -- the transformed battler graphic at full mosaic, then the mosaic
      -- shrinks back to zero. Keep the species/state swap owned by the host.
      local duration=93
      local finish=frame+duration
      out.events[#out.events+1]={kind="battler_mosaic",battler="attacker",frame=frame,
        duration=duration,destroyFrame=finish,swapAge=47,maxStretch=15}
      if finish>visualFinishFrame then visualFinishFrame=finish end
    elseif cmd.op == "createvisualtask" and cmd.task == "AnimTask_Minimize" then
      -- FireRed battle_anim_effects_2.c::AnimTask_Minimize. The task runs three
      -- 32-frame shrink passes (0x28 native affine-scale units per callback),
      -- creates traces at local callbacks 0/3/6, waits 33 callbacks at the
      -- minimum size, then restores by 0x50 native units every callback. The
      -- complete visual task destroys on callback 151.
      local duration=151
      local finish=frame+duration
      out.events[#out.events+1]={kind="battler_affine_sequence",sequence="minimize",
        battler="attacker",frame=frame,duration=duration,destroyFrame=finish,
        cloneAlpha=10/16}
      if finish>visualFinishFrame then visualFinishFrame=finish end
    elseif cmd.op == "createvisualtask" and cmd.task == "AnimTask_GrowAndGrayscale" then
      -- FireRed battle_anim_effects_2.c. SetSpriteRotScale(target, 0xD0,
      -- 0xD0, 0), grayscale the target palette, hold for 81 callbacks, then
      -- ResetSpriteRotScale and restore the original palette.
      local duration=81
      local finish=frame+duration
      out.events[#out.events+1]={kind="battler_scale",battler="target",frame=frame,
        fixedNativeScale=0xD0,duration=duration,destroyFrame=finish}
      out.events[#out.events+1]={kind="battler_grayscale",battler="target",frame=frame,
        amount=1,duration=duration,destroyFrame=finish}
      if finish>visualFinishFrame then visualFinishFrame=finish end
    elseif cmd.op == "createvisualtask" and cmd.task == "AnimTask_MetallicShine" then
      local a=cmd.args or {}
      -- FireRed AnimTask_MetallicShine scrolls BG1 by -4 px/frame. The shine
      -- pattern wraps every 128 px (32 frames), runs two visible passes, then
      -- keeps the visual task alive for one final 32-frame cleanup pass.
      local duration=96
      local finish=frame+duration
      out.events[#out.events+1]={kind="metallic_shine",frame=frame,battler="attacker",
        keepPalette=(a[1] or 0)~=0,useCustomColor=(a[2] or 0)~=0,customColor=a[3] or 0,
        visibleDuration=64,duration=duration,destroyFrame=finish,
        coordinateSpace=BattleSpace.SPACE_SCREEN,displayScale=BattleSpace.displayScale(BattleSpace.SPACE_SCREEN)}
      if finish > visualFinishFrame then visualFinishFrame = finish end
    elseif cmd.op == "createvisualtask" and cmd.task == "AnimTask_WindUpLunge" then
      local a=cmd.args or {}
      -- FireRed battle_anim_mon_movement.c: first translate by arg1 over arg3
      -- frames while sampling a sine Y wave, wait arg4 frames, then lunge by
      -- arg5 over arg6 frames. The task intentionally leaves the battler at
      -- its final x2/y2; a following SlideMonToOriginalPos controller can
      -- capture and return that live offset.
      local firstDuration=math.max(1,math.floor(tonumber(a[4]) or 1))
      local delay=math.max(0,math.floor(tonumber(a[5]) or 0))
      local lungeDuration=math.max(1,math.floor(tonumber(a[7]) or 1))
      local duration=firstDuration+delay+lungeDuration
      local finish=frame+duration
      out.events[#out.events+1]={kind="battler_motion",motionKind="wind_up_lunge",
        battler=a[1] or "attacker",frame=frame,
        windX=tonumber(a[2]) or 0,waveAmplitude=tonumber(a[3]) or 0,
        firstDuration=firstDuration,delay=delay,
        lungeX=tonumber(a[6]) or 0,lungeDuration=lungeDuration,
        duration=duration,destroyFrame=finish}
      if finish > visualFinishFrame then visualFinishFrame = finish end
    elseif cmd.op == "createvisualtask" and cmd.task == "AnimTask_SkullBashPosition" then
      local a=cmd.args or {}
      local mode=math.floor(tonumber(a[1]) or 0)
      if mode==0 then
        -- FireRed battle_anim_effects_1.c: AnimTask_SkullBashPositionSet.
        -- 8-frame 24px set, 8-frame rotation, 8-count alternating shake,
        -- 12-frame hold, then a 3-frame slide back to x2=0.  The final
        -- rotation is intentionally held through the impact until reset.
        local duration=52
        local finish=frame+duration
        out.events[#out.events+1]={kind="battler_affine_sequence",battler="attacker",frame=frame,
          sequence="skull_bash_set",duration=duration,destroyFrame=finish}
        if finish > visualFinishFrame then visualFinishFrame=finish end
      elseif mode==1 then
        -- Reset is eight inverse rotation ticks plus native cleanup callback.
        -- Extend the preceding set event up to this exact frame so its final
        -- rotated pose persists through the impact sequence.
        for i=#out.events,1,-1 do
          local prior=out.events[i]
          if prior.kind=="battler_affine_sequence" and prior.sequence=="skull_bash_set"
             and prior.battler=="attacker" then
            prior.destroyFrame=frame
            prior.duration=math.max(prior.duration or 0,frame-prior.frame)
            break
          end
        end
        local duration=9
        local finish=frame+duration
        out.events[#out.events+1]={kind="battler_affine_sequence",battler="attacker",frame=frame,
          sequence="skull_bash_reset",duration=duration,destroyFrame=finish}
        if finish > visualFinishFrame then visualFinishFrame=finish end
      end
    elseif cmd.op == "createvisualtask" and cmd.task == "AnimTask_ThrashMoveMonHorizontal" then
      -- FireRed sThrashMoveMonAffineAnimCmds: four 7-frame scale segments,
      -- looped three times for 84 frames total. This task affects only the
      -- attacker's affine matrix; the companion Vertical task owns x/y motion.
      local duration=84
      local finish=frame+duration
      out.events[#out.events+1]={kind="battler_affine_sequence",battler="attacker",frame=frame,
        sequence="thrash",duration=duration,destroyFrame=finish}
      if finish > visualFinishFrame then visualFinishFrame=finish end
    elseif cmd.op == "createvisualtask" and cmd.task == "AnimTask_ThrashMoveMonVertical" then
      -- FireRed task: +/-4 px horizontal sawtooth (7,14,7 frames) repeated
      -- three times, with a 2 px vertical bob toggled every third frame.
      local duration=84
      local finish=frame+duration
      out.events[#out.events+1]={kind="battler_motion",motionKind="thrash_native",
        battler="attacker",frame=frame,duration=duration,destroyFrame=finish}
      if finish > visualFinishFrame then visualFinishFrame=finish end
    elseif cmd.op == "createvisualtask" and cmd.task == "AnimTask_TranslateMonElliptical" then
      local a=cmd.args or {}
      local speed=math.max(0,math.min(5,a[5] or 0))
      local wavePeriod=2^speed
      local duration=math.max(1,math.floor(256/wavePeriod)*math.max(1,a[4] or 1))
      local finish=frame+duration
      out.events[#out.events+1]={kind="battler_motion",motionKind="elliptical_raw",
        battler=a[1] or "attacker",frame=frame,xRadius=a[2] or 0,yRadius=a[3] or 0,
        loops=a[4] or 1,step=a[5] or 1,duration=duration,destroyFrame=finish}
      if finish > visualFinishFrame then visualFinishFrame = finish end
    elseif cmd.op == "createvisualtask" and cmd.task == "AnimTask_TranslateMonEllipticalRespectSide" then
      local a=cmd.args or {}
      local speed=math.max(0,math.min(5,a[5] or 0))
      local wavePeriod=2^speed
      local duration=math.max(1,math.floor(256/wavePeriod)*math.max(1,a[4] or 1))
      local finish=frame+duration
      out.events[#out.events+1]={kind="battler_motion",motionKind="elliptical",battler=a[1] or "attacker",frame=frame,xRadius=a[2] or 0,yRadius=a[3] or 0,loops=a[4] or 1,step=a[5] or 1,duration=duration,destroyFrame=finish}
      if finish > visualFinishFrame then visualFinishFrame = finish end
    elseif cmd.op == "createvisualtask" and cmd.task == "AnimTask_TraceMonBlended" then
      local a=cmd.args or {}
      -- This task draws translucent copies of the attacker while it moves. The
      -- host battler sprite itself remains authoritative; the shared bridge
      -- carries a lightweight afterimage event so unsupported 3D renderers can
      -- safely ignore it without affecting movement/timing.
      local duration=math.max(1,(a[3] or 1)*(a[4] or 1))
      local finish=frame+duration
      out.events[#out.events+1]={kind="battler_afterimage",frame=frame,battler="attacker",interval=a[2] or 4,count=a[3] or 7,lifetime=a[4] or 3,duration=duration,destroyFrame=finish}
      if finish > visualFinishFrame then visualFinishFrame = finish end
    elseif cmd.op == "createvisualtask" and cmd.task == "AnimTask_SlideOffScreen" then
      local a=cmd.args or {}
      local battler=a[1] or "target"
      local base=(battler=="attacker") and ctx.attacker or ctx.target
      local speed=math.abs(tonumber(a[2]) or 1)
      -- Roar/Whirlwind push each side out through its nearest horizontal edge.
      local dir=(base.side=="player") and -1 or 1
      local startX=base.x2 or base.x or 0
      local boundary=(dir<0) and -32 or 192
      local duration=math.max(1,math.ceil(math.abs(boundary-startX)/speed)+1)
      local finish=frame+duration
      out.events[#out.events+1]={kind="battler_motion",motionKind="slide_offscreen",
        battler=battler,frame=frame,speed=dir*speed,duration=duration,destroyFrame=finish}
      if finish > visualFinishFrame then visualFinishFrame=finish end
    elseif cmd.op == "createvisualtask" and cmd.task == "AnimTask_RotateMonToSideAndRestore" then
      local a=cmd.args or {}
      local turnFrames=math.max(1,math.floor(tonumber(a[1]) or 1))
      local delta=tonumber(a[2]) or 0
      local battler=a[3] or "target"
      local restoreMode=math.floor(tonumber(a[4]) or 0)
      -- FireRed case 2 runs the same number of callbacks in reverse, then
      -- ResetSpriteRotScale on the following completion edge. Peck uses case 2.
      local duration=(restoreMode==2) and (turnFrames*2) or turnFrames
      local finish=frame+duration
      out.events[#out.events+1]={kind="battler_rotate",battler=battler,frame=frame,
        turnFrames=turnFrames,rotationDelta=delta,restoreMode=restoreMode,
        duration=duration,destroyFrame=finish}
      if finish > visualFinishFrame then visualFinishFrame=finish end
    elseif cmd.op == "createvisualtask" and cmd.task == "AnimTask_RotateMonSpriteToSide" then
      local a=cmd.args or {}
      local turnFrames=math.max(1,math.floor(tonumber(a[1]) or 1))
      local delta=tonumber(a[2]) or 0
      local battler=a[3] or "target"
      local restoreMode=math.floor(tonumber(a[4]) or 0)
      local duration=(restoreMode==2) and (turnFrames*2) or turnFrames
      local finish=frame+duration
      out.events[#out.events+1]={kind="battler_rotate",battler=battler,frame=frame,
        turnFrames=turnFrames,rotationDelta=delta,restoreMode=restoreMode,
        -- Skull Bash uses this task for its head-down charge pose. GBA OBJ
        -- affine rotation samples through the inverse matrix, whereas LÖVE
        -- rotates geometry directly, so this move needs the visible sign
        -- inverted without changing older tested users of the shared task.
        invertVisibleRotation=(move.id=="SKULL_BASH"),
        duration=duration,destroyFrame=finish}
      if finish > visualFinishFrame then visualFinishFrame=finish end
    elseif cmd.op == "createvisualtask" and cmd.task == "AnimTask_DrillPeckHitSplats" then
      -- FireRed increments the task angle by 8 each callback and creates a
      -- flashing splat whenever angle % 32 == 0: eight splats, 4 frames apart,
      -- arranged on a 13 px circle around the target. Each child is a tracked
      -- visual, so waitforvisualfinish also waits for the final 14-frame flash.
      local t=assert(ctx.target)
      local baseX=(t.x2 or t.x); local baseY=(t.yPicOffset or t.y)
      for i=0,7 do
        local angle=i*32
        local r=angle*math.pi*2/256
        local xv=math.sin(r)*-13; local yv=math.cos(r)*-13
        local xoff=(xv>=0) and math.floor(xv+0.5) or math.ceil(xv-0.5)
        local yoff=(yv>=0) and math.floor(yv+0.5) or math.ceil(yv-0.5)
        local sf=frame+i*4
        out.events[#out.events+1]={kind="sprite",frame=sf,template="gFlashingHitSplatSpriteTemplate(task)",
          tag=10135,paletteTag=10135,oam={affine=true,objMode="normal",bpp=4,width=32,height=32},
          anim={kind="dummy",frames={{tileOffset=0,duration=1}}},
          coordinateSpace=BattleSpace.SPACE_BATTLER,displayScale=BattleSpace.spriteDisplayScale(),
          motion={kind="flashing_hit_splat",startX=baseX+xoff,startY=baseY+yoff,
            endX=baseX+xoff,endY=baseY+yoff,duration=14,affineVariant=3},
          subpriorityAnchor="target",priorityModifier=3,destroyFrame=sf+14}
      end
      local finish=frame+7*4+14
      if finish > visualFinishFrame then visualFinishFrame=finish end
    elseif cmd.op == "createvisualtask" and cmd.task == "AnimTask_BarrageBall" then
      -- FireRed battle_anim_effects_3.c: AnimTask_BarrageBall. The task creates
      -- one RED_BALL at the attacker, translates the first eight of sixteen
      -- arc steps every other callback, finishes the remaining eight every
      -- callback, then toggles invisibility every two callbacks 16 times.
      local a,t=assert(ctx.attacker),assert(ctx.target)
      local sx,sy=(a.x2 or a.x),(a.yPicOffset or a.y)
      local tx,ty=(t.x2 or t.x),(t.yPicOffset or t.y)
      local finish=frame+59
      out.events[#out.events+1]={kind="sprite",frame=frame,
        template="gBarrageBallSpriteTemplate(task)",tag=10254,paletteTag=10254,
        oam={affine=true,objMode="normal",bpp=4,width=32,height=32},
        anim={kind="dummy",frames={{tileOffset=0,duration=1}}},
        coordinateSpace=BattleSpace.SPACE_BATTLER,displayScale=BattleSpace.spriteDisplayScale(),
        motion={kind="barrage_ball",startX=sx,startY=sy,endX=tx,endY=ty,
          duration=57,arcAmplitude=-32,liveTargetHeightQuarter=true,
          attackerSide=a.side,translationSteps=16,slowSteps=8,blinkCount=16},
        subpriorityAnchor="target",priorityModifier=-5,destroyFrame=frame+57}
      if finish > visualFinishFrame then visualFinishFrame=finish end
    elseif cmd.op == "createvisualtask" and cmd.task == "AnimTask_Withdraw" then
      -- FireRed AnimTask_Withdraw: data[0] advances by 0xB0 until 0xF20
      -- (22 callbacks), holds that rotation for 30 callbacks, then unwinds
      -- by 0xB0 for 22 callbacks. Reuse the shared battler rotation event
      -- with an explicit hold phase so 2D and Potato Voxel share the path.
      local turnFrames=22
      local holdFrames=30
      local finish=frame+turnFrames+holdFrames+turnFrames
      out.events[#out.events+1]={kind="battler_rotate",battler="attacker",frame=frame,
        turnFrames=turnFrames,holdFrames=holdFrames,rotationDelta=0xB0,restoreMode=2,
        duration=turnFrames+holdFrames+turnFrames,destroyFrame=finish}
      if finish > visualFinishFrame then visualFinishFrame=finish end
    elseif cmd.op == "createvisualtask" and cmd.task == "AnimTask_SetGrayscaleOrOriginalPal" then
      -- FireRed battle_anim_dark.c: this task toggles the battler palette and
      -- destroys immediately. Model grayscale as persistent visual state until
      -- the matching restore task is reached; it must not extend
      -- waitforvisualfinish on its own.
      local a=cmd.args or {}
      local battler=a[1] or "attacker"
      local original=(tonumber(a[2]) or 0)~=0
      if not original then
        out.events[#out.events+1]={kind="battler_grayscale",battler=battler,
          amount=1,frame=frame}
      else
        for i=#out.events,1,-1 do
          local prior=out.events[i]
          if prior.kind=="battler_grayscale" and prior.battler==battler
             and prior.destroyFrame==nil then
            prior.destroyFrame=frame
            prior.duration=math.max(0,frame-(prior.frame or frame))
            break
          end
        end
      end
    elseif cmd.op == "createvisualtask" and cmd.task == "AnimTask_MeditateStretchAttacker" then
      -- FireRed sAffineAnim_MeditateStretchAttacker:
      --   (-8,+10) x 16, (+18,-18) x 16, (-20,+16) x 8.
      -- Native OBJ affine values accumulate across the three commands and
      -- return exactly to 0x100/0x100 after 40 callbacks.
      out.events[#out.events+1]={kind="battler_affine_sequence",battler="attacker",
        frame=frame,sequence="meditate",duration=40,destroyFrame=frame+40}
      local finish=frame+40
      if finish > visualFinishFrame then visualFinishFrame=finish end
    elseif cmd.op == "createvisualtask" and cmd.task == "AnimTask_DefenseCurlDeformMon" then
      -- FireRed DefenseCurlDeformMonAffineAnimCmds:
      --   (-12,+20) x 8, (+12,-20) x 8, loop 2.
      -- Each 16-frame pair returns to native scale, and AFFINEANIMCMD_LOOP(2)
      -- repeats the pair twice more, for three source-faithful cycles (48f).
      -- Reuse the global battler_scale renderer so 2D and Potato Voxel share
      -- the exact same affine path.
      out.events[#out.events+1]={kind="battler_affine_sequence",battler="attacker",
        frame=frame,sequence="defense_curl",duration=48,destroyFrame=frame+48}
      local finish=frame+48
      if finish > visualFinishFrame then visualFinishFrame=finish end
    elseif cmd.op == "createvisualtask" and cmd.task == "AnimTask_AcidArmor" then
      -- FireRed battle_anim_effects_3.c: 64 scanline-distortion/fade callbacks,
      -- 13 invisible hold callbacks, 32 fade-in callbacks, then task cleanup.
      -- Keep the full task as one battler replacement event so the renderer can
      -- hide the native battler and redraw the distorted copy in both flat and
      -- staged battle modes.
      local a=cmd.args or {}
      local duration=110
      local finish=frame+duration
      out.events[#out.events+1]={kind="battler_acid_armor",battler=a[1] or "attacker",
        frame=frame,duration=duration,destroyFrame=finish}
      if finish > visualFinishFrame then visualFinishFrame=finish end
    elseif cmd.op == "createvisualtask" and cmd.task == "AnimTask_Splash" then
      local a=cmd.args or {}
      local hops=math.max(0,math.floor(tonumber(a[2]) or 0))
      local duration=hops*38
      local finish=frame+duration
      if duration>0 then
        out.events[#out.events+1]={kind="battler_affine_sequence",sequence="splash",
          battler=a[1] or "attacker",frame=frame,hops=hops,duration=duration,destroyFrame=finish}
        if finish > visualFinishFrame then visualFinishFrame=finish end
      end
    elseif cmd.op == "createvisualtask" and cmd.task == "AnimTask_ScaleMonAndRestore" then
      local a=cmd.args or {}
      local d=math.max(1,math.floor(tonumber(a[3]) or 1))
      -- Setup frame + d scale-out ticks + d restore ticks + final reset.
      local duration=d*2+2
      local finish=frame+duration
      out.events[#out.events+1]={kind="battler_scale",battler=a[4] or "target",frame=frame,
        xDelta=tonumber(a[1]) or 0,yDelta=tonumber(a[2]) or 0,scaleDuration=d,
        duration=duration,destroyFrame=finish}
      if finish > visualFinishFrame then visualFinishFrame=finish end
    elseif cmd.op == "createvisualtask" and cmd.task == "AnimTask_SwayMon" then
      local a=cmd.args or {}
      -- FireRed's task increments a 16-bit phase accumulator by arg2 each
      -- frame and decrements arg3 on each half-wave boundary. BubbleBeam's
      -- 3072/8 parameters complete in 86 frames. Simulate that boundary
      -- counter here so other moves can reuse the same canonical task.
      local phase=0; local hi=0; local lo=1; local sways=math.max(1,a[4] or 1); local duration=0
      repeat
        duration=duration+1
        phase=(phase+(a[3] or 0))%65536
        local wave=math.floor(phase/256)
        if (wave>0x7F and hi==0 and lo==1) or (wave<0x7F and hi==1 and lo==0) then
          hi=1-hi; lo=1-lo; sways=sways-1
        end
      until sways<=0 or duration>=4096
      local finish=frame+duration
      out.events[#out.events+1]={kind="battler_motion",motionKind="sway",battler=a[5] or "target",frame=frame,
        direction=a[1] or 0,amplitude=a[2] or 0,wavePeriod=a[3] or 0,duration=duration,
        attackerSide=ctx.attacker.side,destroyFrame=finish}
      if finish > visualFinishFrame then visualFinishFrame = finish end
    elseif cmd.op == "createvisualtask" and cmd.task == "AnimTask_ShakeAndSinkMon" then
      local a=cmd.args or {}
      -- FireRed battle_anim_mon_movement.c: horizontal shake while applying a
      -- downward 8.8 fixed-point offset each frame. The final sunk Y offset is
      -- intentionally left latched until a later SlideMonToOriginalPos.
      local duration=math.max(1,math.floor(tonumber(a[5]) or 1))
      local finish=frame+duration
      out.events[#out.events+1]={kind="battler_motion",motionKind="shake_and_sink",
        battler=a[1] or "attacker",frame=frame,shakeX=tonumber(a[2]) or 0,
        delay=math.max(0,math.floor(tonumber(a[3]) or 0)),sinkSpeed=tonumber(a[4]) or 0,
        duration=duration,destroyFrame=finish}
      if finish > visualFinishFrame then visualFinishFrame=finish end
    elseif cmd.op == "createvisualtask" and cmd.task == "AnimTask_DigDownMovement" then
      local a=cmd.args or {}
      if a[1]==true then
        for i=#out.events,1,-1 do
          local prior=out.events[i]
          if prior.kind=="battler_motion" and prior.motionKind=="dig_down"
             and prior.battler=="attacker" and not prior.holdUntilFrame then
            prior.holdUntilFrame=frame
            break
          end
        end
        out.events[#out.events+1]={kind="battler_visibility",frame=frame,battler="attacker",visible=false}
      else
        -- FireRed AnimTask_DigBounceMovement takes ~156 movement callbacks to
        -- pass 63 px, with a 6/256 sine phase step and 1 px descent every 3.
        local duration=160
        local finish=frame+duration
        out.events[#out.events+1]={kind="battler_motion",motionKind="dig_down",
          battler="attacker",frame=frame,duration=duration,destroyFrame=finish,targetY=64}
        if finish>visualFinishFrame then visualFinishFrame=finish end
      end
    elseif cmd.op == "createvisualtask" and cmd.task == "AnimTask_DigUpMovement" then
      local a=cmd.args or {}
      if a[1]==true then
        local duration=10
        local finish=frame+duration
        for i=#out.events,1,-1 do
          local prior=out.events[i]
          if prior.kind=="battler_motion" and prior.motionKind=="dig_underground"
             and prior.battler=="attacker" and not prior.holdUntilFrame then
            prior.holdUntilFrame=frame
            break
          end
        end
        out.events[#out.events+1]={kind="battler_motion",motionKind="dig_up",
          battler="attacker",frame=frame,duration=duration,destroyFrame=finish,startY=64}
        if finish>visualFinishFrame then visualFinishFrame=finish end
      else
        out.events[#out.events+1]={kind="battler_visibility",frame=frame,battler="attacker",visible=true}
        out.events[#out.events+1]={kind="battler_motion",motionKind="dig_underground",
          battler="attacker",frame=frame,duration=1,destroyFrame=frame+1,targetY=64}
        if frame+1>visualFinishFrame then visualFinishFrame=frame+1 end
      end
    elseif cmd.op == "createvisualtask" and cmd.task == "AnimTask_AttackerFadeToInvisible" then
      -- FireRed increments BLDALPHA once every arg0+1 callbacks. Sky Attack
      -- uses arg0=0, so the attacker becomes fully invisible after 16 ticks.
      local a=cmd.args or {}
      local delay=math.max(0,math.floor(tonumber(a[1]) or 0))
      local duration=16*(delay+1)
      local finish=frame+duration
      out.events[#out.events+1]={kind="battler_visibility",frame=finish,battler="attacker",visible=false}
      if finish>visualFinishFrame then visualFinishFrame=finish end
    elseif cmd.op == "createvisualtask" and cmd.task == "AnimTask_AttackerFadeFromInvisible" then
      -- FireRed's reverse alpha fade. Sky Attack uses arg0=1 (one callback
      -- delay between alpha steps), for 32 ticks total. The palette fade that
      -- follows in the script supplies the visible white-to-normal transition.
      local a=cmd.args or {}
      local delay=math.max(0,math.floor(tonumber(a[1]) or 0))
      local duration=16*(delay+1)
      local finish=frame+duration
      out.events[#out.events+1]={kind="battler_visibility",frame=frame,battler="attacker",visible=true}
      if finish>visualFinishFrame then visualFinishFrame=finish end
    elseif cmd.op == "createvisualtask" and cmd.task == "AnimTask_PositionFissureBgOnBattler" then
      local a=cmd.args or {}
      -- FireRed receives ANIM_TARGET/ANIM_ATTACKER as numeric selectors, while
      -- hand-authored move ports use the clearer symbolic names. Accept both.
      -- v0.55.30 treated tonumber("target") as 0 and therefore positioned the
      -- Fissure BG on the attacker, pushing the crack artwork out of view.
      local selector=a[1]
      local battler
      if selector=="target" then battler="target"
      elseif selector=="attacker" then battler="attacker"
      else battler=((tonumber(selector) or 0)%2==1) and "target" or "attacker" end
      local anchor=(battler=="target") and ctx.target or ctx.attacker
      -- FireRed writes BG3_X = 32 - BATTLER_COORD_X_2 and
      -- BG3_Y = 64 - BATTLER_COORD_Y_PIC_OFFSET. Our renderer samples the
      -- native 240x144 background then scales it by 2/3, so convert the
      -- host 160-wide battle anchors back into native source pixels here.
      local x=((anchor and (anchor.x2 or anchor.x)) or 0)*1.5
      local y=((anchor and (anchor.yPicOffset or anchor.y)) or 0)*1.5
      out.events[#out.events+1]={kind="fissure_bg_position",frame=frame,
        x=32-x,y=64-y,battler=battler}
    elseif cmd.op == "createvisualtask" and cmd.task == "AnimTask_HorizontalShake" then
      local a=cmd.args or {}
      local target=a[1] or "all_battlers"
      local intensity=math.max(0,math.floor(tonumber(a[2]) or 0))+3
      local maxTime=math.max(0,math.floor(tonumber(a[3]) or 0))
      -- Native task toggles every two frames. After maxTime toggles it decays
      -- by one pixel every four toggles until the offset reaches zero.
      local toggles=maxTime+math.max(0,intensity-1)*4
      local duration=math.max(1,toggles*2+1)
      local finish=frame+duration
      if target=="all_battlers" then
        out.events[#out.events+1]={kind="battler_motion",motionKind="horizontal_ground_shake",battler="attacker",frame=frame,
          intensity=intensity,maxTime=maxTime,duration=duration,destroyFrame=finish}
        out.events[#out.events+1]={kind="battler_motion",motionKind="horizontal_ground_shake",battler="target",frame=frame,
          intensity=intensity,maxTime=maxTime,duration=duration,destroyFrame=finish}
      elseif target=="terrain" then
        out.events[#out.events+1]={kind="terrain_horizontal_shake",frame=frame,intensity=intensity,maxTime=maxTime,
          duration=duration,destroyFrame=finish}
      else
        out.events[#out.events+1]={kind="battler_motion",motionKind="horizontal_ground_shake",battler=target,frame=frame,
          intensity=intensity,maxTime=maxTime,duration=duration,destroyFrame=finish}
      end
      if finish > visualFinishFrame then visualFinishFrame=finish end
    elseif cmd.op == "createvisualtask" and cmd.task == "AnimTask_ShakeMonInPlace" then
      local a=cmd.args or {}
      local count=math.max(0,math.floor(tonumber(a[4]) or 0))
      local delay=math.max(0,math.floor(tonumber(a[5]) or 0))
      -- AnimTask_ShakeMonInPlace calls its step immediately. The first visible
      -- offset is therefore -arg1/-arg2 relative to the battler's current
      -- location, and the final step restores that exact starting location.
      local duration=(count<=0) and 1 or ((count-1)*(delay+1)+1)
      local finish=frame+duration
      out.events[#out.events+1]={kind="battler_motion",motionKind="shake_in_place",
        battler=a[1],frame=frame,x=tonumber(a[2]) or 0,y=tonumber(a[3]) or 0,
        count=count,delay=delay,duration=duration,destroyFrame=finish}
      if finish > visualFinishFrame then visualFinishFrame = finish end
    elseif cmd.op == "createvisualtask" and (cmd.task == "AnimTask_ShakeMon" or cmd.task == "AnimTask_ShakeMon2") then
      local a=cmd.args or {}
      local count=a[4] or 0; local delay=a[5] or 0
      local duration=count*(delay+1)
      local finish=frame+duration
      out.events[#out.events+1]={kind="battler_motion",motionKind="shake",battler=a[1],frame=frame,x=a[2] or 0,y=a[3] or 0,count=count,delay=delay,duration=duration,destroyFrame=finish}
      if finish > visualFinishFrame then visualFinishFrame = finish end
    elseif cmd.op == "createvisualtask" and cmd.task == "AnimTask_ShakeTargetBasedOnMovePowerOrDmg" then
      -- FireRed derives amplitude from gAnimMovePower/gAnimMoveDmg and toggles
      -- the target every (delay+1) frames. The deterministic planner does not
      -- receive gAnimMoveDmg, so keep the exact cadence and use the smallest
      -- visible symmetric horizontal shake rather than inventing a damage value.
      local a=cmd.args or {}
      local delay=math.max(0,math.floor(tonumber(a[2]) or 0))
      local count=math.max(0,math.floor(tonumber(a[3]) or 0))
      local xEnabled=(a[4]==true or a[4]==1)
      local yEnabled=(a[5]==true or a[5]==1)
      local duration=math.max(1,count*(delay+1))
      local finish=frame+duration
      out.events[#out.events+1]={kind="battler_motion",motionKind="shake",battler="target",
        frame=frame,x=xEnabled and 2 or 0,y=yEnabled and 2 or 0,count=count,delay=delay,
        duration=duration,destroyFrame=finish}
      if finish > visualFinishFrame then visualFinishFrame=finish end
    elseif cmd.op == "createvisualtask" and cmd.task == "AnimTask_FlashAnimTagWithColor" then
      local a=resolveArgs(cmd.args or {},ctx)
      local delay=math.max(0,math.floor(tonumber(a[2]) or 0))
      local flashes=math.max(1,math.floor(tonumber(a[3]) or 1))
      local duration=math.max(1,flashes*2*(delay+1))
      -- Conversion's FireRed call is a palette hold at blend amount 12 before
      -- AnimTask_ConversionAlphaBlend starts six frames later. Preserve that
      -- exact pre-fade window instead of collapsing it into the generic blink.
      if a[1]==CONVERSION_TAG and tonumber(a[5])==CONVERSION_FLASH_BLEND then duration=math.max(duration,6) end
      local finish=frame+duration
      local eventKind=(a[1]==CONVERSION_TAG) and "conversion_grid_flash" or "sprite_tag_flash"
      out.events[#out.events+1]={kind=eventKind,frame=frame,tag=a[1],
        delay=delay,flashes=flashes,color=a[4] or {18,31,31},
        startAmount=a[5] or 16,endAmount=a[6] or 0,duration=duration,destroyFrame=finish,
        -- FireRed's palette engine alternates BG/OBJ palette halves. For the
        -- Conversion call (12 -> 12), the OBJ palette receives the yellow
        -- blend briefly, then the task immediately starts a 0 -> 0 restore.
        -- The script's six-frame delay therefore contains a short flash plus
        -- several frames of the restored white grid before BLDALPHA begins.
        flashFrames=(a[1]==CONVERSION_TAG) and 2 or nil}
      if finish>visualFinishFrame then visualFinishFrame=finish end
    elseif cmd.op == "createvisualtask" and cmd.task == "AnimTask_ConversionAlphaBlend" then
      -- FireRed AnimTask_ConversionAlphaBlend owns the lifetime of every
      -- gConversionSpriteTemplate. The cells do not expire independently.
      -- EVA steps 16 -> 0 once every four callbacks; on the following state
      -- the task writes gBattleAnimArgs[7] = 0xFFFF and all cells destroy.
      local duration=66
      local releaseFrame=frame+65
      local finish=frame+duration
      out.events[#out.events+1]={kind="conversion_alpha_blend",frame=frame,tag=CONVERSION_TAG,
        stepFrames=4,steps=16,duration=duration,destroyFrame=finish,releaseFrame=releaseFrame}
      for _,ev in ipairs(out.events) do
        if ev.kind=="sprite" and ev.motion and ev.motion.kind=="conversion_particle" then
          ev.destroyFrame=releaseFrame
          ev.motion.duration=math.max(1,releaseFrame-ev.frame)
        end
      end
      if finish>visualFinishFrame then visualFinishFrame=finish end
    elseif cmd.op == "createvisualtask" and cmd.task == "AnimTask_StartSinAnimTimer" then
      local a=cmd.args or {}
      local duration=math.max(1,math.floor(tonumber(a[1]) or 1))
      local finish=frame+duration
      runtimeState.sinAnimTimerStartFrame=frame
      runtimeState.sinAnimTimerStopFrame=finish
      out.events[#out.events+1]={kind="sin_anim_timer",frame=frame,duration=duration,destroyFrame=finish,phaseStep=3}
      if finish>visualFinishFrame then visualFinishFrame=finish end
    elseif cmd.op == "createvisualtask" and cmd.task == "AnimTask_RotateAuroraRingColors" then
      -- FireRed rotates rainbow-ring OBJ palette entries 1..8 every 3 task
      -- frames and destroys the task after the requested lifetime (130 here).
      local a=cmd.args or {}
      local duration=math.max(1,math.floor(tonumber(a[1]) or 130))
      runtimeState.auroraPaletteStartFrame=frame
      local finish=frame+duration
      -- The renderer derives the live palette phase directly from this start
      -- frame; no separate visual event is needed. Keep only the task lifetime
      -- so waitforvisualfinish matches FireRed.
      if finish>visualFinishFrame then visualFinishFrame=finish end
    elseif cmd.op == "createvisualtask" and cmd.task == "AnimTask_SetPsychicBackground" then
      -- FireRed removes this task from gAnimVisualTaskCount immediately, so it
      -- must not extend waitforvisualfinish. It only rotates BG palette 1..11
      -- every four task frames until gBattleAnimArgs[7] becomes 0xFFFF.
      out.events[#out.events+1]={
        kind="battle_bg_palette_rotate",frame=frame,background="psychic",
        period=4,entries=11
      }
    elseif cmd.op == "createvisualtask" and cmd.task == "AnimTask_Teleport" then
      -- FireRed battle_anim_psychic.c::AnimTask_Teleport. The attacker runs
      -- sAffineAnim_Teleport for 20 callbacks: native matrix X += 64 and
      -- Y -= 4 each frame. It then rises by 8 battler-local pixels per callback
      -- (8 callbacks on the player side, 4 on the opponent side), and the next
      -- callback hides the battler and destroys the task.
      local playerAttacker=(ctx.attacker.side=="player")
      local riseSteps=playerAttacker and 8 or 4
      local hideFrame=frame+20+riseSteps
      local finish=hideFrame+1
      out.events[#out.events+1]={kind="battler_affine_sequence",battler="attacker",
        frame=frame,sequence="teleport",affineFrames=20,riseSteps=riseSteps,
        risePerFrame=8,duration=finish-frame,destroyFrame=finish}
      out.events[#out.events+1]={kind="battler_visibility",battler="attacker",
        frame=hideFrame,visible=false}
      if finish>visualFinishFrame then visualFinishFrame=finish end
    elseif cmd.op == "createvisualtask" and cmd.task == "AnimTask_CreateSmallSolarBeamOrbs" then
      -- Native task creates 15 small orbs, first immediately and then every
      -- seven task frames. Each orb lives for 80 callbacks independently.
      local template=assert(move.templates.gSolarBeamSmallOrbSpriteTemplate,"missing Solar Beam small-orb template")
      for i=0,14 do
        local sf=frame+i*7
        local before=#out.events
        addSprite(out.events,sf,"gSolarBeamSmallOrbSpriteTemplate",template,{15,0,80,0},ctx,"target",1,alphaBlend,runtimeState)
        for j=before+1,#out.events do
          local finish=out.events[j].destroyFrame
          if finish and finish>visualFinishFrame then visualFinishFrame=finish end
        end
      end
      -- The task itself destroys immediately after spawning the 15th orb.
      local taskFinish=frame+14*7
      if taskFinish>visualFinishFrame then visualFinishFrame=taskFinish end
    elseif cmd.op == "createvisualtask" and cmd.task == "AnimTask_NightShadeClone" then
      -- FireRed battle_anim_ghost.c::AnimTask_NightShadeClone. The attacker OBJ
      -- begins at 0.5 affine scale (2x visual size), fades from EVA 0 to 9 in
      -- 3-frame steps, holds for arg0 frames, then returns toward 1x in 8-unit
      -- affine-scale steps before the task resets the battler OBJ. monbg keeps
      -- the normal-size battler copy visible behind this translucent clone.
      local a=cmd.args or {}
      local hold=math.max(0,math.floor(tonumber(a[1]) or 0))
      local fadeFrames=27
      local shrinkFrames=16
      local duration=fadeFrames+hold+shrinkFrames
      local finish=frame+duration
      out.events[#out.events+1]={kind="night_shade_clone",frame=frame,battler="attacker",
        fadeFrames=fadeFrames,holdFrames=hold,shrinkFrames=shrinkFrames,
        duration=duration,destroyFrame=finish}
      if finish>visualFinishFrame then visualFinishFrame=finish end
    elseif cmd.op == "createvisualtask" and cmd.task == "AnimTask_BlendMonInAndOut" then
      -- FireRed battle_anim_mons.c::AnimTask_BlendMonInAndOut.
      -- Args: battler, blend color, peak coefficient, step delay, cycle count.
      -- The task does not call its step on creation. With Super Fang's
      -- (peak=12, delay=4, cycles=1), amount 1 first appears four frames later,
      -- reaches 12 on frame 48, then returns to 0 and destroys on frame 96.
      local a=cmd.args or {}
      local target=a[1] or "attacker"
      local color=a[2] or "black"
      local peak=math.max(0,math.min(16,math.floor(tonumber(a[3]) or 0)))
      local delay=math.max(1,math.floor(tonumber(a[4]) or 1))
      local cycles=math.max(1,math.floor(tonumber(a[5]) or 1))
      local paletteSteps={}
      local cursor=0
      local function hold(amount,frames)
        if frames<=0 then return end
        paletteSteps[#paletteSteps+1]={start=cursor,finish=cursor+frames,amount=amount,color=color}
        cursor=cursor+frames
      end
      for _=1,cycles do
        hold(0,delay)
        for amount=1,peak do hold(amount,delay) end
        for amount=peak-1,1,-1 do hold(amount,delay) end
      end
      local duration=math.max(1,cursor)
      local finish=frame+duration
      out.events[#out.events+1]={kind="palette_blend",frame=frame,target=target,
        color=color,startAmount=0,endAmount=0,paletteSteps=paletteSteps,
        duration=duration,destroyFrame=finish,effectEndFrame=finish}
      if finish>visualFinishFrame then visualFinishFrame=finish end
    elseif cmd.op == "createvisualtask" and cmd.task == "AnimTask_ShrinkTargetCopy" then
      -- FireRed battle_anim_effects_1.c::AnimTask_ShrinkTargetCopy. monbg_static
      -- preserves the normal target image while the live OBJ copy shifts 12 px
      -- toward its own side and shrinks from native affine 0x100 to 0x280 over
      -- 24 callbacks. setarg 7,0xFFFF later releases/restores the OBJ.
      local a=cmd.args or {}
      local xStep=tonumber(a[1]) or 128
      local steps=math.max(1,math.floor(tonumber(a[2]) or 24))
      local release=(runtimeState and runtimeState.arg7ffffFrame) or (frame+steps+1)
      local finish=math.max(frame+steps,release)+3
      out.events[#out.events+1]={kind="battler_mimic_copy",battler="target",frame=frame,
        xStep=xStep,steps=steps,releaseFrame=release,duration=finish-frame,destroyFrame=finish}
      if finish>visualFinishFrame then visualFinishFrame=finish end
    elseif cmd.op == "createvisualtask" and cmd.task == "AnimTask_BlendColorCycle" then
      local a=cmd.args or {}
      local target=a[1] or "target"
      local delay=math.max(0,math.floor(tonumber(a[2]) or 0))
      local blends=math.max(1,math.floor(tonumber(a[3]) or 1))
      local initial=math.max(0,math.min(16,tonumber(a[4]) or 0))
      local peak=math.max(0,math.min(16,tonumber(a[5]) or 0))
      local color=a[6] or {31,18,31}
      -- FireRed normal palette fades advance blend Y by 2, and the palette
      -- engine alternates BG/OBJ palette processing.  Battler palettes are OBJ
      -- palettes, so a one-way fade takes two update ticks per blend-Y step
      -- (including the initial amount).  Preserve that cadence instead of
      -- treating every blend amount as a single frame.
      local ySteps=math.ceil(math.abs(peak-initial)/2)+1
      local oneWay=math.max(1,ySteps*2*(delay+1))
      local duration=math.max(1,oneWay*blends)
      local finish=frame+duration
      out.events[#out.events+1]={
        kind="palette_blend_cycle",frame=frame,target=target,color=color,
        initialAmount=initial,peakAmount=peak,delay=delay,blends=blends,
        oneWay=oneWay,duration=duration,destroyFrame=finish
      }
      if finish>visualFinishFrame then visualFinishFrame=finish end
    elseif cmd.op == "createvisualtask" and cmd.task == "AnimTask_Flash" then
      -- FireRed battle_anim_utility_funcs.c::AnimTask_Flash. Creation
      -- immediately writes battler OBJ palettes to black and the battle BG
      -- palette to white. Seven setup callbacks follow; the first restore
      -- decrement happens two callbacks later, then one blend-Y step every
      -- two callbacks until amount 0, followed by the destroy callback.
      local steps={}
      local cursor=0
      steps[#steps+1]={start=0,finish=9,amount=16}
      cursor=9
      for amount=15,1,-1 do
        steps[#steps+1]={start=cursor,finish=cursor+2,amount=amount}
        cursor=cursor+2
      end
      local duration=41
      local finish=frame+duration
      out.events[#out.events+1]={kind="palette_blend",frame=frame,target="both",
        color="black",startAmount=16,endAmount=0,paletteSteps=steps,
        duration=duration,destroyFrame=finish,effectEndFrame=finish}
      out.events[#out.events+1]={kind="palette_blend",frame=frame,target="bg",
        color="white",startAmount=16,endAmount=0,paletteSteps=steps,
        duration=duration,destroyFrame=finish,effectEndFrame=finish}
      if finish>visualFinishFrame then visualFinishFrame=finish end
    elseif cmd.op == "createvisualtask" and cmd.task == "AnimTask_HazeScrollingFog" then
      -- FireRed AnimTask_HazeScrollingFog: 19 four-frame fade steps to EVA 9,
      -- 81-frame hold, then nine four-frame fade steps back to zero. BG1 also
      -- scrolls left one native pixel on every callback.
      local amounts={0,1,2,2,2,2,3,4,4,4,5,6,6,6,6,7,8,8,8,9}
      local fadeIn=(#amounts-1)*4
      local hold=81
      local fadeOut=9*4
      local duration=fadeIn+hold+fadeOut+1
      local finish=frame+duration
      out.events[#out.events+1]={kind="haze_scrolling_fog",frame=frame,duration=duration,
        destroyFrame=finish,amounts=amounts,fadeIn=fadeIn,hold=hold,fadeOut=fadeOut}
      if finish>visualFinishFrame then visualFinishFrame=finish end
    elseif cmd.op == "createvisualtask" and cmd.task == "AnimTask_BlendBattleAnimPal" then
      local a=cmd.args or {}
      local target=a[1] or "target"
      local delay=math.max(0,a[2] or 0)
      local startAmount=math.max(0,math.min(16,a[3] or 0))
      local endAmount=math.max(0,math.min(16,a[4] or 0))
      local color=a[5] or "black"
      local steps=math.abs(endAmount-startAmount)
      local duration=math.max(1,steps*(delay+1)+1)
      local finish=frame+duration
      local ev={
        kind="palette_blend",frame=frame,target=target,color=color,
        startAmount=startAmount,endAmount=endAmount,duration=duration,
        destroyFrame=finish
      }
      if move.id=="GLARE" and (target=="bg" or target=="background") then
        -- BlendBattleAnimPal leaves the resulting palette in place after the
        -- task ends. The first Glare task drives BG to black and that black
        -- remains while Scary Face is shown; the later 16->0 task replaces it.
        for i=#out.events,1,-1 do
          local prior=out.events[i]
          if prior.kind=="palette_blend" and (prior.target=="bg" or prior.target=="background")
              and prior.effectEndFrame==math.huge then
            prior.effectEndFrame=frame
            break
          end
        end
        if endAmount>0 then ev.effectEndFrame=math.huge end
      end
      out.events[#out.events+1]=ev
      if finish>visualFinishFrame then visualFinishFrame=finish end
    elseif cmd.op == "setarg" then
      if tonumber(cmd.index)==7 then
        runtimeState.arg7=tonumber(cmd.value)
        if tonumber(cmd.value)==0xFFFF then
          runtimeState.arg7ffffFrame=frame
          for _,e in ipairs(out.events) do
            if e.kind=="sprite" and e.motion and e.motion.kind=="aurora_beam_ring" and not e.motion.transformFrame then
              -- FireRed's script changes gBattleAnimArgs[7] immediately, but
              -- sprites already in flight only observe that change on their
              -- next callback tick. Preserve that one-frame callback boundary.
              e.motion.transformFrame=frame+1
            end
          end
          for i=#out.events,1,-1 do
            local e=out.events[i]
            if e.kind=="battle_bg_palette_rotate" and not e.stopFrame then
              e.stopFrame=frame
              break
            end
          end
        end
      end
    elseif cmd.op == "waitforvisualfinish" then
      -- FireRed Cmd_waitforvisualfinish stalls the script while
      -- gAnimVisualTaskCount != 0. Advance this planner clock to the point
      -- where every visual launched before this command has completed.
      if visualFinishFrame > frame then frame = visualFinishFrame end
    elseif cmd.op == "delay" then
      -- FireRed Cmd_delay does not resume command execution on the exact
      -- countdown-expiry update.  It first spends `frames` callbacks
      -- decrementing sAnimFramesToWait, then one callback switching
      -- gAnimScriptCallback back to RunAnimScriptCommand, and only on the
      -- following animation update does the next command execute.  Therefore
      -- the observable command-to-command spacing is frames + 2 updates.
      -- This distinction is especially visible for delay 1/2 streams such as
      -- Aurora Beam, Flamethrower and Rock Slide.
      frame = frame + math.max(0, cmd.frames or 0) + 2
    elseif cmd.op == "end" then
      out.events[#out.events+1] = {kind="script_end", frame=frame}
    end
  end
  local maxFrame = frame
  for _,e in ipairs(out.events) do
    if e.destroyFrame and e.destroyFrame > maxFrame then maxFrame = e.destroyFrame end
    if e.endFrame and e.endFrame > maxFrame then maxFrame = e.endFrame end
  end
  for _,e in ipairs(out.events) do
    if e.kind=="palette_blend" and not e.effectEndFrame then e.effectEndFrame=maxFrame end
  end
  out.durationFrames = maxFrame
  out.durationSeconds = maxFrame / M.GBA_FPS
  return out
end

-- Extract an OBJ frame from decoded 8x8 tiles using GBA 1D tile order.
function M.decodeObjFrame(decodedTiles, tileOffset, width, height)
  width,height=width or 32,height or 32
  assert(width%8==0 and height%8==0, "OBJ dimensions must be multiples of 8")
  local px,tilesPerRow={},width/8
  for y=0,height-1 do
    local row={}; local tileY=math.floor(y/8); local inY=y%8
    for x=0,width-1 do
      local tileX=math.floor(x/8); local inX=x%8
      local tileIndex=tileOffset+tileY*tilesPerRow+tileX+1
      local tile=assert(decodedTiles[tileIndex], "sprite frame exceeds extracted tile sheet")
      row[x+1]=tile[inY*8+inX+1]
    end
    px[y+1]=row
  end
  return px
end

-- Compatibility alias for the verified Ember baseline.
function M.decode32x32Frame(decodedTiles,tileOffset)
  return M.decodeObjFrame(decodedTiles,tileOffset,32,32)
end


return M
