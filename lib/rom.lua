-- Small, bounds-checked GBA ROM reader. Offsets are zero-based.
local Rom = {}
Rom.__index = Rom

local function checkInt(v, name)
  if type(v) ~= "number" or v < 0 or v % 1 ~= 0 then
    error((name or "value") .. " must be a non-negative integer", 3)
  end
end

function Rom.new(data)
  assert(type(data) == "string", "ROM data must be a Lua byte string")
  return setmetatable({ data = data, length = #data }, Rom)
end

function Rom:size() return self.length end

function Rom:_check(offset, length)
  checkInt(offset, "offset")
  checkInt(length, "length")
  if offset + length > self.length then
    error(string.format("ROM read out of bounds: 0x%X + %d > 0x%X", offset, length, self.length), 3)
  end
end

function Rom:u8(offset)
  self:_check(offset, 1)
  return string.byte(self.data, offset + 1)
end

function Rom:u16(offset)
  self:_check(offset, 2)
  local a, b = string.byte(self.data, offset + 1, offset + 2)
  return a + b * 0x100
end

function Rom:u32(offset)
  self:_check(offset, 4)
  local a, b, c, d = string.byte(self.data, offset + 1, offset + 4)
  return a + b * 0x100 + c * 0x10000 + d * 0x1000000
end

function Rom:bytes(offset, length)
  self:_check(offset, length)
  return string.sub(self.data, offset + 1, offset + length)
end

-- Fast binary search backed by Lua's C string.find implementation. Returns a
-- zero-based ROM offset. This is intentionally used for large-table/resource
-- discovery so Android does not spend boot time iterating over 16 MiB in Lua.
function Rom:findBytes(needle, startOffset)
  if type(needle) ~= "string" or #needle == 0 then
    error("needle must be a non-empty byte string", 2)
  end
  startOffset = startOffset or 0
  checkInt(startOffset, "startOffset")
  if startOffset >= self.length then return nil end
  local pos = string.find(self.data, needle, startOffset + 1, true)
  return pos and (pos - 1) or nil
end

function Rom:ascii(offset, length)
  local s = self:bytes(offset, length)
  return (s:gsub("%z+$", ""))
end

function Rom:gbaPointer(offset)
  local p = self:u32(offset)
  if p < 0x08000000 or p >= 0x0A000000 then
    return nil, p
  end
  local fileOffset = p - 0x08000000
  if fileOffset >= self.length then return nil, p end
  return fileOffset, p
end

-- Nintendo/GBA LZ77 type 0x10 decompressor.
function Rom:lz77(offset, maxOutput)
  maxOutput = maxOutput or (4 * 1024 * 1024)
  if self:u8(offset) ~= 0x10 then
    return nil, "not a GBA LZ77(0x10) stream"
  end
  local outLen = self:u8(offset + 1) + self:u8(offset + 2) * 0x100 + self:u8(offset + 3) * 0x10000
  if outLen > maxOutput then return nil, "decompressed stream exceeds safety limit" end

  local pos = offset + 4
  local out = {}
  local n = 0
  while n < outLen do
    local flags = self:u8(pos); pos = pos + 1
    for bit = 7, 0, -1 do
      if n >= outLen then break end
      if math.floor(flags / (2 ^ bit)) % 2 == 0 then
        out[n + 1] = string.char(self:u8(pos)); pos = pos + 1; n = n + 1
      else
        local a, b = self:u8(pos), self:u8(pos + 1); pos = pos + 2
        local count = math.floor(a / 16) + 3
        local disp = (a % 16) * 0x100 + b + 1
        if disp > n then return nil, "invalid LZ77 back-reference" end
        for _ = 1, count do
          if n >= outLen then break end
          local src = n - disp + 1
          out[n + 1] = out[src]
          n = n + 1
        end
      end
    end
  end
  return table.concat(out)
end

return Rom
