-- Shared staged-battle compatibility for third-party voxel renderers.
--
-- Move implementations should depend on this normalized contract rather than
-- renderer-specific fields. Flat battles return nil and remain untouched.
local M = {}
M.__index = M

local function finite(v)
  v=tonumber(v)
  return v and v==v and v~=math.huge and v~=-math.huge and v or nil
end

local function point(v)
  if type(v)~="table" then return nil end
  local x,y=finite(v[1] or v.x),finite(v[2] or v.y)
  if not (x and y) then return nil end
  return {x,y}
end

local function copyPoint(v,fallback)
  return point(v) or point(fallback)
end

local function distance(a,b)
  if not (a and b) then return nil end
  local dx,dy=b[1]-a[1],b[2]-a[2]
  return math.sqrt(dx*dx+dy*dy)
end

local function safeScale(v)
  v=finite(v) or 1
  if v<=0 then return 1 end
  return v
end

function M.new(opts)
  opts=opts or {}
  return setmetatable({mod=opts.mod,log=opts.log},M)
end

function M:_find(id)
  local mod=self.mod
  if not (mod and type(mod.find)=="function") then return nil end
  local ok,h=pcall(mod.find,id)
  if ok and type(h)=="table" then return h end
  ok,h=pcall(mod.find,mod,id)
  if ok and type(h)=="table" then return h end
  return nil
end

-- Battle Art Voxel Fork publishes a read-only battleStage API specifically for
-- compatibility consumers. Keep this adapter strictly on that public surface.
function M:_battleArt(battle)
  local handle=self:_find("BATTLE_ART_VOXEL_FORK")
  if not handle then return nil end
  local ex=handle.exports
  local stage=type(ex)=="table" and ex.battleStage or nil
  if not (stage and type(stage.state)=="function") then return nil end
  local ok,s=pcall(stage.state,battle)
  if not ok or type(s)~="table" or s.staged~=true or s.ready~=true then return nil end

  local projected=s.projectedAnchors or {}
  local authored=s.authoredAnchors or {}
  local player=copyPoint(projected.player)
  local enemy=copyPoint(projected.enemy)
  if not (player and enemy) then return nil end
  local ap=copyPoint(authored.player,{26,96})
  local ae=copyPoint(authored.enemy,{124,56})
  local scale=safeScale(s.animationScale)
  local mirrorPlayer=type(s.mirror)=="table" and s.mirror.player==true or false
  local mirrorEnemy=type(s.mirror)=="table" and s.mirror.enemy==true or false
  -- BattleStage v1 is intentionally read-only and does not currently publish
  -- the per-side presentation mirror. Battle Art does expose its loaded module
  -- namespace, so when the stage omits mirror metadata read only the public
  -- presentation settings used by its own monCards path. This keeps world
  -- clones and facing-relative motion aligned with the real staged player card.
  if not (type(s.mirror)=="table" and s.mirror.player~=nil) then
    local V=type(ex)=="table" and ex.lib or nil
    if V and type(V.require)=="function" then
      local okBA,BA=pcall(V.require,"BattleArt")
      if okBA and type(BA)=="table" then
        local side=type(BA.playerSide)=="function" and BA.playerSide() or "front"
        local flips=type(BA.flipsPlayerFront)=="function" and BA.flipsPlayerFront() or false
        mirrorPlayer=(side=="front" and flips==true)
      end
    end
  end

  return {
    provider="battle_art",
    sourceModId=s.sourceModId or "BATTLE_ART_VOXEL_FORK",
    staged=true,ready=true,
    ownership=type(s.ownership)=="table" and s.ownership or {battlers=true,animationProjection=true},
    projectedAnchors={player=player,enemy=enemy},
    authoredAnchors={player=ap,enemy=ae},
    animationScale=scale,
    backPinned=s.backPinned==true,
    -- Optional renderer-facing metadata. Battle Art currently does not
    -- publish a per-side mirror flag, so default to the engine image
    -- orientation unless a future API version provides one.
    mirror={player=mirrorPlayer,enemy=mirrorEnemy},
    raw=s,
  }
end

-- PotatoVoxel does not currently publish a battleStage export. Its supported
-- staged-battle seam is the live BattleState.dramaticShapeShot descriptor that
-- its own BattleState wrappers install while 3D-BTL is actually active. We
-- only consume that read-only descriptor and never require Potato private
-- modules or mutate its state.
function M:_potato(battle)
  if not self:_find("potato_voxel") then return nil end
  local shot=battle and battle.dramaticShapeShot
  if type(shot)~="table" then return nil end
  local player=copyPoint(shot.player)
  local enemy=copyPoint(shot.enemy)
  if not (player and enemy) then return nil end

  local anchors=type(shot.anchors)=="table" and shot.anchors or nil
  local ap=copyPoint(anchors and anchors.player,{26,96})
  local ae=copyPoint(anchors and anchors.enemy,{124,56})
  local authoredSpan=finite(shot.anchorSpan) or distance(ap,ae)
  local projectedSpan=distance(player,enemy)
  local scale=1
  if authoredSpan and authoredSpan>1 and projectedSpan and projectedSpan>1 then
    scale=projectedSpan/authoredSpan
    -- PotatoVoxel OverworldBattle.animScale clamps the staged animation layer
    -- to this exact 0.5..2.0 range. Mirror it so overlays line up with the
    -- renderer's own move-effect transform.
    if scale<0.5 then scale=0.5 elseif scale>2 then scale=2 end
  end

  return {
    provider="potato_voxel",
    sourceModId="potato_voxel",
    staged=true,ready=true,
    ownership={battlers=true,animationProjection=true},
    projectedAnchors={player=player,enemy=enemy},
    authoredAnchors={player=ap,enemy=ae},
    animationScale=safeScale(scale),
    -- PotatoVoxel stages both sides with FRONT art. Its BattleScene.monCards
    -- mirrors the player card by default so the near-side Pokemon faces the
    -- opponent; the enemy card remains unmirrored. Carry that presentation
    -- state through the shared adapter so clones/afterimages match the staged
    -- battler instead of showing the same front art facing the wrong way.
    mirror={player=true,enemy=false},
    raw=shot,
  }
end

function M:state(battle)
  -- Renderer mods conflict with each other, but prefer the explicit public
  -- Battle Art contract if a broken install exposes more than one handle.
  return self:_battleArt(battle) or self:_potato(battle)
end

-- FireRed's replacement Transform animation consumes the native
-- SE_TRANSFORM_MON presentation event that Battle Art normally observes.
-- Re-publish the same semantic handoff through Battle Art's own modules at
-- the exact FireRed mosaic midpoint so its static/animated species resolver
-- follows the copied Pokemon for the remainder of the battle.
function M:markBattleArtTransform(battle,user,target)
  local state=self:_battleArt(battle)
  if not (state and state.provider=="battle_art" and user and target) then return false end
  local handle=self:_find("BATTLE_ART_VOXEL_FORK")
  local V=handle and handle.exports and handle.exports.lib
  if not (V and type(V.require)=="function") then return false end
  local species=target.mon and target.mon.species
  if not species then return false end
  local okBA,BA=pcall(V.require,"BattleArt")
  local okABA,ABA=pcall(V.require,"AnimatedBattleArt")
  if not (okBA and type(BA)=="table" and type(BA.markTransformed)=="function") then return false end
  local okMark,res=pcall(BA.markTransformed,user,species)
  if not okMark or res==false then return false end
  if okABA and type(ABA)=="table" and type(ABA.abandonForTransform)=="function" then
    pcall(ABA.abandonForTransform,user)
  end
  return true
end

function M:isStaged(battle)
  return self:state(battle)~=nil
end

local function sideKey(side)
  if type(side)=="table" then
    if side.isPlayer==true or side.side=="player" then return "player" end
    return "enemy"
  end
  side=tostring(side or "")
  if side=="player" or side=="attacker_player" then return "player" end
  return "enemy"
end

function M:anchor(state,side)
  if type(state)~="table" then return nil end
  return copyPoint(state.projectedAnchors and state.projectedAnchors[sideKey(side)])
end

function M:authoredAnchor(state,side)
  if type(state)~="table" then return nil end
  return copyPoint(state.authoredAnchors and state.authoredAnchors[sideKey(side)])
end

function M:mirrorX(state,side)
  if type(state)~="table" then return false end
  local m=state.mirror
  return type(m)=="table" and m[sideKey(side)]==true or false
end

-- Project any point authored in the renderer's original battle-animation
-- coordinate space into the staged shot. This is useful for effects that are
-- not exactly on a battler anchor but should follow the same camera transform.
function M:projectPoint(state,x,y)
  if type(state)~="table" then return finite(x),finite(y) end
  x,y=finite(x),finite(y)
  if not (x and y) then return nil,nil end
  local ap=state.authoredAnchors and state.authoredAnchors.player
  local ae=state.authoredAnchors and state.authoredAnchors.enemy
  local pp=state.projectedAnchors and state.projectedAnchors.player
  local pe=state.projectedAnchors and state.projectedAnchors.enemy
  if not (ap and ae and pp and pe) then return x,y end
  local acx,acy=(ap[1]+ae[1])/2,(ap[2]+ae[2])/2
  local pcx,pcy=(pp[1]+pe[1])/2,(pp[2]+pe[2])/2
  local k=safeScale(state.animationScale)
  return pcx+(x-acx)*k,pcy+(y-acy)*k
end

-- Convert a desired staged screen-space point back into the authored
-- animation-layer coordinates expected by staged renderers. Their own
-- drawAnimLayer wrapper will then apply the shared center/scale transform once.
-- This is how per-battler ground effects can target an exact projected foot
-- position without being projected a second time.
function M:unprojectPoint(state,x,y)
  if type(state)~="table" then return finite(x),finite(y) end
  x,y=finite(x),finite(y)
  if not (x and y) then return nil,nil end
  local ap=state.authoredAnchors and state.authoredAnchors.player
  local ae=state.authoredAnchors and state.authoredAnchors.enemy
  local pp=state.projectedAnchors and state.projectedAnchors.player
  local pe=state.projectedAnchors and state.projectedAnchors.enemy
  if not (ap and ae and pp and pe) then return x,y end
  local acx,acy=(ap[1]+ae[1])/2,(ap[2]+ae[2])/2
  local pcx,pcy=(pp[1]+pe[1])/2,(pp[2]+pe[2])/2
  local k=safeScale(state.animationScale)
  return acx+(x-pcx)/k,acy+(y-pcy)/k
end

-- Resolve the currently displayed battler image for 2D effect overlays. This
-- deliberately uses BattleState's own picImage method so other sprite/art mods
-- continue to participate.
function M:battlerImage(battle,battler)
  if not (battle and battler and type(battle.picImage)=="function") then return nil end
  local sprite=battler.sprite or (battler.mon and battler.mon.sprite)
  if not sprite then return nil end
  local ok,img=pcall(battle.picImage,battle,sprite)
  if ok then return img end
  return nil
end

-- Generic projected clone/effect helper. This is intentionally renderer-
-- neutral: both Battle Art and PotatoVoxel hand back a screen-space anchor and
-- animation scale through state(). Moves can layer their FireRed-specific
-- opacity/scale/rotation on top without branching on renderer names.
function M:drawBattlerImage(state,battle,battler,opts)
  if not (state and battler and love and love.graphics) then return false end
  opts=opts or {}
  local anchor=self:anchor(state,battler)
  local img=opts.image or self:battlerImage(battle,battler)
  if not (anchor and img and type(img.getDimensions)=="function") then return false end
  local iw,ih=img:getDimensions()
  local k=safeScale(state.animationScale)
  local baseScale=finite(opts.scale) or 1
  local sx=k*(finite(opts.scaleX) or baseScale)
  local sy=k*(finite(opts.scaleY) or baseScale)
  local mirror=opts.mirrorX
  if mirror==nil then mirror=self:mirrorX(state,battler) end
  if mirror then sx=-sx end
  local alpha=finite(opts.alpha) or 1
  if alpha<0 then alpha=0 elseif alpha>1 then alpha=1 end
  local rotation=finite(opts.rotation) or 0
  local dx,dy=finite(opts.dx) or 0,finite(opts.dy) or 0
  -- Offsets are authored animation-space pixels, so stage-scale them too.
  dx,dy=dx*k,dy*k
  local g=love.graphics
  g.push("all")
  g.setColor(1,1,1,alpha)
  g.draw(img,anchor[1]+dx,anchor[2]+dy,rotation,sx,sy,iw/2,ih/2)
  g.pop()
  return true
end


-- Draw a battler image in the renderer's original authored battle-animation
-- coordinate space. This is for effects that are themselves being captured
-- into Potato Voxel's in-world animation texture: BattleScene.fxCard applies
-- the staged translation/scale later, so applying projected anchors here would
-- transform the clone twice.
function M:drawBattlerImageAuthored(state,battle,battler,opts)
  if not (state and battler and love and love.graphics) then return false end
  opts=opts or {}
  local anchor=self:authoredAnchor(state,battler)
  local img=opts.image or self:battlerImage(battle,battler)
  if not (anchor and img and type(img.getDimensions)=="function") then return false end
  local iw,ih=img:getDimensions()
  local baseScale=finite(opts.scale) or 1
  local sx=finite(opts.scaleX) or baseScale
  local sy=finite(opts.scaleY) or baseScale
  local mirror=opts.mirrorX
  if mirror==nil then mirror=self:mirrorX(state,battler) end
  if mirror then sx=-sx end
  local alpha=finite(opts.alpha) or 1
  if alpha<0 then alpha=0 elseif alpha>1 then alpha=1 end
  local rotation=finite(opts.rotation) or 0
  local dx,dy=finite(opts.dx) or 0,finite(opts.dy) or 0
  local g=love.graphics
  local ox=iw/2
  local oy=(opts.anchorMode=="feet") and ih or ih/2
  g.push("all")
  g.setColor(1,1,1,alpha)
  g.draw(img,anchor[1]+dx,anchor[2]+dy,rotation,sx,sy,ox,oy)
  g.pop()
  return true
end


-- Repaint the battle's bottom text/menu layer after mod animation overlays in
-- staged battles. Gen1Recomp calls battle.overlay after drawTextArea(), so any
-- custom animation drawn there would otherwise cover the menu. Keep this
-- strictly staged-only: flat battles retain the host renderer's native order.
function M:repaintBottomUI(state,battle)
  if type(state)~="table" or not battle then return false end
  if type(battle.drawTextArea)~="function" then return false end
  if type(battle.bottomUIVisible)=="function" then
    local ok,visible=pcall(battle.bottomUIVisible,battle)
    if ok and visible==false then return false end
  end
  -- WideBattle owns a different text-area layout. Do not paint the classic
  -- 160x48 box over it; staged voxel renderers currently use the classic
  -- battle surface. A future wide staged API can expose its own repaint seam.
  if type(battle.wideLayout)=="function" then
    local ok,wide=pcall(battle.wideLayout,battle)
    if ok and wide==true then return false end
  end
  local g=love and love.graphics
  if not g then return false end
  g.push("all")
  g.setScissor(0,96,160,48)
  local ok=pcall(battle.drawTextArea,battle)
  g.setScissor()
  g.pop()
  return ok
end

function M:info(battle)
  local s=battle and self:state(battle) or nil
  return {
    supported={"BATTLE_ART_VOXEL_FORK","potato_voxel"},
    active=s and s.provider or nil,
    staged=s~=nil,
    animationScale=s and s.animationScale or nil,
  }
end

return M
