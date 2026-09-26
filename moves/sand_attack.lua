local M = { id="SAND_ATTACK", name="Sand Attack" }

-- Source-faithful FireRed Move_SAND_ATTACK. The attacker slides 10 px away
-- from the target, returns over two frames, then emits six tightly staggered
-- bursts of five small ANIM_TAG_MUD_SAND dirt particles. AnimDirtScatter
-- chooses each particle endpoint using FireRed's signed 5-bit random offsets.
M.script = {
  { op="loadspritegfx", tag=10074 }, -- ANIM_TAG_MUD_SAND
  { op="monbg", battler="attacker_partner" },
  { op="splitbgprio", battler="attacker" },
  { op="setalpha", eva=12, evb=8 },
  { op="playsewithpan", sound=152, pan="attacker" }, -- SE_M_SAND_ATTACK
  { op="createsprite", template="gSlideMonToOffsetSpriteTemplate", anchor="attacker", priority=2,
    args={0,-10,0,0,3} },
  { op="waitforvisualfinish" },
  { op="createsprite", template="gSlideMonToOriginalPosSpriteTemplate", anchor="attacker", priority=2,
    args={0,0,2} },
  { op="call", label="SandAttackDirt" },
  { op="call", label="SandAttackDirt" },
  { op="call", label="SandAttackDirt" },
  { op="call", label="SandAttackDirt" },
  { op="call", label="SandAttackDirt" },
  { op="call", label="SandAttackDirt" },
  { op="waitforvisualfinish" },
  { op="clearmonbg", battler="attacker_partner" },
  { op="blendoff" },
  { op="end" },
}

M.labels = {
  SandAttackDirt = {
    { op="createsprite", template="gSandAttackDirtSpriteTemplate", anchor="target", priority=2, args={15,15,20,0,0} },
    { op="createsprite", template="gSandAttackDirtSpriteTemplate", anchor="target", priority=2, args={15,15,20,10,10} },
    { op="createsprite", template="gSandAttackDirtSpriteTemplate", anchor="target", priority=2, args={15,15,20,-10,-10} },
    { op="createsprite", template="gSandAttackDirtSpriteTemplate", anchor="target", priority=2, args={15,15,20,20,5} },
    { op="createsprite", template="gSandAttackDirtSpriteTemplate", anchor="target", priority=2, args={15,15,20,-20,-5} },
    { op="delay", frames=2 },
    { op="return" },
  },
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
  gSandAttackDirtSpriteTemplate = {
    tileTag=10074,paletteTag=10074,callback="AnimDirtScatter",
    oam={affine=false,objMode="normal",bpp=4,width=8,height=8},
    anim={kind="dummy",frames={{tileOffset=0,duration=1}}},
  },
}

return M
