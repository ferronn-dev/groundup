local thisAddonName = ...

local bindings = {
  ['ALT-CTRL-Q'] = 'CLICK GroundUpSecureButton:quit',
  ['ALT-CTRL-W'] = 'CLICK GroundUpSecureButton:logout',
  ['SHIFT-T'] = 'INTERACTMOUSEOVER',
  ['SHIFT-MOUSEWHEELDOWN'] = 'CAMERAZOOMOUT',
  ['SHIFT-MOUSEWHEELUP'] = 'CAMERAZOOMIN',
  ['`'] = 'TOGGLEAUTORUN',
  ['Q'] = 'STRAFELEFT',
  ['W'] = 'MOVEFORWARD',
  ['E'] = 'STRAFERIGHT',
  ['T'] = 'INTERACTTARGET',
  ['S'] = 'MOVEBACKWARD',
  ['.'] = 'CLICK GroundUpSecureButton:focus',
  ['SPACE'] = 'JUMP',
  ['UP'] = 'MOVEFORWARD',
  ['LEFT'] = 'TURNLEFT',
  ['DOWN'] = 'MOVEBACKWARD',
  ['RIGHT'] = 'TURNRIGHT',
}

do
  local f = EnumerateFrames()
  while f do
    f:UnregisterAllEvents()
    if f ~= WorldFrame then
      f:Hide()
    end
    f = EnumerateFrames(f)
  end
end

local state = {
  camping = false,
  chatchannels = {},
  cursor = 0,
  expectflags = false,
  factions = {},
  merching = false,
  gossiping = false,
  loaded = false,
  loggedin = false,
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

local function update(k, new)
  local old = state[k]
  if old ~= new then
    print(('updating %s from %q to %q'):format(k, tostring(old), tostring(new)))
    state[k] = new
  end
end

local handlers = {
  ACTIONBAR_UPDATE_STATE = nop,
  ADDON_ACTION_BLOCKED = function()
    print('addon action blocked!')
  end,
  ADDON_ACTION_FORBIDDEN = function(taint, func)
    print(('[ERROR] forbidden from calling %s (%s)'):format(func, taint))
  end,
  ADDON_LOADED = function(addonName, containsBindings)
    if addonName == thisAddonName then
      assert(containsBindings == false)
      assert(not state.loaded)
      state.loaded = true
    end
  end,
  AREA_POIS_UPDATED = nop,
  ARENA_OPPONENT_UPDATE = nop,
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
  CHAT_MSG_MONSTER_SAY = function(s)
    print('[chat][monster] ' .. s)
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
  COMBAT_LOG_EVENT = nop, -- TODO process
  COMBAT_LOG_EVENT_UNFILTERED = nop, -- TODO process
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
    local options = C_GossipInfo.GetOptions()
    for _, o in ipairs(options) do
      print(('[gossip][%d][icon:%d] %s'):format(o.gossipOptionID, o.icon, o.name))
    end
    local availableQuests = C_GossipInfo.GetAvailableQuests()
    for i, q in ipairs(availableQuests) do
      print(('[gossip][!%d][id:%d] %s'):format(i, q.questID, q.title))
    end
    local activeQuests = C_GossipInfo.GetActiveQuests()
    for i, q in ipairs(activeQuests) do
      print(('[gossip][?%d][id:%d] %s'):format(i, q.questID, q.title))
    end
    local no, nav, nac = #options, #availableQuests, #activeQuests
    if no == 0 and nav == 0 and nac == 0 then
      -- If we do this in the same frame, GOSSIP_CLOSED doesn't fire.
      C_Timer.After(0, function()
        C_GossipInfo.CloseGossip()
      end)
    elseif no == 1 and nav == 0 and nac == 0 then
      print('[gossip] auto-selecting option')
      C_GossipInfo.SelectOption(options[1].gossipOptionID)
    elseif no == 0 and nav == 1 and nac == 0 then
      print('[gossip] auto-selecting available quest')
      C_GossipInfo.SelectAvailableQuest(availableQuests[1].questID)
    elseif no == 0 and nav == 0 and nac == 1 then
      print('[gossip] auto-selecting active quest')
      C_GossipInfo.SelectActiveQuest(activeQuests[1].questID)
    end
  end,
  LUA_WARNING = function(ty, msg)
    print(('[warning][%d] %s'):format(ty, msg))
  end,
  MERCHANT_CLOSED = function()
    assert(state.merching)
    state.merching = false
    print('[merchant][closed]')
  end,
  MERCHANT_SHOW = function()
    assert(not state.merching)
    state.merching = true
    for i = 1, GetMerchantNumItems() do
      print('[merchant] ' .. tostring(GetMerchantItemInfo(i)))
    end
  end,
  MODIFIER_STATE_CHANGED = function()
    -- This is not reliable since Is*KeyDown functions can get out of sync
    -- with these events, e.g. Alt-Tabbing out of the game releases the
    -- modifier per IsAltKeyDown but a corresponding event does not fire.
  end,
  NEW_WMO_CHUNK = nop,
  PLAYER_AVG_ITEM_LEVEL_UPDATE = nop,
  PLAYER_CAMPING = function()
    assert(not state.camping)
    assert(not state.quitting)
    assert(not state.expectflags)
    state.camping = true
    state.expectflags = true
    print('camping!')
  end,
  PLAYER_ENTERING_WORLD = function()
    update('zone', GetZoneText())
    update('subzone', GetSubZoneText())
    for i = 1, GetNumBindings() do
      local t = { GetBinding(i) }
      for j = 3, #t do
        SetOverrideBinding(WorldFrame, false, t[j], ' ')
      end
    end
    for k, v in pairs(bindings) do
      SetOverrideBinding(WorldFrame, false, k, v)
    end
  end,
  PLAYER_INTERACTION_MANAGER_FRAME_HIDE = nop,
  PLAYER_INTERACTION_MANAGER_FRAME_SHOW = nop,
  PLAYER_LOGIN = function()
    update('loggedin', true)
  end,
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
  PLAYER_TARGET_CHANGED = function()
    update('targetname', UnitName('target'))
  end,
  QUEST_COMPLETE = function()
    print('[quest] (' .. GetQuestID() .. ') ' .. GetTitleText() .. '\n' .. GetRewardText())
    print(('[quest] money:%d xp:%d'):format(GetRewardMoney(), GetRewardXP()))
    for i = 1, GetNumQuestRewards() do
      local name, _, num = GetQuestItemInfo('reward', i)
      print(('[quest][reward][%d] %s (%d)'):format(i, name, num))
    end
    for i = 1, GetNumQuestChoices() do
      local name, _, num = GetQuestItemInfo('choice', i)
      print(('[quest][choice][%d] %s (%d)'):format(i, name, num))
    end
    GetQuestReward(0)
  end,
  QUEST_DETAIL = function()
    assert(not state.quest)
    state.quest = true
    print('[quest] (' .. GetQuestID() .. ') ' .. GetTitleText() .. '\n' .. GetQuestText())
    print('[quest][objective] ' .. GetObjectiveText())
    AcceptQuest()
  end,
  QUEST_FINISHED = function()
    -- Cannot assert since it can fire multiple times.
    if state.quest then
      state.quest = false
      print('[quest] finished')
    end
  end,
  QUEST_PROGRESS = function()
    print('[quest] (' .. GetQuestID() .. ') ' .. GetTitleText() .. '\n' .. GetProgressText())
    CompleteQuest()
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
  UNIT_TARGET = function(unit)
    -- Eventually we'll do something interesting with this.
    -- For now it's redundant with PLAYER_TARGET_CHANGED.
    if unit ~= 'player' then
      print('unsupported UNIT_TARGET with ' .. unit)
    end
  end,
  UPDATE_ALL_UI_WIDGETS = nop,
  UPDATE_BINDINGS = function()
    if state.loggedin then
      print('[error] unexpected UPDATE_BINDINGS')
    end
  end,
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
    update('durability', ('%d/%d (%d%%)'):format(c, m, m == 0 and 0 or c / m * 100))
  end,
  UPDATE_MOUSEOVER_UNIT = function()
    local m = UnitGUID('mouseover')
    state.mouseoverunit = (state.mouseoverunit ~= m) and m or nil
  end,
  UPDATE_SHAPESHIFT_FORM = function()
    -- We'll probably want to resurrect this at some point, but for now it's just noise.
  end,
  UPDATE_WEB_TICKET = nop,
  VARIABLES_LOADED = function()
    local cvars = {
      nameplateShowAll = 0,
      nameplateShowEnemies = 0,
      nameplateShowEnemyMinions = 0,
      nameplateShowEnemyMinus = 0,
      nameplateShowFriends = 0,
      nameplateShowFriendlyMinions = 0,
    }
    for k, v in pairs(cvars) do
      SetCVar(k, tostring(v))
    end
  end,
  ZONE_CHANGED = function()
    update('subzone', GetSubZoneText())
  end,
  ZONE_CHANGED_INDOORS = function()
    update('subzone', GetSubZoneText())
  end,
  ZONE_CHANGED_NEW_AREA = function()
    update('zone', GetZoneText())
    update('subzone', GetSubZoneText())
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

seterrorhandler(function(s)
  print('lua error: ' .. s)
end)

local lsmt = {
  __index = function(_, k)
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
  elseif cmd == 'noquit' then
    CancelLogout()
    DoEmote('stand')
  elseif cmd == 'reload' then
    ReloadUI()
  elseif cmd:sub(1, 6) == 'train ' then
    BuyTrainerService(tonumber(cmd:sub(7)))
  elseif cmd == 'close' then
    if state.merching then
      CloseMerchant()
      assert(not state.merching)
    elseif state.training then
      CloseTrainer()
      assert(not state.training)
    elseif state.gossiping then
      C_GossipInfo.CloseGossip()
      assert(not state.gossiping)
    else
      print('[error] nothing to close')
    end
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

local secureButton = CreateFrame('Button', 'GroundUpSecureButton', nil, 'SecureActionButtonTemplate')
secureButton:SetAttribute('type-quit', 'macro')
secureButton:SetAttribute('macrotext-quit', '/quit')
secureButton:SetAttribute('type-logout', 'macro')
secureButton:SetAttribute('macrotext-logout', '/logout')
secureButton:HookScript('OnClick', function(_, b)
  if b == 'focus' then
    e:SetFocus()
  end
end)

-- This is necessary to get C_Macro.SetMacroExecuteLineCallback called.
-- Otherwise, macro execution is completely disabled.
EventRegistry.frameEventFrame:RegisterEvent('PLAYER_ENTERING_WORLD')
EventRegistry.frameEventFrame:HookScript('OnEvent', function()
  EventRegistry.frameEventFrame:UnregisterAllEvents()
end)
