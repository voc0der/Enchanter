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
	if GetCVarBool and GetCVarBool("timeMgrUseLocalTime") then
		local localHours, localMinutes = GetLocalClockParts()
		if localHours ~= nil and localMinutes ~= nil then
			return FormatClockTime(localHours, localMinutes)
		end
	end

	if GetGameTime then
		local gameHours, gameMinutes = GetGameTime()
		if gameHours ~= nil and gameMinutes ~= nil then
			return FormatClockTime(gameHours, gameMinutes)
		end
	end

	local localHours, localMinutes = GetLocalClockParts()
	if localHours ~= nil and localMinutes ~= nil then
		return FormatClockTime(localHours, localMinutes)
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

local function TrimText(value)
	if not value then
		return ""
	end
	return tostring(value):gsub("^%s+", ""):gsub("%s+$", "")
end

local function CopyRecipeNames(recipeMapOrList)
	local out = {}
	local seen = {}

	if type(recipeMapOrList) ~= "table" then
		return out
	end

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

	table.sort(out)
	return out
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

local function EnsureRuntime()
	Workbench.Runtime = Workbench.Runtime or {}
	return Workbench.Runtime
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

local function EnsureOrderFields(order)
	order.Recipes = order.Recipes or {}
	order.MaterialState = order.MaterialState or {}
	order.Message = order.Message or ""
	order.CreatedAt = NormalizeTimestampText(order.CreatedAt)
	order.UpdatedAt = NormalizeTimestampText(order.UpdatedAt or order.CreatedAt)
	return order
end

local function MaterialKey(material)
	if not material then
		return ""
	end
	return material.Link or material.Name or ""
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

local function GetQueueHeight(frame)
	local frameHeight = ClampNumber(frame and frame.GetHeight and frame:GetHeight() or DEFAULT_FRAME_HEIGHT, MIN_FRAME_HEIGHT, MAX_FRAME_HEIGHT)
	local maximumQueueHeight = math.max(MIN_QUEUE_HEIGHT, frameHeight - DETAIL_RESERVED_HEIGHT)
	local suggestedQueueHeight = math.floor(frameHeight * 0.42)
	return ClampNumber(suggestedQueueHeight, MIN_QUEUE_HEIGHT, maximumQueueHeight)
end

local function ApplyFrameLayout(frame)
	if not frame or not frame.ListScroll then
		return
	end

	frame.ListScroll:SetHeight(GetQueueHeight(frame))
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
	if not GetTradeTargetItemInfo then
		return counts
	end

	for index = 1, GetTradeSlotLimit() do
		local itemName, _, itemCount = GetTradeTargetItemInfo(index)
		itemName = TrimText(itemName)
		if itemName ~= "" then
			itemCount = tonumber(itemCount) or 1
			local itemLink = GetTradeTargetItemLink and GetTradeTargetItemLink(index) or nil
			if type(itemLink) == "string" and itemLink ~= "" then
				counts[itemLink] = (counts[itemLink] or 0) + itemCount
			end
			counts[itemName] = (counts[itemName] or 0) + itemCount
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

function Workbench.SelectOrder(orderId)
	SetSelectedOrder(orderId)
	local order = Workbench.GetSelectedOrder()
	if order then
		WorkbenchDebug("selected order for", order.Customer, "(" .. tostring(#(order.Recipes or {})) .. " enchants)")
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
			return order
		end
	end

	return nil
end

local function OrderHasRecipe(order, recipeName)
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

function Workbench.GetMaterialSnapshot(order)
	local materials = {}
	local byKey = {}
	local missingRecipes = {}
	local recipeMats = EC.DBChar and EC.DBChar.RecipeMats or {}
	order = order or Workbench.GetSelectedOrder()

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
				if key ~= "" then
					if not byKey[key] then
						byKey[key] = {
							Key = key,
							Name = material.Name or material.Link or "Unknown Material",
							Link = material.Link,
							Count = 0,
						}
						materials[#materials + 1] = byKey[key]
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

	for _, material in ipairs(materials) do
		if order.MaterialState and order.MaterialState[material.Key] then
			checked = checked + 1
		end
	end

	return checked, total
end

function Workbench.GetTradeMaterialProgress(order)
	local materials = Workbench.GetMaterialSnapshot(order)
	local total = #materials
	local checked = 0
	local offeredState = {}
	local activeTrade = GetActiveTradeForOrder(order)

	order = order or Workbench.GetSelectedOrder()
	if not order or not activeTrade or total == 0 then
		return 0, total, offeredState
	end

	local offeredCounts = CaptureTradeTargetCounts()
	for _, material in ipairs(materials) do
		local offeredCount = offeredCounts[material.Key] or offeredCounts[material.Link or ""] or offeredCounts[material.Name or ""] or 0
		if offeredCount >= (tonumber(material.Count) or 1) then
			offeredState[material.Key] = true
			checked = checked + 1
		end
	end

	activeTrade.OfferedMaterialState = offeredState
	activeTrade.OfferedCounts = offeredCounts
	activeTrade.OfferedChecked = checked
	activeTrade.OfferedTotal = total

	return checked, total, offeredState
end

local function GetDisplayedMaterialProgress(order)
	local materials = Workbench.GetMaterialSnapshot(order)
	local total = #materials
	local manualChecked = 0
	local combinedChecked = 0
	local offeredChecked, _, offeredState = Workbench.GetTradeMaterialProgress(order)

	order = order or Workbench.GetSelectedOrder()
	if not order then
		return 0, total, offeredState, 0, offeredChecked
	end

	for _, material in ipairs(materials) do
		local hasManual = order.MaterialState and order.MaterialState[material.Key]
		local hasOffered = offeredState[material.Key]
		if hasManual then
			manualChecked = manualChecked + 1
		end
		if hasManual or hasOffered then
			combinedChecked = combinedChecked + 1
		end
	end

	return combinedChecked, total, offeredState, manualChecked, offeredChecked
end

function Workbench.GetTradePartnerName()
	local candidates = {
		_G and _G.TradeFrameRecipientNameText,
		_G and _G.TradeRecipientNameText,
		_G and _G.TradeFrameRecipientNameText and _G.TradeFrameRecipientNameText.GetText and _G.TradeFrameRecipientNameText:GetText(),
	}

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

function Workbench.BeginTrade(customerName)
	local runtime = EnsureRuntime()
	local order = Workbench.GetOrderByCustomer(customerName)

	runtime.ActiveTrade = {
		CustomerName = customerName or nil,
		OrderId = order and order.Id or nil,
		CastedRecipeName = nil,
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

	if order then
		SetSelectedOrder(order.Id)
		Workbench.GetTradeMaterialProgress(order)
	else
		activeTrade.OfferedMaterialState = {}
		activeTrade.OfferedCounts = {}
		activeTrade.OfferedChecked = 0
		activeTrade.OfferedTotal = 0
	end

	Workbench.Refresh()
	return order
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
	local completedOrder = nil

	runtime.ActiveTrade = nil

	if not activeTrade or not activeTrade.OrderId then
		WorkbenchDebug("trade closed with no tracked order")
		return nil
	end

	local order = Workbench.GetOrderById(activeTrade.OrderId)
	if not order then
		WorkbenchDebug("trade closed but tracked order is gone")
		return nil
	end

	local checked, total = Workbench.GetMaterialProgress(order)
	local hasAllMats = total > 0 and checked == total
	local gotPaid = (tonumber(goldDelta) or 0) > 0
	local castedRecipe = activeTrade.CastedRecipeName

	if gotPaid or castedRecipe or hasAllMats then
		WorkbenchDebug("auto-completing", order.Customer, "(paid=" .. tostring(gotPaid) .. ", cast=" .. tostring(castedRecipe ~= nil) .. ", mats=" .. tostring(hasAllMats) .. ")")
		completedOrder = order
		Workbench.RemoveOrder(order.Id)
	else
		WorkbenchDebug("trade closed for", order.Customer, "but keeping the order queued")
	end

	return completedOrder
end

function Workbench.UseTradeMaterials(orderId)
	local order = Workbench.GetOrderById(orderId)
	if not order then
		return false
	end

	local offeredChecked, total, offeredState = Workbench.GetTradeMaterialProgress(order)
	if total == 0 or offeredChecked == 0 then
		return false
	end

	order.MaterialState = order.MaterialState or {}
	for materialKey, isOffered in pairs(offeredState) do
		if isOffered then
			order.MaterialState[materialKey] = true
		end
	end
	order.UpdatedAt = TimestampText()
	WorkbenchDebug("copied trade mats for", order.Customer, "(" .. tostring(offeredChecked) .. "/" .. tostring(total) .. ")")
	Workbench.Refresh()
	return true
end

function Workbench.SetMaterialChecked(orderId, materialKey, checked)
	local state = Workbench.EnsureState()
	for _, order in ipairs(state.Orders) do
		if order.Id == orderId then
			order.MaterialState = order.MaterialState or {}
			order.MaterialState[materialKey] = checked and true or nil
			order.UpdatedAt = TimestampText()
			WorkbenchDebug((checked and "checked" or "cleared"), "material", materialKey, "for", order.Customer)
			break
		end
	end

	Workbench.Refresh()
end

function Workbench.SetAllMaterials(orderId, checked)
	local state = Workbench.EnsureState()
	for _, order in ipairs(state.Orders) do
		if order.Id == orderId then
			order.MaterialState = order.MaterialState or {}
			local materials = Workbench.GetMaterialSnapshot(order)
			for _, material in ipairs(materials) do
				order.MaterialState[material.Key] = checked and true or nil
			end
			order.UpdatedAt = TimestampText()
			WorkbenchDebug((checked and "checked" or "cleared"), "all mats for", order.Customer, "(" .. tostring(#materials) .. " items)")
			break
		end
	end

	Workbench.Refresh()
end

function Workbench.RemoveOrder(orderId)
	local state = Workbench.EnsureState()
	local removedOrder

	for index, order in ipairs(state.Orders) do
		if order.Id == orderId then
			removedOrder = order
			table.remove(state.Orders, index)
			break
		end
	end

	if removedOrder then
		EC.PlayerList[removedOrder.Customer] = nil
		EC.LfRecipeList[removedOrder.Customer] = nil
		WorkbenchDebug("removed order for", removedOrder.Customer, "(" .. tostring(#(removedOrder.Recipes or {})) .. " enchants)")
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
	end

	state.Orders = {}
	state.SelectedOrderId = nil
	local runtime = EnsureRuntime()
	runtime.ActiveTrade = nil

	WorkbenchDebug("cleared queue (" .. tostring(removedCount) .. " orders)")
	Workbench.Refresh()
	return removedCount
end

function Workbench.InviteOrder(orderId)
	local order = Workbench.GetOrderById(orderId)
	if not order then
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
	if not order or not order.Customer or #(order.Recipes or {}) == 0 then
		return false
	end

	WorkbenchDebug("manual whisper for", order.Customer)
	if EC and EC.SendRecipeWhisperTo then
		EC.SendRecipeWhisperTo(order.Customer, order.Recipes, "[Workbench] whisper")
		return true
	end

	return false
end

function Workbench.AddOrUpdateOrder(customer, message, recipeMap)
	local state = Workbench.EnsureState()
	local recipeNames = CopyRecipeNames(recipeMap)
	local order
	local isNewOrder = false

	if not customer or customer == "" or #recipeNames == 0 then
		return nil
	end

	for _, existing in ipairs(state.Orders) do
		if existing.Customer == customer then
			order = EnsureOrderFields(existing)
			break
		end
	end

	if not order then
		order = EnsureOrderFields({
			Id = state.NextOrderId,
			Customer = customer,
		})
		state.NextOrderId = state.NextOrderId + 1
		state.Orders[#state.Orders + 1] = order
		isNewOrder = true
	end

	local seen = {}
	for _, recipeName in ipairs(order.Recipes) do
		seen[recipeName] = true
	end
	for _, recipeName in ipairs(recipeNames) do
		if not seen[recipeName] then
			order.Recipes[#order.Recipes + 1] = recipeName
			seen[recipeName] = true
		end
	end

	table.sort(order.Recipes)
	order.Message = TrimText(message)
	order.UpdatedAt = TimestampText()

	if not state.SelectedOrderId then
		state.SelectedOrderId = order.Id
	end

	if isNewOrder then
		WorkbenchDebug("queued order for", customer, "(" .. tostring(#order.Recipes) .. " enchants)")
	else
		WorkbenchDebug("updated order for", customer, "(" .. tostring(#order.Recipes) .. " enchants)")
	end

	Workbench.Refresh()
	return order
end

local function TryCastRecipe(recipeName)
	if GetNumCrafts and GetCraftInfo and DoCraft then
		for index = 1, GetNumCrafts() or 0 do
			if GetCraftInfo(index) == recipeName then
				DoCraft(index)
				return true
			end
		end
	end

	if GetNumTradeSkills and GetTradeSkillInfo and DoTradeSkill then
		for index = 1, GetNumTradeSkills() or 0 do
			if GetTradeSkillInfo(index) == recipeName then
				DoTradeSkill(index)
				return true
			end
		end
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
	if not recipeName or recipeName == "" then
		return false
	end

	if TryCastRecipe(recipeName) then
		Workbench.NoteRecipeCast(recipeName)
		PrintTradeApplyHint(recipeName)
		WorkbenchDebug("cast started for", recipeName)
		return true
	end

	if CastSpellByName then
		WorkbenchDebug("opening enchanting before cast for", recipeName)
		CastSpellByName("Enchanting")
	end

	if C_Timer and C_Timer.After then
		C_Timer.After(0.2, function()
			if not TryCastRecipe(recipeName) then
				WorkbenchDebug("cast retry still unavailable for", recipeName)
				print("|cFFFF1C1CEnchanter|r Open enchanting and click Cast again if the client did not expose the recipe list yet.")
			else
				Workbench.NoteRecipeCast(recipeName)
				PrintTradeApplyHint(recipeName)
				WorkbenchDebug("cast started for", recipeName, "after opening enchanting")
			end
		end)
	else
		WorkbenchDebug("cast retry unavailable for", recipeName)
		print("|cFFFF1C1CEnchanter|r Open enchanting and click Cast again if the client did not expose the recipe list yet.")
	end

	return false
end

local function UpdateLockButtonText()
	if not Workbench.Frame or not Workbench.Frame.LockButton then
		return
	end

	local state = Workbench.EnsureState()
	Workbench.Frame.LockButton:SetText(state.Locked and "Unlock" or "Lock")
end

local function CreateOrderRow(parent, index)
	local row = CreateFrameCompat("Button", TOCNAME .. "WorkbenchOrder" .. index, parent)
	row:SetHeight(58)
	row:SetPoint("LEFT", parent, "LEFT", 4, 0)
	row:SetPoint("RIGHT", parent, "RIGHT", -10, 0)
	ApplyBackdrop(row, 0.16, 0.11, 0.08, 0.95, 0.58, 0.41, 0.22, 1)

	row.NameText = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	row.NameText:SetPoint("TOPLEFT", row, "TOPLEFT", 10, -8)
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

	row.InviteButton = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
	row.InviteButton:SetSize(42, 18)
	row.InviteButton:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", -6, 6)
	row.InviteButton:SetText("Inv")
	ApplyElvUISkin(row.InviteButton, "button")
	row.InviteButton:SetScript("OnClick", function(self)
		if self.OrderId then
			Workbench.InviteOrder(self.OrderId)
		end
	end)

	row.WhisperButton = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
	row.WhisperButton:SetSize(42, 18)
	row.WhisperButton:SetPoint("RIGHT", row.InviteButton, "LEFT", -4, 0)
	row.WhisperButton:SetText("Msg")
	ApplyElvUISkin(row.WhisperButton, "button")
	row.WhisperButton:SetScript("OnClick", function(self)
		if self.OrderId then
			Workbench.WhisperOrder(self.OrderId)
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
	line.NameText:SetPoint("RIGHT", line, "RIGHT", -68, 0)
	line.NameText:SetJustifyH("LEFT")

	line.CastButton = CreateFrame("Button", nil, line, "UIPanelButtonTemplate")
	line.CastButton:SetSize(56, 20)
	line.CastButton:SetPoint("RIGHT", line, "RIGHT", 0, 0)
	line.CastButton:SetText("Cast")
	ApplyElvUISkin(line.CastButton, "button")
	line.CastButton:SetScript("OnClick", function(self)
		if self.RecipeName then
			Workbench.CastRecipe(self.RecipeName)
		end
	end)

	return line
end

local function CreateMaterialLine(parent, index)
	local line = CreateFrameCompat("Frame", TOCNAME .. "WorkbenchMaterial" .. index, parent)
	line:SetHeight(22)
	line:SetPoint("LEFT", parent, "LEFT", 0, 0)
	line:SetPoint("RIGHT", parent, "RIGHT", 0, 0)

	line.Check = CreateFrame("CheckButton", nil, line, "UICheckButtonTemplate")
	line.Check:SetPoint("LEFT", line, "LEFT", -4, 0)
	ApplyElvUISkin(line.Check, "checkbox")
	line.Check:SetScript("OnClick", function(self)
		if self.OrderId and self.MaterialKey then
			Workbench.SetMaterialChecked(self.OrderId, self.MaterialKey, self:GetChecked())
		end
	end)

	line.Text = line:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	line.Text:SetPoint("LEFT", line.Check, "RIGHT", -2, 0)
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

	frame.LockButton = CreateFrame("Button", nil, frame.Header, "UIPanelButtonTemplate")
	frame.LockButton:SetSize(66, 20)
	frame.LockButton:SetPoint("RIGHT", frame.CloseButton, "LEFT", -6, 0)
	if frame.LockButton.SetFrameLevel and frame.Header.GetFrameLevel then
		frame.LockButton:SetFrameLevel(frame.Header:GetFrameLevel() + 2)
	end
	ApplyElvUISkin(frame.LockButton, "button")
	frame.LockButton:SetScript("OnClick", function()
		local state = Workbench.EnsureState()
		state.Locked = not state.Locked
		UpdateLockButtonText()
		WorkbenchDebug("frame", state.Locked and "locked" or "unlocked")
	end)

	frame.ClearButton = CreateFrame("Button", nil, frame.Header, "UIPanelButtonTemplate")
	frame.ClearButton:SetSize(48, 20)
	frame.ClearButton:SetPoint("RIGHT", frame.LockButton, "LEFT", -6, 0)
	frame.ClearButton:SetText("Clear")
	if frame.ClearButton.SetFrameLevel and frame.Header.GetFrameLevel then
		frame.ClearButton:SetFrameLevel(frame.Header:GetFrameLevel() + 2)
	end
	ApplyElvUISkin(frame.ClearButton, "button")
	frame.ClearButton:SetScript("OnClick", function()
		Workbench.ClearOrders()
	end)

	frame.TitleText = frame.Header:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	frame.TitleText:SetPoint("LEFT", frame.Header, "LEFT", 10, 0)
	frame.TitleText:SetText("Enchanter Workbench")

	frame.QueueCountText = frame.Header:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	frame.QueueCountText:SetPoint("LEFT", frame.TitleText, "RIGHT", 12, 0)
	frame.QueueCountText:SetPoint("RIGHT", frame.ClearButton, "LEFT", -10, 0)
	frame.QueueCountText:SetJustifyH("LEFT")
	frame.QueueCountText:SetText("0 orders")

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
	frame.Detail:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -14, 14)
	ApplyBackdrop(frame.Detail, 0.14, 0.1, 0.07, 0.96, 0.54, 0.37, 0.19, 1)
	ApplyElvUISkin(frame.Detail, "frame")

	frame.Detail.Title = frame.Detail:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	frame.Detail.Title:SetPoint("TOPLEFT", frame.Detail, "TOPLEFT", 12, -12)
	frame.Detail.Title:SetPoint("RIGHT", frame.Detail, "RIGHT", -12, 0)
	frame.Detail.Title:SetJustifyH("LEFT")

	frame.Detail.Meta = frame.Detail:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	frame.Detail.Meta:SetPoint("TOPLEFT", frame.Detail.Title, "BOTTOMLEFT", 0, -4)
	frame.Detail.Meta:SetPoint("RIGHT", frame.Detail, "RIGHT", -12, 0)
	frame.Detail.Meta:SetJustifyH("LEFT")

	frame.Detail.Message = frame.Detail:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	frame.Detail.Message:SetPoint("TOPLEFT", frame.Detail.Meta, "BOTTOMLEFT", 0, -8)
	frame.Detail.Message:SetPoint("RIGHT", frame.Detail, "RIGHT", -12, 0)
	frame.Detail.Message:SetJustifyH("LEFT")
	frame.Detail.Message:SetJustifyV("TOP")

	frame.Detail.TradeHint = frame.Detail:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	frame.Detail.TradeHint:SetPoint("TOPLEFT", frame.Detail.Message, "BOTTOMLEFT", 0, -8)
	frame.Detail.TradeHint:SetPoint("RIGHT", frame.Detail, "RIGHT", -12, 0)
	frame.Detail.TradeHint:SetJustifyH("LEFT")
	frame.Detail.TradeHint:SetJustifyV("TOP")
	frame.Detail.TradeHint:Hide()

	frame.Detail.RecipesHeader = frame.Detail:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	frame.Detail.RecipesHeader:SetText("Enchants")

	frame.Detail.MatsHeader = frame.Detail:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	frame.Detail.MatsHeader:SetText("Materials")

	frame.Detail.AllMatsButton = CreateFrame("Button", nil, frame.Detail, "UIPanelButtonTemplate")
	frame.Detail.AllMatsButton:SetSize(72, 20)
	frame.Detail.AllMatsButton:SetText("All Mats")
	ApplyElvUISkin(frame.Detail.AllMatsButton, "button")
	frame.Detail.AllMatsButton:SetScript("OnClick", function()
		local order = Workbench.GetSelectedOrder()
		if order then
			Workbench.SetAllMaterials(order.Id, true)
		end
	end)

	frame.Detail.UseTradeButton = CreateFrame("Button", nil, frame.Detail, "UIPanelButtonTemplate")
	frame.Detail.UseTradeButton:SetSize(78, 20)
	frame.Detail.UseTradeButton:SetText("Use Trade")
	ApplyElvUISkin(frame.Detail.UseTradeButton, "button")
	frame.Detail.UseTradeButton:SetScript("OnClick", function()
		local order = Workbench.GetSelectedOrder()
		if order then
			Workbench.UseTradeMaterials(order.Id)
		end
	end)

	frame.Detail.ClearMatsButton = CreateFrame("Button", nil, frame.Detail, "UIPanelButtonTemplate")
	frame.Detail.ClearMatsButton:SetSize(60, 20)
	frame.Detail.ClearMatsButton:SetText("Clear")
	ApplyElvUISkin(frame.Detail.ClearMatsButton, "button")
	frame.Detail.ClearMatsButton:SetScript("OnClick", function()
		local order = Workbench.GetSelectedOrder()
		if order then
			Workbench.SetAllMaterials(order.Id, false)
		end
	end)

	frame.Detail.ReadyText = frame.Detail:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	frame.Detail.ReadyText:SetJustifyH("LEFT")

	frame.Detail.Empty = frame.Detail:CreateFontString(nil, "OVERLAY", "GameFontDisable")
	frame.Detail.Empty:SetPoint("TOPLEFT", frame.Detail, "TOPLEFT", 12, -44)
	frame.Detail.Empty:SetPoint("RIGHT", frame.Detail, "RIGHT", -12, 0)
	frame.Detail.Empty:SetJustifyH("LEFT")
	frame.Detail.Empty:SetText("Select an order to see enchants, raw chat text, and a manual materials checklist.")

	frame.ResizeHandle = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
	frame.ResizeHandle:SetSize(54, 18)
	frame.ResizeHandle:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -14, 14)
	frame.ResizeHandle:SetText("Resize")
	frame.ResizeHandle:RegisterForDrag("LeftButton")
	ApplyElvUISkin(frame.ResizeHandle, "button")
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

	frame.OrderRows = {}
	frame.Detail.RecipeLines = {}
	frame.Detail.MaterialLines = {}

	frame:SetScript("OnSizeChanged", function(self)
		ApplyFrameLayout(self)
	end)
	frame:SetScript("OnHide", function()
		frame:StopMovingOrSizing()
	end)

	ApplyFrameLayout(frame)
	UpdateLockButtonText()
	return frame
end

function Workbench.Refresh()
	local frame = Workbench.Frame
	local state = Workbench.EnsureState()
	if not frame then
		return
	end

	frame.QueueCountText:SetText(string.format("%d orders", #state.Orders))
	SetRegionShown(frame.EmptyQueueText, #state.Orders == 0)
	UpdateLockButtonText()
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
		local readyText
		if total > 0 and checked == total then
			readyText = "Ready"
		elseif total > 0 then
			readyText = string.format("%d/%d mats", checked, total)
		else
			readyText = "No mats snapshot"
		end

		row.OrderId = order.Id
		row.RemoveButton.OrderId = order.Id
		row.InviteButton.OrderId = order.Id
		row.WhisperButton.OrderId = order.Id
		row.NameText:SetText(order.Customer or "Unknown")
		row.MetaText:SetText(string.format("Queued %s  •  Updated %s  •  %s", order.CreatedAt or "--:--", order.UpdatedAt or "--:--", readyText))
		row.SummaryText:SetText(OrderSummary(order))
		row:Show()

		if state.SelectedOrderId == order.Id then
			ApplyBackdrop(row, 0.24, 0.14, 0.08, 0.98, 0.9, 0.68, 0.28, 1)
		else
			ApplyBackdrop(row, 0.16, 0.11, 0.08, 0.95, 0.58, 0.41, 0.22, 1)
		end

		row:ClearAllPoints()
		row:SetPoint("TOPLEFT", frame.ListChild, "TOPLEFT", 4, -((index - 1) * 62))
		row:SetWidth(GetQueueListWidth(frame) - 14)
	end

	for index = #state.Orders + 1, #frame.OrderRows do
		frame.OrderRows[index]:Hide()
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
		frame.Detail.TradeHint:Hide()
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
		return
	end

	frame.Detail.Empty:Hide()
	frame.Detail.Title:SetText(order.Customer or "Unknown")

	local checked, total, offeredState, manualChecked, offeredChecked = GetDisplayedMaterialProgress(order)
	local activeTrade = GetActiveTradeForOrder(order)
	local readyText = total > 0 and string.format("%d/%d materials ready", checked, total) or "No materials captured yet"
	frame.Detail.Meta:SetText(string.format("Queued %s  •  Updated %s  •  %s", order.CreatedAt or "--:--", order.UpdatedAt or "--:--", readyText))
	frame.Detail.Message:SetText("Last chat: " .. (order.Message ~= "" and order.Message or "No raw message captured"))
	if activeTrade then
		frame.Detail.TradeHint:SetText("|cFFFFD26ATrade active. Click Apply, then click the customer's item in the trade window.|r")
		frame.Detail.TradeHint:Show()
	else
		frame.Detail.TradeHint:Hide()
	end
	frame.Detail.RecipesHeader:ClearAllPoints()
	frame.Detail.RecipesHeader:SetPoint("TOPLEFT", activeTrade and frame.Detail.TradeHint or frame.Detail.Message, "BOTTOMLEFT", 0, activeTrade and -10 or -14)
	frame.Detail.RecipesHeader:Show()

	local recipeAnchor = frame.Detail.RecipesHeader
	for index, recipeName in ipairs(order.Recipes or {}) do
		if not frame.Detail.RecipeLines[index] then
			frame.Detail.RecipeLines[index] = CreateRecipeLine(frame.Detail, index)
		end
		local line = frame.Detail.RecipeLines[index]
		local recipeLink = EC.DBChar and EC.DBChar.RecipeLinks and EC.DBChar.RecipeLinks[recipeName]
		line.NameText:SetText(recipeLink or recipeName)
		line.CastButton.RecipeName = recipeName
		line.CastButton:SetText(activeTrade and "Apply" or "Cast")
		line:ClearAllPoints()
		if index == 1 then
			line:SetPoint("TOPLEFT", recipeAnchor, "BOTTOMLEFT", 0, -6)
		else
			line:SetPoint("TOPLEFT", frame.Detail.RecipeLines[index - 1], "BOTTOMLEFT", 0, -4)
		end
		line:Show()
	end

	for index = #(order.Recipes or {}) + 1, #frame.Detail.RecipeLines do
		frame.Detail.RecipeLines[index]:Hide()
	end

	local materials, missingRecipes = Workbench.GetMaterialSnapshot(order)
	local matsAnchor = #(order.Recipes or {}) > 0 and frame.Detail.RecipeLines[#order.Recipes] or frame.Detail.RecipesHeader
	frame.Detail.MatsHeader:ClearAllPoints()
	frame.Detail.MatsHeader:SetPoint("TOPLEFT", matsAnchor, "BOTTOMLEFT", 0, -14)
	frame.Detail.MatsHeader:Show()

	frame.Detail.AllMatsButton:ClearAllPoints()
	frame.Detail.AllMatsButton:SetPoint("LEFT", frame.Detail.MatsHeader, "RIGHT", 12, 0)
	frame.Detail.UseTradeButton:ClearAllPoints()
	frame.Detail.UseTradeButton:SetPoint("LEFT", frame.Detail.AllMatsButton, "RIGHT", 6, 0)
	frame.Detail.ClearMatsButton:ClearAllPoints()
	frame.Detail.ClearMatsButton:SetPoint("LEFT", frame.Detail.UseTradeButton, "RIGHT", 6, 0)
	frame.Detail.ReadyText:ClearAllPoints()
	frame.Detail.ReadyText:SetPoint("TOPLEFT", frame.Detail.MatsHeader, "BOTTOMLEFT", 0, -4)
	frame.Detail.ReadyText:SetPoint("RIGHT", frame.Detail, "RIGHT", -12, 0)

	if #materials > 0 then
		frame.Detail.AllMatsButton:Show()
		if activeTrade and offeredChecked > 0 then
			frame.Detail.UseTradeButton:Show()
		else
			frame.Detail.UseTradeButton:Hide()
		end
		frame.Detail.ClearMatsButton:Show()
		if manualChecked == total then
			frame.Detail.ReadyText:SetText("|cFF74D06CAll queued mats are checked off.|r")
		elseif offeredChecked == total and total > 0 then
			frame.Detail.ReadyText:SetText("|cFF74D06CTrade currently has all queued mats. Click Use Trade to keep them checked.|r")
		elseif offeredChecked > 0 then
			frame.Detail.ReadyText:SetText("|cFFFFD26ATrade currently has " .. tostring(checked) .. "/" .. tostring(total) .. " queued mats. Click Use Trade to keep them checked.|r")
		else
			frame.Detail.ReadyText:SetText("|cFFFFD26AUse the checklist as the customer hands you materials.|r")
		end
	else
		frame.Detail.AllMatsButton:Hide()
		frame.Detail.UseTradeButton:Hide()
		frame.Detail.ClearMatsButton:Hide()
		frame.Detail.ReadyText:SetText("|cFFFF9F5AMaterials snapshot unavailable until your recipe scan exposes reagent data.|r")
	end
	frame.Detail.ReadyText:Show()

	local materialAnchor = frame.Detail.ReadyText
	for index, material in ipairs(materials) do
		if not frame.Detail.MaterialLines[index] then
			frame.Detail.MaterialLines[index] = CreateMaterialLine(frame.Detail, index)
		end
		local line = frame.Detail.MaterialLines[index]
		line.Check.OrderId = order.Id
		line.Check.MaterialKey = material.Key
		line.Check:SetChecked((order.MaterialState and order.MaterialState[material.Key]) or offeredState[material.Key] or false)
		line.Text:SetText(string.format("%dx %s", material.Count or 0, material.Link or material.Name or "Unknown Material"))
		line:ClearAllPoints()
		if index == 1 then
			line:SetPoint("TOPLEFT", materialAnchor, "BOTTOMLEFT", 0, -4)
		else
			line:SetPoint("TOPLEFT", frame.Detail.MaterialLines[index - 1], "BOTTOMLEFT", 0, -2)
		end
		line:Show()
	end

	for index = #materials + 1, #frame.Detail.MaterialLines do
		frame.Detail.MaterialLines[index]:Hide()
	end

	if #missingRecipes > 0 then
		frame.Detail.ReadyText:SetText(frame.Detail.ReadyText:GetText() .. "  |cFFFF9F5AMissing mats: " .. table.concat(missingRecipes, ", ") .. "|r")
	end
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
	local frame = Workbench.CreateFrame()
	if not frame then
		return
	end

	if frame:IsShown() then
		Workbench.Hide()
	else
		Workbench.Show()
	end
end

function Workbench.SyncVisibility()
	local state = Workbench.EnsureState()
	if state.Visible then
		Workbench.Show()
	elseif Workbench.Frame then
		Workbench.Frame:Hide()
	end
end
