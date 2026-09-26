local M = { id="SELFDESTRUCT", name="Self-Destruct" }

-- Source-faithful FireRed Move_SELF_DESTRUCT (RBY move 120).
-- The attacker blends toward RGB_RED while both visible battlers shake, then
-- two identical five-explosion bursts fire around the attacker at six-frame
-- intervals. After all visuals finish, the attacker palette blends back out.
M.script = {
  { op="loadspritegfx", tag=10198 }, -- ANIM_TAG_EXPLOSION
  { op="createvisualtask", task="AnimTask_BlendBattleAnimPal", priority=10,
    args={"attacker",1,0,9,{31,0,0}} }, -- F_PAL_ATTACKER, RGB_RED
  -- In singles FireRed's selectors 4..7 resolve to the two visible fixed
  -- battle positions (the unused double-battle slots abort); selector 8 is
  -- the attacker. The duplicate attacker task writes the same x2 value, so
  -- the visible result is one horizontal shake on each battler.
  { op="createvisualtask", task="AnimTask_ShakeMon2", priority=5,
    args={"attacker",6,0,38,1} },
  { op="createvisualtask", task="AnimTask_ShakeMon2", priority=5,
    args={"target",6,0,38,1} },
  { op="call", label="SelfDestructExplode" },
  { op="call", label="SelfDestructExplode" },
  { op="waitforvisualfinish" },
  { op="createvisualtask", task="AnimTask_BlendBattleAnimPal", priority=10,
    args={"attacker",1,9,0,{31,0,0}} },
  { op="end" },
}

M.labels = {
  SelfDestructExplode = {
    { op="playsewithpan", sound=170, pan="attacker" }, -- SE_M_SELF_DESTRUCT
    { op="createsprite", template="gExplosionSpriteTemplate", anchor="attacker", priority=3,
      args={0,0,"attacker",1} },
    { op="delay", frames=6 },
    { op="playsewithpan", sound=170, pan="attacker" },
    { op="createsprite", template="gExplosionSpriteTemplate", anchor="attacker", priority=3,
      args={24,-24,"attacker",1} },
    { op="delay", frames=6 },
    { op="playsewithpan", sound=170, pan="attacker" },
    { op="createsprite", template="gExplosionSpriteTemplate", anchor="attacker", priority=3,
      args={-16,16,"attacker",1} },
    { op="delay", frames=6 },
    { op="playsewithpan", sound=170, pan="attacker" },
    { op="createsprite", template="gExplosionSpriteTemplate", anchor="attacker", priority=3,
      args={-24,-12,"attacker",1} },
    { op="delay", frames=6 },
    { op="playsewithpan", sound=170, pan="attacker" },
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
}

return M
