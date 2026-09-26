local M = { id="HEADBUTT", name="Headbutt" }

-- FireRed Move_HEADBUTT. The attacker uses the shared BowMon controller to
-- lean forward and hold the bowed pose, returns its 12 px displacement while
-- staying bowed, then both battlers shake on impact. A flashing hit splat and
-- SE_M_VITAL_THROW2 mark the hit before BowMon mode 2 restores the attacker.
M.script = {
  { op="loadspritegfx", tag=10135 }, -- ANIM_TAG_IMPACT
  { op="createsprite", template="gBowMonSpriteTemplate", anchor="attacker", priority=2, args={0} },
  { op="playsewithpan", sound=155, pan="attacker" }, -- SE_M_HEADBUTT
  { op="waitforvisualfinish" },
  { op="delay", frames=2 },
  { op="createsprite", template="gBowMonSpriteTemplate", anchor="attacker", priority=2, args={1} },
  { op="waitforvisualfinish" },
  { op="createvisualtask", task="AnimTask_ShakeMonInPlace", priority=2,
    args={"attacker",2,0,4,1} },
  { op="createvisualtask", task="AnimTask_ShakeMon", priority=2,
    args={"target",5,0,6,1} },
  { op="createsprite", template="gBowMonSpriteTemplate", anchor="attacker", priority=2, args={2} },
  { op="createsprite", template="gFlashingHitSplatSpriteTemplate", anchor="target", priority=3,
    args={0,0,"target",1} },
  { op="playsewithpan", sound=207, pan="target" }, -- SE_M_VITAL_THROW2
  { op="waitforvisualfinish" },
  { op="end" },
}

M.templates = {
  gFlashingHitSplatSpriteTemplate = {
    tileTag=10135,paletteTag=10135,callback="AnimFlashingHitSplat",
    oam={affine=true,objMode="normal",bpp=4,width=32,height=32},
    anim={kind="dummy",frames={{tileOffset=0,duration=1}}},
  },
}

return M
