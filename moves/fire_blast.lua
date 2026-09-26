local M = { id="FIRE_BLAST", name="Fire Blast" }

M.soundIds = {137,138}

-- FireRed Move_FIRE_BLAST / FireBlastRing / FireBlastCross.
M.script = {
  { op="loadspritegfx", tag=10029 }, -- ANIM_TAG_SMALL_EMBER
  { op="createsoundtask", task="SoundTask_FireBlast", args={137,138} },
  { op="call", label="FireBlastRing" },
  { op="call", label="FireBlastRing" },
  { op="call", label="FireBlastRing" },
  { op="delay", frames=24 },
  { op="createvisualtask", task="AnimTask_BlendBattleAnimPal", priority=10,
    args={"bg",3,0,8,"black"} },
  { op="waitforvisualfinish" },
  { op="delay", frames=19 },
  { op="createvisualtask", task="AnimTask_ShakeMon", priority=2,
    args={"target",5,0,20,1} },
  { op="call", label="FireBlastCross" },
  { op="delay", frames=3 }, { op="call", label="FireBlastCross" },
  { op="delay", frames=3 }, { op="call", label="FireBlastCross" },
  { op="delay", frames=3 }, { op="call", label="FireBlastCross" },
  { op="delay", frames=3 }, { op="call", label="FireBlastCross" },
  { op="delay", frames=3 }, { op="call", label="FireBlastCross" },
  { op="delay", frames=3 }, { op="call", label="FireBlastCross" },
  { op="delay", frames=3 }, { op="call", label="FireBlastCross" },
  { op="delay", frames=3 }, { op="call", label="FireBlastCross" },
  { op="waitforvisualfinish" },
  { op="createvisualtask", task="AnimTask_BlendBattleAnimPal", priority=10,
    args={"bg",2,8,0,"black"} },
  { op="waitforvisualfinish" },
  { op="end" },
}

M.labels = {
  FireBlastRing = {
    { op="createsprite", template="gFireBlastRingSpriteTemplate", anchor="target", priority=2, args={0,0,0} },
    { op="createsprite", template="gFireBlastRingSpriteTemplate", anchor="target", priority=2, args={0,0,51} },
    { op="createsprite", template="gFireBlastRingSpriteTemplate", anchor="target", priority=2, args={0,0,102} },
    { op="createsprite", template="gFireBlastRingSpriteTemplate", anchor="target", priority=2, args={0,0,153} },
    { op="createsprite", template="gFireBlastRingSpriteTemplate", anchor="target", priority=2, args={0,0,204} },
    { op="delay", frames=5 },
    { op="return" },
  },
  FireBlastCross = {
    { op="createsprite", template="gFireBlastCrossSpriteTemplate", anchor="target", priority=2, args={0,0,10,0,-2} },
    { op="createsprite", template="gFireBlastCrossSpriteTemplate", anchor="target", priority=2, args={0,0,13,-2,0} },
    { op="createsprite", template="gFireBlastCrossSpriteTemplate", anchor="target", priority=2, args={0,0,13,2,0} },
    { op="createsprite", template="gFireBlastCrossSpriteTemplate", anchor="target", priority=2, args={0,0,15,-2,2} },
    { op="createsprite", template="gFireBlastCrossSpriteTemplate", anchor="target", priority=2, args={0,0,15,2,2} },
    { op="return" },
  },
}

local basicFire={kind="loop",frames={{tileOffset=0,duration=4},{tileOffset=16,duration=4},{tileOffset=32,duration=4},{tileOffset=48,duration=4},{tileOffset=64,duration=4}}}
M.templates = {
  gFireBlastRingSpriteTemplate = {
    tileTag=10029,paletteTag=10029,callback="AnimFireRing",
    oam={affine=false,objMode="normal",bpp=4,width=32,height=32},anim=basicFire,
  },
  gFireBlastCrossSpriteTemplate = {
    tileTag=10029,paletteTag=10029,callback="AnimFireCross",
    oam={affine=false,objMode="normal",bpp=4,width=32,height=32},
    anim={kind="loop",frames={{tileOffset=32,duration=6},{tileOffset=48,duration=6}}},
  },
}

return M
