local TOCNAME, EC = ...
Enchanter_Addon = EC

EC.Initalized = false
EC.PlayerList = {}
EC.LfRecipeList = {}
EC.LfRequestedRecipeCounts = {}
EC.SessionGold = 0
EC.DefaultMsg = "I can do "
EC.DefaultLfWhisperMsg = "What you looking for?"
EC.DefaultGroupedFollowUpMsg = 'You were in a group, but if you still need, please whisper "inv"! Thanks.'
EC.EnchanterTags = EC.DefaultEnchanterTags or {}
EC.PrefixTags = EC.DefaultPrefixTags or {}
EC.RecipeTags = EC.DefaultRecipeTags or {}
EC.RecipesWithNether = {"Enchant Boots - Surefooted"}
EC.PrefixTagsCompiled = {}
EC.BlacklistCompiled = {}
EC.RecipeTagsMap = {}
EC.RecipeTagList = {}
EC.RequestRecipeTagsMap = {}
EC.RequestRecipeTagList = {}
EC.PendingInvites = {}
EC.SimulatedPlayers = {}
EC.Simulation = EC.Simulation or {}

local pendingInviteWindow = 10
local simulationInterval = 180
local simulationSeeded = false
local simulationFallbackCounter = 0
local simulationNamePrefixes = {
	"SimAldren",
	"SimBrenna",
	"SimCorin",
	"SimDelia",
	"SimEdrin",
	"SimFiora",
	"SimGarrik",
	"SimHelia",
	"SimIvor",
	"SimJessa",
}
local simulationRealms = {
	"Workbench",
	"Tradesong",
	"Spellbarter",
	"Tipjar",
	"Enchantdesk",
	"Queueforge",
}
local simulationMessageTemplates = {
	"%s %s ench in tb tipping well!",
	"%s %s pst",
	"%s %s have mats already",
	"%s %s in shatt can come to you",
	"%s %s if you're around",
}

local function HasCraftRecipeApi()
	return GetNumCrafts and GetCraftInfo and GetCraftRecipeLink
end

local function HasTradeSkillRecipeApi()
	return GetNumTradeSkills and GetTradeSkillInfo and GetTradeSkillRecipeLink
end

local function GetRecipeApiCount(kind)
	if kind == "trade" and HasTradeSkillRecipeApi() then
		return math.max(0, math.floor(tonumber(GetNumTradeSkills and GetNumTradeSkills() or 0) or 0))
	end
	if kind == "craft" and HasCraftRecipeApi() then
		return math.max(0, math.floor(tonumber(GetNumCrafts and GetNumCrafts() or 0) or 0))
	end
	return 0
end

local function ResolveRecipeApiKind(preferredKind)
	local orderedKinds = {}
	local seenKinds = {}

	local function AddKind(kind)
		if kind and not seenKinds[kind] then
			seenKinds[kind] = true
			orderedKinds[#orderedKinds + 1] = kind
		end
	end

	AddKind(preferredKind)
	AddKind("trade")
	AddKind("craft")

	for _, kind in ipairs(orderedKinds) do
		if GetRecipeApiCount(kind) > 0 then
			return kind
		end
	end

	for _, kind in ipairs(orderedKinds) do
		if kind == "trade" and HasTradeSkillRecipeApi() then
			return kind
		end
		if kind == "craft" and HasCraftRecipeApi() then
			return kind
		end
	end

	return nil
end

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

local function GetRecipeApi(apiKind)
	apiKind = ResolveRecipeApiKind(apiKind)
	if apiKind == "trade" and HasTradeSkillRecipeApi() then
		return GetNumTradeSkills, GetTradeSkillInfo, GetTradeSkillRecipeLink
	end
	if apiKind == "craft" and HasCraftRecipeApi() then
		return GetNumCrafts, GetCraftInfo, GetCraftRecipeLink
	end
	return nil, nil, nil
end

local function GetRecipeSelectApi(apiKind)
	apiKind = ResolveRecipeApiKind(apiKind)
	if apiKind == "trade" and HasTradeSkillRecipeApi() and SelectTradeSkill then
		return SelectTradeSkill
	end
	if apiKind == "craft" and HasCraftRecipeApi() and SelectCraft then
		return SelectCraft
	end
	return nil
end

local function GetRecipeEntryType(index, apiKind)
	apiKind = ResolveRecipeApiKind(apiKind)
	if apiKind == "trade" and HasTradeSkillRecipeApi() then
		return select(2, GetTradeSkillInfo(index))
	end
	if apiKind == "craft" and HasCraftRecipeApi() then
		return select(3, GetCraftInfo(index))
	end
	return nil
end

local function IsRecipeHeader(index, apiKind)
	local entryType = GetRecipeEntryType(index, apiKind)
	return entryType == "header" or entryType == "subheader"
end

local function GetRecipeReagentApi(apiKind)
	apiKind = ResolveRecipeApiKind(apiKind)
	if apiKind == "trade" and GetNumTradeSkills and GetTradeSkillInfo and GetTradeSkillNumReagents and GetTradeSkillReagentInfo then
		return GetTradeSkillNumReagents, GetTradeSkillReagentInfo, GetTradeSkillReagentItemLink
	end
	if apiKind == "craft" and GetNumCrafts and GetCraftInfo and GetCraftNumReagents and GetCraftReagentInfo then
		return GetCraftNumReagents, GetCraftReagentInfo, GetCraftReagentItemLink
	end
	return nil, nil, nil
end

local function CaptureRecipeMaterials(recipeIndex, apiKind)
	local getNumReagents, getReagentInfo, getReagentLink = GetRecipeReagentApi(apiKind)
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

local function SnapshotTradeSkillFilters()
	local snapshot = {
		available = nil,
		subClass = {},
		invSlot = {},
		searchText = nil,
	}
	local subClassNames = { GetTradeSkillSubClasses and GetTradeSkillSubClasses() or nil }
	local invSlotNames = { GetTradeSkillInvSlots and GetTradeSkillInvSlots() or nil }

	if TradeSkillFrameAvailableFilterCheckButton and TradeSkillFrameAvailableFilterCheckButton.GetChecked then
		snapshot.available = TradeSkillFrameAvailableFilterCheckButton:GetChecked() and true or false
	end

	for index = 0, #subClassNames do
		if GetTradeSkillSubClassFilter then
			snapshot.subClass[index] = GetTradeSkillSubClassFilter(index)
		end
	end

	for index = 0, #invSlotNames do
		if GetTradeSkillInvSlotFilter then
			snapshot.invSlot[index] = GetTradeSkillInvSlotFilter(index)
		end
	end

	if TradeSearchInputBox and TradeSearchInputBox.GetText then
		snapshot.searchText = TradeSearchInputBox:GetText()
	end

	return snapshot
end

local function GetSelectedTradeSkillFilterIndex(filterValues)
	local selectedIndex = 0

	for index, selected in pairs(filterValues or {}) do
		local filterIndex = tonumber(index) or 0
		if filterIndex > 0 and (selected == 1 or selected == true) then
			return filterIndex
		end
		if filterIndex == 0 and (selected == 1 or selected == true) then
			selectedIndex = 0
		end
	end

	return selectedIndex
end

local function RestoreTradeSkillFilters(snapshot)
	if not snapshot then
		return
	end

	if snapshot.available ~= nil and TradeSkillOnlyShowMakeable then
		TradeSkillOnlyShowMakeable(snapshot.available)
		if TradeSkillFrameAvailableFilterCheckButton and TradeSkillFrameAvailableFilterCheckButton.SetChecked then
			TradeSkillFrameAvailableFilterCheckButton:SetChecked(snapshot.available)
		end
	end

	if SetTradeSkillSubClassFilter then
		SetTradeSkillSubClassFilter(GetSelectedTradeSkillFilterIndex(snapshot.subClass), 1, 1)
	end

	if SetTradeSkillInvSlotFilter then
		SetTradeSkillInvSlotFilter(GetSelectedTradeSkillFilterIndex(snapshot.invSlot), 1, 1)
	end

	if TradeSearchInputBox and TradeSearchInputBox.SetText then
		TradeSearchInputBox:SetText(snapshot.searchText or "")
	end
	if TradeSkillFilter_OnTextChanged and TradeSearchInputBox then
		TradeSkillFilter_OnTextChanged(TradeSearchInputBox)
	end
end

local function ClearTradeSkillFiltersForScan()
	if TradeSkillOnlyShowMakeable then
		TradeSkillOnlyShowMakeable(false)
		if TradeSkillFrameAvailableFilterCheckButton and TradeSkillFrameAvailableFilterCheckButton.SetChecked then
			TradeSkillFrameAvailableFilterCheckButton:SetChecked(false)
		end
	end

	if ExpandTradeSkillSubClass then
		ExpandTradeSkillSubClass(0)
	end
	if SetTradeSkillSubClassFilter then
		SetTradeSkillSubClassFilter(0, 1, 1)
	end
	if SetTradeSkillInvSlotFilter then
		SetTradeSkillInvSlotFilter(0, 1, 1)
	end

	if TradeSearchInputBox and TradeSearchInputBox.SetText then
		TradeSearchInputBox:SetText("")
	end
	if SetTradeSkillItemLevelFilter then
		SetTradeSkillItemLevelFilter(0, 0)
	end
	if SetTradeSkillItemNameFilter then
		SetTradeSkillItemNameFilter("")
	end
	if TradeSkillFilter_OnTextChanged and TradeSearchInputBox then
		TradeSkillFilter_OnTextChanged(TradeSearchInputBox)
	end
end

local function SnapshotCraftFilters()
	local snapshot = {
		available = nil,
		slot = 0,
	}
	local craftSlots = { GetCraftSlots and GetCraftSlots() or nil }

	if CraftFrameAvailableFilterCheckButton and CraftFrameAvailableFilterCheckButton.GetChecked then
		snapshot.available = CraftFrameAvailableFilterCheckButton:GetChecked() and true or false
	end

	if GetCraftFilter then
		for index = 0, #craftSlots do
			if GetCraftFilter(index) then
				snapshot.slot = index
				break
			end
		end
	end

	return snapshot
end

local function RestoreCraftFilters(snapshot)
	if not snapshot then
		return
	end

	if snapshot.available ~= nil and CraftOnlyShowMakeable then
		CraftOnlyShowMakeable(snapshot.available)
		if CraftFrameAvailableFilterCheckButton and CraftFrameAvailableFilterCheckButton.SetChecked then
			CraftFrameAvailableFilterCheckButton:SetChecked(snapshot.available)
		end
	end

	if snapshot.slot ~= nil and SetCraftFilter then
		SetCraftFilter(snapshot.slot)
	end
end

local function ClearCraftFiltersForScan()
	if CraftOnlyShowMakeable then
		CraftOnlyShowMakeable(false)
		if CraftFrameAvailableFilterCheckButton and CraftFrameAvailableFilterCheckButton.SetChecked then
			CraftFrameAvailableFilterCheckButton:SetChecked(false)
		end
	end
	if SetCraftFilter then
		SetCraftFilter(0)
	end
end

local function CountRecipeEntries(recipeMap)
	local count = 0
	if type(recipeMap) ~= "table" then
		return 0
	end

	for _ in pairs(recipeMap) do
		count = count + 1
	end

	return count
end

local function NormalizePhrase(value)
	if not value then
		return ""
	end
	return value:lower():gsub("[%W_]+", "")
end

local function TrimText(value)
	if not value then
		return ""
	end
	return tostring(value):gsub("^%s+", ""):gsub("%s+$", "")
end

local function SplitStoredCSV(value)
	local out = {}
	if not value or value == "" then
		return out
	end

	value = tostring(value):lower()

	if EC and EC.Tool and EC.Tool.Split then
		return EC.Tool.Split(value, ",")
	end

	for token in string.gmatch(value, "([^,]+)") do
		out[#out + 1] = token
	end

	return out
end

local function Now()
	if GetTime then
		return GetTime()
	end
	return 0
end

local function NormalizeNameKey(name)
	if not name then
		return ""
	end
	local cleaned = tostring(name):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
	cleaned = cleaned:gsub("^%s+", ""):gsub("%s+$", "")
	return cleaned:lower()
end

local function IsSimulatedCustomer(name)
	local key = NormalizeNameKey(name)
	return key ~= "" and EC.SimulatedPlayers[key] == true
end

local function MarkSimulatedCustomer(name)
	local key = NormalizeNameKey(name)
	if key ~= "" then
		EC.SimulatedPlayers[key] = true
	end
end

local function SeedSimulationRandom()
	if simulationSeeded then
		return
	end

	local seed = math.floor((Now() or 0) * 1000) + 1
	if date then
		local ok, timeStamp = pcall(date, "%Y%m%d%H%M%S")
		if ok and tonumber(timeStamp) then
			seed = seed + tonumber(timeStamp)
		end
	end

	local randomSeed = (math and math.randomseed) or randomseed
	local randomFn = (math and math.random) or random

	if type(randomSeed) == "function" then
		pcall(randomSeed, seed)
	end
	if type(randomFn) == "function" then
		pcall(randomFn)
		pcall(randomFn)
		pcall(randomFn)
	end
	simulationSeeded = true
end

local function PickRandomIndex(list)
	if type(list) ~= "table" or #list == 0 then
		return nil
	end

	SeedSimulationRandom()

	local randomFn = (math and math.random) or random
	local index

	if type(randomFn) == "function" then
		local ok, value = pcall(randomFn, #list)
		if ok then
			index = tonumber(value)
		end
	end

	if not index or index < 1 or index > #list then
		simulationFallbackCounter = simulationFallbackCounter + 1
		index = ((simulationFallbackCounter - 1) % #list) + 1
	end

	return math.floor(index)
end

local function PickRandom(list)
	local index = PickRandomIndex(list)
	if not index then
		return nil
	end
	return list[index]
end

local function GetSimulationRecipePool()
	local pool = {}

	for recipeName, tags in pairs(EC.DBChar and EC.DBChar.RecipeList or {}) do
		local usableTags = {}
		if type(tags) == "table" then
			for _, tag in ipairs(tags) do
				tag = TrimText(tag)
				if tag ~= "" then
					usableTags[#usableTags + 1] = tag
				end
			end
		end

		if type(recipeName) == "string" and recipeName ~= "" and #usableTags > 0 then
			pool[#pool + 1] = {
				Recipe = recipeName,
				Tags = usableTags,
			}
		end
	end

	table.sort(pool, function(left, right)
		return left.Recipe < right.Recipe
	end)

	return pool
end

local function BuildSimulatedCustomerName(simulationState)
	local generation = (simulationState.GeneratedCount or 0) + 1
	local prefixIndex = ((PickRandomIndex(simulationNamePrefixes) or 1) + generation - 2) % #simulationNamePrefixes + 1
	local realmIndex = ((PickRandomIndex(simulationRealms) or 1) + generation - 2) % #simulationRealms + 1
	return simulationNamePrefixes[prefixIndex] .. "-" .. simulationRealms[realmIndex]
end

local function BuildSimulatedMessage()
	local recipePool = GetSimulationRecipePool()
	if #recipePool == 0 then
		return nil, nil
	end

	local prefixPool = (type(EC.PrefixTags) == "table" and #EC.PrefixTags > 0) and EC.PrefixTags or { "lf", "need" }
	local selectedRecipe = PickRandom(recipePool)
	local selectedTag = selectedRecipe and PickRandom(selectedRecipe.Tags) or nil
	local selectedPrefix = PickRandom(prefixPool) or "lf"
	local template = PickRandom(simulationMessageTemplates) or "%s %s pst"

	if not selectedRecipe or not selectedTag or selectedTag == "" then
		return nil, nil
	end

	return BuildSimulatedCustomerName(EC.Simulation), string.format(template, selectedPrefix, selectedTag)
end

local function ScheduleSimulationTick(token)
	After(simulationInterval, function()
		if not EC.Simulation or not EC.Simulation.Running or EC.Simulation.Token ~= token then
			return
		end
		EC.GenerateSimulatedOrder("scheduled")
		ScheduleSimulationTick(token)
	end)
end

local function BuildGlobalStringPattern(template)
	if type(template) ~= "string" or template == "" then
		return nil
	end

	local pattern = template:gsub("([%(%)%.%%%+%-%*%?%[%]%^%$])", "%%%1")
	pattern = pattern:gsub("%%%d%$s", "(.+)")
	pattern = pattern:gsub("%%s", "(.+)")
	return "^" .. pattern .. "$"
end

local function MessageMatchesGroupedTemplate(message, customerName)
	local templates = {
		_G and _G.ERR_ALREADY_IN_GROUP_S,
		_G and _G.ERR_ALREADY_IN_GROUP_SS,
		_G and _G.ERR_ALREADY_IN_GROUP_GUID_S,
	}
	local normalizedCustomer = NormalizeNameKey(customerName)

	for _, template in ipairs(templates) do
		local pattern = BuildGlobalStringPattern(template)
		if pattern then
			local captures = { string.match(message, pattern) }
			if #captures == 0 and message == template then
				return true
			end
			for _, capture in ipairs(captures) do
				if NormalizeNameKey(capture) == normalizedCustomer then
					return true
				end
			end
		end
	end

	return false
end

local function IsAlreadyGroupedMessage(message, customerName)
	local normalizedMessage = NormalizePhrase(message)
	if normalizedMessage == "" then
		return false
	end

	if MessageMatchesGroupedTemplate(message, customerName) then
		return true
	end

	if string.find(normalizedMessage, "alreadyinagroup", 1, true) then
		local normalizedCustomer = NormalizePhrase(customerName)
		if normalizedCustomer == "" or string.find(normalizedMessage, normalizedCustomer, 1, true) then
			return true
		end
	end

	return false
end

local function PrunePendingInvites()
	local cutoff = Now() - pendingInviteWindow
	for key, pending in pairs(EC.PendingInvites) do
		if not pending or (pending.Timestamp or 0) < cutoff then
			EC.PendingInvites[key] = nil
		end
	end
end

function EC.GetMatchedRecipeNames(recipeMap)
	local out = {}
	local seen = {}
	if type(recipeMap) ~= "table" then
		return out
	end

	for key, value in pairs(recipeMap) do
		local recipeName
		if type(key) == "number" then
			recipeName = value
		else
			recipeName = key
		end

		if type(recipeName) == "string" and recipeName ~= "" and not seen[recipeName] then
			seen[recipeName] = true
			out[#out + 1] = recipeName
		end
	end

	table.sort(out)
	return out
end

function EC.DebugPrint(...)
	if not EC.DBChar or not EC.DBChar.Debug then
		return
	end

	local parts = {}
	for index = 1, select("#", ...) do
		parts[#parts + 1] = tostring(select(index, ...))
	end

	print("Debug mode:", table.concat(parts, " "))
end

local function AddRecipeTagsToLookup(tagMap, tagList, recipeName, tags)
	if type(recipeName) ~= "string" or recipeName == "" or type(tags) ~= "table" then
		return
	end

	for _, tag in ipairs(tags) do
		if tag and tag ~= "" then
			tagMap[tag] = recipeName
			tagList[#tagList + 1] = tag
		end
	end
end

local function GetConfiguredRecipeTags(recipeName)
	local customText = EC.DB and EC.DB.Custom and EC.DB.Custom[recipeName]
	if customText ~= nil and customText ~= "" then
		return SplitStoredCSV(customText)
	end

	if EC.RecipeTags and EC.RecipeTags["enGB"] then
		return EC.RecipeTags["enGB"][recipeName]
	end

	return nil
end

local function MatchRecipeTags(parsedMessage, tagList, tagMap)
	local matches = {}

	if type(parsedMessage) ~= "string" or parsedMessage == "" then
		return matches
	end

	for _, tag in ipairs(tagList or {}) do
		if string.find(parsedMessage, tag, 1, true) then
			local recipeName = tagMap[tag]
			if recipeName then
				matches[recipeName] = tag
			end
		end
	end

	return matches
end

local function GetRecipeRequestDetails(parsedMessage)
	local matchedRecipeMap = MatchRecipeTags(parsedMessage, EC.RecipeTagList, EC.RecipeTagsMap)
	local requestedRecipeMap = MatchRecipeTags(parsedMessage, EC.RequestRecipeTagList, EC.RequestRecipeTagsMap)
	local matchedCount = CountRecipeEntries(matchedRecipeMap)
	local requestedCount = math.max(matchedCount, CountRecipeEntries(requestedRecipeMap))

	return matchedRecipeMap, matchedCount, requestedCount
end

function EC.BuildRecipeWhisper(recipeNames, requestedRecipeCount)
	local matchedRecipeNames = EC.GetMatchedRecipeNames(recipeNames)
	local msg = EC.DB.MsgPrefix or EC.DefaultMsg
	local matchedCount = #matchedRecipeNames
	local requestedCount = math.max(matchedCount, math.floor(tonumber(requestedRecipeCount) or 0))

	if EC.DB.WarnIncompleteOrder ~= false and requestedCount > matchedCount then
		msg = msg .. matchedCount .. "/" .. requestedCount .. " "
	end

	for _, recipeName in ipairs(matchedRecipeNames) do
		msg = msg .. (EC.DBChar.RecipeLinks[recipeName] or ("[" .. recipeName .. "] "))
	end

	return msg
end

function EC.SendRecipeWhisperTo(name, recipeNames, sourceLabel, requestedRecipeCount)
	local msg = EC.BuildRecipeWhisper(recipeNames, requestedRecipeCount)

	if IsSimulatedCustomer(name) then
		EC.DebugPrint((sourceLabel or "simulated whisper") .. " to " .. name .. ": " .. msg)
	elseif EC.DBChar.Debug then
		EC.DebugPrint((sourceLabel or "would whisper") .. " to " .. name .. ": " .. msg)
	else
		SendChatMessage(msg, "WHISPER", nil, name)
	end

	return msg
end

function EC.SendGroupedFollowUp(name, sourceLabel)
	local msg = EC.DB.GroupedFollowUpMsg or EC.DefaultGroupedFollowUpMsg

	if IsSimulatedCustomer(name) then
		EC.DebugPrint((sourceLabel or "simulated grouped-followup") .. " to " .. name .. ": " .. msg)
	elseif EC.DBChar.Debug then
		EC.DebugPrint((sourceLabel or "would grouped-followup") .. " to " .. name .. ": " .. msg)
	else
		SendChatMessage(msg, "WHISPER", nil, name)
	end

	return msg
end

function EC.InviteCustomer(name, sourceLabel)
	if not name or name == "" then
		return
	end

	if IsSimulatedCustomer(name) then
		EC.DebugPrint((sourceLabel or "simulated invite") .. " " .. name)
		return
	end

	PrunePendingInvites()
	EC.PendingInvites[NormalizeNameKey(name)] = {
		Name = name,
		Timestamp = Now(),
	}

	if EC.DBChar.Debug then
		EC.DebugPrint((sourceLabel or "would invite") .. " " .. name)
	else
		InvitePlayer(name)
	end
end

function EC.HandleInviteFailureMessage(message)
	if not EC.DB or not EC.DB.GroupedFollowUp then
		return false
	end
	if type(message) ~= "string" or message == "" then
		return false
	end

	PrunePendingInvites()

	local matchedPending
	local pendingCount = 0
	local latestPending

	for _, pending in pairs(EC.PendingInvites) do
		if pending and pending.Name then
			pendingCount = pendingCount + 1
			if not latestPending or (pending.Timestamp or 0) > (latestPending.Timestamp or 0) then
				latestPending = pending
			end
			if IsAlreadyGroupedMessage(message, pending.Name) then
				matchedPending = pending
				break
			end
		end
	end

	if not matchedPending and pendingCount == 1 and latestPending and IsAlreadyGroupedMessage(message, nil) then
		matchedPending = latestPending
	end

	if not matchedPending then
		return false
	end

	EC.PendingInvites[NormalizeNameKey(matchedPending.Name)] = nil
	EC.DebugPrint("detected already-grouped invite failure for", matchedPending.Name)
	After(EC.DB.GroupedFollowUpDelay, function()
		EC.SendGroupedFollowUp(matchedPending.Name, "grouped follow-up")
	end)
	return true
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
	if EC.DB.WarnIncompleteOrder == nil then EC.DB.WarnIncompleteOrder = true end
	if EC.DB.InviteIncompleteOrder == nil then EC.DB.InviteIncompleteOrder = true end
	if EC.DB.NetherRecipes == nil then EC.DB.NetherRecipes = false end
	if EC.DB.WhisperLfRequests == nil then EC.DB.WhisperLfRequests = false end
	if EC.DB.GroupedFollowUp == nil then EC.DB.GroupedFollowUp = false end
	if EC.DB.InviteTimeDelay == nil then EC.DB.InviteTimeDelay = 0 end
	if EC.DB.WhisperTimeDelay == nil then EC.DB.WhisperTimeDelay = 0 end
	if EC.DB.GroupedFollowUpDelay == nil then EC.DB.GroupedFollowUpDelay = 1 end
	if not EC.DB.MsgPrefix or EC.DB.MsgPrefix == "" then EC.DB.MsgPrefix = EC.DefaultMsg end
	if not EC.DB.LfWhisperMsg or EC.DB.LfWhisperMsg == "" then EC.DB.LfWhisperMsg = EC.DefaultLfWhisperMsg end
	if not EC.DB.GroupedFollowUpMsg or EC.DB.GroupedFollowUpMsg == "" then EC.DB.GroupedFollowUpMsg = EC.DefaultGroupedFollowUpMsg end
	if EC.Workbench and EC.Workbench.EnsureState then EC.Workbench.EnsureState() end
end

function EC.RefreshCompiledData()
	EC.PrefixTagsCompiled = {}
	EC.BlacklistCompiled = {}
	EC.RecipeTagsMap = {}
	EC.RecipeTagList = {}
	EC.RequestRecipeTagsMap = {}
	EC.RequestRecipeTagList = {}

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

	for recipeName in pairs(EC.RecipeTags and EC.RecipeTags["enGB"] or {}) do
		AddRecipeTagsToLookup(EC.RequestRecipeTagsMap, EC.RequestRecipeTagList, recipeName, GetConfiguredRecipeTags(recipeName))
	end

	for recipeName, tags in pairs(EC.DBChar.RecipeList or {}) do
		AddRecipeTagsToLookup(EC.RecipeTagsMap, EC.RecipeTagList, recipeName, tags)
	end

	if EC.Workbench and EC.Workbench.Refresh then
		EC.Workbench.Refresh()
	end
end

function EC.GetItems()
	local function CountScannedRecipes(recipeList)
		return CountRecipeEntries(recipeList)
	end

	local function ApplyNetherRecipeFilter(recipeList, recipeLinks, recipeMats)
		if not EC.DB.NetherRecipes then
			return
		end

		for _, recipeName in ipairs(EC.RecipesWithNether) do
			recipeList[recipeName] = nil
			recipeLinks[recipeName] = nil
			recipeMats[recipeName] = nil
		end
	end

	local function CaptureRecipesForApi(apiKind)
		local getCount, getInfo, getLink = GetRecipeApi(apiKind)
		local selectRecipe = GetRecipeSelectApi(apiKind)
		local restoreFilters
		local recipeList = {}
		local recipeLinks = {}
		local recipeMats = {}

		if not getCount or not getInfo then
			return false, recipeList, recipeLinks, recipeMats, 0
		end

		if apiKind == "trade" then
			restoreFilters = SnapshotTradeSkillFilters()
			ClearTradeSkillFiltersForScan()
		elseif apiKind == "craft" then
			restoreFilters = SnapshotCraftFilters()
			ClearCraftFiltersForScan()
		end

		for index = 1, getCount() or 0 do
			local recipeName = getInfo(index)
			if recipeName and not IsRecipeHeader(index, apiKind) and EC.RecipeTags["enGB"][recipeName] then
				if selectRecipe then
					selectRecipe(index)
				end
				recipeLinks[recipeName] = getLink and getLink(index) or nil
				recipeMats[recipeName] = CaptureRecipeMaterials(index, apiKind)
				recipeList[recipeName] = EC.RecipeTags["enGB"][recipeName]
			end
		end

		if apiKind == "trade" then
			RestoreTradeSkillFilters(restoreFilters)
		elseif apiKind == "craft" then
			RestoreCraftFilters(restoreFilters)
		end

		ApplyNetherRecipeFilter(recipeList, recipeLinks, recipeMats)
		return true, recipeList, recipeLinks, recipeMats, CountScannedRecipes(recipeList)
	end

	local orderedKinds = {}
	local seenKinds = {}
	local bestRecipeCount = -1
	local bestRecipeList = {}
	local bestRecipeLinks = {}
	local bestRecipeMats = {}
	local triedAnyApi = false

	local function AddApiKind(kind)
		if kind and not seenKinds[kind] then
			seenKinds[kind] = true
			orderedKinds[#orderedKinds + 1] = kind
		end
	end

	if CastSpellByName then
		CastSpellByName("Enchanting")
	end

	AddApiKind(ResolveRecipeApiKind("trade"))
	AddApiKind("trade")
	AddApiKind("craft")

	for _, apiKind in ipairs(orderedKinds) do
		local ok, recipeList, recipeLinks, recipeMats, recipeCount = CaptureRecipesForApi(apiKind)
		if ok then
			triedAnyApi = true
			if recipeCount > bestRecipeCount then
				bestRecipeCount = recipeCount
				bestRecipeList = recipeList
				bestRecipeLinks = recipeLinks
				bestRecipeMats = recipeMats
			end
			if recipeCount > 0 then
				break
			end
		end
	end

	if not triedAnyApi then
		print("|cFFFF1C1CEnchanter|r could not find a supported enchanting scan API on this client.")
		return false
	end

	EC.DBChar.RecipeList = bestRecipeList
	EC.DBChar.RecipeLinks = bestRecipeLinks
	EC.DBChar.RecipeMats = bestRecipeMats

	EC.UpdateTags()
	EC.RefreshCompiledData()
	return bestRecipeCount > 0
end

function EC.GenerateSimulatedOrder(sourceLabel)
	local customerName, message = BuildSimulatedMessage()
	if not customerName or not message then
		print("|cFFFF1C1CEnchanter|r Run /ec scan before using /ec simulate so fake orders can target your known enchants.")
		return false
	end

	MarkSimulatedCustomer(customerName)
	EC.Simulation.GeneratedCount = (EC.Simulation.GeneratedCount or 0) + 1

	local wasStopped = EC.DBChar and EC.DBChar.Stop
	if EC.DBChar then
		EC.DBChar.Stop = false
	end
	EC.ParseMessage(message, customerName)
	if EC.DBChar then
		EC.DBChar.Stop = wasStopped
	end

	if EC.Workbench and EC.Workbench.Refresh then
		EC.Workbench.Refresh()
	end

	print("|cFFFF1C1CEnchanter|r Simulated order from " .. customerName .. ": " .. message)
	EC.DebugPrint("[Simulate] queued", customerName, "via", sourceLabel or "manual")
	return true
end

function EC.StartSimulation()
	if #GetSimulationRecipePool() == 0 then
		print("|cFFFF1C1CEnchanter|r Run /ec scan before starting /ec simulate so fake orders can target your known enchants.")
		return false
	end

	if EC.Simulation.Running then
		print("|cFFFF1C1CEnchanter|r Workbench simulation is already running.")
		return true
	end

	EC.Simulation.Running = true
	EC.Simulation.Token = (EC.Simulation.Token or 0) + 1

	print("|cFFFF1C1CEnchanter|r Workbench simulation started. One fake order will be generated every 3 minutes.")
	EC.GenerateSimulatedOrder("start")
	ScheduleSimulationTick(EC.Simulation.Token)
	return true
end

function EC.StopSimulation()
	if not EC.Simulation.Running then
		print("|cFFFF1C1CEnchanter|r Workbench simulation is already stopped.")
		return false
	end

	EC.Simulation.Running = false
	EC.Simulation.Token = (EC.Simulation.Token or 0) + 1
	print("|cFFFF1C1CEnchanter|r Workbench simulation stopped.")
	return true
end

function EC.ToggleSimulation()
	if EC.Simulation.Running then
		return EC.StopSimulation()
	end
	return EC.StartSimulation()
end

function EC.IsChatScanningEnabled()
	return EC.DBChar ~= nil and EC.DBChar.Stop ~= true
end

function EC.SetChatScanningEnabled(enabled)
	if not EC.DBChar then
		return false
	end

	enabled = enabled and true or false
	EC.DBChar.Stop = not enabled

	if EC.Workbench and EC.Workbench.Refresh then
		EC.Workbench.Refresh()
	end

	print(enabled and "Started..." or "Paused")
	return enabled
end

function EC.ToggleChatScanning()
	return EC.SetChatScanningEnabled(not EC.IsChatScanningEnabled())
end

function EC.NeedsRecipeScan()
	if not EC.DBChar then
		return true
	end

	local recipeList = EC.DBChar.RecipeList or {}
	local recipeCount = 0

	for _ in pairs(recipeList) do
		recipeCount = recipeCount + 1
	end

	return recipeCount == 0
end

local function DoScan()
	if EC.GetItems() then
		print("Scan Completed")
		return true
	end
	print("|cFFFF1C1CEnchanter|r Scan found no supported enchanting recipes. Clear profession filters or search text, then try again.")
	return false
end

function EC.RunRecipeScan()
	return DoScan() and not EC.NeedsRecipeScan()
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
			EC.RunRecipeScan()
		end},
		{{"stop", "pause"}, "Pauses addon scanning", function()
			EC.SetChatScanningEnabled(false)
		end},
		{"start", "Starts chat scanning", function()
			EC.SetChatScanningEnabled(true)
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
		{"simulate", "Toggle fake workbench orders for testing. Starts one now, then queues another every 3 minutes.", {
			{"", "Starts or stops fake workbench orders.", function()
				EC.ToggleSimulation()
			end},
			{{"now", "once"}, "Queues one fake order immediately without changing the running timer.", function()
				EC.GenerateSimulatedOrder("manual")
			end},
			{"stop", "Stops fake workbench orders.", function()
				EC.StopSimulation()
			end},
		}},
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
		EC.LfRequestedRecipeCounts[name] = nil
		return
	end

	EC.SendRecipeWhisperTo(name, EC.LfRecipeList[name], "would whisper", EC.LfRequestedRecipeCounts[name])

	EC.LfRecipeList[name] = nil
	EC.LfRequestedRecipeCounts[name] = nil
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
				EC.DebugPrint("Request:", msg, "is being blacklisted due to pattern:", pattern)
			end
			return
		end
	end

	local matchedRecipeMap, matchedRecipeCount, requestedRecipeCount = GetRecipeRequestDetails(parsedMessage)
	local matchedRecipes = matchedRecipeCount > 0

	if matchedRecipes then
		local isIncompleteOrder = requestedRecipeCount > matchedRecipeCount

		if EC.DBChar.Debug then
			EC.DebugPrint("User should be invited for msg:", msg)
			EC.DebugPrint("Matched", tostring(matchedRecipeCount), "recipe(s) out of", tostring(requestedRecipeCount), "requested")
		end

		if EC.Workbench and EC.Workbench.AddOrUpdateOrder then
			EC.Workbench.AddOrUpdateOrder(name, msg, matchedRecipeMap, requestedRecipeCount)
		end

		if EC.PlayerList[name] == nil then
			if isIncompleteOrder and EC.DB.InviteIncompleteOrder == false then
				EC.LfRecipeList[name] = nil
				EC.LfRequestedRecipeCounts[name] = nil
				if EC.DBChar.Debug then
					EC.DebugPrint("left incomplete order unflagged for " .. name .. " (" .. tostring(matchedRecipeCount) .. "/" .. tostring(requestedRecipeCount) .. ")")
				end
			else
				EC.LfRecipeList[name] = matchedRecipeMap
				EC.LfRequestedRecipeCounts[name] = requestedRecipeCount
				EC.PlayerList[name] = 1

				if EC.DBChar.Debug then
					EC.DebugPrint("suppressed invite/whisper to " .. name)
					EC.SendMsg(name)
				else
					if EC.DB.AutoInvite then
						After(EC.DB.InviteTimeDelay, function()
							EC.InviteCustomer(name)
						end)
					end
					After(EC.DB.WhisperTimeDelay, function()
						EC.SendMsg(name)
					end)
				end
			end
		else
			EC.LfRecipeList[name] = nil
			EC.LfRequestedRecipeCounts[name] = nil
		end
		return
	end

	if EC.DB.WhisperLfRequests and EC.PlayerList[name] == nil then
		local normalizedMessage = NormalizePhrase(parsedMessage)
		for _, tag in ipairs(EC.EnchanterTags or {}) do
			if NormalizePhrase(tag) == normalizedMessage then
				EC.PlayerList[name] = 1
				local genericReply = EC.DB.LfWhisperMsg or EC.DefaultLfWhisperMsg
				if IsSimulatedCustomer(name) then
					EC.DebugPrint("suppressed generic whisper to " .. name .. ": " .. genericReply)
				elseif EC.DBChar.Debug then
					EC.DebugPrint("would whisper to " .. name .. ": " .. genericReply)
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
	if EC.Workbench and EC.Workbench.BeginTrade then
		EC.Workbench.BeginTrade(EC.Workbench.GetTradePartnerName and EC.Workbench.GetTradePartnerName() or nil)
	end
end

local function Event_TRADE_STATE_CHANGED()
	if EC.Workbench and EC.Workbench.SyncActiveTrade then
		EC.Workbench.SyncActiveTrade()
	end
end

local function Event_TRADE_ACCEPT_UPDATE(playerAccepted, targetAccepted)
	if EC.Workbench and EC.Workbench.SetTradeAcceptState then
		EC.Workbench.SetTradeAcceptState(playerAccepted, targetAccepted)
	end
	if EC.Workbench and EC.Workbench.SyncActiveTrade then
		EC.Workbench.SyncActiveTrade()
	end
end

local function Event_TRADE_CLOSED()
	if EC.Workbench and EC.Workbench.FinishTrade then
		EC.Workbench.FinishTrade(0)
	end
end

local function Event_CHAT_MSG_CHANNEL(msg, name)
	if not EC.Initalized then
		return
	end
	EC.ParseMessage(msg, name)
end

local function Event_CHAT_MSG_SYSTEM(msg)
	if msg == ERR_TRADE_COMPLETE and EC.Workbench and EC.Workbench.MarkTradeCompleted then
		EC.Workbench.MarkTradeCompleted()
	end
	EC.HandleInviteFailureMessage(msg)
end

local function Event_UI_ERROR_MESSAGE(arg1, arg2, arg3)
	local message
	if type(arg1) == "string" then
		message = arg1
	elseif type(arg2) == "string" then
		message = arg2
	elseif type(arg3) == "string" then
		message = arg3
	end
	EC.HandleInviteFailureMessage(message)
end

local function Event_UI_INFO_MESSAGE(arg1, arg2, arg3)
	local message
	if type(arg1) == "string" then
		message = arg1
	elseif type(arg2) == "string" then
		message = arg2
	elseif type(arg3) == "string" then
		message = arg3
	end

	if message == ERR_TRADE_COMPLETE and EC.Workbench and EC.Workbench.MarkTradeCompleted then
		EC.Workbench.MarkTradeCompleted()
	end
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
	EC.Tool.RegisterEvent("CHAT_MSG_SYSTEM", Event_CHAT_MSG_SYSTEM)
	EC.Tool.RegisterEvent("UI_ERROR_MESSAGE", Event_UI_ERROR_MESSAGE)
	EC.Tool.RegisterEvent("UI_INFO_MESSAGE", Event_UI_INFO_MESSAGE)
	EC.Tool.RegisterEvent("TRADE_SHOW", Event_TRADE_SHOW)
	EC.Tool.RegisterEvent("TRADE_MONEY_CHANGED", Event_TRADE_STATE_CHANGED)
	EC.Tool.RegisterEvent("TRADE_TARGET_ITEM_CHANGED", Event_TRADE_STATE_CHANGED)
	EC.Tool.RegisterEvent("TRADE_PLAYER_ITEM_CHANGED", Event_TRADE_STATE_CHANGED)
	EC.Tool.RegisterEvent("TRADE_ACCEPT_UPDATE", Event_TRADE_ACCEPT_UPDATE)
	EC.Tool.RegisterEvent("TRADE_UPDATE", Event_TRADE_STATE_CHANGED)
	EC.Tool.RegisterEvent("TRADE_CLOSED", Event_TRADE_CLOSED)
end
