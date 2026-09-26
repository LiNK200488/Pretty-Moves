local M = { id="FLASH", name="Flash" }

M.soundIds = {185}

-- FireRed Move_FLASH: SE_M_LEER followed by AnimTask_Flash. The task
-- immediately forces all battler OBJ palettes to black and the battle BG
-- palette to white, holds, then restores both over the native 16 blend steps.
M.script = {
  { op="playsewithpan", sound=185, pan="attacker" }, -- SE_M_LEER
  { op="createvisualtask", task="AnimTask_Flash", priority=2 },
  { op="waitforvisualfinish" },
  { op="end" },
}

return M
