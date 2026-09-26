local M = { id="EXPLOSION", name="Explosion" }

-- Source-faithful FireRed Move_EXPLOSION (RBY move 153).
-- FireRed drives the entire BG palette through a discrete dark-red/black
-- flashing controller: 8/16 toward RGB(26,8,8), then 5/16 toward black,
-- alternating every 9 frames for 9 state changes. It shakes all visible battlers,
-- and fires two identical five-sprite
-- explosion passes, then holds the field white for 50 frames before fading
-- the BG palette back to normal.
M.script = {
  { op="loadspritegfx", tag=10198 }, -- ANIM_TAG_EXPLOSION
  { op="createsprite", template="gComplexPaletteBlendSpriteTemplate", anchor="attacker", priority=2,
    args={"bg",8,9,{26,8,8},8,"black",5} },
  -- In singles FireRed's selectors 4..7 resolve to the two visible fixed
  -- battle positions (unused double-battle slots abort); selector 8 is the
  -- attacker. Encoding the visible result avoids passing host-foreign raw IDs.
  { op="createvisualtask", task="AnimTask_ShakeMon2", priority=5,
    args={"attacker",8,0,40,1} },
  { op="createvisualtask", task="AnimTask_ShakeMon2", priority=5,
    args={"target",8,0,40,1} },
  { op="call", label="Explosion1" },
  { op="call", label="Explosion1" },
  { op="waitforvisualfinish" },
  { op="createvisualtask", task="AnimTask_BlendBattleAnimPal", priority=10,
    args={"bg",1,16,16,{31,31,31}} }, -- F_PAL_BG, RGB_WHITE
  { op="delay", frames=50 },
  { op="createvisualtask", task="AnimTask_BlendBattleAnimPal", priority=10,
    args={"bg",3,16,0,{31,31,31}} },
  { op="end" },
}

M.labels = {
  Explosion1 = {
    { op="playsewithpan", sound=171, pan="attacker" }, -- SE_M_EXPLOSION
    { op="createsprite", template="gExplosionSpriteTemplate", anchor="attacker", priority=3,
      args={0,0,"attacker",1} },
    { op="delay", frames=6 },
    { op="playsewithpan", sound=171, pan="attacker" },
    { op="createsprite", template="gExplosionSpriteTemplate", anchor="attacker", priority=3,
      args={24,-24,"attacker",1} },
    { op="delay", frames=6 },
    { op="playsewithpan", sound=171, pan="attacker" },
    { op="createsprite", template="gExplosionSpriteTemplate", anchor="attacker", priority=3,
      args={-16,16,"attacker",1} },
    { op="delay", frames=6 },
    { op="playsewithpan", sound=171, pan="attacker" },
    { op="createsprite", template="gExplosionSpriteTemplate", anchor="attacker", priority=3,
      args={-24,-12,"attacker",1} },
    { op="delay", frames=6 },
    { op="playsewithpan", sound=171, pan="attacker" },
    { op="createsprite", template="gExplosionSpriteTemplate", anchor="attacker", priority=3,
      args={16,16,"attacker",1} },
    { op="delay", frames=6 },
    { op="return" },
  },
}

M.templates = {
  gExplosionSpriteTemplate = {
    tileTag=10198, paletteTag=10198, callback="AnimSpriteOnMonPos",
    oam={affine=false,objMode="normal",bpp=4,width=32,height=32},
    anim={kind="once",frames={
      {tileOffset=0,duration=5},
      {tileOffset=16,duration=5},
      {tileOffset=32,duration=5},
      {tileOffset=48,duration=5},
    }},
  },
  gComplexPaletteBlendSpriteTemplate = {
    controller=true, callback="AnimComplexPaletteBlend",
    oam={affine=false,objMode="normal",bpp=4,width=8,height=8},
    anim={kind="dummy",frames={{tileOffset=0,duration=1}}},
  },
}

return M
