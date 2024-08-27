local thisAddonName = ...

local f = EnumerateFrames()
while f do
  f:UnregisterAllEvents()
  if f ~= WorldFrame then
    f:Hide()
  end
  f = EnumerateFrames(f)
end

local state = {
  bindings = {},
  bindkeys = {},
  camping = false,
  chatchannels = {},
  cursor = 0,
  expectflags = false,
  factions = {},
  gossiping = false,
  loaded = false,
  mousedown = {},
  moving = false,
  quest = false,
  quitting = false,
  training = false,
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
  DISPLAY_SIZE_CHANGED = nop,
  FIRST_FRAME_RENDERED = nop,
  GLOBAL_MOUSE_DOWN = function(b)
    assert(state.mousedown[b] == nil)
    state.mousedown[b] = true
  end,
  GLOBAL_MOUSE_UP = function(b)
    assert(state.mousedown[b] == true)
    state.mousedown[b] = nil
  end,
  GOSSIP_CONFIRM_CANCEL = function()
    print('[gossip][confirm cancel]')
  end,
  GOSSIP_CLOSED = function()
    assert(state.gossiping)
    state.gossiping = false
    print('[gossip][closed]')
  end,
  GOSSIP_SHOW = function()
    assert(not state.gossiping)
    state.gossiping = true
    print('[gossip] ' .. C_GossipInfo.GetText())
    local t = {}
    for i, o in ipairs(C_GossipInfo.GetOptions()) do
      print(('[gossip][%d][icon:%d] %s'):format(o.gossipOptionID, o.icon, o.name))
      t[o.gossipOptionID] = o.icon
    end
    local auto = {
      [132058] = 'training',
    }
    local k, v = next(t)
    if not next(t, k) and auto[v] then
      print('[gossip] auto-selecting ' .. auto[v])
      C_GossipInfo.SelectOption(k)
    end
  end,
  MODIFIER_STATE_CHANGED = function()
    -- This is not reliable since Is*KeyDown functions can get out of sync
    -- with these events, e.g. Alt-Tabbing out of the game releases the
    -- modifier per IsAltKeyDown but a corresponding event does not fire.
  end,
  PLAYER_AVG_ITEM_LEVEL_UPDATE = nop,
  PLAYER_CAMPING = function()
    assert(not state.camping)
    assert(not state.quitting)
    assert(not state.expectflags)
    state.camping = true
    state.expectflags = true
    print('camping!')
  end,
  PLAYER_INTERACTION_MANAGER_FRAME_HIDE = nop,
  PLAYER_INTERACTION_MANAGER_FRAME_SHOW = nop,
  PLAYER_QUITING = function()
    assert(not state.camping)
    assert(not state.quitting)
    assert(not state.expectflags)
    state.quitting = true
    state.expectflags = true
    print('quitting!')
  end,
  PLAYER_SOFT_TARGET_INTERACTION = nop,
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
  QUEST_DETAIL = function()
    assert(not state.quest)
    state.quest = true
    print('[quest] (' .. GetQuestID() .. ') ' .. GetTitleText() .. '\n' .. GetQuestText())
    print('[quest][objective] ' .. GetObjectiveText())
  end,
  QUEST_FINISHED = function()
    -- Cannot assert since it can fire multiple times.
    if state.quest then
      state.quest = false
      print('[quest] finished')
    end
  end,
  RAID_TARGET_UPDATE = function()
    local old = state.playerraidtarget
    local new = GetRaidTargetIndex('player')
    if old ~= new then
      print('player raid target was ' .. tostring(old) .. ', now ' .. tostring(new))
    end
    state.playerraidtarget = new
  end,
  SPELL_ACTIVATION_OVERLAY_HIDE = nop,
  SPELL_UPDATE_USABLE = nop,
  TRAINER_CLOSED = function()
    assert(state.training)
    state.training = false
    print('[trainer][closed]')
  end,
  TRAINER_SHOW = (function()
    -- Trainers should show us everything they can handle.
    SetTrainerServiceTypeFilter('available', 1)
    SetTrainerServiceTypeFilter('unavailable', 1)
    SetTrainerServiceTypeFilter('used', 1)
    local trainershow = false
    return function()
      if trainershow then
        assert(not state.training)
        state.training = true
        print('[trainer] ' .. GetTrainerGreetingText())
        for i = 1, GetNumTrainerServices() do
          local name, rank, category, expanded = GetTrainerServiceInfo(i)
          if expanded ~= 1 then
            print('[trainer][%d] error: unexpected expanded=0')
          end
          if category == 'available' then
            local lvl = GetTrainerServiceLevelReq(i)
            local cost = GetTrainerServiceCost(i)
            print(('[trainer][%d][L%d][%dc] %s(%s)'):format(i, lvl, cost, name, rank or '<>'))
          end
        end
      end
      -- It fires twice; ignore the first.
      trainershow = not trainershow
    end
  end)(),
  UI_ERROR_MESSAGE = function(id, s)
    local str = GetGameMessageInfo(id)
    assert(_G[str] == s)
    assert(_G['LE_GAME_' .. str] == id)
    print(('[error][%d][%s] %s'):format(id, str, s))
  end,
  UI_SCALE_CHANGED = nop,
  UNIT_FLAGS = function(unit)
    if unit == 'player' and state.expectflags then
      state.expectflags = false
      return
    end
    assert(not state.expectflags)
    if unit == 'player' and state.camping then
      print('cancel camp')
      state.camping = false
      return
    end
    if unit == 'player' and state.quitting then
      print('cancel quit')
      state.quitting = false
      return
    end
    print('unsupported UNIT_FLAGS with ' .. unit)
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
  UPDATE_FACTION = (function()
    local processing = false
    return function()
      if not processing then
        processing = true
        do
          local i, n = 0, GetNumFactions()
          while i < n do
            i = i + 1
            local isHeader, isCollapsed = select(9, GetFactionInfo(i))
            if isCollapsed then
              assert(isHeader)
              ExpandFactionHeader(i)
              n = GetNumFactions()
            end
          end
        end
        table.wipe(state.factions)
        for i = 1, GetNumFactions() do
          local name, _, _, _, _, barValue, _, _, isHeader, isCollapsed = GetFactionInfo(i)
          if isHeader then
            assert(not isCollapsed)
          else
            state.factions[name] = barValue
          end
        end
        print('faction update!')
        processing = false
      end
    end
  end)(),
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

seterrorhandler(function(s)
  print('lua error: ' .. s)
end)

local quitButton = CreateFrame('Button', 'GroundUpQuitButton', nil, 'SecureActionButtonTemplate')
quitButton:SetAttribute('type', 'macro')
quitButton:SetAttribute('macrotext', '/quit')

local lsmt = {
  __index = function(t, k)
    return k == 'print' and print or _G[k]
  end,
}

local function run(cmd)
  if cmd:sub(1, 1) == '.' then
    setfenv(loadstring(cmd:sub(2), '@'), setmetatable({}, lsmt))()
  elseif cmd:sub(1, 5) == 'echo ' then
    print('[echo] ' .. cmd:sub(6))
  elseif cmd == 'factions' then
    for k, v in pairs(state.factions) do
      print('[faction] ' .. k .. ': ' .. v)
    end
  elseif cmd == 'quest accept' and state.quest then
    AcceptQuest()
  elseif cmd == 'quest decline' and state.quest then
    DeclineQuest()
  elseif cmd == 'noquit' then
    CancelLogout()
  elseif cmd == 'reload' then
    ReloadUI()
  elseif cmd:sub(1, 6) == 'train ' then
    BuyTrainerService(tonumber(cmd:sub(7)))
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
e:SetScript('OnEnterPressed', function()
  run(e:GetText())
  e:SetText('')
end)
e:SetScript('OnEscapePressed', function()
  e:ClearFocus()
end)

GroundUp = {
  Bindings = {
    FocusCommandLine = function()
      e:SetFocus()
    end,
  },
}

local bindings = {
  ['ALT-CTRL-Q'] = 'CLICK GroundUpQuitButton:LeftButton',
  ['SHIFT-T'] = 'INTERACTMOUSEOVER',
  ['T'] = 'INTERACTTARGET',
  ['.'] = 'GROUNDUP_FOCUS_COMMAND_LINE',
}
for k, v in pairs(bindings) do
  SetOverrideBinding(WorldFrame, false, k, v)
end
