local M = { id="TACKLE", name="Tackle" }

-- FireRed Move_TACKLE choreography. Runtime behavior for the reusable lunge,
-- hit-splat and shake primitives lives in lib/visual_runtime.lua.
M.script = {
  { op="loadspritegfx", tag=10135 }, -- ANIM_TAG_IMPACT
  { op="monbg", battler="target" },
  { op="setalpha", eva=12, evb=8 },
  { op="createsprite", template="gHorizontalLungeSpriteTemplate", anchor="attacker", priority=2, args={4,4} },
  { op="delay", frames=6 },
  { op="createsprite", template="gBasicHitSplatSpriteTemplate", anchor="attacker", priority=2, args={0,0,"target",2} },
  { op="createvisualtask", task="AnimTask_ShakeMon", priority=2, args={"target",3,0,6,1} },
  { op="playsewithpan", sound=132, pan="target" }, -- SE_M_COMET_PUNCH
  { op="waitforvisualfinish" },
  { op="clearmonbg", battler="target" },
  { op="blendoff" },
  { op="end" },
}

M.templates = {
  -- Dummy controller sprite in FireRed; it moves the attacker's battler sprite.
  gHorizontalLungeSpriteTemplate = {
    controller=true, callback="DoHorizontalLunge",
    oam={affine=false,objMode="normal",bpp=4,width=8,height=8},
    anim={kind="dummy",frames={}},
  },
  gBasicHitSplatSpriteTemplate = {
    tileTag=10135, paletteTag=10135, callback="AnimHitSplatBasic",
    oam={affine=true,objMode="blend",bpp=4,width=32,height=32},
    anim={kind="dummy",frames={{tileOffset=0,duration=1}}},
  },
}
return M
