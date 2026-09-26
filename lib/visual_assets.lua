-- Shared ROM-derived sprite cache for all registered moves.
local M = {}
M.__index = M

local function makeImage(frame, colors)
  if not (love and love.image and love.image.newImageData and love.graphics and love.graphics.newImage) then
    return nil, "LÖVE image/graphics API unavailable"
  end
  local h,w=#frame,#frame[1]
  local id=love.image.newImageData(w,h)
  for y=0,h-1 do for x=0,w-1 do
    local c=colors[(frame[y+1][x+1] or 0)+1] or {r=0,g=0,b=0,a=0}
    id:setPixel(x,y,(c.r or 0)/255,(c.g or 0)/255,(c.b or 0)/255,(c.a or 0)/255)
  end end
  local img=love.graphics.newImage(id)
  if img.setFilter then pcall(img.setFilter,img,"nearest","nearest") end
  return img
end

function M.new(opts)
  return setmetatable({rom=assert(opts.rom), assets=assert(opts.assets), graphics=assert(opts.graphics), visual=assert(opts.visual), tags={}, customImages={}},M)
end


function M:registerCustomImage(key,img)
  if not key or not img then return false end
  self.customImages=self.customImages or {}
  self.customImages[key]=img
  return true
end

function M:prepareDefinition(def, onlyDeferred)
  for _,template in pairs(def.templates or {}) do
    local deferred=(template.deferredPrepare==true)
    local selected=(onlyDeferred==true) and deferred or ((onlyDeferred~=true) and not deferred)
    if selected and not template.controller then
    local tag=assert(template.tileTag)
    local paletteTag=template.paletteTag or tag
    local resourceKey=tostring(tag)..":"..tostring(paletteTag)
    local cache=self.tags[resourceKey]
    if not cache then
      local sprite
      -- Glare's two assets are reached from already-proven neighboring FireRed
      -- resource-table entries. This keeps them ROM-native without introducing
      -- any new whole-ROM tag scan during move precache.
      if tag==10218 and paletteTag==10218 and self.assets.extractRelativeTaggedSprite then
        sprite=self.assets.extractRelativeTaggedSprite(self.rom,10219,-1,10218) -- Eye Sparkle <- Pink Heart
      elseif tag==10248 and paletteTag==10248 and self.assets.extractRelativeTaggedSprite then
        sprite=self.assets.extractRelativeTaggedSprite(self.rom,10254,-6,10248) -- Small Red Eye <- Red Ball
      elseif tag==10075 and paletteTag==10075 and self.assets.extractRelativeTaggedSprite then
        -- Kinesis ALERT is two contiguous records after the already-proven
        -- ANIM_TAG_DUCK resource used by Dizzy Punch/confusion status.
        sprite=self.assets.extractRelativeTaggedSprite(self.rom,10073,2,10075)
      elseif tag==10097 and paletteTag==10097 and self.assets.extractRelativeTaggedSprite then
        -- Kinesis BENT_SPOON immediately follows ANIM_TAG_PETAL in FireRed's
        -- contiguous sprite-sheet and palette tables. Petal is already a proven
        -- ROM-native resource in this mod. Resolve the spoon from that exact
        -- table record, while its deferred preparation remains isolated from
        -- Alert/zaps and all Poké Ball resources.
        sprite=self.assets.extractRelativeTaggedSprite(self.rom,10096,1,10097)
      else
        sprite=self.assets.extractTaggedSprite(self.rom,tag,paletteTag)
      end
      cache={colors=self.graphics.decodeBgr555(sprite.paletteBgr555),tiles=self.graphics.decode4bpp(sprite.tiles4bpp),images={},rotatedImages={},variantImages={}}
      self.tags[resourceKey]=cache
    end
    cache.variantImages=cache.variantImages or {}
    local anim=template.anim or {}
    local offsets={}
    for _,f in ipairs(anim.frames or {}) do offsets[#offsets+1]=f.tileOffset or 0 end
    -- Variant animations (e.g. FireRed Spore, hands/feet) keep their frames
    -- in anim.variants rather than anim.frames. Precache every referenced tile
    -- offset so a tag used only by a variant animation still has drawable art.
    for _,variant in pairs(anim.variants or {}) do
      local vframes=(type(variant)=="table" and variant.frames) or variant or {}
      for _,f in ipairs(vframes) do offsets[#offsets+1]=f.tileOffset or 0 end
    end
    for _,off in ipairs(template.extraTileOffsets or {}) do offsets[#offsets+1]=off end
    for _,off in ipairs(offsets) do
      if not cache.images[off] then
        local oam=template.oam or {}
        local pixels=self.visual.decodeObjFrame(cache.tiles,off,oam.width or 32,oam.height or 32)
        local img,err=makeImage(pixels,cache.colors)
        if not img then return nil,err end
        cache.images[off]=img
      end
      if template.customPaletteVariants then
        local pixels=self.visual.decodeObjFrame(cache.tiles,off,(template.oam or {}).width or 32,(template.oam or {}).height or 32)
        for vi,entries in ipairs(template.customPaletteVariants) do
          cache.variantImages[vi-1]=cache.variantImages[vi-1] or {}
          if not cache.variantImages[vi-1][off] then
            local colors={}
            for i,c in ipairs(cache.colors) do colors[i]={r=c.r,g=c.g,b=c.b,a=c.a} end
            for palIndex,rgb in ipairs(entries or {}) do
              local function cv(v) return math.floor((tonumber(v) or 0)*255/31+0.5) end
              colors[palIndex+1]={r=cv(rgb[1]),g=cv(rgb[2]),b=cv(rgb[3]),a=255}
            end
            local vimg,verr=makeImage(pixels,colors)
            if not vimg then return nil,verr end
            cache.variantImages[vi-1][off]=vimg
          end
        end
      end
      if template.paletteRotations and not cache.rotatedImages[off] then
        cache.rotatedImages[off]={}
        local pixels=self.visual.decodeObjFrame(cache.tiles,off,(template.oam or {}).width or 32,(template.oam or {}).height or 32)
        for rotation=1,7 do
          local colors={}
          for i,c in ipairs(cache.colors) do colors[i]=c end
          for palIndex=1,8 do
            local src=((palIndex-1-rotation)%8)+1
            colors[palIndex+1]=cache.colors[src+1]
          end
          local rimg,rerr=makeImage(pixels,colors)
          if not rimg then return nil,rerr end
          cache.rotatedImages[off][rotation]=rimg
        end
      end
    end
    end
  end
  return true
end

-- Backward-compatible semantic name for move callers. Status definitions use
-- prepareDefinition directly so the resource cache stays animation-generic.
function M:prepareMove(move) return self:prepareDefinition(move,false) end
function M:prepareDeferred(def) return self:prepareDefinition(def,true) end

function M:imageForTileOffset(event,tileOffset)
  local resourceKey=tostring(event.tag)..":"..tostring(event.paletteTag or event.tag)
  local cache=self.tags[resourceKey]
  return cache and cache.images[tileOffset or 0] or nil
end

function M:imageForVariant(event,tileOffset,variant)
  local resourceKey=tostring(event.tag)..":"..tostring(event.paletteTag or event.tag)
  local cache=self.tags[resourceKey]
  local variants=cache and cache.variantImages
  local set=variants and variants[tonumber(variant) or 0]
  return (set and set[tileOffset or 0]) or (cache and cache.images[tileOffset or 0]) or nil
end

function M:imageFor(event,age,paletteRotation)
  if event and event.customImageKey and self.customImages then
    return self.customImages[event.customImageKey],nil
  end
  local resourceKey=tostring(event.tag)..":"..tostring(event.paletteTag or event.tag)
  local cache=self.tags[resourceKey]; if not cache then return nil end
  local function choose(off)
    off=off or 0
    local r=(paletteRotation or 0)%8
    if r~=0 and cache.rotatedImages and cache.rotatedImages[off] then
      return cache.rotatedImages[off][r] or cache.images[off]
    end
    return cache.images[off]
  end
  local anim=event.anim or {}
  local localAge=age
  local frames=anim.frames or {}
  local playbackKind=anim.kind
  if anim.kind=="variants" then
    local variantIndex=math.floor(tonumber(event.motion and event.motion.animVariant) or 0)
    local variant=(anim.variants or {})[variantIndex] or (anim.variants or {})[variantIndex+1]
    if type(variant)=="table" then
      frames=variant.frames or variant
      -- A variant can itself be a normal FireRed once/loop animation.  Keep
      -- that playback mode after selecting the variant instead of treating
      -- the variant as a static first frame.
      playbackKind=variant.kind or "once"
    end
  end
  if #frames==0 then return choose(0),nil end
  if playbackKind=="loop" or playbackKind=="once" then
    local total=0
    for _,f in ipairs(frames) do total=total+(f.duration or 1) end
    local t=playbackKind=="loop" and (localAge % math.max(1,total)) or math.min(localAge,math.max(0,total-1))
    for _,f in ipairs(frames) do
      local d=f.duration or 1
      if t<d then return choose(f.tileOffset or 0),f end
      t=t-d
    end
  end
  return choose(frames[1].tileOffset or 0),frames[1]
end

return M
