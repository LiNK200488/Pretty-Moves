-- FireRed battle-animation resource locator.
-- Locates CompressedSpriteSheet / CompressedSpritePalette records by tag,
-- then validates the referenced GBA LZ77 stream before accepting a match.
--
-- Important: resource tags are searched with Rom:findBytes (C-backed
-- string.find), not by walking all 16 MiB of the ROM in Lua. The old walker was
-- functionally correct but dominated Android boot time.
local M = {}

local function isRomPtr(v, romSize)
  return v >= 0x08000000 and v < 0x08000000 + romSize
end

local function lzHeader(rom, off)
  if not off or off < 0 or off + 4 > rom:size() then return nil end
  if rom:u8(off) ~= 0x10 then return nil end
  local n = rom:u8(off + 1) + rom:u8(off + 2) * 0x100 + rom:u8(off + 3) * 0x10000
  if n <= 0 or n > 0x100000 then return nil end
  return n
end

local function tagBytes(tag)
  tag=assert(tonumber(tag),"numeric animation tag required")
  if tag < 0 or tag > 0xFFFF or tag % 1 ~= 0 then error("animation tag outside u16 range",3) end
  return string.char(tag % 0x100, math.floor(tag / 0x100) % 0x100)
end

-- Visit only actual occurrences of the two-byte tag. On a clean FireRed ROM
-- this is a few hundred candidates at worst, instead of ~8.4 million Lua loop
-- iterations per lookup.
local function eachTagOccurrence(rom, tag, fn)
  local needle=tagBytes(tag)
  local pos=rom:findBytes(needle,0)
  while pos do
    -- The records we are looking for are halfword aligned. Random occurrences
    -- inside compressed data can be unaligned and are ignored immediately.
    if pos % 2 == 0 then fn(pos) end
    pos=rom:findBytes(needle,pos+1)
  end
end

-- Scan once for a tag and classify matching records as sheets and palettes.
local function findRecords(rom, tag)
  local sheets, palettes = {}, {}
  eachTagOccurrence(rom,tag,function(off)
    -- struct CompressedSpriteSheet { const void *data; u16 size; u16 tag; }
    if off >= 6 then
      local rec=off-6
      local ptr=rom:u32(rec)
      local size=rom:u16(rec+4)
      if isRomPtr(ptr,rom:size()) and size>=0x20 and size<=0x8000 and size%0x20==0 then
        local dataOff=ptr-0x08000000
        local unpacked=lzHeader(rom,dataOff)
        -- Most FireRed animation sheets use an allocation size identical to
        -- the LZ77 payload size. Bent Spoon is a real exception: the resource
        -- table allocates 0x0C00 bytes, while bent_spoon.4bpp is a 16x192
        -- six-frame sheet whose decompressed payload is 0x0600 bytes.
        local sizeMatches=(unpacked==size) or (tag==10097 and size==0x0C00 and unpacked==0x0600)
        if unpacked and sizeMatches then
          sheets[#sheets+1]={recordOffset=rec,gbaPointer=ptr,dataOffset=dataOff,size=size,tag=tag,compressed=true,decompressedSize=unpacked}
        end
      end
    end

    -- struct CompressedSpritePalette { const void *data; u16 tag; u16 padding; }
    -- Alignment/padding after tag is compiler-owned, so match using ptr at tag-4.
    if off >= 4 then
      local rec=off-4
      local ptr=rom:u32(rec)
      if isRomPtr(ptr,rom:size()) then
        local dataOff=ptr-0x08000000
        local unpacked=lzHeader(rom,dataOff)
        if unpacked==32 then
          palettes[#palettes+1]={recordOffset=rec,gbaPointer=ptr,dataOffset=dataOff,tag=tag,compressed=true,decompressedSize=unpacked}
        end
      end
    end
  end)
  return sheets,palettes
end

function M.findSpriteSheets(rom, tag)
  local sheets=findRecords(rom,tag)
  return sheets
end

function M.findPalettes(rom, tag)
  local _,palettes=findRecords(rom,tag)
  return palettes
end

-- A few animation tags can also occur inside compressed/random ROM data in a
-- way that looks structurally plausible to the generic scanner. For those tags
-- only, verify their exact position inside FireRed's real animation resource
-- tables by checking the neighboring tag records. This leaves every other tag
-- on the original lookup path.
local function disambiguateKnownAnimTag(rom, kind, tag, matches)
  local prevTag, nextTag
  if tag == 10000 then
    -- ANIM_TAG_BONE is the first entry; only a following neighbor exists.
    nextTag = 10001 -- ANIM_TAG_SPARK
  elseif tag == 10097 then
    -- ANIM_TAG_BENT_SPOON; the u16 tag can occur in unrelated/compressed ROM
    -- data. The real FireRed animation-table entry is exactly between PETAL
    -- (10096) and WEB (10098) in both the sheet and palette tables.
    prevTag = 10096
    nextTag = 10098
  elseif tag == 10100 then
    -- ANIM_TAG_COIN; verify the real animation resource-table entry because
    -- this u16 value can occur elsewhere in the ROM as plausible-looking data.
    prevTag = 10099
    nextTag = 10101
  else
    return matches
  end

  local function validSheetRecord(rec, expectedTag)
    if rec < 0 or rec + 8 > rom:size() or rom:u16(rec+6) ~= expectedTag then return false end
    local ptr=rom:u32(rec)
    local size=rom:u16(rec+4)
    return isRomPtr(ptr,rom:size()) and size>=0x20 and size<=0x8000 and size%0x20==0
      and lzHeader(rom,ptr-0x08000000)==size
  end

  local function validPaletteRecord(rec, expectedTag)
    if rec < 0 or rec + 8 > rom:size() or rom:u16(rec+4) ~= expectedTag then return false end
    local ptr=rom:u32(rec)
    return isRomPtr(ptr,rom:size()) and lzHeader(rom,ptr-0x08000000)==32
  end

  local filtered = {}
  for _,m in ipairs(matches) do
    local rec=m.recordOffset
    local ok=true
    if kind=="sprite sheet" then
      if prevTag then ok=ok and validSheetRecord(rec-8,prevTag) end
      if nextTag then ok=ok and validSheetRecord(rec+8,nextTag) end
    elseif kind=="sprite palette" then
      if prevTag then ok=ok and validPaletteRecord(rec-8,prevTag) end
      if nextTag then ok=ok and validPaletteRecord(rec+8,nextTag) end
    end
    if ok then filtered[#filtered+1]=m end
  end
  return (#filtered>0) and filtered or matches
end

local function uniqueOrError(rom, kind, tag, matches)
  matches=disambiguateKnownAnimTag(rom,kind,tag,matches)
  if #matches == 0 then
    error(string.format("FireRed %s tag %d was not found", kind, tag), 3)
  end
  if #matches > 1 then
    local offsets = {}
    for i = 1, #matches do offsets[i] = string.format("0x%X", matches[i].recordOffset) end
    error(string.format("FireRed %s tag %d is ambiguous (%s)", kind, tag, table.concat(offsets, ", ")), 3)
  end
  return matches[1]
end


local function validateSheetRecord(rom, rec, expectedTag)
  if rec < 0 or rec + 8 > rom:size() or rom:u16(rec+6) ~= expectedTag then return nil end
  local ptr=rom:u32(rec); local size=rom:u16(rec+4)
  if not (isRomPtr(ptr,rom:size()) and size>=0x20 and size<=0x8000 and size%0x20==0) then return nil end
  local dataOff=ptr-0x08000000
  local unpacked=lzHeader(rom,dataOff)
  local sizeMatches=(unpacked==size) or (expectedTag==10097 and size==0x0C00 and unpacked==0x0600)
  if not sizeMatches then return nil end
  return {recordOffset=rec,gbaPointer=ptr,dataOffset=dataOff,size=size,tag=expectedTag,compressed=true,decompressedSize=unpacked}
end

local function validatePaletteRecord(rom, rec, expectedTag)
  if rec < 0 or rec + 8 > rom:size() or rom:u16(rec+4) ~= expectedTag then return nil end
  local ptr=rom:u32(rec)
  if not isRomPtr(ptr,rom:size()) then return nil end
  local dataOff=ptr-0x08000000
  local unpacked=lzHeader(rom,dataOff)
  if unpacked~=32 then return nil end
  return {recordOffset=rec,gbaPointer=ptr,dataOffset=dataOff,tag=expectedTag,compressed=true,decompressedSize=unpacked}
end

-- Resolve a FireRed animation resource by walking the actual contiguous
-- resource tables from an already-proven anchor tag. This avoids searching the
-- ROM for the target tag at all. `delta` is measured in 8-byte table records.
function M.extractRelativeTaggedSprite(rom, anchorTag, delta, expectedTag)
  delta=assert(tonumber(delta),'numeric resource-table delta required')
  expectedTag=assert(tonumber(expectedTag),'numeric expected animation tag required')
  local anchorSheets,anchorPalettes=findRecords(rom,anchorTag)
  local anchorSheet=uniqueOrError(rom,'sprite sheet',anchorTag,anchorSheets)
  local anchorPalette=uniqueOrError(rom,'sprite palette',anchorTag,anchorPalettes)
  local sheet=validateSheetRecord(rom,anchorSheet.recordOffset+delta*8,expectedTag)
  local palette=validatePaletteRecord(rom,anchorPalette.recordOffset+delta*8,expectedTag)
  if not sheet then error(string.format('FireRed relative sprite sheet tag %d from anchor %d was invalid',expectedTag,anchorTag),2) end
  if not palette then error(string.format('FireRed relative sprite palette tag %d from anchor %d was invalid',expectedTag,anchorTag),2) end
  local pixels,perr=rom:lz77(sheet.dataOffset,0x100000)
  if not pixels then error('Failed to decompress FireRed relative sprite sheet: '..tostring(perr),2) end
  local pal,palErr=rom:lz77(palette.dataOffset,0x1000)
  if not pal then error('Failed to decompress FireRed relative sprite palette: '..tostring(palErr),2) end
  return {tag=expectedTag,paletteTag=expectedTag,sheet=sheet,palette=palette,tiles4bpp=pixels,paletteBgr555=pal}
end

function M.extractTaggedSprite(rom, tag, paletteTag)
  paletteTag = paletteTag or tag
  local sheets,palettes=findRecords(rom,tag)
  local sheet=uniqueOrError(rom,"sprite sheet",tag,sheets)
  local palette
  if paletteTag==tag then
    palette=uniqueOrError(rom,"sprite palette",paletteTag,palettes)
  else
    local _,otherPalettes=findRecords(rom,paletteTag)
    palette=uniqueOrError(rom,"sprite palette",paletteTag,otherPalettes)
  end
  local pixels, perr = rom:lz77(sheet.dataOffset, 0x100000)
  if not pixels then error("Failed to decompress FireRed sprite sheet: " .. tostring(perr), 2) end
  local pal, palErr = rom:lz77(palette.dataOffset, 0x1000)
  if not pal then error("Failed to decompress FireRed sprite palette: " .. tostring(palErr), 2) end
  return {
    tag = tag,
    paletteTag = paletteTag,
    sheet = sheet,
    palette = palette,
    tiles4bpp = pixels,
    paletteBgr555 = pal,
  }
end

return M
