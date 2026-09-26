-- FireRed SmokescreenImpact dedicated sprite resources. Unlike normal battle
-- animation sprites these are not in the tagged animation sheet table: the
-- game loads smokescreen_impact.4bpp.lz (0x180 bytes) and its palette directly.
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
  -- graphics.c stores the dedicated impact tiles immediately followed by its
  -- 16-color palette. Match the exact decompressed sizes from FireRed source.
  local needle=string.char(0x10,0x80,0x01,0x00) -- 0x180 output bytes
  local off=rom:findBytes(needle,0)
  while off do
    if off%4==0 then
      local pal=nextStream(rom,off)
      if pal and outLen(rom,pal)==32 then return off,pal end
    end
    off=rom:findBytes(needle,off+1)
  end
  return nil
end

local function makeImage(graphics,tiles,colors,tileOffset)
  if not (love and love.image and love.image.newImageData and love.graphics and love.graphics.newImage) then
    return nil,"LÖVE image/graphics API unavailable"
  end
  local pixels={}
  for y=1,16 do pixels[y]={} end
  for ty=0,1 do for tx=0,1 do
    local tile=tiles[tileOffset+ty*2+tx+1]
    for py=0,7 do for px=0,7 do
      pixels[ty*8+py+1][tx*8+px+1]=(tile and tile[py*8+px+1]) or 0
    end end
  end end
  local id=love.image.newImageData(16,16)
  for y=0,15 do for x=0,15 do
    local c=colors[(pixels[y+1][x+1] or 0)+1] or {r=0,g=0,b=0,a=0}
    id:setPixel(x,y,(c.r or 0)/255,(c.g or 0)/255,(c.b or 0)/255,(c.a or 0)/255)
  end end
  local img=love.graphics.newImage(id)
  if img.setFilter then pcall(img.setFilter,img,"nearest","nearest") end
  return img
end

function M.new(opts)
  return setmetatable({rom=assert(opts.rom),graphics=assert(opts.graphics),log=opts.log,images=nil},M)
end
function M:prepare()
  if self.images then return true end
  local gfxOff,palOff=findCluster(self.rom)
  if not gfxOff then return nil,"FireRed smokescreen-impact resource cluster not found" end
  local gfx,ge=self.rom:lz77(gfxOff,0x1000); if not gfx then return nil,ge end
  local pal,pe=self.rom:lz77(palOff,0x1000); if not pal then return nil,pe end
  local tiles=self.graphics.decode4bpp(gfx)
  local colors=self.graphics.decodeBgr555(pal)
  self.images={}
  for _,off in ipairs({0,4,8}) do
    local img,why=makeImage(self.graphics,tiles,colors,off); if not img then return nil,why end
    self.images[off]=img
  end
  return true
end
function M:image(tileOffset)
  return self.images and self.images[tileOffset or 0] or nil
end
return M
