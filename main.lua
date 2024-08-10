local thisAddonName = ...

local state = {
  loaded = false,
  moving = false,
  turning = false,
}

local print = (function()
  local m = CreateFrame('MessageFrame')
  m:SetAllPoints()
  m:SetFontObject(GameFontNormalLeft)
  m:SetTimeVisible(3.402823e38)
  return function(s)
    m:AddMessage(s)
  end
end)()

local handlers = {
  ADDON_LOADED = function(addonName, containsBindings)
    if addnoName == thisAddonName then
      assert(containsBindings == false)
      assert(not state.loaded)
      state.loaded = true
    end
  end,
  CONSOLE_MESSAGE = function(s)
    print('console: ' .. s)
  end,
  PLAYER_STARTED_MOVING = function()
    assert(not state.moving)
    state.moving = true
    print('moving: false -> true')
  end,
  PLAYER_STOPPED_MOVING = function()
    assert(state.moving)
    state.moving = false
    print('moving: true -> false')
  end,
  PLAYER_STARTED_TURNING = function()
    assert(not state.turning)
    state.turning = true
    print('turning: false -> true')
  end,
  PLAYER_STOPPED_TURNING = function()
    assert(state.turning)
    state.turning = false
    print('turning: true -> false')
  end,
  UI_ERROR_MESSAGE = function(_, s)
    print('ERROR: ' .. s)
  end,
}

local reported = {}
local f = CreateFrame('Frame')
f:SetScript('OnEvent', function(_, ev, ...)
  local h = handlers[ev]
  if h then
    h(...)
  elseif not reported[ev] then
    print('unsupported event ' .. ev)
    reported[ev] = true
  end
end)
f:RegisterAllEvents()

UIParent:Hide()

SetOverrideBinding(WorldFrame, false, 'ALT-R', 'GROUNDUP_RELOADUI')
