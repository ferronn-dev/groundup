local thisAddonName = ...

local state = {
  bindings = {},
  bindkeys = {},
  chatchannels = {},
  cursor = 0,
  loaded = false,
  mousedown = {},
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
  local t = m:CreateTexture()
  t:SetAllPoints()
  t:SetColorTexture(0, 0, 0, 0.9)
  m:SetFont(('Interface\\AddOns\\%s\\Inconsolata.ttf'):format(thisAddonName), 10, '')
  m:SetJustifyH('LEFT')
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
  ARENA_TEAM_ROSTER_UPDATE = function()
    -- Fires three times as part of the login process; that's it.
  end,
  BN_FRIEND_INFO_CHANGED = function()
    -- Just ignoring battle.net stuff for now.
  end,
  CHAT_MSG_BN_INLINE_TOAST_ALERT = function(s)
    print('[chat][bn]: ' .. s)
  end,
  CHAT_MSG_CHANNEL = function(s, p, _, c)
    print(('[chat][%s][%s]: %s'):format(c, p, s))
  end,
  CHAT_MSG_SYSTEM = function(s)
    print('[chat][system] ' .. s)
  end,
  CONSOLE_MESSAGE = function(s)
    print('[console] ' .. s)
  end,
  CORPSE_POSITION_UPDATE = function(...)
    -- This seems to fire at random times, just eat it for now.
    assert(select('#', ...) == 0)
  end,
  CURSOR_CHANGED = function(isDefault, new, old)
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
    end
  end,
  CVAR_UPDATE = function(eventName, value)
    print('[cvar] ' .. eventName .. ': ' .. value)
  end,
  GLOBAL_MOUSE_DOWN = function(b)
    assert(state.mousedown[b] == nil)
    state.mousedown[b] = true
  end,
  GLOBAL_MOUSE_UP = function(b)
    assert(state.mousedown[b] == true)
    state.mousedown[b] = nil
  end,
  MODIFIER_STATE_CHANGED = function()
    -- This is not reliable since Is*KeyDown functions can get out of sync
    -- with these events, e.g. Alt-Tabbing out of the game releases the
    -- modifier per IsAltKeyDown but a corresponding event does not fire.
  end,
  PLAYER_STARTED_LOOKING = function()
    assert(not state.looking)
    state.looking = true
  end,
  PLAYER_STARTED_MOVING = function()
    assert(not state.moving)
    state.moving = true
  end,
  PLAYER_STARTED_TURNING = function()
    assert(not state.turning)
    state.turning = true
  end,
  PLAYER_STOPPED_LOOKING = function()
    assert(state.looking)
    state.looking = false
  end,
  PLAYER_STOPPED_MOVING = function()
    assert(state.moving)
    state.moving = false
  end,
  PLAYER_STOPPED_TURNING = function()
    assert(state.turning)
    state.turning = false
  end,
  SPELL_ACTIVATION_OVERLAY_HIDE = function()
    -- Unclear why it fires, but nothing listens to it in classic.
  end,
  SPELL_UPDATE_USABLE = function()
    -- Doesn't seem to communicate any useful information.
  end,
  UI_ERROR_MESSAGE = function(_, s)
    print('ERROR: ' .. s)
  end,
  UI_SCALE_CHANGED = function()
    -- Do nothing.
  end,
  UPDATE_BINDINGS = (function()
    local process = function(command, category, ...)
      state.bindings[command] = category
      for i = 1, select('#', ...) do
        state.bindkeys[select(i, ...)] = command
      end
    end
    return function()
      state.bindings = {}
      state.bindkeys = {}
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
