local TSM = select(2, ...)
local L = LibStub("AceLocale-3.0"):GetLocale("TradeSkillMaster_Shopping")

local private = {}

function private.Create(parent)
	local frame = CreateFrame("Frame", nil, parent)
	frame:SetAllPoints()
	frame:SetScript("OnShow", function() private.UpdateTaskList() end)
	TSMAPI.Design:SetFrameColor(frame)

	local helpText = TSMAPI.GUI:CreateLabel(frame)
	helpText:SetPoint("TOPLEFT", 5, -5)
	helpText:SetPoint("TOPRIGHT", -5, -5)
	helpText:SetHeight(30)
	helpText:SetJustifyH("CENTER")
	helpText:SetJustifyV("CENTER")
	helpText:SetText("Craft Queue - Items to Craft")
	frame.helpText = helpText

	local queueSTParent = CreateFrame("Frame", nil, frame)
	queueSTParent:SetPoint("TOPLEFT", helpText, "BOTTOMLEFT", 0, -5)
	queueSTParent:SetPoint("TOPRIGHT", helpText, "BOTTOMRIGHT", 0, -5)
	queueSTParent:SetHeight(150)
	TSMAPI.Design:SetFrameColor(queueSTParent)

	local queueCols = {
		{ name = "Craft", width = 0.65, align = "LEFT" },
		{ name = "Queue", width = 0.15, align = "CENTER" },
		{ name = "Profit", width = 0.20, align = "RIGHT" },
	}

	local stHandlers = {
		OnEnter = function(_, data, self)
			if not data or not data.spellID then return end
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
			GameTooltip:AddLine(data.name)
			if data.profit then
				GameTooltip:AddLine("Profit per craft: " .. TSMAPI:FormatTextMoney(data.profit))
			end
			GameTooltip:Show()
		end,
		OnLeave = function()
			GameTooltip:Hide()
		end
	}

	frame.queueST = TSMAPI:CreateScrollingTable(queueSTParent, queueCols, stHandlers, 10)
	frame.queueST:DisableSelection(true)

	local matsText = TSMAPI.GUI:CreateLabel(frame)
	matsText:SetPoint("TOPLEFT", queueSTParent, "BOTTOMLEFT", 0, -10)
	matsText:SetPoint("TOPRIGHT", queueSTParent, "BOTTOMRIGHT", 0, -10)
	matsText:SetHeight(25)
	matsText:SetJustifyH("CENTER")
	matsText:SetJustifyV("CENTER")
	matsText:SetText("Materials Needed")
	frame.matsText = matsText

	local matsSTParent = CreateFrame("Frame", nil, frame)
	matsSTParent:SetPoint("TOPLEFT", matsText, "BOTTOMLEFT", 0, -5)
	matsSTParent:SetPoint("TOPRIGHT", matsText, "BOTTOMRIGHT", 0, -5)
	matsSTParent:SetPoint("BOTTOM", frame, 0, 5)
	TSMAPI.Design:SetFrameColor(matsSTParent)

	local matsCols = {
		{ name = "Material", width = 0.50, align = "LEFT" },
		{ name = "Need", width = 0.25, align = "CENTER" },
		{ name = "Have/Total", width = 0.25, align = "CENTER" },
	}

	local matsHandlers = {
		OnEnter = function(_, data, self)
			if not data or not data.itemString then return end
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
			GameTooltip:SetHyperlink(data.itemString)
			GameTooltip:Show()
		end,
		OnLeave = function()
			GameTooltip:Hide()
		end
	}

	frame.matsST = TSMAPI:CreateScrollingTable(matsSTParent, matsCols, matsHandlers, 8)
	frame.matsST:DisableSelection(true)

	private.frame = frame
	return frame
end

function private.UpdateTaskList()
	if not private.frame then return end

	local TSMCrafting = LibStub("AceAddon-3.0"):GetAddon("TSM_Crafting", true)
	if not TSMCrafting or not TSMCrafting.db or not TSMCrafting.db.realm or not TSMCrafting.db.realm.crafts then
		private.frame.queueST:SetData({})
		private.frame.matsST:SetData({})
		return
	end

	local queueData = {}
	local matsNeeded = {}

	for spellID, data in pairs(TSMCrafting.db.realm.crafts) do
		if data.queued and data.queued > 0 then
			local Cost = TSMCrafting:GetModule("Cost", true)
			local cost, buyout, profit
			if Cost then
				cost, buyout, profit = Cost:GetCraftPrices(spellID)
			end

			local profitText = "---"
			if profit then
				profitText = TSMAPI:FormatTextMoney(profit, profit < 0 and "|cffff0000" or "|cff00ff00")
			end

			tinsert(queueData, {
				cols = {
					{ value = data.name },
					{ value = data.queued },
					{ value = profitText }
				},
				spellID = spellID,
				name = data.name,
				profit = profit
			})

			if data.mats then
				for itemString, quantity in pairs(data.mats) do
					matsNeeded[itemString] = (matsNeeded[itemString] or 0) + (quantity * data.queued)
				end
			end
		end
	end

	private.frame.queueST:SetData(queueData)

	local matsData = {}
	local Inventory = TSMCrafting:GetModule("Inventory", true)
	for itemString, totalNeeded in pairs(matsNeeded) do
		local itemName = TSMAPI.Item:GetName(itemString)
		if not itemName then
			itemName = itemString
		end

		local have = 0
		if Inventory then
			have = Inventory:GetTotalQuantity(itemString) or 0
		end

		local need = max(totalNeeded - have, 0)
		local needText = need > 0 and "|cffff0000" .. need .. "|r" or "|cff00ff00" .. need .. "|r"

		tinsert(matsData, {
			cols = {
				{ value = itemName },
				{ value = needText },
				{ value = have .. "/" .. totalNeeded }
			},
			itemString = itemString
		})
	end

	private.frame.matsST:SetData(matsData)
end

do
	TSM:AddSidebarFeature(L["Task List"], private.Create, private.UpdateTaskList)
end
