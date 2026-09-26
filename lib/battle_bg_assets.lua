-- Shared FireRed move-background assets, decoded from the user's imported ROM.
-- BG_GHOST is resolved through FireRed's gBattleAnimBackgroundTable rather
-- than bundled/replacement artwork, so Confuse Ray and later ghost moves can
-- share the exact ROM-native background.
local M={}; M.__index=M

local function validLz(rom,off,want)
  if not off or off<0 or off+4>rom:size() or rom:u8(off)~=0x10 then return false end
  local n=rom:u8(off+1)+rom:u8(off+2)*0x100+rom:u8(off+3)*0x10000
  return not want or n==want
end

local function ptrAt(rom,off)
  local p=rom:u32(off)
  if p<0x08000000 or p>=0x0A000000 then return nil end
  local f=p-0x08000000
  if f<0 or f>=rom:size() then return nil end
  return f
end

local function findBackgroundTable(rom)
  -- FireRed's table starts with BG_DARK twice (BG_NONE and BG_DARK), followed
  -- by BG_GHOST. Search for three ROM pointers repeated as one 12-byte entry;
  -- then validate the third entry as a normal image/palette/tilemap triple.
  local data=rom.data
  local pat="..."..string.char(0x08).."..."..string.char(0x08).."..."..string.char(0x08)
  local start=1
  while true do
    local pos=string.find(data,pat,start,false)
    if not pos then return nil end
    local off=pos-1
    if off%4==0 and off+36<=rom:size() and rom:bytes(off,12)==rom:bytes(off+12,12) then
      local ok=true
      for e=0,2 do
        for p=0,2 do if not ptrAt(rom,off+e*12+p*4) then ok=false break end end
        if not ok then break end
      end
      if ok then
        local gi=ptrAt(rom,off+24)
        local gp=ptrAt(rom,off+28)
        local gm=ptrAt(rom,off+32)
        if validLz(rom,gi) and validLz(rom,gp,32) and validLz(rom,gm,2048) then
          return off
        end
      end
    end
    start=pos+1
  end
end

-- Measure one compressed GBA LZ77 stream so adjacent graphics.c resources can
-- be walked without hardcoded ROM addresses.
local function lzCompressedSpan(rom,off)
  if not off or off<0 or off+4>rom:size() or rom:u8(off)~=0x10 then return nil end
  local want=rom:u8(off+1)+rom:u8(off+2)*0x100+rom:u8(off+3)*0x10000
  if want<=0 or want>0x100000 then return nil end
  local src,out=off+4,0
  while out<want do
    if src>=rom:size() then return nil end
    local flags=rom:u8(src); src=src+1
    for bit=7,0,-1 do
      if out>=want then break end
      if math.floor(flags/(2^bit))%2==0 then
        src=src+1; out=out+1
      else
        if src+1>=rom:size() then return nil end
        local a=rom:u8(src); src=src+2
        out=out+math.floor(a/16)+3
      end
      if src>rom:size() then return nil end
    end
  end
  return src-off
end

local function align4(v) return math.floor((v+3)/4)*4 end
local function nextAdjacentLz(rom,off)
  local span=lzCompressedSpan(rom,off); if not span then return nil end
  local p=align4(off+span)
  for q=p,math.min(p+32,rom:size()-4),4 do
    if rom:u8(q)==0x10 then return q end
  end
  return nil
end

local function makeSurfImage(graphics,gfxBytes,tilemapBytes,palBytes,paletteRotation,waveOnly)
  if not (love and love.image and love.image.newImageData and love.graphics and love.graphics.newImage) then
    return nil,"LÖVE image/graphics API unavailable"
  end
  if #tilemapBytes~=4096 then return nil,"unexpected FireRed Surf tilemap size" end
  local tiles=graphics.decode4bpp(gfxBytes)
  local colors=graphics.decodeBgr555(palBytes)
  if paletteRotation and paletteRotation~=0 then
    local base={}; for i,c in ipairs(colors) do base[i]=c end
    local r=paletteRotation%7
    -- AnimTask_CreateSurfWave rotates BG palette entries 1..7 every 4 frames.
    for palIndex=1,7 do
      local src=((palIndex-1-r)%7)+1
      colors[palIndex+1]=base[src+1]
    end
  end
  local id=love.image.newImageData(512,256)
  for ty=0,31 do for tx=0,63 do
    local mapIndex=((tx<32) and 0 or 1024)+ty*32+(tx%32)
    local i=mapIndex*2+1
    local lo,hi=string.byte(tilemapBytes,i,i+1); local entry=lo+hi*256
    local tile=entry%1024
    if tile>=#tiles then return nil,"FireRed Surf tilemap exceeds decoded sheet" end
    local hflip=math.floor(entry/1024)%2==1
    local vflip=math.floor(entry/2048)%2==1
    local src=tiles[tile+1]
    for py=0,7 do for px=0,7 do
      local sx=hflip and (7-px) or px; local sy=vflip and (7-py) or py
      local ci=src[sy*8+sx+1] or 0; local c=colors[ci+1] or {r=0,g=0,b=0}
      local alpha=1
      if waveOnly then
        -- Backgrounds-off Surf is a true transparent move effect, not a
        -- cropped copy of the filled BG1 layer.  The native Surf palette is
        -- an 8-step water ramp: indices 0..2 are the backdrop/deep fill,
        -- while 3..8 carry the crest, foam and highlight contours.  Keep the
        -- latter with a gentle alpha ramp so the original artwork defines the
        -- wave shape while the normal Gen I battlefield remains visible.
        if ci<=2 then alpha=0
        elseif ci==3 then alpha=0.35
        elseif ci==4 then alpha=0.5
        elseif ci==5 then alpha=0.7
        else alpha=1 end
      end
      id:setPixel(tx*8+px,ty*8+py,(c.r or 0)/255,(c.g or 0)/255,(c.b or 0)/255,alpha)
    end end
  end end
  local img=love.graphics.newImage(id)
  if img.setFilter then pcall(img.setFilter,img,"nearest","nearest") end
  if img.setWrap then pcall(img.setWrap,img,"repeat","repeat") end
  return img
end

local function findSurfResources(rom)
  -- graphics.c places Surf immediately after ANIM_TAG_CROSS_IMPACT's OBJ
  -- palette. Search every structurally valid Cross Impact palette record and
  -- accept only a candidate followed by the exact Surf resource chain:
  -- gfx, 32-byte palette, then three 4096-byte maps. This disambiguates random
  -- tag hits without importing another loader or hardcoding ROM offsets.
  local tag=10285
  local needle=string.char(tag%256,math.floor(tag/256)%256)
  local candidates={}
  local pos=rom:findBytes(needle,0)
  while pos do
    if pos%2==0 and pos>=4 then
      local rec=pos-4; local ptr=rom:u32(rec)
      if ptr>=0x08000000 and ptr<0x08000000+rom:size() then
        local palOff=ptr-0x08000000
        if validLz(rom,palOff,32) then
          local gfxOff=nextAdjacentLz(rom,palOff)
          local surfPal=gfxOff and nextAdjacentLz(rom,gfxOff)
          local oppMap=surfPal and nextAdjacentLz(rom,surfPal)
          local playerMap=oppMap and nextAdjacentLz(rom,oppMap)
          local contestMap=playerMap and nextAdjacentLz(rom,playerMap)
          if gfxOff and surfPal and oppMap and playerMap and contestMap
              and validLz(rom,surfPal,32)
              and validLz(rom,oppMap,4096)
              and validLz(rom,playerMap,4096)
              and validLz(rom,contestMap,4096) then
            candidates[#candidates+1]={gfx=gfxOff,pal=surfPal,opponent=oppMap,player=playerMap}
          end
        end
      end
    end
    pos=rom:findBytes(needle,pos+1)
  end
  if #candidates~=1 then
    return nil,string.format("FireRed Surf resource chain %s",#candidates==0 and "not found" or "is ambiguous")
  end
  local c=candidates[1]
  local gfx,ge=rom:lz77(c.gfx,0x20000); if not gfx then return nil,ge end
  local pal,pe=rom:lz77(c.pal,0x1000); if not pal then return nil,pe end
  local om,oe=rom:lz77(c.opponent,0x10000); if not om then return nil,oe end
  local pm,pme=rom:lz77(c.player,0x10000); if not pm then return nil,pme end
  return {gfx=gfx,pal=pal,opponent=om,player=pm}
end


local function makeWideBackgroundImage(graphics,gfxBytes,tilemapBytes,palBytes)
  if not (love and love.image and love.image.newImageData and love.graphics and love.graphics.newImage) then
    return nil,"LÖVE image/graphics API unavailable"
  end
  if #tilemapBytes~=4096 then return nil,"unexpected FireRed wide background tilemap size" end
  local tiles=graphics.decode4bpp(gfxBytes)
  local colors=graphics.decodeBgr555(palBytes)
  local id=love.image.newImageData(512,256)
  -- 64x32 GBA text BG: two 32x32 screenblocks laid side-by-side.
  for ty=0,31 do for tx=0,63 do
    local mapIndex=((tx<32) and 0 or 1024)+ty*32+(tx%32)
    local i=mapIndex*2+1
    local lo,hi=string.byte(tilemapBytes,i,i+1); local entry=lo+hi*256
    local tile=entry%1024
    if tile>=#tiles then return nil,"FireRed wide background tilemap exceeds decoded sheet" end
    local hflip=math.floor(entry/1024)%2==1
    local vflip=math.floor(entry/2048)%2==1
    local src=tiles[tile+1]
    for py=0,7 do for px=0,7 do
      local sx=hflip and (7-px) or px; local sy=vflip and (7-py) or py
      local ci=src[sy*8+sx+1] or 0; local c=colors[ci+1] or {r=0,g=0,b=0}
      id:setPixel(tx*8+px,ty*8+py,(c.r or 0)/255,(c.g or 0)/255,(c.b or 0)/255,1)
    end end
  end end
  local img=love.graphics.newImage(id)
  if img.setFilter then pcall(img.setFilter,img,"nearest","nearest") end
  if img.setWrap then pcall(img.setWrap,img,"repeat","repeat") end
  return img
end

local function makeImage(graphics,gfxBytes,tilemapBytes,palBytes,paletteRotation)
  if not (love and love.image and love.image.newImageData and love.graphics and love.graphics.newImage) then
    return nil,"LÖVE image/graphics API unavailable"
  end
  if #tilemapBytes%64~=0 then return nil,"unexpected FireRed background tilemap size" end
  local tileRows=#tilemapBytes/64
  if tileRows<18 or tileRows>32 then return nil,"unsupported FireRed background tilemap height" end
  local tiles=graphics.decode4bpp(gfxBytes)
  local colors=graphics.decodeBgr555(palBytes)
  if paletteRotation and paletteRotation~=0 then
    local base={}
    for i,c in ipairs(colors) do base[i]=c end
    local r=paletteRotation%11
    -- FireRed SetPsychicBackground rotates BG palette entries 1..11.
    -- colors[] is Lua 1-based, so palette entry N lives at colors[N+1].
    for palIndex=1,11 do
      local src=((palIndex-1-r)%11)+1
      colors[palIndex+1]=base[src+1]
    end
  end
  local id=love.image.newImageData(256,tileRows*8)
  for ty=0,tileRows-1 do for tx=0,31 do
    local i=(ty*32+tx)*2+1
    local lo,hi=string.byte(tilemapBytes,i,i+1); local entry=lo+hi*256
    local tile=entry%1024
    if tile>=#tiles then return nil,"FireRed background tilemap exceeds decoded sheet" end
    local hflip=math.floor(entry/1024)%2==1
    local vflip=math.floor(entry/2048)%2==1
    local src=tiles[tile+1]
    for py=0,7 do for px=0,7 do
      local sx=hflip and (7-px) or px; local sy=vflip and (7-py) or py
      local ci=src[sy*8+sx+1] or 0; local c=colors[ci+1] or {r=0,g=0,b=0}
      -- BG palette index 0 is a real background color, unlike OBJ index 0.
      id:setPixel(tx*8+px,ty*8+py,(c.r or 0)/255,(c.g or 0)/255,(c.b or 0)/255,1)
    end end
  end end
  local img=love.graphics.newImage(id)
  if img.setFilter then pcall(img.setFilter,img,"nearest","nearest") end
  if img.setWrap then pcall(img.setWrap,img,"repeat","repeat") end
  return img
end


local function previousAdjacentLz(rom,currentOff,want)
  if not currentOff then return nil end
  local minOff=math.max(0,currentOff-0x4000)
  for off=currentOff-4,minOff,-4 do
    if rom:u8(off)==0x10 and validLz(rom,off,want) then
      local span=lzCompressedSpan(rom,off)
      if span then
        local nextOff=align4(off+span)
        if nextOff<=currentOff and currentOff-nextOff<=32 then return off end
      end
    end
  end
  return nil
end

local function findScaryFaceResources(self)
  -- FireRed USA 1.0 exact ROM file offsets. These are the same baseline
  -- symbol locations used by gen1recomp's GBA version/edition importer;
  -- do not scan the ROM or infer adjacency for Glare's Scary Face assets.
  local SCARY_FACE_PAL      = 0xD24BA4 -- gBattleAnim_ScaryFacePal
  local SCARY_FACE_GFX      = 0xD24BCC -- gBattleAnim_ScaryFaceGfx
  local SCARY_FACE_PLAYER   = 0xE7F4AC -- gBattleAnimBgTilemap_ScaryFacePlayer
  local SCARY_FACE_OPPONENT = 0xE7F690 -- gBattleAnimBgTilemap_ScaryFaceOpponent

  local gfx,ge=self.rom:lz77(SCARY_FACE_GFX,0x20000); if not gfx then return nil,ge end
  local pal,pe=self.rom:lz77(SCARY_FACE_PAL,0x1000); if not pal then return nil,pe end
  local pm,pme=self.rom:lz77(SCARY_FACE_PLAYER,0x10000); if not pm then return nil,pme end
  local om,ome=self.rom:lz77(SCARY_FACE_OPPONENT,0x10000); if not om then return nil,ome end
  return {gfx=gfx,pal=pal,player=pm,opponent=om}
end

function M.new(opts)
  return setmetatable({rom=assert(opts.rom),graphics=assert(opts.graphics),assets=opts.assets,log=opts.log,images={},rotations={},surfImages={},surfRotations={},surfWaveImages={},surfWaveRotations={},tableOff=nil,failed={}},M)
end

function M:prepare(name)
  name=string.lower(tostring(name or ""))
  if name=="haze" then
    if self.images[name] then return true end
    if self.failed[name] then return nil,self.failed[name] end
    -- FireRed USA 1.0 ROM-native Haze resources. AnimTask_HazeScrollingFog
    -- loads the raw horizontal weather fog tiles, the compressed battle fog
    -- tilemap, and the default weather palette. Keep the move asset-free: all
    -- three are decoded from the user's imported FireRed ROM at runtime.
    local HAZE_PAL = 0x3C2CE0 -- gDefaultWeatherSpritePalette
    local HAZE_GFX = 0x3C3540 -- gWeatherFogHorizontalTiles (0x800 raw bytes)
    local HAZE_MAP = 0xE7F1F4 -- gBattleAnimFogTilemap (LZ77)
    if HAZE_GFX+0x800>self.rom:size() or HAZE_PAL+32>self.rom:size() then
      self.failed[name]="FireRed Haze ROM resources out of range"
      return nil,self.failed[name]
    end
    local gfx=self.rom:bytes(HAZE_GFX,0x800)
    local pal=self.rom:bytes(HAZE_PAL,32)
    local map,me=self.rom:lz77(HAZE_MAP,0x10000)
    if not map then self.failed[name]=me; return nil,me end
    local img,why=makeImage(self.graphics,gfx,map,pal,0)
    if not img then self.failed[name]=why; return nil,why end
    self.images[name]=img
    return true
  end
  if name=="surf_player" or name=="surf_opponent" or name=="surf_wave_player" or name=="surf_wave_opponent" then
    if self.surfImages[name] or self.surfWaveImages[name] then return true end
    if self.failed[name] then return nil,self.failed[name] end
    local res,why=findSurfResources(self.rom)
    if not res then self.failed[name]=why; return nil,why end
    for _,side in ipairs({"player","opponent"}) do
      local key="surf_"..side; local rs={}
      local waveKey="surf_wave_"..side; local wrs={}
      for r=0,6 do
        local img,e=makeSurfImage(self.graphics,res.gfx,res[side],res.pal,r,false)
        if not img then self.failed[key]=e; return nil,e end
        local wave,we=makeSurfImage(self.graphics,res.gfx,res[side],res.pal,r,true)
        if not wave then self.failed[waveKey]=we; return nil,we end
        rs[r]=img; wrs[r]=wave
      end
      self.surfImages[key]=rs[0]; self.surfRotations[key]=rs
      self.surfWaveImages[waveKey]=wrs[0]; self.surfWaveRotations[waveKey]=wrs
    end
    return true
  end
  if self.images[name] then return true end
  if self.failed[name] then return nil,self.failed[name] end
  if name=="scary_face_player" or name=="scary_face_opponent" then
    local called,res,why=pcall(findScaryFaceResources,self)
    if not called then self.failed[name]=tostring(res); return nil,self.failed[name] end
    if not res then self.failed[name]=why; return nil,why end
    for _,side in ipairs({"player","opponent"}) do
      local key="scary_face_"..side
      local img,e=makeImage(self.graphics,res.gfx,res[side],res.pal,0)
      if not img then self.failed[key]=e; return nil,e end
      self.images[key]=img
    end
    return true
  end
  local bgIndex = ({ghost=2, psychic=3, impact_opponent=4, impact_player=5, impact_contests=6, drill=7, highspeed_opponent=9, highspeed_player=10, thunder=11, guillotine_opponent=12, guillotine_player=13, guillotine_contests=14, in_air=17, aurora=20, fissure=21, solar_beam_opponent=24, solar_beam_player=25})[name]
  if bgIndex==nil then return nil,"unsupported FireRed move background: "..name end
  local tableOff=self.tableOff
  if not tableOff then
    tableOff=findBackgroundTable(self.rom)
    if not tableOff then
      self.failed[name]="FireRed battle-animation background table not found"
      return nil,self.failed[name]
    end
    self.tableOff=tableOff
  end
  local base=tableOff+bgIndex*12
  local gfxOff=ptrAt(self.rom,base)
  local palOff=ptrAt(self.rom,base+4)
  local mapOff=ptrAt(self.rom,base+8)
  local gfx,ge=self.rom:lz77(gfxOff,0x20000); if not gfx then self.failed[name]=ge; return nil,ge end
  local pal,pe=self.rom:lz77(palOff,0x1000); if not pal then self.failed[name]=pe; return nil,pe end
  local map,me=self.rom:lz77(mapOff,0x10000); if not map then self.failed[name]=me; return nil,me end
  local img,why
  if name=="fissure" then
    -- BG_FISSURE is the one FireRed move background in this set using a
    -- 64x32 (4096-byte) text-BG tilemap. The generic decoder is 32 tiles
    -- wide and correctly rejects this layout, so decode its two horizontal
    -- screenblocks explicitly.
    img,why=makeWideBackgroundImage(self.graphics,gfx,map,pal)
  else
    img,why=makeImage(self.graphics,gfx,map,pal,0)
  end
  if not img then self.failed[name]=why; return nil,why end
  self.images[name]=img
  if name=="psychic" then
    local rs={[0]=img}
    for r=1,10 do
      local ri,rwhy=makeImage(self.graphics,gfx,map,pal,r)
      if not ri then self.failed[name]=rwhy; self.images[name]=nil; return nil,rwhy end
      rs[r]=ri
    end
    self.rotations[name]=rs
  end
  return true
end

function M:image(name,rotation)
  name=string.lower(tostring(name or ""))
  if rotation~=nil and self.surfWaveRotations[name] then
    return self.surfWaveRotations[name][(tonumber(rotation) or 0)%7]
  end
  if self.surfWaveImages[name] then return self.surfWaveImages[name] end
  if rotation~=nil and self.surfRotations[name] then
    return self.surfRotations[name][(tonumber(rotation) or 0)%7]
  end
  if self.surfImages[name] then return self.surfImages[name] end
  if rotation~=nil and self.rotations[name] then
    return self.rotations[name][(tonumber(rotation) or 0)%11]
  end
  return self.images[name]
end
return M
