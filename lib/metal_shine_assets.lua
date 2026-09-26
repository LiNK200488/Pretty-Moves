-- FireRed AnimTask_MetallicShine background mask resources, extracted from the
-- imported ROM. Harden/Iron Defense use the real metal_shine 4bpp sheet,
-- palette and 32x32 tilemap; no replacement artwork is synthesized.
local M={}; M.__index=M

local function outLen(rom,off)
  if not off or off+4>rom:size() or rom:u8(off)~=0x10 then return nil end
  return rom:u8(off+1)+rom:u8(off+2)*0x100+rom:u8(off+3)*0x10000
end
local function streamEnd(rom,off)
  local want=outLen(rom,off); if not want then return nil end
  local pos,n=off+4,0
  while n<want do
    local flags=rom:u8(pos); pos=pos+1
    for bit=7,0,-1 do
      if n>=want then break end
      if math.floor(flags/(2^bit))%2==0 then pos=pos+1; n=n+1
      else
        local a=rom:u8(pos); pos=pos+2
        n=math.min(want,n+math.floor(a/16)+3)
      end
    end
  end
  return pos
end
local function align4(n) return n + ((4-n%4)%4) end
local function nextStream(rom,off)
  local e=streamEnd(rom,off); return e and align4(e) or nil
end

local function validTilemap(bytes,maxTile)
  if not bytes or #bytes~=2048 then return false end
  local used=0
  for i=1,#bytes,2 do
    local lo,hi=string.byte(bytes,i,i+1); local entry=lo+hi*256
    local tile=entry%1024
    if tile>maxTile then return false end
    if tile~=0 then used=used+1 end
  end
  return used>0
end

local function findCluster(rom)
  -- graphics.c stores these consecutively as:
  -- metal_shine.4bpp.lz (64 tiles = 2048 bytes),
  -- metal_shine.gbapal.lz (32 bytes), metal_shine.bin.lz (2048 bytes).
  local needle=string.char(0x10,0x00,0x08,0x00)
  local off=rom:findBytes(needle,0)
  while off do
    if off%4==0 then
      local pal=nextStream(rom,off)
      local map=pal and nextStream(rom,pal) or nil
      if pal and map and outLen(rom,pal)==32 and outLen(rom,map)==2048 then
        local tilemap=rom:lz77(map,0x10000)
        if validTilemap(tilemap,63) then return off,pal,map end
      end
    end
    off=rom:findBytes(needle,off+1)
  end
  return nil
end

local function makeBgImage(graphics,gfxBytes,tilemapBytes,palBytes)
  if not (love and love.image and love.image.newImageData and love.graphics and love.graphics.newImage) then
    return nil,"LÖVE image/graphics API unavailable"
  end
  local tiles=graphics.decode4bpp(gfxBytes)
  local colors=graphics.decodeBgr555(palBytes)
  local id=love.image.newImageData(256,256)
  for ty=0,31 do for tx=0,31 do
    local i=(ty*32+tx)*2+1
    local lo,hi=string.byte(tilemapBytes,i,i+1); local entry=lo+hi*256
    local tile=entry%1024; local hflip=math.floor(entry/1024)%2==1; local vflip=math.floor(entry/2048)%2==1
    local src=tiles[tile+1]
    for py=0,7 do for px=0,7 do
      local sx=hflip and (7-px) or px; local sy=vflip and (7-py) or py
      local ci=src and src[sy*8+sx+1] or 0; local c=colors[ci+1] or {r=0,g=0,b=0,a=0}
      id:setPixel(tx*8+px,ty*8+py,(c.r or 0)/255,(c.g or 0)/255,(c.b or 0)/255,(c.a or 0)/255)
    end end
  end end
  local img=love.graphics.newImage(id); if img.setFilter then pcall(img.setFilter,img,"nearest","nearest") end
  return img
end

function M.new(opts)
  return setmetatable({rom=assert(opts.rom),graphics=assert(opts.graphics),log=opts.log,imageData=nil},M)
end
function M:prepare()
  if self.imageData then return true end
  local gfxOff,palOff,mapOff=findCluster(self.rom)
  if not gfxOff then return nil,"FireRed metal-shine LZ77 resource cluster not found" end
  local gfx,ge=self.rom:lz77(gfxOff,0x10000); if not gfx then return nil,ge end
  local pal,pe=self.rom:lz77(palOff,0x1000); if not pal then return nil,pe end
  local map,me=self.rom:lz77(mapOff,0x10000); if not map then return nil,me end
  local img,why=makeBgImage(self.graphics,gfx,map,pal); if not img then return nil,why end
  self.imageData=img
  return true
end
function M:image() return self.imageData end
return M
