-- FireRed B_ANIM_STATS_CHANGE mask resources, extracted from the imported ROM.
-- The source assets are one 4bpp sheet, two 32x32 tilemaps and eight palettes,
-- stored consecutively in FireRed graphics.c. Locate that exact LZ77 cluster;
-- never synthesize replacement art.
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

local function findCluster(rom)
  -- stat.4bpp is 64 tiles (2048 bytes); both tilemaps are 2048 bytes; all
  -- eight palettes are 32 bytes. INCBIN_U32 keeps every stream 4-byte aligned.
  local needle=string.char(0x10,0x00,0x08,0x00)
  local off=rom:findBytes(needle,0)
  while off do
    if off%4==0 then
      local seq={off}; local p=off; local ok=true
      local expected={2048,2048,32,32,32,32,32,32,32,32}
      for _,n in ipairs(expected) do
        p=nextStream(rom,p)
        if not p or outLen(rom,p)~=n then ok=false; break end
        seq[#seq+1]=p
      end
      if ok then return seq end
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
  return setmetatable({rom=assert(opts.rom),graphics=assert(opts.graphics),log=opts.log,images=nil},M)
end
function M:prepare()
  if self.images then return true end
  local seq=findCluster(self.rom)
  if not seq then return nil,"FireRed stat-mask LZ77 resource cluster not found" end
  local gfx,err=self.rom:lz77(seq[1],0x10000); if not gfx then return nil,err end
  local maps={}; for i=2,3 do maps[i-1]=assert(self.rom:lz77(seq[i],0x10000)) end
  local pals={}; for i=4,11 do pals[i-3]=assert(self.rom:lz77(seq[i],0x1000)) end
  self.images={{},{}}
  for m=1,2 do for p=1,8 do
    local img,why=makeBgImage(self.graphics,gfx,maps[m],pals[p]); if not img then return nil,why end
    self.images[m][p]=img
  end end
  return true
end
function M:image(goesDown,paletteIndex)
  if not self.images then return nil end
  local m=goesDown and 2 or 1
  return self.images[m][math.max(1,math.min(8,paletteIndex or 5))]
end
return M
