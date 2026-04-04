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
        slash = nil,
        timer_delays = {},
        timer_callbacks = {},
        trade_skills = copy_table(opts.trade_skills or {}),
        whispers = {},
        frames = {},
        selected_trade_skill = nil,
    }

    local function new_font_string()
        local font_string = {
            shown = true,
        }

        function font_string:SetPoint(...) self.point = { ... } end
        function font_string:ClearAllPoints() self.point = nil end
        function font_string:SetText(text) self.text = text end
        function font_string:GetText() return self.text end
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
        function texture:SetTexture(value) self.texture = value end
        function texture:SetColorTexture(...) self.color = { ... } end
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
        function frame:SetPoint(...) self.point = { ... } end
        function frame:GetPoint()
            if self.point then
                return table.unpack(self.point)
            end
            return "CENTER", _G.UIParent, "CENTER", 0, 0
        end
        function frame:ClearAllPoints() self.point = nil end
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
        function frame:SetChecked(value) self.checked = value and true or false end
        function frame:GetChecked() return self.checked end
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
    _G.CastSpellByName = function(name)
        state.last_cast = name
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

    function addon.Tool.RegisterEvent() end

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
    assert_equal(frame.CloseButton.text, "X", "close button should use a stable text button on this client")
    assert_equal(frame.ListChild.point[1], "TOPLEFT", "queue scroll child should be anchored so order rows render inside the scroll area")
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

local function test_workbench_auto_completes_after_trade_cast()
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

    assert_equal(#addon.Workbench.EnsureState().Orders, 0, "cast evidence during trade should auto-complete the order")
    assert_nil(addon.PlayerList["Buyer-Finish"], "auto-completion should clear the anti-spam gate")
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
test_options_update_rebuilds_compiled_tags()
test_parse_message_invites_once_and_whispers_link()
test_generic_lf_enchanter_whisper()
test_workbench_tracks_and_merges_orders()
test_workbench_remove_clears_player_gate()
test_workbench_debug_output_is_printed()
test_workbench_frame_keeps_buttons_above_drag_header()
test_workbench_refresh_survives_without_fontstring_setshown()
test_workbench_resize_persists_saved_size_and_updates_layout()
test_workbench_applies_elvui_skin_when_available()
test_scan_selects_trade_skill_before_capturing_materials()
test_workbench_timestamps_follow_clock_style()
test_workbench_timestamps_honor_military_and_local_clock_settings()
test_workbench_legacy_timestamps_are_reformatted_on_load()
test_workbench_auto_completes_after_trade_cast()
test_workbench_keeps_order_when_trade_has_no_completion_signal()
test_workbench_manual_invite_and_whisper_actions()
test_workbench_clear_button_empties_queue_and_resets_detail()
test_workbench_refresh_clamps_stale_scroll_offset()
test_grouped_follow_up_whispers_after_invite_failure()
test_grouped_follow_up_is_ignored_when_disabled()
test_trade_with_unmatched_partner_does_not_complete_selected_order()
test_simulate_generates_safe_fake_orders_and_schedules_next_tick()
test_simulate_stop_invalidates_pending_tick()
test_simulate_now_queues_extra_fake_order_without_starting_loop()
test_simulate_survives_without_math_random_helpers()
test_slash_commands_expose_simulate_entry()
