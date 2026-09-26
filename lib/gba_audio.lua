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

local function bor(a, b)
  a, b = math.floor(a or 0), math.floor(b or 0)
  local out, bit = 0, 1
  while a > 0 or b > 0 do
    local aa, bb = a % 2, b % 2
    if aa == 1 or bb == 1 then out = out + bit end
    a, b, bit = math.floor(a / 2), math.floor(b / 2), bit * 2
  end
  return out
end

local function lshift(a, n)
  return (math.floor(a or 0) * (2 ^ n)) % 4294967296
end


-- Pokemon FireRed (US v1.0) sound IDs from pret/pokefirered/include/constants/songs.h.
-- NOTE: FireRed's IDs differ from Emerald's; v0.3 accidentally used Emerald IDs.
M.sfx = {
  SE_M_FLAME_WHEEL = 137,
  SE_M_FLAME_WHEEL2 = 138,
  SE_M_FLAMETHROWER = 139,
  SE_M_EMBER = 144,
  SE_M_TAKE_DOWN = 145,
}

function M.emberRequirements()
  return {
    { id = M.sfx.SE_M_EMBER, name = "SE_M_EMBER", usage = "loopsewithpan", pan = "attacker", interval = 5, count = 2 },
    { id = M.sfx.SE_M_FLAME_WHEEL, name = "SE_M_FLAME_WHEEL", usage = "playsewithpan", pan = "target" },
  }
end

local function romPtrToOffset(rom, p)
  if p < 0x08000000 or p >= 0x08000000 + rom:size() then return nil end
  return p - 0x08000000
end

-- struct Song { struct SongHeader *header; u16 ms; u16 me; } = 8 bytes.
function M.parseSongTableEntry(rom, tableOffset, songId)
  local off = tableOffset + songId * 8
  if off < 0 or off + 8 > rom:size() then error("song table entry outside ROM", 2) end
  local headerPtr = rom:u32(off)
  local headerOffset = romPtrToOffset(rom, headerPtr)
  if not headerOffset then error("song entry has invalid header pointer", 2) end
  return {
    id = songId,
    entryOffset = off,
    headerPointer = headerPtr,
    headerOffset = headerOffset,
    ms = rom:u16(off + 4),
    me = rom:u16(off + 6),
  }
end

function M.parseSongHeader(rom, offset)
  if offset < 0 or offset + 12 > rom:size() then error("song header outside ROM", 2) end
  local trackCount = rom:u8(offset)
  local blockCount = rom:u8(offset + 1)
  local priority = rom:u8(offset + 2)
  local reverb = rom:u8(offset + 3)
  if trackCount < 1 or trackCount > 16 then error("invalid M4A track count", 2) end
  local voicegroupPtr = rom:u32(offset + 4)
  local voicegroup = romPtrToOffset(rom, voicegroupPtr)
  if not voicegroup then error("invalid M4A voicegroup pointer", 2) end
  if offset + 8 + trackCount * 4 > rom:size() then error("truncated M4A song header", 2) end
  local tracks = {}
  for i = 0, trackCount - 1 do
    local p = rom:u32(offset + 8 + i * 4)
    local to = romPtrToOffset(rom, p)
    if not to then error("invalid M4A track pointer", 2) end
    tracks[#tracks + 1] = { pointer = p, offset = to }
  end
  return {
    offset = offset,
    trackCount = trackCount,
    blockCount = blockCount,
    priority = priority,
    reverb = reverb,
    voicegroupPointer = voicegroupPtr,
    voicegroupOffset = voicegroup,
    tracks = tracks,
  }
end

local function validEntryAt(rom, base, id)
  local ok, entry = pcall(M.parseSongTableEntry, rom, base, id)
  if not ok then return false end
  if entry.ms > 3 or entry.me > 0x20 then return false end
  local hok = pcall(M.parseSongHeader, rom, entry.headerOffset)
  return hok
end

-- Pokemon FireRed (USA v1.0 / revision 0) gSongTable ROM offset.
-- The manifest and FireRed.validate already pin this mod to the exact clean ROM,
-- so using the known table offset is both simpler and safer than heuristic scans.
M.SONG_TABLE_OFFSET = 0x4A32CC

function M.findSongTable(rom)
  local base = M.SONG_TABLE_OFFSET
  local probeIds = {
    M.sfx.SE_M_FLAME_WHEEL,
    M.sfx.SE_M_FLAME_WHEEL2,
    M.sfx.SE_M_FLAMETHROWER,
    M.sfx.SE_M_EMBER,
    M.sfx.SE_M_TAKE_DOWN,
  }
  for _, id in ipairs(probeIds) do
    if not validEntryAt(rom, base, id) then
      error("FireRed gSongTable validation failed at known ROM offset", 2)
    end
  end
  return base
end

function M.extractSong(rom, tableOffset, songId, trackWindow)
  trackWindow = trackWindow or 0x400
  local entry = M.parseSongTableEntry(rom, tableOffset, songId)
  local header = M.parseSongHeader(rom, entry.headerOffset)
  local tracks = {}
  for i, t in ipairs(header.tracks) do
    local n = math.min(trackWindow, rom:size() - t.offset)
    tracks[i] = {
      pointer = t.pointer,
      offset = t.offset,
      -- Exact ROM bytes, intentionally a bounded diagnostic window for now.
      -- Full control-flow-aware M4A track extraction is the next layer.
      bytes = rom:bytes(t.offset, n),
    }
  end
  return { entry = entry, header = header, tracks = tracks }
end

function M.extractEmberSongs(rom)
  local table = M.findSongTable(rom)
  return {
    songTableOffset = table,
    ember = M.extractSong(rom, table, M.sfx.SE_M_EMBER),
    flameWheel = M.extractSong(rom, table, M.sfx.SE_M_FLAME_WHEEL),
  }
end


-- M4A/Sappy event opcodes used by the GBA driver. 0x80..0xB0 are wait
-- commands; 0xCF..0xFF are note-length/running-status commands.
M.cmd = {
  FINE=0xB1, GOTO=0xB2, PATT=0xB3, PEND=0xB4, REPT=0xB5,
  MEMACC=0xB9, PRIO=0xBA, TEMPO=0xBB, KEYSH=0xBC, VOICE=0xBD,
  VOL=0xBE, PAN=0xBF, BEND=0xC0, BENDR=0xC1, LFOS=0xC2,
  LFODL=0xC3, MOD=0xC4, MODT=0xC5, TUNE=0xC8, EOT=0xCE, TIE=0xCF,
}

local function ptrAt(rom, off)
  return romPtrToOffset(rom, rom:u32(off))
end

-- Conservative control-flow-aware track walker. Its purpose is dependency
-- extraction, not synthesis: it identifies VOICE selections and follows the
-- explicit GOTO/PATT pointers while preserving the exact source bytes.
function M.walkTrack(rom, startOffset, maxBytes)
  maxBytes = maxBytes or 0x1000
  local q, seenBlocks, blocks, voices = {startOffset}, {}, {}, {}
  local voiceSet = {}
  while #q > 0 do
    local block = table.remove(q, 1)
    if not seenBlocks[block] then
      seenBlocks[block] = true
      local pc, stop = block, math.min(rom:size(), block + maxBytes)
      local bytesStart = pc
      while pc < stop do
        local op = rom:u8(pc)
        if op == M.cmd.FINE or op == M.cmd.PEND then
          pc = pc + 1
          break
        elseif op == M.cmd.GOTO or op == M.cmd.PATT then
          if pc + 5 > rom:size() then error('truncated M4A branch', 2) end
          local target = ptrAt(rom, pc + 1)
          if not target then error('invalid M4A branch pointer', 2) end
          q[#q+1] = target
          pc = pc + 5
          if op == M.cmd.GOTO then break end
        elseif op == M.cmd.REPT then
          if pc + 6 > rom:size() then error('truncated M4A repeat', 2) end
          local target = ptrAt(rom, pc + 2)
          if target then q[#q+1] = target end
          pc = pc + 6
        elseif op == M.cmd.MEMACC then
          pc = pc + 4
        elseif op == M.cmd.PRIO or op == M.cmd.TEMPO or op == M.cmd.KEYSH
            or op == M.cmd.VOICE or op == M.cmd.VOL or op == M.cmd.PAN
            or op == M.cmd.BEND or op == M.cmd.BENDR or op == M.cmd.LFOS
            or op == M.cmd.LFODL or op == M.cmd.MOD or op == M.cmd.MODT
            or op == M.cmd.TUNE then
          if op == M.cmd.VOICE then
            local v = rom:u8(pc + 1)
            if not voiceSet[v] then voiceSet[v] = true; voices[#voices+1] = v end
          end
          pc = pc + 2
        elseif op == M.cmd.EOT then
          -- EOT may optionally include a key byte (<0x80); consume it if present.
          pc = pc + 1
          if pc < stop and rom:u8(pc) < 0x80 then pc = pc + 1 end
        elseif op == M.cmd.TIE then
          -- TIE uses key + optional velocity. We only need to stay synchronized.
          pc = pc + 1
          if pc < stop and rom:u8(pc) < 0x80 then pc = pc + 1 end
          if pc < stop and rom:u8(pc) < 0x80 then pc = pc + 1 end
        elseif op >= 0x80 and op <= 0xB0 then
          pc = pc + 1 -- wait command
        elseif op >= 0xD0 then
          -- Note command. Running-status form allows omitted key/velocity; consume
          -- up to two literal data bytes, stopping at the next command byte.
          pc = pc + 1
          if pc < stop and rom:u8(pc) < 0x80 then pc = pc + 1 end
          if pc < stop and rom:u8(pc) < 0x80 then pc = pc + 1 end
        elseif op < 0x80 then
          -- Data byte belonging to running status. The driver's previous command
          -- determines semantics; dependency discovery can safely advance one.
          pc = pc + 1
        else
          -- Unsupported control command: keep exact bytes available but stop the
          -- semantic walk rather than guessing its argument width.
          pc = pc + 1
        end
      end
      blocks[#blocks+1] = { offset=block, endOffset=pc, bytes=rom:bytes(bytesStart, pc-bytesStart) }
    end
  end
  table.sort(voices)
  return { startOffset=startOffset, blocks=blocks, voices=voices }
end

-- ToneData is 12 bytes in the GBA M4A driver.
function M.parseTone(rom, voicegroupOffset, voiceId)
  local off = voicegroupOffset + voiceId * 12
  if off < 0 or off + 12 > rom:size() then error('ToneData outside ROM', 2) end
  local t = {
    id=voiceId, offset=off,
    type=rom:u8(off), key=rom:u8(off+1), length=rom:u8(off+2), panSweep=rom:u8(off+3),
    dataPointer=rom:u32(off+4), attack=rom:u8(off+8), decay=rom:u8(off+9), sustain=rom:u8(off+10), release=rom:u8(off+11),
  }
  t.dataOffset = romPtrToOffset(rom, t.dataPointer)
  return t
end

function M.parseWaveData(rom, offset)
  if not offset or offset < 0 or offset + 16 > rom:size() then return nil end
  local size = rom:u32(offset + 12)
  if size > rom:size() or offset + 16 + size > rom:size() then return nil end
  return {
    offset=offset, type=rom:u16(offset), status=rom:u16(offset+2), freq=rom:u32(offset+4),
    loopStart=rom:u32(offset+8), size=size, samples=rom:bytes(offset+16, size),
  }
end


local function decorateTone(rom, tone)
  local baseType = tone.type % 8
  local isSplit = band(tone.type, 0x40) ~= 0
  local isRhythm = band(tone.type, 0x80) ~= 0
  if isSplit or isRhythm then
    tone.childVoicegroupOffset = tone.dataOffset
    tone.splitTablePointer = isSplit and bor(bor(tone.attack, lshift(tone.decay, 8)), bor(lshift(tone.sustain, 16), lshift(tone.release, 24))) or 0
    tone.splitTableOffset = isSplit and romPtrToOffset(rom, tone.splitTablePointer) or nil
    tone.children = {}
    tone.splitMap = {}
    if isSplit and tone.splitTableOffset and tone.splitTableOffset + 128 <= rom:size() then
      local ids = {}
      for key=0,127 do
        local id = rom:u8(tone.splitTableOffset + key)
        tone.splitMap[key] = id
        ids[id] = true
      end
      for id in pairs(ids) do
        local child = M.parseTone(rom, tone.childVoicegroupOffset, id)
        tone.children[id] = decorateTone(rom, child)
      end
    elseif isRhythm and tone.childVoicegroupOffset then
      -- voice_keysplit_all uses the MIDI key directly as the child ToneData index.
      for key=0,127 do
        local ok, child = pcall(M.parseTone, rom, tone.childVoicegroupOffset, key)
        if ok then tone.children[key] = decorateTone(rom, child) end
      end
    end
    return tone
  end
  if baseType == 0 and tone.dataOffset then
    tone.wave = M.parseWaveData(rom, tone.dataOffset)
  elseif baseType == 1 or baseType == 2 then
    tone.cgb = { channel=baseType, duty=(tone.dataPointer % 4) }
  elseif baseType == 3 then
    if tone.dataOffset and tone.dataOffset + 16 <= rom:size() then
      tone.cgb = { channel=3, waveBytes=rom:bytes(tone.dataOffset, 16), waveOffset=tone.dataOffset }
    end
  elseif baseType == 4 then
    tone.cgb = { channel=4, noiseParam=(tone.dataPointer % 256) }
  end
  return tone
end

function M.resolveSongDependencies(rom, song)
  local tracks, voiceSet = {}, {}
  for i,t in ipairs(song.header.tracks) do
    local w = M.walkTrack(rom, t.offset)
    tracks[i] = w
    for _,v in ipairs(w.voices) do voiceSet[v] = true end
  end
  local voices, samples = {}, {}
  local sampleOffsets = {}
  local function collectSamples(t)
    if t.wave and not sampleOffsets[t.wave.offset] then
      sampleOffsets[t.wave.offset]=true; samples[#samples+1]=t.wave
    end
    for _,c in pairs(t.children or {}) do collectSamples(c) end
  end
  for v in pairs(voiceSet) do
    local tone = decorateTone(rom, M.parseTone(rom, song.header.voicegroupOffset, v))
    collectSamples(tone)
    voices[#voices+1] = tone
  end
  table.sort(voices, function(a,b) return a.id < b.id end)
  return { tracks=tracks, voices=voices, samples=samples, reverb=song.header.reverb }
end

function M.extractEmberDependencyGraph(rom)
  local a = M.extractEmberSongs(rom)
  return {
    songTableOffset=a.songTableOffset,
    ember={ song=a.ember, dependencies=M.resolveSongDependencies(rom, a.ember) },
    flameWheel={ song=a.flameWheel, dependencies=M.resolveSongDependencies(rom, a.flameWheel) },
  }
end

return M
