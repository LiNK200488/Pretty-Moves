-- First-overworld-entry cache builder UI.
-- The entry chunk registers content up front, but ROM-derived runtime assets
-- and generated WAV files are prepared only after the player reaches the
-- overworld and confirms the cache build.
local M={}

local function makeProgressScreen(game,jobs,onDone,onError)
  local Font=require("src.render.Font")
  local screen={game=game,jobs=jobs,index=0,detail="Preparing cache...",started=false,announced=false,done=false,error=nil}
  screen.isOpaque=false

  function screen:update(dt)
    if self.done then return end
    -- Give the renderer one frame with the progress window visible before the
    -- first potentially expensive ROM/audio job starts.
    if not self.started then self.started=true; return end

    local job=self.jobs[self.index+1]
    if not job then
      self.done=true
      collectgarbage("collect")
      self.game.stack:pop()
      if onDone then onDone() end
      return
    end

    if not self.announced then
      self.detail=job.label or "Building cache..."
      self.announced=true
      return
    end
    local ok,result,why=pcall(job.run)
    if not ok or result==false or result==nil then
      local err=not ok and result or why or "unknown cache error"
      self.error=tostring(err)
      self.done=true
      if onError then onError(self.error) end
      return
    end
    self.index=self.index+1
    self.announced=false
  end

  function screen:draw()
    -- Draw as a blocking popup over the live overworld.
    Font.drawBox(1,3,18,11)
    love.graphics.setColor(0,0,0,1)
    Font.draw("FIRERED CACHE",16,32)
    if self.error then
      Font.draw("CACHE BUILD FAILED",16,56)
      Font.draw(self.error:sub(1,18),16,72)
      Font.draw("RESTART TO RETRY",16,96)
    else
      local total=math.max(1,#self.jobs)
      local progress=math.max(0,math.min(1,self.index/total))
      Font.draw(("BUILDING %d/%d"):format(self.index,#self.jobs),16,48)
      local detail=self.detail or "Preparing cache..."
      Font.draw(detail:sub(1,16),16,64)
      if #detail>16 then Font.draw(detail:sub(17,32),16,72) end
      -- Percentage sits above the progress bar so the lower popup stays clean.
      -- Gen1's tile font does not reliably expose a percent glyph to mods, so
      -- draw the numeric value with Font and the small % mark explicitly.
      local percent=math.floor(progress*100+0.5)
      Font.draw(("%3d"):format(percent),64,84)
      love.graphics.rectangle("fill",88,84,2,2)
      love.graphics.rectangle("fill",93,89,2,2)
      love.graphics.rectangle("fill",92,86,1,1)
      love.graphics.rectangle("fill",91,87,1,1)
      love.graphics.rectangle("fill",90,88,1,1)
      -- Lift the bar 2 px further so the percentage and bar read as one group.
      love.graphics.rectangle("line",16,94,128,10)
      love.graphics.rectangle("fill",18,96,math.floor(124*progress),6)
    end
    love.graphics.setColor(1,1,1,1)
  end

  return screen
end

function M.install(opts)
  opts=opts or {}
  local mod=assert(opts.mod)
  local jobs=opts.jobs or {}
  local runtimeJobs=opts.runtimeJobs or {}
  local liveGame=nil
  local worldSeen=false
  local started=false
  local runtimePrepared=false
  local runtimeError=nil

  local function prepareRuntime()
    if runtimePrepared then return true end
    for _,job in ipairs(runtimeJobs) do
      local ok,result,why=pcall(job.run)
      if not ok or result==false or result==nil then
        runtimeError=tostring((not ok and result) or why or "unknown runtime preparation error")
        mod.log:warn("FireRed runtime asset preparation failed: %s",runtimeError)
        return false
      end
    end
    runtimePrepared=true
    return true
  end

  local function showPrompt()
    if started or not worldSeen or not liveGame then return end
    -- These five ROM-derived visual resources are LÖVE runtime objects, not a
    -- persistent disk cache. They must be reconstructed once per process, but
    -- doing so must not make the user rebuild the persistent FireRed cache.
    if not prepareRuntime() then return end
    if #jobs==0 then
      started=true
      mod.log:info("FireRed persistent cache already valid; no cache build required")
      return
    end
    started=true
    local TextBox=require("src.render.TextBox")
    liveGame.stack:push(TextBox.new(liveGame,
      "FIRERED CACHE NEEDS\nTO BE BUILT.\nPRESS A TO START.",
      function()
        local progress=makeProgressScreen(liveGame,jobs,
          function() mod.log:info("FireRed cache build complete") end,
          function(err) mod.log:warn("FireRed cache build failed: %s",tostring(err)) end)
        liveGame.stack:push(progress)
      end))
  end

  mod.events:on("game.ready",function(ev)
    liveGame=ev and ev.game or liveGame
    showPrompt()
  end)
  mod.events:on("map.entered",function(ev)
    if worldSeen then return end
    worldSeen=true
    showPrompt()
  end)

  return {
    started=function() return started end,
    worldSeen=function() return worldSeen end,
  }
end

return M
