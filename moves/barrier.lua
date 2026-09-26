local M = { id="BARRIER", name="Barrier" }

-- FireRed Move_BARRIER choreography. The GBA script uses X +40; this mod's
-- established defensive-wall host-layout correction is X +24 so the wall
-- occupies the same visual position relative to the battler as on FireRed.
M.script = {
  { op="loadspritegfx", tag=10169 }, -- ANIM_TAG_GRAY_LIGHT_WALL
  { op="setalpha", eva=0, evb=16 },
  { op="waitplaysewithpan", sound=201, pan="attacker", wait=15 }, -- SE_M_BARRIER
  { op="createsprite", template="gBarrierWallSpriteTemplate", anchor="attacker", priority=3,
    args={24,0,10169} },
  { op="waitforvisualfinish" },
  { op="delay", frames=1 },
  { op="blendoff" },
  { op="end" },
}

M.templates = {
  gBarrierWallSpriteTemplate = {
    tileTag=10169,paletteTag=10169,callback="AnimDefensiveWall",
    oam={affine=false,objMode="blend",bpp=4,width=64,height=64},
    anim={kind="dummy",frames={{tileOffset=0,duration=1}}},
    paletteRotations=true,
  },
}

return M
