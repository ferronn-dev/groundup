local thisAddonName = ...

local state = {
  bindings = {},
  bindkeys = {},
  chatchannels = {},
  cursor = 0,
  loaded = false,
  moving = false,
  turning = false,
}

local function ensuret(t, k)
  local v = t[k]
  if not v then
    v = {}
    t[k] = v
  end
  return v
end

local print = (function()
  local m = CreateFrame('MessageFrame')
  m:SetAllPoints()
  m:SetFontObject(GameFontNormalSmallLeft)
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
    print('[console] ' .. s)
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
  CVAR_UPDATE = function(eventName, value)
    print('[cvar] ' .. eventName .. ': ' .. value)
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
  SPELL_ACTIVATION_OVERLAY_HIDE = function()
    -- Unclear why it fires, but nothing listens to it in classic.
  end,
  UI_ERROR_MESSAGE = function(_, s)
    print('ERROR: ' .. s)
  end,
  UPDATE_BINDINGS = (function()
    local process = function(command, category, ...)
      state.bindings[command] = category
      for i = 1, select('#', ...) do
        state.bindkeys[select(i, ...)] = command
      end
    end
    return function()
      for i = 1, GetNumBindings() do
        process(GetBinding(i))
      end
    end
  end)(),
  UPDATE_CHAT_COLOR = function(name, r, g, b)
    Mixin(ensuret(state.chatchannels, name), { r = r, g = g, b = b })
  end,
  UPDATE_CHAT_COLOR_NAME_BY_CLASS = function(name, colorNameByClass)
    Mixin(ensuret(state.chatchannels, name), { colorNameByClass = colorNameByClass })
  end,
  UPDATE_MOUSEOVER_UNIT = function()
    local m = UnitGUID('mouseover')
    state.mouseoverunit = (state.mouseoverunit ~= m) and m or nil
    print('mouseoverunit is now ' .. tostring(state.mouseoverunit))
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
  },
}
