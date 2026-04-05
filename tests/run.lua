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

local function setup_env(opts)
    opts = opts or {}

    local state = {
        invites = {},
        prints = {},
        played_sounds = {},
        played_sound_calls = {},
        crafts = copy_table(opts.crafts or {}),
        craft_available_only = opts.craft_available_only and true or false,
        craft_filter = tonumber(opts.craft_filter) or 0,
        do_craft_calls = {},
        do_trade_skill_calls = {},
        events = {},
        slash = nil,
        timer_delays = {},
        timer_callbacks = {},
        trade_skills = copy_table(opts.trade_skills or {}),
        trade_target_items = copy_table(opts.trade_target_items or {}),
        trade_player_items = copy_table(opts.trade_player_items or {}),
        trade_target_money = tonumber(opts.trade_target_money) or 0,
        whispers = {},
        frames = {},
        selected_craft = tonumber(opts.selected_craft) or nil,
        selected_trade_skill = nil,
    }

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
        function frame:SetAutoFocus(value) self.auto_focus = value and true or false end
        function frame:SetNumeric(value) self.numeric = value and true or false end
        function frame:SetMaxLetters(value) self.max_letters = value end
        function frame:SetTextInsets(...) self.text_insets = { ... } end
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
    _G.SOUNDKIT = {
        UI_REFORGING_REFORGE = 23291,
        AUCTION_WINDOW_OPEN = 5274,
    }
    _G.ERR_TRADE_COMPLETE = "Trade complete."
    _G.PlaySound = function(sound_kit, channel)
        if opts.play_sound_errors_on_channel and channel ~= nil then
            error("channel playback unsupported")
        end
        state.played_sounds[#state.played_sounds + 1] = sound_kit
        state.played_sound_calls[#state.played_sound_calls + 1] = {
            sound_kit = sound_kit,
            channel = channel,
        }
        return true
    end
    _G.CastSpellByName = function(name)
        state.last_cast = name
    end
    _G.CraftFrame = {
        selectedCraft = state.selected_craft,
    }
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
        return table.unpack(opts.craft_slots or {})
    end
    _G.GetCraftFilter = function(index)
        return (tonumber(index) or 0) == state.craft_filter
    end
    _G.SetCraftFilter = function(index)
        state.craft_filter = tonumber(index) or 0
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
    _G.TradeSkillFrame = {
        selectedSkill = nil,
    }
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
        checked = false,
    }
    function _G.TradeSkillFrameAvailableFilterCheckButton:GetChecked()
        return self.checked and true or false
    end
    function _G.TradeSkillFrameAvailableFilterCheckButton:SetChecked(value)
        self.checked = value and true or false
    end
    _G.GetTradeSkillSubClasses = function()
        return table.unpack(opts.trade_skill_subclasses or {})
    end
    _G.GetTradeSkillInvSlots = function()
        return table.unpack(opts.trade_skill_invslots or {})
    end
    _G.GetTradeSkillSubClassFilter = function(index)
        return index == 0 and 1 or 0
    end
    _G.GetTradeSkillInvSlotFilter = function(index)
        return index == 0 and 1 or 0
    end
    _G.SetTradeSkillSubClassFilter = function() end
    _G.SetTradeSkillInvSlotFilter = function() end
    _G.ExpandTradeSkillSubClass = function(index)
        state.expanded_trade_skill_subclass = index
    end
    _G.TradeSkillOnlyShowMakeable = function(value)
        _G.TradeSkillFrameAvailableFilterCheckButton.checked = value and true or false
    end
    _G.GetNumTradeSkills = function()
        return #state.trade_skills
    end
    _G.GetTradeSkillInfo = function(index)
        local skill = state.trade_skills[index]
        if not skill then
            return nil
        end
        return skill.name, skill.skill_type
    end
    _G.GetTradeSkillRecipeLink = function(index)
        return state.trade_skills[index] and state.trade_skills[index].link or nil
    end
    _G.SelectTradeSkill = function(index)
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
    _G.GetTradeSkillNumReagents = function(index)
        local skill = state.trade_skills[index]
        if not skill or not skill.reagents then
            return 0
        end
        if opts.require_trade_selection_for_reagents and state.selected_trade_skill ~= index then
            return 0
        end
        return #skill.reagents
    end
    _G.GetTradeSkillReagentInfo = function(index, reagent_index)
        local skill = state.trade_skills[index]
        if not skill or not skill.reagents then
            return nil
        end
        if opts.require_trade_selection_for_reagents and state.selected_trade_skill ~= index then
            return nil
        end
        local reagent = skill.reagents[reagent_index]
        if not reagent then
            return nil
        end
        return reagent.name, reagent.texture, reagent.count
    end
    _G.GetTradeSkillReagentItemLink = function(index, reagent_index)
        local skill = state.trade_skills[index]
        if not skill or not skill.reagents then
            return nil
        end
        if opts.require_trade_selection_for_reagents and state.selected_trade_skill ~= index then
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
    _G.GetCVarBool = function(name)
        if name == "timeMgrUseMilitaryTime" then
            return opts.use_military_time and true or false
        end
        if name == "timeMgrUseLocalTime" then
            return opts.use_local_time and true or false
        end
        return false
    end
    _G.TIME_TWENTYFOURHOURS = "%02d:%02d"
    _G.TIME_TWELVEHOURAM = "%d:%02d AM"
    _G.TIME_TWELVEHOURPM = "%d:%02d PM"
    _G.date = opts.date_impl
    _G.CreateFrame = function(frame_type, name, parent, template)
        return new_frame(frame_type, name, parent, template)
    end
    _G.UIParent = new_frame("Frame", "UIParent", nil, nil)
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

    function addon.Tool.RegisterEvent(event)
        state.events[#state.events + 1] = event
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
    assert_equal(addon.RecipeTagsMap["mongoose"], "Enchant Weapon - Mongoose", "custom recipe tag should be mapped")
    assert_equal(addon.DBChar.RecipeList["Enchant Weapon - Mongoose"][2], "weapon mongoose", "custom recipe tags should replace stale tags")
end

local function test_incomplete_order_settings_default_on()
    local addon = setup_env()

    assert_true(addon.DB.WarnIncompleteOrder, "incomplete-order warnings should default to enabled")
    assert_true(addon.DB.InviteIncompleteOrder, "incomplete-order invites should default to enabled")
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

    local frame = addon.Workbench.CreateFrame()

    assert_not_nil(frame, "workbench frame should be created when UI helpers exist")
    assert_equal(frame.frame_strata, "DIALOG", "workbench should use dialog strata so it stays interactable")
    assert_true(frame.resizable, "workbench should allow resizing")
    assert_equal(frame.CloseButton.parent, frame.Header, "close button should live on the header so the drag region does not cover it")
    assert_equal(frame.LockButton.parent, frame.Header, "lock button should live on the header so it remains clickable")
    assert_equal(frame.ClearButton.parent, frame.Header, "clear button should also live on the header so it stays clickable")
    assert_equal(frame.SoundButton.parent, frame.Header, "sound button should live on the header so it stays clickable")
    assert_equal(frame.ScanButton.parent, frame.Header, "scan/start/stop button should live on the header so it stays clickable")
    assert_equal(frame.CloseButton.text, "X", "close button should use a stable text button on this client")
    assert_equal(frame.QueueCountText.point[1], "BOTTOMLEFT", "queue summary should live in the footer instead of crowding the header")
    assert_equal(frame.ListChild.point[1], "TOPLEFT", "queue scroll child should be anchored so order rows render inside the scroll area")
end

local function test_workbench_sound_button_defaults_off_and_toggles()
    local addon = setup_env()

    local frame = addon.Workbench.CreateFrame()
    local workbenchState = addon.Workbench.EnsureState()

    assert_true(not workbenchState.SoundEnabled, "queue sound should default to disabled")
    assert_equal(frame.SoundButton.text, "No Sound", "header button should show No Sound when alerts are disabled")

    frame.SoundButton.scripts["OnClick"]()
    assert_true(workbenchState.SoundEnabled, "sound toggle should persist as enabled after clicking")
    assert_equal(frame.SoundButton.text, "Sound", "header button should flip to Sound when alerts are enabled")

    frame.SoundButton.scripts["OnClick"]()
    assert_true(not workbenchState.SoundEnabled, "sound toggle should persist as disabled after a second click")
    assert_equal(frame.SoundButton.text, "No Sound", "header button should flip back to No Sound when alerts are disabled")
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
end

local function test_workbench_tracks_trade_tip_using_trade_money_api_until_manual_completion()
    local addon, state = setup_env({
        trade_target_money = 123400,
        char_db = {
            RecipeList = {
                ["Enchant Weapon - Mongoose"] = { "mongoose" },
            },
        },
    })

    local frame = addon.Workbench.CreateFrame()
    addon.RefreshCompiledData()
    addon.ParseMessage("LF mongoose pst", "Buyer-Tip")

    local order = addon.Workbench.GetSelectedOrder()
    addon.Workbench.SetRecipeVerified(order.Id, "Enchant Weapon - Mongoose", true)
    addon.Workbench.BeginTrade("Buyer-Tip")
    addon.Workbench.SetTradeAcceptState(1, 1)
    addon.Workbench.SyncActiveTrade()
    addon.Workbench.FinishTrade(0)

    order = addon.Workbench.GetSelectedOrder()
    local workbenchState = addon.Workbench.EnsureState()

    assert_not_nil(order, "accepted trades should leave the order queued until you click complete")
    assert_equal(order.LastObservedTipCopper, 123400, "accepted trades should store the target trade money on the order")
    assert_equal(frame.Detail.TipStatus.text, "Tip: 12g 34s", "the detail pane should show the recorded trade tip after the trade closes")
    assert_true(frame.Detail.CompleteButton:IsEnabled(), "complete should enable after a verified order has a recorded tip")
    assert_equal(workbenchState.CompletedOrders, 0, "accepted trades should not auto-complete the order")
    assert_equal(workbenchState.CompletedTipsCopper, 0, "accepted trades should wait for manual completion before banking totals")
    assert_equal(#workbenchState.Orders, 1, "accepted verified trades should stay queued until manually completed")
    assert_true(string.find(frame.QueueCountText.text or "", "0 done") ~= nil, "footer summary should stay unbanked until manual completion")
    assert_equal(state.trade_target_money, 123400, "trade money test should use the target trade money api path")

    frame.Detail.CompleteButton.scripts["OnClick"](frame.Detail.CompleteButton)

    assert_equal(workbenchState.CompletedOrders, 1, "manual completion should increment the running completed count")
    assert_equal(workbenchState.CompletedTipsCopper, 123400, "manual completion should bank the tracked trade money in the running total")
    assert_equal(#workbenchState.Orders, 0, "manual completion should remove the order from the queue")
    assert_true(string.find(frame.QueueCountText.text or "", "1 done") ~= nil, "footer summary should show the completed count")
    assert_true(string.find(frame.QueueCountText.text or "", "12g 34s tips") ~= nil, "footer summary should show the running tips total")

    frame.ClearButton.scripts["OnClick"]()

    assert_equal(workbenchState.CompletedOrders, 0, "clear should reset the running completed count")
    assert_equal(workbenchState.CompletedTipsCopper, 0, "clear should reset the running tips total")
    assert_true(string.find(frame.QueueCountText.text or "", "0 done") ~= nil, "footer summary should return to zero after clear")
end

local function test_workbench_complete_allows_zero_tip_without_a_separate_button()
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

    assert_equal(frame.Detail.TipStatus.text, "Tip: not recorded", "untipped orders should show that no gold has been recorded yet")
    assert_nil(frame.Detail.NoTipButton, "untipped orders should no longer render a separate no-tip button")
    assert_true(frame.Detail.CompleteButton:IsEnabled(), "complete should stay available for verified zero-tip orders")

    frame.Detail.CompleteButton.scripts["OnClick"](frame.Detail.CompleteButton)

    local workbenchState = addon.Workbench.EnsureState()
    assert_equal(workbenchState.CompletedOrders, 1, "zero-tip completions should still count as completed orders")
    assert_equal(workbenchState.CompletedTipsCopper, 0, "no-tip completions should not add to the running tips total")
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

    local order = addon.Workbench.GetSelectedOrder()
    addon.Workbench.SetRecipeVerified(order.Id, "Enchant Weapon - Mongoose", true)
    addon.Workbench.BeginTrade("Buyer-LiveTrade")

    assert_equal(frame.Detail.TipStatus.text, "Tip in trade: 50s", "active trades should show the live trade gold amount")
    assert_nil(frame.Detail.NoTipButton, "active trades should no longer render a separate no-tip override")
    assert_true(frame.Detail.CompleteButton.shown == false, "active trades should hide the manual completion fallback")
    assert_true(string.find(frame.Detail.ReadyText.text or "", "Complete stays manual") ~= nil, "active verified trades should explain that trade syncing is automatic but completion stays manual")
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

    local verified, total = addon.Workbench.GetRecipeVerificationProgress(addon.Workbench.GetOrderById(order.Id))
    assert_equal(verified, 1, "the completion signal should trust the recorded cast when the trade slot never exposes enchant text")
    assert_equal(total, 1, "completion-signal fallback should preserve the queued recipe total")
end

local function test_workbench_accepted_trade_commits_progress_and_waits_for_manual_zero_tip_completion()
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

    order = addon.Workbench.GetOrderById(order.Id)
    local state = addon.Workbench.EnsureState()
    local verified, totalRecipes = addon.Workbench.GetRecipeVerificationProgress(order)
    local checked, totalMats = addon.Workbench.GetMaterialProgress(order)

    assert_not_nil(order, "accepted zero-tip trades should stay queued until you choose to complete them")
    assert_equal(verified, 1, "accepted trades should auto-verify the applied recipe once the enchant slot shows the enchantment")
    assert_equal(totalRecipes, 1, "the order should still track the recipe total")
    assert_equal(checked, 2, "accepted trades should carry the matching mats forward into the order")
    assert_equal(totalMats, 2, "material progress should still use the order material total")
    assert_nil(frame.Detail.NoTipButton, "after a zero-tip trade there should still be no separate no-tip button")
    assert_true(frame.Detail.CompleteButton:IsEnabled(), "complete should stay available after a verified zero-tip trade")
    assert_equal(state.CompletedOrders, 0, "accepted zero-tip trades should not auto-complete the order")
    assert_equal(state.CompletedTipsCopper, 0, "accepted zero-tip trades should not bank tips before manual completion")

    frame.Detail.CompleteButton.scripts["OnClick"](frame.Detail.CompleteButton)

    assert_equal(state.CompletedOrders, 1, "manual completion should still work after a zero-tip accepted trade")
    assert_equal(state.CompletedTipsCopper, 0, "manual completion should bank zero tip for a no-tip order")
    assert_nil(addon.Workbench.GetOrderById(order.Id), "manual completion should remove the finished zero-tip order")
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

    order = addon.Workbench.GetOrderById(order.Id)
    local verified, total = addon.Workbench.GetRecipeVerificationProgress(order)
    assert_equal(verified, 1, "trade completion should capture a final enchant that only appears when the completion message fires")
    assert_equal(total, 1, "late completion-message verification should preserve the queued recipe total")
end

local function test_workbench_accumulates_multiple_trade_tips_until_manual_completion()
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
    addon.ParseMessage("LF mongoose pst", "Buyer-MultiTip")

    local order = addon.Workbench.GetSelectedOrder()
    addon.Workbench.SetRecipeVerified(order.Id, "Enchant Weapon - Mongoose", true)

    addon.Workbench.BeginTrade("Buyer-MultiTip")
    addon.Workbench.SetTradeAcceptState(1, 1)
    addon.Workbench.FinishTrade(0)

    state.trade_target_money = 2000
    addon.Workbench.BeginTrade("Buyer-MultiTip")
    addon.Workbench.SetTradeAcceptState(1, 1)
    addon.Workbench.FinishTrade(0)

    order = addon.Workbench.GetSelectedOrder()
    local workbenchState = addon.Workbench.EnsureState()

    assert_not_nil(order, "verified orders should stay queued so later tips can still attach")
    assert_equal(order.LastObservedTipCopper, 7000, "multiple successful tip trades should accumulate until manual completion")
    assert_equal(frame.Detail.TipStatus.text, "Tip: 70s", "the detail pane should show the accumulated tip total after multiple trades")
    assert_true(frame.Detail.CompleteButton:IsEnabled(), "complete should be ready once the accumulated tip is recorded")
    assert_equal(workbenchState.CompletedOrders, 0, "multiple accepted tip trades should not auto-complete the order")

    frame.Detail.CompleteButton.scripts["OnClick"](frame.Detail.CompleteButton)

    assert_equal(workbenchState.CompletedOrders, 1, "manual completion should bank the accumulated multi-trade tip")
    assert_equal(workbenchState.CompletedTipsCopper, 7000, "manual completion should use the full accumulated tip total")
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

    addon.Workbench.SetRecipeVerified(order.Id, "Enchant Weapon - Mongoose", true)
    state.trade_target_money = 0
    addon.Workbench.BeginTrade("Buyer-SplitTip")
    addon.Workbench.SetTradeAcceptState(1, 1)
    addon.Workbench.FinishTrade(0)

    order = addon.Workbench.GetSelectedOrder()
    local workbenchState = addon.Workbench.EnsureState()
    assert_not_nil(order, "the later accepted trade should still leave the order queued for manual completion")
    assert_equal(order.LastObservedTipCopper, 5000, "the earlier tip should stay attached to the order after the later accepted trade")
    assert_equal(workbenchState.CompletedOrders, 0, "the later accepted trade should not auto-complete the already-paid order")

    addon.Workbench.CompleteOrder(order.Id)

    assert_equal(workbenchState.CompletedOrders, 1, "manual completion should bank the earlier split tip once the order is finished")
    assert_equal(workbenchState.CompletedTipsCopper, 5000, "manual completion should still count the earlier tip total")
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
    assert_true(frame.ResizeHandle.elvui_button_skinned, "resize handle should use the ElvUI button template when available")
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

local function test_workbench_timestamps_follow_clock_style()
    local addon = setup_env({
        game_time = {
            hour = 13,
            min = 11,
        },
    })

    addon.Workbench.AddOrUpdateOrder("Buyer-Time", "LF mongoose pst", {
        ["Enchant Weapon - Mongoose"] = "mongoose",
    })

    local order = addon.Workbench.GetOrderByCustomer("Buyer-Time")

    assert_not_nil(order, "queued order should exist for timestamp checks")
    assert_equal(order.CreatedAt, "1:11 PM", "workbench timestamps should use the in-game 12-hour clock style")
    assert_equal(order.UpdatedAt, "1:11 PM", "updated timestamp should match the same clock style")
end

local function test_workbench_timestamps_honor_military_and_local_clock_settings()
    local addon = setup_env({
        use_military_time = true,
        use_local_time = true,
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
    assert_equal(order.CreatedAt, "06:05", "timestamps should honor local clock and military time settings when enabled")
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
    assert_equal(state.played_sounds[1], SOUNDKIT.UI_REFORGING_REFORGE, "queue alert should use the enchanting-themed WoW sound first")
    assert_equal(state.played_sounds[2], SOUNDKIT.UI_REFORGING_REFORGE, "each new queued customer should reuse the same alert sound")
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

    local handled = addon.HandleInviteFailureMessage("Buyer-Grouped is already in a group.")

    assert_true(handled, "already-grouped invite failures should be recognized")
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

    local handled = addon.HandleInviteFailureMessage("Buyer-NoFollowUp is already in a group.")

    assert_true(not handled, "grouped follow-up should ignore invite failures when the option is disabled")
    assert_equal(#state.whispers, 1, "no follow-up whisper should be added when disabled")
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

    assert_true(string.find(frame.OrderRows[1].MetaText.text or "", "Verified") ~= nil, "the queue should only show the green verified state after every requested enchant is checked")
    assert_true(string.find(frame.Detail.Meta.text or "", "Verified") ~= nil, "detail meta should also show the full-order verified state once all recipes are checked")
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

    assert_true(frame.Detail.RecipeLines[1].StatusCheck.shown, "verified recipe rows should show the green-check texture")
    assert_true(frame.Detail.RecipeLines[1].StatusText.shown == false, "verified recipe rows should hide the question-mark indicator")
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

    local order = addon.Workbench.GetSelectedOrder()
    local verified, total = addon.Workbench.GetRecipeVerificationProgress(order)

    assert_equal(verified, 1, "accepted trades should auto-verify a matching enchant even when Apply was not clicked first")
    assert_equal(total, 1, "auto verification should still track the total queued recipe count")
    assert_true(frame.Detail.RecipeLines[1].StatusCheck.shown, "auto-verified recipes should show the green-check indicator")
    assert_true(frame.Detail.RecipeLines[1].StatusText.shown == false, "auto-verified recipes should hide the question-mark indicator")
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
test_scan_prefers_trade_skill_recipe_data_when_both_apis_exist()
test_options_update_rebuilds_compiled_tags()
test_incomplete_order_settings_default_on()
test_parse_message_invites_once_and_whispers_link()
test_parse_message_warns_for_incomplete_order()
test_parse_message_skips_incomplete_warning_when_disabled()
test_incomplete_order_can_be_left_unflagged_until_corrected()
test_generic_lf_enchanter_whisper()
test_workbench_tracks_and_merges_orders()
test_workbench_remove_clears_player_gate()
test_workbench_debug_output_is_printed()
test_workbench_frame_keeps_buttons_above_drag_header()
test_workbench_sound_button_defaults_off_and_toggles()
test_workbench_toggle_shows_a_newly_created_hidden_frame()
test_workbench_toggle_recovers_from_a_stale_hidden_frame_state()
test_trade_events_register_even_when_chat_scanning_is_stopped()
test_workbench_tracks_trade_tip_using_trade_money_api_until_manual_completion()
test_workbench_complete_allows_zero_tip_without_a_separate_button()
test_workbench_active_trade_hides_manual_completion_controls()
test_trade_enchant_slot_requires_real_enchantment_before_auto_verify()
test_trade_completion_message_falls_back_to_recorded_cast_when_enchant_text_never_appears()
test_workbench_accepted_trade_commits_progress_and_waits_for_manual_zero_tip_completion()
test_workbench_trade_completion_message_captures_final_enchant_without_extra_trade_sync()
test_workbench_accumulates_multiple_trade_tips_until_manual_completion()
test_workbench_accumulates_trade_tip_before_the_final_successful_trade()
test_workbench_accumulates_split_material_counts_across_accepted_trades()
test_workbench_keeps_last_accepted_trade_material_snapshot_when_trade_slots_clear_before_close()
test_workbench_header_button_scans_when_recipe_data_is_missing()
test_workbench_header_button_toggles_start_and_stop_after_scan_data_exists()
test_workbench_refresh_survives_without_fontstring_setshown()
test_workbench_detail_lines_keep_a_usable_width_after_refresh()
test_workbench_resize_persists_saved_size_and_updates_layout()
test_workbench_applies_elvui_skin_when_available()
test_scan_selects_trade_skill_before_capturing_materials()
test_workbench_timestamps_follow_clock_style()
test_workbench_timestamps_honor_military_and_local_clock_settings()
test_workbench_queue_alert_only_plays_for_new_orders_when_enabled()
test_workbench_queue_alert_falls_back_when_channel_argument_is_unsupported()
test_workbench_cast_selects_trade_skill_and_uses_create_count()
test_workbench_cast_uses_legacy_craft_api_after_temporarily_clearing_filters()
test_workbench_legacy_timestamps_are_reformatted_on_load()
test_workbench_trade_cast_keeps_order_until_verified()
test_workbench_keeps_order_when_trade_has_no_completion_signal()
test_workbench_manual_invite_and_whisper_actions()
test_workbench_clear_button_empties_queue_and_resets_detail()
test_workbench_refresh_clamps_stale_scroll_offset()
test_grouped_follow_up_whispers_after_invite_failure()
test_grouped_follow_up_is_ignored_when_disabled()
test_trade_with_unmatched_partner_does_not_complete_selected_order()
test_order_only_turns_verified_when_all_recipes_are_checked()
test_recipe_lines_show_read_only_status_indicators()
test_workbench_auto_verifies_trade_enchant_without_apply_click()
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
