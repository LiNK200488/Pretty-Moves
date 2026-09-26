local M = { id="POISON_GAS", name="Poison Gas" }

M.soundIds = {161}

-- Source-faithful Pokemon FireRed Move_POISON_GAS.
-- Six native purple gas clouds launch from the attacker at 4-frame intervals,
-- travel to the target, swirl around it, then drift away before the target
-- receives FireRed's purple palette cycle.
M.script = {
  { op="loadspritegfx", tag=10172 }, -- ANIM_TAG_PURPLE_GAS_CLOUD
  { op="loadspritegfx", tag=10150 }, -- ANIM_TAG_POISON_BUBBLE (preloaded by FireRed)
  { op="delay", frames=0 },
  { op="monbg", battler="def_partner" },
  { op="splitbgprio_all" },
  { op="setalpha", eva=12, evb=8 },
  { op="delay", frames=0 },
}

for _=1,6 do
  M.script[#M.script+1] = { op="playsewithpan", sound=161, pan="attacker" } -- SE_M_MIST
  M.script[#M.script+1] = { op="createsprite", template="gPoisonGasCloudSpriteTemplate",
    anchor="target", priority=0, args={64,0,0,-32,-6,4192,1072,0} }
  M.script[#M.script+1] = { op="delay", frames=4 }
end

M.script[#M.script+1] = { op="delay", frames=40 }
M.script[#M.script+1] = { op="loopsewithpan", sound=161, pan="target", interval=28, count=6 }
M.script[#M.script+1] = { op="createvisualtask", task="AnimTask_BlendColorCycle", priority=2,
  args={"target",6,2,0,12,{26,0,26}} }
M.script[#M.script+1] = { op="waitforvisualfinish" }
M.script[#M.script+1] = { op="blendoff" }
M.script[#M.script+1] = { op="clearmonbg", battler="def_partner" }
M.script[#M.script+1] = { op="delay", frames=0 }
M.script[#M.script+1] = { op="end" }

M.templates = {
  gPoisonGasCloudSpriteTemplate = {
    tileTag=10172, paletteTag=10172, callback="InitPoisonGasCloudAnim",
    oam={affine=false,objMode="blend",bpp=4,width=32,height=16},
    anim={kind="loop",frames={{tileOffset=0,duration=8},{tileOffset=8,duration=8}}},
  },
}

return M
