local TSM = select(2, ...)
local L = LibStub("AceLocale-3.0"):GetLocale("TradeSkillMaster_Shopping")

local private = {}

-- Helper function to aggregate raw materials from queue (copied from Crafting module logic)
local function AggregateRawMaterialsFromQueue(queuedCrafts)
	local TSMCrafting = LibStub("AceAddon-3.0"):GetAddon("TSM_Crafting", true)
	if not TSMCrafting or not TSMCrafting.db or not TSMCrafting.db.realm then return {} end

	local aggregatedMats = {}

	for profession, crafts in pairs(queuedCrafts) do
		for _, stage in ipairs(crafts) do
			for spellID, numQueued in pairs(stage.crafts) do
				local craftData = TSMCrafting.db.realm.crafts[spellID]
				if craftData and craftData.mats then
					for itemString, quantity in pairs(craftData.mats) do
						aggregatedMats[itemString] = (aggregatedMats[itemString] or 0) + (quantity * numQueued)
					end
				end
			end
		end
	end

	return aggregatedMats
end

function private.Create(parent)
	local frame = CreateFrame("Frame", nil, parent)
	frame:SetAllPoints()
	frame:SetScript("OnShow", function() private.UpdateTaskList() end)
	TSMAPI.Design:SetFrameColor(frame)

	-- Queue ScrollingTable - upper half
	local queueContainer = CreateFrame("Frame", nil, frame)
	queueContainer:SetPoint("TOPLEFT", 5, -5)
	queueContainer:SetPoint("TOPRIGHT", -5, -5)
	queueContainer:SetHeight(125)
	TSMAPI.Design:SetFrameColor(queueContainer)

	local queueCols = {
		{ name = L["Craft Queue"], width = 1, align = "Left" },
	}

	local function OnCraftRowEnter(_, data, self)
		if not data or not data.spellID then return end
		local TSMCrafting = LibStub("AceAddon-3.0"):GetAddon("TSM_Crafting", true)
		if not TSMCrafting then return end

		local color
		local totalProfit
		local moneyCoinsTooltip = TSMAPI:GetMoneyCoinsTooltip()
		if data.profit then
			totalProfit = data.numQueued * data.profit
			if data.profit < 0 then
				color = "|cffff0000"
			else
				color = "|cff00ff00"
			end
		end
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:AddLine(TSMCrafting.db.realm.crafts[data.spellID].name .. " (x" .. data.numQueued .. ")")

		local cost = TSMCrafting.Cost:GetCraftPrices(data.spellID)
		if data.profit then
			local profitPercent = data.profit / cost * 100
			local profitPercText = format("%s%.0f%%|r", color, profitPercent)
			if data.profit > 0 then
				if moneyCoinsTooltip then
					GameTooltip:AddLine("Profit: " .. (TSMAPI:FormatTextMoneyIcon(data.profit, color) or "---") .. " (" .. (profitPercText or "---") .. ")")
				else
					GameTooltip:AddLine("Profit: " .. (TSMAPI:FormatTextMoney(data.profit, color) or "---") .. " (" .. (profitPercText or "---") .. ")")
				end
				if data.numQueued > 1 then
					if moneyCoinsTooltip then
						GameTooltip:AddLine("Total Profit: " .. (TSMAPI:FormatTextMoneyIcon(totalProfit, color) or "---"))
					else
						GameTooltip:AddLine("Total Profit: " .. (TSMAPI:FormatTextMoney(totalProfit, color) or "---"))
					end
				end
			else
				if moneyCoinsTooltip then
					GameTooltip:AddLine("Loss: " .. (TSMAPI:FormatTextMoneyIcon(data.profit, color) or "---") .. " (" .. (profitPercText or "---") .. ")")
				else
					GameTooltip:AddLine("Loss: " .. (TSMAPI:FormatTextMoney(data.profit, color) or "---") .. " (" .. (profitPercText or "---") .. ")")
				end
			end
		end

		GameTooltip:AddLine(" ")
		if moneyCoinsTooltip then
			GameTooltip:AddLine("Crafting Cost: " .. (TSMAPI:FormatTextMoneyIcon(cost, "|cffffff00") or "---"))
		else
			GameTooltip:AddLine("Crafting Cost: " .. (TSMAPI:FormatTextMoney(cost, "|cffffff00") or "---"))
		end

		for itemID, matQuantity in pairs(TSMCrafting.db.realm.crafts[data.spellID].mats) do
			local name = TSMAPI:GetSafeItemInfo(itemID) or (TSMCrafting.db.realm.mats[itemID] and TSMCrafting.db.realm.mats[itemID].name) or "?"
			local inventory = TSMCrafting.Inventory:GetPlayerBagNum(itemID)
			local need = matQuantity * data.numQueued
			local color
			local isVendorItem = TSMAPI:GetVendorCost(itemID) ~= nil
			if inventory >= need then
				color = "|cff00ff00"
			elseif isVendorItem then
				color = "|cff00bfff"
			else
				color = "|cffff0000"
			end
			name = color .. inventory .. "/" .. need .. "|r " .. name
			GameTooltip:AddLine(name, 1, 1, 1)
		end

		GameTooltip:Show()
	end

	local function OnCraftRowLeave()
		GameTooltip:Hide()
	end

	local function OnCraftRowClicked(_, data)
		local TSMCrafting = LibStub("AceAddon-3.0"):GetAddon("TSM_Crafting", true)
		if not TSMCrafting then return end

		if IsModifiedClick() and data.spellID then
			local itemID = TSMCrafting.db.realm.crafts[data.spellID] and TSMCrafting.db.realm.crafts[data.spellID].itemID
			if itemID then
				local link = select(2, TSMAPI:GetSafeItemInfo(itemID))
				if link then
					HandleModifiedItemClick(link)
					return
				end
			end
		end

		if data.isTitle then
			if data.stage then
				TSMCrafting.db.realm.queueStatus.collapsed[data.profession .. data.stage] = not TSMCrafting.db.realm.queueStatus.collapsed[data.profession .. data.stage]
			else
				TSMCrafting.db.realm.queueStatus.collapsed[data.profession] = not TSMCrafting.db.realm.queueStatus.collapsed[data.profession]
			end
			private.UpdateTaskList()
		end
	end

	frame.queueST = TSMAPI:CreateScrollingTable(queueContainer, queueCols, { OnClick = OnCraftRowClicked, OnEnter = OnCraftRowEnter, OnLeave = OnCraftRowLeave }, 14)
	frame.queueST:SetData({})
	frame.queueST:DisableSelection(true)

	-- Materials table - middle section
	local matContainer = CreateFrame("Frame", nil, frame)
	matContainer:SetPoint("TOPLEFT", queueContainer, "BOTTOMLEFT", 0, -10)
	matContainer:SetPoint("TOPRIGHT", queueContainer, "BOTTOMRIGHT", 0, -10)
	matContainer:SetPoint("BOTTOMLEFT", 5, 85)
	matContainer:SetPoint("BOTTOMRIGHT", -5, 85)
	TSMAPI.Design:SetFrameColor(matContainer)

	local matCols = {
		{ name = "Material Name", width = 0.69, align = "Left" },
		{ name = "Need", width = 0.2, align = "LEFT" },
		{ name = "Total", width = 0.2, align = "LEFT" },
	}

	local function MatOnEnter(_, data, col)
		GameTooltip:SetOwner(col, "ANCHOR_RIGHT")
		TSMAPI:SafeTooltipLink(data.itemString)
		GameTooltip:Show()
	end

	local function MatOnLeave()
		GameTooltip:Hide()
	end

	local function MatOnClick(_, data)
		if IsModifiedClick() then
			local link = select(2, TSMAPI:GetSafeItemInfo(data.itemString))
			HandleModifiedItemClick(link or data.itemString)
		else
			-- Try to buy from vendor if merchant frame is open
			if MerchantFrame and MerchantFrame:IsVisible() then
				local TSMCrafting = LibStub("AceAddon-3.0"):GetAddon("TSM_Crafting", true)
				if not TSMCrafting then return end

				local itemID = TSMAPI:GetItemID(data.itemString)
				if itemID then
					-- Find item in merchant inventory
					local numItems = GetMerchantNumItems()
					for i = 1, numItems do
						local merchantItemLink = GetMerchantItemLink(i)
						local merchantItemID = merchantItemLink and tonumber(string.match(merchantItemLink, "item:(%d+)"))
						if merchantItemID == itemID then
							-- Calculate how many we need
							local have = TSMCrafting.Inventory:GetTotalQuantity(data.itemString)
							local need = data.cols[2].args[1] -- This is the "Need" value
							if need > 0 then
								-- Get stack size and buy enough stacks
								local _, _, _, quantity = GetMerchantItemInfo(i)
								local stacksToBuy = ceil(need / quantity)
								for j = 1, stacksToBuy do
									BuyMerchantItem(i, 1)
								end
								-- Refresh task list after purchase
								TSMAPI:CreateTimeDelay("shoppingTaskListUpdateAfterVendorBuy", 0.3, private.UpdateTaskList)
								return
							end
						end
					end
				end
			end
		end
	end

	frame.matST = TSMAPI:CreateScrollingTable(matContainer, matCols, { OnEnter = MatOnEnter, OnLeave = MatOnLeave, OnClick = MatOnClick }, 12)
	frame.matST:SetData({})
	frame.matST:DisableSelection(true)

	-- Profit/Cost labels
	local profitLabel = TSMAPI.GUI:CreateLabel(frame, "medium")
	profitLabel:SetPoint("BOTTOMLEFT", 5, 60)
	profitLabel:SetPoint("BOTTOMRIGHT", -5, 60)
	profitLabel:SetJustifyH("LEFT")
	profitLabel:SetJustifyV("BOTTOM")
	profitLabel.SetAmounts = function(self, cost, profit)
		if type(cost) == "number" then
			cost = TSMAPI:FormatTextMoney(cost, TSMAPI.Design:GetInlineColor("link"))
		else
			cost = TSMAPI.Design:GetInlineColor("link") .. "---|r"
		end
		if type(profit) == "number" then
			if profit < 0 then
				profit = "|cffff0000-|r" .. TSMAPI:FormatTextMoney(-profit, "|cffff0000")
			else
				profit = TSMAPI:FormatTextMoney(profit, "|cff00ff00")
			end
		else
			profit = TSMAPI.Design:GetInlineColor("link") .. "---|r"
		end
		self:SetText(format("Estimated Cost: %s\nEstimated Profit: %s", cost, profit))
	end
	profitLabel:SetAmounts("---", "---")
	frame.profitLabel = profitLabel

	-- Clear Queue button (top-left)
	local clearQueueBtn = TSMAPI.GUI:CreateButton(frame, 14)
	clearQueueBtn:SetPoint("BOTTOMLEFT", 5, 30)
	clearQueueBtn:SetWidth(120)
	clearQueueBtn:SetHeight(20)
	clearQueueBtn:SetText("Clear Queue")
	clearQueueBtn:SetScript("OnClick", function()
		local TSMCrafting = LibStub("AceAddon-3.0"):GetAddon("TSM_Crafting", true)
		if TSMCrafting and TSMCrafting.Queue then
			TSMCrafting.Queue:ClearQueue()
			private.UpdateTaskList()
		end
	end)

	-- Refresh button (top-right)
	local refreshBtn = TSMAPI.GUI:CreateButton(frame, 14)
	refreshBtn:SetPoint("BOTTOMLEFT", clearQueueBtn, "BOTTOMRIGHT", 5, 0)
	refreshBtn:SetPoint("BOTTOMRIGHT", -5, 30)
	refreshBtn:SetHeight(20)
	refreshBtn:SetText("Refresh")
	refreshBtn:SetScript("OnClick", function()
		private.UpdateTaskList()
	end)

	-- Vendor Buy button (bottom-left)
	local vendorBuyBtn = TSMAPI.GUI:CreateButton(frame, 14)
	vendorBuyBtn:SetPoint("BOTTOMLEFT", 5, 5)
	vendorBuyBtn:SetWidth(120)
	vendorBuyBtn:SetHeight(20)
	vendorBuyBtn:SetText("Vendor Buy")
	vendorBuyBtn:Disable()

	vendorBuyBtn:SetScript("OnClick", function()
		local TSMCrafting = LibStub("AceAddon-3.0"):GetAddon("TSM_Crafting", true)
		if not TSMCrafting or not TSMCrafting.Queue then return end

		local queuedCrafts = TSMCrafting.Queue:GetQueue()
		local aggregatedMats = AggregateRawMaterialsFromQueue(queuedCrafts)

		local numItems = GetMerchantNumItems()
		local purchasedAny = false
		for itemString, quantity in pairs(aggregatedMats) do
			local isVendorItem = TSMAPI:GetVendorCost(itemString) ~= nil
			if isVendorItem then
				local have = TSMCrafting.Inventory:GetTotalQuantity(itemString)
				local need = max(quantity - have, 0)
				if need > 0 then
					local itemID = TSMAPI:GetItemID(itemString)
					if itemID then
						for i = 1, numItems do
							local merchantItemLink = GetMerchantItemLink(i)
							local merchantItemID = merchantItemLink and tonumber(string.match(merchantItemLink, "item:(%d+)"))
							if merchantItemID == itemID then
								local _, _, _, stackSize = GetMerchantItemInfo(i)
								local stacksToBuy = ceil(need / stackSize)
								for j = 1, stacksToBuy do
									BuyMerchantItem(i, 1)
								end
								purchasedAny = true
								break
							end
						end
					end
				end
			end
		end

		if purchasedAny then
			TSM:Print("Purchased vendor items.")
			TSMAPI:CreateTimeDelay("shoppingTaskListUpdateAfterVendorBuy", 0.3, private.UpdateTaskList)
		else
			TSM:Print("No vendor items needed or available.")
		end
	end)

	-- Search Auction button (bottom-right)
	local searchAuctionBtn = TSMAPI.GUI:CreateButton(frame, 14)
	searchAuctionBtn:SetPoint("BOTTOMLEFT", vendorBuyBtn, "BOTTOMRIGHT", 5, 0)
	searchAuctionBtn:SetPoint("BOTTOMRIGHT", -5, 5)
	searchAuctionBtn:SetHeight(20)
	searchAuctionBtn:SetText("Search Auction")

	searchAuctionBtn:SetScript("OnClick", function()
		local TSMCrafting = LibStub("AceAddon-3.0"):GetAddon("TSM_Crafting", true)
		if not TSMCrafting or not TSMCrafting.Queue then return end

		local queuedCrafts = TSMCrafting.Queue:GetQueue()
		local aggregatedMats = AggregateRawMaterialsFromQueue(queuedCrafts)

		local searchList = {}
		for itemString, quantity in pairs(aggregatedMats) do
			local isVendorItem = TSMAPI:GetVendorCost(itemString) ~= nil
			if not isVendorItem then
				local have = TSMCrafting.Inventory:GetTotalQuantity(itemString)
				local need = max(quantity - have, 0)
				if need > 0 then
					local itemName = TSMAPI:GetSafeItemInfo(itemString)
					if itemName then
						tinsert(searchList, itemName .. "/x" .. need)
					end
				end
			end
		end

		if #searchList > 0 then
			local searchString = table.concat(searchList, ";")
			if TSM.StartFilterSearch then
				TSM:StartFilterSearch(searchString)
				TSM:Print("Searching for " .. #searchList .. " materials.")
			else
				TSM:Print("Could not start search.")
			end
		else
			TSM:Print("No materials needed from auction house.")
		end
	end)

	-- Update button states periodically
	frame:SetScript("OnUpdate", function(self, elapsed)
		self.timeSinceLastUpdate = (self.timeSinceLastUpdate or 0) + elapsed
		if self.timeSinceLastUpdate >= 0.5 then
			if MerchantFrame and MerchantFrame:IsVisible() then
				vendorBuyBtn:Enable()
			else
				vendorBuyBtn:Disable()
			end
			self.timeSinceLastUpdate = 0
		end
	end)

	private.frame = frame
	return frame
end

function private.UpdateTaskList()
	if not private.frame then return end

	local TSMCrafting = LibStub("AceAddon-3.0"):GetAddon("TSM_Crafting", true)
	if not TSMCrafting or not TSMCrafting.db or not TSMCrafting.db.realm or not TSMCrafting.Queue then
		private.frame.queueST:SetData({})
		private.frame.matST:SetData({})
		private.frame.profitLabel:SetAmounts("---", "---")
		return
	end

	TSMCrafting:UpdateCraftReverseLookup()
	local queuedCrafts, queuedMats, totalCost, totalProfit = TSMCrafting.Queue:GetQueue()
	private.frame.profitLabel:SetAmounts(totalCost, totalProfit)

	-- Update queue table
	local stData = {}
	local bagTotals = TSMCrafting.Inventory:GetTotals()

	for profession, crafts in pairs(queuedCrafts) do
		local professionColor = "|cffffffff"
		local players = {}
		for player, data in pairs(TSMCrafting.db.realm.tradeSkills) do
			if data[profession] then
				tinsert(players, player)
			end
		end

		local professionCollapsed = TSMCrafting.db.realm.queueStatus.collapsed[profession]
		local row = {
			cols = {
				{
					value = format("%s (%s) %s%s|r", professionColor .. profession .. "|r", "|cffffffff" .. table.concat(players, ", ") .. "|r", TSMAPI.Design:GetInlineColor("link"), professionCollapsed and "[+]" or "[-]")
				}
			},
			isTitle = true,
			profession = profession,
		}
		tinsert(stData, row)

		if not professionCollapsed then
			for _, stage in ipairs(crafts) do
				local stageCollapsed = TSMCrafting.db.realm.queueStatus.collapsed[profession .. stage.name]
				local row = {
					cols = {
						{
							value = format("    %s %s%s|r", stage.name, TSMAPI.Design:GetInlineColor("link"), stageCollapsed and "[+]" or "[-]")
						}
					},
					isTitle = true,
					stage = stage.name,
					profession = profession,
				}
				tinsert(stData, row)

				if not stageCollapsed then
					local craftRows = {}
					for spellID, numQueued in pairs(stage.crafts) do
						local canCraft = math.huge

						for itemID, quantity in pairs(TSMCrafting.db.realm.crafts[spellID].mats) do
							local numHave = bagTotals[itemID] or 0
							canCraft = min(canCraft, floor(numHave / quantity))
						end

						local color
						if canCraft >= numQueued then
							color = "|cff00ff00"
						elseif canCraft > 0 then
							color = "|cff5599ff"
						else
							color = "|cffff7700"
						end

						local row = {
							cols = {
								{
									value = "        " .. color .. TSMCrafting.db.realm.crafts[spellID].name .. " (x" .. numQueued .. ")" .. "|r",
								},
							},
							spellID = spellID,
							canCraft = (canCraft > 0) and canCraft or 0,
							numQueued = numQueued,
							profit = select(3, TSMCrafting.Cost:GetCraftPrices(spellID)),
						}
						tinsert(craftRows, row)
					end

					sort(craftRows, function(a, b)
						if (a.canCraft == 0 and b.canCraft == 0) or (a.canCraft >= a.numQueued and b.canCraft >= b.numQueued) then
							if a.profit and b.profit and a.profit ~= b.profit then
								return a.profit > b.profit
							else
								return a.spellID > b.spellID
							end
						elseif a.canCraft >= a.numQueued then
							return true
						elseif b.canCraft >= b.numQueued then
							return false
						else
							return a.canCraft > b.canCraft
						end
					end)

					for _, row in ipairs(craftRows) do
						tinsert(stData, row)
					end
				end
			end
		end
	end

	private.frame.queueST:SetData(stData)

	-- Update materials table: only raw materials
	stData = {}
	local order = 0
	local aggregatedMats = AggregateRawMaterialsFromQueue(queuedCrafts)

	local sortedMats = {}
	for itemString, totalQuantity in pairs(aggregatedMats) do
		tinsert(sortedMats, {itemString = itemString, quantity = totalQuantity})
	end

	table.sort(sortedMats, function(a, b)
		local aName = TSMCrafting.db.realm.mats[a.itemString] and TSMCrafting.db.realm.mats[a.itemString].name or TSMAPI:GetSafeItemInfo(a.itemString) or "?"
		local bName = TSMCrafting.db.realm.mats[b.itemString] and TSMCrafting.db.realm.mats[b.itemString].name or TSMAPI:GetSafeItemInfo(b.itemString) or "?"
		return aName < bName
	end)

	for _, matInfo in ipairs(sortedMats) do
		local itemString = matInfo.itemString
		local quantity = matInfo.quantity
		local have = TSMCrafting.Inventory:GetTotalQuantity(itemString)
		local need = max(quantity - have, 0)

		local color
		local isVendorItem = TSMAPI:GetVendorCost(itemString) ~= nil

		if need == 0 then
			-- We have enough - check if it's all in bags
			if TSMCrafting.Inventory:GetPlayerBagNum(itemString) >= quantity then
				color = "|cff00ff00" -- Green - all in bags
			else
				color = "|cffffff00" -- Yellow - have enough but not all in bags (bank/alts)
			end
		elseif isVendorItem then
			-- Vendor items are shown in blue
			color = "|cff00bfff"
		else
			-- Missing materials - red
			color = "|cffff0000"
		end

		local matName = TSMCrafting.db.realm.mats[itemString] and TSMCrafting.db.realm.mats[itemString].name or TSMAPI:GetSafeItemInfo(itemString) or "?"

		order = order + 1
		local matRow = {
			cols = {
				{
					value = color .. matName .. " (" .. have .. " / " .. quantity .. ")|r",
					args = { matName },
				},
				{
					value = color .. need .. "|r",
					args = { need },
				},
				{
					value = color .. quantity .. "|r",
					args = { quantity },
				},
			},
			itemString = itemString,
			order = order,
		}
		tinsert(stData, matRow)
	end

	private.frame.matST:SetData(stData)
end

do
	TSM:AddSidebarFeature(L["Task List"], private.Create, private.UpdateTaskList)
end
