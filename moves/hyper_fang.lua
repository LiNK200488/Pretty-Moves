local M = { id="HYPER_FANG", name="Hyper Fang" }

-- Source-traced FireRed Move_HYPER_FANG. After the Bite cue, FireRed fades to
-- the side-specific impact background, draws the 32x32 fang sprite over the
-- target at 2x scale shrinking to normal over 8 frames, then shakes the target
-- while SE_M_LEER supplies the crunch accent before restoring the battle BG.
M.script = {
  { op="loadspritegfx", tag=10192 }, -- ANIM_TAG_FANG_ATTACK
  { op="playsewithpan", sound=154, pan="target" }, -- SE_M_BITE
  { op="delay", frames=1 },
  { op="delay", frames=2 },
  { op="fadetobg", bg={byAttackerSide={player="impact_opponent",opponent="impact_player"}} },
  { op="waitbgfadeout" },
  { op="createsprite", template="gFangSpriteTemplate", anchor="target", priority=2, args={} },
  { op="waitbgfadein" },
  { op="createvisualtask", task="AnimTask_ShakeMon", priority=3,
    args={"target",0,10,10,1} },
  { op="playsewithpan", sound=185, pan="target" }, -- SE_M_LEER
  { op="delay", frames=20 },
  { op="restorebg" },
  { op="waitbgfadein" },
  { op="waitforvisualfinish" },
  { op="end" },
}

M.templates = {
  gFangSpriteTemplate = {
    tileTag=10192,paletteTag=10192,callback="AnimFang",
    oam={affine=true,doubleSize=true,objMode="normal",bpp=4,width=32,height=32},
    anim={kind="once",frames={
      {tileOffset=0,duration=8},
      {tileOffset=16,duration=16},
      {tileOffset=32,duration=4},
      {tileOffset=48,duration=4},
    }},
    affineAnim={kind="linear_scale",start=512,delta=-32,frames=8},
  },
}

return M
