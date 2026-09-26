-- Shared battler palette-blend renderer.
-- FireRed battle animations manipulate OBJ palettes directly. Gen1Recomp
-- draws battlers as RGBA images, so reproduce the same operation at the
-- battler draw seam. One manager owns one wrapper per battle; moves and status
-- feedback register blend providers instead of stacking draw wrappers.
local M={}
M.__index=M

function M.new(opts)
  local self=setmetatable({},M)
  self.log=opts and opts.log
  self.shader=nil
  self.battles=setmetatable({},{__mode="k"})
  return self
end

function M:ensureShader()
  if self.shader~=nil then return self.shader end
  if not (love and love.graphics and love.graphics.newShader) then self.shader=false; return nil end
  local ok,shader=pcall(love.graphics.newShader,[[
    extern number frBlendAmount;
    extern vec3 frBlendColor;
    extern number frGrayAmount;
    vec4 effect(vec4 color, Image tex, vec2 tc, vec2 sc) {
      vec4 px = Texel(tex, tc) * color;
      if (px.a <= 0.0) return px;
      number gray=(px.r+px.g+px.b)/3.0;
      px.rgb=mix(px.rgb,vec3(gray),frGrayAmount);
      px.rgb = mix(px.rgb, frBlendColor, frBlendAmount);
      return px;
    }
  ]])
  if not ok then
    self.shader=false
    if self.log then self.log:warn("FireRed battler palette shader unavailable: %s",tostring(shader)) end
    return nil
  end
  self.shader=shader
  return shader
end

local function removeToken(list,token)
  for i=#list,1,-1 do
    if list[i]==token then table.remove(list,i); return true end
  end
  return false
end

-- getBlend(battler) -> amount 0..1, {r,g,b}, where FireRed RGB channels are 0..31.
local function normalizeBlendColor(color)
  if color == "white" then return {31,31,31} end
  if color == "black" then return {0,0,0} end
  if type(color) == "table" then return color end
  return {0,0,0}
end

function M:ensureMaskShader()
  if self.maskShader~=nil then return self.maskShader end
  if not (love and love.graphics and love.graphics.newShader) then self.maskShader=false; return nil end
  local ok,shader=pcall(love.graphics.newShader,[[
    extern Image frMask;
    extern number frMaskEVA;
    extern number frMaskEVB;
    extern number frGrayAmount;
    extern number frMaskScale;
    extern number frMaskYScale;
    extern vec2 frMaskOffset;
    extern number frMaskUseColor;
    extern vec3 frMaskColor;
    vec4 effect(vec4 color, Image tex, vec2 tc, vec2 sc) {
      vec4 px=Texel(tex,tc)*color;
      if (px.a<=0.0) return px;
      number gray=(px.r+px.g+px.b)/3.0;
      px.rgb=mix(px.rgb,vec3(gray),frGrayAmount);
      vec2 fireRedCoord=vec2(sc.x/max(frMaskScale,0.001), sc.y/max(frMaskYScale,0.001))+frMaskOffset;
      vec2 mtc=mod(fireRedCoord,256.0)/256.0;
      vec4 m=Texel(frMask,mtc);
      if (m.a>0.0) {
        // Preserve the ROM mask's light/dark energy bands when applying a
        // project color override.  Using max(r,g,b) flattened palettes such
        // as Attack (whose red channel is 1.0 in every visible shade), making
        // the whole battler look uniformly tinted and hiding the scroll.
        float maskIntensity=(m.r+m.g+m.b)/3.0;
        vec3 recolored=frMaskColor*maskIntensity;
        vec3 maskRgb=mix(m.rgb,recolored,frMaskUseColor);
        px.rgb=min(vec3(1.0),maskRgb*frMaskEVA+px.rgb*frMaskEVB);
      }
      return px;
    }
  ]])
  if not ok then self.maskShader=false; if self.log then self.log:warn("FireRed battler mask shader unavailable: %s",tostring(shader)) end; return nil end
  self.maskShader=shader; return shader
end

local function ensureState(self,battle)
  local state=self.battles[battle]
  if state then return state end
  state={original=battle.drawBattlerPic,providers={},maskProviders={},grayProviders={}}
  local renderer=self
  local wrapper
  wrapper=function(bb,battler,...)
    local amount,color=0,nil
    local grayAmount=0
    for i=#state.grayProviders,1,-1 do
      local p=state.grayProviders[i]
      local a=tonumber(p.getAmount(battler)) or 0
      if a>0 then grayAmount=math.max(0,math.min(1,a)); break end
    end
    local mask
    for i=#state.maskProviders,1,-1 do
      local p=state.maskProviders[i]
      local cfg=p.getMask(battler)
      if cfg and cfg.image and (tonumber(cfg.amount) or 0)>0 then mask=cfg; break end
    end
    if mask then
      local shader=renderer:ensureMaskShader()
      if shader then
        local g=love.graphics; local previous=g.getShader and g.getShader() or nil
        shader:send("frMask",mask.image)
        local ma=math.max(0,math.min(1,tonumber(mask.amount) or 0))
        shader:send("frMaskEVA",math.max(0,math.min(1,tonumber(mask.eva) or ma)))
        shader:send("frMaskEVB",math.max(0,math.min(1,tonumber(mask.evb) or (1-ma))))
        shader:send("frGrayAmount",grayAmount)
        shader:send("frMaskScale",tonumber(mask.displayScale) or 1)
        shader:send("frMaskYScale",tonumber(mask.yDisplayScale) or tonumber(mask.displayScale) or 1)
        shader:send("frMaskOffset",{tonumber(mask.x) or 0,tonumber(mask.y) or 0})
        local override=mask.color
        shader:send("frMaskUseColor",override and 1 or 0)
        shader:send("frMaskColor",override and {(override[1] or 0)/31,(override[2] or 0)/31,(override[3] or 0)/31} or {0,0,0})
        g.setShader(shader)
        local packed={pcall(state.original,bb,battler,...)}
        g.setShader(previous)
        if not packed[1] then error(packed[2]) end
        return unpack(packed,2)
      end
    end
    -- Newest provider wins when effects overlap. FireRed's script runner is
    -- effectively serial for the cases currently ported, but this makes the
    -- shared seam deterministic without leaving nested stale wrappers.
    for i=#state.providers,1,-1 do
      local p=state.providers[i]
      local a,c=p.getBlend(battler)
      a=tonumber(a) or 0
      if a>0 then amount,color=a,c; break end
    end
    local shader=(amount>0 or grayAmount>0) and renderer:ensureShader() or nil
    if not shader then return state.original(bb,battler,...) end
    local g=love.graphics
    local previous=g.getShader and g.getShader() or nil
    local c=normalizeBlendColor(color)
    shader:send("frBlendAmount",math.max(0,math.min(1,amount)))
    shader:send("frBlendColor",{(c[1] or 0)/31,(c[2] or 0)/31,(c[3] or 0)/31})
    shader:send("frGrayAmount",grayAmount)
    g.setShader(shader)
    local packed={pcall(state.original,bb,battler,...)}
    g.setShader(previous)
    if not packed[1] then error(packed[2]) end
    return unpack(packed,2)
  end
  state.wrapper=wrapper
  self.battles[battle]=state
  battle.drawBattlerPic=wrapper
  return state
end

function M:installMask(battle,getMask)
  if not battle or type(battle.drawBattlerPic)~="function" or type(getMask)~="function" then return nil end
  local state=ensureState(self,battle)
  local token={battle=battle,getMask=getMask,isMask=true}
  state.maskProviders[#state.maskProviders+1]=token
  return token
end

function M:installGrayscale(battle,getAmount)
  if not battle or type(battle.drawBattlerPic)~="function" or type(getAmount)~="function" then return nil end
  local state=ensureState(self,battle)
  local token={battle=battle,getAmount=getAmount,isGray=true}
  state.grayProviders[#state.grayProviders+1]=token
  return token
end

function M:install(battle,getBlend)
  if not battle or type(battle.drawBattlerPic)~="function" or type(getBlend)~="function" then return nil end
  local state=ensureState(self,battle)
  local token={battle=battle,getBlend=getBlend}
  state.providers[#state.providers+1]=token
  return token
end

function M:clear(token)
  if not token or not token.battle then return end
  local battle=token.battle
  local state=self.battles[battle]
  if not state then return end
  if token.isMask then removeToken(state.maskProviders,token) elseif token.isGray then removeToken(state.grayProviders,token) else removeToken(state.providers,token) end
  if #state.providers==0 and #state.maskProviders==0 and #state.grayProviders==0 then
    if battle.drawBattlerPic==state.wrapper then battle.drawBattlerPic=state.original end
    self.battles[battle]=nil
  end
end

return M
