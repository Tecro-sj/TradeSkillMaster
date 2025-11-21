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
	queueSTParent:SetHeight(120)
	TSMAPI.Design:SetFrameColor(queueSTParent)

	local queueCols = {
		{ name = "Craft", width = 0.65, align = "LEFT" },
		{ name = "Queue", width = 0.15, align = "CENTER" },
		{ name = "Profit", width = 0.20, align = "RIGHT" },
	}

	local stHandlers = {
		OnEnter = function(_, data, self)
			if not data or not data.spellID then return end
			local TSMCrafting = LibStub("AceAddon-3.0"):GetAddon("TSM_Crafting", true)
			if not TSMCrafting or not TSMCrafting.db or not TSMCrafting.db.realm or not TSMCrafting.db.realm.crafts then return end

			GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
			GameTooltip:AddLine(data.name .. " (x" .. data.queued .. ")")

			if data.profit then
				local color = data.profit < 0 and "|cffff0000" or "|cff00ff00"
				GameTooltip:AddLine("Profit: " .. TSMAPI:FormatTextMoney(data.profit, color))
				if data.queued > 1 then
					local totalProfit = data.profit * data.queued
					GameTooltip:AddLine("Total Profit: " .. TSMAPI:FormatTextMoney(totalProfit, color))
				end
			end

			local craft = TSMCrafting.db.realm.crafts[data.spellID]
			if craft and craft.mats then
				GameTooltip:AddLine(" ")
				for itemString, matQuantity in pairs(craft.mats) do
					local itemName = GetItemInfo(itemString) or itemString
					local inventory = TSMCrafting.Inventory:GetPlayerBagNum(itemString) or 0
					local need = matQuantity * data.queued
					local color = inventory >= need and "|cff00ff00" or "|cffff0000"
					GameTooltip:AddLine(color .. inventory .. "/" .. need .. "|r " .. itemName, 1, 1, 1)
				end
			end

			GameTooltip:Show()
		end,
		OnLeave = function()
			GameTooltip:Hide()
		end
	}

	frame.queueST = TSMAPI:CreateScrollingTable(queueSTParent, queueCols, stHandlers, 8)
	frame.queueST:DisableSelection(true)

	local searchBtn = TSMAPI.GUI:CreateButton(frame, 18)
	searchBtn:SetPoint("TOPLEFT", queueSTParent, "BOTTOMLEFT", 0, -5)
	searchBtn:SetPoint("TOPRIGHT", queueSTParent, "BOTTOMRIGHT", 0, -5)
	searchBtn:SetHeight(25)
	searchBtn:SetText("Search Auction")
	searchBtn:SetScript("OnClick", function()
		private.SearchAuction()
	end)
	frame.searchBtn = searchBtn

	local matsText = TSMAPI.GUI:CreateLabel(frame)
	matsText:SetPoint("TOPLEFT", searchBtn, "BOTTOMLEFT", 0, -10)
	matsText:SetPoint("TOPRIGHT", searchBtn, "BOTTOMRIGHT", 0, -10)
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
		end,
		OnClick = function(_, data)
			if data and data.itemString and IsAltKeyDown() then
				local itemName = GetItemInfo(data.itemString)
				if itemName then
					TSM:GetModule("Search"):StartItemSearch(itemName)
				end
			end
		end
	}

	frame.matsST = TSMAPI:CreateScrollingTable(matsSTParent, matsCols, matsHandlers, 6)
	frame.matsST:DisableSelection(true)

	private.frame = frame
	return frame
end

function private.SearchAuction()
	local TSMCrafting = LibStub("AceAddon-3.0"):GetAddon("TSM_Crafting", true)
	if not TSMCrafting or not TSMCrafting.db or not TSMCrafting.db.realm or not TSMCrafting.db.realm.crafts then
		TSM:Print("No craft queue found.")
		return
	end

	local materials = {}
	for spellID, data in pairs(TSMCrafting.db.realm.crafts) do
		if data.queued and data.queued > 0 and data.mats then
			for itemString, quantity in pairs(data.mats) do
				local totalNeeded = quantity * data.queued
				local have = TSMCrafting.Inventory:GetPlayerBagNum(itemString) or 0
				local need = max(totalNeeded - have, 0)
				if need > 0 then
					materials[itemString] = (materials[itemString] or 0) + need
				end
			end
		end
	end

	local searchTerms = {}
	for itemString in pairs(materials) do
		local itemName = GetItemInfo(itemString)
		if itemName then
			tinsert(searchTerms, itemName)
		end
	end

	if #searchTerms == 0 then
		TSM:Print("All materials available!")
		return
	end

	local searchString = table.concat(searchTerms, ";")
	TSM:GetModule("Search"):StartItemSearch(searchString)
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
				queued = data.queued,
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
	for itemString, totalNeeded in pairs(matsNeeded) do
		local itemName = GetItemInfo(itemString)
		if not itemName then
			itemName = itemString
		end

		local have = TSMCrafting.Inventory:GetPlayerBagNum(itemString) or 0
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
