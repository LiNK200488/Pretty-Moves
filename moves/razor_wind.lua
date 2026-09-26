local M = { id="RAZOR_WIND", name="Razor Wind" }

-- FireRed Move_RAZOR_WIND uses choosetwoturnanim: RazorWindSetUp on the
-- initial charge turn and RazorWindUnleash on the release turn. Gen1Recomp's
-- battle.charge_required hook is the authoritative first-turn seam, so this
-- setup runs on the real charging turn while the engine keeps charge mechanics.
M.chargeRowAnims = { player="XSTATITEM_ANIM", opponent="XSTATITEM_DUPLICATE_ANIM" }

M.chargeScript = {
  { op="loadspritegfx", tag=10009 }, -- ANIM_TAG_GUST
  { op="playsewithpan", sound=125, pan="attacker" }, -- SE_M_GUST
  { op="createsprite", template="gRazorWindTornadoSpriteTemplate", anchor="attacker", priority=2,
    args={32,0,16,16,0,7,40} },
  { op="createsprite", template="gRazorWindTornadoSpriteTemplate", anchor="attacker", priority=2,
    args={32,0,16,16,85,7,40} },
  { op="createsprite", template="gRazorWindTornadoSpriteTemplate", anchor="attacker", priority=2,
    args={32,0,16,16,170,7,40} },
  { op="waitforvisualfinish" },
  { op="playsewithpan", sound=126, pan="attacker" }, -- SE_M_GUST2
  { op="end" },
}

-- FireRed RazorWindUnleash: three Air Wave crescents seek different flip
-- states, translate attacker->target for 22 native ticks, then the target /
-- partner shake lands with the final Razor Wind SFX.
M.script = {
  { op="loadspritegfx", tag=10154 }, -- ANIM_TAG_AIR_WAVE_2
  { op="loadspritegfx", tag=10135 }, -- ANIM_TAG_IMPACT
  { op="monbg", battler="target" },
  { op="setalpha", eva=12, evb=8 },
  { op="playsewithpan", sound=153, pan="attacker" }, -- SE_M_RAZOR_WIND2
  { op="createsprite", template="gAirWaveCrescentSpriteTemplate", anchor="attacker", priority=2,
    args={14,8,0,0,22,2,1} },
  { op="delay", frames=2 },
  { op="playsewithpan", sound=153, pan="attacker" },
  { op="createsprite", template="gAirWaveCrescentSpriteTemplate", anchor="attacker", priority=2,
    args={14,-8,16,14,22,1,1} },
  { op="delay", frames=2 },
  { op="playsewithpan", sound=153, pan="attacker" },
  { op="createsprite", template="gAirWaveCrescentSpriteTemplate", anchor="attacker", priority=2,
    args={14,12,-16,-14,22,0,1} },
  { op="delay", frames=17 },
  { op="playsewithpan", sound=129, pan="target" }, -- SE_M_RAZOR_WIND
  { op="createvisualtask", task="AnimTask_ShakeMon2", priority=5,
    args={"target",2,0,10,1} },
  { op="createvisualtask", task="AnimTask_ShakeMon2", priority=5,
    args={"def_partner",2,0,10,1} },
  { op="waitforvisualfinish" },
  { op="clearmonbg", battler="target" },
  { op="blendoff" },
  { op="end" },
}

M.templates = {
  gRazorWindTornadoSpriteTemplate = {
    tileTag=10009,paletteTag=10009,callback="AnimRazorWindTornado",
    oam={affine=true,objMode="normal",bpp=4,width=32,height=64},
    anim={kind="dummy",frames={{tileOffset=0,duration=40}}},
  },
  gAirWaveCrescentSpriteTemplate = {
    tileTag=10154,paletteTag=10154,callback="AnimAirWaveCrescent",
    oam={affine=false,objMode="normal",bpp=4,width=32,height=16},
    anim={kind="loop",frames={
      {tileOffset=0,duration=3},
      {tileOffset=0,duration=3,hFlip=true},
      {tileOffset=0,duration=3,vFlip=true},
      {tileOffset=0,duration=3,hFlip=true,vFlip=true},
    }},
  },
}

return M
