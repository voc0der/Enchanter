local TOCNAME, EC = ...

if not EC.Options then
	EC.Options = {}
end

local function Combine(values)
	return EC.Tool.Combine(values or {}, ",")
end

local function SplitCSV(value)
	if not value or value == "" then
		return {}
	end
	return EC.Tool.Split(value:lower(), ",")
end

function EC.UpdateTags()
	for recipeName in pairs(EC.DBChar.RecipeList or {}) do
		local customText = EC.DB.Custom[recipeName]
		if customText ~= nil and customText ~= "" then
			EC.DBChar.RecipeList[recipeName] = SplitCSV(customText)
		end
	end
end

function EC.DefaultCustomTags()
	for recipeName, tags in pairs(EC.DefaultRecipeTags["enGB"]) do
		EC.DB.Custom[recipeName] = Combine(tags)
	end
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
	EC.DB.InviteTimeDelay = 0
	EC.DB.WhisperTimeDelay = 0
	EC.DB.GroupedFollowUpDelay = 1
	EC.DB.MsgPrefix = EC.DefaultMsg
	EC.DB.LfWhisperMsg = EC.DefaultLfWhisperMsg
	EC.DB.GroupedFollowUpMsg = EC.DefaultGroupedFollowUpMsg
	EC.DB.Custom.BlackList = ""
	EC.DB.Custom.SearchPrefix = Combine(EC.DefaultPrefixTags)
	EC.DB.Custom.GenericPrefix = Combine(EC.DefaultEnchanterTags)
	EC.DefaultCustomTags()
end

function EC.OptionsUpdate()
	EC.DB.Custom.BlackList = EC.DB.Custom.BlackList or ""
	EC.DB.Custom.SearchPrefix = EC.DB.Custom.SearchPrefix or Combine(EC.DefaultPrefixTags)
	EC.DB.Custom.GenericPrefix = EC.DB.Custom.GenericPrefix or Combine(EC.DefaultEnchanterTags)

	if EC.DB.WarnIncompleteOrder == nil then
		EC.DB.WarnIncompleteOrder = true
	end
	if EC.DB.InviteIncompleteOrder == nil then
		EC.DB.InviteIncompleteOrder = true
	end
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
end

function EC.Options.DoOk()
	EC.OptionsUpdate()
end

function EC.Options.DoCancel()
	EC.OptionsUpdate()
end

function EC.Options.DoDefault()
	EC.Default()
	if EC.OptionsBuilder and EC.OptionsBuilder.DefaultRegisteredVariables then
		EC.OptionsBuilder.DefaultRegisteredVariables()
	end
	EC.OptionsUpdate()
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
	EC.OptionsBuilder.Indent(-10)
	EC.OptionsBuilder.AddSpacerToPanel()

	MakeSavedEditBox(EC.DB, "WhisperTimeDelay", 0, "Whisper Delay (seconds)", 60, nil, true)
	MakeSavedEditBox(EC.DB, "InviteTimeDelay", 0, "Invite Delay (seconds)", 60, nil, true)
	MakeSavedEditBox(EC.DB, "GroupedFollowUpDelay", 1, "Grouped follow-up delay (seconds)", 60, nil, true)

	EC.OptionsBuilder.AddHeaderToCurrentPanel("Search Patterns")
	EC.OptionsBuilder.Indent(10)
	EC.OptionsBuilder.AddTextToCurrentPanel('Use "," as the separator with no spaces after it when adding custom patterns.', 650)
	EC.OptionsBuilder.AddSpacerToPanel()

	MakeSavedEditBox(EC.DB, "MsgPrefix", EC.DefaultMsg, "Message Prefix", 445, 200, false)
	MakeSavedEditBox(EC.DB, "LfWhisperMsg", EC.DefaultLfWhisperMsg, "Generic request whisper", 445, 200, false)
	MakeSavedEditBox(EC.DB, "GroupedFollowUpMsg", EC.DefaultGroupedFollowUpMsg, "Already grouped follow-up", 445, 200, false)
	EC.OptionsBuilder.AddSpacerToPanel()

	MakeSavedEditBox(EC.DB.Custom, "SearchPrefix", Combine(EC.PrefixTags), "Prefix to search for", 445, 200, false)
	MakeSavedEditBox(EC.DB.Custom, "GenericPrefix", Combine(EC.EnchanterTags), "Generic request match phrases", 445, 200, false)
	MakeSavedEditBox(EC.DB.Custom, "BlackList", "", "Blacklist", 445, 200, false)
	EC.OptionsBuilder.AddSpacerToPanel()

	for recipeName, tags in pairs(EC.RecipeTags["enGB"]) do
		MakeSavedEditBox(EC.DB.Custom, recipeName, Combine(tags), recipeName, 445, 200, false)
	end

	EC.OptionsUpdate()
end
