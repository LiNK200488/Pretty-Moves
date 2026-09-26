local M = { id="DRAGON_RAGE", name="Dragon Rage" }

-- FireRed Move_DRAGON_RAGE. The target is nudged forward, a large rotating
-- flame travels from attacker to target, then eight native fire-plume sprites
-- erupt around the target while it shakes.
M.soundIds = {164,138}

M.script = {
  { op="loadspritegfx", tag=10029 }, -- ANIM_TAG_SMALL_EMBER
  { op="loadspritegfx", tag=10035 }, -- ANIM_TAG_FIRE_PLUME
  { op="playsewithpan", sound=164, pan="attacker" },
  { op="createvisualtask", task="AnimTask_ShakeMon", priority=5, args={"attacker",0,2,40,1} },
  { op="waitforvisualfinish" },
  { op="createsprite", template="gSlideMonToOffsetSpriteTemplate", anchor="target", priority=2,
    args={0,15,0,0,4} },
  { op="waitforvisualfinish" },
  { op="createsprite", template="gDragonRageFireSpitSpriteTemplate", anchor="target", priority=2,
    args={30,15,0,10,10} },
  { op="waitforvisualfinish" },
  { op="loopsewithpan", sound=138, pan="target", interval=11, count=3 },
  { op="createvisualtask", task="AnimTask_ShakeMon", priority=5, args={"target",0,3,25,1} },
  { op="createsprite", template="gDragonRageFirePlumeSpriteTemplate", anchor="target", priority=66, args={1,5,0} },
  { op="delay", frames=1 },
  { op="createsprite", template="gDragonRageFirePlumeSpriteTemplate", anchor="target", priority=66, args={1,-10,-15} },
  { op="delay", frames=1 },
  { op="createsprite", template="gDragonRageFirePlumeSpriteTemplate", anchor="target", priority=2, args={1,0,25} },
  { op="delay", frames=1 },
  { op="createsprite", template="gDragonRageFirePlumeSpriteTemplate", anchor="target", priority=66, args={1,15,5} },
  { op="delay", frames=1 },
  { op="createsprite", template="gDragonRageFirePlumeSpriteTemplate", anchor="target", priority=66, args={1,-25,0} },
  { op="delay", frames=1 },
  { op="createsprite", template="gDragonRageFirePlumeSpriteTemplate", anchor="target", priority=2, args={1,30,30} },
  { op="delay", frames=1 },
  { op="createsprite", template="gDragonRageFirePlumeSpriteTemplate", anchor="target", priority=2, args={1,-27,25} },
  { op="delay", frames=1 },
  { op="createsprite", template="gDragonRageFirePlumeSpriteTemplate", anchor="target", priority=66, args={1,0,8} },
  { op="waitforvisualfinish" },
  { op="createsprite", template="gSlideMonToOriginalPosSpriteTemplate", anchor="target", priority=66, args={0,0,4} },
  { op="waitforvisualfinish" },
  { op="end" },
}

M.templates = {
  gSlideMonToOffsetSpriteTemplate = {
    controller=true, callback="SlideMonToOffset",
    oam={affine=false,objMode="normal",bpp=4,width=8,height=8},
    anim={kind="dummy",frames={{tileOffset=0,duration=1}}},
  },
  gSlideMonToOriginalPosSpriteTemplate = {
    controller=true, callback="SlideMonToOriginalPos",
    oam={affine=false,objMode="normal",bpp=4,width=8,height=8},
    anim={kind="dummy",frames={{tileOffset=0,duration=1}}},
  },
  gDragonRageFireSpitSpriteTemplate = {
    tileTag=10029,paletteTag=10029,callback="AnimDragonFireToTarget",
    oam={affine=true,doubleSize=true,objMode="normal",bpp=4,width=32,height=32},
    anim={kind="loop",frames={{tileOffset=16,duration=3},{tileOffset=32,duration=3},{tileOffset=48,duration=3}}},
  },
  gDragonRageFirePlumeSpriteTemplate = {
    tileTag=10035,paletteTag=10035,callback="AnimDragonRageFirePlume",
    oam={affine=false,objMode="normal",bpp=4,width=32,height=32},
    anim={kind="once",frames={{tileOffset=0,duration=5},{tileOffset=16,duration=5},{tileOffset=32,duration=5},{tileOffset=48,duration=5},{tileOffset=64,duration=5}}},
  },
}

return M
