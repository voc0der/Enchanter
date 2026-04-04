local TOCNAME, EC = ...
Enchanter_Addon = EC

EC.Initalized = false
EC.PlayerList = {}
EC.LfRecipeList = {}
EC.SessionGold = 0
EC.DefaultMsg = "I can do "
EC.DefaultLfWhisperMsg = "What you looking for?"
EC.EnchanterTags = EC.DefaultEnchanterTags or {}
EC.PrefixTags = EC.DefaultPrefixTags or {}
EC.RecipeTags = EC.DefaultRecipeTags or {}
EC.RecipesWithNether = {"Enchant Boots - Surefooted"}
EC.PrefixTagsCompiled = {}
EC.BlacklistCompiled = {}
EC.RecipeTagsMap = {}
EC.RecipeTagList = {}

local preTradeGold = nil

local function GetAddOnMetadataCompat(addonName, field)
	if C_AddOns and C_AddOns.GetAddOnMetadata then
		return C_AddOns.GetAddOnMetadata(addonName, field)
	end
	if GetAddOnMetadata then
		return GetAddOnMetadata(addonName, field)
	end
	return ""
end

local function After(delay, func)
	delay = tonumber(delay) or 0
	if C_Timer and C_Timer.After then
		C_Timer.After(delay, func)
	else
		func()
	end
end

local function InvitePlayer(name)
	if C_PartyInfo and C_PartyInfo.InviteUnit then
		C_PartyInfo.InviteUnit(name)
	elseif InviteUnit then
		InviteUnit(name)
	end
end

local function GetRecipeApi()
	if GetNumCrafts and GetCraftInfo and GetCraftRecipeLink then
		return GetNumCrafts, GetCraftInfo, GetCraftRecipeLink
	end
	if GetNumTradeSkills and GetTradeSkillInfo and GetTradeSkillRecipeLink then
		return GetNumTradeSkills, GetTradeSkillInfo, GetTradeSkillRecipeLink
	end
	return nil, nil, nil
end

local function GetRecipeReagentApi()
	if GetNumCrafts and GetCraftInfo and GetCraftNumReagents and GetCraftReagentInfo then
		return GetCraftNumReagents, GetCraftReagentInfo, GetCraftReagentItemLink
	end
	if GetNumTradeSkills and GetTradeSkillInfo and GetTradeSkillNumReagents and GetTradeSkillReagentInfo then
		return GetTradeSkillNumReagents, GetTradeSkillReagentInfo, GetTradeSkillReagentItemLink
	end
	return nil, nil, nil
end

local function CaptureRecipeMaterials(recipeIndex)
	local getNumReagents, getReagentInfo, getReagentLink = GetRecipeReagentApi()
	local materials = {}

	if not getNumReagents or not getReagentInfo then
		return materials
	end

	for reagentIndex = 1, getNumReagents(recipeIndex) or 0 do
		local reagentName, _, reagentCount = getReagentInfo(recipeIndex, reagentIndex)
		if reagentName and reagentName ~= "" then
			materials[#materials + 1] = {
				Name = reagentName,
				Count = tonumber(reagentCount) or 1,
				Link = getReagentLink and getReagentLink(recipeIndex, reagentIndex) or nil,
			}
		end
	end

	return materials
end

local function NormalizePhrase(value)
	if not value then
		return ""
	end
	return value:lower():gsub("[%W_]+", "")
end

function EC.GetMatchedRecipeNames(recipeMap)
	local out = {}
	if type(recipeMap) ~= "table" then
		return out
	end

	for recipeName in pairs(recipeMap) do
		out[#out + 1] = recipeName
	end

	table.sort(out)
	return out
end

local function EnsureSavedVariables()
	if not EnchanterDB then EnchanterDB = {} end
	if not EnchanterDBChar then EnchanterDBChar = {} end

	EC.DB = EnchanterDB
	EC.DBChar = EnchanterDBChar

	if not EC.DB.Custom then EC.DB.Custom = {} end
	if not EC.DBChar.RecipeList then EC.DBChar.RecipeList = {} end
	if not EC.DBChar.RecipeLinks then EC.DBChar.RecipeLinks = {} end
	if not EC.DBChar.RecipeMats then EC.DBChar.RecipeMats = {} end
	if EC.DBChar.Stop == nil then EC.DBChar.Stop = false end
	if EC.DBChar.Debug == nil then EC.DBChar.Debug = false end
	if EC.DB.AutoInvite == nil then EC.DB.AutoInvite = true end
	if EC.DB.NetherRecipes == nil then EC.DB.NetherRecipes = false end
	if EC.DB.WhisperLfRequests == nil then EC.DB.WhisperLfRequests = false end
	if EC.DB.InviteTimeDelay == nil then EC.DB.InviteTimeDelay = 0 end
	if EC.DB.WhisperTimeDelay == nil then EC.DB.WhisperTimeDelay = 0 end
	if not EC.DB.MsgPrefix or EC.DB.MsgPrefix == "" then EC.DB.MsgPrefix = EC.DefaultMsg end
	if not EC.DB.LfWhisperMsg or EC.DB.LfWhisperMsg == "" then EC.DB.LfWhisperMsg = EC.DefaultLfWhisperMsg end
	if EC.Workbench and EC.Workbench.EnsureState then EC.Workbench.EnsureState() end
end

function EC.RefreshCompiledData()
	EC.PrefixTagsCompiled = {}
	EC.BlacklistCompiled = {}
	EC.RecipeTagsMap = {}
	EC.RecipeTagList = {}

	for _, value in ipairs(EC.PrefixTags or {}) do
		if value and value ~= "" then
			table.insert(EC.PrefixTagsCompiled, "%f[%w_]" .. value .. "%f[^%w_]")
		end
	end

	for _, value in ipairs(EC.BlackList or {}) do
		if value and value ~= "" then
			table.insert(EC.BlacklistCompiled, "%f[%w_]" .. value .. "%f[^%w_]")
		end
	end

	for recipeName, tags in pairs(EC.DBChar.RecipeList or {}) do
		for _, tag in ipairs(tags) do
			if tag and tag ~= "" then
				EC.RecipeTagsMap[tag] = recipeName
				table.insert(EC.RecipeTagList, tag)
			end
		end
	end

	if EC.Workbench and EC.Workbench.Refresh then
		EC.Workbench.Refresh()
	end
end

function EC.GetItems()
	local getCount, getInfo, getLink = GetRecipeApi()
	if not getCount or not getInfo then
		print("|cFFFF1C1CEnchanter|r could not find a supported enchanting scan API on this client.")
		return false
	end

	EC.DBChar.RecipeList = {}
	EC.DBChar.RecipeLinks = {}
	EC.DBChar.RecipeMats = {}

	CastSpellByName("Enchanting")

	for index = 1, getCount() or 0 do
		local recipeName = getInfo(index)
		if recipeName and EC.RecipeTags["enGB"][recipeName] then
			EC.DBChar.RecipeLinks[recipeName] = getLink and getLink(index) or nil
			EC.DBChar.RecipeMats[recipeName] = CaptureRecipeMaterials(index)
			EC.DBChar.RecipeList[recipeName] = EC.RecipeTags["enGB"][recipeName]
		end
	end

	if EC.DB.NetherRecipes then
		for _, recipeName in ipairs(EC.RecipesWithNether) do
			EC.DBChar.RecipeList[recipeName] = nil
			EC.DBChar.RecipeLinks[recipeName] = nil
			EC.DBChar.RecipeMats[recipeName] = nil
		end
	end

	EC.UpdateTags()
	EC.RefreshCompiledData()
	return true
end

local function DoScan()
	if EC.GetItems() then
		print("Scan Completed")
	end
end

function EC.Init()
	EnsureSavedVariables()

	EC.Tool.SlashCommand({"/ec", "/enchanter", "/e"}, {
		{"", "Toggles the workbench queue.", function()
			if EC.Workbench and EC.Workbench.Toggle then
				EC.Workbench.Toggle()
			end
		end},
		{"scan", "MUST BE RAN PRIOR TO /ec start. Scans and stores your enchanting recipes to be used when filtering requests. Rerun after learning new recipes.", function()
			DoScan()
		end},
		{{"stop", "pause"}, "Pauses addon scanning", function()
			EC.DBChar.Stop = true
			print("Paused")
		end},
		{"start", "Starts chat scanning", function()
			EC.DBChar.Stop = false
			print("Started...")
		end},
		{{"default", "reset"}, "Resets addon settings to defaults", function()
			EC.Default()
			EC.OptionsUpdate()
			print("Reset complete")
		end},
		{{"config", "setup", "options"}, "Settings", function()
			if EC.OptionsBuilder and EC.OptionsBuilder.OpenCategoryPanel then
				EC.OptionsBuilder.OpenCategoryPanel(1)
			elseif EC.Options and EC.Options.Open then
				EC.Options.Open(1)
			end
		end, 1},
		{{"workbench", "bench"}, "Toggles the workbench queue.", function()
			if EC.Workbench and EC.Workbench.Toggle then
				EC.Workbench.Toggle()
			end
		end},
		{"debug", "Enables/Disables debug messages", function()
			EC.DBChar.Debug = not EC.DBChar.Debug
			print("Debug mode is now " .. (EC.DBChar.Debug and "on" or "off"))
		end},
		{"summary", "Prints total gold earned from trades this session", function()
			local total = EC.SessionGold
			local gold = math.floor(total / 10000)
			local silver = math.floor((total % 10000) / 100)
			local copper = total % 100
			print("|cFFFF1C1CEnchanter|r Session Earnings: "
				.. "|cFFFFD700" .. gold .. "g|r "
				.. "|cFFC0C0C0" .. silver .. "s|r "
				.. "|cFFB87333" .. copper .. "c|r")
		end},
		{{"about", "usage"}, "Run /ec scan once to store your recipes, then /ec start to begin matching chat requests."},
	})

	EC.OptionsInit()
	EC.OptionsUpdate()
	if EC.Workbench and EC.Workbench.SyncVisibility then
		EC.Workbench.SyncVisibility()
	end
	EC.Initalized = true

	print("|cFFFF1C1C Loaded: "
		.. (GetAddOnMetadataCompat(TOCNAME, "Title") or TOCNAME)
		.. " " .. (GetAddOnMetadataCompat(TOCNAME, "Version") or "")
		.. " by " .. (GetAddOnMetadataCompat(TOCNAME, "Author") or ""))
end

function EC.SendMsg(name)
	if not EC.LfRecipeList[name] then
		return
	end

	local msg = EC.DB.MsgPrefix or EC.DefaultMsg
	for _, recipeName in ipairs(EC.GetMatchedRecipeNames(EC.LfRecipeList[name])) do
		msg = msg .. (EC.DBChar.RecipeLinks[recipeName] or ("[" .. recipeName .. "] "))
	end

	if EC.DBChar.Debug then
		print("Debug mode: would whisper to " .. name .. ": " .. msg)
	else
		SendChatMessage(msg, "WHISPER", nil, name)
	end

	EC.LfRecipeList[name] = nil
end

function EC.ParseMessage(msg, name)
	if EC.Initalized == false or not name or name == "" or not msg or msg == "" or string.len(msg) < 4 or EC.DBChar.Stop == true then
		return
	end

	local parsedMessage = msg:lower()
	local isRequestValid = false

	for _, pattern in ipairs(EC.PrefixTagsCompiled) do
		if string.find(parsedMessage, pattern) then
			isRequestValid = true
			break
		end
	end

	if not isRequestValid then
		return
	end

	for _, pattern in ipairs(EC.BlacklistCompiled) do
		if string.find(parsedMessage, pattern) then
			if EC.DBChar.Debug then
				print("Request: " .. msg .. " is being blacklisted due to pattern: " .. pattern)
			end
			return
		end
	end

	local matchedRecipes = false
	for _, tag in ipairs(EC.RecipeTagList) do
		if string.find(parsedMessage, tag, 1, true) then
			local recipeName = EC.RecipeTagsMap[tag]
			if recipeName then
				EC.LfRecipeList[name] = EC.LfRecipeList[name] or {}
				EC.LfRecipeList[name][recipeName] = tag
				matchedRecipes = true
				if EC.DBChar.Debug then
					print("User should be invited for msg: " .. msg)
					print("Due to tag: " .. tag .. " -> recipe " .. tostring(recipeName))
				end
			end
		end
	end

	if matchedRecipes then
		if EC.Workbench and EC.Workbench.AddOrUpdateOrder then
			EC.Workbench.AddOrUpdateOrder(name, msg, EC.LfRecipeList[name])
		end

		if EC.PlayerList[name] == nil then
			EC.PlayerList[name] = 1

			if EC.DBChar.Debug then
				print("Debug mode: suppressed invite/whisper to " .. name)
				EC.SendMsg(name)
			else
				if EC.DB.AutoInvite then
					After(EC.DB.InviteTimeDelay, function()
						InvitePlayer(name)
					end)
				end
				After(EC.DB.WhisperTimeDelay, function()
					EC.SendMsg(name)
				end)
			end
		else
			EC.LfRecipeList[name] = nil
		end
		return
	end

	if EC.DB.WhisperLfRequests and EC.PlayerList[name] == nil then
		local normalizedMessage = NormalizePhrase(parsedMessage)
		for _, tag in ipairs(EC.EnchanterTags or {}) do
			if NormalizePhrase(tag) == normalizedMessage then
				EC.PlayerList[name] = 1
				local genericReply = EC.DB.LfWhisperMsg or EC.DefaultLfWhisperMsg
				if EC.DBChar.Debug then
					print("Debug mode: would whisper to " .. name .. ": " .. genericReply)
				else
					After(EC.DB.WhisperTimeDelay, function()
						SendChatMessage(genericReply, "WHISPER", nil, name)
					end)
				end
				break
			end
		end
	end
end

local function Event_TRADE_SHOW()
	preTradeGold = GetMoney()
end

local function Event_TRADE_CLOSED()
	if preTradeGold ~= nil then
		local snapshot = preTradeGold
		preTradeGold = nil
		After(1, function()
			local delta = GetMoney() - snapshot
			if delta > 0 then
				EC.SessionGold = EC.SessionGold + delta
			end
		end)
	end
end

local function Event_CHAT_MSG_CHANNEL(msg, name)
	if not EC.Initalized then
		return
	end
	EC.ParseMessage(msg, name)
end

local function Event_ADDON_LOADED(arg1)
	if arg1 == TOCNAME then
		EC.Init()
	end
end

function EC.OnLoad()
	EC.Tool.RegisterEvent("ADDON_LOADED", Event_ADDON_LOADED)
	EC.Tool.RegisterEvent("CHAT_MSG_CHANNEL", Event_CHAT_MSG_CHANNEL)
	EC.Tool.RegisterEvent("CHAT_MSG_SAY", Event_CHAT_MSG_CHANNEL)
	EC.Tool.RegisterEvent("CHAT_MSG_YELL", Event_CHAT_MSG_CHANNEL)
	EC.Tool.RegisterEvent("CHAT_MSG_GUILD", Event_CHAT_MSG_CHANNEL)
	EC.Tool.RegisterEvent("CHAT_MSG_OFFICER", Event_CHAT_MSG_CHANNEL)
	EC.Tool.RegisterEvent("TRADE_SHOW", Event_TRADE_SHOW)
	EC.Tool.RegisterEvent("TRADE_CLOSED", Event_TRADE_CLOSED)
end
