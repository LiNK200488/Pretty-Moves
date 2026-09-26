local M = { id="BIND", name="Bind" }

-- FireRed Move_BIND. The initial hit is task-driven: the attacker sways while
-- the target is compressed/expanded twice by AnimTask_ScaleMonAndRestore.
-- FireRed does NOT use the tendril OBJ sprites on this initial move script.
M.script = {
  { op="createvisualtask", task="AnimTask_SwayMon", priority=5, args={0,6,3328,4,"attacker"} },
  { op="playsewithpan", sound=163, pan="target" }, -- SE_M_BIND
  { op="createvisualtask", task="AnimTask_ScaleMonAndRestore", priority=5, args={10,-5,5,"target",0} },
  { op="delay", frames=16 },
  { op="createvisualtask", task="AnimTask_ScaleMonAndRestore", priority=5, args={10,-5,5,"target",0} },
  { op="delay", frames=16 },
  { op="waitforvisualfinish" },
  { op="end" },
}

-- FireRed Status_BindWrap presentation, mapped onto Gen1Recomp's locked Bind
-- continuation rows. Gen1Recomp intentionally keeps Gen-1 trapping mechanics
-- (the trapping move replays on each continuation), so the bridge selects this
-- visual-only branch once trapMove == BIND instead of changing battle logic.
--
-- Native FireRed sets shared anim arg 7 to 0xFFFF at script frame 30. The
-- runtime-only fifth sprite argument below stores that exact release delay for
-- deterministic planning: 30 frames for the first tendril and 23 for the one
-- created seven frames later. It is not a FireRed callback argument.
M.trapContinuationScript = {
  { op="loadspritegfx", tag=10186 }, -- ANIM_TAG_TENDRILS
  { op="loopsewithpan", sound=148, pan="target", interval=6, count=2 }, -- SE_M_SCRATCH
  { op="createsprite", template="gConstrictBindingSpriteTemplate", anchor="target", priority=4,
    args={0,16,0,1,30} },
  { op="delay", frames=7 },
  { op="createsprite", template="gConstrictBindingSpriteTemplate", anchor="target", priority=2,
    args={0,8,1,1,23} },
  { op="delay", frames=3 },
  { op="createvisualtask", task="AnimTask_ShakeMon2", priority=2, args={"target",2,0,8,1} },
  { op="delay", frames=20 },
  { op="playsewithpan", sound=163, pan="target" }, -- SE_M_BIND; source setarg 7,0xFFFF occurs here
  { op="waitforvisualfinish" },
  { op="end" },
}

M.templates = {
  gConstrictBindingSpriteTemplate = {
    tileTag=10186,paletteTag=10186,callback="AnimConstrictBinding",
    oam={affine=true,objMode="normal",bpp=4,width=64,height=32},
    anim={kind="once",frames={
      {tileOffset=0,duration=4},
      {tileOffset=32,duration=4},
      {tileOffset=64,duration=4},
      {tileOffset=96,duration=4},
    }},
  },
}
return M
