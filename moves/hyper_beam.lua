local M = { id="HYPER_BEAM", name="Hyper Beam" }

-- FireRed Move_HYPER_BEAM. Recharge/gameplay logic remains Gen1Recomp-owned;
-- this definition replaces only the move animation and its native FireRed SFX.
M.script = {
  { op="loadspritegfx", tag=10147 }, -- ANIM_TAG_ORBS
  { op="createsprite", template="gSimplePaletteBlendSpriteTemplate", anchor="attacker", priority=2, args={"bg",4,0,16,"black"} },
  { op="waitforvisualfinish" },
  { op="delay", frames=10 },
  { op="playsewithpan", sound=208, pan="attacker" },
  { op="createvisualtask", task="AnimTask_ShakeMon2", priority=2, args={"attacker",1,0,4,1} },
  { op="waitforvisualfinish" },
  { op="delay", frames=30 },
  { op="createsoundtask", task="SoundTask_LoopSEAdjustPanning", args={240,"attacker","target",1,15,0,5} },
  { op="createvisualtask", task="AnimTask_ShakeMon", priority=2, args={"attacker",0,4,50,1} },
  { op="createvisualtask", task="AnimTask_FlashAnimTagWithColor", priority=2, args={10147,1,12,{31,0,0},16,0,0} },
  { op="call", label="HyperBeamOrbs" },
  { op="call", label="HyperBeamOrbs" },
  { op="call", label="HyperBeamOrbs" },
  { op="call", label="HyperBeamOrbs" },
  { op="call", label="HyperBeamOrbs" },
  { op="createvisualtask", task="AnimTask_ShakeMon2", priority=2, args={"target",4,0,50,1} },
  { op="createvisualtask", task="AnimTask_BlendBattleAnimPal", priority=10, args={"target",2,0,11,{25,25,25}} },
}
for _=1,21 do M.script[#M.script+1]={ op="call", label="HyperBeamOrbs" } end
M.script[#M.script+1]={ op="createvisualtask", task="AnimTask_BlendBattleAnimPal", priority=10, args={"target",2,11,0,{25,25,25}} }
M.script[#M.script+1]={ op="waitforvisualfinish" }
M.script[#M.script+1]={ op="createsprite", template="gSimplePaletteBlendSpriteTemplate", anchor="attacker", priority=2, args={"bg",4,16,0,"black"} }
M.script[#M.script+1]={ op="end" }

M.labels = {
  HyperBeamOrbs = {
    { op="createsprite", template="gHyperBeamOrbSpriteTemplate", anchor="target", priority=2 },
    { op="createsprite", template="gHyperBeamOrbSpriteTemplate", anchor="target", priority=2 },
    { op="delay", frames=1 },
    { op="return" },
  },
}

M.templates = {
  gSimplePaletteBlendSpriteTemplate={controller=true,callback="AnimSimplePaletteBlend"},
  gHyperBeamOrbSpriteTemplate={
    tileTag=10147,paletteTag=10147,callback="AnimHyperBeamOrb",
    oam={width=8,height=8,objMode="normal"},
    anim={kind="dummy",frames={{tileOffset=0,duration=1}}},
  },
}

return M
