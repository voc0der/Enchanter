local function assert_equal(actual, expected, message)
    if actual ~= expected then
        error((message or "assert_equal failed") .. string.format(" (expected=%s, actual=%s)", tostring(expected), tostring(actual)))
    end
end

local function assert_true(value, message)
    if not value then
        error(message or "assert_true failed")
    end
end

local function assert_nil(value, message)
    if value ~= nil then
        error((message or "assert_nil failed") .. string.format(" (actual=%s)", tostring(value)))
    end
end

local function assert_not_nil(value, message)
    if value == nil then
        error(message or "assert_not_nil failed")
    end
end

local function escape_lua_pattern(value)
    return (tostring(value):gsub("([%(%)%.%%%+%-%*%?%[%]%^%$])", "%%%1"))
end

local function copy_table(value)
    if type(value) ~= "table" then
        return value
    end

    local out = {}
    for key, nested in pairs(value) do
        out[key] = copy_table(nested)
    end
    return out
end

local function split_csv(value, separator)
    local out = {}
    if not value or value == "" then
        return out
    end

    separator = separator or ","
    local pattern = string.format("([^%s]+)", separator)
    for token in string.gmatch(value, pattern) do
        out[#out + 1] = token
    end
    return out
end

local function load_chunk(path, ...)
    local chunk = assert(loadfile(path))
    return chunk(...)
end

local original_math_random = math.random
local original_math_randomseed = math.randomseed
local original_global_random = _G.random
local original_global_randomseed = _G.randomseed
local original_os_date = os.date

local function setup_env(opts)
    opts = opts or {}

    local function normalize_item_id(item_reference)
        local item_id

        if type(item_reference) == "number" then
            item_id = math.floor(tonumber(item_reference) or 0)
            return item_id > 0 and item_id or nil
        end

        if type(item_reference) ~= "string" then
            return nil
        end

        item_id = tonumber(item_reference:match("item:(%d+)"))
        if item_id and item_id > 0 then
            return math.floor(item_id)
        end

        return nil
    end

    local state = {
        auctionator_calls = {},
        bag_pickups = {},
        bag_use_calls = {},
        bags = copy_table(opts.bags or {}),
        invites = {},
        item_cache = {},
        inbox = copy_table(opts.inbox or {}),
        prints = {},
        played_sounds = {},
        played_sound_calls = {},
        secure_hooks = {},
        send_mail_attachments = copy_table(opts.send_mail_attachments or {}),
        send_mail_tab = tonumber(opts.send_mail_tab) or 1,
        emotes = {},
        requested_item_data = {},
        crafts = copy_table(opts.crafts or {}),
        craft_available_only = opts.craft_available_only and true or false,
        craft_filter = tonumber(opts.craft_filter) or 0,
        craft_slots = copy_table(opts.craft_slots or {}),
        do_craft_calls = {},
        do_trade_skill_calls = {},
        events = {},
        event_handlers = {},
        slash = nil,
        timer_delays = {},
        timer_callbacks = {},
        trade_skills = copy_table(opts.trade_skills or {}),
        trade_target_items = copy_table(opts.trade_target_items or {}),
        trade_player_items = copy_table(opts.trade_player_items or {}),
        trade_target_money = tonumber(opts.trade_target_money) or 0,
        whispers = {},
        frames = {},
        current_time = tonumber(opts.current_time) or 0,
        current_spell_name = opts.current_spell_name,
        current_mouseover_name = opts.current_mouseover_name or nil,
        current_npc_name = opts.current_npc_name or nil,
        current_party_members = copy_table(opts.current_party_members or {}),
        current_raid_members = copy_table(opts.current_raid_members or {}),
        current_target_name = opts.current_target_name or nil,
        player_afk = opts.player_afk and true or false,
        player_name = opts.player_name or "Enchanter-Test",
        player_realm = opts.player_realm or "TestRealm",
        previous_target_name = opts.previous_target_name or nil,
        raid_targets = copy_table(opts.raid_targets or {}),
        selected_craft = tonumber(opts.selected_craft) or nil,
        set_raid_target_calls = {},
        selected_trade_skill = nil,
        trade_skill_frame_selection = nil,
        trade_skill_available_only = opts.trade_skill_available_only and true or false,
        trade_skill_subclass_filter = tonumber(opts.trade_skill_subclass_filter) or 0,
        trade_skill_invslot_filter = tonumber(opts.trade_skill_invslot_filter) or 0,
        trade_skill_search_text = opts.trade_skill_search_text,
        trade_skill_item_level_min = tonumber(opts.trade_skill_item_level_min) or 0,
        trade_skill_item_level_max = tonumber(opts.trade_skill_item_level_max) or 0,
    }

    for key, item in pairs(copy_table(opts.item_cache or {})) do
        local item_id = normalize_item_id(key) or normalize_item_id(item and item.link) or tonumber(item and item.item_id)
        if item_id and item_id > 0 then
            state.item_cache[item_id] = item
            if state.item_cache[item_id].cached == nil then
                state.item_cache[item_id].cached = true
            end
        end
    end

    local function set_shown_methods(frame, shown)
        frame.shown = shown and true or false

        function frame:IsShown()
            return self.shown and true or false
        end

        function frame:SetShown(value)
            self.shown = value and true or false
        end

        function frame:Show()
            self.shown = true
        end

        function frame:Hide()
            self.shown = false
        end

        return frame
    end

    local function new_font_string()
        local font_string = {
            shown = true,
        }

        function font_string:SetPoint(...)
            self.points = self.points or {}
            self.points[#self.points + 1] = { ... }
            if not self.point then
                self.point = self.points[1]
            end
        end
        function font_string:ClearAllPoints()
            self.point = nil
            self.points = nil
        end
        function font_string:SetText(text) self.text = text end
        function font_string:GetText() return self.text end
        function font_string:SetTextColor(...) self.text_color = { ... } end
        function font_string:SetJustifyH(value) self.justify_h = value end
        function font_string:SetJustifyV(value) self.justify_v = value end
        function font_string:Show() self.shown = true end
        function font_string:Hide() self.shown = false end
        if not opts.omit_fontstring_setshown then
            function font_string:SetShown(value) self.shown = value and true or false end
        end

        return font_string
    end

    local function new_texture()
        local texture = {
            shown = true,
        }

        function texture:SetAllPoints() end
        function texture:SetPoint(...) self.point = { ... } end
        function texture:SetSize(width, height)
            self.width = width
            self.height = height
        end
        function texture:SetTexture(value) self.texture = value end
        function texture:SetAtlas(value) self.atlas = value end
        function texture:SetColorTexture(...) self.color = { ... } end
        function texture:SetVertexColor(...) self.vertex_color = { ... } end
        function texture:Show() self.shown = true end
        function texture:Hide() self.shown = false end

        return texture
    end

    local function new_frame(frame_type, name, parent, template)
        local frame = {
            frame_type = frame_type,
            name = name,
            parent = parent,
            template = template,
            shown = true,
            width = 0,
            height = 0,
            scripts = {},
            frame_level = parent and parent.frame_level and (parent.frame_level + 1) or 1,
        }

        local function run_size_changed()
            if frame.scripts["OnSizeChanged"] then
                frame.scripts["OnSizeChanged"](frame, frame.width, frame.height)
            end
        end

        function frame:SetSize(width, height)
            self.width = width
            self.height = height
            run_size_changed()
        end
        function frame:SetWidth(width)
            self.width = width
            run_size_changed()
        end
        function frame:SetHeight(height)
            self.height = height
            run_size_changed()
        end
        function frame:GetWidth() return self.width or 0 end
        function frame:GetHeight() return self.height or 0 end
        function frame:GetName() return self.name end
        function frame:SetPoint(...)
            self.points = self.points or {}
            self.points[#self.points + 1] = { ... }
            if not self.point then
                self.point = self.points[1]
            end
        end
        function frame:GetPoint()
            if self.point then
                return table.unpack(self.point)
            end
            return "CENTER", _G.UIParent, "CENTER", 0, 0
        end
        function frame:ClearAllPoints()
            self.point = nil
            self.points = nil
        end
        function frame:SetMovable(value) self.movable = value end
        function frame:SetResizable(value) self.resizable = value end
        function frame:SetResizeBounds(min_width, min_height, max_width, max_height)
            self.resize_bounds = { min_width, min_height, max_width, max_height }
        end
        function frame:SetMinResize(min_width, min_height)
            self.min_resize = { min_width, min_height }
        end
        function frame:SetMaxResize(max_width, max_height)
            self.max_resize = { max_width, max_height }
        end
        function frame:SetClampedToScreen(value) self.clamped = value end
        function frame:EnableMouse(value) self.mouse_enabled = value end
        function frame:RegisterForDrag(...) self.drag_buttons = { ... } end
        function frame:SetFrameStrata(value) self.frame_strata = value end
        function frame:SetFrameLevel(value) self.frame_level = value end
        function frame:GetFrameLevel() return self.frame_level or 1 end
        function frame:SetToplevel(value) self.toplevel = value end
        function frame:SetBackdrop(value) self.backdrop = value end
        function frame:SetBackdropColor(...) self.backdrop_color = { ... } end
        function frame:SetBackdropBorderColor(...) self.backdrop_border_color = { ... } end
        function frame:SetScript(script_name, fn) self.scripts[script_name] = fn end
        function frame:CreateFontString() return new_font_string() end
        function frame:CreateTexture() return new_texture() end
        function frame:SetScrollChild(child) self.scroll_child = child end
        function frame:SetVerticalScroll(value) self.vertical_scroll = value end
        function frame:GetVerticalScroll() return self.vertical_scroll or 0 end
        function frame:SetText(text) self.text = text end
        function frame:GetText() return self.text end
        function frame:SetNormalTexture(value) self.normal_texture = value end
        function frame:GetNormalTexture() return self.normal_texture end
        function frame:SetHighlightTexture(value) self.highlight_texture = value end
        function frame:GetHighlightTexture() return self.highlight_texture end
        function frame:SetPushedTexture(value) self.pushed_texture = value end
        function frame:GetPushedTexture() return self.pushed_texture end
        function frame:SetAutoFocus(value) self.auto_focus = value and true or false end
        function frame:SetNumeric(value) self.numeric = value and true or false end
        function frame:SetMaxLetters(value) self.max_letters = value end
        if not opts.omit_text_insets then
            function frame:SetTextInsets(...) self.text_insets = { ... } end
        end
        function frame:ClearFocus() self.cleared_focus = true end
        function frame:HighlightText(...) self.highlight = { ... } end
        function frame:GetNumber() return tonumber(self.text) or 0 end
        function frame:SetChecked(value) self.checked = value and true or false end
        function frame:GetChecked() return self.checked end
        function frame:Enable() self.enabled = true end
        function frame:Disable() self.enabled = false end
        function frame:IsEnabled() return self.enabled ~= false end
        function frame:Show() self.shown = true end
        function frame:Hide() self.shown = false end
        function frame:IsShown() return self.shown end
        function frame:SetShown(value) self.shown = value and true or false end
        function frame:SetParent(parent_frame) self.parent = parent_frame end
        function frame:StartMoving() self.started_moving = true end
        function frame:StartSizing(point) self.started_sizing = point end
        function frame:StopMovingOrSizing() self.stopped_moving = true end
        function frame:RegisterForClicks(...) self.clicks = { ... } end
        function frame:RegisterEvent(event) self.registered_events = self.registered_events or {}; self.registered_events[event] = true end
        function frame:UnregisterEvent(event) if self.registered_events then self.registered_events[event] = nil end end

        state.frames[#state.frames + 1] = frame
        if name then
            _G[name] = frame
        end
        return frame
    end

    _G.Enchanter_Addon = nil
    _G.EnchanterDB = copy_table(opts.db or {})
    _G.EnchanterDBChar = copy_table(opts.char_db or {})
    math.random = original_math_random
    math.randomseed = original_math_randomseed
    if opts.omit_math_random then
        math.random = nil
    end
    if opts.omit_math_randomseed then
        math.randomseed = nil
    end
    _G.random = original_global_random
    _G.randomseed = original_global_randomseed
    if opts.omit_global_random then
        _G.random = nil
    elseif opts.global_random ~= nil then
        _G.random = opts.global_random
    end
    if opts.omit_global_randomseed then
        _G.randomseed = nil
    elseif opts.global_randomseed ~= nil then
        _G.randomseed = opts.global_randomseed
    end
    _G.C_AddOns = nil
    _G.C_PartyInfo = nil
    _G.C_Timer = {
        After = function(delay, callback)
            state.timer_delays[#state.timer_delays + 1] = delay
            state.timer_callbacks[#state.timer_callbacks + 1] = callback
            if not opts.defer_timers then
                callback()
            end
        end,
    }
    _G.GetAddOnMetadata = function(_, field)
        if field == "Title" then
            return "Enchanter"
        end
        if field == "Version" then
            return "test"
        end
        if field == "Author" then
            return "Test Author"
        end
        return ""
    end
    _G.GetTime = function()
        return state.current_time or 0
    end
    _G.InviteUnit = function(name)
        state.invites[#state.invites + 1] = name
    end
    _G.SendChatMessage = function(message, chat_type, _, target)
        state.whispers[#state.whispers + 1] = {
            message = message,
            chat_type = chat_type,
            target = target,
        }
    end
    _G.DoEmote = function(token, target)
        state.emotes[#state.emotes + 1] = {
            token = token,
            target = target,
        }
        return false
    end
    _G.SOUNDKIT = {
        IG_MAINMENU_OPTION_CHECKBOX_ON = 856,
        U_CHAT_SCROLL_BUTTON = 1115,
        IG_CHARACTER_INFO_OPEN = 839,
        AUCTION_WINDOW_OPEN = 5274,
        READY_CHECK = 8960,
        PVP_ENTER_QUEUE = 8458,
        RAID_WARNING = 8959,
        LFG_ROLE_CHECK = 17317,
    }
    _G.ERR_TRADE_COMPLETE = "Trade complete."
    _G.ERR_ALREADY_IN_GROUP_S = "%s is already in a group."
    _G.ERR_DECLINE_GROUP_S = "%s declines your group invitation."
    _G.PlaySound = function(sound_kit, channel)
        if opts.play_sound_errors_on_channel and channel ~= nil then
            error("channel playback unsupported")
        end
        state.played_sounds[#state.played_sounds + 1] = sound_kit
        state.played_sound_calls[#state.played_sound_calls + 1] = {
            sound_kit = sound_kit,
            channel = channel,
        }
        if opts.play_sound_returns_false then
            return false
        end
        return true
    end
    _G.CastSpellByName = function(name)
        state.last_cast = name
    end
    _G.CraftFrame = set_shown_methods({
        selectedCraft = state.selected_craft,
    }, opts.craft_frame_shown)
    _G.CraftFrameAvailableFilterCheckButton = {
        checked = state.craft_available_only and true or false,
    }
    function _G.CraftFrameAvailableFilterCheckButton:GetChecked()
        return self.checked and true or false
    end
    function _G.CraftFrameAvailableFilterCheckButton:SetChecked(value)
        self.checked = value and true or false
    end
    local function get_visible_crafts()
        local visible = {}

        for _, craft in ipairs(state.crafts) do
            local craftType = craft.craft_type or craft.skill_type or "optimal"
            local filterIndex = tonumber(craft.filter_index) or 0
            local numAvailable = math.max(0, math.floor(tonumber(craft.num_available) or 0))
            local matchesFilter = state.craft_filter == 0 or filterIndex == state.craft_filter or craftType == "header"
            local matchesAvailable = not state.craft_available_only or craftType == "header" or numAvailable > 0

            if matchesFilter and matchesAvailable then
                visible[#visible + 1] = craft
            end
        end

        return visible
    end
    _G.GetCraftSlots = function()
        return table.unpack(state.craft_slots or {})
    end
    _G.GetCraftFilter = function(index)
        return (tonumber(index) or 0) == state.craft_filter
    end
    _G.SetCraftFilter = function(index)
        index = math.floor(tonumber(index) or 0)
        if index < 0 or index > #(state.craft_slots or {}) then
            error("SetCraftFilter(index) index out of range")
        end
        state.craft_filter = index
        if index == 0 and opts.craft_slots_after_clear_filter ~= nil then
            state.craft_slots = copy_table(opts.craft_slots_after_clear_filter)
        end
    end
    _G.CraftOnlyShowMakeable = function(value)
        state.craft_available_only = value and true or false
        _G.CraftFrameAvailableFilterCheckButton.checked = state.craft_available_only
    end
    _G.GetNumCrafts = function()
        return #get_visible_crafts()
    end
    _G.GetCraftInfo = function(index)
        local craft = get_visible_crafts()[index]
        if not craft then
            return nil
        end
        return craft.name, craft.sub_spell_name, craft.craft_type or craft.skill_type or "optimal", craft.num_available or 0, craft.is_expanded, craft.training_point_cost or 0, craft.required_level or 0
    end
    _G.GetCraftRecipeLink = function(index)
        local craft = get_visible_crafts()[index]
        return craft and craft.link or nil
    end
    _G.GetCraftDisplaySkillLine = function()
        return opts.craft_skill_line_name or "Enchanting", 375, 375
    end
    _G.SelectCraft = function(index)
        state.selected_craft = index
        _G.CraftFrame.selectedCraft = index
    end
    _G.CraftFrame_SetSelection = function(index)
        state.craft_frame_selection = index
        state.selected_craft = index
        _G.CraftFrame.selectedCraft = index
    end
    _G.GetCraftSelectionIndex = function()
        return tonumber(state.selected_craft) or 0
    end
    _G.DoCraft = function(index)
        state.do_craft_calls[#state.do_craft_calls + 1] = {
            index = index,
            selected = state.selected_craft,
        }
        state.last_do_craft = {
            index = index,
        }
    end
    _G.GetCraftNumReagents = function(index)
        local craft = get_visible_crafts()[index]
        if not craft or not craft.reagents then
            return 0
        end
        if opts.require_craft_selection_for_reagents and state.selected_craft ~= index then
            return 0
        end
        return #craft.reagents
    end
    _G.GetCraftReagentInfo = function(index, reagent_index)
        local craft = get_visible_crafts()[index]
        if not craft or not craft.reagents then
            return nil
        end
        if opts.require_craft_selection_for_reagents and state.selected_craft ~= index then
            return nil
        end
        local reagent = craft.reagents[reagent_index]
        if not reagent then
            return nil
        end
        return reagent.name, reagent.texture, reagent.count
    end
    _G.GetCraftReagentItemLink = function(index, reagent_index)
        local craft = get_visible_crafts()[index]
        if not craft or not craft.reagents then
            return nil
        end
        if opts.require_craft_selection_for_reagents and state.selected_craft ~= index then
            return nil
        end
        local reagent = craft.reagents[reagent_index]
        return reagent and reagent.link or nil
    end
    _G.TradeSkillFrame = set_shown_methods({
        selectedSkill = nil,
    }, opts.trade_skill_frame_shown)
    _G.TradeSearchInputBox = {
        text = opts.trade_skill_search_text or "",
    }
    function _G.TradeSearchInputBox:SetText(value)
        self.text = value or ""
    end
    function _G.TradeSearchInputBox:GetText()
        return self.text or ""
    end
    _G.TradeSkillInputBox = {
        value = 1,
    }
    function _G.TradeSkillInputBox:SetNumber(value)
        self.value = tonumber(value) or 1
    end
    function _G.TradeSkillInputBox:GetNumber()
        return self.value or 1
    end
    function _G.TradeSkillInputBox:ClearFocus()
        self.cleared_focus = true
    end
    _G.TradeSkillFrameAvailableFilterCheckButton = {
        checked = state.trade_skill_available_only and true or false,
    }
    function _G.TradeSkillFrameAvailableFilterCheckButton:GetChecked()
        return self.checked and true or false
    end
    function _G.TradeSkillFrameAvailableFilterCheckButton:SetChecked(value)
        self.checked = value and true or false
    end
    local function get_visible_trade_skills()
        local visible = {}

        for _, skill in ipairs(state.trade_skills) do
            local skillType = skill.skill_type or "optimal"
            local subClassIndex = tonumber(skill.sub_class_index) or 0
            local invSlotIndex = tonumber(skill.inv_slot_index) or 0
            local numAvailable = math.max(0, math.floor(tonumber(skill.num_available) or 0))
            local itemLevel = math.max(0, math.floor(tonumber(skill.item_level) or 0))
            local searchText = state.trade_skill_search_text
            local matchesSubClass = state.trade_skill_subclass_filter == 0 or subClassIndex == state.trade_skill_subclass_filter or skillType == "header"
            local matchesInvSlot = state.trade_skill_invslot_filter == 0 or invSlotIndex == state.trade_skill_invslot_filter or skillType == "header"
            local matchesAvailable = not state.trade_skill_available_only or skillType == "header" or numAvailable > 0
            local matchesLevel = (state.trade_skill_item_level_min <= 0 and state.trade_skill_item_level_max <= 0) or skillType == "header" or (itemLevel >= state.trade_skill_item_level_min and itemLevel <= state.trade_skill_item_level_max)
            local matchesSearch = searchText == nil or searchText == "" or skillType == "header" or string.find(string.lower(skill.name or ""), string.lower(searchText), 1, true) ~= nil

            if matchesSubClass and matchesInvSlot and matchesAvailable and matchesLevel and matchesSearch then
                visible[#visible + 1] = skill
            end
        end

        return visible
    end
    _G.GetTradeSkillSubClasses = function()
        return table.unpack(opts.trade_skill_subclasses or {})
    end
    _G.GetTradeSkillInvSlots = function()
        return table.unpack(opts.trade_skill_invslots or {})
    end
    _G.GetTradeSkillSubClassFilter = function(index)
        index = tonumber(index) or 0
        if state.trade_skill_subclass_filter == 0 then
            return index == 0 and 1 or 0
        end
        return index == state.trade_skill_subclass_filter and 1 or 0
    end
    _G.GetTradeSkillInvSlotFilter = function(index)
        index = tonumber(index) or 0
        if state.trade_skill_invslot_filter == 0 then
            return index == 0 and 1 or 0
        end
        return index == state.trade_skill_invslot_filter and 1 or 0
    end
    _G.SetTradeSkillSubClassFilter = function(index, on, exclusive)
        index = tonumber(index) or 0
        if exclusive == 1 or exclusive == true then
            state.trade_skill_subclass_filter = (on == 1 or on == true) and index or 0
        elseif on == 1 or on == true then
            state.trade_skill_subclass_filter = index
        elseif state.trade_skill_subclass_filter == index then
            state.trade_skill_subclass_filter = 0
        end
    end
    _G.SetTradeSkillInvSlotFilter = function(index, on, exclusive)
        index = tonumber(index) or 0
        if exclusive == 1 or exclusive == true then
            state.trade_skill_invslot_filter = (on == 1 or on == true) and index or 0
        elseif on == 1 or on == true then
            state.trade_skill_invslot_filter = index
        elseif state.trade_skill_invslot_filter == index then
            state.trade_skill_invslot_filter = 0
        end
    end
    _G.ExpandTradeSkillSubClass = function(index)
        state.expanded_trade_skill_subclass = index
    end
    _G.TradeSkillOnlyShowMakeable = function(value)
        state.trade_skill_available_only = value and true or false
        _G.TradeSkillFrameAvailableFilterCheckButton.checked = state.trade_skill_available_only
    end
    _G.SetTradeSkillItemNameFilter = function(value)
        state.trade_skill_search_text = value
    end
    _G.SetTradeSkillItemLevelFilter = function(min_level, max_level)
        state.trade_skill_item_level_min = tonumber(min_level) or 0
        state.trade_skill_item_level_max = tonumber(max_level) or 0
    end
    _G.TradeSkillFilter_OnTextChanged = function(self)
        local text = self and self.GetText and self:GetText() or ""
        state.trade_skill_search_text = text ~= "" and text or ""
        state.trade_skill_item_level_min = 0
        state.trade_skill_item_level_max = 0
    end
    _G.GetNumTradeSkills = function()
        return #get_visible_trade_skills()
    end
    _G.GetTradeSkillInfo = function(index)
        local skill = get_visible_trade_skills()[index]
        if not skill then
            return nil
        end
        return skill.name, skill.skill_type
    end
    _G.GetTradeSkillLine = function()
        return opts.trade_skill_line_name or "Enchanting", 375, 375
    end
    _G.GetTradeSkillRecipeLink = function(index)
        local skill = get_visible_trade_skills()[index]
        return skill and skill.link or nil
    end
    _G.SelectTradeSkill = function(index)
        state.selected_trade_skill = index
        _G.TradeSkillFrame.selectedSkill = index
    end
    _G.TradeSkillFrame_SetSelection = function(index)
        state.trade_skill_frame_selection = index
        state.selected_trade_skill = index
        _G.TradeSkillFrame.selectedSkill = index
    end
    _G.DoTradeSkill = function(index, count)
        state.do_trade_skill_calls[#state.do_trade_skill_calls + 1] = {
            index = index,
            count = count,
            selected = state.selected_trade_skill,
        }
        state.last_do_trade_skill = {
            index = index,
            count = count,
        }
    end
    local function trade_skill_reagents_are_available(index)
        if opts.require_trade_frame_selection_for_reagents then
            return state.trade_skill_frame_selection == index
        end
        if opts.require_trade_selection_for_reagents then
            return state.selected_trade_skill == index
        end
        return true
    end
    _G.GetTradeSkillNumReagents = function(index)
        local skill = get_visible_trade_skills()[index]
        if not skill or not skill.reagents then
            return 0
        end
        if not trade_skill_reagents_are_available(index) then
            return 0
        end
        return #skill.reagents
    end
    _G.GetTradeSkillReagentInfo = function(index, reagent_index)
        local skill = get_visible_trade_skills()[index]
        if not skill or not skill.reagents then
            return nil
        end
        if not trade_skill_reagents_are_available(index) then
            return nil
        end
        local reagent = skill.reagents[reagent_index]
        if not reagent then
            return nil
        end
        if opts.trade_reagent_info_includes_item_id then
            local itemId = tonumber(reagent.item_id) or tonumber((reagent.link or ""):match("item:(%d+)")) or 0
            return reagent.name, reagent.texture, itemId, reagent.count, reagent.player_count or 0
        end
        return reagent.name, reagent.texture, reagent.count
    end
    _G.GetTradeSkillReagentItemLink = function(index, reagent_index)
        local skill = get_visible_trade_skills()[index]
        if not skill or not skill.reagents then
            return nil
        end
        if not trade_skill_reagents_are_available(index) then
            return nil
        end
        local reagent = skill.reagents[reagent_index]
        return reagent and reagent.link or nil
    end
    _G.MAX_TRADE_ITEMS = 7
    _G.MAX_TRADABLE_ITEMS = 6
    _G.TRADE_ENCHANT_SLOT = 7
    _G.GetTradeTargetItemInfo = function(index)
        local item = state.trade_target_items[index]
        if not item then
            return nil
        end
        return item.name, item.texture, item.count, item.quality, item.is_usable, item.enchantment, item.item_id
    end
    _G.GetTradeTargetItemLink = function(index)
        local item = state.trade_target_items[index]
        return item and item.link or nil
    end
    _G.GetTradePlayerItemInfo = function(index)
        local item = state.trade_player_items[index]
        if not item then
            return nil
        end
        return item.name, item.texture, item.count, item.quality, item.enchantment, item.can_lose_transmog, item.is_bound, item.item_id
    end
    _G.GetTargetTradeMoney = function()
        return state.trade_target_money or 0
    end
    _G.GetPlayerTradeMoney = function()
        return state.trade_player_money or 0
    end
    _G.GetGameTime = function()
        if opts.game_time then
            return opts.game_time.hour, opts.game_time.min
        end
        return 13, 11
    end
    local function unit_name_from_token(unit)
        if unit == "player" then
            return state.player_name
        end
        if unit == "target" then
            return state.current_target_name
        end
        if unit == "mouseover" then
            return state.current_mouseover_name
        end
        if unit == "NPC" or unit == "npc" then
            return state.current_npc_name
        end

        local party_index = tonumber(tostring(unit or ""):match("^party(%d+)$") or "")
        if party_index then
            return state.current_party_members[party_index]
        end

        local raid_index = tonumber(tostring(unit or ""):match("^raid(%d+)$") or "")
        if raid_index then
            return state.current_raid_members[raid_index]
        end

        return nil
    end
    local function names_match(left, right)
        left = tostring(left or ""):lower()
        right = tostring(right or ""):lower()
        if left == "" or right == "" then
            return false
        end

        local left_short = left:match("^([^%-]+)") or left
        local right_short = right:match("^([^%-]+)") or right
        return left == right
            or left == right_short
            or left_short == right
            or left_short == right_short
    end
    _G.UnitName = function(unit)
        return unit_name_from_token(unit)
    end
    _G.GetUnitName = function(unit, show_server_name)
        local name = unit_name_from_token(unit)
        if not name then
            return nil
        end
        if show_server_name and string.find(name, "-", 1, true) == nil and state.player_realm ~= "" then
            return name .. "-" .. state.player_realm
        end
        return name
    end
    _G.TargetUnit = function(name, exact_match)
        local target_name = unit_name_from_token(name) or (type(name) == "string" and name or nil)
        state.last_target_unit_call = {
            name = name,
            exact_match = exact_match and true or false,
        }
        if not target_name or target_name == "" then
            return false
        end
        state.previous_target_name = state.current_target_name
        state.current_target_name = target_name
        return true
    end
    _G.ClearTarget = function()
        local had_target = state.current_target_name ~= nil and state.current_target_name ~= ""
        state.previous_target_name = state.current_target_name
        state.current_target_name = nil
        return had_target
    end
    _G.TargetLastTarget = function()
        local current = state.current_target_name
        state.current_target_name = state.previous_target_name
        state.previous_target_name = current
        return state.current_target_name ~= nil and state.current_target_name ~= ""
    end
    _G.UnitInParty = function(name)
        for _, member_name in ipairs(state.current_party_members or {}) do
            if names_match(member_name, name) then
                return true
            end
        end
        return nil
    end
    _G.UnitInRaid = function(name)
        for _, member_name in ipairs(state.current_raid_members or {}) do
            if names_match(member_name, name) then
                return true
            end
        end
        return nil
    end
    _G.UnitIsAFK = function(unit)
        if unit == "player" then
            return state.player_afk and true or false
        end
        return false
    end
    _G.SetRaidTarget = function(unit, index)
        local unit_name = unit_name_from_token(unit)
        local key = unit_name or tostring(unit or "")
        state.set_raid_target_calls[#state.set_raid_target_calls + 1] = {
            unit = unit,
            index = index,
        }
        if key ~= "" then
            state.raid_targets[key] = tonumber(index) or 0
        end
    end
    _G.GetCVarBool = function(name)
        if name == "timeMgrUseMilitaryTime" then
            return opts.use_military_time and true or false
        end
        if name == "timeMgrUseLocalTime" then
            return opts.use_local_time and true or false
        end
        return false
    end
    _G.GetSpellInfo = function(spell)
        if type(opts.spell_info_map) == "table" and opts.spell_info_map[spell] ~= nil then
            return opts.spell_info_map[spell]
        end
        if spell == 7411 then
            return opts.enchanting_spell_name or "Enchanting"
        end
        if spell == 13262 then
            return opts.disenchant_spell_name or "Disenchant"
        end
        if type(spell) == "string" then
            return spell
        end
        return nil
    end
    _G.GetItemInfo = function(item_reference)
        local item_id = normalize_item_id(item_reference)
        local item = item_id and state.item_cache[item_id] or nil
        local item_link

        if not item or item.cached == false then
            return nil
        end

        item_link = item.link
        if item_link == nil and item.name ~= nil then
            item_link = string.format("|cffffffff|Hitem:%d::::::::|h[%s]|h|r", item_id, item.name)
        end

        return item.name, item_link, item.quality, item.item_level or 0, item.min_level or 0, item.item_type, item.item_sub_type, item.stack_count or 1, item.equip_loc or "", item.texture, item.sell_price or 0, item.class_id, item.subclass_id, item.bind_type
    end
    _G.GetItemInfoInstant = function(item_reference)
        return normalize_item_id(item_reference)
    end
    if opts.omit_c_item then
        _G.C_Item = nil
    else
        _G.C_Item = {
            RequestLoadItemDataByID = function(item_reference)
                local item_id = normalize_item_id(item_reference)
                state.requested_item_data[#state.requested_item_data + 1] = item_id
            end,
            GetItemInfoInstant = function(item_reference)
                return normalize_item_id(item_reference)
            end,
        }
    end
    _G.IsCurrentSpell = function(spell)
        if type(opts.is_current_spell) == "function" then
            return opts.is_current_spell(spell)
        end
        if state.current_spell_name == nil then
            return false
        end
        return tostring(spell) == tostring(state.current_spell_name)
            or (tonumber(spell) == 13262 and state.current_spell_name == (opts.disenchant_spell_name or "Disenchant"))
    end
    _G.SpellIsTargeting = function()
        return (state.spell_is_targeting or opts.spell_is_targeting) and true or false
    end
    _G.SpellCanTargetItem = function()
        return (state.spell_can_target_item or opts.spell_can_target_item) and true or false
    end
    _G.NUM_BAG_SLOTS = tonumber(opts.num_bag_slots) or 4
    local function get_bag_slot(bag, slot)
        local bag_items = state.bags[tonumber(bag) or 0] or {}
        return bag_items[tonumber(slot) or 0]
    end
    local function ensure_send_mail_attachment_slot(index)
        state.send_mail_attachments[index] = state.send_mail_attachments[index] or nil
        return state.send_mail_attachments[index]
    end
    _G.C_Container = {
        GetContainerNumSlots = function(bag)
            local bag_items = state.bags[tonumber(bag) or 0] or {}
            local max_slot = 0
            for slot in pairs(bag_items) do
                if slot > max_slot then
                    max_slot = slot
                end
            end
            return max_slot
        end,
        GetContainerItemInfo = function(bag, slot)
            local item = get_bag_slot(bag, slot)
            if not item then
                return nil
            end
            return {
                stackCount = item.count or 1,
                itemID = item.item_id or normalize_item_id(item.link),
                quality = item.quality,
                hyperlink = item.link,
            }
        end,
        GetContainerItemLink = function(bag, slot)
            local item = get_bag_slot(bag, slot)
            return item and item.link or nil
        end,
        UseContainerItem = function(bag, slot)
            state.bag_use_calls[#state.bag_use_calls + 1] = {
                bag = bag,
                slot = slot,
            }
        end,
        PickupContainerItem = function(bag, slot)
            local item = get_bag_slot(bag, slot)
            state.bag_pickups[#state.bag_pickups + 1] = {
                bag = bag,
                slot = slot,
            }
            state.cursor_item = item and copy_table(item) or nil
        end,
    }
    _G.GetInboxHeaderInfo = function(index)
        local mail = state.inbox[tonumber(index) or 0]
        if not mail then
            return nil
        end
        local first_attachment = mail.attachments and mail.attachments[1] or nil
        return mail.package_icon, mail.stationery_icon, mail.sender, mail.subject, mail.money or 0, mail.cod or 0, mail.days_left or 0, #(mail.attachments or {}), mail.was_read, nil, nil, nil, mail.is_gm, first_attachment and first_attachment.count or nil, first_attachment and first_attachment.item_id or nil
    end
    _G.GetInboxItem = function(index, attachment_index)
        local mail = state.inbox[tonumber(index) or 0]
        local attachment = mail and mail.attachments and mail.attachments[tonumber(attachment_index) or 0] or nil
        if not attachment then
            return nil
        end
        return attachment.name, attachment.item_id, attachment.texture, attachment.count or 1, attachment.quality, attachment.can_use
    end
    _G.GetInboxItemLink = function(index, attachment_index)
        local mail = state.inbox[tonumber(index) or 0]
        local attachment = mail and mail.attachments and mail.attachments[tonumber(attachment_index) or 0] or nil
        return attachment and attachment.link or nil
    end
    _G.TakeInboxItem = function(index, attachment_index)
        state.last_take_inbox_item = {
            index = index,
            attachment_index = attachment_index,
        }
    end
    _G.HasSendMailItem = function(index)
        return ensure_send_mail_attachment_slot(index) ~= nil
    end
    _G.GetSendMailItem = function(index)
        local attachment = ensure_send_mail_attachment_slot(index)
        if not attachment then
            return nil
        end
        return attachment.name, attachment.item_id, attachment.texture, attachment.count or 1, attachment.quality
    end
    _G.ClickSendMailItemButton = function(index)
        local attachment_limit = tonumber(_G.ATTACHMENTS_MAX_SEND) or 12
        local target_index = tonumber(index)
        if state.cursor_item == nil then
            return
        end
        if target_index == nil or target_index <= 0 then
            for attachment_index = 1, attachment_limit do
                if state.send_mail_attachments[attachment_index] == nil then
                    target_index = attachment_index
                    break
                end
            end
        end
        if target_index and target_index > 0 and target_index <= attachment_limit then
            state.send_mail_attachments[target_index] = copy_table(state.cursor_item)
            state.cursor_item = nil
        end
    end
    _G.ATTACHMENTS_MAX_SEND = tonumber(opts.attachments_max_send) or 12
    _G.SendMailNameEditBox = new_frame("EditBox", "SendMailNameEditBox", nil, nil)
    _G.SendMailSubjectEditBox = new_frame("EditBox", "SendMailSubjectEditBox", nil, nil)
    _G.MailEditBox = new_frame("EditBox", "MailEditBox", nil, nil)
    function _G.MailEditBox:GetInputText()
        return self.text or ""
    end
    _G.SendMailFrame_Update = function()
        state.send_mail_frame_updated = true
    end
    _G.SendMailFrame_CanSend = function()
        state.send_mail_can_send_checked = true
    end
    _G.MailFrameTab_OnClick = function(_, tab_id)
        state.send_mail_tab = tonumber(tab_id) or state.send_mail_tab
    end
    _G.SendMail = function(recipient, subject, body)
        state.last_send_mail = {
            recipient = recipient,
            subject = subject,
            body = body,
            attachments = copy_table(state.send_mail_attachments),
        }
    end
    _G.hooksecurefunc = function(target, method, hook)
        if type(target) == "table" and type(method) == "string" and type(hook) == "function" then
            local original = target[method]
            state.secure_hooks[#state.secure_hooks + 1] = { target = target, method = method }
            target[method] = function(...)
                local results = { original(...) }
                hook(...)
                return table.unpack(results)
            end
            return
        end
        if type(target) == "string" and type(method) == "function" then
            local original = _G[target]
            state.secure_hooks[#state.secure_hooks + 1] = { target = target }
            _G[target] = function(...)
                local results = { original(...) }
                method(...)
                return table.unpack(results)
            end
        end
    end
    _G.TIME_TWENTYFOURHOURS = "%02d:%02d"
    _G.TIME_TWELVEHOURAM = "%d:%02d AM"
    _G.TIME_TWELVEHOURPM = "%d:%02d PM"
    _G.date = opts.date_impl
    if opts.disable_os_date then
        os.date = nil
    elseif opts.os_date_impl ~= nil then
        os.date = opts.os_date_impl
    else
        os.date = original_os_date
    end
    _G.CreateFrame = function(frame_type, name, parent, template)
        return new_frame(frame_type, name, parent, template)
    end
    _G.UIParent = new_frame("Frame", "UIParent", nil, nil)
    _G.AuctionFrame = set_shown_methods({}, opts.auction_frame_shown or opts.auction_house_open)
    _G.AuctionHouseFrame = set_shown_methods({}, opts.auction_house_frame_shown or opts.auction_house_open)
    if opts.with_auctionator then
        _G.Auctionator = {
            API = {
                v1 = {
                    MultiSearchExact = function(caller_id, search_terms)
                        state.auctionator_calls[#state.auctionator_calls + 1] = {
                            caller_id = caller_id,
                            search_terms = copy_table(search_terms),
                        }
                        if opts.auctionator_multi_search_error then
                            error(opts.auctionator_multi_search_error)
                        end
                    end,
                },
            },
        }
    else
        _G.Auctionator = nil
    end
    if opts.elvui then
        local skins = {}

        function skins:HandleFrame(frame)
            frame.elvui_frame_skinned = true
        end

        function skins:HandleButton(frame)
            frame.elvui_button_skinned = true
        end

        function skins:HandleCheckBox(frame)
            frame.elvui_checkbox_skinned = true
        end

        function skins:HandleScrollBar(frame)
            frame.elvui_scrollbar_skinned = true
        end

        _G.ElvUI = {
            {
                GetModule = function(_, module_name)
                    if module_name == "Skins" then
                        return skins
                    end
                    return nil
                end,
            },
        }
    else
        _G.ElvUI = nil
    end
    _G.print = function(...)
        local parts = {}
        for i = 1, select("#", ...) do
            parts[#parts + 1] = tostring(select(i, ...))
        end
        state.prints[#state.prints + 1] = table.concat(parts, " ")
    end

    local addon = {
        Tool = {},
    }

    function addon.Tool.Split(value, separator)
        return split_csv(value, separator)
    end

    function addon.Tool.Combine(values, separator)
        return table.concat(values, separator or ",")
    end

    function addon.Tool.SlashCommand(commands, entries)
        state.slash = {
            commands = copy_table(commands),
            entries = copy_table(entries),
        }
    end

    function addon.Tool.RegisterEvent(event, handler)
        state.events[#state.events + 1] = event
        state.event_handlers[event] = handler
    end

    load_chunk("Tags.lua", "Enchanter", addon)
    load_chunk("Options.lua", "Enchanter", addon)
    load_chunk("Workbench.lua", "Enchanter", addon)
    load_chunk("Enchanter.lua", "Enchanter", addon)

    addon.Init()

    return addon, state
end

local function run_timer(state, index)
    local callback = state.timer_callbacks[index]
    assert_not_nil(callback, "timer callback should exist")
    callback()
end

local function seed_scanned_recipes(addon, recipe_names)
    addon.DBChar.RecipeList = addon.DBChar.RecipeList or {}
    addon.DBChar.RecipeLinks = addon.DBChar.RecipeLinks or {}

    for _, recipe_name in ipairs(recipe_names or {}) do
        addon.DBChar.RecipeList[recipe_name] = copy_table(addon.DefaultRecipeTags.enGB[recipe_name] or {})
        addon.DBChar.RecipeLinks[recipe_name] = "[" .. recipe_name .. "] "
    end
end

local function assert_whisper_contains_recipe(message, recipe_name, context)
    assert_true(
        string.find(message, "%[" .. escape_lua_pattern(recipe_name) .. "%]") ~= nil,
        (context or "whisper") .. " should include " .. recipe_name
    )
end

local function sorted_recipe_names(recipe_names)
    local out = copy_table(recipe_names or {})
    table.sort(out)
    return out
end

local function list_contains(list, expected)
    for _, value in ipairs(list or {}) do
        if value == expected then
            return true
        end
    end
    return false
end

local function set_bag_item(state, bag, slot, item)
    state.bags[bag] = state.bags[bag] or {}
    if item == nil then
        state.bags[bag][slot] = nil
    else
        state.bags[bag][slot] = copy_table(item)
    end
end

local function assert_recipe_bucket_matches(order, expected_recipes, context)
    assert_not_nil(order, (context or "order") .. " should exist")

    local actual = sorted_recipe_names(order.Recipes or {})
    local expected = sorted_recipe_names(expected_recipes or {})

    assert_equal(#actual, #expected, (context or "order") .. " should have the expected recipe count")
    for index = 1, #expected do
        assert_equal(actual[index], expected[index], (context or "order") .. " should bucket the exact recipes")
    end
end

local function run_request_matching_case(case, index, invalid)
    local addon, state = setup_env({
        db = {
            InviteTimeDelay = 0,
            WhisperTimeDelay = 0,
            MsgPrefix = "I can do ",
            WarnIncompleteOrder = true,
        },
    })

    local customer_name = (invalid and "Buyer-Invalid-" or "Buyer-Valid-") .. tostring(index)
    seed_scanned_recipes(addon, case.scanned)
    addon.OptionsUpdate()
    addon.ParseMessage(case.message, customer_name)

    local order = addon.Workbench.GetOrderByCustomer(customer_name)

    if invalid then
        assert_equal(#state.whispers, 0, case.name .. " should not whisper for a blocked or invalid match")
        assert_equal(#state.invites, 0, case.name .. " should not invite for a blocked or invalid match")
        assert_nil(order, case.name .. " should not create a workbench order")
        assert_equal(#addon.Workbench.EnsureState().Orders, 0, case.name .. " should not queue any orders")
        return
    end

    assert_equal(#state.whispers, 1, case.name .. " should whisper exactly once")
    assert_equal(#state.invites, 1, case.name .. " should invite exactly once")
    assert_equal(#addon.Workbench.EnsureState().Orders, 1, case.name .. " should queue exactly one order")
    assert_recipe_bucket_matches(order, case.expected, case.name)

    local matched_count = #case.expected
    local requested_count = case.requested or matched_count
    assert_equal(order.RequestedRecipeCount, requested_count, case.name .. " should track the correct requested count")

    local whisper = state.whispers[1].message
    for _, recipe_name in ipairs(case.expected or {}) do
        assert_whisper_contains_recipe(whisper, recipe_name, case.name)
    end

    local warning_match = string.find(whisper, "%f[%d]%d+/%d+%f[%D]")
    if requested_count > matched_count then
        assert_true(
            string.find(whisper, tostring(matched_count) .. "/" .. tostring(requested_count), 1, true) ~= nil,
            case.name .. " should show the accurate incomplete warning"
        )
    else
        assert_true(warning_match == nil, case.name .. " should not show an incomplete warning")
    end
end

local function test_valid_request_matching_scenarios()
    local cases = {
        {
            name = "comma separated chest and weapon request",
            message = "lf enchanter 15 resil to chest, 81 heal wep",
            scanned = {
                "Enchant Chest - Major Resilience",
                "Enchant Weapon - Major Healing",
            },
            expected = {
                "Enchant Chest - Major Resilience",
                "Enchant Weapon - Major Healing",
            },
            requested = 2,
        },
        {
            name = "and separated multi list",
            message = "looking for mongoose and boar and dodge",
            scanned = {
                "Enchant Weapon - Mongoose",
                "Enchant Boots - Boar's Speed",
                "Enchant Cloak - Dodge",
            },
            expected = {
                "Enchant Weapon - Mongoose",
                "Enchant Boots - Boar's Speed",
                "Enchant Cloak - Dodge",
            },
            requested = 3,
        },
        {
            name = "slash separated chest and weapon request",
            message = "wtb enchant chest - restore mana prime / 81 heal wep",
            scanned = {
                "Enchant Chest - Restore Mana Prime",
                "Enchant Weapon - Major Healing",
            },
            expected = {
                "Enchant Chest - Restore Mana Prime",
                "Enchant Weapon - Major Healing",
            },
            requested = 2,
        },
        {
            name = "glove and weapon healing stay separate by segment",
            message = "lf 35 heal gloves, 81 heal wep",
            scanned = {
                "Enchant Gloves - Major Healing",
                "Enchant Weapon - Major Healing",
            },
            expected = {
                "Enchant Gloves - Major Healing",
                "Enchant Weapon - Major Healing",
            },
            requested = 2,
        },
        {
            name = "glove and weapon spellpower stay separate by segment",
            message = "lf 20sp to glove, 30 sp wep",
            scanned = {
                "Enchant Gloves - Major Spellpower",
                "Enchant Weapon - Spell Power",
            },
            expected = {
                "Enchant Gloves - Major Spellpower",
                "Enchant Weapon - Spell Power",
            },
            requested = 2,
        },
        {
            name = "cloak boots and weapon list buckets three distinct requests",
            message = "lf greater agility to cloak / boar / mongoose",
            scanned = {
                "Enchant Cloak - Greater Agility",
                "Enchant Boots - Boar's Speed",
                "Enchant Weapon - Mongoose",
            },
            expected = {
                "Enchant Cloak - Greater Agility",
                "Enchant Boots - Boar's Speed",
                "Enchant Weapon - Mongoose",
            },
            requested = 3,
        },
        {
            name = "assault split between bracer and gloves",
            message = "lf 24 ap bracer + 26 ap gloves",
            scanned = {
                "Enchant Bracer - Assault",
                "Enchant Gloves - Assault",
            },
            expected = {
                "Enchant Bracer - Assault",
                "Enchant Gloves - Assault",
            },
            requested = 2,
        },
        {
            name = "segment list keeps spellpower variants distinct",
            message = "lf 15 spell power bracer, 30 sp wep, 20sp to glove",
            scanned = {
                "Enchant Bracer - Spellpower",
                "Enchant Weapon - Spell Power",
                "Enchant Gloves - Major Spellpower",
            },
            expected = {
                "Enchant Bracer - Spellpower",
                "Enchant Weapon - Spell Power",
                "Enchant Gloves - Major Spellpower",
            },
            requested = 3,
        },
        {
            name = "chest mana prime and shield resilience pair correctly",
            message = "lf mp5 to chest and 12 res to shield",
            scanned = {
                "Enchant Chest - Restore Mana Prime",
                "Enchant Shield - Resilience",
            },
            expected = {
                "Enchant Chest - Restore Mana Prime",
                "Enchant Shield - Resilience",
            },
            requested = 2,
        },
        {
            name = "classic superior stamina bracer request uses specific numeric alias",
            message = "lf enchanter with 9 stam to bracers",
            scanned = {
                "Enchant Bracer - Superior Stamina",
            },
            expected = {
                "Enchant Bracer - Superior Stamina",
            },
            requested = 1,
        },
        {
            name = "classic mighty intellect weapon request uses specific numeric alias",
            message = "wtb 22 int weapon pst",
            scanned = {
                "Enchant Weapon - Mighty Intellect",
            },
            expected = {
                "Enchant Weapon - Mighty Intellect",
            },
            requested = 1,
        },
        {
            name = "classic mighty intellect weapon request uses numeric to-slot alias",
            message = "wtb 22 int to weapon pst",
            scanned = {
                "Enchant Weapon - Mighty Intellect",
            },
            expected = {
                "Enchant Weapon - Mighty Intellect",
            },
            requested = 1,
        },
        {
            name = "classic mighty intellect weapon request uses compact numeric alias",
            message = "wtb 22int weapon pst",
            scanned = {
                "Enchant Weapon - Mighty Intellect",
            },
            expected = {
                "Enchant Weapon - Mighty Intellect",
            },
            requested = 1,
        },
        {
            name = "classic mighty intellect weapon request uses plus numeric to-slot alias",
            message = "wtb +22 int to weapon pst",
            scanned = {
                "Enchant Weapon - Mighty Intellect",
            },
            expected = {
                "Enchant Weapon - Mighty Intellect",
            },
            requested = 1,
        },
        {
            name = "classic mighty intellect weapon request uses plus numeric alias",
            message = "wtb +22 int weapon pst",
            scanned = {
                "Enchant Weapon - Mighty Intellect",
            },
            expected = {
                "Enchant Weapon - Mighty Intellect",
            },
            requested = 1,
        },
        {
            name = "classic mighty intellect weapon request uses compact plus numeric alias",
            message = "wtb +22int weapon pst",
            scanned = {
                "Enchant Weapon - Mighty Intellect",
            },
            expected = {
                "Enchant Weapon - Mighty Intellect",
            },
            requested = 1,
        },
        {
            name = "incomplete list keeps accurate request count",
            message = "lf mongoose, boar, dodge",
            scanned = {
                "Enchant Weapon - Mongoose",
                "Enchant Boots - Boar's Speed",
            },
            expected = {
                "Enchant Weapon - Mongoose",
                "Enchant Boots - Boar's Speed",
            },
            requested = 3,
        },
        {
            name = "specific restore mana prime recipe name does not double count",
            message = "lf enchant chest - restore mana prime pst",
            scanned = {
                "Enchant Chest - Restore Mana Prime",
            },
            expected = {
                "Enchant Chest - Restore Mana Prime",
            },
            requested = 1,
        },
        {
            name = "full recipe name still matches when the separator dash is omitted",
            message = "lf enchanter with enchant shield major stamina",
            scanned = {
                "Enchant Shield - Major Stamina",
            },
            expected = {
                "Enchant Shield - Major Stamina",
            },
            requested = 1,
        },
        -- Cloak resistance permutations
        {
            name = "5 resist cloak matches Greater Resistance",
            message = "lf 5 resist cloak",
            scanned = { "Enchant Cloak - Greater Resistance" },
            expected = { "Enchant Cloak - Greater Resistance" },
        },
        {
            name = "+5 resist cloak matches Greater Resistance",
            message = "lf +5 resist cloak",
            scanned = { "Enchant Cloak - Greater Resistance" },
            expected = { "Enchant Cloak - Greater Resistance" },
        },
        {
            name = "5 resist to cloak matches Greater Resistance",
            message = "lf enchanter 5 resist to cloak pst",
            scanned = { "Enchant Cloak - Greater Resistance" },
            expected = { "Enchant Cloak - Greater Resistance" },
        },
        {
            name = "+5 resistance to cloak matches Greater Resistance",
            message = "wtb +5 resistance to cloak",
            scanned = { "Enchant Cloak - Greater Resistance" },
            expected = { "Enchant Cloak - Greater Resistance" },
        },
        {
            name = "5 resistance cloak matches Greater Resistance",
            message = "lf 5 resistance cloak pst",
            scanned = { "Enchant Cloak - Greater Resistance" },
            expected = { "Enchant Cloak - Greater Resistance" },
        },
        {
            name = "5 all resist cloak matches Greater Resistance",
            message = "lf 5 all resist to cloak",
            scanned = { "Enchant Cloak - Greater Resistance" },
            expected = { "Enchant Cloak - Greater Resistance" },
        },
        {
            name = "greater resistance to cloak matches Greater Resistance",
            message = "lf greater resistance to cloak",
            scanned = { "Enchant Cloak - Greater Resistance" },
            expected = { "Enchant Cloak - Greater Resistance" },
        },
        {
            name = "7 resis cloak matches Major Resistance",
            message = "lf 7 resis cloak",
            scanned = { "Enchant Cloak - Major Resistance" },
            expected = { "Enchant Cloak - Major Resistance" },
        },
        {
            name = "7 resist cloak matches Major Resistance",
            message = "lf 7 resist cloak",
            scanned = { "Enchant Cloak - Major Resistance" },
            expected = { "Enchant Cloak - Major Resistance" },
        },
        {
            name = "7 resistance cloak matches Major Resistance",
            message = "lf 7 resistance cloak",
            scanned = { "Enchant Cloak - Major Resistance" },
            expected = { "Enchant Cloak - Major Resistance" },
        },
        -- Cloak agility permutations
        {
            name = "12 agi to cloak matches Greater Agility",
            message = "lf 12 agi to cloak",
            scanned = { "Enchant Cloak - Greater Agility" },
            expected = { "Enchant Cloak - Greater Agility" },
        },
        {
            name = "12 agi to back matches Greater Agility via back alias",
            message = "wtb 12 agi to back pst",
            scanned = { "Enchant Cloak - Greater Agility" },
            expected = { "Enchant Cloak - Greater Agility" },
        },
        {
            name = "agi to cloak matches Greater Agility",
            message = "lf agi to cloak pst",
            scanned = { "Enchant Cloak - Greater Agility" },
            expected = { "Enchant Cloak - Greater Agility" },
        },
        -- Boots permutations
        {
            name = "7 agi to boots matches Enchant Boots - Greater Agility",
            message = "lf 7 agi to boots",
            scanned = { "Enchant Boots - Greater Agility" },
            expected = { "Enchant Boots - Greater Agility" },
        },
        {
            name = "+7 agi boots matches Enchant Boots - Greater Agility",
            message = "lf +7 agi boots",
            scanned = { "Enchant Boots - Greater Agility" },
            expected = { "Enchant Boots - Greater Agility" },
        },
        {
            name = "greater agility to boots matches Enchant Boots - Greater Agility",
            message = "lf greater agility to boots",
            scanned = { "Enchant Boots - Greater Agility" },
            expected = { "Enchant Boots - Greater Agility" },
        },
        {
            name = "7 stam to boots matches Enchant Boots - Greater Stamina",
            message = "lf 7 stam to boots",
            scanned = { "Enchant Boots - Greater Stamina" },
            expected = { "Enchant Boots - Greater Stamina" },
        },
        {
            name = "+7 stam boots matches Enchant Boots - Greater Stamina",
            message = "lf +7 stam boots",
            scanned = { "Enchant Boots - Greater Stamina" },
            expected = { "Enchant Boots - Greater Stamina" },
        },
        -- Bracer permutations
        {
            name = "9 stam to bracers matches Superior Stamina",
            message = "lf 9 stam to bracers",
            scanned = { "Enchant Bracer - Superior Stamina" },
            expected = { "Enchant Bracer - Superior Stamina" },
        },
        {
            name = "+9 stam bracers matches Superior Stamina",
            message = "lf +9 stam bracers",
            scanned = { "Enchant Bracer - Superior Stamina" },
            expected = { "Enchant Bracer - Superior Stamina" },
        },
        {
            name = "9 stam wrist matches Superior Stamina",
            message = "lf 9 stam to wrist",
            scanned = { "Enchant Bracer - Superior Stamina" },
            expected = { "Enchant Bracer - Superior Stamina" },
        },
        {
            name = "9 str bracer matches Superior Strength",
            message = "lf 9 str to bracer",
            scanned = { "Enchant Bracer - Superior Strength" },
            expected = { "Enchant Bracer - Superior Strength" },
        },
        {
            name = "+9 str to wrist matches Superior Strength",
            message = "lf +9 str to wrist",
            scanned = { "Enchant Bracer - Superior Strength" },
            expected = { "Enchant Bracer - Superior Strength" },
        },
        {
            name = "7 int bracer matches Greater Intellect",
            message = "lf 7 int bracer",
            scanned = { "Enchant Bracer - Greater Intellect" },
            expected = { "Enchant Bracer - Greater Intellect" },
        },
        {
            name = "+7 int to wrist matches Greater Intellect",
            message = "lf +7 int to wrist",
            scanned = { "Enchant Bracer - Greater Intellect" },
            expected = { "Enchant Bracer - Greater Intellect" },
        },
        -- Weapon permutations
        {
            name = "22 int to weapon matches Mighty Intellect",
            message = "lf 22 int to weapon",
            scanned = { "Enchant Weapon - Mighty Intellect" },
            expected = { "Enchant Weapon - Mighty Intellect" },
        },
        {
            name = "+22 int weapon matches Mighty Intellect",
            message = "lf +22 int weapon",
            scanned = { "Enchant Weapon - Mighty Intellect" },
            expected = { "Enchant Weapon - Mighty Intellect" },
        },
        {
            name = "22int weapon matches Mighty Intellect (compact)",
            message = "lf 22int weapon",
            scanned = { "Enchant Weapon - Mighty Intellect" },
            expected = { "Enchant Weapon - Mighty Intellect" },
        },
        {
            name = "22 intellect to weapon matches Mighty Intellect",
            message = "lf 22 intellect to weapon",
            scanned = { "Enchant Weapon - Mighty Intellect" },
            expected = { "Enchant Weapon - Mighty Intellect" },
        },
        {
            name = "15 str to weapon matches Strength",
            message = "lf 15 str to weapon",
            scanned = { "Enchant Weapon - Strength" },
            expected = { "Enchant Weapon - Strength" },
        },
        {
            name = "+15 str weapon matches Strength",
            message = "lf +15 str weapon",
            scanned = { "Enchant Weapon - Strength" },
            expected = { "Enchant Weapon - Strength" },
        },
        -- Chest permutations
        {
            name = "6 stat chest matches Exceptional Stats",
            message = "lf 6 stat to chest",
            scanned = { "Enchant Chest - Exceptional Stats" },
            expected = { "Enchant Chest - Exceptional Stats" },
        },
        {
            name = "150 hp chest matches Exceptional Health",
            message = "lf 150 hp chest",
            scanned = { "Enchant Chest - Exceptional Health" },
            expected = { "Enchant Chest - Exceptional Health" },
        },
        {
            name = "15 resil chest matches Major Resilience",
            message = "lf 15 resil to chest",
            scanned = { "Enchant Chest - Major Resilience" },
            expected = { "Enchant Chest - Major Resilience" },
        },
        -- Glove permutations
        {
            name = "15 agi gloves matches Superior Agility",
            message = "lf 15 agi gloves",
            scanned = { "Enchant Gloves - Superior Agility" },
            expected = { "Enchant Gloves - Superior Agility" },
        },
        {
            name = "+15 agi to gloves matches Superior Agility",
            message = "lf +15 agi to gloves",
            scanned = { "Enchant Gloves - Superior Agility" },
            expected = { "Enchant Gloves - Superior Agility" },
        },
        {
            name = "15 agi hands matches Superior Agility",
            message = "lf 15 agi to hands",
            scanned = { "Enchant Gloves - Superior Agility" },
            expected = { "Enchant Gloves - Superior Agility" },
        },
        {
            name = "26 ap gloves matches Assault",
            message = "lf 26 ap gloves",
            scanned = { "Enchant Gloves - Assault" },
            expected = { "Enchant Gloves - Assault" },
        },
        {
            name = "ap to gloves matches Assault",
            message = "lf ap to gloves",
            scanned = { "Enchant Gloves - Assault" },
            expected = { "Enchant Gloves - Assault" },
        },
        -- Shield permutations
        {
            name = "18 stam to shield matches Major Stamina",
            message = "lf 18 stam to shield",
            scanned = { "Enchant Shield - Major Stamina" },
            expected = { "Enchant Shield - Major Stamina" },
        },
        {
            name = "+18 stam shield matches Major Stamina",
            message = "lf +18 stam shield",
            scanned = { "Enchant Shield - Major Stamina" },
            expected = { "Enchant Shield - Major Stamina" },
        },
        {
            name = "stam to shield matches Major Stamina",
            message = "lf stam to shield",
            scanned = { "Enchant Shield - Major Stamina" },
            expected = { "Enchant Shield - Major Stamina" },
        },
        -- Plus-sign prefix permutations (common player shorthand)
        {
            name = "+40 sp to weapon matches Major Spellpower",
            message = "lf +40 sp to weap",
            scanned = { "Enchant Weapon - Major Spellpower" },
            expected = { "Enchant Weapon - Major Spellpower" },
        },
        {
            name = "40 sp weapon matches Major Spellpower",
            message = "lf 40 sp weapon",
            scanned = { "Enchant Weapon - Major Spellpower" },
            expected = { "Enchant Weapon - Major Spellpower" },
        },
        {
            name = "sp to weap matches Major Spellpower",
            message = "lf sp to weap",
            scanned = { "Enchant Weapon - Major Spellpower" },
            expected = { "Enchant Weapon - Major Spellpower" },
        },
        -- Cape synonym for cloak
        {
            name = "5 resist cape matches Greater Resistance",
            message = "lf 5 resist to cape",
            scanned = { "Enchant Cloak - Greater Resistance" },
            expected = { "Enchant Cloak - Greater Resistance" },
        },
        -- 2H weapon permutations
        {
            name = "35 agi 2h matches Major Agility",
            message = "lf 35 agi 2h",
            scanned = { "Enchant 2H Weapon - Major Agility" },
            expected = { "Enchant 2H Weapon - Major Agility" },
        },
        {
            name = "savagery 2h matches Savagery",
            message = "lf savagery 2h",
            scanned = { "Enchant 2H Weapon - Savagery" },
            expected = { "Enchant 2H Weapon - Savagery" },
        },
        -- Feet synonym for boots
        {
            name = "boar speed to feet matches Boar Speed",
            message = "lf boar to feet",
            scanned = { "Enchant Boots - Boar's Speed" },
            expected = { "Enchant Boots - Boar's Speed" },
        },
        {
            name = "speed to feet matches Minor Speed",
            message = "lf speed to feet",
            scanned = { "Enchant Boots - Minor Speed" },
            expected = { "Enchant Boots - Minor Speed" },
        },
        -- Healing bracer and wrist
        {
            name = "30 healing to bracer matches Superior Healing",
            message = "lf 30 healing to bracer",
            scanned = { "Enchant Bracer - Superior Healing" },
            expected = { "Enchant Bracer - Superior Healing" },
        },
        {
            name = "heal to wrist matches Superior Healing",
            message = "lf heal to wrist",
            scanned = { "Enchant Bracer - Superior Healing" },
            expected = { "Enchant Bracer - Superior Healing" },
        },
        -- MP5 permutations
        {
            name = "mp5 to wrist matches Restore Mana Prime bracer",
            message = "lf mp5 to wrist",
            scanned = { "Enchant Bracer - Restore Mana Prime" },
            expected = { "Enchant Bracer - Restore Mana Prime" },
        },
        {
            name = "mp5 to chest matches Restore Mana Prime chest",
            message = "lf mp5 to chest",
            scanned = { "Enchant Chest - Restore Mana Prime" },
            expected = { "Enchant Chest - Restore Mana Prime" },
        },
        -- [Enchanting: ...] spell link format (Shift-click from profession window)
        {
            name = "enchanting spell link with lf prefix matches scanned recipe",
            message = "lf enchanter [Enchanting: Enchant Shield - Major Stamina]",
            scanned = { "Enchant Shield - Major Stamina" },
            expected = { "Enchant Shield - Major Stamina" },
        },
        {
            name = "enchanting spell link with wtb prefix matches scanned recipe",
            message = "wtb [Enchanting: Enchant Weapon - Mongoose]",
            scanned = { "Enchant Weapon - Mongoose" },
            expected = { "Enchant Weapon - Mongoose" },
        },
        {
            name = "adjacent enchanting spell links each match their own scanned recipe",
            message = "lf [Enchanting: Enchant Weapon - Mongoose][Enchanting: Enchant Boots - Boar's Speed]",
            scanned = { "Enchant Weapon - Mongoose", "Enchant Boots - Boar's Speed" },
            expected = { "Enchant Weapon - Mongoose", "Enchant Boots - Boar's Speed" },
            requested = 2,
        },
        {
            name = "enchanting spell links separated by and each match their own scanned recipe",
            message = "lf enchanter - [Enchanting: Enchant Bracer - Spellpower] and [Enchanting: Enchant Cloak - Subtlety]",
            scanned = { "Enchant Bracer - Spellpower", "Enchant Cloak - Subtlety" },
            expected = { "Enchant Bracer - Spellpower", "Enchant Cloak - Subtlety" },
            requested = 2,
        },
    }

    for index, case in ipairs(cases) do
        run_request_matching_case(case, index, false)
    end
end

local function test_invalid_request_matching_scenarios()
    local cases = {
        {
            name = "default blacklist blocks glove healing on weapon ask",
            message = "lf 35 heal wep",
            scanned = {
                "Enchant Gloves - Major Healing",
            },
        },
        {
            name = "default blacklist blocks weapon healing on chest ask",
            message = "lf 81 heal chest",
            scanned = {
                "Enchant Weapon - Major Healing",
            },
        },
        {
            name = "default blacklist blocks bracer mana prime on chest ask",
            message = "lf restore mana prime to chest",
            scanned = {
                "Enchant Bracer - Restore Mana Prime",
            },
        },
        {
            name = "default blacklist blocks glove major spellpower on weapon ask",
            message = "lf major spellpower weapon",
            scanned = {
                "Enchant Gloves - Major Spellpower",
            },
        },
        {
            name = "default blacklist blocks glove agility on weapon phrasing",
            message = "lf 15 agi to wep",
            scanned = {
                "Enchant Gloves - Superior Agility",
            },
        },
        {
            name = "default blacklist blocks glove healing on shield ask",
            message = "lf 35 heal shield",
            scanned = {
                "Enchant Gloves - Major Healing",
            },
        },
        {
            name = "default blacklist blocks weapon spell power on chest ask",
            message = "lf 30 sp chest",
            scanned = {
                "Enchant Weapon - Spell Power",
            },
        },
        {
            name = "default blacklist blocks bracer spellpower on glove ask",
            message = "lf 15 spell power gloves",
            scanned = {
                "Enchant Bracer - Spellpower",
            },
        },
        {
            name = "default blacklist blocks shield resilience on chest ask",
            message = "lf 12 res chest",
            scanned = {
                "Enchant Shield - Resilience",
            },
        },
        {
            name = "default blacklist blocks chest mana prime on wrist ask",
            message = "lf mp5 to wrist",
            scanned = {
                "Enchant Chest - Restore Mana Prime",
            },
        },
        {
            name = "default blacklist blocks 2h agility on glove ask",
            message = "lf 35 agi gloves",
            scanned = {
                "Enchant 2H Weapon - Major Agility",
            },
        },
        {
            name = "missing dash alias does not match a different shield enchant",
            message = "lf enchant shield major stamina",
            scanned = {
                "Enchant Shield - Resilience",
            },
        },
        {
            name = "generic stamina bracer ask does not match a classic stamina rank",
            message = "lf stam to bracers",
            scanned = {
                "Enchant Bracer - Superior Stamina",
            },
        },
        -- Slot cross-contamination: cloak resistance should not match non-cloak requests
        {
            name = "5 resist weapon does not match cloak resistance",
            message = "lf 5 resist weapon",
            scanned = {
                "Enchant Cloak - Greater Resistance",
            },
        },
        {
            name = "5 resist chest does not match cloak resistance",
            message = "lf 5 resist to chest",
            scanned = {
                "Enchant Cloak - Greater Resistance",
            },
        },
        -- Rank cross-contamination: a lower-rank enchant should not match a higher-rank request
        {
            name = "7 agi boots does not match Dexterity (12 agi to boots)",
            message = "lf 7 agi to boots",
            scanned = {
                "Enchant Boots - Dexterity",
            },
        },
        {
            name = "generic int weapon does not match classic Mighty Intellect",
            message = "lf int weapon",
            scanned = {
                "Enchant Weapon - Mighty Intellect",
            },
        },
        {
            name = "generic str weapon does not match classic Strength",
            message = "lf str to weapon",
            scanned = {
                "Enchant Weapon - Strength",
            },
        },
        {
            name = "generic stam boots does not match classic Greater Stamina",
            message = "lf stam to boots",
            scanned = {
                "Enchant Boots - Greater Stamina",
            },
        },
        {
            name = "generic agi bracer does not match classic Greater Strength",
            message = "lf agi to bracer",
            scanned = {
                "Enchant Bracer - Greater Strength",
            },
        },
        -- Weapon/glove spellpower ambiguity should be caught by blacklist
        {
            name = "major spellpower to weapon does not match glove Major Spellpower",
            message = "lf major spellpower to weapon",
            scanned = {
                "Enchant Gloves - Major Spellpower",
            },
        },
        -- Shield/chest resilience separation
        {
            name = "15 resil chest does not match shield resilience",
            message = "lf 15 resil chest",
            scanned = {
                "Enchant Shield - Resilience",
            },
        },
        {
            name = "12 res shield does not match chest major resilience",
            message = "lf 12 res shield",
            scanned = {
                "Enchant Chest - Major Resilience",
            },
        },
        {
            name = "formula item link should not match enchant service request",
            message = "wtb [Formula: Enchant Chest - Major Resilience]",
            scanned = {
                "Enchant Chest - Major Resilience",
            },
        },
    }

    for index, case in ipairs(cases) do
        run_request_matching_case(case, index, true)
    end
end

local function test_requested_recipe_count_scenarios()
    local cases = {
        {
            name = "two valid segmented requests count as two of two",
            message = "lf 15 resil to chest, 81 heal wep",
            scanned = {
                "Enchant Chest - Major Resilience",
                "Enchant Weapon - Major Healing",
            },
            expected = {
                "Enchant Chest - Major Resilience",
                "Enchant Weapon - Major Healing",
            },
            requested = 2,
        },
        {
            name = "partial list counts missing third request",
            message = "lf 15 resil to chest, 81 heal wep, mongoose",
            scanned = {
                "Enchant Chest - Major Resilience",
                "Enchant Weapon - Major Healing",
            },
            expected = {
                "Enchant Chest - Major Resilience",
                "Enchant Weapon - Major Healing",
            },
            requested = 3,
        },
        {
            name = "three matched and one missing count as three of four",
            message = "lf mongoose, boar, dodge, savagery",
            scanned = {
                "Enchant Weapon - Mongoose",
                "Enchant Boots - Boar's Speed",
                "Enchant Cloak - Dodge",
            },
            expected = {
                "Enchant Weapon - Mongoose",
                "Enchant Boots - Boar's Speed",
                "Enchant Cloak - Dodge",
            },
            requested = 4,
        },
        {
            name = "blocked false positive does not inflate requested count",
            message = "lf 35 heal gloves, 35 heal wep",
            scanned = {
                "Enchant Gloves - Major Healing",
            },
            expected = {
                "Enchant Gloves - Major Healing",
            },
            requested = 1,
        },
        {
            name = "mixed valid and invalid spellpower chunks count only real requests",
            message = "lf 15 spell power bracer, 30 sp wep, major spellpower weapon",
            scanned = {
                "Enchant Bracer - Spellpower",
                "Enchant Weapon - Spell Power",
                "Enchant Gloves - Major Spellpower",
            },
            expected = {
                "Enchant Bracer - Spellpower",
                "Enchant Weapon - Spell Power",
            },
            requested = 2,
        },
        {
            name = "invalid agility bait does not block a later valid request count",
            message = "lf 15 agi to wep, mongoose",
            scanned = {
                "Enchant Gloves - Superior Agility",
                "Enchant Weapon - Mongoose",
            },
            expected = {
                "Enchant Weapon - Mongoose",
            },
            requested = 1,
        },
        {
            name = "recognized unscanned bracer request still increments requested count",
            message = "lf 15 res chest and 12 res shield and mp5 to wrist",
            scanned = {
                "Enchant Chest - Major Resilience",
            },
            expected = {
                "Enchant Chest - Major Resilience",
            },
            requested = 3,
        },
        {
            name = "slash separated mixed known requests count accurately",
            message = "lf mp5 to chest / 81 heal wep / 15 res chest",
            scanned = {
                "Enchant Chest - Restore Mana Prime",
                "Enchant Weapon - Major Healing",
                "Enchant Chest - Major Resilience",
            },
            expected = {
                "Enchant Chest - Restore Mana Prime",
                "Enchant Weapon - Major Healing",
                "Enchant Chest - Major Resilience",
            },
            requested = 3,
        },
        {
            name = "multiple valid segments plus one unscanned valid chunk count as four",
            message = "lf 35 heal gloves / 81 heal wep / 30 sp wep / 20sp to glove",
            scanned = {
                "Enchant Gloves - Major Healing",
                "Enchant Weapon - Major Healing",
                "Enchant Weapon - Spell Power",
            },
            expected = {
                "Enchant Gloves - Major Healing",
                "Enchant Weapon - Major Healing",
                "Enchant Weapon - Spell Power",
            },
            requested = 4,
        },
        {
            name = "full four piece request counts as four of four",
            message = "lf 15 resil chest, 12 res shield, mp5 to chest, mongoose",
            scanned = {
                "Enchant Chest - Major Resilience",
                "Enchant Shield - Resilience",
                "Enchant Chest - Restore Mana Prime",
                "Enchant Weapon - Mongoose",
            },
            expected = {
                "Enchant Chest - Major Resilience",
                "Enchant Shield - Resilience",
                "Enchant Chest - Restore Mana Prime",
                "Enchant Weapon - Mongoose",
            },
            requested = 4,
        },
    }

    for index, case in ipairs(cases) do
        run_request_matching_case(case, index + 100, false)
    end
end

local function test_default_recipe_blacklists_compile_and_merge_with_custom_blacklists()
    local addon = setup_env({
        db = {
            Custom = {
                RecipeBlackList = {
                    ["Enchant Gloves - Major Healing"] = "focus",
                },
            },
        },
    })

    addon.OptionsUpdate()

    local blacklist = addon.RecipeBlacklistMap["Enchant Gloves - Major Healing"] or {}
    local joined = table.concat(blacklist, ",")

    assert_true(string.find(joined, "weapon", 1, true) ~= nil, "default recipe blacklists should compile even without custom overrides")
    assert_true(string.find(joined, "focus", 1, true) ~= nil, "custom recipe blacklists should merge with built-in defaults")
end

local function test_scan_filters_unknown_and_nether_recipes()
    local addon, state = setup_env({
        db = {
            NetherRecipes = true,
        },
        trade_skills = {
            { name = "Enchant Boots - Surefooted", link = "spell:27954" },
            { name = "Enchant Weapon - Mongoose", link = "spell:27984" },
            { name = "Completely Unknown Recipe", link = "spell:99999" },
        },
    })

    local ok = addon.GetItems()

    assert_true(ok, "scan should succeed with trade-skill API fallback")
    assert_equal(state.last_cast, "Enchanting", "scan should open enchanting")
    assert_nil(EnchanterDBChar.RecipeList["Enchant Boots - Surefooted"], "nether recipe should be filtered when disabled")
    assert_equal(EnchanterDBChar.RecipeLinks["Enchant Weapon - Mongoose"], "spell:27984", "known recipe link should be stored")
    assert_nil(EnchanterDBChar.RecipeList["Completely Unknown Recipe"], "unknown recipes should not be added")
end

local function test_scan_builds_specific_slot_aliases_for_unsupported_enchants()
    local addon, state = setup_env({
        trade_skills = {
            { name = "Enchant Cloak - Lesser Agility" },
        },
    })

    local ok = addon.GetItems()
    local scannedTags = EnchanterDBChar.RecipeList["Enchant Cloak - Lesser Agility"]

    assert_true(ok, "scan should keep unsupported enchant formulas when their official names are available")
    assert_not_nil(scannedTags, "unsupported enchant formulas should still be stored after scanning")
    assert_true(list_contains(scannedTags, "enchant cloak - lesser agility"), "unsupported enchant formulas should still keep the official recipe name")
    assert_true(list_contains(scannedTags, "lesser agility to cloak"), "unsupported enchant formulas should gain specific slot-aware fallback aliases")
    assert_true(list_contains(scannedTags, "lesser agility to back"), "unsupported enchant formulas should include specific back-slot phrasing")
    assert_true(list_contains(scannedTags, "3 agi cloak"), "unsupported enchant formulas should include recipe-specific numeric phrasing")
    assert_true(list_contains(scannedTags, "+3 agi cloak"), "unsupported enchant formulas should include plus-prefixed numeric phrasing")
    assert_true(list_contains(scannedTags, "3 agi cape"), "unsupported enchant formulas should include cape as a cloak synonym")
    assert_true(not list_contains(scannedTags, "agility to back"), "unsupported enchant formulas should not gain generic shorthand aliases")

    addon.ParseMessage("LF Enchant Cloak - Lesser Agility pst", "Buyer-ExactName")
    assert_equal(#state.whispers, 1, "exact recipe names should match unsupported scanned enchants")
    assert_true(string.find(state.whispers[1].message, "%[Enchant Cloak %- Lesser Agility%]") ~= nil, "exact-name matches should still whisper the scanned enchant")

    addon.ParseMessage("LF [Enchanting: Enchant Cloak - Lesser Agility] pst", "Buyer-LinkedName")
    assert_equal(#state.whispers, 2, "linked recipe names should match unsupported scanned enchants")

    addon.ParseMessage("LF lesser agility to back pst", "Buyer-SpecificFallback")
    assert_equal(#state.whispers, 3, "unsupported scanned enchants should match their generated specific fallback aliases")

    addon.ParseMessage("LF +3 agi cloak pst", "Buyer-PlusNumeric")
    assert_equal(#state.whispers, 4, "unsupported scanned enchants should match plus-prefixed numeric cloak aliases")

    addon.ParseMessage("LF 3 agi cape pst", "Buyer-CapeNumeric")
    assert_equal(#state.whispers, 5, "unsupported scanned enchants should match numeric cape aliases")

    addon.ParseMessage("LF agility to back pst", "Buyer-Shorthand")
    assert_equal(#state.whispers, 5, "unsupported scanned enchants should not gain new generic shorthand aliases")
end

local function test_classic_recipe_aliases_stay_specific()
    local addon = setup_env()
    local staminaTags = addon.DefaultRecipeTags.enGB["Enchant Bracer - Superior Stamina"] or {}
    local intellectTags = addon.DefaultRecipeTags.enGB["Enchant Weapon - Mighty Intellect"] or {}

    assert_true(list_contains(staminaTags, "9 stam to bracers"), "classic rank aliases should include specific numeric phrasing")
    assert_true(list_contains(staminaTags, "superior stamina to bracers"), "classic rank aliases should include specific named-effect phrasing")
    assert_true(not list_contains(staminaTags, "stam to bracers"), "classic rank aliases should avoid generic ambiguous phrasing")
    assert_true(list_contains(intellectTags, "22int weapon"), "classic rank aliases should include compact numeric phrasing")
    assert_true(list_contains(intellectTags, "22 int to weapon"), "classic rank aliases should keep spaced numeric phrasing")
    assert_true(list_contains(intellectTags, "+22 int to weapon"), "classic rank aliases should include plus-prefixed spaced phrasing")
    assert_true(list_contains(intellectTags, "+22 int weapon"), "classic rank aliases should include plus-prefixed slot phrasing")
    assert_true(list_contains(intellectTags, "+22int weapon"), "classic rank aliases should include compact plus-prefixed phrasing")
    assert_true(not list_contains(intellectTags, "int weapon"), "classic rank aliases should not fall back to generic ambiguous phrasing")
end

local function test_formula_purchase_requests_do_not_match_enchant_service()
    local addon, state = setup_env({
        char_db = {
            RecipeList = {
                ["Enchant Chest - Major Resilience"] = { "enchant chest - major resilience" },
            },
            RecipeLinks = {
                ["Enchant Chest - Major Resilience"] = "[Enchant Chest - Major Resilience] ",
            },
        },
    })

    addon.RefreshCompiledData()
    addon.ParseMessage("[Formula: Enchant Chest - Major Resilience] WTB", "Buyer-FormulaLink")

    assert_equal(#state.invites, 0, "formula item links should not trigger enchant invites")
    assert_equal(#state.whispers, 0, "formula item links should not trigger enchant whispers")
    assert_nil(addon.Workbench.GetOrderByCustomer("Buyer-FormulaLink"), "formula item links should not queue an enchant order")

    addon.ParseMessage("WTB Formula: Enchant Chest - Major Resilience pst", "Buyer-FormulaText")

    assert_equal(#state.invites, 0, "plain formula sale text should not trigger enchant invites")
    assert_equal(#state.whispers, 0, "plain formula sale text should not trigger enchant whispers")
    assert_nil(addon.Workbench.GetOrderByCustomer("Buyer-FormulaText"), "plain formula sale text should not queue an enchant order")
end

local function test_scan_prefers_trade_skill_recipe_data_when_both_apis_exist()
    local addon = setup_env({
        crafts = {
            {
                name = "Enchant Boots - Minor Speed",
                link = "craft:13890",
                reagents = {
                    { name = "Wrong Dust", count = 2, link = "item:99999" },
                },
            },
        },
        trade_skills = {
            {
                name = "Enchant Boots - Minor Speed",
                link = "spell:13890",
                reagents = {
                    { name = "Soul Dust", count = 6, link = "item:11083" },
                },
            },
        },
    })

    local ok = addon.GetItems()
    local materials = EnchanterDBChar.RecipeMats["Enchant Boots - Minor Speed"]

    assert_true(ok, "scan should still succeed when both recipe api families are exposed")
    assert_equal(EnchanterDBChar.RecipeLinks["Enchant Boots - Minor Speed"], "spell:13890", "scan should prefer the trade skill recipe link when both api families are available")
    assert_equal(materials[1].Name, "Soul Dust", "scan should keep recipe materials aligned with the chosen trade skill api family")
end

local function test_options_update_rebuilds_compiled_tags()
    local addon = setup_env({
        db = {
            Custom = {
                BlackList = "wts,portal",
                SearchPrefix = "lf,need",
                GenericPrefix = "lf enchanter,need enchanter",
                RecipeBlackList = {
                    ["Enchant Weapon - Mongoose"] = "staff,polearm",
                },
                ["Enchant Weapon - Mongoose"] = "mongoose,weapon mongoose",
            },
        },
        char_db = {
            RecipeList = {
                ["Enchant Weapon - Mongoose"] = { "stale tag" },
            },
        },
    })

    addon.OptionsUpdate()

    assert_equal(#addon.PrefixTagsCompiled, 2, "custom prefixes should compile")
    assert_equal(#addon.BlacklistCompiled, 2, "custom blacklist should compile")
    assert_equal(#addon.RecipeBlacklistMap["Enchant Weapon - Mongoose"], 2, "per-recipe blacklist phrases should compile")
    assert_equal(addon.RecipeTagsMap["mongoose"], "Enchant Weapon - Mongoose", "custom recipe tag should be mapped")
    assert_equal(addon.DBChar.RecipeList["Enchant Weapon - Mongoose"][2], "weapon mongoose", "custom recipe tags should replace stale tags")
end

local function test_custom_recipe_tags_keep_exact_link_matching()
    local addon, state = setup_env({
        db = {
            InviteTimeDelay = 0,
            WhisperTimeDelay = 0,
            Custom = {
                ["Enchant Shield - Major Stamina"] = "18 stam shield custom",
            },
        },
        char_db = {
            RecipeList = {
                ["Enchant Shield - Major Stamina"] = { "18 stam shield custom" },
            },
            RecipeLinks = {
                ["Enchant Shield - Major Stamina"] = "[Enchant Shield - Major Stamina] ",
            },
        },
    })

    addon.OptionsUpdate()
    addon.ParseMessage("LF enchanter [Enchanting: Enchant Shield - Major Stamina]", "Buyer-CustomLink")

    assert_true(
        list_contains(addon.DBChar.RecipeList["Enchant Shield - Major Stamina"], "enchant shield - major stamina"),
        "custom recipe phrase lists should retain exact linked recipe matching"
    )
    assert_equal(#state.invites, 1, "exact profession link should still invite when custom tags omit the official name")
    assert_equal(#state.whispers, 1, "exact profession link should still whisper when custom tags omit the official name")
end

local function test_global_blacklist_treats_punctuation_literally()
    local addon, state = setup_env({
        db = {
            InviteTimeDelay = 0,
            WhisperTimeDelay = 0,
            Custom = {
                BlackList = "enchant ring -",
            },
        },
        char_db = {
            RecipeList = {
                ["Enchant Ring Stats"] = { "enchant ring stats" },
                ["Enchant Ring - Stats"] = { "enchant ring - stats" },
            },
            RecipeLinks = {
                ["Enchant Ring Stats"] = "[Enchant Ring Stats] ",
                ["Enchant Ring - Stats"] = "[Enchant Ring - Stats] ",
            },
        },
    })

    addon.OptionsUpdate()
    addon.ParseMessage("LF [Enchanting: Enchant Ring Stats]", "Buyer-RingPlain")
    addon.ParseMessage("LF [Enchanting: Enchant Ring - Stats]", "Buyer-RingDash")

    assert_equal(#state.invites, 1, "blacklist punctuation should not behave like a Lua pattern operator")
    assert_equal(#state.whispers, 1, "only the literal dashed ring phrase should be blacklisted")
    assert_equal(state.whispers[1].target, "Buyer-RingPlain", "the non-dashed linked recipe should remain eligible")
end

local function test_linked_enchanting_messages_survive_user_global_blacklist()
    local userBlacklist = "your mats,no clankers,shat,shatt,no clanker,tailor,lfw, lf work,Undercity,in uc,Silvermoon,free,thunder bluff, in TB,no auto invite,not accepting auto invite,enchant ring -,Mana Tombs"
    local addon, state = setup_env({
        db = {
            InviteTimeDelay = 0,
            WhisperTimeDelay = 0,
            Custom = {
                BlackList = userBlacklist,
            },
        },
    })

    seed_scanned_recipes(addon, {
        "Enchant Gloves - Healing Power",
        "Enchant Shield - Major Stamina",
        "Enchant Chest - Major Resilience",
        "Enchant Bracer - Spellpower",
        "Enchant Cloak - Subtlety",
    })
    addon.OptionsUpdate()

    addon.ParseMessage("LF enchanter with [Enchanting: Enchant Gloves - Healing Power] n org mats tipping", "Buyer-Gloves")
    addon.ParseMessage("LF enchanter [Enchanting: Enchant Shield - Major Stamina]", "Buyer-Shield")
    addon.ParseMessage("LF [Enchanting: Enchant Chest - Major Resilience] PST", "Buyer-Chest")
    addon.ParseMessage("LF Enchanter - [Enchanting: Enchant Bracer - Spellpower] and [Enchanting: Enchant Cloak - Subtlety]", "Buyer-MultiLink")
    addon.ParseMessage("[Enchanting] LFW Have ALL TBC Enchants PST!!", "Seller-LFW")

    assert_equal(#state.invites, 4, "screenshot-style linked requests should not be blocked by the user's global blacklist")
    assert_equal(#state.whispers, 4, "screenshot-style linked requests should still be whispered")
    assert_whisper_contains_recipe(state.whispers[4].message, "Enchant Bracer - Spellpower", "multi-link screenshot whisper")
    assert_whisper_contains_recipe(state.whispers[4].message, "Enchant Cloak - Subtlety", "multi-link screenshot whisper")
end

local function test_parse_message_skips_recipe_when_per_recipe_blacklist_matches()
    local addon, state = setup_env({
        db = {
            Custom = {
                RecipeBlackList = {
                    ["Enchant Gloves - Superior Agility"] = "wep,weapon",
                },
            },
        },
        char_db = {
            RecipeList = {
                ["Enchant Gloves - Superior Agility"] = { "15 agi" },
            },
            RecipeLinks = {
                ["Enchant Gloves - Superior Agility"] = "[Enchant Gloves - Superior Agility] ",
            },
        },
    })

    addon.OptionsUpdate()
    addon.ParseMessage("LF 15 agi to wep pst", "Buyer-Blacklisted")

    assert_equal(#state.invites, 0, "per-recipe blacklist phrases should block false-positive invites")
    assert_equal(#state.whispers, 0, "per-recipe blacklist phrases should block false-positive whispers")
end

local function test_parse_message_keeps_recipe_when_blacklist_phrase_is_in_another_segment()
    local addon, state = setup_env({
        db = {
            InviteTimeDelay = 0,
            WhisperTimeDelay = 0,
            Custom = {
                RecipeBlackList = {
                    ["Enchant Gloves - Major Healing"] = "weapon,wep,chest,bracer,boots,cloak,shield",
                },
            },
        },
        char_db = {
            RecipeList = {
                ["Enchant Gloves - Major Healing"] = { "35 heal" },
                ["Enchant Weapon - Spell Power"] = { "30 sp" },
            },
            RecipeLinks = {
                ["Enchant Gloves - Major Healing"] = "[Enchant Gloves - Major Healing] ",
                ["Enchant Weapon - Spell Power"] = "[Enchant Weapon - Spell Power] ",
            },
        },
    })

    addon.OptionsUpdate()
    addon.ParseMessage("LF 35 heal gloves, 30 sp weapon pst", "Buyer-Segmented")

    assert_equal(#state.invites, 1, "recipes should still match when a blacklist phrase appears in another request segment")
    assert_equal(#state.whispers, 1, "segmented blacklist matching should still whisper the valid recipes")
    assert_true(string.find(state.whispers[1].message, "%[Enchant Gloves %- Major Healing%]") ~= nil, "glove recipe should survive when the conflicting slot word is in another segment")
    assert_true(string.find(state.whispers[1].message, "%[Enchant Weapon %- Spell Power%]") ~= nil, "other segmented recipe matches should still be included")
end

local function test_parse_message_does_not_double_count_nested_request_tags()
    local addon, state = setup_env({
        db = {
            InviteTimeDelay = 0,
            WhisperTimeDelay = 0,
            MsgPrefix = "I can do ",
            WarnIncompleteOrder = true,
        },
        char_db = {
            RecipeList = {
                ["Enchant Chest - Restore Mana Prime"] = { "enchant chest - restore mana prime", "mp5 to chest" },
            },
            RecipeLinks = {
                ["Enchant Chest - Restore Mana Prime"] = "[Enchant Chest - Restore Mana Prime] ",
            },
        },
    })

    addon.RefreshCompiledData()
    addon.ParseMessage("LF enchant chest - restore mana prime pst", "Buyer-Nested")

    assert_equal(#state.whispers, 1, "single nested recipe requests should still whisper once")
    assert_true(string.find(state.whispers[1].message, "1/2", 1, true) == nil, "longer nested recipe names should not inflate the requested recipe count")
    assert_true(string.find(state.whispers[1].message, "%[Enchant Chest %- Restore Mana Prime%]") ~= nil, "nested recipe requests should still match the intended recipe")
end

local function test_parse_message_matches_multi_enchant_lists_by_segment()
    local addon, state = setup_env({
        db = {
            InviteTimeDelay = 0,
            WhisperTimeDelay = 0,
            MsgPrefix = "I can do ",
            WarnIncompleteOrder = true,
        },
        char_db = {
            RecipeList = {
                ["Enchant Weapon - Mongoose"] = { "mongoose" },
                ["Enchant Boots - Boar's Speed"] = { "boar" },
                ["Enchant Cloak - Dodge"] = { "dodge" },
            },
            RecipeLinks = {
                ["Enchant Weapon - Mongoose"] = "[Enchant Weapon - Mongoose] ",
                ["Enchant Boots - Boar's Speed"] = "[Enchant Boots - Boar's Speed] ",
                ["Enchant Cloak - Dodge"] = "[Enchant Cloak - Dodge] ",
            },
        },
    })

    addon.RefreshCompiledData()
    addon.ParseMessage("LF mongoose, boar, dodge pst", "Buyer-List")

    assert_equal(#state.whispers, 1, "multi-enchant list requests should still produce one whisper")
    assert_true(string.find(state.whispers[1].message, "1/2", 1, true) == nil, "segmented multi-enchant lists should not get a false incomplete warning")
    assert_true(string.find(state.whispers[1].message, "%[Enchant Weapon %- Mongoose%]") ~= nil, "first segmented recipe should match")
    assert_true(string.find(state.whispers[1].message, "%[Enchant Boots %- Boar's Speed%]") ~= nil, "second segmented recipe should match")
    assert_true(string.find(state.whispers[1].message, "%[Enchant Cloak %- Dodge%]") ~= nil, "third segmented recipe should match")
end

local function test_parse_message_keeps_adjacent_linked_enchants_from_blacklisting_each_other()
    local addon, state = setup_env({
        db = {
            InviteTimeDelay = 0,
            WhisperTimeDelay = 0,
            MsgPrefix = "I can do ",
        },
        char_db = {
            RecipeList = {
                ["Enchant Bracer - Superior Healing"] = { "enchant bracer - superior healing" },
                ["Enchant Gloves - Major Healing"] = { "enchant gloves - major healing", "35 heal" },
            },
            RecipeLinks = {
                ["Enchant Bracer - Superior Healing"] = "[Enchant Bracer - Superior Healing] ",
                ["Enchant Gloves - Major Healing"] = "[Enchant Gloves - Major Healing] ",
            },
        },
    })

    addon.RefreshCompiledData()
    addon.ParseMessage("LF Enchanter [Enchanting: Enchant Bracer - Superior Healing][Enchanting: Enchant Gloves - Major Healing]", "Buyer-Linked")

    assert_equal(#state.whispers, 1, "adjacent linked enchants should still produce one whisper")
    assert_true(string.find(state.whispers[1].message, "%[Enchant Bracer %- Superior Healing%]") ~= nil, "linked bracer recipe should match")
    assert_true(string.find(state.whispers[1].message, "%[Enchant Gloves %- Major Healing%]") ~= nil, "linked glove recipe should survive the bracer blacklist phrase")
end

local function test_parse_message_ignores_mid_token_recipe_alias_false_positive()
    local addon, state = setup_env({
        db = {
            InviteTimeDelay = 0,
            WhisperTimeDelay = 0,
            MsgPrefix = "I can do ",
        },
        char_db = {
            RecipeList = {
                ["Enchant Chest - Major Resilience"] = { "15 res", "15 resil" },
            },
            RecipeLinks = {
                ["Enchant Chest - Major Resilience"] = "[Enchant Chest - Major Resilience] ",
            },
        },
    })

    addon.RefreshCompiledData()
    addon.ParseMessage("1815 resto druid lf 2's partner", "Buyer-Arena")

    assert_equal(#state.invites, 0, "mid-token numeric shorthand should not trigger a false invite")
    assert_equal(#state.whispers, 0, "mid-token numeric shorthand should not trigger a false whisper")
    assert_nil(addon.Workbench.GetOrderByCustomer("Buyer-Arena"), "mid-token numeric shorthand should not queue a fake order")
end

local function test_incomplete_order_settings_default_on()
    local addon = setup_env()

    assert_true(addon.DB.WarnIncompleteOrder, "incomplete-order warnings should default to enabled")
    assert_true(addon.DB.InviteIncompleteOrder, "incomplete-order invites should default to enabled")
    assert_true(addon.DB.EmoteThankAfterCast == false, "thank emotes should default to disabled")
    assert_equal(addon.DB.DeclinedInviteRemovalSeconds, 0, "declined invite removal timer should default to disabled")
    assert_equal(addon.DB.MaxGroupedCustomers, 0, "max grouped customers should default to unlimited")
end

local function test_parse_message_invites_once_and_whispers_link()
    local addon, state = setup_env({
        db = {
            InviteTimeDelay = 2,
            WhisperTimeDelay = 1,
            MsgPrefix = "I can do ",
        },
        char_db = {
            RecipeList = {
                ["Enchant Weapon - Mongoose"] = { "mongoose" },
            },
            RecipeLinks = {
                ["Enchant Weapon - Mongoose"] = "[Enchant Weapon - Mongoose] ",
            },
        },
    })

    addon.RefreshCompiledData()
    addon.ParseMessage("LF mongoose pst", "Buyer-One")
    addon.ParseMessage("LF mongoose pst", "Buyer-One")

    assert_equal(#state.invites, 1, "player should only be invited once")
    assert_equal(state.invites[1], "Buyer-One", "invite target should match requester")
    assert_equal(#state.whispers, 1, "one whisper should be sent for the first match")
    assert_equal(state.whispers[1].chat_type, "WHISPER", "match response should use whisper")
    assert_equal(state.whispers[1].target, "Buyer-One", "whisper target should match requester")
    assert_true(string.find(state.whispers[1].message, "%[Enchant Weapon %- Mongoose%]") ~= nil, "whisper should include recipe link text")
    assert_equal(state.timer_delays[1], 2, "invite delay should flow through the timer helper")
    assert_equal(state.timer_delays[2], 1, "whisper delay should flow through the timer helper")
end

local function test_message_prefix_randomizes_across_comma_separated_choices()
    local random_results = { 2, 1 }
    local random_choice_calls = 0
    local addon, state = setup_env({
        omit_math_random = true,
        omit_math_randomseed = true,
        global_random = function(max_value)
            if max_value == nil then
                return 1
            end
            random_choice_calls = random_choice_calls + 1
            assert_equal(max_value, 3, "randomized message prefixes should pick from every configured choice")
            return random_results[random_choice_calls]
        end,
        db = {
            InviteTimeDelay = 0,
            WhisperTimeDelay = 0,
            MsgPrefix = "I can do ,Yo I got ,Wass good I got you fam ",
        },
        char_db = {
            RecipeList = {
                ["Enchant Weapon - Mongoose"] = { "mongoose" },
            },
            RecipeLinks = {
                ["Enchant Weapon - Mongoose"] = "[Enchant Weapon - Mongoose] ",
            },
        },
    })

    addon.RefreshCompiledData()
    addon.ParseMessage("LF mongoose pst", "Buyer-Random-One")
    addon.ParseMessage("LF mongoose pst", "Buyer-Random-Two")

    assert_equal(#state.whispers, 2, "randomized prefixes should still whisper each matched customer once")
    assert_true(string.find(state.whispers[1].message, "Yo I got ", 1, true) == 1, "the first whisper should use the randomly selected second prefix")
    assert_true(string.find(state.whispers[2].message, "I can do ", 1, true) == 1, "the second whisper should reroll the prefix for the next customer")
    assert_true(string.find(state.whispers[1].message, "%[Enchant Weapon %- Mongoose%]") ~= nil, "randomized prefixes should still include recipe links")
    assert_equal(random_choice_calls, 2, "each outgoing recipe whisper should choose its prefix independently")
end

local function test_message_prefix_keeps_literal_commas_inside_one_phrase()
    local addon = setup_env({
        db = {
            MsgPrefix = "Sending inv, can do ",
        },
        char_db = {
            RecipeLinks = {
                ["Enchant Weapon - Mongoose"] = "[Enchant Weapon - Mongoose] ",
            },
        },
    })

    local whisper = addon.BuildRecipeWhisper({
        ["Enchant Weapon - Mongoose"] = true,
    }, 1)

    assert_true(string.find(whisper, "Sending inv, can do ", 1, true) == 1, "commas inside a single prefix phrase should stay literal")
    assert_true(string.find(whisper, "can do [Enchant Weapon - Mongoose]", 1, true) ~= nil, "single-prefix commas should still keep normal link spacing")
end

local function test_parse_message_warns_for_incomplete_order()
    local addon, state = setup_env({
        db = {
            InviteTimeDelay = 0,
            WhisperTimeDelay = 0,
            MsgPrefix = "Sending inv, can do ",
            WarnIncompleteOrder = true,
        },
        char_db = {
            RecipeList = {
                ["Enchant Weapon - Mongoose"] = { "mongoose" },
                ["Enchant Boots - Boar's Speed"] = { "boar" },
                ["Enchant Cloak - Dodge"] = { "dodge" },
            },
            RecipeLinks = {
                ["Enchant Weapon - Mongoose"] = "[Enchant Weapon - Mongoose] ",
                ["Enchant Boots - Boar's Speed"] = "[Enchant Boots - Boar's Speed] ",
                ["Enchant Cloak - Dodge"] = "[Enchant Cloak - Dodge] ",
            },
        },
    })

    addon.RefreshCompiledData()
    addon.ParseMessage("LF mongoose boar dodge savagery pst", "Buyer-Incomplete")

    assert_equal(#state.invites, 1, "incomplete orders should still invite by default")
    assert_equal(#state.whispers, 1, "incomplete orders should still whisper by default")
    assert_true(string.find(state.whispers[1].message, "Sending inv, can do 3/4 ", 1, true) ~= nil, "whisper should include the matched/requested recipe count when incomplete warnings are enabled")
    assert_true(string.find(state.whispers[1].message, "%[Enchant Weapon %- Mongoose%]") ~= nil, "incomplete-order whisper should still include recipe links")
end

local function test_parse_message_skips_incomplete_warning_when_disabled()
    local addon, state = setup_env({
        db = {
            InviteTimeDelay = 0,
            WhisperTimeDelay = 0,
            MsgPrefix = "Sending inv, can do ",
            WarnIncompleteOrder = false,
        },
        char_db = {
            RecipeList = {
                ["Enchant Weapon - Mongoose"] = { "mongoose" },
                ["Enchant Boots - Boar's Speed"] = { "boar" },
            },
            RecipeLinks = {
                ["Enchant Weapon - Mongoose"] = "[Enchant Weapon - Mongoose] ",
                ["Enchant Boots - Boar's Speed"] = "[Enchant Boots - Boar's Speed] ",
            },
        },
    })

    addon.RefreshCompiledData()
    addon.ParseMessage("LF mongoose boar savagery pst", "Buyer-NoWarn")

    assert_equal(#state.whispers, 1, "incomplete orders should still whisper when only the warning text is disabled")
    assert_true(string.find(state.whispers[1].message, "2/3", 1, true) == nil, "whisper should omit the matched/requested count when incomplete warnings are disabled")
end

local function test_incomplete_order_can_be_left_unflagged_until_corrected()
    local addon, state = setup_env({
        db = {
            InviteTimeDelay = 0,
            WhisperTimeDelay = 0,
            MsgPrefix = "Sending inv, can do ",
            WarnIncompleteOrder = true,
            InviteIncompleteOrder = false,
        },
        char_db = {
            RecipeList = {
                ["Enchant Weapon - Mongoose"] = { "mongoose" },
            },
            RecipeLinks = {
                ["Enchant Weapon - Mongoose"] = "[Enchant Weapon - Mongoose] ",
            },
        },
    })

    addon.RefreshCompiledData()
    addon.ParseMessage("LF mongoose savagery pst", "Buyer-Hold")

    local order = addon.Workbench.GetOrderByCustomer("Buyer-Hold")

    assert_equal(#state.invites, 0, "incomplete orders should skip auto-invite when the option is disabled")
    assert_equal(#state.whispers, 0, "incomplete orders should skip auto-whisper when the option is disabled")
    assert_nil(addon.PlayerList["Buyer-Hold"], "skipped incomplete orders should not trip the anti-spam player gate")
    assert_not_nil(order, "incomplete orders should still be added to the workbench queue")
    assert_equal(order.RequestedRecipeCount, 2, "workbench should remember the full requested recipe count for manual follow-up")
    assert_equal(#addon.Workbench.EnsureState().Orders, 1, "repeated incomplete requests should still reuse the same queued order")

    addon.Workbench.WhisperOrder(order.Id)

    assert_equal(#state.whispers, 1, "manual workbench whisper should still be available for incomplete orders")
    assert_true(string.find(state.whispers[1].message, "1/2", 1, true) ~= nil, "manual workbench whisper should include the incomplete-order warning")

    addon.ParseMessage("LF mongoose pst", "Buyer-Hold")

    order = addon.Workbench.GetOrderByCustomer("Buyer-Hold")

    assert_equal(#state.invites, 1, "a later corrected request should invite once the order is complete")
    assert_equal(#state.whispers, 2, "a later corrected request should whisper once the anti-spam gate stays open")
    assert_equal(addon.PlayerList["Buyer-Hold"], 1, "completed follow-up requests should still be flagged after handling")
    assert_equal(order.RequestedRecipeCount, 1, "latest complete requests should clear the stored incomplete count when the queued recipes still match")
    assert_true(string.find(state.whispers[2].message, "1/2", 1, true) == nil, "corrected complete requests should not keep the stale incomplete warning")
end

local function test_generic_lf_enchanter_whisper()
    local addon, state = setup_env({
        db = {
            WhisperLfRequests = true,
            WhisperTimeDelay = 3,
            LfWhisperMsg = "What you looking for?",
        },
    })

    addon.RefreshCompiledData()
    addon.ParseMessage("LF Enchanter", "Buyer-Two")

    assert_equal(#state.invites, 0, "generic lf enchanter should not auto-invite without a recipe match")
    assert_equal(#state.whispers, 1, "generic lf enchanter should get a whisper when enabled")
    assert_equal(state.whispers[1].message, "What you looking for?", "generic whisper should use configured message")
    assert_equal(state.timer_delays[1], 3, "generic whisper should honor whisper delay")
end

local function test_generic_lf_enchanter_follow_up_whisper_creates_order()
    local addon, state = setup_env({
        db = {
            WhisperLfRequests = true,
            LfWhisperMsg = "What you looking for?",
        },
    })

    addon.OnLoad()
    seed_scanned_recipes(addon, {
        "Enchant Weapon - Mongoose",
        "Enchant Boots - Boar's Speed",
    })
    addon.RefreshCompiledData()
    addon.ParseMessage("LF Enchanter", "Buyer-Whisper")

    assert_not_nil(state.event_handlers["CHAT_MSG_WHISPER"], "whisper follow-up should register a chat whisper handler")
    assert_equal(#state.invites, 0, "generic lf enchanter should not invite before the follow-up whisper names a recipe")
    assert_equal(#state.whispers, 1, "generic lf enchanter should still send the configured prompt first")

    state.event_handlers["CHAT_MSG_WHISPER"]("mongoose and boar", "Buyer-Whisper")

    local order = addon.Workbench.GetOrderByCustomer("Buyer-Whisper")

    assert_not_nil(order, "follow-up whispers should open a workbench order")
    assert_equal(#order.Recipes, 2, "follow-up whispers should allow multiple recipe aliases in one private reply")
    assert_true(list_contains(order.Recipes, "Enchant Weapon - Mongoose"), "follow-up whispers should match mongoose aliases")
    assert_true(list_contains(order.Recipes, "Enchant Boots - Boar's Speed"), "follow-up whispers should match boar aliases")
    assert_equal(#state.invites, 1, "the first matched follow-up whisper should still auto-invite like a public request")
    assert_equal(state.invites[1], "Buyer-Whisper", "the first matched follow-up whisper should invite the whispering customer")
    assert_equal(#state.whispers, 2, "the first matched follow-up whisper should still send the recipe confirmation whisper")
    assert_whisper_contains_recipe(state.whispers[2].message, "Enchant Weapon - Mongoose", "follow-up recipe whisper")
    assert_whisper_contains_recipe(state.whispers[2].message, "Enchant Boots - Boar's Speed", "follow-up recipe whisper")
    assert_equal(addon.PlayerList["Buyer-Whisper"], 1, "the first matched follow-up whisper should trip the anti-spam gate")
end

local function test_generic_lf_enchanter_follow_up_whispers_update_existing_order()
    local addon, state = setup_env({
        db = {
            WhisperLfRequests = true,
            LfWhisperMsg = "What you looking for?",
        },
    })

    addon.OnLoad()
    seed_scanned_recipes(addon, {
        "Enchant Weapon - Mongoose",
        "Enchant Boots - Boar's Speed",
    })
    addon.RefreshCompiledData()
    addon.ParseMessage("LF Enchanter", "Buyer-Thread")

    state.event_handlers["CHAT_MSG_WHISPER"]("mongoose", "Buyer-Thread")
    state.event_handlers["CHAT_MSG_WHISPER"]("boar", "Buyer-Thread")

    local order = addon.Workbench.GetOrderByCustomer("Buyer-Thread")

    assert_not_nil(order, "the private follow-up thread should keep a workbench order open")
    assert_equal(#order.Recipes, 2, "later recipe-only whispers should keep extending the same queued order")
    assert_true(list_contains(order.Recipes, "Enchant Weapon - Mongoose"), "the original private follow-up recipe should stay on the order")
    assert_true(list_contains(order.Recipes, "Enchant Boots - Boar's Speed"), "later private follow-up recipes should merge into the same order")
    assert_equal(#state.invites, 1, "later follow-up whispers should not send extra invites once the customer is flagged")
    assert_equal(#state.whispers, 2, "later follow-up whispers should not send extra recipe whispers once the customer is flagged")
end

local function test_workbench_tracks_and_merges_orders()
    local addon = setup_env({
        char_db = {
            RecipeList = {
                ["Enchant Weapon - Mongoose"] = { "mongoose" },
                ["Enchant Boots - Boar's Speed"] = { "boar" },
            },
            RecipeLinks = {
                ["Enchant Weapon - Mongoose"] = "[Enchant Weapon - Mongoose] ",
                ["Enchant Boots - Boar's Speed"] = "[Enchant Boots - Boar's Speed] ",
            },
            RecipeMats = {
                ["Enchant Weapon - Mongoose"] = {
                    { Name = "Large Prismatic Shard", Count = 8, Link = "item:22449" },
                    { Name = "Void Crystal", Count = 6, Link = "item:22450" },
                },
                ["Enchant Boots - Boar's Speed"] = {
                    { Name = "Large Prismatic Shard", Count = 4, Link = "item:22449" },
                    { Name = "Primal Air", Count = 8, Link = "item:22451" },
                },
            },
        },
    })

    addon.RefreshCompiledData()
    addon.ParseMessage("LF mongoose pst", "Buyer-Queue")
    addon.ParseMessage("lf boar speed now", "Buyer-Queue")

    local state = addon.Workbench.EnsureState()
    local order = addon.Workbench.GetSelectedOrder()
    local materials = addon.Workbench.GetMaterialSnapshot(order)

    assert_equal(#state.Orders, 1, "repeat customer should update the same workbench order")
    assert_equal(order.Customer, "Buyer-Queue", "workbench order should track the customer")
    assert_equal(#order.Recipes, 2, "workbench order should merge recipes across repeat messages")
    assert_equal(materials[1].Count, 12, "shared materials should aggregate counts across queued enchants")
    assert_equal(materials[2].Name, "Primal Air", "other materials should remain in the snapshot")
end

local function test_parse_message_expands_recipe_quantity_suffix_into_duplicate_order_entries()
    local addon, state = setup_env({
        db = {
            InviteTimeDelay = 0,
            WhisperTimeDelay = 0,
        },
        char_db = {
            RecipeList = {
                ["Enchant Weapon - Crusader"] = { "crusader" },
            },
            RecipeLinks = {
                ["Enchant Weapon - Crusader"] = "[Enchant Weapon - Crusader] ",
            },
            RecipeMats = {
                ["Enchant Weapon - Crusader"] = {
                    { Name = "Large Brilliant Shard", Count = 4, Link = "item:14344" },
                    { Name = "Righteous Orb", Count = 2, Link = "item:12811" },
                },
            },
        },
    })

    addon.RefreshCompiledData()
    addon.ParseMessage("LF Crusader x2 my mats will tip", "Buyer-Quantity")

    local order = addon.Workbench.GetOrderByCustomer("Buyer-Quantity")
    local materials = addon.Workbench.GetMaterialSnapshot(order)
    local _, whisperRecipeCount = string.gsub(state.whispers[1].message or "", "%[" .. escape_lua_pattern("Enchant Weapon - Crusader") .. "%]", "")

    assert_not_nil(order, "quantity-matched requests should still create a workbench order")
    assert_equal(#order.Recipes, 2, "quantity-matched requests should expand into duplicate queued recipe rows")
    assert_equal(order.Recipes[1], "Enchant Weapon - Crusader", "the first queued recipe row should keep the matched recipe name")
    assert_equal(order.Recipes[2], "Enchant Weapon - Crusader", "the second queued recipe row should keep the matched recipe name")
    assert_equal(order.RequestedRecipeCount, 2, "quantity-matched requests should track the expanded requested count")
    assert_equal(#materials, 2, "quantity-matched requests should still keep the full reagent list")
    assert_equal(materials[1].Count, 8, "shared mats should scale with the expanded recipe quantity")
    assert_equal(materials[2].Count, 4, "non-shared mats should also scale with the expanded recipe quantity")
    assert_equal(whisperRecipeCount, 2, "quantity-matched recipe whispers should repeat the linked enchant for each requested copy")
end

local function test_workbench_remove_clears_player_gate()
    local addon = setup_env({
        char_db = {
            RecipeList = {
                ["Enchant Weapon - Mongoose"] = { "mongoose" },
            },
        },
    })

    addon.RefreshCompiledData()
    addon.ParseMessage("LF mongoose pst", "Buyer-Clear")

    local order = addon.Workbench.GetSelectedOrder()
    addon.Workbench.RemoveOrder(order.Id)

    assert_nil(addon.PlayerList["Buyer-Clear"], "removing a workbench order should clear the anti-spam player gate")
    assert_equal(#addon.Workbench.EnsureState().Orders, 0, "removed orders should leave the queue")
end

local function test_mailbox_loot_queues_sender_disenchant_orders_and_pauses_chat_scanning()
    local mailed_green = {
        item_id = 1001,
        name = "Mailed Green Blade",
        link = "|cff1eff00|Hitem:1001::::::::|h[Mailed Green Blade]|h|r",
        quality = 2,
        equip_loc = "INVTYPE_WEAPON",
        bind_type = 2,
        count = 1,
    }
    local mailed_blue = {
        item_id = 1002,
        name = "Mailed Blue Wand",
        link = "|cff0070dd|Hitem:1002::::::::|h[Mailed Blue Wand]|h|r",
        quality = 3,
        equip_loc = "INVTYPE_HOLDABLE",
        bind_type = 2,
        count = 1,
    }
    local addon, state = setup_env({
        item_cache = {
            [1001] = mailed_green,
            [1002] = mailed_blue,
        },
        inbox = {
            [1] = {
                sender = "Alice",
                subject = "pls de these",
                attachments = { mailed_green },
            },
            [2] = {
                sender = "Bob",
                subject = "blue for de",
                attachments = { mailed_blue },
            },
            [3] = {
                sender = "Alice",
                subject = "one more",
                attachments = { mailed_green },
            },
        },
        bags = {
            [0] = {
                [1] = mailed_green,
                [2] = mailed_blue,
                [3] = mailed_green,
            },
        },
    })

    addon.SetChatScanningEnabled(true)
    addon.OnLoad()
    state.event_handlers["MAIL_SHOW"]()

    addon.HandlePotentialMailboxLoot(1, 1)
    state.event_handlers["MAIL_SUCCESS"]()
    addon.HandlePotentialMailboxLoot(2, 1)
    state.event_handlers["MAIL_SUCCESS"]()
    addon.HandlePotentialMailboxLoot(3, 1)
    state.event_handlers["MAIL_SUCCESS"]()

    local alice_order = addon.Workbench.GetDisenchantOrderByCustomer("Alice")
    local bob_order = addon.Workbench.GetDisenchantOrderByCustomer("Bob")

    assert_not_nil(alice_order, "mailbox loot from Alice should create a disenchant work order")
    assert_not_nil(bob_order, "mailbox loot from Bob should create a second disenchant work order")
    assert_equal(alice_order.Kind, "disenchant", "mailbox work orders should be marked as disenchant orders")
    assert_equal(#alice_order.SourceItems, 2, "repeat mailbox loot from the same sender should spool into the same work order")
    assert_equal(#bob_order.SourceItems, 1, "a different sender should get a separate mailbox work order")
    assert_true(addon.DBChar.Stop == true, "mailbox disenchant work should pause chat scanning once it starts")
end

local function test_mailbox_disenchant_tracking_records_results_and_prepares_return_mail()
    local mailed_green = {
        item_id = 1001,
        name = "Mailed Green Blade",
        link = "|cff1eff00|Hitem:1001::::::::|h[Mailed Green Blade]|h|r",
        quality = 2,
        equip_loc = "INVTYPE_WEAPON",
        bind_type = 2,
        count = 1,
    }
    local arcane_dust = {
        item_id = 2001,
        name = "Arcane Dust",
        link = "|cffffffff|Hitem:2001::::::::|h[Arcane Dust]|h|r",
        quality = 1,
        item_type = "Trade Goods",
        item_sub_type = "Enchanting",
        count = 2,
    }
    local addon, state = setup_env({
        item_cache = {
            [1001] = mailed_green,
            [2001] = arcane_dust,
        },
        inbox = {
            [1] = {
                sender = "Alice",
                subject = "pls de this",
                attachments = { mailed_green },
            },
        },
        bags = {
            [0] = {
                [1] = mailed_green,
            },
        },
    })

    addon.OnLoad()
    state.event_handlers["MAIL_SHOW"]()
    addon.HandlePotentialMailboxLoot(1, 1)
    state.event_handlers["MAIL_SUCCESS"]()

    local order = addon.Workbench.GetDisenchantOrderByCustomer("Alice")
    assert_not_nil(order, "mailbox loot should create a disenchant order before tracking bag results")
    assert_equal(order.SourceItems[1].Bag, 0, "tracked mailbox items should remember their current bag location")
    assert_equal(order.SourceItems[1].Slot, 1, "tracked mailbox items should remember their current bag slot")

    state.current_spell_name = "Disenchant"
    state.spell_is_targeting = true
    addon.HandlePotentialDisenchantTarget(0, 1)
    state.spell_is_targeting = false

    set_bag_item(state, 0, 1, nil)
    set_bag_item(state, 0, 2, arcane_dust)
    state.event_handlers["BAG_UPDATE_DELAYED"]()

    order = addon.Workbench.GetDisenchantOrderByCustomer("Alice")
    local materials = addon.Workbench.GetMaterialSnapshot(order)

    assert_equal(order.SourceItems[1].Status, "done", "disenchanting a tracked mailbox item should mark that source item as completed")
    assert_equal(#materials, 1, "disenchanting a tracked mailbox item should add the resulting mats to the order")
    assert_equal(materials[1].Key, "item:2001", "result mats should be keyed by item id for reliable return-mail tracking")
    assert_equal(materials[1].Count, 2, "result mats should preserve the full disenchant yield count")

    addon.Workbench.PrepareReturnMail(order.Id)

    assert_equal(SendMailNameEditBox.text, "Alice", "preparing return mail should fill the original sender as the recipient")
    assert_equal(SendMailSubjectEditBox.text, "Your disenchant mats", "preparing return mail should fill the default return-mail subject")
    assert_true(string.find(MailEditBox.text, "Disenchanted the greens and blues", 1, true) ~= nil, "preparing return mail should prefill the return-mail body")
    assert_equal(state.send_mail_tab, 2, "preparing return mail should switch the mailbox UI to the send tab")
    assert_equal(#state.bag_pickups, 1, "preparing return mail should try to attach tracked mats from your bags")
    assert_not_nil(state.send_mail_attachments[1], "preparing return mail should place attached mats into the send-mail attachment slots")

    state.event_handlers["MAIL_SUCCESS"]()

    assert_nil(addon.Workbench.GetDisenchantOrderByCustomer("Alice"), "successfully sending return mail should retire the mailbox disenchant work order")
end

local function test_workbench_debug_output_is_printed()
    local addon, state = setup_env({
        char_db = {
            Debug = true,
            RecipeList = {
                ["Enchant Weapon - Mongoose"] = { "mongoose" },
            },
        },
    })

    addon.RefreshCompiledData()
    addon.ParseMessage("LF mongoose pst", "Buyer-Debug")

    local found = false
    for _, line in ipairs(state.prints) do
        if string.find(line, "%[Workbench%] queued order for Buyer%-Debug") then
            found = true
            break
        end
    end

    assert_true(found, "workbench queue actions should print through debug mode")
end

local function test_workbench_frame_keeps_buttons_above_drag_header()
    local addon = setup_env()
    local opened_config_panel

    addon.Options.Open = function(panel_id)
        opened_config_panel = panel_id
    end
    addon.Workbench.Show()
    local frame = addon.Workbench.Frame
    local workbenchState = addon.Workbench.EnsureState()

    assert_not_nil(frame, "workbench frame should be created when UI helpers exist")
    assert_equal(frame.frame_strata, "DIALOG", "workbench should use dialog strata so it stays interactable")
    assert_true(frame.resizable, "workbench should allow resizing")
    assert_equal(frame.CloseButton.parent, frame.Header, "close button should live on the header so the drag region does not cover it")
    assert_equal(frame.ConfigButton.parent, frame.Header, "config button should live on the header so it stays clickable")
    assert_equal(frame.LockButton.parent, frame.Header, "lock button should live on the header so it remains clickable")
    assert_equal(frame.ClearButton.parent, frame.Header, "clear button should also live on the header so it stays clickable")
    assert_equal(frame.SoundButton.parent, frame.Header, "sound button should live on the header so it stays clickable")
    assert_equal(frame.ScanButton.parent, frame.Header, "scan/start/stop button should live on the header so it stays clickable")
    assert_equal(frame.AuctionSearchButton.parent, frame.Header, "auction search button should also live on the header so it stays clickable")
    assert_equal(frame.CloseButton.text, "X", "close button should use a stable text button on this client")
    assert_equal(frame.ConfigButton.text, "", "config control should use an icon-only state instead of a text label")
    assert_equal(frame.ConfigButton.width, 24, "config control should stay compact as an icon toggle")
    assert_equal(frame.LockButton.text, "", "lock control should use icon-only state instead of a text label")
    assert_equal(frame.LockButton.width, 24, "lock control should stay compact as an icon toggle")
    assert_equal(frame.SoundButton.text, "", "sound control should also be icon-only")
    assert_equal(frame.SoundButton.width, 24, "sound control should stay compact as an icon toggle")
    assert_equal(frame.ConfigButton.Icon.atlas, "OptionsIcon-Brown", "config control should use the Blizzard options cog atlas")
    assert_equal(frame.LockButton.Icon.texture, "Interface\\PetBattles\\PetBattle-LockIcon", "lock control should use a padlock icon texture when locked")
    assert_equal(frame.SoundButton.Icon.texture, "Interface\\Common\\VoiceChat-Speaker", "sound control should use the native speaker icon")
    assert_equal(frame.SoundButton.Muted.texture, "Interface\\Common\\VoiceChat-Muted", "sound control should show the muted overlay when alerts are off")
    assert_equal(frame.SoundButton.LoudText.text, "!", "sound control should have a separate loud marker")
    assert_true(workbenchState.Locked, "workbench should start locked by default")
    assert_true(frame.LockButton.Icon.shown, "locked state should show the closed padlock icon")
    assert_true(not frame.LockButton.UnlockedCheck.shown, "locked state should hide the unlocked check overlay")
    assert_true(frame.SoundButton.Muted.shown, "sound-off state should show the muted overlay")
    assert_true(not frame.SoundButton.SoundOn.shown, "sound-off state should hide the active sound overlay")
    assert_true(not frame.SoundButton.LoudText.shown, "sound-off state should hide the loud marker")
    assert_equal(frame.ConfigButton.point[2], frame.CloseButton, "config cog should sit immediately beside the close button")
    assert_equal(frame.LockButton.point[2], frame.ConfigButton, "lock icon should sit immediately beside the config cog")
    assert_equal(frame.SoundButton.point[2], frame.LockButton, "sound icon should sit immediately beside the lock icon")
    assert_equal(frame.ClearButton.point[2], frame.SoundButton, "clear should sit next to the icon toggles")
    assert_equal(frame.ScanButton.point[2], frame.ClearButton, "start/scan should sit next to clear")
    assert_equal(frame.AuctionSearchButton.point[2], frame.ScanButton, "auction search should sit directly to the left of scan when it is available")
    assert_true(frame.AuctionSearchButton.shown == false, "auction search should stay hidden until the AH integration is usable")
    assert_equal(frame.AuctionSearchButton.text, "Search AH", "auction search should use a clear action label")
    assert_equal(frame.QueueCountText.point[1], "BOTTOMLEFT", "queue summary should live in the footer instead of crowding the header")
    assert_equal(frame.ListChild.point[1], "TOPLEFT", "queue scroll child should be anchored so order rows render inside the scroll area")

    frame.ConfigButton.scripts["OnClick"]()

    assert_equal(opened_config_panel, 1, "config cog should open the main addon settings panel")

    frame.LockButton.scripts["OnClick"]()

    assert_true(not workbenchState.Locked, "clicking the padlock should still unlock the workbench")
    assert_equal(frame.LockButton.text, "", "unlocking should remain icon-only")
    assert_true(frame.LockButton.Icon.shown, "unlocked state should keep the native padlock visible")
    assert_true(frame.LockButton.UnlockedCheck.shown, "unlocked state should show the cleaner native check overlay")
end

local function test_workbench_title_includes_addon_version()
    local addon = setup_env()

    local frame = addon.Workbench.CreateFrame()

    assert_equal(frame.TitleText.text, "Enchanter vtest Workbench", "workbench title should include the addon version from metadata")
end

local function test_workbench_sound_button_defaults_off_and_cycles()
    local addon, state = setup_env()

    local frame = addon.Workbench.CreateFrame()
    local workbenchState = addon.Workbench.EnsureState()

    -- muted (default)
    assert_true(not workbenchState.SoundEnabled, "queue sound should default to disabled")
    assert_equal(frame.SoundButton.text, "", "header sound button should use icons instead of text")
    assert_true(frame.SoundButton.Muted.shown, "muted overlay should show when alerts are disabled")
    assert_true(not frame.SoundButton.SoundOn.shown, "speaker waves should stay hidden when alerts are disabled")
    assert_equal(#state.played_sounds, 0, "sound preview should stay idle until the toggle is enabled")

    -- muted -> normal
    frame.SoundButton.scripts["OnClick"]()
    assert_equal(workbenchState.SoundEnabled, true, "first click should advance to normal volume")
    assert_equal(frame.SoundButton.text, "", "normal sound state should remain icon-only")
    assert_true(frame.SoundButton.SoundOn.shown, "speaker waves should show when alerts are at normal volume")
    assert_true(not frame.SoundButton.Muted.shown, "muted overlay should hide when alerts are at normal volume")
    assert_true(not frame.SoundButton.LoudText.shown, "loud marker should stay hidden at normal volume")
    assert_equal(frame.SoundButton.SoundOn.vertex_color[1], 1, "normal volume speaker waves: R should be 1")
    assert_equal(frame.SoundButton.SoundOn.vertex_color[2], 1, "normal volume speaker waves: G should be 1")
    assert_equal(frame.SoundButton.SoundOn.vertex_color[3], 1, "normal volume speaker waves: B should be 1")
    assert_equal(#state.played_sounds, 1, "enabling queue sounds should play an immediate preview")
    assert_equal(state.played_sounds[1], SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON, "normal preview should use the standard Blizzard UI sound")
    assert_equal(state.played_sound_calls[1].channel, "Master", "normal preview should use the Master channel")

    -- normal -> loud
    frame.SoundButton.scripts["OnClick"]()
    assert_equal(workbenchState.SoundEnabled, "loud", "second click should advance to loud volume")
    assert_equal(frame.SoundButton.text, "", "loud sound state should remain icon-only")
    assert_true(frame.SoundButton.SoundOn.shown, "speaker waves should show when alerts are at loud volume")
    assert_true(not frame.SoundButton.Muted.shown, "muted overlay should stay hidden at loud volume")
    assert_true(frame.SoundButton.LoudText.shown, "loud marker should make loud mode visually distinct")
    assert_equal(frame.SoundButton.SoundOn.vertex_color[1], 1,    "loud volume speaker waves: R should be 1")
    assert_equal(frame.SoundButton.SoundOn.vertex_color[2], 0.76, "loud volume speaker waves: G should be 0.76")
    assert_equal(frame.SoundButton.SoundOn.vertex_color[3], 0.18, "loud volume speaker waves: B should be 0.18")
    assert_equal(#state.played_sounds, 2, "switching to loud volume should play a preview")
    assert_equal(state.played_sounds[2], SOUNDKIT.READY_CHECK, "loud preview should use a Blizzard ready-check alert")
    assert_equal(state.played_sound_calls[2].channel, "Master", "loud preview should use the Master channel")

    -- loud -> muted
    frame.SoundButton.scripts["OnClick"]()
    assert_equal(workbenchState.SoundEnabled, false, "third click should return to muted")
    assert_equal(frame.SoundButton.text, "", "muted state should remain icon-only")
    assert_true(frame.SoundButton.Muted.shown, "muted overlay should return when cycling back to muted")
    assert_true(not frame.SoundButton.SoundOn.shown, "speaker waves should hide again when muted")
    assert_true(not frame.SoundButton.LoudText.shown, "loud marker should hide again when muted")
    assert_equal(#state.played_sounds, 2, "muting should not play any extra preview")
end

local function test_workbench_sound_button_warns_when_preview_cannot_play()
    local addon, state = setup_env({
        play_sound_returns_false = true,
    })

    local frame = addon.Workbench.CreateFrame()

    frame.SoundButton.scripts["OnClick"]()

    local foundWarning = false
    for _, line in ipairs(state.prints) do
        if string.find(line, "Queue alert sound preview failed", 1, true) ~= nil then
            foundWarning = true
            break
        end
    end

    assert_true(foundWarning, "enabling queue sounds should warn when none of the preview fallbacks can actually play")
end

local function test_workbench_lock_button_survives_clients_without_text_insets()
    local addon = setup_env({
        omit_text_insets = true,
    })

    local frame = addon.Workbench.CreateFrame()
    local workbenchState = addon.Workbench.EnsureState()

    assert_not_nil(frame, "workbench frame should still load when buttons do not expose SetTextInsets")
    assert_equal(frame.LockButton.text, "", "lock control should not rely on fallback text labels when text insets are unavailable")
    assert_true(frame.LockButton.Icon.shown, "locked icon should still render without text inset support")

    frame.LockButton.scripts["OnClick"]()

    assert_true(not workbenchState.Locked, "lock toggle should still work without text inset support")
    assert_equal(frame.LockButton.text, "", "unlocking should remain icon-only without text inset support")
    assert_true(frame.LockButton.UnlockedCheck.shown, "unlocked indicator should still render without text inset support")
end

local function test_workbench_toggle_shows_a_newly_created_hidden_frame()
    local addon = setup_env()

    local state = addon.Workbench.EnsureState()
    assert_true(state.Visible == false, "workbench should start hidden by default")

    addon.Workbench.Toggle()

    local frame = addon.Workbench.Frame
    assert_not_nil(frame, "toggle should create the workbench frame on first use")
    assert_true(frame:IsShown(), "the first toggle should show the newly created workbench frame instead of immediately hiding it again")
    assert_true(state.Visible, "showing the newly created workbench should persist visible state")
end

local function test_workbench_toggle_recovers_from_a_stale_hidden_frame_state()
    local addon = setup_env()

    addon.Workbench.Show()
    local state = addon.Workbench.EnsureState()
    local frame = addon.Workbench.Frame

    frame:Hide()
    if frame.scripts["OnHide"] then
        frame.scripts["OnHide"](frame)
    end
    state.Visible = true

    addon.Workbench.Toggle()

    assert_true(frame:IsShown(), "toggle should show the workbench when the frame is actually hidden, even if saved visibility drifted stale")
    assert_true(state.Visible, "toggle should resync saved visibility with the actual frame state")
end

local function test_trade_events_register_even_when_chat_scanning_is_stopped()
    local addon, state = setup_env({
        char_db = {
            Stop = true,
        },
    })

    addon.OnLoad()

    local seen = {}
    for _, event_name in ipairs(state.events) do
        seen[event_name] = true
    end

    assert_true(seen["TRADE_SHOW"], "trade open should be registered even when chat scanning is stopped")
    assert_true(seen["TRADE_MONEY_CHANGED"], "trade money changes should be registered independently of /ec start")
    assert_true(seen["TRADE_ACCEPT_UPDATE"], "trade accept updates should be registered independently of /ec start")
    assert_true(seen["TRADE_CLOSED"], "trade close should be registered independently of /ec start")
    assert_true(seen["UI_INFO_MESSAGE"], "trade completion messages should be registered independently of /ec start")
    assert_true(seen["GROUP_ROSTER_UPDATE"], "group roster changes should be registered so grouped queue state can refresh")
    assert_true(seen["PLAYER_FLAGS_CHANGED"], "player flag changes should be registered so AFK state can auto-pause chat scanning")
end

local function test_workbench_tracks_trade_tip_using_trade_money_api_and_auto_completes_verified_trade()
    local addon, state = setup_env({
        trade_target_money = 123400,
        char_db = {
            RecipeList = {
                ["Enchant Weapon - Mongoose"] = { "mongoose" },
            },
        },
        trade_target_items = {
            [7] = { name = "Arcanite Reaper", enchantment = "Mongoose" },
        },
    })

    local frame = addon.Workbench.CreateFrame()
    addon.RefreshCompiledData()
    addon.ParseMessage("LF mongoose pst", "Buyer-Tip")

    local order = addon.Workbench.GetSelectedOrder()
    addon.Workbench.BeginTrade("Buyer-Tip")
    addon.Workbench.SetTradeAcceptState(1, 1)
    addon.Workbench.SyncActiveTrade()
    addon.Workbench.FinishTrade(0)

    local workbenchState = addon.Workbench.EnsureState()

    assert_true(order.VerifiedRecipes["Enchant Weapon - Mongoose"], "accepted trades should still verify the matching enchant before the order retires")
    assert_equal(order.LastObservedTipCopper, 123400, "accepted trades should still store the target trade money on the order before auto-completing")
    assert_nil(addon.Workbench.GetOrderById(order.Id), "accepted verified trades should retire themselves automatically")
    assert_equal(workbenchState.CompletedOrders, 1, "accepted verified trades should auto-complete the order")
    assert_equal(workbenchState.CompletedTipsCopper, 123400, "auto-completion should bank the tracked trade money immediately")
    assert_equal(#workbenchState.Orders, 0, "auto-completed verified trades should leave no queued order behind")
    assert_true(string.find(frame.QueueCountText.text or "", "1 done") ~= nil, "footer summary should show the completed count right away")
    assert_true(string.find(frame.QueueCountText.text or "", "12g 34s tips") ~= nil, "footer summary should show the tracked tip total right away")
    assert_equal(frame.Detail.Title.text, "No active order selected", "the detail pane should reset after the order auto-completes")
    assert_equal(state.trade_target_money, 123400, "trade money test should use the target trade money api path")

    frame.ClearButton.scripts["OnClick"]()

    assert_equal(workbenchState.CompletedOrders, 0, "clear should reset the running completed count")
    assert_equal(workbenchState.CompletedTipsCopper, 0, "clear should reset the running tips total")
    assert_true(string.find(frame.QueueCountText.text or "", "0 done") ~= nil, "footer summary should return to zero after clear")
end

local function test_workbench_verified_orders_auto_complete_without_a_button()
    local addon = setup_env({
        char_db = {
            RecipeList = {
                ["Enchant Weapon - Mongoose"] = { "mongoose" },
            },
        },
    })

    local frame = addon.Workbench.CreateFrame()
    addon.RefreshCompiledData()
    addon.ParseMessage("LF mongoose pst", "Buyer-NoTip")

    local order = addon.Workbench.GetSelectedOrder()
    addon.Workbench.SetRecipeVerified(order.Id, "Enchant Weapon - Mongoose", true)

    local workbenchState = addon.Workbench.EnsureState()
    assert_nil(addon.Workbench.GetOrderById(order.Id), "fully verified orders should auto-complete even without a trade")
    assert_equal(workbenchState.CompletedOrders, 1, "auto-completing a verified order should increment the completed count")
    assert_equal(workbenchState.CompletedTipsCopper, 0, "zero-tip auto-completions should not add to the running tips total")
    assert_nil(frame.Detail.NoTipButton, "untipped orders should no longer render a separate no-tip button")
    assert_true(frame.Detail.CompleteButton.shown == false, "the old Complete button should stay hidden")
    assert_equal(frame.Detail.Title.text, "No active order selected", "the detail pane should reset once the order auto-completes")
end

local function test_workbench_active_trade_hides_manual_completion_controls()
    local addon, state = setup_env({
        trade_target_money = 5000,
        char_db = {
            RecipeList = {
                ["Enchant Weapon - Mongoose"] = { "mongoose" },
            },
        },
    })

    local frame = addon.Workbench.CreateFrame()
    addon.RefreshCompiledData()
    addon.ParseMessage("LF mongoose pst", "Buyer-LiveTrade")

    addon.Workbench.BeginTrade("Buyer-LiveTrade")

    assert_equal(frame.Detail.TipStatus.text, "Tip in trade: 50s", "active trades should show the live trade gold amount")
    assert_nil(frame.Detail.NoTipButton, "active trades should no longer render a separate no-tip override")
    assert_true(frame.Detail.CompleteButton.shown == false, "the old Complete button should stay hidden during active trades")
    assert_true(string.find(frame.Detail.TradeHint.text or "", "retire themselves") ~= nil, "active trades should explain that verified orders retire automatically")
    assert_equal(state.trade_target_money, 5000, "active trade ui test should rely on the trade money api state")
end

local function test_trade_enchant_slot_requires_real_enchantment_before_auto_verify()
    local addon = setup_env({
        char_db = {
            RecipeList = {
                ["Enchant Boots - Minor Speed"] = { "minor speed" },
            },
        },
        trade_target_items = {
            [7] = { name = "Netherweave Boots" },
        },
    })

    addon.RefreshCompiledData()
    addon.ParseMessage("LF minor speed pst", "Buyer-NoEnchantYet")

    local order = addon.Workbench.GetSelectedOrder()
    addon.Workbench.BeginTrade("Buyer-NoEnchantYet")
    addon.Workbench.NoteRecipeCast("Enchant Boots - Minor Speed")
    addon.Workbench.SyncActiveTrade()
    addon.Workbench.SetTradeAcceptState(1, 1)
    addon.Workbench.FinishTrade(0)

    local verified, total = addon.Workbench.GetRecipeVerificationProgress(addon.Workbench.GetOrderById(order.Id))
    assert_equal(verified, 0, "an item merely sitting in the enchant slot should not auto-verify the recipe")
    assert_equal(total, 1, "the order should still track the single requested recipe")
end

local function test_trade_completion_message_falls_back_to_recorded_cast_when_enchant_text_never_appears()
    local addon = setup_env({
        char_db = {
            RecipeList = {
                ["Enchant Boots - Minor Speed"] = { "minor speed" },
            },
        },
        trade_target_items = {
            [7] = { name = "Netherweave Boots" },
        },
    })

    addon.RefreshCompiledData()
    addon.ParseMessage("LF minor speed pst", "Buyer-CompletionFallback")

    local order = addon.Workbench.GetSelectedOrder()
    addon.Workbench.BeginTrade("Buyer-CompletionFallback")
    addon.Workbench.NoteRecipeCast("Enchant Boots - Minor Speed")
    addon.Workbench.SyncActiveTrade()
    addon.Workbench.SetTradeAcceptState(1, 1)
    addon.Workbench.MarkTradeCompleted()
    addon.Workbench.FinishTrade(0)

    local workbenchState = addon.Workbench.EnsureState()
    assert_true(order.VerifiedRecipes["Enchant Boots - Minor Speed"], "the completion signal should trust the recorded cast when the trade slot never exposes enchant text")
    assert_equal(workbenchState.CompletedOrders, 1, "completion-signal fallback should still auto-complete the finished order")
    assert_nil(addon.Workbench.GetOrderById(order.Id), "completion-signal fallback should retire the finished order")
end

local function test_workbench_accepted_trade_commits_progress_and_auto_completes_zero_tip_order()
    local addon = setup_env({
        char_db = {
            RecipeList = {
                ["Enchant Boots - Minor Speed"] = { "minor speed" },
            },
            RecipeMats = {
                ["Enchant Boots - Minor Speed"] = {
                    { Name = "Soul Dust", Count = 6, Link = "item:11083" },
                    { Name = "Lesser Nether Essence", Count = 1, Link = "item:11174" },
                },
            },
        },
        trade_target_items = {
            [1] = { name = "Soul Dust", count = 6, link = "item:11083" },
            [2] = { name = "Lesser Nether Essence", count = 1, link = "item:11174" },
            [7] = { name = "Enchant Boots - Minor Speed", enchantment = "Minor Speed" },
        },
    })

    local frame = addon.Workbench.CreateFrame()
    addon.RefreshCompiledData()
    addon.ParseMessage("LF minor speed pst", "Buyer-Auto")

    local order = addon.Workbench.GetSelectedOrder()
    addon.Workbench.BeginTrade("Buyer-Auto")
    addon.Workbench.NoteRecipeCast("Enchant Boots - Minor Speed")
    addon.Workbench.SyncActiveTrade()
    addon.Workbench.SetTradeAcceptState(1, 1)
    addon.Workbench.FinishTrade(0)

    local state = addon.Workbench.EnsureState()

    assert_true(order.VerifiedRecipes["Enchant Boots - Minor Speed"], "accepted trades should still auto-verify the applied recipe before the order retires")
    assert_equal(order.MaterialCounts["item:11083"], 6, "accepted trades should still carry the matching Soul Dust forward into the order before auto-completing")
    assert_equal(order.MaterialCounts["item:11174"], 1, "accepted trades should still carry the matching essence forward into the order before auto-completing")
    assert_nil(frame.Detail.NoTipButton, "after a zero-tip trade there should still be no separate no-tip button")
    assert_true(frame.Detail.CompleteButton.shown == false, "the old Complete button should stay hidden after a zero-tip trade")
    assert_equal(state.CompletedOrders, 1, "accepted zero-tip trades should auto-complete the order")
    assert_equal(state.CompletedTipsCopper, 0, "accepted zero-tip trades should bank zero tip immediately")
    assert_nil(addon.Workbench.GetOrderById(order.Id), "auto-completing zero-tip trades should remove the finished order")
end

local function test_workbench_persists_trade_progress_after_accept_flags_reset_during_close()
    local addon = setup_env({
        char_db = {
            RecipeList = {
                ["Enchant Boots - Minor Speed"] = { "minor speed" },
            },
            RecipeMats = {
                ["Enchant Boots - Minor Speed"] = {
                    { Name = "Soul Dust", Count = 6, Link = "item:11083" },
                    { Name = "Lesser Nether Essence", Count = 1, Link = "item:11174" },
                },
            },
        },
        trade_target_items = {
            [1] = { name = "Soul Dust", count = 6, link = "item:11083" },
            [2] = { name = "Lesser Nether Essence", count = 1, link = "item:11174" },
            [7] = { name = "Netherweave Boots", enchantment = "Minor Speed" },
        },
    })

    addon.RefreshCompiledData()
    addon.ParseMessage("LF minor speed pst", "Buyer-AcceptReset")

    local order = addon.Workbench.GetSelectedOrder()
    addon.Workbench.BeginTrade("Buyer-AcceptReset")
    addon.Workbench.SyncActiveTrade()
    addon.Workbench.SetTradeAcceptState(1, 1)
    addon.Workbench.SetTradeAcceptState(0, 0)
    addon.Workbench.FinishTrade(0)

    local workbenchState = addon.Workbench.EnsureState()

    assert_equal(order.MaterialCounts["item:11083"], 6, "a successful trade should keep received mats recorded even if the client clears accept flags before close")
    assert_equal(order.MaterialCounts["item:11174"], 1, "material totals should stay intact after the close-time accept reset")
    assert_true(order.VerifiedRecipes["Enchant Boots - Minor Speed"], "a detected in-trade enchant should still persist when accept flags reset during the close sequence")
    assert_equal(workbenchState.CompletedOrders, 1, "a fully verified trade should still auto-complete after the close-time accept reset")
    assert_nil(addon.Workbench.GetOrderById(order.Id), "auto-completed trades should leave no queued order behind after the accept reset")
end

local function test_workbench_trade_completion_message_captures_final_enchant_without_extra_trade_sync()
    local addon, state = setup_env({
        char_db = {
            RecipeList = {
                ["Enchant Boots - Minor Speed"] = { "minor speed" },
            },
        },
        trade_target_items = {
            [7] = { name = "Netherweave Boots" },
        },
    })

    addon.RefreshCompiledData()
    addon.ParseMessage("LF minor speed pst", "Buyer-LateEnchant")

    local order = addon.Workbench.GetSelectedOrder()
    addon.Workbench.BeginTrade("Buyer-LateEnchant")
    addon.Workbench.NoteRecipeCast("Enchant Boots - Minor Speed")
    addon.Workbench.SyncActiveTrade()
    addon.Workbench.SetTradeAcceptState(1, 1)
    state.trade_target_items = {
        [7] = { name = "Netherweave Boots", enchantment = "Minor Speed" },
    }

    addon.Workbench.MarkTradeCompleted()
    addon.Workbench.FinishTrade(0)

    local workbenchState = addon.Workbench.EnsureState()
    assert_true(order.VerifiedRecipes["Enchant Boots - Minor Speed"], "trade completion should capture a final enchant that only appears when the completion message fires")
    assert_equal(workbenchState.CompletedOrders, 1, "late completion-message verification should still auto-complete the finished order")
    assert_nil(addon.Workbench.GetOrderById(order.Id), "late completion-message verification should retire the finished order")
end

local function test_workbench_verified_orders_auto_complete_on_the_next_successful_trade()
    local addon, state = setup_env({
        trade_target_money = 5000,
        char_db = {
            Workbench = {
                Orders = {
                    {
                        Id = 7,
                        Customer = "Buyer-MultiTip",
                        Recipes = { "Enchant Weapon - Mongoose" },
                        VerifiedRecipes = { ["Enchant Weapon - Mongoose"] = true },
                        Message = "LF mongoose pst",
                        CreatedAt = "1:11 PM",
                        UpdatedAt = "1:11 PM",
                    },
                },
                SelectedOrderId = 7,
                NextOrderId = 8,
                Locked = true,
                Visible = false,
                Position = { Point = "CENTER", RelativePoint = "CENTER", X = 0, Y = 0 },
                Size = { Width = 468, Height = 520 },
            },
        },
    })

    local frame = addon.Workbench.CreateFrame()
    local order = addon.Workbench.GetSelectedOrder()

    addon.Workbench.BeginTrade("Buyer-MultiTip")
    addon.Workbench.SetTradeAcceptState(1, 1)
    addon.Workbench.FinishTrade(0)

    local workbenchState = addon.Workbench.EnsureState()

    assert_equal(order.LastObservedTipCopper, 5000, "a later successful tip trade should still be recorded before a legacy verified order retires")
    assert_equal(workbenchState.CompletedOrders, 1, "already-verified orders should auto-complete on their next successful trade")
    assert_equal(workbenchState.CompletedTipsCopper, 5000, "auto-completion should bank the first successful tip trade immediately")
    assert_nil(addon.Workbench.GetOrderByCustomer("Buyer-MultiTip"), "auto-completed verified orders should not stay queued for later tips")
    assert_equal(frame.Detail.Title.text, "No active order selected", "the detail pane should reset after a verified order auto-completes")
end

local function test_workbench_accumulates_trade_tip_before_the_final_successful_trade()
    local addon, state = setup_env({
        trade_target_money = 5000,
        char_db = {
            RecipeList = {
                ["Enchant Weapon - Mongoose"] = { "mongoose" },
            },
        },
    })

    addon.RefreshCompiledData()
    addon.ParseMessage("LF mongoose pst", "Buyer-SplitTip")

    local order = addon.Workbench.GetSelectedOrder()
    addon.Workbench.BeginTrade("Buyer-SplitTip")
    addon.Workbench.SetTradeAcceptState(1, 1)
    addon.Workbench.FinishTrade(0)

    order = addon.Workbench.GetSelectedOrder()
    assert_not_nil(order, "orders without a finished enchant should stay queued after an earlier tip trade")
    assert_equal(order.LastObservedTipCopper, 5000, "trade tips should accumulate on the order even before the final trade finishes the work")

    state.trade_target_money = 0
    state.trade_target_items = {
        [7] = { name = "Arcanite Reaper", enchantment = "Mongoose" },
    }
    addon.Workbench.BeginTrade("Buyer-SplitTip")
    addon.Workbench.SyncActiveTrade()
    addon.Workbench.SetTradeAcceptState(1, 1)
    addon.Workbench.FinishTrade(0)

    local workbenchState = addon.Workbench.EnsureState()
    assert_true(order.VerifiedRecipes["Enchant Weapon - Mongoose"], "the later accepted trade should still verify the requested enchant before the order retires")
    assert_equal(order.LastObservedTipCopper, 5000, "the earlier tip should stay attached to the order after the later accepted trade")
    assert_equal(workbenchState.CompletedOrders, 1, "the later accepted trade should auto-complete the already-paid order")
    assert_equal(workbenchState.CompletedTipsCopper, 5000, "auto-completion should still count the earlier split tip total")
    assert_nil(addon.Workbench.GetOrderById(order.Id), "auto-completing the final verified trade should remove the order from the queue")
end

local function test_workbench_accumulates_split_material_counts_across_accepted_trades()
    local addon, state = setup_env({
        char_db = {
            RecipeList = {
                ["Enchant Boots - Minor Speed"] = { "minor speed" },
                ["Enchant Cloak - Greater Agility"] = { "greater agility" },
            },
            RecipeMats = {
                ["Enchant Boots - Minor Speed"] = {
                    { Name = "Soul Dust", Count = 6, Link = "item:11083" },
                },
                ["Enchant Cloak - Greater Agility"] = {
                    { Name = "Soul Dust", Count = 6, Link = "item:11083" },
                },
            },
        },
        trade_target_items = {
            [1] = { name = "Soul Dust", count = 6, link = "item:11083" },
        },
    })

    addon.RefreshCompiledData()
    addon.Workbench.AddOrUpdateOrder("Buyer-SplitMats", "LF minor speed + greater agility", {
        ["Enchant Boots - Minor Speed"] = true,
        ["Enchant Cloak - Greater Agility"] = true,
    })

    local order = addon.Workbench.GetSelectedOrder()
    addon.Workbench.BeginTrade("Buyer-SplitMats")
    addon.Workbench.SetTradeAcceptState(1, 1)
    addon.Workbench.FinishTrade(0)

    order = addon.Workbench.GetSelectedOrder()
    local checked, total = addon.Workbench.GetMaterialProgress(order)
    assert_equal(order.MaterialCounts["item:11083"], 6, "the first accepted trade should persist the partial material count")
    assert_equal(checked, 0, "a partial material handoff should not mark the aggregated material row complete yet")
    assert_equal(total, 1, "aggregated material progress should still treat the shared reagent as one row")

    state.trade_target_items = {
        [1] = { name = "Soul Dust", count = 6, link = "item:11083" },
    }
    addon.Workbench.BeginTrade("Buyer-SplitMats")
    addon.Workbench.SetTradeAcceptState(1, 1)
    addon.Workbench.FinishTrade(0)

    order = addon.Workbench.GetSelectedOrder()
    checked, total = addon.Workbench.GetMaterialProgress(order)
    assert_equal(order.MaterialCounts["item:11083"], 12, "accepted trades should accumulate partial reagent counts across multiple handoffs")
    assert_equal(checked, 1, "once the accumulated count reaches the required total the material row should complete")
    assert_equal(total, 1, "the aggregated material row count should stay stable across repeated handoffs")
end

local function test_workbench_keeps_last_accepted_trade_material_snapshot_when_trade_slots_clear_before_close()
    local addon, state = setup_env({
        char_db = {
            RecipeList = {
                ["Enchant Boots - Minor Speed"] = { "minor speed" },
            },
            RecipeMats = {
                ["Enchant Boots - Minor Speed"] = {
                    { Name = "Soul Dust", Count = 6, Link = "item:11083" },
                    { Name = "Lesser Nether Essence", Count = 1, Link = "item:11174" },
                },
            },
        },
        trade_target_items = {
            [1] = { name = "Soul Dust", count = 6, link = "item:11083" },
            [2] = { name = "Lesser Nether Essence", count = 1, link = "item:11174" },
        },
    })

    addon.RefreshCompiledData()
    addon.ParseMessage("LF minor speed pst", "Buyer-ClearedTrade")

    local order = addon.Workbench.GetSelectedOrder()
    addon.Workbench.BeginTrade("Buyer-ClearedTrade")
    addon.Workbench.SetTradeAcceptState(1, 1)
    addon.Workbench.SyncActiveTrade()

    state.trade_target_items = {}
    addon.Workbench.SyncActiveTrade()
    addon.Workbench.MarkTradeCompleted()
    addon.Workbench.FinishTrade(0)

    order = addon.Workbench.GetOrderById(order.Id)
    local checked, total = addon.Workbench.GetMaterialProgress(order)

    assert_equal(order.MaterialCounts["item:11083"], 6, "accepted trades should keep the last settled Soul Dust count even if the live trade slots clear before close")
    assert_equal(order.MaterialCounts["item:11174"], 1, "accepted trades should keep the last settled essence count even if the live trade slots clear before close")
    assert_equal(checked, 2, "trade-close persistence should still mark both queued mats complete after the slots clear")
    assert_equal(total, 2, "trade-close persistence should keep the original material total")
end

local function test_workbench_late_completion_signal_preserves_split_trade_progress_during_followup_trade()
    local addon, state = setup_env({
        trade_target_money = 5000,
        char_db = {
            RecipeList = {
                ["Enchant Boots - Minor Speed"] = { "minor speed" },
            },
            RecipeMats = {
                ["Enchant Boots - Minor Speed"] = {
                    { Name = "Soul Dust", Count = 6, Link = "item:11083" },
                    { Name = "Lesser Nether Essence", Count = 1, Link = "item:11174" },
                },
            },
        },
        trade_target_items = {
            [1] = { name = "Soul Dust", count = 6, link = "item:11083" },
            [2] = { name = "Lesser Nether Essence", count = 1, link = "item:11174" },
        },
    })

    local frame = addon.Workbench.CreateFrame()
    addon.RefreshCompiledData()
    addon.ParseMessage("LF minor speed pst", "Buyer-LateSplit")

    local order = addon.Workbench.GetSelectedOrder()
    addon.Workbench.BeginTrade("Buyer-LateSplit")
    addon.Workbench.SyncActiveTrade()
    addon.Workbench.FinishTrade(0)

    state.trade_target_money = 0
    state.trade_target_items = {
        [7] = { name = "Netherweave Boots" },
    }
    addon.Workbench.BeginTrade("Buyer-LateSplit")
    addon.Workbench.MarkTradeCompleted()

    order = addon.Workbench.GetOrderById(order.Id)
    local checked, total = addon.Workbench.GetMaterialProgress(order)

    assert_equal(order.LastObservedTipCopper, 5000, "a late completion signal should still attach the earlier split-trade tip to the queued order")
    assert_equal(order.MaterialCounts["item:11083"], 6, "a late completion signal should still persist the earlier split-trade Soul Dust handoff")
    assert_equal(order.MaterialCounts["item:11174"], 1, "a late completion signal should still persist the earlier split-trade essence handoff")
    assert_equal(checked, 2, "the follow-up enchant trade should still see the earlier accepted mats as tracked")
    assert_equal(total, 2, "follow-up trade mat totals should still use the original queued snapshot")
    assert_equal(frame.Detail.TipStatus.text, "Tip: 50s", "the follow-up trade should keep showing the carried tip instead of resetting to a fresh trade watch")
    assert_true(frame.Detail.MaterialLines[1].StatusCheck.shown, "follow-up trade should keep the first carried material checked")
    assert_true(frame.Detail.MaterialLines[2].StatusCheck.shown, "follow-up trade should keep the second carried material checked")
end

local function test_workbench_header_button_scans_when_recipe_data_is_missing()
    local addon, state = setup_env({
        trade_skills = {
            {
                name = "Enchant Boots - Minor Speed",
                link = "spell:13890",
                reagents = {
                    { name = "Soul Dust", count = 6, link = "item:11083" },
                    { name = "Lesser Nether Essence", count = 1, link = "item:11174" },
                },
            },
        },
    })

    local frame = addon.Workbench.CreateFrame()

    assert_equal(frame.ScanButton.text, "Scan", "header button should prompt for a scan when recipe data is missing")

    frame.ScanButton.scripts["OnClick"]()

    assert_equal(state.last_cast, "Enchanting", "scan header button should perform a recipe scan")
    assert_true(addon.NeedsRecipeScan() == false, "successful scan should satisfy the missing-data check")
    assert_equal(frame.ScanButton.text, "Stop", "after scanning, the header button should fall back to the active scan-state toggle")
end

local function test_workbench_header_button_toggles_start_and_stop_after_scan_data_exists()
    local addon = setup_env({
        char_db = {
            Stop = false,
            RecipeList = {
                ["Enchant Boots - Minor Speed"] = { "minor speed" },
            },
            RecipeMats = {
                ["Enchant Boots - Minor Speed"] = {
                    { Name = "Soul Dust", Count = 6, Link = "item:11083" },
                },
            },
        },
    })

    local frame = addon.Workbench.CreateFrame()

    assert_equal(frame.ScanButton.text, "Stop", "header button should show Stop when chat matching is active and scan data exists")

    frame.ScanButton.scripts["OnClick"]()
    assert_true(addon.DBChar.Stop, "header stop button should pause chat matching")
    assert_equal(frame.ScanButton.text, "Start", "paused chat matching should flip the header button to Start")

    frame.ScanButton.scripts["OnClick"]()
    assert_true(addon.DBChar.Stop == false, "header start button should resume chat matching")
    assert_equal(frame.ScanButton.text, "Stop", "resumed chat matching should flip the header button back to Stop")
end

local function test_workbench_header_button_does_not_get_stuck_on_scan_when_only_mats_are_missing()
    local addon = setup_env({
        char_db = {
            Stop = false,
            RecipeList = {
                ["Enchant Boots - Minor Speed"] = { "minor speed" },
            },
            RecipeMats = {},
        },
    })

    local frame = addon.Workbench.CreateFrame()

    assert_true(addon.NeedsRecipeScan() == false, "existing scanned recipes should satisfy the scan gate even if reagent snapshots are unavailable")
    assert_equal(frame.ScanButton.text, "Stop", "header button should follow chat scanning state instead of staying on Scan when only material snapshots are missing")
end

local function test_auction_search_button_only_shows_while_the_auction_house_is_open()
    local addon, state = setup_env({
        with_auctionator = true,
    })

    addon.OnLoad()
    local frame = addon.Workbench.CreateFrame()

    assert_true(frame.AuctionSearchButton.shown == false, "auction search should stay hidden until the auction house is open")

    AuctionFrame:Show()
    state.event_handlers["AUCTION_HOUSE_SHOW"]()
    assert_true(frame.AuctionSearchButton.shown, "auction search should appear as soon as the auction house opens")

    AuctionFrame:Hide()
    AuctionHouseFrame:Hide()
    state.event_handlers["AUCTION_HOUSE_CLOSED"]()
    assert_true(frame.AuctionSearchButton.shown == false, "auction search should hide again when the auction house closes")
end

local function test_auction_search_uses_formula_names_and_refreshes_live_enchanting_data()
    local addon, state = setup_env({
        with_auctionator = true,
        auction_house_open = true,
        trade_skill_frame_shown = true,
        trade_skill_line_name = "Enchanting",
        db = {
            NetherRecipes = true,
        },
        trade_skills = {
            {
                name = "Enchant Boots - Minor Speed",
                link = "spell:13890",
                reagents = {
                    { name = "Soul Dust", count = 6, link = "item:11083" },
                    { name = "Lesser Nether Essence", count = 1, link = "item:11174" },
                },
            },
        },
    })

    local frame = addon.Workbench.CreateFrame()

    assert_true(frame.AuctionSearchButton.shown, "auction search should be visible when Auctionator is loaded and the AH is open")

    frame.AuctionSearchButton.scripts["OnClick"]()

    assert_equal(state.last_cast, "Enchanting", "auction search should refresh your enchanting scan when the profession window is open")
    assert_equal(#state.auctionator_calls, 1, "auction search should hand the missing formulas to Auctionator")
    assert_equal(state.auctionator_calls[1].caller_id, "Enchanter", "auction search should identify this addon when calling Auctionator")
    assert_true(list_contains(state.auctionator_calls[1].search_terms, "Formula: Enchant Weapon - Mongoose"), "auction search should map missing recipes to their Formula item names")
    assert_true(not list_contains(state.auctionator_calls[1].search_terms, "Enchant Weapon - Mongoose"), "auction search should not pass raw enchant names to Auctionator")
    assert_true(not list_contains(state.auctionator_calls[1].search_terms, "Formula: Enchant Boots - Minor Speed"), "auction search should skip formulas you already know")
    assert_true(not list_contains(state.auctionator_calls[1].search_terms, "Formula: Enchant Boots - Surefooted"), "auction search should respect disabled recipes when building the missing-formula list")
end

local function test_auction_search_uses_saved_scan_when_the_profession_window_is_closed()
    local addon, state = setup_env({
        with_auctionator = true,
        auction_house_open = true,
        char_db = {
            RecipeList = {
                ["Enchant Boots - Minor Speed"] = { "minor speed" },
            },
        },
    })

    local frame = addon.Workbench.CreateFrame()
    frame.AuctionSearchButton.scripts["OnClick"]()

    assert_nil(state.last_cast, "auction search should not force-open enchanting when a saved scan already exists")
    assert_equal(#state.auctionator_calls, 1, "auction search should still work from the saved scan data")
    assert_true(list_contains(state.auctionator_calls[1].search_terms, "Formula: Enchant Weapon - Mongoose"), "saved-scan searches should still use formula item names")
    assert_true(not list_contains(state.auctionator_calls[1].search_terms, "Formula: Enchant Boots - Minor Speed"), "saved-scan searches should continue skipping recipes you already know")
end

local function test_auction_search_requires_a_scan_when_no_recipe_data_is_available()
    local addon, state = setup_env({
        with_auctionator = true,
        auction_house_open = true,
    })

    local frame = addon.Workbench.CreateFrame()
    frame.AuctionSearchButton.scripts["OnClick"]()

    assert_equal(#state.auctionator_calls, 0, "auction search should not call Auctionator without recipe data")

    local foundWarning = false
    for _, line in ipairs(state.prints) do
        if string.find(line, "Run /ec scan first", 1, true) ~= nil then
            foundWarning = true
            break
        end
    end

    assert_true(foundWarning, "auction search should explain how to build recipe data when no scan is available")
end

local function test_workbench_refresh_survives_without_fontstring_setshown()
    local addon = setup_env({
        omit_fontstring_setshown = true,
        char_db = {
            RecipeList = {
                ["Enchant Weapon - Mongoose"] = { "mongoose" },
            },
        },
    })

    local frame = addon.Workbench.CreateFrame()

    addon.RefreshCompiledData()
    addon.ParseMessage("LF mongoose pst", "Buyer-NoSetShown")

    assert_not_nil(frame.OrderRows[1], "queue row should still be created when font strings do not expose SetShown")
    assert_true(frame.OrderRows[1].shown, "queue row should still be shown when refresh uses the compatibility visibility helper")
    assert_equal(frame.OrderRows[1].NameText.text, "Buyer-NoSetShown", "visible queue row should match the newly queued customer")
    assert_true((frame.OrderRows[1]:GetWidth() or 0) > 0, "queue row should keep a positive width after refresh so it does not disappear")
end

local function test_workbench_detail_lines_keep_a_usable_width_after_refresh()
    local addon = setup_env({
        char_db = {
            RecipeList = {
                ["Enchant Boots - Minor Speed"] = { "minor speed" },
            },
            RecipeMats = {
                ["Enchant Boots - Minor Speed"] = {
                    { Name = "Soul Dust", Count = 6, Link = "item:11083" },
                    { Name = "Lesser Nether Essence", Count = 1, Link = "item:11174" },
                },
            },
        },
    })

    local frame = addon.Workbench.CreateFrame()
    local emptyQueueHeight = frame.ListScroll:GetHeight() or 0
    addon.RefreshCompiledData()
    addon.ParseMessage("LF minor speed pst", "Buyer-Detail")

    assert_equal(frame.Detail.Scroll.scroll_child, frame.Detail.Content, "detail pane should render through a scroll child so long orders stay inside the window")
    assert_not_nil(frame.Detail.RecipeLines[1], "detail recipe line should be created for the selected order")
    assert_not_nil(frame.Detail.MaterialLines[1], "detail material lines should be created when a mats snapshot exists")
    assert_true((frame.Detail.RecipeLines[1]:GetWidth() or 0) > 100, "detail recipe rows should keep enough width to render their text and buttons")
    assert_true((frame.Detail.MaterialLines[1]:GetWidth() or 0) > 100, "detail material rows should keep enough width to render the tracked material status")
    assert_equal(frame.Detail.MatsHeader.shown, true, "materials header should stay visible when the selected order has queued mats")
    assert_true((frame.ListScroll:GetHeight() or 0) < emptyQueueHeight, "a short queue should collapse so the detail pane gets more room")
end

local function test_workbench_resize_persists_saved_size_and_updates_layout()
    local addon = setup_env()

    local frame = addon.Workbench.CreateFrame()
    frame:SetSize(640, 720)
    frame.ResizeHandle.scripts["OnDragStop"]()

    local state = addon.Workbench.EnsureState()

    assert_equal(state.Size.Width, 640, "resizing should persist the frame width")
    assert_equal(state.Size.Height, 720, "resizing should persist the frame height")
    assert_true((frame.ListScroll:GetHeight() or 0) > 220, "queue area should grow when the frame is taller")
end

local function test_workbench_applies_elvui_skin_when_available()
    local addon = setup_env({
        elvui = true,
    })

    local frame = addon.Workbench.CreateFrame()

    assert_true(frame.elvui_frame_skinned, "main workbench frame should use the ElvUI frame template when available")
    assert_true(frame.LockButton.elvui_button_skinned, "lock button should use the ElvUI button template when available")
    assert_equal(frame.LockButton.Icon.texture, "Interface\\PetBattles\\PetBattle-LockIcon", "lock button should keep its padlock icon even when ElvUI is active")
    assert_equal(frame.ResizeHandle.normal_texture, "Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up", "resize handle should use the native size-grabber texture instead of a text button")
    assert_equal(frame.ResizeHandle.highlight_texture, "Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight", "resize handle should expose the native highlight grip texture")
    assert_equal(frame.ResizeHandle.pushed_texture, "Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down", "resize handle should expose the native pressed grip texture")
    assert_true(frame.ResizeHandle.text == nil, "resize handle should not render a Resize text label")
end

local function test_scan_selects_trade_skill_before_capturing_materials()
    local addon, state = setup_env({
        require_trade_selection_for_reagents = true,
        trade_skills = {
            {
                name = "Enchant Boots - Minor Speed",
                link = "spell:13890",
                reagents = {
                    { name = "Soul Dust", count = 6, link = "item:11083" },
                    { name = "Lesser Nether Essence", count = 1, link = "item:11174" },
                },
            },
        },
    })

    local ok = addon.GetItems()
    local materials = EnchanterDBChar.RecipeMats["Enchant Boots - Minor Speed"]

    assert_true(ok, "scan should still succeed when reagents require explicit recipe selection")
    assert_equal(state.selected_trade_skill, 1, "scan should select each trade-skill recipe before reading reagents")
    assert_not_nil(materials, "scan should store a mats snapshot for the selected recipe")
    assert_equal(#materials, 2, "scan should capture reagent data after selecting the recipe")
    assert_equal(materials[1].Name, "Soul Dust", "captured mats should include the first reagent")
end

local function test_scan_keeps_full_reagent_snapshot_when_only_one_mat_is_owned()
    local addon, state = setup_env({
        require_trade_frame_selection_for_reagents = true,
        trade_reagent_info_includes_item_id = true,
        trade_skills = {
            {
                name = "Enchant Boots - Minor Speed",
                link = "spell:13890",
                reagents = {
                    { name = "Small Radiant Shard", count = 1, player_count = 0, link = "item:11178", item_id = 11178 },
                    { name = "Aquamarine", count = 1, player_count = 1, link = "item:7909", item_id = 7909 },
                    { name = "Lesser Nether Essence", count = 1, player_count = 0, link = "item:11174", item_id = 11174 },
                },
            },
        },
    })

    local ok = addon.GetItems()
    local scannedMaterials = EnchanterDBChar.RecipeMats["Enchant Boots - Minor Speed"]

    assert_true(ok, "scan should still succeed when Anniversary-style reagent info includes item ids")
    assert_equal(state.trade_skill_frame_selection, 1, "scan should use the trade-skill frame selection helper when reagent APIs depend on it")
    assert_not_nil(scannedMaterials, "scan should store a mats snapshot for the selected recipe")
    assert_equal(#scannedMaterials, 3, "scan should keep the full reagent list even when only one reagent is currently owned")
    assert_equal(scannedMaterials[1].Count, 1, "scan should keep the required count instead of confusing it with item ids or owned counts")
    assert_equal(scannedMaterials[2].Name, "Aquamarine", "scan should preserve the owned reagent without collapsing the other missing mats")

    addon.RefreshCompiledData()
    addon.ParseMessage("LF minor speed boots", "Buyer-OwnedAqua")

    local order = addon.Workbench.GetSelectedOrder()
    local orderMaterials = addon.Workbench.GetMaterialSnapshot(order)
    local checked, total = addon.Workbench.GetMaterialProgress(order)

    assert_equal(#orderMaterials, 3, "queued orders should still show every customer-supplied reagent for the recipe")
    assert_equal(checked, 0, "owning one reagent yourself should not pre-mark any customer mat as tracked")
    assert_equal(total, 3, "material progress should reflect the full reagent count for the queued order")
end

local function test_scan_keeps_reagent_rows_when_only_the_item_link_has_a_name()
    local addon = setup_env({
        require_trade_frame_selection_for_reagents = true,
        trade_reagent_info_includes_item_id = true,
        trade_skills = {
            {
                name = "Enchant Weapon - Crusader",
                link = "spell:20034",
                reagents = {
                    { name = "Large Brilliant Shard", count = 4, player_count = 0, link = "item:14344", item_id = 14344 },
                    { name = nil, count = 2, player_count = 0, link = "|cffffffff|Hitem:12811::::::::|h[Righteous Orb]|h|r", item_id = 12811 },
                },
            },
        },
    })

    local ok = addon.GetItems()
    local scannedMaterials = EnchanterDBChar.RecipeMats["Enchant Weapon - Crusader"]

    assert_true(ok, "scan should still succeed when a reagent name falls back to the item link text")
    assert_not_nil(scannedMaterials, "scan should still save mats when only the item link carries the reagent name")
    assert_equal(#scannedMaterials, 2, "scan should keep link-backed reagents instead of dropping them from the snapshot")
    assert_equal(scannedMaterials[2].Name, "Righteous Orb", "scan should recover the reagent name from the item link text")
    assert_equal(scannedMaterials[2].Count, 2, "scan should preserve the required count for link-backed reagents")
end

local function test_scan_marks_empty_link_text_reagents_pending_until_item_data_arrives()
    local addon, state = setup_env({
        require_trade_frame_selection_for_reagents = true,
        trade_reagent_info_includes_item_id = true,
        item_cache = {
            [6037] = {
                name = "Truesilver Bar",
                link = "|cffffffff|Hitem:6037::::::::|h[Truesilver Bar]|h|r",
                cached = false,
            },
        },
        trade_skills = {
            {
                name = "Enchant Gloves - Advanced Mining",
                link = "spell:13948",
                reagents = {
                    { name = "Vision Dust", count = 3, player_count = 0, link = "item:11137", item_id = 11137 },
                    { name = nil, count = 3, player_count = 0, link = "|cffffffff|Hitem:6037::::::::|h[]|h|r", item_id = 6037 },
                },
            },
        },
    })

    local ok = addon.GetItems()
    local scannedMaterials = EnchanterDBChar.RecipeMats["Enchant Gloves - Advanced Mining"]

    assert_true(ok, "scan should still succeed when one reagent name is waiting on the item cache")
    addon.OnLoad()
    assert_not_nil(scannedMaterials, "scan should save the reagent snapshot even while one mat is unresolved")
    assert_equal(scannedMaterials[2].ItemId, 6037, "scan should preserve the reagent item id for cold-cache mats")
    assert_equal(scannedMaterials[2].Link, "item:6037", "scan should normalize empty-bracket links into a stable item key")
    assert_nil(scannedMaterials[2].Name, "scan should not commit an empty reagent name as finished data")
    assert_true(scannedMaterials[2].PendingName == true, "scan should mark the unresolved reagent so it can hydrate later")
    assert_equal(state.requested_item_data[1], 6037, "scan should request item data for unresolved reagents")

    state.item_cache[6037].cached = true
    state.event_handlers["ITEM_DATA_LOAD_RESULT"](6037, true)

    assert_equal(scannedMaterials[2].Name, "Truesilver Bar", "item data events should hydrate the stored reagent name")
    assert_true(scannedMaterials[2].PendingName == nil, "hydrated reagents should clear the pending flag")
    assert_true(string.find(scannedMaterials[2].Link or "", "%[Truesilver Bar%]") ~= nil, "hydrated reagents should replace the placeholder link text")
end

local function test_workbench_lazily_hydrates_unresolved_material_names_before_render()
    local addon, state = setup_env({
        require_trade_frame_selection_for_reagents = true,
        trade_reagent_info_includes_item_id = true,
        item_cache = {
            [6037] = {
                name = "Truesilver Bar",
                link = "|cffffffff|Hitem:6037::::::::|h[Truesilver Bar]|h|r",
                cached = false,
            },
        },
        trade_skills = {
            {
                name = "Enchant Gloves - Advanced Mining",
                link = "spell:13948",
                reagents = {
                    { name = "Vision Dust", count = 3, player_count = 0, link = "item:11137", item_id = 11137 },
                    { name = nil, count = 3, player_count = 0, link = "|cffffffff|Hitem:6037::::::::|h[]|h|r", item_id = 6037 },
                },
            },
        },
    })

    local frame = addon.Workbench.CreateFrame()
    local sawTruesilver = false
    local sawEmptyBrackets = false

    addon.GetItems()
    state.item_cache[6037].cached = true
    addon.ParseMessage("LF advanced mining gloves", "Buyer-TruesilverLazy")
    addon.Workbench.Refresh()

    local order = addon.Workbench.GetSelectedOrder()
    local materials = addon.Workbench.GetMaterialSnapshot(order)

    for _, material in ipairs(materials) do
        if material.Name == "Truesilver Bar" then
            sawTruesilver = true
        end
    end
    for _, line in ipairs(frame.Detail.MaterialLines or {}) do
        if line.Text and type(line.Text.text) == "string" and line.Text.text ~= "" then
            if string.find(line.Text.text, "Truesilver Bar", 1, true) ~= nil then
                sawTruesilver = true
            end
            if string.find(line.Text.text, "[]", 1, true) ~= nil then
                sawEmptyBrackets = true
            end
        end
    end

    assert_true(sawTruesilver, "opening the workbench should lazily hydrate newly cached reagent names before rendering")
    assert_true(not sawEmptyBrackets, "material lines should never render the empty bracket placeholder once hydration is available")
end

local function test_trade_material_progress_matches_by_item_id_when_recipe_link_text_was_unresolved()
    local addon = setup_env({
        char_db = {
            RecipeList = {
                ["Enchant Gloves - Advanced Mining"] = { "advanced mining" },
            },
            RecipeMats = {
                ["Enchant Gloves - Advanced Mining"] = {
                    { Name = "Vision Dust", Count = 3, Link = "item:11137", ItemId = 11137 },
                    { Count = 3, Link = "item:6037", ItemId = 6037, PendingName = true },
                },
            },
        },
        trade_target_items = {
            { name = "Vision Dust", count = 3, link = "|cffffffff|Hitem:11137::::::::|h[Vision Dust]|h|r", item_id = 11137 },
            { name = "Truesilver Bar", count = 3, link = "|cffffffff|Hitem:6037::::::::|h[Truesilver Bar]|h|r", item_id = 6037 },
        },
    })

    addon.RefreshCompiledData()
    addon.ParseMessage("LF advanced mining gloves", "Buyer-ItemIdTrade")
    addon.Workbench.BeginTrade("Buyer-ItemIdTrade")

    local order = addon.Workbench.GetSelectedOrder()
    local checked, total = addon.Workbench.GetTradeMaterialProgress(order)

    assert_equal(checked, 2, "live trade mats should still match unresolved recipe links by stable item id")
    assert_equal(total, 2, "item-id matching should keep the full material progress total intact")
end

local function test_scan_clears_trade_skill_filters_and_restores_them_afterward()
    local addon = setup_env({
        trade_skill_available_only = true,
        trade_skill_subclasses = { "Boots" },
        trade_skill_invslots = { "Boots" },
        trade_skill_subclass_filter = 1,
        trade_skill_invslot_filter = 1,
        trade_skill_search_text = "zzz",
        trade_skills = {
            {
                name = "Enchant Boots - Minor Speed",
                link = "spell:13890",
                num_available = 0,
                sub_class_index = 1,
                inv_slot_index = 1,
                reagents = {
                    { name = "Soul Dust", count = 6, link = "item:11083" },
                },
            },
        },
    })

    local ok = addon.GetItems()

    assert_true(ok, "scan should still succeed after temporarily clearing trade-skill filters")
    assert_not_nil(EnchanterDBChar.RecipeList["Enchant Boots - Minor Speed"], "scan should capture recipes even when filters would otherwise hide them")
    assert_true(TradeSkillFrameAvailableFilterCheckButton:GetChecked(), "trade-skill makeable filter should be restored after scanning")
    assert_equal(GetTradeSkillSubClassFilter(1), 1, "trade-skill subclass filter should be restored after scanning")
    assert_equal(GetTradeSkillInvSlotFilter(1), 1, "trade-skill inventory-slot filter should be restored after scanning")
    assert_equal(TradeSearchInputBox:GetText(), "zzz", "trade-skill search text should be restored after scanning")
end

local function test_run_recipe_scan_does_not_claim_success_when_zero_supported_recipes_are_found()
    local addon, state = setup_env({
        trade_skills = {
            {
                name = "Completely Unknown Recipe",
                link = "spell:99999",
            },
        },
    })

    local ok = addon.RunRecipeScan()

    assert_true(not ok, "scan should fail when no supported enchanting recipes were captured")
    assert_true(addon.NeedsRecipeScan(), "missing supported recipes should keep the scan-required state")

    local sawSuccess = false
    local sawFailure = false
    for _, line in ipairs(state.prints) do
        if line == "Scan Completed" then
            sawSuccess = true
        end
        if string.find(line, "Scan found no supported enchanting recipes", 1, true) ~= nil then
            sawFailure = true
        end
    end

    assert_true(not sawSuccess, "scan should not print a success message when zero supported recipes were captured")
    assert_true(sawFailure, "scan should explain why it stayed in the scan-required state")
end

local function test_workbench_timestamps_follow_clock_style()
    local addon = setup_env({
        date_impl = function(format_string)
            if format_string == "*t" then
                return {
                    hour = 13,
                    min = 11,
                }
            end
            return nil
        end,
        game_time = {
            hour = 6,
            min = 58,
        },
    })

    addon.Workbench.AddOrUpdateOrder("Buyer-Time", "LF mongoose pst", {
        ["Enchant Weapon - Mongoose"] = "mongoose",
    })

    local order = addon.Workbench.GetOrderByCustomer("Buyer-Time")

    assert_not_nil(order, "queued order should exist for timestamp checks")
    assert_equal(order.CreatedAt, "1:11 PM", "workbench timestamps should prefer the client-local clock while keeping the 12-hour style")
    assert_equal(order.UpdatedAt, "1:11 PM", "updated timestamp should match the same clock style")
end

local function test_workbench_timestamps_honor_military_and_local_clock_settings()
    local addon = setup_env({
        use_military_time = true,
        date_impl = function(format_string)
            if format_string == "*t" then
                return {
                    hour = 6,
                    min = 5,
                }
            end
            return nil
        end,
        game_time = {
            hour = 22,
            min = 44,
        },
    })

    addon.Workbench.AddOrUpdateOrder("Buyer-Local-Time", "LF mongoose pst", {
        ["Enchant Weapon - Mongoose"] = "mongoose",
    })

    local order = addon.Workbench.GetOrderByCustomer("Buyer-Local-Time")

    assert_not_nil(order, "queued order should exist for local clock checks")
    assert_equal(order.CreatedAt, "06:05", "timestamps should still honor the user's military time preference while using local time")
end

local function test_workbench_timestamps_fall_back_to_game_time_when_local_clock_is_unavailable()
    local addon = setup_env({
        disable_os_date = true,
        game_time = {
            hour = 13,
            min = 11,
        },
    })

    addon.Workbench.AddOrUpdateOrder("Buyer-Realm-Time-Fallback", "LF mongoose pst", {
        ["Enchant Weapon - Mongoose"] = "mongoose",
    })

    local order = addon.Workbench.GetOrderByCustomer("Buyer-Realm-Time-Fallback")

    assert_not_nil(order, "queued order should exist for realm-time fallback checks")
    assert_equal(order.CreatedAt, "1:11 PM", "timestamps should fall back to realm time when the client-local clock is unavailable")
end

local function test_workbench_queue_alert_only_plays_for_new_orders_when_enabled()
    local addon, state = setup_env({
        char_db = {
            Workbench = {
                SoundEnabled = true,
            },
        },
    })

    addon.Workbench.AddOrUpdateOrder("Buyer-Sound", "LF mongoose pst", {
        ["Enchant Weapon - Mongoose"] = "mongoose",
    })
    addon.Workbench.AddOrUpdateOrder("Buyer-Sound", "LF mongoose again", {
        ["Enchant Weapon - Mongoose"] = "mongoose",
        ["Enchant Boots - Minor Speed"] = "minor speed",
    })
    addon.Workbench.AddOrUpdateOrder("Buyer-Sound-Two", "LF speed pst", {
        ["Enchant Boots - Minor Speed"] = "minor speed",
    })

    assert_equal(#state.played_sounds, 2, "queue alert should only play for newly queued customers")
    assert_equal(state.played_sounds[1], SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON, "queue alert should use a Blizzard UI sound that exists on Classic and TBC clients")
    assert_equal(state.played_sounds[2], SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON, "each new queued customer should reuse the same first-choice alert sound")
    assert_equal(state.played_sound_calls[1].channel, "Master", "queue alerts should play on the Master channel so they can be heard with muted SFX")
    assert_equal(state.played_sound_calls[2].channel, "Master", "each new queue alert should keep using the Master channel")
end

local function test_workbench_queue_alert_falls_back_when_channel_argument_is_unsupported()
    local addon, state = setup_env({
        play_sound_errors_on_channel = true,
        char_db = {
            Workbench = {
                SoundEnabled = true,
            },
            RecipeList = {
                ["Enchant Weapon - Mongoose"] = { "mongoose" },
            },
        },
    })

    addon.Workbench.AddOrUpdateOrder("Buyer-Sound-Fallback", "LF mongoose pst", {
        ["Enchant Weapon - Mongoose"] = "mongoose",
    })

    assert_equal(#state.played_sounds, 1, "queue alert should still play when the client rejects explicit sound channels")
    assert_equal(state.played_sound_calls[1].channel, nil, "unsupported channel playback should retry without a channel instead of failing silently")
end

local function test_workbench_party_join_sound_mode_moves_alert_off_new_orders()
    local addon, state = setup_env({
        db = {
            PlaySoundOnPartyJoinInstead = true,
        },
        char_db = {
            Workbench = {
                SoundEnabled = true,
            },
        },
    })

    addon.Workbench.AddOrUpdateOrder("Buyer-Join", "LF mongoose pst", {
        ["Enchant Weapon - Mongoose"] = "mongoose",
    })

    assert_equal(#state.played_sounds, 0, "party-join sound mode should suppress the new-order alert")

    state.current_party_members[1] = "Buyer-Join"
    addon.Workbench.SyncGroupedOrders()

    assert_equal(#state.played_sounds, 1, "party-join sound mode should alert when the queued customer actually joins the party")
    assert_equal(state.played_sound_calls[1].channel, "Master", "party-join alerts should keep using the Master channel")

    addon.Workbench.SyncGroupedOrders()

    assert_equal(#state.played_sounds, 1, "party-join alerts should only fire once per join transition")
end

local function test_workbench_party_join_sound_mode_does_not_false_alert_for_existing_group_members()
    local addon, state = setup_env({
        db = {
            PlaySoundOnPartyJoinInstead = true,
        },
        char_db = {
            Workbench = {
                SoundEnabled = true,
            },
        },
        current_party_members = {
            "Buyer-Already",
        },
    })

    addon.Workbench.AddOrUpdateOrder("Buyer-Already", "LF speed pst", {
        ["Enchant Boots - Minor Speed"] = "minor speed",
    })
    addon.Workbench.SyncGroupedOrders()

    assert_equal(#state.played_sounds, 0, "party-join sound mode should not alert just because a newly queued customer was already in your party")
    assert_equal(#state.set_raid_target_calls, 0, "existing group members should not re-mark the player with a fresh star transition")
end

local function test_grouped_customer_join_marks_player_with_star()
    local addon, state = setup_env()

    addon.Workbench.AddOrUpdateOrder("Buyer-Star", "LF mongoose pst", {
        ["Enchant Weapon - Mongoose"] = "mongoose",
    })

    assert_equal(#state.set_raid_target_calls, 0, "queuing an order alone should not mark the player")

    state.current_party_members[1] = "Buyer-Star"
    addon.Workbench.SyncGroupedOrders()

    assert_equal(#state.set_raid_target_calls, 1, "a newly joined grouped customer should mark the player once")
    assert_equal(state.set_raid_target_calls[1].unit, "player", "the player should receive the locator marker")
    assert_equal(state.set_raid_target_calls[1].index, 1, "the locator marker should use the star icon")

    addon.Workbench.SyncGroupedOrders()

    assert_equal(#state.set_raid_target_calls, 1, "the star marker should only be applied once per join transition")
end

local function test_grouped_customer_join_auto_shows_hidden_workbench()
    local addon, state = setup_env({
        char_db = {
            RecipeList = {
                ["Enchant Weapon - Mongoose"] = { "mongoose" },
            },
            RecipeLinks = {
                ["Enchant Weapon - Mongoose"] = "[Enchant Weapon - Mongoose] ",
            },
        },
    })

    local frame = addon.Workbench.CreateFrame()
    local workbenchState = addon.Workbench.EnsureState()

    addon.RefreshCompiledData()
    addon.ParseMessage("LF mongoose pst", "Buyer-Unhide")
    addon.Workbench.Hide()

    assert_true(not frame:IsShown(), "workbench should stay hidden before the queued customer joins the group")
    assert_true(not workbenchState.Visible, "hidden workbench state should persist before the customer joins")

    state.current_party_members[1] = "Buyer-Unhide"
    addon.Workbench.SyncGroupedOrders()

    assert_true(frame:IsShown(), "a queued customer joining the group should automatically show the hidden workbench")
    assert_true(workbenchState.Visible, "auto-show should persist the visible workbench state")
end

local function test_workbench_cast_selects_trade_skill_and_uses_create_count()
    local addon, state = setup_env({
        trade_skills = {
            {
                name = "Enchant Boots - Minor Speed",
                link = "spell:13890",
            },
        },
    })

    local casted = addon.Workbench.CastRecipe("Enchant Boots - Minor Speed")

    assert_true(casted, "cast should start immediately when the trade skill recipe is already visible")
    assert_equal(state.selected_trade_skill, 1, "cast should explicitly select the matched trade skill before creating it")
    assert_equal(TradeSkillFrame.selectedSkill, 1, "cast should keep TradeSkillFrame.selectedSkill aligned with the chosen recipe")
    assert_equal(TradeSkillInputBox.value, 1, "cast should reset the trade skill repeat count to one")
    assert_equal(state.last_do_trade_skill.index, 1, "cast should create the selected trade skill")
    assert_equal(state.last_do_trade_skill.count, 1, "cast should use the Blizzard create count instead of omitting it")
end

local function test_workbench_cast_clears_trade_skill_search_and_restores_it_afterward()
    local addon, state = setup_env({
        trade_skill_search_text = "zzz",
        trade_skills = {
            {
                name = "Enchant Boots - Minor Speed",
                link = "spell:13890",
            },
        },
    })

    local casted = addon.Workbench.CastRecipe("Enchant Boots - Minor Speed")

    assert_true(casted, "cast should still start after temporarily clearing the profession search text")
    assert_equal(state.selected_trade_skill, 1, "cast should still select the matched trade skill after clearing the search text")
    assert_equal(state.last_do_trade_skill.index, 1, "cast should still create the matched trade skill after clearing the search text")
    assert_equal(TradeSearchInputBox:GetText(), "zzz", "cast should restore the previous profession search text after starting the enchant")
    assert_equal(state.trade_skill_search_text, "zzz", "cast should keep the restored search text synced with the trade-skill filter state")
end

local function test_workbench_cast_uses_legacy_craft_api_after_temporarily_clearing_filters()
    local addon, state = setup_env({
        craft_available_only = true,
        craft_filter = 1,
        craft_slots = { "INVTYPE_WEAPON" },
        crafts = {
            {
                name = "Enchant Boots - Minor Speed",
                link = "craft:13890",
                filter_index = 0,
                num_available = 0,
            },
        },
    })

    local casted = addon.Workbench.CastRecipe("Enchant Boots - Minor Speed")

    assert_true(casted, "cast should still start when only the legacy craft api exposes the recipe")
    assert_equal(state.craft_frame_selection, 1, "craft casting should use the Blizzard craft selection helper when it is available")
    assert_equal(state.last_do_craft.index, 1, "craft casting should create the selected legacy craft recipe")
    assert_equal(state.craft_filter, 1, "craft casting should restore the previous craft slot filter after casting")
    assert_true(state.craft_available_only, "craft casting should restore the previous makeable-only filter after casting")
    assert_true(CraftFrameAvailableFilterCheckButton.checked, "craft casting should keep the craft filter checkbox aligned with the restored state")
end

local function test_scan_restores_legacy_craft_filters_when_slot_list_changes()
    local addon, state = setup_env({
        craft_available_only = true,
        craft_filter = 1,
        craft_slots = { "INVTYPE_FEET" },
        craft_slots_after_clear_filter = {},
        crafts = {
            {
                name = "Enchant Boots - Minor Speed",
                link = "craft:13890",
                filter_index = 0,
                num_available = 0,
                reagents = {
                    { name = "Soul Dust", count = 6, link = "item:11083" },
                },
            },
        },
    })

    local ok = addon.GetItems()

    assert_true(ok, "scan should not fail when the legacy craft slot list disappears during filter restore")
    assert_not_nil(EnchanterDBChar.RecipeList["Enchant Boots - Minor Speed"], "scan should still capture the craft recipe after temporarily clearing filters")
    assert_equal(state.craft_filter, 0, "scan should safely fall back to the all-slots filter when the saved craft slot is no longer valid")
    assert_true(state.craft_available_only, "scan should still restore the makeable-only checkbox state")
    assert_true(CraftFrameAvailableFilterCheckButton.checked, "scan should keep the craft filter checkbox aligned after restore fallback")
end

local function test_workbench_cast_falls_back_to_all_craft_slots_when_saved_slot_becomes_invalid()
    local addon, state = setup_env({
        craft_available_only = true,
        craft_filter = 1,
        craft_slots = { "INVTYPE_WEAPON" },
        craft_slots_after_clear_filter = {},
        crafts = {
            {
                name = "Enchant Boots - Minor Speed",
                link = "craft:13890",
                filter_index = 0,
                num_available = 0,
            },
        },
    })

    local casted = addon.Workbench.CastRecipe("Enchant Boots - Minor Speed")

    assert_true(casted, "cast should still start when the legacy craft slot filter disappears before restore")
    assert_equal(state.craft_frame_selection, 1, "craft casting should still select the matched craft recipe")
    assert_equal(state.last_do_craft.index, 1, "craft casting should still execute the matched legacy craft recipe")
    assert_equal(state.craft_filter, 0, "craft casting should fall back to the all-slots filter instead of restoring an invalid slot index")
    assert_true(state.craft_available_only, "craft casting should still restore the makeable-only filter")
    assert_true(CraftFrameAvailableFilterCheckButton.checked, "craft casting should keep the craft filter checkbox aligned after fallback")
end

local function test_workbench_legacy_timestamps_are_reformatted_on_load()
    local addon = setup_env({
        char_db = {
            Workbench = {
                Orders = {
                    {
                        Id = 7,
                        Customer = "Buyer-Legacy-Time",
                        Recipes = { "Enchant Weapon - Mongoose" },
                        Message = "LF mongoose pst",
                        CreatedAt = "13:11",
                        UpdatedAt = "13:11",
                    },
                },
                SelectedOrderId = 7,
                NextOrderId = 8,
                Locked = true,
                Visible = false,
                Position = { Point = "CENTER", RelativePoint = "CENTER", X = 0, Y = 0 },
                Size = { Width = 468, Height = 520 },
            },
        },
    })

    local order = addon.Workbench.GetOrderByCustomer("Buyer-Legacy-Time")

    assert_not_nil(order, "legacy queued order should still load")
    assert_equal(order.CreatedAt, "1:11 PM", "legacy 24-hour timestamps should be reformatted to the current clock style on load")
    assert_equal(order.UpdatedAt, "1:11 PM", "legacy updated timestamps should also be reformatted on load")
end

local function test_workbench_trade_cast_keeps_order_until_verified()
    local addon = setup_env({
        char_db = {
            RecipeList = {
                ["Enchant Weapon - Mongoose"] = { "mongoose" },
            },
        },
    })

    addon.RefreshCompiledData()
    addon.ParseMessage("LF mongoose pst", "Buyer-Finish")

    local order = addon.Workbench.GetSelectedOrder()
    assert_not_nil(order, "order should exist before trade completion")

    addon.Workbench.BeginTrade("Buyer-Finish")
    addon.Workbench.NoteRecipeCast("Enchant Weapon - Mongoose")
    addon.Workbench.FinishTrade(0)

    assert_equal(#addon.Workbench.EnsureState().Orders, 1, "a cast alone should not complete the whole order")
    assert_not_nil(addon.Workbench.GetOrderByCustomer("Buyer-Finish"), "cast-only orders should stay queued until manually verified")
end

local function test_workbench_keeps_order_when_trade_has_no_completion_signal()
    local addon = setup_env({
        char_db = {
            RecipeList = {
                ["Enchant Weapon - Mongoose"] = { "mongoose" },
            },
        },
    })

    addon.RefreshCompiledData()
    addon.ParseMessage("LF mongoose pst", "Buyer-Stays")

    addon.Workbench.BeginTrade("Buyer-Stays")
    addon.Workbench.FinishTrade(0)

    assert_equal(#addon.Workbench.EnsureState().Orders, 1, "trade close without evidence should keep the order queued")
    assert_not_nil(addon.Workbench.GetOrderByCustomer("Buyer-Stays"), "the queued order should still exist")
end

local function test_workbench_manual_invite_and_whisper_actions()
    local addon, state = setup_env({
        db = {
            InviteTimeDelay = 0,
            WhisperTimeDelay = 0,
            MsgPrefix = "I can do ",
        },
        char_db = {
            RecipeList = {
                ["Enchant Weapon - Mongoose"] = { "mongoose" },
            },
            RecipeLinks = {
                ["Enchant Weapon - Mongoose"] = "[Enchant Weapon - Mongoose] ",
            },
        },
    })

    addon.RefreshCompiledData()
    addon.ParseMessage("LF mongoose pst", "Buyer-Again")

    local order = addon.Workbench.GetOrderByCustomer("Buyer-Again")
    assert_not_nil(order, "order should exist for manual resend actions")

    addon.Workbench.InviteOrder(order.Id)
    addon.Workbench.WhisperOrder(order.Id)

    assert_equal(#state.invites, 2, "manual invite should bypass the anti-spam gate and send again")
    assert_equal(state.invites[2], "Buyer-Again", "manual invite should target the queued customer")
    assert_equal(#state.whispers, 2, "manual whisper should resend the recipe message")
    assert_equal(state.whispers[2].target, "Buyer-Again", "manual whisper should target the queued customer")
    assert_true(string.find(state.whispers[2].message, "%[Enchant Weapon %- Mongoose%]") ~= nil, "manual whisper should include the matched recipe links")
end

local function test_workbench_missing_mats_whisper_action()
    local addon, state = setup_env({
        db = {
            InviteTimeDelay = 0,
            WhisperTimeDelay = 0,
        },
        char_db = {
            RecipeList = {
                ["Enchant Weapon - Mongoose"] = { "mongoose" },
            },
            RecipeLinks = {
                ["Enchant Weapon - Mongoose"] = "[Enchant Weapon - Mongoose] ",
            },
            RecipeMats = {
                ["Enchant Weapon - Mongoose"] = {
                    { Name = "Primal Fire", Count = 4 },
                    { Name = "Large Prismatic Shard", Count = 1 },
                },
            },
        },
    })

    addon.RefreshCompiledData()
    addon.ParseMessage("LF mongoose pst", "Buyer-MissingMats")

    local order = addon.Workbench.GetOrderByCustomer("Buyer-MissingMats")
    assert_not_nil(order, "order should exist before testing missing mats whisper")

    local baseCount = #state.whispers
    local sent = addon.Workbench.WhisperMissingMats(order.Id)

    assert_true(sent, "WhisperMissingMats should return true when materials are missing")
    assert_equal(#state.whispers, baseCount + 1, "WhisperMissingMats should send one whisper")
    assert_equal(state.whispers[#state.whispers].target, "Buyer-MissingMats", "missing mats whisper should target the queued customer")
    assert_true(string.find(state.whispers[#state.whispers].message, "Still need:", 1, true) ~= nil, "missing mats whisper should contain a 'Still need:' label")
    assert_true(string.find(state.whispers[#state.whispers].message, "Primal Fire", 1, true) ~= nil, "missing mats whisper should list a missing material by name")
end

local function test_workbench_missing_mats_whisper_skips_when_all_mats_present()
    local addon, state = setup_env({
        db = {
            InviteTimeDelay = 0,
            WhisperTimeDelay = 0,
        },
        char_db = {
            RecipeList = {
                ["Enchant Weapon - Mongoose"] = { "mongoose" },
            },
            RecipeLinks = {
                ["Enchant Weapon - Mongoose"] = "[Enchant Weapon - Mongoose] ",
            },
            RecipeMats = {
                ["Enchant Weapon - Mongoose"] = {
                    { Name = "Primal Fire", Count = 4 },
                },
            },
        },
    })

    addon.RefreshCompiledData()
    addon.ParseMessage("LF mongoose pst", "Buyer-AllMats")

    local order = addon.Workbench.GetOrderByCustomer("Buyer-AllMats")
    assert_not_nil(order, "order should exist before testing missing mats no-send")

    -- Record all materials as present
    order.MaterialState = order.MaterialState or {}
    local mats = addon.Workbench.GetMaterialSnapshot(order)
    for _, mat in ipairs(mats) do
        if mat.Key then
            order.MaterialState[mat.Key] = true
        end
    end

    local baseCount = #state.whispers
    local sent = addon.Workbench.WhisperMissingMats(order.Id)

    assert_true(not sent, "WhisperMissingMats should return false when all materials are present")
    assert_equal(#state.whispers, baseCount, "WhisperMissingMats should not send when nothing is missing")
end

local function test_ban_player_silences_messages()
    local addon, state = setup_env({
        db = {
            InviteTimeDelay = 0,
            WhisperTimeDelay = 0,
        },
        char_db = {
            RecipeList = {
                ["Enchant Weapon - Mongoose"] = { "mongoose" },
            },
            RecipeLinks = {
                ["Enchant Weapon - Mongoose"] = "[Enchant Weapon - Mongoose] ",
            },
        },
    })

    addon.RefreshCompiledData()

    -- Ban a player then have them request something
    addon.BanPlayer("SpammerA")
    addon.ParseMessage("LF mongoose pst", "SpammerA")

    assert_equal(#state.whispers, 0, "banned player should not trigger a whisper")
    assert_equal(#state.invites, 0, "banned player should not trigger an invite")
    assert_equal(#addon.Workbench.EnsureState().Orders, 0, "banned player should not add a queue entry")
end

local function test_ban_player_is_case_insensitive()
    local addon, state = setup_env({
        db = {
            InviteTimeDelay = 0,
            WhisperTimeDelay = 0,
        },
        char_db = {
            RecipeList = {
                ["Enchant Weapon - Mongoose"] = { "mongoose" },
            },
            RecipeLinks = {
                ["Enchant Weapon - Mongoose"] = "[Enchant Weapon - Mongoose] ",
            },
        },
    })

    addon.RefreshCompiledData()
    addon.BanPlayer("PlayerX")

    -- Message arrives with different capitalization
    addon.ParseMessage("LF mongoose pst", "playerx")

    assert_equal(#state.whispers, 0, "ban check should be case insensitive")
    assert_equal(#state.invites, 0, "ban check should be case insensitive for invites")
end

local function test_unban_player_restores_matching()
    local addon, state = setup_env({
        db = {
            InviteTimeDelay = 0,
            WhisperTimeDelay = 0,
        },
        char_db = {
            RecipeList = {
                ["Enchant Weapon - Mongoose"] = { "mongoose" },
            },
            RecipeLinks = {
                ["Enchant Weapon - Mongoose"] = "[Enchant Weapon - Mongoose] ",
            },
        },
    })

    addon.RefreshCompiledData()
    addon.BanPlayer("FriendA")
    addon.UnbanPlayer("FriendA")
    addon.ParseMessage("LF mongoose pst", "FriendA")

    assert_equal(#state.whispers, 1, "unbanned player should receive a whisper again")
    assert_equal(#state.invites, 1, "unbanned player should receive an invite again")
end

local function test_is_banned_respects_ban_and_unban()
    local addon = setup_env()

    assert_true(not addon.IsBanned("Loner"), "new player should not be banned")
    addon.BanPlayer("Loner")
    assert_true(addon.IsBanned("Loner"), "player should be banned after BanPlayer")
    addon.UnbanPlayer("Loner")
    assert_true(not addon.IsBanned("Loner"), "player should not be banned after UnbanPlayer")
end

local function test_workbench_clear_button_empties_queue_and_resets_detail()
    local addon = setup_env({
        char_db = {
            RecipeList = {
                ["Enchant Weapon - Mongoose"] = { "mongoose" },
            },
        },
    })

    local frame = addon.Workbench.CreateFrame()
    addon.RefreshCompiledData()
    addon.ParseMessage("LF mongoose pst", "Buyer-Wipe")

    frame.ClearButton.scripts["OnClick"]()

    assert_equal(#addon.Workbench.EnsureState().Orders, 0, "clear button should remove every queued order")
    assert_nil(addon.Workbench.GetSelectedOrder(), "clear button should clear the selected order")
    assert_equal(frame.Detail.Title.text, "No active order selected", "clear button should reset the stale detail pane")
end

local function test_workbench_refresh_clamps_stale_scroll_offset()
    local addon = setup_env({
        char_db = {
            RecipeList = {
                ["Enchant Weapon - Mongoose"] = { "mongoose" },
            },
        },
    })

    local frame = addon.Workbench.CreateFrame()
    frame.ListScroll:SetVerticalScroll(999)

    addon.RefreshCompiledData()
    addon.ParseMessage("LF mongoose pst", "Buyer-Scroll")

    assert_equal(frame.ListScroll:GetVerticalScroll(), 0, "refresh should clamp stale queue scroll offsets so visible rows are not scrolled into empty space")
end

local function test_grouped_follow_up_whispers_after_invite_failure()
    local addon, state = setup_env({
        db = {
            AutoInvite = true,
            GroupedFollowUp = true,
            GroupedFollowUpDelay = 4,
            GroupedFollowUpMsg = 'You were in a group, but if you still need, please whisper "inv"! Thanks.',
            InviteTimeDelay = 0,
            WhisperTimeDelay = 0,
            MsgPrefix = "I can do ",
        },
        char_db = {
            RecipeList = {
                ["Enchant Weapon - Mongoose"] = { "mongoose" },
            },
            RecipeLinks = {
                ["Enchant Weapon - Mongoose"] = "[Enchant Weapon - Mongoose] ",
            },
        },
    })

    addon.RefreshCompiledData()
    addon.ParseMessage("LF mongoose pst", "Buyer-Grouped")

    local order = addon.Workbench.GetOrderByCustomer("Buyer-Grouped")
    local handled = addon.HandleInviteFailureMessage("Buyer-Grouped is already in a group.")

    assert_true(handled, "already-grouped invite failures should be recognized")
    assert_true(order.AlreadyGrouped, "already-grouped invite failures should flag the queued order")
    assert_equal(#state.invites, 1, "initial invite should still be attempted once")
    assert_equal(#state.whispers, 2, "grouped follow-up should add a second whisper")
    assert_equal(state.whispers[2].target, "Buyer-Grouped", "grouped follow-up should target the failed invite customer")
    assert_equal(state.whispers[2].message, 'You were in a group, but if you still need, please whisper "inv"! Thanks.', "grouped follow-up should use the configured message")
    assert_equal(state.timer_delays[3], 4, "grouped follow-up should honor its own delay")
end

local function test_grouped_follow_up_is_ignored_when_disabled()
    local addon, state = setup_env({
        db = {
            AutoInvite = true,
            GroupedFollowUp = false,
            InviteTimeDelay = 0,
            WhisperTimeDelay = 0,
        },
        char_db = {
            RecipeList = {
                ["Enchant Weapon - Mongoose"] = { "mongoose" },
            },
            RecipeLinks = {
                ["Enchant Weapon - Mongoose"] = "[Enchant Weapon - Mongoose] ",
            },
        },
    })

    addon.RefreshCompiledData()
    addon.ParseMessage("LF mongoose pst", "Buyer-NoFollowUp")

    local order = addon.Workbench.GetOrderByCustomer("Buyer-NoFollowUp")
    local handled = addon.HandleInviteFailureMessage("Buyer-NoFollowUp is already in a group.")

    assert_true(handled, "already-grouped invite failures should still be tracked when the whisper follow-up is disabled")
    assert_true(order.AlreadyGrouped, "disabled follow-up should still flag the queued order as already grouped")
    assert_equal(#state.whispers, 1, "no follow-up whisper should be added when disabled")
end

local function test_grouped_queue_indicator_clears_when_customer_joins_group()
    local addon, state = setup_env({
        db = {
            AutoInvite = true,
            GroupedFollowUp = false,
            GroupedQueueExpireSeconds = 60,
            InviteTimeDelay = 0,
            WhisperTimeDelay = 0,
        },
        char_db = {
            RecipeList = {
                ["Enchant Weapon - Mongoose"] = { "mongoose" },
            },
            RecipeLinks = {
                ["Enchant Weapon - Mongoose"] = "[Enchant Weapon - Mongoose] ",
            },
        },
    })

    local frame = addon.Workbench.CreateFrame()
    addon.RefreshCompiledData()
    addon.ParseMessage("LF mongoose pst", "Buyer-Join")

    local order = addon.Workbench.GetOrderByCustomer("Buyer-Join")
    local handled = addon.HandleInviteFailureMessage("Buyer-Join is already in a group.")

    assert_true(handled, "grouped queue indicator test should recognize the invite failure")
    assert_true(order.AlreadyGrouped, "grouped queue indicator test should flag the order before the customer joins")
    assert_equal(frame.OrderRows[1].backdrop_border_color[1], 0.86, "grouped queue rows should use a red border while the customer is outside the group")
    assert_true(not frame.OrderRows[1].PartyCheck.shown, "queue rows should not show the in-group check before the customer joins")
    assert_true(not frame.Detail.GroupCheck.shown, "detail pane should not show the in-group check before the customer joins")

    state.current_party_members = { "Buyer-Join" }
    addon.Workbench.SyncGroupedOrders()

    order = addon.Workbench.GetOrderByCustomer("Buyer-Join")

    assert_true(not order.AlreadyGrouped, "joining the group should clear the already-grouped queue flag")
    assert_true(frame.OrderRows[1].backdrop_border_color[1] ~= 0.86, "joining the group should remove the red grouped border from the queue row")
    assert_true(frame.OrderRows[1].PartyCheck.shown, "queue rows should show a green check once the customer joins the group")
    assert_true(frame.Detail.GroupCheck.shown, "detail pane should show an in-group check once the customer joins the group")
    assert_true(frame.Detail.GroupText.shown, "detail pane should show the in-group label once the customer joins the group")
end

local function test_grouped_customer_limit_pauses_chat_scanning_when_customer_joins()
    local addon, state = setup_env({
        db = {
            AutoInvite = true,
            InviteTimeDelay = 0,
            WhisperTimeDelay = 0,
            MaxGroupedCustomers = 1,
        },
        char_db = {
            Stop = false,
            RecipeList = {
                ["Enchant Weapon - Mongoose"] = { "mongoose" },
            },
            RecipeLinks = {
                ["Enchant Weapon - Mongoose"] = "[Enchant Weapon - Mongoose] ",
            },
        },
    })

    local frame = addon.Workbench.CreateFrame()
    addon.RefreshCompiledData()
    addon.ParseMessage("LF mongoose pst", "Buyer-Capped")

    state.current_party_members = { "Buyer-Capped" }
    addon.Workbench.SyncGroupedOrders()
    addon.EnforceMaxGroupedCustomerLimit()

    assert_true(addon.DBChar.Stop, "joining customer cap should pause chat scanning")
    assert_true(addon.DBChar.AutoPausedForMaxGroupedCustomers, "reaching the grouped-customer cap should mark the pause as automatic")
    assert_equal(frame.ScanButton.text, "Start", "pausing at the grouped-customer cap should flip the header button back to Start")

    local foundMessage = false
    for _, line in ipairs(state.prints) do
        if string.find(line, "Paused after 1 customer joined your group (max 1).", 1, true) ~= nil then
            foundMessage = true
            break
        end
    end

    assert_true(foundMessage, "reaching the grouped-customer cap should explain why chat scanning paused")
end

local function test_grouped_customer_limit_auto_resumes_when_customer_leaves()
    local addon, state = setup_env({
        db = {
            AutoInvite = true,
            InviteTimeDelay = 0,
            WhisperTimeDelay = 0,
            MaxGroupedCustomers = 1,
        },
        char_db = {
            Stop = false,
            RecipeList = {
                ["Enchant Weapon - Mongoose"] = { "mongoose" },
            },
            RecipeLinks = {
                ["Enchant Weapon - Mongoose"] = "[Enchant Weapon - Mongoose] ",
            },
        },
    })

    local frame = addon.Workbench.CreateFrame()
    addon.RefreshCompiledData()
    addon.ParseMessage("LF mongoose pst", "Buyer-Resume")

    state.current_party_members = { "Buyer-Resume" }
    addon.Workbench.SyncGroupedOrders()
    addon.EnforceMaxGroupedCustomerLimit()

    assert_true(addon.DBChar.Stop, "hitting the grouped-customer cap should pause scanning before the leave test starts")
    assert_true(addon.DBChar.AutoPausedForMaxGroupedCustomers, "leave test should start from an auto-paused state")

    state.current_party_members = {}
    addon.Workbench.SyncGroupedOrders()
    addon.EnforceMaxGroupedCustomerLimit()

    assert_true(addon.DBChar.Stop == false, "dropping back under the grouped-customer cap should auto-resume scanning")
    assert_true(addon.DBChar.AutoPausedForMaxGroupedCustomers == false, "auto-resume should clear the grouped-customer auto-pause flag")
    assert_equal(frame.ScanButton.text, "Stop", "auto-resuming after a customer leaves should flip the header button back to Stop")

    local foundMessage = false
    for _, line in ipairs(state.prints) do
        if string.find(line, "Resumed after grouped customers dropped below max 1 (0 customers in group).", 1, true) ~= nil then
            foundMessage = true
            break
        end
    end

    assert_true(foundMessage, "dropping under the grouped-customer cap should explain why scanning resumed")
end

local function test_grouped_customer_limit_does_not_auto_resume_after_manual_stop()
    local addon, state = setup_env({
        db = {
            AutoInvite = true,
            InviteTimeDelay = 0,
            WhisperTimeDelay = 0,
            MaxGroupedCustomers = 1,
        },
        char_db = {
            Stop = false,
            RecipeList = {
                ["Enchant Weapon - Mongoose"] = { "mongoose" },
            },
            RecipeLinks = {
                ["Enchant Weapon - Mongoose"] = "[Enchant Weapon - Mongoose] ",
            },
        },
    })

    addon.RefreshCompiledData()
    addon.ParseMessage("LF mongoose pst", "Buyer-ManualStop")

    state.current_party_members = { "Buyer-ManualStop" }
    addon.Workbench.SyncGroupedOrders()
    addon.EnforceMaxGroupedCustomerLimit()

    assert_true(addon.DBChar.AutoPausedForMaxGroupedCustomers, "manual-stop test should begin from an auto-paused state")

    addon.SetChatScanningEnabled(false)

    assert_true(addon.DBChar.Stop, "manual stop should keep scanning paused")
    assert_true(addon.DBChar.AutoPausedForMaxGroupedCustomers == false, "manual stop should clear the grouped-customer auto-pause flag")

    state.current_party_members = {}
    addon.Workbench.SyncGroupedOrders()
    addon.EnforceMaxGroupedCustomerLimit()

    assert_true(addon.DBChar.Stop, "manual stop should prevent the grouped-customer cap from auto-resuming scanning later")
end

local function test_player_afk_event_auto_stops_chat_scanning()
    local addon, state = setup_env({
        char_db = {
            Stop = false,
        },
    })

    addon.OnLoad()
    state.player_afk = true
    state.event_handlers["PLAYER_FLAGS_CHANGED"]("player")

    assert_true(addon.DBChar.Stop, "going AFK should pause chat scanning while matching is active")

    local foundMessage = false
    for _, line in ipairs(state.prints) do
        if string.find(line, "Paused chat scanning because you went AFK.", 1, true) ~= nil then
            foundMessage = true
            break
        end
    end

    assert_true(foundMessage, "going AFK should explain why chat scanning paused")
end

local function test_grouped_queue_auto_expires_when_customer_never_joins()
    local addon, state = setup_env({
        defer_timers = true,
        db = {
            AutoInvite = true,
            GroupedFollowUp = false,
            GroupedQueueExpireSeconds = 30,
            InviteTimeDelay = 0,
            WhisperTimeDelay = 0,
        },
        char_db = {
            RecipeList = {
                ["Enchant Weapon - Mongoose"] = { "mongoose" },
            },
            RecipeLinks = {
                ["Enchant Weapon - Mongoose"] = "[Enchant Weapon - Mongoose] ",
            },
        },
    })

    local frame = addon.Workbench.CreateFrame()
    addon.RefreshCompiledData()
    addon.ParseMessage("LF mongoose pst", "Buyer-Expire")
    run_timer(state, 1)

    local order = addon.Workbench.GetOrderByCustomer("Buyer-Expire")
    local handled = addon.HandleInviteFailureMessage("Buyer-Expire is already in a group.")

    assert_true(handled, "grouped expiry test should recognize the invite failure")
    assert_not_nil(order, "grouped expiry test should start with a queued order")
    assert_true(state.timer_delays[3] > 30, "grouped queue expiry should schedule just after the configured seconds so the callback lands past the real deadline")
    assert_equal(#addon.Workbench.EnsureState().Orders, 1, "grouped queue expiry should keep the order queued until the timer fires")

    state.current_time = 31
    run_timer(state, 3)

    assert_equal(#addon.Workbench.EnsureState().Orders, 0, "grouped queue expiry should remove orders that never joined the group")
    assert_nil(addon.Workbench.GetOrderByCustomer("Buyer-Expire"), "expired grouped orders should disappear from the workbench")
    assert_nil(addon.PlayerList["Buyer-Expire"], "expired grouped orders should clear the anti-spam player gate")
    assert_true(frame.EmptyQueueText.shown, "expiring grouped orders should switch the open workbench back to its empty-queue state immediately")
    assert_true(string.find(frame.QueueCountText.text or "", "0 orders", 1, true) ~= nil, "expiring grouped orders should refresh the open workbench summary immediately")
end

local function test_declined_invite_order_auto_expires_when_timer_enabled()
    local addon, state = setup_env({
        defer_timers = true,
        db = {
            AutoInvite = true,
            DeclinedInviteRemovalSeconds = 45,
            InviteTimeDelay = 0,
            WhisperTimeDelay = 0,
        },
        char_db = {
            RecipeList = {
                ["Enchant Weapon - Mongoose"] = { "mongoose" },
            },
            RecipeLinks = {
                ["Enchant Weapon - Mongoose"] = "[Enchant Weapon - Mongoose] ",
            },
        },
    })

    addon.Workbench.CreateFrame()
    addon.RefreshCompiledData()
    addon.ParseMessage("LF mongoose pst", "Buyer-Declined")
    run_timer(state, 1)

    local order = addon.Workbench.GetOrderByCustomer("Buyer-Declined")
    local handled = addon.HandleInviteFailureMessage("Buyer-Declined declines your group invitation.")

    assert_true(handled, "declined group invites should be recognized")
    assert_not_nil(order, "declined invite expiry test should start with a queued order")
    assert_true(order.InviteDeclined, "declined invite expiry test should flag the order while the removal timer is active")
    assert_true(state.timer_delays[3] > 45, "declined invite removal should schedule just after the configured seconds so the callback lands past the deadline")
    assert_equal(#addon.Workbench.EnsureState().Orders, 1, "declined invite removal should leave the order queued until the timer fires")

    state.current_time = 46
    run_timer(state, 3)

    assert_equal(#addon.Workbench.EnsureState().Orders, 0, "declined invite removal should remove queued customers after the timer expires")
    assert_nil(addon.Workbench.GetOrderByCustomer("Buyer-Declined"), "declined invite removal should clear the queued order")
    assert_nil(addon.PlayerList["Buyer-Declined"], "declined invite removal should clear the anti-spam player gate")
end

local function test_manual_reinvite_clears_declined_invite_timer()
    local addon, state = setup_env({
        defer_timers = true,
        db = {
            AutoInvite = true,
            DeclinedInviteRemovalSeconds = 45,
            InviteTimeDelay = 0,
            WhisperTimeDelay = 0,
        },
        char_db = {
            RecipeList = {
                ["Enchant Weapon - Mongoose"] = { "mongoose" },
            },
            RecipeLinks = {
                ["Enchant Weapon - Mongoose"] = "[Enchant Weapon - Mongoose] ",
            },
        },
    })

    addon.RefreshCompiledData()
    addon.ParseMessage("LF mongoose pst", "Buyer-Retry")
    run_timer(state, 1)

    local order = addon.Workbench.GetOrderByCustomer("Buyer-Retry")
    local handled = addon.HandleInviteFailureMessage("Buyer-Retry declines your group invitation.")

    assert_true(handled, "manual re-invite test should recognize the declined invite")
    assert_true(order.InviteDeclined, "manual re-invite test should start from a declined order")
    assert_true(addon.Workbench.InviteOrder(order.Id), "manual re-invite should succeed for declined orders")
    assert_true(not addon.Workbench.GetOrderByCustomer("Buyer-Retry").InviteDeclined, "manual re-invite should clear the declined-removal flag before retrying")
    assert_equal(#state.invites, 2, "manual re-invite should issue a second invite attempt")

    state.current_time = 46
    run_timer(state, 3)

    assert_not_nil(addon.Workbench.GetOrderByCustomer("Buyer-Retry"), "an old declined-removal timer should not delete an order after a retry invite")
    assert_equal(#addon.Workbench.EnsureState().Orders, 1, "the order should remain queued after a retry invite clears the old timer")
end

local function test_trade_with_unmatched_partner_does_not_complete_selected_order()
    local addon = setup_env({
        char_db = {
            RecipeList = {
                ["Enchant Weapon - Mongoose"] = { "mongoose" },
            },
        },
    })

    addon.RefreshCompiledData()
    addon.ParseMessage("LF mongoose pst", "Buyer-Queued")

    addon.Workbench.BeginTrade("Completely-Other")
    addon.Workbench.NoteRecipeCast("Enchant Weapon - Mongoose")
    addon.Workbench.FinishTrade(5000)

    assert_equal(#addon.Workbench.EnsureState().Orders, 1, "an unrelated trade should not complete the selected queued order")
    assert_not_nil(addon.Workbench.GetOrderByCustomer("Buyer-Queued"), "the queued order should remain after an unrelated trade")
end

local function test_order_only_turns_verified_when_all_recipes_are_checked()
    local addon = setup_env({
        char_db = {
            RecipeList = {
                ["Enchant Weapon - Mongoose"] = { "mongoose" },
                ["Enchant Boots - Minor Speed"] = { "minor speed" },
            },
        },
    })

    local frame = addon.Workbench.CreateFrame()

    addon.RefreshCompiledData()
    addon.ParseMessage("LF mongoose and minor speed pst", "Buyer-Multi")

    local order = addon.Workbench.GetSelectedOrder()
    addon.Workbench.SetRecipeVerified(order.Id, "Enchant Weapon - Mongoose", true)

    assert_true(string.find(frame.OrderRows[1].MetaText.text or "", "1/2 verified") ~= nil, "one verified recipe should not mark a multi-enchant order as fully complete")

    addon.Workbench.SetRecipeVerified(order.Id, "Enchant Boots - Minor Speed", true)

    local state = addon.Workbench.EnsureState()
    assert_equal(state.CompletedOrders, 1, "the queue should only retire the order once every requested enchant is checked")
    assert_nil(addon.Workbench.GetOrderById(order.Id), "fully verified multi-enchant orders should auto-complete")
    assert_equal(frame.Detail.Title.text, "No active order selected", "detail meta should reset once the fully verified order retires")
end

local function test_recipe_lines_show_read_only_status_indicators()
    local addon = setup_env({
        char_db = {
            RecipeList = {
                ["Enchant Boots - Minor Speed"] = { "minor speed" },
            },
        },
    })

    local frame = addon.Workbench.CreateFrame()
    addon.RefreshCompiledData()
    addon.ParseMessage("LF minor speed pst", "Buyer-Check")

    assert_nil(frame.Detail.RecipeLines[1].VerifyCheck, "recipe rows should no longer expose a clickable verify checkbox")
    assert_equal(frame.Detail.RecipeLines[1].StatusText.text, "?", "unverified recipe rows should show a question-mark indicator")
    assert_true(frame.Detail.RecipeLines[1].StatusCheck.shown == false, "unverified recipe rows should not show the green-check texture")

    local order = addon.Workbench.GetSelectedOrder()
    addon.Workbench.SetRecipeVerified(order.Id, "Enchant Boots - Minor Speed", true)

    assert_nil(addon.Workbench.GetOrderById(order.Id), "fully verified orders should retire automatically instead of lingering with a manual complete step")
    assert_equal(frame.Detail.Title.text, "No active order selected", "the detail pane should reset after the order auto-completes")
end

local function test_workbench_auto_verifies_trade_enchant_without_apply_click()
    local addon = setup_env({
        char_db = {
            RecipeList = {
                ["Enchant Boots - Minor Speed"] = { "minor speed" },
            },
        },
        trade_target_items = {
            [7] = { name = "Netherweave Boots", enchantment = "Minor Speed" },
        },
    })

    local frame = addon.Workbench.CreateFrame()
    addon.RefreshCompiledData()
    addon.ParseMessage("LF minor speed pst", "Buyer-AutoVerify")

    addon.Workbench.BeginTrade("Buyer-AutoVerify")
    addon.Workbench.SyncActiveTrade()
    addon.Workbench.SetTradeAcceptState(1, 1)
    addon.Workbench.FinishTrade(0)

    local state = addon.Workbench.EnsureState()

    assert_equal(state.CompletedOrders, 1, "accepted trades should auto-verify and then auto-complete a matching enchant even when Apply was not clicked first")
    assert_nil(addon.Workbench.GetOrderByCustomer("Buyer-AutoVerify"), "auto-verified finished orders should retire automatically")
    assert_equal(frame.Detail.Title.text, "No active order selected", "the detail pane should reset after auto-verification retires the order")
end

local function test_workbench_tracks_duplicate_recipe_verification_one_trade_at_a_time()
    local addon = setup_env({
        char_db = {
            RecipeList = {
                ["Enchant Boots - Minor Speed"] = { "minor speed" },
            },
        },
        trade_target_items = {
            [7] = { name = "Netherweave Boots", enchantment = "Minor Speed" },
        },
    })

    addon.RefreshCompiledData()
    addon.ParseMessage("LF minor speed x2 pst", "Buyer-DoubleVerify")

    local order = addon.Workbench.GetOrderByCustomer("Buyer-DoubleVerify")

    assert_not_nil(order, "duplicate recipe requests should still queue a workbench order")
    assert_equal(#order.Recipes, 2, "duplicate recipe requests should keep both queued recipe rows")

    addon.Workbench.BeginTrade("Buyer-DoubleVerify")
    addon.Workbench.SyncActiveTrade()
    addon.Workbench.SetTradeAcceptState(1, 1)
    addon.Workbench.FinishTrade(0)

    order = addon.Workbench.GetOrderByCustomer("Buyer-DoubleVerify")
    local verifiedAfterFirstTrade, totalAfterFirstTrade = addon.Workbench.GetRecipeVerificationProgress(order)
    local state = addon.Workbench.EnsureState()

    assert_not_nil(order, "the first successful trade should leave the duplicate order queued until every copy is verified")
    assert_equal(verifiedAfterFirstTrade, 1, "the first successful trade should verify only one copy of the duplicate recipe")
    assert_equal(totalAfterFirstTrade, 2, "duplicate recipe verification should keep the full queued total")
    assert_equal(order.VerifiedRecipeCounts["Enchant Boots - Minor Speed"], 1, "duplicate recipe orders should store how many copies have already been verified")
    assert_equal(state.CompletedOrders, 0, "partially verified duplicate orders should not auto-complete early")

    addon.Workbench.BeginTrade("Buyer-DoubleVerify")
    addon.Workbench.SyncActiveTrade()
    addon.Workbench.SetTradeAcceptState(1, 1)
    addon.Workbench.FinishTrade(0)

    assert_nil(addon.Workbench.GetOrderByCustomer("Buyer-DoubleVerify"), "the duplicate order should retire once the final copy is verified")
    assert_equal(state.CompletedOrders, 1, "the final duplicate verification should auto-complete the order")
end

local function test_successful_trade_can_emote_thank_directly_to_customer()
    local addon, state = setup_env({
        db = {
            EmoteThankAfterCast = true,
        },
        char_db = {
            RecipeList = {
                ["Enchant Boots - Minor Speed"] = { "minor speed" },
            },
        },
        current_party_members = {
            "Buyer-Thanks",
        },
        trade_target_items = {
            [7] = { name = "Netherweave Boots", enchantment = "Minor Speed" },
        },
    })

    addon.RefreshCompiledData()
    addon.ParseMessage("LF minor speed pst", "Buyer-Thanks")

    addon.Workbench.BeginTrade("Buyer-Thanks")
    addon.Workbench.SyncActiveTrade()
    addon.Workbench.SetTradeAcceptState(1, 1)
    addon.Workbench.FinishTrade(0)

    assert_equal(#state.emotes, 1, "successful enchant trades should fire one thank emote when the option is enabled")
    assert_equal(state.emotes[1].token, "THANK", "successful enchant trades should use the THANK emote token directly")
    assert_equal(state.emotes[1].target, "party1", "thank emotes should prefer a live grouped unit token instead of relying on the player's target")
    assert_nil(state.current_target_name, "grouped thank emotes should not have to retarget the player")
end

local function test_successful_trade_can_thank_by_temporary_target_and_restore_previous_target()
    local addon, state = setup_env({
        db = {
            EmoteThankAfterCast = true,
        },
        char_db = {
            RecipeList = {
                ["Enchant Boots - Minor Speed"] = { "minor speed" },
            },
        },
        current_target_name = "Friendly-Priest",
        trade_target_items = {
            [7] = { name = "Netherweave Boots", enchantment = "Minor Speed" },
        },
    })

    addon.RefreshCompiledData()
    addon.ParseMessage("LF minor speed pst", "Buyer-Thanks-Target")

    addon.Workbench.BeginTrade("Buyer-Thanks-Target")
    addon.Workbench.SyncActiveTrade()
    addon.Workbench.SetTradeAcceptState(1, 1)
    addon.Workbench.FinishTrade(0)

    assert_equal(#state.emotes, 1, "successful enchant trades should still thank non-grouped customers by temporarily targeting them")
    assert_equal(state.emotes[1].token, "THANK", "temporary-target thank flow should keep using the THANK emote token")
    assert_equal(state.emotes[1].target, "target", "temporary-target thank flow should direct the emote at the resolved target token")
    assert_equal(state.current_target_name, "Friendly-Priest", "temporary thank targeting should restore the player's original target afterward")
end

local function test_tip_only_trade_does_not_emote_thank()
    local addon, state = setup_env({
        db = {
            EmoteThankAfterCast = true,
        },
        trade_target_money = 5000,
        char_db = {
            RecipeList = {
                ["Enchant Weapon - Mongoose"] = { "mongoose" },
            },
        },
    })

    addon.RefreshCompiledData()
    addon.ParseMessage("LF mongoose pst", "Buyer-NoCastThanks")

    addon.Workbench.BeginTrade("Buyer-NoCastThanks")
    addon.Workbench.SetTradeAcceptState(1, 1)
    addon.Workbench.FinishTrade(0)

    assert_equal(#state.emotes, 0, "successful tip-only trades should not emit a thank emote when no enchant was actually applied")
end

local function test_trade_detected_enchant_shows_as_checked_before_trade_closes()
    local addon = setup_env({
        char_db = {
            RecipeList = {
                ["Enchant Boots - Minor Speed"] = { "minor speed" },
            },
        },
        trade_target_items = {
            [7] = { name = "Netherweave Boots", enchantment = "Minor Speed" },
        },
    })

    local frame = addon.Workbench.CreateFrame()
    addon.RefreshCompiledData()
    addon.ParseMessage("LF minor speed pst", "Buyer-LiveEnchant")

    addon.Workbench.BeginTrade("Buyer-LiveEnchant")
    addon.Workbench.SyncActiveTrade()

    assert_true(frame.Detail.RecipeLines[1].StatusCheck.shown, "a trade-detected enchant should flip the recipe row to a green check before the trade closes")
    assert_true(frame.Detail.RecipeLines[1].StatusText.shown == false, "a trade-detected enchant should hide the question mark immediately")
    assert_true(string.find(frame.Detail.Meta.text or "", "Verified") ~= nil, "detail meta should reflect the live verified state while the trade is still open")
end

local function test_trade_offer_marks_live_material_progress()
    local addon = setup_env({
        char_db = {
            RecipeList = {
                ["Enchant Boots - Minor Speed"] = { "minor speed" },
            },
            RecipeMats = {
                ["Enchant Boots - Minor Speed"] = {
                    { Name = "Soul Dust", Count = 6, Link = "item:11083" },
                    { Name = "Lesser Nether Essence", Count = 1, Link = "item:11174" },
                },
            },
        },
        trade_target_items = {
            { name = "Soul Dust", count = 6, link = "item:11083" },
            { name = "Lesser Nether Essence", count = 1, link = "item:11174" },
        },
    })

    addon.RefreshCompiledData()
    addon.ParseMessage("LF minor speed pst", "Buyer-TradeMats")
    addon.Workbench.BeginTrade("Buyer-TradeMats")

    local order = addon.Workbench.GetSelectedOrder()
    local checked, total = addon.Workbench.GetTradeMaterialProgress(order)

    assert_equal(order.Customer, "Buyer-TradeMats", "trade open should select the matching queued order")
    assert_equal(checked, 2, "live trade offer should satisfy both queued materials")
    assert_equal(total, 2, "live trade mats progress should use the order's material total")
end

local function test_trade_sync_recovers_partner_name_after_trade_show()
    local addon = setup_env({
        char_db = {
            RecipeList = {
                ["Enchant Boots - Minor Speed"] = { "minor speed" },
            },
            RecipeMats = {
                ["Enchant Boots - Minor Speed"] = {
                    { Name = "Soul Dust", Count = 6, Link = "item:11083" },
                    { Name = "Lesser Nether Essence", Count = 1, Link = "item:11174" },
                },
            },
        },
        trade_target_items = {
            { name = "Soul Dust", count = 6, link = "item:11083" },
            { name = "Lesser Nether Essence", count = 1, link = "item:11174" },
        },
    })

    local frame = addon.Workbench.CreateFrame()
    addon.RefreshCompiledData()
    addon.ParseMessage("LF minor speed pst", "Buyer-LateTradeName")

    addon.Workbench.BeginTrade(nil)
    _G.TradeFrameRecipientNameText = {
        GetText = function()
            return "Buyer-LateTradeName"
        end,
    }
    addon.Workbench.SyncActiveTrade()

    local order = addon.Workbench.GetSelectedOrder()
    local checked, total = addon.Workbench.GetTradeMaterialProgress(order)

    assert_not_nil(order, "trade sync should recover the matching queued order once the recipient name becomes available")
    assert_equal(order.Customer, "Buyer-LateTradeName", "late trade-name recovery should select the matching queued order")
    assert_equal(checked, 2, "recovered trade partner should still enable live mats tracking")
    assert_equal(total, 2, "recovered trade partner should preserve the queued mats total")
    assert_true(frame.Detail.UseTradeButton.shown == false, "recovered trade partner should keep the manual trade-mat button hidden")
end

local function test_trade_material_helper_copies_live_offer_into_recorded_progress()
    local addon = setup_env({
        char_db = {
            RecipeList = {
                ["Enchant Boots - Minor Speed"] = { "minor speed" },
            },
            RecipeMats = {
                ["Enchant Boots - Minor Speed"] = {
                    { Name = "Soul Dust", Count = 6, Link = "item:11083" },
                    { Name = "Lesser Nether Essence", Count = 1, Link = "item:11174" },
                },
            },
        },
        trade_target_items = {
            { name = "Soul Dust", count = 6, link = "item:11083" },
            { name = "Lesser Nether Essence", count = 1, link = "item:11174" },
        },
    })

    addon.RefreshCompiledData()
    addon.ParseMessage("LF minor speed pst", "Buyer-TradeCopy")
    addon.Workbench.BeginTrade("Buyer-TradeCopy")

    local order = addon.Workbench.GetSelectedOrder()
    local copied = addon.Workbench.UseTradeMaterials(order.Id)
    local checked, total = addon.Workbench.GetMaterialProgress(order)

    assert_true(copied, "the internal trade-material helper should still be able to copy the live offer into recorded progress")
    assert_equal(checked, 2, "copied trade mats should become persisted tracked progress")
    assert_equal(total, 2, "recorded mats progress should still reflect the full material total")
end

local function test_material_lines_show_read_only_status_indicators()
    local addon = setup_env({
        char_db = {
            RecipeList = {
                ["Enchant Boots - Minor Speed"] = { "minor speed" },
            },
            RecipeMats = {
                ["Enchant Boots - Minor Speed"] = {
                    { Name = "Soul Dust", Count = 6, Link = "item:11083" },
                    { Name = "Lesser Nether Essence", Count = 1, Link = "item:11174" },
                },
            },
        },
        trade_target_items = {
            [1] = { name = "Soul Dust", count = 6, link = "item:11083" },
            [2] = { name = "Lesser Nether Essence", count = 1, link = "item:11174" },
        },
    })

    local frame = addon.Workbench.CreateFrame()
    addon.RefreshCompiledData()
    addon.ParseMessage("LF minor speed pst", "Buyer-Status")

    assert_true(frame.Detail.AllMatsButton.shown == false, "all mats should stay hidden because mat tracking is automatic")
    assert_true(frame.Detail.UseTradeButton.shown == false, "use trade should stay hidden because mat tracking is automatic")
    assert_true(frame.Detail.ClearMatsButton.shown == false, "clear mats should stay hidden because mat tracking is automatic")
    assert_equal(frame.Detail.MaterialLines[1].StatusText.text, "?", "untracked materials should show a question-mark indicator")
    assert_true(frame.Detail.MaterialLines[1].StatusCheck.shown == false, "untracked materials should not show the green-check texture")

    addon.Workbench.BeginTrade("Buyer-Status")

    assert_true(frame.Detail.MaterialLines[1].StatusCheck.shown, "fully offered trade mats should show the green-check indicator")
    assert_true(frame.Detail.MaterialLines[1].StatusText.shown == false, "fully offered trade mats should hide the question-mark indicator")
end

local function test_active_trade_updates_recipe_button_to_apply()
    local addon = setup_env({
        char_db = {
            RecipeList = {
                ["Enchant Boots - Minor Speed"] = { "minor speed" },
            },
        },
    })

    local frame = addon.Workbench.CreateFrame()
    addon.RefreshCompiledData()
    addon.ParseMessage("LF minor speed pst", "Buyer-Apply")
    addon.Workbench.BeginTrade("Buyer-Apply")

    assert_equal(frame.Detail.RecipeLines[1].CastButton.text, "Apply", "active trade recipe actions should read Apply so the trade-slot flow is more obvious")
    assert_true(string.find(frame.Detail.TradeHint.text or "", "Trade active") ~= nil, "detail pane should explain the trade apply flow when a matching trade is open")
end

local function test_simulate_generates_safe_fake_orders_and_schedules_next_tick()
    local addon, state = setup_env({
        defer_timers = true,
        char_db = {
            RecipeList = {
                ["Enchant Weapon - Mongoose"] = { "mongoose" },
            },
            RecipeLinks = {
                ["Enchant Weapon - Mongoose"] = "[Enchant Weapon - Mongoose] ",
            },
        },
    })

    addon.RefreshCompiledData()

    local started = addon.StartSimulation()
    local orders = addon.Workbench.EnsureState().Orders
    local order = orders[1]

    assert_true(started, "simulation should start when scanned recipes exist")
    assert_true(addon.Simulation.Running, "simulation should stay marked as running")
    assert_equal(#orders, 1, "starting simulation should queue one fake order immediately")
    assert_true(string.find(order.Customer, "^Sim") ~= nil, "simulated customers should be clearly marked as fake")
    assert_equal(state.timer_delays[3], 180, "simulation should schedule its next fake order three minutes later")
    run_timer(state, 1)
    run_timer(state, 2)
    assert_equal(#state.invites, 0, "simulated customers should not receive real invites even when their callbacks fire")
    assert_equal(#state.whispers, 0, "simulated customers should not receive real whispers even when their callbacks fire")
end

local function test_simulate_stop_invalidates_pending_tick()
    local addon, state = setup_env({
        defer_timers = true,
        char_db = {
            RecipeList = {
                ["Enchant Boots - Minor Speed"] = { "minor speed" },
            },
        },
    })

    addon.RefreshCompiledData()
    addon.StartSimulation()
    addon.StopSimulation()
    run_timer(state, 3)

    assert_equal(#addon.Workbench.EnsureState().Orders, 1, "stopped simulation should ignore the already-scheduled tick")
    assert_true(not addon.Simulation.Running, "simulation should stay stopped after toggling it off")
end

local function test_simulate_now_queues_extra_fake_order_without_starting_loop()
    local addon, state = setup_env({
        defer_timers = true,
        char_db = {
            RecipeList = {
                ["Enchant Boots - Minor Speed"] = { "minor speed" },
            },
        },
    })

    addon.RefreshCompiledData()

    local queued = addon.GenerateSimulatedOrder("manual")

    assert_true(queued, "manual simulate should queue one fake order when scanned recipes exist")
    assert_equal(#addon.Workbench.EnsureState().Orders, 1, "manual simulate should add a fake order to the workbench")
    assert_nil(state.timer_delays[3], "manual simulate should not start the repeating three-minute timer by itself")
end

local function test_simulate_survives_without_math_random_helpers()
    local addon = setup_env({
        omit_math_random = true,
        omit_math_randomseed = true,
        omit_global_random = true,
        omit_global_randomseed = true,
        char_db = {
            RecipeList = {
                ["Enchant Boots - Minor Speed"] = { "minor speed" },
            },
        },
    })

    addon.RefreshCompiledData()

    local queued = addon.GenerateSimulatedOrder("manual")
    local order = addon.Workbench.GetSelectedOrder()

    assert_true(queued, "manual simulate should still queue an order when the client does not expose math random helpers")
    assert_not_nil(order, "simulation should still produce a selected fake order without random helpers")
    assert_true(string.find(order.Customer, "^Sim") ~= nil, "fallback simulation should still mark the generated customer as fake")
end

local function test_slash_commands_expose_simulate_entry()
    local _, state = setup_env()
    local found = false

    for _, entry in ipairs(state.slash.entries or {}) do
        if entry[1] == "simulate" then
            found = true
            break
        end
    end

    assert_true(found, "slash command table should expose /ec simulate")
end

test_scan_filters_unknown_and_nether_recipes()
test_scan_builds_specific_slot_aliases_for_unsupported_enchants()
test_classic_recipe_aliases_stay_specific()
test_scan_prefers_trade_skill_recipe_data_when_both_apis_exist()
test_default_recipe_blacklists_compile_and_merge_with_custom_blacklists()
test_valid_request_matching_scenarios()
test_invalid_request_matching_scenarios()
test_requested_recipe_count_scenarios()
test_options_update_rebuilds_compiled_tags()
test_custom_recipe_tags_keep_exact_link_matching()
test_global_blacklist_treats_punctuation_literally()
test_linked_enchanting_messages_survive_user_global_blacklist()
test_parse_message_skips_recipe_when_per_recipe_blacklist_matches()
test_parse_message_keeps_recipe_when_blacklist_phrase_is_in_another_segment()
test_parse_message_does_not_double_count_nested_request_tags()
test_parse_message_matches_multi_enchant_lists_by_segment()
test_parse_message_keeps_adjacent_linked_enchants_from_blacklisting_each_other()
test_parse_message_ignores_mid_token_recipe_alias_false_positive()
test_incomplete_order_settings_default_on()
test_parse_message_invites_once_and_whispers_link()
test_message_prefix_randomizes_across_comma_separated_choices()
test_message_prefix_keeps_literal_commas_inside_one_phrase()
test_parse_message_warns_for_incomplete_order()
test_parse_message_skips_incomplete_warning_when_disabled()
test_incomplete_order_can_be_left_unflagged_until_corrected()
test_generic_lf_enchanter_whisper()
test_generic_lf_enchanter_follow_up_whisper_creates_order()
test_generic_lf_enchanter_follow_up_whispers_update_existing_order()
test_workbench_tracks_and_merges_orders()
test_parse_message_expands_recipe_quantity_suffix_into_duplicate_order_entries()
test_workbench_remove_clears_player_gate()
test_mailbox_loot_queues_sender_disenchant_orders_and_pauses_chat_scanning()
test_mailbox_disenchant_tracking_records_results_and_prepares_return_mail()
test_workbench_debug_output_is_printed()
test_workbench_frame_keeps_buttons_above_drag_header()
test_workbench_title_includes_addon_version()
test_workbench_sound_button_defaults_off_and_cycles()
test_workbench_sound_button_warns_when_preview_cannot_play()
test_workbench_lock_button_survives_clients_without_text_insets()
test_workbench_toggle_shows_a_newly_created_hidden_frame()
test_workbench_toggle_recovers_from_a_stale_hidden_frame_state()
test_trade_events_register_even_when_chat_scanning_is_stopped()
test_workbench_tracks_trade_tip_using_trade_money_api_and_auto_completes_verified_trade()
test_workbench_verified_orders_auto_complete_without_a_button()
test_workbench_active_trade_hides_manual_completion_controls()
test_trade_enchant_slot_requires_real_enchantment_before_auto_verify()
test_trade_completion_message_falls_back_to_recorded_cast_when_enchant_text_never_appears()
test_workbench_accepted_trade_commits_progress_and_auto_completes_zero_tip_order()
test_workbench_persists_trade_progress_after_accept_flags_reset_during_close()
test_workbench_trade_completion_message_captures_final_enchant_without_extra_trade_sync()
test_workbench_verified_orders_auto_complete_on_the_next_successful_trade()
test_workbench_accumulates_trade_tip_before_the_final_successful_trade()
test_workbench_accumulates_split_material_counts_across_accepted_trades()
test_workbench_keeps_last_accepted_trade_material_snapshot_when_trade_slots_clear_before_close()
test_workbench_late_completion_signal_preserves_split_trade_progress_during_followup_trade()
test_workbench_header_button_scans_when_recipe_data_is_missing()
test_workbench_header_button_toggles_start_and_stop_after_scan_data_exists()
test_workbench_header_button_does_not_get_stuck_on_scan_when_only_mats_are_missing()
test_auction_search_button_only_shows_while_the_auction_house_is_open()
test_auction_search_uses_formula_names_and_refreshes_live_enchanting_data()
test_auction_search_uses_saved_scan_when_the_profession_window_is_closed()
test_auction_search_requires_a_scan_when_no_recipe_data_is_available()
test_workbench_refresh_survives_without_fontstring_setshown()
test_workbench_detail_lines_keep_a_usable_width_after_refresh()
test_workbench_resize_persists_saved_size_and_updates_layout()
test_workbench_applies_elvui_skin_when_available()
test_scan_selects_trade_skill_before_capturing_materials()
test_scan_keeps_full_reagent_snapshot_when_only_one_mat_is_owned()
test_scan_keeps_reagent_rows_when_only_the_item_link_has_a_name()
test_scan_marks_empty_link_text_reagents_pending_until_item_data_arrives()
test_workbench_lazily_hydrates_unresolved_material_names_before_render()
test_trade_material_progress_matches_by_item_id_when_recipe_link_text_was_unresolved()
test_scan_clears_trade_skill_filters_and_restores_them_afterward()
test_scan_restores_legacy_craft_filters_when_slot_list_changes()
test_run_recipe_scan_does_not_claim_success_when_zero_supported_recipes_are_found()
test_workbench_timestamps_follow_clock_style()
test_workbench_timestamps_honor_military_and_local_clock_settings()
test_workbench_timestamps_fall_back_to_game_time_when_local_clock_is_unavailable()
test_workbench_queue_alert_only_plays_for_new_orders_when_enabled()
test_workbench_queue_alert_falls_back_when_channel_argument_is_unsupported()
test_formula_purchase_requests_do_not_match_enchant_service()
test_workbench_party_join_sound_mode_moves_alert_off_new_orders()
test_workbench_party_join_sound_mode_does_not_false_alert_for_existing_group_members()
test_grouped_customer_join_marks_player_with_star()
test_grouped_customer_join_auto_shows_hidden_workbench()
test_workbench_cast_selects_trade_skill_and_uses_create_count()
test_workbench_cast_clears_trade_skill_search_and_restores_it_afterward()
test_workbench_cast_uses_legacy_craft_api_after_temporarily_clearing_filters()
test_workbench_cast_falls_back_to_all_craft_slots_when_saved_slot_becomes_invalid()
test_workbench_legacy_timestamps_are_reformatted_on_load()
test_workbench_trade_cast_keeps_order_until_verified()
test_workbench_keeps_order_when_trade_has_no_completion_signal()
test_workbench_manual_invite_and_whisper_actions()
test_workbench_clear_button_empties_queue_and_resets_detail()
test_workbench_refresh_clamps_stale_scroll_offset()
test_grouped_follow_up_whispers_after_invite_failure()
test_grouped_follow_up_is_ignored_when_disabled()
test_grouped_queue_indicator_clears_when_customer_joins_group()
test_grouped_customer_limit_pauses_chat_scanning_when_customer_joins()
test_grouped_customer_limit_auto_resumes_when_customer_leaves()
test_grouped_customer_limit_does_not_auto_resume_after_manual_stop()
test_player_afk_event_auto_stops_chat_scanning()
test_grouped_queue_auto_expires_when_customer_never_joins()
test_declined_invite_order_auto_expires_when_timer_enabled()
test_manual_reinvite_clears_declined_invite_timer()
test_trade_with_unmatched_partner_does_not_complete_selected_order()
test_order_only_turns_verified_when_all_recipes_are_checked()
test_recipe_lines_show_read_only_status_indicators()
test_workbench_auto_verifies_trade_enchant_without_apply_click()
test_workbench_tracks_duplicate_recipe_verification_one_trade_at_a_time()
test_successful_trade_can_emote_thank_directly_to_customer()
test_successful_trade_can_thank_by_temporary_target_and_restore_previous_target()
test_tip_only_trade_does_not_emote_thank()
test_trade_detected_enchant_shows_as_checked_before_trade_closes()
test_trade_offer_marks_live_material_progress()
test_trade_sync_recovers_partner_name_after_trade_show()
test_trade_material_helper_copies_live_offer_into_recorded_progress()
test_material_lines_show_read_only_status_indicators()
test_active_trade_updates_recipe_button_to_apply()
test_simulate_generates_safe_fake_orders_and_schedules_next_tick()
test_simulate_stop_invalidates_pending_tick()
test_simulate_now_queues_extra_fake_order_without_starting_loop()
test_simulate_survives_without_math_random_helpers()
test_slash_commands_expose_simulate_entry()
test_workbench_missing_mats_whisper_action()
test_workbench_missing_mats_whisper_skips_when_all_mats_present()
test_ban_player_silences_messages()
test_ban_player_is_case_insensitive()
test_unban_player_restores_matching()
test_is_banned_respects_ban_and_unban()
