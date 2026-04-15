local TOCNAME, EC = ...

if not EC.Options then
	EC.Options = {}
end

local RECIPE_BLACKLIST_KEY = "RecipeBlackList"

local function TrimText(value)
	if value == nil then
		return ""
	end
	return tostring(value):gsub("^%s+", ""):gsub("%s+$", "")
end

local function Combine(values)
	return EC.Tool.Combine(values or {}, ",")
end

local function SplitCSV(value)
	local out = {}
	if not value or value == "" then
		return out
	end

	local tokens
	if EC.Tool and EC.Tool.Split then
		tokens = EC.Tool.Split(tostring(value):lower(), ",")
	end

	if not tokens then
		tokens = {}
		for token in string.gmatch(tostring(value):lower(), "([^,]+)") do
			tokens[#tokens + 1] = token
		end
	end

	for _, token in ipairs(tokens) do
		local cleanedToken = TrimText(token)
		if cleanedToken ~= "" then
			out[#out + 1] = cleanedToken
		end
	end

	return out
end

local function NormalizeCSVText(value)
	return Combine(SplitCSV(value))
end

local function GetDefaultRecipeTags(recipeName)
	local defaultLocaleTags = EC.DefaultRecipeTags and EC.DefaultRecipeTags["enGB"]
	local generatedLocaleTags = EC.GeneratedRecipeTags and EC.GeneratedRecipeTags["enGB"]
	local scannedRecipeTags = EC.DBChar and EC.DBChar.RecipeList

	if defaultLocaleTags and type(defaultLocaleTags[recipeName]) == "table" and #defaultLocaleTags[recipeName] > 0 then
		return defaultLocaleTags[recipeName]
	end

	if generatedLocaleTags and type(generatedLocaleTags[recipeName]) == "table" and #generatedLocaleTags[recipeName] > 0 then
		return generatedLocaleTags[recipeName]
	end

	if scannedRecipeTags and type(scannedRecipeTags[recipeName]) == "table" and #scannedRecipeTags[recipeName] > 0 then
		return scannedRecipeTags[recipeName]
	end

	return {}
end

local function GetRecipeBlacklistStore()
	EC.DB.Custom[RECIPE_BLACKLIST_KEY] = EC.DB.Custom[RECIPE_BLACKLIST_KEY] or {}
	return EC.DB.Custom[RECIPE_BLACKLIST_KEY]
end

local function GetRecipeSearchText(recipeName)
	local customText = EC.DB and EC.DB.Custom and EC.DB.Custom[recipeName]
	if type(customText) == "string" and customText ~= "" then
		return customText
	end
	return Combine(GetDefaultRecipeTags(recipeName))
end

local function SetRecipeSearchText(recipeName, value)
	value = NormalizeCSVText(value)
	if value == "" then
		value = Combine(GetDefaultRecipeTags(recipeName))
	end
	EC.DB.Custom[recipeName] = value
end

local function GetRecipeBlacklistText(recipeName)
	local blacklistStore = EC.DB and EC.DB.Custom and EC.DB.Custom[RECIPE_BLACKLIST_KEY]
	local customText = blacklistStore and blacklistStore[recipeName]
	if type(customText) == "string" and customText ~= "" then
		return customText
	end
	return ""
end

local function SetRecipeBlacklistText(recipeName, value)
	value = NormalizeCSVText(value)
	local blacklistStore = GetRecipeBlacklistStore()
	if value == "" then
		blacklistStore[recipeName] = nil
	else
		blacklistStore[recipeName] = value
	end
end

local function GetSortedRecipeNames()
	local out = {}
	local seen = {}

	local function AddRecipeNames(recipeMap)
		for recipeName in pairs(recipeMap or {}) do
			if not seen[recipeName] then
				seen[recipeName] = true
				out[#out + 1] = recipeName
			end
		end
	end

	AddRecipeNames(EC.RecipeTags and EC.RecipeTags["enGB"] or {})
	AddRecipeNames(EC.GeneratedRecipeTags and EC.GeneratedRecipeTags["enGB"] or {})
	AddRecipeNames(EC.DBChar and EC.DBChar.RecipeList or {})

	table.sort(out)
	return out
end

local function GetRecipeFilterText(ui)
	if not ui or not ui.FilterBox or not ui.FilterBox.GetText then
		return ""
	end
	return TrimText(ui.FilterBox:GetText()):lower()
end

local function RecipeMatchesFilter(recipeName, filterText)
	if filterText == nil or filterText == "" then
		return true
	end

	local haystacks = {
		string.lower(recipeName or ""),
		string.lower(GetRecipeSearchText(recipeName) or ""),
		string.lower(GetRecipeBlacklistText(recipeName) or ""),
	}

	for _, haystack in ipairs(haystacks) do
		if string.find(haystack, filterText, 1, true) then
			return true
		end
	end

	return false
end

local function CreateBackdropFrame(parent, name)
	local template = BackdropTemplateMixin and "BackdropTemplate" or nil
	local frame = CreateFrame("Frame", name, parent, template)
	if frame.SetBackdrop then
		frame:SetBackdrop({
			bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
			edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
			tile = true,
			tileSize = 16,
			edgeSize = 12,
			insets = { left = 3, right = 3, top = 3, bottom = 3 },
		})
		frame:SetBackdropColor(0.04, 0.04, 0.04, 0.82)
		frame:SetBackdropBorderColor(0.35, 0.35, 0.35, 0.95)
	end
	return frame
end

local function CreateTextLabel(parent, text)
	local label = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	label:SetText(text)
	label:SetJustifyH("LEFT")
	label:SetJustifyV("TOP")
	return label
end

local RefreshRecipeCustomizationUI
local RefreshBanlistUI

local function CreateCSVEditBox(parent, name, sampleText, getter, setter)
	local editBox = CreateFrame("EditBox", name, parent, "InputBoxInstructionsTemplate")
	editBox:SetAutoFocus(false)
	editBox:SetFontObject("ChatFontNormal")
	editBox:SetHeight(20)
	if editBox.SetTextInsets then
		editBox:SetTextInsets(6, 6, 0, 0)
	end
	if editBox.Instructions then
		editBox.Instructions:SetFontObject("ChatFontNormal")
		editBox.Instructions:SetText(sampleText or "")
	end

	local function syncFromSavedValue()
		local value = getter()
		if editBox:GetText() ~= value then
			editBox:SetText(value)
			if editBox.SetCursorPosition then
				editBox:SetCursorPosition(0)
			end
		end
	end

	local function saveValue()
		setter(editBox:GetText())
		syncFromSavedValue()
		EC.OptionsUpdate()
		RefreshRecipeCustomizationUI(false)
	end

	editBox.SyncFromSavedValue = syncFromSavedValue
	editBox:SetScript("OnEnterPressed", function(self)
		self._savedOnEnter = true
		saveValue()
		self:ClearFocus()
	end)
	editBox:SetScript("OnEscapePressed", function(self)
		syncFromSavedValue()
		self:ClearFocus()
	end)
	editBox:SetScript("OnEditFocusLost", function(self)
		if self._savedOnEnter then
			self._savedOnEnter = nil
			return
		end
		saveValue()
	end)

	syncFromSavedValue()
	return editBox
end

RefreshRecipeCustomizationUI = function(syncValues)
	local ui = EC.Options.RecipeCustomizationUI
	if not ui or not ui.Panel then
		return
	end

	local filterText = GetRecipeFilterText(ui)
	local visibleCount = 0
	local yOffset = -6
	local rowSpacing = 12
	local minimumWidth = 560
	local scrollWidth = ui.ScrollFrame and ui.ScrollFrame.GetWidth and ui.ScrollFrame:GetWidth() or minimumWidth
	local contentWidth = math.max(minimumWidth, scrollWidth - 30)

	ui.ScrollChild:SetWidth(contentWidth)

	for _, row in ipairs(ui.Rows or {}) do
		if syncValues then
			row.SearchEdit:SyncFromSavedValue()
			row.BlacklistEdit:SyncFromSavedValue()
		end

		local shouldShow = RecipeMatchesFilter(row.RecipeName, filterText)
		row:SetShown(shouldShow)
		if shouldShow then
			visibleCount = visibleCount + 1
			row:ClearAllPoints()
			row:SetPoint("TOPLEFT", ui.ScrollChild, "TOPLEFT", 10, yOffset)
			row:SetPoint("TOPRIGHT", ui.ScrollChild, "TOPRIGHT", -10, yOffset)
			yOffset = yOffset - row:GetHeight() - rowSpacing
		end
	end

	ui.ScrollChild:SetHeight(math.max(1, -yOffset + 10))
	if ui.StatusText then
		ui.StatusText:SetText(string.format("Showing %d of %d recipes", visibleCount, #ui.Rows))
	end

	if ui.ScrollFrame and ui.ScrollFrame.GetVerticalScroll and ui.ScrollFrame.SetVerticalScroll then
		local maxOffset = math.max(0, ui.ScrollChild:GetHeight() - ui.ScrollFrame:GetHeight())
		if ui.ScrollFrame:GetVerticalScroll() > maxOffset then
			ui.ScrollFrame:SetVerticalScroll(maxOffset)
		end
	end
end

local function BuildRecipeCustomizationPanel(panel)
	local ui = {
		Panel = panel,
		Rows = {},
	}
	EC.Options.RecipeCustomizationUI = ui

	local intro = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	intro:SetPoint("TOPLEFT", 10, -44)
	intro:SetPoint("TOPRIGHT", -10, -44)
	intro:SetJustifyH("LEFT")
	intro:SetJustifyV("TOP")
	intro:SetText('Search by recipe name, search phrase, or blacklist phrase. Clearing a search field restores the defaults; recipe blacklist entries add to the built-in blacklist defaults for that recipe. Use "," to separate phrases.')

	local filterLabel = CreateTextLabel(panel, "Filter")
	filterLabel:SetPoint("TOPLEFT", intro, "BOTTOMLEFT", 0, -18)
	filterLabel:SetWidth(80)
	ui.FilterLabel = filterLabel

	local filterBox = CreateFrame("EditBox", TOCNAME .. "RecipeFilterBox", panel, "InputBoxInstructionsTemplate")
	filterBox:SetPoint("LEFT", filterLabel, "RIGHT", 8, 0)
	filterBox:SetPoint("RIGHT", panel, "RIGHT", -80, 0)
	filterBox:SetHeight(20)
	filterBox:SetAutoFocus(false)
	filterBox:SetFontObject("ChatFontNormal")
	if filterBox.SetTextInsets then
		filterBox:SetTextInsets(6, 6, 0, 0)
	end
	if filterBox.Instructions then
		filterBox.Instructions:SetFontObject("ChatFontNormal")
		filterBox.Instructions:SetText("major agility, glove, weapon, spellpower...")
	end
	filterBox:SetScript("OnTextChanged", function()
		if ui.ScrollFrame and ui.ScrollFrame.SetVerticalScroll then
			ui.ScrollFrame:SetVerticalScroll(0)
		end
		RefreshRecipeCustomizationUI(false)
	end)
	filterBox:SetScript("OnEscapePressed", function(self)
		self:SetText("")
		self:ClearFocus()
	end)
	ui.FilterBox = filterBox

	local clearButton = CreateFrame("Button", TOCNAME .. "RecipeFilterClearButton", panel, "UIPanelButtonTemplate")
	clearButton:SetPoint("LEFT", filterBox, "RIGHT", 8, 0)
	clearButton:SetSize(52, 22)
	clearButton:SetText("Clear")
	clearButton:SetScript("OnClick", function()
		filterBox:SetText("")
		filterBox:ClearFocus()
		RefreshRecipeCustomizationUI(false)
	end)
	ui.ClearButton = clearButton

	local statusText = CreateTextLabel(panel, "")
	statusText:SetPoint("TOPLEFT", filterLabel, "BOTTOMLEFT", 0, -12)
	statusText:SetWidth(260)
	ui.StatusText = statusText

	local listFrame = CreateBackdropFrame(panel, TOCNAME .. "RecipeCustomizationList")
	listFrame:SetPoint("TOPLEFT", statusText, "BOTTOMLEFT", 0, -10)
	listFrame:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -8, -132)
	listFrame:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 8, 10)
	ui.ListFrame = listFrame

	local scrollFrame = CreateFrame("ScrollFrame", TOCNAME .. "RecipeCustomizationScrollFrame", listFrame, "UIPanelScrollFrameTemplate")
	scrollFrame:SetPoint("TOPLEFT", listFrame, "TOPLEFT", 6, -6)
	scrollFrame:SetPoint("BOTTOMRIGHT", listFrame, "BOTTOMRIGHT", -28, 6)
	ui.ScrollFrame = scrollFrame

	local scrollChild = CreateFrame("Frame", TOCNAME .. "RecipeCustomizationScrollChild", scrollFrame)
	scrollChild:SetSize(1, 1)
	scrollFrame:SetScrollChild(scrollChild)
	ui.ScrollChild = scrollChild

	for _, recipeName in ipairs(GetSortedRecipeNames()) do
		local row = CreateBackdropFrame(scrollChild, nil)
		row.RecipeName = recipeName
		row:SetHeight(82)

		local title = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		title:SetPoint("TOPLEFT", row, "TOPLEFT", 12, -10)
		title:SetPoint("TOPRIGHT", row, "TOPRIGHT", -12, -10)
		title:SetJustifyH("LEFT")
		title:SetText(recipeName)
		row.Title = title

		local searchLabel = CreateTextLabel(row, "Search")
		searchLabel:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -10)
		searchLabel:SetWidth(72)
		row.SearchLabel = searchLabel

		local searchEdit = CreateCSVEditBox(
			row,
			nil,
			"match phrases",
			function()
				return GetRecipeSearchText(recipeName)
			end,
			function(value)
				SetRecipeSearchText(recipeName, value)
			end
		)
		searchEdit:SetPoint("LEFT", searchLabel, "RIGHT", 8, 0)
		searchEdit:SetPoint("RIGHT", row, "RIGHT", -12, 0)
		row.SearchEdit = searchEdit

		local blacklistLabel = CreateTextLabel(row, "Blacklist")
		blacklistLabel:SetPoint("TOPLEFT", searchLabel, "BOTTOMLEFT", 0, -14)
		blacklistLabel:SetWidth(72)
		row.BlacklistLabel = blacklistLabel

		local blacklistEdit = CreateCSVEditBox(
			row,
			nil,
			"phrases that should block this recipe",
			function()
				return GetRecipeBlacklistText(recipeName)
			end,
			function(value)
				SetRecipeBlacklistText(recipeName, value)
			end
		)
		blacklistEdit:SetPoint("LEFT", blacklistLabel, "RIGHT", 8, 0)
		blacklistEdit:SetPoint("RIGHT", row, "RIGHT", -12, 0)
		row.BlacklistEdit = blacklistEdit

		ui.Rows[#ui.Rows + 1] = row
	end

	panel:HookScript("OnShow", function()
		RefreshRecipeCustomizationUI(true)
	end)
	panel:HookScript("OnSizeChanged", function()
		RefreshRecipeCustomizationUI(false)
	end)

	RefreshRecipeCustomizationUI(true)
end

RefreshBanlistUI = function()
	local ui = EC.Options.BanlistUI
	if not ui or not ui.Panel then
		return
	end

	EC.DB.BanList = EC.DB.BanList or {}

	for _, row in ipairs(ui.Rows or {}) do
		row:Hide()
	end
	ui.Rows = {}

	local bannedNames = {}
	for name in pairs(EC.DB.BanList) do
		bannedNames[#bannedNames + 1] = name
	end
	table.sort(bannedNames)

	local yOffset = -6
	local rowHeight = 28

	for _, name in ipairs(bannedNames) do
		local row = CreateFrame("Frame", nil, ui.ScrollChild)
		row:SetHeight(rowHeight)
		row:SetPoint("TOPLEFT", ui.ScrollChild, "TOPLEFT", 6, yOffset)
		row:SetPoint("TOPRIGHT", ui.ScrollChild, "TOPRIGHT", -6, yOffset)

		local nameLabel = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		nameLabel:SetPoint("LEFT", row, "LEFT", 8, 0)
		nameLabel:SetPoint("RIGHT", row, "RIGHT", -70, 0)
		nameLabel:SetJustifyH("LEFT")
		nameLabel:SetText(name)

		local removeButton = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
		removeButton:SetSize(60, 20)
		removeButton:SetPoint("RIGHT", row, "RIGHT", -4, 0)
		removeButton:SetText("Unban")
		removeButton.BannedName = name
		removeButton:SetScript("OnClick", function(self)
			if EC.UnbanPlayer then
				EC.UnbanPlayer(self.BannedName)
			end
			RefreshBanlistUI()
		end)

		ui.Rows[#ui.Rows + 1] = row
		yOffset = yOffset - rowHeight - 4
	end

	if #bannedNames == 0 then
		local emptyLabel = CreateFrame("Frame", nil, ui.ScrollChild)
		emptyLabel:SetHeight(rowHeight)
		emptyLabel:SetPoint("TOPLEFT", ui.ScrollChild, "TOPLEFT", 6, yOffset)
		emptyLabel:SetPoint("TOPRIGHT", ui.ScrollChild, "TOPRIGHT", -6, yOffset)
		local emptyText = emptyLabel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
		emptyText:SetPoint("LEFT", emptyLabel, "LEFT", 8, 0)
		emptyText:SetText("No banned players.")
		ui.Rows[#ui.Rows + 1] = emptyLabel
		yOffset = yOffset - rowHeight - 4
	end

	ui.ScrollChild:SetHeight(math.max(1, -yOffset + 10))
	if ui.CountText then
		ui.CountText:SetText(string.format("%d banned player%s", #bannedNames, #bannedNames == 1 and "" or "s"))
	end
end

local function BuildBanlistPanel(panel)
	local ui = {
		Panel = panel,
		Rows = {},
	}
	EC.Options.BanlistUI = ui

	local intro = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	intro:SetPoint("TOPLEFT", 10, -44)
	intro:SetPoint("TOPRIGHT", -10, -44)
	intro:SetJustifyH("LEFT")
	intro:SetJustifyV("TOP")
	intro:SetText("Banned players are silently ignored — no invites, no whispers. Right-click any player name in-game and choose \"Ban from Enchanter\" to add them.")

	local addLabel = CreateTextLabel(panel, "Ban player")
	addLabel:SetPoint("TOPLEFT", intro, "BOTTOMLEFT", 0, -18)
	addLabel:SetWidth(80)

	local addBox = CreateFrame("EditBox", TOCNAME .. "BanlistAddBox", panel, "InputBoxInstructionsTemplate")
	addBox:SetPoint("LEFT", addLabel, "RIGHT", 8, 0)
	addBox:SetPoint("RIGHT", panel, "RIGHT", -80, 0)
	addBox:SetHeight(20)
	addBox:SetAutoFocus(false)
	addBox:SetFontObject("ChatFontNormal")
	if addBox.SetTextInsets then
		addBox:SetTextInsets(6, 6, 0, 0)
	end
	if addBox.Instructions then
		addBox.Instructions:SetFontObject("ChatFontNormal")
		addBox.Instructions:SetText("player name...")
	end
	local function commitAdd()
		local name = TrimText(addBox:GetText())
		if name ~= "" and EC.BanPlayer then
			EC.BanPlayer(name)
			addBox:SetText("")
			RefreshBanlistUI()
		end
		addBox:ClearFocus()
	end
	addBox:SetScript("OnEnterPressed", commitAdd)
	addBox:SetScript("OnEscapePressed", function(self)
		self:SetText("")
		self:ClearFocus()
	end)

	local addButton = CreateFrame("Button", TOCNAME .. "BanlistAddButton", panel, "UIPanelButtonTemplate")
	addButton:SetSize(52, 22)
	addButton:SetPoint("LEFT", addBox, "RIGHT", 8, 0)
	addButton:SetText("Ban")
	addButton:SetScript("OnClick", commitAdd)

	local countText = CreateTextLabel(panel, "")
	countText:SetPoint("TOPLEFT", addLabel, "BOTTOMLEFT", 0, -16)
	countText:SetWidth(260)
	ui.CountText = countText

	local listFrame = CreateBackdropFrame(panel, TOCNAME .. "BanlistFrame")
	listFrame:SetPoint("TOPLEFT", countText, "BOTTOMLEFT", 0, -10)
	listFrame:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -8, -160)
	listFrame:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 8, 10)
	listFrame:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -8, 10)

	local scrollFrame = CreateFrame("ScrollFrame", TOCNAME .. "BanlistScrollFrame", listFrame, "UIPanelScrollFrameTemplate")
	scrollFrame:SetPoint("TOPLEFT", listFrame, "TOPLEFT", 6, -6)
	scrollFrame:SetPoint("BOTTOMRIGHT", listFrame, "BOTTOMRIGHT", -28, 6)
	ui.ScrollFrame = scrollFrame

	local scrollChild = CreateFrame("Frame", TOCNAME .. "BanlistScrollChild", scrollFrame)
	scrollChild:SetSize(1, 1)
	scrollFrame:SetScrollChild(scrollChild)
	ui.ScrollChild = scrollChild

	panel:HookScript("OnShow", function()
		RefreshBanlistUI()
	end)

	RefreshBanlistUI()
end

function EC.UpdateTags()
	for recipeName in pairs(EC.DBChar.RecipeList or {}) do
		local customText = GetRecipeSearchText(recipeName)
		if customText ~= "" then
			EC.DBChar.RecipeList[recipeName] = SplitCSV(customText)
		end
	end
end

function EC.DefaultCustomTags()
	for recipeName, tags in pairs(EC.DefaultRecipeTags["enGB"]) do
		EC.DB.Custom[recipeName] = Combine(tags)
	end
	EC.DB.Custom[RECIPE_BLACKLIST_KEY] = {}
end

function EC.Default()
	EC.RecipeTags = EC.DefaultRecipeTags
	EC.PrefixTags = EC.DefaultPrefixTags
	EC.EnchanterTags = EC.DefaultEnchanterTags

	EC.DB.AutoInvite = true
	EC.DB.WarnIncompleteOrder = true
	EC.DB.InviteIncompleteOrder = true
	EC.DB.NetherRecipes = false
	EC.DB.WhisperLfRequests = false
	EC.DB.GroupedFollowUp = false
	EC.DB.EmoteThankAfterCast = false
	EC.DB.PlaySoundOnPartyJoinInstead = false
	EC.DB.InviteTimeDelay = 0
	EC.DB.WhisperTimeDelay = 0
	EC.DB.GroupedFollowUpDelay = 1
	EC.DB.GroupedQueueExpireSeconds = 0
	EC.DB.DeclinedInviteRemovalSeconds = 0
	EC.DB.MaxGroupedCustomers = 0
	EC.DB.AutoReplaceEnchant = true
	EC.DB.MsgPrefix = EC.DefaultMsg
	EC.DB.LfWhisperMsg = EC.DefaultLfWhisperMsg
	EC.DB.GroupedFollowUpMsg = EC.DefaultGroupedFollowUpMsg
	EC.DB.Custom.BlackList = ""
	EC.DB.Custom.SearchPrefix = Combine(EC.DefaultPrefixTags)
	EC.DB.Custom.GenericPrefix = Combine(EC.DefaultEnchanterTags)
	EC.DB.Custom[RECIPE_BLACKLIST_KEY] = {}
	EC.DB.BanList = {}
	EC.DefaultCustomTags()
end

function EC.OptionsUpdate()
	EC.DB.Custom.BlackList = EC.DB.Custom.BlackList or ""
	EC.DB.Custom.SearchPrefix = EC.DB.Custom.SearchPrefix or Combine(EC.DefaultPrefixTags)
	EC.DB.Custom.GenericPrefix = EC.DB.Custom.GenericPrefix or Combine(EC.DefaultEnchanterTags)
	EC.DB.Custom[RECIPE_BLACKLIST_KEY] = EC.DB.Custom[RECIPE_BLACKLIST_KEY] or {}
	EC.DB.BanList = EC.DB.BanList or {}

	if EC.DB.AutoReplaceEnchant == nil then
		EC.DB.AutoReplaceEnchant = true
	end
	if EC.DB.WarnIncompleteOrder == nil then
		EC.DB.WarnIncompleteOrder = true
	end
	if EC.DB.InviteIncompleteOrder == nil then
		EC.DB.InviteIncompleteOrder = true
	end
	if EC.DB.EmoteThankAfterCast == nil then
		EC.DB.EmoteThankAfterCast = false
	end
	if EC.DB.PlaySoundOnPartyJoinInstead == nil then
		EC.DB.PlaySoundOnPartyJoinInstead = false
	end
	if EC.DB.GroupedQueueExpireSeconds == nil then
		EC.DB.GroupedQueueExpireSeconds = 0
	end
	EC.DB.GroupedQueueExpireSeconds = math.max(0, math.floor(tonumber(EC.DB.GroupedQueueExpireSeconds) or 0))
	if EC.DB.DeclinedInviteRemovalSeconds == nil then
		EC.DB.DeclinedInviteRemovalSeconds = 0
	end
	EC.DB.DeclinedInviteRemovalSeconds = math.max(0, math.floor(tonumber(EC.DB.DeclinedInviteRemovalSeconds) or 0))
	if EC.DB.MaxGroupedCustomers == nil then
		EC.DB.MaxGroupedCustomers = 0
	end
	EC.DB.MaxGroupedCustomers = math.max(0, math.floor(tonumber(EC.DB.MaxGroupedCustomers) or 0))
	if not EC.DB.MsgPrefix or EC.DB.MsgPrefix == "" then
		EC.DB.MsgPrefix = EC.DefaultMsg
	end
	if not EC.DB.LfWhisperMsg or EC.DB.LfWhisperMsg == "" then
		EC.DB.LfWhisperMsg = EC.DefaultLfWhisperMsg
	end
	if not EC.DB.GroupedFollowUpMsg or EC.DB.GroupedFollowUpMsg == "" then
		EC.DB.GroupedFollowUpMsg = EC.DefaultGroupedFollowUpMsg
	end

	EC.BlackList = SplitCSV(EC.DB.Custom.BlackList)
	EC.PrefixTags = SplitCSV(EC.DB.Custom.SearchPrefix)
	EC.EnchanterTags = SplitCSV(EC.DB.Custom.GenericPrefix)
	EC.UpdateTags()
	EC.RefreshCompiledData()
	if EC.Workbench and EC.Workbench.SyncGroupedOrders then
		EC.Workbench.SyncGroupedOrders()
	end
	if EC.Initalized and EC.EnforceMaxGroupedCustomerLimit then
		EC.EnforceMaxGroupedCustomerLimit()
	end
end

function EC.Options.DoOk()
	EC.OptionsUpdate()
	RefreshRecipeCustomizationUI(true)
end

function EC.Options.DoCancel()
	EC.OptionsUpdate()
	RefreshRecipeCustomizationUI(true)
end

function EC.Options.DoDefault()
	EC.Default()
	if EC.OptionsBuilder and EC.OptionsBuilder.DefaultRegisteredVariables then
		EC.OptionsBuilder.DefaultRegisteredVariables()
	end
	EC.OptionsUpdate()
	RefreshRecipeCustomizationUI(true)
end

function EC.Options.Open(panelID)
	if EC.OptionsBuilder and EC.OptionsBuilder.OpenCategoryPanel then
		EC.OptionsBuilder.OpenCategoryPanel(panelID or 1)
	end
end

function EC.OptionsInit()
	if not EC.OptionsBuilder then
		return
	end

	EC.OptionsBuilder.Init(
		function()
			EC.Options.DoOk()
		end,
		function()
			EC.Options.DoCancel()
		end,
		function()
			EC.Options.DoDefault()
		end
	)

	EC.OptionsBuilder.SetScale(0.85)

	local function AddSavedCheckBox(db, key, defaultValue, label)
		local checkButton = EC.OptionsBuilder.AddCheckBoxToCurrentPanel(db, key, defaultValue, label)
		if checkButton.OnSavedVarUpdate then
			checkButton:OnSavedVarUpdate(function()
				EC.OptionsUpdate()
			end)
		end
		return checkButton
	end

	local function MakeSavedEditBox(db, key, defaultValue, label, width, labelWidth, numeric)
		local editBox = EC.OptionsBuilder.AddEditBoxToCurrentPanel(db, key, defaultValue, label, width, labelWidth, numeric)
		local originalEnter = editBox:GetScript("OnEnterPressed")
		local originalLost = editBox:GetScript("OnEditFocusLost")

		editBox:SetScript("OnEnterPressed", function(self)
			if originalEnter then
				originalEnter(self)
			else
				self:ClearFocus()
			end
			EC.OptionsUpdate()
		end)

		editBox:SetScript("OnEditFocusLost", function(self)
			if numeric then
				self:SetSavedValue(self:GetNumber())
			else
				self:SetSavedValue(self:GetText())
			end
			if originalLost then
				originalLost(self)
			end
			EC.OptionsUpdate()
		end)

		return editBox
	end

	EC.OptionsBuilder.AddNewCategoryPanel("Enchanter", false, true)

	EC.OptionsBuilder.AddHeaderToCurrentPanel("General Options")
	EC.OptionsBuilder.Indent(10)
	EC.OptionsBuilder.InLine()
	AddSavedCheckBox(EC.DB, "AutoInvite", true, "Auto Invite")
	AddSavedCheckBox(EC.DB, "NetherRecipes", false, "Disable Nether Recipes")
	AddSavedCheckBox(EC.DB, "WhisperLfRequests", false, "Reply to LF Enchanter requests")
	AddSavedCheckBox(EC.DB, "GroupedFollowUp", false, "Follow up if target already grouped")
	EC.OptionsBuilder.EndInLine()
	EC.OptionsBuilder.InLine()
	AddSavedCheckBox(EC.DB, "WarnIncompleteOrder", true, "Warn if Incomplete Order")
	AddSavedCheckBox(EC.DB, "InviteIncompleteOrder", true, "Invite Incomplete Order")
	EC.OptionsBuilder.EndInLine()
	EC.OptionsBuilder.InLine()
	AddSavedCheckBox(EC.DB, "AutoReplaceEnchant", true, "Automatically replace enchants")
	EC.OptionsBuilder.EndInLine()
	EC.OptionsBuilder.InLine()
	AddSavedCheckBox(EC.DB, "EmoteThankAfterCast", false, "Emote /thank after successful cast")
	AddSavedCheckBox(EC.DB, "PlaySoundOnPartyJoinInstead", false, "Play sound on party join instead")
	EC.OptionsBuilder.EndInLine()
	EC.OptionsBuilder.Indent(-10)
	EC.OptionsBuilder.AddSpacerToPanel()

	MakeSavedEditBox(EC.DB, "WhisperTimeDelay", 0, "Whisper Delay (seconds)", 60, nil, true)
	MakeSavedEditBox(EC.DB, "InviteTimeDelay", 0, "Invite Delay (seconds)", 60, nil, true)
	MakeSavedEditBox(EC.DB, "GroupedFollowUpDelay", 1, "Grouped follow-up delay (seconds)", 60, nil, true)
	MakeSavedEditBox(EC.DB, "GroupedQueueExpireSeconds", 0, "Grouped queue expiry (0 disables)", 60, nil, true)
	MakeSavedEditBox(EC.DB, "DeclinedInviteRemovalSeconds", 0, "Party declined removal timer", 60, nil, true)
	MakeSavedEditBox(EC.DB, "MaxGroupedCustomers", 0, "Max customers in group (0 disables)", 60, nil, true)

	EC.OptionsBuilder.AddHeaderToCurrentPanel("Search Patterns")
	EC.OptionsBuilder.Indent(10)
	EC.OptionsBuilder.AddTextToCurrentPanel('Use "," to separate patterns. Global blacklist entries still block the whole message; recipe blacklists now live in the Recipe Customizations subcategory.', 700)
	EC.OptionsBuilder.AddSpacerToPanel()
	EC.OptionsBuilder.AddTextToCurrentPanel('Use " ," between Message Prefix choices to randomize one per whisper. Plain commas inside one phrase stay literal.', 700)

	MakeSavedEditBox(EC.DB, "MsgPrefix", EC.DefaultMsg, "Message Prefix", 445, 200, false)
	MakeSavedEditBox(EC.DB, "LfWhisperMsg", EC.DefaultLfWhisperMsg, "Generic request whisper", 445, 200, false)
	MakeSavedEditBox(EC.DB, "GroupedFollowUpMsg", EC.DefaultGroupedFollowUpMsg, "Already grouped follow-up", 445, 200, false)
	EC.OptionsBuilder.AddSpacerToPanel()

	MakeSavedEditBox(EC.DB.Custom, "SearchPrefix", Combine(EC.PrefixTags), "Prefix to search for", 445, 200, false)
	MakeSavedEditBox(EC.DB.Custom, "GenericPrefix", Combine(EC.EnchanterTags), "Generic request match phrases", 445, 200, false)
	MakeSavedEditBox(EC.DB.Custom, "BlackList", "", "Global blacklist", 445, 200, false)
	EC.OptionsBuilder.AddSpacerToPanel()
	EC.OptionsBuilder.AddTextToCurrentPanel('Per-enchant search phrases and per-enchant blacklists now live under "Recipe Customizations" in this category.', 700)

	local recipePanel = EC.OptionsBuilder.AddNewCategoryPanel("Recipe Customizations", false, false)
	BuildRecipeCustomizationPanel(recipePanel)

	local banlistPanel = EC.OptionsBuilder.AddNewCategoryPanel("Banlist", false, false)
	BuildBanlistPanel(banlistPanel)

	EC.OptionsUpdate()
end
