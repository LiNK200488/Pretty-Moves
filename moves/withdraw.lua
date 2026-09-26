local M = { id="WITHDRAW", name="Withdraw" }

M.soundIds = {155}

-- FireRed Move_WITHDRAW: play SE_M_HEADBUTT, rotate the attacker into the
-- withdrawn pose over 22 callbacks, hold for 30 callbacks, then rotate back
-- over 22 callbacks. SetBattlerSpriteYOffsetFromRotation keeps the battler
-- visually planted while the OBJ affine rotation is active.
M.script = {
  { op="playsewithpan", sound=155, pan="attacker" }, -- SE_M_HEADBUTT
  { op="createvisualtask", task="AnimTask_Withdraw", priority=5 },
  { op="waitforvisualfinish" },
  { op="end" },
}

return M
