-- Declarative FireRed move registry. Move files contain data only; runtime
-- behavior lives in shared engines under lib/.
local M = {}
M.__index = M

function M.new()
  return setmetatable({ byId={}, ordered={} }, M)
end

local function flatten(def, rootScript)
  local out, stack, pc, script = {}, {}, 1, rootScript or def.script
  while true do
    local cmd=script[pc]
    if not cmd then break end
    if cmd.op=="call" then
      stack[#stack+1]={script=script,pc=pc+1}
      script=assert(def.labels and def.labels[cmd.label], "unknown label: "..tostring(cmd.label)); pc=1
    elseif cmd.op=="return" then
      local f=table.remove(stack); if not f then break end
      script,pc=f.script,f.pc
    elseif cmd.op=="end" then out[#out+1]=cmd; break
    else out[#out+1]=cmd; pc=pc+1 end
  end
  return out
end

function M:add(def)
  assert(type(def)=="table" and type(def.id)=="string", "move definition requires id")
  assert(not self.byId[def.id], "duplicate move definition: " .. def.id)
  def.flattened = flatten(def, def.script)
  if def.chargeScript then def.chargeFlattened = flatten(def, def.chargeScript) end
  if def.trapContinuationScript then def.trapContinuationFlattened = flatten(def, def.trapContinuationScript) end
  self.byId[def.id] = def
  self.ordered[#self.ordered+1] = def
  return def
end

function M:get(id) return self.byId[id] end
function M:all() return self.ordered end

function M:soundIds()
  local seen,out = {},{}
  local function add(id)
    id=tonumber(id)
    if id and not seen[id] then seen[id]=true; out[#out+1]=id end
  end
  for _,def in ipairs(self.ordered) do
    -- Some FireRed sprite callbacks play SFX internally rather than through a
    -- script playse command. Move definitions declare those callback-owned
    -- sounds here so the shared native-audio cache registers them too.
    for _,id in ipairs(def.soundIds or {}) do add(id) end
    local function scan(commands)
      for _,cmd in ipairs(commands or {}) do
        if cmd.op=="loopsewithpan" or cmd.op=="playsewithpan" or cmd.op=="waitplaysewithpan" or cmd.op=="panse" or cmd.op=="createsoundtask" then
          add(cmd.sound or (cmd.args and cmd.args[1]))
        end
      end
    end
    scan(def.flattened)
    scan(def.chargeFlattened)
    scan(def.trapContinuationFlattened)
  end
  return out
end

return M
