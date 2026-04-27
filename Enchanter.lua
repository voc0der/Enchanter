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
EC.GeneratedRecipeTags = EC.GeneratedRecipeTags or { enGB = {} }
EC.RecipesWithNether = {"Enchant Boots - Surefooted"}
EC.PrefixTagsCompiled = {}
EC.BlacklistCompiled = {}
EC.RecipeBlacklistMap = {}
EC.RecipeTagsMap = {}
EC.RecipeTagList = {}
EC.RecipeTagBuckets = {}
EC.RequestRecipeTagsMap = {}
EC.RequestRecipeTagList = {}
EC.RequestRecipeTagBuckets = {}
EC.EnchanterTagsNormalized = {}
EC.PendingInvites = {}
EC.SimulatedPlayers = {}
EC.Simulation = EC.Simulation or {}
EC.WhisperListenMode = EC.WhisperListenMode or {}

local pendingInviteWindow = 10
local simulationInterval = 180
local randomSeeded = false
local randomFallbackCounter = 0
local AUCTIONATOR_CALLER_ID = TOCNAME or "Enchanter"
local ENCHANTING_SPELL_ID = 7411
local ENCHANTING_SKILL_LINE_ID = 333
local RECIPE_FORMULA_PREFIX = "Formula: "
local MAILBOX_DISENCHANT_PAUSE_MESSAGE = "|cFFFF1C1CEnchanter|r Paused chat scanning after mailbox work started."
local MAILBOX_DISENCHANT_RETURN_SUBJECT = "Your disenchant mats"
local MAILBOX_DISENCHANT_RETURN_BODY = "Disenchanted the greens and blues you mailed over. Sending the mats back."
local MAILBOX_LOCKBOX_RETURN_SUBJECT = "Your unlocked lockboxes"
local MAILBOX_LOCKBOX_RETURN_BODY = "Unlocked the lockboxes you mailed over. Sending them back."
local MAILBOX_DISENCHANT_ITEM_CLASS_WEAPON = (Enum and Enum.ItemClass and Enum.ItemClass.Weapon) or 2
local MAILBOX_DISENCHANT_ITEM_CLASS_ARMOR = (Enum and Enum.ItemClass and Enum.ItemClass.Armor) or 4
local MAILBOX_DISENCHANT_AUCTION_HOUSE_SENDER = "auction house"
local MAILBOX_DISENCHANT_BLOCKED_EQUIP_LOCS = {
	INVTYPE_AMMO = true,
	INVTYPE_BAG = true,
	INVTYPE_BODY = true,
	INVTYPE_NON_EQUIP = true,
	INVTYPE_NON_EQUIP_IGNORE = true,
	INVTYPE_QUIVER = true,
	INVTYPE_TABARD = true,
}
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
local RecipeAuctionSearchOverrides = {}
local activeEventsInstalled = false
local RegisterActiveEvents

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

local function GetMaxGroupedCustomers()
	return math.max(0, math.floor(tonumber(EC and EC.DB and EC.DB.MaxGroupedCustomers or 0) or 0))
end

local function BuildGroupedCustomerLimitMessage(currentCount, maxCustomers)
	local customerLabel = currentCount == 1 and "customer" or "customers"
	return string.format(
		"|cFFFF1C1CEnchanter|r Paused after %d %s joined your group (max %d).",
		currentCount,
		customerLabel,
		maxCustomers
	)
end

local function BuildGroupedCustomerResumeMessage(currentCount, maxCustomers)
	local customerLabel = currentCount == 1 and "customer" or "customers"
	return string.format(
		"|cFFFF1C1CEnchanter|r Resumed after grouped customers dropped below max %d (%d %s in group).",
		maxCustomers,
		currentCount,
		customerLabel
	)
end

local function IsPlayerAfk()
	return type(UnitIsAFK) == "function" and UnitIsAFK("player") == true
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
	if apiKind == "trade" and HasTradeSkillRecipeApi() then
		return function(index)
			local usedFrameSelection = false

			if TradeSkillFrame_SetSelection then
				usedFrameSelection = pcall(TradeSkillFrame_SetSelection, index)
			end
			if not usedFrameSelection and SelectTradeSkill then
				SelectTradeSkill(index)
			end
			if TradeSkillFrame then
				TradeSkillFrame.selectedSkill = index
			end
		end
	end
	if apiKind == "craft" and HasCraftRecipeApi() then
		return function(index)
			local usedFrameSelection = false

			if CraftFrame_SetSelection then
				usedFrameSelection = pcall(CraftFrame_SetSelection, index)
			end
			if not usedFrameSelection and SelectCraft then
				SelectCraft(index)
			end
			if CraftFrame then
				CraftFrame.selectedCraft = index
			end
		end
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

local function GetSelectedRecipeIndex(apiKind, fallbackIndex)
	apiKind = ResolveRecipeApiKind(apiKind)

	if apiKind == "trade" and GetTradeSkillSelectionIndex then
		local selectedIndex = math.floor(tonumber(GetTradeSkillSelectionIndex()) or 0)
		if selectedIndex > 0 then
			return selectedIndex
		end
	end

	if apiKind == "craft" and GetCraftSelectionIndex then
		local selectedIndex = math.floor(tonumber(GetCraftSelectionIndex()) or 0)
		if selectedIndex > 0 then
			return selectedIndex
		end
	end

	return fallbackIndex
end

local function ExtractReagentCount(reagentLink, thirdValue, fourthValue, fifthValue)
	local requiredCount = tonumber(thirdValue)
	local alternateCount = tonumber(fourthValue)
	local playerCount = tonumber(fifthValue)
	local linkItemId = type(reagentLink) == "string" and tonumber(reagentLink:match("item:(%d+)")) or nil

	if fifthValue ~= nil then
		if linkItemId and requiredCount and requiredCount == linkItemId and alternateCount and alternateCount > 0 then
			requiredCount = alternateCount
		elseif alternateCount and alternateCount > 0 and (not playerCount or playerCount <= alternateCount) then
			requiredCount = alternateCount
		end
	end

	if not requiredCount or requiredCount < 1 then
		requiredCount = alternateCount
	end

	requiredCount = tonumber(requiredCount) or 1
	return math.max(1, math.floor(requiredCount))
end

local function NormalizeTextValue(value)
	if type(value) ~= "string" then
		return ""
	end
	return value:gsub("^%s+", ""):gsub("%s+$", "")
end

local function ExtractLinkedItemName(itemLink)
	local linkedName

	itemLink = NormalizeTextValue(itemLink)
	if itemLink == "" then
		return nil
	end

	linkedName = NormalizeTextValue(itemLink:match("%[(.-)%]"))
	return linkedName ~= "" and linkedName or nil
end

local function ExtractItemIdFromItemReference(itemReference)
	local itemId

	if type(itemReference) == "number" then
		itemId = math.floor(tonumber(itemReference) or 0)
		return itemId > 0 and itemId or nil
	end

	if type(itemReference) ~= "string" then
		return nil
	end

	itemId = tonumber(itemReference:match("item:(%d+)"))
	if itemId and itemId > 0 then
		return math.floor(itemId)
	end

	if type(GetItemInfoInstant) == "function" then
		local ok, instantItemId = pcall(GetItemInfoInstant, itemReference)
		instantItemId = ok and tonumber(instantItemId) or nil
		if instantItemId and instantItemId > 0 then
			return math.floor(instantItemId)
		end
	end

	if C_Item and type(C_Item.GetItemInfoInstant) == "function" then
		local ok, instantItemId = pcall(C_Item.GetItemInfoInstant, itemReference)
		instantItemId = ok and tonumber(instantItemId) or nil
		if instantItemId and instantItemId > 0 then
			return math.floor(instantItemId)
		end
	end

	return nil
end

local function GetItemInfoInstantSnapshot(itemReference)
	local ok
	local instantItemId
	local instantItemType
	local instantItemSubType
	local instantItemEquipLoc
	local instantItemTexture
	local instantClassID
	local instantSubClassID

	if itemReference == nil or itemReference == "" then
		return nil
	end

	if type(GetItemInfoInstant) == "function" then
		ok, instantItemId, instantItemType, instantItemSubType, instantItemEquipLoc, instantItemTexture, instantClassID, instantSubClassID = pcall(GetItemInfoInstant, itemReference)
		instantItemId = ok and tonumber(instantItemId) or nil
		if instantItemId and instantItemId > 0 then
			return {
				ItemId = math.floor(instantItemId),
				Type = NormalizeTextValue(instantItemType),
				SubType = NormalizeTextValue(instantItemSubType),
				EquipLoc = NormalizeTextValue(instantItemEquipLoc),
				Texture = instantItemTexture,
				ClassID = tonumber(instantClassID),
				SubClassID = tonumber(instantSubClassID),
			}
		end
	end

	if C_Item and type(C_Item.GetItemInfoInstant) == "function" then
		ok, instantItemId, instantItemType, instantItemSubType, instantItemEquipLoc, instantItemTexture, instantClassID, instantSubClassID = pcall(C_Item.GetItemInfoInstant, itemReference)
		instantItemId = ok and tonumber(instantItemId) or nil
		if instantItemId and instantItemId > 0 then
			return {
				ItemId = math.floor(instantItemId),
				Type = NormalizeTextValue(instantItemType),
				SubType = NormalizeTextValue(instantItemSubType),
				EquipLoc = NormalizeTextValue(instantItemEquipLoc),
				Texture = instantItemTexture,
				ClassID = tonumber(instantClassID),
				SubClassID = tonumber(instantSubClassID),
			}
		end
	end

	return nil
end

local function ExtractReagentItemId(reagentLink, thirdValue, fourthValue, fifthValue)
	local linkItemId = ExtractItemIdFromItemReference(reagentLink)
	local candidateItemId

	if linkItemId then
		return linkItemId
	end

	if fifthValue ~= nil then
		candidateItemId = tonumber(thirdValue)
		if candidateItemId and candidateItemId > 0 and tonumber(fourthValue) and tonumber(fourthValue) > 0 then
			return math.floor(candidateItemId)
		end
	end

	return nil
end

local function GetItemNameAndLinkFromCache(itemReference)
	local itemName, itemLink
	local ok

	if itemReference == nil or itemReference == "" or type(GetItemInfo) ~= "function" then
		return nil, nil
	end

	ok, itemName, itemLink = pcall(GetItemInfo, itemReference)
	if not ok then
		return nil, nil
	end

	itemName = NormalizeTextValue(itemName)
	itemLink = NormalizeTextValue(itemLink)
	return itemName ~= "" and itemName or nil, itemLink ~= "" and itemLink or nil
end

local function RequestItemDataLoad(itemId)
	local requestQueued = false

	itemId = tonumber(itemId)
	if not itemId or itemId < 1 then
		return false
	end

	itemId = math.floor(itemId)
	EC.PendingMaterialItemLoads = EC.PendingMaterialItemLoads or {}
	if EC.PendingMaterialItemLoads[itemId] then
		return false
	end

	if C_Item and type(C_Item.RequestLoadItemDataByID) == "function" then
		requestQueued = pcall(C_Item.RequestLoadItemDataByID, itemId)
	elseif type(GetItemInfo) == "function" then
		requestQueued = pcall(GetItemInfo, itemId)
	end

	if requestQueued then
		EC.PendingMaterialItemLoads[itemId] = true
		return true
	end

	return false
end

local function ResolveStoredRecipeMaterial(material)
	local changed = false
	local itemId
	local currentLink
	local currentName
	local resolvedName
	local resolvedLink
	local linkedName
	local pendingName

	if type(material) ~= "table" then
		return false
	end

	currentLink = NormalizeTextValue(material.Link)
	currentName = NormalizeTextValue(material.Name)
	itemId = tonumber(material.ItemId) or ExtractItemIdFromItemReference(currentLink)

	if itemId and itemId > 0 then
		itemId = math.floor(itemId)
		if material.ItemId ~= itemId then
			material.ItemId = itemId
			changed = true
		end
	end

	linkedName = ExtractLinkedItemName(currentLink)
	resolvedName = currentName ~= "" and currentName or linkedName

	if itemId then
		local cachedName, cachedLink = GetItemNameAndLinkFromCache(itemId)
		resolvedName = cachedName or resolvedName
		resolvedLink = cachedLink or resolvedLink
	end
	if not resolvedName or resolvedName == "" then
		local cachedName, cachedLink = GetItemNameAndLinkFromCache(currentLink)
		resolvedName = cachedName or resolvedName
		resolvedLink = cachedLink or resolvedLink
	end

	resolvedName = NormalizeTextValue(resolvedName)
	resolvedLink = NormalizeTextValue(resolvedLink)
	if resolvedLink == "" and linkedName then
		resolvedLink = currentLink
	end
	if resolvedLink == "" and itemId then
		resolvedLink = "item:" .. tostring(itemId)
	end

	if resolvedName ~= "" then
		if currentName ~= resolvedName then
			material.Name = resolvedName
			changed = true
		end
	elseif material.Name ~= nil then
		material.Name = nil
		changed = true
	end

	if resolvedLink ~= "" then
		if currentLink ~= resolvedLink then
			material.Link = resolvedLink
			changed = true
		end
	elseif material.Link ~= nil then
		material.Link = nil
		changed = true
	end

	pendingName = resolvedName == "" and itemId ~= nil
	if pendingName then
		RequestItemDataLoad(itemId)
	end
	if (material.PendingName == true) ~= pendingName then
		material.PendingName = pendingName and true or nil
		changed = true
	end

	return changed
end

local function GetStoredRecipeMaterialName(material)
	local materialName

	if type(material) ~= "table" then
		return ""
	end

	ResolveStoredRecipeMaterial(material)
	materialName = NormalizeTextValue(material.Name)
	if materialName ~= "" then
		return materialName
	end

	materialName = ExtractLinkedItemName(material.Link)
	return materialName or ""
end

local function GetStoredRecipeMaterialDisplayText(material)
	local displayName

	if type(material) ~= "table" then
		return "Unknown Material"
	end

	ResolveStoredRecipeMaterial(material)
	displayName = ExtractLinkedItemName(material.Link)
	if displayName then
		return material.Link
	end

	displayName = NormalizeTextValue(material.Name)
	if displayName ~= "" then
		return displayName
	end

	return "Unknown Material"
end

local function GetStoredRecipeMaterialKey(material)
	local itemId
	local materialName
	local materialLink

	if type(material) ~= "table" then
		return ""
	end

	ResolveStoredRecipeMaterial(material)
	itemId = tonumber(material.ItemId) or ExtractItemIdFromItemReference(material.Link)
	if itemId and itemId > 0 then
		return "item:" .. tostring(math.floor(itemId))
	end

	materialName = NormalizeTextValue(material.Name)
	if materialName ~= "" then
		return materialName
	end

	materialLink = NormalizeTextValue(material.Link)
	return materialLink ~= "" and materialLink or ""
end

local function CountUnresolvedMaterials(materials)
	local unresolvedCount = 0

	for _, material in ipairs(materials or {}) do
		ResolveStoredRecipeMaterial(material)
		if material.PendingName == true then
			unresolvedCount = unresolvedCount + 1
		end
	end

	return unresolvedCount
end

local function CountUnresolvedRecipeMaterials(recipeMats)
	local unresolvedCount = 0

	for _, materials in pairs(recipeMats or {}) do
		unresolvedCount = unresolvedCount + CountUnresolvedMaterials(materials)
	end

	return unresolvedCount
end

local function RefreshStoredRecipeMaterials(targetItemId)
	local changed = false
	local unresolvedCount = 0
	local recipeMats = EC.DBChar and EC.DBChar.RecipeMats or {}

	targetItemId = tonumber(targetItemId)
	if targetItemId then
		targetItemId = math.floor(targetItemId)
	end

	for _, materials in pairs(recipeMats) do
		for _, material in ipairs(materials or {}) do
			local materialItemId = tonumber(material.ItemId) or ExtractItemIdFromItemReference(material.Link)
			if not targetItemId or materialItemId == targetItemId then
				if ResolveStoredRecipeMaterial(material) then
					changed = true
				end
			end
			if material.PendingName == true then
				unresolvedCount = unresolvedCount + 1
			end
		end
	end

	if targetItemId and EC.PendingMaterialItemLoads then
		EC.PendingMaterialItemLoads[targetItemId] = nil
	end
	if EC.DBChar then
		EC.DBChar.PendingRecipeMaterialCount = unresolvedCount
	end

	return changed, unresolvedCount
end

local function ExtractReagentDisplayName(reagentName, reagentLink, itemId)
	local displayName = NormalizeTextValue(reagentName)

	if displayName ~= "" then
		return displayName
	end

	displayName = ExtractLinkedItemName(reagentLink)
	if displayName then
		return displayName
	end

	displayName = select(1, GetItemNameAndLinkFromCache(itemId or reagentLink))
	return displayName or nil
end

local function CaptureRecipeMaterialsForIndex(recipeIndex, apiKind)
	local getNumReagents, getReagentInfo, getReagentLink = GetRecipeReagentApi(apiKind)
	local materials = {}

	if not recipeIndex or not getNumReagents or not getReagentInfo then
		return materials
	end

	for reagentIndex = 1, getNumReagents(recipeIndex) or 0 do
		local reagentName, _, thirdValue, fourthValue, fifthValue = getReagentInfo(recipeIndex, reagentIndex)
		local reagentLink = getReagentLink and getReagentLink(recipeIndex, reagentIndex) or nil
		local itemId = ExtractReagentItemId(reagentLink, thirdValue, fourthValue, fifthValue)
		local displayName = ExtractReagentDisplayName(reagentName, reagentLink, itemId)
		local material = {
			Name = displayName,
			Count = ExtractReagentCount(reagentLink, thirdValue, fourthValue, fifthValue),
			Link = reagentLink,
			ItemId = itemId,
		}

		ResolveStoredRecipeMaterial(material)
		if material.ItemId or material.Name or material.Link then
			materials[#materials + 1] = material
		end
	end

	return materials
end

local function CaptureRecipeMaterials(recipeIndex, apiKind)
	local selectedMaterials = CaptureRecipeMaterialsForIndex(GetSelectedRecipeIndex(apiKind), apiKind)
	local indexedMaterials = CaptureRecipeMaterialsForIndex(recipeIndex, apiKind)
	local selectedUnresolvedCount = CountUnresolvedMaterials(selectedMaterials)
	local indexedUnresolvedCount = CountUnresolvedMaterials(indexedMaterials)

	if #indexedMaterials > #selectedMaterials then
		return indexedMaterials
	end
	if #indexedMaterials == #selectedMaterials and indexedUnresolvedCount < selectedUnresolvedCount then
		return indexedMaterials
	end
	if #selectedMaterials > 0 then
		return selectedMaterials
	end
	return indexedMaterials
end

EC.ResolveStoredRecipeMaterial = ResolveStoredRecipeMaterial
EC.GetStoredRecipeMaterialKey = GetStoredRecipeMaterialKey
EC.GetStoredRecipeMaterialName = GetStoredRecipeMaterialName
EC.GetStoredRecipeMaterialDisplayText = GetStoredRecipeMaterialDisplayText
EC.GetPendingRecipeMaterialCount = function()
	return math.max(0, math.floor(tonumber(EC.DBChar and EC.DBChar.PendingRecipeMaterialCount or 0) or 0))
end

local mailboxHooksInstalled = false

local function MailboxNow()
	if GetTime then
		return GetTime()
	end
	return 0
end

EC.GetDisenchantSpellName = function()
	local spellName = GetSpellInfo and GetSpellInfo(13262) or nil
	return NormalizeTextValue(spellName) ~= "" and spellName or "Disenchant"
end

local function NormalizePlayerName(value)
	value = NormalizeTextValue(value):lower()
	return value:match("^([^%-]+)") or value
end

local function IsOtherPlayerName(value)
	local playerName = NormalizePlayerName(UnitName and UnitName("player") or nil)
	local senderName = NormalizePlayerName(value)
	return senderName ~= "" and senderName ~= playerName
end

local function IsAuctionHouseSender(value)
	local senderName = NormalizeTextValue(value):lower()
	return senderName ~= "" and senderName:find(MAILBOX_DISENCHANT_AUCTION_HOUSE_SENDER, 1, true) ~= nil
end

local function GetMailboxDisenchantRuntime()
	EC.MailboxDisenchant = EC.MailboxDisenchant or {}
	local runtime = EC.MailboxDisenchant
	runtime.PendingLoots = runtime.PendingLoots or {}
	return runtime
end

local function GetMailboxBagCountKey(item)
	if EC.GetStoredRecipeMaterialKey then
		return EC.GetStoredRecipeMaterialKey(item)
	end
	return ""
end

local function GetItemInfoSnapshot(itemReference, fallbackName, fallbackLink, fallbackQuality)
	local itemName, itemLink, itemQuality, _, _, itemType, itemSubType, itemStackCount, itemEquipLoc, itemTexture, _, classID, subClassID, bindType
	local itemId = ExtractItemIdFromItemReference(itemReference or fallbackLink)
	local instantInfo

	if not itemId and tonumber(itemReference) and tonumber(itemReference) > 0 then
		itemId = math.floor(tonumber(itemReference))
	end

	instantInfo = GetItemInfoInstantSnapshot(itemReference or itemId or fallbackLink)
	if not itemId and instantInfo and instantInfo.ItemId then
		itemId = instantInfo.ItemId
	end

	if GetItemInfo then
		itemName, itemLink, itemQuality, _, _, itemType, itemSubType, itemStackCount, itemEquipLoc, itemTexture, _, classID, subClassID, bindType = GetItemInfo(itemReference or itemId or fallbackLink)
	end

	if itemId and (itemName == nil or itemLink == nil) then
		RequestItemDataLoad(itemId)
	end

	return {
		Name = NormalizeTextValue(itemName) ~= "" and itemName or fallbackName,
		Link = NormalizeTextValue(itemLink) ~= "" and itemLink or fallbackLink,
		ItemId = itemId,
		Quality = math.max(0, math.floor(tonumber(itemQuality) or tonumber(fallbackQuality) or 0)),
		Type = NormalizeTextValue(itemType) ~= "" and NormalizeTextValue(itemType) or (instantInfo and instantInfo.Type or ""),
		SubType = NormalizeTextValue(itemSubType) ~= "" and NormalizeTextValue(itemSubType) or (instantInfo and instantInfo.SubType or ""),
		StackCount = math.max(1, math.floor(tonumber(itemStackCount) or 1)),
		EquipLoc = NormalizeTextValue(itemEquipLoc) ~= "" and NormalizeTextValue(itemEquipLoc) or (instantInfo and instantInfo.EquipLoc or ""),
		Texture = itemTexture or (instantInfo and instantInfo.Texture or nil),
		ClassID = tonumber(classID) or (instantInfo and tonumber(instantInfo.ClassID) or nil),
		SubClassID = tonumber(subClassID) or (instantInfo and tonumber(instantInfo.SubClassID) or nil),
		BindType = tonumber(bindType),
	}
end

local function GetInboxAttachmentSnapshot(mailIndex, attachmentIndex)
	local sender, subject, codAmount, daysLeft
	local normalizedDaysLeft
	local itemName, itemId, _, itemCount, quality
	local itemLink
	local itemInfo

	if not mailIndex or not attachmentIndex or not GetInboxHeaderInfo then
		return nil
	end

	_, _, sender, subject, _, codAmount, daysLeft = GetInboxHeaderInfo(mailIndex)
	if GetInboxItem then
		itemName, itemId, _, itemCount, quality = GetInboxItem(mailIndex, attachmentIndex)
	end
	itemLink = GetInboxItemLink and GetInboxItemLink(mailIndex, attachmentIndex) or nil
	itemInfo = GetItemInfoSnapshot(itemLink or itemId, itemName, itemLink, quality)
	itemInfo.Sender = NormalizeTextValue(sender)
	itemInfo.MailSubject = NormalizeTextValue(subject)
	itemInfo.CODAmount = math.max(0, math.floor(tonumber(codAmount) or 0))
	itemInfo.Count = math.max(1, math.floor(tonumber(itemCount) or 1))
	itemInfo.MailIndex = math.max(0, math.floor(tonumber(mailIndex) or 0))
	itemInfo.AttachmentIndex = math.max(0, math.floor(tonumber(attachmentIndex) or 0))
	normalizedDaysLeft = math.max(0, tonumber(daysLeft) or 0)
	itemInfo.MailDaysLeft = normalizedDaysLeft
	if normalizedDaysLeft > 0 then
		itemInfo.MailExpiresAt = math.floor(MailboxNow() + (normalizedDaysLeft * 24 * 60 * 60) + 0.5)
	end
	return itemInfo
end

local function IsMailboxDisenchantCandidate(itemInfo)
	local quality
	local bindType
	local classID
	local equipLoc

	if type(itemInfo) ~= "table" then
		return false
	end

	if not IsOtherPlayerName(itemInfo.Sender) then
		return false
	end

	if IsAuctionHouseSender(itemInfo.Sender) then
		return false
	end

	if math.max(0, math.floor(tonumber(itemInfo.CODAmount) or 0)) > 0 then
		return false
	end

	quality = math.max(0, math.floor(tonumber(itemInfo.Quality) or 0))
	if quality ~= 2 and quality ~= 3 then
		return false
	end

	classID = tonumber(itemInfo.ClassID)
	equipLoc = NormalizeTextValue(itemInfo.EquipLoc)
	if MAILBOX_DISENCHANT_BLOCKED_EQUIP_LOCS[equipLoc] then
		return false
	end

	if classID ~= nil then
		if classID ~= MAILBOX_DISENCHANT_ITEM_CLASS_WEAPON and classID ~= MAILBOX_DISENCHANT_ITEM_CLASS_ARMOR then
			return false
		end
	elseif equipLoc == "" then
		return false
	end

	bindType = tonumber(itemInfo.BindType)
	if bindType ~= nil and bindType > 0 and bindType ~= (_G and _G.LE_ITEM_BIND_ON_EQUIP or 2) then
		return false
	end

	return true
end

local function IsMailboxLockboxCandidate(itemInfo)
	local itemName

	if type(itemInfo) ~= "table" then
		return false
	end

	if not IsOtherPlayerName(itemInfo.Sender) then
		return false
	end

	if IsAuctionHouseSender(itemInfo.Sender) then
		return false
	end

	if math.max(0, math.floor(tonumber(itemInfo.CODAmount) or 0)) > 0 then
		return false
	end

	itemName = NormalizeTextValue(itemInfo.Name)
	if itemName == "" then
		itemName = ExtractLinkedItemName(itemInfo.Link) or ""
	end

	return itemName:lower():find("lockbox", 1, true) ~= nil
end

local function GetMailboxLootJobKind(itemInfo)
	if IsMailboxLockboxCandidate(itemInfo) then
		return "lockbox"
	end
	if IsMailboxDisenchantCandidate(itemInfo) then
		return "disenchant"
	end
	return nil
end

local function GetPendingMailboxLootKey(itemInfo)
	local itemPart

	if type(itemInfo) ~= "table" then
		return ""
	end

	if NormalizeTextValue(itemInfo.LootKey) ~= "" then
		return NormalizeTextValue(itemInfo.LootKey)
	end

	itemPart = tostring(itemInfo.ItemId or "")
	if itemPart == "" then
		itemPart = NormalizeTextValue(itemInfo.Link)
	end
	if itemPart == "" then
		itemPart = NormalizeTextValue(itemInfo.Name)
	end

	return table.concat({
		NormalizeTextValue(itemInfo.MailboxJobKind),
		NormalizeTextValue(itemInfo.Sender),
		NormalizeTextValue(itemInfo.MailSubject),
		tostring(itemInfo.MailExpiresAt or itemInfo.MailIndex or ""),
		tostring(itemInfo.AttachmentIndex or ""),
		itemPart,
	}, ":")
end

local function IsPendingMailboxLootQueued(runtime, itemInfo)
	local pendingKey = GetPendingMailboxLootKey(itemInfo)

	if pendingKey == "" then
		return false
	end

	for _, pendingItem in ipairs(runtime.PendingLoots or {}) do
		if GetPendingMailboxLootKey(pendingItem) == pendingKey then
			return true
		end
	end

	return false
end

local function RemoveAuctionHouseDisenchantOrders()
	local state
	local changed = false
	local selectedOrderExists = false

	if not (EC.Workbench and EC.Workbench.EnsureState) then
		return false
	end

	state = EC.Workbench.EnsureState()
	for index = #(state.Orders or {}), 1, -1 do
		local order = state.Orders[index]
		if order and order.Kind == "disenchant" and IsAuctionHouseSender(order.Customer) then
			table.remove(state.Orders, index)
			changed = true
		end
	end

	if not changed then
		return false
	end

	for _, order in ipairs(state.Orders or {}) do
		if order.Id == state.SelectedOrderId then
			selectedOrderExists = true
			break
		end
	end
	if not selectedOrderExists then
		state.SelectedOrderId = state.Orders[1] and state.Orders[1].Id or nil
	end

	if EC.Workbench.Refresh then
		EC.Workbench.Refresh()
	end
	return true
end

local function GetBagSlotCount(bagIndex)
	if C_Container and type(C_Container.GetContainerNumSlots) == "function" then
		return math.max(0, math.floor(tonumber(C_Container.GetContainerNumSlots(bagIndex)) or 0))
	end
	if type(GetContainerNumSlots) == "function" then
		return math.max(0, math.floor(tonumber(GetContainerNumSlots(bagIndex)) or 0))
	end
	return 0
end

local function GetBagItemSnapshot(bagIndex, slotIndex)
	local containerInfo
	local itemLink
	local itemCount
	local itemId
	local quality
	local itemInfo

	if C_Container and type(C_Container.GetContainerItemInfo) == "function" then
		containerInfo = C_Container.GetContainerItemInfo(bagIndex, slotIndex)
	end
	if type(containerInfo) ~= "table" then
		return nil
	end

	itemLink = (C_Container and type(C_Container.GetContainerItemLink) == "function" and C_Container.GetContainerItemLink(bagIndex, slotIndex)) or containerInfo.hyperlink
	itemCount = math.max(1, math.floor(tonumber(containerInfo.stackCount) or 1))
	itemId = tonumber(containerInfo.itemID) or ExtractItemIdFromItemReference(itemLink)
	quality = tonumber(containerInfo.quality)
	itemInfo = GetItemInfoSnapshot(itemLink or itemId, nil, itemLink, quality)
	itemInfo.Count = itemCount
	itemInfo.Bag = bagIndex
	itemInfo.Slot = slotIndex
	itemInfo.Key = GetMailboxBagCountKey(itemInfo)
	if containerInfo.isLocked ~= nil then
		itemInfo.IsLocked = containerInfo.isLocked and true or false
	end

	if itemInfo.Key == "" then
		return nil
	end

	return itemInfo
end

local function CaptureBagSnapshot()
	local snapshot = {
		Slots = {},
		OrderedSlots = {},
		Counts = {},
	}

	for bagIndex = 0, (_G and tonumber(_G.NUM_BAG_SLOTS) or 4) do
		for slotIndex = 1, GetBagSlotCount(bagIndex) do
			local itemInfo = GetBagItemSnapshot(bagIndex, slotIndex)
			if itemInfo then
				local locationKey = tostring(bagIndex) .. ":" .. tostring(slotIndex)
				snapshot.Slots[locationKey] = itemInfo
				snapshot.OrderedSlots[#snapshot.OrderedSlots + 1] = itemInfo
				snapshot.Counts[itemInfo.Key] = (snapshot.Counts[itemInfo.Key] or 0) + itemInfo.Count
			end
		end
	end

	return snapshot
end

EC.CopyMailboxCountMap = function(counts)
	local out = {}
	for key, count in pairs(counts or {}) do
		out[key] = count
	end
	return out
end

local function FindTrackedDisenchantItemByLocation(bagIndex, slotIndex)
	if not (EC.Workbench and EC.Workbench.EnsureState) then
		return nil, nil
	end

	for _, order in ipairs(EC.Workbench.EnsureState().Orders or {}) do
		if order.Kind == "disenchant" then
			for _, item in ipairs(order.SourceItems or {}) do
				if item.Status ~= "done" and tonumber(item.Bag) == tonumber(bagIndex) and tonumber(item.Slot) == tonumber(slotIndex) then
					return order, item
				end
			end
		end
	end

	return nil, nil
end

local function PrimePendingDisenchant(order, sourceItem, bagIndex, slotIndex, beforeCounts)
	local snapshot
	local runtime

	if not order or not sourceItem then
		return false
	end

	bagIndex = tonumber(bagIndex)
	slotIndex = tonumber(slotIndex)
	if bagIndex == nil or slotIndex == nil then
		return false
	end

	snapshot = CaptureBagSnapshot()
	runtime = GetMailboxDisenchantRuntime()
	runtime.PendingDisenchant = {
		OrderId = order.Id,
		ItemToken = sourceItem.Token,
		Bag = bagIndex,
		Slot = slotIndex,
		ItemKey = GetMailboxBagCountKey(sourceItem),
		BeforeCounts = EC.CopyMailboxCountMap(beforeCounts or snapshot.Counts),
		ResolveAfter = MailboxNow() + 8,
	}
	if C_Timer and C_Timer.After then
		C_Timer.After(8.1, function()
			local pendingAction = GetMailboxDisenchantRuntime().PendingDisenchant
			if pendingAction
				and pendingAction.OrderId == order.Id
				and pendingAction.ItemToken == sourceItem.Token
				and tonumber(pendingAction.Bag) == bagIndex
				and tonumber(pendingAction.Slot) == slotIndex
				and EC.SyncDisenchantInventoryTracking
			then
				EC.SyncDisenchantInventoryTracking()
			end
		end)
	end
	return true
end

EC.CaptureRecentMailboxItemTargeting = function()
	local runtime = GetMailboxDisenchantRuntime()
	local isItemTargeting = (type(SpellCanTargetItem) == "function" and SpellCanTargetItem() and true)
		or (type(SpellCanTargetItemID) == "function" and SpellCanTargetItemID() and true)
		or (type(SpellIsTargeting) == "function" and SpellIsTargeting() and true)
		or false

	if isItemTargeting then
		local snapshot = CaptureBagSnapshot()
		runtime.RecentItemTargeting = {
			Active = true,
			BeforeCounts = EC.CopyMailboxCountMap(snapshot.Counts),
			UpdatedAt = MailboxNow(),
			ExpiresAt = nil,
		}
	elseif runtime.RecentItemTargeting then
		runtime.RecentItemTargeting.Active = false
		runtime.RecentItemTargeting.ExpiresAt = MailboxNow() + 2
	end
end

EC.GetRecentMailboxItemTargetingCounts = function()
	local recent = GetMailboxDisenchantRuntime().RecentItemTargeting
	if not recent then
		return nil
	end
	if recent.Active or MailboxNow() <= (tonumber(recent.ExpiresAt) or 0) then
		return recent.BeforeCounts
	end
	return nil
end

local function SyncDisenchantBagAssignments(snapshot)
	local runtime = GetMailboxDisenchantRuntime()
	local pendingAction = runtime.PendingDisenchant
	local usedSlots = {}
	local changed = false

	if not (EC.Workbench and EC.Workbench.EnsureState and EC.Workbench.SetDisenchantItemLocation) then
		return false
	end

	for _, order in ipairs(EC.Workbench.EnsureState().Orders or {}) do
		if order.Kind == "disenchant" then
			for _, item in ipairs(order.SourceItems or {}) do
				local bagKey = tostring(item.Bag or "") .. ":" .. tostring(item.Slot or "")
				local slotInfo = snapshot.Slots[bagKey]
				local itemKey = GetMailboxBagCountKey(item)
				local isPendingItem = pendingAction and pendingAction.OrderId == order.Id and pendingAction.ItemToken == item.Token

				if item.Status == "done" or isPendingItem then
					if slotInfo and not isPendingItem then
						usedSlots[bagKey] = true
					end
				elseif slotInfo and slotInfo.Key == itemKey then
					usedSlots[bagKey] = true
				elseif item.Bag ~= nil or item.Slot ~= nil then
					if EC.Workbench.SetDisenchantItemLocation(order.Id, item.Token, nil, nil) then
						changed = true
					end
				end
			end
		end
	end

	for _, order in ipairs(EC.Workbench.EnsureState().Orders or {}) do
		if order.Kind == "disenchant" then
			for _, item in ipairs(order.SourceItems or {}) do
				local isPendingItem = pendingAction and pendingAction.OrderId == order.Id and pendingAction.ItemToken == item.Token
				local itemKey = GetMailboxBagCountKey(item)
				if item.Status ~= "done" and not isPendingItem and (item.Bag == nil or item.Slot == nil) and itemKey ~= "" then
					for _, slotInfo in ipairs(snapshot.OrderedSlots) do
						local slotKey = tostring(slotInfo.Bag) .. ":" .. tostring(slotInfo.Slot)
						if not usedSlots[slotKey] and slotInfo.Key == itemKey then
							usedSlots[slotKey] = true
							if EC.Workbench.SetDisenchantItemLocation(order.Id, item.Token, slotInfo.Bag, slotInfo.Slot) then
								changed = true
							end
							break
						end
					end
				end
			end
		end
	end

	return changed
end

local function SyncLockboxBagAssignments(snapshot)
	local usedSlots = {}
	local changed = false

	if not (EC.Workbench and EC.Workbench.EnsureState and EC.Workbench.SetLockboxItemLocation and EC.Workbench.MarkLockboxItemUnlocked) then
		return false
	end

	for _, order in ipairs(EC.Workbench.EnsureState().Orders or {}) do
		if order.Kind == "lockbox" then
			for _, item in ipairs(order.SourceItems or {}) do
				local bagKey = tostring(item.Bag or "") .. ":" .. tostring(item.Slot or "")
				local slotInfo = snapshot.Slots[bagKey]
				local itemKey = GetMailboxBagCountKey(item)

				if item.Status == "done" then
					if slotInfo and slotInfo.Key == itemKey then
						usedSlots[bagKey] = true
						if EC.Workbench.SetLockboxItemLocation(order.Id, item.Token, slotInfo.Bag, slotInfo.Slot, slotInfo.IsLocked) then
							changed = true
						end
					end
				elseif slotInfo and slotInfo.Key == itemKey then
					usedSlots[bagKey] = true
					if slotInfo.IsLocked == false then
						if EC.Workbench.MarkLockboxItemUnlocked(order.Id, item.Token, slotInfo.Bag, slotInfo.Slot) then
							changed = true
						end
					elseif EC.Workbench.SetLockboxItemLocation(order.Id, item.Token, slotInfo.Bag, slotInfo.Slot, slotInfo.IsLocked) then
						changed = true
					end
				elseif item.Bag ~= nil or item.Slot ~= nil then
					if EC.Workbench.SetLockboxItemLocation(order.Id, item.Token, nil, nil, nil) then
						changed = true
					end
				end
			end
		end
	end

	for _, order in ipairs(EC.Workbench.EnsureState().Orders or {}) do
		if order.Kind == "lockbox" then
			for _, item in ipairs(order.SourceItems or {}) do
				local itemKey = GetMailboxBagCountKey(item)
				if item.Status ~= "done" and (item.Bag == nil or item.Slot == nil) and itemKey ~= "" then
					for _, slotInfo in ipairs(snapshot.OrderedSlots) do
						local slotKey = tostring(slotInfo.Bag) .. ":" .. tostring(slotInfo.Slot)
						if not usedSlots[slotKey] and slotInfo.Key == itemKey then
							usedSlots[slotKey] = true
							if slotInfo.IsLocked == false then
								if EC.Workbench.MarkLockboxItemUnlocked(order.Id, item.Token, slotInfo.Bag, slotInfo.Slot) then
									changed = true
								end
							elseif EC.Workbench.SetLockboxItemLocation(order.Id, item.Token, slotInfo.Bag, slotInfo.Slot, slotInfo.IsLocked) then
								changed = true
							end
							break
						end
					end
				end
			end
		end
	end

	return changed
end

local function BuildPositiveMaterialDelta(snapshot, previousCounts, ignoredKey)
	local materialDelta = {}

	for _, itemInfo in ipairs(snapshot.OrderedSlots or {}) do
		local currentKey = itemInfo.Key
		local currentCount
		local previousCount
		local deltaCount

		if currentKey ~= "" and currentKey ~= ignoredKey and materialDelta[currentKey] == nil then
			currentCount = math.max(0, math.floor(tonumber(snapshot.Counts[currentKey]) or 0))
			previousCount = math.max(0, math.floor(tonumber(previousCounts and previousCounts[currentKey] or 0) or 0))
			deltaCount = currentCount - previousCount
			if deltaCount > 0 then
				materialDelta[currentKey] = {
					Key = currentKey,
					Name = itemInfo.Name,
					Link = itemInfo.Link,
					ItemId = itemInfo.ItemId,
					Count = deltaCount,
				}
			end
		end
	end

	return materialDelta
end

local function ResolvePendingDisenchantAction(snapshot)
	local runtime = GetMailboxDisenchantRuntime()
	local pendingAction = runtime.PendingDisenchant
	local order
	local sourceItem
	local slotKey
	local slotInfo
	local materialDelta

	if not pendingAction then
		return false
	end

	order = EC.Workbench and EC.Workbench.GetOrderById and EC.Workbench.GetOrderById(pendingAction.OrderId) or nil
	if not order or order.Kind ~= "disenchant" then
		runtime.PendingDisenchant = nil
		return false
	end

	for _, item in ipairs(order.SourceItems or {}) do
		if item.Token == pendingAction.ItemToken then
			sourceItem = item
			break
		end
	end

	if not sourceItem or sourceItem.Status == "done" then
		runtime.PendingDisenchant = nil
		return false
	end

	slotKey = tostring(pendingAction.Bag) .. ":" .. tostring(pendingAction.Slot)
	slotInfo = snapshot.Slots[slotKey]
	if slotInfo and slotInfo.Key == pendingAction.ItemKey then
		if MailboxNow() >= (tonumber(pendingAction.ResolveAfter) or 0) then
			runtime.PendingDisenchant = nil
		end
		return false
	end

	materialDelta = BuildPositiveMaterialDelta(snapshot, pendingAction.BeforeCounts, pendingAction.ItemKey)
	if next(materialDelta) ~= nil then
		runtime.PendingDisenchant = nil
		if EC.Workbench and EC.Workbench.MarkDisenchantItemProcessed then
			EC.Workbench.MarkDisenchantItemProcessed(order.Id, pendingAction.ItemToken, materialDelta)
		end
		return true
	end

	if MailboxNow() >= (tonumber(pendingAction.ResolveAfter) or 0) then
		runtime.PendingDisenchant = nil
	end

	return false
end

function EC.SyncDisenchantInventoryTracking()
	local runtime = GetMailboxDisenchantRuntime()
	local snapshot = CaptureBagSnapshot()
	local changed = false

	if SyncDisenchantBagAssignments(snapshot) then
		changed = true
	end
	if SyncLockboxBagAssignments(snapshot) then
		changed = true
	end
	if ResolvePendingDisenchantAction(snapshot) then
		changed = true
	end

	runtime.LastBagSnapshot = snapshot
	if changed and EC.Workbench and EC.Workbench.Refresh then
		EC.Workbench.Refresh()
	end
	return changed
end

local function PickupContainerItemCompat(bagIndex, slotIndex)
	if C_Container and type(C_Container.PickupContainerItem) == "function" then
		C_Container.PickupContainerItem(bagIndex, slotIndex)
		return true
	end
	if type(PickupContainerItem) == "function" then
		PickupContainerItem(bagIndex, slotIndex)
		return true
	end
	return false
end

local function SplitContainerItemCompat(bagIndex, slotIndex, count)
	if C_Container and type(C_Container.SplitContainerItem) == "function" then
		C_Container.SplitContainerItem(bagIndex, slotIndex, count)
		return true
	end
	if type(SplitContainerItem) == "function" then
		SplitContainerItem(bagIndex, slotIndex, count)
		return true
	end
	return false
end

local function CountSendMailAttachments()
	local attachmentLimit = math.max(1, math.floor(tonumber(_G and _G.ATTACHMENTS_MAX_SEND or 12) or 12))
	local attachmentCount = 0

	if type(HasSendMailItem) ~= "function" then
		return 0
	end

	for attachmentIndex = 1, attachmentLimit do
		if HasSendMailItem(attachmentIndex) then
			attachmentCount = attachmentCount + 1
		end
	end

	return attachmentCount
end

local function AttachTrackedReturnMaterials(order)
	local snapshot
	local remaining = {}
	local attachedStacks = 0
	local remainingMaterialCount = 0
	local attachmentLimit = math.max(1, math.floor(tonumber(_G and _G.ATTACHMENTS_MAX_SEND or 12) or 12))

	if not order or order.Kind ~= "disenchant" then
		return 0, 0, "invalid"
	end

	if CountSendMailAttachments() > 0 then
		return 0, 0, "existing_attachments"
	end

	snapshot = CaptureBagSnapshot()
	for _, material in ipairs(EC.Workbench and EC.Workbench.GetMaterialSnapshot and EC.Workbench.GetMaterialSnapshot(order) or {}) do
		remaining[material.Key] = math.max(0, math.floor(tonumber(material.Count) or 0))
	end

	for _, itemInfo in ipairs(snapshot.OrderedSlots or {}) do
		local key = itemInfo.Key
		local stackCount = math.max(0, math.floor(tonumber(itemInfo.Count) or 0))
		if attachedStacks >= attachmentLimit then
			break
		end
		if key ~= "" and remaining[key] and remaining[key] > 0 and stackCount > 0 then
			if stackCount <= remaining[key] then
				if PickupContainerItemCompat(itemInfo.Bag, itemInfo.Slot) and type(ClickSendMailItemButton) == "function" then
					ClickSendMailItemButton()
					remaining[key] = remaining[key] - stackCount
					attachedStacks = attachedStacks + 1
				end
			else
				local splitCount = remaining[key]
				if SplitContainerItemCompat(itemInfo.Bag, itemInfo.Slot, splitCount) and type(ClickSendMailItemButton) == "function" then
					ClickSendMailItemButton()
					remaining[key] = 0
					attachedStacks = attachedStacks + 1
				end
			end
		end
	end

	for _, count in pairs(remaining) do
		remainingMaterialCount = remainingMaterialCount + math.max(0, math.floor(tonumber(count) or 0))
	end

	return attachedStacks, remainingMaterialCount, nil
end

function EC.PrepareDisenchantReturnMail(orderId)
	local order = EC.Workbench and EC.Workbench.GetOrderById and EC.Workbench.GetOrderById(orderId) or nil
	local attachedStacks
	local remainingMaterialCount
	local attachReason
	local runtime = GetMailboxDisenchantRuntime()

	if not order or order.Kind ~= "disenchant" then
		return false
	end

	if not (SendMailNameEditBox and SendMailSubjectEditBox and MailEditBox) then
		print("|cFFFF1C1CEnchanter|r Open a mailbox first to prep the return mail.")
		return false
	end

	if type(MailFrameTab_OnClick) == "function" then
		pcall(MailFrameTab_OnClick, nil, 2)
	end

	if SendMailNameEditBox.SetText then
		SendMailNameEditBox:SetText(order.Customer or "")
	end
	if SendMailSubjectEditBox.SetText then
		SendMailSubjectEditBox:SetText(MAILBOX_DISENCHANT_RETURN_SUBJECT)
	end
	if MailEditBox.SetText then
		MailEditBox:SetText(MAILBOX_DISENCHANT_RETURN_BODY)
	elseif MailEditBox.SetInputText then
		MailEditBox:SetInputText(MAILBOX_DISENCHANT_RETURN_BODY)
	end

	attachedStacks, remainingMaterialCount, attachReason = AttachTrackedReturnMaterials(order)
	if type(SendMailFrame_Update) == "function" then
		pcall(SendMailFrame_Update)
	end
	if type(SendMailFrame_CanSend) == "function" then
		pcall(SendMailFrame_CanSend)
	end

	runtime.PendingReturnMailOrderId = orderId
	if attachReason == "existing_attachments" then
		print("|cFFFF1C1CEnchanter|r Prepared return mail for " .. tostring(order.Customer) .. ". Existing attachments were left alone, so only the recipient and message were filled in.")
	elseif attachedStacks > 0 and remainingMaterialCount > 0 then
		print("|cFFFF1C1CEnchanter|r Prepared return mail for " .. tostring(order.Customer) .. " and attached " .. tostring(attachedStacks) .. " stack(s). " .. tostring(remainingMaterialCount) .. " tracked mat(s) still need manual handling.")
	elseif attachedStacks > 0 then
		print("|cFFFF1C1CEnchanter|r Prepared return mail for " .. tostring(order.Customer) .. " and attached " .. tostring(attachedStacks) .. " stack(s) of tracked mats.")
	else
		print("|cFFFF1C1CEnchanter|r Prepared return mail for " .. tostring(order.Customer) .. ". No tracked mats were auto-attached yet.")
	end
	return true
end

local function AttachTrackedReturnLockboxes(order)
	local snapshot
	local attachedStacks = 0
	local remainingUnlocked = 0
	local attachmentLimit = math.max(1, math.floor(tonumber(_G and _G.ATTACHMENTS_MAX_SEND or 12) or 12))
	local usedSlots = {}

	if not order or order.Kind ~= "lockbox" then
		return 0, 0, "invalid"
	end

	if CountSendMailAttachments() > 0 then
		return 0, 0, "existing_attachments"
	end

	snapshot = CaptureBagSnapshot()
	for _, item in ipairs(order.SourceItems or {}) do
		local slotKey = tostring(item.Bag or "") .. ":" .. tostring(item.Slot or "")
		local slotInfo = snapshot.Slots[slotKey]
		local itemKey = GetMailboxBagCountKey(item)

		if item.Status == "done" then
			if slotInfo and slotInfo.Key == itemKey and slotInfo.IsLocked == false then
				remainingUnlocked = remainingUnlocked + 1
				if attachedStacks < attachmentLimit and not usedSlots[slotKey] and PickupContainerItemCompat(slotInfo.Bag, slotInfo.Slot) and type(ClickSendMailItemButton) == "function" then
					ClickSendMailItemButton()
					usedSlots[slotKey] = true
					attachedStacks = attachedStacks + 1
					remainingUnlocked = remainingUnlocked - 1
				end
			end
		end
	end

	return attachedStacks, remainingUnlocked, nil
end

function EC.PrepareLockboxReturnMail(orderId)
	local order = EC.Workbench and EC.Workbench.GetOrderById and EC.Workbench.GetOrderById(orderId) or nil
	local attachedStacks
	local remainingUnlocked
	local attachReason
	local runtime = GetMailboxDisenchantRuntime()

	if not order or order.Kind ~= "lockbox" then
		return false
	end

	if not (SendMailNameEditBox and SendMailSubjectEditBox and MailEditBox) then
		print("|cFFFF1C1CEnchanter|r Open a mailbox first to prep the return mail.")
		return false
	end

	if type(MailFrameTab_OnClick) == "function" then
		pcall(MailFrameTab_OnClick, nil, 2)
	end

	if SendMailNameEditBox.SetText then
		SendMailNameEditBox:SetText(order.Customer or "")
	end
	if SendMailSubjectEditBox.SetText then
		SendMailSubjectEditBox:SetText(MAILBOX_LOCKBOX_RETURN_SUBJECT)
	end
	if MailEditBox.SetText then
		MailEditBox:SetText(MAILBOX_LOCKBOX_RETURN_BODY)
	elseif MailEditBox.SetInputText then
		MailEditBox:SetInputText(MAILBOX_LOCKBOX_RETURN_BODY)
	end

	attachedStacks, remainingUnlocked, attachReason = AttachTrackedReturnLockboxes(order)
	if type(SendMailFrame_Update) == "function" then
		pcall(SendMailFrame_Update)
	end
	if type(SendMailFrame_CanSend) == "function" then
		pcall(SendMailFrame_CanSend)
	end

	runtime.PendingReturnMailOrderId = orderId
	if attachReason == "existing_attachments" then
		print("|cFFFF1C1CEnchanter|r Prepared return mail for " .. tostring(order.Customer) .. ". Existing attachments were left alone, so only the recipient and message were filled in.")
	elseif attachedStacks > 0 and remainingUnlocked > 0 then
		print("|cFFFF1C1CEnchanter|r Prepared return mail for " .. tostring(order.Customer) .. " and attached " .. tostring(attachedStacks) .. " unlocked lockbox(es). " .. tostring(remainingUnlocked) .. " unlocked lockbox(es) still need manual handling.")
	elseif attachedStacks > 0 then
		print("|cFFFF1C1CEnchanter|r Prepared return mail for " .. tostring(order.Customer) .. " and attached " .. tostring(attachedStacks) .. " unlocked lockbox(es).")
	else
		print("|cFFFF1C1CEnchanter|r Prepared return mail for " .. tostring(order.Customer) .. ". No unlocked lockboxes were auto-attached yet.")
	end
	return true
end

function EC.HandlePotentialMailboxLoot(mailIndex, attachmentIndex)
	local itemInfo = GetInboxAttachmentSnapshot(mailIndex, attachmentIndex)
	local runtime = GetMailboxDisenchantRuntime()
	local lootKey
	local jobKind

	if not EC.Initalized then
		return false
	end

	jobKind = GetMailboxLootJobKind(itemInfo)
	if not jobKind then
		return false
	end
	itemInfo.MailboxJobKind = jobKind

	lootKey = GetPendingMailboxLootKey(itemInfo)
	if lootKey == "" then
		return false
	end
	itemInfo.LootKey = lootKey

	if IsPendingMailboxLootQueued(runtime, itemInfo) then
		return false
	end

	if EC.Workbench and EC.Workbench.EnsureState then
		for _, order in ipairs(EC.Workbench.EnsureState().Orders or {}) do
			if (order.Kind == "disenchant" or order.Kind == "lockbox") and order.Customer == itemInfo.Sender then
				for _, item in ipairs(order.SourceItems or {}) do
					if item.Status ~= "done" and NormalizeTextValue(item.LootKey) == lootKey then
						return false
					end
				end
			end
		end
	end

	runtime.PendingLoots[#runtime.PendingLoots + 1] = itemInfo
	return true
end

function EC.HandlePendingMailboxLootSuccess()
	local runtime = GetMailboxDisenchantRuntime()
	local itemInfo = table.remove(runtime.PendingLoots, 1)
	local order

	if not itemInfo then
		return false
	end

	if not (EC.Workbench and EC.Workbench.AddDisenchantMailItem and EC.Workbench.AddLockboxMailItem) then
		return false
	end

	if itemInfo.MailboxJobKind == "lockbox" then
		order = EC.Workbench.AddLockboxMailItem(itemInfo.Sender, itemInfo)
	else
		order = EC.Workbench.AddDisenchantMailItem(itemInfo.Sender, itemInfo)
	end
	if order and EC.IsChatScanningEnabled and EC.IsChatScanningEnabled() then
		EC.SetChatScanningEnabled(false, MAILBOX_DISENCHANT_PAUSE_MESSAGE)
	end
	if order and EC.SyncDisenchantInventoryTracking then
		EC.SyncDisenchantInventoryTracking()
	end
	if order and EC.Workbench and EC.Workbench.Show then
		EC.Workbench.Show()
	end
	return order ~= nil
end

function EC.HandleDisenchantReturnMailSent()
	local runtime = GetMailboxDisenchantRuntime()
	local orderId = runtime.PendingReturnMailOrderId

	if not orderId then
		return false
	end

	runtime.PendingReturnMailOrderId = nil
	if EC.Workbench and EC.Workbench.CompleteOrder then
		return EC.Workbench.CompleteOrder(orderId)
	end

	return false
end

local function IsDisenchantSpellTargeting()
	return (type(SpellCanTargetItem) == "function" and SpellCanTargetItem() and true)
		or (type(SpellCanTargetItemID) == "function" and SpellCanTargetItemID() and true)
		or (type(SpellIsTargeting) == "function" and SpellIsTargeting() and true)
		or false
end

function EC.HandlePotentialDisenchantTarget(bagIndex, slotIndex)
	local order
	local sourceItem
	local beforeCounts

	-- Look up the tracked item first so that same-frame DE+click sequences
	-- are not dropped. When DE is selected and the item clicked in the same
	-- game frame, CURRENT_SPELL_CAST_CHANGED fires after the UseContainerItem
	-- hook, so SpellIsTargeting() is already false and the passive BeforeCounts
	-- capture hasn't run yet. A slot match is strong enough evidence;
	-- PrimePendingDisenchant falls back to the current bag snapshot for
	-- BeforeCounts and self-clears after 8 s if no mat delta appears.
	order, sourceItem = FindTrackedDisenchantItemByLocation(bagIndex, slotIndex)
	if not order or not sourceItem then
		return false
	end

	beforeCounts = EC.GetRecentMailboxItemTargetingCounts()
	return PrimePendingDisenchant(order, sourceItem, bagIndex, slotIndex, beforeCounts)
end

local function InstallMailboxDisenchantHooks()
	if mailboxHooksInstalled or type(hooksecurefunc) ~= "function" then
		return
	end

	mailboxHooksInstalled = true
	if type(TakeInboxItem) == "function" then
		hooksecurefunc("TakeInboxItem", function(mailIndex, attachmentIndex)
			if EC.Initalized then
				EC.HandlePotentialMailboxLoot(mailIndex, attachmentIndex)
			end
		end)
	end
	if C_Container and type(C_Container.UseContainerItem) == "function" then
		hooksecurefunc(C_Container, "UseContainerItem", function(bagIndex, slotIndex)
			if EC.Initalized then
				EC.HandlePotentialDisenchantTarget(bagIndex, slotIndex)
			end
		end)
	elseif type(UseContainerItem) == "function" then
		hooksecurefunc("UseContainerItem", function(bagIndex, slotIndex)
			if EC.Initalized then
				EC.HandlePotentialDisenchantTarget(bagIndex, slotIndex)
			end
		end)
	end
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
	if type(recipeMap) == "table" and #recipeMap > 0 then
		return #recipeMap
	end

	local count = 0
	if type(recipeMap) ~= "table" then
		return 0
	end

	for _ in pairs(recipeMap) do
		count = count + 1
	end

	return count
end

local function NormalizePositiveInteger(value, fallback)
	local normalized = math.floor(tonumber(value) or 0)
	if normalized < 1 then
		return fallback or 1
	end
	return normalized
end

local function NormalizePhrase(value)
	if not value then
		return ""
	end
	return value:lower():gsub("[%W_]+", "")
end

local function IsWordBoundaryCharacter(character)
	return type(character) == "string"
		and character ~= ""
		and (string.find(character, "%w") ~= nil or character == "_")
end

local function EscapeLuaPattern(value)
	return (tostring(value or ""):gsub("([%(%)%.%%%+%-%*%?%[%]%^%$])", "%%%1"))
end

local function BuildLiteralWordBoundaryPattern(value)
	value = tostring(value or ""):gsub("^%s+", ""):gsub("%s+$", "")
	if value == "" then
		return nil
	end

	local pattern = EscapeLuaPattern(value)
	if IsWordBoundaryCharacter(string.sub(value, 1, 1)) then
		pattern = "%f[%w_]" .. pattern
	end
	if IsWordBoundaryCharacter(string.sub(value, -1)) then
		pattern = pattern .. "%f[^%w_]"
	end
	return pattern
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
		for _, token in ipairs(EC.Tool.Split(value, ",")) do
			local cleanedToken = TrimText(token)
			if cleanedToken ~= "" then
				out[#out + 1] = cleanedToken
			end
		end
		return out
	end

	for token in string.gmatch(value, "([^,]+)") do
		local cleanedToken = TrimText(token)
		if cleanedToken ~= "" then
			out[#out + 1] = cleanedToken
		end
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

local function GetWhisperListenModeStore()
	EC.WhisperListenMode = EC.WhisperListenMode or {}
	return EC.WhisperListenMode
end

function EC.IsWhisperListenMode(name)
	local key = NormalizeNameKey(name)
	return key ~= "" and GetWhisperListenModeStore()[key] == true
end

function EC.SetWhisperListenMode(name, enabled)
	local key = NormalizeNameKey(name)
	local store

	if key == "" then
		return false
	end

	store = GetWhisperListenModeStore()
	if enabled then
		store[key] = true
	else
		store[key] = nil
	end
	return true
end

function EC.ClearWhisperListenMode(name)
	return EC.SetWhisperListenMode(name, false)
end

local function GetComparableNameParts(name)
	if not name then
		return "", ""
	end

	local cleaned = tostring(name):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
	cleaned = cleaned:gsub("^%s+", ""):gsub("%s+$", "")

	local full = cleaned:lower()
	local short = full:match("^([^%-]+)") or full
	return short, full
end

local function NamesMatch(left, right)
	local leftShort, leftFull = GetComparableNameParts(left)
	local rightShort, rightFull = GetComparableNameParts(right)

	if leftShort == "" or rightShort == "" then
		return false
	end

	return leftShort == rightShort
		or leftShort == rightFull
		or leftFull == rightShort
		or leftFull == rightFull
end

local function GetNamedUnit(unitToken)
	local unitName

	if type(GetUnitName) == "function" then
		local ok, namedUnit = pcall(GetUnitName, unitToken, true)
		if ok and type(namedUnit) == "string" and namedUnit ~= "" then
			unitName = namedUnit
		end
	end

	if not unitName and type(UnitName) == "function" then
		local ok, namedUnit = pcall(UnitName, unitToken)
		if ok and type(namedUnit) == "string" and namedUnit ~= "" then
			unitName = namedUnit
		end
	end

	return unitName
end

local function ResolveEmoteTargetUnitToken(name)
	local candidateUnits = { "target", "mouseover", "npc", "NPC" }

	for index = 1, 4 do
		candidateUnits[#candidateUnits + 1] = "party" .. index
	end

	for index = 1, 40 do
		candidateUnits[#candidateUnits + 1] = "raid" .. index
	end

	for _, unitToken in ipairs(candidateUnits) do
		if NamesMatch(GetNamedUnit(unitToken), name) then
			return unitToken
		end
	end

	return nil
end

local function RestoreTemporaryEmoteTarget(originalTargetName, hadTarget)
	if hadTarget then
		if type(TargetLastTarget) == "function" then
			local ok = pcall(TargetLastTarget)
			if ok then
				return true
			end
		end

		if type(TargetUnit) == "function" and originalTargetName ~= "" then
			local ok = pcall(TargetUnit, originalTargetName, true)
			if ok then
				return true
			end
		end

		return false
	end

	if type(ClearTarget) == "function" then
		local ok = pcall(ClearTarget)
		return ok and true or false
	end

	return false
end

local function SendTargetedEmote(emoteToken, name)
	name = TrimText(name)
	if name == "" or type(DoEmote) ~= "function" then
		return false
	end

	local unitToken = ResolveEmoteTargetUnitToken(name)
	if unitToken then
		DoEmote(emoteToken, unitToken)
		return true
	end

	if type(TargetUnit) ~= "function" then
		return false
	end

	local originalTargetName = GetNamedUnit("target") or ""
	local hadTarget = originalTargetName ~= ""
	local ok = pcall(TargetUnit, name, true)
	if not ok then
		return false
	end

	local currentTargetName = GetNamedUnit("target") or ""
	if not NamesMatch(currentTargetName, name) then
		RestoreTemporaryEmoteTarget(originalTargetName, hadTarget)
		return false
	end

	DoEmote(emoteToken, "target")
	RestoreTemporaryEmoteTarget(originalTargetName, hadTarget)
	return true
end

local function IsFrameShown(frame)
	if not frame or not frame.IsShown then
		return false
	end

	local ok, shown = pcall(frame.IsShown, frame)
	return ok and shown and true or false
end

local function IsRecipeDisabledBySettings(recipeName)
	if not EC.DB or not EC.DB.NetherRecipes then
		return false
	end

	for _, disabledRecipeName in ipairs(EC.RecipesWithNether or {}) do
		if disabledRecipeName == recipeName then
			return true
		end
	end

	return false
end

local function GetEnchantingSkillLineName()
	if GetSpellInfo then
		local enchantingName = GetSpellInfo(ENCHANTING_SPELL_ID)
		if type(enchantingName) == "string" and enchantingName ~= "" then
			return enchantingName
		end
	end

	return "Enchanting"
end

local function SkillLineMatchesEnchanting(skillLineName)
	local normalizedSkillLineName = NormalizePhrase(skillLineName)
	local normalizedEnchantingName = NormalizePhrase(GetEnchantingSkillLineName())
	return normalizedSkillLineName ~= "" and normalizedSkillLineName == normalizedEnchantingName
end

local function ProfessionIndexMatchesEnchanting(professionIndex)
	local name, _, _, _, _, _, skillLineId, _, _, _, skillLineName

	if not professionIndex or type(GetProfessionInfo) ~= "function" then
		return false
	end

	name, _, _, _, _, _, skillLineId, _, _, _, skillLineName = GetProfessionInfo(professionIndex)
	return tonumber(skillLineId) == ENCHANTING_SKILL_LINE_ID
		or SkillLineMatchesEnchanting(name)
		or SkillLineMatchesEnchanting(skillLineName)
end

local function ProfessionListShowsEnchanting()
	if type(GetProfessions) ~= "function" or type(GetProfessionInfo) ~= "function" then
		return nil
	end

	for _, professionIndex in ipairs({ GetProfessions() }) do
		if ProfessionIndexMatchesEnchanting(professionIndex) then
			return true
		end
	end

	return false
end

local function SkillLinesShowEnchanting()
	if type(GetNumSkillLines) ~= "function" or type(GetSkillLineInfo) ~= "function" then
		return nil
	end

	for skillIndex = 1, math.max(0, math.floor(tonumber(GetNumSkillLines()) or 0)) do
		local skillName, isHeader = GetSkillLineInfo(skillIndex)
		if not isHeader and SkillLineMatchesEnchanting(skillName) then
			return true
		end
	end

	return false
end

function EC.IsPlayerEnchanter()
	local professionMatch = ProfessionListShowsEnchanting()
	local skillLineMatch

	if professionMatch == true then
		return true
	end

	skillLineMatch = SkillLinesShowEnchanting()
	if skillLineMatch == true then
		return true
	end

	if type(IsSpellKnown) == "function" and IsSpellKnown(ENCHANTING_SPELL_ID) then
		return true
	end

	if skillLineMatch ~= nil then
		return false
	end

	if professionMatch ~= nil then
		return professionMatch
	end

	if type(IsSpellKnown) == "function" then
		return false
	end

	return true
end

local function BuildAuctionSearchTermForRecipe(recipeName)
	recipeName = TrimText(recipeName)
	if recipeName == "" then
		return nil
	end

	local overrideSearchTerm = RecipeAuctionSearchOverrides[recipeName]
	if overrideSearchTerm ~= nil then
		overrideSearchTerm = TrimText(overrideSearchTerm)
		return overrideSearchTerm ~= "" and overrideSearchTerm or nil
	end

	if string.find(recipeName, "^Formula:%s") then
		return recipeName
	end

	return RECIPE_FORMULA_PREFIX .. recipeName
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

local function GetBanList()
	EC.DB = EC.DB or {}
	EC.DB.BanList = EC.DB.BanList or {}
	return EC.DB.BanList
end

function EC.IsBanned(name)
	local key = NormalizeNameKey(name)
	if key == "" then
		return false
	end
	return GetBanList()[key] == true
end

function EC.BanPlayer(name)
	local key = NormalizeNameKey(name)
	if key == "" then
		return false
	end
	GetBanList()[key] = true
	return true
end

function EC.UnbanPlayer(name)
	local key = NormalizeNameKey(name)
	if key == "" then
		return false
	end
	GetBanList()[key] = nil
	return true
end

local function SeedRandom()
	if randomSeeded then
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
	randomSeeded = true
end

local function PickRandomIndex(list)
	if type(list) ~= "table" or #list == 0 then
		return nil
	end

	SeedRandom()

	local randomFn = (math and math.random) or random
	local index

	if type(randomFn) == "function" then
		local ok, value = pcall(randomFn, #list)
		if ok then
			index = tonumber(value)
		end
	end

	if not index or index < 1 or index > #list then
		randomFallbackCounter = randomFallbackCounter + 1
		index = ((randomFallbackCounter - 1) % #list) + 1
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

local function SplitMessagePrefixChoices(value)
	local out = {}
	local prefixText = tostring(value or "")
	local chunkStart = 1

	if prefixText == "" then
		return out
	end

	while true do
		local delimiterStart, delimiterEnd = string.find(prefixText, "%s+,%s*", chunkStart)
		if not delimiterStart then
			break
		end

		local choice = TrimText(string.sub(prefixText, chunkStart, delimiterStart - 1))
		if choice ~= "" then
			out[#out + 1] = choice
		end

		chunkStart = delimiterEnd + 1
	end

	local finalChoice = TrimText(string.sub(prefixText, chunkStart))
	if finalChoice ~= "" then
		out[#out + 1] = finalChoice
	end

	return out
end

local function GetRecipeWhisperPrefix()
	local prefixChoices = SplitMessagePrefixChoices(EC and EC.DB and EC.DB.MsgPrefix)
	local prefix = PickRandom(prefixChoices)

	if not prefix or prefix == "" then
		prefix = TrimText(EC and EC.DB and EC.DB.MsgPrefix or EC.DefaultMsg)
	end
	if prefix == "" then
		prefix = TrimText(EC.DefaultMsg)
	end
	if prefix == "" then
		return ""
	end

	return prefix .. " "
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

local function MessageMatchesDeclinedGroupTemplate(message, customerName)
	local templates = {
		_G and _G.ERR_DECLINE_GROUP_S,
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

local function IsDeclinedGroupInviteMessage(message, customerName)
	local normalizedMessage = NormalizePhrase(message)
	if normalizedMessage == "" then
		return false
	end

	if MessageMatchesDeclinedGroupTemplate(message, customerName) then
		return true
	end

	if string.find(normalizedMessage, "declinesyourgroupinvitation", 1, true) then
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

local function FindPendingInviteByMatcher(message, matcher)
	local matchedPending
	local pendingCount = 0
	local latestPending

	for _, pending in pairs(EC.PendingInvites) do
		if pending and pending.Name then
			pendingCount = pendingCount + 1
			if not latestPending or (pending.Timestamp or 0) > (latestPending.Timestamp or 0) then
				latestPending = pending
			end
			if matcher(message, pending.Name) then
				matchedPending = pending
				break
			end
		end
	end

	if not matchedPending and pendingCount == 1 and latestPending and matcher(message, nil) then
		matchedPending = latestPending
	end

	return matchedPending
end

function EC.GetMatchedRecipeNames(recipeMap)
	local out = {}
	if type(recipeMap) ~= "table" then
		return out
	end

	if #recipeMap > 0 then
		for index = 1, #recipeMap do
			local recipeName = recipeMap[index]
			if type(recipeName) == "string" and recipeName ~= "" then
				out[#out + 1] = recipeName
			end
		end
	else
		local seen = {}
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

local function AddSupplementalRecipeTagAlias(tagMap, tagList, recipeName, tag)
	if type(tagMap) ~= "table" or type(tagList) ~= "table" or type(recipeName) ~= "string" or recipeName == "" then
		return
	end

	if type(tag) ~= "string" or tag ~= string.lower(recipeName) then
		return
	end

	local undashedTag = TrimText((tag:gsub("%s+%-%s+", " ")):gsub("%s+", " "))
	if undashedTag == "" or undashedTag == tag then
		return
	end

	if tagMap[undashedTag] == nil then
		tagMap[undashedTag] = recipeName
		tagList[#tagList + 1] = undashedTag
	end
end

local function AddRecipeTagsToLookup(tagMap, tagList, recipeName, tags)
	if type(recipeName) ~= "string" or recipeName == "" or type(tags) ~= "table" then
		return
	end

	local canonicalTag = string.lower(recipeName)
	for _, tag in ipairs(tags) do
		if tag and tag ~= "" then
			tagMap[tag] = recipeName
			tagList[#tagList + 1] = tag
			if tag == canonicalTag then
				-- Accept the full official enchant name even when callers omit the separator dash.
				AddSupplementalRecipeTagAlias(tagMap, tagList, recipeName, tag)
			end
		end
	end
end

local function BuildTagBuckets(tagMap)
	local buckets = {}

	if type(tagMap) ~= "table" then
		return buckets
	end

	for tag, recipeName in pairs(tagMap) do
		if type(tag) == "string" and tag ~= "" and type(recipeName) == "string" and recipeName ~= "" then
			local firstCharacter = string.sub(tag, 1, 1)
			local bucket = buckets[firstCharacter]
			if not bucket then
				bucket = {}
				buckets[firstCharacter] = bucket
			end
			bucket[#bucket + 1] = {
				Length = string.len(tag),
				RecipeName = recipeName,
				Tag = tag,
			}
		end
	end

	for _, bucket in pairs(buckets) do
		table.sort(bucket, function(left, right)
			if left.Length ~= right.Length then
				return left.Length > right.Length
			end
			if left.Tag ~= right.Tag then
				return left.Tag < right.Tag
			end
			return left.RecipeName < right.RecipeName
		end)
	end

	return buckets
end

local function GetConfiguredRecipeTags(recipeName)
	local customText = EC.DB and EC.DB.Custom and EC.DB.Custom[recipeName]
	if customText ~= nil and customText ~= "" then
		local customTags = SplitStoredCSV(customText)
		if EC.EnsureExactRecipeNameTag then
			return EC.EnsureExactRecipeNameTag(recipeName, customTags)
		end
		return customTags
	end

	if EC.RecipeTags and EC.RecipeTags["enGB"] then
		local defaultTags = EC.RecipeTags["enGB"][recipeName]
		if type(defaultTags) == "table" and #defaultTags > 0 then
			return defaultTags
		end
	end

	if EC.GeneratedRecipeTags and EC.GeneratedRecipeTags["enGB"] then
		local generatedTags = EC.GeneratedRecipeTags["enGB"][recipeName]
		if type(generatedTags) == "table" and #generatedTags > 0 then
			return generatedTags
		end
	end

	return nil
end

local function GetScannedRecipeTags(recipeName)
	recipeName = TrimText(recipeName)
	if recipeName == "" then
		return nil
	end

	local configuredTags = GetConfiguredRecipeTags(recipeName)
	if type(configuredTags) == "table" and #configuredTags > 0 then
		return configuredTags
	end

	local normalizedRecipeName = string.lower(recipeName)
	if string.find(normalizedRecipeName, "enchant ", 1, true) == 1 then
		local generatedTags = EC.BuildSpecificRecipeTagList and EC.BuildSpecificRecipeTagList(recipeName) or nil
		if type(generatedTags) == "table" and #generatedTags > 0 then
			EC.GeneratedRecipeTags = EC.GeneratedRecipeTags or { enGB = {} }
			EC.GeneratedRecipeTags["enGB"] = EC.GeneratedRecipeTags["enGB"] or {}
			EC.GeneratedRecipeTags["enGB"][recipeName] = generatedTags
			return generatedTags
		end

		return { normalizedRecipeName }
	end

	return nil
end

local function MergePhraseLists(...)
	local merged = {}
	local seen = {}

	for index = 1, select("#", ...) do
		local phraseList = select(index, ...)
		if type(phraseList) == "table" then
			for _, phrase in ipairs(phraseList) do
				if phrase and phrase ~= "" and not seen[phrase] then
					seen[phrase] = true
					merged[#merged + 1] = phrase
				end
			end
		end
	end

	if #merged == 0 then
		return nil
	end

	return merged
end

local function GetConfiguredRecipeBlacklist(recipeName)
	local defaultBlacklist = EC.DefaultRecipeBlacklists
		and EC.DefaultRecipeBlacklists["enGB"]
		and EC.DefaultRecipeBlacklists["enGB"][recipeName]
	local blacklistMap = EC.DB and EC.DB.Custom and EC.DB.Custom.RecipeBlackList
	local customText = blacklistMap and blacklistMap[recipeName]
	if customText ~= nil and customText ~= "" then
		return MergePhraseLists(defaultBlacklist, SplitStoredCSV(customText))
	end

	return MergePhraseLists(defaultBlacklist)
end

local function FindNextRecipeContextSeparator(message, startIndex)
	local length = string.len(message or "")
	local index = math.max(1, math.floor(tonumber(startIndex) or 1))

	while index <= length do
		local character = string.sub(message, index, index)
		if string.find(",;/+&", character, 1, true) then
			return index, index
		end

		if string.sub(message, index, index + 4) == " and " then
			return index, index + 4
		end

		if string.sub(message, index, index + 3) == " or " then
			return index, index + 3
		end

		if string.sub(message, index, index + 5) == " then " then
			return index, index + 5
		end

		index = index + 1
	end

	return nil
end

local function GetRecipeMatchContext(parsedMessage, matchStart, matchEnd)
	if type(parsedMessage) ~= "string" or parsedMessage == "" then
		return ""
	end

	matchStart = math.max(1, math.floor(tonumber(matchStart) or 1))
	matchEnd = math.max(matchStart, math.floor(tonumber(matchEnd) or matchStart))

	local contextStart = 1
	local contextEnd = string.len(parsedMessage)
	local scanIndex = 1

	while true do
		local boundaryStart, boundaryEnd = FindNextRecipeContextSeparator(parsedMessage, scanIndex)
		if not boundaryStart then
			break
		end

		if boundaryEnd < matchStart then
			contextStart = boundaryEnd + 1
			scanIndex = boundaryEnd + 1
		elseif boundaryStart > matchEnd then
			contextEnd = boundaryStart - 1
			break
		else
			scanIndex = boundaryEnd + 1
		end
	end

	return TrimText(string.sub(parsedMessage, contextStart, contextEnd))
end

local function GetBracketedRecipeMatchContext(parsedMessage, matchStart, matchEnd)
	if type(parsedMessage) ~= "string" or parsedMessage == "" then
		return ""
	end

	matchStart = math.max(1, math.floor(tonumber(matchStart) or 1))
	matchEnd = math.max(matchStart, math.floor(tonumber(matchEnd) or matchStart))

	local bracketStart
	local bracketEnd
	local index = matchStart
	local messageLength = string.len(parsedMessage)

	while index >= 1 do
		local character = string.sub(parsedMessage, index, index)
		if character == "[" then
			bracketStart = index
			break
		end
		if character == "]" then
			return ""
		end
		index = index - 1
	end

	if not bracketStart then
		return ""
	end

	index = matchEnd
	while index <= messageLength do
		local character = string.sub(parsedMessage, index, index)
		if character == "]" then
			bracketEnd = index
			break
		end
		if character == "[" then
			return ""
		end
		index = index + 1
	end

	if not bracketEnd or bracketEnd <= bracketStart then
		return ""
	end

	return TrimText(string.sub(parsedMessage, bracketStart + 1, bracketEnd - 1))
end

local function IsFormulaRecipeContext(parsedMessage, matchStart, matchEnd)
	local bracketContext = GetBracketedRecipeMatchContext(parsedMessage, matchStart, matchEnd)
	if bracketContext ~= "" and string.match(string.lower(bracketContext), "^formula:%s*") then
		return true
	end

	local prefixContext = TrimText(string.sub(parsedMessage or "", 1, math.max(0, (tonumber(matchStart) or 1) - 1)))
	if prefixContext ~= "" and string.find(string.lower(prefixContext), "formula:", 1, true) then
		return true
	end

	return false
end

local function GetRecipeBlacklistContext(parsedMessage, matchStart, matchEnd)
	local bracketContext = GetBracketedRecipeMatchContext(parsedMessage, matchStart, matchEnd)
	if bracketContext ~= "" then
		return bracketContext
	end

	return GetRecipeMatchContext(parsedMessage, matchStart, matchEnd)
end

local function SplitRecipeRequestSegments(parsedMessage)
	local segments = {}
	if type(parsedMessage) ~= "string" or parsedMessage == "" then
		return segments
	end

	local length = string.len(parsedMessage)
	local segmentStart = 1

	while segmentStart <= length do
		local boundaryStart, boundaryEnd = FindNextRecipeContextSeparator(parsedMessage, segmentStart)
		local segmentEnd = boundaryStart and (boundaryStart - 1) or length
		local segmentText = TrimText(string.sub(parsedMessage, segmentStart, segmentEnd))
		if segmentText ~= "" then
			segments[#segments + 1] = segmentText
		end

		if not boundaryStart then
			break
		end

		segmentStart = boundaryEnd + 1
	end

	return segments
end

local function GetMatchedRecipeBlacklist(parsedMessage, recipeName)
	local blacklist = EC.RecipeBlacklistMap and EC.RecipeBlacklistMap[recipeName]
	if type(blacklist) ~= "table" then
		return nil
	end

	if type(parsedMessage) ~= "string" or parsedMessage == "" then
		return nil
	end

	for _, phrase in ipairs(blacklist) do
		if phrase and phrase ~= "" and string.find(parsedMessage, phrase, 1, true) then
			return phrase
		end
	end

	return nil
end

local function RangesOverlap(startA, finishA, startB, finishB)
	return startA <= finishB and startB <= finishA
end

local function IsAlphaNumericCharacter(character)
	return IsWordBoundaryCharacter(character)
end

local function HasRecipeTagStartBoundary(parsedMessage, matchStart)
	if type(parsedMessage) ~= "string" then
		return false
	end

	if matchStart <= 1 then
		return true
	end

	return not IsAlphaNumericCharacter(string.sub(parsedMessage, matchStart - 1, matchStart - 1))
end

local function CompareRecipeTagCandidates(left, right)
	if left.Length ~= right.Length then
		return left.Length > right.Length
	end
	if left.Start ~= right.Start then
		return left.Start < right.Start
	end
	if left.Finish ~= right.Finish then
		return left.Finish < right.Finish
	end
	if left.RecipeName ~= right.RecipeName then
		return left.RecipeName < right.RecipeName
	end
	return left.Tag < right.Tag
end

local function MergeRecipeMatches(targetMap, sourceMap)
	if type(targetMap) ~= "table" or type(sourceMap) ~= "table" then
		return targetMap
	end

	for recipeName, tag in pairs(sourceMap) do
		if targetMap[recipeName] == nil then
			targetMap[recipeName] = tag
		end
	end

	return targetMap
end

local function GetRecipeMatchQuantity(parsedMessage, matchStart, matchEnd)
	local prefixContext
	local suffixContext
	local quantity

	if type(parsedMessage) ~= "string" or parsedMessage == "" then
		return 1
	end

	prefixContext = TrimText(string.sub(parsedMessage, 1, math.max(0, matchStart - 1)))
	suffixContext = TrimText(string.sub(parsedMessage, matchEnd + 1))

	quantity = suffixContext:match("^x%s*(%d+)%f[%D]")
		or suffixContext:match("^(%d+)%s*x%f[%D]")
		or prefixContext:match("^x%s*(%d+)$")
		or prefixContext:match("%s+x%s*(%d+)$")
		or prefixContext:match("^(%d+)%s*x$")
		or prefixContext:match("%s+(%d+)%s*x$")

	return NormalizePositiveInteger(quantity, 1)
end

local function ExpandRecipeMatchEntries(matchEntries)
	local recipes = {}

	if type(matchEntries) ~= "table" then
		return recipes
	end

	for _, entry in ipairs(matchEntries) do
		local recipeName = entry and entry.RecipeName
		local quantity = NormalizePositiveInteger(entry and entry.Quantity, 1)
		if type(recipeName) == "string" and recipeName ~= "" then
			for _ = 1, quantity do
				recipes[#recipes + 1] = recipeName
			end
		end
	end

	return recipes
end

local function AppendRecipeMatches(targetList, sourceList)
	if type(targetList) ~= "table" or type(sourceList) ~= "table" then
		return targetList
	end

	for _, recipeName in ipairs(sourceList) do
		targetList[#targetList + 1] = recipeName
	end

	return targetList
end

local function MatchRecipeTags(parsedMessage, tagBuckets)
	local candidates = {}
	local matches = {}
	local matchedRecipes = {}
	local acceptedRanges = {}

	if type(parsedMessage) ~= "string" or parsedMessage == "" then
		return matches
	end

	local messageLength = string.len(parsedMessage)
	for matchStart = 1, messageLength do
		if HasRecipeTagStartBoundary(parsedMessage, matchStart) then
			local bucket = tagBuckets and tagBuckets[string.sub(parsedMessage, matchStart, matchStart)]
			if bucket then
				for _, entry in ipairs(bucket) do
					local matchEnd = matchStart + entry.Length - 1
					if matchEnd <= messageLength and string.sub(parsedMessage, matchStart, matchEnd) == entry.Tag then
						local recipeName = entry.RecipeName
						local blacklistContext = GetRecipeBlacklistContext(parsedMessage, matchStart, matchEnd)
						if not IsFormulaRecipeContext(parsedMessage, matchStart, matchEnd)
							and not GetMatchedRecipeBlacklist(blacklistContext, recipeName) then
							candidates[#candidates + 1] = {
								RecipeName = recipeName,
								Tag = entry.Tag,
								Start = matchStart,
								Finish = matchEnd,
								Length = entry.Length,
							}
						end
					end
				end
			end
		end
	end

	table.sort(candidates, CompareRecipeTagCandidates)

	for _, candidate in ipairs(candidates) do
		if not matchedRecipes[candidate.RecipeName] then
			local isOverlapping = false
			for _, acceptedRange in ipairs(acceptedRanges) do
				if RangesOverlap(candidate.Start, candidate.Finish, acceptedRange.Start, acceptedRange.Finish) then
					isOverlapping = true
					break
				end
			end

			if not isOverlapping then
				matchedRecipes[candidate.RecipeName] = true
				matches[#matches + 1] = {
					RecipeName = candidate.RecipeName,
					Tag = candidate.Tag,
					Start = candidate.Start,
					Finish = candidate.Finish,
					Quantity = GetRecipeMatchQuantity(parsedMessage, candidate.Start, candidate.Finish),
				}
				acceptedRanges[#acceptedRanges + 1] = {
					Start = candidate.Start,
					Finish = candidate.Finish,
				}
			end
		end
	end

	return matches
end

local function GetRecipeRequestDetails(parsedMessage)
	local matchedRecipeMap = {}
	local requestedRecipeMap = {}
	local segments = SplitRecipeRequestSegments(parsedMessage)
	if #segments == 0 then
		segments[1] = parsedMessage
	end

	for _, segment in ipairs(segments) do
		AppendRecipeMatches(matchedRecipeMap, ExpandRecipeMatchEntries(MatchRecipeTags(segment, EC.RecipeTagBuckets)))
		AppendRecipeMatches(requestedRecipeMap, ExpandRecipeMatchEntries(MatchRecipeTags(segment, EC.RequestRecipeTagBuckets)))
	end

	local matchedCount = CountRecipeEntries(matchedRecipeMap)
	local requestedCount = math.max(matchedCount, CountRecipeEntries(requestedRecipeMap))

	return matchedRecipeMap, matchedCount, requestedCount
end

function EC.BuildRecipeWhisper(recipeNames, requestedRecipeCount)
	local matchedRecipeNames = EC.GetMatchedRecipeNames(recipeNames)
	local msg = GetRecipeWhisperPrefix()
	local matchedCount = #matchedRecipeNames
	local requestedCount = math.max(matchedCount, math.floor(tonumber(requestedRecipeCount) or 0))

	if EC.DB.WarnIncompleteOrder ~= false and requestedCount > matchedCount then
		msg = msg .. matchedCount .. "/" .. requestedCount .. " "
	end

	for _, recipeName in ipairs(matchedRecipeNames) do
		local recipeLink = EC.DBChar.RecipeLinks[recipeName]
		msg = msg .. (NormalizeTextValue(recipeLink) ~= "" and recipeLink or ("[" .. recipeName .. "] "))
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

function EC.SendThankEmote(name, sourceLabel)
	if not name or name == "" or not EC.DB or EC.DB.EmoteThankAfterCast ~= true then
		return false
	end

	if IsSimulatedCustomer(name) then
		EC.DebugPrint((sourceLabel or "simulated thank") .. " " .. name)
		return true
	end

	if EC.DBChar and EC.DBChar.Debug then
		EC.DebugPrint((sourceLabel or "would thank") .. " " .. name)
		return true
	end

	if type(DoEmote) ~= "function" then
		return false
	end

	if SendTargetedEmote("THANK", name) then
		return true
	end

	if EC.DBChar and EC.DBChar.Debug then
		EC.DebugPrint((sourceLabel or "could not thank") .. " " .. name)
	end
	return false
end

function EC.InviteCustomer(name, sourceLabel)
	if not name or name == "" then
		return
	end

	if IsSimulatedCustomer(name) then
		EC.DebugPrint((sourceLabel or "simulated invite") .. " " .. name)
		return
	end

	if EC.Workbench and EC.Workbench.ClearOrderInviteDeclined then
		EC.Workbench.ClearOrderInviteDeclined(name)
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
	if type(message) ~= "string" or message == "" then
		return false
	end

	PrunePendingInvites()

	local matchedPending = FindPendingInviteByMatcher(message, IsAlreadyGroupedMessage)
	if matchedPending then
		EC.PendingInvites[NormalizeNameKey(matchedPending.Name)] = nil
		if EC.Workbench and EC.Workbench.MarkOrderAlreadyGrouped then
			EC.Workbench.MarkOrderAlreadyGrouped(matchedPending.Name)
		end
		EC.DebugPrint("detected already-grouped invite failure for", matchedPending.Name)
		if EC.DB and EC.DB.GroupedFollowUp then
			After(EC.DB.GroupedFollowUpDelay, function()
				EC.SendGroupedFollowUp(matchedPending.Name, "grouped follow-up")
			end)
		end
		return true
	end

	matchedPending = FindPendingInviteByMatcher(message, IsDeclinedGroupInviteMessage)
	if matchedPending then
		EC.PendingInvites[NormalizeNameKey(matchedPending.Name)] = nil
		if EC.Workbench and EC.Workbench.MarkOrderInviteDeclined then
			EC.Workbench.MarkOrderInviteDeclined(matchedPending.Name)
		end
		EC.DebugPrint("detected declined invite for", matchedPending.Name)
		return true
	end

	return false
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
	if EC.DBChar.PendingRecipeMaterialCount == nil then EC.DBChar.PendingRecipeMaterialCount = 0 end
	if EC.DBChar.Stop == nil then EC.DBChar.Stop = false end
	if EC.DBChar.AutoPausedForMaxGroupedCustomers == nil then EC.DBChar.AutoPausedForMaxGroupedCustomers = false end
	if EC.DBChar.Debug == nil then EC.DBChar.Debug = false end
	if EC.DB.AutoInvite == nil then EC.DB.AutoInvite = true end
	if EC.DB.WarnIncompleteOrder == nil then EC.DB.WarnIncompleteOrder = true end
	if EC.DB.InviteIncompleteOrder == nil then EC.DB.InviteIncompleteOrder = true end
	if EC.DB.NetherRecipes == nil then EC.DB.NetherRecipes = false end
	if EC.DB.WhisperLfRequests == nil then EC.DB.WhisperLfRequests = false end
	if EC.DB.GroupedFollowUp == nil then EC.DB.GroupedFollowUp = false end
	if EC.DB.EmoteThankAfterCast == nil then EC.DB.EmoteThankAfterCast = false end
	if EC.DB.PlaySoundOnPartyJoinInstead == nil then EC.DB.PlaySoundOnPartyJoinInstead = false end
	if EC.DB.InviteTimeDelay == nil then EC.DB.InviteTimeDelay = 0 end
	if EC.DB.WhisperTimeDelay == nil then EC.DB.WhisperTimeDelay = 0 end
	if EC.DB.GroupedFollowUpDelay == nil then EC.DB.GroupedFollowUpDelay = 1 end
	if EC.DB.GroupedQueueExpireSeconds == nil then EC.DB.GroupedQueueExpireSeconds = 0 end
	EC.DB.GroupedQueueExpireSeconds = math.max(0, math.floor(tonumber(EC.DB.GroupedQueueExpireSeconds) or 0))
	if EC.DB.DeclinedInviteRemovalSeconds == nil then EC.DB.DeclinedInviteRemovalSeconds = 0 end
	EC.DB.DeclinedInviteRemovalSeconds = math.max(0, math.floor(tonumber(EC.DB.DeclinedInviteRemovalSeconds) or 0))
	if EC.DB.MaxGroupedCustomers == nil then EC.DB.MaxGroupedCustomers = 0 end
	EC.DB.MaxGroupedCustomers = GetMaxGroupedCustomers()
	if not EC.DB.MsgPrefix or EC.DB.MsgPrefix == "" then EC.DB.MsgPrefix = EC.DefaultMsg end
	if not EC.DB.LfWhisperMsg or EC.DB.LfWhisperMsg == "" then EC.DB.LfWhisperMsg = EC.DefaultLfWhisperMsg end
	if not EC.DB.GroupedFollowUpMsg or EC.DB.GroupedFollowUpMsg == "" then EC.DB.GroupedFollowUpMsg = EC.DefaultGroupedFollowUpMsg end
	RefreshStoredRecipeMaterials()
	if EC.Workbench and EC.Workbench.EnsureState then EC.Workbench.EnsureState() end
end

function EC.EnforceMaxGroupedCustomerLimit()
	local maxCustomers = GetMaxGroupedCustomers()
	local groupedCustomerCount
	local wasAutoPaused

	if not EC.DBChar then
		return false
	end

	wasAutoPaused = EC.DBChar.AutoPausedForMaxGroupedCustomers == true

	if maxCustomers <= 0 then
		if wasAutoPaused then
			EC.DBChar.AutoPausedForMaxGroupedCustomers = false
			EC.DBChar.Stop = false
			if EC.Workbench and EC.Workbench.Refresh then
				EC.Workbench.Refresh()
			end
		end
		return false
	end

	if not EC.Workbench or not EC.Workbench.GetGroupedCustomerCount then
		return false
	end

	groupedCustomerCount = math.max(0, math.floor(tonumber(EC.Workbench.GetGroupedCustomerCount()) or 0))
	if groupedCustomerCount < maxCustomers then
		if wasAutoPaused then
			EC.DBChar.AutoPausedForMaxGroupedCustomers = false
			EC.DBChar.Stop = false
			if EC.Workbench and EC.Workbench.Refresh then
				EC.Workbench.Refresh()
			end
			print(BuildGroupedCustomerResumeMessage(groupedCustomerCount, maxCustomers))
		end
		return false
	end

	if EC.DBChar.Stop == true then
		return wasAutoPaused
	end

	EC.DBChar.AutoPausedForMaxGroupedCustomers = true
	EC.DBChar.Stop = true
	if EC.Workbench and EC.Workbench.Refresh then
		EC.Workbench.Refresh()
	end

	print(BuildGroupedCustomerLimitMessage(groupedCustomerCount, maxCustomers))
	return true
end

function EC.RefreshCompiledData()
	EC.PrefixTagsCompiled = {}
	EC.BlacklistCompiled = {}
	EC.RecipeBlacklistMap = {}
	EC.RecipeTagsMap = {}
	EC.RecipeTagList = {}
	EC.RecipeTagBuckets = {}
	EC.RequestRecipeTagsMap = {}
	EC.RequestRecipeTagList = {}
	EC.RequestRecipeTagBuckets = {}
	EC.EnchanterTagsNormalized = {}

	for _, value in ipairs(EC.PrefixTags or {}) do
		if value and value ~= "" then
			local pattern = BuildLiteralWordBoundaryPattern(value)
			if pattern then
				table.insert(EC.PrefixTagsCompiled, pattern)
			end
		end
	end

	for _, value in ipairs(EC.BlackList or {}) do
		if value and value ~= "" then
			local pattern = BuildLiteralWordBoundaryPattern(value)
			if pattern then
				table.insert(EC.BlacklistCompiled, pattern)
			end
		end
	end

	for _, value in ipairs(EC.EnchanterTags or {}) do
		local normalizedValue = NormalizePhrase(value)
		if normalizedValue ~= "" then
			EC.EnchanterTagsNormalized[normalizedValue] = true
		end
	end

	for recipeName in pairs(EC.RecipeTags and EC.RecipeTags["enGB"] or {}) do
		local recipeBlacklist = GetConfiguredRecipeBlacklist(recipeName)
		if recipeBlacklist and #recipeBlacklist > 0 then
			EC.RecipeBlacklistMap[recipeName] = recipeBlacklist
		end
		AddRecipeTagsToLookup(EC.RequestRecipeTagsMap, EC.RequestRecipeTagList, recipeName, GetConfiguredRecipeTags(recipeName))
	end

	for recipeName, tags in pairs(EC.DBChar.RecipeList or {}) do
		if not EC.RecipeBlacklistMap[recipeName] then
			local recipeBlacklist = GetConfiguredRecipeBlacklist(recipeName)
			if recipeBlacklist and #recipeBlacklist > 0 then
				EC.RecipeBlacklistMap[recipeName] = recipeBlacklist
			end
		end
		AddRecipeTagsToLookup(EC.RecipeTagsMap, EC.RecipeTagList, recipeName, tags)
	end

	EC.RecipeTagBuckets = BuildTagBuckets(EC.RecipeTagsMap)
	EC.RequestRecipeTagBuckets = BuildTagBuckets(EC.RequestRecipeTagsMap)

	if EC.Workbench and EC.Workbench.Refresh then
		EC.Workbench.Refresh()
	end
end

function EC.GetItems()
	EC.GeneratedRecipeTags = { enGB = {} }

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
			local recipeTags = GetScannedRecipeTags(recipeName)
			if recipeName and not IsRecipeHeader(index, apiKind) and recipeTags then
				if selectRecipe then
					selectRecipe(index)
				end
				recipeLinks[recipeName] = getLink and getLink(index) or nil
				recipeMats[recipeName] = CaptureRecipeMaterials(index, apiKind)
				recipeList[recipeName] = recipeTags
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
	local bestUnresolvedMaterialCount = math.huge
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
		local unresolvedMaterialCount = CountUnresolvedRecipeMaterials(recipeMats)
		if ok then
			triedAnyApi = true
			if recipeCount > bestRecipeCount or (recipeCount == bestRecipeCount and unresolvedMaterialCount < bestUnresolvedMaterialCount) then
				bestRecipeCount = recipeCount
				bestUnresolvedMaterialCount = unresolvedMaterialCount
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
	RefreshStoredRecipeMaterials()

	EC.UpdateTags()
	EC.RefreshCompiledData()
	return bestRecipeCount > 0
end

function EC.IsAuctionatorAvailable()
	return Auctionator ~= nil
		and Auctionator.API ~= nil
		and Auctionator.API.v1 ~= nil
		and type(Auctionator.API.v1.MultiSearchExact) == "function"
end

function EC.IsAuctionHouseOpen()
	return IsFrameShown(AuctionFrame) or IsFrameShown(AuctionHouseFrame)
end

function EC.IsEnchantingProfessionVisible()
	if IsFrameShown(TradeSkillFrame) then
		if type(GetTradeSkillLine) ~= "function" then
			return true
		end
		return SkillLineMatchesEnchanting(GetTradeSkillLine())
	end

	if IsFrameShown(CraftFrame) then
		if type(GetCraftDisplaySkillLine) ~= "function" then
			return true
		end
		return SkillLineMatchesEnchanting(GetCraftDisplaySkillLine())
	end

	return false
end

function EC.CanSearchMissingEnchantRecipes()
	return EC.IsAuctionatorAvailable() and EC.IsAuctionHouseOpen()
end

function EC.GetMissingEnchantRecipeNames()
	local knownRecipeList = EC.DBChar and EC.DBChar.RecipeList or {}
	local missingRecipeNames = {}

	for recipeName in pairs(EC.RecipeTags and EC.RecipeTags["enGB"] or {}) do
		if not knownRecipeList[recipeName] and not IsRecipeDisabledBySettings(recipeName) then
			missingRecipeNames[#missingRecipeNames + 1] = recipeName
		end
	end

	table.sort(missingRecipeNames)
	return missingRecipeNames
end

function EC.GetMissingEnchantRecipeSearchTerms()
	local missingRecipeNames = EC.GetMissingEnchantRecipeNames()
	local searchTerms = {}

	for _, recipeName in ipairs(missingRecipeNames) do
		local searchTerm = BuildAuctionSearchTermForRecipe(recipeName)
		if searchTerm then
			searchTerms[#searchTerms + 1] = searchTerm
		end
	end

	return searchTerms
end

function EC.SearchAuctionHouseForMissingEnchantRecipes()
	if not EC.CanSearchMissingEnchantRecipes() then
		print("|cFFFF1C1CEnchanter|r Open the Auction House with Auctionator loaded to search for missing enchant formulas.")
		return false
	end

	local hadStoredRecipes = CountRecipeEntries(EC.DBChar and EC.DBChar.RecipeList or nil) > 0
	local previousRecipeList = EC.DBChar and EC.DBChar.RecipeList or nil
	local previousRecipeLinks = EC.DBChar and EC.DBChar.RecipeLinks or nil
	local previousRecipeMats = EC.DBChar and EC.DBChar.RecipeMats or nil

	if EC.IsEnchantingProfessionVisible() then
		local refreshed = EC.GetItems()
		if not refreshed and hadStoredRecipes and EC.DBChar then
			EC.DBChar.RecipeList = previousRecipeList
			EC.DBChar.RecipeLinks = previousRecipeLinks
			EC.DBChar.RecipeMats = previousRecipeMats
			EC.UpdateTags()
			EC.RefreshCompiledData()
		end
	end

	if EC.NeedsRecipeScan and EC.NeedsRecipeScan() then
		print("|cFFFF1C1CEnchanter|r Run /ec scan first, or open your enchanting window before searching the AH for missing formulas.")
		return false
	end

	local searchTerms = EC.GetMissingEnchantRecipeSearchTerms()
	if #searchTerms == 0 then
		print("|cFFFF1C1CEnchanter|r No missing enchant formulas were found in your current recipe set.")
		return false
	end

	local ok, err = pcall(Auctionator.API.v1.MultiSearchExact, AUCTIONATOR_CALLER_ID, searchTerms)
	if not ok then
		print("|cFFFF1C1CEnchanter|r Auctionator could not start the missing-formula search: " .. tostring(err))
		return false
	end

	print(string.format("|cFFFF1C1CEnchanter|r Searching Auctionator for %d missing enchant formula%s.", #searchTerms, #searchTerms == 1 and "" or "s"))
	return true
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

function EC.SetChatScanningEnabled(enabled, statusMessage)
	if not EC.DBChar then
		return false
	end

	enabled = enabled and true or false
	if enabled then
		EC.DBChar.AutoPausedForMaxGroupedCustomers = false
		EC.DBChar.Stop = false
		if EC.EnforceMaxGroupedCustomerLimit and EC.EnforceMaxGroupedCustomerLimit() then
			return false
		end
	else
		EC.DBChar.AutoPausedForMaxGroupedCustomers = false
		EC.DBChar.Stop = true
	end

	if EC.Workbench and EC.Workbench.Refresh then
		EC.Workbench.Refresh()
	end

	print(statusMessage or (enabled and "Started..." or "Paused"))
	return enabled
end

function EC.ToggleChatScanning()
	return EC.SetChatScanningEnabled(not EC.IsChatScanningEnabled())
end

function EC.HandleGroupedCustomerJoin(joinedCount)
	if math.max(0, math.floor(tonumber(joinedCount) or 0)) <= 0 or type(SetRaidTarget) ~= "function" then
		return false
	end

	local ok = pcall(SetRaidTarget, "player", 1)
	return ok and true or false
end

function EC.HandlePlayerFlagsChanged(unitToken)
	if unitToken ~= nil and unitToken ~= "" and unitToken ~= "player" then
		return false
	end

	if not EC.IsChatScanningEnabled() or not IsPlayerAfk() then
		return false
	end

	EC.SetChatScanningEnabled(false, "|cFFFF1C1CEnchanter|r Paused chat scanning because you went AFK.")
	return true
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
		if EC.GetPendingRecipeMaterialCount() > 0 then
			print(string.format(
				"|cFFFFD26AEnchanter|r %d reagent name%s still loading from the item cache; the queue will refresh automatically once they resolve.",
				EC.GetPendingRecipeMaterialCount(),
				EC.GetPendingRecipeMaterialCount() == 1 and "" or "s"
			))
		end
		return true
	end
	print("|cFFFF1C1CEnchanter|r Scan found no supported enchanting recipes. Clear profession filters or search text, then try again.")
	return false
end

function EC.RunRecipeScan()
	return DoScan() and not EC.NeedsRecipeScan()
end

function EC.OpenConfigPanel(panelID)
	panelID = math.max(1, math.floor(tonumber(panelID) or 1))

	if EC.OptionsBuilder and EC.OptionsBuilder.OpenCategoryPanel then
		EC.OptionsBuilder.OpenCategoryPanel(panelID)
		return true
	end

	if EC.Options and EC.Options.Open then
		EC.Options.Open(panelID)
		return true
	end

	return false
end

function EC.DeactivateForNonEnchanter()
	EC.Initalized = false
	EC.DormantForNonEnchanter = true
	EC.PlayerList = {}
	EC.LfRecipeList = {}
	EC.LfRequestedRecipeCounts = {}
	EC.PendingInvites = {}
	if EC.Workbench and EC.Workbench.Hide then
		EC.Workbench.Hide()
	end
	if EC.Simulation and EC.Simulation.Running and EC.StopSimulation then
		EC.StopSimulation()
	end
	return false
end

function EC.Init()
	EnsureSavedVariables()
	if EC.Initalized then
		return true
	end
	if not EC.IsPlayerEnchanter() then
		return EC.DeactivateForNonEnchanter()
	end

	EC.DormantForNonEnchanter = false
	if RegisterActiveEvents then
		RegisterActiveEvents()
	end
	InstallMailboxDisenchantHooks()
	RemoveAuctionHouseDisenchantOrders()

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
			EC.OpenConfigPanel(1)
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
	return true
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

local function MessageHasRequestPrefix(parsedMessage)
	for _, pattern in ipairs(EC.PrefixTagsCompiled) do
		if string.find(parsedMessage, pattern) then
			return true
		end
	end

	return false
end

local function IsGenericEnchanterRequest(parsedMessage)
	local normalizedMessage = NormalizePhrase(parsedMessage)
	return normalizedMessage ~= ""
		and EC.EnchanterTagsNormalized
		and EC.EnchanterTagsNormalized[normalizedMessage] == true
end

function EC.ParseMessage(msg, name, options)
	local allowMissingPrefix = type(options) == "table" and options.AllowMissingPrefix == true
	local hasRequestPrefix

	if EC.Initalized == false or not name or name == "" or not msg or msg == "" or (not allowMissingPrefix and string.len(msg) < 4) or EC.DBChar.Stop == true then
		return
	end

	if EC.IsBanned(name) then
		return
	end

	local parsedMessage = msg:lower()
	hasRequestPrefix = MessageHasRequestPrefix(parsedMessage)
	if not hasRequestPrefix and not allowMissingPrefix then
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

	if EC.DB.WhisperLfRequests and EC.PlayerList[name] == nil and not EC.IsWhisperListenMode(name) then
		if IsGenericEnchanterRequest(parsedMessage) then
			EC.SetWhisperListenMode(name, true)
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
		end
	end
end

local function IsAddonActive()
	return EC.Initalized == true
end

local function Event_TRADE_SHOW()
	if not IsAddonActive() then
		return
	end
	if EC.Workbench and EC.Workbench.BeginTrade then
		EC.Workbench.BeginTrade(EC.Workbench.GetTradePartnerName and EC.Workbench.GetTradePartnerName() or nil)
	end
end

local function Event_TRADE_STATE_CHANGED()
	if not IsAddonActive() then
		return
	end
	if EC.Workbench and EC.Workbench.SyncActiveTrade then
		EC.Workbench.SyncActiveTrade()
	end
end

local function Event_TRADE_ACCEPT_UPDATE(playerAccepted, targetAccepted)
	if not IsAddonActive() then
		return
	end
	if EC.Workbench and EC.Workbench.SetTradeAcceptState then
		EC.Workbench.SetTradeAcceptState(playerAccepted, targetAccepted)
	end
	if EC.Workbench and EC.Workbench.SyncActiveTrade then
		EC.Workbench.SyncActiveTrade()
	end
end

local function Event_TRADE_CLOSED()
	if not IsAddonActive() then
		return
	end
	if EC.Workbench and EC.Workbench.FinishTrade then
		EC.Workbench.FinishTrade(0)
	end
end

local function Event_GROUP_ROSTER_UPDATE()
	if not IsAddonActive() then
		return
	end
	if EC.Workbench and EC.Workbench.SyncGroupedOrders then
		EC.Workbench.SyncGroupedOrders()
	elseif EC.Workbench and EC.Workbench.Refresh then
		EC.Workbench.Refresh()
	end
	if EC.EnforceMaxGroupedCustomerLimit then
		EC.EnforceMaxGroupedCustomerLimit()
	end
end

local function Event_PLAYER_FLAGS_CHANGED(unitToken)
	if not IsAddonActive() then
		return
	end
	EC.HandlePlayerFlagsChanged(unitToken)
end

local function Event_MAIL_SHOW()
	if not IsAddonActive() then
		return
	end
	local runtime = GetMailboxDisenchantRuntime()
	runtime.PendingReturnMailOrderId = nil
	EC.SyncDisenchantInventoryTracking()
end

local function Event_MAIL_CLOSED()
	if not IsAddonActive() then
		return
	end
	local runtime = GetMailboxDisenchantRuntime()
	runtime.PendingLoots = {}
	runtime.PendingDisenchant = nil
	runtime.PendingReturnMailOrderId = nil
end

local function Event_MAIL_SUCCESS()
	if not IsAddonActive() then
		return
	end
	if EC.HandlePendingMailboxLootSuccess and EC.HandlePendingMailboxLootSuccess() then
		return
	end
	if EC.HandleDisenchantReturnMailSent then
		EC.HandleDisenchantReturnMailSent()
	end
end

local function Event_MAIL_FAILED()
	if not IsAddonActive() then
		return
	end
	local runtime = GetMailboxDisenchantRuntime()
	if type(runtime.PendingLoots) == "table" and #runtime.PendingLoots > 0 then
		table.remove(runtime.PendingLoots, 1)
	end
end

local function Event_BAG_UPDATE_DELAYED()
	if not IsAddonActive() then
		return
	end
	if EC.SyncDisenchantInventoryTracking then
		EC.SyncDisenchantInventoryTracking()
	end
end

local function Event_ITEM_UNLOCKED()
	if not IsAddonActive() then
		return
	end
	if EC.SyncDisenchantInventoryTracking then
		EC.SyncDisenchantInventoryTracking()
	end
end

EC.HandleCurrentSpellCastChanged = function()
	if not IsAddonActive() then
		return
	end
	EC.CaptureRecentMailboxItemTargeting()
end

local function Event_UI_CONTEXT_REFRESH()
	if not IsAddonActive() then
		return
	end
	if EC.Workbench and EC.Workbench.Refresh then
		EC.Workbench.Refresh()
	end
end

local function Event_ITEM_DATA_RECEIVED(itemId, success)
	if not IsAddonActive() then
		return
	end
	itemId = tonumber(itemId)
	if itemId and itemId > 0 then
		itemId = math.floor(itemId)
	end

	if not itemId then
		return
	end

	if not success and EC.PendingMaterialItemLoads then
		EC.PendingMaterialItemLoads[itemId] = nil
		return
	end

	if RefreshStoredRecipeMaterials(itemId) and EC.Workbench and EC.Workbench.Refresh then
		EC.Workbench.Refresh()
	end
	if EC.SyncDisenchantInventoryTracking then
		EC.SyncDisenchantInventoryTracking()
	end
end

local function Event_CHAT_MSG_CHANNEL(msg, name)
	if not IsAddonActive() then
		return
	end
	EC.ParseMessage(msg, name)
end

local function Event_CHAT_MSG_WHISPER(msg, name)
	if not IsAddonActive() or not EC.IsWhisperListenMode(name) then
		return
	end
	EC.ParseMessage(msg, name, { AllowMissingPrefix = true })
end

local function Event_CHAT_MSG_SYSTEM(msg)
	if not IsAddonActive() then
		return
	end
	if msg == ERR_TRADE_COMPLETE and EC.Workbench and EC.Workbench.MarkTradeCompleted then
		EC.Workbench.MarkTradeCompleted()
	end
	EC.HandleInviteFailureMessage(msg)
end

local function Event_UI_ERROR_MESSAGE(arg1, arg2, arg3)
	local message
	if not IsAddonActive() then
		return
	end

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
	if not IsAddonActive() then
		return
	end

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

local function Event_TRADE_REPLACE_ENCHANT()
	if not IsAddonActive() then
		return
	end
	if not (EC.DB and EC.DB.AutoReplaceEnchant) then
		return
	end
	if C_Item and type(C_Item.ReplaceTradeEnchant) == "function" then
		C_Item.ReplaceTradeEnchant()
	elseif type(ReplaceTradeEnchant) == "function" then
		ReplaceTradeEnchant()
	end
	if StaticPopup_Hide then
		StaticPopup_Hide("TRADE_REPLACE_ENCHANT")
	end
end

local function Event_ADDON_LOADED(arg1)
	if arg1 == TOCNAME then
		EC.Init()
	elseif IsAddonActive() and arg1 == "Auctionator" and EC.Workbench and EC.Workbench.Refresh then
		EC.Workbench.Refresh()
	end
end

local function Event_SKILL_LINES_CHANGED()
	if EC.IsPlayerEnchanter() then
		if not IsAddonActive() then
			EC.Init()
		end
	elseif IsAddonActive() then
		EC.DeactivateForNonEnchanter()
	end
end

RegisterActiveEvents = function()
	if activeEventsInstalled then
		return
	end

	activeEventsInstalled = true
	EC.Tool.RegisterEvent("TRADE_REPLACE_ENCHANT", Event_TRADE_REPLACE_ENCHANT)
	EC.Tool.RegisterEvent("MAIL_SHOW", Event_MAIL_SHOW)
	EC.Tool.RegisterEvent("MAIL_CLOSED", Event_MAIL_CLOSED)
	EC.Tool.RegisterEvent("MAIL_SUCCESS", Event_MAIL_SUCCESS)
	EC.Tool.RegisterEvent("MAIL_FAILED", Event_MAIL_FAILED)
	EC.Tool.RegisterEvent("BAG_UPDATE_DELAYED", Event_BAG_UPDATE_DELAYED)
	EC.Tool.RegisterEvent("ITEM_UNLOCKED", Event_ITEM_UNLOCKED)
	EC.Tool.RegisterEvent("CURRENT_SPELL_CAST_CHANGED", EC.HandleCurrentSpellCastChanged)
	EC.Tool.RegisterEvent("CHAT_MSG_CHANNEL", Event_CHAT_MSG_CHANNEL)
	EC.Tool.RegisterEvent("CHAT_MSG_SAY", Event_CHAT_MSG_CHANNEL)
	EC.Tool.RegisterEvent("CHAT_MSG_YELL", Event_CHAT_MSG_CHANNEL)
	EC.Tool.RegisterEvent("CHAT_MSG_GUILD", Event_CHAT_MSG_CHANNEL)
	EC.Tool.RegisterEvent("CHAT_MSG_OFFICER", Event_CHAT_MSG_CHANNEL)
	EC.Tool.RegisterEvent("CHAT_MSG_WHISPER", Event_CHAT_MSG_WHISPER)
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
	EC.Tool.RegisterEvent("GROUP_ROSTER_UPDATE", Event_GROUP_ROSTER_UPDATE)
	EC.Tool.RegisterEvent("PLAYER_FLAGS_CHANGED", Event_PLAYER_FLAGS_CHANGED)
	EC.Tool.RegisterEvent("AUCTION_HOUSE_SHOW", Event_UI_CONTEXT_REFRESH)
	EC.Tool.RegisterEvent("AUCTION_HOUSE_CLOSED", Event_UI_CONTEXT_REFRESH)
	EC.Tool.RegisterEvent("GET_ITEM_INFO_RECEIVED", Event_ITEM_DATA_RECEIVED)
	EC.Tool.RegisterEvent("ITEM_DATA_LOAD_RESULT", Event_ITEM_DATA_RECEIVED)
	EC.Tool.RegisterEvent("TRADE_SKILL_SHOW", Event_UI_CONTEXT_REFRESH)
	EC.Tool.RegisterEvent("TRADE_SKILL_CLOSE", Event_UI_CONTEXT_REFRESH)
	EC.Tool.RegisterEvent("CRAFT_SHOW", Event_UI_CONTEXT_REFRESH)
	EC.Tool.RegisterEvent("CRAFT_CLOSE", Event_UI_CONTEXT_REFRESH)
end

function EC.OnLoad()
	EC.Tool.RegisterEvent("ADDON_LOADED", Event_ADDON_LOADED)
	EC.Tool.RegisterEvent("SKILL_LINES_CHANGED", Event_SKILL_LINES_CHANGED)
end
