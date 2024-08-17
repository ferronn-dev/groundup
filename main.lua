local thisAddonName = ...

local state = {
  cursor = 0,
  loaded = false,
  moving = false,
  turning = false,
}

local print = (function()
  local m = CreateFrame('MessageFrame')
  m:SetAllPoints()
  m:SetFontObject(GameFontNormalLeft)
  m:SetTimeVisible(3.402823e38)
  local tick = 0
  m:SetScript('OnUpdate', function()
    tick = tick + 1
  end)
  return function(s)
    m:AddMessage('[' .. tick .. '] ' .. tostring(s))
  end
end)()

local handlers = {
  ADDON_ACTION_BLOCKED = function()
    print('addon action blocked!')
  end,
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
  CURSOR_CHANGED = function(isDefault, new, old)
    print('isDefault = ' .. tostring(isDefault))
    print('new = ' .. new)
    print('old = ' .. old)
    assert(isDefault == (new == 0))
    if new == old then
      -- The event fires for things that change the default cursor
      -- in the 3D world, but doesn't expose what's being moused over
      -- (e.g. vendor, repair, attack).
      assert(isDefault)
    else
      assert(new ~= old)
      assert(state.cursor == old)
      state.cursor = new
      print('cursor: ' .. old .. ' -> ' .. new)
    end
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

local f = CreateFrame('Frame')
f:SetScript('OnEvent', function(_, ev, ...)
  local h = handlers[ev]
  if h then
    h(...)
  else
    print('unsupported event ' .. ev)
  end
end)
f:RegisterAllEvents()

SetOverrideBinding(WorldFrame, false, 'ALT-R', 'GROUNDUP_RELOADUI')
SetOverrideBinding(WorldFrame, false, 'ALT-Z', 'GROUNDUP_TOGGLEUI')
seterrorhandler(function(s)
  print('lua error: ' .. s)
end)

local hidden = CreateFrame('Frame')
hidden:Hide()
UIParent:SetParent(hidden)

GroundUp = {
  Bindings = {
    ReloadUI = ReloadUI,
    ToggleUI = function()
      UIParent:SetParent(not UIParent:GetParent() and hidden or nil)
      UIParent:SetAllPoints()
    end,
  }
}
