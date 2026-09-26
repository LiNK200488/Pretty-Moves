local M = { id="SMOKESCREEN", name="Smokescreen" }

-- Exact FireRed Move_SMOKESCREEN choreography.
M.script = {
  { op="loadspritegfx", tag=10016 }, -- ANIM_TAG_BLACK_SMOKE
  { op="loadspritegfx", tag=10017 }, -- ANIM_TAG_BLACK_BALL
  { op="playsewithpan", sound=128, pan="attacker" }, -- SE_M_DOUBLE_TEAM
  { op="createsprite", template="gBlackBallSpriteTemplate", anchor="target", priority=2,
    args={20,0,0,0,35,-25} },
  { op="waitforvisualfinish" },
  { op="createvisualtask", task="AnimTask_SmokescreenImpact", priority=2 },
  { op="delay", frames=2 },
  { op="playsewithpan", sound=152, pan="target" }, -- SE_M_SAND_ATTACK
  { op="createsprite", template="gBlackSmokeSpriteTemplate", anchor="target", priority=4, args={0,-12,104,0,75} },
  { op="createsprite", template="gBlackSmokeSpriteTemplate", anchor="target", priority=4, args={0,-12,72,1,75} },
  { op="createsprite", template="gBlackSmokeSpriteTemplate", anchor="target", priority=4, args={0,-6,56,1,75} },
  { op="createsprite", template="gBlackSmokeSpriteTemplate", anchor="target", priority=4, args={0,-6,88,0,75} },
  { op="createsprite", template="gBlackSmokeSpriteTemplate", anchor="target", priority=4, args={0,0,56,0,75} },
  { op="createsprite", template="gBlackSmokeSpriteTemplate", anchor="target", priority=4, args={0,0,88,1,75} },
  { op="createsprite", template="gBlackSmokeSpriteTemplate", anchor="target", priority=4, args={0,6,72,0,75} },
  { op="createsprite", template="gBlackSmokeSpriteTemplate", anchor="target", priority=4, args={0,6,104,1,75} },
  { op="createsprite", template="gBlackSmokeSpriteTemplate", anchor="target", priority=4, args={0,12,72,0,75} },
  { op="createsprite", template="gBlackSmokeSpriteTemplate", anchor="target", priority=4, args={0,12,56,1,75} },
  { op="createsprite", template="gBlackSmokeSpriteTemplate", anchor="target", priority=4, args={0,18,80,0,75} },
  { op="createsprite", template="gBlackSmokeSpriteTemplate", anchor="target", priority=4, args={0,18,72,1,75} },
  { op="waitforvisualfinish" },
  { op="end" },
}

M.templates = {
  gBlackBallSpriteTemplate = {
    tileTag=10017,paletteTag=10017,callback="AnimThrowProjectile",
    oam={affine=false,objMode="normal",bpp=4,width=8,height=8},
    anim={kind="dummy",frames={{tileOffset=0,duration=1}}},
  },
  gBlackSmokeSpriteTemplate = {
    tileTag=10016,paletteTag=10016,callback="AnimBlackSmoke",
    oam={affine=false,objMode="normal",bpp=4,width=32,height=16},
    anim={kind="dummy",frames={{tileOffset=0,duration=1}}},
  },
}

return M
