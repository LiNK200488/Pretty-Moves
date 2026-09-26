local M = {}

-- FireRed uses the standard MP2k/M4A wait/note duration table (24 TPQN).
local DURATIONS = {
  0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,
  28,30,32,36,40,42,44,48,52,54,56,60,64,66,68,72,76,78,80,84,88,90,92,96,
}
M.DURATIONS = DURATIONS
M.TICKS_PER_QUARTER = 24
M.GBA_MIX_RATE = 13379 -- FireRed m4aSoundMode(SOUND_MODE_FREQ_13379)

-- Standard MP2k command bytes used by FireRed.
M.cmd = {
  FINE=0xB1, GOTO=0xB2, PATT=0xB3, PEND=0xB4, REPT=0xB5,
  MEMACC=0xB9, PRIO=0xBA, TEMPO=0xBB, KEYSH=0xBC, VOICE=0xBD,
  VOL=0xBE, PAN=0xBF, BEND=0xC0, BENDR=0xC1, LFOS=0xC2,
  LFODL=0xC3, MOD=0xC4, MODT=0xC5, TUNE=0xC8,
  EOT=0xCE, TIE=0xCF,
}

local function durationFromCommand(op, base)
  local i = op - base + 1
  return DURATIONS[i]
end

local function ptrToOffset(rom, off)
  local p = rom:u32(off)
  if p < 0x08000000 or p >= 0x08000000 + rom:size() then return nil end
  return p - 0x08000000
end

local function signed7Centered(v)
  return math.max(-64, math.min(63, v - 0x40))
end

local function signed8(v)
  if v >= 128 then return v - 256 end
  return v
end

-- TEMPO stores half-BPM. One M4A tick is 1/24 of a quarter note.
function M.secondsPerTick(tempoByte)
  local bpm = math.max(1, (tempoByte or 75) * 2)
  return 60 / (bpm * M.TICKS_PER_QUARTER)
end

-- Converts one M4A track into a deterministic tick-domain event plan.
function M.planTrack(rom, startOffset, opts)
  opts = opts or {}
  local maxSteps = opts.maxSteps or 20000
  local maxTicks = opts.maxTicks or 60 * 60 * 120
  local pc, tick, steps = startOffset, 0, 0
  local callStack, repeatState = {}, {}
  local running = {
    voice=0, vol=127, pan=0, bend=0, bendRange=2, keysh=0, tune=0,
    tempo=75, lastNoteOp=nil, lastKey=60, lastVelocity=127,
  }
  local events = {}

  local function emit(kind, data, at)
    data = data or {}
    data.kind, data.tick, data.offset = kind, tick, at or pc
    events[#events+1] = data
  end

  while pc < rom:size() and steps < maxSteps and tick <= maxTicks do
    steps = steps + 1
    local opOff = pc
    local op = rom:u8(pc)

    if op >= 0x80 and op <= 0xB0 then
      local d = durationFromCommand(op, 0x80)
      if d == nil then break end
      tick = tick + d
      pc = pc + 1

    elseif op == M.cmd.FINE then
      emit('fine', nil, opOff); pc = pc + 1; break

    elseif op == M.cmd.GOTO then
      local target = ptrToOffset(rom, pc + 1)
      if not target then error('invalid M4A GOTO pointer', 2) end
      emit('goto', {target=target}, opOff); pc = target

    elseif op == M.cmd.PATT then
      local target = ptrToOffset(rom, pc + 1)
      if not target then error('invalid M4A PATT pointer', 2) end
      callStack[#callStack+1] = pc + 5
      emit('pattern_call', {target=target}, opOff); pc = target

    elseif op == M.cmd.PEND then
      local ret = table.remove(callStack)
      emit('pattern_end', nil, opOff); pc = ret or (pc + 1)

    elseif op == M.cmd.REPT then
      local count = rom:u8(pc + 1)
      local target = ptrToOffset(rom, pc + 2)
      if not target then error('invalid M4A REPT pointer', 2) end
      local key = pc
      local n = repeatState[key] or 0
      if count == 0 or n < count then
        repeatState[key] = n + 1
        emit('repeat', {count=count, iteration=n+1, target=target}, opOff)
        pc = target
      else
        repeatState[key] = nil
        pc = pc + 6
      end

    elseif op == M.cmd.MEMACC then
      -- MEMACC is 4 bytes total in the standard driver. Preserve it as an
      -- uninterpreted event; FireRed move SFX normally do not depend on it.
      emit('memacc', {op=rom:u8(pc+1), a=rom:u8(pc+2), b=rom:u8(pc+3)}, opOff)
      pc = pc + 4
    elseif op == M.cmd.PRIO then
      emit('priority', {value=rom:u8(pc+1)}, opOff); pc=pc+2
    elseif op == M.cmd.TEMPO then
      running.tempo=rom:u8(pc+1); emit('tempo', {value=running.tempo, bpm=running.tempo*2}, opOff); pc=pc+2
    elseif op == M.cmd.KEYSH then
      local v=signed8(rom:u8(pc+1)); running.keysh=v; emit('key_shift', {value=v}, opOff); pc=pc+2
    elseif op == M.cmd.VOICE then
      running.voice=rom:u8(pc+1); emit('voice', {voice=running.voice}, opOff); pc=pc+2
    elseif op == M.cmd.VOL then
      running.vol=rom:u8(pc+1); emit('volume', {value=running.vol}, opOff); pc=pc+2
    elseif op == M.cmd.PAN then
      running.pan=signed7Centered(rom:u8(pc+1)); emit('pan', {value=running.pan}, opOff); pc=pc+2
    elseif op == M.cmd.BEND then
      running.bend=signed7Centered(rom:u8(pc+1)); emit('bend', {value=running.bend}, opOff); pc=pc+2
    elseif op == M.cmd.BENDR then
      running.bendRange=rom:u8(pc+1); emit('bend_range', {value=running.bendRange}, opOff); pc=pc+2
    elseif op == M.cmd.LFOS or op == M.cmd.LFODL or op == M.cmd.MOD or op == M.cmd.MODT then
      emit('controller', {opcode=op, value=rom:u8(pc+1)}, opOff); pc=pc+2
    elseif op == M.cmd.TUNE then
      running.tune=signed7Centered(rom:u8(pc+1)); emit('tune', {value=running.tune}, opOff); pc=pc+2
    elseif op == M.cmd.EOT then
      pc = pc + 1
      local key = nil
      if pc < rom:size() and rom:u8(pc) < 0x80 then key=rom:u8(pc); pc=pc+1 end
      emit('note_off', {key=key}, opOff)

    elseif op == M.cmd.TIE then
      pc = pc + 1
      local key = running.lastKey
      local vel = running.lastVelocity
      if pc < rom:size() and rom:u8(pc) < 0x80 then key=rom:u8(pc); running.lastKey=key; pc=pc+1 end
      if pc < rom:size() and rom:u8(pc) < 0x80 then vel=rom:u8(pc); running.lastVelocity=vel; pc=pc+1 end
      running.lastNoteOp=op
      emit('note_on', {
        key=key + running.keysh, velocity=vel, voice=running.voice,
        volume=running.vol, pan=running.pan, bend=running.bend,
        bendRange=running.bendRange, tune=running.tune, tied=true,
      }, opOff)

    elseif op >= 0xD0 then
      local dur = durationFromCommand(op, 0xCF)
      if dur == nil then
        emit('unknown', {opcode=op}, opOff); pc=pc+1
      else
        pc = pc + 1
        local key = running.lastKey
        local vel = running.lastVelocity
        if pc < rom:size() and rom:u8(pc) < 0x80 then key=rom:u8(pc); running.lastKey=key; pc=pc+1 end
        if pc < rom:size() and rom:u8(pc) < 0x80 then vel=rom:u8(pc); running.lastVelocity=vel; pc=pc+1 end
        -- Optional gate-time byte (1..3) follows velocity in MP2k note events.
        local gate = 0
        if pc < rom:size() and rom:u8(pc) < 0x80 and rom:u8(pc) <= 3 then gate=rom:u8(pc); pc=pc+1 end
        running.lastNoteOp=op
        emit('note', {
          duration=dur + gate, baseDuration=dur, gate=gate,
          key=key + running.keysh, velocity=vel, voice=running.voice,
          volume=running.vol, pan=running.pan, bend=running.bend,
          bendRange=running.bendRange, tune=running.tune,
        }, opOff)
      end

    elseif op < 0x80 and running.lastNoteOp then
      local key, vel = op, running.lastVelocity
      pc = pc + 1
      if pc < rom:size() and rom:u8(pc) < 0x80 then vel=rom:u8(pc); running.lastVelocity=vel; pc=pc+1 end
      running.lastKey=key
      local dur = durationFromCommand(running.lastNoteOp, 0xCF) or 0
      emit('note', {
        duration=dur, key=key + running.keysh, velocity=vel,
        voice=running.voice, volume=running.vol, pan=running.pan,
        bend=running.bend, bendRange=running.bendRange, tune=running.tune,
        running=true,
      }, opOff)

    else
      emit('unknown', {opcode=op}, opOff); pc = pc + 1
    end
  end

  return {
    startOffset=startOffset, endOffset=pc, ticks=tick, steps=steps,
    truncated=(steps>=maxSteps or tick>maxTicks), events=events,
  }
end

function M.planSong(rom, song)
  local tracks = {}
  for i,t in ipairs(song.header.tracks) do tracks[i] = M.planTrack(rom, t.offset) end
  return {id=song.entry.id, priority=song.header.priority, reverb=song.header.reverb, tracks=tracks}
end

-- Exact source-byte normalization only. WaveData.freq is NOT a PCM sample rate;
-- it is the pitch reference consumed by MidiKeyToFreq. FireRed's DirectSound
-- mixer itself runs at GBA_MIX_RATE in this title/configuration.
function M.decodeDirectSoundWave(wave)
  if not wave or not wave.samples then return nil end
  local out = {}
  for i=1,#wave.samples do
    local v = wave.samples:byte(i)
    if v >= 128 then v = v - 256 end
    out[i] = v / 128
  end
  return {
    sourceOffset=wave.offset, frequencyReference=wave.freq,
    mixerRate=M.GBA_MIX_RATE, loopStart=wave.loopStart,
    sampleCount=wave.size, looped=(wave.loopStart < wave.size), samples=out,
  }
end

function M.stereoGains(pan)
  pan = math.max(-64, math.min(63, pan or 0))
  if pan < 0 then return 1.0, (pan + 64) / 64 end
  return (63 - pan) / 63, 1.0
end

return M
