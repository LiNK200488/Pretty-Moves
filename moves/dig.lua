local M = { id="DIG", name="Dig" }

-- FireRed Move_DIG. Gen1Recomp special-cases Dig's charge presentation to
-- SLIDE_DOWN_ANIM (Fly alone uses TELEPORT), so that is the row this mod must
-- replace on the real first turn. Battle mechanics remain host-authoritative.
M.chargeRowAnims = { player="SLIDE_DOWN_ANIM", opponent="SLIDE_DOWN_ANIM" }
M.soundIds = {168,134}

M.chargeScript = {
  { op="loadspritegfx", tag=10074 }, -- ANIM_TAG_MUD_SAND
  { op="loadspritegfx", tag=10281 }, -- ANIM_TAG_DIRT_MOUND
  { op="monbg", battler="attacker" },
  { op="createsprite", template="gDirtMoundSpriteTemplate", anchor="attacker", priority=1, args={0,0,180} },
  { op="createsprite", template="gDirtMoundSpriteTemplate", anchor="attacker", priority=1, args={0,1,180} },
  { op="createvisualtask", task="AnimTask_DigDownMovement", priority=2, args={false} },
  { op="delay", frames=6 },
  { op="call", label="DigThrowDirt" },
  { op="call", label="DigThrowDirt" },
  { op="call", label="DigThrowDirt" },
  { op="call", label="DigThrowDirt" },
  { op="call", label="DigThrowDirt" },
  { op="waitforvisualfinish" },
  { op="createvisualtask", task="AnimTask_DigDownMovement", priority=2, args={true} },
  { op="clearmonbg", battler="attacker" },
  { op="blendoff" },
  { op="end" },
}

M.script = {
  { op="loadspritegfx", tag=10281 }, -- ANIM_TAG_DIRT_MOUND
  { op="loadspritegfx", tag=10135 }, -- ANIM_TAG_IMPACT
  { op="createvisualtask", task="AnimTask_DigUpMovement", priority=2, args={false} },
  { op="waitforvisualfinish" },
  { op="monbg", battler="attacker" },
  { op="createsprite", template="gDirtMoundSpriteTemplate", anchor="attacker", priority=1, args={0,0,48} },
  { op="createsprite", template="gDirtMoundSpriteTemplate", anchor="attacker", priority=1, args={0,1,48} },
  { op="delay", frames=1 },
  { op="createvisualtask", task="AnimTask_DigUpMovement", priority=2, args={true} },
  { op="delay", frames=16 },
  { op="playsewithpan", sound=134, pan="attacker" }, -- SE_M_MEGA_KICK2
  { op="createsprite", template="gBasicHitSplatSpriteTemplate", anchor="attacker", priority=2,
    args={-8,0,"target",2} },
  { op="createvisualtask", task="AnimTask_ShakeMon", priority=2, args={"target",5,0,6,1} },
  { op="waitforvisualfinish" },
  { op="clearmonbg", battler="attacker" },
  { op="blendoff" },
  { op="end" },
}

M.labels = {
  DigThrowDirt = {
    { op="createsprite", template="gDirtPlumeSpriteTemplate", anchor="attacker", priority=2, args={0,0,12,4,-16,18} },
    { op="createsprite", template="gDirtPlumeSpriteTemplate", anchor="attacker", priority=2, args={0,0,16,4,-10,18} },
    { op="createsprite", template="gDirtPlumeSpriteTemplate", anchor="attacker", priority=2, args={0,1,14,4,-18,18} },
    { op="createsprite", template="gDirtPlumeSpriteTemplate", anchor="attacker", priority=2, args={0,1,12,4,-16,18} },
    { op="playsewithpan", sound=168, pan="attacker" }, -- SE_M_DIG
    { op="delay", frames=32 },
    { op="return" },
  },
}

M.templates = {
  gDirtMoundSpriteTemplate = {
    tileTag=10281,paletteTag=10281,callback="AnimDigDirtMound",
    oam={affine=false,objMode="normal",bpp=4,width=32,height=16},
    anim={kind="dummy",frames={{tileOffset=0,duration=1}}},
    extraTileOffsets={8},
  },
  gDirtPlumeSpriteTemplate = {
    tileTag=10074,paletteTag=10074,callback="AnimDirtPlumeParticle",
    oam={affine=false,objMode="normal",bpp=4,width=8,height=8},
    anim={kind="dummy",frames={{tileOffset=0,duration=1}}},
  },
  gBasicHitSplatSpriteTemplate = {
    tileTag=10135,paletteTag=10135,callback="AnimHitSplatBasic",
    oam={affine=true,objMode="blend",bpp=4,width=32,height=32},
    anim={kind="dummy",frames={{tileOffset=0,duration=1}}},
  },
}

return M
