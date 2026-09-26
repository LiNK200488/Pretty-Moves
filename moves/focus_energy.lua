local M = { id="FOCUS_ENERGY", name="Focus Energy" }

M.soundIds = {164}

-- Source-faithful Pokemon FireRed Move_FOCUS_ENERGY.
-- Uses the native Focus Energy / Endure energy sprite three times, with the
-- exact 4-frame spawn cadence, white attacker palette cycle, and 32-frame
-- horizontal shake from the FireRed battle animation script.
local function endureEffect(dst)
  local seq = {
    {0,-24,26,2},
    {0, 14,28,1},
    {0, -5,10,2},
    {0, 28,26,3},
    {0,-12, 0,1},
  }
  for i,s in ipairs(seq) do
    dst[#dst+1] = { op="createsprite", template="gEndureEnergySpriteTemplate",
      anchor="attacker", priority=2, args={s[1],s[2],s[3],s[4]} }
    if i < #seq then dst[#dst+1] = { op="delay", frames=4 } end
  end
end

M.script = {
  { op="loadspritegfx", tag=10184 }, -- ANIM_TAG_FOCUS_ENERGY
  { op="playsewithpan", sound=164, pan="attacker" }, -- SE_M_DRAGON_RAGE
}

endureEffect(M.script)
M.script[#M.script+1] = { op="delay", frames=8 }
M.script[#M.script+1] = { op="createvisualtask", task="AnimTask_BlendColorCycle", priority=2,
  args={"attacker",2,2,0,11,{31,31,31}} }
M.script[#M.script+1] = { op="createvisualtask", task="AnimTask_ShakeMon2", priority=2,
  args={"attacker",1,0,32,1} }
endureEffect(M.script)
M.script[#M.script+1] = { op="delay", frames=8 }
endureEffect(M.script)
M.script[#M.script+1] = { op="waitforvisualfinish" }
M.script[#M.script+1] = { op="end" }

M.templates = {
  gEndureEnergySpriteTemplate = {
    tileTag=10184, paletteTag=10184, callback="AnimEndureEnergy",
    oam={affine=false,objMode="normal",bpp=4,width=16,height=32},
    anim={kind="once",frames={
      {tileOffset=0,duration=4},
      {tileOffset=8,duration=12},
      {tileOffset=16,duration=4},
      {tileOffset=24,duration=4},
    }},
  },
}

return M
