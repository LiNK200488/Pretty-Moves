local M = { id="LEER", name="Leer" }

M.soundIds = {185}

-- FireRed Move_LEER. The native Leer sprite appears beside the attacker while
-- the attacker scales outward, then the target shakes after a 10-frame pause.
M.script = {
  { op="loadspritegfx", tag=10027 }, -- ANIM_TAG_LEER
  { op="monbg", battler="attacker" },
  { op="splitbgprio", battler="attacker" },
  { op="setalpha", eva=8, evb=8 },
  { op="playsewithpan", sound=185, pan="attacker" }, -- SE_M_LEER
  { op="createsprite", template="gLeerSpriteTemplate", anchor="attacker", priority=2, args={24,-12} },
  { op="createvisualtask", task="AnimTask_ScaleMonAndRestore", priority=5,
    args={-5,-5,10,"attacker",1} },
  { op="waitforvisualfinish" },
  { op="delay", frames=10 },
  { op="createvisualtask", task="AnimTask_ShakeMon2", priority=2, args={"target",1,0,9,1} },
  { op="createvisualtask", task="AnimTask_ShakeMon2", priority=2, args={"def_partner",1,0,9,1} },
  { op="waitforvisualfinish" },
  { op="clearmonbg", battler="attacker" },
  { op="blendoff" },
  { op="delay", frames=1 },
  { op="waitforvisualfinish" },
  { op="end" },
}

M.templates = {
  gLeerSpriteTemplate = {
    tileTag=10027,paletteTag=10027,callback="AnimLeer",
    oam={affine=false,objMode="normal",bpp=4,width=32,height=32},
    anim={kind="once",frames={
      {tileOffset=0,duration=3},{tileOffset=16,duration=3},{tileOffset=32,duration=3},
      {tileOffset=48,duration=3},{tileOffset=64,duration=3},
    }},
  },
}

return M
