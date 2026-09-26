local M = { id="VINE_WHIP", name="Vine Whip" }

-- FireRed Move_VINE_WHIP choreography. Uses the ROM-native whip-hit OBJ and
-- the existing shared horizontal-lunge / target-shake primitives.
M.script = {
  { op="loadspritegfx", tag=10287 }, -- ANIM_TAG_WHIP_HIT
  { op="playsewithpan", sound=136, pan="attacker" }, -- SE_M_JUMP_KICK
  { op="createsprite", template="gHorizontalLungeSpriteTemplate", anchor="attacker", priority=2, args={4,6} },
  { op="delay", frames=6 },
  { op="playsewithpan", sound=148, pan="target" }, -- SE_M_SCRATCH
  { op="createsprite", template="gVineWhipSpriteTemplate", anchor="target", priority=2, args={0,0} },
  { op="delay", frames=6 },
  { op="createvisualtask", task="AnimTask_ShakeMon2", priority=2, args={"target",2,0,6,1} },
  { op="end" },
}

M.templates = {
  gHorizontalLungeSpriteTemplate = {
    controller=true, callback="DoHorizontalLunge",
    oam={affine=false,objMode="normal",bpp=4,width=8,height=8},
    anim={kind="dummy",frames={}},
  },
  gVineWhipSpriteTemplate = {
    tileTag=10287, paletteTag=10287, callback="AnimWhipHit",
    oam={affine=false,objMode="normal",bpp=4,width=32,height=32},
    -- FireRed sAnim_Whip: four 32x32 frames, four GBA frames each.
    anim={kind="once",frames={
      {tileOffset=0,duration=4},
      {tileOffset=16,duration=4},
      {tileOffset=32,duration=4},
      {tileOffset=48,duration=4},
    }},
  },
}

return M
