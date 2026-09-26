local M = {}
local function band(a, b)
  a, b = math.floor(a or 0), math.floor(b or 0)
  local out, bit = 0, 1
  while a > 0 or b > 0 do
    local aa, bb = a % 2, b % 2
    if aa == 1 and bb == 1 then out = out + bit end
    a, b, bit = math.floor(a / 2), math.floor(b / 2), bit * 2
  end
  return out
end

local function bxor(a, b)
  a, b = math.floor(a or 0), math.floor(b or 0)
  local out, bit = 0, 1
  while a > 0 or b > 0 do
    local aa, bb = a % 2, b % 2
    if aa ~= bb then out = out + bit end
    a, b, bit = math.floor(a / 2), math.floor(b / 2), bit * 2
  end
  return out
end


local function clamp(v, lo, hi)
  if v < lo then return lo end
  if v > hi then return hi end
  return v
end

local function voiceMap(deps)
  local out = {}
  for _,tone in ipairs((deps and deps.voices) or {}) do out[tone.id] = tone end
  return out
end

local function resolveToneForKey(tone, key, depth)
  depth = depth or 0
  if not tone or depth > 8 then return nil end
  local isSplit = band((tone.type or 0), 0x40) ~= 0
  local isRhythm = band((tone.type or 0), 0x80) ~= 0
  if not isSplit and not isRhythm then return tone end
  local idx
  if isSplit then idx = tone.splitMap and tone.splitMap[clamp(key or 0,0,127)]
  else idx = clamp(key or 0,0,127) end
  local child = idx ~= nil and tone.children and tone.children[idx] or nil
  return resolveToneForKey(child, key, depth + 1)
end

local function tempoTimeline(plan)
  local changes = {{tick=0, tempo=75}}
  for _,track in ipairs(plan.tracks or {}) do
    for _,e in ipairs(track.events or {}) do
      if e.kind == 'tempo' then changes[#changes+1] = {tick=e.tick, tempo=e.value} end
    end
  end
  table.sort(changes, function(a,b)
    if a.tick == b.tick then return a.tempo < b.tempo end
    return a.tick < b.tick
  end)
  local dedup = {}
  for _,c in ipairs(changes) do
    if #dedup > 0 and dedup[#dedup].tick == c.tick then dedup[#dedup] = c
    else dedup[#dedup+1] = c end
  end
  return dedup
end

local function tickToSeconds(runtime, timeline, tick)
  local sec, prevTick, tempo = 0, 0, 75
  for _,c in ipairs(timeline) do
    if c.tick > tick then break end
    if c.tick > prevTick then
      sec = sec + (c.tick - prevTick) * runtime.secondsPerTick(tempo)
      prevTick = c.tick
    end
    tempo = c.tempo
  end
  if tick > prevTick then sec = sec + (tick - prevTick) * runtime.secondsPerTick(tempo) end
  return sec
end

local function panGains(runtime, pan)
  return runtime.stereoGains(pan or 0)
end

local function noteFine(e)
  local bend = (e.bend or 0) * (e.bendRange or 2)
  local x = ((e.tune or 0) + bend) * 4
  local coarse = math.floor(x / 256)
  local fine = x % 256
  return (e.key or 60) + coarse, fine
end

local function pitchStepForState(tables, e, tone, wave, bend, bendRange, tune)
  local state = {
    key=e.key,
    bend=(bend ~= nil) and bend or e.bend,
    bendRange=(bendRange ~= nil) and bendRange or e.bendRange,
    tune=(tune ~= nil) and tune or e.tune,
  }
  local key, fine = noteFine(state)
  key = math.max(0, math.min(178, key))
  local wf = wave.frequencyReference or wave.freq or 0
  local f = tables.midiKeyToFreq(wf, key, fine)
  local base = tables.midiKeyToFreq(wf, tone.key or 60, 0)
  if base <= 0 then return 1 end
  return f / base
end


-- FireRed's stock MP2k DirectSound mixer applies track volume/pan, note
-- velocity, ADSR, and the global master volume before summing channels.
-- Keeping that order is important: summing near-full-scale normalized samples
-- and clamping afterward creates distortion that the original mixer never sees.
local FIRE_RED_MASTER_VOLUME = 12

local function mp2kDirectSoundChannelGains(e)
  local trackVol = clamp(math.floor(e.volume or 127), 0, 127)
  local velocity = clamp(math.floor(e.velocity or 127), 0, 127)
  local pan = clamp(math.floor(e.pan or 0), -64, 63)

  -- TrkVolPitSet: volX is 64 at normal playback, so x=(vol*64)>>5.
  local x = math.floor(trackVol * 64 / 32)
  local y = clamp(2 * pan, -128, 127)
  local trackRight = math.floor((y + 128) * x / 256)
  local trackLeft = math.floor((127 - y) * x / 256)

  -- ply_note scales the track-side volumes by note velocity into the channel.
  local channelRight = math.floor(trackRight * velocity / 128)
  local channelLeft = math.floor(trackLeft * velocity / 128)

  -- SoundMainRAM: ((env * (master+1) * channelVol) >> 13), then the
  -- normal uncompressed mixer converts the 0..255 volume domain to 0..127.
  -- Return the envelope-independent part normalized to the signed PCM range.
  local master = FIRE_RED_MASTER_VOLUME + 1
  local left = (master * channelLeft) / (8192 * 2 * 128) * 255
  local right = (master * channelRight) / (8192 * 2 * 128) * 255
  return left, right
end

local function controllerChangesForNote(track, e, endTick)
  local out = {}
  for _,c in ipairs(track.events or {}) do
    if c.tick >= e.tick and c.tick <= endTick then
      if c.kind == 'bend' or c.kind == 'bend_range' or c.kind == 'tune'
          or c.kind == 'volume' or c.kind == 'pan' then
        out[#out+1] = c
      end
    end
  end
  table.sort(out, function(a,b)
    if a.tick == b.tick then return (a.offset or 0) < (b.offset or 0) end
    return a.tick < b.tick
  end)
  return out
end

-- Stock MP2k uses a 23-bit fractional accumulator for normal DirectSound
-- voices.  The ARM mixer interpolates with an arithmetic shift, so preserve
-- that integer truncation instead of doing floating-point interpolation.
local function sampleMp2k(samples, pos, noResample)
  local n = #samples
  if n == 0 or pos < 0 then return 0 end
  local i = math.floor(pos)
  local a = samples[i+1]
  if a == nil then return 0 end
  if noResample then return a end
  local b = samples[i+2] or a
  local frac23 = math.floor((pos - i) * 8388608)
  if frac23 < 0 then frac23 = 0 elseif frac23 > 8388607 then frac23 = 8388607 end
  -- Equivalent to: a + ((frac23 * (b-a)) ASR 23).
  return a + math.floor(frac23 * (b-a) / 8388608)
end

-- DirectSound channels do not use the GBA PSG hardware envelope. This state
-- model preserves the M4A tone bytes as discrete mixer steps rather than
-- mapping them to arbitrary millisecond constants. One update occurs per
-- rendered 1/64 second, matching the compatible-sound envelope cadence.
local function mixerEnvelope(tone, bodyFrames, rate)
  -- SoundMain-compatible byte-domain envelope approximation: at each mixer
  -- update, attack adds the attack byte up to 255; decay/release multiply the
  -- current envelope by their byte / 256. Sustain is the lower bound for decay.
  -- FireRed calls SoundMain once per video frame, so use ~59.7275 Hz here.
  local stepFrames = math.max(1, math.floor(rate / 59.7275 + 0.5))
  local attack = tone.attack or 0
  local decay = tone.decay or 0
  local sustain = tone.sustain or 0
  local release = tone.release or 0
  local env = (attack == 0) and 255 or 0
  local lastStep = -1
  local function advance(targetStep, inRelease)
    while lastStep < targetStep do
      lastStep = lastStep + 1
      if inRelease then
        env = math.floor(env * release / 256)
      elseif env < 255 and attack ~= 0 then
        env = math.min(255, env + attack)
      elseif decay ~= 0 and env > sustain then
        env = math.floor(env * decay / 256)
        if env < sustain then env = sustain end
      else
        env = math.max(env, sustain)
      end
    end
  end
  local bodyStep = math.floor(bodyFrames / stepFrames)
  advance(bodyStep, false)
  local releaseStart = env
  local function gainAt(frame)
    local step = math.floor(frame / stepFrames)
    if frame < bodyFrames then
      -- recompute body independently so out-of-order calls stay deterministic.
      local e=(attack==0) and 255 or 0
      for i=0,step do
        if e < 255 and attack ~= 0 then e=math.min(255,e+attack)
        elseif decay ~= 0 and e > sustain then e=math.max(sustain,math.floor(e*decay/256)) end
      end
      return e/255
    end
    local rs=math.floor((frame-bodyFrames)/stepFrames)
    local e=releaseStart
    for _=1,rs+1 do e=math.floor(e*release/256) end
    return e/255
  end
  local relSteps=1
  local e=releaseStart
  while e>1 and relSteps<512 do e=math.floor(e*release/256); relSteps=relSteps+1 end
  return gainAt, math.max(stepFrames, relSteps*stepFrames)
end

local function cgbSoftwareEnvelope(tone, bodyFrames, rate, goal)
  -- CgbSound/PSG envelope steps occur at 64 Hz. The four ToneData envelope
  -- bytes are hardware step counters, not arbitrary millisecond constants.
  local stepFrames = math.max(1, math.floor(rate / 64 + 0.5))
  local attack = tone.attack or 0
  local decay = tone.decay or 0
  local sustainByte = tone.sustain or 0
  local release = tone.release or 0
  goal = clamp(math.floor(goal or 15), 0, 15)
  local sustainGoal = math.floor((goal * sustainByte + 15) / 16)
  sustainGoal = clamp(sustainGoal, 0, goal)

  local attackEnd = attack == 0 and 0 or goal * math.max(1, attack)
  local function bodyVolume(frame)
    local step = math.floor(math.max(0, frame) / stepFrames)
    local vol
    if attack == 0 then
      vol = goal
    else
      vol = math.min(goal, math.floor(step / math.max(1, attack)))
    end
    if step >= attackEnd then
      local ds = step - attackEnd
      if decay == 0 then vol = sustainGoal
      else vol = math.max(sustainGoal, goal - math.floor(ds / math.max(1, decay))) end
    end
    return clamp(vol, 0, 15)
  end

  -- A note can be released before decay reaches sustain. The old renderer
  -- always started release from sustainGoal, shortening/quieting those notes.
  local releaseStart = bodyVolume(math.max(0, bodyFrames - 1))
  local function stageAt(frame)
    local vol
    if frame < bodyFrames then
      vol = bodyVolume(frame)
    else
      local rs = math.floor((frame - bodyFrames) / stepFrames)
      if release == 0 then vol = 0
      else vol = math.max(0, releaseStart - math.floor(rs / math.max(1, release))) end
    end
    return vol / 15
  end
  local releaseFrames = math.max(stepFrames, 15 * math.max(1, release) * stepFrames)
  return stageAt, releaseFrames
end


-- Square/noise channels have two envelope layers on real GBA hardware:
-- CgbSound updates an MP2K software envelope at the VBlank cadence, while
-- NRx2 owns a separate 4-bit hardware envelope clocked by the PSG frame
-- sequencer at 64 Hz.  Every CgbSound MO_VOL write reloads NRx2 from the
-- software level and sets NRx4's trigger bit.  The 64 Hz frame-sequencer phase
-- itself does NOT reset on those writes.  Short effects such as SE_BALL_OPEN
-- are very sensitive to this distinction because their square/noise notes are
-- retriggered before a simple 1/64-second envelope approximation can settle.
local function cgbNrx2Envelope(tone, bodyFrames, rate, goal, absoluteStartFrame)
  local FPS = 59.727500569606
  local attack = band(tone.attack or 0, 0x07)
  local decay = band(tone.decay or 0, 0x07)
  local sustainByte = band(tone.sustain or 0, 0x0F)
  local release = band(tone.release or 0, 0x07)
  goal = clamp(math.floor(goal or 15), 0, 15)
  local sustainGoal = clamp(math.floor((goal * sustainByte + 15) / 16), 0, 15)

  local swState, swVol, swCounter, hwStepDir
  if attack == 0 then
    swVol = goal
    swState = 'decay'
    swCounter = decay
    hwStepDir = decay
    if decay == 0 then
      if sustainByte == 0 then
        -- CgbSound enters the zero-sustain/release-style hardware decay path.
        -- It does not force the initial NRx2 volume to zero.
        swState = 'release'
        hwStepDir = release
      else
        swVol = sustainGoal
        swState = 'sustain'
        swCounter = 7
        hwStepDir = 0x08 -- step time 0, frozen at sustain
      end
    end
  else
    swVol = 0
    swState = 'attack'
    swCounter = attack
    hwStepDir = attack + 0x08
  end

  local hwVol, hwNextStep, hwDead = 0, 0, false
  local function hwWrite()
    local stepTime = band(hwStepDir, 0x07)
    local dirInc = band(hwStepDir, 0x08) ~= 0
    hwVol = band(swVol, 0x0F)
    hwNextStep = stepTime
    hwDead = stepTime == 0
      or ((not dirInc) and hwVol == 0)
      or (dirInc and hwVol == 15)
  end
  hwWrite()

  local absStart = math.max(0, math.floor(absoluteStartFrame or 0))
  -- Hardware frame sequencer is global/free-running.  Seeding from absolute
  -- render time preserves its phase across rapid note retriggers without
  -- making each cached note pretend the 64 Hz clock restarted at note-on.
  local hwClockAccum = ((absStart * 64) / rate) % 1
  local engineClockAccum = ((absStart * FPS) / rate) % 1
  local absoluteEngineTick = math.floor((absStart * FPS) / rate)
  local stopRequested = false
  local off = false
  local lastFrame = -1
  local lastGain = hwVol / 15
  local lastWrite = false

  local function stepComplete(doubleStep, usedDouble)
    swCounter = swCounter - 1
    if doubleStep and not usedDouble then return true end
    return false
  end

  local function softwareTick(c15)
    if off then return false end
    local wrote = false
    local doubleStep = c15 == 0
    local usedDouble = false

    -- NOTE-off marks STOP in MP2K; CgbSound enters release on the next engine
    -- pass and immediately rewrites NRx2/NRx4 when release is non-zero.
    if stopRequested and swState ~= 'release' then
      swState = 'release'
      swCounter = release
      if release == 0 then
        off = true
        return false
      end
      hwStepDir = release
      wrote = true
      if stepComplete(doubleStep, usedDouble) then usedDouble = true else
        if wrote then hwWrite() end
        return wrote
      end
    end

    while not off do
      if swCounter == 0 then
        if swState == 'release' then
          swVol = swVol - 1
          if swVol <= 0 then off = true; break end
          swCounter = release
        elseif swState == 'sustain' then
          swVol = sustainGoal
          swCounter = 7
        elseif swState == 'decay' then
          swVol = swVol - 1
          if swVol <= sustainGoal then
            if sustainByte == 0 then
              off = true
              break
            end
            swState = 'sustain'
            swVol = sustainGoal
            swCounter = 7
            hwStepDir = 0x08
            wrote = true
          else
            swCounter = decay
          end
        else -- attack
          swVol = swVol + 1
          if swVol >= goal then
            swState = 'decay'
            swCounter = decay
            if decay ~= 0 then
              swVol = goal
              hwStepDir = decay
              wrote = true
            else
              if sustainByte == 0 then
                off = true
                break
              end
              swState = 'sustain'
              swVol = sustainGoal
              swCounter = 7
              hwStepDir = 0x08
              wrote = true
            end
          else
            swCounter = attack
          end
        end
      end

      local repeatStep = stepComplete(doubleStep, usedDouble)
      if repeatStep then
        usedDouble = true
      else
        break
      end
    end

    if wrote and not off then hwWrite() end
    return wrote
  end

  local function hardwareClock()
    if off or hwDead or band(hwStepDir, 0x07) == 0 then return end
    hwNextStep = hwNextStep - 1
    if hwNextStep ~= 0 then return end
    local stepTime = band(hwStepDir, 0x07)
    if band(hwStepDir, 0x08) ~= 0 then
      hwVol = hwVol + 1
      if hwVol >= 15 then hwVol, hwDead = 15, true
      else hwNextStep = stepTime end
    else
      hwVol = hwVol - 1
      if hwVol <= 0 then hwVol, hwDead = 0, true
      else hwNextStep = stepTime end
    end
  end

  local function advanceOne(frame)
    if frame >= bodyFrames then stopRequested = true end
    lastWrite = false

    -- Engine/VBlank and PSG frame-sequencer clocks are independent.  Process
    -- all boundaries that fall into this rendered sample before taking its
    -- audible level, matching the real register->hardware flow closely.
    engineClockAccum = engineClockAccum + FPS / rate
    while engineClockAccum >= 1 do
      engineClockAccum = engineClockAccum - 1
      absoluteEngineTick = absoluteEngineTick + 1
      local c15 = 14 - (absoluteEngineTick % 15)
      if softwareTick(c15) then lastWrite = true end
    end

    hwClockAccum = hwClockAccum + 64 / rate
    while hwClockAccum >= 1 do
      hwClockAccum = hwClockAccum - 1
      hardwareClock()
    end

    lastGain = off and 0 or (hwVol / 15)
  end

  local function gainAt(frame)
    frame = math.max(0, math.floor(frame or 0))
    while lastFrame < frame do
      lastFrame = lastFrame + 1
      advanceOne(lastFrame)
    end
    return lastGain, lastWrite
  end

  -- Software release is the lifetime limiter: at worst it needs one VBlank
  -- before entering release, then 15 volume steps of `release` engine ticks.
  local vblankFrames = math.ceil(rate / FPS)
  local releaseFrames
  if release == 0 then releaseFrames = vblankFrames + 2
  else releaseFrames = vblankFrames + math.ceil(15 * release * rate / FPS) + 2 end
  return gainAt, releaseFrames
end

-- CGB square channels use an 8-step duty sequencer. Keeping the actual bit
-- patterns preserves the hardware phase/polarity instead of approximating the
-- duty as a continuous threshold.
local dutyPatterns = {[0]=0x01,[1]=0x81,[2]=0xE1,[3]=0x7E}
local function squareSample(phase, duty)
  local pattern = dutyPatterns[duty or 2] or dutyPatterns[2]
  local step = math.floor((phase % 1) * 8) % 8
  return band(pattern, 2 ^ step) ~= 0 and 1 or -1
end

-- FireRed initializes SOUNDBIAS_H to 0x40. For TONEDATA_TYPE_FIX CGB voices
-- CgbSound rounds the initial pitch register to the GBA's 65536 Hz PWM grid:
-- (freq + 1) & 0x7fe. Sweep-generated frequencies are not requantized.
local function cgbFixedRegister(tone, channel, reg)
  if channel < 4 and band(tone.type or 0, 0x08) ~= 0 then
    reg = (math.floor((reg + 1) / 2) * 2) % 2048
  end
  return reg
end

-- Square 1 NR10 sweep. MP2k writes ToneData.panSweep to NR10 at note start;
-- the hardware then clocks the shadow-frequency unit at 128 Hz.
local function newSquareSweep(sweepByte, reg)
  local sweep = band(sweepByte or 0, 0x7F)
  local time = math.floor(sweep / 16) % 8
  if time == 0 then time = 8 end
  local shift = sweep % 8
  local negate = band(sweep, 0x08) ~= 0
  local state = {
    reg=reg, shadow=reg, time=time, shift=shift, negate=negate,
    counter=time, enabled=(time ~= 8) or shift ~= 0, muted=false, accum=0,
  }

  local function calc(initial)
    -- A zero shift still participates in timed overflow behavior, but the
    -- trigger-time overflow check only exists when shift is non-zero.
    local delta = math.floor(state.shadow / (2 ^ state.shift))
    local nextReg = state.negate and (state.shadow - delta) or (state.shadow + delta)
    if not state.negate and nextReg >= 2048 then
      state.muted = true
      return false
    end
    if not initial then
      if state.negate then
        if nextReg >= 0 then state.shadow, state.reg = nextReg, nextReg end
      elseif state.shift ~= 0 then
        state.shadow, state.reg = nextReg, nextReg
        -- Hardware immediately performs a second overflow-only calculation
        -- after an upward write.
        local next2 = state.shadow + math.floor(state.shadow / (2 ^ state.shift))
        if next2 >= 2048 then state.muted = true; return false end
      end
    end
    return true
  end

  if shift ~= 0 then calc(true) end
  -- NRx2 volume writes in CgbSound also set the NRx4 trigger bit. For
  -- Square 1 that reloads the hardware sweep shadow/timer from the current
  -- frequency register, but the 128 Hz frame-sequencer phase keeps running.
  state.retrigger = function()
    state.shadow = state.reg
    state.counter = state.time
    state.enabled = (state.time ~= 8) or state.shift ~= 0
    state.muted = false
    if state.shift ~= 0 then calc(true) end
  end
  state.clock = function(rate)
    if not state.enabled or state.muted then return end
    state.accum = state.accum + 128 / rate
    while state.accum >= 1 do
      state.accum = state.accum - 1
      state.counter = state.counter - 1
      if state.counter <= 0 then
        calc(false)
        state.counter = state.time
        if state.muted then break end
      end
    end
  end
  return state
end

-- The GBA routes CGB volume through ChnVolSetAsm and CgbModVol before the
-- 4-bit hardware envelope. Do that once here; do NOT multiply track volume and
-- velocity again in the waveform mixer. The previous double attenuation is
-- what buried SE_BALL_OPEN's quiet square/noise layers under its PCM snare.
local function cgbChannelMix(e)
  local trackVol = clamp(math.floor(e.volume or 127), 0, 127)
  local velocity = clamp(math.floor(e.velocity or 127), 0, 127)
  local pan = clamp(math.floor(e.pan or 0), -64, 63)
  local x = math.floor(trackVol * 64 / 32)
  local y = clamp(2 * pan, -128, 127)
  local volMR = math.floor((y + 128) * x / 256)
  local volML = math.floor((127 - y) * x / 256)
  local rightVolume = math.floor(128 * velocity * volMR / 16384)
  local leftVolume = math.floor(127 * velocity * volML / 16384)
  rightVolume = clamp(rightVolume, 0, 255)
  leftVolume = clamp(leftVolume, 0, 255)

  local routeL, routeR = 1, 1
  local hardPan = false
  if rightVolume >= leftVolume then
    if math.floor(rightVolume / 2) >= leftVolume then routeL, routeR, hardPan = 0, 1, true end
  else
    if math.floor(leftVolume / 2) >= rightVolume then routeL, routeR, hardPan = 1, 0, true end
  end
  local goal = math.floor((leftVolume + rightVolume) / 16)
  if hardPan then goal = math.min(goal, 15) end
  return clamp(goal, 0, 15), routeL, routeR
end

-- With SOUND_ALL_MIX_FULL, a full-scale square/noise level reaches roughly
-- +/-30 before the final GBA-style /256 output normalization: raw PSG +/-64
-- * env(15/16) >> 1. In our normalized PCM domain that is 30/256.
local CGB_OUTPUT_SCALE = 15 / 128

local function wave32Samples(bytes)
  local out = {}
  for i=1,#(bytes or '') do
    local b = string.byte(bytes, i)
    out[#out+1] = ((math.floor(b / 16) % 16) - 7.5) / 7.5
    out[#out+1] = ((b % 16) - 7.5) / 7.5
  end
  return out
end

local function cgbHzFromRegister(channel, reg)
  if channel == 4 then
    local r = reg % 8
    local s = math.floor(reg / 16) % 16
    local divisor = (r == 0) and 0.5 or r
    return 524288 / divisor / (2 ^ (s + 1))
  end
  reg = clamp(reg, 0, 2047)
  return 131072 / math.max(1, 2048 - reg)
end

-- GBA square channels do not restart their 8-step duty sequencer when NRx4 is
-- triggered. The oscillator counter free-runs, even while a channel is silent.
-- A cached SFX therefore has to carry Square 1/2 phase from one note trigger to
-- the next instead of rendering every note from phase zero.  This is especially
-- audible in SE_BALL_OPEN, whose program 86 fires several very short Square 1
-- notes through the same hardware channel.
--
-- Precompute the phase seen at each note-on by walking the hardware channel's
-- frequency timeline.  Sweep changes are included while the preceding note is
-- keyed; after key-off the square counter keeps running at the last programmed
-- frequency until the next trigger.  The first note intentionally starts from
-- the reset phase used by the standalone cache renderer; only retrigger behavior
-- is changed here.
local function assignSquareRetriggerPhases(notes, tables, rate)
  local perChannel = {[1]={}, [2]={}}
  for _,n in ipairs(notes or {}) do
    if n.baseType == 1 or n.baseType == 2 then
      perChannel[n.baseType][#perChannel[n.baseType]+1] = n
    end
  end

  for channel=1,2 do
    local list = perChannel[channel]
    table.sort(list, function(a,b)
      if a.startSec == b.startSec then return (a.track or 0) < (b.track or 0) end
      return a.startSec < b.startSec
    end)

    local phase, hz, frame = 0, 64, 0
    local sweep, sweepEnd = nil, -1
    for _,n in ipairs(list) do
      local target = math.max(0, math.floor(n.startSec * rate + 0.5))
      while frame < target do
        if sweep and frame < sweepEnd then
          sweep.clock(rate)
          if not sweep.muted then hz = cgbHzFromRegister(channel, sweep.reg) end
        else
          sweep = nil
        end
        phase = (phase + hz / rate) % 1
        frame = frame + 1
      end

      n.cgbStartPhase = phase

      local key,fine = noteFine(n.event)
      local reg = tables.cgbRegister(channel,key,fine)
      reg = cgbFixedRegister(n.tone,channel,reg)
      hz = cgbHzFromRegister(channel,reg)
      if channel == 1 then
        sweep = newSquareSweep(n.tone.panSweep or 0,reg)
      else
        sweep = nil
      end
      local bodyFrames = math.max(1, math.floor(n.bodySec * rate + 0.5))
      sweepEnd = target + bodyFrames
      frame = target
    end
  end
end

-- The GBA has exactly one instance of each PSG hardware channel (Square 1,
-- Square 2, Wave, Noise). A new CGB note assigned to a channel reprograms /
-- retriggers that hardware channel; the previous note cannot keep contributing
-- an independent release tail underneath it. The note-oriented offline renderer
-- used to let those tails overlap, which is especially audible in rapid Noise
-- sequences such as FireRed SE_M_SNORE and in short square retrigger effects.
--
-- Resolve that hardware ownership before mixing: the next note on a CGB channel
-- is a hard lifetime boundary for the current note. DirectSound is deliberately
-- excluded because MP2K has multiple software mixer channels and overlapping PCM
-- voices there are valid.
local function capCgbRetriggerLifetimes(notes, rate)
  local perChannel = {[1]={}, [2]={}, [3]={}, [4]={}}
  for _,n in ipairs(notes or {}) do
    if n.baseType and n.baseType >= 1 and n.baseType <= 4 then
      perChannel[n.baseType][#perChannel[n.baseType]+1] = n
    end
  end

  for channel=1,4 do
    local list = perChannel[channel]
    table.sort(list, function(a,b)
      if a.startSec == b.startSec then
        if (a.track or 0) == (b.track or 0) then
          return ((a.event and a.event.offset) or 0) < ((b.event and b.event.offset) or 0)
        end
        return (a.track or 0) < (b.track or 0)
      end
      return a.startSec < b.startSec
    end)

    for i=1,#list-1 do
      local cur,nxt = list[i],list[i+1]
      local untilNext = math.max(0, math.floor((nxt.startSec-cur.startSec)*rate+0.5))
      if cur.renderFrames == nil or untilNext < cur.renderFrames then
        cur.renderFrames = untilNext
      end
    end
  end
end

local function lfsrStep(state, width7)
  local bit = bxor((state % 2), (math.floor(state / 2) % 2))
  state = math.floor(state / 2) + bit * 16384
  if width7 then
    if bit == 1 then
      if band(state, 0x40) == 0 then state = state + 0x40 end
    else
      if band(state, 0x40) ~= 0 then state = state - 0x40 end
    end
  end
  return state
end

local function lfsrLevel(state)
  -- GBA PSG polarity: low LFSR bit set is the positive output level.
  return (state % 2 ~= 0) and 1 or -1
end

-- Box-average every LFSR transition that occurs inside an output frame. The
-- noise clock can run dozens of times faster than the renderer rate; sampling
-- it only once per frame aliases percussion into a rigid click/pop.
local function noiseSampleAveraged(state, phase, clocks, width7)
  if clocks <= 0 then return lfsrLevel(state), state, phase end
  local remaining, sum = clocks, 0
  while remaining > 0 do
    local toEdge = 1 - phase
    if toEdge <= 0.000000001 then
      state = lfsrStep(state, width7)
      phase = 0
      toEdge = 1
    end
    local span = math.min(remaining, toEdge)
    sum = sum + lfsrLevel(state) * span
    remaining = remaining - span
    phase = phase + span
    if phase >= 0.999999999 then
      state = lfsrStep(state, width7)
      phase = 0
    end
  end
  return sum / clocks, state, phase
end

-- FireRed uses Nintendo's stock MP2k DirectSound reverb. SoundMainRAM
-- seeds each new PCM block from four signed 8-bit taps in the circular DMA
-- buffer: L/R at the current delay position plus L/R one VBlank-frame away.
-- The mono wet value is (sum * amount) >> 9 and is written back to BOTH sides.
-- CGB/PSG channels bypass this PCM feedback path.
local function applyMp2kReverb(left, right, rate, amount)
  amount = clamp(math.floor(amount or 0), 0, 127)
  if amount == 0 then return end
  local gbaRate, gbaBuf, gbaFrame = 13379, 1584, 224
  local bufferSize = math.max(1, math.floor(gbaBuf * rate / gbaRate + 0.5))
  local frameSize = math.max(1, math.floor(gbaFrame * rate / gbaRate + 0.5))
  local delayL, delayR = {}, {}
  for i=1,bufferSize do delayL[i],delayR[i]=0,0 end
  local pos = 1
  local function toS8(x)
    x = clamp(x, -1, 1)
    if x >= 0 then return math.floor(x * 127 + 0.5) end
    return math.ceil(x * 128 - 0.5)
  end
  local function fromS8(x) return x / 128 end
  for i=1,#left do
    local other = ((pos - 1 + frameSize) % bufferSize) + 1
    local sum = delayL[pos] + delayR[pos] + delayL[other] + delayR[other]
    local product = sum * amount
    -- ARM ASR #9 is an arithmetic right shift; floor division reproduces
    -- the sign-extending shift for negative products as well as positive ones.
    local wet = math.floor(product / 512)
    -- Stock SoundMainRAM performs this signed-byte correction after ASR #9
    -- before storing the feedback seed.
    if band(wet, 0x80) ~= 0 then wet = wet + 1 end
    local wl = clamp(toS8(left[i]) + wet, -128, 127)
    local wr = clamp(toS8(right[i]) + wet, -128, 127)
    left[i], right[i] = fromS8(wl), fromS8(wr)
    delayL[pos], delayR[pos] = wl, wr
    pos = pos + 1; if pos > bufferSize then pos = 1 end
  end
end

local function effectiveSongReverb(plan, opts)
  if opts and opts.reverb ~= nil then return clamp(math.floor(opts.reverb),0,127) end
  local raw = (plan and plan.reverb) or 0
  -- Song headers only change SoundInfo.reverb when bit 7 is set. FireRed's
  -- m4aSoundInit leaves global reverb at zero, so an unflagged header is dry.
  if band(raw, 0x80) ~= 0 then return band(raw, 0x7F) end
  return 0
end

local function trackFineTick(track, fromTick)
  for _,e in ipairs(track.events or {}) do
    if e.kind == 'fine' and e.tick >= (fromTick or 0) then return e.tick end
  end
  return nil
end

-- TIE notes are held until EOT (optionally key-specific). If a track reaches
-- FINE first, MP2k's TrackStop kills the channel there instead of allowing a
-- synthesized release tail to continue after the sequence has ended.
local function tiedNoteEndTick(track, note)
  local fineTick = trackFineTick(track, note.tick)
  for _,e in ipairs(track.events or {}) do
    if e.tick >= note.tick and e.kind == 'note_off' then
      if e.key == nil or e.key == note.key then
        if fineTick then return math.min(e.tick, fineTick), e.tick <= fineTick end
        return e.tick, true
      end
    end
  end
  return fineTick, false
end

function M.renderSong(runtime, tables, plan, deps, opts)
  opts = opts or {}
  local rate = opts.sampleRate or runtime.GBA_MIX_RATE
  local timeline = tempoTimeline(plan)
  local voices = voiceMap(deps)
  local notes, endSec = {}, 0

  for ti,track in ipairs(plan.tracks or {}) do
    for _,e in ipairs(track.events or {}) do
      if e.kind == 'note' or e.kind == 'note_on' then
        local rootTone = voices[e.voice]
        local tone = resolveToneForKey(rootTone, e.key)
        if tone then
          local startSec = tickToSeconds(runtime, timeline, e.tick)
          local fineTick = trackFineTick(track, e.tick)
          local endTick, releaseAtEnd
          if e.tied then
            endTick, releaseAtEnd = tiedNoteEndTick(track, e)
            if not endTick then endTick = e.tick + (opts.tieFallbackTicks or 12); releaseAtEnd = true end
          else
            endTick = e.tick + (e.duration or 0)
            releaseAtEnd = true
          end
          if endTick <= e.tick then endTick = e.tick + 1 end
          local bodySec = math.max(1/rate, tickToSeconds(runtime, timeline, endTick) - startSec)
          local baseType = (tone.type or 0) % 8
          local lg, rg = panGains(runtime, e.pan)
          local dsLg, dsRg = mp2kDirectSoundChannelGains(e)
          local channelGoal, cgbLg, cgbRg
          if baseType >= 1 and baseType <= 4 then
            channelGoal, cgbLg, cgbRg = cgbChannelMix(e)
          else
            channelGoal = 15
          end
          local env, releaseFrames
          local bodyFramesForEnv = math.floor(bodySec*rate+0.5)
          if baseType == 0 then
            env, releaseFrames = mixerEnvelope(tone, bodyFramesForEnv, rate)
          elseif baseType == 3 then
            -- Wave channel uses NR32 rather than the NRx2 hardware envelope.
            env, releaseFrames = cgbSoftwareEnvelope(tone, bodyFramesForEnv, rate, channelGoal)
          else
            env, releaseFrames = cgbNrx2Envelope(tone, bodyFramesForEnv, rate, channelGoal,
                                                 math.floor(startSec*rate+0.5))
          end
          if not releaseAtEnd then releaseFrames = 0 end

          -- FINE invokes TrackStop in the stock driver. Never render this
          -- channel beyond that hard stop, even when a looping sample has a
          -- very slow release byte (the Gust wind exposed this bug).
          local hardStopFrames
          if fineTick then
            local fineSec = tickToSeconds(runtime, timeline, fineTick)
            hardStopFrames = math.max(0, math.ceil((fineSec - startSec) * rate))
          end
          local renderFrames = math.max(1, math.floor(bodySec*rate+0.5) + releaseFrames)
          if hardStopFrames then renderFrames = math.min(renderFrames, hardStopFrames) end

          notes[#notes+1] = {
            event=e,tone=tone,startSec=startSec,bodySec=bodySec,track=ti,baseType=baseType,
            lg=lg,rg=rg,cgbLg=cgbLg,cgbRg=cgbRg,dsLg=dsLg,dsRg=dsRg,env=env,releaseFrames=releaseFrames,
            renderFrames=renderFrames,
            controllerChanges=controllerChangesForNote(track, e, endTick),
          }
          endSec = math.max(endSec, startSec + renderFrames/rate)
        end
      end
    end
  end

  -- A FireRed SFX track is no longer audible once the sequence itself ends.
  -- Cap the final mix to the latest track termination tick so envelope release,
  -- looping DirectSound waves, or reverb cannot make the generated WAV longer
  -- than the original MP2k sequence. This is deliberately sequence-wide rather
  -- than note-specific, because some converted tracks end through control flow
  -- that does not leave a convenient per-note FINE event to clamp against.
  local sequenceEndTick = 0
  for _,track in ipairs(plan.tracks or {}) do
    local trackEnd = tonumber(track.ticks) or 0
    for _,e in ipairs(track.events or {}) do
      if e.kind == 'fine' and e.tick > trackEnd then trackEnd = e.tick end
    end
    if trackEnd > sequenceEndTick then sequenceEndTick = trackEnd end
  end
  if sequenceEndTick > 0 then
    local sequenceEndSec = tickToSeconds(runtime, timeline, sequenceEndTick)
    endSec = math.min(endSec, sequenceEndSec)
  end
  endSec = math.min(endSec, opts.maxSeconds or 8)

  -- Resolve the hardware square-channel phase timeline before any notes are
  -- mixed.  The render loop below can stay note-oriented while still entering
  -- each Square 1/2 note at the phase the free-running GBA channel had reached.
  assignSquareRetriggerPhases(notes, tables, rate)
  capCgbRetriggerLifetimes(notes, rate)

  local frames = math.max(1, math.ceil(endSec * rate))
  local pcmLeft,pcmRight,cgbLeft,cgbRight = {},{},{},{}
  for i=1,frames do pcmLeft[i],pcmRight[i],cgbLeft[i],cgbRight[i]=0,0,0,0 end
  local counts={directSound=0,square=0,wave=0,noise=0,keySplitResolved=0,rhythmResolved=0,unsupported=0}

  for _,n in ipairs(notes) do
    local e,tone = n.event,n.tone
    local start = math.floor(n.startSec * rate)
    local bodyFrames = math.max(1, math.floor(n.bodySec*rate+0.5))
    local totalFrames = n.renderFrames or (bodyFrames + n.releaseFrames)
    if n.baseType == 0 and tone.wave then
      counts.directSound=counts.directSound+1
      local decoded = runtime.decodeDirectSoundWave(tone.wave)
      if decoded then
        local bend, bendRange, tune = e.bend or 0, e.bendRange or 2, e.tune or 0
        local volume, pan = e.volume or 127, e.pan or 0
        local dsLg, dsRg = n.dsLg, n.dsRg
        local changes, changeIndex = n.controllerChanges or {}, 1
        local srcPos,loopStart = 0,decoded.loopStart or decoded.sampleCount
        local looped = decoded.looped and loopStart < decoded.sampleCount
        for j=0,totalFrames-1 do
          local di=start+j+1; if di>frames then break end
          local sec = n.startSec + j / rate
          while changes[changeIndex] do
            local c = changes[changeIndex]
            local cSec = tickToSeconds(runtime, timeline, c.tick)
            if cSec > sec then break end
            if c.kind == 'bend' then bend = c.value
            elseif c.kind == 'bend_range' then bendRange = c.value
            elseif c.kind == 'tune' then tune = c.value
            elseif c.kind == 'volume' then
              volume = c.value
              dsLg, dsRg = mp2kDirectSoundChannelGains({volume=volume, velocity=e.velocity, pan=pan})
            elseif c.kind == 'pan' then
              pan = c.value
              dsLg, dsRg = mp2kDirectSoundChannelGains({volume=volume, velocity=e.velocity, pan=pan})
            end
            changeIndex = changeIndex + 1
          end
          local ratio = pitchStepForState(tables,e,tone,decoded,bend,bendRange,tune)
          local p=srcPos
          if looped and p>=decoded.sampleCount then local span=decoded.sampleCount-loopStart; if span>0 then p=loopStart+((p-loopStart)%span) end end
          if (not looped) and p>=decoded.sampleCount then break end
          -- Tone type bit 3 is TONEDATA_TYPE_FIX / DirectSound no-resample.
          -- FireRed's mixer bypasses fractional interpolation for these voices.
          local v=sampleMp2k(decoded.samples,p,band(tone.type or 0,0x08) ~= 0)
          local envGain=n.env(j)
          pcmLeft[di]=pcmLeft[di]+v*envGain*dsLg
          pcmRight[di]=pcmRight[di]+v*envGain*dsRg
          srcPos=srcPos+ratio
        end
      end
    elseif n.baseType >= 1 and n.baseType <= 4 and tone.cgb then
      local key,fine=noteFine(e)
      local reg=tables.cgbRegister(n.baseType,key,fine)
      reg=cgbFixedRegister(tone,n.baseType,reg)
      local hz=cgbHzFromRegister(n.baseType,reg)
      local phase=n.cgbStartPhase or 0
      local sweep=(n.baseType==1) and newSquareSweep(tone.panSweep or 0,reg) or nil
      local wave = n.baseType==3 and wave32Samples(tone.cgb.waveBytes) or nil
      local lfsr=0x7FFF
      local noisePhase=0
      local width7=band((tone.cgb.noiseParam or 0), 0x08) ~= 0
      local cgbLg=n.cgbLg or n.lg or 1
      local cgbRg=n.cgbRg or n.rg or 1
      if n.baseType==1 or n.baseType==2 then counts.square=counts.square+1 elseif n.baseType==3 then counts.wave=counts.wave+1 else counts.noise=counts.noise+1 end
      for j=0,totalFrames-1 do
        local di=start+j+1; if di>frames then break end
        local envGain,nrx2Write=n.env(j)

        -- A CgbSound volume update writes NRx2 and sets NRx4's trigger bit.
        -- That does NOT restart square duty phase, but it does re-arm Square
        -- 1's sweep unit and reset the noise LFSR. Keep those hardware side
        -- effects coupled to the envelope write instead of treating NRx2 as
        -- a simple gain curve.
        if nrx2Write then
          if n.baseType==1 and sweep and sweep.retrigger then sweep.retrigger() end
          if n.baseType==4 then lfsr = width7 and 0x7F or 0x7FFF end
        end

        local v=0
        if n.baseType==1 or n.baseType==2 then
          if sweep then
            sweep.clock(rate)
            if sweep.muted then v=0 else hz=cgbHzFromRegister(n.baseType,sweep.reg); v=squareSample(phase,tone.cgb.duty) end
          else
            v=squareSample(phase,tone.cgb.duty)
          end
          phase=phase+hz/rate
        elseif n.baseType==3 and wave and #wave>0 then
          local idx=(math.floor(phase*32)%#wave)+1; v=wave[idx]; phase=phase+hz/rate
        elseif n.baseType==4 then
          v,lfsr,noisePhase=noiseSampleAveraged(lfsr,noisePhase,hz/rate,width7)
        end
        -- Track volume/velocity already determined envelopeGoal through
        -- cgbChannelMix. Multiplying them again here was a global PSG gain bug.
        local g=envGain*CGB_OUTPUT_SCALE
        cgbLeft[di]=cgbLeft[di]+v*g*cgbLg; cgbRight[di]=cgbRight[di]+v*g*cgbRg
      end
    else counts.unsupported=counts.unsupported+1 end
  end

  local reverbAmount = effectiveSongReverb(plan, opts)
  applyMp2kReverb(pcmLeft, pcmRight, rate, reverbAmount)

  local left,right = {},{}
  local peak=0
  for i=1,frames do
    left[i]=pcmLeft[i]+cgbLeft[i]; right[i]=pcmRight[i]+cgbRight[i]
    peak=math.max(peak,math.abs(left[i]),math.abs(right[i]))
  end
  -- FireRed's mixer does not peak-normalize each SFX.  Per-sound normalization
  -- changes the transient/envelope and makes short effects audibly unlike the GBA.
  -- Clamp only at the final PCM boundary; an explicit normalize=true remains
  -- available for diagnostics, but native battle rendering leaves it off.
  local norm=(opts.normalize==true and peak>1) and 1/peak or 1
  for i=1,frames do left[i]=clamp(left[i]*norm,-1,1); right[i]=clamp(right[i]*norm,-1,1) end
  return {sampleRate=rate,frames=frames,seconds=frames/rate,left=left,right=right,noteCount=#notes,voiceCounts=counts,peak=peak,reverbAmount=reverbAmount,
    fidelity={directSoundPcm='exact ROM bytes; stock 23-bit integer interpolation/no-resample path',eventTiming='MP2k tick/tempo plan with EOT/TIE and FINE hard-stop semantics',pitch='FireRed MP2k lookup/interpolation',
      directSoundEnvelope='SoundMain-style byte-domain attack/add and decay-release multiply model at video-frame cadence',directSoundVolume='FireRed track pan/volume + velocity + master-volume scaling before channel summing',
      cgbVoices='hardware duty patterns, free-running Square 1/2 retrigger phase, FIX quantization, Square 1 NR10 sweep/retrigger, wave/noise from FireRed ToneData and CGB register math',
      cgbEnvelope='CgbSound VBlank software envelope + free-running 64 Hz NRx2 hardware envelope/retrigger model with ChnVolSet/CgbModVol gain staging and GBA PSG/PCM output ratio',cgbNoise='LFSR transitions box-averaged inside each renderer frame to avoid point-sampling alias',keySplitRhythm='recursively resolved from ROM voicegroup/split tables',
      reverb='stock MP2k four-tap mono PCM feedback over the 1584-sample DMA ring; CGB voices bypass PCM feedback'}}
end

-- Compatibility name retained for callers from v0.8/v0.9.
function M.renderDirectSoundSong(runtime,tables,plan,deps,opts)
  return M.renderSong(runtime,tables,plan,deps,opts)
end

return M
