-- Shared Gen1Recomp battle integration for every registered FireRed move.
local M = {}
M.__index = M

local function lerp(a,b,t) return a + (b-a)*t end
local function clamp(v,a,b) if v<a then return a elseif v>b then return b else return v end end

-- Convert FireRed/GBA BLDALPHA coefficients to Love2D's normal alpha blend.
-- GBA OBJ blend is: out = src * EVA/16 + dst * EVB/16.
-- Love2D's alpha blend is: out = (src * rgbGain) * A + dst * (1-A).
-- Choosing A = 1-EVB/16 and rgbGain = (EVA/16)/A makes the equations
-- identical for the coefficient pairs used by FireRed move OBJ sprites.
local function gbaObjBlendParams(alphaBlend, opacity)
  if not alphaBlend then return 1, clamp(opacity or 1,0,1) end
  local eva=clamp(tonumber(alphaBlend.eva) or 16,0,16)/16
  local evb=clamp(tonumber(alphaBlend.evb) or 0,0,16)/16
  local opacity=clamp(opacity or 1,0,1)
  local a=1-evb
  if a<=0 then
    return 1, eva*opacity
  end

  -- GBA OBJ alpha is src*EVA + dst*EVB.  Mapping that exactly onto Love's
  -- normal alpha blend requires rgbGain=EVA/(1-EVB).  Common FireRed 12/8
  -- therefore needs 1.5x source RGB, but the host's standard battle target
  -- clamps setColor RGB to 1.0.  The old path consequently degraded 12/8 to
  -- roughly 0.5*src + 0.5*dst, which is visibly too transparent in staged /
  -- voxel battles.  Use the exact mapping whenever its gain fits in-range;
  -- otherwise preserve FireRed's source coefficient (the important visual
  -- term for attack sprites) and let normal alpha supply the closest bounded
  -- destination term.  8/8 remains exact; 12/8 becomes 0.75*src+0.25*dst
  -- instead of the broken 0.5*src+0.5*dst approximation.
  local gain=eva/a
  if gain<=1 then
    return gain, a*opacity
  end
  return 1, eva*opacity
end
local function shallowCopy(t)
  local o = {}
  for k,v in pairs(t or {}) do o[k]=v end
  return o
end

local HIT_SPLAT_SCALE={ [0]=1.0, [1]=0xD8/0x100, [2]=0xB0/0x100, [3]=0x80/0x100 }
local function hitSplatScale(variant)
  return HIT_SPLAT_SCALE[math.floor(tonumber(variant) or 0)] or 1.0
end

-- FireRed gAffineAnims_Droplet: start at 1x1, squash X / stretch Y by 0x10
-- per frame for six frames, then reverse for six frames, looping.
local function waterDropletScaleAtAge(age)
  local phase=math.max(0,math.floor(age or 0)) % 12
  local n=(phase < 6) and (phase+1) or (11-phase)
  return (0x100-0x10*n)/0x100, (0x100+0x10*n)/0x100
end

-- FireRed sAffineAnim_ConfuseRayBallBounce pulses scale by +/-0x1E over two
-- five-frame halves while adding +10 rotation units every frame.
local function confuseRayAffineAtAge(age)
  age=math.max(0,math.floor(age or 0))
  local phase=age % 10
  local n=(phase < 5) and (phase+1) or (9-phase)
  local scale=(0x100+0x1E*n)/0x100
  local angle=((age+1)*10 % 256) * math.pi*2/256
  return scale,angle
end


-- FireRed's missile/arrow callbacks are authored around the GBA battler layout.
-- Gen1Recomp places the opponent higher in its 144 px battle canvas, so a
-- native negative arc can put a rotated needle partly above y=0 even though
-- its launch and landing points are both valid. Keep the callback's endpoints
-- and timing intact and compress only the sinusoidal excursion when necessary
-- to keep the complete rotated source sprite inside the host viewport.
local function missileArcSafeAmplitude(motion, drawYOffset, displayScale, width, height)
  local amp=tonumber(motion and motion.arcAmplitude) or 0
  if amp>=0 then return amp end
  local d=math.max(1,math.floor(tonumber(motion and motion.duration) or 1))
  if d<=1 then return amp end
  local ds=tonumber(displayScale) or 1
  local w=(tonumber(width) or 16)*ds
  local h=(tonumber(height) or 16)*ds
  -- A rotated rectangle never extends farther than half its diagonal. One
  -- extra pixel avoids texture filtering touching the viewport edge.
  local topRadius=0.5*math.sqrt(w*w+h*h)+1
  local safe=amp
  for frame=1,d-1 do
    local t=frame/d
    local wave=math.sin(t*math.pi)
    if wave>0.000001 then
      local baseY=lerp(motion.startY or 0,motion.endY or 0,t)+(drawYOffset or 0)+16
      local minAmp=(topRadius-baseY)/wave
      if minAmp>safe then safe=minAmp end
    end
  end
  -- Never invert the FireRed arc; flatten it at most.
  return math.min(0,safe)
end

-- Mirror UpdateConfuseRayBallBlend's visible EVA. Internal values 0x100..0x10C
-- are its fully-transparent hold state; the BLDALPHA register remains 0/16.
local function confuseRayAlphaAtAge(age)
  local amount=16
  local rising=false
  local steps=math.max(0,math.floor(age or 0))
  for _=1,steps do
    if amount > 0xFF then
      amount=amount+1
      if amount==0x10D then amount=0 end
    else
      amount=amount+(rising and 1 or -1)
      if amount==0 or amount==16 then rising=not rising end
      if amount==0 then amount=0x100 end
    end
  end
  if amount>16 then return 0 end
  return clamp(amount/16,0,1)
end

local function imageDimensions(sprite,scale)
  if not sprite then return nil,nil end
  scale=scale or 1
  if type(sprite.getDimensions)=="function" then
    local ok,w,h=pcall(sprite.getDimensions,sprite)
    if ok and tonumber(w) and tonumber(h) then return w*scale,h*scale end
  elseif type(sprite.getWidth)=="function" and type(sprite.getHeight)=="function" then
    local okw,w=pcall(sprite.getWidth,sprite); local okh,h=pcall(sprite.getHeight,sprite)
    if okw and okh and tonumber(w) and tonumber(h) then return w*scale,h*scale end
  end
  return nil,nil
end

local G3PicSize = nil
local G3PicCoords = nil
local function fireRedBattlerPicHeight(battler, anchor)
  -- Exact FireRed gMonFrontPicCoords/gMonBackPicCoords size metadata exposed
  -- by Gen1Recomp's native FireRed animation port.
  if G3PicSize == nil then
    local ok,m=pcall(require,"src.core.game3.battle.anim_port.g3_pic_size")
    G3PicSize=ok and m or false
  end
  if not G3PicSize then return nil end
  local species=battler and ((battler.def and (battler.def.dex or battler.def.index))
    or battler.species or (battler.mon and battler.mon.species))
  if type(species)=="table" then species=species.dex or species.id or species.num or species.index end
  species=tonumber(species)
  if not species then return nil end
  local playerSide=(battler and battler.isPlayer) or (anchor and anchor.side=="player")
  local tbl=playerSide and G3PicSize.back or G3PicSize.front
  local packed=tbl and tbl[species]
  if not packed then return nil end
  return packed % 256
end

local function fireRedBattlerPicWidth(battler, anchor)
  if G3PicSize == nil then
    local ok,m=pcall(require,"src.core.game3.battle.anim_port.g3_pic_size")
    G3PicSize=ok and m or false
  end
  if not G3PicSize then return nil end
  local species=battler and ((battler.def and (battler.def.dex or battler.def.index))
    or battler.species or (battler.mon and battler.mon.species))
  if type(species)=="table" then species=species.dex or species.id or species.num or species.index end
  species=tonumber(species)
  if not species then return nil end
  local playerSide=(battler and battler.isPlayer) or (anchor and anchor.side=="player")
  local tbl=playerSide and G3PicSize.back or G3PicSize.front
  local packed=tbl and tbl[species]
  if not packed then return nil end
  return math.floor(packed / 256) % 256
end

local function fireRedBattlerRawY(battler, anchor)
  -- Convert the host's battler picture anchor back to FireRed BATTLER_COORD_Y.
  -- FireRed Y_PIC_OFFSET is species-adjusted from the fixed slot Y using
  -- gMonFront/BackPicCoords and (for opponents) gEnemyMonElevation.
  if G3PicCoords == nil then
    local ok,m=pcall(require,"src.core.game3.battle.pic_coords")
    G3PicCoords=ok and m or false
  end
  local hostPicY=(anchor and (anchor.yPicOffset or anchor.y)) or 0
  if not G3PicCoords then return hostPicY end
  local species=battler and ((battler.def and (battler.def.dex or battler.def.index))
    or battler.species or (battler.mon and battler.mon.species))
  if type(species)=="table" then species=species.dex or species.id or species.num or species.index end
  species=tonumber(species)
  if not species then return hostPicY end
  local playerSide=(battler and battler.isPlayer) or (anchor and anchor.side=="player")
  if playerSide then
    local back=(G3PicCoords.back and G3PicCoords.back[species]) or 0
    -- FireRed: min(104, 80 + backOffset + 8), so relative to raw Y=80 the
    -- visible picture-anchor delta is capped at 24 pixels.
    return hostPicY-math.min(24,back+8)
  end
  local front=(G3PicCoords.front and G3PicCoords.front[species]) or 0
  local elev=(G3PicCoords.elev and G3PicCoords.elev[species]) or 0
  return hostPicY-(front-elev)
end

local function fireRedBattlerElevation(battler, anchor)
  local playerSide=(battler and battler.isPlayer) or (anchor and anchor.side=="player")
  if playerSide then return 0 end
  if G3PicCoords == nil then
    local ok,m=pcall(require,"src.core.game3.battle.pic_coords")
    G3PicCoords=ok and m or false
  end
  if not G3PicCoords then return 0 end
  local species=battler and ((battler.def and (battler.def.dex or battler.def.index))
    or battler.species or (battler.mon and battler.mon.species))
  if type(species)=="table" then species=species.dex or species.id or species.num or species.index end
  species=tonumber(species)
  if not species then return 0 end
  return (G3PicCoords.elev and G3PicCoords.elev[species]) or 0
end

local function battlerSpriteDimensions(battle,battler)
  local w,h
  -- Resolve through BattleState:picImage(). battler.sprite is normally an image
  -- id/path rather than the Love2D Image itself, so probing battler.sprite
  -- directly silently fell back to 32x32 and made the previous live-anchor
  -- correction a no-op for ordinary front sprites.
  local function resolveImage(ref)
    if not ref then return nil end
    if battle and type(battle.picImage)=="function" then
      local ok,img=pcall(battle.picImage,battle,ref)
      if ok and img then return img end
    end
    return ref
  end

  -- Gen1Recomp displays the player's 32x32 back pic at 2x.
  if battler and battler.isPlayer and battle then
    w,h=imageDimensions(resolveImage(battle.playerBackPic),2)
  end
  if not w then w,h=imageDimensions(resolveImage(battler and battler.sprite),1) end

  -- Classic slots are a safer semantic fallback than 32x32: enemy front art
  -- occupies a 7x7 (56 px) slot and the player back sprite is 64 px tall after
  -- the host's 2x presentation.
  if not w then
    if battler and battler.isPlayer then w,h=64,64 else w,h=56,56 end
  end
  return math.max(2,math.floor(w)),math.max(4,math.floor(h))
end

local function battlerLocalEffectY(battle,battler,anchor)
  -- FireRed distinguishes projectile/trajectory coordinates from battler-local
  -- effect coordinates.  Several callbacks intentionally bias local effects
  -- toward the upper body with Y_PIC_OFFSET - HEIGHT/4.  Gen1Recomp's visible
  -- battle area is vertically compressed relative to FireRed, so using the
  -- plain sprite centre for local overlays makes powders, splashes, hit flares,
  -- etc. read too low even while projectile paths are correct.  Derive one
  -- shared upper-body anchor from the actual rendered battler bounds instead
  -- of adding move-specific Y nudges.
  local _,h=battlerSpriteDimensions(battle,battler)
  local bottom=((battler and battler.isPlayer) or (anchor and anchor.side=="player")) and 96 or 56
  local top=bottom-h
  return top+(h/4)
end

-- Cached plans are immutable. FireRed callbacks that call Random() (currently
-- AnimFistOrFootRandomPos) are resolved into a per-use clone here so every move
-- execution gets a fresh point without contaminating the startup plan cache.
local function instantiatePlan(plan, attackerBattler, targetBattler, attackerAnchor, targetAnchor, battle)
  local out=shallowCopy(plan)
  out.events={}
  local groups={}
  for i,e in ipairs(plan.events or {}) do
    local ne=shallowCopy(e)
    ne.oam=e.oam and shallowCopy(e.oam) or nil
    ne.motion=e.motion and shallowCopy(e.motion) or nil
    out.events[i]=ne
    local m=ne.motion
    if m and m.kind=="question_mark" and m.liveQuestionMarkBattler then
      local battler=attackerBattler
      local anchor=attackerAnchor
      local w,h=battlerSpriteDimensions(battle,battler)
      local baseX=(anchor and (anchor.x2 or anchor.x)) or m.startX or 0
      local baseY=(anchor and (anchor.yPicOffset or anchor.y)) or m.startY or 0
      local xoff=math.floor((w/2) * 0.50)
      if not ((battler and battler.isPlayer) or (anchor and anchor.side=="player")) then xoff=-xoff end
      local xx=baseX+xoff
      local yy=math.max(16,baseY-math.floor(h/2))
      m.startX,m.endX,m.startY,m.endY=xx,xx,yy,yy
      ne.x,ne.y=xx,yy
    end
    if ne.liveRawYBattler and ne.y~=nil then
      local useTarget=ne.liveRawYBattler=="target"
      local battler=useTarget and targetBattler or attackerBattler
      local anchor=useTarget and targetAnchor or attackerAnchor
      local plannedRaw=(anchor and (anchor.yRaw or anchor.y)) or 0
      ne.y=ne.y+(fireRedBattlerRawY(battler,anchor)-plannedRaw)
    end
    if m and m.liveLocalYBattler then
      local useTarget=m.liveLocalYBattler=="target"
      local battler=useTarget and targetBattler or attackerBattler
      local anchor=useTarget and targetAnchor or attackerAnchor
      local plannedY=(anchor and (anchor.yPicOffset or anchor.y)) or 0
      local liveY=battlerLocalEffectY(battle,battler,anchor)
      local dy=liveY-plannedY
      if dy~=0 then
        for _,key in ipairs({"startY","endY","targetY","midY"}) do
          if m[key]~=nil then m[key]=m[key]+dy end
        end
      end
    end
    if m and m.liveRawYBattler then
      local useTarget=m.liveRawYBattler=="target"
      local battler=useTarget and targetBattler or attackerBattler
      local anchor=useTarget and targetAnchor or attackerAnchor
      local plannedRaw=(anchor and (anchor.yRaw or anchor.y)) or 0
      local liveRaw=fireRedBattlerRawY(battler,anchor)
      local dy=liveRaw-plannedRaw
      if dy~=0 then
        local keys=m.liveRawYKeys or {"startY","endY","targetY","midY"}
        for _,key in ipairs(keys) do if m[key]~=nil then m[key]=m[key]+dy end end
      end
    end
    if m and m.liveElevationBattler then
      local useTarget=m.liveElevationBattler=="target"
      local battler=useTarget and targetBattler or attackerBattler
      local anchor=useTarget and targetAnchor or attackerAnchor
      local elev=fireRedBattlerElevation(battler,anchor)
      if elev~=0 then
        for _,key in ipairs({"startY","endY","targetY","midY"}) do
          if m[key]~=nil then m[key]=m[key]-elev end
        end
      end
    end
    if m and m.liveTargetHeightQuarter then
      -- FireRed BarrageBall uses GetBattlerSpriteCoordAttr(..., HEIGHT), which
      -- reads the species' exact FireRed front/back pic-coordinate metadata.
      local h=fireRedBattlerPicHeight(targetBattler,targetAnchor)
      if not h then
        -- Defensive fallback only; normal Gen1Recomp builds expose g3_pic_size.
        local _,renderedH=battlerSpriteDimensions(battle,targetBattler)
        h=renderedH
      end
      if m.endY~=nil then m.endY=m.endY+math.floor(h/4) end
    end
    if m and m.liveTargetEndpointY then
      -- Traveling projectiles that visibly hand off to target-local hit effects
      -- should meet the same live upper-body anchor. Rebase only the endpoint;
      -- do not move the attacker-side launch point or continuous beam geometry.
      local plannedY=(targetAnchor and (targetAnchor.yPicOffset or targetAnchor.y)) or 0
      local liveY=battlerLocalEffectY(battle,targetBattler,targetAnchor)
      local dy=liveY-plannedY
      if dy~=0 and m.endY~=nil then m.endY=m.endY+dy end
    end
    if m and m.randomDrift then
      -- FireRed AnimSmallDriftingBubbles: randData=(Random()&0xFF)|256;
      -- odd randData moves left, even moves right. Vertical speed is the
      -- folded low 9 bits of a second Random() call, giving 0..256.
      local rawX=math.random(0,255)
      local speedX=256+rawX
      if rawX % 2 == 1 then speedX=-speedX end
      local rawY=math.random(0,511)
      if rawY>255 then rawY=256-rawY end
      m.driftSpeedX=speedX
      m.driftSpeedY=rawY
    end
    if m and m.liveNextToHeadBattler then
      local useTarget=m.liveNextToHeadBattler=="target"
      local battler=useTarget and targetBattler or attackerBattler
      local anchor=useTarget and targetAnchor or attackerAnchor
      local w=fireRedBattlerPicWidth(battler,anchor)
      local h=fireRedBattlerPicHeight(battler,anchor)
      if not w or not h then
        w,h=battlerSpriteDimensions(battle,battler)
      end
      local isPlayer=(battler and battler.isPlayer==true) or (anchor and anchor.side=="player")
      local cx=(anchor and (anchor.x2 or anchor.x)) or 0
      local cy=(anchor and (anchor.yPicOffset or anchor.y)) or 0
      -- GetBattlerSpriteCoordAttr lives in FireRed's 240 px battle geometry.
      -- Our battler centres are already projected into the 160 px host field,
      -- so scale the pic-coordinate half-extents and the native 8 px head gap
      -- before adding them to that centre. Otherwise a 64 px back sprite can
      -- push this anchor almost exactly to x=80 (field centre).
      local gs=(self and self.battleSpace and self.battleSpace.SCREEN_SCALE) or (160/240)
      local headDx=(w/2 + 8)*gs
      local headDy=(h/4)*gs
      local x=isPlayer and (cx + headDx) or (cx - headDx)
      local y=cy - headDy
      m.startX,m.endX,m.startY,m.endY=x,x,y,y
    end
    if m and m.randomGroup then
      local pos=groups[m.randomGroup]
      if not pos then
        local useTarget=m.randomBattler~="attacker"
        local battler=useTarget and targetBattler or attackerBattler
        local anchor=useTarget and targetAnchor or attackerAnchor
        local w,h=battlerSpriteDimensions(battle,battler)
        local xMod=math.max(1,math.floor(w/2))
        local yMod=math.max(1,math.floor(h/4))
        local dx=math.random(0,xMod-1)
        local dy=math.random(0,yMod-1)
        if math.random(0,1)==1 then dx=-dx end
        if math.random(0,1)==1 then dy=-dy end
        local isPlayer=(battler and battler.isPlayer==true) or (anchor and anchor.side=="player")
        if isPlayer then dy=dy-16 end
        pos={x=(m.startX or 0)+dx,y=(m.startY or 0)+dy}
        groups[m.randomGroup]=pos
      end
      m.startX,m.endX,m.startY,m.endY=pos.x,pos.x,pos.y,pos.y
    end
  end
  return out
end

local function classicAnchors(userIsPlayer)
  local player = {x=40, y=64, yRaw=64, x2=40, yPicOffset=64, side="player", position="player_left"}
  local enemy  = {x=120,y=40, yRaw=40, x2=120,yPicOffset=40, side="opponent",position="opponent_left"}
  if userIsPlayer then return player,enemy end
  return enemy,player
end

local function soundPan(symbol, attacker)
  local playerPan, foePan = -64, 63
  local function one(v)
    if v == "attacker" then return attacker.side == "player" and playerPan or foePan end
    if v == "target" then return attacker.side == "player" and foePan or playerPan end
    return tonumber(v) or 0
  end
  if type(symbol)=="table" then
    local a,b=one(symbol.from),one(symbol.to)
    return math.floor(a+(b-a)*(symbol.t or 0)+0.5)
  end
  return one(symbol)
end

local function rowAtFront(b,row)
  return b and type(b.queue)=="table" and b.queue[1] == row
end

local function queueContainsRow(b,row)
  if not (b and type(b.queue)=="table" and row) then return false end
  for _,candidate in ipairs(b.queue) do
    if candidate==row then return true end
  end
  return false
end



local function isClassicBattle(b)
  if not b then return false,"no battle" end
  if type(b.queue) ~= "table" then return false,"battle queue unavailable" end
  if b.isWideBattleLayout and b:isWideBattleLayout() then return false,"wide battle layout" end
  return true
end

function M.new(opts)
  local self = setmetatable({}, M)
  self.mod = opts.mod
  self.voxelCompat = opts.voxelCompat
  self.voxelCategories = opts.voxelCategories
  self.visual = assert(opts.visual)
  self.registry = assert(opts.registry)
  self.visualAssets = assert(opts.visualAssets)
  self.precache = opts.precache
  self.playSound = assert(opts.playSound)
  self.playMoveCry = opts.playMoveCry
  self.setQuietBgm = opts.setQuietBgm or function() end
  self.log = opts.log
  self.paletteRenderer = assert(opts.paletteRenderer)
  self.metalShineAssets = assert(opts.metalShineAssets)
  self.smokescreenImpactAssets = opts.smokescreenImpactAssets
  self.battleBgAssets = assert(opts.battleBgAssets)
  self.backgroundsEnabled = opts.backgroundsEnabled or function() return true end
  self.holdBattlerHidden = opts.holdBattlerHidden
  self.substituteDollOverrideBattles = setmetatable({}, {__mode="k"})
  self.substituteHiddenBattlers = setmetatable({}, {__mode="k"})
  self.transformVisualLatches = setmetatable({}, {__mode="k"})
  self.pending = nil
  self.chargePending = nil
  self.active = nil
  self.nativeHitPending = nil
  self.animTurnSequence = nil
  self.serial = 0
  self.stats = {
    triggered=0, replaced=0, failed=0, cancelled=0, stalePendingCleared=0,
    reentrant=0, completed=0, chargeTriggered=0, chargeCompleted=0,
    nativeHitSuppressed=0, nativeHitClaimedByFeedback=0, playerToEnemy=0, enemyToPlayer=0,
  }
  self.lastFailureReason = nil
  return self
end



function M:applySubstituteSwapHide(a)
  if not a or not a.battle or not a.attackerBattler then return end
  local b=a.attackerBattler
  local pf=a.battle:picFxFor(b)
  if not pf then return end
  if not a.substituteSwapHide then
    a.substituteSwapHide={
      battler=b,
      pf=pf,
      previousHidden=pf.hidden
    }
  end
  if self.substituteHiddenBattlers[b]==nil then
    self.substituteHiddenBattlers[b]={
      pf=pf,
      previousHidden=pf.hidden
    }
  end
  pf.hidden=true
end

function M:installFireRedSubstituteDoll(battle)
  if not battle or self.substituteDollOverrideBattles[battle] then return true end
  if type(battle.drawSubstituteDoll)~="function" then return false end

  local original=battle.drawSubstituteDoll
  local visualAssets=self.visualAssets
  local voxelCompat=self.voxelCompat

  battle.drawSubstituteDoll=function(host,battler,dx,dy)
    if not battler then
      return original(host,battler,dx,dy)
    end

    local images=visualAssets and visualAssets.customImages
    local staged=voxelCompat and voxelCompat:state(host) or nil
    -- Battle Art calls the host-owned Substitute draw through a presentation
    -- wrapper whose `host` table is not always the exact live BattleState.
    -- Its public BattleStage API accepts nil to return the currently staged
    -- battle, so fall back to that read-only current-stage query. Potato
    -- continues to resolve through the exact host and is unchanged.
    if not staged and voxelCompat then staged=voxelCompat:state(nil) end
    local stagedMirror=staged and voxelCompat:mirrorX(staged,battler) or false

    -- FireRed uses the back doll for the player and the front doll for the
    -- enemy. Potato Voxel still needs that same player back doll; only mirror
    -- the back doll horizontally so it faces the staged opponent.
    local useFront=not battler.isPlayer
    local img=images and images[useFront and "substitute_front" or "substitute_back"]
    if not img then
      return original(host,battler,dx,dy)
    end

    dx,dy=dx or 0,dy or 0
    local cx=battler.isPlayer and 40 or 120
    local cy=battler.isPlayer and 80 or 40
    -- Keep the original host-owned persistent Substitute path (important for
    -- Battle Art), but align it with the voxel-local drop/bounce landing.
    -- The active bounce uses the same near-centre authored anchor;
    -- apply the same visible position here only while a voxel stage is active.
    if staged then
      -- Match each voxel provider's drop/bounce landing exactly. Potato keeps
      -- its confirmed-good 16px centre shift. Battle Art uses the renderer's
      -- actual authored battler anchors rather than raw screen centre.
      if staged.provider=="battle_art" then
        cx=battler.isPlayer and 96 or 64
      else
        cx=battler.isPlayer and 24 or 136
      end
    end
    local w,h=img:getDimensions()

    love.graphics.setColor(1,1,1,1)
    if stagedMirror then
      love.graphics.draw(
        img,
        math.floor(cx+dx+0.5),
        math.floor(cy+dy-h/2+0.5),
        0,-1,1,w/2,0
      )
    else
      love.graphics.draw(
        img,
        math.floor(cx+dx-w/2+0.5),
        math.floor(cy+dy-h/2+0.5)
      )
    end
  end

  self.substituteDollOverrideBattles[battle]=original

  -- Gen1Recomp resolves Substitute damage before the queued move animation
  -- is shown. Keep the FireRed doll visible through that animation and release
  -- our hidden-state ownership only after the incoming animation completes.
  if not battle.substituteBreakRestoreOriginalDrawBattlerPic
     and type(battle.drawBattlerPic)=="function" then
    local originalDrawBattlerPic=battle.drawBattlerPic
    local hiddenBattlers=self.substituteHiddenBattlers
    battle.substituteBreakRestoreOriginalDrawBattlerPic=originalDrawBattlerPic
    battle.drawBattlerPic=function(host,battler,x,y,scale,shakeX,shakeY)
      local owned=hiddenBattlers and hiddenBattlers[battler]
      if owned and not battler.substituteHP then
        owned.breakPending=true
        -- Visually the Substitute still exists until the attack animation
        -- finishes, even though Gen1Recomp has already resolved its HP.
        host:drawSubstituteDoll(battler,shakeX,shakeY)
        return
      end
      return originalDrawBattlerPic(host,battler,x,y,scale,shakeX,shakeY)
    end
  end

  return true
end

-- Potato Voxel currently exposes no stable mutable battler-affine seam for
-- Growth.  Keep its real staged battler authoritative: the shared palette
-- hook still reproduces FireRed's two white flashes, while the unsupported
-- enlargement is deliberately omitted instead of drawing a 2D replacement.

function M:noteFailure(reason)
  self.stats.failed = self.stats.failed + 1
  self.lastFailureReason = reason
end

function M:clearStalePending(battle)
  local p=self.pending
  if not p or not p.row then return false end
  if battle and p.battle~=battle then return false end
  if queueContainsRow(p.battle,p.row) then return false end

  -- Gen1Recomp removes a move animation row when the move is cancelled
  -- after battle.move_used (missed/failed primary effects, charge turns,
  -- etc.). Never let that dead row block the next registered move.
  self.pending=nil
  self.stats.stalePendingCleared=self.stats.stalePendingCleared+1
  return true
end

local function findRegisteredAnimRow(self,b)
  if not b or type(b.queue) ~= "table" then return nil,nil end
  for _,row in ipairs(b.queue) do
    if type(row) == "table" and type(row.anim) == "string" then
      local move = self.registry:get(row.anim)
      if move then return row,move end
    end
  end
  return nil,nil
end

local function chargeRowAnim(move,userIsPlayer)
  local rows=move and move.chargeRowAnims
  if type(rows)~="table" then return nil end
  return userIsPlayer and rows.player or rows.opponent
end

local function findChargeAnimRow(b,move,userIsPlayer)
  local wanted=chargeRowAnim(move,userIsPlayer)
  if not wanted or not b or type(b.queue)~="table" then return nil end
  for _,row in ipairs(b.queue) do
    if type(row)=="table" and row.anim==wanted and row.attackerIsPlayer==(userIsPlayer==true) then
      return row
    end
  end
  return nil
end

function M:resetAnimTurnSequence(b,move)
  if move and move.alternatingAnimTurn then
    self.animTurnSequence={battle=b,moveId=move.id,next=0}
  else
    self.animTurnSequence=nil
  end
end

function M:takeAnimTurn(b,row,move)
  if not (move and move.alternatingAnimTurn) then return 0 end
  if type(row)=="table" and row._fireRedAnimTurn~=nil then
    return tonumber(row._fireRedAnimTurn) or 0
  end
  local seq=self.animTurnSequence
  if not seq or seq.battle~=b or seq.moveId~=move.id then
    seq={battle=b,moveId=move.id,next=0}
    self.animTurnSequence=seq
  end
  local turn=seq.next or 0
  seq.next=(turn+1)%2
  if type(row)=="table" then row._fireRedAnimTurn=turn end
  return turn
end

function M:queuePending(b,row,move,userIsPlayer,targetIsPlayer)
  if self.pending or self.active then return false end
  self.serial = self.serial + 1
  self.pending = {
    serial=self.serial, battle=b, row=row, move=move,
    userIsPlayer=userIsPlayer == true, targetIsPlayer=targetIsPlayer == true,
    animTurn=(type(row)=="table") and self:takeAnimTurn(b,row,move) or nil, age=0,
  }
  self.stats.triggered = self.stats.triggered + 1
  return true
end

local function suppressThrashSetupRow(b, moveRow, move, userIsPlayer)
  if not b or not moveRow or not move or (move.id ~= "THRASH" and move.id ~= "PETAL_DANCE") or type(b.queue) ~= "table" then return end
  local wanted = userIsPlayer and "SHRINKING_SQUARE_ANIM" or "ANIM_B1"
  for _,candidate in ipairs(b.queue) do
    if candidate == moveRow then break end
    if type(candidate)=="table" and candidate.anim==wanted
       and candidate.attackerIsPlayer==(userIsPlayer==true) then
      -- Gen1Recomp's Thrash/Petal Dance effect queues this setup animation
      -- before the actual move row. FireRed Move_THRASH has no equivalent
      -- pre-animation: its two native battler tasks start at frame 0. Remove
      -- both the Gen-I picture animation and its attached slow screen shake,
      -- without touching the effect's already-committed lock-in mechanics.
      candidate.anim=nil
      candidate.hit=nil
      candidate.hitRow=nil
      candidate._fireRedRampageSetupSuppressed=true
      break
    end
  end
end

function M:discoverQueuedMove(b)
  if self.pending or self.active then return false end
  local ok,reason = isClassicBattle(b)
  if not ok then return false end
  local row,move = findRegisteredAnimRow(self,b)
  if not row then return false end
  -- Gen1Recomp publishes attackerIsPlayer on every move-animation queue row.
  -- The queue is therefore authoritative for both move identity and direction;
  -- replacement no longer depends on battle.move_used arriving first.
  local userIsPlayer = row.attackerIsPlayer == true
  suppressThrashSetupRow(b,row,move,userIsPlayer)
  return self:queuePending(b,row,move,userIsPlayer,not userIsPlayer)
end

function M:onMoveUsed(ev)
  if not ev or not ev.battle or not ev.move then return end
  local move = self.registry:get(ev.move.id)
  if not move then return end

  local b = ev.battle
  -- A charge-turn hook owns the initial Razor Wind setup. battle.move_used can
  -- arrive before or after battle.charge_required depending on the host path;
  -- if that hook has already claimed this use, do not create a dead native-row
  -- pending entry for a turn whose move animation row will be cancelled.
  if self.chargePending and self.chargePending.battle==b and self.chargePending.move==move then
    return
  end
  -- battle.move_used fires once for a move use, while Gen1Recomp queues fresh
  -- animation rows for later multi-hit strikes. Reset FireRed's animation-turn
  -- selector here so choosetwoturnanim starts on branch 0 for every new use.
  if not (self.pending and self.pending.battle==b and self.pending.move.id==move.id) then
    self:resetAnimTurnSequence(b,move)
  end
  -- A prior registered move may have emitted battle.move_used and then had
  -- its native animation row removed synchronously by Gen1Recomp because the
  -- move missed/failed. Clear that dead pending claim before deciding this
  -- move is reentrant.
  self:clearStalePending(b)
  local ok,reason = isClassicBattle(b)
  if not ok then self:noteFailure(reason); return end

  -- The live queue is now the authority for claiming the native row. Keep the
  -- event only as a useful early hint/bookkeeping source. If fixed-step queue
  -- discovery already found this exact move, enrich it instead of treating the
  -- event as a reentrant failure.
  if self.pending and self.pending.battle == b and self.pending.move.id == move.id then
    if ev.user then self.pending.userIsPlayer = ev.user.isPlayer == true end
    if ev.target then self.pending.targetIsPlayer = ev.target.isPlayer == true end
    return
  end
  if self.active and self.active.battle == b and self.active.move.id == move.id then
    return
  end
  if self.pending or self.active then
    self.stats.reentrant = self.stats.reentrant + 1
    self:noteFailure("FireRed move already pending/active")
    return
  end

  local row = b.moveAnimRow
  if type(row) ~= "table" or row.anim ~= move.id then
    row = nil
    for _,candidate in ipairs(b.queue) do
      if type(candidate) == "table" and candidate.anim == move.id then
        row = candidate
        break
      end
    end
  end

  self:queuePending(
    b,row,move,
    ev.user and ev.user.isPlayer or false,
    ev.target and ev.target.isPlayer or false
  )
end

function M:onChargeRequired(ctx)
  if not ctx or ctx.charge ~= true or not ctx.battle or not ctx.move then return false end
  local move=self.registry:get(ctx.move.id)
  local userIsPlayer=ctx.user and ctx.user.isPlayer==true or false
  if not move or not move.chargeFlattened or not chargeRowAnim(move,userIsPlayer) then return false end
  local b=ctx.battle
  local ok,reason=isClassicBattle(b)
  if not ok then self:noteFailure(reason); return false end

  -- De-duplicate in case a host wrapper chain evaluates the guarded hook more
  -- than once. The native charge decision itself is left untouched.
  if self.chargePending and self.chargePending.battle==b and self.chargePending.move==move then
    return true
  end
  if self.active and self.active.battle==b and self.active.move==move and self.active.phase=="charge" then
    return true
  end

  -- If battle.move_used ran first, discard the doomed row claim now; the host
  -- intentionally removes the move-animation row on an initial charge turn.
  if self.pending and self.pending.battle==b and self.pending.move==move then
    self.pending=nil
  end
  self.serial=self.serial+1
  self.chargePending={
    serial=self.serial,battle=b,move=move,
    userIsPlayer=userIsPlayer,
    targetIsPlayer=ctx.target and ctx.target.isPlayer==true or false,
    age=0,
  }
  self.stats.chargeTriggered=self.stats.chargeTriggered+1
  return true
end

function M:startChargePending()
  local p=self.chargePending
  if not p or self.active then return false end
  local b=p.battle
  p.age=(p.age or 0)+1
  if not b or b.dead then self.chargePending=nil; self:noteFailure("battle ended before FireRed charge setup"); return false end
  if p.age>180 then self.chargePending=nil; self:noteFailure("timed out waiting for Gen1Recomp charge animation row"); return false end

  -- battle.charge_required fires before Gen1Recomp constructs the generic
  -- charge row. Bind only the row name declared by this move once it appears.
  -- This keeps XSTATITEM animations for every other move/item untouched.
  local row=findChargeAnimRow(b,p.move,p.userIsPlayer)
  if not row then return false end
  if not rowAtFront(b,row) or not row.animDelayed or (b.waitFrames~=nil and b.waitFrames>0) then return false end

  local attacker,target=classicAnchors(p.userIsPlayer)
  local okPlan,plan
  if self.precache and type(self.precache.chargePlan)=="function" then
    okPlan,plan=pcall(self.precache.chargePlan,self.precache,p.move,p.userIsPlayer)
  else
    okPlan,plan=pcall(self.visual.compile,p.move,{attacker=attacker,target=target,phase="charge"})
  end
  if not okPlan or not plan or not plan.durationFrames or plan.durationFrames<1 then
    self.chargePending=nil; self:noteFailure("FireRed charge-plan compilation failed"); return false
  end
  local assetsOk,err=self.visualAssets:prepareMove(p.move)
  if not assetsOk then
    self.chargePending=nil; self:noteFailure("FireRed charge texture construction failed")
    if self.log then self.log:warn("FireRed charge overlay unavailable: %s",tostring(err)) end
    return false
  end

  local snapshot={anim=row.anim,hit=row.hit,hitRow=row.hitRow,waitFrames=b.waitFrames}
  -- Replace the generic XSTATITEM presentation completely. Its `hit` payload
  -- is only the host's applying-animation shake, not move damage; FireRed's
  -- RazorWindSetUp does not use it. No native-hit seam is created on charge.
  row.anim=nil
  row.hit=nil
  row.hitRow=nil

  local attackerBattler=p.userIsPlayer and b.player or b.enemy
  local targetBattler=p.userIsPlayer and b.enemy or b.player
  local planForUse=instantiatePlan(plan,attackerBattler,targetBattler,attacker,target,b)
  local hold=math.max(1,math.floor(planForUse.durationFrames+0.5))
  b.waitFrames=hold
  self.active={
    serial=p.serial,battle=b,row=row,snapshot=snapshot,holdFrames=hold,
    move=p.move,plan=planForUse,frame=0,attacker=attacker,target=target,
    attackerBattler=attackerBattler,targetBattler=targetBattler,
    played={},done=false,userIsPlayer=p.userIsPlayer,animTurn=0,motionDisabled=false,
    phase="charge",
  }
  self.chargePending=nil
  self:installPaletteHook(self.active)
  self:applyBattlerMotion(self.active,0)
  self:fireSoundsAt(0)
  self.stats.replaced=self.stats.replaced+1
  return true
end

local function paletteBlendState(e, frame)
  local age=frame-e.frame
  if e.paletteSteps then
    for _,step in ipairs(e.paletteSteps) do
      if age>=step.start and age<step.finish then
        return clamp((step.amount or 0)/16,0,1), step.color or e.color
      end
    end
    return 0,e.color
  end
  local steps=math.max(1,(e.duration or 1)-1)
  local delay=math.max(0,math.floor(tonumber(e.delay) or 0))
  local progress
  if delay>0 then
    local totalSteps=math.abs((e.endAmount or 0)-(e.startAmount or 0))
    local advanced=math.min(totalSteps,math.floor(age/(delay+1)))
    local dir=((e.endAmount or 0)>=(e.startAmount or 0)) and 1 or -1
    progress=(e.startAmount or 0)+advanced*dir
  else
    local t=clamp(age/steps,0,1)
    progress=lerp(e.startAmount or 0,e.endAmount or 0,t)
  end
  return clamp(progress/16,0,1),e.color
end

local function activePaletteBlend(a, frame, battler)
  if not a then return nil end
  -- Multiple FireRed palette tasks can target the same battler at once. Tasks
  -- created later run from higher task slots and their BlendPalette write lands
  -- later in the frame, so the most recently-created active blend is the one
  -- visible. Sky Attack's charge deliberately relies on this: its white attacker
  -- glow overlaps the preceding black fade-out.
  local latest=nil
  for _,e in ipairs(a.plan.events or {}) do
    if (e.kind=="palette_blend" or e.kind=="palette_blend_cycle")
        and frame>=e.frame and frame<(e.effectEndFrame or e.destroyFrame or math.huge) then
      local target=e.target or e.selector or "target"
      local applies=false
      if target=="target" then applies=(battler==a.targetBattler)
      elseif target=="attacker" then applies=(battler==a.attackerBattler)
      elseif target=="both" or target=="all" then applies=true end
      if applies then latest=e end
    end
  end
  if not latest then return nil end
  local amount,color
  if latest.kind=="palette_blend_cycle" then
    local age=frame-latest.frame
    local oneWay=math.max(1,latest.oneWay or 1)
    local leg=math.floor(age/oneWay)
    local u=clamp((age%oneWay)/math.max(1,oneWay-1),0,1)
    local from,to
    if leg%2==0 then
      from=latest.initialAmount or 0; to=latest.peakAmount or 0
    else
      from=latest.peakAmount or 0; to=latest.initialAmount or 0
    end
    amount=lerp(from,to,u)/16
    color=latest.color
  else
    amount,color=paletteBlendState(latest,frame)
  end
  return latest,clamp(amount or 0,0,1),color
end

local CONVERSION_TAG = 10018
local CONVERSION_FLASH_BLEND = 12

local function activeSpriteTagFlash(a,frame,tag)
  if not a then return nil end
  for _,e in ipairs(a.plan.events or {}) do
    if e.kind=="sprite_tag_flash" and e.tag==tag and frame>=e.frame and frame<(e.destroyFrame or math.huge) then
      local c=e.color or {18,31,31}
      local cr=(type(c)=="table" and (c[1] or c.r)) or 31
      local cg=(type(c)=="table" and (c[2] or c.g)) or 31
      local cb=(type(c)=="table" and (c[3] or c.b)) or 31
      -- FireRed Conversion starts BeginNormalPaletteFade with start=end=12,
      -- tinting the completed white grid 12/16 toward RGB(31,31,13) for the
      -- short pre-alpha window. Model the palette result directly; this is a
      -- hold, not the generic full-strength on/off flash used by other tags.
      if tag==CONVERSION_TAG and tonumber(e.startAmount)==CONVERSION_FLASH_BLEND then
        local t=12/16
        return {
          r=(1-t)+t*math.min(1,(tonumber(cr) or 31)/31),
          g=(1-t)+t*math.min(1,(tonumber(cg) or 31)/31),
          b=(1-t)+t*math.min(1,(tonumber(cb) or 31)/31),
        }
      end
      local age=frame-e.frame
      local phase=math.floor(age/math.max(1,(e.delay or 0)+1))
      local on=(phase%2)==0
      if on then
        return {r=math.min(1,(tonumber(cr) or 31)/31),g=math.min(1,(tonumber(cg) or 31)/31),b=math.min(1,(tonumber(cb) or 31)/31)}
      end
    end
  end
  return nil
end

local function activeConversionGridFlash(a,frame)
  if not a then return nil end
  for _,e in ipairs(a.plan.events or {}) do
    if e.kind=="conversion_grid_flash" and e.tag==CONVERSION_TAG
        and frame>=e.frame and frame<(e.destroyFrame or math.huge)
        and (frame-e.frame)<(e.flashFrames or 2) then
      local c=e.color or {31,31,13}
      local cr=(type(c)=="table" and (c[1] or c.r)) or 31
      local cg=(type(c)=="table" and (c[2] or c.g)) or 31
      local cb=(type(c)=="table" and (c[3] or c.b)) or 13
      local t=math.max(0,math.min(16,tonumber(e.startAmount) or CONVERSION_FLASH_BLEND))/16
      -- Final Conversion frame is solid palette index 1 (white). FireRed's
      -- BeginNormalPaletteFade blends only ANIM_TAG_CONVERSION toward
      -- RGB(31,31,13); the battler palette is not part of this flash.
      return {
        r=(1-t)+t*math.min(1,(tonumber(cr) or 31)/31),
        g=(1-t)+t*math.min(1,(tonumber(cg) or 31)/31),
        b=(1-t)+t*math.min(1,(tonumber(cb) or 13)/31),
      }
    end
  end
  return nil
end

local function activeConversionAlpha(a,frame)
  if not a then return nil end
  for _,e in ipairs(a.plan.events or {}) do
    if e.kind=="conversion_alpha_blend" and e.tag==CONVERSION_TAG
        and frame>=e.frame and frame<(e.destroyFrame or math.huge) then
      local step=math.min(e.steps or 16,math.floor((frame-e.frame)/math.max(1,e.stepFrames or 4)))
      return math.max(0,1-step/16)
    end
  end
  return nil
end

local function activeBackgroundBlend(a,frame)
  if not a then return nil end
  local latest=nil
  for _,e in ipairs(a.plan.events or {}) do
    local target=e.target or e.selector
    if e.kind=="palette_blend" and (target=="bg" or target=="background") and
       frame>=e.frame and frame<(e.effectEndFrame or e.destroyFrame or math.huge) then
      latest=e
    end
  end
  if not latest then return nil end
  local amount,color=paletteBlendState(latest,frame)
  return latest,amount,color
end

local function activeMetallicShine(a,frame,battler)
  if not a or battler~=a.attackerBattler then return nil end
  for _,e in ipairs(a.plan.events or {}) do
    if e.kind=="metallic_shine" and frame>=e.frame and frame<e.frame+(e.visibleDuration or 64) then return e end
  end
  return nil
end

local function activeBattlerGrayscale(a,frame,battler)
  if not a then return 0 end
  local amount=0
  for _,e in ipairs(a.plan.events or {}) do
    if e.kind=="battler_grayscale" and frame>=e.frame and frame<(e.destroyFrame or math.huge) then
      local symbol=e.battler or "target"
      local who=(symbol=="attacker") and a.attackerBattler or ((symbol=="target") and a.targetBattler or nil)
      if who==battler then amount=math.max(amount,tonumber(e.amount) or 1) end
    end
  end
  return math.max(0,math.min(1,amount))
end

function M:metallicMask(a,frame,battler)
  local e=activeMetallicShine(a,frame,battler)
  if not e then return nil end
  local img=self.metalShineAssets:image(); if not img then return nil end
  local ds=e.displayScale or 1
  local age=frame-e.frame
  local anchor=a.attacker
  -- FireRed initializes BG1 to (-sprite.x + 96, -sprite.y + 32), then
  -- subtracts 4 X pixels every frame and wraps after each 128 px. Express the
  -- same BG coordinates relative to the host battler anchor after converting
  -- host screen coordinates back into FireRed's 240 px screen space.
  local x=96-(anchor.x or 0)/ds-(age%32)*4
  -- Native FireRed front/back pictures occupy 56/64 px presentation slots, but
  -- external battler-art providers can supply taller images. Keep the canonical
  -- 1:1 mask sampling for native-sized art; for taller replacement art, stretch
  -- only the mask's local Y coordinate around the same battler anchor so the
  -- metallic band traverses the full rendered silhouette instead of stopping
  -- across its upper portion. This stays provider-agnostic and also covers any
  -- future high-resolution battler source.
  local _,h=battlerSpriteDimensions(a.battle,battler)
  local nativeH=(battler and battler.isPlayer) and 64 or 56
  local yScale=math.max(1,(tonumber(h) or nativeH)/nativeH)
  -- Shader sampling is sc.y / yScale + offset. Rebase the offset around the
  -- FireRed battler anchor so yScale changes size without moving the shine.
  local y=32-(anchor.y or 0)/yScale
  return {image=img,amount=1,eva=8/16,evb=12/16,displayScale=ds,yDisplayScale=yScale,x=x,y=y}
end

function M:installPaletteHook(a)
  local b=a and a.battle
  if not b or a.paletteHook then return end
  a.paletteHook=self.paletteRenderer:install(b,function(battler)
    local ev,amount,color=activePaletteBlend(a,a.frame,battler)
    return amount,color or (ev and ev.color) or nil
  end)
  local owner=self
  a.metalMaskHook=self.paletteRenderer:installMask(b,function(battler) return owner:metallicMask(a,a.frame,battler) end)
  a.metalGrayHook=self.paletteRenderer:installGrayscale(b,function(battler)
    if activeMetallicShine(a,a.frame,battler) then return 1 end
    return activeBattlerGrayscale(a,a.frame,battler)
  end)
end

function M:clearPaletteHook(a)
  if not a then return end
  if a.paletteHook then self.paletteRenderer:clear(a.paletteHook); a.paletteHook=nil end
  if a.metalMaskHook then self.paletteRenderer:clear(a.metalMaskHook); a.metalMaskHook=nil end
  if a.metalGrayHook then self.paletteRenderer:clear(a.metalGrayHook); a.metalGrayHook=nil end
end

function M:cancelActive(reason)
  local a = self.active
  if not a then return false end
  local b,row,snap = a.battle,a.row,a.snapshot
  -- Strict replacement: once a registered FireRed move row is claimed, never
  -- restore its native animation. The hit row remains only as the shared
  -- feedback timing seam and is consumed by the FireRed apply-FX dispatcher.
  if b and row and rowAtFront(b,row) then
    row.anim = nil
    if a.phase=="charge" then
      row.hit=nil
      row.hitRow=nil
    else
      row.hitRow=true
    end
    if b.waitFrames == a.holdFrames then b.waitFrames = snap and snap.waitFrames or 0 end
  end
  self.stats.cancelled = self.stats.cancelled + 1
  self:clearBattlerMotion(a)
  self:clearPaletteHook(a)
  if a.move and a.move.quietBgm then self.setQuietBgm(false,a.battle) end
  self.active = nil
  if self.log and reason then self.log:warn("FireRed move replacement cancelled; vanilla remains suppressed: %s", tostring(reason)) end
  return true
end


-- Shared battler-picture motion support. This is deliberately isolated from
-- the core FireRed overlay path: if the host build cannot expose compatible
-- picFx state, only battler movement is disabled for that move; visuals/audio
-- continue normally.
local function motionBattler(active, symbol)
  if symbol == "attacker" then return active.attackerBattler end
  if symbol == "target" then return active.targetBattler end
  return nil
end

local function lungeOffset(e, age, battler)
  local half = math.max(1, math.floor((e.duration or 1) / 2))
  local step = e.delta or 0
  if battler and not battler.isPlayer then step = -step end
  if age < half then return step * (age + 1), 0 end
  local backAge = age - half
  return step * math.max(0, half - backAge - 1), 0
end

local function cIntDiv(n,d)
  d=math.max(1,math.abs(d or 1))
  if n>=0 then return math.floor(n/d) end
  return math.ceil(n/d)
end

local function gbaShift8(v)
  -- ARM arithmetic right shift used by FireRed's signed fixed-point data.
  return math.floor(v/256)
end

local function gbaSinApprox(index, amplitude)
  if (amplitude or 0)==0 then return 0 end
  local v=math.sin(((index or 0)%256)*math.pi*2/256)*(amplitude or 0)
  return v>=0 and math.floor(v+0.5) or math.ceil(v-0.5)
end

local function verticalDipOffset(e, age)
  local d=math.max(1,e.dipDuration or 1)
  local step=e.deltaY or 0
  -- age 0 is DoVerticalDip setup; translation begins on the next callback.
  if age<=0 then return 0,0 end
  if age<=d then return 0,step*age end
  if age==d+1 then return 0,step*d end
  if age<=2*d+1 then
    local back=age-(d+1)
    return 0,step*math.max(0,d-back)
  end
  return 0,0
end

local function slideToOffsetOffset(e, age, battler)
  local d=math.max(1,e.moveDuration or 1)
  local dx=e.targetX or 0
  local dy=e.targetY or 0
  if battler and not battler.isPlayer then
    dx=-dx
    if e.mirrorY then dy=-dy end
  end
  -- age 0 is SlideMonToOffset setup. InitSpriteDataForLinearTranslation
  -- stores signed 8.8 per-frame speeds using C's truncation toward zero.
  local steps=math.max(0,math.min(d,age))
  local sx=cIntDiv(dx*256,d)
  local sy=cIntDiv(dy*256,d)
  return gbaShift8(sx*steps),gbaShift8(sy*steps)
end

local function windUpLungeOffset(e, age, battler)
  local first=math.max(1,e.firstDuration or 1)
  local pause=math.max(0,e.delay or 0)
  local lunge=math.max(1,e.lungeDuration or 1)
  local windX=e.windX or 0
  local lungeX=e.lungeX or 0
  if battler and not battler.isPlayer then
    windX=-windX
    lungeX=-lungeX
  end

  local windStep=cIntDiv(windX*256,first)
  local windFrames=math.min(age+1,first)
  local windAccum=windStep*windFrames
  local baseX=gbaShift8(windAccum)

  local sampleAge=math.min(age,first-1)
  local wavePeriod=math.floor(0x8000/first)
  local waveIndex=math.floor((sampleAge*wavePeriod)/256)%256
  local y=gbaSinApprox(waveIndex,e.waveAmplitude or 0)

  if age < first+pause then return baseX,y end

  local lungeAge=math.min(lunge,age-(first+pause)+1)
  local lungeStep=cIntDiv(lungeX*256,lunge)
  local lungeAccum=lungeStep*lungeAge
  return gbaShift8(windStep*first)+gbaShift8(lungeAccum),y
end

local function slideToOriginalOffset(e,age,snap)
  -- The compiled plan is immutable and can be reused across battles/sides.
  -- Store callback-owned capture state on this active battler snapshot, not on
  -- the plan event itself.
  snap._slideCaptures=snap._slideCaptures or {}
  local capture=snap._slideCaptures[e]
  if not capture then
    capture={
      x=(snap.pf and (snap.pf.ox or 0)-(snap.ox or 0)) or 0,
      y=(snap.pf and (snap.pf.oy or 0)-(snap.oy or 0)) or 0,
    }
    snap._slideCaptures[e]=capture
  end
  local d=math.max(1,e.slideDuration or 1)
  if age>=d then
    local dir=e.direction or 0
    if dir==1 then return 0,capture.y or 0 end
    if dir==2 then return capture.x or 0,0 end
    return 0,0
  end
  local function axis(start)
    local step=cIntDiv(-(start or 0)*256,d)
    return (start or 0)+gbaShift8(step*age)
  end
  local dir=e.direction or 0
  if dir==1 then return axis(capture.x),capture.y or 0 end
  if dir==2 then return capture.x or 0,axis(capture.y) end
  return axis(capture.x),axis(capture.y)
end

local function ellipticalOffset(e, age, battler)
  local speed=math.max(0,math.min(5,e.step or 0))
  local angle=((age*(2^speed)) % 256) * math.pi * 2 / 256
  local x=math.sin(angle)*(e.xRadius or 0)
  local y=(1-math.cos(angle))*(e.yRadius or 0)
  if battler and not battler.isPlayer then x=-x end
  return math.floor(x+0.5), math.floor(y+0.5)
end

local function ellipticalRawOffset(e, age)
  local speed=math.max(0,math.min(5,e.step or 0))
  local angle=((age*(2^speed)) % 256) * math.pi * 2 / 256
  local x=math.sin(angle)*(e.xRadius or 0)
  local y=-math.cos(angle)*(e.yRadius or 0)+(e.yRadius or 0)
  return math.floor(x+0.5),math.floor(y+0.5)
end

local function slideOffscreenOffset(e,age)
  return (e.speed or 0)*(age+1),0
end

local function shakeAndSinkOffset(e, age)
  local d=math.max(1,e.duration or 1)
  local activeAge=math.min(math.max(0,age),d)
  local y=math.floor((activeAge*(e.sinkSpeed or 0))/256)
  if age>=d then return 0,y end
  local stride=math.max(1,(e.delay or 0)+1)
  local phase=math.floor(age/stride)
  local x=(phase%2==0) and (e.shakeX or 0) or -(e.shakeX or 0)
  return x,y
end

local function shakeOffset(e, age)
  local delay = math.max(0, e.delay or 0)
  local phase = math.floor(age / (delay + 1))
  if phase >= (e.count or 0) then return 0,0 end
  if phase % 2 == 0 then return e.x or 0, e.y or 0 end
  return 0,0
end

local function horizontalGroundShakeOffset(e, age)
  if age < 0 or age >= (e.duration or 0) then return 0,0 end
  -- Native HorizontalShake updates once every two frames. It starts at
  -- intensity=(arg1+3), alternates +/- for maxTime updates, then reduces the
  -- magnitude by one every four updates until it reaches zero.
  local update=math.floor(age/2)
  local maxTime=e.maxTime or 0
  local mag=e.intensity or 0
  if update >= maxTime then
    local decay=math.floor((update-maxTime)/4)+1
    mag=math.max(0,mag-decay)
  end
  if mag<=0 then return 0,0 end
  return ((update%2)==0) and mag or -mag,0
end

local function terrainControllerOffset(e, age)
  if age < 0 or age >= (e.duration or 0) then return 0,0 end
  local lifetime=math.max(0,e.lifetime or 0)
  if age>lifetime then return 0,0 end
  local delay=math.max(0,e.delay or 0)
  -- Native callback starts with data[1]=delay. Each update decrements lifetime;
  -- the coordinate flips only when the delay counter has already reached 0.
  local flips=math.floor(age/(delay+1))
  if flips<=0 then return 0,0 end
  local amp=e.amplitude or 0
  local offset=(flips%2==1) and -amp or amp
  local selector=e.selector or 0
  if selector==0 or selector==2 then return offset,0 end
  return 0,offset
end

local function shakeInPlaceOffset(e, age)
  local count=math.max(0,e.count or 0)
  if count<=1 then return 0,0 end
  local stride=math.max(1,(e.delay or 0)+1)
  local phase=math.floor(age/stride)
  -- The final native step recenters the battler before destroying the task.
  if phase>=count-1 then return 0,0 end
  local sign=(phase%2==0) and -1 or 1
  return sign*(e.x or 0),sign*(e.y or 0)
end


local SHAKE_PATTERN_0={1,-1,1,-1,1,-1,1,-1,1,-1}
local SHAKE_PATTERN_1={1,1,-1,-1,1,1,-1,-1,1,-1}
local function patternShakeOffset(e,age)
  local p=(e.pattern or 0)==0 and SHAKE_PATTERN_0 or SHAKE_PATTERN_1
  local dir=p[(age%#p)+1] or 1
  local amp=e.amplitude or 3
  if e.vertical then return 0,dir*amp end
  return dir*amp,0
end

local function bowMonState(plan, frame, battler)
  local x,angle=0,0
  if not plan or not plan.events or not battler then return x,angle end
  for _,e in ipairs(plan.events) do
    if e.kind=="battler_bow" and e.battler=="attacker" and frame>=e.frame then
      local age=frame-e.frame
      local mode=math.floor(tonumber(e.bowMode) or 0)
      if mode==0 then
        -- Native cadence: create callback, Step1 setup, 6 TranslateSpriteLinearById
        -- callbacks, one callback handoff, then 4 affine bow callbacks.
        local moveSteps=math.max(0,math.min(6,age-1))
        local xStep=battler.isPlayer and -2 or 2
        x=x+xStep*moveSteps
        local rotSteps=math.max(0,math.min(4,age-8))
        local rotStep=battler.isPlayer and -0x300 or 0x300
        angle=angle+rotStep*rotSteps
      elseif mode==1 then
        -- Preserve the latched bow; only translate the battler back.
        local moveSteps=math.max(0,math.min(4,age-1))
        local xStep=battler.isPlayer and 3 or -3
        x=x+xStep*moveSteps
      elseif mode==2 then
        -- Step3 waits for 9 callbacks before the 3-step affine restore.
        local rotSteps=math.max(0,math.min(3,age-9))
        local rotStep=battler.isPlayer and 0x400 or -0x400
        angle=angle+rotStep*rotSteps
      end
    end
  end
  return x,angle
end

local function swayOffset(e, age, battler)
  -- Native AnimTask_SwayMon increments phase before sampling Sin().
  local phase=((age+1)*(e.wavePeriod or 0)) % 65536
  local wave=math.floor(phase/256) % 256
  local angle=wave*math.pi*2/256
  local amp=e.amplitude or 0
  if e.attackerSide ~= "player" then amp=-amp end
  local v=math.sin(angle)*amp
  if (e.direction or 0)==0 then return math.floor(v+0.5),0 end
  local y=math.abs(v)
  if battler and not battler.isPlayer then y=-y end
  return 0,math.floor(y+0.5)
end

local function digDownOffset(e,age)
  -- Gen1Recomp's 56 px battler slot makes FireRed's native early bounce read
  -- much more aggressively than on the GBA. Keep the five Dig dirt volleys
  -- visually progressive: after each 32-frame volley the attacker is only
  -- about 10, 20, 32, 47 and finally 64 px underground. A small sine bob
  -- preserves the digging motion without swallowing most of the mon on the
  -- first burst.
  local keys={
    {0,0}, {38,10}, {70,20}, {102,32}, {134,47}, {159,e.targetY or 64},
  }
  local y=keys[#keys][2]
  for i=1,#keys-1 do
    local a,b=keys[i],keys[i+1]
    if age<=b[1] then
      local t=(age-a[1])/math.max(1,b[1]-a[1])
      y=a[2]+(b[2]-a[2])*math.max(0,math.min(1,t))
      break
    end
  end
  local phase=((age+1)*6)%128
  local bob=math.sin(phase*math.pi*2/256)*4
  y=math.max(0,math.min(e.targetY or 64,y+bob))
  return 0,math.floor(y+0.5)
end

local function digUndergroundOffset(e,age)
  return 0,e.targetY or 64
end

local function digUpOffset(e,age)
  local start=e.startY or 64
  local steps=math.min(8,math.max(0,math.floor(age)))
  return 0,math.max(0,start-steps*8)
end

local function thrashNativeOffset(e,age,battler)
  local t=math.max(0,math.min(83,math.floor(age or 0)))
  local cycle=t % 28
  local x
  if cycle < 7 then
    x=(cycle+1)*4
  elseif cycle < 21 then
    x=28-(cycle-6)*4
  else
    x=-28+(cycle-20)*4
  end
  if battler and not battler.isPlayer then x=-x end
  -- Native task increments its bob counter each step and toggles after >2.
  local toggles=math.floor((t+1)/3)
  local y=(toggles%2==1) and 2 or 0
  return x,y
end

function M:disableBattlerMotion(a, reason)
  if not a or a.motionDisabled then return end
  a.motionDisabled = true
  if a.motionOwned then
    for _,snap in pairs(a.motionOwned) do
      if snap.pf then
        snap.pf.ox = snap.ox
        snap.pf.oy = snap.oy
      end
    end
  end
  a.motionOwned = nil
  if self.log then self.log:warn("FireRed battler motion disabled; move overlay continues: %s", tostring(reason)) end
end

function M:initBattlerMotion(a)
  if not a or a.motionDisabled then return false end
  local ok,err = pcall(function()
    local b = a.battle
    if not b or type(b.picFxFor) ~= "function" then error("host picFxFor unavailable") end
    a.attackerBattler = a.userIsPlayer and b.player or b.enemy
    a.targetBattler = a.userIsPlayer and b.enemy or b.player
    a.motionOwned = {}
    for _,battler in ipairs({a.attackerBattler,a.targetBattler}) do
      if battler then
        local pf = b:picFxFor(battler)
        if type(pf) ~= "table" then error("host picFx state unavailable") end
        a.motionOwned[battler] = {pf=pf, ox=pf.ox or 0, oy=pf.oy or 0, hidden=pf.hidden}
      end
    end
  end)
  if not ok then self:disableBattlerMotion(a,err); return false end
  return true
end

function M:afterHostUpdate(battle)
  local h=battle and self.transformVisualLatches[battle]
  if not h then return end
  local battler=h.battler
  local stillCurrent=battler and (battle.player==battler or battle.enemy==battler) and battler.mon==h.mon
  if not stillCurrent then
    self.transformVisualLatches[battle]=nil
    return
  end

  -- Keep the FireRed midpoint image armed for the ENTIRE replacement
  -- animation.  v0.57.33 started the four-tick grace countdown as soon as the
  -- midpoint swap occurred, so the latch had expired roughly 46 frames before
  -- Gen1Recomp committed the real Transform sprite.  The host can briefly
  -- clear/rebuild battler.sprite during that post-animation commit; reassert
  -- the transformed display through that seam, then release only once the host
  -- supplies its own different non-nil sprite (or after a short post-animation
  -- fail-safe window).
  local active=self.active
  local transformStillRunning=active and active.battle==battle and active.move
    and active.move.id=="TRANSFORM"

  local cur=battler.sprite
  if cur==nil or cur==h.originalSprite then
    battler.sprite=h.image
  elseif cur~=h.image then
    self.transformVisualLatches[battle]=nil
    return
  end

  if transformStillRunning then
    h.postGrace=4
    return
  end

  h.postGrace=(tonumber(h.postGrace) or 4)-1
  if h.postGrace<=0 then self.transformVisualLatches[battle]=nil end
end

function M:applyBattlerMotion(a, frame)
  if not a or a.motionDisabled then return end
  if not a.motionOwned and not self:initBattlerMotion(a) then return end
  local ok,err = pcall(function()
    -- Terrain-only shake controllers have no separate BG3 layer in Gen1Recomp.
    -- Use the host's battlefield shake seam for the duration, restoring the
    -- pre-existing FX values when the controller is inactive.
    local terrainX,terrainY=0,0
    for _,e in ipairs(a.plan.events or {}) do
      if e.kind=="terrain_controller_shake" and frame>=e.frame and frame<(e.destroyFrame or e.frame) then
        local x,y=terrainControllerOffset(e,frame-e.frame)
        terrainX=terrainX+x; terrainY=terrainY+y
      end
    end
    if terrainX~=0 or terrainY~=0 then
      a.terrainFxOwned=a.terrainFxOwned or {
        shakeX=(a.battle.fx and a.battle.fx.shakeX) or 0,
        shakeY=(a.battle.fx and a.battle.fx.shakeY) or 0,
      }
      a.battle.fx=a.battle.fx or {}
      a.battle.fx.shakeX=(a.terrainFxOwned.shakeX or 0)+terrainX
      a.battle.fx.shakeY=(a.terrainFxOwned.shakeY or 0)+terrainY
    elseif a.terrainFxOwned then
      a.battle.fx=a.battle.fx or {}
      a.battle.fx.shakeX=a.terrainFxOwned.shakeX or 0
      a.battle.fx.shakeY=a.terrainFxOwned.shakeY or 0
    end
    local accum = {}
    for battler,_ in pairs(a.motionOwned) do accum[battler] = {x=0,y=0} end
    -- FireRed Transform swaps the visible battler graphic while the mosaic is
    -- fully closed.  Latch only the display sprite at that midpoint instead of
    -- restoring the original image after every draw.  Gen1Recomp still owns
    -- the actual Transform species/moves/stats state; when its real Transform
    -- update lands it naturally takes over this same battler sprite.
    for _,e in ipairs(a.plan.events or {}) do
      if e.kind=="battler_mosaic" and frame >= e.frame + (tonumber(e.swapAge) or 47) then
        local battler=motionBattler(a,e.battler or "attacker")
        if battler and not e.visualLatched and a.targetBattler then
          local staged=self.voxelCompat and self.voxelCompat:state(a.battle) or nil
          -- Battle Art already owns Transform-aware static/animated sprite
          -- routing. Our FireRed replacement consumes its native
          -- SE_TRANSFORM_MON trigger, so hand the copied species to Battle
          -- Art directly at the same mosaic midpoint instead of forcing
          -- gen1recomp's plain speciesSprite into the voxel card.
          if staged and staged.provider=="battle_art"
             and type(self.voxelCompat.markBattleArtTransform)=="function"
             and self.voxelCompat:markBattleArtTransform(a.battle,battler,a.targetBattler) then
            e.visualLatched=true
            self.transformVisualLatches[a.battle]=nil
          elseif type(a.battle.speciesSprite)=="function" then
            local species=a.targetBattler.mon and a.targetBattler.mon.species
            if species then
              local ok,img=pcall(a.battle.speciesSprite,a.battle,species,battler.isPlayer==true)
              if ok and img then
                local originalSprite=battler.sprite
                battler.sprite=img
                e.visualLatched=true
                -- Keep the transformed display image across the host's brief
                -- post-animation sprite refresh. The real Transform state remains
                -- host-owned; this latch only bridges the visual handoff.
                self.transformVisualLatches[a.battle]={
                  battler=battler, mon=battler.mon, image=img,
                  originalSprite=originalSprite, postGrace=4
                }
              end
            end
          end
        end
      end
    end

    -- Visibility events are persistent state changes (Fly setup hides the user
    -- across turns; Fly release restores it). Apply the latest event reached.
    for _,e in ipairs(a.plan.events) do
      if e.kind=="battler_visibility" and frame>=e.frame then
        local battler=motionBattler(a,e.battler)
        local snap=battler and a.motionOwned[battler]
        if snap and snap.pf then snap.pf.hidden=(e.visible==false) and true or nil end
      end
    end
    -- ScaleMonAndRestore is drawn by the overlay using the host's own battler
    -- picture layer. Hide the native unscaled copy only while a scale event is
    -- active, then restore whatever visibility state existed beforehand.
    --
    -- Potato's safe battler-texture affine path now supports both animated
    -- ScaleMonAndRestore-style scaling and fixed native affine scales such as
    -- Disable's GrowAndGrayscale (0xD0/0xD0). Keep the real voxel card visible
    -- whenever that texture path owns the transform.
    local staged=self.voxelCompat and self.voxelCompat:state(a.battle) or nil
    local stagedOwnsBattlers=staged and staged.ownership and staged.ownership.battlers
    for battler,snap in pairs(a.motionOwned) do
      local scaled=false
      for _,e in ipairs(a.plan.events) do
        if (e.kind=="battler_scale" or e.kind=="battler_rotate" or e.kind=="battler_affine_sequence" or e.kind=="battler_acid_armor" or e.kind=="battler_mosaic")
           and frame>=e.frame and frame<(e.destroyFrame or e.frame) then
          -- Potato's real card stays visible whenever the safe battler-texture
          -- affine path can represent the transform. This is intentionally
          -- limited to rotation + ordinary ScaleMonAndRestore-style scaling +
          -- Minimize + Skull Bash. It does NOT become a general visibility,
          -- translation, clone, or world-matrix bridge.
          local isPotatoTextureAffine = stagedOwnsBattlers
            and (staged.provider=="potato_voxel" or staged.provider=="battle_art")
            and (e.kind=="battler_scale"
              or e.kind=="battler_rotate"
              or e.kind=="battler_mosaic"
              or e.kind=="battler_acid_armor"
              or (e.kind=="battler_affine_sequence"
                  and (e.sequence=="skull_bash_set"
                    or e.sequence=="skull_bash_reset"
                    or e.sequence=="minimize"
                    or e.sequence=="defense_curl"
                    or e.sequence=="meditate"
                    or e.sequence=="splash")))
          local ownsHiddenReplacement = true
          if e.kind=="battler_mosaic" then
            -- REG_MOSAIC strength 0 is an ordinary fully visible battler.
            -- Hide the host copy only while the replacement mosaic actually
            -- has non-zero block size; otherwise the final zero-strength
            -- callbacks create a blank ownership gap before Transform commits.
            local age=math.max(0,math.floor(frame-e.frame))
            local stretch
            if age<=0 then stretch=0
            elseif age<=45 then stretch=math.min(15,math.floor((age+2)/3))
            elseif age<=47 then stretch=15
            else stretch=math.max(0,15-math.floor((age-45)/3)) end
            ownsHiddenReplacement = stretch>0
          end
          if motionBattler(a,e.battler)==battler
             and not isPotatoTextureAffine and ownsHiddenReplacement then scaled=true break end
        end
      end
      if not scaled and battler==a.attackerBattler then
        local _,bowAngle=bowMonState(a.plan,frame,battler)
        if bowAngle~=0 then
          local potatoTilt=stagedOwnsBattlers and (staged.provider=="potato_voxel" or staged.provider=="battle_art")
          if not potatoTilt then scaled=true end
        end
      end
      -- FireRed Double Team puts the attacker into monbg, then the native
      -- task disables that BG while its two cloned OBJ sprites are active.
      -- Reproduce the visible result by hiding only the real attacker for the
      -- lifetime of the Double Team clone task, restoring its prior state at
      -- the exact end of the task.
      local doubleTeamHidden=false
      if battler==a.attackerBattler then
        for _,e in ipairs(a.plan.events) do
          if e.kind=="double_team_clones" and frame>=e.frame and frame<(e.destroyFrame or e.frame) then
            doubleTeamHidden=true
            break
          end
        end
      end
      if scaled or doubleTeamHidden then
        if not snap.scaleManaged then snap.scaleHiddenBefore=snap.pf.hidden end
        snap.scaleManaged=true; snap.pf.hidden=true
      elseif snap.scaleManaged then
        snap.pf.hidden=snap.scaleHiddenBefore
        snap.scaleManaged=nil; snap.scaleHiddenBefore=nil
      end
    end
    for _,e in ipairs(a.plan.events) do
      local motionActive=false
      if e.kind=="battler_motion" and frame>=e.frame then
        motionActive=frame<(e.destroyFrame or e.frame)
        if e.motionKind=="slide_to_offset" or e.motionKind=="shake_and_sink" or e.motionKind=="dig_underground" or e.motionKind=="dig_down" then
          local holdUntil=e.holdUntilFrame or math.huge
          motionActive=frame<holdUntil
        elseif e.motionKind=="slide_offscreen" then
          -- FireRed AnimTask_SlideOffScreen destroys only the TASK after the
          -- battler has crossed the edge. It never restores gSprites[].x2, so
          -- the terminal offset remains latched for the rest of the animation.
          -- Keep contributing that final X offset until clearBattlerMotion()
          -- hands the completed disappearance to the persistent hide seam.
          motionActive=true
        end
      end
      if motionActive then
        local battler = motionBattler(a,e.battler)
        local v = battler and accum[battler]
        if v then
          local age = frame - e.frame
          if e.motionKind=="slide_offscreen" or e.motionKind=="dig_down" then
            age=math.min(age,math.max(0,(e.duration or 1)-1))
          end
          local x,y = 0,0
          if e.motionKind == "horizontal_lunge" then
            x,y = lungeOffset(e,age,battler)
            -- FireRed mirrors horizontal lunges by battle side. Potato Voxel
            -- may then mirror the staged battler artwork again (notably the
            -- player FRONT sprite), which visually reverses the lunge. Apply
            -- the presentation mirror after the native side calculation so
            -- Tackle and every other shared HorizontalLunge user still moves
            -- in its intended facing-relative direction.
            local staged=self.voxelCompat and self.voxelCompat:state(a.battle) or nil
            if staged and (staged.provider=="potato_voxel" or staged.provider=="battle_art")
               and self.voxelCompat:mirrorX(staged,battler) then
              x=-x
            end
          elseif e.motionKind == "vertical_dip" then x,y = verticalDipOffset(e,age)
          elseif e.motionKind == "slide_to_offset" then
            x,y = slideToOffsetOffset(e,age,battler)
            -- FireRed SlideMonToOffset already mirrors the requested X offset
            -- by battle side. A staged voxel provider may additionally mirror
            -- the battler artwork itself (Potato Voxel uses mirrored FRONT art
            -- for the player). Keep the slide facing-relative by applying the
            -- presentation mirror after the native side calculation, matching
            -- the correction used by RespectSide elliptical motions.
            local staged=self.voxelCompat and self.voxelCompat:state(a.battle) or nil
            if staged and (staged.provider=="potato_voxel" or staged.provider=="battle_art")
               and self.voxelCompat:mirrorX(staged,battler) then
              x=-x
            end
          elseif e.motionKind == "wind_up_lunge" then
            x,y = windUpLungeOffset(e,age,battler)
            -- Same side-relative rule as HorizontalLunge: preserve the native
            -- FireRed direction, then compensate only for Potato's staged-art
            -- presentation mirror.
            local staged=self.voxelCompat and self.voxelCompat:state(a.battle) or nil
            if staged and (staged.provider=="potato_voxel" or staged.provider=="battle_art")
               and self.voxelCompat:mirrorX(staged,battler) then
              x=-x
            end
          elseif e.motionKind == "slide_to_original" then x,y = slideToOriginalOffset(e,age,a.motionOwned[battler])
          elseif e.motionKind == "elliptical" then
            x,y = ellipticalOffset(e,age,battler)
            -- FireRed's RespectSide task mirrors the horizontal arc by battle
            -- side. Potato Voxel stages the player with FRONT art and mirrors
            -- that card again to face the opponent. Preserve the move's
            -- facing-relative motion by mirroring only the horizontal offset
            -- when the staged battler presentation itself is mirrored.
            local staged=self.voxelCompat and self.voxelCompat:state(a.battle) or nil
            if staged and (staged.provider=="potato_voxel" or staged.provider=="battle_art")
               and self.voxelCompat:mirrorX(staged,battler) then
              x=-x
            end
          elseif e.motionKind == "elliptical_raw" then x,y = ellipticalRawOffset(e,age)
          elseif e.motionKind == "slide_offscreen" then x,y = slideOffscreenOffset(e,age)
          elseif e.motionKind == "shake_and_sink" then x,y = shakeAndSinkOffset(e,age)
          elseif e.motionKind == "shake" then x,y = shakeOffset(e,age)
          elseif e.motionKind == "horizontal_ground_shake" then x,y = horizontalGroundShakeOffset(e,age)
          elseif e.motionKind == "shake_in_place" then x,y = shakeInPlaceOffset(e,age)
          elseif e.motionKind == "pattern_shake" then x,y = patternShakeOffset(e,age)
          elseif e.motionKind == "dig_down" then x,y = digDownOffset(e,age)
          elseif e.motionKind == "dig_underground" then x,y = digUndergroundOffset(e,age)
          elseif e.motionKind == "dig_up" then x,y = digUpOffset(e,age)
          elseif e.motionKind == "sway" then x,y = swayOffset(e,age,battler)
          elseif e.motionKind == "thrash_native" then x,y = thrashNativeOffset(e,age,battler) end
          v.x = v.x + x; v.y = v.y + y
        end
      end
    end
    for battler,v in pairs(accum) do
      local bowX=0
      if battler==a.attackerBattler then
        bowX=bowMonState(a.plan,frame,battler)
      end
      v.x=v.x+bowX
      local snap = a.motionOwned[battler]
      snap.pf.ox = snap.ox + v.x
      snap.pf.oy = snap.oy + v.y
    end
  end)
  if not ok then self:disableBattlerMotion(a,err) end
end

function M:clearBattlerMotion(a, preserveTerminal)
  if a and a.terrainFxOwned and a.battle then
    a.battle.fx=a.battle.fx or {}
    a.battle.fx.shakeX=a.terrainFxOwned.shakeX or 0
    a.battle.fx.shakeY=a.terrainFxOwned.shakeY or 0
    a.terrainFxOwned=nil
  end
  if not a or not a.motionOwned then return end
  local ok,err = pcall(function()
    local keepOffscreen = {}
    local keepTeleportHidden = {}
    if preserveTerminal and a.plan and a.plan.events then
      for _,e in ipairs(a.plan.events) do
        if e.kind=="battler_motion" and e.motionKind=="slide_offscreen"
           and (a.frame or 0) >= (e.destroyFrame or math.huge) then
          local battler=motionBattler(a,e.battler)
          if battler then keepOffscreen[battler]=true end
        elseif e.kind=="battler_affine_sequence" and e.sequence=="teleport"
           and (a.frame or 0) >= (e.destroyFrame or math.huge) then
          local battler=motionBattler(a,e.battler)
          if battler then keepTeleportHidden[battler]=true end
        end
      end
    end
    for battler,snap in pairs(a.motionOwned) do
      if snap.pf then
        snap.pf.ox=snap.ox; snap.pf.oy=snap.oy
        if snap.scaleManaged then snap.pf.hidden=snap.scaleHiddenBefore end
        -- FireRed AnimTask_SlideOffScreen destroys only the task after the
        -- battler has crossed the screen edge; it does not snap the sprite
        -- back to its origin.  Keep the completed target visually absent
        -- while the host resolves Whirlwind/Roar's battle outcome.  Using
        -- hidden rather than a stale huge X offset avoids contaminating a
        -- later battler picture if the host reuses this picFx table.
        if keepOffscreen[battler] or keepTeleportHidden[battler] then
          snap.pf.hidden=true
          if self.holdBattlerHidden then
            -- Teleport may reconstruct the battler's render sprite before the
            -- battle outcome row completes. Preserve hidden state across that
            -- visual refresh, but still release immediately if the Pokémon
            -- identity itself changes.
            self.holdBattlerHidden(a.battle,battler,{allowSpriteRefresh=keepTeleportHidden[battler]==true})
          end
        end
      end
    end
  end)
  a.motionOwned=nil
  if not ok and self.log then self.log:warn("FireRed battler motion cleanup failed: %s", tostring(err)) end
end

-- Registered FireRed moves retain Gen1Recomp's hit row only as a timing seam
-- for shared status/stat feedback and the generic effectiveness hit cue. The
-- native Gen1 visual is never allowed to run. Feedback consumers call
-- ackApplyHitFx when they claim the seam; otherwise consumeApplyHitFx asks the
-- shared dispatcher to play FireRed's 32-frame target hit reaction plus hit.sfx.
function M:ackApplyHitFx(battle)
  local p=self.nativeHitPending
  if not p or p.battle~=battle then return false end
  self.nativeHitPending=nil
  self.stats.nativeHitClaimedByFeedback=self.stats.nativeHitClaimedByFeedback+1
  return true
end

function M:consumeApplyHitFx(battle,hit)
  local p=self.nativeHitPending
  if not p or p.battle~=battle then return false end
  self.nativeHitPending=nil
  self.stats.nativeHitSuppressed=self.stats.nativeHitSuppressed+1
  return "fire-red-hit"
end

local function removeQueuedThrashSetup(b)
  if not b or type(b.queue) ~= "table" then return false end
  local rampageIndex
  for i,row in ipairs(b.queue) do
    if type(row)=="table" and (row.anim=="THRASH" or row.anim=="PETAL_DANCE") then
      rampageIndex=i
      break
    end
  end
  if not rampageIndex then return false end
  local removed=false
  for i=rampageIndex-1,1,-1 do
    local row=b.queue[i]
    if type(row)=="table" and (row.anim=="SHRINKING_SQUARE_ANIM" or row.anim=="ANIM_B1") then
      table.remove(b.queue,i)
      removed=true
      rampageIndex=rampageIndex-1
    end
  end
  if removed and type(b.waitFrames)=="number" and b.waitFrames>0 then
    -- The setup row may already have paid PlayMoveAnimation's three-frame
    -- pre-delay and been reinserted at the front. Removing it must also clear
    -- that delay so the FireRed Thrash row can be claimed immediately.
    b.waitFrames=nil
  end
  return removed
end

function M:cancelActiveThrashSetup(b)
  if not b or not b.animPlaying then return false end
  if b.animName~="SHRINKING_SQUARE_ANIM" and b.animName~="ANIM_B1" then return false end
  local hasRampageMove=false
  if type(b.queue)=="table" then
    for _,row in ipairs(b.queue) do
      if type(row)=="table" and (row.anim=="THRASH" or row.anim=="PETAL_DANCE") then
        hasRampageMove=true
        break
      end
    end
  end
  if not hasRampageMove then return false end
  b.animPlaying=false
  b.animName=nil
  b.pendingHit=nil
  b.waitFrames=nil
  if type(b.resetPicFx)=="function" then pcall(b.resetPicFx,b) end
  if type(b.fx)=="table" then
    b.fx.shake=nil
    b.fx.flash=nil
  end
  return true
end


local function findBideSetupRow(self,b)
  local move=self.registry:get("BIDE")
  if not move or not move.chargeFlattened or not b or type(b.queue)~="table" then return nil end
  for _,row in ipairs(b.queue) do
    if type(row)=="table" and (row.anim=="XSTATITEM_ANIM" or row.anim=="XSTATITEM_DUPLICATE_ANIM") then
      local userIsPlayer=row.attackerIsPlayer==true
      local user=userIsPlayer and b.player or b.enemy
      -- Gen1Recomp creates this X-Stat row only on Bide's first storing turn,
      -- after setting bideTurns/bideDamage. Other X-Stat uses are left alone.
      if user and user.bideTurns~=nil and user.bideDamage~=nil then
        return row,move,userIsPlayer
      end
    end
  end
  return nil
end

function M:startBideSetupRow(b)
  if self.pending or self.active or self.chargePending then return false end
  -- Do not scan ahead past a message that is still being typed. The native
  -- X-Stat row starts only after BattleState has finished the current text;
  -- claiming it earlier visibly interrupts the "used BIDE!" prompt.
  if b and b.current then return false end
  local row,move,userIsPlayer=findBideSetupRow(self,b)
  if not row then return false end
  -- Preserve the host's normal three-frame PlayMoveAnimation pre-delay. Once
  -- it has elapsed, claim the real X-Stat row before AnimPlayer can start it.
  if not rowAtFront(b,row) or not row.animDelayed or (b.waitFrames~=nil and b.waitFrames>0) then
    return false
  end

  local attacker,target=classicAnchors(userIsPlayer)
  local okPlan,plan
  if self.precache and type(self.precache.chargePlan)=="function" then
    okPlan,plan=pcall(self.precache.chargePlan,self.precache,move,userIsPlayer)
  else
    okPlan,plan=pcall(self.visual.compile,move,{attacker=attacker,target=target,phase="charge"})
  end
  if not okPlan or not plan or not plan.durationFrames or plan.durationFrames<1 then
    self:noteFailure("Bide setup-plan compilation failed")
    return false
  end
  local assetsOk,err=self.visualAssets:prepareMove(move)
  if not assetsOk then
    self:noteFailure("Bide setup texture construction failed")
    if self.log then self.log:warn("FireRed Bide setup unavailable: %s",tostring(err)) end
    return false
  end

  local attackerBattler=userIsPlayer and b.player or b.enemy
  local targetBattler=userIsPlayer and b.enemy or b.player
  local planForUse=instantiatePlan(plan,attackerBattler,targetBattler,attacker,target,b)
  local hold=math.max(1,math.floor(planForUse.durationFrames+0.5))
  local snapshot={anim=row.anim,hit=row.hit,hitRow=row.hitRow,waitFrames=b.waitFrames}

  -- Suppress both the native X-Stat spiral and its attached Gen-I screen-shake
  -- hit metadata. Keep a harmless hitRow shell at the queue front while the
  -- FireRed setup owns the same timing slot.
  row.anim=nil
  row.hit=nil
  row.hitRow=true
  b.waitFrames=hold

  self.serial=self.serial+1
  self.active={
    serial=self.serial,battle=b,row=row,snapshot=snapshot,holdFrames=hold,
    move=move,plan=planForUse,frame=0,attacker=attacker,target=target,
    attackerBattler=attackerBattler,targetBattler=targetBattler,
    played={},done=false,userIsPlayer=userIsPlayer,animTurn=0,motionDisabled=false,
    phase="bide_setup",
  }
  self:installPaletteHook(self.active)
  self:applyBattlerMotion(self.active,0)
  self:fireSoundsAt(0)
  self.stats.replaced=self.stats.replaced+1
  if userIsPlayer then self.stats.playerToEnemy=self.stats.playerToEnemy+1
  else self.stats.enemyToPlayer=self.stats.enemyToPlayer+1 end
  return true
end

function M:beforeUpdate(battle)
  -- Thrash's Gen-I setup can be queued ahead of the actual move row. Strip it
  -- at the earliest fixed-tick seam, before BattleState:updateQueue can start it.
  removeQueuedThrashSetup(battle)

  -- Remove a pending row as soon as the host has cancelled and deleted it.
  -- Without this, the stale claim survives for 180 ticks and causes the next
  -- registered move to be rejected as reentrant, letting its Gen1 animation
  -- play once before replacement recovers.
  self:clearStalePending(battle)

  -- Bide is not a normal charge move in Gen1Recomp: its first storing turn
  -- replaces the BIDE row with a standalone XSTATITEM animation. Claim that
  -- exact live row directly; no animBeforeMove/charge hook is involved.
  if battle and self:startBideSetupRow(battle) then return end

  -- Initial charge turns do not keep the normal move-animation row. The guarded
  -- battle.charge_required hook marks this use; once Gen1Recomp creates its
  -- generic XSTATITEM charge row, bind to that real queue row and replace only
  -- its presentation with FireRed's setup plan for the exact plan duration.
  if self.chargePending and not self.active then
    self:startChargePending()
    if self.chargePending or (self.active and self.active.phase=="charge") then return end
  end

  -- Claim from the live queue first. This runs on input.step, before
  -- BattleState can advance a native animation row on the same logic tick.
  if not self.pending and not self.active and battle then
    self:discoverQueuedMove(battle)
  end
  local nh=self.nativeHitPending
  if nh and not self.active and not queueContainsRow(nh.battle,nh.row) then self.nativeHitPending=nil end
  local p = self.pending
  if not p then return end
  p.age = p.age + 1
  local b,row = p.battle,p.row
  if not b or b.dead then self.pending=nil; self:noteFailure("battle ended before FireRed move row"); return end
  if p.age > 180 then self.pending=nil; self:noteFailure("timed out waiting for FireRed move row"); return end

  -- First-use-safe row binding. Keep looking until the host has published the
  -- row instead of allowing the vanilla animation to win a one-frame race.
  if type(row) ~= "table" then
    local published = b.moveAnimRow
    if type(published) == "table" and published.anim == p.move.id then
      row = published
    else
      for _,candidate in ipairs(b.queue) do
        if type(candidate) == "table" and candidate.anim == p.move.id then
          row = candidate
          break
        end
      end
    end
    p.row = row
    if type(row)=="table" and p.move.alternatingAnimTurn then
      p.animTurn=self:takeAnimTurn(b,row,p.move)
    end
  end

  if rowAtFront(b,row) and row.animDelayed and (b.waitFrames == nil or b.waitFrames <= 0) then
    local snapshot = { anim=row.anim, hitRow=row.hitRow, waitFrames=b.waitFrames }
    -- Claim the native row before doing any replacement work. From this point
    -- onward vanilla move visuals/SFX are never restored for a registered move.
    row.anim = nil
    row.hitRow = true
    self.nativeHitPending = {battle=b,row=row,serial=p.serial}

    local attacker,target = classicAnchors(p.userIsPlayer)
    local attackerBattler=p.userIsPlayer and b.player or b.enemy
    local targetBattler=p.userIsPlayer and b.enemy or b.player
    -- FireRed Gen 3 separates the initial Bind move from Status_BindWrap,
    -- whose tendril sprites are used for later trapped-damage feedback.
    -- Gen1Recomp intentionally uses Gen-1 trapping and replays BIND rows on
    -- continuation turns. trapMove is unset while the first-hit animation is
    -- running and stored after that hit lands, so it is a clean presentation
    -- seam for selecting the FireRed residual visual without changing battle
    -- mechanics or adding tendrils to Move_BIND itself.
    local trapContinuation = p.move.trapContinuationFlattened and attackerBattler
      and attackerBattler.trapMove==p.move.id
    local phase=trapContinuation and "trap_continuation" or nil
    local backgroundsEnabled = self.backgroundsEnabled() ~= false
    local okPlan,plan
    if trapContinuation and self.precache and type(self.precache.trapPlan)=="function" then
      okPlan,plan=pcall(self.precache.trapPlan,self.precache,p.move,p.userIsPlayer)
    elseif backgroundsEnabled and self.precache and type(self.precache.plan)=="function" then
      okPlan,plan=pcall(self.precache.plan,self.precache,p.move,p.userIsPlayer,p.animTurn)
    else
      -- A background-disabled plan is compiled separately so FireRed's
      -- fadetobg/restorebg waits disappear together with the visual layer.
      -- This keeps the move choreography/SFX from sitting through an invisible
      -- 69-frame background transition. The choice is sampled per move.
      okPlan,plan=pcall(self.visual.compile,p.move,{
        attacker=attacker,target=target,backgroundsEnabled=backgroundsEnabled,animTurn=p.animTurn,phase=phase,
      })
    end
    if not okPlan or not plan or not plan.durationFrames or plan.durationFrames < 1 then
      self.pending=nil; self:noteFailure("visual plan compilation failed after native row was claimed"); return
    end
    -- Normally already prepared for every registered move during mod load.
    -- Keep preparation idempotent for hot-added definitions, but never fall
    -- back to the native animation if preparation fails.
    local assetsOk,err = self.visualAssets:prepareMove(p.move)
    if not assetsOk then
      self.pending=nil; self:noteFailure("texture construction failed after native row was claimed")
      if self.log then self.log:warn("FireRed move overlay unavailable; vanilla remains suppressed: %s", tostring(err)) end
      return
    end

    local planForUse=instantiatePlan(plan,attackerBattler,targetBattler,attacker,target,b)
    local hold = math.max(1, math.floor(planForUse.durationFrames + 0.5))
    b.waitFrames = hold

    self.active = {
      serial=p.serial, battle=b, row=row, snapshot=snapshot, holdFrames=hold,
      move=p.move, plan=planForUse, frame=0, attacker=attacker, target=target,
      attackerBattler=attackerBattler,
      targetBattler=targetBattler,
      played={}, done=false, userIsPlayer=p.userIsPlayer, animTurn=p.animTurn or 0, motionDisabled=false,
      phase=phase,
    }
    self.pending = nil
    self:installPaletteHook(self.active)
    if p.move and p.move.id=="SUBSTITUTE" then
      self:installFireRedSubstituteDoll(b)
    end
    if p.move.quietBgm then self.setQuietBgm(true,b) end
    self:applyBattlerMotion(self.active,0)
    self.stats.replaced = self.stats.replaced + 1
    if p.userIsPlayer then self.stats.playerToEnemy=self.stats.playerToEnemy+1
    else self.stats.enemyToPlayer=self.stats.enemyToPlayer+1 end
    self:fireSoundsAt(0)
  end
end

function M:afterUpdate()
  local a = self.active
  if not a then return end
  if not a.battle or a.battle.dead then self:cancelActive("battle teardown"); return end
  -- The row should remain at the queue front while waitFrames holds it. If the
  -- engine advances unexpectedly, stop drawing/audio immediately rather than
  -- attaching one move to a later action.
  if not rowAtFront(a.battle,a.row) and a.frame < a.plan.durationFrames then
    self:cancelActive("queue advanced during FireRed move")
    return
  end
  a.frame = a.frame + 1
  self:applyBattlerMotion(a,a.frame)
  -- FireRed hides the battler only after ResetSpriteRotScale. The shared
  -- affine manager restores its pre-scale visibility when the 10-frame
  -- sequence ends, so apply the Substitute swap hide after that restoration.
  if a.move and a.move.id=="SUBSTITUTE" and a.frame==10 then
    self:applySubstituteSwapHide(a)
  end
  self:fireSoundsAt(a.frame)
  if a.frame >= a.plan.durationFrames then
    a.done = true
    self.stats.completed = self.stats.completed + 1
    if a.phase=="charge" then self.stats.chargeCompleted=self.stats.chargeCompleted+1 end
    -- The native row remains hit-only as a timing seam; its applyHitFx call is
    -- always consumed by FireRed feedback or by the move bridge itself.
    if a.substituteSwapHide then
      local sh=a.substituteSwapHide
      local b=sh.battler
      local pf=sh.pf
      if b and pf then
        if not b.substituteHP then
          pf.hidden=sh.previousHidden
          self.substituteHiddenBattlers[b]=nil
        else
          -- Keep the real battler hidden; host drawSubstituteDoll owns appearance now.
          pf.hidden=true
        end
      end
      a.substituteSwapHide=nil
    end
    self:clearBattlerMotion(a, true)
    self:clearPaletteHook(a)

    -- Visual Substitute break handoff. Damage was resolved before this move
    -- animation started, but the doll stayed visible through the hit. Reveal
    -- the real Pokemon only now, after the incoming animation has finished.
    local brokenTarget=a.targetBattler
    local owned=brokenTarget and self.substituteHiddenBattlers[brokenTarget]
    if owned and owned.breakPending and not brokenTarget.substituteHP then
      if owned.pf then
        owned.pf.hidden=owned.previousHidden
      end
      self.substituteHiddenBattlers[brokenTarget]=nil
    end

    if a.move and a.move.quietBgm then self.setQuietBgm(false,a.battle) end
    self.active = nil
  end
end

function M:fireSoundsAt(frame)
  local a = self.active
  if not a then return end
  for i,e in ipairs(a.plan.events) do
    if e.kind == "sound" and e.frame == frame and not a.played[i] then
      a.played[i] = true
      local pan = soundPan(e.pan, a.attacker)
      local ok,err = self.playSound(e.sound, pan, a.battle, nil, e.overlap==true)
      if not ok and self.log then self.log:warn("FireRed move SFX %s failed: %s", tostring(e.sound), tostring(err)) end
    elseif e.kind == "move_cry" and e.frame == frame and not a.played[i] then
      a.played[i] = true
      if self.playMoveCry then
        local ok,err=self.playMoveCry(a.battle,a.attackerBattler,e.tempo)
        if ok==nil and err and self.log then self.log:warn("FireRed move cry failed: %s",tostring(err)) end
      end
    end
  end
end

-- Draw a ROM-native FireRed battle background in the host battle coordinate
-- space. battle.overlay is already inside the battle's own 160x144 render
-- transform, so do NOT use love.graphics.setScissor here: LÖVE scissor
-- coordinates are window-space and caused the v0.25.11 black-edge/white-field
-- failure. Instead crop the FireRed 256x256 image with a Quad to the exact
-- 240x144 source region that maps to Gen1Recomp's 160x96 battlefield.

local function thunderInvertState(a,frame)
  local bg,attacker,target=false,false,false
  for _,e in ipairs(a.plan.events or {}) do
    if e.kind=="screen_invert_toggle" and e.frame<=frame then
      if e.bg then bg=not bg end
      if e.attacker then attacker=not attacker end
      if e.target then target=not target end
    end
  end
  return bg,attacker,target
end

local function activeBgScroll(a,frame)
  local latest=nil
  local fissure=nil
  local rise=nil
  local drop=nil
  for _,e in ipairs(a.plan.events or {}) do
    if e.kind=="battle_bg_scroll" and e.frame<=frame then latest=e end
    if e.kind=="fissure_bg_position" and e.frame<=frame then fissure=e end
    if e.kind=="seismic_toss_bg_rise" and e.frame<=frame then rise=e end
    if e.kind=="seismic_toss_bg_drop" and e.frame<=frame then drop=e end
  end
  if rise then
    local age=math.max(0,math.min(120,frame-rise.frame))
    local y=0
    for i=0,age-1 do y=y+math.floor((200-i*3)/10) end
    if drop and frame>=drop.frame then
      local d=frame-drop.frame+1
      local v=(d*80)%256
      y=y+math.cos(4*math.pi*2/256)*v
    end
    return 0,y
  end
  if fissure then return fissure.x or 0,fissure.y or 0 end
  if not latest then return 0,0 end
  local age=frame-latest.frame
  -- FireRed stores BG scroll velocities in 8.8 fixed point.
  return (latest.dx or 0)*age/256,(latest.dy or 0)*age/256
end

local function activeSurfWave(a,frame)
  local latest=nil
  for _,e in ipairs(a.plan.events or {}) do
    if e.kind=="surf_wave" and e.frame<=frame and frame<(e.destroyFrame or e.frame) then latest=e end
  end
  if not latest then return nil end
  local age=frame-latest.frame
  local d=math.floor(age/2)+1
  local eva
  if d<14 then eva=d elseif d>54 then eva=math.max(0,13-(d-54)) else eva=13 end
  if eva<=0 then return nil end
  local y0,y1
  if latest.side=="player" then
    y0=math.max(0,48-age); y1=112
  else
    y0=0; y1=math.min(112,age)
  end
  local startX=(latest.side=="player") and 0 or -224
  local startY=(latest.side=="player") and -48 or 256
  local dx=(latest.side=="player") and -2 or 2
  local dy=(latest.side=="player") and 1 or -1
  return latest,eva/16,y0,y1,startX+dx*age,startY+dy*age,math.floor(age/4)%7
end

local function ensureInvertShader(a)
  if a.invertShader~=nil then return a.invertShader end
  if not (love and love.graphics and love.graphics.newShader) then a.invertShader=false; return nil end
  local ok,shader=pcall(love.graphics.newShader,[[
    vec4 effect(vec4 color, Image tex, vec2 tc, vec2 sc) {
      vec4 px = Texel(tex, tc);
      return vec4(vec3(1.0)-px.rgb, px.a) * color;
    }
  ]])
  a.invertShader=ok and shader or false
  return ok and shader or nil
end

local function activeBackgroundPaletteRotation(a,frame,bg)
  if not (a and bg) then return 0 end
  local latest=nil
  for _,e in ipairs(a.plan.events or {}) do
    if e.kind=="battle_bg_palette_rotate" and e.background==bg and e.frame<=frame and
       (not e.stopFrame or frame<e.stopFrame) then
      latest=e
    end
  end
  if not latest then return 0 end
  local period=math.max(1,tonumber(latest.period) or 4)
  local entries=math.max(1,tonumber(latest.entries) or 11)
  return math.floor((frame-latest.frame)/period)%entries
end

local function activeScaryFace(a,frame)
  if not a then return nil end
  for _,e in ipairs(a.plan.events or {}) do
    if e.kind=="scary_face_bg" and frame>=e.frame and frame<(e.destroyFrame or math.huge) then
      local age=frame-e.frame
      local fadeIn=math.max(1,tonumber(e.fadeIn) or 28)
      local hold=math.max(0,tonumber(e.hold) or 21)
      local fadeOut=math.max(1,tonumber(e.fadeOut) or 28)
      local alpha
      if age<fadeIn then alpha=(age/fadeIn)*(14/16)
      elseif age<fadeIn+hold then alpha=14/16
      else alpha=math.max(0,(1-(age-fadeIn-hold)/fadeOut)*(14/16)) end
      return e,math.max(0,math.min(14/16,alpha))
    end
  end
  return nil
end

function M:drawBackground(battle,opts)
  local a=self.active
  if not a or a.battle~=battle or not (love and love.graphics) then return end
  local backgroundOnly = type(opts)=="table" and opts.backgroundOnly==true
  local drewBackground = false

  -- Resolve the latest FireRed BG transition at the current fixed-step frame.
  -- Task_FadeToBg uses a hardware brightness-decrease fade: current BG ->
  -- black, swap at full black, then black -> new BG. BLDCNT 0xE8 targets BG3
  -- and backdrop, not OBJ, so battler sprites stay visible throughout.
  local bg=nil
  local blackAlpha=0
  local latest=nil
  for _,e in ipairs(a.plan.events or {}) do
    if e.kind=="battle_bg_transition" and e.frame<=a.frame then latest=e end
  end
  if latest then
    local f=a.frame
    if f < latest.midpointFrame then
      bg=latest.fromBg
      local span=math.max(1,latest.midpointFrame-latest.frame)
      blackAlpha=math.max(0,math.min(1,(f-latest.frame)/span))
    elseif f < latest.swapFrame then
      -- FireRed holds the old BG at full black for one Task_FadeToBg update
      -- before loading the replacement background.
      bg=latest.fromBg
      blackAlpha=1
    elseif f < latest.endFrame then
      bg=latest.toBg
      local span=math.max(1,latest.endFrame-latest.swapFrame)
      blackAlpha=math.max(0,math.min(1,1-(f-latest.swapFrame)/span))
    else
      bg=latest.toBg
    end
  end
  local allowMoveBackgrounds = (not self.backgroundsEnabled) or self.backgroundsEnabled()
  local surf,surfAlpha,surfY0,surfY1,surfX,surfY,surfRot=activeSurfWave(a,a.frame)
  if surf then
    -- Surf is a special case. With move backgrounds enabled, reproduce the
    -- native filled BG1 layer. With backgrounds disabled, render a separate
    -- transparent crest/foam image derived from the same ROM-native Surf
    -- graphics. This is a real move effect over the normal battlefield, not
    -- a crop of the full water background.
    local surfPrefix=allowMoveBackgrounds and "surf_" or "surf_wave_"
    local surfName=surfPrefix..tostring(surf.side or "player")
    local img=self.battleBgAssets:image(surfName,surfRot)
    if not img and self.battleBgAssets and type(self.battleBgAssets.prepare)=="function" then
      local ok,why=pcall(self.battleBgAssets.prepare,self.battleBgAssets,surfName)
      if ok then img=self.battleBgAssets:image(surfName,surfRot)
      elseif self.log then self.log:warn("FireRed Surf background unavailable: %s",tostring(why)) end
    end
    if img and surfY1>surfY0 then
      local g=love.graphics; local iw,ih=img:getDimensions()
      local qx=((surfX%iw)+iw)%iw; local qy=((surfY%ih)+ih)%ih

      -- Surf is special: AnimTask_SurfWaveScanlineEffect operates in a
      -- 112-line battle window (0..111), not the 144-line move-background
      -- space used by FadeToBg.  Gen I's visible battlefield is 96 px high,
      -- so map that native Surf window directly to the host battlefield.
      -- Keeping this conversion here avoids mixing source scanlines, host
      -- pixels and the generic 2/3 background transform.
      local SURF_NATIVE_HEIGHT=112
      local SURF_HOST_HEIGHT=96
      local SURF_Y_SCALE=SURF_HOST_HEIGHT/SURF_NATIVE_HEIGHT
      local sx0=math.max(0,math.min(SURF_NATIVE_HEIGHT,surfY0))
      local sx1=math.max(0,math.min(SURF_NATIVE_HEIGHT,surfY1))
      local sourceHeight=math.max(0,sx1-sx0)
      if sourceHeight>0 then
        a.surfBandQuad=a.surfBandQuad or g.newQuad(0,0,240,sourceHeight,iw,ih)
        if a.surfBandQuad.setViewport then
          a.surfBandQuad:setViewport(qx,qy+sx0,240,sourceHeight,iw,ih)
        end
        g.setColor(1,1,1,surfAlpha)
        g.draw(img,a.surfBandQuad,0,sx0*SURF_Y_SCALE,0,2/3,SURF_Y_SCALE)
        drewBackground = true
        g.setColor(1,1,1,1)
      end
    end
  end
  local bgBlend,bgAmount,bgColor=nil,nil,nil
  if allowMoveBackgrounds then
    bgBlend,bgAmount,bgColor=activeBackgroundBlend(a,a.frame)
  end
  local scaryFace,scaryAlpha=activeScaryFace(a,a.frame)

  -- Pure palette blends (Thunder Wave / Thunderbolt) do not load a replacement
  -- battle background. Do not exit just because there is no FadeToBg asset.
  if not bg and blackAlpha<=0 and not (bgBlend and bgAmount and bgAmount>0) and not scaryFace then return drewBackground end

  local g=love.graphics
  local invertBg,invertAttacker,invertTarget=thunderInvertState(a,a.frame)
  local invertShader=(invertBg or invertAttacker or invertTarget) and ensureInvertShader(a) or nil
  if bg then
    local bgRotation=activeBackgroundPaletteRotation(a,a.frame,bg)
    local img=self.battleBgAssets:image(bg,bgRotation)
    if not img and self.battleBgAssets and type(self.battleBgAssets.prepare)=="function" then
      local ok,why=pcall(self.battleBgAssets.prepare,self.battleBgAssets,bg)
      if ok then
        img=self.battleBgAssets:image(bg,bgRotation)
      elseif self.log then
        self.log:warn("FireRed move background %s unavailable: %s",tostring(bg),tostring(why))
      end
    end
    if img then
      local iw,ih=img:getDimensions()
      local scrollX,scrollY=activeBgScroll(a,a.frame)
      local qx=((scrollX%iw)+iw)%iw
      local qy=((scrollY%ih)+ih)%ih
      a.bgQuad=a.bgQuad or g.newQuad(0,0,240,144,iw,ih)
      if a.bgQuad.setViewport then a.bgQuad:setViewport(qx,qy,240,144,iw,ih) end
      g.setColor(1,1,1,1)
      if invertBg and invertShader then g.setShader(invertShader) end
      g.draw(img,a.bgQuad,0,0,0,2/3,2/3)
      drewBackground = true
      if invertBg and invertShader then g.setShader() end
    end
  end

  -- FireRed's 0xE8 hardware fade darkens BG3/backdrop only. Draw the black
  -- fade over the 160x96 battlefield, then repaint native battlers/HUD above
  -- it so OBJ/HUD layers are not incorrectly faded with the background.
  if blackAlpha>0 then
    g.setColor(0,0,0,blackAlpha)
    g.rectangle("fill",0,0,160,96)
    drewBackground = true
  end

  if bgBlend and bgAmount and bgAmount>0 then
    -- FireRed BlendPalettes mixes the selected BG palette toward the exact
    -- BGR555 color supplied by the animation script.  Do not collapse custom
    -- RGB colors to black: Absorb/Mega Drain use RGB(13,31,12), for example.
    local c=bgColor or bgBlend.color or "black"
    local r,gc,b=0,0,0
    if c=="white" then
      r,gc,b=1,1,1
    elseif c=="black" then
      r,gc,b=0,0,0
    elseif type(c)=="table" then
      r=math.max(0,math.min(31,tonumber(c[1] or c.r) or 0))/31
      gc=math.max(0,math.min(31,tonumber(c[2] or c.g) or 0))/31
      b=math.max(0,math.min(31,tonumber(c[3] or c.b) or 0))/31
    end
    g.setColor(r,gc,b,bgAmount)
    g.rectangle("fill",0,0,160,96)
    drewBackground = true
  end

  local function drawScaryFaceOverlay()
    if not (scaryFace and scaryAlpha and scaryAlpha>0) then return false end
    local name="scary_face_"..tostring(scaryFace.side or "player")
    local img=self.battleBgAssets:image(name)
    if not img and self.battleBgAssets and type(self.battleBgAssets.prepare)=="function" then
      local ok,why=pcall(self.battleBgAssets.prepare,self.battleBgAssets,name)
      if ok then img=self.battleBgAssets:image(name)
      elseif self.log then self.log:warn("FireRed Scary Face background unavailable: %s",tostring(why)) end
    end
    if not img then return false end
    local iw,ih=img:getDimensions()
    local q=a.scaryFaceQuad
    if not q then q=love.graphics.newQuad(0,0,240,144,iw,ih); a.scaryFaceQuad=q end
    if q.setViewport then q:setViewport(0,0,240,144,iw,ih) end
    love.graphics.setColor(1,1,1,scaryAlpha)
    love.graphics.draw(img,q,0,0,0,2/3,2/3)
    love.graphics.setColor(1,1,1,1)
    drewBackground=true
    return true
  end

  -- Scary Face is a FireRed BG1 animation layer. It must remain behind both
  -- battler OBJ layers in classic 2D, and belongs to the background canvas in
  -- Potato/background-only composition. Draw it before the battler picture
  -- layer in both paths so it can never occlude either Pokemon.
  drawScaryFaceOverlay()

  local fx=battle.fx
  local sx=(fx and fx.shakeX) or 0
  local sy=(fx and fx.shakeY) or 0
  if sx==0 and sy==0 and fx and fx.shake and fx.shake>0 then
    sx=(battle.frame or 0)%4<2 and 2 or -2
  end
  if not backgroundOnly and battle.drawPicsLayer then
    if (invertAttacker or invertTarget) and invertShader then g.setShader(invertShader) end
    battle:drawPicsLayer(0,sx,sy)
    if (invertAttacker or invertTarget) and invertShader then g.setShader() end
  end
  -- The host HUD was already drawn before this FireRed overlay. Repaint it only
  -- for native BG swaps / brightness fades, where FireRed keeps interface OBJ
  -- above the BG3 transition. Explicit battle-background palette blends (for
  -- example Hyper Beam's fade to black) are presentation-wide in this mod: if
  -- we repaint the HUD here the colored HP fill leaks back through as a bright
  -- line over the altered battlefield. Leaving the host HUD underneath the
  -- blend masks the whole healthbox cleanly until that blend returns to zero.
  local maskHudForPaletteBlend = bgBlend and bgAmount and bgAmount > 0
  if not backgroundOnly and battle.drawHUDs and not maskHudForPaletteBlend then
    -- Classic color mode normally draws HP fills as raw DMG gray because the
    -- host's earlier SGB zone pass recolors them green/yellow/red. We are
    -- repainting the HUD after that pass so the zone shader will not run a
    -- second time. Temporarily force the HUD's flat-color path so the native
    -- renderer emits the final HP-bar color directly instead of gray.
    local hadColorMode = rawget(battle, "colorMode")
    battle.colorMode = function() return false end
    local ok,err = pcall(battle.drawHUDs,battle,0)
    battle.colorMode = hadColorMode
    if not ok and self.log then
      self.log:warn("FireRed background HUD repaint failed: %s", tostring(err))
    end
  end
  g.setColor(1,1,1,1)
  return drewBackground
end

-- FireRed Double Team clone offsets for the current active frame.  This is
-- shared by the classic overlay renderer and Potato's dedicated 3D clone
-- billboards so both paths use the exact same GBA integer sine progression.
local function doubleTeamCloneOffsets(event,frame)
  local age=math.max(0,math.floor(frame-event.frame))
  local function trunc0(v)
    if v<0 then return math.ceil(v) end
    return math.floor(v)
  end
  local function gbaSin(idx,amp)
    local raw=trunc0(math.sin((idx%256)*math.pi/128)*256)
    return trunc0(raw*(amp or 0)/256)
  end
  local data0,angle0,angle1=0,0,128
  for cb=1,age+1 do
    if cb%2==0 then data0=data0+1 end
    if data0>64 then break end
    local sine=trunc0(math.sin((data0%256)*math.pi/128)*256)
    local amp=trunc0(sine/6)
    local vel=trunc0(sine/13)
    angle0=(angle0+vel)%256
    angle1=(angle1+vel)%256
    if cb==age+1 then
      return gbaSin(angle0,amp),gbaSin(angle1,amp)
    end
  end
  return 0,0
end

-- Potato Voxel Double Team: the two copies are actor-like local effects, not
-- HUD overlays and not sprites spanning the player<->enemy fxCard plane.
-- Return live billboard descriptions attached to the attacker's world cell.
function M:doubleTeamWorldClones(battle)
  local a=self.active
  if not a or a.battle~=battle then return nil end
  if not self.voxelCompat then return nil end
  local staged=self.voxelCompat:state(battle)
  if not (staged and (staged.provider=="potato_voxel" or staged.provider=="battle_art")) then return nil end
  local f=a.frame
  for _,e in ipairs(a.plan.events or {}) do
    if e.kind=="double_team_clones" and f>=e.frame and f<(e.destroyFrame or e.frame) then
      local battler=motionBattler(a,e.battler or "attacker")
      if not battler then return nil end
      local img=self.voxelCompat:battlerImage(battle,battler)
      if not img then return nil end
      local dx0,dx1=doubleTeamCloneOffsets(e,f)
      return {
        battler=battler,
        image=img,
        offsets={dx0,dx1},
        alpha=e.cloneAlpha or (12/16),
        darkMul=e.darkMul or (5/16),
        mirrorX=self.voxelCompat:mirrorX(staged,battler),
      }
    end
  end
  return nil
end

-- Potato Voxel Night Shade: return the live clone as a dedicated world
-- billboard description. Keeping this out of the shared fxCard texture is
-- important: a battler clone is an actor standing on one cell, not a move
-- sprite spanning the player/enemy animation plane.
-- Potato Voxel Minimize: the real battler is handled by the shared safe
-- battler-texture affine path; only the transient translucent traces need
-- separate actor billboards. Return their live scales/alpha for main.lua.
function M:minimizeWorldClones(battle)
  local a=self.active
  if not a or a.battle~=battle or not self.voxelCompat then return nil end
  local staged=self.voxelCompat:state(battle)
  if not (staged and (staged.provider=="potato_voxel" or staged.provider=="battle_art")) then return nil end
  local f=a.frame
  for _,e in ipairs(a.plan.events or {}) do
    if e.kind=="battler_affine_sequence" and e.sequence=="minimize"
       and f>=e.frame and f<(e.destroyFrame or e.frame) then
      local battler=motionBattler(a,e.battler or "attacker")
      if not battler then return nil end
      local img=self.voxelCompat:battlerImage(battle,battler)
      if not img then return nil end
      local age=math.max(0,math.floor(f-e.frame))
      local clones={}
      for _,base in ipairs({0,34,68}) do
        for _,localStart in ipairs({0,3,6}) do
          local born=base+localStart
          if age>=born and age<born+16 then
            local native=256+40*localStart
            clones[#clones+1]={scale=256/native,alpha=e.cloneAlpha or (10/16)}
          end
        end
      end
      if #clones==0 then return nil end
      return {
        battler=battler,image=img,clones=clones,
        mirrorX=self.voxelCompat:mirrorX(staged,battler),
      }
    end
  end
  return nil
end

function M:nightShadeWorldClone(battle)
  local a=self.active
  if not a or a.battle~=battle then return nil end
  if not (self.voxelCompat and self.voxelCompat:state(battle)) then return nil end
  local staged=self.voxelCompat:state(battle)
  if not (staged and (staged.provider=="potato_voxel" or staged.provider=="battle_art")) then return nil end
  local f=a.frame
  for _,e in ipairs(a.plan.events or {}) do
    if e.kind=="night_shade_clone" and f>=e.frame and f<(e.destroyFrame or e.frame) then
      local battler=motionBattler(a,e.battler or "attacker")
      if not battler then return nil end
      local age=f-e.frame
      local fade=e.fadeFrames or 27
      local hold=e.holdFrames or 0
      local eva=math.min(9,math.max(0,math.floor(age/3)))
      local scale=2
      local shrinkStart=fade+hold
      if age>=shrinkStart then
        local step=math.min(15,age-shrinkStart+1)
        local gbaScale=128+8*step
        scale=256/gbaScale
      end
      local img=self.voxelCompat:battlerImage(battle,battler)
      if not img then return nil end
      return {
        battler=battler,
        image=img,
        scale=scale,
        alpha=eva/16,
        mirrorX=self.voxelCompat:mirrorX(staged,battler),
      }
    end
  end
  return nil
end

-- Potato Voxel battler-texture affine compatibility. This is the safe,
-- renderer-independent path proven by Skull Bash tilt and Growth scaling:
-- transform only the already-generated battler texture around Potato's own
-- anchor. Supported state is deliberately narrow: rotation, X/Y scale and the
-- small Skull Bash X offset. Visibility, general movement and clones remain
-- separate systems.
function M:voxelBattlerAffine(battle, forcePotato, providerHint)
  local a=self.active
  if not a or a.battle~=battle or not self.voxelCompat then return nil end
  local staged=self.voxelCompat:state(battle)
  -- When called from Potato's own BattleScene.render hook, provider identity is
  -- already authoritative. voxelCompat:state() can briefly be unavailable
  -- while Transform refreshes the battler image, which used to suppress the
  -- mosaic descriptor even though the render is unquestionably Potato.
  if not forcePotato and not (staged and (staged.provider=="potato_voxel" or staged.provider=="battle_art")) then return nil end
  local f=a.frame
  local out={}
  local function put(battler,angle,dx)
    angle=tonumber(angle) or 0
    dx=tonumber(dx) or 0
    if battler and (math.abs(angle)>0.000001 or math.abs(dx)>0.000001) then
      out[battler.isPlayer and "player" or "enemy"]={battler=battler,angle=angle,dx=dx}
    end
  end

  for _,e in ipairs(a.plan.events or {}) do
    if e.kind=="battler_scale"
       and f>=e.frame and f<(e.destroyFrame or e.frame) then
      local battler=motionBattler(a,e.battler)
      if battler then
        local sx,sy=1,1
        if e.fixedNativeScale then
          -- FireRed affine matrices are inverse sampling scales: 0xD0 makes
          -- the visible sprite 256/208 ~= 1.2308x larger. Keep X/Y separate
          -- if a future fixed task supplies distinct native values.
          local nx=tonumber(e.fixedNativeScaleX or e.fixedNativeScale) or 256
          local ny=tonumber(e.fixedNativeScaleY or e.fixedNativeScale) or 256
          sx=256/math.max(1,nx)
          sy=256/math.max(1,ny)
        else
          local age=math.max(0,math.floor(f-e.frame))
          local d=math.max(1,math.floor(tonumber(e.scaleDuration) or 1))
          local dx=tonumber(e.xDelta) or 0
          local dy=tonumber(e.yDelta) or 0
          local step
          if age < d then
            step=age+1
          elseif age < d*2 then
            step=math.max(0,d-(age-d+1))
          else
            step=0
          end
          local nativeX=256+dx*step
          local nativeY=256+dy*step
          sx=256/math.max(1,nativeX)
          sy=256/math.max(1,nativeY)
        end
        if math.abs(sx-1)>0.000001 or math.abs(sy-1)>0.000001 then
          local key=battler.isPlayer and "player" or "enemy"
          out[key]=out[key] or {battler=battler,angle=0,dx=0}
          out[key].scaleX=sx
          out[key].scaleY=sy
        end
      end
    elseif e.kind=="battler_mosaic" and f>=e.frame and f<(e.destroyFrame or e.frame) then
      local battler=motionBattler(a,e.battler or "attacker")
      if battler then
        local age=math.max(0,math.floor(f-e.frame))
        local stretch
        if age<=0 then stretch=0
        elseif age<=45 then stretch=math.min(15,math.floor((age+2)/3))
        elseif age<=47 then stretch=15
        else stretch=math.max(0,15-math.floor((age-45)/3)) end
        local key=battler.isPlayer and "player" or "enemy"
        if stretch>0 then
          out[key]=out[key] or {battler=battler,angle=0,dx=0}
          out[key].mosaicSize=stretch+1
        end
        -- FireRed swaps the battler's graphics while REG_MOSAIC is fully
        -- closed, then reveals the transformed species as the mosaic opens.
        -- Keep gen1recomp's real Transform state change authoritative, but
        -- supply its own Transform-specific side-correct species image to the
        -- Potato texture path from the exact midpoint onward.
        if age >= (tonumber(e.swapAge) or 47) and a.targetBattler then
          -- Battle Art's Transform marker makes its own generated battler
          -- texture switch to the copied species (including animated art).
          -- Do not overwrite that texture with Gen1Recomp's plain sprite.
          local provider=(staged and staged.provider) or providerHint
          if provider~="battle_art" and type(battle.speciesSprite)=="function" then
            local species=a.targetBattler.mon and a.targetBattler.mon.species
            if species then
              local ok,img=pcall(battle.speciesSprite,battle,species,battler.isPlayer==true)
              if ok and img then
                out[key]=out[key] or {battler=battler,angle=0,dx=0}
                out[key].replacementImage=img
              end
            end
          end
        end
      end
    elseif e.kind=="battler_affine_sequence" and e.sequence=="defense_curl"
       and f>=e.frame and f<(e.destroyFrame or e.frame) then
      local battler=motionBattler(a,e.battler or "attacker")
      if battler then
        local age=math.max(0,math.floor(f-e.frame))
        local localAge=age%16
        local step=(localAge<8) and (localAge+1) or math.max(0,15-localAge)
        local nativeX=256-12*step
        local nativeY=256+20*step
        local sx=256/math.max(1,nativeX)
        local sy=256/math.max(1,nativeY)
        local key=battler.isPlayer and "player" or "enemy"
        out[key]=out[key] or {battler=battler,angle=0,dx=0}
        out[key].scaleX=sx; out[key].scaleY=sy
      end
    elseif e.kind=="battler_affine_sequence" and e.sequence=="meditate"
       and f>=e.frame and f<(e.destroyFrame or e.frame) then
      local battler=motionBattler(a,e.battler or "attacker")
      if battler then
        local age=math.max(0,math.floor(f-e.frame))
        local nativeX,nativeY=256,256
        if age < 16 then
          local n=age+1
          nativeX=256-8*n; nativeY=256+10*n
        elseif age < 32 then
          local n=age-15
          nativeX=128+18*n; nativeY=416-18*n
        else
          local n=math.min(8,age-31)
          nativeX=416-20*n; nativeY=128+16*n
        end
        local sx=256/math.max(1,nativeX)
        local sy=256/math.max(1,nativeY)
        local key=battler.isPlayer and "player" or "enemy"
        out[key]=out[key] or {battler=battler,angle=0,dx=0}
        out[key].scaleX=sx; out[key].scaleY=sy
      end
    elseif e.kind=="battler_affine_sequence" and e.sequence=="splash"
       and f>=e.frame and f<(e.destroyFrame or e.frame) then
      local battler=motionBattler(a,e.battler or "attacker")
      if battler then
        local age=math.max(0,math.floor(f-e.frame))
        local hop=age%38
        local nativeX,nativeY=256,256
        local dy=0
        if hop < 8 then
          local n=hop+1
          nativeX=256-6*n; nativeY=256+4*n
          dy=-3*n
        elseif hop < 16 then
          local n=hop-7
          nativeX=208+10*n; nativeY=288-10*n
          dy=-24
        elseif hop < 29 then
          -- During FireRed states 2/transition the affine matrix is held at
          -- the end of command 2 while y2 rises back by two pixels per tick.
          nativeX=288; nativeY=208
          local n=math.min(12,hop-15)
          dy=-math.max(0,24-2*n)
        elseif hop < 37 then
          local n=hop-28
          nativeX=288-4*n; nativeY=208+6*n
          dy=0
        else
          nativeX=256; nativeY=256; dy=0
        end
        local sx=256/math.max(1,nativeX)
        local sy=256/math.max(1,nativeY)
        local key=battler.isPlayer and "player" or "enemy"
        out[key]=out[key] or {battler=battler,angle=0,dx=0}
        out[key].scaleX=sx; out[key].scaleY=sy; out[key].dy=dy
      end
    elseif e.kind=="battler_acid_armor"
       and f>=e.frame and f<(e.destroyFrame or e.frame) then
      local battler=motionBattler(a,e.battler or "attacker")
      if battler then
        local age=math.max(0,math.floor(f-e.frame))
        local alpha
        if age < 32 then alpha=15/16
        elseif age < 64 then
          local k=age-31
          alpha=math.max(0,(16-math.ceil(k/2))/16)
        elseif age < 77 then alpha=0
        elseif age < 109 then
          local k=age-76
          alpha=math.min(1,math.ceil(k/2)/16)
        else alpha=1 end
        local key=battler.isPlayer and "player" or "enemy"
        out[key]=out[key] or {battler=battler,angle=0,dx=0}
        out[key].acidArmor={age=age,alpha=alpha}
      end
    elseif e.kind=="battler_affine_sequence"
       and e.sequence=="minimize"
       and f>=e.frame and f<(e.destroyFrame or e.frame) then
      local battler=motionBattler(a,e.battler or "attacker")
      if battler then
        local age=math.max(0,math.floor(f-e.frame))
        local function nativeScaleAt(t)
          if t<=31 then return 256+40*(t+1) end
          if t<=33 then return 256 end
          if t<=65 then return 256+40*(t-33) end
          if t<=67 then return 256 end
          if t<=99 then return 256+40*(t-67) end
          if t<=133 then return 1536 end
          if t<=149 then return math.max(256,1536-80*(t-133)) end
          return 256
        end
        local k=256/math.max(1,nativeScaleAt(age))
        if math.abs(k-1)>0.000001 then
          local key=battler.isPlayer and "player" or "enemy"
          out[key]=out[key] or {battler=battler,angle=0,dx=0}
          out[key].scaleX=k
          out[key].scaleY=k
        end
      end
    elseif e.kind=="battler_affine_sequence"
       and (e.sequence=="skull_bash_set" or e.sequence=="skull_bash_reset")
       and f>=e.frame and f<(e.destroyFrame or e.frame) then
      local battler=motionBattler(a,e.battler)
      if battler then
        local age=math.max(0,math.floor(f-e.frame))
        local side=(battler.isPlayer and -1 or 1)
        local angleUnits,dx=0,0
        if e.sequence=="skull_bash_set" then
          if age < 8 then
            dx=side*3*(age+1)
          elseif age < 17 then
            dx=side*24
            local r=math.max(0,math.min(8,age-8))
            angleUnits=side*0xC0*r
          elseif age < 34 then
            local r=math.max(0,math.min(8,math.floor((age-18)/2)+1))
            dx=side*24
            if age>=18 then
              local wob=((r%2)==1) and 2 or -2
              dx=dx+side*wob
            end
            angleUnits=side*0x600
          elseif age < 48 then
            dx=side*24
            angleUnits=side*0x600
          elseif age < 51 then
            dx=side*math.max(0,24-8*(age-47))
            angleUnits=side*0x600
          else
            angleUnits=side*0x600
          end
        else
          local r=math.max(0,math.min(8,age+1))
          angleUnits=side*math.max(0,0x600-0xC0*r)
        end
        -- Same GBA inverse-affine -> visible LÖVE sign conversion as the 2D path.
        put(battler,-angleUnits*math.pi*2/65536,dx)
      end
    elseif e.kind=="battler_rotate" and f>=e.frame and f<(e.destroyFrame or e.frame) then
      local battler=motionBattler(a,e.battler)
      if battler then
        local age=f-e.frame
        local d=math.max(1,e.turnFrames or 1)
        local hold=math.max(0,math.floor(tonumber(e.holdFrames) or 0))
        local steps
        if age<d then
          steps=age+1
        elseif age<d+hold then
          steps=d
        else
          steps=math.max(0,2*d+hold-(age+1))
        end
        local nativeDelta=tonumber(e.rotationDelta) or 0
        local signedStep=(battler.isPlayer and -nativeDelta or nativeDelta)
        local angle=signedStep*steps*math.pi*2/65536
        if e.invertVisibleRotation then angle=-angle end
        put(battler,angle)
      end
    end
  end

  local battler=a.attackerBattler
  if battler then
    local _,bowAngleUnits=bowMonState(a.plan,f,battler)
    if bowAngleUnits~=0 then
      local bowX=select(1,bowMonState(a.plan,f,battler)) or 0
      put(battler,-bowAngleUnits*math.pi*2/65536,bowX)
    end
  end
  return next(out) and out or nil
end

-- Backward-compatible name used by v0.55.43/44 main.lua.
M.voxelBattlerTilt = M.voxelBattlerAffine


local function hazeFogState(a,frame)
  if not a then return nil end
  for _,e in ipairs(a.plan.events or {}) do
    if e.kind=="haze_scrolling_fog" and frame>=e.frame and frame<(e.destroyFrame or e.frame) then
      local age=math.max(0,math.floor(frame-e.frame))
      local amounts=e.amounts or {0,1,2,2,2,2,3,4,4,4,5,6,6,6,6,7,8,8,8,9}
      local amount
      local fadeIn=e.fadeIn or ((#amounts-1)*4)
      local hold=e.hold or 81
      if age<fadeIn then
        local idx=math.min(#amounts,math.floor(age/4)+1)
        amount=amounts[idx] or 0
      elseif age<fadeIn+hold then
        amount=9
      else
        local n=math.floor((age-(fadeIn+hold))/4)
        amount=math.max(0,9-n)
      end
      return e,age,amount/16
    end
  end
end

local function ensureHazeFogImage(self)
  if self._hazeFogImage~=nil then return self._hazeFogImage or nil end
  self._hazeFogImage=false
  local assets=self.battleBgAssets
  if not assets then return nil end
  local img=assets:image("haze")
  if not img and type(assets.prepare)=="function" then
    local ok=pcall(assets.prepare,assets,"haze")
    if ok then img=assets:image("haze") end
  end
  if img then
    if img.setFilter then pcall(img.setFilter,img,"nearest","nearest") end
    if img.setWrap then pcall(img.setWrap,img,"repeat","repeat") end
    self._hazeFogImage=img
    return img
  end
  return nil
end

function M:draw(battle,opts)
  local a = self.active
  if not a or a.battle ~= battle then return end
  if not (love and love.graphics) then return end
  local g = love.graphics
  local f = a.frame
  local effectLayerOnly = type(opts)=="table" and opts.effectLayerOnly==true
  local battlerLayerOnly = type(opts)=="table" and opts.battlerLayerOnly==true
  local voxelCategory = type(opts)=="table" and opts.voxelCategory or nil
  local voxelSide = type(opts)=="table" and opts.voxelSide or nil
  g.setColor(1,1,1,1)
  -- FireRed Acid Armor: the attacker itself is moved to a BG layer, distorted
  -- scanline-by-scanline, faded fully out, held invisible for 13 callbacks,
  -- then faded back in. Rebuild only that battler into an off-screen layer and
  -- slice it horizontally so the rest of the battle/HUD is never distorted.
  if not effectLayerOnly and type(battle.drawPicsLayer)=="function" and a.motionOwned then
    for _,e in ipairs(a.plan.events or {}) do
      if e.kind=="battler_acid_armor" and f>=e.frame and f<(e.destroyFrame or e.frame) then
        local battler=motionBattler(a,e.battler or "attacker")
        local snap=battler and a.motionOwned[battler]
        if battler and snap and snap.pf then
          local age=math.max(0,math.floor(f-e.frame))
          local alpha
          if age < 32 then alpha=15/16
          elseif age < 64 then
            local k=age-31
            alpha=math.max(0,(16-math.ceil(k/2))/16)
          elseif age < 77 then alpha=0
          elseif age < 109 then
            local k=age-76
            alpha=math.min(1,math.ceil(k/2)/16)
          else alpha=1 end

          if alpha>0 then
            local staged=self.voxelCompat and self.voxelCompat:state(battle) or nil
            local drewStaged=staged and (staged.provider=="potato_voxel" or staged.provider=="battle_art") or false
            -- Potato Voxel handles Acid Armor on the real in-world battler
            -- texture inside BattleScene.render. Do not draw a second copy in
            -- battle.overlay, which would snap back to the authored HUD anchor.
            -- Other staged providers keep the existing projected fallback.
            -- In staged battles, draw from the renderer-neutral battler image at
            -- its authored animation anchor. Horizontal sine displacement keeps
            -- the same melt/wave character while the staged layer applies its
            -- own world projection exactly once.
            if not drewStaged and staged and self.voxelCompat then
              local img=self.voxelCompat:battlerImage(battle,battler)
              local anchor=self.voxelCompat:authoredAnchor(staged,battler)
              if img and anchor and type(img.getDimensions)=="function" then
                local iw,ih=img:getDimensions()
                local mirror=self.voxelCompat:mirrorX(staged,battler)
                local sx=mirror and -1 or 1
                local x0=anchor[1]-iw/2
                -- BattleStage authored anchors are battler FEET/baselines, not
                -- image centres. Acid Armor replaces the live battler with a
                -- sliced copy, so centre-anchoring Y lifted that copy by half
                -- its image height at the handoff. Preserve the exact native
                -- baseline and let only the scanline task move individual rows.
                local y0=anchor[2]-ih
                g.push("all")
                g.setColor(1,1,1,alpha)
                for yy=0,ih-1 do
                  local phase=((age*2)+(yy*10))%256
                  local wave=math.sin(phase*math.pi*2/256)*4
                  local melt=0
                  if age<64 then
                    local d6=math.min(64,32+age)
                    melt=(yy-ih/2)*(1-(32/d6))*0.35
                  end
                  local quad=g.newQuad(0,yy,iw,1,iw,ih)
                  local dx=wave
                  if sx<0 then
                    g.draw(img,quad,x0+iw+dx,y0+yy-melt,0,-1,1)
                  else
                    g.draw(img,quad,x0+dx,y0+yy-melt)
                  end
                end
                g.pop()
                drewStaged=true
              end
            end
            if not drewStaged then
              local w,h=g.getDimensions()
              local okCanvas,layer=pcall(g.newCanvas,w,h)
              if okCanvas and layer then
                local prev=g.getCanvas and g.getCanvas() or nil
                local wasHidden=snap.pf.hidden
                snap.pf.hidden=nil
                g.push("all")
                g.setCanvas(layer); g.clear(0,0,0,0); g.origin(); g.setColor(1,1,1,1)
                pcall(battle.drawPicsLayer,battle,0,0,0,battler.isPlayer and "player" or "enemy",true)
                g.setCanvas(prev); g.pop()
                snap.pf.hidden=wasHidden
                g.push("all")
                g.setColor(1,1,1,alpha)
                -- FireRed AnimTask_AcidArmor keeps the scanline DESTINATION
                -- fixed and changes the source row via BG vertical scroll. The
                -- previous implementation moved each destination row upward,
                -- which made the whole mon appear to jump before the melt.
                -- Preserve the battler's exact screen baseline and sample rows
                -- from progressively farther upward instead.
                -- Gen1Recomp draws both battlers into fixed 56x56 picture
                -- slots: player y=40..95, enemy y=0..55. Acid Armor must
                -- distort that actual battler tile region, not the previous
                -- guessed 66-line band (62..127 / 22..87), which sampled rows
                -- below the Pokemon and produced a pinned horizontal line.
                local top=battler.isPlayer and 40 or 0
                local bottom=math.min(h-1,top+55)
                -- Gen1Recomp/LÖVE cannot reproduce the GBA BG vertical-scroll
                -- sampling literally here: resampling rows outside the 56x56
                -- battler tile pulls transparent pixels into the replacement
                -- layer and makes the Pokemon visibly shrink. Preserve each
                -- battler row 1:1 and reproduce Acid Armor's scanline wave in
                -- place; FireRed's alpha/fade phases above remain unchanged.
                for destY=bottom,top,-1 do
                  local i=bottom-destY
                  local phase=((age*2)+(i*10))%256
                  local wave=math.sin(phase*math.pi*2/256)*4
                  local quad=g.newQuad(0,destY,w,1,w,h)
                  g.draw(layer,quad,wave,destY)
                end
                g.pop()
              end
            end
          end
        end
      end
    end
  end
  -- FireRed Double Team: draw the two cloned attacker OBJs. Their x offsets
  -- reproduce AnimDoubleTeam's integer GBA sine-table math rather than using
  -- generic afterimages. Flat battles tint the clones by the exact 11/16
  -- palette blend toward black. Battle Art keeps its projected compatibility
  -- path; Potato draws these copies later as true world-space billboards.
  if not effectLayerOnly and type(battle.drawPicsLayer)=="function" then
    for _,e in ipairs(a.plan.events) do
      if e.kind=="double_team_clones" and f>=e.frame and f<(e.destroyFrame or e.frame) then
        local battler=motionBattler(a,e.battler or "attacker")
        if battler then
          local dx0,dx1=doubleTeamCloneOffsets(e,f)
          local staged=self.voxelCompat and self.voxelCompat:state(battle) or nil
          local stagedOwned=staged and staged.ownership and staged.ownership.battlers
          if stagedOwned and self.voxelCompat then
            if (staged.provider~="potato_voxel" and staged.provider~="battle_art") then
              self.voxelCompat:drawBattlerImage(staged,battle,battler,{dx=dx0,alpha=e.cloneAlpha or 0.75})
              self.voxelCompat:drawBattlerImage(staged,battle,battler,{dx=dx1,alpha=e.cloneAlpha or 0.75})
            end
          else
            local w,h=g.getDimensions()
            local layer=nil
            local okCanvas,canvas=pcall(g.newCanvas,w,h)
            if okCanvas and canvas then
              layer=canvas
              local prevCanvas=g.getCanvas and g.getCanvas() or nil
              g.push("all")
              g.setCanvas(layer)
              g.clear(0,0,0,0)
              g.origin()
              g.setColor(1,1,1,1)
              -- Double Team hides the real battler through picFx.hidden, but
              -- the clone source still needs that same image. Temporarily
              -- expose it only inside this off-screen capture.
              local clonePf=nil
              local cloneHidden=nil
              if type(battle.picFxFor)=="function" then
                local okPf,pf=pcall(battle.picFxFor,battle,battler)
                if okPf and pf then
                  clonePf=pf
                  cloneHidden=pf.hidden
                  pf.hidden=false
                end
              end
              pcall(battle.drawPicsLayer,battle,0,0,0,battler.isPlayer and "player" or "enemy",true)
              if clonePf then clonePf.hidden=cloneHidden end
              g.setCanvas(prevCanvas)
              g.pop()
            end
            if layer then
              local d=e.darkMul or (5/16)
              local alpha=e.cloneAlpha or (12/16)
              g.push("all")
              g.setColor(d,d,d,alpha)
              g.draw(layer,dx0,0)
              g.draw(layer,dx1,0)
              g.pop()
            end
          end
        end
      end
    end
  end

  -- FireRed Night Shade: monbg leaves the normal attacker image in place while
  -- the live attacker OBJ is enlarged, alpha-blended, then shrunk back toward
  -- normal size. In Potato Voxel this clone belongs to the in-world effect
  -- billboard, not to the HUD/battler overlay: draw it in authored animation
  -- coordinates when effectLayerOnly is requested and let Potato's fxCard()
  -- place it in the 3D arena. Other staged renderers keep the projected
  -- battler-overlay path, and flat battles keep the established isolated
  -- canvas path.
  if type(battle.drawPicsLayer)=="function" then
    for _,e in ipairs(a.plan.events) do
      if e.kind=="night_shade_clone" and f>=e.frame and f<(e.destroyFrame or e.frame) then
        local battler=motionBattler(a,e.battler or "attacker")
        if battler then
          local age=f-e.frame
          local fade=e.fadeFrames or 27
          local hold=e.holdFrames or 0
          local eva=math.min(9,math.max(0,math.floor(age/3)))
          local scale=2
          local shrinkStart=fade+hold
          if age>=shrinkStart then
            local step=math.min(15,age-shrinkStart+1)
            local gbaScale=128+8*step
            scale=256/gbaScale
          end
          local cx=battler.isPlayer and 40 or 120
          -- Flat 2D Night Shade should scale from the battler's feet, not its
          -- sprite centre.  FireRed's enlarged live OBJ remains grounded while
          -- growing upward; using the centre anchor made the clone expand both
          -- up and down in Gen1Recomp.  Keep voxel/staged paths unchanged.
          local cy=battler.isPlayer and 96 or 56
          local staged=self.voxelCompat and self.voxelCompat:state(battle) or nil
          local stagedOwned=staged and staged.ownership and staged.ownership.battlers
          local stagedDrawn=false

          if stagedOwned and self.voxelCompat then
            if (staged.provider=="potato_voxel" or staged.provider=="battle_art") then
              -- Night Shade has its own dedicated camera-facing world
              -- billboard in the Potato bridge. Do not bake it into the
              -- shared two-battler fxCard plane: that plane is intentionally
              -- sloped between the two authored slot anchors, which makes a
              -- battler clone lean toward its target and also runs its alpha
              -- through the generic effect texture path.
              stagedDrawn=true
            elseif not effectLayerOnly then
              stagedDrawn=self.voxelCompat:drawBattlerImage(staged,battle,battler,{
                scale=scale,alpha=eva/16
              })
            end
          end

          if not stagedDrawn and not effectLayerOnly then
            local w,h=g.getDimensions()
            local cloneCanvas=nil
            local okCanvas,canvas=pcall(g.newCanvas,w,h)
            if okCanvas and canvas then
              cloneCanvas=canvas
              local prevCanvas=g.getCanvas and g.getCanvas() or nil
              g.push("all")
              g.setCanvas(cloneCanvas)
              g.clear(0,0,0,0)
              g.origin()
              g.setColor(1,1,1,1)
              pcall(battle.drawPicsLayer,battle,0,0,0,battler.isPlayer and "player" or "enemy",true)
              g.setCanvas(prevCanvas)
              g.pop()
            end

            g.push()
            g.translate(cx,cy); g.scale(scale,scale); g.translate(-cx,-cy)
            g.setColor(1,1,1,eva/16)
            if cloneCanvas then
              g.draw(cloneCanvas,0,0)
            else
              pcall(battle.drawPicsLayer,battle,0,0,0,battler.isPlayer and "player" or "enemy",true)
            end
            g.setColor(1,1,1,1)
            g.pop()
          end
        end
      end
    end
  end

  if not effectLayerOnly then
  -- FireRed Transform mosaic. The native REG_MOSAIC OBJ field expands each
  -- source texel into (stretch+1)x(stretch+1) blocks. Render only the live
  -- attacker through a nearest-neighbour down/up pass; the host still owns
  -- the actual transformed species/state switch.
  if type(battle.drawPicsLayer)=="function" and a.motionOwned then
    for _,e in ipairs(a.plan.events) do
      if e.kind=="battler_mosaic" and f>=e.frame and f<(e.destroyFrame or e.frame) then
        local battler=motionBattler(a,e.battler or "attacker")
        local snap=battler and a.motionOwned[battler]
        local staged=self.voxelCompat and self.voxelCompat:state(battle) or nil
        local potato=staged and (staged.provider=="potato_voxel" or staged.provider=="battle_art") and staged.ownership and staged.ownership.battlers
        if battler and snap and snap.pf and not potato then
          local age=math.max(0,math.floor(f-e.frame))
          local stretch
          if age<=0 then stretch=0 elseif age<=45 then stretch=math.min(15,math.floor((age+2)/3)) elseif age<=47 then stretch=15 else stretch=math.max(0,15-math.floor((age-45)/3)) end
          local block=stretch+1
          if block>1 then
            local w,h=g.getDimensions()
            a.transformMosaic=a.transformMosaic or {}
            local src=a.transformMosaic.src
            if not src or src:getWidth()~=w or src:getHeight()~=h then
              src=g.newCanvas(w,h,{dpiscale=1}); pcall(src.setFilter,src,"nearest","nearest"); a.transformMosaic.src=src
            end
            local lw,lh=math.max(1,math.ceil(w/block)),math.max(1,math.ceil(h/block))
            local low=a.transformMosaic.low
            if not low or low:getWidth()~=lw or low:getHeight()~=lh then
              low=g.newCanvas(lw,lh,{dpiscale=1}); pcall(low.setFilter,low,"nearest","nearest"); a.transformMosaic.low=low
            end
            local prev=g.getCanvas and g.getCanvas() or nil
            g.push("all"); g.origin(); g.setCanvas(src); g.clear(0,0,0,0); g.setColor(1,1,1,1)
            local was=snap.pf.hidden; snap.pf.hidden=nil
            -- The Transform midpoint display sprite is latched by
            -- applyBattlerMotion, so drawPicsLayer naturally reveals that same
            -- transformed image as the mosaic opens.  Do not restore the old
            -- sprite here; doing so caused a one-frame flash before the host's
            -- real Transform update.
            pcall(battle.drawPicsLayer,battle,0,0,0,battler.isPlayer and "player" or "enemy",true)
            snap.pf.hidden=was
            g.setCanvas(low); g.clear(0,0,0,0); g.setColor(1,1,1,1); g.draw(src,0,0,0,lw/w,lh/h)
            if prev then g.setCanvas(prev) else g.setCanvas() end
            g.setColor(1,1,1,1); g.draw(low,0,0,0,w/lw,h/lh); g.pop()
          end
        end
      end
    end
  end

  -- FireRed Mimic target-copy task. The normal target remains visible (the
  -- role of monbg_static); this draws the shrinking/moving OBJ copy on top.
  if type(battle.drawPicsLayer)=="function" and a.motionOwned then
    for _,e in ipairs(a.plan.events) do
      if e.kind=="battler_mimic_copy" and f>=e.frame and f<(e.destroyFrame or e.frame) then
        local battler=motionBattler(a,e.battler or "target")
        local snap=battler and a.motionOwned[battler]
        if battler and snap and snap.pf then
          local age=math.max(0,math.floor(f-e.frame))
          local step=math.min(e.steps or 24,math.max(0,age))
          local native=256+16*step
          local scale=256/math.max(1,native)
          local xpix=math.floor(((e.xStep or 128)*step)/256)
          if not battler.isPlayer then xpix=-xpix end
          local staged=self.voxelCompat and self.voxelCompat:state(battle) or nil
          local stagedOwned=staged and staged.ownership and staged.ownership.battlers
          local drawn=false
          if stagedOwned and self.voxelCompat then
            -- Mimic's GBA SetBattlerSpriteYOffsetFromYScale correction is
            -- expressed in the 64px OBJ sprite box. Applying the same formula
            -- to a voxel provider's full battler texture can turn a few GBA
            -- pixels into a large downward lurch. Keep the projected/world
            -- anchor fixed in voxel and apply only Mimic's authored sideways
            -- travel + shrink; the 2D path below retains the exact GBA pivot.
            drawn=self.voxelCompat:drawBattlerImage(staged,battle,battler,{scale=scale,alpha=1,dx=xpix,dy=0})
          end
          if not drawn and not stagedOwned then
            local was=snap.pf.hidden; snap.pf.hidden=nil
            local pivotX=battler.isPlayer and 40 or 120
            local pivotY=battler.isPlayer and 96 or 56
            g.push("all")
            g.translate(xpix,0)
            g.translate(pivotX,pivotY); g.scale(scale,scale); g.translate(-pivotX,-pivotY)
            pcall(battle.drawPicsLayer,battle,0,0,0,battler.isPlayer and "player" or "enemy",true)
            g.pop()
            snap.pf.hidden=was
          end
          g.setColor(1,1,1,1)
        end
      end
    end
  end

  -- FireRed Minimize affine task. Draw the live battler through the exact
  -- inverse GBA affine scale and preserve its lower edge, matching
  -- SetBattlerSpriteYOffsetFromYScale. Three translucent traces are cloned at
  -- callbacks 0/3/6 of each shrink pass and persist for 16 callbacks.
  if type(battle.drawPicsLayer)=="function" and a.motionOwned then
    for _,e in ipairs(a.plan.events) do
      if e.kind=="battler_affine_sequence" and e.sequence=="minimize"
         and f>=e.frame and f<(e.destroyFrame or e.frame) then
        local battler=motionBattler(a,e.battler or "attacker")
        local snap=battler and a.motionOwned[battler]
        if battler and snap and snap.pf then
          local age=math.max(0,math.floor(f-e.frame))
          local function nativeScaleAt(t)
            if t<=31 then return 256+40*(t+1) end
            if t<=33 then return 256 end
            if t<=65 then return 256+40*(t-33) end
            if t<=67 then return 256 end
            if t<=99 then return 256+40*(t-67) end
            if t<=133 then return 1536 end
            if t<=149 then return math.max(256,1536-80*(t-133)) end
            return 256
          end
          local mainScale=256/math.max(1,nativeScaleAt(age))
          local cloneDefs={}
          for _,base in ipairs({0,34,68}) do
            for _,localStart in ipairs({0,3,6}) do
              local born=base+localStart
              if age>=born and age<born+16 then
                local native=256+40*localStart
                cloneDefs[#cloneDefs+1]={scale=256/native,alpha=e.cloneAlpha or (10/16)}
              end
            end
          end

          local staged=self.voxelCompat and self.voxelCompat:state(battle) or nil
          local stagedOwned=staged and staged.ownership and staged.ownership.battlers
          local function drawVoxel(scale,alpha)
            if not (stagedOwned and self.voxelCompat) then return false end
            local img=self.voxelCompat:battlerImage(battle,battler)
            local dy=0
            if img and type(img.getDimensions)=="function" then
              local _,ih=img:getDimensions()
              dy=(ih*(1-scale))/2
            end
            return self.voxelCompat:drawBattlerImage(staged,battle,battler,{scale=scale,alpha=alpha or 1,dy=dy})
          end

          if stagedOwned then
            if (staged.provider=="potato_voxel" or staged.provider=="battle_art") then
              -- The real Potato card is scaled by voxelBattlerAffine() through
              -- the safe texture-transform path in main.lua. Its translucent
              -- Minimize traces are drawn later as world-local billboards, so
              -- nothing from this battler-owned branch should fall back to the
              -- 2D HUD.
            else
              for _,cl in ipairs(cloneDefs) do drawVoxel(cl.scale,cl.alpha) end
              drawVoxel(mainScale,1)
            end
          else
            -- Render the battler once into a transparent layer, then reuse it
            -- for all traces and the live shrunken copy. This avoids multiple
            -- host battler redraws and preserves alpha correctly even though
            -- drawPicsLayer resets Love2D draw color internally.
            local w,h=g.getDimensions()
            local layer=nil
            local okCanvas,canvas=pcall(g.newCanvas,w,h)
            if okCanvas and canvas then
              layer=canvas
              local prevCanvas=g.getCanvas and g.getCanvas() or nil
              local wasHidden=snap.pf.hidden
              snap.pf.hidden=nil
              g.push("all")
              g.setCanvas(layer)
              g.clear(0,0,0,0)
              g.origin()
              g.setColor(1,1,1,1)
              pcall(battle.drawPicsLayer,battle,0,0,0,battler.isPlayer and "player" or "enemy",true)
              g.setCanvas(prevCanvas)
              g.pop()
              snap.pf.hidden=wasHidden
            end
            local pivotX=battler.isPlayer and 40 or 120
            local pivotY=battler.isPlayer and 96 or 56
            local function drawLayer(scale,alpha)
              if not layer then return end
              g.push("all")
              g.translate(pivotX,pivotY); g.scale(scale,scale); g.translate(-pivotX,-pivotY)
              g.setColor(1,1,1,alpha or 1)
              g.draw(layer,0,0)
              g.pop()
            end
            for _,cl in ipairs(cloneDefs) do drawLayer(cl.scale,cl.alpha) end
            drawLayer(mainScale,1)
          end
          g.setColor(1,1,1,1)
        end
      end
    end
  end

  -- FireRed Splash: three source-faithful 38-frame squash/stretch hops.
  -- Scaling is around the battler baseline, which reproduces
  -- SetBattlerSpriteYOffsetFromYScale without center-pivot drift.
  if type(battle.drawPicsLayer)=="function" and a.motionOwned then
    for _,e in ipairs(a.plan.events) do
      if e.kind=="battler_affine_sequence" and e.sequence=="splash"
         and f>=e.frame and f<(e.destroyFrame or e.frame) then
        local battler=motionBattler(a,e.battler or "attacker")
        local snap=battler and a.motionOwned[battler]
        if battler and snap and snap.pf then
          local staged=self.voxelCompat and self.voxelCompat:state(battle) or nil
          local potato=staged and staged.ownership and staged.ownership.battlers
            and (staged.provider=="potato_voxel" or staged.provider=="battle_art")
          if not potato then
            local age=math.max(0,math.floor(f-e.frame))
            local hop=age%38
            local nativeX,nativeY,dy=256,256,0
            if hop < 8 then
              local n=hop+1; nativeX=256-6*n; nativeY=256+4*n; dy=-3*n
            elseif hop < 16 then
              local n=hop-7; nativeX=208+10*n; nativeY=288-10*n; dy=-24
            elseif hop < 29 then
              nativeX=288; nativeY=208
              local n=math.min(12,hop-15); dy=-math.max(0,24-2*n)
            elseif hop < 37 then
              local n=hop-28; nativeX=288-4*n; nativeY=208+6*n
            end
            local sx=256/math.max(1,nativeX)
            local sy=256/math.max(1,nativeY)
            local pivotX=battler.isPlayer and 40 or 120
            local pivotY=battler.isPlayer and 96 or 56
            local wasHidden=snap.pf.hidden; snap.pf.hidden=nil
            g.push()
            g.translate(0,dy)
            g.translate(pivotX,pivotY); g.scale(sx,sy); g.translate(-pivotX,-pivotY)
            pcall(battle.drawPicsLayer,battle,0,0,0,battler.isPlayer and "player" or "enemy",true)
            g.pop(); snap.pf.hidden=wasHidden; g.setColor(1,1,1,1)
          end
        end
      end
    end
  end

  -- FireRed Meditate attacker deformation. The native battler is hidden while
  -- the inverse GBA affine matrix is redrawn around the battler baseline. Potato
  -- Voxel receives the same scale through voxelBattlerAffine(), so this branch
  -- is flat-2D only and never falls back to the HUD in staged mode.
  if type(battle.drawPicsLayer)=="function" and a.motionOwned then
    for _,e in ipairs(a.plan.events) do
      if e.kind=="battler_affine_sequence" and e.sequence=="meditate"
         and f>=e.frame and f<(e.destroyFrame or e.frame) then
        local battler=motionBattler(a,e.battler or "attacker")
        local snap=battler and a.motionOwned[battler]
        if battler and snap and snap.pf then
          local staged=self.voxelCompat and self.voxelCompat:state(battle) or nil
          local potato=staged and staged.ownership and staged.ownership.battlers
            and (staged.provider=="potato_voxel" or staged.provider=="battle_art")
          if not potato then
            local age=math.max(0,math.floor(f-e.frame))
            local nativeX,nativeY=256,256
            if age < 16 then
              local n=age+1
              nativeX=256-8*n; nativeY=256+10*n
            elseif age < 32 then
              local n=age-15
              nativeX=128+18*n; nativeY=416-18*n
            else
              local n=math.min(8,age-31)
              nativeX=416-20*n; nativeY=128+16*n
            end
            local sx=256/math.max(1,nativeX)
            local sy=256/math.max(1,nativeY)
            local pivotX=battler.isPlayer and 40 or 120
            local pivotY=battler.isPlayer and 96 or 56
            local wasHidden=snap.pf.hidden
            snap.pf.hidden=nil
            g.push()
            g.translate(pivotX,pivotY); g.scale(sx,sy); g.translate(-pivotX,-pivotY)
            pcall(battle.drawPicsLayer,battle,0,0,0,battler.isPlayer and "player" or "enemy",true)
            g.pop()
            snap.pf.hidden=wasHidden
            g.setColor(1,1,1,1)
          end
        end
      end
    end
  end

  -- FireRed Defense Curl affine deformation. The native battler is hidden
  -- while this exact inverse GBA affine matrix is redrawn around the battler's
  -- lower baseline. Potato Voxel uses voxelBattlerAffine() instead, so this
  -- branch is flat-2D only and never falls back to the HUD in staged mode.
  if type(battle.drawPicsLayer)=="function" and a.motionOwned then
    for _,e in ipairs(a.plan.events) do
      if e.kind=="battler_affine_sequence" and e.sequence=="defense_curl"
         and f>=e.frame and f<(e.destroyFrame or e.frame) then
        local battler=motionBattler(a,e.battler or "attacker")
        local snap=battler and a.motionOwned[battler]
        if battler and snap and snap.pf then
          local staged=self.voxelCompat and self.voxelCompat:state(battle) or nil
          local potato=staged and staged.ownership and staged.ownership.battlers
            and (staged.provider=="potato_voxel" or staged.provider=="battle_art")
          if not potato then
            local age=math.max(0,math.floor(f-e.frame))
            local localAge=age%16
            local step=(localAge<8) and (localAge+1) or math.max(0,15-localAge)
            local nativeX=256-12*step
            local nativeY=256+20*step
            local sx=256/math.max(1,nativeX)
            local sy=256/math.max(1,nativeY)
            local pivotX=battler.isPlayer and 40 or 120
            local pivotY=battler.isPlayer and 96 or 56
            local wasHidden=snap.pf.hidden
            snap.pf.hidden=nil
            g.push()
            g.translate(pivotX,pivotY); g.scale(sx,sy); g.translate(-pivotX,-pivotY)
            pcall(battle.drawPicsLayer,battle,0,0,0,battler.isPlayer and "player" or "enemy",true)
            g.pop()
            snap.pf.hidden=wasHidden
            g.setColor(1,1,1,1)
          end
        end
      end
    end
  end

  -- FireRed Teleport affine task. Keep the native battler copy hidden while
  -- drawing the attacker through the exact inverse GBA affine matrix. After
  -- 20 callbacks the final thin/tall matrix is held while the battler rises
  -- 8 px per callback; the persistent visibility event hides it on the next
  -- callback, matching AnimTask_Teleport_Step.
  if type(battle.drawPicsLayer)=="function" and a.motionOwned then
    for _,e in ipairs(a.plan.events) do
      if e.kind=="battler_affine_sequence" and e.sequence=="teleport"
         and f>=e.frame and f<(e.destroyFrame or e.frame) then
        local battler=motionBattler(a,e.battler)
        local snap=battler and a.motionOwned[battler]
        if battler and snap and snap.pf then
          local age=math.max(0,math.floor(f-e.frame))
          local af=math.max(1,e.affineFrames or 20)
          local n=math.min(af,age+1)
          local nativeX=256+64*n
          local nativeY=256-4*n
          local sx=256/math.max(1,nativeX)
          local sy=256/math.max(1,nativeY)
          local rise=0
          if age>=af then
            local steps=math.min(e.riseSteps or 0,age-af+1)
            rise=-(e.risePerFrame or 8)*steps
          end
          local cx=battler.isPlayer and 40 or 120
          local cy=battler.isPlayer and 72 or 40
          local staged=self.voxelCompat and self.voxelCompat:state(battle) or nil
          local stagedOwned=staged and staged.ownership and staged.ownership.battlers
          local drawn=false
          if stagedOwned and self.voxelCompat then
            drawn=self.voxelCompat:drawBattlerImage(staged,battle,battler,{scaleX=sx,scaleY=sy,offsetY=rise})
          end
          if not drawn then
            local wasHidden=snap.pf.hidden
            snap.pf.hidden=nil
            g.push()
            g.translate(0,rise)
            g.translate(cx,cy); g.scale(sx,sy); g.translate(-cx,-cy)
            pcall(battle.drawPicsLayer,battle,0,0,0,battler.isPlayer and "player" or "enemy",true)
            g.pop()
            snap.pf.hidden=wasHidden
          end
          g.setColor(1,1,1,1)
        end
      end
    end
  end

  -- FireRed Skull Bash release pose. The setup task first shifts the attacker
  -- 24 px toward its own side, rotates it into a head-down pose, shakes there,
  -- holds, then returns x2 to zero while leaving the rotation active through
  -- impact. AnimTask_SkullBashPosition(1) unwinds only the rotation afterward.
  if type(battle.drawPicsLayer)=="function" and a.motionOwned then
    for _,e in ipairs(a.plan.events) do
      if e.kind=="battler_affine_sequence"
         and (e.sequence=="skull_bash_set" or e.sequence=="skull_bash_reset")
         and f>=e.frame and f<(e.destroyFrame or e.frame) then
        local battler=motionBattler(a,e.battler)
        local snap=battler and a.motionOwned[battler]
        if battler and snap and snap.pf then
          local age=math.max(0,math.floor(f-e.frame))
          local side=(battler.isPlayer and -1 or 1)
          local dx,angleUnits=0,0
          if e.sequence=="skull_bash_set" then
            if age < 8 then
              dx=side*3*(age+1)
            elseif age < 17 then
              dx=side*24
              local r=math.max(0,math.min(8,age-8))
              angleUnits=side*0xC0*r
            elseif age < 34 then
              local r=math.max(0,math.min(8,math.floor((age-18)/2)+1))
              dx=side*24
              if age>=18 then
                local wob=((r%2)==1) and 2 or -2
                dx=dx + side*wob
              end
              angleUnits=side*0x600
            elseif age < 48 then
              dx=side*24
              angleUnits=side*0x600
            elseif age < 51 then
              dx=side*math.max(0,24-8*(age-47))
              angleUnits=side*0x600
            else
              dx=0
              angleUnits=side*0x600
            end
          else
            local r=math.max(0,math.min(8,age+1))
            dx=0
            angleUnits=side*math.max(0,0x600-0xC0*r)
          end
          -- GBA OBJ affine matrices are inverse sampling transforms; LÖVE
          -- rotates geometry directly, so invert the native angle for the
          -- visible Skull Bash pose.
          local angle=-angleUnits*math.pi*2/65536
          local cx=(battler.isPlayer and 40 or 120)+dx
          local cy=battler.isPlayer and 72 or 40
          local staged=self.voxelCompat and self.voxelCompat:state(battle) or nil
          local stagedOwned=staged and staged.ownership and staged.ownership.battlers
          local drawn=false
          if stagedOwned and (staged.provider=="potato_voxel" or staged.provider=="battle_art") then
            drawn=true -- real Potato card receives the texture tilt in main.lua
          elseif stagedOwned and self.voxelCompat then
            drawn=self.voxelCompat:drawBattlerImage(staged,battle,battler,{rotation=angle,dx=dx,dy=0})
          else
            local wasHidden=snap.pf.hidden
            snap.pf.hidden=nil
            g.push()
            g.translate(dx,0)
            g.translate(cx-dx,cy); g.rotate(angle); g.translate(-(cx-dx),-cy)
            pcall(battle.drawPicsLayer,battle,0,0,0,battler.isPlayer and "player" or "enemy",true)
            g.pop()
            snap.pf.hidden=wasHidden
            drawn=true
          end
          g.setColor(1,1,1,1)
        end
      end
    end
  end

  -- FireRed Thrash affine task. The native matrix accumulates four 7-frame
  -- delta segments (-10,+9), (+20,-20), (-20,+20), (+10,-9), repeated 3x.
  if type(battle.drawPicsLayer)=="function" and a.motionOwned then
    for _,e in ipairs(a.plan.events) do
      if e.kind=="battler_affine_sequence" and e.sequence=="thrash"
         and f>=e.frame and f<(e.destroyFrame or e.frame) then
        local battler=motionBattler(a,e.battler)
        local snap=battler and a.motionOwned[battler]
        if battler and snap and snap.pf then
          local age=math.max(0,math.min(83,math.floor(f-e.frame)))
          local seg=age%28
          local nx,ny=256,256
          local function add(dx,dy,n) nx=nx+dx*n; ny=ny+dy*n end
          if seg < 7 then
            add(-10,9,seg+1)
          elseif seg < 14 then
            add(-10,9,7); add(20,-20,seg-6)
          elseif seg < 21 then
            add(-10,9,7); add(20,-20,7); add(-20,20,seg-13)
          else
            add(-10,9,7); add(20,-20,7); add(-20,20,7); add(10,-9,seg-20)
          end
          local sx=256/math.max(1,nx); local sy=256/math.max(1,ny)
          -- The Vertical Thrash task runs concurrently. Its offset already lives
          -- in pf.ox/pf.oy, so use that same displacement for the transformed
          -- repaint instead of scaling a stationary copy underneath it.
          local dx=(snap.pf.ox or snap.ox or 0)-(snap.ox or 0)
          local dy=(snap.pf.oy or snap.oy or 0)-(snap.oy or 0)
          local cx=(battler.isPlayer and 40 or 120)+dx
          local cy=(battler.isPlayer and 72 or 40)+dy
          local staged=self.voxelCompat and self.voxelCompat:state(battle) or nil
          local stagedOwned=staged and staged.ownership and staged.ownership.battlers
          local drawn=false
          if stagedOwned and self.voxelCompat then
            drawn=self.voxelCompat:drawBattlerImage(staged,battle,battler,{scaleX=sx,scaleY=sy,dx=dx,dy=dy})
          end
          if not drawn then
            local wasHidden=snap.pf.hidden; snap.pf.hidden=nil
            g.push(); g.translate(cx,cy); g.scale(sx,sy); g.translate(-cx,-cy)
            pcall(battle.drawPicsLayer,battle,0,0,0,battler.isPlayer and "player" or "enemy",true)
            g.pop(); snap.pf.hidden=wasHidden
          end
          g.setColor(1,1,1,1)
        end
      end
    end
  end

  -- FireRed battler rotation tasks operate on the battler OBJ itself. Repaint
  -- that picture under the native 16-bit GBA rotation while its host copy is hidden.
  if type(battle.drawPicsLayer)=="function" and a.motionOwned then
    for _,e in ipairs(a.plan.events) do
      if e.kind=="battler_rotate" and f>=e.frame and f<(e.destroyFrame or e.frame) then
        local battler=motionBattler(a,e.battler)
        local snap=battler and a.motionOwned[battler]
        if battler and snap and snap.pf then
          local age=f-e.frame
          local d=math.max(1,e.turnFrames or 1)
          local hold=math.max(0,math.floor(tonumber(e.holdFrames) or 0))
          local steps
          if age<d then
            steps=age+1
          elseif age<d+hold then
            steps=d
          else
            steps=math.max(0,2*d+hold-(age+1))
          end
          -- AnimTask_RotateMonToSideAndRestore mirrors arg1 by battler side,
          -- then negates it once more because SetBattlerSpriteYOffsetFromRotation is enabled.
          local nativeDelta=tonumber(e.rotationDelta) or 0
          local signedStep=(battler.isPlayer and -nativeDelta or nativeDelta)
          local angleUnits=signedStep*steps
          local angle=angleUnits*math.pi*2/65536
          if e.invertVisibleRotation then angle=-angle end
          local cx=battler.isPlayer and 40 or 120
          local cy=battler.isPlayer and 72 or 40
          local staged=self.voxelCompat and self.voxelCompat:state(battle) or nil
          local stagedOwned=staged and staged.ownership and staged.ownership.battlers
          local drawn=false
          if stagedOwned and (staged.provider=="potato_voxel" or staged.provider=="battle_art") then
            drawn=true -- real Potato card receives the texture tilt in main.lua
          elseif stagedOwned and self.voxelCompat then
            -- A staged voxel renderer owns the battler image. Never fall back to
            -- the host's flat drawPicsLayer if a projected affine repaint is
            -- unavailable for a frame: that would flash the normal 2D battler
            -- at its classic battle position (most visible on Low Kick's target
            -- rotation). Keep the native copy hidden and let the staged renderer
            -- remain authoritative instead.
            drawn=self.voxelCompat:drawBattlerImage(staged,battle,battler,{rotation=angle})
          else
            local wasHidden=snap.pf.hidden
            snap.pf.hidden=nil
            g.push()
            g.translate(cx,cy); g.rotate(angle); g.translate(-cx,-cy)
            pcall(battle.drawPicsLayer,battle,0,0,0,battler.isPlayer and "player" or "enemy",true)
            g.pop()
            snap.pf.hidden=wasHidden
            drawn=true
          end
          g.setColor(1,1,1,1)
        end
      end
    end
  end
  -- FireRed BowMon keeps its affine rotation latched across separate controller
  -- sprites. Draw that persistent pose once from the accumulated controller state.
  if type(battle.drawPicsLayer)=="function" and a.motionOwned then
    local battler=a.attackerBattler
    local snap=battler and a.motionOwned[battler]
    if battler and snap and snap.pf then
      local bowX,bowAngleUnits=bowMonState(a.plan,f,battler)
      if bowAngleUnits~=0 then
        -- GBA OBJ affine matrices apply the inverse transform when sampling
        -- sprite pixels, so the visible rotation direction is opposite the raw
        -- SetSpriteRotScale angle sign. LÖVE rotates geometry directly.
        local angle=-bowAngleUnits*math.pi*2/65536
        local cx=(battler.isPlayer and 40 or 120)+bowX
        local cy=battler.isPlayer and 72 or 40
        local staged=self.voxelCompat and self.voxelCompat:state(battle) or nil
        local stagedOwned=staged and staged.ownership and staged.ownership.battlers
        local drawn=false
        if stagedOwned and (staged.provider=="potato_voxel" or staged.provider=="battle_art") then
          drawn=true -- real Potato card receives the texture tilt in main.lua
        elseif stagedOwned and self.voxelCompat then
          drawn=self.voxelCompat:drawBattlerImage(staged,battle,battler,{dx=bowX,rotation=angle})
        end
        if not drawn then
          local wasHidden=snap.pf.hidden
          snap.pf.hidden=nil
          g.push()
          g.translate(cx,cy); g.rotate(angle); g.translate(-cx,-cy)
          pcall(battle.drawPicsLayer,battle,0,0,0,battler.isPlayer and "player" or "enemy",true)
          g.pop()
          snap.pf.hidden=wasHidden
        end
        g.setColor(1,1,1,1)
      end
    end
  end
  end -- not effectLayerOnly (battler-owned affine/picture effects)

  if not battlerLayerOnly then
  for _,e in ipairs(a.plan.events) do
    local voxelEventOk=(not self.voxelCategories) or self.voxelCategories.matches(a,e,voxelCategory,voxelSide)
    if voxelEventOk then
    if e.kind == "smokescreen_impact" and f >= e.frame and f < e.destroyFrame then
      local assets=self.smokescreenImpactAssets
      local age=f-e.frame
      local off=(age<4 and 0) or (age<8 and 4) or 8
      local img=assets and assets:image(off) or nil
      if img then
        local ds=self.battleSpace.spriteDisplayScale()
        local quads={
          {e.x-16,e.y-16,1,1},
          {e.x,e.y-16,-1,1},
          {e.x-16,e.y,1,-1},
          {e.x,e.y,-1,-1},
        }
        g.setColor(1,1,1,1)
        for _,q in ipairs(quads) do
          local sx,sy=q[3]*ds,q[4]*ds
          local ox=q[3]<0 and 16 or 0
          local oy=q[4]<0 and 16 or 0
          g.draw(img,math.floor(q[1]+0.5),math.floor(q[2]+0.5),0,sx,sy,ox,oy)
        end
      end
    elseif e.kind == "electric_bolt_segment" and f >= e.frame and f < e.destroyFrame then
      local img=self.visualAssets:imageFor(e,f-e.frame)
      if img then
        g.setColor(1,1,1,1)
        local w=(e.oam and e.oam.width) or 8
        local h=(e.oam and e.oam.height) or 16
        local ds=e.displayScale or self.battleSpace.spriteDisplayScale()
        g.draw(img,math.floor(e.x-(w*ds)/2+0.5),math.floor(e.y-(h*ds)/2+0.5),0,ds,ds)
      end
    elseif e.kind == "sprite" and f >= e.frame and f < e.destroyFrame then
      local age = f - e.frame
      local d = math.max(1,e.motion.duration or 1)
      local t = clamp(age / d,0,1)
      local x,y
      local missileArcAmplitude
      if e.motion.kind == "endure_energy" then
        -- Literal AnimEndureEnergy_Step. data0 increments each callback; when
        -- it exceeds data1 it resets, moves the base sprite up one pixel, then
        -- the current data0 is subtracted again from Y.
        x=e.motion.startX or 0
        local yy=e.motion.startY or 0
        local data0=0
        local data1=math.max(0,e.motion.riseCadence or 0)
        for _=1,math.max(0,age) do
          data0=data0+1
          if data0>data1 then
            data0=0
            yy=yy-1
          end
          yy=yy-data0
        end
        y=yy
      elseif e.motion.kind == "poison_gas_cloud" then
        -- Literal three-stage geometry from FireRed MovePoisonGasCloud.
        local travel=math.max(1,e.motion.travelDuration or 64)
        local orbit=math.max(1,e.motion.orbitDuration or 80)
        if age < travel then
          local tt=clamp((age+1)/travel,0,1)
          local phase=((age+1)*8)%256
          local dir=e.motion.swirlReverse and -1 or 1
          x=lerp(e.motion.startX,e.motion.firstEndX,tt)+math.sin(phase*math.pi*2/256)*16/4*dir
          y=lerp(e.motion.startY,e.motion.firstEndY,tt)
        elseif age < travel+orbit then
          local n=age-travel
          local tt=clamp((n+1)/orbit,0,1)
          local startPhase=(e.motion.targetSide=="player") and 80 or 204
          local step=(e.motion.targetSide=="player") and -4 or 4
          local phase=(startPhase+(n+1)*step)%256
          x=(e.motion.targetX or e.motion.firstEndX)+math.sin(phase*math.pi*2/256)*32
          -- Native y uses the 29 px linear descent plus a small cosine wobble.
          y=(e.motion.firstEndY or 0)+29*tt-math.cos(phase*math.pi*2/256)*3
        else
          local n=age-travel-orbit
          local ef=math.max(1,e.motion.exitFrames or 1)
          local tt=clamp((n+1)/ef,0,1)
          local startPhase=(e.motion.targetSide=="player") and ((80-orbit*4)%256) or ((204+orbit*4)%256)
          local ox=(e.motion.targetX or e.motion.firstEndX)+math.sin(startPhase*math.pi*2/256)*32
          local oy=(e.motion.firstEndY or 0)+29-math.cos(startPhase*math.pi*2/256)*3
          x=lerp(ox,e.motion.exitX or ox,tt)
          y=lerp(oy,oy+4,tt)
        end
      elseif e.motion.kind == "lovely_kiss_devil" then
        -- Literal AnimDevil state machine. data0 oscillates forward/back while
        -- the ellipse radii shrink as data0 grows.
        local data0,data2=0,1
        local phase=0
        for _=0,math.max(0,age) do
          data0=data0+data2
          phase=(data0*4)%256
          if phase>128 and data2>0 then data2=-1 end
          if phase==0 and data2<0 then data2=1 end
        end
        local radX=30-data0/4
        local radY=10-data0/8
        x=(e.motion.startX or 0)+math.cos(phase*math.pi*2/256)*radX
        y=(e.motion.startY or 0)+math.sin(phase*math.pi*2/256)*radY
      elseif e.motion.kind == "lovely_kiss_heart" then
        -- Callback 0 only captures args. Subsequent callbacks drift in 8.8
        -- fixed point with a 3-unit sine phase until phase > 70, then the
        -- heart falls while wobbling for 31 callbacks.
        local moveTicks=math.min(24,math.max(0,age))
        local phase=math.min(72,moveTicks*3)
        local xdrift=math.floor((moveTicks*(e.motion.velocity or 0))/256)
        local ydrift=math.sin(phase*math.pi*2/256)*(e.motion.amplitude or 0)
        if age<=24 then
          x=(e.motion.startX or 0)+xdrift
          y=(e.motion.startY or 0)+ydrift
        else
          local fall=age-24
          local baseX=(e.motion.startX or 0)+math.floor((24*(e.motion.velocity or 0))/256)
          local baseY=(e.motion.startY or 0)+math.sin(72*math.pi*2/256)*(e.motion.amplitude or 0)
          local p=((e.motion.randomPhase or 0)+fall*3)%256
          x=baseX+math.sin(p*math.pi*2/256)*5
          y=baseY+math.floor(fall/2)
        end
      elseif e.motion.kind == "sleep_letter_z" then
        -- Native AnimSleepLetterZ_Step. Before callback n (0-based), data1=n,
        -- data0=n*(n-1)/2 and data4=+/-2n. C integer division truncates.
        local n=math.max(0,age)
        local driftSign=e.motion.playerSide and 1 or -1
        local xDrift=math.floor((2*n)/10)*driftSign
        x=(e.motion.startX or 0)+xDrift
        y=(e.motion.startY or 0)-math.floor((n*(n-1)/2)/40)
      elseif e.motion.kind == "roar_noise_line" then
        -- Native step uses signed 8.8 accumulators: 0x280 = 2.5 px/tick.
        x=(e.motion.startX or 0)+age*(e.motion.velocityX or 0)
        y=(e.motion.startY or 0)+age*(e.motion.velocityY or 0)
      elseif e.motion.kind == "wavy_music_note" then
        x=(e.motion.startX or 0)+age*(e.motion.velocityX or 0)
        local phase=(age*5)%256
        y=(e.motion.startY or 0)+age*(e.motion.velocityY or 0)+math.sin(phase*math.pi*2/256)*15
      elseif e.motion.kind == "substitute_doll_bounce" then
        -- Literal FireRed AnimTask_MonToSubstituteDoll state machine.
        -- age 0 is case 0 (initialize); callbacks 1.. are cases 1/2/3.
        -- This remains a generic visual sprite and never owns host battler state.
        local x0=e.motion.startX or 0
        local y0=e.motion.startY or 0
        local y2=0
        local x2=0
        local v=0
        local state=0
        for i=0,math.max(0,age) do
          if state==0 then
            y2=-200
            x2=200
            v=0
            state=1
          elseif state==1 then
            v=v+112
            y2=y2+math.floor(v/256)
            if y0+y2>=-32 then x2=0 end
            if y2>0 then y2=0 end
            if y2==0 then
              v=v-0x800
              state=2
            end
          elseif state==2 then
            v=v-112
            if v<0 then v=0 end
            y2=y2-math.floor(v/256)
            if v==0 then state=3 end
          else
            v=v+112
            y2=y2+math.floor(v/256)
            if y2>0 then y2=0 end
            -- FireRed destroys the task once y2 reaches 0 again.
          end
        end
        x=x0+x2
        y=y0+y2
      elseif e.motion.kind == "powder_particle" then
        local angle=((age*(e.motion.waveSpeed or 0)) % 256) * math.pi * 2 / 256
        x=(e.motion.startX or 0) + math.sin(angle)*(e.motion.amplitude or 0)
        y=(e.motion.startY or 0) + age*(e.motion.verticalSpeed or 0)
      elseif e.motion.kind == "spore_particle" then
        -- AnimSporeParticle calls its step once during initialization. At
        -- visible age 0 the angle is therefore the script angle and the
        -- +24 fixed-point Y accumulator has already advanced once.
        local step=math.max(0,age)
        local a=((e.motion.initialAngle or 0) + step*2) % 256
        local rad=a*math.pi*2/256
        x=(e.motion.startX or 0)+math.sin(rad)*32
        y=(e.motion.startY or 0)+math.cos(rad)*(-3)+math.floor(((step+1)*24)/256)
      elseif e.motion.kind == "confuse_ray_bounce" then
        local travel=math.max(1,e.motion.travelDuration or e.motion.duration or 1)
        local tt=clamp(age/travel,0,1)
        local angle=((age*5)%256)*math.pi*2/256
        x=lerp(e.motion.startX,e.motion.endX,tt)+math.sin(angle)*10
        y=lerp(e.motion.startY,e.motion.endY,tt)+math.cos(angle)*15
      elseif e.motion.kind == "confuse_ray_spiral" then
        local angle=((age*19)%256)*math.pi*2/256
        x=(e.motion.startX or 0)+math.sin(angle)*32
        -- FireRed AnimConfuseRayBallSpiral: data[0] += 19, data[2] += 80,
        -- y2 = Cos(angle, 8) + (data[2] >> 8), and the sprite lives 61 frames.
        y=(e.motion.startY or 0)+math.cos(angle)*8+math.floor(((age+1)*80)/256)
      elseif e.motion.kind == "black_smoke" then
        x=(e.motion.startX or 0)+age*(e.motion.velocityX or 0)
        y=e.motion.startY or 0
      elseif e.motion.kind == "bite" then
        local steps=math.max(1,e.motion.steps or 1)
        local n
        if age < steps then n=age else n=math.max(0,(steps*2)-age) end
        x=(e.motion.startX or 0)+(n*(e.motion.stepX or 0))/256
        y=(e.motion.startY or 0)+(n*(e.motion.stepY or 0))/256
      elseif e.motion.kind == "stomp_foot" then
        local waitFrames=e.motion.waitFrames or 0
        local travelFrames=math.max(1,e.motion.travelFrames or 6)
        if age < waitFrames then
          x=e.motion.startX or 0; y=e.motion.startY or 0
        elseif age < waitFrames+travelFrames then
          local tt=clamp((age-waitFrames+1)/travelFrames,0,1)
          x=lerp(e.motion.startX,e.motion.endX,tt)
          y=lerp(e.motion.startY,e.motion.endY,tt)
        else
          x=e.motion.endX or e.motion.startX or 0
          y=e.motion.endY or e.motion.startY or 0
        end
      elseif e.motion.kind == "elliptical_gust" then
        local angle=(((e.motion.startAngle or 191)+age*(e.motion.angleStep or 5))%256)*math.pi*2/256
        x=(e.motion.startX or 0)+math.sin(angle)*32
        y=(e.motion.startY or 0)+math.cos(angle)*8
      elseif e.motion.kind == "rock_scatter" then
        local step=math.max(0,math.min(17,age))
        local x2=0
        local data3=0
        for _=0,step do data3=data3+(e.motion.xImpulse or 0); x2=x2+data3/40 end
        local angle=((step+1)*8)%256
        local rad=angle*math.pi*2/256
        x=(e.motion.startX or 0)+x2
        y=(e.motion.startY or 0)-math.sin(rad)*(e.motion.sineAmplitude or 0)
      elseif e.motion.kind == "dirt_plume" then
        local tt=clamp(age/math.max(1,e.motion.duration or 1),0,1)
        x=lerp(e.motion.startX,e.motion.endX,tt)
        y=lerp(e.motion.startY,e.motion.endY,tt)+math.sin(tt*math.pi)*(e.motion.arcAmplitude or 0)
      elseif e.motion.kind == "barrage_ball" then
        -- Native task timing: arc steps 1..8 happen every second callback,
        -- then steps 9..16 happen every callback. Hold at the landing point
        -- during the subsequent flicker-out phase.
        local step
        if age <= 16 then
          step=math.floor(math.max(0,age)/2)
        elseif age <= 24 then
          step=8+(age-16)
        else
          step=16
        end
        step=math.max(0,math.min(16,step))
        local tt=step/16
        x=lerp(e.motion.startX,e.motion.endX,tt)
        y=lerp(e.motion.startY,e.motion.endY,tt)+math.sin(tt*math.pi)*(e.motion.arcAmplitude or -32)
      elseif e.motion.kind == "coin_throw" then
        x=lerp(e.motion.startX,e.motion.endX,t)
        y=lerp(e.motion.startY,e.motion.endY,t)
      elseif e.motion.kind == "falling_coin" then
        local n=math.max(1,age+1)
        local cycle=math.floor((n-1)/26)
        local within=(n-1)%26
        local angle=(within*5)%256
        local amp=(cycle==0) and -16 or -8
        x=(e.motion.startX or 0)+(e.motion.driftSign or 1)*math.floor(n/2)
        y=(e.motion.startY or 0)+gbaSinApprox(angle,amp)
      elseif e.motion.kind == "throw_projectile" then
        x=lerp(e.motion.startX,e.motion.endX,t)
        y=lerp(e.motion.startY,e.motion.endY,t)+math.sin(t*math.pi)*(e.motion.arcAmplitude or 0)
      elseif e.motion.kind == "bonemerang_projectile" then
        local outD=math.max(1,e.motion.outDuration or 20)
        local retD=math.max(1,e.motion.returnDuration or 20)
        if age <= outD then
          local tt=clamp(age/outD,0,1)
          x=lerp(e.motion.startX,e.motion.midX,tt)
          y=lerp(e.motion.startY,e.motion.midY,tt)+math.sin(tt*math.pi)*(e.motion.outArc or -40)
        else
          local tt=clamp((age-outD)/retD,0,1)
          x=lerp(e.motion.midX,e.motion.endX,tt)
          y=lerp(e.motion.midY,e.motion.endY,tt)+math.sin(tt*math.pi)*(e.motion.returnArc or 40)
        end
      elseif e.motion.kind == "falling_rock" then
        -- Native TranslateSpriteInEllipse sequence from AnimFallingRock.
        -- The first phase uses angle 0..60, X amplitude 0 and Y amplitude -70.
        -- After one transition callback, the second starts at angle 192 with
        -- horizontal amplitude arg2 and Y amplitude -24 for 32 callbacks.
        local baseX=e.motion.startX or 0
        local baseY=e.motion.startY or 0
        if age <= 15 then
          local angle=(age*4)%256
          local rad=angle*math.pi*2/256
          x=baseX
          y=baseY+math.cos(rad)*-70
        elseif age==16 then
          local angle=60
          local rad=angle*math.pi*2/256
          x=baseX
          y=baseY+math.cos(rad)*-70
        else
          local step=math.min(31,math.max(0,age-17))
          local angle=(192+step*4)%256
          local rad=angle*math.pi*2/256
          local amp=e.motion.horizAmplitude or 0
          x=baseX+amp+math.sin(rad)*amp
          y=baseY+math.cos(rad)*-24
        end
      elseif e.motion.kind == "sliding_kick" then
        local setup=1
        if age < setup then
          x=e.motion.startX or 0; y=e.motion.startY or 0
        else
          local step=math.min(math.max(1,age),math.max(1,e.motion.nativeDuration or 1))
          local nd=math.max(1,e.motion.nativeDuration or 1)
          local tt=step/nd
          x=lerp(e.motion.startX,e.motion.endX,tt)
          local sineIndex=math.floor(((step-1)*(e.motion.phaseStep or 0))/256)%256
          y=lerp(e.motion.startY,e.motion.endY,tt)+math.sin(sineIndex*math.pi*2/256)*(e.motion.amplitude or 0)
        end
      elseif e.motion.kind == "acid_poison_bubble" then
        x=lerp(e.motion.startX,e.motion.endX,t)
        y=lerp(e.motion.startY,e.motion.endY,t)+math.sin(t*math.pi)*(e.motion.arcAmplitude or -30)
      elseif e.motion.kind == "acid_poison_droplet" then
        x=lerp(e.motion.startX,e.motion.endX,t)
        y=lerp(e.motion.startY,e.motion.endY,t)
      elseif e.motion.kind == "absorption_orb" then
        x=lerp(e.motion.startX,e.motion.endX,t)
        y=lerp(e.motion.startY,e.motion.endY,t)+math.sin(t*math.pi)*(e.motion.arcAmplitude or 0)
      elseif e.motion.kind == "hyper_beam_orb" then
        x=lerp(e.motion.startX,e.motion.endX,t)
        local angle=((e.motion.phase or 0)+age*(e.motion.phaseStep or 24))%256
        y=lerp(e.motion.startY,e.motion.endY,t)+math.cos(angle*math.pi*2/256)*(e.motion.waveAmplitude or 12)
      elseif e.motion.kind == "mimic_orb" then
        local grow=math.max(1,e.motion.growFrames or 14)
        local travel=math.max(1,e.motion.travelDuration or 25)
        if age <= grow then
          x=e.motion.startX or 0; y=e.motion.startY or 0
        else
          local step=math.min(travel,math.max(0,age-grow))
          local tt=step/travel
          x=lerp(e.motion.startX,e.motion.endX,tt)
          y=lerp(e.motion.startY,e.motion.endY,tt)
        end
      elseif e.motion.kind == "soft_boiled_egg" then
        -- Exact fixed-point hop from FireRed AnimSoftBoiledEgg_Step1.
        local sx,sy=e.motion.startX or 0,e.motion.startY or 0
        local sign=e.motion.playerSide and 1 or -1
        if age < (e.motion.hopFrames or 51) then
          local d0,d1,y2,x2=0x380,160*sign,0,0
          for _=0,age do
            y2=y2-math.floor(d0/256)
            x2=math.floor(d1/256)
            d0=d0-32
            d1=d1+160*sign
          end
          x=sx+x2; y=sy+y2
        else
          x=sx+31*sign; y=sy+3
          local crack=e.motion.crackFrame or 104
          if (e.motion.variant or 0)==0 and age>=crack then
            y=y-2*math.min(9,age-crack+1)
          end
        end
      elseif e.motion.kind == "power_absorption_orb" or e.motion.kind == "solar_beam_big_orb" then
        x=lerp(e.motion.startX,e.motion.endX,t)
        y=lerp(e.motion.startY,e.motion.endY,t)
      elseif e.motion.kind == "solar_beam_small_orb" then
        local angle=((e.motion.phase or 0)+age*(e.motion.phaseStep or 15))%256
        x=lerp(e.motion.startX,e.motion.endX,t)+math.sin(angle*math.pi*2/256)*(e.motion.xAmplitude or 5)
        y=lerp(e.motion.startY,e.motion.endY,t)+math.cos(angle*math.pi*2/256)*(e.motion.yAmplitude or 14)
      elseif e.motion.kind == "leech_seed" then
        local travel=math.max(1,e.motion.travelDuration or 1)
        if age <= travel then
          local tt=clamp(age/travel,0,1)
          x=lerp(e.motion.startX,e.motion.endX,tt)
          y=lerp(e.motion.startY,e.motion.endY,tt)+math.sin(tt*math.pi)*(e.motion.arcAmplitude or 0)
        else
          x=e.motion.endX; y=e.motion.endY
        end
      elseif e.motion.kind == "missile_arc" then
        -- FireRed InitAnimArcTranslation / TranslateAnimHorizontalArc. Keep
        -- the native path unless Gen1Recomp's shorter/higher battle layout
        -- would clip the rotated sprite at the top of the host viewport.
        local yoff=-16
        local ds=e.displayScale or self.battleSpace.spriteDisplayScale()
        local ow=(e.oam and e.oam.width) or 16
        local oh=(e.oam and e.oam.height) or 16
        missileArcAmplitude=missileArcSafeAmplitude(e.motion,yoff,ds,ow,oh)
        x=lerp(e.motion.startX,e.motion.endX,t)
        y=lerp(e.motion.startY,e.motion.endY,t)+math.sin(t*math.pi)*missileArcAmplitude
      elseif e.motion.kind == "petal_dance_big" then
        local aa=math.min(age,math.max(1,e.motion.duration or 1))
        local tt=clamp(aa/math.max(1,e.motion.duration or 1),0,1)
        local angle=((e.motion.angleStart or 64)+aa*(e.motion.angleStep or 5))%256
        x=lerp(e.motion.startX,e.motion.endX,tt)+gbaSinApprox(angle,32)
        y=lerp(e.motion.startY,e.motion.endY,tt)+gbaSinApprox((angle+64)%256,-5)
      elseif e.motion.kind == "petal_dance_small" then
        local aa=math.min(age,math.max(1,e.motion.duration or 1))
        local tt=clamp(aa/math.max(1,e.motion.duration or 1),0,1)
        local angle=((e.motion.angleStart or 64)+aa*(e.motion.angleStep or 5))%256
        x=lerp(e.motion.startX,e.motion.endX,tt)+gbaSinApprox(angle,8)
        y=lerp(e.motion.startY,e.motion.endY,tt)
      elseif e.motion.kind == "razor_leaf_particle" then
        local launch=e.motion.launchDuration or 0
        if age < launch then
          x=(e.motion.startX or 0)+age*(e.motion.launchDX or 0)
          y=(e.motion.startY or 0)+age*(e.motion.launchDY or 0)
        else
          local bx=(e.motion.startX or 0)+launch*(e.motion.launchDX or 0)
          local by=(e.motion.startY or 0)+launch*(e.motion.launchDY or 0)
          local phase2=math.max(0,age-((e.motion.phase2Start or (launch+1))+1))
          local angle=(((e.motion.phase2Angle or 0)+phase2*2)%256)*math.pi*2/256
          x=bx+(e.motion.swaySign or 1)*math.sin(angle)*25
          y=by+math.floor((phase2+1)/2)
        end
      elseif e.motion.kind == "move_particle_beyond_target" then
        local inf=math.max(1,e.motion.inFrames or 1)
        local outf=math.max(1,e.motion.outFrames or 1)
        local total=inf+outf
        local aa=math.min(age,total)
        local tt
        if aa<=inf then
          tt=aa/inf
          x=lerp(e.motion.startX,e.motion.targetX,tt)
          y=lerp(e.motion.startY,e.motion.targetY,tt)
        else
          tt=(aa-inf)/outf
          x=lerp(e.motion.targetX,e.motion.endX,tt)
          y=lerp(e.motion.targetY,e.motion.endY,tt)
        end
        local freq=e.motion.waveFrequency or 0
        if freq~=0 then
          y=y+gbaSinApprox((age*freq)%256,e.motion.waveAmplitude or 0)
        end
      elseif e.motion.kind == "swirling_snowball" then
        local inf=math.max(1,e.motion.inFrames or 1)
        local orb=math.max(1,e.motion.orbitFrames or 32)
        local outf=math.max(1,e.motion.outFrames or 1)
        if age<inf then
          local tt=age/inf
          x=lerp(e.motion.startX,e.motion.targetX,tt)
          y=lerp(e.motion.startY,e.motion.targetY,tt)
        elseif age<inf+orb then
          local oa=age-inf
          local angle=((128+oa*16)%256)
          -- Native callback subtracts the starting Sin/Cos sample, so the
          -- orbit begins exactly at the arrival point rather than jumping.
          x=(e.motion.targetX or 0)+gbaSinApprox(angle,e.motion.orbitX or -20)-gbaSinApprox(128,e.motion.orbitX or -20)
          y=(e.motion.targetY or 0)+gbaSinApprox((angle+64)%256,e.motion.orbitY or 15)-gbaSinApprox((128+64)%256,e.motion.orbitY or 15)
        else
          local tt=clamp((age-inf-orb)/outf,0,1)
          x=lerp(e.motion.targetX,e.motion.endX,tt)
          y=lerp(e.motion.targetY,e.motion.endY,tt)
        end
      elseif e.motion.kind == "linear_single_sine" then
        x=lerp(e.motion.startX,e.motion.endX,t)
        y=lerp(e.motion.startY,e.motion.endY,t)+math.sin(t*math.pi*2)*(e.motion.waveAmplitude or 0)
      elseif e.motion.kind == "sin_wave_to_target" then
        -- FireRed AnimToTargetInSinWave calls AnimTranslateLinear first, then
        -- adds Sin(data[6] >> 8, data[7]) to y2. data[6] advances by 7
        -- angle units per callback and folds at 127 while flipping amplitude.
        local steps=math.min(e.motion.nativeDuration or 30,age+1)
        local tt=steps/math.max(1,e.motion.nativeDuration or 30)
        local phase=(e.motion.phaseStart or 0)
        local amp=e.motion.waveAmplitude or 0
        if phase>127 then phase=phase-127; amp=-amp end
        for _=1,math.max(0,steps-1) do
          if phase+(e.motion.phaseStep or 7)>127 then
            phase=0; amp=-amp
          else
            phase=phase+(e.motion.phaseStep or 7)
          end
        end
        x=lerp(e.motion.startX,e.motion.endX,tt)
        y=lerp(e.motion.startY,e.motion.endY,tt)+gbaSinApprox(phase,amp)
      elseif e.motion.kind == "dragon_fire_to_target" then
        x=lerp(e.motion.startX,e.motion.endX,t)
        y=lerp(e.motion.startY,e.motion.endY,t)
      elseif e.motion.kind == "dragon_rage_fire_plume" then
        x=e.motion.startX or 0
        y=e.motion.startY or 0
      elseif e.motion.kind == "water_bubble_projectile" then
        local travel=math.max(1,e.motion.travelDuration or 1)
        local ta=math.min(age,travel-1)
        local tt=clamp(ta/travel,0,1)
        local start=(e.motion.startAngle or 0)
        local step=(e.motion.angleStep or 0)
        local angle=((start+ta*step)%256)*math.pi*2/256
        local angle0=(start%256)*math.pi*2/256
        x=lerp(e.motion.startX,e.motion.endX,tt)+math.sin(angle)*(e.motion.waveX or 0)-math.sin(angle0)*(e.motion.waveX or 0)
        y=lerp(e.motion.startY,e.motion.endY,tt)+math.cos(angle)*(e.motion.waveY or 0)-math.cos(angle0)*(e.motion.waveY or 0)
        if age>=travel then
          if e.motion.preserveArrivalOrbit then
            -- FireRed keeps the final x2/y2 orbital displacement while the
            -- bubble plays its 0/4/8 impact animation. Do not snap the pop
            -- back to the target center after travel completes.
            local finalTa=math.max(0,travel-1)
            local finalAngle=((start+finalTa*step)%256)*math.pi*2/256
            x=(e.motion.endX or 0)+math.sin(finalAngle)*(e.motion.waveX or 0)-math.sin(angle0)*(e.motion.waveX or 0)
            y=(e.motion.endY or 0)+math.cos(finalAngle)*(e.motion.waveY or 0)-math.cos(angle0)*(e.motion.waveY or 0)
          else
            x=e.motion.endX; y=e.motion.endY
          end
        end
      elseif e.motion.kind == "bubble_effect" then
        local angle=((age*11)%256)*math.pi*2/256
        x=(e.motion.startX or 0)+math.sin(angle)*4
        y=(e.motion.startY or 0)-math.floor(((age+1)*48)/256)
      elseif e.motion.kind == "small_bubble_pair" then
        local angle=(((age+1)*11)%256)*math.pi*2/256
        x=(e.motion.startX or 0)+math.sin(angle)*4
        y=(e.motion.startY or 0)-math.floor(((age+1)*48)/256)
      elseif e.motion.kind == "small_drifting_bubbles" then
        -- Initial callback is setup-only. Subsequent ticks accumulate the
        -- signed 8.8 horizontal speed and positive-Y drift used by FireRed.
        if age <= 0 then
          x=e.motion.startX or 0
          y=e.motion.startY or 0
        else
          x=(e.motion.startX or 0)+gbaShift8(age*(e.motion.driftSpeedX or 0))
          y=(e.motion.startY or 0)+gbaShift8(age*(e.motion.driftSpeedY or 0))
        end
      elseif e.motion.kind == "particle_in_vortex" then
        -- FireRed AnimParticleInVortex has one setup-only callback tick. Each
        -- later tick adds signed 8.8 Y velocity, samples Sin(currentPhase,
        -- amplitude), then advances phase by phaseStep modulo 256.
        if age <= 0 then
          x=e.motion.startX or 0
          y=e.motion.startY or 0
        else
          local stepAge=age
          local phase=((stepAge-1)*(e.motion.phaseStep or 0))%256
          x=(e.motion.startX or 0)+gbaSinApprox(phase,e.motion.amplitude or 0)
          y=(e.motion.startY or 0)-gbaShift8(stepAge*(e.motion.verticalSpeed or 0))
        end
      elseif e.motion.kind == "ice_punch_swirl" then
        -- Same native growing-circle helper as Fire Punch, with Ice Punch's
        -- crystal templates layered on top.
        local radius=(e.motion.initialRadius or 60)+gbaShift8(age*(e.motion.radiusSpeed or -0x200))
        local angle=((e.motion.initialAngle or 0)+age*(e.motion.angleStep or 9))%256
        x=(e.motion.startX or 0)+gbaSinApprox(angle,radius)
        y=(e.motion.startY or 0)+gbaSinApprox(angle+64,radius)
      elseif e.motion.kind == "fire_spiral_inward" then
        -- AnimFireSpiralInward immediately executes TranslateSpriteInGrowingCircle.
        -- Radius is 60 + ((-0x200 * age) >> 8), i.e. two pixels smaller per tick.
        local radius=(e.motion.initialRadius or 60)+gbaShift8(age*(e.motion.radiusSpeed or -0x200))
        local angle=((e.motion.initialAngle or 0)+age*(e.motion.angleStep or 9))%256
        x=(e.motion.startX or 0)+gbaSinApprox(angle,radius)
        y=(e.motion.startY or 0)+gbaSinApprox(angle+64,radius)
      elseif e.motion.kind == "fire_spread" then
        -- AnimFireSpread switches to TranslateSpriteLinearFixedPoint without
        -- invoking it on the creation frame. Subsequent ticks accumulate 8.8
        -- signed velocities exactly like the GBA callback.
        local steps=math.min(math.max(0,age),math.max(0,e.motion.nativeDuration or 0))
        x=(e.motion.startX or 0)+gbaShift8(steps*(e.motion.speedX or 0))
        y=(e.motion.startY or 0)+gbaShift8(steps*(e.motion.speedY or 0))
      elseif e.motion.kind == "fire_blast_ring" then
        local a0=e.motion.initialAngle or 0
        local step=e.motion.angleStep or 20
        local radius=e.motion.radius or 28
        local orbitIn=e.motion.orbitIn or 18
        local travel=e.motion.travelDuration or 25
        if age < orbitIn then
          local ang=(a0+age*step)%256
          x=(e.motion.startX or 0)+gbaSinApprox(ang,radius)
          y=(e.motion.startY or 0)+gbaSinApprox(ang+64,radius)
        elseif age < orbitIn+travel then
          local ta=age-orbitIn
          local tt=clamp((ta+1)/math.max(1,travel),0,1)
          local ang=(a0+(orbitIn+ta)*step)%256
          x=lerp(e.motion.startX,e.motion.targetX,tt)+gbaSinApprox(ang,radius)
          y=lerp(e.motion.startY,e.motion.targetY,tt)+gbaSinApprox(ang+64,radius)
        else
          local oa=age-orbitIn-travel
          local ang=(a0+(orbitIn+travel+oa)*step)%256
          x=(e.motion.targetX or 0)+gbaSinApprox(ang,radius)
          y=(e.motion.targetY or 0)+gbaSinApprox(ang+64,radius)
        end
      elseif e.motion.kind == "fire_blast_cross" then
        local steps=math.min(math.max(0,age),math.max(0,e.motion.nativeDuration or 0))
        x=(e.motion.startX or 0)+steps*(e.motion.dx or 0)
        y=(e.motion.startY or 0)+steps*(e.motion.dy or 0)
      elseif e.motion.kind == "spark_electricity_flashing" then
        local angle=(((e.motion.angle or 0)+age*(e.motion.angleStep or 0))%256)*math.pi*2/256
        x=(e.motion.startX or 0)+math.sin(angle)*(e.motion.radius or 0)
        y=(e.motion.startY or 0)+math.cos(angle)*(e.motion.radius or 0)
      elseif e.motion.kind == "razor_wind_tornado" then
        local angle=((e.motion.initialAngle or 0)+(e.motion.angleStep or 0)*age)%256
        x=(e.motion.startX or 0)+gbaSinApprox(angle,e.motion.radius or 0)
        y=(e.motion.startY or 0)+gbaSinApprox(angle+64,e.motion.radius or 0)
      elseif e.motion.kind == "guillotine_pincer" then
        local d=math.max(1,math.floor(e.motion.nativeDuration or 6))
        local function axis(startv,endv,steps)
          local diff=(endv or 0)-(startv or 0)
          local mag=math.floor(math.abs(diff)*256/d)
          if diff < 0 then
            if mag % 2 == 0 then mag=mag+1 end
            return (startv or 0)-math.floor((mag*steps)/256)
          else
            if mag % 2 == 1 then mag=mag-1 end
            return (startv or 0)+math.floor((mag*steps)/256)
          end
        end
        local reverse=e.motion.reverseFrame or 49
        if age <= (e.motion.closeFrame or d) then
          local steps=math.min(d,math.max(0,age))
          x=axis(e.motion.startX,e.motion.endX,steps)
          y=axis(e.motion.startY,e.motion.endY,steps)
        elseif age < reverse then
          x=e.motion.endX; y=(e.motion.endY or 0)-2
        else
          local steps=math.min(d,math.max(0,age-reverse))
          x=axis(e.motion.endX,e.motion.startX,steps)
          y=axis((e.motion.endY or 0)-2,e.motion.startY,steps)
        end
      elseif e.motion.kind == "gust_to_target" then
        local affine=e.motion.affineDuration or 24
        local travel=math.max(1,e.motion.nativeDuration or 1)
        if age<=affine then x=e.motion.startX; y=e.motion.startY
        else
          local steps=math.min(travel,math.max(0,age-affine))
          x=lerp(e.motion.startX,e.motion.endX,steps/travel)
          y=lerp(e.motion.startY,e.motion.endY,steps/travel)
        end
      elseif e.motion.kind == "whirlwind_line" then
        local state=((e.motion.initialState or 0)+age)%6
        x=(e.motion.startX or 0)+12*state
        y=e.motion.startY
      elseif e.motion.kind == "fly_ball_up" then
        x=e.motion.startX
        local wait=e.motion.waitFrames or 0
        if age<=wait then y=e.motion.startY
        else
          local n=age-wait; local disp=0; local accel=e.motion.acceleration or 0
          for k=1,n do disp=disp+math.floor((k*accel)/256) end
          y=(e.motion.startY or 0)-disp
        end
      elseif e.motion.kind == "fly_ball_attack" then
        local travel=math.max(1,e.motion.nativeDuration or 1)
        if age<=travel then
          x=lerp(e.motion.startX,e.motion.endX,age/travel)
          y=lerp(e.motion.startY,e.motion.endY,age/travel)
        else
          local n=age-travel
          x=(e.motion.endX or 0)+(e.motion.velocityX or 0)*n
          y=(e.motion.endY or 0)+(e.motion.velocityY or 0)*n
        end
      elseif e.motion.kind == "sky_attack_bird" then
        local travel=math.max(1,e.motion.nativeDuration or 12)
        if age<=travel then
          x=lerp(e.motion.startX,e.motion.endX,age/travel)
          y=lerp(e.motion.startY,e.motion.endY,age/travel)
        else
          local n=age-travel
          x=(e.motion.endX or 0)+(e.motion.velocityX or 0)*n
          y=(e.motion.endY or 0)+(e.motion.velocityY or 0)*n
        end
      elseif e.motion.kind == "swords_dance_blade" then
        local affineEnd=e.motion.affineDuration or 44
        local rise=math.max(1,e.motion.riseDuration or 6)
        x=e.motion.startX
        if age <= affineEnd then
          y=e.motion.startY
        else
          local steps=math.min(rise,math.max(0,age-affineEnd))
          y=lerp(e.motion.startY,e.motion.endY,steps/rise)
        end
      elseif e.motion.kind == "swirling_fog" then
        local setup=math.max(0,e.motion.setupFrames or 1)
        if age < setup then
          x=e.motion.startX or 0; y=e.motion.startY or 0
        else
          local step=age-setup+1
          local nd=math.max(1,e.motion.nativeDuration or 1)
          local tt=clamp(step/nd,0,1)
          local angle=((e.motion.angleStart or 64)+(step-1)*(e.motion.angleStep or 3))%256
          local rad=angle*math.pi*2/256
          x=lerp(e.motion.startX,e.motion.endX,tt)+math.sin(rad)*(e.motion.orbitX or 32)
          y=lerp(e.motion.startY,e.motion.endY,tt)+math.cos(rad)*(e.motion.orbitY or -6)
        end
      elseif e.motion.kind == "aurora_beam_ring" then
        -- FireRed AnimAuroraBeamRings calls its step callback immediately after
        -- InitAnimLinearTranslation, so the sprite is already one native fixed-point
        -- translation step away from the attacker on its creation frame. Preserve
        -- that callback ordering here rather than showing an extra origin frame.
        local d=math.max(1,math.floor(e.motion.nativeDuration or e.motion.duration or 17))
        local steps=math.min(d,math.max(1,age+1))
        local function axis(startv,endv)
          local diff=(endv or 0)-(startv or 0)
          local mag=math.floor(math.abs(diff)*256/d)
          if diff < 0 then
            if mag % 2 == 0 then mag=mag+1 end
            return (startv or 0)-math.floor((mag*steps)/256)
          else
            if mag % 2 == 1 then mag=mag-1 end
            return (startv or 0)+math.floor((mag*steps)/256)
          end
        end
        x=axis(e.motion.startX,e.motion.endX)
        y=axis(e.motion.startY,e.motion.endY)
      elseif e.motion.kind == "tri_attack_triangle" then
        local hold=math.max(0,e.motion.holdFrames or 60)
        if age<=hold then
          x=e.motion.startX or 0; y=e.motion.startY or 0
        else
          local d=math.max(1,e.motion.nativeDuration or 20)
          local steps=math.min(d,math.max(0,age-hold))
          local function axis(startv,endv)
            local diff=(endv or 0)-(startv or 0)
            local mag=math.floor(math.abs(diff)*256/d)
            if diff < 0 then
              if mag % 2 == 0 then mag=mag+1 end
              return (startv or 0)-math.floor((mag*steps)/256)
            else
              if mag % 2 == 1 then mag=mag-1 end
              return (startv or 0)+math.floor((mag*steps)/256)
            end
          end
          x=axis(e.motion.startX,e.motion.endX)
          y=axis(e.motion.startY,e.motion.endY)
        end
      elseif e.motion.kind == "large_flame" then
        local steps=math.min(e.motion.moveFrames or 29,math.max(0,age))
        x=(e.motion.startX or 0)+(e.motion.velocityX or 0)*steps
        y=(e.motion.startY or 0)+(e.motion.velocityY or 0)*steps
      elseif e.motion.kind == "string_shot_web_thread" then
        -- Exact InitAnimLinearTranslation fixed-point stepping, then the
        -- callback adds Sin(data[6], amplitude) to X and advances data[6] by 13.
        local d=math.max(1,math.floor(e.motion.nativeDuration or e.motion.duration or 1))
        local steps=math.min(d,math.max(0,age))
        local function axis(startv,endv)
          local diff=(endv or 0)-(startv or 0)
          local mag=math.floor(math.abs(diff)*256/d)
          if diff < 0 then
            if mag % 2 == 0 then mag=mag+1 end
            return (startv or 0)-math.floor((mag*steps)/256)
          else
            if mag % 2 == 1 then mag=mag-1 end
            return (startv or 0)+math.floor((mag*steps)/256)
          end
        end
        x=axis(e.motion.startX,e.motion.endX)
        y=axis(e.motion.startY,e.motion.endY)
        if steps>0 then
          x=x+gbaSinApprox(((steps-1)*(e.motion.phaseStep or 13))%256,e.motion.amplitude or 0)
        end
      elseif e.motion.kind == "dizzy_punch_duck" then
        -- Frame 0 is callback setup. Subsequent callbacks accumulate the
        -- signed 8.8 X velocity and sample Sin(data[3], amplitude), then add 3.
        local steps=math.max(0,age)
        x=(e.motion.startX or 0)+math.floor(((e.motion.velocityX or 0)*steps)/256)
        if steps>0 then
          y=(e.motion.startY or 0)+gbaSinApprox(((steps-1)*3)%256,e.motion.sineAmplitude or 0)
        else
          y=e.motion.startY or 0
        end
      elseif e.motion.kind == "string_shot_wrap" then
        x=e.motion.startX or x; y=e.motion.startY or y
      elseif e.motion.kind == "anim_linear_fixed" or e.motion.kind == "vice_grip_pincer" or e.motion.kind == "air_wave_crescent" or e.motion.kind == "sonic_boom_projectile" or e.motion.kind == "bone_hit_projectile" then
        -- FireRed InitAnimLinearTranslation / AnimTranslateLinear. Magnitudes
        -- are unsigned 8.8 values; the low bit stores direction (set for
        -- negative, cleared for positive). age 0 is the callback's setup-only
        -- frame; StartAnimLinearTranslation performs step 1 on the next tick.
        local d=math.max(1,math.floor(e.motion.nativeDuration or e.motion.duration or 1))
        local steps=math.min(d,math.max(0,age))
        local function axis(startv,endv)
          local diff=(endv or 0)-(startv or 0)
          local mag=math.floor(math.abs(diff)*256/d)
          if diff < 0 then
            if mag % 2 == 0 then mag=mag+1 end
            return (startv or 0)-math.floor((mag*steps)/256)
          else
            if mag % 2 == 1 then mag=mag-1 end
            return (startv or 0)+math.floor((mag*steps)/256)
          end
        end
        x=axis(e.motion.startX,e.motion.endX)
        y=axis(e.motion.startY,e.motion.endY)
      else
        x = lerp(e.motion.startX,e.motion.endX,t)
        y = lerp(e.motion.startY,e.motion.endY,t)
      end
      -- Grounded per-battler effects need a side-specific staged anchor.
      -- PotatoVoxel/Battle Art already transform the whole animation layer
      -- around the pair midpoint, so compute the desired projected foot point
      -- and inverse-map it into authored layer coordinates here. The renderer
      -- then applies its transform exactly once.
      if e.motion.stagedFootBattler and self.voxelCompat then
        local staged=self.voxelCompat:state(battle)
        if staged then
          local battler=(e.motion.stagedFootBattler=="target") and a.targetBattler or a.attackerBattler
          local anchor=self.voxelCompat:anchor(staged,battler)
          if anchor then
            local k=tonumber(staged.animationScale) or 1
            local dx=(x or 0)-(e.motion.stagedFootBaseX or 0)
            local dy=(y or 0)-(e.motion.stagedFootBaseY or 0)
            local wantX=anchor[1]+dx*k
            local wantY=anchor[2]+dy*k
            local ux,uy=self.voxelCompat:unprojectPoint(staged,wantX,wantY)
            if ux and uy then x,y=ux,uy end
          end
        end
      end
      local paletteRotation=0
      if e.motion.kind=="elliptical_gust" or e.motion.kind=="gust_to_target" then
        paletteRotation=math.floor(age/((e.motion.paletteCycleDelay or 1)+1))%8
      elseif e.motion.kind=="aurora_beam_ring" then
        local start=e.motion.paletteCycleStartFrame or e.frame
        paletteRotation=math.floor(math.max(0,f-start)/3)%8
      elseif e.motion.kind=="defensive_wall" and age >= 14 and age <= 45 then
        -- FireRed AnimDefensiveWall_Step3 rotates palette entries 1..8 once
        -- every two callbacks for 16 rotations while the wall is fully visible.
        paletteRotation=math.floor((age-13)/2)%8
      end
      local img,animFrame
      if e.motion.kind=="wavy_music_note" then
        local variants={
          [0]={off=0},[1]={off=4},[2]={off=8},[3]={off=12},
          [4]={off=16},[5]={off=20},[6]={off=0,vFlip=true},[7]={off=4,vFlip=true},
        }
        local v=variants[(e.motion.noteVariant or 0)%8] or variants[0]
        local cycle=(e.motion.paletteCycleTime or 0)+1
        local pal=(e.motion.paletteStart+math.floor(age/math.max(1,cycle)))%4
        img=self.visualAssets:imageForVariant(e,v.off,pal)
        animFrame={vFlip=v.vFlip}
      elseif e.motion.kind=="roar_noise_line" and (e.motion.direction or 0)==2 then
        local off=(math.floor(age/3)%2==0) and 32 or 48
        img=self.visualAssets:imageForTileOffset(e,off)
      elseif e.motion.kind=="leech_seed" then
        local travel=e.motion.travelDuration or 35
        local hidden=e.motion.hiddenDuration or 10
        if age >= travel and age < travel+hidden then
          img=nil
        elseif age >= travel+hidden then
          -- Native sprout anim 1 alternates tile offsets 4 and 8 every 7 frames.
          local sproutAge=age-(travel+hidden)
          local off=(math.floor(sproutAge/7)%2==0) and 4 or 8
          img=self.visualAssets:imageForTileOffset(e,off)
        else
          img=self.visualAssets:imageForTileOffset(e,0)
        end
      elseif e.motion.kind=="water_bubble_projectile" then
        local travel=e.motion.travelDuration or 50
        local off=0
        if age>=travel then
          local impactAge=age-travel
          if impactAge>=1 and impactAge<6 then off=4
          elseif impactAge>=6 and impactAge<11 then off=8
          else off=0 end
        end
        img=self.visualAssets:imageForTileOffset(e,off)
      elseif e.motion.kind=="fist_foot_random_pos" then
        -- FireRed sAnims_HandsAndFeet: 0=fist, 1=wide foot, 2=tall foot,
        -- 3=left hand, 4=right hand (same tile as 3, horizontally flipped).
        local variant=math.floor(tonumber(e.motion.animVariant) or 0)%5
        local offsets={[0]=0,[1]=16,[2]=32,[3]=48,[4]=48}
        img=self.visualAssets:imageForTileOffset(e,offsets[variant] or 0)
        if variant==4 then animFrame={hFlip=true} end
      elseif e.motion.kind=="spinning_kick_or_punch" then
        -- FireRed sAnims_HandsAndFeet: anim 0 = fist (tile 0), anim 1 =
        -- wide foot (tile 16). Mega Punch uses 0; Mega Kick uses 1.
        local off=((e.motion.animVariant or 0)==1) and 16 or 0
        img=self.visualAssets:imageForTileOffset(e,off)
      elseif e.motion.kind=="dig_dirt_mound" then
        img=self.visualAssets:imageForTileOffset(e,8*((e.motion.tileHalf or 0)%2))
      elseif e.motion.kind=="rock_scatter" then
        local off=16*((e.motion.animVariant or 0)%6)
        img=self.visualAssets:imageForTileOffset(e,off)
        animFrame={rotation=-(age or 0)*5}
      elseif e.motion.kind=="soft_boiled_egg" then
        local off=0
        if age >= (e.motion.crackFrame or 104) then
          off=((e.motion.variant or 0)==0) and 16 or 32
        end
        img=self.visualAssets:imageForTileOffset(e,off)
      elseif e.motion.kind=="falling_rock" then
        -- sAnims_FlyingRock variants: tile offsets 32, 48, 64.
        local off=32+16*((e.motion.animVariant or 0)%3)
        img=self.visualAssets:imageForTileOffset(e,off)
      elseif e.motion.kind=="aurora_beam_ring" then
        local tf=e.motion.transformFrame
        local off=(tf and f>=tf) and 4 or 0
        -- Use the palette-rotated image for the currently selected ring frame.
        local resourceKey=tostring(e.tag)..":"..tostring(e.paletteTag or e.tag)
        local cache=self.visualAssets.tags and self.visualAssets.tags[resourceKey]
        local base=cache and cache.images and cache.images[off]
        if paletteRotation~=0 and cache and cache.rotatedImages and cache.rotatedImages[off] then
          base=cache.rotatedImages[off][paletteRotation] or base
        end
        img=base
      else
        local animAge=age
        if e.motion.kind=="movement_waves" then
          -- FireRed AnimMovementWaves restarts its 32-frame sprite animation
          -- for each repeat. Do not let the generic `once` playback clamp to
          -- the final frame between cycles.
          animAge=age % 32
        end
        if e.motion.kind=="air_wave_crescent" then animAge=age+(e.motion.animSeek or 0)*3 end
        if e.motion.kind=="whirlwind_line" then animAge=((e.motion.initialState or 0)+age)%5 end
        img,animFrame = self.visualAssets:imageFor(e,animAge,paletteRotation)
      end
      if e.motion.kind=="black_smoke" and (age%2)==0 then img=nil end
      if e.motion.kind=="mimic_orb" and age==0 then img=nil end
      local yoff = -16
      local w=(e.oam and e.oam.width) or 32
      local h=(e.oam and e.oam.height) or 32
      if img and e.motion.kind=="missile_arc" and e.motion.hideSetupFrame and age==0 then
        img=nil
      end
      if img then
        if e.motion.kind=="thunder_wave_band" then
          -- AnimThunderWave creates a second 32x16 half at +32 X and toggles
          -- both halves every three frames for exactly 51 frames.
          if math.floor(age/3)%2==1 then img=nil end
        end
      end
      if img and e.motion.kind=="tri_attack_triangle" then
        local count=age+1
        if count < 31 and (count % 2)==0 then img=nil end
      end
      if img and e.motion.kind=="flashing_hit_splat" then
        -- AnimFlashingHitSplat_Step toggles OBJ invisibility every callback.
        if age % 2 == 1 then img=nil end
      end
      if img and e.motion.kind=="sharpen_sphere" then
        -- Exact AnimSharpenSphere visibility state. data1 starts at 2; every
        -- two toggles its interval grows by one tick. The native sprite starts
        -- visible and is destroyed on tick 287 after the final invisible toggle.
        local visible=true
        local interval=2
        local within=0
        local togglesAtInterval=0
        for _=1,age do
          within=within+1
          if within>=interval then
            within=0
            visible=not visible
            togglesAtInterval=togglesAtInterval+1
            if togglesAtInterval>1 then
              togglesAtInterval=0
              interval=interval+1
            end
          end
        end
        if not visible then img=nil end
      end
      if img and e.motion.kind=="lick" and age >= (e.motion.animEnd or 10) then
        -- AnimLick_Step hides the completed tongue, then toggles it five
        -- times every 3 callbacks and five more times every 5 callbacks.
        local post=age-(e.motion.animEnd or 10)
        local visible=false
        if post < 15 then
          local toggles=math.floor((post+1)/3)
          visible=(toggles % 2)==1
        elseif post < 40 then
          local toggles=5+math.floor((post-15+1)/5)
          visible=(toggles % 2)==1
        end
        if not visible then img=nil end
      end
      if img and e.motion.kind=="dizzy_punch_duck" and age>0 then
        local data3=(age*3)%256
        if data3>100 and (data3%2)==1 then img=nil end
      end
      if img and e.motion.kind=="barrage_ball" and age >= 25 then
        -- State 2 toggles invisibility every two callbacks. The first toggle
        -- occurs on its second callback after the 16th translation step.
        local toggles=math.floor((age-24)/2)
        if toggles%2==1 then img=nil end
      end
      if img and e.motion.kind=="string_shot_wrap" then
        -- Native callback toggles on callbacks 3,6,...,48.
        if math.floor((age+1)/math.max(1,e.motion.blinkEvery or 3))%2==1 then img=nil end
      end
      if img and e.motion.kind=="thunderbolt_orb" then
        if math.floor(age/math.max(1,(e.motion.blinkDelay or 3)+1))%2==1 then img=nil end
      elseif img and e.motion.kind=="spark_electricity_flashing" then
        local div=math.max(1,e.motion.flashDiv or 3)
        local toggles=0
        for k=0,age do
          if (((e.motion.angle or 0)+k*(e.motion.angleStep or 0))%256)%div==0 then toggles=toggles+1 end
        end
        if toggles%2==1 then img=nil end
      end
      if img then
        -- FireRed ObjBlend sprites use GBA BLDALPHA, whose source and
        -- destination coefficients are independent. Map that equation onto
        -- Love2D's alpha blend instead of treating EVA as ordinary opacity.
        local rgbGain,alpha=1,1
        if e.motion.kind=="conversion_particle" then
          -- FireRed begins at BLDALPHA 16/0 (fully visible), then the shared
          -- task reduces EVA by one every four callbacks. Do this directly so
          -- the cells cannot disappear because of host destination-alpha rules.
          -- The palette flash happens on the still-opaque Conversion grid
          -- before the shared BLDALPHA reveal begins. Never let battler
          -- reveal alpha leak into the flash window.
          local conversionFlash=activeConversionGridFlash(a,f)
          alpha=conversionFlash and 1 or (activeConversionAlpha(a,f) or 1)
        elseif e.oam and e.oam.objMode=="blend" and e.alphaBlend then
          local blend=e.alphaBlend
          if e.motion.kind=="defensive_wall" then
            -- AnimDefensiveWall owns BLDALPHA after creation. It fades EVA
            -- 0->13 over 14 callbacks, holds at 13 while cycling the palette,
            -- then fades 13->0. Do not freeze the sprite at script setalpha 0,16.
            local eva
            if age <= 13 then eva=age
            elseif age <= 46 then eva=13
            else eva=math.max(0,59-age) end
            blend={eva=eva,evb=16-eva}
          end
          rgbGain,alpha=gbaObjBlendParams(blend,1)
        end
        if e.motion.kind=="soft_boiled_egg" and (e.motion.variant or 0)==0 then
          local fadeStart=(e.motion.crackFrame or 104)+9
          if age>=fadeStart then
            local step=math.min(16,math.floor((age-fadeStart)/3)+1)
            alpha=math.max(0,(16-step)/16)
          end
        end
        if e.motion.kind=="ice_effect_particle" and age >= (e.motion.flickerStart or 16) then
          -- AnimFlickerIceEffectParticle toggles invisibility every frame for 20 frames.
          if ((age-(e.motion.flickerStart or 16)) % 2)==0 then img=nil end
        end
        if img and e.motion.kind=="lovely_kiss_devil" then
          -- AnimDevil flickers while data3 < 10 and > 80 using data0 parity.
          if age < 9 or age > 79 then
            local data0,data2=0,1
            for _=0,math.max(0,age) do
              data0=data0+data2
              local ph=(data0*4)%256
              if ph>128 and data2>0 then data2=-1 end
              if ph==0 and data2<0 then data2=1 end
            end
            if (data0%2)==1 then img=nil end
          end
        elseif img and e.motion.kind=="lovely_kiss_heart" and age>44 then
          -- Pink-heart step flickers on alternating frames once data5 > 20.
          if ((age-24)%2)==1 then img=nil end
        end
        local flash=nil
        if img then
          flash=(e.motion.kind=="conversion_particle")
            and activeConversionGridFlash(a,f) or activeSpriteTagFlash(a,f,e.tag)
          if flash then
            g.setColor(flash.r*rgbGain,flash.g*rgbGain,flash.b*rgbGain,alpha)
          else
            g.setColor(rgbGain,rgbGain,rgbGain,alpha)
          end
        end
        if img and e.motion.kind=="conversion_particle" then
          local ds=e.displayScale or self.battleSpace.spriteDisplayScale()
          -- FireRed sConversionAffineAnimCmds starts at 0x200/0x200. The
          -- sprite affine animation engine expresses visible scale in 8.8
          -- units here: 0x100 = 1x, 0x200 = 2x. Each native 8x8 cell is
          -- therefore displayed as 16x16. The script offsets (-24,-8,8,24)
          -- are exactly 16 px apart, so the 16 cells meet edge-to-edge as a
          -- continuous 64x64 Conversion grid over the attacker.
          local scale=ds*2.0
          -- FireRed's BLDALPHA stage is an actual blend operation. Isolate
          -- Conversion from whatever blend mode the surrounding battle pass
          -- left active so the shared EVA value can genuinely fade the OBJ
          -- grid instead of merely changing vertex alpha under a replace pass.
          g.push("all")
          g.setBlendMode("alpha")
          if flash then
            g.setColor(flash.r*rgbGain,flash.g*rgbGain,flash.b*rgbGain,alpha)
          else
            g.setColor(rgbGain,rgbGain,rgbGain,alpha)
          end
          g.draw(img,math.floor(x+0.5),math.floor(y+yoff+16+0.5),0,scale,scale,w/2,h/2)
          g.pop()
        elseif img and e.motion.kind=="soft_boiled_egg" then
          local ds=e.displayScale or self.battleSpace.spriteDisplayScale()
          local angle,sxScale,syScale=0,ds,ds
          if age < (e.motion.hopFrames or 51) then
            local k=age%8
            local rotUnits
            if k<2 then rotUnits=-8*(k+1)
            elseif k<6 then rotUnits=-16+8*(k-1)
            else rotUnits=16-8*(k-5) end
            angle=-rotUnits*math.pi*2/256
          else
            local squeezeStart=(e.motion.hopFrames or 51)+(e.motion.holdFrames or 21)
            local crack=e.motion.crackFrame or 104
            if age>=squeezeStart and age<crack then
              local q=(age-squeezeStart)%16
              local phase=(q<=8) and q or (16-q)
              local mx=256-8*phase
              local my=256+4*phase
              sxScale=ds*256/math.max(1,mx)
              syScale=ds*256/math.max(1,my)
            end
          end
          g.draw(img,math.floor(x+0.5),math.floor(y+yoff+16+0.5),angle,sxScale,syScale,w/2,h/2)
        elseif img and e.motion.kind=="mimic_orb" then
          local ds=e.displayScale or self.battleSpace.spriteDisplayScale()
          local grow=math.max(1,e.motion.growFrames or 14)
          local native
          if age<=0 then native=1
          elseif age<=grow then native=48*age
          else native=48*grow-16*math.min(e.motion.travelDuration or 25,age-grow) end
          native=math.max(1,native)
          local scale=ds*(256/native)
          g.draw(img,math.floor(x+0.5),math.floor(y+yoff+16+0.5),0,scale,scale,w/2,h/2)
        elseif img and e.motion.kind=="sleep_letter_z" then
          -- FireRed affine program: initial matrix scale +0x14, then +0x8 for
          -- 24 frames; rotation begins at +/-30 and moves 1 unit toward zero.
          -- The affine animation ends after 24 frames and leaves that matrix.
          local ds=e.displayScale or self.battleSpace.spriteDisplayScale()
          local k=math.min(24,math.max(0,age))
          local matrixScale=0x100+0x14+(0x8*k)
          local scale=ds*(0x100/matrixScale)
          local rotUnits
          if e.motion.playerSide then rotUnits=-30+k else rotUnits=30-k end
          local angle=-rotUnits*math.pi*2/256
          g.draw(img,math.floor(x+0.5),math.floor(y+yoff+16+0.5),angle,scale,scale,w/2,h/2)
        elseif img and e.motion.kind=="metronome_thought_bubble" then
          local ds=e.displayScale or self.battleSpace.spriteDisplayScale()
          local tile=48
          local hflip=e.motion.playerSide==true
          if age < 8 then
            tile=math.floor(age/2)*16
          elseif age >= 108 then
            local k=math.min(3,math.floor((age-108)/2))
            tile=(3-k)*16
          end
          local bubble=self.visualAssets:imageForTileOffset(e,tile) or img
          -- FireRed uses the four native 32x32 frames from the ThoughtBubble
          -- sheet.  Do not upscale: frame 48 is the full-size bubble; the
          -- previous tiny appearance was caused by offsets 16/32/48 not being
          -- cached, which made every stage fall back to the small frame 0.
          local inward=e.motion.playerSide and -6 or 6
          local sx=hflip and -ds or ds
          local sy=ds
          g.draw(bubble,math.floor(x+inward+0.5),math.floor(y+yoff+16+0.5),0,sx,sy,w/2,h/2)
        elseif img and e.motion.kind=="metronome_finger" then
          local ds=e.displayScale or self.battleSpace.spriteDisplayScale()
          local nativeScale,rotUnits=256,0
          if age < 8 then
            nativeScale=math.min(256,16+30*(age+1))
          elseif age < 25 then
            nativeScale=256
          elseif age < 91 then
            local cycle=(age-25)%22
            rotUnits=(cycle<11) and (4*(cycle+1)) or (4*(22-cycle-1))
          else
            nativeScale=math.max(16,256-30*(age-90))
          end
          local scale=ds*(nativeScale/256)
          -- GBA affine matrix rotation is inverse to direct screen geometry.
          local angle=-rotUnits*math.pi*2/256
          -- Keep the finger and thought bubble as one Metronome gesture:
          -- both sit 6 px inward toward the selected battler.
          local inward=e.motion.playerSide and -6 or 6
          g.draw(img,math.floor(x+inward+0.5),math.floor(y+yoff+16+0.5),angle,scale,scale,w/2,h/2)
        elseif img and e.motion.kind=="question_mark" then
          local ds=e.displayScale or self.battleSpace.spriteDisplayScale()
          local rotUnits=0
          if age >= 54 and age < 102 then
            local t=(age-54)%16
            if t < 4 then rotUnits=4*(t+1)
            elseif t < 12 then rotUnits=16-4*(t-3)
            else rotUnits=-16+4*(t-11) end
          end
          local angle=-rotUnits*math.pi*2/256
          g.draw(img,math.floor(x+0.5),math.floor(y+yoff+16+0.5),angle,ds,ds,w/2,h/2)
        elseif img and e.motion.kind=="wavy_music_note" then
          local ds=e.displayScale or self.battleSpace.spriteDisplayScale()
          local phase=age%32
          local native=phase<16 and (256+12*phase) or (256+12*(32-phase))
          local scale=ds*native/256
          local sx=scale
          local sy=(animFrame and animFrame.vFlip) and -scale or scale
          g.draw(img,math.floor(x+0.5),math.floor(y+yoff+16+0.5),0,sx,sy,w/2,h/2)
        elseif img and e.motion.kind=="roar_noise_line" then
          local ds=e.displayScale or self.battleSpace.spriteDisplayScale()
          local sx=e.motion.hFlip and -ds or ds
          local sy=e.motion.vFlip and -ds or ds
          g.draw(img,math.floor(x+0.5),math.floor(y+yoff+16+0.5),0,sx,sy,w/2,h/2)
        elseif img and e.motion.kind=="thunder_wave_band" then
          local ds=e.displayScale or 1
          local yy=math.floor(y+yoff+(16-(h*ds)/2)+0.5)
          local xx=math.floor(x-(w*ds)/2+0.5)
          g.draw(img,xx,yy,0,ds,ds)
          local right=self.visualAssets:imageForTileOffset(e,8)
          if right then g.draw(right,xx+32*ds,yy,0,ds,ds) end
        elseif img and (e.motion.kind=="water_gun_droplet" or e.motion.kind=="acid_poison_droplet") then
          local ds=e.displayScale or 1
          local sx,sy=waterDropletScaleAtAge(age)
          g.draw(img,math.floor(x+0.5),math.floor(y+yoff+16+0.5),0,
            ds*sx,ds*sy,w/2,h/2)
        elseif img and e.motion.kind=="acid_poison_bubble" then
          local ds=e.displayScale or 1
          -- sAffineAnim_PoisonProjectile: start at 0x160, shrink by 0x0A for
          -- ten frames, then grow by 0x0A for ten frames, looping.
          local phase=age%20
          local native=(phase<10) and (352-10*phase) or (252+10*(phase-10))
          local scale=ds*(native/256)
          g.draw(img,math.floor(x+0.5),math.floor(y+yoff+16+0.5),0,scale,scale,w/2,h/2)
        elseif img and e.motion.kind=="bone_hit_projectile" then
          local ds=e.displayScale or 1
          -- FireRed affine OBJ matrices rotate with the inverse draw sign.
          local angle=-(((age+1)*(e.motion.affineRotationStep or 20))%256)*math.pi*2/256
          g.draw(img,math.floor(x+0.5),math.floor(y+yoff+16+0.5),angle,ds,ds,w/2,h/2)
        elseif img and e.motion.kind=="bonemerang_projectile" then
          local ds=e.displayScale or 1
          local angle=-(((age+1)*(e.motion.affineRotationStep or 15))%256)*math.pi*2/256
          g.draw(img,math.floor(x+0.5),math.floor(y+yoff+16+0.5),angle,ds,ds,w/2,h/2)
        elseif img and e.motion.kind=="ice_punch_swirl" and (e.motion.affineRotationStep or 0)~=0 then
          local ds=e.displayScale or 1
          local angle=((age+1)*(e.motion.affineRotationStep or 40)%256)*math.pi*2/256
          g.draw(img,math.floor(x+0.5),math.floor(y+yoff+16+0.5),angle,ds,ds,w/2,h/2)
        elseif img and e.motion.kind=="ice_beam_particle" and (e.motion.affineRotationStep or 0)~=0 then
          local ds=e.displayScale or 1
          local angle=((age+1)*(e.motion.affineRotationStep or 10)%256)*math.pi*2/256
          g.draw(img,math.floor(x+0.5),math.floor(y+yoff+16+0.5),angle,ds,ds,w/2,h/2)
        elseif img and e.motion.kind=="confuse_ray_bounce" then
          local ds=e.displayScale or 1
          local scale,angle=confuseRayAffineAtAge(age)
          local nativeAlpha=confuseRayAlphaAtAge(age)
          g.setColor(rgbGain,rgbGain,rgbGain,alpha*nativeAlpha)
          g.draw(img,math.floor(x+0.5),math.floor(y+yoff+16+0.5),angle,
            ds*scale,ds*scale,w/2,h/2)
        elseif img and e.motion.kind=="aurora_beam_ring" then
          local ds=e.displayScale or 1
          local tf=e.motion.transformFrame
          local nativeScale=1
          if tf and f>=tf then
            -- AFFINEANIM: one frame at 0x100 then +0x60 for one frame.
            nativeScale=(f==tf) and 1 or (0x160/0x100)
          end
          local scale=ds*nativeScale
          g.draw(img,math.floor(x+0.5),math.floor(y+yoff+16+0.5),0,scale,scale,w/2,h/2)
        elseif img and e.motion.kind=="dragon_fire_to_target" then
          local ds=e.displayScale or self.battleSpace.spriteDisplayScale()
          -- Native Dragon Rage fire uses affine scale 0x64 on both axes. GBA
          -- affine matrices are inverse scale, so 0x64 displays at 256/100.
          local sc=256/100
          local angle=e.motion.opponent and (127*math.pi*2/256) or 0
          g.draw(img,math.floor(x+0.5),math.floor(y+yoff+16+0.5),angle,ds*sc,ds*sc,w/2,h/2)
        elseif img and e.motion.kind=="water_bubble_projectile" then
          local ds=e.displayScale or 1
          local travel=e.motion.travelDuration or 50
          local pulseAge=math.min(age,math.max(0,travel-1))%20
          local affine=(pulseAge<10) and (256-5*(pulseAge+1)) or (206+5*(pulseAge-9))
          local scale=ds*(affine/256)
          g.draw(img,math.floor(x+0.5),math.floor(y+yoff+16+0.5),0,scale,scale,w/2,h/2)
        elseif img and e.motion.kind=="bubble_effect" then
          local ds=e.displayScale or 1
          local affine=math.min(256,156+5*math.min(age,20))
          local scale=ds*(affine/256)
          g.draw(img,math.floor(x+0.5),math.floor(y+yoff+16+0.5),0,scale,scale,w/2,h/2)
        elseif img and e.motion.kind=="thunderbolt_orb" then
          local ds=e.displayScale or 1
          local pulse=age%20
          local affine=(pulse<10) and (232-8*pulse) or (160+8*(pulse-10))
          local scale=ds*(affine/256)
          local animOff=math.floor(age/6)%3*16
          local orb=self.visualAssets:imageForTileOffset(e,animOff) or img
          g.draw(orb,math.floor(x+0.5),math.floor(y+yoff+16+0.5),0,scale,scale,w/2,h/2)
        elseif img and e.motion.kind=="spinning_kick_or_punch" then
          local ds=e.displayScale or self.battleSpace.spriteDisplayScale()
          local spinDuration=e.motion.spinDuration or 50
          local scale,angle=1,0
          if age < spinDuration then
            -- sAffineAnim_MegaPunchKick: -4 scale units and +20 angle units
            -- each frame, looping from the second affine command.
            local step=age+1
            scale=(256-4*step)/256
            angle=((20*step)%256)*math.pi*2/256
          end
          g.draw(img,math.floor(x+0.5),math.floor(y+yoff+16+0.5),angle,
            ds*scale,ds*scale,w/2,h/2)
        elseif img and e.motion.kind=="hyper_beam_orb" then
          local orb=self.visualAssets:imageForTileOffset(e,e.motion.tileOffset or 0) or img
          local ds=e.displayScale or self.battleSpace.spriteDisplayScale()
          g.draw(orb,math.floor(x+0.5),math.floor(y+yoff+16+0.5),0,ds,ds,
            ((e.oam and e.oam.width) or 8)/2,((e.oam and e.oam.height) or 8)/2)
          img=nil
        elseif img and e.motion.kind=="sludge_projectile" then
          -- sAffineAnim_PoisonProjectile: start at 0x160, shrink by 0x0A
          -- for ten frames, grow by 0x0A for ten, then repeat.
          local ds=e.displayScale or self.battleSpace.spriteDisplayScale()
          local half=e.motion.affinePulseHalf or 10
          local phase=age%(half*2)
          local start=e.motion.affineStartScale or (0x160/256)
          local d=e.motion.affinePulseDelta or (0x0A/256)
          local sc=(phase<half) and (start-d*phase) or (start-d*half+d*(phase-half))
          g.draw(img,math.floor(x+0.5),math.floor(y+yoff+16+0.5),0,ds*sc,ds*sc,
            ((e.oam and e.oam.width) or 16)/2,((e.oam and e.oam.height) or 16)/2)
          img=nil
        elseif img and e.motion.kind=="absorption_orb" then
          local ds=e.displayScale or self.battleSpace.spriteDisplayScale()
          local sc=math.max(0.20,1+age*(e.motion.affineScaleDelta or 0))
          -- Keep absorption orbs in the same battler presentation space as
          -- every other FireRed OBJ. The first Dream Eater port omitted the
          -- shared move Y offset / +16 baseline here, so the correct target ->
          -- attacker arcs were rendered vertically displaced from the mons.
          g.draw(img,math.floor(x+0.5),math.floor(y+yoff+16+0.5),0,ds*sc,ds*sc,
            ((e.oam and e.oam.width) or 16)/2,((e.oam and e.oam.height) or 16)/2)
          img=nil
        elseif img and e.motion.kind=="power_absorption_orb" then
          local orb=self.visualAssets:imageForTileOffset(e,e.motion.tileOffset or 8) or img
          local ds=e.displayScale or self.battleSpace.spriteDisplayScale()
          local sc=math.max(0.20,1+age*(e.motion.affineScaleDelta or 0))
          g.draw(orb,math.floor(x+0.5),math.floor(y+yoff+16+0.5),0,ds*sc,ds*sc,
            ((e.oam and e.oam.width) or 16)/2,((e.oam and e.oam.height) or 16)/2)
          img=nil
        elseif img and (e.motion.kind=="solar_beam_big_orb" or e.motion.kind=="solar_beam_small_orb") then
          local orb=self.visualAssets:imageForTileOffset(e,e.motion.tileOffset or 0) or img
          local ds=e.displayScale or self.battleSpace.spriteDisplayScale()
          g.draw(orb,math.floor(x+0.5),math.floor(y+yoff+16+0.5),0,ds,ds,
            ((e.oam and e.oam.width) or 8)/2,((e.oam and e.oam.height) or 8)/2)
          img=nil
        elseif img and e.motion.kind=="barrage_ball" then
          local ds=e.displayScale or self.battleSpace.spriteDisplayScale()
          local n=math.min(24,math.max(0,age))
          local rotUnits
          if e.motion.attackerSide=="player" then
            rotUnits=-4*n
          else
            -- sBarrageBallAffineAnimCmds2 starts at -64 then adds +4 for 24 frames.
            rotUnits=-64+4*n
          end
          local angle=rotUnits*math.pi*2/256
          g.draw(img,math.floor(x+0.5),math.floor(y+yoff+16+0.5),angle,ds,ds,w/2,h/2)
          img=nil
        elseif img and e.motion.kind=="leech_life_needle" then
          -- FireRed gLeechLifeNeedleSpriteTemplate starts affine animation 0:
          -- a one-shot rotation transform on the vertical needle art; the host renderer uses the sign-corrected +33 orientation.
          -- The motion callback already preserves the source rotationUnits;
          -- render it here instead of falling through to the unrotated OBJ path.
          local ds=e.displayScale or self.battleSpace.spriteDisplayScale()
          local angle=(e.motion.rotationUnits or 0)*math.pi*2/256
          g.draw(img,math.floor(x+0.5),math.floor(y+yoff+16+0.5),angle,ds,ds,w/2,h/2)
        elseif img and e.motion.kind=="linear_stinger" then
          -- AnimTranslateStinger keeps its source-traced rotation/path, but its
          -- base sprite size now comes from the same global scale as every OBJ.
          local ds=e.displayScale or self.battleSpace.spriteDisplayScale()
          local dx=(e.motion.endX or x)-(e.motion.startX or x)
          local dy=(e.motion.endY or y)-(e.motion.startY or y)
          -- Needle art is vertical. This is the Love2D equivalent of FireRed's
          -- ArcTan2Neg(dest-start) + 0xC000 rotation applied once at creation.
          -- Gen1Recomp runs LuaJIT, where the two-axis arctangent is
          -- math.atan2(y, x). math.atan only consumes the first argument,
          -- which flattened steep stinger paths to an almost-horizontal angle.
          local angle=math.atan2(dy,dx)+math.pi/2
          g.draw(img,math.floor(x+0.5),math.floor(y+yoff+16+0.5),angle,ds,ds,w/2,h/2)
        elseif img and e.motion.kind=="coin_throw" then
          local ds=e.displayScale or self.battleSpace.spriteDisplayScale()
          g.draw(img,math.floor(x+0.5),math.floor(y+yoff+16+0.5),e.motion.rotation or 0,ds,ds,w/2,h/2)
        elseif img and e.motion.kind=="falling_coin" then
          local ds=e.displayScale or self.battleSpace.spriteDisplayScale()
          local angle=((age*(e.motion.spinStep or 10))%256)*math.pi*2/256
          g.draw(img,math.floor(x+0.5),math.floor(y+yoff+16+0.5),angle,ds,ds,w/2,h/2)
        elseif img and e.motion.kind=="missile_arc" then
          local ds=e.displayScale or 1
          local d=math.max(1,e.motion.duration or 1)
          local prevAge=math.max(0,age-1)
          local pt=clamp(prevAge/d,0,1)
          local px=lerp(e.motion.startX,e.motion.endX,pt)
          local amp=missileArcAmplitude or (e.motion.arcAmplitude or 0)
          local py=lerp(e.motion.startY,e.motion.endY,pt)+math.sin(pt*math.pi)*amp
          local dx=x-px
          local dy=y-py
          if math.abs(dx)<0.0001 and math.abs(dy)<0.0001 then
            local nt=clamp((age+1)/d,0,1)
            local nx=lerp(e.motion.startX,e.motion.endX,nt)
            local ny=lerp(e.motion.startY,e.motion.endY,nt)+math.sin(nt*math.pi)*amp
            dx=nx-x; dy=ny-y
          end
          -- gPinMissileSpriteTemplate's needle art is vertical. FireRed uses
          -- ArcTan2Neg(tangent) + 0xC000, which corresponds to orienting that
          -- vertical source along the screen-space trajectory.
          local angle=math.atan(dy,dx)+math.pi/2
          g.draw(img,math.floor(x+0.5),math.floor(y+yoff+16+0.5),angle,ds,ds,w/2,h/2)
        elseif img and (e.motion.kind=="hit_splat" or e.motion.kind=="linked_hit_splat" or e.motion.kind=="flashing_hit_splat" or e.motion.kind=="hit_splat_handle_invert") then
          local ds=e.displayScale or 1
          local scale=ds*hitSplatScale(e.motion.affineVariant)
          g.draw(img,math.floor(x+0.5),math.floor(y+yoff+16+0.5),0,scale,scale,w/2,h/2)
        elseif img and e.motion.kind=="horn_hit" then
          local ds=e.displayScale or 1
          local sx=e.motion.hFlip and -ds or ds
          local sy=e.motion.vFlip and -ds or ds
          g.draw(img,math.floor(x+0.5),math.floor(y+yoff+16+0.5),0,sx,sy,w/2,h/2)
        elseif img and e.motion.kind=="vice_grip_pincer" then
          local ds=e.displayScale or self.battleSpace.spriteDisplayScale()
          local sx=e.motion.hFlip and -ds or ds
          local sy=e.motion.vFlip and -ds or ds
          g.draw(img,math.floor(x+0.5),math.floor(y+yoff+16+0.5),0,sx,sy,w/2,h/2)
        elseif img and e.motion.kind=="guillotine_pincer" then
          local ds=e.displayScale or self.battleSpace.spriteDisplayScale()
          local reverse=age >= (e.motion.reverseFrame or 49)
          local hf=e.motion.hFlip
          local vf=e.motion.vFlip
          if reverse then hf=not hf; vf=not vf end
          local sx=hf and -ds or ds
          local sy=vf and -ds or ds
          g.draw(img,math.floor(x+0.5),math.floor(y+yoff+16+0.5),0,sx,sy,w/2,h/2)
        elseif img and e.motion.kind=="gust_to_target" then
          local ds=e.displayScale or self.battleSpace.spriteDisplayScale()
          local grow=math.min(e.motion.affineDuration or 24,math.max(0,age))
          local sx=ds*math.min(1,(16+10*grow)/256)
          g.draw(img,math.floor(x+0.5),math.floor(y+yoff+16+0.5),0,sx,ds,w/2,h/2)
        elseif img and e.motion.kind=="fly_ball_up" then
          local ds=e.displayScale or self.battleSpace.spriteDisplayScale()
          local sx,sy=16/256,1
          if age<=6 then sx=math.min(1,(16+40*age)/256)
          else sx=1 end
          if age>6 and age<=11 then sy=math.max(96/256,(256-32*(age-6))/256)
          elseif age>11 then
            local q=math.min(10,age-11)
            sx=math.max(96/256,(256-16*q)/256)
            sy=(96+32*q)/256
          end
          g.draw(img,math.floor(x+0.5),math.floor(y+yoff+16+0.5),0,ds*sx,ds*sy,w/2,h/2)
        elseif img and e.motion.kind=="sonic_boom_projectile" then
          local ds=e.displayScale or self.battleSpace.spriteDisplayScale()
          local angle=(e.motion.rotationUnits or 0)*math.pi*2/256
          g.draw(img,math.floor(x+0.5),math.floor(y+yoff+16+0.5),angle,ds,ds,w/2,h/2)
        elseif img and e.motion.kind=="fly_ball_attack" then
          local ds=e.displayScale or self.battleSpace.spriteDisplayScale()
          local angle=(e.motion.rotationUnits or 0)*math.pi*2/256
          g.draw(img,math.floor(x+0.5),math.floor(y+yoff+16+0.5),angle,ds,ds,w/2,h/2)
        elseif img and e.motion.kind=="sky_attack_bird" then
          local ds=e.displayScale or self.battleSpace.spriteDisplayScale()
          local dx=(e.motion.endX or x)-(e.motion.startX or x)
          local dy=(e.motion.endY or y)-(e.motion.startY or y)
          -- FireRed uses ArcTan2Neg(dx, dy) + 0xC000 in GBA affine space.
          -- Love2D's screen-space rotation convention differs, so convert from
          -- the actual flight vector exactly as for the correctly oriented
          -- stinger projectiles: vertical source art points along trajectory.
          local angle=math.atan2(dy,dx)+math.pi/2
          g.draw(img,math.floor(x+0.5),math.floor(y+yoff+16+0.5),angle,ds,ds,w/2,h/2)
        elseif img and e.motion.kind=="razor_wind_tornado" then
          local ds=e.displayScale or self.battleSpace.spriteDisplayScale()
          local sx=ds*(16+4*math.min(40,math.max(0,age)))/256
          g.draw(img,math.floor(x+0.5),math.floor(y+yoff+16+0.5),0,sx,ds,w/2,h/2)
        elseif img and e.motion.kind=="tri_attack_triangle" then
          local ds=e.displayScale or self.battleSpace.spriteDisplayScale()
          -- sTriAttackTriangleAffineAnimCmds rotation deltas: 5x40,
          -- 10x10, 15x10, 20x40, then loop. Full GBA affine turn = 256.
          local cycle=age%100
          local rot
          if cycle < 40 then rot=5*(cycle+1)
          elseif cycle < 50 then rot=5*40+10*(cycle-39)
          elseif cycle < 60 then rot=5*40+10*10+15*(cycle-49)
          else rot=5*40+10*10+15*10+20*(cycle-59) end
          local angle=(rot%256)*math.pi*2/256
          g.draw(img,math.floor(x+0.5),math.floor(y+yoff+16+0.5),angle,ds,ds,w/2,h/2)
        elseif img and e.motion.kind=="swords_dance_blade" then
          local ds=e.displayScale or self.battleSpace.spriteDisplayScale()
          local grow=math.min(12,math.max(0,age))
          local sx=ds*math.min(1,(16+20*grow)/256)
          g.draw(img,math.floor(x+0.5),math.floor(y+yoff+16+0.5),0,sx,ds,w/2,h/2)
        elseif img and e.motion.kind=="constrict_binding" then
          local ds=e.displayScale or self.battleSpace.spriteDisplayScale()
          local release=e.motion.releaseAfter or 0
          local localAge=math.max(0,age-release)
          local cycle=localAge%12
          local native=256
          if age>=release then
            if cycle<=6 then native=256-11*cycle else native=190+11*(cycle-6) end
          end
          native=math.max(1,math.abs(native))
          local sx=ds*(256/native)
          if (e.motion.affineVariant or 0)==1 then sx=-sx end
          g.draw(img,math.floor(x+0.5),math.floor(y+yoff+16+0.5),0,sx,ds,w/2,h/2)
        elseif img and e.motion.kind=="bite" then
          local ds=e.displayScale or 1
          -- gAffineAnims_Bite has eight static orientations in 45-degree steps.
          local angle=((e.motion.affineVariant or 0)%8)*(math.pi/4)
          g.draw(img,math.floor(x+0.5),math.floor(y+yoff+16+0.5),angle,ds,ds,w/2,h/2)
        elseif img and e.motion.kind=="electricity_arc" then
          local ds=e.displayScale or 1
          local sx,sy=ds,ds
          if e.motion.variant==1 then sx=-ds elseif e.motion.variant==2 then sy=-ds end
          g.draw(img,math.floor(x+0.5),math.floor(y+yoff+16+0.5),0,sx,sy,w/2,h/2)
        elseif img and e.motion.kind=="spark_electricity_flashing" then
          local ds=e.displayScale or 1
          local angle=((age*20)%256)*math.pi*2/256
          g.draw(img,math.floor(x+0.5),math.floor(y+yoff+16+0.5),angle,ds,ds,w/2,h/2)
        elseif img and e.affineAnim and e.affineAnim.kind=="anger_pulse" then
          -- gAngerMarkSpriteTemplate: +11 matrix scale for 8 frames, then -11
          -- for 8. GBA affine scale matrices are inverse visual scale, so keep
          -- the mark centered while it contracts and returns to normal size.
          local ds=e.displayScale or self.battleSpace.spriteDisplayScale()
          local a=math.max(0,math.min(16,age))
          local matrix=256 + 11*(a<=8 and a or (16-a))
          local scale=ds*256/math.max(1,matrix)
          g.draw(img,math.floor(x+0.5),math.floor(y+yoff+16+0.5),0,scale,scale,w/2,h/2)
        elseif img and e.affineAnim and e.affineAnim.kind=="linear_scale" then
          -- Generic FireRed affine scale sequence. Values are native 8.8
          -- matrix scales, so 256 is normal size. This models templates such
          -- as gGrowingRingAffineAnimTable without move-specific draw hacks.
          local ds=e.displayScale or self.battleSpace.spriteDisplayScale()
          local start=tonumber(e.affineAnim.start) or 256
          local delta=tonumber(e.affineAnim.delta) or 0
          local frames=math.max(0,math.floor(tonumber(e.affineAnim.frames) or 0))
          local native=start+delta*math.min(age,frames)
          local scale=ds*math.max(0,native)/256
          g.draw(img,math.floor(x+0.5),math.floor(y+yoff+16+0.5),0,scale,scale,w/2,h/2)
        elseif img and e.motion.kind=="ice_effect_particle" then
          local scale=e.motion.startScale or 1
          if age < (e.motion.scaleStepFrames or 10) then
            scale=scale + age*(e.motion.scaleStep or 0)
          else
            scale=scale + (e.motion.scaleStepFrames or 10)*(e.motion.scaleStep or 0)
          end
          scale=scale*(e.displayScale or self.battleSpace.spriteDisplayScale())
          local xx=math.floor(x+0.5)
          local yy=math.floor(y+yoff+16+0.5)
          g.draw(img,xx,yy,0,scale,scale,w/2,h/2)
        elseif img then
          local ds=e.displayScale or self.battleSpace.spriteDisplayScale()
          if animFrame and (animFrame.hFlip or animFrame.vFlip) then
            local sx=animFrame.hFlip and -ds or ds
            local sy=animFrame.vFlip and -ds or ds
            g.draw(img,math.floor(x+0.5),math.floor(y+yoff+16+0.5),0,sx,sy,w/2,h/2)
          else
            g.draw(img, math.floor(x-(w*ds)/2+0.5), math.floor(y+yoff+(16-(h*ds)/2)+0.5), 0, ds, ds)
          end
        end
        g.setColor(1,1,1,1)
      end
    end
    end -- voxelEventOk
  end
  end -- not battlerLayerOnly (ordinary FireRed effect sprites)

  -- Haze is a BG1 layer at priority 1: it overlays the battler sprites while
  -- the priority-0 battle HUD remains above it. Draw the exact FireRed fog tile
  -- source as a repeating 240x144 native BG, scaled into Gen1Recomp's 160x96
  -- battlefield, and then repaint the HUD above the fog.
  if not effectLayerOnly then
    local haze,age,alpha=hazeFogState(a,f)
    if haze and alpha and alpha>0 then
      local img=ensureHazeFogImage(self)
      if img then
        local iw,ih=img:getDimensions()
        local q=a.hazeFogQuad
        if not q then q=g.newQuad(0,0,240,144,iw,ih); a.hazeFogQuad=q end
        local sx=(-age)%iw
        if q.setViewport then q:setViewport(sx,0,240,144,iw,ih) end
        g.setColor(1,1,1,alpha)
        g.draw(img,q,0,0,0,2/3,2/3)
        g.setColor(1,1,1,1)
        if type(battle.drawHUDs)=="function" then pcall(battle.drawHUDs,battle,0) end
      end
    end
  end
  g.setColor(1,1,1,1)
end

function M:reset(reason)
  if self.active then self:cancelActive(reason or "bridge reset") end
  self.pending = nil
  self.chargePending = nil
  self.nativeHitPending = nil
  self.animTurnSequence = nil
end

-- Pure structural checks that can run without a live battle or LÖVE renderer.
-- These catch the queue-shape regressions most likely to make the internal seam
-- unsafe before an actual battle is entered.
M._instantiatePlanForTest=instantiatePlan
M._hitSplatScaleForTest=hitSplatScale
M._waterDropletScaleAtAgeForTest=waterDropletScaleAtAge
M._confuseRayAffineAtAgeForTest=confuseRayAffineAtAge
M._confuseRayAlphaAtAgeForTest=confuseRayAlphaAtAge
M._missileArcSafeAmplitudeForTest=missileArcSafeAmplitude
M._gbaObjBlendParamsForTest=gbaObjBlendParams

function M.selfTest()
  local failures = {}
  local function expect(name,cond) if not cond then failures[#failures+1]=name end end
  local row = {anim="EMBER",animDelayed=true,hitRow=false}
  local b = {queue={row}, waitFrames=0}
  local ok = isClassicBattle(b)
  expect("classic queue accepted", ok == true)
  expect("front row identity", rowAtFront(b,row))
  expect("zero wait is ready", b.waitFrames == nil or b.waitFrames <= 0)
  b.isWideBattleLayout=function() return true end
  local ok2 = isClassicBattle(b)
  expect("wide layout rejected", ok2 == false)
  local snap=shallowCopy(row); row.anim=nil; row.hitRow=true
  expect("claimed row suppresses native animation", row.anim==nil and row.hitRow==true and snap.anim=="EMBER")

  local liveRow={anim="GUST"}
  local liveBattle={queue={liveRow}}
  local live={pending={battle=liveBattle,row=liveRow},stats={stalePendingCleared=0}}
  M.clearStalePending(live,liveBattle)
  expect("live pending row is retained", live.pending~=nil and live.stats.stalePendingCleared==0)

  local deadRow={anim="THUNDER_WAVE"}
  local deadBattle={queue={}}
  local dead={pending={battle=deadBattle,row=deadRow},stats={stalePendingCleared=0}}
  M.clearStalePending(dead,deadBattle)
  expect("removed pending row is cleared", dead.pending==nil and dead.stats.stalePendingCleared==1)

  local gain128,alpha128=gbaObjBlendParams({eva=12,evb=8},1)
  expect("BLDALPHA 12/8 keeps destination at 8/16", math.abs(alpha128-0.5)<0.000001)
  expect("BLDALPHA 12/8 keeps source at 12/16", math.abs(gain128*alpha128-0.75)<0.000001)
  local gain88,alpha88=gbaObjBlendParams({eva=8,evb=8},1)
  expect("BLDALPHA 8/8 maps to ordinary half blend", math.abs(gain88-1)<0.000001 and math.abs(alpha88-0.5)<0.000001)
  return {ok=#failures==0, failures=failures, checks=10}
end

function M:info()
  return {
    active = self.active ~= nil,
    pending = self.pending ~= nil,
    chargePending = self.chargePending ~= nil,
    classicLayoutOnly = true,
    registeredMoves = #self.registry:all(),
    nativeQueueReplacement = "transactional guarded hit-row substitution after MOVE_ANIM_PRE",
    triggered = self.stats.triggered,
    replaced = self.stats.replaced,
    failed = self.stats.failed,
    cancelled = self.stats.cancelled,
    reentrant = self.stats.reentrant,
    stalePendingCleared = self.stats.stalePendingCleared,
    completed = self.stats.completed,
    chargeTriggered = self.stats.chargeTriggered,
    chargeCompleted = self.stats.chargeCompleted,
    nativeHitSuppressed = self.stats.nativeHitSuppressed,
    nativeHitClaimedByFeedback = self.stats.nativeHitClaimedByFeedback,
    playerToEnemy = self.stats.playerToEnemy,
    enemyToPlayer = self.stats.enemyToPlayer,
    lastFailureReason = self.lastFailureReason,
  }
end

return M
