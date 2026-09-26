local M = {}

M.freq = {
  2147483648,2275179671,2410468894,2553802834,2705659852,2866546760,
  3037000500,3217589947,3408917802,3611622603,3826380858,4053909305,
}
M.cgbFreq = {-2004,-1891,-1785,-1685,-1591,-1501,-1417,-1337,-1262,-1192,-1125,-1062}
M.noise = {
  0xD7,0xD6,0xD5,0xD4,0xC7,0xC6,0xC5,0xC4,0xB7,0xB6,0xB5,0xB4,
  0xA7,0xA6,0xA5,0xA4,0x97,0x96,0x95,0x94,0x87,0x86,0x85,0x84,
  0x77,0x76,0x75,0x74,0x67,0x66,0x65,0x64,0x57,0x56,0x55,0x54,
  0x47,0x46,0x45,0x44,0x37,0x36,0x35,0x34,0x27,0x26,0x25,0x24,
  0x17,0x16,0x15,0x14,0x07,0x06,0x05,0x04,0x03,0x02,0x01,0x00,
}

local function scaleEntry(key)
  -- gScaleTable is 15 descending octaves of 12 semitones: E0..EB .. 00..0B.
  local octave = 14 - math.floor(key / 12)
  local semitone = key % 12
  return octave * 16 + semitone
end

local function scaleFreq(key)
  local e = scaleEntry(key)
  local shift = math.floor(e / 16)
  local idx = (e % 16) + 1
  return math.floor(M.freq[idx] / (2 ^ shift))
end

-- Integer-equivalent form of MP2k MidiKeyToFreq's table interpolation. Lua
-- numbers are exact for these intermediate integer ranges on the supported VM.
function M.midiKeyToFreq(waveFreq, key, fine)
  key = math.floor(key or 0)
  fine = math.max(0, math.min(255, math.floor(fine or 0)))
  if key > 178 then key, fine = 178, 255 end
  if key < 0 then key, fine = 0, 0 end
  local v1, v2 = scaleFreq(key), scaleFreq(key + 1)
  local interp = v1 + math.floor((v2 - v1) * fine / 256)
  -- Equivalent to high 32 bits of waveFreq * interp.
  return math.floor((waveFreq * interp) / 4294967296)
end

function M.cgbRegister(chan, key, fine)
  key = math.floor(key or 0); fine = math.max(0, math.min(255, math.floor(fine or 0)))
  if chan == 4 then
    local k = key <= 20 and 0 or math.min(59, key - 21)
    return M.noise[k + 1]
  end
  if key <= 35 then key, fine = 0, 0 else key = key - 36 end
  if key > 130 then key, fine = 130, 255 end
  local function cgbScale(k)
    local octave, semi = math.floor(k / 12), k % 12
    return math.floor(M.cgbFreq[semi + 1] / (2 ^ octave))
  end
  local a,b = cgbScale(key), cgbScale(key+1)
  return a + math.floor(fine * (b-a) / 256) + 2048
end

return M
