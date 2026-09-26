-- Pretty Moves: shared FireRed animation engines + declarative move definitions.
local function loadFile(mod,path)
  local source,err=mod:read(path)
  if not source then error("firered_battle_anims: "..tostring(err),0) end
  local chunk,compileErr=load(source,"@"..mod.path.."/"..path)
  if not chunk then error(compileErr,0) end
  return chunk()
end
local function lib(mod,name) return loadFile(mod,"lib/"..name..".lua") end
local function move(mod,name) return loadFile(mod,"moves/"..name..".lua") end

return function(mod)
  -- In-game mod option: keep canonical FireRed move-background commands on by
  -- default, but allow players to suppress only that background/fade layer.
  mod.options:define({
    { key="move_backgrounds", label="MOVE BACKGROUNDS", type="toggle", default=true },
    { key="pokeball_animations", label="POKEBALL ANIMATIONS", type="toggle", default=true },
  })
  local Rom=lib(mod,"rom"); local FireRed=lib(mod,"firered")
  local Assets=lib(mod,"anim_assets"); local Graphics=lib(mod,"gba_graphics")
  local Registry=lib(mod,"move_registry"); local BattleSpace=lib(mod,"battle_space"); local VoxelCompat=lib(mod,"voxel_compat"); local VoxelCategories=lib(mod,"voxel_categories"); local Visual=lib(mod,"visual_runtime").configure({battleSpace=BattleSpace})
  local VisualAssets=lib(mod,"visual_assets"); local SubstituteFireRed=lib(mod,"substitute_fire_red"); local BattleBgAssets=lib(mod,"battle_bg_assets"); local StatMaskAssets=lib(mod,"stat_mask_assets"); local MetalShineAssets=lib(mod,"metal_shine_assets"); local SmokescreenImpactAssets=lib(mod,"smokescreen_impact_assets"); local Precache=lib(mod,"precache"); local BattleBridge=lib(mod,"battle_bridge"); local BattlerPalette=lib(mod,"battler_palette")
  local Audio=lib(mod,"gba_audio"); local SoundCatalog=lib(mod,"sound_catalog"); local BattleSfx=lib(mod,"battle_sfx"); local StatusConditions=lib(mod,"status_conditions"); local StatusBridge=lib(mod,"status_bridge"); local StatFeedback=lib(mod,"stat_change_feedback"); local ApplyFxBridge=lib(mod,"apply_fx_bridge"); local PokeballEntry=lib(mod,"pokeball_entry"); local PokeballCapture=lib(mod,"pokeball_capture")
  local M4ARuntime=lib(mod,"m4a_runtime"); local M4ATables=lib(mod,"m4a_tables")
  local M4ASynth=lib(mod,"m4a_synth"); local WavPcm=lib(mod,"wav_pcm")
  local NativeAudio=lib(mod,"native_audio"); local StartupCache=lib(mod,"startup_cache")

  local bytes,err=mod:read("baseroms/firered.gba")
  if not bytes then error("FireRed import unavailable: "..tostring(err),0) end
  local rom=Rom.new(bytes); local romInfo=FireRed.validate(rom)

  -- One registry entry per move. Adding a move should normally require only a
  -- declarative moves/<name>.lua file plus any new shared callback/SFX support.
  local registry=Registry.new()
  for _,name in ipairs(move(mod,"index")) do registry:add(move(mod,name)) end

  local visualAssets=VisualAssets.new({rom=rom,assets=Assets,graphics=Graphics,visual=Visual})
  local substituteFireRed=SubstituteFireRed.new()
  local okFront,frontImg=pcall(function() return substituteFireRed:get(false) end)
  local okBack,backImg=pcall(function() return substituteFireRed:get(true) end)
  if okFront and frontImg then visualAssets:registerCustomImage("substitute_front",frontImg) end
  if okBack and backImg then visualAssets:registerCustomImage("substitute_back",backImg) end
  local battleBgAssets=BattleBgAssets.new({rom=rom,graphics=Graphics,assets=Assets,log=mod.log})
  local precache=Precache.new({registry=registry,visual=Visual,visualAssets=visualAssets,log=mod.log})

  local songTable
  local function renderSong(songId)
    if not songTable then songTable=Audio.findSongTable(rom) end
    -- NativeAudio consumes each render immediately into its persistent WAV
    -- cache. Do not retain all PCM songs in this long-lived main closure: on
    -- Android that heap pressure can cause first-menu slowdown and audio
    -- underruns after a cache rebuild.
    local song=Audio.extractSong(rom,songTable,songId)
    local deps=Audio.resolveSongDependencies(rom,song)
    local plan=M4ARuntime.planSong(rom,song)
    return M4ASynth.renderSong(M4ARuntime,M4ATables,plan,deps,{})
  end

  local audio,audioInitError
  local activeBattle
  local singQuietBgm=false
  local function musicLevelFor(battle)
    local game=battle and battle.game
    if not game then
      local ok,Game=pcall(require,"src.core.Game")
      if ok then game=Game end
    end
    local options=game and game.save and game.save.options
    return (options and tonumber(options.musicVol)) or 7
  end
  local function refreshMusicVolume(battle)
    local ok,Music=pcall(require,"src.core.Music")
    if ok and Music and type(Music.setVolumeLevel)=="function" then
      pcall(Music.setVolumeLevel,musicLevelFor(battle))
    end
  end
  -- FireRed's gMovesWithQuietBGM includes Sing: battle animation setup lowers
  -- the playing BGM to 128/256 and restores full configured level afterward.
  mod.hooks:wrap("music.volume",function(next,vol,ctx)
    local out=next(vol,ctx)
    out=tonumber(out) or tonumber(vol) or 0
    if singQuietBgm then out=out*0.5 end
    return out
  end)
  local function setQuietBgm(active,battle)
    active=active==true
    if singQuietBgm==active then return end
    singQuietBgm=active
    refreshMusicVolume(battle)
  end
  local paletteRenderer=BattlerPalette.new({log=mod.log})
  -- Renderer timing is presentation-specific. Battle Art already stages the
  -- native send-out state into its world-card pass, while Potato/2D use the
  -- tuned FireRed visual compensation below. Keep the provider lookup at the
  -- shared compatibility boundary rather than hard-coding Battle Art internals.
  local voxelCompat=VoxelCompat.new({mod=mod,log=mod.log})
  local pokeballEntry=PokeballEntry.new({
    visualAssets=visualAssets,
    paletteRenderer=paletteRenderer,
    playSound=function(soundId,pan,battle,gain,overlap)
      if audio then return audio.play(soundId,pan,battle,gain,overlap) end
      return nil,audioInitError or "FireRed audio unavailable"
    end,
    enabled=function() return mod.options:get("pokeball_animations") ~= false end,
    log=mod.log,
  })
  local pokeballCapture=PokeballCapture.new({
    visualAssets=visualAssets,
    enabled=function() return mod.options:get("pokeball_animations") ~= false end,
    log=mod.log,
  })
  local metalShineAssets=MetalShineAssets.new({rom=rom,graphics=Graphics,log=mod.log})
  local smokescreenImpactAssets=SmokescreenImpactAssets.new({rom=rom,graphics=Graphics,log=mod.log})
  -- Dedicated Smokescreen impact art is outside the tagged battle-animation
  -- sprite table, so prepare it once from the imported FireRed ROM. Keep the
  -- rest of the move usable if an unexpected ROM layout prevents extraction.
  pcall(function() smokescreenImpactAssets:prepare() end)
  local statMaskAssets=StatMaskAssets.new({rom=rom,graphics=Graphics,log=mod.log})
  local statFeedback=StatFeedback.new({
    playSound=function(soundId,pan,battle,gain,overlap)
      if audio then return audio.play(soundId,pan,battle,gain,overlap) end
      return nil,audioInitError or "FireRed audio unavailable"
    end,
    log=mod.log, maskAssets=statMaskAssets, paletteRenderer=paletteRenderer, battleSpace=BattleSpace,
  })
  local statusConditions=StatusConditions.new()

  -- Local voxel planes must be registered against the same authored battler
  -- coordinates that the FireRed move runtime uses. Renderer presentation
  -- anchors describe where a staged picture is composed; they are not always
  -- the FireRed animation coordinate used by battler-local ground callbacks.
  -- Ground art (currently Dig dirt/mound) is authored at the classic raw
  -- battler feet: player (40,96), enemy (120,56). A 10px world-contact
  -- drop keeps the vertical billboard visually seated on the staged feet.
  local function voxelLocalAuthoredAnchor(staged,battler,category,moveId)
    -- Substitute is a battler-local actor. Its drop/bounce canvas is authored
    -- around the classic FireRed doll centre. Place that authored centre much closer to battle centre so the final bounce lands exactly where the host-
    -- owned persistent doll is drawn below. The host keeps owning persistence;
    -- this helper only positions the active falling/bouncing animation.
    if battler and category==VoxelCategories.UPRIGHT and moveId=="SUBSTITUTE" then
      -- Provider-specific landing anchors. Potato keeps the confirmed-good
      -- 16px centre shift; Battle Art lands on its actual authored battler
      -- anchors so the persistent host-owned doll takes over without a snap.
      if staged and staged.provider=="battle_art" then
        if battler.isPlayer then return {26,80},0 end
        return {124,40},0
      end
      if battler.isPlayer then return {24,80},0 end
      return {136,40},0
    end
    if battler and category==VoxelCategories.GROUND then
      if battler.isPlayer then return {40,96},10 end
      return {120,56},10
    end
    local authored=staged and staged.authoredAnchors and staged.authoredAnchors[battler and battler.isPlayer and "player" or "enemy"]
    return authored,0
  end

  local bridge=BattleBridge.new({
    mod=mod,
    voxelCompat=voxelCompat,
    voxelCategories=VoxelCategories,
    visual=Visual,registry=registry,visualAssets=visualAssets,precache=precache,paletteRenderer=paletteRenderer,metalShineAssets=metalShineAssets,smokescreenImpactAssets=smokescreenImpactAssets,battleBgAssets=battleBgAssets,
    playSound=function(soundId,pan,battle,gain,overlap)
      if audio then return audio.play(soundId,pan,battle,gain,overlap) end
      return nil,audioInitError or "FireRed audio unavailable"
    end,
    playMoveCry=function(battle,battler,tempo)
      local data=battle and (battle.data or (battle.game and battle.game.data))
      local species=battler and (battler.species or (battler.mon and battler.mon.species))
      if not (data and species) then return nil,"battle cry context unavailable" end
      local ok,src=pcall(require("src.core.Sound").playMoveCry,data,species,tempo or 0x80)
      if not ok then return nil,src end
      return src or true
    end,
    setQuietBgm=setQuietBgm,
    backgroundsEnabled=function() return mod.options:get("move_backgrounds") ~= false end,
    log=mod.log,
  })
  -- Potato Voxel world-effect bridge. Potato's normal non-VR staged battle
  -- keeps move sprites on a transformed 2D overlay; its true depth-tested
  -- effect billboard is only wired for the VR eye pass. For FireRed move
  -- effects, extend the normal BattleScene render at the narrow seam where
  -- Potato has finished drawing battler cards but is still inside the active
  -- 3D scene. If anything about Potato's private renderer is unavailable,
  -- this hook simply declines and the projected 2D fallback remains active.
  local potatoWorldFx={installed=false,canvases={},tiltCanvases={},mosaicCanvases={},transformReplacementCanvases={},backgroundCanvas=nil}
  local function findMod(id)
    if not (mod and type(mod.find)=="function") then return nil end
    local ok,h=pcall(mod.find,id)
    if ok and type(h)=="table" then return h end
    ok,h=pcall(mod.find,mod,id)
    if ok and type(h)=="table" then return h end
    return nil
  end
  local function ensurePotatoWorldFx()
    if potatoWorldFx.installed then return true end
    local h=findMod("potato_voxel")
    local V=h and h.exports and h.exports.lib
    if not (V and type(V.require)=="function") then return false end
    local okBS,BattleScene=pcall(V.require,"BattleScene")
    local okVX,Voxel3D=pcall(V.require,"Voxel3D")
    local okBB,BattleBillboard=pcall(V.require,"BattleBillboard")
    local okOB,OverworldBattle=pcall(V.require,"OverworldBattle")
    local okM4,Mat4=pcall(V.require,"Mat4")
    if not (okBS and okVX and okBB and okOB and okM4 and BattleScene and Voxel3D and BattleBillboard and OverworldBattle and Mat4) then return false end
    if BattleScene._fireredWorldFxOriginalRender then
      potatoWorldFx.installed=true
      return true
    end
    local originalRender=BattleScene.render
    if type(originalRender)~="function" or type(Voxel3D.glass)~="function" or type(Voxel3D.draw)~="function" then return false end
    BattleScene._fireredWorldFxOriginalRender=originalRender
    BattleScene.render=function(state,arena,textures,token,drawActors)
      local battle=activeBattle
      if battle then battle._fireredWorldBallToken=nil end
      local a=bridge.active
      local staged=battle and voxelCompat:state(battle) or nil
      local moveEligible=a and a.battle==battle
      local ballEntryInfo=battle and pokeballEntry:info() or nil
      local ballCaptureInfo=battle and pokeballCapture:info() or nil
      local ballEntryActive=false
      if ballEntryInfo and type(ballEntryInfo.active)=="table" then
        for _ in pairs(ballEntryInfo.active) do ballEntryActive=true break end
      end
      local ballCaptureActive=ballCaptureInfo and ballCaptureInfo.active~=nil
      local ballEligible=staged and staged.provider=="potato_voxel" and (ballEntryActive or ballCaptureActive)
      local eligible=moveEligible or ballEligible
      local fxCanvases={}
      local backgroundCanvas=nil
      if eligible and love and love.graphics then
        local g=love.graphics
        local function renderCategory(category,side)
          local key=category..":"..(side or "all")
          local c=potatoWorldFx.canvases[key]
          if not c then
            local okC,newc=pcall(g.newCanvas,160,144)
            if okC and newc then c=newc; potatoWorldFx.canvases[key]=c; pcall(c.setFilter,c,"nearest","nearest") end
          end
          if not c then return nil end
          local prev=g.getCanvas and g.getCanvas() or nil
          local okDraw=pcall(function()
            g.push("all"); g.origin(); g.setCanvas(c); g.clear(0,0,0,0)
            g.setBlendMode("alpha"); g.setColor(1,1,1,1)
            bridge:draw(battle,{effectLayerOnly=true,voxelCategory=category,voxelSide=side})
            g.pop()
          end)
          if not okDraw then pcall(g.pop,g) end
          if prev then pcall(g.setCanvas,g,prev) else pcall(g.setCanvas,g) end
          -- The effect layer is captured against transparent black. FireRed's
          -- OBJ alpha blend has already contributed to the captured RGB there;
          -- carrying that alpha into the voxel world blends the same sprite a
          -- second time against grass/trees and shifts its apparent colour.
          -- Collapse ordinary move-layer pixels to one opaque composite here.
          -- Dedicated actor clones (Double Team/Night Shade/Minimize) do not
          -- use this canvas and retain their explicit FireRed alpha timelines.
          if okDraw and c then
            local keyOpaque=key..":opaque"
            local oc=potatoWorldFx.canvases[keyOpaque]
            if not oc then
              local okO,newo=pcall(g.newCanvas,160,144,{dpiscale=1})
              if okO and newo then oc=newo; potatoWorldFx.canvases[keyOpaque]=oc; pcall(oc.setFilter,oc,"nearest","nearest") end
            end
            if oc then
              potatoWorldFx.opaqueShader=potatoWorldFx.opaqueShader or (function()
                local okS,sh=pcall(g.newShader,[[
                  vec4 effect(vec4 color, Image tex, vec2 tc, vec2 sc) {
                    vec4 p=Texel(tex,tc);
                    if (p.a <= 0.001) discard;
                    vec3 rgb=p.rgb / max(p.a, 0.001);
                    return vec4(clamp(rgb,0.0,1.0),1.0) * vec4(color.rgb,1.0);
                  }
                ]])
                return okS and sh or false
              end)()
              local sh=potatoWorldFx.opaqueShader
              if sh then
                local old=g.getCanvas and g.getCanvas() or nil
                local okO=pcall(function()
                  g.push("all"); g.origin(); g.setCanvas(oc); g.clear(0,0,0,0)
                  g.setBlendMode("replace","premultiplied"); g.setShader(sh); g.setColor(1,1,1,1)
                  g.draw(c,0,0); g.setShader(); g.pop()
                end)
                if not okO then pcall(g.setShader); pcall(g.pop,g) end
                if old then pcall(g.setCanvas,g,old) else pcall(g.setCanvas,g) end
                if okO then return oc end
              end
            end
          end
          return okDraw and c or nil
        end
        if moveEligible then
          fxCanvases.arena=renderCategory(VoxelCategories.ARENA,nil)
          fxCanvases.uprightAttacker=renderCategory(VoxelCategories.UPRIGHT,"attacker")
          fxCanvases.uprightTarget=renderCategory(VoxelCategories.UPRIGHT,"target")
          fxCanvases.groundAttacker=renderCategory(VoxelCategories.GROUND,"attacker")
          fxCanvases.groundTarget=renderCategory(VoxelCategories.GROUND,"target")
        end
        if moveEligible then
          local c=potatoWorldFx.backgroundCanvas
          if not c then
            local okC,newc=pcall(g.newCanvas,160,144,{dpiscale=1})
            if okC and newc then
              c=newc; potatoWorldFx.backgroundCanvas=c
              pcall(c.setFilter,c,"nearest","nearest")
            end
          end
          if c then
            local prev=g.getCanvas and g.getCanvas() or nil
            local bgDrew=false
            local okBg=pcall(function()
              g.push("all"); g.origin(); g.setCanvas(c); g.clear(0,0,0,0)
              g.setBlendMode("alpha"); g.setColor(1,1,1,1)
              bgDrew=bridge:drawBackground(battle,{backgroundOnly=true}) and true or false
              g.pop()
            end)
            if not okBg then pcall(g.pop,g) end
            if prev then pcall(g.setCanvas,g,prev) else pcall(g.setCanvas,g) end
            if okBg and bgDrew then backgroundCanvas=c end
          end
        end

        -- Poké Ball entry/capture visuals are authored against the same full
        -- 160x144 battle space as the classic move layer. Capture them on a
        -- dedicated transparent canvas and let Potato's fxCard put the toss,
        -- opening particles, shake and settled ball inside the 3D arena.
        if ballEligible then
          local c=potatoWorldFx.canvases.pokeball
          if not c then
            local okC,newc=pcall(g.newCanvas,160,144)
            if okC and newc then c=newc; potatoWorldFx.canvases.pokeball=c; pcall(c.setFilter,c,"nearest","nearest") end
          end
          if c then
            local prev=g.getCanvas and g.getCanvas() or nil
            local okDraw=pcall(function()
              g.push("all"); g.origin(); g.setCanvas(c); g.clear(0,0,0,0)
              g.setBlendMode("alpha"); g.setColor(1,1,1,1)
              pokeballEntry:draw(battle)
              pokeballCapture:draw(battle)
              g.pop()
            end)
            if not okDraw then pcall(g.pop,g) end
            if prev then pcall(g.setCanvas,g,prev) else pcall(g.setCanvas,g) end
            if okDraw then fxCanvases.pokeball=c end
          end
        end
      end
      -- Safe Potato battler texture-affine path. Rotation and X/Y scaling are
      -- applied only to the already-generated battler texture around Potato's
      -- own anchor. BattleScene still renders its ordinary world card/matrix;
      -- no 3D renderer function is wrapped or replaced for this feature.
      local tiltRestore={}
      local tiltNow=moveEligible and ((bridge.voxelBattlerAffine and bridge:voxelBattlerAffine(battle,true)) or (bridge.voxelBattlerTilt and bridge:voxelBattlerTilt(battle,true))) or nil
      if tiltNow and type(textures)=="table" and love and love.graphics then
        local g=love.graphics
        for side,desc in pairs(tiltNow) do
          local tex=textures[side]
          local src=tex and tex.canvas
          if src and type(src.getDimensions)=="function" then
            local cw,ch=src:getDimensions()
            local tc=potatoWorldFx.tiltCanvases[side]
            if not tc or tc:getWidth()~=cw or tc:getHeight()~=ch then
              local okC,newc=pcall(g.newCanvas,cw,ch,{dpiscale=1})
              if okC and newc then
                tc=newc; potatoWorldFx.tiltCanvases[side]=tc
                pcall(tc.setFilter,tc,"nearest","nearest")
              else
                tc=nil
              end
            end
            if tc then
              local img=desc.battler and voxelCompat:battlerImage(battle,desc.battler) or nil
              local ih=56
              if img and type(img.getDimensions)=="function" then
                local _,h=img:getDimensions()
                ih=tonumber(h) or ih
              end
              local px=tonumber(tex.ax) or (cw/2)
              local py=(tonumber(tex.ay) or 96)-(ih/2)
              local angle=tonumber(desc.angle) or 0
              local dx=tonumber(desc.dx) or 0
              local dy=tonumber(desc.dy) or 0
              local sx=tonumber(desc.scaleX) or 1
              local sy=tonumber(desc.scaleY) or 1
              local acid=type(desc.acidArmor)=="table" and desc.acidArmor or nil
              -- Potato mirrors the player card after texturing. Pre-rotated /
              -- pre-translated pixels therefore use the opposite source signs
              -- so the final visible pose matches FireRed.
              if desc.battler and voxelCompat:mirrorX(staged,desc.battler) then
                angle=-angle; dx=-dx
              end
              local prev=g.getCanvas and g.getCanvas() or nil
              local okTilt=pcall(function()
                g.push("all"); g.origin(); g.setCanvas(tc); g.clear(0,0,0,0)
                g.setBlendMode("alpha"); g.setColor(1,1,1,1)
                g.translate(dx,dy)
                -- Rotation stays centred on the visible Pokemon like v0.55.43.
                -- Growth scaling is anchored at Potato's battler baseline so
                -- the Pokemon grows upward instead of sinking through its cell.
                if math.abs(angle)>0.000001 then
                  g.translate(px,py); g.rotate(angle); g.translate(-px,-py)
                end
                if math.abs(sx-1)>0.000001 or math.abs(sy-1)>0.000001 then
                  local scalePivotY=tonumber(tex.ay) or 96
                  g.translate(px,scalePivotY); g.scale(sx,sy); g.translate(-px,-scalePivotY)
                end
                if acid then
                  -- Acid Armor must remain on Potato's real world-space card.
                  -- Warp the already-generated battler texture scanline by
                  -- scanline, preserving its texture-space Y exactly (the
                  -- corrected v0.56.12 2D behavior), then let Potato place the
                  -- transformed canvas with its ordinary world matrix.
                  local aa=tonumber(acid.alpha) or 1
                  if aa<0 then aa=0 elseif aa>1 then aa=1 end
                  g.setColor(1,1,1,aa)
                  if aa>0 then
                    local age=math.max(0,math.floor(tonumber(acid.age) or 0))
                    for yy=0,ch-1 do
                      local phase=((age*2)+(yy*10))%256
                      local wave=math.sin(phase*math.pi*2/256)*4
                      local quad=g.newQuad(0,yy,cw,1,cw,ch)
                      g.draw(src,quad,wave,yy)
                    end
                  end
                else
                  -- Transform switches graphics at maximum mosaic.  The bridge
                  -- supplies gen1recomp's own side-correct speciesSprite; draw
                  -- it into Potato's existing card texture at the same feet
                  -- anchor before applying the exact same mosaic pass.
                  local mosaicSource=src
                  local replacement=desc.replacementImage
                  if replacement and type(replacement.getDimensions)=="function" then
                    local rc=potatoWorldFx.transformReplacementCanvases and potatoWorldFx.transformReplacementCanvases[side] or nil
                    if not potatoWorldFx.transformReplacementCanvases then potatoWorldFx.transformReplacementCanvases={} end
                    if not rc or rc:getWidth()~=cw or rc:getHeight()~=ch then
                      local okR,newr=pcall(g.newCanvas,cw,ch,{dpiscale=1})
                      if okR and newr then rc=newr; potatoWorldFx.transformReplacementCanvases[side]=rc; pcall(rc.setFilter,rc,"nearest","nearest") else rc=nil end
                    end
                    if rc then
                      local rw,rh=replacement:getDimensions()
                      local ax=tonumber(tex.ax) or (cw/2)
                      local ay=tonumber(tex.ay) or 96
                      g.setCanvas(rc); g.clear(0,0,0,0); g.origin(); g.setColor(1,1,1,1)
                      g.draw(replacement,ax-rw/2,ay-rh)
                      mosaicSource=rc
                    end
                  end
                  local block=math.max(1,math.floor(tonumber(desc.mosaicSize) or 1))
                  if block>1 then
                    local lw,lh=math.max(1,math.ceil(cw/block)),math.max(1,math.ceil(ch/block))
                    local mc=potatoWorldFx.mosaicCanvases[side]
                    if not mc or mc:getWidth()~=lw or mc:getHeight()~=lh then
                      local okM,newm=pcall(g.newCanvas,lw,lh,{dpiscale=1})
                      if okM and newm then mc=newm; potatoWorldFx.mosaicCanvases[side]=mc; pcall(mc.setFilter,mc,"nearest","nearest") else mc=nil end
                    end
                    if mc then
                      g.setCanvas(mc); g.clear(0,0,0,0); g.origin(); g.setColor(1,1,1,1); g.draw(mosaicSource,0,0,0,lw/cw,lh/ch)
                      g.setCanvas(tc); g.origin(); g.setColor(1,1,1,1); g.draw(mc,0,0,0,cw/lw,ch/lh)
                    else
                      g.draw(mosaicSource,0,0)
                    end
                  else
                    g.draw(mosaicSource,0,0)
                  end
                end
                g.pop()
              end)
              if not okTilt then pcall(g.pop,g) end
              if prev then pcall(g.setCanvas,g,prev) else pcall(g.setCanvas,g) end
              if okTilt then
                local copy={}
                for k,v in pairs(tex) do copy[k]=v end
                copy.canvas=tc
                tiltRestore[side]=tex
                textures[side]=copy
              end
            end
          end
        end
      end

      local function restoreTiltTextures()
        if type(textures)=="table" then
          for side,tex in pairs(tiltRestore) do textures[side]=tex end
        end
      end

      if not next(fxCanvases) and not backgroundCanvas then
        local results={pcall(originalRender,state,arena,textures,token,drawActors)}
        restoreTiltTextures()
        if not results[1] then error(results[2],0) end
        table.remove(results,1)
        return unpack(results)
      end

      local innerGlass=Voxel3D.glass
      local innerSeams=Voxel3D.seams
      local innerDraw=Voxel3D.draw
      -- FireRed animation art is authored screen art, not world material.
      -- Cancel the staged renderer's day/night tint and opt out of sun/shadow
      -- reception so ROM palette colors stay exact over trees, flowers, etc.
      local function fireRedDraw(mesh,tex,model,pull,r,g,b,alpha)
        local tint=Voxel3D.tint or {1,1,1}
        local function untint(v,i)
          local t=tonumber(tint[i]) or 1
          if t < 0.05 then t=0.05 end
          return (tonumber(v) or 1)/t
        end
        love.graphics.setColor(untint(r,1),untint(g,2),untint(b,3),alpha or 1)
        innerDraw(mesh,tex,model,pull,nil,false)
      end
      local sawCardPass=false
      local injected=false
      local vegetationDepthMasked=false
      local backgroundInjected=false

      -- Ground-category effects belong at the battler's feet, but they must
      -- composite in front of the battler base.  Keep them out of the normal
      -- pre-card effect pass and draw them once at the post-card seam.  This
      -- is shared by Potato and Battle Art so every GROUND effect follows the
      -- same ordering rather than relying on move-specific fixes.
      local function drawGroundForeground()
        if not a then return false end
        local host=(arena and arena.map) or (state and state.map)
        local groundY=host and BattleScene.groundY(host,arena) or nil
        local mesh=BattleBillboard.mesh and BattleBillboard.mesh() or nil
        if not (arena and mesh and groundY) then return false end
        local any=false
        local function drawOne(tex,side)
          if not tex then return end
          local battler=(side=="target") and a.targetBattler or a.attackerBattler
          local cell=battler and battler.isPlayer and arena.player or arena.enemy
          if not cell then return end
          local authored,groundDropPx=voxelLocalAuthoredAnchor(staged,battler,VoxelCategories.GROUND,a and a.move and a.move.id)
          if not authored then return end
          local pw,ph=tex:getDimensions()
          local w,h=BattleBillboard.sizeFor(pw,ph)
          local unit=BattleBillboard.FULL_W/BattleBillboard.FULL_PIC
          local ax=(authored[1]-pw/2)*unit
          local ay=(ph-authored[2])*unit
          local yaw=BattleBillboard.yawToward(cell[1],cell[2],Voxel3D.eye)
          local baseY=groundY-(groundDropPx or 0)*unit
          local base=Mat4.mul(Mat4.translate(cell[1],baseY,cell[2]),Mat4.rotateY(yaw))
          local modelLocal=Mat4.mul(base,Mat4.mul(Mat4.translate(-ax,-ay,0),Mat4.scale(w,h,1)))
          innerSeams(false); innerGlass(false)
          pcall(love.graphics.setDepthMode,"always",false)
          love.graphics.setColor(1,1,1,1)
          fireRedDraw(mesh,tex,modelLocal,(BattleBillboard.PULL or 0)+7,1,1,1,1)
          love.graphics.setColor(1,1,1,1)
          pcall(love.graphics.setDepthMode,"lequal",true)
          innerGlass(false); innerSeams(false)
          any=true
        end
        drawOne(fxCanvases.groundAttacker,"attacker")
        drawOne(fxCanvases.groundTarget,"target")
        if any then battle._fireredWorldFxFrame=a.frame end
        return any
      end

      -- Potato/Battle Art may draw grass and flowers after the battler-card
      -- pass. Preserve the existing visible OAM/battler ordering, then stamp
      -- only the already-visible FireRed effect silhouettes into depth before
      -- that final vegetation pass. Their voxel shader discards transparent
      -- texels, so this protects sprite pixels without creating rectangular
      -- depth cards around them.
      local function writeVegetationDepthMask()
        if vegetationDepthMasked or not injected then return end
        vegetationDepthMasked=true
        local g=love and love.graphics
        if not (g and type(g.setColorMask)=="function") then return end
        local host=(arena and arena.map) or (state and state.map)
        local groundY=host and BattleScene.groundY(host,arena) or nil
        local anchors=OverworldBattle.ANCHOR
        local model=groundY and anchors and BattleScene.fxCard(arena,groundY,anchors) or nil
        local mesh=BattleBillboard.mesh and BattleBillboard.mesh() or nil
        if not (mesh and groundY) then return end
        local okMask=pcall(function()
          innerSeams(false); innerGlass(false)
          g.setColorMask(false,false,false,false)
          g.setDepthMode("always",true)
          g.setColor(1,1,1,1)
          if model and fxCanvases.arena then
            fireRedDraw(mesh,fxCanvases.arena,model,(BattleBillboard.PULL or 0)+6,1,1,1,1)
          end
          if model and fxCanvases.pokeball then
            fireRedDraw(mesh,fxCanvases.pokeball,model,(BattleBillboard.PULL or 0)+8,1,1,1,1)
          end
          local function maskLocal(tex,side,category,pull)
            if not (tex and arena and a) then return end
            local battler=(side=="target") and a.targetBattler or a.attackerBattler
            local cell=battler and battler.isPlayer and arena.player or arena.enemy
            if not cell then return end
            local authored,groundDropPx=voxelLocalAuthoredAnchor(staged,battler,category,a and a.move and a.move.id)
            if not authored then return end
            local pw,ph=tex:getDimensions()
            local w,h=BattleBillboard.sizeFor(pw,ph)
            local unit=BattleBillboard.FULL_W/BattleBillboard.FULL_PIC
            local ax=(authored[1]-pw/2)*unit
            local ay=(ph-authored[2])*unit
            local yaw=BattleBillboard.yawToward(cell[1],cell[2],Voxel3D.eye)
            local baseY=groundY-(groundDropPx or 0)*unit
            local base=Mat4.mul(Mat4.translate(cell[1],baseY,cell[2]),Mat4.rotateY(yaw))
            local mm=Mat4.mul(base,Mat4.mul(Mat4.translate(-ax,-ay,0),Mat4.scale(w,h,1)))
            innerDraw(mesh,tex,mm,pull)
          end
          maskLocal(fxCanvases.uprightAttacker,"attacker",VoxelCategories.UPRIGHT,(BattleBillboard.PULL or 0)+7)
          maskLocal(fxCanvases.uprightTarget,"target",VoxelCategories.UPRIGHT,(BattleBillboard.PULL or 0)+7)
          maskLocal(fxCanvases.groundAttacker,"attacker",VoxelCategories.GROUND,(BattleBillboard.PULL or 0)+5)
          maskLocal(fxCanvases.groundTarget,"target",VoxelCategories.GROUND,(BattleBillboard.PULL or 0)+5)

          local dt=a and bridge.doubleTeamWorldClones and bridge:doubleTeamWorldClones(battle) or nil
          if dt and dt.image and dt.offsets and arena then
            local cell=dt.battler and dt.battler.isPlayer and arena.player or arena.enemy
            if cell then
              local iw,ih=dt.image:getDimensions()
              local w,h=BattleBillboard.sizeFor(iw,ih)
              if dt.mirrorX then w=-w end
              local yaw=BattleBillboard.yawToward(cell[1],cell[2],Voxel3D.eye)
              local unit=BattleBillboard.FULL_W/BattleBillboard.FULL_PIC
              local base=Mat4.mul(Mat4.translate(cell[1],groundY,cell[2]),Mat4.rotateY(yaw))
              for _,dx in ipairs(dt.offsets) do
                local localModel=Mat4.mul(Mat4.translate((tonumber(dx) or 0)*unit,0,0),Mat4.scale(w,h,1))
                innerDraw(mesh,dt.image,Mat4.mul(base,localModel),(BattleBillboard.PULL or 0)+7)
              end
            end
          end
          local mn=a and bridge.minimizeWorldClones and bridge:minimizeWorldClones(battle) or nil
          if mn and mn.image and mn.clones and arena then
            local cell=mn.battler and mn.battler.isPlayer and arena.player or arena.enemy
            if cell then
              local iw,ih=mn.image:getDimensions()
              local baseW,baseH=BattleBillboard.sizeFor(iw,ih)
              local yaw=BattleBillboard.yawToward(cell[1],cell[2],Voxel3D.eye)
              for _,cl in ipairs(mn.clones) do
                local k=tonumber(cl.scale) or 1
                local w,h=baseW*k,baseH*k
                if mn.mirrorX then w=-w end
                innerDraw(mesh,mn.image,BattleBillboard.matrix(cell[1],groundY,cell[2],w,h,yaw),(BattleBillboard.PULL or 0)+7)
              end
            end
          end
          local ns=a and bridge.nightShadeWorldClone and bridge:nightShadeWorldClone(battle) or nil
          if ns and ns.image and arena then
            local cell=ns.battler and ns.battler.isPlayer and arena.player or arena.enemy
            if cell then
              local iw,ih=ns.image:getDimensions()
              local w,h=BattleBillboard.sizeFor(iw,ih)
              local k=tonumber(ns.scale) or 1
              w,h=w*k,h*k
              if ns.mirrorX then w=-w end
              local yaw=BattleBillboard.yawToward(cell[1],cell[2],Voxel3D.eye)
              innerDraw(mesh,ns.image,BattleBillboard.matrix(cell[1],groundY,cell[2],w,h,yaw),(BattleBillboard.PULL or 0)+7)
            end
          end
        end)
        pcall(g.setColorMask,true,true,true,true)
        pcall(g.setDepthMode,"lequal",true)
        pcall(g.setColor,1,1,1,1)
        innerGlass(true)
        if not okMask then vegetationDepthMasked=false end
      end
      -- FireRed move backgrounds are presentation backdrops, not a second
      -- renderer. Inject the background once after Potato has finished its 3D
      -- world/vegetation pass and immediately before Potato draws battler cards.
      -- Everything above that seam (battlers, affine transforms, clones and
      -- move effects) keeps using Potato's normal, already-correct render path.
      Voxel3D.glass=function(on,...)
        if on==false then
          if backgroundCanvas and not backgroundInjected then
            local okBgInject=pcall(function()
              local host=(arena and arena.map) or (state and state.map)
              local groundY=host and BattleScene.groundY(host,arena) or nil
              local anchors=OverworldBattle.ANCHOR
              local model=groundY and anchors and BattleScene.fxCard(arena,groundY,anchors) or nil
              local mesh=BattleBillboard.mesh and BattleBillboard.mesh() or nil
              if model and mesh then
                -- This is a presentation background, not world geometry. Draw
                -- it after the finished world/vegetation and before Potato's
                -- battler cards, ignoring world depth exactly like the old
                -- background-before-actors ordering.
                pcall(love.graphics.setDepthMode,"always",false)
                love.graphics.setColor(1,1,1,1)
                fireRedDraw(mesh,backgroundCanvas,model,(BattleBillboard.PULL or 0)+4,1,1,1,1)
                love.graphics.setColor(1,1,1,1)
                pcall(love.graphics.setDepthMode,"lequal",true)
                backgroundInjected=true
                battle._fireredWorldBgFrame=a and a.frame or true
              end
            end)
            if not okBgInject then backgroundInjected=false end
          end
        elseif on==true and sawCardPass and not injected then
          injected=true
          local okInject=pcall(function()
            local host=(arena and arena.map) or (state and state.map)
            local groundY=host and BattleScene.groundY(host,arena) or nil
            local anchors=OverworldBattle.ANCHOR
            local model=groundY and anchors and BattleScene.fxCard(arena,groundY,anchors) or nil
            local mesh=BattleBillboard.mesh and BattleBillboard.mesh() or nil
            if model and mesh and fxCanvases.arena then
              -- Battle-animation sprites are foreground actors relative to the
              -- voxel scenery.  Use an always-pass depth test so trees/grass
              -- cannot punch through effects such as Constrict tendrils.
              pcall(love.graphics.setDepthMode,"always",false)
              fireRedDraw(mesh,fxCanvases.arena,model,(BattleBillboard.PULL or 0)+6,1,1,1,1)
              pcall(love.graphics.setDepthMode,"lequal",true)
            end
            if model and mesh and fxCanvases.pokeball then
              -- A hair farther camera-ward than ordinary move effects so the
              -- ball remains readable when crossing a battler card, matching
              -- the original OAM layering while still depth-testing in world.
              fireRedDraw(mesh,fxCanvases.pokeball,model,(BattleBillboard.PULL or 0)+8,1,1,1,1)
              battle._fireredWorldBallToken=token or true
            else
              battle._fireredWorldBallToken=nil
            end

            -- Local category canvases are full authored 160x144 battle layers,
            -- but unlike the arena plane they are attached to one battler and
            -- always face the camera. Align that canvas' authored battler anchor
            -- exactly to the battler's world cell; this removes the pair-plane
            -- tilt while preserving every sprite's native relative coordinates.
            local function drawLocalCanvas(tex,side,category,pull)
              if not (tex and arena and mesh and groundY) then return false end
              if not a then return false end
              local battler=(side=="target") and a.targetBattler or a.attackerBattler
              local cell=battler and battler.isPlayer and arena.player or arena.enemy
              if not cell then return false end
              local authored,groundDropPx=voxelLocalAuthoredAnchor(staged,battler,category,a and a.move and a.move.id)
              if not authored then return false end
              local pw,ph=tex:getDimensions()
              local w,h=BattleBillboard.sizeFor(pw,ph)
              local unit=BattleBillboard.FULL_W/BattleBillboard.FULL_PIC
              local ax=(authored[1]-pw/2)*unit
              local ay=(ph-authored[2])*unit
              local yaw=BattleBillboard.yawToward(cell[1],cell[2],Voxel3D.eye)
              local baseY=groundY-(groundDropPx or 0)*unit
              local base=Mat4.mul(Mat4.translate(cell[1],baseY,cell[2]),Mat4.rotateY(yaw))
              local modelLocal=Mat4.mul(base,Mat4.mul(Mat4.translate(-ax,-ay,0),Mat4.scale(w,h,1)))
              Voxel3D.seams(false); Voxel3D.glass(false)
              pcall(love.graphics.setDepthMode,"always",false)
              love.graphics.setColor(1,1,1,1)
              fireRedDraw(mesh,tex,modelLocal,pull,1,1,1,1)
              love.graphics.setColor(1,1,1,1)
              pcall(love.graphics.setDepthMode,"lequal",true)
              Voxel3D.glass(false); Voxel3D.seams(false)
              return true
            end
            local anyLocal=false
            anyLocal=drawLocalCanvas(fxCanvases.uprightAttacker,"attacker","upright",(BattleBillboard.PULL or 0)+7) or anyLocal
            anyLocal=drawLocalCanvas(fxCanvases.uprightTarget,"target","upright",(BattleBillboard.PULL or 0)+7) or anyLocal
            -- GROUND canvases are deliberately deferred until after the
            -- battler-card pass; see drawGroundForeground().
            if a and model and mesh and (fxCanvases.arena or anyLocal) then battle._fireredWorldFxFrame=a.frame end

            -- Double Team's two copies are local battler actors just like the
            -- Night Shade clone: keep them inside Potato's 3D scene instead
            -- of drawing projected copies over the HUD.  Their FireRed x
            -- offsets are authored pixels; convert those to the same world
            -- unit scale Potato uses for 56px battler cards, then translate
            -- along the camera-facing billboard's local X axis.
            local dt=a and bridge.doubleTeamWorldClones and bridge:doubleTeamWorldClones(battle) or nil
            if dt and dt.image and dt.offsets and arena then
              local cell=dt.battler and dt.battler.isPlayer and arena.player or arena.enemy
              if cell then
                local iw,ih=dt.image:getDimensions()
                local w,h=BattleBillboard.sizeFor(iw,ih)
                if dt.mirrorX then w=-w end
                local yaw=BattleBillboard.yawToward(cell[1],cell[2],Voxel3D.eye)
                local unit=BattleBillboard.FULL_W/BattleBillboard.FULL_PIC
                local base=Mat4.mul(Mat4.translate(cell[1],groundY,cell[2]),Mat4.rotateY(yaw))
                local d=math.max(0,math.min(1,tonumber(dt.darkMul) or (5/16)))
                local alpha=math.max(0,math.min(1,tonumber(dt.alpha) or (12/16)))
                Voxel3D.seams(false)
                Voxel3D.glass(false)
                Voxel3D.blend("alpha")
                pcall(love.graphics.setDepthMode,"always",false)
                for _,dx in ipairs(dt.offsets) do
                  local localModel=Mat4.mul(Mat4.translate((tonumber(dx) or 0)*unit,0,0),Mat4.scale(w,h,1))
                  local dtModel=Mat4.mul(base,localModel)
                  fireRedDraw(mesh,dt.image,dtModel,(BattleBillboard.PULL or 0)+7,d,d,d,alpha)
                end
                love.graphics.setColor(1,1,1,1)
                pcall(love.graphics.setDepthMode,"lequal",true)
                Voxel3D.blend(nil)
                Voxel3D.glass(false)
                Voxel3D.seams(false)
              end
            end

            -- Minimize's translucent traces are actor-like copies of the
            -- attacker. The real battler shrink/grow is already applied by the
            -- safe texture-affine path above; render only the temporary traces
            -- here as camera-facing billboards rooted at the same world cell.
            local mn=a and bridge.minimizeWorldClones and bridge:minimizeWorldClones(battle) or nil
            if mn and mn.image and mn.clones and arena then
              local cell=mn.battler and mn.battler.isPlayer and arena.player or arena.enemy
              if cell then
                local iw,ih=mn.image:getDimensions()
                local baseW,baseH=BattleBillboard.sizeFor(iw,ih)
                local yaw=BattleBillboard.yawToward(cell[1],cell[2],Voxel3D.eye)
                Voxel3D.seams(false)
                Voxel3D.glass(false)
                Voxel3D.blend("alpha")
                pcall(love.graphics.setDepthMode,"always",false)
                for _,cl in ipairs(mn.clones) do
                  local k=tonumber(cl.scale) or 1
                  local w,h=baseW*k,baseH*k
                  if mn.mirrorX then w=-w end
                  local mm=BattleBillboard.matrix(cell[1],groundY,cell[2],w,h,yaw)
                  fireRedDraw(mesh,mn.image,mm,(BattleBillboard.PULL or 0)+7,1,1,1,math.max(0,math.min(1,tonumber(cl.alpha) or (10/16))))
                end
                love.graphics.setColor(1,1,1,1)
                pcall(love.graphics.setDepthMode,"lequal",true)
                Voxel3D.blend(nil)
                Voxel3D.glass(false)
                Voxel3D.seams(false)
              end
            end

            -- Night Shade's clone is an actor on the attacker's own cell,
            -- not a sprite spanning the two-slot move plane. Draw it as a
            -- dedicated camera-facing billboard so it stands perfectly
            -- upright, keeps its feet on the ground, and preserves FireRed's
            -- live alpha/scale timeline.
            local ns=a and bridge.nightShadeWorldClone and bridge:nightShadeWorldClone(battle) or nil
            if ns and ns.image and arena then
              local cell=ns.battler and ns.battler.isPlayer and arena.player or arena.enemy
              if cell then
                local iw,ih=ns.image:getDimensions()
                local w,h=BattleBillboard.sizeFor(iw,ih)
                local k=tonumber(ns.scale) or 1
                w,h=w*k,h*k
                if ns.mirrorX then w=-w end
                local yaw=BattleBillboard.yawToward(cell[1],cell[2],Voxel3D.eye)
                local nsModel=BattleBillboard.matrix(cell[1],groundY,cell[2],w,h,yaw)
                Voxel3D.seams(false)
                Voxel3D.glass(false)
                Voxel3D.blend("alpha")
                pcall(love.graphics.setDepthMode,"always",false)
                fireRedDraw(mesh,ns.image,nsModel,(BattleBillboard.PULL or 0)+7,1,1,1,math.max(0,math.min(1,tonumber(ns.alpha) or 0)))
                love.graphics.setColor(1,1,1,1)
                pcall(love.graphics.setDepthMode,"lequal",true)
                Voxel3D.blend(nil)
                Voxel3D.glass(false)
                Voxel3D.seams(false)
              end
            end
          end)
          if not okInject then injected=false end
        end
        return innerGlass(on,...)
      end
      -- BattleScene has exactly one seams(false) transition: after all arena
      -- terrain/vegetation (including custom foreground leaves) and immediately
      -- before battler cards. Inject FireRed foreground effects at that seam so
      -- no voxel vegetation can be drawn over them afterward.
      if type(innerSeams)=="function" then
        Voxel3D.seams=function(on,...)
          if on==false and not injected then
            sawCardPass=true
            -- Reuse the normal injection branch without changing its drawing
            -- behavior; BattleScene itself sets glass(false) immediately next.
            Voxel3D.glass(true)
            sawCardPass=false
          elseif on==true and injected and not vegetationDepthMasked then
            -- GROUND effects are authored at the battler's feet and should
            -- composite over the battler base, so draw the entire shared
            -- GROUND path here, after the cards and before any late foliage.
            drawGroundForeground()
            -- Then stamp the depth-only protection for all FireRed effects so
            -- Potato's late grass/flower pass cannot cover them.
            writeVegetationDepthMask()
          end
          return innerSeams(on,...)
        end
      end
      -- FireRed Double Team disables the attacker's monbg while the two clone
      -- OBJs are active. Potato owns its battlers as 3D cards, so the host
      -- picFx.hidden flag cannot guarantee that card disappears. Temporarily
      -- remove only the attacker's Potato texture for this render pass; the
      -- dedicated world clone billboards above remain available from the
      -- FireRed bridge and the texture is restored immediately afterward.
      local hiddenDtKey=nil
      local hiddenDtTexture=nil
      local dtNow=moveEligible and bridge.doubleTeamWorldClones and bridge:doubleTeamWorldClones(battle) or nil
      if dtNow and dtNow.battler and type(textures)=="table" then
        hiddenDtKey=dtNow.battler.isPlayer and "player" or "enemy"
        hiddenDtTexture=textures[hiddenDtKey]
        textures[hiddenDtKey]=nil
      end
      local results={pcall(originalRender,state,arena,textures,token,drawActors)}
      if hiddenDtKey then textures[hiddenDtKey]=hiddenDtTexture end
      restoreTiltTextures()
      Voxel3D.glass=innerGlass
      if innerSeams then Voxel3D.seams=innerSeams end
      if not results[1] then error(results[2],0) end
      table.remove(results,1)
      return unpack(results)
    end
    potatoWorldFx.installed=true
    return true
  end

  local battleArtWorldFx={installed=false,canvases={},tiltCanvases={},mosaicCanvases={},transformReplacementCanvases={},backgroundCanvas=nil}
  local function findMod(id)
    if not (mod and type(mod.find)=="function") then return nil end
    local ok,h=pcall(mod.find,id)
    if ok and type(h)=="table" then return h end
    ok,h=pcall(mod.find,mod,id)
    if ok and type(h)=="table" then return h end
    return nil
  end
  local function ensureBattleArtWorldFx()
    if battleArtWorldFx.installed then return true end
    local h=findMod("BATTLE_ART_VOXEL_FORK")
    local V=h and h.exports and h.exports.lib
    if not (V and type(V.require)=="function") then return false end
    local okBS,BattleScene=pcall(V.require,"BattleScene")
    local okVX,Voxel3D=pcall(V.require,"Voxel3D")
    local okBB,BattleBillboard=pcall(V.require,"BattleBillboard")
    local okOB,OverworldBattle=pcall(V.require,"OverworldBattle")
    local okM4,Mat4=pcall(V.require,"Mat4")
    if not (okBS and okVX and okBB and okOB and okM4 and BattleScene and Voxel3D and BattleBillboard and OverworldBattle and Mat4) then return false end
    if BattleScene._fireredBattleArtWorldFxOriginalRender then
      battleArtWorldFx.installed=true
      return true
    end
    local originalRender=BattleScene.render
    if type(originalRender)~="function" or type(Voxel3D.glass)~="function" or type(Voxel3D.draw)~="function" then return false end
    BattleScene._fireredBattleArtWorldFxOriginalRender=originalRender
    BattleScene.render=function(state,arena,textures,token,battleParam,drawActors,externalCamera,externalModelShadow)
      local battle=battleParam or activeBattle
      if battle then battle._fireredWorldBallToken=nil end
      local a=bridge.active
      local staged=battle and voxelCompat:state(battle) or nil
      local moveEligible=a and a.battle==battle
      local ballEntryInfo=battle and pokeballEntry:info() or nil
      local ballCaptureInfo=battle and pokeballCapture:info() or nil
      local ballEntryActive=false
      if ballEntryInfo and type(ballEntryInfo.active)=="table" then
        for _ in pairs(ballEntryInfo.active) do ballEntryActive=true break end
      end
      local ballCaptureActive=ballCaptureInfo and ballCaptureInfo.active~=nil
      local ballEligible=staged and staged.provider=="battle_art" and (ballEntryActive or ballCaptureActive)
      local eligible=moveEligible or ballEligible
      local fxCanvases={}
      local backgroundCanvas=nil
      if eligible and love and love.graphics then
        local g=love.graphics
        local function renderCategory(category,side)
          local key=category..":"..(side or "all")
          local c=battleArtWorldFx.canvases[key]
          if not c then
            local okC,newc=pcall(g.newCanvas,160,144)
            if okC and newc then c=newc; battleArtWorldFx.canvases[key]=c; pcall(c.setFilter,c,"nearest","nearest") end
          end
          if not c then return nil end
          local prev=g.getCanvas and g.getCanvas() or nil
          local okDraw=pcall(function()
            g.push("all"); g.origin(); g.setCanvas(c); g.clear(0,0,0,0)
            g.setBlendMode("alpha"); g.setColor(1,1,1,1)
            bridge:draw(battle,{effectLayerOnly=true,voxelCategory=category,voxelSide=side})
            g.pop()
          end)
          if not okDraw then pcall(g.pop,g) end
          if prev then pcall(g.setCanvas,g,prev) else pcall(g.setCanvas,g) end
          -- The effect layer is captured against transparent black. FireRed's
          -- OBJ alpha blend has already contributed to the captured RGB there;
          -- carrying that alpha into the voxel world blends the same sprite a
          -- second time against grass/trees and shifts its apparent colour.
          -- Collapse ordinary move-layer pixels to one opaque composite here.
          -- Dedicated actor clones (Double Team/Night Shade/Minimize) do not
          -- use this canvas and retain their explicit FireRed alpha timelines.
          if okDraw and c then
            local keyOpaque=key..":opaque"
            local oc=potatoWorldFx.canvases[keyOpaque]
            if not oc then
              local okO,newo=pcall(g.newCanvas,160,144,{dpiscale=1})
              if okO and newo then oc=newo; potatoWorldFx.canvases[keyOpaque]=oc; pcall(oc.setFilter,oc,"nearest","nearest") end
            end
            if oc then
              potatoWorldFx.opaqueShader=potatoWorldFx.opaqueShader or (function()
                local okS,sh=pcall(g.newShader,[[
                  vec4 effect(vec4 color, Image tex, vec2 tc, vec2 sc) {
                    vec4 p=Texel(tex,tc);
                    if (p.a <= 0.001) discard;
                    vec3 rgb=p.rgb / max(p.a, 0.001);
                    return vec4(clamp(rgb,0.0,1.0),1.0) * vec4(color.rgb,1.0);
                  }
                ]])
                return okS and sh or false
              end)()
              local sh=potatoWorldFx.opaqueShader
              if sh then
                local old=g.getCanvas and g.getCanvas() or nil
                local okO=pcall(function()
                  g.push("all"); g.origin(); g.setCanvas(oc); g.clear(0,0,0,0)
                  g.setBlendMode("replace","premultiplied"); g.setShader(sh); g.setColor(1,1,1,1)
                  g.draw(c,0,0); g.setShader(); g.pop()
                end)
                if not okO then pcall(g.setShader); pcall(g.pop,g) end
                if old then pcall(g.setCanvas,g,old) else pcall(g.setCanvas,g) end
                if okO then return oc end
              end
            end
          end
          return okDraw and c or nil
        end
        if moveEligible then
          fxCanvases.arena=renderCategory(VoxelCategories.ARENA,nil)
          fxCanvases.uprightAttacker=renderCategory(VoxelCategories.UPRIGHT,"attacker")
          fxCanvases.uprightTarget=renderCategory(VoxelCategories.UPRIGHT,"target")
          fxCanvases.groundAttacker=renderCategory(VoxelCategories.GROUND,"attacker")
          fxCanvases.groundTarget=renderCategory(VoxelCategories.GROUND,"target")
        end
        if moveEligible then
          local c=battleArtWorldFx.backgroundCanvas
          if not c then
            local okC,newc=pcall(g.newCanvas,160,144,{dpiscale=1})
            if okC and newc then
              c=newc; battleArtWorldFx.backgroundCanvas=c
              pcall(c.setFilter,c,"nearest","nearest")
            end
          end
          if c then
            local prev=g.getCanvas and g.getCanvas() or nil
            local bgDrew=false
            local okBg=pcall(function()
              g.push("all"); g.origin(); g.setCanvas(c); g.clear(0,0,0,0)
              g.setBlendMode("alpha"); g.setColor(1,1,1,1)
              bgDrew=bridge:drawBackground(battle,{backgroundOnly=true}) and true or false
              g.pop()
            end)
            if not okBg then pcall(g.pop,g) end
            if prev then pcall(g.setCanvas,g,prev) else pcall(g.setCanvas,g) end
            if okBg and bgDrew then backgroundCanvas=c end
          end
        end

        -- Poké Ball entry/capture visuals are authored against the same full
        -- 160x144 battle space as the classic move layer. Capture them on a
        -- dedicated transparent canvas and let Battle Art's fxCard put the toss,
        -- opening particles, shake and settled ball inside the 3D arena.
        if ballEligible then
          local c=battleArtWorldFx.canvases.pokeball
          if not c then
            local okC,newc=pcall(g.newCanvas,160,144)
            if okC and newc then c=newc; battleArtWorldFx.canvases.pokeball=c; pcall(c.setFilter,c,"nearest","nearest") end
          end
          if c then
            local prev=g.getCanvas and g.getCanvas() or nil
            local okDraw=pcall(function()
              g.push("all"); g.origin(); g.setCanvas(c); g.clear(0,0,0,0)
              g.setBlendMode("alpha"); g.setColor(1,1,1,1)
              pokeballEntry:draw(battle)
              pokeballCapture:draw(battle)
              g.pop()
            end)
            if not okDraw then pcall(g.pop,g) end
            if prev then pcall(g.setCanvas,g,prev) else pcall(g.setCanvas,g) end
            if okDraw then fxCanvases.pokeball=c end
          end
        end
      end
      -- Safe Battle Art battler texture-affine path. Rotation and X/Y scaling are
      -- applied only to the already-generated battler texture around Battle Art's
      -- own anchor. BattleScene still renders its ordinary world card/matrix;
      -- no 3D renderer function is wrapped or replaced for this feature.
      local tiltRestore={}
      local tiltNow=moveEligible and ((bridge.voxelBattlerAffine and bridge:voxelBattlerAffine(battle,true,"battle_art")) or (bridge.voxelBattlerTilt and bridge:voxelBattlerTilt(battle,true,"battle_art"))) or nil
      if tiltNow and type(textures)=="table" and love and love.graphics then
        local g=love.graphics
        for side,desc in pairs(tiltNow) do
          local tex=textures[side]
          local src=tex and tex.canvas
          if src and type(src.getDimensions)=="function" then
            local cw,ch=src:getDimensions()
            local tc=battleArtWorldFx.tiltCanvases[side]
            if not tc or tc:getWidth()~=cw or tc:getHeight()~=ch then
              local okC,newc=pcall(g.newCanvas,cw,ch,{dpiscale=1})
              if okC and newc then
                tc=newc; battleArtWorldFx.tiltCanvases[side]=tc
                pcall(tc.setFilter,tc,"nearest","nearest")
              else
                tc=nil
              end
            end
            if tc then
              local img=desc.battler and voxelCompat:battlerImage(battle,desc.battler) or nil
              local ih=56
              if img and type(img.getDimensions)=="function" then
                local _,h=img:getDimensions()
                ih=tonumber(h) or ih
              end
              local px=tonumber(tex.ax) or (cw/2)
              local py=(tonumber(tex.ay) or 96)-(ih/2)
              local angle=tonumber(desc.angle) or 0
              local dx=tonumber(desc.dx) or 0
              local dy=tonumber(desc.dy) or 0
              local sx=tonumber(desc.scaleX) or 1
              local sy=tonumber(desc.scaleY) or 1
              local acid=type(desc.acidArmor)=="table" and desc.acidArmor or nil
              -- Battle Art mirrors the player card after texturing. Pre-rotated /
              -- pre-translated pixels therefore use the opposite source signs
              -- so the final visible pose matches FireRed.
              if desc.battler and voxelCompat:mirrorX(staged,desc.battler) then
                angle=-angle; dx=-dx
              end
              local prev=g.getCanvas and g.getCanvas() or nil
              local okTilt=pcall(function()
                g.push("all"); g.origin(); g.setCanvas(tc); g.clear(0,0,0,0)
                g.setBlendMode("alpha"); g.setColor(1,1,1,1)
                g.translate(dx,dy)
                -- Rotation stays centred on the visible Pokemon like v0.55.43.
                -- Growth scaling is anchored at Battle Art's battler baseline so
                -- the Pokemon grows upward instead of sinking through its cell.
                if math.abs(angle)>0.000001 then
                  g.translate(px,py); g.rotate(angle); g.translate(-px,-py)
                end
                if math.abs(sx-1)>0.000001 or math.abs(sy-1)>0.000001 then
                  local scalePivotY=tonumber(tex.ay) or 96
                  g.translate(px,scalePivotY); g.scale(sx,sy); g.translate(-px,-scalePivotY)
                end
                if acid then
                  -- Acid Armor must remain on Battle Art's real world-space card.
                  -- Warp the already-generated battler texture scanline by
                  -- scanline, preserving its texture-space Y exactly (the
                  -- corrected v0.56.12 2D behavior), then let Potato place the
                  -- transformed canvas with its ordinary world matrix.
                  local aa=tonumber(acid.alpha) or 1
                  if aa<0 then aa=0 elseif aa>1 then aa=1 end
                  g.setColor(1,1,1,aa)
                  if aa>0 then
                    local age=math.max(0,math.floor(tonumber(acid.age) or 0))
                    for yy=0,ch-1 do
                      local phase=((age*2)+(yy*10))%256
                      local wave=math.sin(phase*math.pi*2/256)*4
                      local quad=g.newQuad(0,yy,cw,1,cw,ch)
                      g.draw(src,quad,wave,yy)
                    end
                  end
                else
                  -- Transform switches graphics at maximum mosaic.  The bridge
                  -- supplies gen1recomp's own side-correct speciesSprite; draw
                  -- it into Battle Art's existing card texture at the same feet
                  -- anchor before applying the exact same mosaic pass.
                  local mosaicSource=src
                  local replacement=desc.replacementImage
                  if replacement and type(replacement.getDimensions)=="function" then
                    local rc=battleArtWorldFx.transformReplacementCanvases and battleArtWorldFx.transformReplacementCanvases[side] or nil
                    if not battleArtWorldFx.transformReplacementCanvases then battleArtWorldFx.transformReplacementCanvases={} end
                    if not rc or rc:getWidth()~=cw or rc:getHeight()~=ch then
                      local okR,newr=pcall(g.newCanvas,cw,ch,{dpiscale=1})
                      if okR and newr then rc=newr; battleArtWorldFx.transformReplacementCanvases[side]=rc; pcall(rc.setFilter,rc,"nearest","nearest") else rc=nil end
                    end
                    if rc then
                      local rw,rh=replacement:getDimensions()
                      local ax=tonumber(tex.ax) or (cw/2)
                      local ay=tonumber(tex.ay) or 96
                      g.setCanvas(rc); g.clear(0,0,0,0); g.origin(); g.setColor(1,1,1,1)
                      g.draw(replacement,ax-rw/2,ay-rh)
                      mosaicSource=rc
                    end
                  end
                  local block=math.max(1,math.floor(tonumber(desc.mosaicSize) or 1))
                  if block>1 then
                    local lw,lh=math.max(1,math.ceil(cw/block)),math.max(1,math.ceil(ch/block))
                    local mc=battleArtWorldFx.mosaicCanvases[side]
                    if not mc or mc:getWidth()~=lw or mc:getHeight()~=lh then
                      local okM,newm=pcall(g.newCanvas,lw,lh,{dpiscale=1})
                      if okM and newm then mc=newm; battleArtWorldFx.mosaicCanvases[side]=mc; pcall(mc.setFilter,mc,"nearest","nearest") else mc=nil end
                    end
                    if mc then
                      g.setCanvas(mc); g.clear(0,0,0,0); g.origin(); g.setColor(1,1,1,1); g.draw(mosaicSource,0,0,0,lw/cw,lh/ch)
                      g.setCanvas(tc); g.origin(); g.setColor(1,1,1,1); g.draw(mc,0,0,0,cw/lw,ch/lh)
                    else
                      g.draw(mosaicSource,0,0)
                    end
                  else
                    g.draw(mosaicSource,0,0)
                  end
                end
                g.pop()
              end)
              if not okTilt then pcall(g.pop,g) end
              if prev then pcall(g.setCanvas,g,prev) else pcall(g.setCanvas,g) end
              if okTilt then
                local copy={}
                for k,v in pairs(tex) do copy[k]=v end
                copy.canvas=tc
                tiltRestore[side]=tex
                textures[side]=copy
              end
            end
          end
        end
      end

      local function restoreTiltTextures()
        if type(textures)=="table" then
          for side,tex in pairs(tiltRestore) do textures[side]=tex end
        end
      end

      if not next(fxCanvases) and not backgroundCanvas then
        local results={pcall(originalRender,state,arena,textures,token,battleParam,drawActors,externalCamera,externalModelShadow)}
        restoreTiltTextures()
        if not results[1] then error(results[2],0) end
        table.remove(results,1)
        return unpack(results)
      end

      local innerGlass=Voxel3D.glass
      local innerSeams=Voxel3D.seams
      local innerDraw=Voxel3D.draw
      -- FireRed animation art is authored screen art, not world material.
      -- Cancel the staged renderer's day/night tint and opt out of sun/shadow
      -- reception so ROM palette colors stay exact over trees, flowers, etc.
      local function fireRedDraw(mesh,tex,model,pull,r,g,b,alpha)
        local tint=Voxel3D.tint or {1,1,1}
        local function untint(v,i)
          local t=tonumber(tint[i]) or 1
          if t < 0.05 then t=0.05 end
          return (tonumber(v) or 1)/t
        end
        love.graphics.setColor(untint(r,1),untint(g,2),untint(b,3),alpha or 1)
        innerDraw(mesh,tex,model,pull,nil,false)
      end
      local sawCardPass=false
      local injected=false
      local vegetationDepthMasked=false
      local backgroundInjected=false

      -- Ground-category effects belong at the battler's feet, but they must
      -- composite in front of the battler base.  Keep them out of the normal
      -- pre-card effect pass and draw them once at the post-card seam.  This
      -- is shared by Potato and Battle Art so every GROUND effect follows the
      -- same ordering rather than relying on move-specific fixes.
      local function drawGroundForeground()
        if not a then return false end
        local host=(arena and arena.map) or (state and state.map)
        local groundY=host and BattleScene.groundY(host,arena) or nil
        local mesh=BattleBillboard.mesh and BattleBillboard.mesh() or nil
        if not (arena and mesh and groundY) then return false end
        local any=false
        local function drawOne(tex,side)
          if not tex then return end
          local battler=(side=="target") and a.targetBattler or a.attackerBattler
          local cell=battler and battler.isPlayer and arena.player or arena.enemy
          if not cell then return end
          local authored,groundDropPx=voxelLocalAuthoredAnchor(staged,battler,VoxelCategories.GROUND,a and a.move and a.move.id)
          if not authored then return end
          local pw,ph=tex:getDimensions()
          local w,h=BattleBillboard.sizeFor(pw,ph)
          local unit=BattleBillboard.FULL_W/BattleBillboard.FULL_PIC
          local ax=(authored[1]-pw/2)*unit
          local ay=(ph-authored[2])*unit
          local yaw=BattleBillboard.yawToward(cell[1],cell[2],Voxel3D.eye)
          local baseY=groundY-(groundDropPx or 0)*unit
          local base=Mat4.mul(Mat4.translate(cell[1],baseY,cell[2]),Mat4.rotateY(yaw))
          local modelLocal=Mat4.mul(base,Mat4.mul(Mat4.translate(-ax,-ay,0),Mat4.scale(w,h,1)))
          innerSeams(false); innerGlass(false)
          pcall(love.graphics.setDepthMode,"always",false)
          love.graphics.setColor(1,1,1,1)
          fireRedDraw(mesh,tex,modelLocal,(BattleBillboard.PULL or 0)+7,1,1,1,1)
          love.graphics.setColor(1,1,1,1)
          pcall(love.graphics.setDepthMode,"lequal",true)
          innerGlass(false); innerSeams(false)
          any=true
        end
        drawOne(fxCanvases.groundAttacker,"attacker")
        drawOne(fxCanvases.groundTarget,"target")
        if any then battle._fireredWorldFxFrame=a.frame end
        return any
      end

      -- Potato/Battle Art may draw grass and flowers after the battler-card
      -- pass. Preserve the existing visible OAM/battler ordering, then stamp
      -- only the already-visible FireRed effect silhouettes into depth before
      -- that final vegetation pass. Their voxel shader discards transparent
      -- texels, so this protects sprite pixels without creating rectangular
      -- depth cards around them.
      local function writeVegetationDepthMask()
        if vegetationDepthMasked or not injected then return end
        vegetationDepthMasked=true
        local g=love and love.graphics
        if not (g and type(g.setColorMask)=="function") then return end
        local host=(arena and arena.map) or (state and state.map)
        local groundY=host and BattleScene.groundY(host,arena) or nil
        local anchors=OverworldBattle.ANCHOR
        local model=groundY and anchors and BattleScene.fxCard(arena,groundY,anchors) or nil
        local mesh=BattleBillboard.mesh and BattleBillboard.mesh() or nil
        if not (mesh and groundY) then return end
        local okMask=pcall(function()
          innerSeams(false); innerGlass(false)
          g.setColorMask(false,false,false,false)
          g.setDepthMode("always",true)
          g.setColor(1,1,1,1)
          if model and fxCanvases.arena then
            fireRedDraw(mesh,fxCanvases.arena,model,(BattleBillboard.PULL or 0)+6,1,1,1,1)
          end
          if model and fxCanvases.pokeball then
            fireRedDraw(mesh,fxCanvases.pokeball,model,(BattleBillboard.PULL or 0)+8,1,1,1,1)
          end
          local function maskLocal(tex,side,category,pull)
            if not (tex and arena and a) then return end
            local battler=(side=="target") and a.targetBattler or a.attackerBattler
            local cell=battler and battler.isPlayer and arena.player or arena.enemy
            if not cell then return end
            local authored,groundDropPx=voxelLocalAuthoredAnchor(staged,battler,category,a and a.move and a.move.id)
            if not authored then return end
            local pw,ph=tex:getDimensions()
            local w,h=BattleBillboard.sizeFor(pw,ph)
            local unit=BattleBillboard.FULL_W/BattleBillboard.FULL_PIC
            local ax=(authored[1]-pw/2)*unit
            local ay=(ph-authored[2])*unit
            local yaw=BattleBillboard.yawToward(cell[1],cell[2],Voxel3D.eye)
            local baseY=groundY-(groundDropPx or 0)*unit
            local base=Mat4.mul(Mat4.translate(cell[1],baseY,cell[2]),Mat4.rotateY(yaw))
            local mm=Mat4.mul(base,Mat4.mul(Mat4.translate(-ax,-ay,0),Mat4.scale(w,h,1)))
            innerDraw(mesh,tex,mm,pull)
          end
          maskLocal(fxCanvases.uprightAttacker,"attacker",VoxelCategories.UPRIGHT,(BattleBillboard.PULL or 0)+7)
          maskLocal(fxCanvases.uprightTarget,"target",VoxelCategories.UPRIGHT,(BattleBillboard.PULL or 0)+7)
          maskLocal(fxCanvases.groundAttacker,"attacker",VoxelCategories.GROUND,(BattleBillboard.PULL or 0)+5)
          maskLocal(fxCanvases.groundTarget,"target",VoxelCategories.GROUND,(BattleBillboard.PULL or 0)+5)

          local dt=a and bridge.doubleTeamWorldClones and bridge:doubleTeamWorldClones(battle) or nil
          if dt and dt.image and dt.offsets and arena then
            local cell=dt.battler and dt.battler.isPlayer and arena.player or arena.enemy
            if cell then
              local iw,ih=dt.image:getDimensions()
              local w,h=BattleBillboard.sizeFor(iw,ih)
              if dt.mirrorX then w=-w end
              local yaw=BattleBillboard.yawToward(cell[1],cell[2],Voxel3D.eye)
              local unit=BattleBillboard.FULL_W/BattleBillboard.FULL_PIC
              local base=Mat4.mul(Mat4.translate(cell[1],groundY,cell[2]),Mat4.rotateY(yaw))
              for _,dx in ipairs(dt.offsets) do
                local localModel=Mat4.mul(Mat4.translate((tonumber(dx) or 0)*unit,0,0),Mat4.scale(w,h,1))
                innerDraw(mesh,dt.image,Mat4.mul(base,localModel),(BattleBillboard.PULL or 0)+7)
              end
            end
          end
          local mn=a and bridge.minimizeWorldClones and bridge:minimizeWorldClones(battle) or nil
          if mn and mn.image and mn.clones and arena then
            local cell=mn.battler and mn.battler.isPlayer and arena.player or arena.enemy
            if cell then
              local iw,ih=mn.image:getDimensions()
              local baseW,baseH=BattleBillboard.sizeFor(iw,ih)
              local yaw=BattleBillboard.yawToward(cell[1],cell[2],Voxel3D.eye)
              for _,cl in ipairs(mn.clones) do
                local k=tonumber(cl.scale) or 1
                local w,h=baseW*k,baseH*k
                if mn.mirrorX then w=-w end
                innerDraw(mesh,mn.image,BattleBillboard.matrix(cell[1],groundY,cell[2],w,h,yaw),(BattleBillboard.PULL or 0)+7)
              end
            end
          end
          local ns=a and bridge.nightShadeWorldClone and bridge:nightShadeWorldClone(battle) or nil
          if ns and ns.image and arena then
            local cell=ns.battler and ns.battler.isPlayer and arena.player or arena.enemy
            if cell then
              local iw,ih=ns.image:getDimensions()
              local w,h=BattleBillboard.sizeFor(iw,ih)
              local k=tonumber(ns.scale) or 1
              w,h=w*k,h*k
              if ns.mirrorX then w=-w end
              local yaw=BattleBillboard.yawToward(cell[1],cell[2],Voxel3D.eye)
              innerDraw(mesh,ns.image,BattleBillboard.matrix(cell[1],groundY,cell[2],w,h,yaw),(BattleBillboard.PULL or 0)+7)
            end
          end
        end)
        pcall(g.setColorMask,true,true,true,true)
        pcall(g.setDepthMode,"lequal",true)
        pcall(g.setColor,1,1,1,1)
        innerGlass(true)
        if not okMask then vegetationDepthMasked=false end
      end
      -- FireRed move backgrounds are presentation backdrops, not a second
      -- renderer. Inject the background once after Potato has finished its 3D
      -- world/vegetation pass and immediately before Potato draws battler cards.
      -- Everything above that seam (battlers, affine transforms, clones and
      -- move effects) keeps using Battle Art's normal, already-correct render path.
      Voxel3D.glass=function(on,...)
        if on==false then
          if backgroundCanvas and not backgroundInjected then
            local okBgInject=pcall(function()
              local host=(arena and arena.map) or (state and state.map)
              local groundY=host and BattleScene.groundY(host,arena) or nil
              local anchors=OverworldBattle.ANCHOR
              local model=groundY and anchors and BattleScene.fxCard(arena,groundY,anchors) or nil
              local mesh=BattleBillboard.mesh and BattleBillboard.mesh() or nil
              if model and mesh then
                -- This is a presentation background, not world geometry. Draw
                -- it after the finished world/vegetation and before Battle Art's
                -- battler cards, ignoring world depth exactly like the old
                -- background-before-actors ordering.
                pcall(love.graphics.setDepthMode,"always",false)
                love.graphics.setColor(1,1,1,1)
                fireRedDraw(mesh,backgroundCanvas,model,(BattleBillboard.PULL or 0)+4,1,1,1,1)
                love.graphics.setColor(1,1,1,1)
                pcall(love.graphics.setDepthMode,"lequal",true)
                backgroundInjected=true
                battle._fireredWorldBgFrame=a and a.frame or true
              end
            end)
            if not okBgInject then backgroundInjected=false end
          end
        elseif on==true and sawCardPass and not injected then
          injected=true
          local okInject=pcall(function()
            local host=(arena and arena.map) or (state and state.map)
            local groundY=host and BattleScene.groundY(host,arena) or nil
            local anchors=OverworldBattle.ANCHOR
            local model=groundY and anchors and BattleScene.fxCard(arena,groundY,anchors) or nil
            local mesh=BattleBillboard.mesh and BattleBillboard.mesh() or nil
            if model and mesh and fxCanvases.arena then
              -- Battle-animation sprites are foreground actors relative to the
              -- voxel scenery.  Use an always-pass depth test so trees/grass
              -- cannot punch through effects such as Constrict tendrils.
              pcall(love.graphics.setDepthMode,"always",false)
              fireRedDraw(mesh,fxCanvases.arena,model,(BattleBillboard.PULL or 0)+6,1,1,1,1)
              pcall(love.graphics.setDepthMode,"lequal",true)
            end
            if model and mesh and fxCanvases.pokeball then
              -- A hair farther camera-ward than ordinary move effects so the
              -- ball remains readable when crossing a battler card, matching
              -- the original OAM layering while still depth-testing in world.
              fireRedDraw(mesh,fxCanvases.pokeball,model,(BattleBillboard.PULL or 0)+8,1,1,1,1)
              battle._fireredWorldBallToken=token or true
            else
              battle._fireredWorldBallToken=nil
            end

            -- Local category canvases are full authored 160x144 battle layers,
            -- but unlike the arena plane they are attached to one battler and
            -- always face the camera. Align that canvas' authored battler anchor
            -- exactly to the battler's world cell; this removes the pair-plane
            -- tilt while preserving every sprite's native relative coordinates.
            local function drawLocalCanvas(tex,side,category,pull)
              if not (tex and arena and mesh and groundY) then return false end
              if not a then return false end
              local battler=(side=="target") and a.targetBattler or a.attackerBattler
              local cell=battler and battler.isPlayer and arena.player or arena.enemy
              if not cell then return false end
              local authored,groundDropPx=voxelLocalAuthoredAnchor(staged,battler,category,a and a.move and a.move.id)
              if not authored then return false end
              local pw,ph=tex:getDimensions()
              local w,h=BattleBillboard.sizeFor(pw,ph)
              local unit=BattleBillboard.FULL_W/BattleBillboard.FULL_PIC
              local ax=(authored[1]-pw/2)*unit
              local ay=(ph-authored[2])*unit
              local yaw=BattleBillboard.yawToward(cell[1],cell[2],Voxel3D.eye)
              local baseY=groundY-(groundDropPx or 0)*unit
              local base=Mat4.mul(Mat4.translate(cell[1],baseY,cell[2]),Mat4.rotateY(yaw))
              local modelLocal=Mat4.mul(base,Mat4.mul(Mat4.translate(-ax,-ay,0),Mat4.scale(w,h,1)))
              Voxel3D.seams(false); Voxel3D.glass(false)
              pcall(love.graphics.setDepthMode,"always",false)
              love.graphics.setColor(1,1,1,1)
              fireRedDraw(mesh,tex,modelLocal,pull,1,1,1,1)
              love.graphics.setColor(1,1,1,1)
              pcall(love.graphics.setDepthMode,"lequal",true)
              Voxel3D.glass(false); Voxel3D.seams(false)
              return true
            end
            local anyLocal=false
            anyLocal=drawLocalCanvas(fxCanvases.uprightAttacker,"attacker","upright",(BattleBillboard.PULL or 0)+7) or anyLocal
            anyLocal=drawLocalCanvas(fxCanvases.uprightTarget,"target","upright",(BattleBillboard.PULL or 0)+7) or anyLocal
            -- GROUND canvases are deliberately deferred until after the
            -- battler-card pass; see drawGroundForeground().
            if a and model and mesh and (fxCanvases.arena or anyLocal) then battle._fireredWorldFxFrame=a.frame end

            -- Double Team's two copies are local battler actors just like the
            -- Night Shade clone: keep them inside Battle Art's 3D scene instead
            -- of drawing projected copies over the HUD.  Their FireRed x
            -- offsets are authored pixels; convert those to the same world
            -- unit scale Potato uses for 56px battler cards, then translate
            -- along the camera-facing billboard's local X axis.
            local dt=a and bridge.doubleTeamWorldClones and bridge:doubleTeamWorldClones(battle) or nil
            if dt and dt.image and dt.offsets and arena then
              local cell=dt.battler and dt.battler.isPlayer and arena.player or arena.enemy
              if cell then
                local iw,ih=dt.image:getDimensions()
                local w,h=BattleBillboard.sizeFor(iw,ih)
                if dt.mirrorX then w=-w end
                local yaw=BattleBillboard.yawToward(cell[1],cell[2],Voxel3D.eye)
                local unit=BattleBillboard.FULL_W/BattleBillboard.FULL_PIC
                local base=Mat4.mul(Mat4.translate(cell[1],groundY,cell[2]),Mat4.rotateY(yaw))
                local d=math.max(0,math.min(1,tonumber(dt.darkMul) or (5/16)))
                local alpha=math.max(0,math.min(1,tonumber(dt.alpha) or (12/16)))
                Voxel3D.seams(false)
                Voxel3D.glass(false)
                Voxel3D.blend("alpha")
                pcall(love.graphics.setDepthMode,"always",false)
                for _,dx in ipairs(dt.offsets) do
                  local localModel=Mat4.mul(Mat4.translate((tonumber(dx) or 0)*unit,0,0),Mat4.scale(w,h,1))
                  local dtModel=Mat4.mul(base,localModel)
                  fireRedDraw(mesh,dt.image,dtModel,(BattleBillboard.PULL or 0)+7,d,d,d,alpha)
                end
                love.graphics.setColor(1,1,1,1)
                pcall(love.graphics.setDepthMode,"lequal",true)
                Voxel3D.blend(nil)
                Voxel3D.glass(false)
                Voxel3D.seams(false)
              end
            end

            -- Minimize's translucent traces are actor-like copies of the
            -- attacker. The real battler shrink/grow is already applied by the
            -- safe texture-affine path above; render only the temporary traces
            -- here as camera-facing billboards rooted at the same world cell.
            local mn=a and bridge.minimizeWorldClones and bridge:minimizeWorldClones(battle) or nil
            if mn and mn.image and mn.clones and arena then
              local cell=mn.battler and mn.battler.isPlayer and arena.player or arena.enemy
              if cell then
                local iw,ih=mn.image:getDimensions()
                local baseW,baseH=BattleBillboard.sizeFor(iw,ih)
                local yaw=BattleBillboard.yawToward(cell[1],cell[2],Voxel3D.eye)
                Voxel3D.seams(false)
                Voxel3D.glass(false)
                Voxel3D.blend("alpha")
                pcall(love.graphics.setDepthMode,"always",false)
                for _,cl in ipairs(mn.clones) do
                  local k=tonumber(cl.scale) or 1
                  local w,h=baseW*k,baseH*k
                  if mn.mirrorX then w=-w end
                  local mm=BattleBillboard.matrix(cell[1],groundY,cell[2],w,h,yaw)
                  fireRedDraw(mesh,mn.image,mm,(BattleBillboard.PULL or 0)+7,1,1,1,math.max(0,math.min(1,tonumber(cl.alpha) or (10/16))))
                end
                love.graphics.setColor(1,1,1,1)
                pcall(love.graphics.setDepthMode,"lequal",true)
                Voxel3D.blend(nil)
                Voxel3D.glass(false)
                Voxel3D.seams(false)
              end
            end

            -- Night Shade's clone is an actor on the attacker's own cell,
            -- not a sprite spanning the two-slot move plane. Draw it as a
            -- dedicated camera-facing billboard so it stands perfectly
            -- upright, keeps its feet on the ground, and preserves FireRed's
            -- live alpha/scale timeline.
            local ns=a and bridge.nightShadeWorldClone and bridge:nightShadeWorldClone(battle) or nil
            if ns and ns.image and arena then
              local cell=ns.battler and ns.battler.isPlayer and arena.player or arena.enemy
              if cell then
                local iw,ih=ns.image:getDimensions()
                local w,h=BattleBillboard.sizeFor(iw,ih)
                local k=tonumber(ns.scale) or 1
                w,h=w*k,h*k
                if ns.mirrorX then w=-w end
                local yaw=BattleBillboard.yawToward(cell[1],cell[2],Voxel3D.eye)
                local nsModel=BattleBillboard.matrix(cell[1],groundY,cell[2],w,h,yaw)
                Voxel3D.seams(false)
                Voxel3D.glass(false)
                Voxel3D.blend("alpha")
                pcall(love.graphics.setDepthMode,"always",false)
                fireRedDraw(mesh,ns.image,nsModel,(BattleBillboard.PULL or 0)+7,1,1,1,math.max(0,math.min(1,tonumber(ns.alpha) or 0)))
                love.graphics.setColor(1,1,1,1)
                pcall(love.graphics.setDepthMode,"lequal",true)
                Voxel3D.blend(nil)
                Voxel3D.glass(false)
                Voxel3D.seams(false)
              end
            end
          end)
          if not okInject then injected=false end
        end
        return innerGlass(on,...)
      end
      -- BattleScene has exactly one seams(false) transition: after all arena
      -- terrain/vegetation (including custom foreground leaves) and immediately
      -- before battler cards. Inject FireRed foreground effects at that seam so
      -- no voxel vegetation can be drawn over them afterward.
      if type(innerSeams)=="function" then
        Voxel3D.seams=function(on,...)
          if on==false and not injected then
            sawCardPass=true
            -- Reuse the normal injection branch without changing its drawing
            -- behavior; BattleScene itself sets glass(false) immediately next.
            Voxel3D.glass(true)
            sawCardPass=false
          elseif on==true and injected and not vegetationDepthMasked then
            -- GROUND effects are authored at the battler's feet and should
            -- composite over the battler base, so draw the entire shared
            -- GROUND path here, after the cards and before any late foliage.
            drawGroundForeground()
            -- Then stamp the depth-only protection for all FireRed effects so
            -- Potato's late grass/flower pass cannot cover them.
            writeVegetationDepthMask()
          end
          return innerSeams(on,...)
        end
      end
      -- FireRed Double Team disables the attacker's monbg while the two clone
      -- OBJs are active. Battle Art owns its battlers as 3D cards, so the host
      -- picFx.hidden flag cannot guarantee that card disappears. Temporarily
      -- remove only the attacker's Battle Art texture for this render pass; the
      -- dedicated world clone billboards above remain available from the
      -- FireRed bridge and the texture is restored immediately afterward.
      local hiddenDtKey=nil
      local hiddenDtTexture=nil
      local dtNow=moveEligible and bridge.doubleTeamWorldClones and bridge:doubleTeamWorldClones(battle) or nil
      if dtNow and dtNow.battler and type(textures)=="table" then
        hiddenDtKey=dtNow.battler.isPlayer and "player" or "enemy"
        hiddenDtTexture=textures[hiddenDtKey]
        textures[hiddenDtKey]=nil
      end
      local results={pcall(originalRender,state,arena,textures,token,battleParam,drawActors,externalCamera,externalModelShadow)}
      if hiddenDtKey then textures[hiddenDtKey]=hiddenDtTexture end
      restoreTiltTextures()
      Voxel3D.glass=innerGlass
      if innerSeams then Voxel3D.seams=innerSeams end
      if not results[1] then error(results[2],0) end
      table.remove(results,1)
      return unpack(results)
    end
    battleArtWorldFx.installed=true
    return true
  end

  local applyFxBridge=ApplyFxBridge.new({log=mod.log})
  bridge.holdBattlerHidden=function(battle,battler,opts) return applyFxBridge:holdBattlerHidden(battle,battler,opts) end
  local statusBridge=StatusBridge.new({
    conditions=statusConditions,visualAssets=visualAssets,paletteRenderer=paletteRenderer,battleSpace=BattleSpace,
    playSound=function(soundId,pan,battle,gain,overlap)
      if audio then return audio.play(soundId,pan,battle,gain,overlap) end
      return nil,audioInitError or "FireRed audio unavailable"
    end,
    selfHitFeedback=function(battle,affected)
      applyFxBridge:startFireRedHit(battle,affected,{sfx="Damage"})
    end,
    log=mod.log,
  })
  applyFxBridge:add("status",function(battle,hit)
    local consumed=statusBridge:consumeApplyHitFx(battle,hit)
    if consumed then bridge:ackApplyHitFx(battle) end
    return consumed
  end)
  applyFxBridge:add("move-replacement",function(battle,hit) return bridge:consumeApplyHitFx(battle,hit) end)
  -- Audio remains isolated: registration happens now, but expensive ROM/M4A
  -- rendering is deferred to the first-overworld cache builder.
  do
    local ok,result=pcall(NativeAudio.new,{mod=mod,M4ARuntime=M4ARuntime,WavPcm=WavPcm,renderSong=renderSong,catalog=SoundCatalog,soundIds=registry:soundIds(),battleSfx=BattleSfx,extraSoundIds=(function() local out=statusConditions:soundIds(); for _,id in ipairs(statFeedback:soundIds()) do out[#out+1]=id end; for _,id in ipairs(pokeballEntry:soundIds()) do out[#out+1]=id end; return out end)()})
    if ok then audio=result else audioInitError=tostring(result); mod.log:warn("FireRed audio disabled; visuals remain active: %s",audioInitError) end
  end

  -- Build ROM-derived runtime resources only after the player first enters the
  -- overworld. The modal prompt blocks gameplay until A is pressed and every
  -- job completes; the progress window advances between jobs so the player can
  -- see exactly what is being cached.
  -- These are runtime-only LÖVE image objects. They cannot persist across
  -- launches, so prepare them silently on first world entry. They are not a
  -- reason to show the persistent-cache rebuild UI.
  local runtimeJobs={
    {label="Battle backgrounds",run=function()
      local ok,why=battleBgAssets:prepare("ghost"); if not ok then return nil,why end
      ok,why=battleBgAssets:prepare("thunder"); if not ok then return nil,why end
      ok,why=battleBgAssets:prepare("guillotine_opponent"); if not ok then return nil,why end
      ok,why=battleBgAssets:prepare("guillotine_player"); if not ok then return nil,why end
      ok,why=battleBgAssets:prepare("surf_player"); if not ok then return nil,why end
      ok,why=battleBgAssets:prepare("surf_opponent"); if not ok then return nil,why end
      return true
    end},
    {label="Move sprites",run=function()
      local ok,why=precache:prepareVisuals(); if not ok then return nil,why end; return true
    end},
    {label="Metal shine",run=function()
      local ok,why=metalShineAssets:prepare(); if not ok then return nil,why end; return true
    end},
    {label="Stat-change mask",run=function()
      local ok,why=statMaskAssets:prepare(); if not ok then return nil,why end; return true
    end},
    {label="Poké Ball send-out",run=function()
      local ok,why=pokeballEntry:prepare(); if not ok then return nil,why end; return true
    end},
    {label="Poké Ball capture",run=function()
      local ok,why=pokeballCapture:prepare(); if not ok then return nil,why end; return true
    end},
    {label="Status effects",run=function()
      local ok,why=statusBridge:prepare(); if not ok then return nil,why end; return true
    end},
    {label="Kinesis Alert resource",run=function()
      -- Prepare each Kinesis resource independently. A failure in Bent Spoon
      -- must never suppress the already-working Alert/zap sheet.
      local kinesis=registry:get("KINESIS")
      local alertDef={templates={gKinesisZapEnergySpriteTemplate=kinesis.templates.gKinesisZapEnergySpriteTemplate}}
      local called,ok,why=pcall(visualAssets.prepareDeferred,visualAssets,alertDef)
      if (not called or not ok) and mod.log then
        mod.log:warn("FireRed Kinesis Alert sprite unavailable: %s",tostring(called and why or ok))
      end
      return true
    end},
    {label="Kinesis Bent Spoon resource",run=function()
      local kinesis=registry:get("KINESIS")
      local spoonDef={templates={gBentSpoonSpriteTemplate=kinesis.templates.gBentSpoonSpriteTemplate}}
      local called,ok,why=pcall(visualAssets.prepareDeferred,visualAssets,spoonDef)
      if (not called or not ok) and mod.log then
        mod.log:warn("FireRed Kinesis Bent Spoon unavailable: %s",tostring(called and why or ok))
      end
      return true
    end},
    {label="Glare resources",run=function()
      -- Glare's new resources are deliberately isolated from the global Move
      -- sprites job. They prepare only after Poké Ball/status resources, and
      -- every failure is contained so Glare can never abort global startup.
      local glare=registry:get("GLARE")
      local called,ok,why=pcall(visualAssets.prepareDeferred,visualAssets,glare)
      if (not called or not ok) and mod.log then
        mod.log:warn("FireRed Glare sprites unavailable: %s",tostring(called and why or ok))
      end
      local bgCalled,bgOk,bgWhy=pcall(battleBgAssets.prepare,battleBgAssets,"scary_face_player")
      if (not bgCalled or not bgOk) and mod.log then
        mod.log:warn("FireRed Glare background unavailable: %s",tostring(bgCalled and bgWhy or bgOk))
      end
      return true
    end},
  }
  local cacheJobs={}
  if audio and type(audio.needsBuild)=="function" and audio.needsBuild() then
    local plan=type(audio.buildPlan)=="function" and audio.buildPlan() or {}
    for _,label in ipairs(plan) do
      cacheJobs[#cacheJobs+1]={label=label or "FireRed audio",run=function()
        local ok,why=audio.buildStep()
        if ok==nil or ok==false then return nil,why end
        return true
      end}
    end
  end
  StartupCache.install({mod=mod,runtimeJobs=runtimeJobs,jobs=cacheJobs})

  mod.events:on("battle.started",function(ev)
    activeBattle=ev and ev.battle or activeBattle
    statFeedback:reset()
    pokeballCapture:reset()
    if activeBattle then
      statusBridge:observeConfusion(activeBattle)
      statFeedback:beginBattle(activeBattle)
      applyFxBridge:attach(activeBattle)
      statusBridge:attach(activeBattle)
      pokeballEntry:attach(activeBattle)
    end
    if audio and not precache.audioReady then
      local b=ev and ev.battle
      local data=b and (b.data or (b.game and b.game.data))
      local ok,why=precache:warmAudio(audio,data)
      if not ok then mod.log:warn("FireRed all-move audio precache unavailable: %s",tostring(why)) end
    end
  end)
  mod.events:on("battle.status_inflicted",function(ev) statusBridge:onStatus(ev) end)
  -- Gen1Recomp intentionally omits the normal move-animation row on the first
  -- turn of a charge move. Keep the native charge decision unchanged, but use
  -- its guarded hook as the authoritative seam for FireRed setup animations.
  mod.hooks:wrap("battle.charge_required",function(next,ctx)
    local required=next(ctx)
    if required ~= false then bridge:onChargeRequired(ctx) end
    return required
  end)
  -- Thrash is special in Gen1Recomp: THRASH_PETAL_DANCE_EFFECT calls
  -- BattleState:animBeforeMove() and inserts SHRINKING_SQUARE_ANIM/ANIM_B1
  -- before the normal move row. FireRed Thrash/Petal Dance have no such Gen-I setup
  -- animation, so suppress it at creation time. Queue-time suppression is too
  -- late because this row can begin before the FireRed move row is discoverable.
  mod.hooks:wrap("battle.animBeforeMove",function(next,battle,name,isPlayer)
    -- THRASH_PETAL_DANCE_EFFECT sets battler.thrashMove immediately before
    -- calling animBeforeMove().  moveAnimRow does not exist yet here, so the
    -- locked move instance is the authoritative identity for this pre-row
    -- Gen-I setup animation.
    local battler=battle and (isPlayer and battle.player or battle.enemy)
    local locked=battler and battler.thrashMove
    local lockedId=type(locked)=="table" and locked.id or nil
    if (lockedId=="THRASH" or lockedId=="PETAL_DANCE")
       and (name=="SHRINKING_SQUARE_ANIM" or name=="ANIM_B1") then
      return nil
    end
    return next(battle,name,isPlayer)
  end)
  mod.events:on("battle.move_used",function(ev)
    -- Gen1Recomp deliberately substitutes THRASH for every locked rampage
    -- continuation.  Keep that stock behavior for Thrash, but Petal Dance's
    -- locked turns should replay the FireRed Petal Dance visual we registered.
    -- battle.move_used arrives after moveAnimRow has been queued and before it
    -- is consumed, so this is the narrowest seam: mechanics/text/countdown stay
    -- Gen-I faithful while only the visual row is restored to PETAL_DANCE.
    local b=ev and ev.battle
    local move=ev and ev.move
    local moveId=type(move)=="table" and move.id or nil
    local row=b and b.moveAnimRow
    -- Gen1Recomp clears thrashMove before emitting battle.move_used on the
    -- final locked turn.  The event's move is still the authoritative real
    -- move, so use it rather than the volatile lock to restore Petal Dance's
    -- FireRed visual on every continuation, including the last one.
    if moveId=="PETAL_DANCE" and type(row)=="table" and row.anim=="THRASH" then
      row.anim="PETAL_DANCE"
    end
    bridge:onMoveUsed(ev)
    statFeedback:onMoveUsed(ev)
  end)
  mod.events:on("battle.ball_thrown",function(ev) pokeballCapture:onBallThrown(ev) end)
  mod.events:on("battle.ended",function(ev)
    local b=(ev and ev.battle) or activeBattle
    bridge:reset("battle.ended")
    statusBridge:detach(b)
    applyFxBridge:detach(b)
    statFeedback:reset()
    statusBridge:reset(b)
    pokeballEntry:reset("battle.ended")
    pokeballCapture:reset()
    activeBattle=nil
  end)
  -- Move replacement must run on Gen1Recomp's fixed 60 Hz logic boundary,
  -- not once per rendered frame. core.update can contain several logic ticks
  -- under fast-forward/catch-up; input.step is called exactly once at the
  -- start of every Game:step, before BattleState advances its animation row.
  -- Advancing the active FireRed clock here keeps it in lockstep with the
  -- host waitFrames countdown and gives pending rows a chance to be claimed
  -- on every logic tick before the native animation can begin.
  mod.hooks:wrap("input.step",function(next,game,dt)
    pcall(ensurePotatoWorldFx)
    pcall(ensureBattleArtWorldFx)
    bridge:afterUpdate()
    pokeballEntry:afterUpdate()
    pokeballCapture:afterUpdate()
    bridge:beforeUpdate(activeBattle)
    pokeballEntry:beforeUpdate(activeBattle)
    -- Status and stat-change animations are FireRed 60 Hz battle animations.
    -- Advance both on the same fixed logic boundary as move replacement;
    -- core.update can run at a different cadence on high-refresh/catch-up
    -- paths and would make these effects play too quickly.
    statusBridge:afterUpdate()
    if activeBattle then statFeedback:afterUpdate(activeBattle) end
    return next(game,dt)
  end)
  mod.hooks:wrap("core.update",function(next,game,dt)
    statusBridge:beforeUpdate(); statFeedback:beforeUpdate()
    local result=next(game,dt)
    if activeBattle then
      -- A Thrash setup row can be created and started inside this host update,
      -- after input.step's pre-tick suppression has already run. Cancel that
      -- just-started Gen-I animation before battle.overlay renders it.
      bridge:cancelActiveThrashSetup(activeBattle)
      bridge:afterHostUpdate(activeBattle); pokeballEntry:afterHostUpdate(activeBattle); pokeballCapture:afterHostUpdate(activeBattle); applyFxBridge:afterUpdate(activeBattle); statusBridge:observeConfusion(activeBattle); statusBridge:applyBattlerMotion(activeBattle)
    end
    return result
  end)
  mod.hooks:wrap("battle.overlay",function(next,battle)
    next(battle)
    local staged=voxelCompat:state(battle)
    local a=bridge.active
    local worldBgDrawn=staged and (staged.provider=="potato_voxel" or staged.provider=="battle_art") and a
      and battle._fireredWorldBgFrame==a.frame
    if not worldBgDrawn then bridge:drawBackground(battle) end
    if staged and staged.ownership and staged.ownership.animationProjection then
      -- Battler-owned transforms stay on their established staged-battler path.
      bridge:draw(battle,{battlerLayerOnly=true})

      -- If the Potato in-world bridge successfully drew this exact FireRed
      -- frame inside BattleScene's 3D pass, do not draw a second flat copy.
      -- Otherwise retain v0.55.16's projected 2D behavior as a fail-safe.
      a=bridge.active
      local worldDrawn=(staged.provider=="potato_voxel" or staged.provider=="battle_art") and a
        and battle._fireredWorldFxFrame==a.frame
      if not worldDrawn then
        local ap=staged.authoredAnchors and staged.authoredAnchors.player
        local ae=staged.authoredAnchors and staged.authoredAnchors.enemy
        local pp=staged.projectedAnchors and staged.projectedAnchors.player
        local pe=staged.projectedAnchors and staged.projectedAnchors.enemy
        if ap and ae and pp and pe and love and love.graphics then
          local g=love.graphics
          local ax,ay=(ap[1]+ae[1])/2,(ap[2]+ae[2])/2
          local cx,cy=(pp[1]+pe[1])/2,(pp[2]+pe[2])/2
          local k=tonumber(staged.animationScale) or 1
          g.push()
          g.translate(cx-ax,cy-ay)
          if k~=1 then
            g.translate(ax,ay); g.scale(k,k); g.translate(-ax,-ay)
          end
          bridge:draw(battle,{effectLayerOnly=true})
          g.pop()
        else
          bridge:draw(battle,{effectLayerOnly=true})
        end
      end
    else
      bridge:draw(battle)
    end
    statusBridge:draw(battle)
    statFeedback:draw(battle)
    -- In Potato Voxel the ball layer is drawn inside the active 3D scene.
    -- Keep the old HUD path as a fail-safe if that in-world injection did not
    -- run for the current staged frame.
    if not (staged and (staged.provider=="potato_voxel" or staged.provider=="battle_art") and battle._fireredWorldBallToken) then
      pokeballEntry:draw(battle)
      pokeballCapture:draw(battle)
    end
    -- battle.overlay runs after the host text/menu layer. In staged voxel
    -- battles repaint that bottom UI once all FireRed animation overlays have
    -- been drawn so move sprites can never cover the command/message box.
    staged=staged or voxelCompat:state(battle)
    if staged then voxelCompat:repaintBottomUI(staged,battle) end
  end)

  mod.exports.fireredRomInfo=function() return {title=romInfo.title,gameCode=romInfo.gameCode,revision=romInfo.revision,size=rom:size()} end
  mod.exports.fireRedAudioInfo=function() return audio and audio.info() or {available=false,initError=audioInitError} end
  mod.exports.fireRedBattleBridgeInfo=function() return bridge:info() end
  mod.exports.fireRedVoxelCompatInfo=function() return voxelCompat:info(activeBattle) end
  mod.exports.fireRedVoxelCategories=function() return VoxelCategories.summary() end
  mod.exports.fireRedStatusBridgeInfo=function() return statusBridge:info() end
  mod.exports.fireRedPrecacheInfo=function() return precache:info() end
  mod.exports.fireRedStatChangeFeedbackInfo=function() return statFeedback:info() end
  mod.exports.fireRedPokeballEntryInfo=function() return pokeballEntry:info() end
  mod.exports.fireRedPokeballCaptureInfo=function() return pokeballCapture:info() end
  mod.log:info("v0.59.2-test loaded: Potato preserved + Battle Art world-effect backend")
end
