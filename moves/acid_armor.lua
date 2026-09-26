local M = { id="ACID_ARMOR", name="Acid Armor" }

-- Exact FireRed Move_ACID_ARMOR choreography. The visual task distorts the
-- attacker with a scanline wave while fading it out, pauses briefly, then
-- restores it. No separate sprite asset is used.
M.script = {
  { op="monbg", battler="attacker" },
  { op="setalpha", eva=15, evb=0 },
  { op="createvisualtask", task="AnimTask_AcidArmor", priority=2, args={"attacker"} },
  { op="playsewithpan", sound=211, pan="attacker" }, -- SE_M_ACID_ARMOR
  { op="waitforvisualfinish" },
  { op="blendoff" },
  { op="clearmonbg", battler="attacker" },
  { op="delay", frames=1 },
  { op="end" },
}

return M
