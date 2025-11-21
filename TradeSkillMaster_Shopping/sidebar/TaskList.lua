local TSM = select(2, ...)
local L = LibStub("AceLocale-3.0"):GetLocale("TradeSkillMaster_Shopping")

local private = {}

function private.Create(parent)
	local frame = CreateFrame("Frame", nil, parent)
	frame:Hide()
	frame:SetAllPoints()
	frame:SetScript("OnShow", private.UpdateTaskList)
	TSMAPI.Design:SetFrameColor(frame)
	private.frame = frame

	local TSMCrafting = TSMAPI:GetModule("TradeSkillMaster_Crafting", "CraftingGUI")
	if not TSMCrafting then
		local noDataText = frame:CreateFontString(nil, "OVERLAY")
		noDataText:SetFont(TSMAPI.Design:GetContentFont(), 16)
		TSMAPI.Design:SetWidgetTextColor(noDataText)
		noDataText:SetPoint("CENTER")
		noDataText:SetText("TSM Crafting not loaded")
		return frame
	end

	local queueContainer = CreateFrame("Frame", nil, frame)
	queueContainer:SetPoint("TOPLEFT", 5, -5)
	queueContainer:SetPoint("TOPRIGHT", -5, -5)
	queueContainer:SetHeight(200)
	TSMAPI.Design:SetFrameColor(queueContainer)
	frame.queueContainer = queueContainer

	local queueTitle = queueContainer:CreateFontString(nil, "OVERLAY")
	queueTitle:SetFont(TSMAPI.Design:GetContentFont(), 14)
	TSMAPI.Design:SetWidgetLabelColor(queueTitle)
	queueTitle:SetPoint("TOP", queueContainer, 0, -5)
	queueTitle:SetText("Craft Queue")

	local queueCols = {
		{ name = "Crafts", width = 1, align = "Left" },
	}

	local stHandlers = {
		OnEnter = function(_, data, self)
			if not data or not data.spellID then return end
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
			local TSMCrafting = TSMAPI:GetModule("TradeSkillMaster_Crafting")
			if TSMCrafting and TSMCrafting.db and TSMCrafting.db.realm.crafts[data.spellID] then
				local craftData = TSMCrafting.db.realm.crafts[data.spellID]
				GameTooltip:AddLine(craftData.name .. " (x" .. data.numQueued .. ")")
				local moneyCoinsTooltip = TSMAPI:GetMoneyCoinsTooltip()
				if data.profit then
					local color = data.profit < 0 and "|cffff0000" or "|cff00ff00"
					if moneyCoinsTooltip then
						GameTooltip:AddLine("Profit: " .. (TSMAPI:FormatTextMoneyIcon(data.profit, color) or "---"))
					else
						GameTooltip:AddLine("Profit: " .. (TSMAPI:FormatTextMoney(data.profit, color) or "---"))
					end
				end
			end
			GameTooltip:Show()
		end,
		OnLeave = function()
			GameTooltip:ClearLines()
			GameTooltip:Hide()
		end
	}

	frame.queueST = TSMAPI:CreateScrollingTable(queueContainer, queueCols, stHandlers, 8)
	frame.queueST.frame:SetPoint("TOPLEFT", queueTitle, "BOTTOMLEFT", 0, -5)
	frame.queueST.frame:SetPoint("BOTTOMRIGHT", queueContainer, -5, 5)
	frame.queueST:DisableSelection(true)

	local matsContainer = CreateFrame("Frame", nil, frame)
	matsContainer:SetPoint("TOPLEFT", queueContainer, "BOTTOMLEFT", 0, -10)
	matsContainer:SetPoint("TOPRIGHT", queueContainer, "BOTTOMRIGHT", 0, -10)
	matsContainer:SetPoint("BOTTOM", frame, 0, 5)
	TSMAPI.Design:SetFrameColor(matsContainer)
	frame.matsContainer = matsContainer

	local matsTitle = matsContainer:CreateFontString(nil, "OVERLAY")
	matsTitle:SetFont(TSMAPI.Design:GetContentFont(), 14)
	TSMAPI.Design:SetWidgetLabelColor(matsTitle)
	matsTitle:SetPoint("TOP", matsContainer, 0, -5)
	matsTitle:SetText("Materials Needed")

	local matsCols = {
		{ name = "Material", width = 0.5, align = "Left" },
		{ name = "Need", width = 0.25, align = "Center" },
		{ name = "Total", width = 0.25, align = "Center" },
	}

	local matsHandlers = {
		OnEnter = function(_, data, self)
			if not data or not data.itemString then return end
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
			GameTooltip:SetHyperlink(data.itemString)
			GameTooltip:Show()
		end,
		OnLeave = function()
			GameTooltip:ClearLines()
			GameTooltip:Hide()
		end
	}

	frame.matsST = TSMAPI:CreateScrollingTable(matsContainer, matsCols, matsHandlers, 8)
	frame.matsST.frame:SetPoint("TOPLEFT", matsTitle, "BOTTOMLEFT", 0, -5)
	frame.matsST.frame:SetPoint("BOTTOMRIGHT", matsContainer, -5, 5)
	frame.matsST:DisableSelection(true)

	return frame
end

function private.UpdateTaskList()
	local frame = private.frame
	if not frame then return end

	local TSMCrafting = TSMAPI:GetModule("TradeSkillMaster_Crafting")
	if not TSMCrafting or not TSMCrafting.db or not TSMCrafting.db.realm.crafts then
		return
	end

	local queueData = {}
	local matsNeeded = {}

	for spellID, data in pairs(TSMCrafting.db.realm.crafts) do
		if data.queued and data.queued > 0 then
			local Cost = TSMAPI:GetModule("TradeSkillMaster_Crafting", "Cost")
			local cost, buyout, profit
			if Cost then
				cost, buyout, profit = Cost:GetCraftPrices(spellID)
			end

			local color = "|cffffffff"
			if profit then
				color = profit < 0 and "|cffff0000" or "|cff00ff00"
			end

			local profitText = ""
			if profit then
				profitText = " " .. color .. TSMAPI:FormatTextMoney(profit) .. "|r"
			end

			tinsert(queueData, {
				cols = {
					{ value = data.name .. " |cff99ffff(x" .. data.queued .. ")|r" .. profitText }
				},
				spellID = spellID,
				numQueued = data.queued,
				profit = profit
			})

			for itemString, quantity in pairs(data.mats) do
				matsNeeded[itemString] = (matsNeeded[itemString] or 0) + (quantity * data.queued)
			end
		end
	end

	frame.queueST:SetData(queueData)

	local matsData = {}
	local Inventory = TSMAPI:GetModule("TradeSkillMaster_Crafting", "Inventory")
	for itemString, quantity in pairs(matsNeeded) do
		local itemName = TSMAPI.Item:GetName(itemString)
		local bagQuantity = 0
		if Inventory then
			bagQuantity = Inventory:GetTotalQuantity(itemString) or 0
		end

		local need = max(quantity - bagQuantity, 0)
		local needColor = need > 0 and "|cffff0000" or "|cff00ff00"

		tinsert(matsData, {
			cols = {
				{ value = itemName or itemString },
				{ value = needColor .. need .. "|r" },
				{ value = bagQuantity .. "/" .. quantity }
			},
			itemString = itemString
		})
	end

	frame.matsST:SetData(matsData)
end

do
	TSM:AddSidebarFeature("Task List", private.Create, private.UpdateTaskList)
end
