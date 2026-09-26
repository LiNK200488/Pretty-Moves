local M = {}

function M.validate(rom)
  if rom:size() ~= 16777216 then error("Expected a 16 MiB FireRed ROM", 2) end
  local title = rom:ascii(0xA0, 12)
  local gameCode = rom:ascii(0xAC, 4)
  local makerCode = rom:ascii(0xB0, 2)
  local revision = rom:u8(0xBC)
  if title ~= "POKEMON FIRE" then error("Unexpected GBA title: " .. tostring(title), 2) end
  if gameCode ~= "BPRE" then error("Expected English FireRed game code BPRE, got " .. tostring(gameCode), 2) end
  if revision ~= 0 then error("This build supports FireRed revision 0 only", 2) end
  return { title = title, gameCode = gameCode, makerCode = makerCode, revision = revision }
end

M.ANIM_SPRITES_START = 10000
M.animTags = {
  SMALL_EMBER = 10029,
}

M.animOpcode = {
  LOAD_SPRITE_GFX = 0x00, UNLOAD_SPRITE_GFX = 0x01,
  CREATE_SPRITE = 0x02, CREATE_VISUAL_TASK = 0x03,
  DELAY = 0x04, WAIT_FOR_VISUAL_FINISH = 0x05,
  HANG_1 = 0x06, HANG_2 = 0x07, END_ANIM = 0x08,
  PLAY_SE = 0x09, MON_BG = 0x0A, CLEAR_MON_BG = 0x0B,
  SET_ALPHA = 0x0C, BLEND_OFF = 0x0D, CALL = 0x0E,
  RETURN = 0x0F, SET_ARG = 0x10, CHOOSE_TWO_TURN_ANIM = 0x11,
  JUMP_IF_MOVE_TURN = 0x12, GOTO = 0x13, FADE_TO_BG = 0x14,
  RESTORE_BG = 0x15, WAIT_BG_FADE_OUT = 0x16, WAIT_BG_FADE_IN = 0x17,
  CHANGE_BG = 0x18, PLAY_SE_WITH_PAN = 0x19, SET_PAN = 0x1A,
  PAN_SE = 0x1B, LOOP_SE_WITH_PAN = 0x1C, WAIT_PLAY_SE_WITH_PAN = 0x1D,
  SET_BLDCNT = 0x1E, CREATE_SOUND_TASK = 0x1F, WAIT_SOUND = 0x20,
  JUMP_ARG_EQ = 0x21, MON_BG_STATIC = 0x22, CLEAR_MON_BG_STATIC = 0x23,
  JUMP_IF_CONTEST = 0x24, FADE_TO_BG_FROM_SET = 0x25,
  PAN_SE_ADJUST_NONE = 0x26, PAN_SE_ADJUST_ALL = 0x27,
  SPLIT_BG_PRIO = 0x28, SPLIT_BG_PRIO_ALL = 0x29,
  SPLIT_BG_PRIO_FOES = 0x2A, INVISIBLE = 0x2B, VISIBLE = 0x2C,
  TEAM_ATTACK_MOVEBACK = 0x2D, TEAM_ATTACK_MOVEFWD = 0x2E,
  STOP_SOUND = 0x2F,
}

return M
