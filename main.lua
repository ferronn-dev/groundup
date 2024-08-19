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

local pw, ph = GetPhysicalScreenSize()
local lh = 768
local lw = pw / ph * lh

WorldFrame:ClearAllPoints()
WorldFrame:SetPoint('TOPLEFT')
WorldFrame:SetHeight(lh / 2)
WorldFrame:SetWidth(lw / 2)

local print = (function()
  local m = CreateFrame('MessageFrame')
  m:SetPoint('TOPRIGHT')
  m:SetPoint('BOTTOM')
  m:SetWidth(lw / 2)
  m:SetFont(('Interface\\AddOns\\%s\\Inconsolata.ttf'):format(thisAddonName), 10, '')
  m:SetJustifyH('LEFT')
  m:SetTimeVisible(3.402823e38)
  local tick = 0
  m:SetScript('OnUpdate', function()
    tick = tick + 1
  end)
  return function(s)
    m:AddMessage('[' .. tick .. '] ' .. tostring(s), 0, 1, 0)
  end
end)()

local function nop() end

local handlers = {
  ACTIONBAR_UPDATE_STATE = nop,
  ADDON_ACTION_BLOCKED = function()
    print('addon action blocked!')
  end,
  ADDON_ACTION_FORBIDDEN = function(taint, func)
    print(('[ERROR] forbidden from calling %s (%s)'):format(func, taint))
  end,
  ADDON_LOADED = function(addonName, containsBindings)
    if addnoName == thisAddonName then
      assert(containsBindings == false)
      assert(not state.loaded)
      state.loaded = true
    end
  end,
  ARENA_TEAM_ROSTER_UPDATE = nop,
  BN_FRIEND_ACCOUNT_OFFLINE = nop,
  BN_FRIEND_ACCOUNT_ONLINE = nop,
  BN_FRIEND_INFO_CHANGED = nop,
  CHAT_MSG_BN_INLINE_TOAST_ALERT = function(s)
    print('[chat][bn]: ' .. s)
  end,
  CHAT_MSG_CHANNEL = function(s, p, _, c)
    print(('[chat][%s][%s]: %s'):format(c, p, s))
  end,
  CHAT_MSG_SAY = function(s)
    print('[chat][say] ' .. s)
  end,
  CHAT_MSG_SYSTEM = function(s)
    print('[chat][system] ' .. s)
  end,
  CHAT_MSG_TEXT_EMOTE = function(s)
    print('[chat][emote] ' .. s)
  end,
  CONSOLE_MESSAGE = function(s)
    print('[console] ' .. s)
  end,
  CORPSE_POSITION_UPDATE = function(...)
    -- This seems to fire at random times, just eat it for now.
    assert(select('#', ...) == 0)
  end,
  CURRENT_SPELL_CAST_CHANGED = function()
    -- Accepts a cancelledCast argument.
    -- Very noisy even when doing nothing, so eating for now.
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
  FIRST_FRAME_RENDERED = nop,
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
  PLAYER_AVG_ITEM_LEVEL_UPDATE = nop,
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
  SPELL_ACTIVATION_OVERLAY_HIDE = nop,
  SPELL_UPDATE_USABLE = nop,
  UI_ERROR_MESSAGE = function(_, s)
    print('ERROR: ' .. s)
  end,
  UI_SCALE_CHANGED = nop,
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
  UPDATE_FACTION = function()
    print('GetNumFactions() = ' .. GetNumFactions())
  end,
  UPDATE_FLOATING_CHAT_WINDOWS = nop,
  UPDATE_INVENTORY_DURABILITY = function()
    local c, m = 0, 0
    for i = 0, 19 do
      local cc, mm = GetInventoryItemDurability(i)
      if cc then
        c = c + cc
        m = m + mm
      end
    end
    print(('durability %d/%d (%d%%)'):format(c, m, m == 0 and 0 or c / m * 100))
  end,
  UPDATE_MOUSEOVER_UNIT = function()
    local m = UnitGUID('mouseover')
    state.mouseoverunit = (state.mouseoverunit ~= m) and m or nil
  end,
  UPDATE_SHAPESHIFT_FORM = function()
    -- We'll probably want to resurrect this at some point, but for now it's just noise.
  end,
  UPDATE_WEB_TICKET = nop,
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

SetOverrideBinding(WorldFrame, false, 'ALT-Z', 'GROUNDUP_TOGGLEUI')
seterrorhandler(function(s)
  print('lua error: ' .. s)
end)

local hidden = CreateFrame('Frame')
hidden:Hide()
UIParent:SetParent(hidden)

GroundUp = {
  Bindings = {
    ToggleUI = function()
      UIParent:SetParent(not UIParent:GetParent() and hidden or nil)
      UIParent:SetAllPoints()
    end,
  },
}

local function run(cmd)
  if cmd:sub(1, 1) == '.' then
    loadstring(cmd:sub(2), '@')()
  elseif cmd:sub(1, 5) == 'echo ' then
    print('[echo] ' .. cmd:sub(6))
  else
    print('[error] bad command')
  end
end

local e = CreateFrame('EditBox')
e:SetPoint('BOTTOMLEFT')
e:SetWidth(lw / 2)
e:SetHeight(20)
e:SetFont(('Interface\\AddOns\\%s\\Inconsolata.ttf'):format(thisAddonName), 10, '')
e:SetTextColor(0, 1, 0)
e:SetText('')
e:SetAutoFocus(false)
e:SetFocus()
e:SetScript('OnEnterPressed', function()
  run(e:GetText())
  e:SetText('')
end)
e:SetScript('OnEscapePressed', function()
  e:ClearFocus()
end)
