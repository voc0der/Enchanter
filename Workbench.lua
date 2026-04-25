local TOCNAME, EC = ...

EC.Workbench = EC.Workbench or {}
local Workbench = EC.Workbench

local DEFAULT_FRAME_WIDTH = 468
local DEFAULT_FRAME_HEIGHT = 520
local MIN_FRAME_WIDTH = 440
local MIN_FRAME_HEIGHT = 420
local MAX_FRAME_WIDTH = 960
local MAX_FRAME_HEIGHT = 960
local MIN_QUEUE_HEIGHT = 160
local DETAIL_RESERVED_HEIGHT = 220
local ORDER_EXPIRY_TIMER_BUFFER = 0.05
local QUEUE_ALERT_SOUND_CHANNEL = "Master"
local LOCK_BUTTON_ICON_TEXTURE = "Interface\\PetBattles\\PetBattle-LockIcon"
local LOCK_BUTTON_UNLOCKED_TEXTURE = "Interface\\Buttons\\UI-CheckBox-Check"
local SOUND_BUTTON_ICON_TEXTURE = "Interface\\Common\\VoiceChat-Speaker"
local SOUND_BUTTON_ON_TEXTURE = "Interface\\Common\\VoiceChat-On"
local SOUND_BUTTON_MUTED_TEXTURE = "Interface\\Common\\VoiceChat-Muted"
local DISENCHANT_ORDER_ICON_TEXTURE = "Interface\\Icons\\INV_Enchant_Disenchant"
local LOCKBOX_ORDER_ICON_TEXTURE = "Interface\\Icons\\INV_Misc_Lockbox_01"
local CONFIG_BUTTON_ICON_ATLAS = "OptionsIcon-Brown"
local ORDER_ALERT_SOUND_FALLBACKS = {
	{ key = "IG_MAINMENU_OPTION_CHECKBOX_ON", id = 856, legacy = "igMainMenuOptionCheckBoxOn" },
	{ key = "U_CHAT_SCROLL_BUTTON", id = 1115, legacy = "UChatScrollButton" },
	{ key = "IG_CHARACTER_INFO_OPEN", id = 839, legacy = "igCharacterInfoOpen" },
	{ key = "AUCTION_WINDOW_OPEN", id = 5274, legacy = "AuctionWindowOpen" },
}
local LOUD_ORDER_ALERT_SOUND_FALLBACKS = {
	{ key = "READY_CHECK", id = 8960, legacy = "ReadyCheck" },
	{ key = "PVP_ENTER_QUEUE", id = 8458, legacy = "PVPEnterQueue" },
	{ key = "RAID_WARNING", id = 8959, legacy = "RaidWarning" },
	{ key = "LFG_ROLE_CHECK", id = 17317, legacy = "LFGRoleCheck" },
}
local QUEUE_ALERT_SOUND_LOUD_CHANNEL = "Master"
local TRADE_CAST_RETRY_DELAYS = { 0.2, 0.5, 1.0 }

local ElvUIEngine, ElvUISkins

local function WorkbenchDebug(...)
	if EC and EC.DebugPrint then
		EC.DebugPrint("[Workbench]", ...)
	end
end

local function ClampNumber(value, minimumValue, maximumValue)
	value = tonumber(value) or minimumValue
	if minimumValue and value < minimumValue then
		value = minimumValue
	end
	if maximumValue and value > maximumValue then
		value = maximumValue
	end
	return value
end

local function IsElvUILoaded()
	if not ElvUI then
		return false
	end

	local unpackTable = unpack or table.unpack
	if not unpackTable then
		return false
	end

	local ok, engine = pcall(function()
		return unpackTable(ElvUI)
	end)
	if not ok or not engine or not engine.GetModule then
		return false
	end

	ElvUIEngine = engine
	ElvUISkins = ElvUIEngine:GetModule("Skins", true)
	return ElvUISkins ~= nil
end

local function ApplyElvUISkin(frame, frameType)
	if not frame or not IsElvUILoaded() then
		return
	end

	frame._ECElvUISkinned = frame._ECElvUISkinned or {}
	if frame._ECElvUISkinned[frameType] then
		return
	end

	if frameType == "frame" and ElvUISkins.HandleFrame then
		ElvUISkins:HandleFrame(frame, true)
	elseif frameType == "button" and ElvUISkins.HandleButton then
		ElvUISkins:HandleButton(frame)
	elseif frameType == "checkbox" and ElvUISkins.HandleCheckBox then
		ElvUISkins:HandleCheckBox(frame)
	elseif frameType == "scrollbar" and ElvUISkins.HandleScrollBar then
		ElvUISkins:HandleScrollBar(frame)
	else
		return
	end

	frame._ECElvUISkinned[frameType] = true
end

local function FormatClockTime(hours, minutes)
	hours = tonumber(hours) or 0
	minutes = tonumber(minutes) or 0

	if GetCVarBool and GetCVarBool("timeMgrUseMilitaryTime") then
		local twentyFourHourTemplate = _G and _G.TIME_TWENTYFOURHOURS
		if type(twentyFourHourTemplate) == "string" and twentyFourHourTemplate ~= "" then
			local ok, formatted = pcall(string.format, twentyFourHourTemplate, hours, minutes)
			if ok and type(formatted) == "string" and formatted ~= "" then
				return formatted
			end
		end
		return string.format("%02d:%02d", hours % 24, minutes % 60)
	end

	local isPM = hours >= 12
	local displayHour = hours % 12
	if displayHour == 0 then
		displayHour = 12
	end

	local twelveHourTemplate = isPM and (_G and _G.TIME_TWELVEHOURPM) or (_G and _G.TIME_TWELVEHOURAM)
	if type(twelveHourTemplate) == "string" and twelveHourTemplate ~= "" then
		local ok, formatted = pcall(string.format, twelveHourTemplate, displayHour, minutes)
		if ok and type(formatted) == "string" and formatted ~= "" then
			return formatted
		end
	end

	return string.format("%d:%02d %s", displayHour, minutes, isPM and "PM" or "AM")
end

local function GetLocalClockParts()
	if date then
		local ok, timeTable = pcall(date, "*t")
		if ok and type(timeTable) == "table" and timeTable.hour ~= nil and timeTable.min ~= nil then
			return timeTable.hour, timeTable.min
		end
	end
	if os and os.date then
		local timeTable = os.date("*t")
		if type(timeTable) == "table" and timeTable.hour ~= nil and timeTable.min ~= nil then
			return timeTable.hour, timeTable.min
		end
	end
	return nil, nil
end

local function TimestampText()
	local localHours, localMinutes = GetLocalClockParts()
	if localHours ~= nil and localMinutes ~= nil then
		return FormatClockTime(localHours, localMinutes)
	end

	if GetGameTime then
		local gameHours, gameMinutes = GetGameTime()
		if gameHours ~= nil and gameMinutes ~= nil then
			return FormatClockTime(gameHours, gameMinutes)
		end
	end

	if GetTime then
		local totalSeconds = math.floor(GetTime())
		local minutes = math.floor(totalSeconds / 60)
		local hours = math.floor(minutes / 60)
		return FormatClockTime(hours % 24, minutes % 60)
	end

	return "--:--"
end

local function NormalizeTimestampText(value)
	if type(value) ~= "string" or value == "" then
		return TimestampText()
	end

	local hours, minutes = value:match("^(%d%d?):(%d%d)$")
	if hours and minutes then
		hours = tonumber(hours)
		minutes = tonumber(minutes)
		if hours and minutes and hours >= 0 and hours <= 23 and minutes >= 0 and minutes <= 59 then
			return FormatClockTime(hours, minutes)
		end
	end

	return value
end

local function SetRegionShown(region, shouldShow)
	if not region then
		return
	end

	if region.SetShown then
		region:SetShown(shouldShow and true or false)
	elseif shouldShow then
		if region.Show then
			region:Show()
		end
	elseif region.Hide then
		region:Hide()
	end
end

local function IsRegionShown(region)
	if not region then
		return false
	end

	if region.IsShown then
		return region:IsShown()
	end

	return region.shown ~= false
end

local function IsWorkbenchFrameShown(frame)
	frame = frame or Workbench.Frame
	if not frame then
		return false
	end

	if frame.IsShown then
		return frame:IsShown() and true or false
	end

	return frame.shown ~= false
end

local function TrimText(value)
	if not value then
		return ""
	end
	return tostring(value):gsub("^%s+", ""):gsub("%s+$", "")
end

local function Now()
	if GetTime then
		return GetTime()
	end
	return 0
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

local function GetWorkbenchTitleText()
	local version = TrimText(GetAddOnMetadataCompat(TOCNAME, "Version"))
	if version ~= "" then
		return "Enchanter v" .. version .. " Workbench"
	end

	return "Enchanter Workbench"
end

local function FormatMoneyCompact(copper)
	copper = math.max(0, math.floor(tonumber(copper) or 0))

	local gold = math.floor(copper / 10000)
	local silver = math.floor((copper % 10000) / 100)
	local coin = copper % 100
	local parts = {}

	if gold > 0 then
		parts[#parts + 1] = tostring(gold) .. "g"
	end
	if silver > 0 then
		parts[#parts + 1] = tostring(silver) .. "s"
	end
	if coin > 0 then
		parts[#parts + 1] = tostring(coin) .. "c"
	end

	if #parts == 0 then
		return "0g"
	end

	return table.concat(parts, " ")
end

local function ParseMoneyCompact(value)
	value = TrimText(value)
	if value == "" then
		return 0
	end

	local normalized = value:lower():gsub(",", ""):gsub("%s+", "")
	if normalized:match("^%d+$") then
		return (tonumber(normalized) or 0) * 10000
	end

	local total = 0
	local matched = false
	for amount, unit in normalized:gmatch("(%d+)([gsc])") do
		local numericAmount = tonumber(amount) or 0
		if unit == "g" then
			total = total + (numericAmount * 10000)
		elseif unit == "s" then
			total = total + (numericAmount * 100)
		elseif unit == "c" then
			total = total + numericAmount
		end
		matched = true
	end

	if matched then
		return total
	end

	return nil
end

local function GetLegacyTipCopper(order)
	if not order then
		return 0
	end

	local pendingTipText = TrimText(order.PendingTipText)
	if pendingTipText == "" then
		return 0
	end

	local tipCopper = ParseMoneyCompact(pendingTipText)
	if tipCopper == nil then
		return 0
	end

	return math.max(0, math.floor(tipCopper))
end

local function GetRecordedTipCopper(order)
	if not order then
		return 0
	end

	local observedTipCopper = math.max(0, math.floor(tonumber(order.LastObservedTipCopper) or 0))
	if observedTipCopper > 0 then
		return observedTipCopper
	end

	return GetLegacyTipCopper(order)
end

local function GetResolvedTipCopper(order)
	local recordedTipCopper = GetRecordedTipCopper(order)
	if recordedTipCopper > 0 then
		return recordedTipCopper, true
	end

	if order and order.NoTipConfirmed then
		return 0, true
	end

	return 0, false
end

local function NormalizeItemCount(value)
	return math.max(0, math.floor(tonumber(value) or 0))
end

local function CopyNormalizedCountTable(source)
	local copy = {}

	if type(source) ~= "table" then
		return copy
	end

	for key, value in pairs(source) do
		local normalized = NormalizeItemCount(value)
		if type(key) == "string" and key ~= "" and normalized > 0 then
			copy[key] = normalized
		end
	end

	return copy
end

local function CountTableHasPositiveCounts(source)
	if type(source) ~= "table" then
		return false
	end

	for _, value in pairs(source) do
		if NormalizeItemCount(value) > 0 then
			return true
		end
	end

	return false
end

local function GetRequiredMaterialCount(material)
	local requiredCount = NormalizeItemCount(material and material.Count or 0)
	if requiredCount > 0 then
		return requiredCount
	end
	return 1
end

local function GetRecordedMaterialCount(order, material, requiredCount)
	local materialKey
	local storedCount
	local fallbackKeys = {}

	if not order or not material then
		return 0
	end

	requiredCount = math.max(1, NormalizeItemCount(requiredCount or GetRequiredMaterialCount(material)))
	materialKey = type(material) == "table" and material.Key or material
	storedCount = NormalizeItemCount(order.MaterialCounts and order.MaterialCounts[materialKey] or 0)
	if storedCount <= 0 and order.MaterialState and order.MaterialState[materialKey] then
		storedCount = requiredCount
	end
	if storedCount <= 0 and type(material) == "table" then
		fallbackKeys = { material.Name, material.Link }
		for _, fallbackKey in ipairs(fallbackKeys) do
			if fallbackKey and fallbackKey ~= "" and fallbackKey ~= materialKey then
				storedCount = NormalizeItemCount(order.MaterialCounts and order.MaterialCounts[fallbackKey] or 0)
				if storedCount <= 0 and order.MaterialState and order.MaterialState[fallbackKey] then
					storedCount = requiredCount
				end
				if storedCount > 0 then
					break
				end
			end
		end
	end
	return math.min(requiredCount, storedCount)
end

local function SetRecordedMaterialCount(order, materialKey, count, requiredCount)
	if not order or not materialKey or materialKey == "" then
		return 0
	end

	count = NormalizeItemCount(count)
	requiredCount = math.max(1, NormalizeItemCount(requiredCount))
	count = math.min(requiredCount, count)

	order.MaterialCounts = order.MaterialCounts or {}
	order.MaterialState = order.MaterialState or {}
	order.MaterialCounts[materialKey] = count > 0 and count or nil
	order.MaterialState[materialKey] = count >= requiredCount and true or nil
	return count
end

local function GetManuallyRecordedTradeMaterialCount(activeTrade, materialKey)
	if not activeTrade or type(activeTrade.ManuallyRecordedMaterialCounts) ~= "table" then
		return 0
	end
	return NormalizeItemCount(activeTrade.ManuallyRecordedMaterialCounts[materialKey] or 0)
end

local function GetDisplayedTradeMaterialCount(activeTrade, materialKey)
	local offeredCount = NormalizeItemCount(activeTrade and activeTrade.OfferedMaterialCounts and activeTrade.OfferedMaterialCounts[materialKey] or 0)
	local recordedCount = GetManuallyRecordedTradeMaterialCount(activeTrade, materialKey)
	return math.max(0, offeredCount - recordedCount)
end

local function HasAcceptedTradeSettlement(activeTrade)
	if not activeTrade then
		return false
	end

	return activeTrade.AcceptedSignal and true or (activeTrade.PlayerAccepted and activeTrade.TargetAccepted) and true or false
end

local function GetOrderForActiveTrade(activeTrade)
	local order

	if not activeTrade then
		return nil
	end

	if activeTrade.OrderId then
		order = Workbench.GetOrderById(activeTrade.OrderId)
	end
	if not order and activeTrade.CustomerName and activeTrade.CustomerName ~= "" then
		order = Workbench.GetOrderByCustomer(activeTrade.CustomerName)
		if order then
			activeTrade.OrderId = order.Id
		end
	end

	return order
end

local function GetTipStatusText(order, activeTrade)
	local pendingTradeTipCopper = activeTrade and math.max(0, math.floor(tonumber(activeTrade.TargetTradeMoneyCopper) or 0)) or 0
	if pendingTradeTipCopper > 0 then
		return "Tip in trade: " .. FormatMoneyCompact(pendingTradeTipCopper)
	end

	local tipCopper, resolved = GetResolvedTipCopper(order)
	if tipCopper > 0 then
		return "Tip: " .. FormatMoneyCompact(tipCopper)
	end
	if resolved then
		return "Tip: no tip"
	end
	if activeTrade then
		return "Tip: watching trade gold"
	end
	return "Tip: not recorded"
end

local function GetTargetTradeMoneyCopper()
	if not GetTargetTradeMoney then
		return 0
	end

	return math.max(0, math.floor(tonumber(GetTargetTradeMoney()) or 0))
end

local function GetTradeEnchantSlotIndex()
	if _G and tonumber(_G.TRADE_ENCHANT_SLOT) and tonumber(_G.TRADE_ENCHANT_SLOT) > 0 then
		return tonumber(_G.TRADE_ENCHANT_SLOT)
	end
	if _G and tonumber(_G.MAX_TRADE_ITEMS) and tonumber(_G.MAX_TRADE_ITEMS) > 0 then
		return tonumber(_G.MAX_TRADE_ITEMS)
	end
	return 7
end

local function BuildTradeEnchantInfo(itemName, enchantment, side)
	local cleanedItemName = TrimText(itemName)
	local cleanedEnchantment = TrimText(enchantment)
	if cleanedItemName == "" and cleanedEnchantment == "" then
		return nil
	end

	return {
		ItemName = cleanedItemName,
		Enchantment = cleanedEnchantment,
		Side = side,
	}
end

local function CaptureTradeEnchantInfo()
	local enchantSlotIndex = GetTradeEnchantSlotIndex()
	local targetInfo
	local playerInfo

	if GetTradeTargetItemInfo then
		local itemName, _, _, _, _, enchantment = GetTradeTargetItemInfo(enchantSlotIndex)
		targetInfo = BuildTradeEnchantInfo(itemName, enchantment, "target")
	end

	if GetTradePlayerItemInfo then
		local itemName, _, _, _, enchantment = GetTradePlayerItemInfo(enchantSlotIndex)
		playerInfo = BuildTradeEnchantInfo(itemName, enchantment, "player")
	end

	if targetInfo and targetInfo.Enchantment ~= "" then
		return targetInfo
	end
	if playerInfo and playerInfo.Enchantment ~= "" then
		return playerInfo
	end
	if targetInfo then
		return targetInfo
	end
	return playerInfo
end

local function TradeEnchantSlotHasItem()
	local enchantInfo = CaptureTradeEnchantInfo()
	return enchantInfo and enchantInfo.Enchantment ~= "" or false
end

local function CopyRecipeNames(recipeMapOrList)
	local out = {}

	if type(recipeMapOrList) ~= "table" then
		return out
	end

	if #recipeMapOrList > 0 then
		for index = 1, #recipeMapOrList do
			local recipeName = recipeMapOrList[index]
			if type(recipeName) == "string" and recipeName ~= "" then
				out[#out + 1] = recipeName
			end
		end
	else
		local seen = {}
		for key, value in pairs(recipeMapOrList) do
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
	end

	table.sort(out)
	return out
end

local function NormalizeRecipeCount(value)
	local normalized = math.floor(tonumber(value) or 0)
	if normalized < 0 then
		return 0
	end
	return normalized
end

local function BuildRecipeCountMap(recipeNames)
	local counts = {}

	if type(recipeNames) ~= "table" then
		return counts
	end

	for _, recipeName in ipairs(recipeNames) do
		if type(recipeName) == "string" and recipeName ~= "" then
			counts[recipeName] = (counts[recipeName] or 0) + 1
		end
	end

	return counts
end

local function BuildRecipeListFromCountMap(recipeCounts)
	local recipes = {}

	if type(recipeCounts) ~= "table" then
		return recipes
	end

	for recipeName, count in pairs(recipeCounts) do
		local normalizedCount = NormalizeRecipeCount(count)
		if type(recipeName) == "string" and recipeName ~= "" then
			for _ = 1, normalizedCount do
				recipes[#recipes + 1] = recipeName
			end
		end
	end

	table.sort(recipes)
	return recipes
end

local function MergeRecipeLists(existingRecipes, incomingRecipes)
	local mergedCounts = BuildRecipeCountMap(existingRecipes)

	for recipeName, count in pairs(BuildRecipeCountMap(incomingRecipes)) do
		mergedCounts[recipeName] = count
	end

	return BuildRecipeListFromCountMap(mergedCounts)
end

local function NormalizeCustomerName(name)
	if not name then
		return "", ""
	end

	local cleaned = tostring(name)
	cleaned = cleaned:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
	cleaned = cleaned:gsub("^%s+", ""):gsub("%s+$", "")

	local full = cleaned:lower()
	local short = full:match("^([^%-]+)") or full
	return short, full
end

local function NamesMatch(left, right)
	local leftShort, leftFull = NormalizeCustomerName(left)
	local rightShort, rightFull = NormalizeCustomerName(right)

	if leftShort == "" or rightShort == "" then
		return false
	end

	return leftShort == rightShort
		or leftShort == rightFull
		or leftFull == rightShort
		or leftFull == rightFull
end

local function GetGroupedQueueExpirySeconds()
	local configuredSeconds = EC and EC.DB and EC.DB.GroupedQueueExpireSeconds or 0
	return math.max(0, math.floor(tonumber(configuredSeconds) or 0))
end

local function GetDeclinedInviteRemovalSeconds()
	local configuredSeconds = EC and EC.DB and EC.DB.DeclinedInviteRemovalSeconds or 0
	return math.max(0, math.floor(tonumber(configuredSeconds) or 0))
end

local function IsCustomerInCurrentGroup(customerName)
	if TrimText(customerName) == "" then
		return false
	end

	local candidates = {}
	local seenCandidates = {}

	local function AddCandidate(value)
		value = TrimText(value)
		if value ~= "" and not seenCandidates[value] then
			seenCandidates[value] = true
			candidates[#candidates + 1] = value
		end
	end

	local shortName, fullName = NormalizeCustomerName(customerName)
	AddCandidate(customerName)
	AddCandidate(shortName)
	AddCandidate(fullName)

	local function CheckGroupFunction(groupFunction)
		if type(groupFunction) ~= "function" then
			return false
		end

		for _, candidate in ipairs(candidates) do
			local ok, isGrouped = pcall(groupFunction, candidate)
			if ok and isGrouped then
				return true
			end
		end

		return false
	end

	if CheckGroupFunction(UnitInParty) or CheckGroupFunction(UnitInRaid) then
		return true
	end

	local function CheckUnitNames(unitNameFunction)
		if type(unitNameFunction) ~= "function" then
			return false
		end

		local function UnitMatches(unitToken)
			local ok, unitName = pcall(unitNameFunction, unitToken, true)
			return ok and NamesMatch(unitName, customerName)
		end

		if UnitMatches("player") then
			return true
		end

		for index = 1, 4 do
			if UnitMatches("party" .. index) then
				return true
			end
		end

		for index = 1, 40 do
			if UnitMatches("raid" .. index) then
				return true
			end
		end

		return false
	end

	return CheckUnitNames(UnitName) or CheckUnitNames(GetUnitName)
end

local function EnsureRuntime()
	Workbench.Runtime = Workbench.Runtime or {}
	return Workbench.Runtime
end

local function IsDisenchantOrder(order)
	return order and order.Kind == "disenchant"
end

local function IsLockboxOrder(order)
	return order and order.Kind == "lockbox"
end

local function IsMailboxItemOrder(order)
	return IsDisenchantOrder(order) or IsLockboxOrder(order)
end

local function GetGroupedExpiryRuntime(orderId, createIfMissing)
	local runtime = EnsureRuntime()
	runtime.GroupedExpiry = runtime.GroupedExpiry or {}

	local groupedExpiry = runtime.GroupedExpiry[orderId]
	if not groupedExpiry and createIfMissing ~= false then
		groupedExpiry = {}
		runtime.GroupedExpiry[orderId] = groupedExpiry
	end

	return groupedExpiry
end

local function ClearGroupedExpiryRuntime(orderId)
	local runtime = EnsureRuntime()
	if runtime.GroupedExpiry then
		runtime.GroupedExpiry[orderId] = nil
	end
end

local function GetDeclinedInviteExpiryRuntime(orderId, createIfMissing)
	local runtime = EnsureRuntime()
	runtime.DeclinedInviteExpiry = runtime.DeclinedInviteExpiry or {}

	local declinedInviteExpiry = runtime.DeclinedInviteExpiry[orderId]
	if not declinedInviteExpiry and createIfMissing ~= false then
		declinedInviteExpiry = {}
		runtime.DeclinedInviteExpiry[orderId] = declinedInviteExpiry
	end

	return declinedInviteExpiry
end

local function ClearDeclinedInviteExpiryRuntime(orderId)
	local runtime = EnsureRuntime()
	if runtime.DeclinedInviteExpiry then
		runtime.DeclinedInviteExpiry[orderId] = nil
	end
end

local function FindOrderIndexById(orderId, state)
	state = state or Workbench.EnsureState()
	for index, order in ipairs(state.Orders) do
		if order.Id == orderId then
			return index
		end
	end
	return nil
end

local OrderHasRecipe

local function EnsureDisenchantItemFields(item)
	item = item or {}
	item.Token = math.max(1, math.floor(tonumber(item.Token) or 0))
	item.Name = TrimText(item.Name)
	item.Link = TrimText(item.Link)
	item.LootKey = TrimText(item.LootKey)
	item.ItemId = tonumber(item.ItemId) and math.floor(tonumber(item.ItemId)) or nil
	item.Quality = math.max(0, math.floor(tonumber(item.Quality) or 0))
	item.MailSubject = TrimText(item.MailSubject)
	item.Status = item.Status == "done" and "done" or "queued"
	item.Bag = tonumber(item.Bag)
	item.Slot = tonumber(item.Slot)
	if item.IsLocked ~= nil then
		item.IsLocked = item.IsLocked and true or false
	end
	item.CreatedAt = NormalizeTimestampText(item.CreatedAt)
	item.UpdatedAt = NormalizeTimestampText(item.UpdatedAt or item.CreatedAt)
	return item
end

local function NormalizeDisenchantMaterialEntry(material, fallbackKey)
	if type(material) ~= "table" then
		return nil
	end

	local normalized = {
		Key = "",
		Name = TrimText(material.Name),
		Link = TrimText(material.Link),
		ItemId = tonumber(material.ItemId) and math.floor(tonumber(material.ItemId)) or nil,
		Count = NormalizeItemCount(material.Count),
	}

	normalized.Key = TrimText(material.Key or fallbackKey)
	if normalized.Key == "" and normalized.ItemId then
		normalized.Key = "item:" .. tostring(normalized.ItemId)
	elseif normalized.Key == "" and normalized.Name ~= "" then
		normalized.Key = normalized.Name
	elseif normalized.Key == "" then
		normalized.Key = normalized.Link
	end
	if normalized.Key == "" or normalized.Count <= 0 then
		return nil
	end

	return normalized
end

local function FindSourceItemByToken(order, itemToken)
	if not IsMailboxItemOrder(order) or not itemToken then
		return nil
	end

	for _, item in ipairs(order.SourceItems or {}) do
		if item.Token == itemToken then
			return item
		end
	end

	return nil
end

local function FindSourceItemByLootKey(order, lootKey)
	lootKey = TrimText(lootKey)
	if not IsMailboxItemOrder(order) or lootKey == "" then
		return nil
	end

	for _, item in ipairs(order.SourceItems or {}) do
		if TrimText(item.LootKey) == lootKey then
			return item
		end
	end

	return nil
end

local function GetLegacyDisenchantDuplicateKey(item)
	local itemIdentity

	if not item or TrimText(item.LootKey) ~= "" then
		return ""
	end

	itemIdentity = item.ItemId and ("item:" .. tostring(item.ItemId)) or TrimText(item.Link)
	if itemIdentity == "" then
		itemIdentity = TrimText(item.Name)
	end
	if itemIdentity == "" then
		return ""
	end

	return table.concat({
		itemIdentity,
		TrimText(item.MailSubject),
		TrimText(item.CreatedAt),
	}, "\031")
end

local function PruneLegacyUntrackedDuplicateSourceItems(order)
	local anchoredKeys = {}
	local changed = false

	if not IsDisenchantOrder(order) then
		return false
	end

	for _, item in ipairs(order.SourceItems or {}) do
		local duplicateKey = GetLegacyDisenchantDuplicateKey(item)
		if duplicateKey ~= "" and (item.Status == "done" or item.Bag ~= nil or item.Slot ~= nil) then
			anchoredKeys[duplicateKey] = true
		end
	end

	for index = #(order.SourceItems or {}), 1, -1 do
		local item = order.SourceItems[index]
		local duplicateKey = GetLegacyDisenchantDuplicateKey(item)
		if duplicateKey ~= "" and anchoredKeys[duplicateKey] and item.Status ~= "done" and item.Bag == nil and item.Slot == nil then
			table.remove(order.SourceItems, index)
			changed = true
		end
	end

	return changed
end

local function GetDisenchantProgress(order)
	local completed = 0
	local total = 0

	if not IsDisenchantOrder(order) then
		return completed, total
	end

	for _, item in ipairs(order.SourceItems or {}) do
		total = total + 1
		if item.Status == "done" then
			completed = completed + 1
		end
	end

	return completed, total
end

local function GetLockboxProgress(order)
	local completed = 0
	local total = 0

	if not IsLockboxOrder(order) then
		return completed, total
	end

	for _, item in ipairs(order.SourceItems or {}) do
		total = total + 1
		if item.Status == "done" then
			completed = completed + 1
		end
	end

	return completed, total
end

local function GetDisenchantMaterialSnapshot(order)
	local materials = {}

	if not IsDisenchantOrder(order) then
		return materials
	end

	for _, material in pairs(order.ReturnMaterials or {}) do
		local normalized = NormalizeDisenchantMaterialEntry(material, material.Key)
		if normalized then
			materials[#materials + 1] = normalized
		end
	end

	table.sort(materials, function(left, right)
		local leftName = TrimText(left.Name) ~= "" and left.Name or left.Link or left.Key
		local rightName = TrimText(right.Name) ~= "" and right.Name or right.Link or right.Key
		if leftName == rightName then
			return left.Key < right.Key
		end
		return leftName < rightName
	end)

	return materials
end

local function GetDisenchantItemDisplayText(item)
	if not item then
		return "Unknown item"
	end

	if item.Link and item.Link ~= "" then
		return item.Link
	end

	if item.Name and item.Name ~= "" then
		return item.Name
	end

	if item.ItemId then
		return "item:" .. tostring(item.ItemId)
	end

	return "Unknown item"
end

local function ClearDisenchantButton(button)
	if not button then
		return
	end

	button.ActionKind = nil
	button.OrderId = nil
	button.ItemToken = nil
	button.Bag = nil
	button.Slot = nil
	if button.Hide then
		button:Hide()
	end
end

local function ConfigureDisenchantButton(button, orderId, item)
	if not button or not item then
		return
	end

	button.ActionKind = "disenchant"
	button.OrderId = orderId
	button.ItemToken = item.Token
	button.Bag = item.Bag
	button.Slot = item.Slot
	if button.SetText then
		button:SetText("DE")
	end
	if button.Show then
		button:Show()
	end
end

local function EnsureOrderFields(order)
	local nextSourceItemToken = 1
	local normalizedReturnMaterials = {}

	if order.Kind ~= "disenchant" and order.Kind ~= "lockbox" then
		order.Kind = "enchant"
	end
	order.Recipes = order.Recipes or {}
	order.MaterialCounts = order.MaterialCounts or {}
	order.MaterialState = order.MaterialState or {}
	order.VerifiedRecipes = order.VerifiedRecipes or {}
	order.VerifiedRecipeCounts = order.VerifiedRecipeCounts or {}
	order.SourceItems = order.SourceItems or {}
	order.ReturnMaterials = order.ReturnMaterials or {}
	table.sort(order.Recipes)
	do
		local requiredRecipeCounts = BuildRecipeCountMap(order.Recipes)
		local normalizedVerifiedRecipes = {}
		local normalizedVerifiedCounts = {}

		for recipeName, requiredCount in pairs(requiredRecipeCounts) do
			local verifiedCount = NormalizeRecipeCount(order.VerifiedRecipeCounts[recipeName] or 0)
			if verifiedCount <= 0 and order.VerifiedRecipes[recipeName] then
				verifiedCount = 1
			end
			verifiedCount = math.min(requiredCount, verifiedCount)
			if verifiedCount > 0 then
				normalizedVerifiedRecipes[recipeName] = true
				normalizedVerifiedCounts[recipeName] = verifiedCount
			end
		end

		order.VerifiedRecipes = normalizedVerifiedRecipes
		order.VerifiedRecipeCounts = normalizedVerifiedCounts
	end
	order.RequestedRecipeCount = math.max(#order.Recipes, math.floor(tonumber(order.RequestedRecipeCount) or 0))
	order.Message = order.Message or ""
	order.PendingTipText = order.PendingTipText or ""
	order.NoTipConfirmed = order.NoTipConfirmed and true or false
	order.LastObservedTipCopper = math.max(0, math.floor(tonumber(order.LastObservedTipCopper) or 0))
	if TrimText(order.PendingTipText) ~= "" then
		local migratedTipCopper = ParseMoneyCompact(order.PendingTipText)
		if migratedTipCopper ~= nil then
			if migratedTipCopper > 0 and order.LastObservedTipCopper <= 0 then
				order.LastObservedTipCopper = migratedTipCopper
			elseif migratedTipCopper == 0 then
				order.NoTipConfirmed = true
			end
		end
		order.PendingTipText = ""
	end
	if order.LastObservedTipCopper > 0 then
		order.NoTipConfirmed = false
	end
	order.AlreadyGrouped = order.AlreadyGrouped and true or nil
	order.AlreadyGroupedAt = order.AlreadyGrouped and math.max(0, tonumber(order.AlreadyGroupedAt) or 0) or nil
	order.InviteDeclined = order.InviteDeclined and true or order.InviteDeclinedAt ~= nil and true or nil
	order.InviteDeclinedAt = order.InviteDeclined and math.max(0, tonumber(order.InviteDeclinedAt) or 0) or nil

	for index, item in ipairs(order.SourceItems) do
		order.SourceItems[index] = EnsureDisenchantItemFields(item)
		if order.SourceItems[index].Token >= nextSourceItemToken then
			nextSourceItemToken = order.SourceItems[index].Token + 1
		end
	end
	if PruneLegacyUntrackedDuplicateSourceItems(order) then
		order.UpdatedAt = TimestampText()
	end
	order.NextSourceItemToken = math.max(nextSourceItemToken, math.floor(tonumber(order.NextSourceItemToken) or 1))

	for materialKey, material in pairs(order.ReturnMaterials) do
		local normalized = NormalizeDisenchantMaterialEntry(material, materialKey)
		if normalized then
			normalizedReturnMaterials[normalized.Key] = normalized
		end
	end
	order.ReturnMaterials = normalizedReturnMaterials

	order.CreatedAt = NormalizeTimestampText(order.CreatedAt)
	order.UpdatedAt = NormalizeTimestampText(order.UpdatedAt or order.CreatedAt)
	return order
end

local function GetRecipeRequiredCount(order, recipeName)
	local requiredCount = NormalizeRecipeCount(BuildRecipeCountMap(order and order.Recipes or nil)[recipeName] or 0)
	return requiredCount
end

local function GetVerifiedRecipeCount(order, recipeName)
	local verifiedCount
	local requiredCount

	if not order or not recipeName or recipeName == "" then
		return 0
	end

	verifiedCount = NormalizeRecipeCount(order.VerifiedRecipeCounts and order.VerifiedRecipeCounts[recipeName] or 0)
	if verifiedCount <= 0 and order.VerifiedRecipes and order.VerifiedRecipes[recipeName] then
		verifiedCount = 1
	end

	requiredCount = GetRecipeRequiredCount(order, recipeName)
	if requiredCount > 0 then
		verifiedCount = math.min(requiredCount, verifiedCount)
	end

	return verifiedCount
end

local function SetVerifiedRecipeCount(order, recipeName, count)
	local requiredCount
	local currentCount

	if not order or not recipeName or recipeName == "" or not OrderHasRecipe(order, recipeName) then
		return 0, false
	end

	requiredCount = GetRecipeRequiredCount(order, recipeName)
	currentCount = GetVerifiedRecipeCount(order, recipeName)
	count = math.min(requiredCount, NormalizeRecipeCount(count))
	if currentCount == count then
		return count, false
	end

	order.VerifiedRecipes = order.VerifiedRecipes or {}
	order.VerifiedRecipeCounts = order.VerifiedRecipeCounts or {}
	order.VerifiedRecipeCounts[recipeName] = count > 0 and count or nil
	order.VerifiedRecipes[recipeName] = count > 0 and true or nil
	return count, true
end

local function GetAppliedRecipeCount(activeTrade, recipeName)
	local appliedCount

	if not activeTrade or not recipeName or recipeName == "" then
		return 0
	end

	appliedCount = NormalizeRecipeCount(activeTrade.AppliedRecipeCounts and activeTrade.AppliedRecipeCounts[recipeName] or 0)
	if appliedCount <= 0 and activeTrade.AppliedRecipes and activeTrade.AppliedRecipes[recipeName] then
		appliedCount = 1
	end

	return appliedCount
end

local function SetAppliedRecipeCount(activeTrade, recipeName, count)
	if not activeTrade or not recipeName or recipeName == "" then
		return 0
	end

	count = NormalizeRecipeCount(count)
	activeTrade.AppliedRecipes = activeTrade.AppliedRecipes or {}
	activeTrade.AppliedRecipeCounts = activeTrade.AppliedRecipeCounts or {}
	activeTrade.AppliedRecipeCounts[recipeName] = count > 0 and count or nil
	activeTrade.AppliedRecipes[recipeName] = count > 0 and true or nil
	return count
end

local function ResetGroupedState(order)
	if not order then
		return false
	end

	local changed = order.AlreadyGrouped or order.AlreadyGroupedAt ~= nil
	order.AlreadyGrouped = nil
	order.AlreadyGroupedAt = nil
	if order.Id then
		ClearGroupedExpiryRuntime(order.Id)
	end
	if changed then
		order.UpdatedAt = TimestampText()
	end
	return changed and true or false
end

local function ResetInviteDeclinedState(order)
	if not order then
		return false
	end

	local changed = order.InviteDeclined or order.InviteDeclinedAt ~= nil
	order.InviteDeclined = nil
	order.InviteDeclinedAt = nil
	if order.Id then
		ClearDeclinedInviteExpiryRuntime(order.Id)
	end
	if changed then
		order.UpdatedAt = TimestampText()
	end
	return changed and true or false
end

local function GetGroupedOrderExpireAt(order)
	if not order or not order.AlreadyGrouped or order.AlreadyGroupedAt == nil then
		return nil
	end

	local expirySeconds = GetGroupedQueueExpirySeconds()
	if expirySeconds <= 0 then
		return nil
	end

	return math.max(0, tonumber(order.AlreadyGroupedAt) or 0) + expirySeconds
end

local function GetDeclinedInviteExpireAt(order)
	if not order or not order.InviteDeclined or order.InviteDeclinedAt == nil then
		return nil
	end

	local removalSeconds = GetDeclinedInviteRemovalSeconds()
	if removalSeconds <= 0 then
		return nil
	end

	return math.max(0, tonumber(order.InviteDeclinedAt) or 0) + removalSeconds
end

local function RemoveOrderByIndex(state, index, reasonPrefix)
	local removedOrder = table.remove(state.Orders, index)
	if not removedOrder then
		return nil
	end

	ClearGroupedExpiryRuntime(removedOrder.Id)
	ClearDeclinedInviteExpiryRuntime(removedOrder.Id)
	EC.PlayerList[removedOrder.Customer] = nil
	EC.LfRecipeList[removedOrder.Customer] = nil
	if EC.ClearWhisperListenMode then
		EC.ClearWhisperListenMode(removedOrder.Customer)
	end
	WorkbenchDebug(reasonPrefix or "removed order for", removedOrder.Customer, "(" .. tostring(#(removedOrder.Recipes or {})) .. " enchants)")
	return removedOrder
end

local function ScheduleGroupedOrderExpiry(order)
	if not order or not order.Id then
		return false
	end

	local expireAt = GetGroupedOrderExpireAt(order)
	if not expireAt or IsCustomerInCurrentGroup(order.Customer) then
		ClearGroupedExpiryRuntime(order.Id)
		return false
	end

	local groupedExpiry = GetGroupedExpiryRuntime(order.Id)
	if groupedExpiry.ExpireAt == expireAt then
		return true
	end

	groupedExpiry.Token = math.floor(tonumber(groupedExpiry.Token) or 0) + 1
	groupedExpiry.ExpireAt = expireAt

	if C_Timer and C_Timer.After then
		local token = groupedExpiry.Token
		local orderId = order.Id
		local delay = math.max(0, expireAt - Now()) + ORDER_EXPIRY_TIMER_BUFFER

		C_Timer.After(delay, function()
			local workbenchState = EC and EC.DBChar and EC.DBChar.Workbench or nil
			local currentOrder
			local currentGroupedExpiry = GetGroupedExpiryRuntime(orderId, false)
			if workbenchState and workbenchState.Orders then
				local orderIndex = FindOrderIndexById(orderId, workbenchState)
				currentOrder = orderIndex and workbenchState.Orders[orderIndex] or nil
			end
			if not currentOrder or not currentGroupedExpiry then
				if Workbench.Frame then
					Workbench.Refresh()
				end
				return
			end
			if currentGroupedExpiry.Token ~= token or currentGroupedExpiry.ExpireAt ~= expireAt then
				return
			end
			if not currentOrder.AlreadyGrouped then
				ClearGroupedExpiryRuntime(orderId)
				return
			end
			if IsCustomerInCurrentGroup(currentOrder.Customer) then
				if ResetGroupedState(currentOrder) and Workbench.Frame then
					Workbench.Refresh()
				end
				return
			end
			if Now() + 0.001 < expireAt then
				return
			end
			WorkbenchDebug("expired grouped order for", currentOrder.Customer, "(" .. tostring(GetGroupedQueueExpirySeconds()) .. "s without joining)")
			Workbench.RemoveOrder(orderId)
			if Workbench.Frame and Workbench.Frame.OrderRows then
				for _, row in ipairs(Workbench.Frame.OrderRows) do
					if row and row.OrderId == orderId and row.Hide then
						row:Hide()
					end
				end
			end
			if Workbench.Frame then
				Workbench.Refresh()
			end
		end)
	end

	return true
end

local function ScheduleDeclinedInviteExpiry(order)
	if not order or not order.Id then
		return false
	end

	local expireAt = GetDeclinedInviteExpireAt(order)
	if not expireAt or IsCustomerInCurrentGroup(order.Customer) then
		ClearDeclinedInviteExpiryRuntime(order.Id)
		return false
	end

	local declinedInviteExpiry = GetDeclinedInviteExpiryRuntime(order.Id)
	if declinedInviteExpiry.ExpireAt == expireAt then
		return true
	end

	declinedInviteExpiry.Token = math.floor(tonumber(declinedInviteExpiry.Token) or 0) + 1
	declinedInviteExpiry.ExpireAt = expireAt

	if C_Timer and C_Timer.After then
		local token = declinedInviteExpiry.Token
		local orderId = order.Id
		local delay = math.max(0, expireAt - Now()) + ORDER_EXPIRY_TIMER_BUFFER

		C_Timer.After(delay, function()
			local workbenchState = EC and EC.DBChar and EC.DBChar.Workbench or nil
			local currentOrder
			local currentDeclinedInviteExpiry = GetDeclinedInviteExpiryRuntime(orderId, false)
			if workbenchState and workbenchState.Orders then
				local orderIndex = FindOrderIndexById(orderId, workbenchState)
				currentOrder = orderIndex and workbenchState.Orders[orderIndex] or nil
			end
			if not currentOrder or not currentDeclinedInviteExpiry then
				if Workbench.Frame then
					Workbench.Refresh()
				end
				return
			end
			if currentDeclinedInviteExpiry.Token ~= token or currentDeclinedInviteExpiry.ExpireAt ~= expireAt then
				return
			end
			if not currentOrder.InviteDeclined then
				ClearDeclinedInviteExpiryRuntime(orderId)
				return
			end
			if IsCustomerInCurrentGroup(currentOrder.Customer) then
				if ResetInviteDeclinedState(currentOrder) and Workbench.Frame then
					Workbench.Refresh()
				end
				return
			end
			if Now() + 0.001 < expireAt then
				return
			end
			WorkbenchDebug("expired declined invite order for", currentOrder.Customer, "(" .. tostring(GetDeclinedInviteRemovalSeconds()) .. "s after decline)")
			Workbench.RemoveOrder(orderId)
			if Workbench.Frame and Workbench.Frame.OrderRows then
				for _, row in ipairs(Workbench.Frame.OrderRows) do
					if row and row.OrderId == orderId and row.Hide then
						row:Hide()
					end
				end
			end
			if Workbench.Frame then
				Workbench.Refresh()
			end
		end)
	end

	return true
end

local function SyncGroupedOrdersInternal(state)
	state = state or Workbench.EnsureState()

	local changed = false
	for index = #state.Orders, 1, -1 do
		local order = state.Orders[index]
		if not IsMailboxItemOrder(order) and order.AlreadyGrouped then
			if IsCustomerInCurrentGroup(order.Customer) then
				if ResetGroupedState(order) then
					WorkbenchDebug("cleared grouped queue flag for", order.Customer, "(now in group)")
					changed = true
				end
			else
				local expireAt = GetGroupedOrderExpireAt(order)
				if expireAt and Now() >= expireAt then
					RemoveOrderByIndex(state, index, "expired grouped order for")
					changed = true
				else
					ScheduleGroupedOrderExpiry(order)
				end
			end
		else
			ClearGroupedExpiryRuntime(order.Id)
		end
	end

	return changed
end

local function SyncDeclinedInviteOrders(state)
	state = state or Workbench.EnsureState()

	local changed = false
	local removalSeconds = GetDeclinedInviteRemovalSeconds()

	for index = #state.Orders, 1, -1 do
		local order = state.Orders[index]
		if not IsMailboxItemOrder(order) and order.InviteDeclined then
			if removalSeconds <= 0 then
				if ResetInviteDeclinedState(order) then
					changed = true
				end
			elseif IsCustomerInCurrentGroup(order.Customer) then
				if ResetInviteDeclinedState(order) then
					WorkbenchDebug("cleared declined invite flag for", order.Customer, "(now in group)")
					changed = true
				end
			else
				local expireAt = GetDeclinedInviteExpireAt(order)
				if expireAt and Now() >= expireAt then
					RemoveOrderByIndex(state, index, "expired declined invite order for")
					changed = true
				else
					ScheduleDeclinedInviteExpiry(order)
				end
			end
		else
			ClearDeclinedInviteExpiryRuntime(order.Id)
		end
	end

	return changed
end

local function SyncQueueOrderStates(state)
	state = state or Workbench.EnsureState()

	local changed = false
	if SyncGroupedOrdersInternal(state) then
		changed = true
	end
	if SyncDeclinedInviteOrders(state) then
		changed = true
	end

	if state.SelectedOrderId and not FindOrderIndexById(state.SelectedOrderId, state) then
		state.SelectedOrderId = state.Orders[1] and state.Orders[1].Id or nil
		changed = true
	end

	return changed
end

local function CountAppliedRecipes(activeTrade)
	local count = 0
	local appliedRecipes = activeTrade and activeTrade.AppliedRecipeCounts
	if type(appliedRecipes) ~= "table" or next(appliedRecipes) == nil then
		appliedRecipes = activeTrade and activeTrade.AppliedRecipes or {}
	end

	for recipeName in pairs(appliedRecipes or {}) do
		count = count + GetAppliedRecipeCount(activeTrade, recipeName)
	end

	return count
end

local function MaybeSendSuccessfulTradeThanks(order, activeTrade)
	if not order or not activeTrade or activeTrade.Thanked then
		return false
	end

	if CountAppliedRecipes(activeTrade) <= 0 then
		return false
	end

	if EC and EC.SendThankEmote and EC.SendThankEmote(order.Customer, "[Workbench] thank") then
		activeTrade.Thanked = true
		WorkbenchDebug("thanked", order.Customer)
		return true
	end

	return false
end

local function MaterialKey(material)
	if EC and EC.GetStoredRecipeMaterialKey then
		return EC.GetStoredRecipeMaterialKey(material)
	end
	if not material then
		return ""
	end
	return material.Link or material.Name or ""
end

local function GetMaterialDisplayName(material)
	if EC and EC.GetStoredRecipeMaterialName then
		return EC.GetStoredRecipeMaterialName(material)
	end
	if not material then
		return ""
	end
	return TrimText(material.Name)
end

local function GetMaterialDisplayText(material)
	if EC and EC.GetStoredRecipeMaterialDisplayText then
		return EC.GetStoredRecipeMaterialDisplayText(material)
	end
	if not material then
		return "Unknown Material"
	end
	return material.Link or material.Name or "Unknown Material"
end

local function CreateFrameCompat(frameType, name, parent, template)
	if not CreateFrame then
		return nil
	end

	local backdropTemplate = BackdropTemplateMixin and "BackdropTemplate" or nil
	if template and backdropTemplate then
		return CreateFrame(frameType, name, parent, template .. "," .. backdropTemplate)
	end
	if template then
		return CreateFrame(frameType, name, parent, template)
	end
	if backdropTemplate then
		return CreateFrame(frameType, name, parent, backdropTemplate)
	end
	return CreateFrame(frameType, name, parent)
end

local function ApplyBackdrop(frame, bgR, bgG, bgB, bgA, borderR, borderG, borderB, borderA)
	if not frame or not frame.SetBackdrop then
		return
	end

	if not frame._ECBackdropConfigured then
		frame:SetBackdrop({
			bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
			edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
			tile = true,
			tileSize = 8,
			edgeSize = 12,
			insets = { left = 3, right = 3, top = 3, bottom = 3 },
		})
		frame._ECBackdropConfigured = true
	end

	frame:SetBackdropColor(bgR or 0.09, bgG or 0.08, bgB or 0.07, bgA or 0.96)
	frame:SetBackdropBorderColor(borderR or 0.66, borderG or 0.46, borderB or 0.23, borderA or 1)
end

local function SaveFramePosition(frame)
	local state = Workbench.EnsureState()
	local point, _, relativePoint, xOfs, yOfs = frame:GetPoint()
	state.Position.Point = point or "CENTER"
	state.Position.RelativePoint = relativePoint or "CENTER"
	state.Position.X = xOfs or 0
	state.Position.Y = yOfs or 0
	WorkbenchDebug("saved position", state.Position.Point, string.format("(%.0f, %.0f)", state.Position.X, state.Position.Y))
end

local function SaveFrameSize(frame)
	local state = Workbench.EnsureState()
	state.Size.Width = ClampNumber(math.floor((frame:GetWidth() or DEFAULT_FRAME_WIDTH) + 0.5), MIN_FRAME_WIDTH, MAX_FRAME_WIDTH)
	state.Size.Height = ClampNumber(math.floor((frame:GetHeight() or DEFAULT_FRAME_HEIGHT) + 0.5), MIN_FRAME_HEIGHT, MAX_FRAME_HEIGHT)
	WorkbenchDebug("saved size", string.format("%dx%d", state.Size.Width, state.Size.Height))
end

local function ApplyFramePosition(frame)
	local state = Workbench.EnsureState()
	local position = state.Position
	frame:ClearAllPoints()
	frame:SetPoint(position.Point or "CENTER", UIParent, position.RelativePoint or "CENTER", position.X or 0, position.Y or 0)
end

local function ApplyFrameSize(frame)
	local state = Workbench.EnsureState()
	local size = state.Size or {}
	frame:SetSize(
		ClampNumber(size.Width or DEFAULT_FRAME_WIDTH, MIN_FRAME_WIDTH, MAX_FRAME_WIDTH),
		ClampNumber(size.Height or DEFAULT_FRAME_HEIGHT, MIN_FRAME_HEIGHT, MAX_FRAME_HEIGHT)
	)
end

local GetDetailContentWidth
local GetDetailVisibleHeight
local ClampDetailScroll
local UpdateDetailContentHeight

local function GetQueueHeight(frame)
	local frameHeight = ClampNumber(frame and frame.GetHeight and frame:GetHeight() or DEFAULT_FRAME_HEIGHT, MIN_FRAME_HEIGHT, MAX_FRAME_HEIGHT)
	local maximumQueueHeight = math.max(MIN_QUEUE_HEIGHT, frameHeight - DETAIL_RESERVED_HEIGHT)
	local suggestedQueueHeight = math.floor(frameHeight * 0.42)
	local orderCount = #(Workbench.EnsureState().Orders or {})

	if orderCount > 0 then
		local rowsHeight = (orderCount * 62) + 8
		local minimumQueueHeight = math.max(74, math.min(MIN_QUEUE_HEIGHT, rowsHeight))
		return ClampNumber(math.min(suggestedQueueHeight, rowsHeight), minimumQueueHeight, maximumQueueHeight)
	end

	return ClampNumber(suggestedQueueHeight, MIN_QUEUE_HEIGHT, maximumQueueHeight)
end

local function ApplyFrameLayout(frame)
	if not frame or not frame.ListScroll then
		return
	end

	frame.ListScroll:SetHeight(GetQueueHeight(frame))

	if frame.Detail and frame.Detail.Content then
		local detailContentWidth = GetDetailContentWidth(frame)
		local detailVisibleHeight = GetDetailVisibleHeight(frame)

		frame.Detail.Content:SetWidth(detailContentWidth)
		if (frame.Detail.Content.GetHeight and tonumber(frame.Detail.Content:GetHeight()) or 0) < detailVisibleHeight then
			frame.Detail.Content:SetHeight(detailVisibleHeight)
		end
		if frame.Detail.ActionRow and frame.Detail.ActionRow.SetWidth then
			frame.Detail.ActionRow:SetWidth(detailContentWidth)
		end
		for _, region in ipairs({
			frame.Detail.Title,
			frame.Detail.Meta,
			frame.Detail.Message,
			frame.Detail.TradeHint,
			frame.Detail.TipStatus,
			frame.Detail.Empty,
			frame.Detail.ReadyText,
		}) do
			if region and region.SetWidth then
				region:SetWidth(detailContentWidth)
			end
		end
		ClampDetailScroll(frame)
	end
end

local function GetTradeSlotLimit()
	if _G then
		if tonumber(_G.MAX_TRADE_ITEMS) and tonumber(_G.MAX_TRADE_ITEMS) > 0 then
			return tonumber(_G.MAX_TRADE_ITEMS)
		end
		if tonumber(_G.NUM_TRADE_ITEMS) and tonumber(_G.NUM_TRADE_ITEMS) > 0 then
			return tonumber(_G.NUM_TRADE_ITEMS)
		end
	end
	return 6
end

local function CaptureTradeTargetCounts()
	local counts = {}
	local function AddCount(key, itemCount)
		key = TrimText(key)
		if key ~= "" then
			counts[key] = (counts[key] or 0) + itemCount
		end
	end
	if not GetTradeTargetItemInfo then
		return counts
	end

	for index = 1, GetTradeSlotLimit() do
		local itemName, _, itemCount, _, _, _, itemId = GetTradeTargetItemInfo(index)
		local materialKey
		local itemLink

		itemName = TrimText(itemName)
		itemLink = GetTradeTargetItemLink and GetTradeTargetItemLink(index) or nil
		if itemName ~= "" or (itemId and itemId > 0) or (type(itemLink) == "string" and itemLink ~= "") then
			itemCount = tonumber(itemCount) or 1
			materialKey = MaterialKey({
				ItemId = itemId,
				Name = itemName,
				Link = itemLink,
			})
			AddCount(materialKey, itemCount)
			if type(itemLink) == "string" and itemLink ~= "" then
				if TrimText(itemLink) ~= TrimText(materialKey) then
					AddCount(itemLink, itemCount)
				end
			end
			if itemName ~= "" then
				if itemName ~= TrimText(materialKey) and itemName ~= TrimText(itemLink) then
					AddCount(itemName, itemCount)
				end
			end
		end
	end

	return counts
end

local function GetQueueListWidth(frame)
	if not frame then
		return DEFAULT_FRAME_WIDTH - 56
	end

	local listWidth = 0
	if frame.ListChild and frame.ListChild.GetWidth then
		listWidth = tonumber(frame.ListChild:GetWidth()) or 0
	end
	if listWidth <= 0 and frame.ListScroll and frame.ListScroll.GetWidth then
		listWidth = (tonumber(frame.ListScroll:GetWidth()) or 0) - 24
	end
	if listWidth <= 0 and frame.GetWidth then
		listWidth = (tonumber(frame:GetWidth()) or DEFAULT_FRAME_WIDTH) - 52
	end

	return math.max(320, math.floor(listWidth))
end

GetDetailContentWidth = function(frame)
	if frame and frame.Detail and frame.Detail.Content and frame.Detail.Content.GetWidth then
		local contentWidth = tonumber(frame.Detail.Content:GetWidth()) or 0
		if contentWidth > 0 then
			return math.max(160, math.floor(contentWidth))
		end
	end

	if frame and frame.Detail and frame.Detail.Scroll and frame.Detail.Scroll.GetWidth then
		local scrollWidth = tonumber(frame.Detail.Scroll:GetWidth()) or 0
		if scrollWidth > 0 then
			return math.max(160, math.floor(scrollWidth - 20))
		end
	end

	if not frame or not frame.Detail or not frame.Detail.GetWidth then
		return DEFAULT_FRAME_WIDTH - 76
	end

	local detailWidth = tonumber(frame.Detail:GetWidth()) or 0
	if detailWidth <= 0 and frame.GetWidth then
		detailWidth = (tonumber(frame:GetWidth()) or DEFAULT_FRAME_WIDTH) - 52
	end

	return math.max(160, math.floor(detailWidth - 24))
end

GetDetailVisibleHeight = function(frame)
	if frame and frame.Detail and frame.Detail.Scroll and frame.Detail.Scroll.GetHeight then
		local scrollHeight = tonumber(frame.Detail.Scroll:GetHeight()) or 0
		if scrollHeight > 0 then
			return math.max(120, math.floor(scrollHeight))
		end
	end

	local frameHeight = ClampNumber(frame and frame.GetHeight and frame:GetHeight() or DEFAULT_FRAME_HEIGHT, MIN_FRAME_HEIGHT, MAX_FRAME_HEIGHT)
	return math.max(140, frameHeight - GetQueueHeight(frame) - 134)
end

ClampDetailScroll = function(frame)
	if not frame or not frame.Detail or not frame.Detail.Scroll or not frame.Detail.Content or not frame.Detail.Scroll.SetVerticalScroll then
		return
	end

	local visibleHeight = GetDetailVisibleHeight(frame)
	local childHeight = frame.Detail.Content.GetHeight and tonumber(frame.Detail.Content:GetHeight()) or 0
	local maximumScroll = math.max(0, childHeight - visibleHeight)
	local currentScroll = frame.Detail.Scroll.GetVerticalScroll and tonumber(frame.Detail.Scroll:GetVerticalScroll()) or 0

	if currentScroll < 0 then
		frame.Detail.Scroll:SetVerticalScroll(0)
	elseif currentScroll > maximumScroll then
		frame.Detail.Scroll:SetVerticalScroll(maximumScroll)
	end
end

local function StripTextDecorations(text)
	text = tostring(text or "")
	text = text:gsub("|c%x%x%x%x%x%x%x%x", "")
	text = text:gsub("|r", "")
	text = text:gsub("|H.-|h(.-)|h", "%1")
	text = text:gsub("|T.-|t", "")
	return text
end

local function MeasureWrappedTextHeight(region, text, width, fallbackLineHeight)
	local lineHeight = math.max(12, tonumber(fallbackLineHeight) or 14)
	if region and region.GetStringHeight then
		local measuredHeight = tonumber(region:GetStringHeight()) or 0
		if measuredHeight > 0 then
			return math.max(lineHeight, math.ceil(measuredHeight))
		end
	end

	local plainText = StripTextDecorations(text)
	if plainText == "" then
		return lineHeight
	end

	local charactersPerLine = math.max(18, math.floor((tonumber(width) or 220) / 7))
	local lineCount = 0
	for segment in (plainText .. "\n"):gmatch("(.-)\n") do
		local trimmedSegment = TrimText(segment)
		lineCount = lineCount + math.max(1, math.ceil(math.max(1, #trimmedSegment) / charactersPerLine))
	end

	return math.max(lineHeight, lineCount * lineHeight)
end

UpdateDetailContentHeight = function(frame, recipeCount, materialCount)
	if not frame or not frame.Detail or not frame.Detail.Content then
		return
	end

	local detailContentWidth = GetDetailContentWidth(frame)
	local visibleHeight = GetDetailVisibleHeight(frame)
	local contentHeight = 48

	contentHeight = contentHeight + 8 + MeasureWrappedTextHeight(frame.Detail.Message, frame.Detail.Message and frame.Detail.Message:GetText() or "", detailContentWidth, 14)
	if IsRegionShown(frame.Detail.TradeHint) then
		contentHeight = contentHeight + 8 + MeasureWrappedTextHeight(frame.Detail.TradeHint, frame.Detail.TradeHint:GetText() or "", detailContentWidth, 14)
	end

	if IsRegionShown(frame.Detail.ActionRow) then
		contentHeight = contentHeight + 12 + 20
		contentHeight = contentHeight + 12 + 14
		if recipeCount > 0 then
			contentHeight = contentHeight + 6 + (recipeCount * 24) + math.max(0, recipeCount - 1) * 4
		end
		contentHeight = contentHeight + 14 + 20
		contentHeight = contentHeight + 4 + MeasureWrappedTextHeight(frame.Detail.ReadyText, frame.Detail.ReadyText and frame.Detail.ReadyText:GetText() or "", detailContentWidth, 14)
		if materialCount > 0 then
			contentHeight = contentHeight + 4 + (materialCount * 22) + math.max(0, materialCount - 1) * 2
		end
	else
		contentHeight = contentHeight + 12 + MeasureWrappedTextHeight(frame.Detail.Empty, frame.Detail.Empty and frame.Detail.Empty:GetText() or "", detailContentWidth, 16)
	end

	frame.Detail.Content:SetHeight(math.max(visibleHeight, math.floor(contentHeight + 12)))
	ClampDetailScroll(frame)
end

local function ClampQueueScroll(frame)
	if not frame or not frame.ListScroll or not frame.ListScroll.SetVerticalScroll then
		return
	end

	local visibleHeight = frame.ListScroll.GetHeight and tonumber(frame.ListScroll:GetHeight()) or 0
	local childHeight = frame.ListChild and frame.ListChild.GetHeight and tonumber(frame.ListChild:GetHeight()) or 0
	local maximumScroll = math.max(0, childHeight - visibleHeight)
	local currentScroll = frame.ListScroll.GetVerticalScroll and tonumber(frame.ListScroll:GetVerticalScroll()) or 0

	if currentScroll < 0 then
		frame.ListScroll:SetVerticalScroll(0)
	elseif currentScroll > maximumScroll then
		frame.ListScroll:SetVerticalScroll(maximumScroll)
	end
end

local function SortedOrders()
	local state = Workbench.EnsureState()
	return state.Orders
end

local function GetActiveTradeForOrder(order)
	local runtime = EnsureRuntime()
	local activeTrade = runtime.ActiveTrade

	if not order or not activeTrade then
		return nil
	end

	if activeTrade.OrderId and activeTrade.OrderId == order.Id then
		return activeTrade
	end

	if activeTrade.CustomerName and activeTrade.CustomerName ~= "" then
		local matchedOrder = Workbench.GetOrderByCustomer(activeTrade.CustomerName)
		if matchedOrder and matchedOrder.Id == order.Id then
			activeTrade.OrderId = order.Id
			return activeTrade
		end
	end

	return nil
end

local function OrderSummary(order)
	if IsDisenchantOrder(order) then
		local itemCount = #(order.SourceItems or {})
		if itemCount == 0 then
			return "Waiting for mailbox items"
		end
		if itemCount == 1 then
			return GetDisenchantItemDisplayText(order.SourceItems[1])
		end
		if itemCount == 2 then
			return GetDisenchantItemDisplayText(order.SourceItems[1]) .. " + " .. GetDisenchantItemDisplayText(order.SourceItems[2])
		end
		return string.format("%s + %d more", GetDisenchantItemDisplayText(order.SourceItems[1]), itemCount - 1)
	end
	if IsLockboxOrder(order) then
		local completed, total = GetLockboxProgress(order)
		if total == 0 then
			return "Waiting for mailbox lockboxes"
		end
		if completed == total then
			return string.format("%d lockbox%s unlocked", total, total == 1 and "" or "es")
		end
		return string.format("%d lockbox%s to unlock", total - completed, (total - completed) == 1 and "" or "es")
	end

	local recipeCount = #(order.Recipes or {})
	if recipeCount == 0 then
		return "Waiting for a recognized enchant"
	end
	if recipeCount == 1 then
		return order.Recipes[1]
	end
	if recipeCount == 2 then
		return order.Recipes[1] .. " + " .. order.Recipes[2]
	end
	return string.format("%s + %d more", order.Recipes[1], recipeCount - 1)
end

local function SetSelectedOrder(orderId)
	local state = Workbench.EnsureState()
	if orderId and FindOrderIndexById(orderId) then
		state.SelectedOrderId = orderId
	else
		state.SelectedOrderId = state.Orders[1] and state.Orders[1].Id or nil
	end
end

local function IsQueueSoundEnabled()
	local state = Workbench.EnsureState()
	return state.SoundEnabled and true or false
end

local function IsQueueSoundLoud()
	local state = Workbench.EnsureState()
	return state.SoundEnabled == "loud"
end

local function IsPartyJoinSoundModeEnabled()
	return EC ~= nil and EC.DB ~= nil and EC.DB.PlaySoundOnPartyJoinInstead == true
end

local function BuildHeaderStatusText(state)
	state = state or Workbench.EnsureState()

	local orderCount = #((state and state.Orders) or {})
	local completedCount = math.max(0, math.floor(tonumber(state.CompletedOrders) or 0))
	local completedTips = math.max(0, math.floor(tonumber(state.CompletedTipsCopper) or 0))

	return string.format("%d orders  •  %d done  •  %s tips", orderCount, completedCount, FormatMoneyCompact(completedTips))
end

local function PlayQueueAlertSound()
	if not IsQueueSoundEnabled() or type(PlaySound) ~= "function" then
		return false
	end

	local tried = {}
	local function RegisterSoundToken(tokens, token)
		if token == nil then
			return
		end

		local tokenKey = type(token) .. ":" .. tostring(token)
		if tried[tokenKey] then
			return
		end

		tried[tokenKey] = true
		tokens[#tokens + 1] = token
	end

	local function TryFallbacks(candidates, channel)
		for _, candidate in ipairs(candidates) do
			local soundTokens = {}
			if type(SOUNDKIT) == "table" and SOUNDKIT[candidate.key] then
				RegisterSoundToken(soundTokens, SOUNDKIT[candidate.key])
			end
			RegisterSoundToken(soundTokens, candidate.id)
			RegisterSoundToken(soundTokens, candidate.legacy)

			for _, soundKit in ipairs(soundTokens) do
				local ok, willPlay = pcall(PlaySound, soundKit, channel)
				if ok and willPlay ~= false then
					return true
				end

				ok, willPlay = pcall(PlaySound, soundKit)
				if ok and willPlay ~= false then
					return true
				end
			end
		end
		return false
	end

	if IsQueueSoundLoud() then
		if TryFallbacks(LOUD_ORDER_ALERT_SOUND_FALLBACKS, QUEUE_ALERT_SOUND_LOUD_CHANNEL) then
			return true
		end
	end

	return TryFallbacks(ORDER_ALERT_SOUND_FALLBACKS, QUEUE_ALERT_SOUND_CHANNEL)
end

local function RememberGroupedCustomerSnapshot(customerName)
	local _, fullName = NormalizeCustomerName(customerName)
	if fullName == "" or not IsCustomerInCurrentGroup(customerName) then
		return false
	end

	local runtime = EnsureRuntime()
	runtime.GroupedCustomerSnapshot = runtime.GroupedCustomerSnapshot or {}
	runtime.GroupedCustomerSnapshot[fullName] = true
	return true
end

local function UpdateGroupedCustomerSnapshot(state)
	state = state or Workbench.EnsureState()

	local runtime = EnsureRuntime()
	local previousSnapshot = runtime.GroupedCustomerSnapshot or {}
	local currentSnapshot = {}
	local joinedCount = 0

	for _, order in ipairs(state.Orders or {}) do
		local _, fullName = NormalizeCustomerName(order and order.Customer)
		if not IsMailboxItemOrder(order) and fullName ~= "" and IsCustomerInCurrentGroup(order.Customer) then
			currentSnapshot[fullName] = true
			if previousSnapshot[fullName] ~= true then
				joinedCount = joinedCount + 1
			end
		end
	end

	runtime.GroupedCustomerSnapshot = currentSnapshot
	if runtime.GroupedCustomerSnapshotInitialized and joinedCount > 0 then
		if not state.Visible then
			Workbench.Show()
		end
		if EC and EC.HandleGroupedCustomerJoin then
			EC.HandleGroupedCustomerJoin(joinedCount)
		end
		if IsPartyJoinSoundModeEnabled() and PlayQueueAlertSound() then
			WorkbenchDebug("played party join alert for", tostring(joinedCount), joinedCount == 1 and "customer" or "customers")
		end
	end
	runtime.GroupedCustomerSnapshotInitialized = true

	return joinedCount > 0
end

local function PreviewQueueAlertSound()
	if not IsQueueSoundEnabled() then
		return false
	end

	if PlayQueueAlertSound() then
		return true
	end

	if print then
		print("|cFFFF1C1CEnchanter|r Queue alert sound preview failed. If you still want alerts, try reloading and toggling Sound on again.")
	end

	return false
end

function Workbench.SelectOrder(orderId)
	SetSelectedOrder(orderId)
	local order = Workbench.GetSelectedOrder()
	if order and IsMailboxItemOrder(order) and EC and EC.SyncDisenchantInventoryTracking then
		EC.SyncDisenchantInventoryTracking()
		order = Workbench.GetSelectedOrder()
	end
	if order then
		WorkbenchDebug("selected order for", order.Customer, "(" .. tostring(#(order.Recipes or {})) .. " enchants)")
	end
	if Workbench.Frame and Workbench.Frame.Detail and Workbench.Frame.Detail.Scroll and Workbench.Frame.Detail.Scroll.SetVerticalScroll then
		Workbench.Frame.Detail.Scroll:SetVerticalScroll(0)
	end
	Workbench.Refresh()
end

function Workbench.EnsureState()
	if not EC.DBChar then
		return {
			Orders = {},
			Position = { Point = "CENTER", RelativePoint = "CENTER", X = 0, Y = 0 },
			Size = { Width = DEFAULT_FRAME_WIDTH, Height = DEFAULT_FRAME_HEIGHT },
			Locked = true,
			Visible = false,
			NextOrderId = 1,
		}
	end

	EC.DBChar.Workbench = EC.DBChar.Workbench or {}
	local state = EC.DBChar.Workbench
	state.Orders = state.Orders or {}
	state.Position = state.Position or {}
	state.Size = state.Size or {}

	if state.Locked == nil then
		state.Locked = true
	end
	if state.Visible == nil then
		state.Visible = false
	end
	if state.SoundEnabled == nil then
		state.SoundEnabled = false
	end
	if state.CompletedOrders == nil then
		state.CompletedOrders = 0
	end
	if state.CompletedTipsCopper == nil then
		state.CompletedTipsCopper = 0
	end
	if not state.NextOrderId or state.NextOrderId < 1 then
		state.NextOrderId = 1
	end
	if not state.Position.Point then
		state.Position.Point = "CENTER"
	end
	if not state.Position.RelativePoint then
		state.Position.RelativePoint = "CENTER"
	end
	if state.Position.X == nil then
		state.Position.X = 0
	end
	if state.Position.Y == nil then
		state.Position.Y = 0
	end
	if state.Size.Width == nil then
		state.Size.Width = DEFAULT_FRAME_WIDTH
	end
	if state.Size.Height == nil then
		state.Size.Height = DEFAULT_FRAME_HEIGHT
	end
	state.Size.Width = ClampNumber(state.Size.Width, MIN_FRAME_WIDTH, MAX_FRAME_WIDTH)
	state.Size.Height = ClampNumber(state.Size.Height, MIN_FRAME_HEIGHT, MAX_FRAME_HEIGHT)
	state.CompletedOrders = math.max(0, math.floor(tonumber(state.CompletedOrders) or 0))
	state.CompletedTipsCopper = math.max(0, math.floor(tonumber(state.CompletedTipsCopper) or 0))

	for index, order in ipairs(state.Orders) do
		state.Orders[index] = EnsureOrderFields(order)
		if order.Id and order.Id >= state.NextOrderId then
			state.NextOrderId = order.Id + 1
		end
	end

	if state.SelectedOrderId and not FindOrderIndexById(state.SelectedOrderId, state) then
		state.SelectedOrderId = nil
	end
	if not state.SelectedOrderId and state.Orders[1] then
		state.SelectedOrderId = state.Orders[1].Id
	end

	SyncQueueOrderStates(state)

	return state
end

function Workbench.GetSelectedOrder()
	local state = Workbench.EnsureState()
	for _, order in ipairs(state.Orders) do
		if order.Id == state.SelectedOrderId then
			return order
		end
	end
	return nil
end

function Workbench.GetOrderById(orderId)
	if not orderId then
		return nil
	end

	for _, order in ipairs(Workbench.EnsureState().Orders) do
		if order.Id == orderId then
			return order
		end
	end

	return nil
end

function Workbench.GetOrderByCustomer(customerName)
	local targetShort, targetFull = NormalizeCustomerName(customerName)
	if targetShort == "" then
		return nil
	end

	for _, order in ipairs(Workbench.EnsureState().Orders) do
		local orderShort, orderFull = NormalizeCustomerName(order.Customer)
		if targetFull == orderFull or targetFull == orderShort or targetShort == orderFull or targetShort == orderShort then
			if not IsMailboxItemOrder(order) then
				return order
			end
		end
	end

	return nil
end

function Workbench.GetDisenchantOrderByCustomer(customerName)
	local targetShort, targetFull = NormalizeCustomerName(customerName)
	if targetShort == "" then
		return nil
	end

	for _, order in ipairs(Workbench.EnsureState().Orders) do
		local orderShort, orderFull = NormalizeCustomerName(order.Customer)
		if IsDisenchantOrder(order)
			and (targetFull == orderFull or targetFull == orderShort or targetShort == orderFull or targetShort == orderShort)
		then
			return order
		end
	end

	return nil
end

function Workbench.GetLockboxOrderByCustomer(customerName)
	local targetShort, targetFull = NormalizeCustomerName(customerName)
	if targetShort == "" then
		return nil
	end

	for _, order in ipairs(Workbench.EnsureState().Orders) do
		local orderShort, orderFull = NormalizeCustomerName(order.Customer)
		if IsLockboxOrder(order)
			and (targetFull == orderFull or targetFull == orderShort or targetShort == orderFull or targetShort == orderShort)
		then
			return order
		end
	end

	return nil
end

function Workbench.GetDisenchantItems(order)
	order = order or Workbench.GetSelectedOrder()
	if not IsDisenchantOrder(order) then
		return {}
	end
	return order.SourceItems or {}
end

function Workbench.GetDisenchantProgress(order)
	order = order or Workbench.GetSelectedOrder()
	return GetDisenchantProgress(order)
end

function Workbench.GetLockboxProgress(order)
	order = order or Workbench.GetSelectedOrder()
	return GetLockboxProgress(order)
end

function Workbench.AddDisenchantMailItem(customer, itemData)
	local state = Workbench.EnsureState()
	local order
	local isNewOrder = false
	local sourceItem
	local lootKey

	if not customer or customer == "" or type(itemData) ~= "table" then
		return nil
	end

	for _, existing in ipairs(state.Orders) do
		if existing.Kind == "disenchant" and existing.Customer == customer then
			order = EnsureOrderFields(existing)
			break
		end
	end

	if not order then
		order = EnsureOrderFields({
			Id = state.NextOrderId,
			Customer = customer,
			Kind = "disenchant",
		})
		state.NextOrderId = state.NextOrderId + 1
		state.Orders[#state.Orders + 1] = order
		isNewOrder = true
	end

	lootKey = TrimText(itemData.LootKey)
	sourceItem = FindSourceItemByLootKey(order, lootKey)
	if sourceItem then
		order.UpdatedAt = TimestampText()
		Workbench.Refresh()
		return order, sourceItem
	end

	sourceItem = EnsureDisenchantItemFields({
		Token = order.NextSourceItemToken,
		Name = itemData.Name,
		Link = itemData.Link,
		LootKey = lootKey,
		ItemId = itemData.ItemId,
		Quality = itemData.Quality,
		MailSubject = itemData.MailSubject,
		Status = "queued",
		CreatedAt = TimestampText(),
		UpdatedAt = TimestampText(),
	})
	order.NextSourceItemToken = sourceItem.Token + 1
	order.SourceItems[#order.SourceItems + 1] = sourceItem
	order.Message = TrimText(itemData.MailSubject or itemData.Message or order.Message)
	order.UpdatedAt = TimestampText()

	if not state.SelectedOrderId then
		state.SelectedOrderId = order.Id
	end

	if isNewOrder then
		WorkbenchDebug("queued mailbox disenchant order for", customer, "(" .. tostring(#order.SourceItems) .. " items)")
		if not IsPartyJoinSoundModeEnabled() and PlayQueueAlertSound() then
			WorkbenchDebug("played queue alert for", customer)
		end
	else
		WorkbenchDebug("updated mailbox disenchant order for", customer, "(" .. tostring(#order.SourceItems) .. " items)")
	end

	Workbench.Refresh()
	return order, sourceItem
end

function Workbench.AddLockboxMailItem(customer, itemData)
	local state = Workbench.EnsureState()
	local order
	local isNewOrder = false
	local sourceItem
	local lootKey

	if not customer or customer == "" or type(itemData) ~= "table" then
		return nil
	end

	for _, existing in ipairs(state.Orders) do
		if existing.Kind == "lockbox" and existing.Customer == customer then
			order = EnsureOrderFields(existing)
			break
		end
	end

	if not order then
		order = EnsureOrderFields({
			Id = state.NextOrderId,
			Customer = customer,
			Kind = "lockbox",
		})
		state.NextOrderId = state.NextOrderId + 1
		state.Orders[#state.Orders + 1] = order
		isNewOrder = true
	end

	lootKey = TrimText(itemData.LootKey)
	sourceItem = FindSourceItemByLootKey(order, lootKey)
	if sourceItem then
		order.UpdatedAt = TimestampText()
		Workbench.Refresh()
		return order, sourceItem
	end

	sourceItem = EnsureDisenchantItemFields({
		Token = order.NextSourceItemToken,
		Name = itemData.Name,
		Link = itemData.Link,
		LootKey = lootKey,
		ItemId = itemData.ItemId,
		Quality = itemData.Quality,
		MailSubject = itemData.MailSubject,
		Status = "queued",
		CreatedAt = TimestampText(),
		UpdatedAt = TimestampText(),
		IsLocked = itemData.IsLocked,
	})
	order.NextSourceItemToken = sourceItem.Token + 1
	order.SourceItems[#order.SourceItems + 1] = sourceItem
	order.Message = TrimText(itemData.MailSubject or itemData.Message or order.Message)
	order.UpdatedAt = TimestampText()

	if not state.SelectedOrderId then
		state.SelectedOrderId = order.Id
	end

	if isNewOrder then
		WorkbenchDebug("queued mailbox lockbox order for", customer, "(" .. tostring(#order.SourceItems) .. " items)")
		if not IsPartyJoinSoundModeEnabled() and PlayQueueAlertSound() then
			WorkbenchDebug("played queue alert for", customer)
		end
	else
		WorkbenchDebug("updated mailbox lockbox order for", customer, "(" .. tostring(#order.SourceItems) .. " items)")
	end

	Workbench.Refresh()
	return order, sourceItem
end

function Workbench.SetDisenchantItemLocation(orderId, itemToken, bag, slot)
	local order = Workbench.GetOrderById(orderId)
	local sourceItem

	if not IsDisenchantOrder(order) then
		return false
	end

	sourceItem = FindSourceItemByToken(order, itemToken)
	if not sourceItem then
		return false
	end

	bag = tonumber(bag)
	slot = tonumber(slot)
	if sourceItem.Bag == bag and sourceItem.Slot == slot then
		return false
	end

	sourceItem.Bag = bag
	sourceItem.Slot = slot
	sourceItem.UpdatedAt = TimestampText()
	order.UpdatedAt = TimestampText()
	return true
end

function Workbench.SetLockboxItemLocation(orderId, itemToken, bag, slot, isLocked)
	local order = Workbench.GetOrderById(orderId)
	local sourceItem
	local normalizedLocked = isLocked ~= nil and (isLocked and true or false) or nil

	if not IsLockboxOrder(order) then
		return false
	end

	sourceItem = FindSourceItemByToken(order, itemToken)
	if not sourceItem then
		return false
	end

	bag = tonumber(bag)
	slot = tonumber(slot)
	if sourceItem.Bag == bag and sourceItem.Slot == slot and sourceItem.IsLocked == normalizedLocked then
		return false
	end

	sourceItem.Bag = bag
	sourceItem.Slot = slot
	sourceItem.IsLocked = normalizedLocked
	sourceItem.UpdatedAt = TimestampText()
	order.UpdatedAt = TimestampText()
	return true
end

function Workbench.RecordDisenchantMaterials(orderId, materialMap)
	local order = Workbench.GetOrderById(orderId)
	local changed = 0

	if not IsDisenchantOrder(order) or type(materialMap) ~= "table" then
		return 0
	end

	order.ReturnMaterials = order.ReturnMaterials or {}
	for materialKey, materialData in pairs(materialMap) do
		local normalized = NormalizeDisenchantMaterialEntry(materialData, materialKey)
		if normalized then
			local existing = order.ReturnMaterials[normalized.Key]
			if existing then
				existing.Count = NormalizeItemCount(existing.Count) + normalized.Count
				if normalized.Name ~= "" then
					existing.Name = normalized.Name
				end
				if normalized.Link ~= "" then
					existing.Link = normalized.Link
				end
				if normalized.ItemId then
					existing.ItemId = normalized.ItemId
				end
			else
				order.ReturnMaterials[normalized.Key] = normalized
			end
			changed = changed + normalized.Count
		end
	end

	if changed > 0 then
		order.UpdatedAt = TimestampText()
		WorkbenchDebug("tracked mailbox disenchant materials for", order.Customer, "(" .. tostring(changed) .. " total)")
		Workbench.Refresh()
	end

	return changed
end

function Workbench.MarkDisenchantItemProcessed(orderId, itemToken, materialMap)
	local order = Workbench.GetOrderById(orderId)
	local sourceItem
	local changed = false

	if not IsDisenchantOrder(order) then
		return false
	end

	sourceItem = FindSourceItemByToken(order, itemToken)
	if not sourceItem then
		return false
	end

	if sourceItem.Status ~= "done" then
		sourceItem.Status = "done"
		sourceItem.Bag = nil
		sourceItem.Slot = nil
		sourceItem.UpdatedAt = TimestampText()
		changed = true
	end

	if Workbench.RecordDisenchantMaterials(orderId, materialMap) > 0 then
		changed = true
	end

	if changed then
		order.UpdatedAt = TimestampText()
		Workbench.Refresh()
	end

	return changed
end

function Workbench.MarkLockboxItemUnlocked(orderId, itemToken, bag, slot)
	local order = Workbench.GetOrderById(orderId)
	local sourceItem
	local changed = false

	if not IsLockboxOrder(order) then
		return false
	end

	sourceItem = FindSourceItemByToken(order, itemToken)
	if not sourceItem then
		return false
	end

	bag = tonumber(bag)
	slot = tonumber(slot)
	if sourceItem.Status ~= "done" then
		sourceItem.Status = "done"
		changed = true
	end
	if sourceItem.Bag ~= bag or sourceItem.Slot ~= slot or sourceItem.IsLocked ~= false then
		sourceItem.Bag = bag
		sourceItem.Slot = slot
		sourceItem.IsLocked = false
		changed = true
	end

	if changed then
		sourceItem.UpdatedAt = TimestampText()
		order.UpdatedAt = TimestampText()
		Workbench.Refresh()
	end

	return changed
end

function Workbench.PrepareLockboxReturnMail(orderId)
	local order = Workbench.GetOrderById(orderId)
	if not IsLockboxOrder(order) then
		return false
	end

	if EC and EC.PrepareLockboxReturnMail then
		return EC.PrepareLockboxReturnMail(order.Id)
	end

	return false
end

function Workbench.PrepareReturnMail(orderId)
	local order = Workbench.GetOrderById(orderId)
	if IsLockboxOrder(order) then
		return Workbench.PrepareLockboxReturnMail(orderId)
	end

	if IsDisenchantOrder(order) and EC and EC.PrepareDisenchantReturnMail then
		return EC.PrepareDisenchantReturnMail(order.Id)
	end

	return false
end

function Workbench.CastDisenchantItem(orderId, itemToken)
	local order = Workbench.GetOrderById(orderId)
	local sourceItem

	if not IsDisenchantOrder(order) then
		return false
	end

	if EC and EC.SyncDisenchantInventoryTracking then
		EC.SyncDisenchantInventoryTracking()
		order = Workbench.GetOrderById(orderId)
	end

	sourceItem = FindSourceItemByToken(order, itemToken)
	if not sourceItem or sourceItem.Status == "done" then
		return false
	end

	if sourceItem.Bag == nil or sourceItem.Slot == nil then
		print("|cFFFF1C1CEnchanter|r Couldn't find that tracked mailbox item in your bags yet. Try moving it once or reopening the mailbox to refresh tracking.")
		return false
	end

	if EC and EC.CastTrackedDisenchantItem then
		return EC.CastTrackedDisenchantItem(order.Id, sourceItem.Token, sourceItem.Bag, sourceItem.Slot)
	end

	return false
end

function Workbench.SyncGroupedOrders()
	local state = Workbench.EnsureState()
	local changed = SyncQueueOrderStates(state)
	if Workbench.Frame then
		Workbench.Refresh()
	else
		UpdateGroupedCustomerSnapshot(state)
	end
	return changed
end

function Workbench.MarkOrderAlreadyGrouped(customerName)
	local order = Workbench.GetOrderByCustomer(customerName)
	if not order then
		return false
	end

	ResetInviteDeclinedState(order)

	if IsCustomerInCurrentGroup(order.Customer) then
		if ResetGroupedState(order) and Workbench.Frame then
			Workbench.Refresh()
		end
		return true
	end

	order.AlreadyGrouped = true
	order.AlreadyGroupedAt = Now()
	order.UpdatedAt = TimestampText()
	ScheduleGroupedOrderExpiry(order)
	WorkbenchDebug("marked order as already grouped for", order.Customer)
	if Workbench.Frame then
		Workbench.Refresh()
	end
	return true
end

function Workbench.ClearOrderInviteDeclined(customerName)
	local order = Workbench.GetOrderByCustomer(customerName)
	if not order then
		return false
	end

	local changed = ResetInviteDeclinedState(order)
	if changed and Workbench.Frame then
		Workbench.Refresh()
	end
	return changed
end

function Workbench.MarkOrderInviteDeclined(customerName)
	local order = Workbench.GetOrderByCustomer(customerName)
	if not order then
		return false
	end

	ResetGroupedState(order)

	if GetDeclinedInviteRemovalSeconds() <= 0 or IsCustomerInCurrentGroup(order.Customer) then
		if ResetInviteDeclinedState(order) and Workbench.Frame then
			Workbench.Refresh()
		end
		return true
	end

	order.InviteDeclined = true
	order.InviteDeclinedAt = Now()
	order.UpdatedAt = TimestampText()
	ScheduleDeclinedInviteExpiry(order)
	WorkbenchDebug("marked order as declined invite for", order.Customer)
	if Workbench.Frame then
		Workbench.Refresh()
	end
	return true
end

OrderHasRecipe = function(order, recipeName)
	if not order or not recipeName then
		return false
	end

	for _, candidate in ipairs(order.Recipes or {}) do
		if candidate == recipeName then
			return true
		end
	end

	return false
end

local function NormalizeRecipeMatchText(text)
	text = TrimText(text)
	if text == "" then
		return ""
	end

	text = text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
	text = text:gsub("%[(.-)%]", "%1")
	text = text:lower()
	text = text:gsub("[^%w]+", " ")
	text = text:gsub("%s+", " ")
	return TrimText(text)
end

local function GetRecipeTradeLabel(recipeName)
	if type(recipeName) ~= "string" then
		return ""
	end

	return TrimText(recipeName:match("^.-%-%s*(.+)$") or recipeName)
end

local function CollectRecipeMatchTerms(recipeName)
	local terms = {}
	local seen = {}

	local function AddTerm(value)
		local normalized = NormalizeRecipeMatchText(value)
		if normalized ~= "" and not seen[normalized] then
			seen[normalized] = true
			terms[#terms + 1] = normalized
		end
	end

	AddTerm(recipeName)
	AddTerm(GetRecipeTradeLabel(recipeName))

	local recipeTags = EC and EC.DBChar and EC.DBChar.RecipeList and EC.DBChar.RecipeList[recipeName]
	if type(recipeTags) == "table" then
		for _, recipeTag in ipairs(recipeTags) do
			AddTerm(recipeTag)
		end
	end

	return terms
end

local function RecipeMatchesTradeEnchantment(recipeName, enchantmentText)
	local normalizedEnchantment = NormalizeRecipeMatchText(enchantmentText)
	local normalizedRecipeName = NormalizeRecipeMatchText(recipeName)
	local normalizedRecipeLabel = NormalizeRecipeMatchText(GetRecipeTradeLabel(recipeName))

	if normalizedEnchantment == "" then
		return false
	end

	for _, term in ipairs(CollectRecipeMatchTerms(recipeName)) do
		if term == normalizedEnchantment then
			return true
		end
	end

	if normalizedRecipeLabel ~= "" then
		if string.find(normalizedRecipeLabel, normalizedEnchantment, 1, true) or string.find(normalizedEnchantment, normalizedRecipeLabel, 1, true) then
			return true
		end
	end

	if normalizedRecipeName ~= "" and string.find(normalizedRecipeName, normalizedEnchantment, 1, true) then
		return true
	end

	return false
end

local function GetRemainingRecipeCount(order, recipeName, activeTrade)
	local remainingCount = GetRecipeRequiredCount(order, recipeName) - GetVerifiedRecipeCount(order, recipeName)
	if remainingCount <= 0 then
		return 0
	end

	if activeTrade then
		remainingCount = remainingCount - GetAppliedRecipeCount(activeTrade, recipeName)
	end

	return math.max(0, remainingCount)
end

local function GetTradeRecipeMatches(order, activeTrade, enchantmentText, onlyUnverified)
	local matches = {}
	local seen = {}

	for _, recipeName in ipairs(order and order.Recipes or {}) do
		if not seen[recipeName] then
			seen[recipeName] = true
			if (not onlyUnverified or GetRemainingRecipeCount(order, recipeName, activeTrade) > 0)
				and RecipeMatchesTradeEnchantment(recipeName, enchantmentText)
			then
				matches[#matches + 1] = recipeName
			end
		end
	end

	table.sort(matches)
	return matches
end

local function GetUnverifiedRecipeNames(order, activeTrade)
	local unverifiedRecipes = {}
	local seen = {}

	for _, recipeName in ipairs(order and order.Recipes or {}) do
		if not seen[recipeName] then
			seen[recipeName] = true
			if GetRemainingRecipeCount(order, recipeName, activeTrade) > 0 then
				unverifiedRecipes[#unverifiedRecipes + 1] = recipeName
			end
		end
	end

	table.sort(unverifiedRecipes)
	return unverifiedRecipes
end

local function ResolveTradeAppliedRecipeName(order, activeTrade, enchantmentText)
	local castedRecipeName = activeTrade and activeTrade.CastedRecipeName or nil
	local unverifiedMatches
	local allMatches
	local unverifiedRecipes
	local uniqueRecipeNames = CopyRecipeNames(order and order.Recipes or nil)

	if not order then
		return nil
	end

	if castedRecipeName
		and GetRemainingRecipeCount(order, castedRecipeName, activeTrade) > 0
		and RecipeMatchesTradeEnchantment(castedRecipeName, enchantmentText)
	then
		return castedRecipeName
	end

	unverifiedMatches = GetTradeRecipeMatches(order, activeTrade, enchantmentText, true)
	if #unverifiedMatches == 1 then
		return unverifiedMatches[1]
	end

	allMatches = GetTradeRecipeMatches(order, activeTrade, enchantmentText, false)
	if #allMatches == 1 then
		return allMatches[1]
	end

	unverifiedRecipes = GetUnverifiedRecipeNames(order, activeTrade)
	if castedRecipeName and GetRemainingRecipeCount(order, castedRecipeName, activeTrade) > 0 and #unverifiedRecipes == 1 then
		return castedRecipeName
	end

	if #unverifiedRecipes == 1 then
		return unverifiedRecipes[1]
	end

	if castedRecipeName and OrderHasRecipe(order, castedRecipeName) and #uniqueRecipeNames == 1 then
		return castedRecipeName
	end

	if #uniqueRecipeNames == 1 then
		return uniqueRecipeNames[1]
	end

	return nil
end

local function SetRecipeVerifiedInternal(order, recipeName, verified)
	local currentCount
	local changed

	if not order or not recipeName or not OrderHasRecipe(order, recipeName) then
		return false
	end

	currentCount = GetVerifiedRecipeCount(order, recipeName)
	_, changed = SetVerifiedRecipeCount(order, recipeName, currentCount + (verified and 1 or -1))
	if changed then
		order.UpdatedAt = TimestampText()
	end
	return changed
end

local function MergeTradeMaterialCounts(order, offeredMaterialCounts, alreadyRecordedCounts)
	local changed = 0
	local appliedCounts = {}

	if not order or type(offeredMaterialCounts) ~= "table" then
		return changed, appliedCounts
	end

	for _, material in ipairs(Workbench.GetMaterialSnapshot(order)) do
		local requiredCount = GetRequiredMaterialCount(material)
		local offeredCount = NormalizeItemCount(offeredMaterialCounts[material.Key] or 0)
		local alreadyRecordedCount = NormalizeItemCount(alreadyRecordedCounts and alreadyRecordedCounts[material.Key] or 0)
		local pendingCount = math.max(0, offeredCount - alreadyRecordedCount)

		if pendingCount > 0 then
			local existingCount = GetRecordedMaterialCount(order, material, requiredCount)
			local mergedCount = math.min(requiredCount, existingCount + pendingCount)
			local appliedCount = math.max(0, mergedCount - existingCount)
			if appliedCount > 0 then
				SetRecordedMaterialCount(order, material.Key, mergedCount, requiredCount)
				appliedCounts[material.Key] = appliedCount
				changed = changed + 1
			end
		end
	end

	if changed > 0 then
		order.UpdatedAt = TimestampText()
	end

	return changed, appliedCounts
end

local function AddRecordedTradeMaterialCounts(activeTrade, appliedCounts)
	if not activeTrade or type(appliedCounts) ~= "table" then
		return
	end

	activeTrade.ManuallyRecordedMaterialCounts = activeTrade.ManuallyRecordedMaterialCounts or {}
	for materialKey, appliedCount in pairs(appliedCounts) do
		local currentCount = NormalizeItemCount(activeTrade.ManuallyRecordedMaterialCounts[materialKey] or 0)
		activeTrade.ManuallyRecordedMaterialCounts[materialKey] = currentCount + NormalizeItemCount(appliedCount)
	end
end

local CommitTradeState

local function SnapshotTradeCompletionState(activeTrade)
	local currentTradeMoneyCopper

	if not activeTrade then
		return
	end

	if CountTableHasPositiveCounts(activeTrade.OfferedMaterialCounts) then
		activeTrade.CompletedMaterialCounts = CopyNormalizedCountTable(activeTrade.OfferedMaterialCounts)
	end

	currentTradeMoneyCopper = math.max(0, math.floor(tonumber(activeTrade.TargetTradeMoneyCopper) or 0))
	if currentTradeMoneyCopper > 0 then
		activeTrade.CompletedTradeMoneyCopper = currentTradeMoneyCopper
	end
end

local function GetTradeSettlementTipCopper(activeTrade, goldDelta)
	local tradeTipCopper = math.max(0, math.floor(tonumber(goldDelta) or 0))

	if not activeTrade then
		return tradeTipCopper
	end

	return math.max(tradeTipCopper, math.max(
		math.max(0, math.floor(tonumber(activeTrade.TargetTradeMoneyCopper) or 0)),
		math.max(0, math.floor(tonumber(activeTrade.CompletedTradeMoneyCopper) or 0))
	))
end

local function FinalizeSuccessfulTrade(order, activeTrade, goldDelta)
	local persistedRecipes = 0
	local persistedMaterials = 0
	local tradeTipCopper = GetTradeSettlementTipCopper(activeTrade, goldDelta)

	if not order or not activeTrade then
		return persistedRecipes, persistedMaterials, tradeTipCopper
	end

	persistedRecipes, persistedMaterials = CommitTradeState(order, activeTrade)
	if tradeTipCopper > 0 then
		order.LastObservedTipCopper = math.max(0, math.floor(tonumber(order.LastObservedTipCopper) or 0)) + tradeTipCopper
		order.PendingTipText = ""
		order.NoTipConfirmed = false
		order.UpdatedAt = TimestampText()
		if EC then
			EC.SessionGold = (tonumber(EC.SessionGold) or 0) + tradeTipCopper
		end
		WorkbenchDebug("tracked trade payment for", order.Customer, "(" .. FormatMoneyCompact(tradeTipCopper) .. ", total " .. FormatMoneyCompact(order.LastObservedTipCopper) .. ")")
	end
	MaybeSendSuccessfulTradeThanks(order, activeTrade)

	return persistedRecipes, persistedMaterials, tradeTipCopper
end

local function TradeHasDeferredCompletionEvidence(activeTrade)
	if not activeTrade or not activeTrade.OrderId then
		return false
	end

	if CountTableHasPositiveCounts(activeTrade.CompletedMaterialCounts) or CountTableHasPositiveCounts(activeTrade.OfferedMaterialCounts) then
		return true
	end
	if GetTradeSettlementTipCopper(activeTrade, 0) > 0 then
		return true
	end
	if next(activeTrade.AppliedRecipes or {}) ~= nil then
		return true
	end
	if TrimText(activeTrade.CastedRecipeName) ~= "" then
		return true
	end
	if TrimText(activeTrade.LastSeenEnchantmentText) ~= "" then
		return true
	end
	if TrimText(activeTrade.LastSeenEnchantItemName) ~= "" then
		return true
	end

	return false
end

local function QueuePendingClosedTrade(activeTrade)
	local runtime
	local pendingClosedTrades

	if not TradeHasDeferredCompletionEvidence(activeTrade) then
		return false
	end

	runtime = EnsureRuntime()
	pendingClosedTrades = runtime.PendingClosedTrades
	if type(pendingClosedTrades) ~= "table" then
		pendingClosedTrades = {}
		runtime.PendingClosedTrades = pendingClosedTrades
	end

	pendingClosedTrades[#pendingClosedTrades + 1] = activeTrade
	while #pendingClosedTrades > 3 do
		table.remove(pendingClosedTrades, 1)
	end

	return true
end

local function TakeMostRecentPendingClosedTrade()
	local runtime = EnsureRuntime()
	local pendingClosedTrades = runtime.PendingClosedTrades

	if type(pendingClosedTrades) ~= "table" or #pendingClosedTrades == 0 then
		return nil
	end

	return table.remove(pendingClosedTrades)
end

local function TrackTradeAppliedRecipe(order, activeTrade)
	if not order or not activeTrade then
		return false
	end

	local enchantInfo = CaptureTradeEnchantInfo()
	local recipeName

	activeTrade.LastSeenEnchantItemName = enchantInfo and enchantInfo.ItemName or ""
	activeTrade.LastSeenEnchantmentText = enchantInfo and enchantInfo.Enchantment or ""

	if not TradeEnchantSlotHasItem() then
		return false
	end

	recipeName = ResolveTradeAppliedRecipeName(order, activeTrade, activeTrade.LastSeenEnchantmentText)
	if not recipeName then
		WorkbenchDebug("trade enchant detected for", order.Customer, "but the recipe match was ambiguous:", activeTrade.LastSeenEnchantmentText)
		return false
	end

	activeTrade.AppliedRecipes = activeTrade.AppliedRecipes or {}
	if GetAppliedRecipeCount(activeTrade, recipeName) <= 0 then
		SetAppliedRecipeCount(activeTrade, recipeName, 1)
		WorkbenchDebug("tracked trade application for", recipeName, "on", order.Customer, "(" .. tostring(activeTrade.LastSeenEnchantmentText) .. ")")
	end
	if activeTrade.CastedRecipeName == recipeName then
		activeTrade.CastedRecipeName = nil
	end
	return true
end

local function TrackCompletedTradeCast(order, activeTrade)
	local recipeName

	if not order or not activeTrade or not activeTrade.CompletedSignal then
		return false
	end

	recipeName = activeTrade.CastedRecipeName
	if not recipeName or recipeName == "" or not OrderHasRecipe(order, recipeName) then
		return false
	end

	if GetAppliedRecipeCount(activeTrade, recipeName) <= 0 then
		SetAppliedRecipeCount(activeTrade, recipeName, 1)
		WorkbenchDebug("trade completion fell back to the recorded cast for", recipeName, "on", order.Customer)
	end
	activeTrade.CastedRecipeName = nil
	return true
end

CommitTradeState = function(order, activeTrade)
	local appliedRecipeCount = 0
	local appliedMaterialCount = 0

	if not order or not activeTrade then
		return appliedRecipeCount, appliedMaterialCount
	end

	local appliedRecipes = activeTrade.AppliedRecipeCounts
	if type(appliedRecipes) ~= "table" or next(appliedRecipes) == nil then
		appliedRecipes = activeTrade.AppliedRecipes or {}
	end

	for recipeName in pairs(appliedRecipes) do
		local currentVerifiedCount = GetVerifiedRecipeCount(order, recipeName)
		local appliedCount = GetAppliedRecipeCount(activeTrade, recipeName)
		local verifiedCount
		local changed

		verifiedCount, changed = SetVerifiedRecipeCount(order, recipeName, currentVerifiedCount + appliedCount)
		if changed then
			appliedRecipeCount = appliedRecipeCount + math.max(0, verifiedCount - currentVerifiedCount)
			order.UpdatedAt = TimestampText()
		end
	end

	appliedMaterialCount = select(1, MergeTradeMaterialCounts(
		order,
		CountTableHasPositiveCounts(activeTrade.CompletedMaterialCounts) and activeTrade.CompletedMaterialCounts or activeTrade.OfferedMaterialCounts,
		activeTrade.ManuallyRecordedMaterialCounts
	))
	return appliedRecipeCount, appliedMaterialCount
end

local function GetDisplayedVerifiedRecipeCount(order, recipeName)
	local activeTrade
	local displayedCount

	if not order or not recipeName or recipeName == "" then
		return 0
	end

	activeTrade = GetActiveTradeForOrder(order)
	displayedCount = GetVerifiedRecipeCount(order, recipeName)
	if activeTrade then
		displayedCount = displayedCount + GetAppliedRecipeCount(activeTrade, recipeName)
	end
	return math.min(GetRecipeRequiredCount(order, recipeName), displayedCount)
end

local function IsRecipeVerifiedForDisplay(order, recipeName, occurrenceIndex)
	if not order or not recipeName or recipeName == "" then
		return false
	end

	return math.max(1, NormalizeRecipeCount(occurrenceIndex or 1)) <= GetDisplayedVerifiedRecipeCount(order, recipeName)
end

local function GetDisplayedRecipeVerificationProgress(order)
	local checked = 0
	local total = 0

	order = order or Workbench.GetSelectedOrder()
	if not order then
		return 0, 0
	end

	total = #(order.Recipes or {})
	for recipeName in pairs(BuildRecipeCountMap(order.Recipes or {})) do
		checked = checked + GetDisplayedVerifiedRecipeCount(order, recipeName)
	end

	return checked, total
end

function Workbench.GetMaterialSnapshot(order)
	order = order or Workbench.GetSelectedOrder()

	if not order then
		return {}, {}
	end

	if IsDisenchantOrder(order) then
		return GetDisenchantMaterialSnapshot(order), {}
	end
	if IsLockboxOrder(order) then
		return {}, {}
	end

	local materials = {}
	local byKey = {}
	local missingRecipes = {}
	local recipeMats = EC.DBChar and EC.DBChar.RecipeMats or {}

	if not order then
		return materials, missingRecipes
	end

	for _, recipeName in ipairs(order.Recipes or {}) do
		local recipeMaterials = recipeMats and recipeMats[recipeName]
		if not recipeMaterials or #recipeMaterials == 0 then
			missingRecipes[#missingRecipes + 1] = recipeName
		else
			for _, material in ipairs(recipeMaterials) do
				local key = MaterialKey(material)
				local displayName = GetMaterialDisplayName(material)
				if key ~= "" then
					if not byKey[key] then
						byKey[key] = {
							Key = key,
							Name = displayName ~= "" and displayName or nil,
							Link = material.Link,
							ItemId = material.ItemId,
							Count = 0,
						}
						materials[#materials + 1] = byKey[key]
					end
					if displayName ~= "" then
						byKey[key].Name = displayName
					end
					if material.Link and material.Link ~= "" then
						byKey[key].Link = material.Link
					end
					if material.ItemId and not byKey[key].ItemId then
						byKey[key].ItemId = material.ItemId
					end
					byKey[key].Count = byKey[key].Count + (tonumber(material.Count) or 1)
				end
			end
		end
	end

	table.sort(materials, function(left, right)
		return (left.Name or "") < (right.Name or "")
	end)

	return materials, missingRecipes
end

function Workbench.GetMaterialProgress(order)
	local materials = Workbench.GetMaterialSnapshot(order)
	local checked = 0
	local total = #materials

	order = order or Workbench.GetSelectedOrder()
	if not order then
		return 0, 0
	end

	if IsDisenchantOrder(order) then
		return GetDisenchantProgress(order)
	end
	if IsLockboxOrder(order) then
		return GetLockboxProgress(order)
	end

	for _, material in ipairs(materials) do
		if GetRecordedMaterialCount(order, material, GetRequiredMaterialCount(material)) >= GetRequiredMaterialCount(material) then
			checked = checked + 1
		end
	end

	return checked, total
end

function Workbench.GetRecipeVerificationProgress(order)
	local checked = 0
	local total = 0

	order = order or Workbench.GetSelectedOrder()
	if not order then
		return 0, 0
	end

	if IsDisenchantOrder(order) then
		return GetDisenchantProgress(order)
	end
	if IsLockboxOrder(order) then
		return GetLockboxProgress(order)
	end

	total = #(order.Recipes or {})
	for recipeName in pairs(BuildRecipeCountMap(order.Recipes or {})) do
		checked = checked + GetVerifiedRecipeCount(order, recipeName)
	end

	return checked, total
end

function Workbench.IsOrderVerified(order)
	local checked, total = Workbench.GetRecipeVerificationProgress(order)
	return total > 0 and checked == total, checked, total
end

function Workbench.GetTradeMaterialProgress(order)
	local materials = Workbench.GetMaterialSnapshot(order)
	local total = #materials
	local checked = 0
	local offeredState = {}
	local offeredMaterialCounts = {}
	local activeTrade = GetActiveTradeForOrder(order)

	order = order or Workbench.GetSelectedOrder()
	if not order or not activeTrade or total == 0 then
		return 0, total, offeredState, offeredMaterialCounts
	end

	local offeredCounts = CaptureTradeTargetCounts()
	for _, material in ipairs(materials) do
		local requiredCount = GetRequiredMaterialCount(material)
		local offeredCount = offeredCounts[material.Key] or offeredCounts[material.Link or ""] or offeredCounts[material.Name or ""] or 0
		offeredCount = NormalizeItemCount(offeredCount)
		offeredMaterialCounts[material.Key] = offeredCount
		if offeredCount >= requiredCount then
			offeredState[material.Key] = true
			checked = checked + 1
		end
	end

	activeTrade.OfferedMaterialState = offeredState
	activeTrade.OfferedMaterialCounts = offeredMaterialCounts
	activeTrade.OfferedCounts = offeredCounts
	activeTrade.OfferedChecked = checked
	activeTrade.OfferedTotal = total

	return checked, total, offeredState, offeredMaterialCounts
end

local function GetDisplayedMaterialProgress(order)
	local materials = Workbench.GetMaterialSnapshot(order)
	local total = #materials
	local manualChecked = 0
	local combinedChecked = 0
	local offeredChecked, _, offeredState, offeredMaterialCounts = Workbench.GetTradeMaterialProgress(order)
	local activeTrade = GetActiveTradeForOrder(order)

	order = order or Workbench.GetSelectedOrder()
	if not order then
		return 0, total, offeredState, 0, offeredChecked, offeredMaterialCounts
	end

	for _, material in ipairs(materials) do
		local requiredCount = GetRequiredMaterialCount(material)
		local manualCount = GetRecordedMaterialCount(order, material, requiredCount)
		local offeredCount = GetDisplayedTradeMaterialCount(activeTrade, material.Key)
		local combinedCount = math.min(requiredCount, manualCount + offeredCount)
		if manualCount >= requiredCount then
			manualChecked = manualChecked + 1
		end
		if combinedCount >= requiredCount then
			combinedChecked = combinedChecked + 1
		end
	end

	return combinedChecked, total, offeredState, manualChecked, offeredChecked, offeredMaterialCounts
end

function Workbench.GetTradePartnerName()
	local candidates = {}

	local function AddCandidate(value)
		if value ~= nil then
			candidates[#candidates + 1] = value
		end
	end

	if GetUnitName then
		AddCandidate(GetUnitName("NPC", true))
	end
	if UnitName then
		AddCandidate(UnitName("NPC"))
	end
	AddCandidate(_G and _G.TradeFrameRecipientNameText or nil)
	AddCandidate(_G and _G.TradeRecipientNameText or nil)
	AddCandidate(_G and _G.TradeFrameRecipientNameText and _G.TradeFrameRecipientNameText.GetText and _G.TradeFrameRecipientNameText:GetText() or nil)
	AddCandidate(_G and _G.TradeRecipientNameText and _G.TradeRecipientNameText.GetText and _G.TradeRecipientNameText:GetText() or nil)

	for _, candidate in ipairs(candidates) do
		local text = candidate
		if type(candidate) == "table" and candidate.GetText then
			text = candidate:GetText()
		end
		if type(text) == "string" and text ~= "" then
			text = text:gsub("^%s+", ""):gsub("%s+$", "")
			if text ~= "" then
				return text
			end
		end
	end

	return nil
end

function Workbench.GetGroupedCustomerCount()
	local count = 0
	local seen = {}

	for _, order in ipairs(Workbench.EnsureState().Orders) do
		local _, fullName = NormalizeCustomerName(order and order.Customer)
		if not IsMailboxItemOrder(order) and fullName ~= "" and not seen[fullName] and IsCustomerInCurrentGroup(order.Customer) then
			seen[fullName] = true
			count = count + 1
		end
	end

	return count
end

function Workbench.BeginTrade(customerName)
	local runtime = EnsureRuntime()
	local order = Workbench.GetOrderByCustomer(customerName)

	runtime.ActiveTrade = {
		CustomerName = customerName or nil,
		OrderId = order and order.Id or nil,
		CastedRecipeName = nil,
		AppliedRecipes = {},
		AppliedRecipeCounts = {},
		LastSeenEnchantItemName = "",
		LastSeenEnchantmentText = "",
		OfferedMaterialState = {},
		OfferedMaterialCounts = {},
		OfferedCounts = {},
		OfferedChecked = 0,
		OfferedTotal = 0,
		CompletedMaterialCounts = {},
		ManuallyRecordedMaterialCounts = {},
		TargetTradeMoneyCopper = GetTargetTradeMoneyCopper(),
		CompletedTradeMoneyCopper = 0,
		PlayerAccepted = false,
		TargetAccepted = false,
		AcceptedSignal = false,
		CompletedSignal = false,
		Thanked = false,
	}

	if order then
		SetSelectedOrder(order.Id)
		WorkbenchDebug("trade opened for", order.Customer)
	else
		WorkbenchDebug("trade opened with no queued order match")
	end

	Workbench.SyncActiveTrade()
	return order
end

function Workbench.SyncActiveTrade()
	local runtime = EnsureRuntime()
	local activeTrade = runtime.ActiveTrade

	if not activeTrade then
		return nil
	end

	if not activeTrade.CustomerName or activeTrade.CustomerName == "" then
		activeTrade.CustomerName = Workbench.GetTradePartnerName and Workbench.GetTradePartnerName() or nil
	end

	local order = GetOrderForActiveTrade(activeTrade)

	if order then
		SetSelectedOrder(order.Id)
		Workbench.GetTradeMaterialProgress(order)
		activeTrade.TargetTradeMoneyCopper = GetTargetTradeMoneyCopper()
		TrackTradeAppliedRecipe(order, activeTrade)
		if activeTrade.CompletedSignal or HasAcceptedTradeSettlement(activeTrade) then
			SnapshotTradeCompletionState(activeTrade)
		end
	else
		activeTrade.OfferedMaterialState = {}
		activeTrade.OfferedMaterialCounts = {}
		activeTrade.OfferedCounts = {}
		activeTrade.OfferedChecked = 0
		activeTrade.OfferedTotal = 0
		activeTrade.TargetTradeMoneyCopper = 0
	end

	Workbench.Refresh()
	return order
end

function Workbench.SetTradeAcceptState(playerAccepted, targetAccepted)
	local activeTrade = EnsureRuntime().ActiveTrade
	if not activeTrade then
		return false
	end

	activeTrade.PlayerAccepted = (tonumber(playerAccepted) or 0) > 0
	activeTrade.TargetAccepted = (tonumber(targetAccepted) or 0) > 0
	if activeTrade.PlayerAccepted and activeTrade.TargetAccepted then
		activeTrade.AcceptedSignal = true
		local order = GetOrderForActiveTrade(activeTrade)
		if order then
			TrackTradeAppliedRecipe(order, activeTrade)
		end
		SnapshotTradeCompletionState(activeTrade)
	end
	WorkbenchDebug("trade accept state", tostring(activeTrade.PlayerAccepted), tostring(activeTrade.TargetAccepted))
	Workbench.Refresh()
	return activeTrade.PlayerAccepted and activeTrade.TargetAccepted
end

function Workbench.MarkTradeCompleted()
	local activeTrade = EnsureRuntime().ActiveTrade
	local targetTrade
	local order
	local persistedRecipes
	local persistedMaterials
	local checked
	local total
	local verifiedCount
	local recipeTotal
	local autoCompleted = false

	if activeTrade and (activeTrade.CompletedSignal or HasAcceptedTradeSettlement(activeTrade)) then
		targetTrade = activeTrade
	elseif activeTrade then
		targetTrade = TakeMostRecentPendingClosedTrade() or activeTrade
	else
		targetTrade = TakeMostRecentPendingClosedTrade()
	end

	if not targetTrade then
		return false
	end

	targetTrade.CompletedSignal = true
	order = GetOrderForActiveTrade(targetTrade)
	if order then
		TrackTradeAppliedRecipe(order, targetTrade)
		TrackCompletedTradeCast(order, targetTrade)
	end
	SnapshotTradeCompletionState(targetTrade)

	if targetTrade ~= activeTrade then
		persistedRecipes, persistedMaterials = FinalizeSuccessfulTrade(order, targetTrade, 0)
		if order then
			checked, total = Workbench.GetMaterialProgress(order)
			_, verifiedCount, recipeTotal = Workbench.IsOrderVerified(order)
			if recipeTotal > 0 and verifiedCount == recipeTotal and Workbench.CompleteOrder then
				autoCompleted = Workbench.CompleteOrder(order.Id) and true or false
			end
			WorkbenchDebug("late trade completion confirmed for", order.Customer, "(" .. tostring(verifiedCount) .. "/" .. tostring(recipeTotal) .. " verified, " .. tostring(persistedRecipes) .. " recipes, " .. tostring(persistedMaterials) .. " mats, " .. tostring(checked) .. "/" .. tostring(total) .. " tracked, tip " .. FormatMoneyCompact(GetRecordedTipCopper(order)) .. ")")
		else
			WorkbenchDebug("late trade completion confirmed by UI_INFO_MESSAGE")
		end
		if not autoCompleted then
			Workbench.Refresh()
		end
	else
		WorkbenchDebug("trade completion confirmed by UI_INFO_MESSAGE")
	end
	return true
end

function Workbench.NoteRecipeCast(recipeName)
	local runtime = EnsureRuntime()
	local activeTrade = runtime.ActiveTrade
	local targetOrder = activeTrade and Workbench.GetOrderById(activeTrade.OrderId) or nil
	local activeTradeHasNamedPartner = activeTrade and activeTrade.CustomerName and activeTrade.CustomerName ~= ""

	if targetOrder and not OrderHasRecipe(targetOrder, recipeName) then
		targetOrder = nil
	end

	if not targetOrder and (not activeTrade or not activeTradeHasNamedPartner) then
		local selectedOrder = Workbench.GetSelectedOrder()
		if selectedOrder and OrderHasRecipe(selectedOrder, recipeName) then
			targetOrder = selectedOrder
		end
	end

	if not targetOrder and (not activeTrade or not activeTradeHasNamedPartner) then
		local matchingOrder
		local matchCount = 0
		for _, order in ipairs(Workbench.EnsureState().Orders) do
			if OrderHasRecipe(order, recipeName) then
				matchCount = matchCount + 1
				matchingOrder = order
				if matchCount > 1 then
					break
				end
			end
		end
		if matchCount == 1 then
			targetOrder = matchingOrder
		elseif matchCount > 1 then
			WorkbenchDebug("cast for", recipeName, "was ambiguous across multiple queued orders")
		end
	end

	if activeTrade and targetOrder then
		activeTrade.OrderId = targetOrder.Id
		activeTrade.CustomerName = targetOrder.Customer
		activeTrade.CastedRecipeName = recipeName
	end

	if targetOrder then
		WorkbenchDebug("noted cast for", recipeName, "on", targetOrder.Customer)
	else
		WorkbenchDebug("noted cast for", recipeName)
	end

	return targetOrder
end

function Workbench.FinishTrade(goldDelta)
	local runtime = EnsureRuntime()
	local activeTrade = runtime.ActiveTrade
	local tradeTipCopper = math.max(0, math.floor(tonumber(goldDelta) or 0))
	local tradeSucceeded
	local persistedRecipes = 0
	local persistedMaterials = 0
	local waitingForLateCompletion = false
	local autoCompleted = false

	if not activeTrade or not activeTrade.OrderId then
		runtime.ActiveTrade = nil
		WorkbenchDebug("trade closed with no tracked order")
		return nil
	end

	local order = Workbench.GetOrderById(activeTrade.OrderId)
	if not order then
		runtime.ActiveTrade = nil
		WorkbenchDebug("trade closed but tracked order is gone")
		return nil
	end

	TrackTradeAppliedRecipe(order, activeTrade)
	SnapshotTradeCompletionState(activeTrade)
	TrackCompletedTradeCast(order, activeTrade)

	tradeTipCopper = GetTradeSettlementTipCopper(activeTrade, tradeTipCopper)
	tradeSucceeded = activeTrade.CompletedSignal and true or HasAcceptedTradeSettlement(activeTrade) or (math.floor(tonumber(goldDelta) or 0) > 0)

	if tradeSucceeded then
		persistedRecipes, persistedMaterials, tradeTipCopper = FinalizeSuccessfulTrade(order, activeTrade, tradeTipCopper)
	elseif QueuePendingClosedTrade(activeTrade) then
		waitingForLateCompletion = true
	end

	runtime.ActiveTrade = nil

	local checked, total = Workbench.GetMaterialProgress(order)
	local isVerified, verifiedCount, recipeTotal = Workbench.IsOrderVerified(order)
	if tradeSucceeded and recipeTotal > 0 and isVerified and Workbench.CompleteOrder then
		autoCompleted = Workbench.CompleteOrder(order.Id) and true or false
	end

	if tradeSucceeded then
		if autoCompleted then
			WorkbenchDebug("trade closed for", order.Customer, "and auto-completed the order (" .. tostring(verifiedCount) .. "/" .. tostring(recipeTotal) .. " verified, " .. tostring(persistedRecipes) .. " recipes, " .. tostring(persistedMaterials) .. " mats, tip " .. FormatMoneyCompact(GetRecordedTipCopper(order)) .. ")")
		else
			WorkbenchDebug("trade closed for", order.Customer, "and updated the queue (" .. tostring(verifiedCount) .. "/" .. tostring(recipeTotal) .. " verified, " .. tostring(persistedRecipes) .. " recipes, " .. tostring(persistedMaterials) .. " mats, tip " .. FormatMoneyCompact(GetRecordedTipCopper(order)) .. ")")
		end
	elseif waitingForLateCompletion then
		WorkbenchDebug("trade closed for", order.Customer, "before completion confirmation arrived; keeping the last trade snapshot pending")
	else
		WorkbenchDebug("trade closed for", order.Customer, "without a completed exchange (tip=" .. FormatMoneyCompact(tradeTipCopper) .. ", mats=" .. tostring(checked) .. "/" .. tostring(total) .. ", verified=" .. tostring(verifiedCount) .. "/" .. tostring(recipeTotal) .. ")")
	end

	if not autoCompleted then
		Workbench.Refresh()
	end
	return tradeSucceeded and order or nil
end

function Workbench.UseTradeMaterials(orderId)
	local order = Workbench.GetOrderById(orderId)
	local activeTrade
	local offeredChecked, total, _, offeredMaterialCounts
	local changed
	local appliedCounts
	if not order then
		return false
	end

	activeTrade = GetActiveTradeForOrder(order)
	offeredChecked, total, _, offeredMaterialCounts = Workbench.GetTradeMaterialProgress(order)
	if total == 0 or offeredChecked == 0 or not activeTrade then
		return false
	end

	changed, appliedCounts = MergeTradeMaterialCounts(order, offeredMaterialCounts, activeTrade.ManuallyRecordedMaterialCounts)
	if changed <= 0 then
		return false
	end

	AddRecordedTradeMaterialCounts(activeTrade, appliedCounts)
	WorkbenchDebug("copied trade mats for", order.Customer, "(" .. tostring(offeredChecked) .. "/" .. tostring(total) .. ")")
	Workbench.Refresh()
	return true
end

function Workbench.SetMaterialChecked(orderId, materialKey, checked)
	local state = Workbench.EnsureState()
	for _, order in ipairs(state.Orders) do
		if order.Id == orderId then
			local requiredCount = 1
			for _, material in ipairs(Workbench.GetMaterialSnapshot(order)) do
				if material.Key == materialKey then
					requiredCount = GetRequiredMaterialCount(material)
					break
				end
			end
			SetRecordedMaterialCount(order, materialKey, checked and requiredCount or 0, requiredCount)
			order.UpdatedAt = TimestampText()
			WorkbenchDebug((checked and "checked" or "cleared"), "material", materialKey, "for", order.Customer)
			break
		end
	end

	Workbench.Refresh()
end

function Workbench.SetRecipeVerified(orderId, recipeName, verified)
	local state = Workbench.EnsureState()
	local autoCompleteOrderId
	for _, order in ipairs(state.Orders) do
		if order.Id == orderId then
			if SetRecipeVerifiedInternal(order, recipeName, verified) then
				WorkbenchDebug((verified and "verified" or "cleared verification for"), recipeName, "on", order.Customer)
				if verified then
					local isVerified, _, recipeTotal = Workbench.IsOrderVerified(order)
					if recipeTotal > 0 and isVerified then
						autoCompleteOrderId = order.Id
					end
				end
			end
			break
		end
	end

	if autoCompleteOrderId and Workbench.CompleteOrder and Workbench.CompleteOrder(autoCompleteOrderId) then
		return
	end

	Workbench.Refresh()
end

function Workbench.SetOrderTipText(orderId, value)
	local order = Workbench.GetOrderById(orderId)
	if not order then
		return false
	end

	local tipCopper = ParseMoneyCompact(value)
	if tipCopper == nil then
		return false
	end

	order.PendingTipText = ""
	order.LastObservedTipCopper = math.max(0, math.floor(tipCopper))
	order.NoTipConfirmed = tipCopper == 0
	order.UpdatedAt = TimestampText()
	return true
end

function Workbench.SetAllMaterials(orderId, checked)
	local state = Workbench.EnsureState()
	for _, order in ipairs(state.Orders) do
		if order.Id == orderId then
			order.MaterialCounts = order.MaterialCounts or {}
			order.MaterialState = order.MaterialState or {}
			local materials = Workbench.GetMaterialSnapshot(order)
			for _, material in ipairs(materials) do
				local requiredCount = GetRequiredMaterialCount(material)
				SetRecordedMaterialCount(order, material.Key, checked and requiredCount or 0, requiredCount)
			end
			order.UpdatedAt = TimestampText()
			WorkbenchDebug((checked and "checked" or "cleared"), "all mats for", order.Customer, "(" .. tostring(#materials) .. " items)")
			break
		end
	end

	Workbench.Refresh()
end

function Workbench.CompleteOrder(orderId)
	local state = Workbench.EnsureState()
	local order = Workbench.GetOrderById(orderId)
	local isVerified, verifiedCount, recipeTotal
	local tipCopper

	if not order then
		return false
	end

	if IsDisenchantOrder(order) then
		local completedItems, totalItems = GetDisenchantProgress(order)
		state.CompletedOrders = (tonumber(state.CompletedOrders) or 0) + 1
		WorkbenchDebug("completed mailbox disenchant order for", order.Customer, "(" .. tostring(completedItems) .. "/" .. tostring(totalItems) .. " items)")
		Workbench.RemoveOrder(orderId)
		return true
	end

	if IsLockboxOrder(order) then
		local completedItems, totalItems = GetLockboxProgress(order)
		state.CompletedOrders = (tonumber(state.CompletedOrders) or 0) + 1
		WorkbenchDebug("completed mailbox lockbox order for", order.Customer, "(" .. tostring(completedItems) .. "/" .. tostring(totalItems) .. " unlocked)")
		Workbench.RemoveOrder(orderId)
		return true
	end

	isVerified, verifiedCount, recipeTotal = Workbench.IsOrderVerified(order)
	if recipeTotal == 0 or not isVerified then
		WorkbenchDebug("refused to complete unverified order for", order.Customer)
		return false
	end

	tipCopper = select(1, GetResolvedTipCopper(order))

	state.CompletedOrders = (tonumber(state.CompletedOrders) or 0) + 1
	state.CompletedTipsCopper = (tonumber(state.CompletedTipsCopper) or 0) + tipCopper
	WorkbenchDebug("completed order for", order.Customer, "(" .. tostring(verifiedCount) .. "/" .. tostring(recipeTotal) .. ", tip " .. FormatMoneyCompact(tipCopper) .. ")")

	Workbench.RemoveOrder(orderId)
	return true
end

function Workbench.RemoveOrder(orderId)
	local state = Workbench.EnsureState()
	local removedOrderIndex

	for index, order in ipairs(state.Orders) do
		if order.Id == orderId then
			removedOrderIndex = index
			break
		end
	end

	if removedOrderIndex then
		RemoveOrderByIndex(state, removedOrderIndex, "removed order for")
	end

	if state.SelectedOrderId == orderId then
		state.SelectedOrderId = state.Orders[1] and state.Orders[1].Id or nil
	end

	Workbench.Refresh()
end

function Workbench.ClearOrders()
	local state = Workbench.EnsureState()
	local removedCount = #state.Orders

	for _, order in ipairs(state.Orders) do
		EC.PlayerList[order.Customer] = nil
		EC.LfRecipeList[order.Customer] = nil
		if EC.ClearWhisperListenMode then
			EC.ClearWhisperListenMode(order.Customer)
		end
	end

	state.Orders = {}
	state.SelectedOrderId = nil
	state.CompletedOrders = 0
	state.CompletedTipsCopper = 0
	local runtime = EnsureRuntime()
	runtime.ActiveTrade = nil
	runtime.PendingClosedTrades = nil
	runtime.GroupedExpiry = nil
	runtime.DeclinedInviteExpiry = nil

	WorkbenchDebug("cleared queue and totals (" .. tostring(removedCount) .. " orders)")
	Workbench.Refresh()
	return removedCount
end

function Workbench.InviteOrder(orderId)
	local order = Workbench.GetOrderById(orderId)
	if not order or IsMailboxItemOrder(order) then
		return false
	end

	WorkbenchDebug("manual invite for", order.Customer)
	if EC and EC.InviteCustomer then
		EC.InviteCustomer(order.Customer, "[Workbench] invite")
		return true
	end

	return false
end

function Workbench.WhisperOrder(orderId)
	local order = Workbench.GetOrderById(orderId)
	if not order or not order.Customer then
		return false
	end

	if IsMailboxItemOrder(order) then
		return Workbench.PrepareReturnMail(orderId)
	end

	if #(order.Recipes or {}) == 0 then
		return false
	end

	WorkbenchDebug("manual whisper for", order.Customer)
	if EC and EC.SendRecipeWhisperTo then
		EC.SendRecipeWhisperTo(order.Customer, order.Recipes, "[Workbench] whisper", order.RequestedRecipeCount)
		return true
	end

	return false
end

function Workbench.WhisperMissingMats(orderId)
	local order = Workbench.GetOrderById(orderId)
	if not order or not order.Customer or IsMailboxItemOrder(order) then
		return false
	end

	local materials = Workbench.GetMaterialSnapshot(order)
	local missing = {}

	for _, material in ipairs(materials) do
		local required = GetRequiredMaterialCount(material)
		local recorded = GetRecordedMaterialCount(order, material, required)
		if recorded < required then
			local itemName = material.Name or "Unknown"
			local stillNeeded = required - recorded
			missing[#missing + 1] = stillNeeded .. "x " .. itemName
		end
	end

	if #missing == 0 then
		WorkbenchDebug("no missing mats for", order.Customer)
		return false
	end

	local msg = "Still need: " .. table.concat(missing, ", ")
	WorkbenchDebug("missing mats whisper for", order.Customer, msg)
	if SendChatMessage then
		SendChatMessage(msg, "WHISPER", nil, order.Customer)
	end
	return true
end

function Workbench.AddOrUpdateOrder(customer, message, recipeMap, requestedRecipeCount)
	local state = Workbench.EnsureState()
	local recipeNames = CopyRecipeNames(recipeMap)
	local order
	local isNewOrder = false

	if not customer or customer == "" or #recipeNames == 0 then
		return nil
	end

	for _, existing in ipairs(state.Orders) do
		if existing.Kind ~= "disenchant" and existing.Customer == customer then
			order = EnsureOrderFields(existing)
			break
		end
	end

	if not order then
		order = EnsureOrderFields({
			Id = state.NextOrderId,
			Customer = customer,
			Kind = "enchant",
		})
		state.NextOrderId = state.NextOrderId + 1
		state.Orders[#state.Orders + 1] = order
		isNewOrder = true
	end

	order.Recipes = MergeRecipeLists(order.Recipes, recipeNames)
	EnsureOrderFields(order)
	order.RequestedRecipeCount = math.max(#order.Recipes, math.floor(tonumber(requestedRecipeCount) or 0))
	order.Message = TrimText(message)
	order.UpdatedAt = TimestampText()

	if not state.SelectedOrderId then
		state.SelectedOrderId = order.Id
	end

	if isNewOrder then
		RememberGroupedCustomerSnapshot(order.Customer)
		WorkbenchDebug("queued order for", customer, "(" .. tostring(#order.Recipes) .. " enchants)")
		if not IsPartyJoinSoundModeEnabled() and PlayQueueAlertSound() then
			WorkbenchDebug("played queue alert for", customer)
		end
	else
		WorkbenchDebug("updated order for", customer, "(" .. tostring(#order.Recipes) .. " enchants)")
	end

	Workbench.Refresh()
	return order
end

local function TryCastRecipe(recipeName)
	local function FindTradeSkillIndexByName()
		if not GetNumTradeSkills or not GetTradeSkillInfo then
			return nil
		end

		for index = 1, GetNumTradeSkills() or 0 do
			local name, skillType = GetTradeSkillInfo(index)
			if skillType ~= "header" and skillType ~= "subheader" and name == recipeName then
				return index
			end
		end

		return nil
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

	local function RestoreTradeSkillFilters(snapshot)
		if not snapshot then
			return
		end

		local function GetSelectedFilterIndex(filterValues)
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

		if snapshot.available ~= nil and TradeSkillOnlyShowMakeable then
			TradeSkillOnlyShowMakeable(snapshot.available)
			if TradeSkillFrameAvailableFilterCheckButton and TradeSkillFrameAvailableFilterCheckButton.SetChecked then
				TradeSkillFrameAvailableFilterCheckButton:SetChecked(snapshot.available)
			end
		end

		if SetTradeSkillSubClassFilter then
			SetTradeSkillSubClassFilter(GetSelectedFilterIndex(snapshot.subClass), 1, 1)
		end

		if SetTradeSkillInvSlotFilter then
			SetTradeSkillInvSlotFilter(GetSelectedFilterIndex(snapshot.invSlot), 1, 1)
		end

		if TradeSearchInputBox and TradeSearchInputBox.SetText then
			TradeSearchInputBox:SetText(snapshot.searchText or "")
		end
		if TradeSkillFilter_OnTextChanged and TradeSearchInputBox then
			TradeSkillFilter_OnTextChanged(TradeSearchInputBox)
		end
	end

	if GetNumTradeSkills and GetTradeSkillInfo and DoTradeSkill then
		local index = FindTradeSkillIndexByName()
		local filterSnapshot

		if not index then
			filterSnapshot = SnapshotTradeSkillFilters()
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
			if SetTradeSkillItemNameFilter then
				SetTradeSkillItemNameFilter("")
			end
			if TradeSkillFilter_OnTextChanged and TradeSearchInputBox then
				TradeSkillFilter_OnTextChanged(TradeSearchInputBox)
			end
			index = FindTradeSkillIndexByName()
		end

		if index then
			if SelectTradeSkill then
				SelectTradeSkill(index)
			end
			if TradeSkillFrame then
				TradeSkillFrame.selectedSkill = index
			end
			if TradeSkillInputBox and TradeSkillInputBox.SetNumber then
				TradeSkillInputBox:SetNumber(1)
			end
			DoTradeSkill(index, 1)
			RestoreTradeSkillFilters(filterSnapshot)
			return true
		end

		RestoreTradeSkillFilters(filterSnapshot)
	end

	local function FindCraftIndexByName()
		if not GetNumCrafts or not GetCraftInfo then
			return nil
		end

		for index = 1, GetNumCrafts() or 0 do
			local name, _, craftType = GetCraftInfo(index)
			if craftType ~= "header" and craftType ~= "subheader" and name == recipeName then
				return index
			end
		end

		return nil
	end

	local function GetCraftSlotCount()
		if not GetCraftSlots then
			return 0
		end

		return select("#", GetCraftSlots())
	end

	local function GetSelectedCraftSlotFilter()
		if not GetCraftFilter then
			return 0
		end

		if GetCraftFilter(0) then
			return 0
		end

		for index = 1, GetCraftSlotCount() do
			if GetCraftFilter(index) then
				return index
			end
		end

		return 0
	end

	local function RestoreCraftSlotFilter(index)
		if not SetCraftFilter then
			return
		end

		local normalizedIndex = math.floor(tonumber(index) or 0)
		if normalizedIndex <= 0 then
			SetCraftFilter(0)
			return
		end

		if normalizedIndex <= GetCraftSlotCount() then
			SetCraftFilter(normalizedIndex)
		else
			SetCraftFilter(0)
		end
	end

	local function SnapshotCraftFilters()
		local snapshot = {
			available = nil,
			slot = 0,
		}

		if CraftFrameAvailableFilterCheckButton and CraftFrameAvailableFilterCheckButton.GetChecked then
			snapshot.available = CraftFrameAvailableFilterCheckButton:GetChecked() and true or false
		end

		snapshot.slot = GetSelectedCraftSlotFilter()

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

		if snapshot.slot ~= nil then
			RestoreCraftSlotFilter(snapshot.slot)
		end
	end

	if GetNumCrafts and GetCraftInfo and DoCraft then
		local index = FindCraftIndexByName()
		local filterSnapshot

		if not index then
			filterSnapshot = SnapshotCraftFilters()
			if CraftOnlyShowMakeable then
				CraftOnlyShowMakeable(false)
				if CraftFrameAvailableFilterCheckButton and CraftFrameAvailableFilterCheckButton.SetChecked then
					CraftFrameAvailableFilterCheckButton:SetChecked(false)
				end
			end
			if SetCraftFilter then
				SetCraftFilter(0)
			end
			index = FindCraftIndexByName()
		end

		if index then
			local usedCraftFrameSelection = false

			if CraftFrame_SetSelection then
				usedCraftFrameSelection = pcall(CraftFrame_SetSelection, index)
			end
			if not usedCraftFrameSelection and SelectCraft then
				SelectCraft(index)
			end

			if GetCraftSelectionIndex and GetNumCrafts then
				local selectedIndex = math.floor(tonumber(GetCraftSelectionIndex()) or 0)
				local visibleCount = math.floor(tonumber(GetNumCrafts()) or 0)
				if selectedIndex < 1 or selectedIndex > visibleCount then
					RestoreCraftFilters(filterSnapshot)
					return false
				end
			end

			DoCraft(index)
			RestoreCraftFilters(filterSnapshot)
			return true
		end

		RestoreCraftFilters(filterSnapshot)
	end

	return false
end

local function PrintTradeApplyHint(recipeName)
	local activeTrade = EnsureRuntime().ActiveTrade
	if not activeTrade then
		return
	end

	print("|cFFFF1C1CEnchanter|r Click the customer's item in the trade window to apply " .. tostring(recipeName) .. ".")
end

function Workbench.CastRecipe(recipeName)
	local function MarkCastStarted(debugSuffix)
		Workbench.NoteRecipeCast(recipeName)
		PrintTradeApplyHint(recipeName)
		if debugSuffix then
			WorkbenchDebug("cast started for", recipeName, debugSuffix)
		else
			WorkbenchDebug("cast started for", recipeName)
		end
	end

	local function RetryCast(attemptIndex)
		if TryCastRecipe(recipeName) then
			MarkCastStarted("after opening enchanting")
			return
		end

		local nextDelay = TRADE_CAST_RETRY_DELAYS[attemptIndex]
		if nextDelay and C_Timer and C_Timer.After then
			C_Timer.After(nextDelay, function()
				RetryCast(attemptIndex + 1)
			end)
			return
		end

		WorkbenchDebug("cast retry still unavailable for", recipeName)
		print("|cFFFF1C1CEnchanter|r Open enchanting and click Cast again if the client did not expose the recipe list yet.")
	end

	if not recipeName or recipeName == "" then
		return false
	end

	if TryCastRecipe(recipeName) then
		MarkCastStarted()
		return true
	end

	if CastSpellByName then
		WorkbenchDebug("opening enchanting before cast for", recipeName)
		CastSpellByName("Enchanting")
	end

	if C_Timer and C_Timer.After then
		C_Timer.After(TRADE_CAST_RETRY_DELAYS[1], function()
			RetryCast(2)
		end)
	else
		WorkbenchDebug("cast retry unavailable for", recipeName)
		print("|cFFFF1C1CEnchanter|r Open enchanting and click Cast again if the client did not expose the recipe list yet.")
	end

	return false
end

local function UpdateLockButtonVisual()
	if not Workbench.Frame or not Workbench.Frame.LockButton then
		return
	end

	local state = Workbench.EnsureState()
	local button = Workbench.Frame.LockButton
	button:SetText("")

	if button.Icon then
		button.Icon:SetTexture(LOCK_BUTTON_ICON_TEXTURE)
		if state.Locked then
			button.Icon:SetVertexColor(1, 0.82, 0.18, 1)
		else
			button.Icon:SetVertexColor(0.78, 0.88, 0.72, 1)
		end
		SetRegionShown(button.Icon, true)
	end

	if button.UnlockedCheck then
		button.UnlockedCheck:SetTexture(LOCK_BUTTON_UNLOCKED_TEXTURE)
		button.UnlockedCheck:SetVertexColor(0.44, 0.86, 0.36, 1)
		SetRegionShown(button.UnlockedCheck, not state.Locked)
	end
end

local function UpdateSoundButtonVisual()
	if not Workbench.Frame or not Workbench.Frame.SoundButton then
		return
	end

	local button = Workbench.Frame.SoundButton
	local soundEnabled = IsQueueSoundEnabled()
	local soundLoud = IsQueueSoundLoud()

	button:SetText("")
	if button.Icon then
		button.Icon:SetTexture(SOUND_BUTTON_ICON_TEXTURE)
		button.Icon:SetVertexColor(1, 1, 1, soundEnabled and 1 or 0.8)
	end
	if button.SoundOn then
		button.SoundOn:SetTexture(SOUND_BUTTON_ON_TEXTURE)
		if soundLoud then
			button.SoundOn:SetVertexColor(1, 0.76, 0.18, 1)
		else
			button.SoundOn:SetVertexColor(1, 1, 1, 1)
		end
		SetRegionShown(button.SoundOn, soundEnabled)
	end
	if button.LoudText then
		button.LoudText:SetText("!")
		button.LoudText:SetTextColor(1, 0.82, 0.18, 1)
		SetRegionShown(button.LoudText, soundLoud)
	end
	if button.Muted then
		button.Muted:SetTexture(SOUND_BUTTON_MUTED_TEXTURE)
		button.Muted:SetVertexColor(1, 1, 1, 1)
		SetRegionShown(button.Muted, not soundEnabled)
	end
end

local function UpdateScanButtonText()
	if not Workbench.Frame or not Workbench.Frame.ScanButton then
		return
	end

	if EC and EC.NeedsRecipeScan and EC.NeedsRecipeScan() then
		Workbench.Frame.ScanButton:SetText("Scan")
	elseif EC and EC.IsChatScanningEnabled and EC.IsChatScanningEnabled() then
		Workbench.Frame.ScanButton:SetText("Stop")
	else
		Workbench.Frame.ScanButton:SetText("Start")
	end
end

local function UpdateAuctionSearchButton()
	if not Workbench.Frame or not Workbench.Frame.AuctionSearchButton then
		return
	end

	local frame = Workbench.Frame
	local shouldShow = EC and EC.CanSearchMissingEnchantRecipes and EC.CanSearchMissingEnchantRecipes()

	SetRegionShown(frame.AuctionSearchButton, shouldShow)
	frame.AuctionSearchButton:SetText("Search AH")

	if frame.TitleText then
		frame.TitleText:ClearAllPoints()
		frame.TitleText:SetPoint("LEFT", frame.Header, "LEFT", 10, 0)
		frame.TitleText:SetPoint("RIGHT", shouldShow and frame.AuctionSearchButton or frame.ScanButton, "LEFT", -10, 0)
	end
end

local function CreateOrderRow(parent, index)
	local row = CreateFrameCompat("Button", TOCNAME .. "WorkbenchOrder" .. index, parent)
	row:SetHeight(58)
	row:SetPoint("LEFT", parent, "LEFT", 4, 0)
	row:SetPoint("RIGHT", parent, "RIGHT", -10, 0)
	ApplyBackdrop(row, 0.16, 0.11, 0.08, 0.95, 0.58, 0.41, 0.22, 1)

	row.TypeIcon = row:CreateTexture(nil, "ARTWORK")
	row.TypeIcon:SetPoint("TOPLEFT", row, "TOPLEFT", 10, -10)
	row.TypeIcon:SetSize(16, 16)
	row.TypeIcon:Hide()

	row.NameText = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	row.NameText:SetPoint("TOPLEFT", row.TypeIcon, "TOPRIGHT", 6, 2)
	row.NameText:SetPoint("RIGHT", row, "RIGHT", -126, 0)
	row.NameText:SetJustifyH("LEFT")

	row.MetaText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	row.MetaText:SetPoint("TOPLEFT", row.NameText, "BOTTOMLEFT", 0, -4)
	row.MetaText:SetPoint("RIGHT", row, "RIGHT", -126, 0)
	row.MetaText:SetJustifyH("LEFT")

	row.SummaryText = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	row.SummaryText:SetPoint("TOPLEFT", row.MetaText, "BOTTOMLEFT", 0, -4)
	row.SummaryText:SetPoint("RIGHT", row, "RIGHT", -126, 0)
	row.SummaryText:SetJustifyH("LEFT")

	row.RemoveButton = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
	row.RemoveButton:SetSize(22, 18)
	row.RemoveButton:SetPoint("TOPRIGHT", row, "TOPRIGHT", -6, -6)
	row.RemoveButton:SetText("X")
	ApplyElvUISkin(row.RemoveButton, "button")
	row.RemoveButton:SetScript("OnClick", function(self)
		if self.OrderId then
			Workbench.RemoveOrder(self.OrderId)
		end
	end)

	row.PartyCheck = row:CreateTexture(nil, "ARTWORK")
	row.PartyCheck:SetPoint("TOPRIGHT", row.RemoveButton, "TOPLEFT", -4, 0)
	row.PartyCheck:SetSize(16, 16)
	row.PartyCheck:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
	row.PartyCheck:SetVertexColor(0.45, 0.82, 0.42)
	row.PartyCheck:Hide()

	row.InviteButton = CreateFrame("Button", nil, row)
	row.InviteButton:SetSize(20, 20)
	row.InviteButton:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", -6, 5)
	row.InviteButton:SetNormalTexture("Interface\\Icons\\Achievement_GuildRep_01")
	row.InviteButton:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square")
	row.InviteButton:SetScript("OnEnter", function(self)
		if GameTooltip then
			GameTooltip:SetOwner(self, "ANCHOR_TOP")
			GameTooltip:SetText(self.TooltipText or "Invite to group", 1, 1, 1)
			GameTooltip:Show()
		end
	end)
	row.InviteButton:SetScript("OnLeave", function()
		if GameTooltip then
			GameTooltip:Hide()
		end
	end)
	row.InviteButton:SetScript("OnClick", function(self)
		if self.OrderId then
			Workbench.InviteOrder(self.OrderId)
		end
	end)

	row.WhisperButton = CreateFrame("Button", nil, row)
	row.WhisperButton:SetSize(20, 20)
	row.WhisperButton:SetPoint("RIGHT", row.InviteButton, "LEFT", -4, 0)
	row.WhisperButton:SetNormalTexture("Interface\\Icons\\INV_Letter_15")
	row.WhisperButton:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square")
	row.WhisperButton:SetScript("OnEnter", function(self)
		if GameTooltip then
			GameTooltip:SetOwner(self, "ANCHOR_TOP")
			GameTooltip:SetText(self.TooltipText or "Whisper customer", 1, 1, 1)
			GameTooltip:Show()
		end
	end)
	row.WhisperButton:SetScript("OnLeave", function()
		if GameTooltip then
			GameTooltip:Hide()
		end
	end)
	row.WhisperButton:SetScript("OnClick", function(self)
		if self.OrderId then
			Workbench.WhisperOrder(self.OrderId)
		end
	end)

	row.MatsButton = CreateFrame("Button", nil, row)
	row.MatsButton:SetSize(20, 20)
	row.MatsButton:SetPoint("RIGHT", row.WhisperButton, "LEFT", -4, 0)
	row.MatsButton:SetNormalTexture("Interface\\Icons\\Trade_Alchemy")
	row.MatsButton:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square")
	row.MatsButton:SetScript("OnEnter", function(self)
		if GameTooltip then
			GameTooltip:SetOwner(self, "ANCHOR_TOP")
			GameTooltip:SetText(self.TooltipText or "Whisper missing materials", 1, 1, 1)
			GameTooltip:Show()
		end
	end)
	row.MatsButton:SetScript("OnLeave", function()
		if GameTooltip then
			GameTooltip:Hide()
		end
	end)
	row.MatsButton:SetScript("OnClick", function(self)
		if self.OrderId then
			Workbench.WhisperMissingMats(self.OrderId)
		end
	end)

	row:SetScript("OnClick", function(self)
		if self.OrderId then
			Workbench.SelectOrder(self.OrderId)
		end
	end)

	return row
end

local function CreateRecipeLine(parent, index)
	local line = CreateFrameCompat("Frame", TOCNAME .. "WorkbenchRecipe" .. index, parent)
	line:SetHeight(24)
	line:SetPoint("LEFT", parent, "LEFT", 0, 0)
	line:SetPoint("RIGHT", parent, "RIGHT", 0, 0)

	line.NameText = line:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	line.NameText:SetPoint("LEFT", line, "LEFT", 0, 0)
	line.NameText:SetJustifyH("LEFT")

	line.StatusAnchor = CreateFrameCompat("Frame", nil, line)
	line.StatusAnchor:SetPoint("RIGHT", line, "RIGHT", 0, 0)
	line.StatusAnchor:SetSize(18, 18)

	line.StatusCheck = line.StatusAnchor:CreateTexture(nil, "ARTWORK")
	line.StatusCheck:SetPoint("CENTER", line.StatusAnchor, "CENTER", 0, 0)
	line.StatusCheck:SetSize(18, 18)
	line.StatusCheck:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
	line.StatusCheck:SetVertexColor(0.45, 0.82, 0.42)
	line.StatusCheck:Hide()

	line.StatusText = line:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	line.StatusText:SetPoint("CENTER", line.StatusAnchor, "CENTER", 0, 0)
	line.StatusText:SetText("?")
	line.StatusText:SetTextColor(1, 0.82, 0.42)

	line.CastButton = CreateFrame("Button", nil, line, "UIPanelButtonTemplate")
	line.CastButton:SetSize(56, 20)
	line.CastButton:SetPoint("RIGHT", line.StatusAnchor, "LEFT", -6, 0)
	line.CastButton:SetText("Cast")
	if line.CastButton.SetFrameLevel and line.GetFrameLevel then
		line.CastButton:SetFrameLevel(line:GetFrameLevel() + 2)
	end
	ApplyElvUISkin(line.CastButton, "button")
	line.CastButton:SetScript("OnClick", function(self)
		if self.ActionKind == "disenchant" and self.OrderId and self.ItemToken then
			Workbench.CastDisenchantItem(self.OrderId, self.ItemToken)
		elseif self.RecipeName then
			Workbench.CastRecipe(self.RecipeName)
		end
	end)

	line.DisenchantButton = CreateFrame("Button", nil, line, "UIPanelButtonTemplate")
	line.DisenchantButton:SetSize(56, 20)
	line.DisenchantButton:SetPoint("RIGHT", line.StatusAnchor, "LEFT", -6, 0)
	line.DisenchantButton:SetText("DE")
	if line.DisenchantButton.SetFrameLevel and line.GetFrameLevel then
		line.DisenchantButton:SetFrameLevel(line:GetFrameLevel() + 2)
	end
	ApplyElvUISkin(line.DisenchantButton, "button")
	line.DisenchantButton:SetScript("OnClick", function(self)
		if self.OrderId and self.ItemToken then
			Workbench.CastDisenchantItem(self.OrderId, self.ItemToken)
		end
	end)
	line.DisenchantButton:Hide()
	line.NameText:SetPoint("RIGHT", line.CastButton, "LEFT", -8, 0)
	line.CastButton:Show()

	return line
end

local function CreateMaterialLine(parent, index)
	local line = CreateFrameCompat("Frame", TOCNAME .. "WorkbenchMaterial" .. index, parent)
	line:SetHeight(22)
	line:SetPoint("LEFT", parent, "LEFT", 0, 0)
	line:SetPoint("RIGHT", parent, "RIGHT", 0, 0)

	line.StatusCheck = line:CreateTexture(nil, "ARTWORK")
	line.StatusCheck:SetPoint("LEFT", line, "LEFT", 0, 0)
	line.StatusCheck:SetSize(18, 18)
	line.StatusCheck:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
	line.StatusCheck:SetVertexColor(0.45, 0.82, 0.42)
	line.StatusCheck:Hide()

	line.StatusText = line:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	line.StatusText:SetPoint("CENTER", line.StatusCheck, "CENTER", 0, 0)
	line.StatusText:SetText("?")
	line.StatusText:SetTextColor(1, 0.82, 0.42)

	line.Text = line:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	line.Text:SetPoint("LEFT", line.StatusCheck, "RIGHT", 4, 0)
	line.Text:SetPoint("RIGHT", line, "RIGHT", 0, 0)
	line.Text:SetJustifyH("LEFT")

	return line
end

function Workbench.CreateFrame()
	if Workbench.Frame or not CreateFrame then
		return Workbench.Frame
	end

	local frame = CreateFrameCompat("Frame", TOCNAME .. "WorkbenchFrame", UIParent)
	Workbench.Frame = frame
	WorkbenchDebug("created workbench frame")
	ApplyFrameSize(frame)
	frame:SetMovable(true)
	if frame.SetResizable then
		frame:SetResizable(true)
	end
	if frame.SetResizeBounds then
		frame:SetResizeBounds(MIN_FRAME_WIDTH, MIN_FRAME_HEIGHT, MAX_FRAME_WIDTH, MAX_FRAME_HEIGHT)
	elseif frame.SetMinResize then
		frame:SetMinResize(MIN_FRAME_WIDTH, MIN_FRAME_HEIGHT)
		if frame.SetMaxResize then
			frame:SetMaxResize(MAX_FRAME_WIDTH, MAX_FRAME_HEIGHT)
		end
	end
	if frame.SetClampedToScreen then
		frame:SetClampedToScreen(true)
	end
	frame:EnableMouse(true)
	frame:RegisterForDrag("LeftButton")
	frame:SetFrameStrata("DIALOG")
	if frame.SetToplevel then
		frame:SetToplevel(true)
	end
	ApplyBackdrop(frame, 0.08, 0.06, 0.05, 0.97, 0.72, 0.52, 0.23, 1)
	ApplyElvUISkin(frame, "frame")
	ApplyFramePosition(frame)

	frame.Header = CreateFrameCompat("Frame", nil, frame)
	frame.Header:SetPoint("TOPLEFT", frame, "TOPLEFT", 8, -8)
	frame.Header:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -8, -8)
	frame.Header:SetHeight(30)
	if frame.Header.SetFrameLevel and frame.GetFrameLevel then
		frame.Header:SetFrameLevel(frame:GetFrameLevel() + 1)
	end
	ApplyBackdrop(frame.Header, 0.21, 0.12, 0.07, 0.98, 0.58, 0.39, 0.18, 1)
	frame.Header:EnableMouse(true)
	frame.Header:RegisterForDrag("LeftButton")
	frame.Header:SetScript("OnDragStart", function()
		if not Workbench.EnsureState().Locked then
			WorkbenchDebug("drag start")
			frame:StartMoving()
		end
	end)
	frame.Header:SetScript("OnDragStop", function()
		frame:StopMovingOrSizing()
		SaveFramePosition(frame)
	end)

	frame.CloseButton = CreateFrame("Button", nil, frame.Header, "UIPanelButtonTemplate")
	frame.CloseButton:SetSize(22, 20)
	frame.CloseButton:SetPoint("RIGHT", frame.Header, "RIGHT", -6, 0)
	frame.CloseButton:SetText("X")
	if frame.CloseButton.SetFrameLevel and frame.Header.GetFrameLevel then
		frame.CloseButton:SetFrameLevel(frame.Header:GetFrameLevel() + 2)
	end
	ApplyElvUISkin(frame.CloseButton, "button")
	frame.CloseButton:SetScript("OnClick", function()
		Workbench.Hide()
	end)

	frame.ConfigButton = CreateFrame("Button", nil, frame.Header, "UIPanelButtonTemplate")
	frame.ConfigButton:SetSize(24, 20)
	frame.ConfigButton:SetPoint("RIGHT", frame.CloseButton, "LEFT", -6, 0)
	frame.ConfigButton:SetText("")
	if frame.ConfigButton.SetFrameLevel and frame.Header.GetFrameLevel then
		frame.ConfigButton:SetFrameLevel(frame.Header:GetFrameLevel() + 2)
	end
	ApplyElvUISkin(frame.ConfigButton, "button")
	frame.ConfigButton.Icon = frame.ConfigButton:CreateTexture(nil, "ARTWORK")
	frame.ConfigButton.Icon:SetSize(14, 14)
	frame.ConfigButton.Icon:SetPoint("CENTER", frame.ConfigButton, "CENTER", 0, 0)
	if frame.ConfigButton.Icon.SetAtlas then
		frame.ConfigButton.Icon:SetAtlas(CONFIG_BUTTON_ICON_ATLAS)
	else
		frame.ConfigButton.Icon:SetTexture("Interface\\PaperDollInfoFrame\\UI-GearManager-Button")
	end
	frame.ConfigButton:SetScript("OnClick", function()
		if EC and EC.OpenConfigPanel then
			EC.OpenConfigPanel(1)
		elseif EC and EC.Options and EC.Options.Open then
			EC.Options.Open(1)
		end
	end)

	frame.LockButton = CreateFrame("Button", nil, frame.Header, "UIPanelButtonTemplate")
	frame.LockButton:SetSize(24, 20)
	frame.LockButton:SetPoint("RIGHT", frame.ConfigButton, "LEFT", -6, 0)
	frame.LockButton:SetText("")
	if frame.LockButton.SetFrameLevel and frame.Header.GetFrameLevel then
		frame.LockButton:SetFrameLevel(frame.Header:GetFrameLevel() + 2)
	end
	ApplyElvUISkin(frame.LockButton, "button")
	frame.LockButton.Icon = frame.LockButton:CreateTexture(nil, "ARTWORK")
	frame.LockButton.Icon:SetSize(14, 14)
	frame.LockButton.Icon:SetPoint("CENTER", frame.LockButton, "CENTER", 0, 0)
	frame.LockButton.UnlockedCheck = frame.LockButton:CreateTexture(nil, "OVERLAY")
	frame.LockButton.UnlockedCheck:SetSize(11, 11)
	frame.LockButton.UnlockedCheck:SetPoint("BOTTOMRIGHT", frame.LockButton, "BOTTOMRIGHT", -1, 1)
	frame.LockButton:SetScript("OnClick", function()
		local state = Workbench.EnsureState()
		state.Locked = not state.Locked
		UpdateLockButtonVisual()
		WorkbenchDebug("frame", state.Locked and "locked" or "unlocked")
	end)

	frame.SoundButton = CreateFrame("Button", nil, frame.Header, "UIPanelButtonTemplate")
	frame.SoundButton:SetSize(24, 20)
	frame.SoundButton:SetPoint("RIGHT", frame.LockButton, "LEFT", -6, 0)
	frame.SoundButton:SetText("")
	if frame.SoundButton.SetFrameLevel and frame.Header.GetFrameLevel then
		frame.SoundButton:SetFrameLevel(frame.Header:GetFrameLevel() + 2)
	end
	ApplyElvUISkin(frame.SoundButton, "button")
	frame.SoundButton.Icon = frame.SoundButton:CreateTexture(nil, "ARTWORK")
	frame.SoundButton.Icon:SetSize(14, 14)
	frame.SoundButton.Icon:SetPoint("CENTER", frame.SoundButton, "CENTER", 0, 0)
	frame.SoundButton.SoundOn = frame.SoundButton:CreateTexture(nil, "OVERLAY")
	frame.SoundButton.SoundOn:SetSize(14, 14)
	frame.SoundButton.SoundOn:SetPoint("CENTER", frame.SoundButton, "CENTER", 0, 0)
	frame.SoundButton.Muted = frame.SoundButton:CreateTexture(nil, "OVERLAY")
	frame.SoundButton.Muted:SetSize(14, 14)
	frame.SoundButton.Muted:SetPoint("CENTER", frame.SoundButton, "CENTER", 0, 0)
	frame.SoundButton.LoudText = frame.SoundButton:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	frame.SoundButton.LoudText:SetPoint("TOPRIGHT", frame.SoundButton, "TOPRIGHT", -3, -1)
	frame.SoundButton.LoudText:SetText("!")
	frame.SoundButton.LoudText:SetTextColor(1, 0.82, 0.18, 1)
	frame.SoundButton:SetScript("OnClick", function()
		local state = Workbench.EnsureState()
		if state.SoundEnabled == false then
			state.SoundEnabled = true
		elseif state.SoundEnabled == true then
			state.SoundEnabled = "loud"
		else
			state.SoundEnabled = false
		end
		UpdateSoundButtonVisual()
		WorkbenchDebug("queue sound", state.SoundEnabled == false and "muted" or (state.SoundEnabled == "loud" and "loud" or "normal"))
		if state.SoundEnabled ~= false then
			PreviewQueueAlertSound()
		end
	end)

	frame.ClearButton = CreateFrame("Button", nil, frame.Header, "UIPanelButtonTemplate")
	frame.ClearButton:SetSize(48, 20)
	frame.ClearButton:SetPoint("RIGHT", frame.SoundButton, "LEFT", -6, 0)
	frame.ClearButton:SetText("Clear")
	if frame.ClearButton.SetFrameLevel and frame.Header.GetFrameLevel then
		frame.ClearButton:SetFrameLevel(frame.Header:GetFrameLevel() + 2)
	end
	ApplyElvUISkin(frame.ClearButton, "button")
	frame.ClearButton:SetScript("OnClick", function()
		Workbench.ClearOrders()
	end)

	frame.ScanButton = CreateFrame("Button", nil, frame.Header, "UIPanelButtonTemplate")
	frame.ScanButton:SetSize(54, 20)
	frame.ScanButton:SetPoint("RIGHT", frame.ClearButton, "LEFT", -6, 0)
	if frame.ScanButton.SetFrameLevel and frame.Header.GetFrameLevel then
		frame.ScanButton:SetFrameLevel(frame.Header:GetFrameLevel() + 2)
	end
	ApplyElvUISkin(frame.ScanButton, "button")
	frame.ScanButton:SetScript("OnClick", function()
		if EC and EC.NeedsRecipeScan and EC.NeedsRecipeScan() then
			if EC.RunRecipeScan then
				EC.RunRecipeScan()
			end
		elseif EC and EC.ToggleChatScanning then
			EC.ToggleChatScanning()
		end
	end)

	frame.AuctionSearchButton = CreateFrame("Button", nil, frame.Header, "UIPanelButtonTemplate")
	frame.AuctionSearchButton:SetSize(82, 20)
	frame.AuctionSearchButton:SetPoint("RIGHT", frame.ScanButton, "LEFT", -6, 0)
	if frame.AuctionSearchButton.SetFrameLevel and frame.Header.GetFrameLevel then
		frame.AuctionSearchButton:SetFrameLevel(frame.Header:GetFrameLevel() + 2)
	end
	ApplyElvUISkin(frame.AuctionSearchButton, "button")
	frame.AuctionSearchButton:SetScript("OnClick", function()
		if EC and EC.SearchAuctionHouseForMissingEnchantRecipes then
			EC.SearchAuctionHouseForMissingEnchantRecipes()
		end
	end)
	frame.AuctionSearchButton:Hide()

	frame.TitleText = frame.Header:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	frame.TitleText:SetPoint("LEFT", frame.Header, "LEFT", 10, 0)
	frame.TitleText:SetText(GetWorkbenchTitleText())

	frame.ListHeader = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	frame.ListHeader:SetPoint("TOPLEFT", frame.Header, "BOTTOMLEFT", 4, -12)
	frame.ListHeader:SetText("Queue")

	frame.ListScroll = CreateFrame("ScrollFrame", TOCNAME .. "WorkbenchQueueScroll", frame, "UIPanelScrollFrameTemplate")
	frame.ListScroll:SetPoint("TOPLEFT", frame, "TOPLEFT", 14, -60)
	frame.ListScroll:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -32, -60)

	frame.ListChild = CreateFrameCompat("Frame", TOCNAME .. "WorkbenchQueueChild", frame.ListScroll)
	frame.ListChild:SetPoint("TOPLEFT", frame.ListScroll, "TOPLEFT", 0, 0)
	frame.ListChild:SetSize(400, 1)
	frame.ListScroll:SetScrollChild(frame.ListChild)
	frame.ListScroll.ScrollBar = frame.ListScroll.ScrollBar or _G[TOCNAME .. "WorkbenchQueueScrollScrollBar"]
	ApplyElvUISkin(frame.ListScroll.ScrollBar, "scrollbar")

	frame.EmptyQueueText = frame:CreateFontString(nil, "OVERLAY", "GameFontDisable")
	frame.EmptyQueueText:SetPoint("TOPLEFT", frame.ListScroll, "TOPLEFT", 8, -12)
	frame.EmptyQueueText:SetPoint("RIGHT", frame.ListScroll, "RIGHT", -8, 0)
	frame.EmptyQueueText:SetJustifyH("LEFT")
	frame.EmptyQueueText:SetText("Orders that match your enchants will stack up here.")

	frame.Detail = CreateFrameCompat("Frame", nil, frame)
	frame.Detail:SetPoint("TOPLEFT", frame.ListScroll, "BOTTOMLEFT", 0, -18)
	frame.Detail:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -14, 40)
	ApplyBackdrop(frame.Detail, 0.14, 0.1, 0.07, 0.96, 0.54, 0.37, 0.19, 1)
	ApplyElvUISkin(frame.Detail, "frame")

	frame.Detail.Scroll = CreateFrame("ScrollFrame", TOCNAME .. "WorkbenchDetailScroll", frame.Detail, "UIPanelScrollFrameTemplate")
	frame.Detail.Scroll:SetPoint("TOPLEFT", frame.Detail, "TOPLEFT", 8, -8)
	frame.Detail.Scroll:SetPoint("BOTTOMRIGHT", frame.Detail, "BOTTOMRIGHT", -28, 8)
	frame.Detail.Scroll.ScrollBar = frame.Detail.Scroll.ScrollBar or _G[TOCNAME .. "WorkbenchDetailScrollScrollBar"]
	ApplyElvUISkin(frame.Detail.Scroll.ScrollBar, "scrollbar")

	frame.Detail.Content = CreateFrameCompat("Frame", TOCNAME .. "WorkbenchDetailChild", frame.Detail.Scroll)
	frame.Detail.Content:SetPoint("TOPLEFT", frame.Detail.Scroll, "TOPLEFT", 0, 0)
	frame.Detail.Content:SetSize(DEFAULT_FRAME_WIDTH - 76, 1)
	frame.Detail.Scroll:SetScrollChild(frame.Detail.Content)

	frame.Detail.Title = frame.Detail.Content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	frame.Detail.Title:SetPoint("TOPLEFT", frame.Detail.Content, "TOPLEFT", 0, -4)
	frame.Detail.Title:SetPoint("RIGHT", frame.Detail.Content, "RIGHT", -78, 0)
	frame.Detail.Title:SetJustifyH("LEFT")

	frame.Detail.GroupCheck = frame.Detail.Content:CreateTexture(nil, "ARTWORK")
	frame.Detail.GroupCheck:SetPoint("TOPRIGHT", frame.Detail.Content, "TOPRIGHT", 0, -4)
	frame.Detail.GroupCheck:SetSize(18, 18)
	frame.Detail.GroupCheck:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
	frame.Detail.GroupCheck:SetVertexColor(0.45, 0.82, 0.42)
	frame.Detail.GroupCheck:Hide()

	frame.Detail.GroupText = frame.Detail.Content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	frame.Detail.GroupText:SetPoint("RIGHT", frame.Detail.GroupCheck, "LEFT", -2, 0)
	frame.Detail.GroupText:SetText("In group")
	frame.Detail.GroupText:SetTextColor(0.45, 0.82, 0.42)
	frame.Detail.GroupText:Hide()

	frame.Detail.Meta = frame.Detail.Content:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	frame.Detail.Meta:SetPoint("TOPLEFT", frame.Detail.Title, "BOTTOMLEFT", 0, -4)
	frame.Detail.Meta:SetPoint("RIGHT", frame.Detail.Content, "RIGHT", 0, 0)
	frame.Detail.Meta:SetJustifyH("LEFT")

	frame.Detail.Message = frame.Detail.Content:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	frame.Detail.Message:SetPoint("TOPLEFT", frame.Detail.Meta, "BOTTOMLEFT", 0, -8)
	frame.Detail.Message:SetPoint("RIGHT", frame.Detail.Content, "RIGHT", 0, 0)
	frame.Detail.Message:SetJustifyH("LEFT")
	frame.Detail.Message:SetJustifyV("TOP")

	frame.Detail.TradeHint = frame.Detail.Content:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	frame.Detail.TradeHint:SetPoint("TOPLEFT", frame.Detail.Message, "BOTTOMLEFT", 0, -8)
	frame.Detail.TradeHint:SetPoint("RIGHT", frame.Detail.Content, "RIGHT", 0, 0)
	frame.Detail.TradeHint:SetJustifyH("LEFT")
	frame.Detail.TradeHint:SetJustifyV("TOP")
	frame.Detail.TradeHint:Hide()

	frame.Detail.ActionRow = CreateFrameCompat("Frame", nil, frame.Detail.Content)
	frame.Detail.ActionRow:SetPoint("LEFT", frame.Detail.Content, "LEFT", 0, 0)
	frame.Detail.ActionRow:SetPoint("RIGHT", frame.Detail.Content, "RIGHT", 0, 0)
	frame.Detail.ActionRow:SetHeight(20)
	frame.Detail.ActionRow:Hide()

	frame.Detail.TipStatus = frame.Detail.Content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	frame.Detail.TipStatus:SetJustifyH("LEFT")
	frame.Detail.TipStatus:Hide()

	frame.Detail.CompleteButton = CreateFrame("Button", nil, frame.Detail.ActionRow, "UIPanelButtonTemplate")
	frame.Detail.CompleteButton:SetSize(72, 20)
	frame.Detail.CompleteButton:SetText("Complete")
	ApplyElvUISkin(frame.Detail.CompleteButton, "button")
	frame.Detail.CompleteButton:SetScript("OnClick", function(self)
		if self.OrderId then
			Workbench.CompleteOrder(self.OrderId)
		end
	end)
	frame.Detail.CompleteButton:Hide()

	frame.Detail.ReturnMailButton = CreateFrame("Button", nil, frame.Detail.ActionRow, "UIPanelButtonTemplate")
	frame.Detail.ReturnMailButton:SetSize(88, 20)
	frame.Detail.ReturnMailButton:SetText("Mail Return")
	ApplyElvUISkin(frame.Detail.ReturnMailButton, "button")
	frame.Detail.ReturnMailButton:SetScript("OnClick", function(self)
		if self.OrderId then
			Workbench.PrepareReturnMail(self.OrderId)
		end
	end)
	frame.Detail.ReturnMailButton:Hide()

	do
		local rh = CreateFrame("Frame", nil, frame.Detail.Content)
		rh:SetHeight(12)
		local rht = rh:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
		rht:SetPoint("TOPLEFT", rh, "TOPLEFT", 0, 0)
		rht:SetText("Enchants")
		rh.SetText = function(self, t) self.text = t; rht:SetText(t) end
		frame.Detail.RecipesHeader = rh
	end

	frame.Detail.MatsHeader = frame.Detail.Content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	frame.Detail.MatsHeader:SetText("Materials")

	frame.Detail.AllMatsButton = CreateFrame("Button", nil, frame.Detail.Content, "UIPanelButtonTemplate")
	frame.Detail.AllMatsButton:SetSize(72, 20)
	frame.Detail.AllMatsButton:SetText("All Mats")
	ApplyElvUISkin(frame.Detail.AllMatsButton, "button")
	frame.Detail.AllMatsButton:SetScript("OnClick", function()
		local order = Workbench.GetSelectedOrder()
		if order then
			Workbench.SetAllMaterials(order.Id, true)
		end
	end)

	frame.Detail.UseTradeButton = CreateFrame("Button", nil, frame.Detail.Content, "UIPanelButtonTemplate")
	frame.Detail.UseTradeButton:SetSize(78, 20)
	frame.Detail.UseTradeButton:SetText("Use Trade")
	ApplyElvUISkin(frame.Detail.UseTradeButton, "button")
	frame.Detail.UseTradeButton:SetScript("OnClick", function()
		local order = Workbench.GetSelectedOrder()
		if order then
			Workbench.UseTradeMaterials(order.Id)
		end
	end)

	frame.Detail.ClearMatsButton = CreateFrame("Button", nil, frame.Detail.Content, "UIPanelButtonTemplate")
	frame.Detail.ClearMatsButton:SetSize(60, 20)
	frame.Detail.ClearMatsButton:SetText("Clear")
	ApplyElvUISkin(frame.Detail.ClearMatsButton, "button")
	frame.Detail.ClearMatsButton:SetScript("OnClick", function()
		local order = Workbench.GetSelectedOrder()
		if order then
			Workbench.SetAllMaterials(order.Id, false)
		end
	end)

	frame.Detail.ReadyText = frame.Detail.Content:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	frame.Detail.ReadyText:SetJustifyH("LEFT")

	frame.Detail.Empty = frame.Detail.Content:CreateFontString(nil, "OVERLAY", "GameFontDisable")
	frame.Detail.Empty:SetPoint("TOPLEFT", frame.Detail.Meta, "BOTTOMLEFT", 0, -12)
	frame.Detail.Empty:SetPoint("RIGHT", frame.Detail.Content, "RIGHT", 0, 0)
	frame.Detail.Empty:SetJustifyH("LEFT")
	frame.Detail.Empty:SetText("Select an order to see enchant requests or mailbox disenchant jobs and their tracked details.")

	frame.ResizeHandle = CreateFrame("Button", nil, frame)
	frame.ResizeHandle:SetSize(16, 16)
	frame.ResizeHandle:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -10, 10)
	if frame.ResizeHandle.SetNormalTexture then
		frame.ResizeHandle:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
	end
	if frame.ResizeHandle.SetHighlightTexture then
		frame.ResizeHandle:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
	end
	if frame.ResizeHandle.SetPushedTexture then
		frame.ResizeHandle:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
	end
	frame.ResizeHandle:RegisterForDrag("LeftButton")
	frame.ResizeHandle:SetScript("OnDragStart", function()
		WorkbenchDebug("resize start")
		if frame.StartSizing then
			frame:StartSizing("BOTTOMRIGHT")
		end
	end)
	frame.ResizeHandle:SetScript("OnDragStop", function()
		frame:StopMovingOrSizing()
		SaveFrameSize(frame)
		ApplyFrameLayout(frame)
		Workbench.Refresh()
	end)

	frame.QueueCountText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	frame.QueueCountText:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 16, 20)
	frame.QueueCountText:SetPoint("RIGHT", frame.ResizeHandle, "LEFT", -10, 0)
	frame.QueueCountText:SetJustifyH("LEFT")
	frame.QueueCountText:SetText(BuildHeaderStatusText())

	frame.OrderRows = {}
	frame.Detail.RecipeLines = {}
	frame.Detail.MaterialLines = {}

	frame:SetScript("OnShow", function()
		Workbench.EnsureState().Visible = true
	end)
	frame:SetScript("OnSizeChanged", function(self)
		ApplyFrameLayout(self)
	end)
	frame:SetScript("OnHide", function()
		Workbench.EnsureState().Visible = false
		frame:StopMovingOrSizing()
	end)

	ApplyFrameLayout(frame)
	UpdateLockButtonVisual()
	UpdateSoundButtonVisual()
	UpdateScanButtonText()
	UpdateAuctionSearchButton()
	if not Workbench.EnsureState().Visible then
		frame:Hide()
	end
	return frame
end

function Workbench.Refresh()
	local frame = Workbench.Frame
	local state = Workbench.EnsureState()
	SyncQueueOrderStates(state)
	UpdateGroupedCustomerSnapshot(state)
	if not frame then
		return
	end

	frame.QueueCountText:SetText(BuildHeaderStatusText(state))
	SetRegionShown(frame.EmptyQueueText, #state.Orders == 0)
	UpdateLockButtonVisual()
	UpdateSoundButtonVisual()
	UpdateScanButtonText()
	UpdateAuctionSearchButton()
	ApplyFrameLayout(frame)
	if frame.ListScroll and frame.ListChild and frame.ListScroll.GetWidth then
		local listWidth = frame.ListScroll:GetWidth()
		if listWidth and listWidth > 0 then
			frame.ListChild:SetWidth(listWidth - 24)
		end
	end

	for index, order in ipairs(SortedOrders()) do
		if not frame.OrderRows[index] then
			frame.OrderRows[index] = CreateOrderRow(frame.ListChild, index)
		end

		local row = frame.OrderRows[index]
		local checked, total = Workbench.GetMaterialProgress(order)
		local verifiedCount, recipeTotal = Workbench.GetRecipeVerificationProgress(order)
		local isInCurrentGroup = IsCustomerInCurrentGroup(order.Customer)
		local isDisenchant = IsDisenchantOrder(order)
		local isLockbox = IsLockboxOrder(order)
		local isMailboxOrder = isDisenchant or isLockbox
		local isGroupedQueueHold = not isMailboxOrder and order.AlreadyGrouped and not isInCurrentGroup
		local readyText
		if isDisenchant then
			if total > 0 and checked == total then
				readyText = "|cFF74D06CReady to mail|r"
			elseif total > 0 then
				readyText = string.format("%d/%d disenchanted", checked, total)
			else
				readyText = "Waiting for mailbox items"
			end
		elseif isLockbox then
			if total > 0 and checked == total then
				readyText = "|cFF74D06CReady to mail|r"
			elseif total > 0 then
				readyText = string.format("%d/%d unlocked", checked, total)
			else
				readyText = "Waiting for lockboxes"
			end
		elseif recipeTotal > 0 and verifiedCount == recipeTotal then
			readyText = "|cFF74D06CVerified|r"
		elseif recipeTotal > 0 then
			readyText = string.format("%d/%d verified", verifiedCount, recipeTotal)
		elseif total > 0 and checked == total then
			readyText = "Ready"
		elseif total > 0 then
			readyText = string.format("%d/%d mats", checked, total)
		else
			readyText = "No mats snapshot"
		end

		row.OrderId = order.Id
		row.RemoveButton.OrderId = order.Id
		row.InviteButton.OrderId = order.Id
		row.InviteButton.TooltipText = "Invite to group"
		row.WhisperButton.OrderId = order.Id
		row.WhisperButton.TooltipText = isMailboxOrder and "Prepare return mail" or "Whisper customer"
		row.MatsButton.OrderId = order.Id
		row.MatsButton.TooltipText = "Whisper missing materials"
		row.NameText:SetText(order.Customer or "Unknown")
		row.MetaText:SetText(string.format("Queued %s  •  Updated %s  •  %s", order.CreatedAt or "--:--", order.UpdatedAt or "--:--", readyText))
		row.SummaryText:SetText(OrderSummary(order))
		SetRegionShown(row.PartyCheck, not isMailboxOrder and isInCurrentGroup)
		if isDisenchant then
			row.TypeIcon:SetTexture(DISENCHANT_ORDER_ICON_TEXTURE)
			row.TypeIcon:SetVertexColor(0.94, 0.78, 0.2, 1)
			row.TypeIcon:Show()
			row.InviteButton:Hide()
			row.MatsButton:Hide()
			row.WhisperButton:Show()
		elseif isLockbox then
			row.TypeIcon:SetTexture(LOCKBOX_ORDER_ICON_TEXTURE)
			row.TypeIcon:SetVertexColor(0.8, 0.9, 1, 1)
			row.TypeIcon:Show()
			row.InviteButton:Hide()
			row.MatsButton:Hide()
			row.WhisperButton:Show()
		else
			row.TypeIcon:Hide()
			row.InviteButton:Show()
			row.MatsButton:Show()
			row.WhisperButton:Show()
		end
		row:Show()

		local bgR, bgG, bgB, bgA
		local borderR, borderG, borderB, borderA
		if isMailboxOrder and checked > 0 and checked == total and state.SelectedOrderId == order.Id then
			bgR, bgG, bgB, bgA = 0.12, 0.2, 0.12, 0.98
			borderR, borderG, borderB, borderA = 0.34, 0.78, 0.34, 1
		elseif isMailboxOrder and checked > 0 and checked == total then
			bgR, bgG, bgB, bgA = 0.09, 0.16, 0.09, 0.95
			borderR, borderG, borderB, borderA = 0.28, 0.62, 0.28, 1
		elseif recipeTotal > 0 and verifiedCount == recipeTotal and state.SelectedOrderId == order.Id then
			bgR, bgG, bgB, bgA = 0.12, 0.2, 0.12, 0.98
			borderR, borderG, borderB, borderA = 0.34, 0.78, 0.34, 1
		elseif recipeTotal > 0 and verifiedCount == recipeTotal then
			bgR, bgG, bgB, bgA = 0.09, 0.16, 0.09, 0.95
			borderR, borderG, borderB, borderA = 0.28, 0.62, 0.28, 1
		elseif state.SelectedOrderId == order.Id then
			bgR, bgG, bgB, bgA = 0.24, 0.14, 0.08, 0.98
			borderR, borderG, borderB, borderA = 0.9, 0.68, 0.28, 1
		else
			bgR, bgG, bgB, bgA = 0.16, 0.11, 0.08, 0.95
			borderR, borderG, borderB, borderA = 0.58, 0.41, 0.22, 1
		end
		if isGroupedQueueHold then
			borderR, borderG, borderB, borderA = 0.86, 0.18, 0.18, 1
		end
		ApplyBackdrop(row, bgR, bgG, bgB, bgA, borderR, borderG, borderB, borderA)

		row:ClearAllPoints()
		row:SetPoint("TOPLEFT", frame.ListChild, "TOPLEFT", 4, -((index - 1) * 62))
		row:SetWidth(GetQueueListWidth(frame) - 14)
	end

	for index, row in ipairs(frame.OrderRows) do
		if index > #state.Orders then
			row:Hide()
		end
	end

	local listHeight = frame.ListScroll and frame.ListScroll.GetHeight and frame.ListScroll:GetHeight() or MIN_QUEUE_HEIGHT
	frame.ListChild:SetHeight(math.max(listHeight, (#state.Orders * 62)))
	ClampQueueScroll(frame)

	local order = Workbench.GetSelectedOrder()
	if not order then
		frame.Detail.Empty:Show()
		frame.Detail.Title:SetText("No active order selected")
		frame.Detail.Meta:SetText("")
		frame.Detail.Message:SetText("")
		frame.Detail.GroupCheck:Hide()
		frame.Detail.GroupText:Hide()
		frame.Detail.TradeHint:Hide()
		frame.Detail.ActionRow:Hide()
		frame.Detail.TipStatus:Hide()
		frame.Detail.CompleteButton:Hide()
		frame.Detail.ReturnMailButton:Hide()
		frame.Detail.RecipesHeader:Hide()
		frame.Detail.MatsHeader:Hide()
		frame.Detail.AllMatsButton:Hide()
		frame.Detail.UseTradeButton:Hide()
		frame.Detail.ClearMatsButton:Hide()
		frame.Detail.ReadyText:Hide()
		for _, line in ipairs(frame.Detail.RecipeLines) do
			line:Hide()
		end
		for _, line in ipairs(frame.Detail.MaterialLines) do
			line:Hide()
		end
		if frame.Detail.Scroll and frame.Detail.Scroll.SetVerticalScroll then
			frame.Detail.Scroll:SetVerticalScroll(0)
		end
		UpdateDetailContentHeight(frame, 0, 0)
		return
	end

	frame.Detail.Empty:Hide()
	frame.Detail.Title:SetText(order.Customer or "Unknown")

	local isDisenchant = IsDisenchantOrder(order)
	local isLockbox = IsLockboxOrder(order)
	local isMailboxOrder = isDisenchant or isLockbox
	SetRegionShown(frame.Detail.GroupCheck, not isMailboxOrder and IsCustomerInCurrentGroup(order.Customer))
	SetRegionShown(frame.Detail.GroupText, not isMailboxOrder and IsCustomerInCurrentGroup(order.Customer))

	local detailContentWidth = GetDetailContentWidth(frame)
	local recipeLineCount = 0
	local materialLineCount = 0

	if isLockbox then
		local completedItems, totalItems = GetLockboxProgress(order)
		local trackedBagItems = 0

		frame.Detail.Meta:SetText(string.format(
			"Queued %s  •  Updated %s  •  %d/%d unlocked",
			order.CreatedAt or "--:--",
			order.UpdatedAt or "--:--",
			completedItems,
			totalItems
		))
		frame.Detail.Message:SetText("Mailbox lockbox job: " .. (order.Message ~= "" and order.Message or "Queued from mailed lockboxes."))
		frame.Detail.TradeHint:Hide()

		frame.Detail.ActionRow:ClearAllPoints()
		frame.Detail.ActionRow:SetPoint("TOPLEFT", frame.Detail.Message, "BOTTOMLEFT", 0, -12)
		frame.Detail.ActionRow:SetPoint("RIGHT", frame.Detail.Content, "RIGHT", 0, 0)
		frame.Detail.ActionRow:Show()

		frame.Detail.ReturnMailButton.OrderId = order.Id
		frame.Detail.ReturnMailButton:ClearAllPoints()
		frame.Detail.ReturnMailButton:SetPoint("RIGHT", frame.Detail.ActionRow, "RIGHT", 0, 0)
		frame.Detail.ReturnMailButton:Show()

		frame.Detail.CompleteButton.OrderId = order.Id
		frame.Detail.CompleteButton:SetText("Done")
		frame.Detail.CompleteButton:ClearAllPoints()
		frame.Detail.CompleteButton:SetPoint("RIGHT", frame.Detail.ReturnMailButton, "LEFT", -6, 0)
		frame.Detail.CompleteButton:Show()

		frame.Detail.TipStatus:ClearAllPoints()
		frame.Detail.TipStatus:SetPoint("LEFT", frame.Detail.ActionRow, "LEFT", 0, 0)
		frame.Detail.TipStatus:SetPoint("RIGHT", frame.Detail.CompleteButton, "LEFT", -8, 0)
		for _, item in ipairs(order.SourceItems or {}) do
			if item.Status ~= "done" and item.Bag ~= nil and item.Slot ~= nil then
				trackedBagItems = trackedBagItems + 1
			end
		end
		if totalItems > 0 and completedItems == totalItems then
			frame.Detail.TipStatus:SetText("All lockboxes are unlocked. Prep return mail when you're ready.")
		elseif completedItems > 0 then
			frame.Detail.TipStatus:SetText(string.format("%d/%d lockboxes are unlocked.", completedItems, totalItems))
		elseif trackedBagItems > 0 then
			frame.Detail.TipStatus:SetText("Tracked bag lockboxes flip to a green check after they are unlocked.")
		else
			frame.Detail.TipStatus:SetText("Looted lockboxes will stack here until they are unlocked.")
		end
		frame.Detail.TipStatus:Show()

		frame.Detail.RecipesHeader:SetText("Lockboxes")
		frame.Detail.RecipesHeader:ClearAllPoints()
		frame.Detail.RecipesHeader:SetPoint("TOPLEFT", frame.Detail.ActionRow, "BOTTOMLEFT", 0, -12)
		frame.Detail.RecipesHeader:Show()

		for index, item in ipairs(order.SourceItems or {}) do
			if not frame.Detail.RecipeLines[index] then
				frame.Detail.RecipeLines[index] = CreateRecipeLine(frame.Detail.Content, index)
			end

			local line = frame.Detail.RecipeLines[index]
			local isDone = item.Status == "done"
			local itemText = GetDisenchantItemDisplayText(item)
			local isTrackedInBag = item.Bag ~= nil and item.Slot ~= nil

			line.NameText:ClearAllPoints()
			line.NameText:SetPoint("LEFT", line, "LEFT", 0, 0)
			line.NameText:SetText((isDone and "|cFF74D06C" or "") .. itemText .. (isDone and "|r" or ""))
			line.CastButton.ActionKind = nil
			line.CastButton.RecipeName = nil
			line.CastButton.OrderId = nil
			line.CastButton.ItemToken = nil
			line.CastButton:Hide()
			ClearDisenchantButton(line.DisenchantButton)
			if isDone then
				line.NameText:SetPoint("RIGHT", line.StatusAnchor, "LEFT", -8, 0)
				line.StatusCheck:Show()
				line.StatusText:Hide()
			elseif isTrackedInBag then
				line.NameText:SetPoint("RIGHT", line.StatusAnchor, "LEFT", -8, 0)
				line.StatusCheck:Hide()
				line.StatusText:SetText("B")
				line.StatusText:Show()
			else
				line.NameText:SetPoint("RIGHT", line.StatusAnchor, "LEFT", -8, 0)
				line.StatusCheck:Hide()
				line.StatusText:SetText("?")
				line.StatusText:Show()
			end
			line:ClearAllPoints()
			if index == 1 then
				line:SetPoint("TOPLEFT", frame.Detail.RecipesHeader, "BOTTOMLEFT", 0, -6)
			else
				line:SetPoint("TOPLEFT", frame.Detail.RecipeLines[index - 1], "BOTTOMLEFT", 0, -4)
			end
			line:SetWidth(detailContentWidth)
			line:Show()
		end
		recipeLineCount = #(order.SourceItems or {})
		for index = recipeLineCount + 1, #frame.Detail.RecipeLines do
			frame.Detail.RecipeLines[index]:Hide()
		end

		frame.Detail.MatsHeader:SetText("Return")
		frame.Detail.MatsHeader:ClearAllPoints()
		frame.Detail.MatsHeader:SetPoint(
			"TOPLEFT",
			recipeLineCount > 0 and frame.Detail.RecipeLines[recipeLineCount] or frame.Detail.RecipesHeader,
			"BOTTOMLEFT",
			0,
			-14
		)
		frame.Detail.MatsHeader:Show()
		frame.Detail.AllMatsButton:Hide()
		frame.Detail.UseTradeButton:Hide()
		frame.Detail.ClearMatsButton:Hide()
		frame.Detail.ReadyText:ClearAllPoints()
		frame.Detail.ReadyText:SetPoint("TOPLEFT", frame.Detail.MatsHeader, "BOTTOMLEFT", 0, -4)
		frame.Detail.ReadyText:SetPoint("RIGHT", frame.Detail.Content, "RIGHT", 0, 0)
		if totalItems > 0 and completedItems == totalItems then
			frame.Detail.ReadyText:SetText("|cFF74D06CUse Mail Return to prefill the send-mail window and attach unlocked lockboxes.|r")
		else
			frame.Detail.ReadyText:SetText("|cFFFFD26AUnlock the tracked lockboxes in your bags; Enchanter will mark each one complete when the bag slot reports it is unlocked.|r")
		end
		frame.Detail.ReadyText:Show()

		for index, line in ipairs(frame.Detail.MaterialLines) do
			line:Hide()
		end

		UpdateDetailContentHeight(frame, recipeLineCount, 0)
		return
	end

	if isDisenchant then
		local completedItems, totalItems = GetDisenchantProgress(order)
		local materials = Workbench.GetMaterialSnapshot(order)
		local totalMaterialCount = 0

		for _, material in ipairs(materials) do
			totalMaterialCount = totalMaterialCount + NormalizeItemCount(material.Count)
		end

		frame.Detail.Meta:SetText(string.format(
			"Queued %s  •  Updated %s  •  %d/%d disenchanted  •  %d mats tracked",
			order.CreatedAt or "--:--",
			order.UpdatedAt or "--:--",
			completedItems,
			totalItems,
			totalMaterialCount
		))
		frame.Detail.Message:SetText("Mailbox job: " .. (order.Message ~= "" and order.Message or "Queued from mailed BoE greens and blues."))
		frame.Detail.TradeHint:Hide()

		frame.Detail.ActionRow:ClearAllPoints()
		frame.Detail.ActionRow:SetPoint("TOPLEFT", frame.Detail.Message, "BOTTOMLEFT", 0, -12)
		frame.Detail.ActionRow:SetPoint("RIGHT", frame.Detail.Content, "RIGHT", 0, 0)
		frame.Detail.ActionRow:Show()

		frame.Detail.ReturnMailButton.OrderId = order.Id
		frame.Detail.ReturnMailButton:ClearAllPoints()
		frame.Detail.ReturnMailButton:SetPoint("RIGHT", frame.Detail.ActionRow, "RIGHT", 0, 0)
		frame.Detail.ReturnMailButton:Show()

		frame.Detail.CompleteButton.OrderId = order.Id
		frame.Detail.CompleteButton:SetText("Done")
		frame.Detail.CompleteButton:ClearAllPoints()
		frame.Detail.CompleteButton:SetPoint("RIGHT", frame.Detail.ReturnMailButton, "LEFT", -6, 0)
		frame.Detail.CompleteButton:Show()

		frame.Detail.TipStatus:ClearAllPoints()
		frame.Detail.TipStatus:SetPoint("LEFT", frame.Detail.ActionRow, "LEFT", 0, 0)
		frame.Detail.TipStatus:SetPoint("RIGHT", frame.Detail.CompleteButton, "LEFT", -8, 0)
		local trackedBagItems = 0
		for _, item in ipairs(order.SourceItems or {}) do
			if item.Status ~= "done" and item.Bag ~= nil and item.Slot ~= nil then
				trackedBagItems = trackedBagItems + 1
			end
		end
		if totalItems > 0 and completedItems == totalItems and totalMaterialCount > 0 then
			frame.Detail.TipStatus:SetText("All mailed items are done. Prep return mail when you're ready.")
		elseif completedItems > 0 then
			frame.Detail.TipStatus:SetText(string.format("%d/%d mailed items are finished and stacked into return mats.", completedItems, totalItems))
		elseif trackedBagItems > 0 then
			frame.Detail.TipStatus:SetText("Tracked bag items show DE. Click it to cast Disenchant on that item from the workbench.")
		else
			frame.Detail.TipStatus:SetText("Looted mailbox gear will keep stacking here until it's all disenchanted.")
		end
		frame.Detail.TipStatus:Show()

		frame.Detail.RecipesHeader:SetText("Items")
		frame.Detail.RecipesHeader:ClearAllPoints()
		frame.Detail.RecipesHeader:SetPoint("TOPLEFT", frame.Detail.ActionRow, "BOTTOMLEFT", 0, -12)
		frame.Detail.RecipesHeader:Show()

		for index, item in ipairs(order.SourceItems or {}) do
			if not frame.Detail.RecipeLines[index] then
				frame.Detail.RecipeLines[index] = CreateRecipeLine(frame.Detail.Content, index)
			end

			local line = frame.Detail.RecipeLines[index]
			local isDone = item.Status == "done"
			local itemText = GetDisenchantItemDisplayText(item)
			local isTrackedInBag = item.Bag ~= nil and item.Slot ~= nil

			line.NameText:ClearAllPoints()
			line.NameText:SetPoint("LEFT", line, "LEFT", 0, 0)
			line.NameText:SetText((isDone and "|cFF74D06C" or "") .. itemText .. (isDone and "|r" or ""))
			line.CastButton.ActionKind = nil
			line.CastButton.RecipeName = nil
			line.CastButton.OrderId = nil
			line.CastButton.ItemToken = nil
			if line.CastButton.ClearAllPoints and line.StatusAnchor then
				line.CastButton:ClearAllPoints()
				line.CastButton:SetPoint("RIGHT", line.StatusAnchor, "LEFT", -6, 0)
			end
			ClearDisenchantButton(line.DisenchantButton)
			if isDone then
				line.NameText:SetPoint("RIGHT", line.StatusAnchor, "LEFT", -8, 0)
				line.CastButton:Hide()
				line.StatusCheck:Show()
				line.StatusText:Hide()
			elseif isTrackedInBag then
				line.NameText:SetPoint("RIGHT", line.DisenchantButton, "LEFT", -8, 0)
				line.CastButton:Hide()
				if line.DisenchantButton.ClearAllPoints and line.StatusAnchor then
					line.DisenchantButton:ClearAllPoints()
					line.DisenchantButton:SetPoint("RIGHT", line.StatusAnchor, "LEFT", -6, 0)
				end
				ConfigureDisenchantButton(line.DisenchantButton, order.Id, item)
				line.StatusCheck:Hide()
				line.StatusText:SetText("B")
				line.StatusText:Show()
			else
				line.NameText:SetPoint("RIGHT", line.StatusAnchor, "LEFT", -8, 0)
				line.CastButton:Hide()
				line.StatusCheck:Hide()
				line.StatusText:SetText("?")
				line.StatusText:Show()
			end
			line:ClearAllPoints()
			if index == 1 then
				line:SetPoint("TOPLEFT", frame.Detail.RecipesHeader, "BOTTOMLEFT", 0, -6)
			else
				line:SetPoint("TOPLEFT", frame.Detail.RecipeLines[index - 1], "BOTTOMLEFT", 0, -4)
			end
			line:SetWidth(detailContentWidth)
			line:Show()
		end
		recipeLineCount = #(order.SourceItems or {})
		for index = recipeLineCount + 1, #frame.Detail.RecipeLines do
			frame.Detail.RecipeLines[index]:Hide()
		end

		frame.Detail.MatsHeader:SetText("Results")
		frame.Detail.MatsHeader:ClearAllPoints()
		frame.Detail.MatsHeader:SetPoint(
			"TOPLEFT",
			recipeLineCount > 0 and frame.Detail.RecipeLines[recipeLineCount] or frame.Detail.RecipesHeader,
			"BOTTOMLEFT",
			0,
			-14
		)
		frame.Detail.MatsHeader:Show()

		frame.Detail.AllMatsButton:Hide()
		frame.Detail.UseTradeButton:Hide()
		frame.Detail.ClearMatsButton:Hide()
		frame.Detail.ReadyText:ClearAllPoints()
		frame.Detail.ReadyText:SetPoint("TOPLEFT", frame.Detail.MatsHeader, "BOTTOMLEFT", 0, -4)
		frame.Detail.ReadyText:SetPoint("RIGHT", frame.Detail.Content, "RIGHT", 0, 0)
		if totalItems > 0 and completedItems == totalItems and totalMaterialCount > 0 then
			frame.Detail.ReadyText:SetText("|cFF74D06CEverything mailed in has been disenchanted. Use Mail Return to prefill the send-mail window and attach the tracked mats.|r")
		elseif completedItems > 0 then
			frame.Detail.ReadyText:SetText("|cFFFFD26AResults are being tracked as the mailed gear gets disenchanted. More mailbox items from this sender will keep spooling into the same order.|r")
		else
			frame.Detail.ReadyText:SetText("|cFFFFD26ALoot BoE greens or blues from the mailbox and they will keep stacking here for this sender. Disenchant the tracked items and the return mats will fill in automatically.|r")
		end
		frame.Detail.ReadyText:Show()

		for index, material in ipairs(materials) do
			if not frame.Detail.MaterialLines[index] then
				frame.Detail.MaterialLines[index] = CreateMaterialLine(frame.Detail.Content, index)
			end

			local line = frame.Detail.MaterialLines[index]
			line.StatusCheck:Show()
			line.StatusText:Hide()
			line.Text:SetText(string.format("%dx %s", NormalizeItemCount(material.Count), GetMaterialDisplayText(material)))
			line:ClearAllPoints()
			if index == 1 then
				line:SetPoint("TOPLEFT", frame.Detail.ReadyText, "BOTTOMLEFT", 0, -4)
			else
				line:SetPoint("TOPLEFT", frame.Detail.MaterialLines[index - 1], "BOTTOMLEFT", 0, -2)
			end
			line:SetWidth(detailContentWidth)
			line:Show()
		end
		materialLineCount = #materials
		for index = materialLineCount + 1, #frame.Detail.MaterialLines do
			frame.Detail.MaterialLines[index]:Hide()
		end

		UpdateDetailContentHeight(frame, recipeLineCount, materialLineCount)
		return
	end

	local activeTrade = GetActiveTradeForOrder(order)
	local checked, total, _, manualChecked, offeredChecked = GetDisplayedMaterialProgress(order)
	local verifiedCount
	local recipeTotal

	if activeTrade then
		verifiedCount, recipeTotal = GetDisplayedRecipeVerificationProgress(order)
	else
		verifiedCount, recipeTotal = Workbench.GetRecipeVerificationProgress(order)
	end
	local hasRecordedTip = GetRecordedTipCopper(order) > 0
	local readyText = total > 0 and string.format("%d/%d materials ready", checked, total) or "No materials captured yet"
	local verificationText = recipeTotal > 0 and string.format("%d/%d verified", verifiedCount, recipeTotal) or "No enchants queued"
	if recipeTotal > 0 and verifiedCount == recipeTotal then
		verificationText = "|cFF74D06CVerified|r"
	end
	frame.Detail.Meta:SetText(string.format("Queued %s  •  Updated %s  •  %s  •  %s", order.CreatedAt or "--:--", order.UpdatedAt or "--:--", verificationText, readyText))
	frame.Detail.Message:SetText("Last chat: " .. (order.Message ~= "" and order.Message or "No raw message captured"))
	if activeTrade then
		frame.Detail.TradeHint:SetText("|cFFFFD26ATrade active. Apply is optional here; accepted trades update mats, tips, and completed enchants automatically. Fully verified orders retire themselves when the trade settles.|r")
		frame.Detail.TradeHint:Show()
	else
		frame.Detail.TradeHint:Hide()
	end

	frame.Detail.ActionRow:ClearAllPoints()
	frame.Detail.ActionRow:SetPoint("TOPLEFT", activeTrade and frame.Detail.TradeHint or frame.Detail.Message, "BOTTOMLEFT", 0, activeTrade and -10 or -12)
	frame.Detail.ActionRow:SetPoint("RIGHT", frame.Detail.Content, "RIGHT", 0, 0)
	frame.Detail.ActionRow:Show()

	frame.Detail.ReturnMailButton:Hide()
	frame.Detail.CompleteButton:SetText("Complete")
	frame.Detail.CompleteButton:Hide()

	frame.Detail.TipStatus:ClearAllPoints()
	frame.Detail.TipStatus:SetPoint("LEFT", frame.Detail.ActionRow, "LEFT", 0, 0)
	frame.Detail.TipStatus:SetText(GetTipStatusText(order, activeTrade))
	frame.Detail.TipStatus:Show()
	frame.Detail.TipStatus:SetPoint("RIGHT", frame.Detail.ActionRow, "RIGHT", 0, 0)

	frame.Detail.RecipesHeader:SetText("Enchants")
	frame.Detail.RecipesHeader:ClearAllPoints()
	frame.Detail.RecipesHeader:SetPoint("TOPLEFT", frame.Detail.ActionRow, "BOTTOMLEFT", 0, -12)
	frame.Detail.RecipesHeader:Show()

	local displayedRecipeOccurrences = {}
	for index, recipeName in ipairs(order.Recipes or {}) do
		if not frame.Detail.RecipeLines[index] then
			frame.Detail.RecipeLines[index] = CreateRecipeLine(frame.Detail.Content, index)
		end
		local line = frame.Detail.RecipeLines[index]
		local recipeLink = EC.DBChar and EC.DBChar.RecipeLinks and EC.DBChar.RecipeLinks[recipeName]
		displayedRecipeOccurrences[recipeName] = (displayedRecipeOccurrences[recipeName] or 0) + 1
		local isVerified = IsRecipeVerifiedForDisplay(order, recipeName, displayedRecipeOccurrences[recipeName])
		line.NameText:ClearAllPoints()
		line.NameText:SetPoint("LEFT", line, "LEFT", 0, 0)
		ClearDisenchantButton(line.DisenchantButton)
		line.NameText:SetPoint("RIGHT", line.CastButton, "LEFT", -8, 0)
		line.NameText:SetText((isVerified and "|cFF74D06C" or "") .. (recipeLink or recipeName) .. (isVerified and "|r" or ""))
		line.CastButton.ActionKind = nil
		line.CastButton.OrderId = nil
		line.CastButton.ItemToken = nil
		line.CastButton.RecipeName = recipeName
		if line.CastButton.ClearAllPoints and line.StatusAnchor then
			line.CastButton:ClearAllPoints()
			line.CastButton:SetPoint("RIGHT", line.StatusAnchor, "LEFT", -6, 0)
		end
		line.CastButton:SetText(activeTrade and "Apply" or "Cast")
		line.CastButton:Show()
		if isVerified then
			line.StatusCheck:Show()
			line.StatusText:Hide()
		else
			line.StatusCheck:Hide()
			line.StatusText:SetText("?")
			line.StatusText:Show()
		end
		line:ClearAllPoints()
		if index == 1 then
			line:SetPoint("TOPLEFT", frame.Detail.RecipesHeader, "BOTTOMLEFT", 0, -6)
		else
			line:SetPoint("TOPLEFT", frame.Detail.RecipeLines[index - 1], "BOTTOMLEFT", 0, -4)
		end
		line:SetWidth(detailContentWidth)
		line:Show()
	end
	recipeLineCount = #(order.Recipes or {})
	for index = recipeLineCount + 1, #frame.Detail.RecipeLines do
		frame.Detail.RecipeLines[index]:Hide()
	end

	local materials, missingRecipes = Workbench.GetMaterialSnapshot(order)
	frame.Detail.MatsHeader:SetText("Materials")
	frame.Detail.MatsHeader:ClearAllPoints()
	frame.Detail.MatsHeader:SetPoint("TOPLEFT", recipeLineCount > 0 and frame.Detail.RecipeLines[recipeLineCount] or frame.Detail.RecipesHeader, "BOTTOMLEFT", 0, -14)
	frame.Detail.MatsHeader:Show()

	frame.Detail.AllMatsButton:Hide()
	frame.Detail.UseTradeButton:Hide()
	frame.Detail.ClearMatsButton:Hide()
	frame.Detail.ReadyText:ClearAllPoints()
	frame.Detail.ReadyText:SetPoint("TOPLEFT", frame.Detail.MatsHeader, "BOTTOMLEFT", 0, -4)
	frame.Detail.ReadyText:SetPoint("RIGHT", frame.Detail.Content, "RIGHT", 0, 0)

	if #materials > 0 then
		local statusBits = {}
		if recipeTotal > 0 and verifiedCount == recipeTotal then
			if activeTrade then
				statusBits[#statusBits + 1] = "|cFF74D06CAccepted trades will finish this verified order automatically when the trade settles.|r"
			elseif hasRecordedTip then
				statusBits[#statusBits + 1] = "|cFF74D06CAll requested enchants are verified. This order will retire itself automatically.|r"
			else
				statusBits[#statusBits + 1] = "|cFF74D06CAll requested enchants are verified. This order will retire itself automatically.|r"
			end
		elseif recipeTotal > 0 and verifiedCount > 0 then
			statusBits[#statusBits + 1] = "|cFFFFD26A" .. tostring(verifiedCount) .. "/" .. tostring(recipeTotal) .. " enchants verified. Accepted trades flip each enchant from ? to a green check automatically.|r"
		else
			statusBits[#statusBits + 1] = "|cFFFFD26AAccepted trades will flip each requested enchant from ? to a green check automatically.|r"
		end

		if manualChecked == total then
			statusBits[#statusBits + 1] = "|cFF74D06CAll mats are tracked.|r"
		elseif offeredChecked == total and total > 0 then
			statusBits[#statusBits + 1] = "|cFF74D06CTrade has all queued mats ready to be tracked when the trade completes.|r"
		elseif offeredChecked > 0 then
			statusBits[#statusBits + 1] = "|cFFFFD26ATrade is moving " .. tostring(checked) .. "/" .. tostring(total) .. " queued mats toward completion.|r"
		elseif total > 0 then
			statusBits[#statusBits + 1] = "|cFFFFD26AMaterials will flip from ? to a green check as trades are tracked.|r"
		end
		frame.Detail.ReadyText:SetText(table.concat(statusBits, "  "))
	else
		if recipeTotal > 0 and verifiedCount == recipeTotal then
			if activeTrade then
				frame.Detail.ReadyText:SetText("|cFF74D06CAccepted trades will finish this verified order automatically when the trade settles.|r  |cFFFF9F5AMaterials snapshot unavailable until your recipe scan exposes reagent data.|r")
			elseif hasRecordedTip then
				frame.Detail.ReadyText:SetText("|cFF74D06CAll requested enchants are verified. This order will retire itself automatically.|r  |cFFFF9F5AMaterials snapshot unavailable until your recipe scan exposes reagent data.|r")
			else
				frame.Detail.ReadyText:SetText("|cFF74D06CAll requested enchants are verified. This order will retire itself automatically.|r  |cFFFF9F5AMaterials snapshot unavailable until your recipe scan exposes reagent data.|r")
			end
		elseif recipeTotal > 0 then
			frame.Detail.ReadyText:SetText("|cFFFFD26A" .. tostring(verifiedCount) .. "/" .. tostring(recipeTotal) .. " enchants verified. Accepted trades will flip the rest automatically.|r  |cFFFF9F5AMaterials snapshot unavailable until your recipe scan exposes reagent data.|r")
		else
			frame.Detail.ReadyText:SetText("|cFFFF9F5AMaterials snapshot unavailable until your recipe scan exposes reagent data.|r")
		end
	end
	frame.Detail.ReadyText:Show()

	for index, material in ipairs(materials) do
		if not frame.Detail.MaterialLines[index] then
			frame.Detail.MaterialLines[index] = CreateMaterialLine(frame.Detail.Content, index)
		end
		local line = frame.Detail.MaterialLines[index]
		local requiredCount = GetRequiredMaterialCount(material)
		local recordedCount = GetRecordedMaterialCount(order, material, requiredCount)
		local offeredCount = GetDisplayedTradeMaterialCount(activeTrade, material.Key)
		local combinedCount = math.min(requiredCount, recordedCount + offeredCount)
		local materialText = string.format("%dx %s", requiredCount, GetMaterialDisplayText(material))
		if combinedCount > 0 and combinedCount < requiredCount then
			materialText = materialText .. " |cFFFFD26A(" .. tostring(combinedCount) .. "/" .. tostring(requiredCount) .. " tracked)|r"
		end
		if combinedCount >= requiredCount then
			line.StatusCheck:Show()
			line.StatusText:Hide()
		else
			line.StatusCheck:Hide()
			line.StatusText:SetText("?")
			line.StatusText:Show()
		end
		line.Text:SetText(materialText)
		line:ClearAllPoints()
		if index == 1 then
			line:SetPoint("TOPLEFT", frame.Detail.ReadyText, "BOTTOMLEFT", 0, -4)
		else
			line:SetPoint("TOPLEFT", frame.Detail.MaterialLines[index - 1], "BOTTOMLEFT", 0, -2)
		end
		line:SetWidth(detailContentWidth)
		line:Show()
	end
	materialLineCount = #materials
	for index = materialLineCount + 1, #frame.Detail.MaterialLines do
		frame.Detail.MaterialLines[index]:Hide()
	end

	if #missingRecipes > 0 then
		frame.Detail.ReadyText:SetText(frame.Detail.ReadyText:GetText() .. "  |cFFFF9F5AMissing mats: " .. table.concat(missingRecipes, ", ") .. "|r")
	end

	UpdateDetailContentHeight(frame, recipeLineCount, materialLineCount)
end

function Workbench.Show()
	local state = Workbench.EnsureState()
	local frame = Workbench.CreateFrame()
	if not frame then
		return
	end

	state.Visible = true
	ApplyFramePosition(frame)
	frame:Show()
	WorkbenchDebug("shown")
	if Workbench.GetSelectedOrder() and IsMailboxItemOrder(Workbench.GetSelectedOrder()) and EC and EC.SyncDisenchantInventoryTracking then
		EC.SyncDisenchantInventoryTracking()
	end
	Workbench.Refresh()
end

function Workbench.Hide()
	local state = Workbench.EnsureState()
	state.Visible = false
	if Workbench.Frame then
		Workbench.Frame:Hide()
		WorkbenchDebug("hidden")
	end
end

function Workbench.Toggle()
	local state = Workbench.EnsureState()
	local frame = Workbench.CreateFrame()
	if not frame then
		return
	end

	state.Visible = IsWorkbenchFrameShown(frame)
	if state.Visible then
		Workbench.Hide()
	else
		Workbench.Show()
	end
end

function Workbench.SyncVisibility()
	local state = Workbench.EnsureState()
	if state.Visible then
		Workbench.Show()
	elseif Workbench.Frame and IsWorkbenchFrameShown(Workbench.Frame) then
		Workbench.Frame:Hide()
	end
end

-- Ban from Enchanter: inject into player right-click menus via Menu.ModifyMenu.
-- TBC Anniversary UnitPopup builds menus with MenuUtil.CreateContextMenu and tags
-- each rootDescription as "MENU_UNIT_PARTY", "MENU_UNIT_RAID_PLAYER", etc.
-- Menu.ModifyMenu is the correct injection point; it runs before the menu is shown.

local function AddBanButton(owner, rootDescription, contextData)
	local name = contextData and contextData.name
	if not name or name == "" then
		return
	end
	rootDescription:CreateButton("Ban from Enchanter", function()
		if EC and EC.BanPlayer then
			EC.BanPlayer(name)
			if EC.RefreshBanlistUI then
				EC.RefreshBanlistUI()
			end
		end
	end)
end

local banButtonFrame = CreateFrame("Frame")
banButtonFrame:RegisterEvent("PLAYER_LOGIN")
banButtonFrame:SetScript("OnEvent", function(_, event)
	if event ~= "PLAYER_LOGIN" then
		return
	end
	banButtonFrame:UnregisterEvent("PLAYER_LOGIN")
	if type(Menu) ~= "table" or type(Menu.ModifyMenu) ~= "function" then
		return
	end
	for _, tag in ipairs({
		"MENU_UNIT_PARTY",
		"MENU_UNIT_RAID_PLAYER",
		"MENU_UNIT_PLAYER",
		"MENU_UNIT_FRIEND",
	}) do
		pcall(Menu.ModifyMenu, tag, AddBanButton)
	end
end)
