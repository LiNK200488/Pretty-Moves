-- Helpers for exact GBA 4bpp tile and BGR555 palette data.
local M = {}

local function u16le(s, i)
  local a, b = string.byte(s, i, i + 1)
  return a + b * 0x100
end

function M.decodeBgr555(paletteBytes)
  assert(type(paletteBytes) == "string" and #paletteBytes % 2 == 0, "invalid BGR555 palette")
  local out = {}
  for i = 1, #paletteBytes, 2 do
    local c = u16le(paletteBytes, i)
    local r5 = c % 32
    local g5 = math.floor(c / 32) % 32
    local b5 = math.floor(c / 1024) % 32
    out[#out + 1] = {
      raw = c,
      r = math.floor((r5 * 255 + 15) / 31),
      g = math.floor((g5 * 255 + 15) / 31),
      b = math.floor((b5 * 255 + 15) / 31),
      a = (#out == 0) and 0 or 255,
    }
  end
  return out
end

-- Decode raw GBA 4bpp tiles into palette indices, keeping native tile order.
-- Each 8x8 tile is 32 bytes; low nibble is the left pixel.
function M.decode4bpp(bytes)
  assert(type(bytes) == "string" and #bytes % 32 == 0, "4bpp data must be whole 8x8 tiles")
  local tiles = {}
  local tileCount = #bytes / 32
  for t = 0, tileCount - 1 do
    local px = {}
    local base = t * 32
    for i = 0, 31 do
      local b = string.byte(bytes, base + i + 1)
      px[#px + 1] = b % 16
      px[#px + 1] = math.floor(b / 16)
    end
    tiles[t + 1] = px
  end
  return tiles
end

return M
