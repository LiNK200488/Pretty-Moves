-- Pure-Lua PCM16 WAV writer used for runtime-derived FireRed SFX.
-- No LÖVE audio objects are created here: the resulting file is handed to
-- Gen1Recomp's own Sound layer so a bad SFX cannot take down global audio.
local M = {}

local function clamp(v, a, b)
  if v < a then return a end
  if v > b then return b end
  return v
end

local function u16le(n)
  n = math.floor(n or 0) % 65536
  return string.char(n % 256, math.floor(n / 256) % 256)
end

local function u32le(n)
  n = math.floor(n or 0) % 4294967296
  local b1 = n % 256; n = math.floor(n / 256)
  local b2 = n % 256; n = math.floor(n / 256)
  local b3 = n % 256; n = math.floor(n / 256)
  local b4 = n % 256
  return string.char(b1,b2,b3,b4)
end

local function s16le(v)
  v = math.floor(clamp(v, -32768, 32767))
  if v < 0 then v = v + 65536 end
  return u16le(v)
end

local function sampleLinear(samples, frames, pos)
  if frames <= 1 then return samples[1] or 0 end
  if pos <= 0 then return samples[1] or 0 end
  if pos >= frames - 1 then return samples[frames] or 0 end
  local i0 = math.floor(pos)
  local frac = pos - i0
  local a = samples[i0 + 1] or 0
  local b = samples[i0 + 2] or a
  return a + (b - a) * frac
end

function M.encodeStereo16(rendered, opts)
  opts = opts or {}
  if type(rendered) ~= "table" or type(rendered.left) ~= "table" or type(rendered.right) ~= "table" then
    return nil, "invalid rendered buffer"
  end
  local srcRate = tonumber(rendered.sampleRate)
  local srcFrames = tonumber(rendered.frames)
  if not srcRate or srcRate <= 0 or not srcFrames or srcFrames < 1 then
    return nil, "invalid source rate/frame count"
  end

  local outRate = math.floor(tonumber(opts.sampleRate) or 44100)
  if outRate < 8000 then outRate = 44100 end
  local leftGain = tonumber(opts.leftGain) or 1
  local rightGain = tonumber(opts.rightGain) or 1

  -- Transport-only conversion: the MP2k renderer owns synthesis, channel
  -- scaling, and mixer behavior. This writer only resamples and serializes PCM.
  local leftSrc, rightSrc = rendered.left, rendered.right

  local outFrames = math.max(1, math.floor(srcFrames * outRate / srcRate + 0.5))
  local step = srcRate / outRate
  local chunks, n = {}, 0

  for i=0,outFrames-1 do
    local pos = i * step
    local l = clamp(sampleLinear(leftSrc, srcFrames, pos) * leftGain, -1, 1)
    local r = clamp(sampleLinear(rightSrc, srcFrames, pos) * rightGain, -1, 1)
    local li = l < 0 and math.ceil(l * 32768) or math.floor(l * 32767)
    local ri = r < 0 and math.ceil(r * 32768) or math.floor(r * 32767)
    n = n + 1
    chunks[n] = s16le(li) .. s16le(ri)
  end

  local pcm = table.concat(chunks)
  local channels, bits = 2, 16
  local blockAlign = channels * bits / 8
  local byteRate = outRate * blockAlign
  local fmt = "fmt " .. u32le(16) .. u16le(1) .. u16le(channels)
    .. u32le(outRate) .. u32le(byteRate) .. u16le(blockAlign) .. u16le(bits)
  local data = "data" .. u32le(#pcm) .. pcm
  local wav = "RIFF" .. u32le(4 + #fmt + #data) .. "WAVE" .. fmt .. data
  return wav, { sampleRate=outRate, frames=outFrames, bytes=#wav }
end

return M
