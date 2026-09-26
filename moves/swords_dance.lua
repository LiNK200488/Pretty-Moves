local M = { id="SWORDS_DANCE", name="Swords Dance" }

-- FireRed Move_SWORDS_DANCE. The attacker traces one 16x6 ellipse while the
-- ROM-native 32x64 sword grows horizontally from 1/16 scale to full width,
-- holds through its affine sequence, flashes cyan/white, then rises 32 px over
-- six fixed translation ticks before being destroyed.
M.script = {
  { op="loadspritegfx", tag=10005 }, -- ANIM_TAG_SWORD
  { op="monbg", battler="attacker" },
  { op="setalpha", eva=12, evb=8 },
  { op="playsewithpan", sound=184, pan="attacker" }, -- SE_M_SWORDS_DANCE
  { op="createvisualtask", task="AnimTask_TranslateMonEllipticalRespectSide", priority=2,
    args={"attacker",16,6,1,4} },
  { op="createsprite", template="gSwordsDanceBladeSpriteTemplate", anchor="attacker", priority=2,
    args={0,0} },
  { op="delay", frames=22 },
  { op="createvisualtask", task="AnimTask_FlashAnimTagWithColor", priority=2,
    args={10005,2,2,{18,31,31},16,0,0} },
  { op="waitforvisualfinish" },
  { op="clearmonbg", battler="attacker" },
  { op="blendoff" },
  { op="delay", frames=1 },
  { op="end" },
}

M.templates = {
  gSwordsDanceBladeSpriteTemplate = {
    tileTag=10005,paletteTag=10005,callback="AnimSwordsDanceBlade",
    oam={affine=true,objMode="blend",bpp=4,width=32,height=64},
    anim={kind="dummy",frames={{tileOffset=0,duration=1}}},
  },
}

return M
