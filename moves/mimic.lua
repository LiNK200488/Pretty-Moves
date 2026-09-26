local M = { id="MIMIC", name="Mimic" }

-- Exact FireRed Move_MIMIC choreography. FireRed leaves a static background
-- copy of the target in place while its live OBJ shrinks/moves sideways, then
-- launches the ORBS-tag mimic orb toward the attacker and flashes the attacker
-- white. Battle mechanics (which move is copied) remain owned by gen1recomp.
M.soundIds = {197,145}

M.script = {
  { op="loadspritegfx", tag=10147 }, -- ANIM_TAG_ORBS
  { op="monbg_static", battler="def_partner" },
  { op="setalpha", eva=11, evb=5 },
  { op="panse", sound=197, from="target", to="attacker", increment=-3, delay=0 }, -- SE_M_MINIMIZE
  { op="createvisualtask", task="AnimTask_ShrinkTargetCopy", priority=5, args={128,24} },
  { op="delay", frames=15 },
  { op="createsprite", template="gMimicOrbSpriteTemplate", anchor="target", priority=2, args={-12,24} },
  { op="delay", frames=10 },
  { op="setarg", index=7, value=0xFFFF },
  { op="waitforvisualfinish" },
  { op="playsewithpan", sound=145, pan="attacker" }, -- SE_M_TAKE_DOWN
  { op="createvisualtask", task="AnimTask_BlendColorCycle", priority=2,
    args={"attacker",0,2,0,11,{31,31,31}} },
  { op="waitforvisualfinish" },
  { op="clearmonbg_static", battler="def_partner" },
  { op="blendoff" },
  { op="end" },
}

M.templates = {
  gMimicOrbSpriteTemplate = {
    tileTag=10147,paletteTag=10147,callback="AnimMimicOrb",
    oam={affine=true,objMode="normal",bpp=4,width=16,height=16},
    -- Same ORBS frame as FireRed's power-absorption orb table.
    anim={kind="dummy",frames={{tileOffset=8,duration=1}}},
  },
}

return M
