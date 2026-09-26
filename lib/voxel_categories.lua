-- Global FireRed -> staged-voxel effect classification.
--
-- Categories describe WHERE an effect belongs in the 3D battle scene, not
-- which move owns it. A move can therefore mix categories safely.
--   arena   : shared player<->enemy animation plane (projectiles, beams, hits)
--   upright : local camera-facing billboard attached to one battler
--   ground  : local ground-anchored billboard attached to one battler's feet
local M = {}

M.ARENA   = "arena"
M.UPRIGHT = "upright"
M.GROUND  = "ground"

-- Move-level defaults. Everything not listed is arena by design. These entries
-- document moves whose principal custom sprite layer is local; event overrides
-- below still take precedence for mixed animations.
M.moveDefaults = {
  NIGHT_SHADE = { category=M.UPRIGHT, side="attacker" },
  DIG = { category=M.GROUND, side="attacker" },
  SWORDS_DANCE = { category=M.UPRIGHT, side="attacker" },
  REFLECT = { category=M.UPRIGHT, side="attacker" },
  LIGHT_SCREEN = { category=M.UPRIGHT, side="attacker" },
  MIST = { category=M.UPRIGHT, side="attacker" },
  METRONOME = { category=M.UPRIGHT, side="attacker" },
}

-- Exact event/motion overrides. side says which battler owns the local plane.
-- Keep this list conservative: only effects whose FireRed semantics are
-- unambiguously local are moved off the shared arena plane.
M.kindRules = {
  night_shade_clone = { category=M.UPRIGHT, side="attacker" },
  double_team_clones = { category=M.UPRIGHT, side="attacker" },
  smokescreen_impact = { category=M.UPRIGHT, side="target" },
}

M.motionRules = {
  -- Ground-attached Dig art.
  dig_dirt_mound = { category=M.GROUND, side="attacker" },
  dirt_plume = { category=M.GROUND, side="attacker" },

  -- Substitute is battler-local: keep the falling/bouncing doll on the same
  -- upright local plane used by the staged battler instead of the arena plane.
  substitute_doll_bounce = { category=M.UPRIGHT, side="attacker" },

  -- Local actor/aura/UI-like move sprites.
  defensive_wall = { category=M.UPRIGHT, side="attacker" },
  wall_sparkle = { category=M.UPRIGHT, side="attacker" },
  swords_dance_blade = { category=M.UPRIGHT, side="attacker" },
  metronome_finger = { category=M.UPRIGHT, side="attacker" },
  metronome_thought_bubble = { category=M.UPRIGHT, side="attacker" },
  glare_eye_sparkle = { category=M.UPRIGHT, side="attacker" },
  question_mark = { category=M.UPRIGHT, side="attacker" },
  swirling_fog = { category=M.UPRIGHT, side="attacker" },
  string_shot_wrap = { category=M.UPRIGHT, side="target" },
  constrict_binding = { category=M.UPRIGHT, side="target" },
  thunder_wave_band = { category=M.UPRIGHT, side="target" },
}

local function moveId(active)
  local m=active and active.move
  return m and tostring(m.id or m.name or ""):upper() or ""
end

function M.classify(active,event)
  if type(event)~="table" then return M.ARENA,nil end
  local r=M.kindRules[event.kind]
  if r then return r.category,r.side end
  local motion=event.motion
  r=type(motion)=="table" and M.motionRules[motion.kind] or nil
  if r then return r.category,r.side end
  local d=M.moveDefaults[moveId(active)]
  if d then return d.category,d.side end
  return M.ARENA,nil
end

function M.matches(active,event,category,side)
  if not category then return true end
  local c,s=M.classify(active,event)
  if c~=category then return false end
  if side and s and s~=side then return false end
  if side and not s then return false end
  return true
end

function M.summary()
  local moves={arena="default",upright={},ground={}}
  for id,d in pairs(M.moveDefaults) do
    if d.category==M.UPRIGHT then moves.upright[#moves.upright+1]=id
    elseif d.category==M.GROUND then moves.ground[#moves.ground+1]=id end
  end
  table.sort(moves.upright); table.sort(moves.ground)
  return moves
end

return M
