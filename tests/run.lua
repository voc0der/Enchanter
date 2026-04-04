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

local function setup_env(opts)
    opts = opts or {}

    local state = {
        invites = {},
        prints = {},
        slash = nil,
        timer_delays = {},
        trade_skills = copy_table(opts.trade_skills or {}),
        whispers = {},
    }

    _G.Enchanter_Addon = nil
    _G.EnchanterDB = copy_table(opts.db or {})
    _G.EnchanterDBChar = copy_table(opts.char_db or {})
    _G.C_AddOns = nil
    _G.C_PartyInfo = nil
    _G.C_Timer = {
        After = function(delay, callback)
            state.timer_delays[#state.timer_delays + 1] = delay
            callback()
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
        return state.trade_skills[index] and state.trade_skills[index].name or nil
    end
    _G.GetTradeSkillRecipeLink = function(index)
        return state.trade_skills[index] and state.trade_skills[index].link or nil
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

test_scan_filters_unknown_and_nether_recipes()
test_options_update_rebuilds_compiled_tags()
test_parse_message_invites_once_and_whispers_link()
test_generic_lf_enchanter_whisper()
test_workbench_tracks_and_merges_orders()
test_workbench_remove_clears_player_gate()
test_workbench_debug_output_is_printed()
test_workbench_auto_completes_after_trade_cast()
test_workbench_keeps_order_when_trade_has_no_completion_signal()
test_workbench_manual_invite_and_whisper_actions()
test_grouped_follow_up_whispers_after_invite_failure()
test_grouped_follow_up_is_ignored_when_disabled()
test_trade_with_unmatched_partner_does_not_complete_selected_order()
