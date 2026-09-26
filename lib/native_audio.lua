-- Shared FireRed SFX adapter: ROM renderer -> persistent verified WAV cache -> Gen1Recomp SFX.
-- Move SFX and generic battle-SFX overrides share the same proven file-backed
-- transport, but their registrations remain separate and declarative.
local M = {}

function M.new(opts)
  opts=opts or {}
  local mod=assert(opts.mod); local Runtime=assert(opts.M4ARuntime); local Wav=assert(opts.WavPcm)
  local renderSong=assert(opts.renderSong); local catalog=assert(opts.catalog); local soundIds=assert(opts.soundIds)
  local battleSfx=opts.battleSfx or {overrides={}}
  local extraSoundIds=opts.extraSoundIds or {}
  do
    local seen={}
    local merged={}
    for _,list in ipairs({soundIds,extraSoundIds}) do
      for _,id in ipairs(list) do
        id=tonumber(id)
        if id and not seen[id] then seen[id]=true; merged[#merged+1]=id end
      end
    end
    table.sort(merged)
    soundIds=merged
  end

  local Sound=require("src.core.Sound")

  -- CACHE_VERSION is intentionally independent of the mod release number.
  -- Bump it only when the generated PCM/WAV bytes can change (synth, mixer,
  -- encoder, panning law, ROM target, etc.). That lets future move-only builds
  -- reuse the same persistent files without another expensive boot-time render.
  local CACHE_VERSION="firered_us_v10_m4a_v234_audio_v15_petal_dance"
  local DIZZY_CACHE_VERSION="dizzy169_v4_dynamic_cc"
  local CONFUSE_RAY_SOUND_CACHE_VERSION={
    [189]="confuseray_189_v2_reimplemented",
    [123]="confuseray_123_v2_reimplemented",
  }
  local relDir="generated/firered_sfx_cache_v1"
  local engineDir="mod_compat/"..mod.id.."/_own/"..relDir
  local ownDir=mod.path.."/"..relDir
  local markerPath=ownDir.."/.complete"

  local info={
    rendered=0,written=0,registered=0,overridden=0,plays=0,started=0,
    precacheRuns=0,precached=0,failures=0,lastError=nil,
    cacheVersion=CACHE_VERSION,cacheHit=false,cacheMiss=false,cachedFiles=0,
  }
  local entries, allKeys = {}, {}

  local function fail(msg) info.failures=info.failures+1; info.lastError=tostring(msg); return nil,info.lastError end
  local function render(source)
    -- Cache generation can involve dozens of multi-second PCM buffers. Keeping
    -- every rendered song alive until the mod closure is collected creates a
    -- large transient Lua heap on mobile and can starve the host audio thread
    -- during the intro / first menu. Each song is encoded immediately, so keep
    -- only the current PCM alive and let it be reclaimed before the next one.
    local ok,result=pcall(renderSong,source); if not ok then return fail(result) end
    info.rendered=info.rendered+1; return result
  end
  local function safeName(s) return (s:gsub("[^%w_]+","_")):lower() end
  local function ownPath(file) return ownDir.."/"..file end
  local function enginePath(file) return engineDir.."/"..file end

  -- Build the complete file manifest before doing any synthesis. A cache is
  -- considered valid only if the version marker and every expected WAV exist.
  local expectedFiles={}
  local expectedSeen={}
  local function expect(file)
    if not expectedSeen[file] then
      expectedSeen[file]=true
      expectedFiles[#expectedFiles+1]=file
    end
  end
  for _,id in ipairs(soundIds) do
    local def=catalog:get(id)
    if not def then error("No FireRed SFX catalog entry for "..tostring(id),0) end
    if tonumber(id)==169 then
      expect(safeName(def.name).."_l_dizzy_v4.wav")
      expect(safeName(def.name).."_r_dizzy_v4.wav")
    else
      expect(safeName(def.name).."_l.wav")
      expect(safeName(def.name).."_r.wav")
    end
  end
  for engineKey,spec in pairs(battleSfx.overrides or {}) do
    local id=assert(spec.soundId,"battle SFX override missing soundId")
    local def=catalog:get(id)
    if not def then error("No FireRed SFX catalog entry for battle override "..tostring(id),0) end
    expect("battle_"..safeName(engineKey).."_"..safeName(def.name)..".wav")
  end
  table.sort(expectedFiles)

  local function fileLooksUsable(file)
    local meta=love.filesystem.getInfo(ownPath(file),"file")
    return meta and tonumber(meta.size) and meta.size>44
  end
  local function cacheIsValid()
    local marker=love.filesystem.read(markerPath)
    if marker~=CACHE_VERSION then return false end
    for _,file in ipairs(expectedFiles) do
      if not fileLooksUsable(file) then return false end
    end
    return true
  end

  local markerMatches=(love.filesystem.read(markerPath)==CACHE_VERSION)
  local cacheHit=cacheIsValid()
  info.cacheHit=cacheHit
  info.cacheMiss=not cacheHit
  if cacheHit then info.cachedFiles=#expectedFiles end

  local function moveFilesUsable(id,def)
    if tonumber(id)==169 then
      return fileLooksUsable(safeName(def.name).."_l_dizzy_v4.wav")
         and fileLooksUsable(safeName(def.name).."_r_dizzy_v4.wav")
    end
    return fileLooksUsable(safeName(def.name).."_l.wav")
       and fileLooksUsable(safeName(def.name).."_r.wav")
  end

  local function ensureOwnDir()
    local ok,why=love.filesystem.createDirectory(ownDir)
    if ok==false then error("FireRed SFX cache directory failed: "..tostring(why),0) end
  end

  -- WAV encoding is transport-only; mixer level is resolved in m4a_synth.lua.
  --
  -- FireRed battle scripts commonly request the extreme positional pans
  -- SOUND_PAN_ATTACKER (-64) and SOUND_PAN_TARGET (+63). Feeding those
  -- values directly into our file-backed stereo encoder makes one channel
  -- effectively disappear. Keep FireRed's *internal* MP2k track panning
  -- untouched, but soften only this final battler-position stage. This is a
  -- shared rule for every move/status SFX, not a move-specific exception.
  -- Half-range preserves clear left/right placement while keeping both
  -- speakers audible.
  local function battleSpatialGains(pan)
    pan=math.max(-64,math.min(63,tonumber(pan) or 0))
    return Runtime.stereoGains(pan*0.5)
  end

  -- Gust-specific transport correction. FireRed SE_M_GUST (125) ends at
  -- exactly 72 MIDI ticks with a 24 PPQN division and 400000 us/qn tempo:
  -- 72 / 24 * 0.4 = 1.20 seconds. Our generic MP2k renderer may retain a
  -- synth/reverb tail beyond that sequence boundary, which is audible as an
  -- overlong wind effect in Gen1Recomp. Do not alter the shared renderer or
  -- playback layer: trim only Gust's rendered PCM before encoding its WAV.
  -- SE_M_DIZZY_PUNCH (169) is the canonical looping SFX used by FireRed's
  -- confusion-duck status animation. In the file-backed MP2k render its PCM
  -- comes out materially quieter than neighboring FireRed battle SFX. Apply a
  -- transport-level correction to that ROM-native sound itself so every use
  -- (status now, Dizzy Punch later) keeps the same relative FireRed loudness.
  -- This is applied before stereo panning/WAV encoding and does not alter the
  -- user's SFX-volume setting.
  local function correctQuietPcm(soundId,pcm)
    if tonumber(soundId)~=169 or type(pcm)~="table" then return pcm end
    local gain=1.0
    local left,right={},{}
    local frames=tonumber(pcm.frames) or math.max(#(pcm.left or {}),#(pcm.right or {}))
    for i=1,frames do
      local l=(pcm.left and pcm.left[i]) or 0
      local r=(pcm.right and pcm.right[i]) or 0
      left[i]=math.max(-1,math.min(1,l*gain))
      right[i]=math.max(-1,math.min(1,r*gain))
    end
    return {sampleRate=pcm.sampleRate,frames=frames,seconds=pcm.seconds,left=left,right=right}
  end

  -- FireRed SE_M_FLAMETHROWER (139) has a long low-volume tail after the
  -- main flame body. On the host file-backed transport that tail remains much
  -- more prominent than on GBA hardware. Preserve the native body, then apply
  -- a short transport fade so the sound dies with the visible flame stream.
  -- This is intentionally isolated to sound 139; no global timing/audio rule
  -- changes here.
  local function trimFlamethrowerPcm(soundId,pcm)
    if tonumber(soundId)~=139 or type(pcm)~="table" then return pcm end
    local rate=tonumber(pcm.sampleRate)
    local frames=tonumber(pcm.frames)
    if not rate or rate<=0 or not frames or frames<1 then return pcm end
    local fadeStart=math.max(1,math.floor(rate*2.50+0.5))
    local keep=math.min(frames,math.max(1,math.floor(rate*2.65+0.5)))
    if fadeStart>=frames then return pcm end
    local left,right={},{}
    for i=1,keep do left[i]=pcm.left[i] or 0; right[i]=pcm.right[i] or 0 end
    if keep>fadeStart then
      local span=keep-fadeStart
      for i=fadeStart,keep do
        local gain=(keep-i)/math.max(1,span)
        left[i]=left[i]*gain; right[i]=right[i]*gain
      end
    end
    return {sampleRate=rate,frames=keep,seconds=keep/rate,left=left,right=right}
  end

  local function trimGustPcm(soundId,pcm)
    if tonumber(soundId)~=125 or type(pcm)~="table" then return pcm end
    local rate=tonumber(pcm.sampleRate)
    local frames=tonumber(pcm.frames)
    if not rate or rate<=0 or not frames or frames<1 then return pcm end
    local keep=math.min(frames,math.max(1,math.floor(rate*1.20+0.5)))
    if keep>=frames then return pcm end
    local left,right={},{}
    for i=1,keep do left[i]=pcm.left[i] or 0; right[i]=pcm.right[i] or 0 end
    -- Tiny end fade prevents a click if the synthesized tail is non-zero at
    -- the exact sequence boundary. It does not extend the 1.20 s duration.
    local fade=math.min(keep,math.max(1,math.floor(rate*0.010+0.5)))
    for j=0,fade-1 do
      local i=keep-j
      local gain=j/(fade-1 > 0 and fade-1 or 1)
      left[i]=left[i]*gain; right[i]=right[i]*gain
    end
    return {sampleRate=rate,frames=keep,seconds=keep/rate,left=left,right=right}
  end

  local function writeWav(file,pcm,pan)
    local lg,rg=battleSpatialGains(pan or 0)
    local wav,meta=Wav.encodeStereo16(pcm,{sampleRate=44100,leftGain=lg,rightGain=rg})
    if not wav then error("FireRed SFX encode failed: "..tostring(meta),0) end
    local path=ownPath(file)
    local ok,why=love.filesystem.write(path,wav); if not ok then error("FireRed SFX write failed: "..tostring(why),0) end
    local check,readErr=love.filesystem.read(path)
    if type(check)~="string" or #check~=#wav or check:sub(1,12)~=wav:sub(1,12) then error("FireRed SFX verification failed: "..tostring(readErr),0) end
    info.written=info.written+1
    return enginePath(file)
  end

  -- Content registries freeze before the overworld starts. Register every
  -- FireRed SFX path now, but defer expensive ROM rendering/WAV generation
  -- until the first overworld entry. Sound sources are loaded lazily by the
  -- host, so the files only need to exist before gameplay can use them.
  local dizzyMarker="dizzy169_cache_version.txt"
  local dizzyMarkerPath=ownPath(dizzyMarker)
  local dizzyCached=false
  do
    local ok,v=pcall(love.filesystem.read,dizzyMarkerPath)
    dizzyCached=ok and v==DIZZY_CACHE_VERSION
  end

  -- Confuse Ray uses two native FireRed SFX (189 for the bouncing ray and 123
  -- for the spiral transition). Track those two generated WAVs independently
  -- from the global cache so they can be rebuilt without invalidating every
  -- move sound. This also replaces the older one-off "second sound" marker:
  -- each Confuse Ray sound now has its own revision and is verified separately.
  local confuseRaySoundCached={}
  local function confuseRayMarkerPath(id)
    return ownPath("confuseray_"..tostring(id).."_cache_version.txt")
  end
  for id,version in pairs(CONFUSE_RAY_SOUND_CACHE_VERSION) do
    local ok,v=pcall(love.filesystem.read,confuseRayMarkerPath(id))
    confuseRaySoundCached[id]=ok and v==version
  end

  local buildJobs={}
  for _,id in ipairs(soundIds) do
    local def=catalog:get(id)
    entries[id]={}
    local numericId=tonumber(id)
    local isDizzy=numericId==169
    local confuseRayRevision=CONFUSE_RAY_SOUND_CACHE_VERSION[numericId]
    -- A move-only release may add one new SFX while every older generated WAV
    -- is still valid for the same renderer revision. Keep the persistent cache
    -- additive: only rebuild this sound when the renderer revision changed, its
    -- own files are missing, or one of its dedicated per-sound revisions changed.
    local needsRender=(not markerMatches)
      or (not moveFilesUsable(id,def))
      or (isDizzy and not dizzyCached)
      or (confuseRayRevision and not confuseRaySoundCached[numericId])
    for _,side in ipairs({{suffix="L",pan=-64},{suffix="R",pan=63}}) do
      local key="FBA230_FR_"..tostring(id).."_"..side.suffix
      local base=safeName(def.name).."_"..side.suffix:lower()
      local file=isDizzy and (base.."_dizzy_v4.wav") or (base..".wav")
      mod.content.sfx:register(key,{file=enginePath(file)}); info.registered=info.registered+1
      if type(Sound.invalidate)=="function" then Sound.invalidate(key) end
      entries[id][side.suffix]=key
      allKeys[#allKeys+1]=key
    end
    if needsRender then
      buildJobs[#buildJobs+1]={
        kind="move",id=id,name=def.name,songId=def.songId,
        isDizzy=isDizzy,confuseRayRevision=confuseRayRevision
      }
    end
  end

  for engineKey,spec in pairs(battleSfx.overrides or {}) do
    local id=assert(spec.soundId,"battle SFX override missing soundId")
    local def=catalog:get(id)
    local file="battle_"..safeName(engineKey).."_"..safeName(def.name)..".wav"
    mod.content.sfx:override(engineKey,{file=enginePath(file)})
    info.overridden=info.overridden+1
    if type(Sound.invalidate)=="function" then Sound.invalidate(engineKey) end
    allKeys[#allKeys+1]=engineKey
    if (not markerMatches) or (not fileLooksUsable(file)) then
      buildJobs[#buildJobs+1]={kind="battle",engineKey=engineKey,spec=spec,id=id,name=def.name,songId=def.songId,file=file}
    end
  end
  table.sort(buildJobs,function(a,b)
    if a.kind~=b.kind then return a.kind<b.kind end
    return tostring(a.name or a.engineKey)<tostring(b.name or b.engineKey)
  end)

  local buildStarted=false
  local buildIndex=0
  local buildDone=(#buildJobs==0)

  local player={}
  local playLevels={}
  local overlapVoices={}
  local activeNormalSource=nil
  local HOST_SFX_BASE_VOLUME=0.8

  local function applyFireRedLevel(src,key,gain)
    local got,current=pcall(src.getVolume,src)
    if not (got and type(current)=="number") then return end

    -- Gen1Recomp deliberately gives every SFX Source a 0.8 headroom factor:
    -- volumeFor(key) = 0.8 * the user's SFX slider. FireRed's imported WAVs
    -- are already mixed as final battle SFX, so inheriting that factor makes
    -- the whole mod-owned FireRed bus 20% quieter than the user's requested
    -- SFX level. Remove only that fixed host headroom while preserving the
    -- user's slider. Track the host value separately so repeated plays never
    -- compound the compensation; if Gen1Recomp reapplies its slider, the
    -- changed Source volume becomes the new authoritative host baseline.
    local prev=playLevels[key]
    local host=current
    if prev and math.abs(current-prev.lastSet)<0.0001 then host=prev.host end
    local fireRedBase=math.max(0,math.min(1,host/HOST_SFX_BASE_VOLUME))
    local target=math.max(0,math.min(1,fireRedBase*(tonumber(gain) or 1)))
    pcall(src.setVolume,src,target)
    playLevels[key]={host=host,lastSet=target}
  end

  function player.needsBuild()
    return not buildDone
  end

  local function buildJobDetail(job)
    if not job then return "Audio cache ready" end
    if job.kind=="move" then
      -- Keep FireRed's canonical SE_M_* identifiers internally, but omit the
      -- technical prefix from the player-facing cache progress window.
      local name=tostring(job.name):gsub("^SE_M_","")
      return "Audio: "..name
    end
    return "Audio: "..tostring(job.engineKey)
  end

  function player.buildInfo()
    local job=buildJobs[math.min(#buildJobs,buildIndex+1)]
    return {done=buildDone,current=buildIndex,total=#buildJobs,detail=buildJobDetail(job)}
  end

  function player.buildPlan()
    local out={}
    for i,job in ipairs(buildJobs) do out[i]=buildJobDetail(job) end
    return out
  end

  function player.buildStep()
    if buildDone then return true end
    if not buildStarted then
      ensureOwnDir()
      if not markerMatches then love.filesystem.remove(markerPath) end
      buildStarted=true
    end

    local job=buildJobs[buildIndex+1]
    if not job then
      if not markerMatches or #buildJobs>0 then
        local ok,why=love.filesystem.write(markerPath,CACHE_VERSION)
        if not ok then return fail("FireRed SFX cache marker write failed: "..tostring(why)) end
      end
      buildDone=true
      info.cachedFiles=#expectedFiles
      info.cacheHit=true
      info.cacheMiss=false
      return true,true
    end

    if job.kind=="move" then
      local pcm,err=render(job.songId)
      if not pcm then return fail("FireRed SFX render failed: "..tostring(err)) end
      pcm=trimGustPcm(job.id,pcm)
      pcm=trimFlamethrowerPcm(job.id,pcm)
      pcm=correctQuietPcm(job.id,pcm)
      for _,side in ipairs({{suffix="L",pan=-64},{suffix="R",pan=63}}) do
        local base=safeName(job.name).."_"..side.suffix:lower()
        local file=job.isDizzy and (base.."_dizzy_v4.wav") or (base..".wav")
        writeWav(file,pcm,side.pan)
      end
      if job.isDizzy then
        local ok,why=love.filesystem.write(dizzyMarkerPath,DIZZY_CACHE_VERSION)
        if not ok then return fail("FireRed dizzy SFX cache marker write failed: "..tostring(why)) end
        dizzyCached=true
      end
      if job.confuseRayRevision then
        local id=tonumber(job.id)
        local ok,why=love.filesystem.write(confuseRayMarkerPath(id),job.confuseRayRevision)
        if not ok then return fail("FireRed Confuse Ray SFX cache marker write failed: "..tostring(why)) end
        confuseRaySoundCached[id]=true
      end
    else
      local pcm,err=render(job.songId)
      if not pcm then return fail("FireRed battle SFX render failed: "..tostring(err)) end
      writeWav(job.file,pcm,job.spec.pan or 0)
    end

    buildIndex=buildIndex+1
    if buildIndex>=#buildJobs then
      if not markerMatches or #buildJobs>0 then
        local ok,why=love.filesystem.write(markerPath,CACHE_VERSION)
        if not ok then return fail("FireRed SFX cache marker write failed: "..tostring(why)) end
      end
      buildDone=true
      info.cachedFiles=#expectedFiles
      info.cacheHit=true
      info.cacheMiss=false
    end
    collectgarbage("collect")
    return true,buildDone
  end

  function player.play(soundId,pan,battle,gain,overlap)
    info.plays=info.plays+1
    local e=entries[tonumber(soundId)]; if not e then return fail("unsupported FireRed SFX "..tostring(soundId)) end
    local key=(tonumber(pan) or 0)>=0 and e.R or e.L
    local data=battle and (battle.data or (battle.game and battle.game.data))
    if not (data and data.audio and data.audio.sfx and data.audio.sfx[key]) then return fail("registered SFX missing from merged battle data: "..tostring(key)) end
    -- FireRed battle animation SFX normally share the same SE playback lane.
    -- Starting a new non-overlap SE replaces the currently sounding one on
    -- that lane. This matters for looped transport SFX such as Blizzard: the
    -- impact sound is what terminates the wind loop in the stock engine.
    -- Explicit overlap events are exempt and keep using cloned Sources below.
    if not overlap and activeNormalSource then
      pcall(activeNormalSource.stop,activeNormalSource)
      activeNormalSource=nil
    end

    local ok,src=pcall(Sound.playStereo,data,key); if not ok then return fail(src) end
    if not src then return fail("Sound.playStereo returned no Source for "..key) end

    -- Compensate Gen1Recomp's fixed 0.8 SFX headroom on every mod-owned
    -- FireRed source, while retaining its user SFX slider as the baseline.
    -- Do this before cloning so overlap voices inherit the corrected level.
    applyFireRedLevel(src,key,gain)

    -- FireRed loopsewithpan can retrigger an animation SFX while the previous
    -- tail is still sounding. Gen1Recomp caches one Source per key and its
    -- playStereo path stops that Source before every play, which cuts those
    -- tails off. For explicitly overlapping FireRed events, use the cached
    -- Source only as the correctly decoded/volume-controlled template, stop
    -- that template immediately, and play a clone. Previous clones continue.
    -- This is deliberately opt-in; ordinary move/status SFX keep the host path.
    if overlap then
      pcall(src.stop,src)
      local cloned,voice=pcall(src.clone,src)
      if cloned and voice then
        local got,vol=pcall(src.getVolume,src)
        if got and type(vol)=="number" then pcall(voice.setVolume,voice,vol) end
        local pool=overlapVoices[key] or {}
        overlapVoices[key]=pool
        for i=#pool,1,-1 do
          local alive,playing=pcall(pool[i].isPlaying,pool[i])
          if not (alive and playing) then table.remove(pool,i) end
        end
        pool[#pool+1]=voice
        local started,why=pcall(voice.play,voice)
        if not started then return fail(why) end
        src=voice
      else
        -- clone is available on supported LÖVE Sources; if a backend lacks it,
        -- fall back to the normal cached Source rather than dropping the SFX.
        pcall(src.play,src)
      end
    else
      activeNormalSource=src
    end

    info.started=info.started+1; info.lastError=nil; return true
  end

  -- Validate every generated FireRed source at battle start without playing it.
  -- Sound.playStereo starts playback immediately; the old play-then-stop warmup
  -- could leak a tiny audible fragment before the first move on some backends.
  -- The persistent static WAV cache already removes the expensive ROM/M4A work,
  -- so first-use source creation is left to Gen1Recomp's normal Sound cache.
  function player.precache(data)
    if not (data and data.audio and data.audio.sfx) then return fail("battle audio data unavailable for precache") end
    info.precacheRuns=info.precacheRuns+1
    for _,key in ipairs(allKeys) do
      if not data.audio.sfx[key] then return fail("registered SFX missing during precache: "..tostring(key)) end
      info.precached=info.precached+1
    end
    info.lastError=nil
    return true
  end

  function player.info()
    return {
      rendered=info.rendered,written=info.written,registered=info.registered,overridden=info.overridden,
      plays=info.plays,started=info.started,failures=info.failures,lastError=info.lastError,
      precacheRuns=info.precacheRuns,precached=info.precached,
      cacheVersion=info.cacheVersion,cacheHit=info.cacheHit,cacheMiss=info.cacheMiss,cachedFiles=info.cachedFiles,
      transport="Gen1Recomp file-backed SFX",directLoveAudio=false,generatedAtLoad=false,
      persistentCache=true,
    }
  end
  return player
end
return M
