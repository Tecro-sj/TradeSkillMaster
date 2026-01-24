-- ------------------------------------------------------------------------------ --
--                            TradeSkillMaster_Crafting                           --
--            http://www.curse.com/addons/wow/tradeskillmaster_crafting           --
--                                                                                --
--             A TradeSkillMaster Addon (http://tradeskillmaster.com)             --
--    All Rights Reserved* - Detailed license information included with addon.    --
-- ------------------------------------------------------------------------------ --

-- create a local reference to the TradeSkillMaster_Crafting table and register a new module
local TSM = select(2, ...)
local GUI = TSM:NewModule("CraftingGUI", "AceEvent-3.0", "AceHook-3.0")
local L = LibStub("AceLocale-3.0"):GetLocale("TradeSkillMaster_Crafting") -- loads the localization table

local priceTextCache = { lastClear = 0 }
local private = {}
private.gather = {}
private.shown = {}

-- list of profession skills that do not have crafting. used by UpdateTradeSkills
local invalidTrade = {
	["Herbalism"] = true,
	["Skinning"] = true,
	["Fishing"] = true,
	["Riding"] = true
}

-- Helper function to find spellID associated to spellname
local function GetTradeSkillSpellID(spellName)
	-- GetTradeSkillRecipeLink ONLY works when a trade skill window is open, but this should always happen
	for i = 1,GetNumTradeSkills() do
		local link = GetTradeSkillRecipeLink(i)
		if link and link:match(spellName) then -- Not a header and spell name found
			local spellID = tonumber(link:match("enchant:(%d+)"))
			if spellID then
				return spellID
			end
		end
	end
	return nil
end

function GUI:OnEnable()
	GUI:RegisterEvent("TRADE_SKILL_SHOW", "ShowProfessionWindow")
	GUI:RegisterEvent("TRADE_SKILL_CLOSE", "EventHandler")
	GUI:RegisterEvent("TRADE_SKILL_UPDATE", "EventHandler")
	GUI:RegisterEvent("TRADE_SKILL_FILTER_UPDATE", "EventHandler")
	GUI:RegisterEvent("UPDATE_TRADESKILL_RECAST", "EventHandler")
	GUI:RegisterEvent("CHAT_MSG_SKILL", "EventHandler")
	GUI:RegisterEvent("UNIT_SPELLCAST_START", "EventHandler")
	GUI:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED", "EventHandler")
	GUI:RegisterEvent("UNIT_SPELLCAST_INTERRUPTED", "EventHandler")
	GUI:RegisterEvent("UNIT_SPELLCAST_FAILED", "EventHandler")
	GUI:RegisterEvent("GUILDBANKFRAME_OPENED", "GatheringEventHandler")
	GUI:RegisterEvent("GUILDBANKFRAME_CLOSED", "GatheringEventHandler")
	GUI:RegisterEvent("GUILDBANKBAGSLOTS_CHANGED", "GatheringEventHandler")
	GUI:RegisterEvent("MERCHANT_SHOW", "GatheringEventHandler")
	GUI:RegisterEvent("MERCHANT_UPDATE", "GatheringEventHandler")
	GUI:RegisterEvent("MERCHANT_CLOSED", "GatheringEventHandler")
	GUI:RegisterEvent("MAIL_SHOW", "GatheringEventHandler")
	GUI:RegisterEvent("MAIL_CLOSED", "GatheringEventHandler")
	GUI:RegisterEvent("BANKFRAME_OPENED", "GatheringEventHandler")
	GUI:RegisterEvent("BANKFRAME_CLOSED", "GatheringEventHandler")
	GUI:RegisterEvent("UPDATE_PENDING_MAIL", "GatheringEventHandler")
	GUI:RegisterEvent("AUCTION_HOUSE_SHOW", "GatheringEventHandler")
	GUI:RegisterEvent("AUCTION_HOUSE_CLOSED", "GatheringEventHandler")
	TSMAPI:CreateTimeDelay("craftingUpdateTradeSkill", 1, function() GUI:UpdateSelectedTradeSkill() end, 0.1)

	TSMAPI:RegisterForBagChange(function()
		TSMAPI:CreateTimeDelay("craftingProfessionUpdateThrottle", 0.05, GUI.UpdateProfessionsTabST)
		TSMAPI:CreateTimeDelay("craftingQueueUpdateThrottle", 0.1, GUI.UpdateQueue)
		TSMAPI:CreateTimeDelay("craftingTaskListUpdateThrottle", 0.1, GUI.UpdateTaskList)
		TSMAPI:CreateTimeDelay("gatheringUpdateThrottle", 0.3, GUI.UpdateGathering)
	end)

	TSMAPI:RegisterForBankChange(function()
		TSMAPI:CreateTimeDelay("gatheringUpdateThrottle", 0.3, GUI.UpdateGathering)
	end)

	GUI:UpdateTradeSkills()
	GUI.gatheringFrame = GUI:CreateGatheringFrame()
	if next(TSM.db.realm.gathering.neededMats) then
		TSMAPI:CreateTimeDelay("gatheringShowThrottle", 0.3, GUI:ShowGatheringFrame())
	end
end

function GUI:ShowGatheringFrame()
	if GUI.gatheringFrame then
		GUI.gatheringFrame:Show()
		if AuctionFrame and AuctionFrame:IsVisible() then
			GUI:GatheringEventHandler("AUCTION_HOUSE_SHOW")
		elseif BankFrame and BankFrame:IsVisible() then
			GUI:GatheringEventHandler("BANKFRAME_OPENED")
		elseif MerchantFrame and MerchantFrame:IsVisible() then
			GUI:GatheringEventHandler("MERCHANT_SHOW")
		elseif GuildBankFrame and GuildBankFrame:IsVisible() then
			GUI:GatheringEventHandler("GUILDBANKFRAME_OPENED")
		end
		GUI:UpdateGathering()
	end
end

function GUI:ShowProfessionWindow()
	if not TradeSkillFrame and not AscensionTradeSkillFrame then return TSMAPI:CreateTimeDelay("craftingShowProfessionDelay", 0, GUI.ShowProfessionWindow) end
	-- if GetTradeSkillLine() == GetSpellInfo(53428) or IsTradeSkillGuild() then
	if GetTradeSkillLine() == GetSpellInfo(53428) then
		-- runeforging or guild profession
		if GUI.frame then
			GUI.noClose = true
			GUI.frame:Hide()
			GUI.noClose = nil
		end
		if GUI.switchBtn then
			GUI.switchBtn:Hide()
		end
		return
	end

	TradeSkillFrame:UnregisterEvent("TRADE_SKILL_SHOW")
	-- AscensionTradeSkillFrame:UnregisterEvent("TRADE_SKILL_SHOW")
	-- AscensionTradeSkillFrame:OpenOldUI()

	GUI:ShowSwitchButton()
	if TSM.db.global.showingDefaultFrame then return end
	GUI:UpdateTradeSkills(GetTradeSkillLine())
	TradeSkillFrame:SetScript("OnHide", nil)
	HideUIPanel(TradeSkillFrame)
	TradeSkillFrame:SetScript("OnHide", function() if not GUI.noClose then GUI.switchBtn:Hide() CloseTradeSkill() end end)
	priceTextCache.lastClear = 0
	GUI.switchBtn:Update()

	if not GUI.frame then
		GUI:CreateGUI()
		if TSM.isSyncing then
			GUI.frame:Hide()
			return TSMAPI:CreateTimeDelay("craftingSyncDelay", 0.1, function() TSM.Sync:OpenTradeSkill() end)
		end
	elseif GUI.frame:IsVisible() then
		if TSM.isSyncing then
			GUI.frame:Hide()
			TSMAPI:CreateTimeDelay("craftingSyncDelay", 0.1, function() TSM.Sync:OpenTradeSkill() end)
		elseif not IsTradeSkillLinked() then
			GUI:SaveFilters()
			GUI:ClearFilters()
			GUI.frame.content.professionsTab.linkBtn:Enable()
			TSMAPI:CreateTimeDelay("craftingScanDelay", 0.1, TSM.Util.ScanCurrentProfession)
		else
			GUI.frame.content.professionsTab.linkBtn:Disable()
		end
		return
	end

	if TSM.isSyncing then
		TSMAPI:CreateTimeDelay("craftingScanDelay", 0, TSM.Util.StartScanSyncedProfessionThread)
	else
		GUI.frame:Show()
		GUI:ShowProfessionsTab()
	end

	if not IsTradeSkillLinked() then
		GUI:SaveFilters()
		GUI:ClearFilters()
		GUI.frame.content.professionsTab.linkBtn:Enable()
		TSMAPI:CreateTimeDelay("craftingScanDelay", 0.1, TSM.Util.ScanCurrentProfession)
	elseif not TSM.isSyncing then
		GUI.frame.content.professionsTab.linkBtn:Disable()
	end
end

function GUI:OpenFirstProfession()
	TSM.db.global.showingDefaultFrame = nil
	local player = UnitName("player")
	local professionName

	for playerName, professions in pairs(TSM.db.realm.tradeSkills) do
		if playerName == player then
			for profession, data in pairs(professions) do
				professionName = profession
				break
			end
			if professionName then break end
		end
	end

	if not professionName then return end

	if professionName == "Mining" then
		CastSpellByName("Smelting")
	else
		CastSpellByName(professionName)
	end
end

function GUI:EventHandler(event, ...)
	if not GUI.frame or not GUI.frame:IsVisible() then return end
	local unittest = ...
	if unittest == "player" or unittest==nil then --Changing tradeskill frames and stuff has "nil" unit, when other players cast this also triggers with nil
		if event == "TRADE_SKILL_CLOSE" then
			GUI.frame:Hide()
		elseif event == "TRADE_SKILL_UPDATE" or event == "TRADE_SKILL_FILTER_UPDATE" then
			if GetTradeSkillLine() ~= GUI.currentTradeSkill or select(2, IsTradeSkillLinked()) ~= GUI.currentLinkedPlayer then
				StopTradeSkillRepeat()
				GUI.currentTradeSkill = GetTradeSkillLine()
				GUI.currentLinkedPlayer = select(2, IsTradeSkillLinked())
			end
			GUI.frame.content.professionsTab:UpdateProfession()
			if (event ~= "TRADE_SKILL_FILTER_UPDATE") and (GetTradeSkillSelectionIndex() > 1) and (GetTradeSkillSelectionIndex() <= GetNumTradeSkills()) then
				TradeSkillFrame_SetSelection(GetTradeSkillSelectionIndex())
			else
				TradeSkillFrame_SetSelection(GetFirstTradeSkill())
			end
			TradeSkillFrame_Update()
			TSMAPI:CreateTimeDelay("craftingProfessionUpdateThrottle", 0.2, GUI.UpdateProfessionsTabST)
			TSMAPI:CreateTimeDelay("craftingQueueUpdateThrottle", 0.2, GUI.UpdateQueue)
			TSMAPI:CreateTimeDelay("craftingTaskListUpdateThrottle", 0.2, GUI.UpdateTaskList)
			if not private.shown[GetTradeSkillLine()] then
				TSMAPI:CreateTimeDelay("firstTimeCraftingProfessionUpdateThrottle", 0.5, GUI.UpdateProfessionsTabST)
				private.shown[GetTradeSkillLine()] = true
			end
		elseif event == "UPDATE_TRADESKILL_RECAST" then
			GUI.frame.content.professionsTab.craftInfoFrame.buttonsFrame.inputBox:SetNumber(GetTradeskillRepeatCount())
		elseif event == "CHAT_MSG_SKILL" and not IsTradeSkillLinked() then
			local skillName, level, maxLevel = GetTradeSkillLine()
			if skillName and skillName ~= "UNKNOWN" and TSM.db.realm.tradeSkills[UnitName("player")] and TSM.db.realm.tradeSkills[UnitName("player")][skillName] then
				TSM.db.realm.tradeSkills[UnitName("player")][skillName].level = level
				TSM.db.realm.tradeSkills[UnitName("player")][skillName].maxLevel = maxLevel
				-- Update the profession dropdown to show the new skill level
				if GUI.frame and GUI.frame.content.professionsTab then
					GUI.frame.content.professionsTab:UpdateProfession()
				end
			end
		elseif event == "UNIT_SPELLCAST_START" then
			local unit = ...
			if unit ~= "player" then return end
			TSM.currentspell = UnitCastingSpellID("player")
		elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
			-- we only care about our spells
			local unit = ...
			if unit ~= "player" then return end
			-- if spell is not related to crafting, ignore
			local craft = TSM.currentspell and TSM.db.realm.crafts[TSM.currentspell]
			if not craft then return end
			-- if spellID == nil then
				-- TSM:Printf("Could not find spellID for %s", spellName)
			-- end

			-- decrements the number of this craft that are queued to be crafted
			craft.queued = max((craft.queued or 0) - 1, 0)
			if GUI.isCrafting and GUI.isCrafting.quantity > 0 then
				GUI.isCrafting.quantity = GUI.isCrafting.quantity - 1
				if GUI.isCrafting.quantity == 0 then
					--GUI:UpdateQueue()
				end
			end
			-- no longer casting a spell so discard spellID
			TSM.currentspell = nil
			-- TSMAPI:CreateTimeDelay("craftingQueueUpdateThrottle", 0.2, GUI.UpdateQueue)
		elseif event == "UNIT_SPELLCAST_INTERRUPTED" or event == "UNIT_SPELLCAST_FAILED" then
			local unit = ...
			if unit ~= "player" then return end

			-- if spellID == nil then
				-- TSM:Printf("Could not find spellID for %s", spellName)
			-- end

			if GUI.isCrafting and TSM.currentspell == GUI.isCrafting.spellID then
				GUI.isCrafting.quantity = 0
				TSMAPI:CreateTimeDelay("craftingQueueUpdateThrottle", 0.2, GUI.UpdateQueue)
			end
			-- no longer casting a spell so discard spellID
			TSM.currentspell = nil
	end
	end
end

function GUI:UpdateTradeSkills(...)
	-- Get player name
	local playerName = UnitName("player")
	if not playerName then return end

	local filterTrade = ... -- only re-index the specific trade skill if told to

	local inProfessions = false
	local inSecondary = false
	local old = TSM.db.realm.tradeSkills[playerName]

	TSM.db.realm.tradeSkills[playerName] = TSM.db.realm.tradeSkills[playerName] or {} -- initialize player data if not found

	-- for each trade skill found, add it to the db
	for i = 1, GetNumSkillLines() do
		local skillName, _, _, skillRank, _, _, skillMaxRank = GetSkillLineInfo(i)
		if  skillName == "Professions" then
			inProfessions = true
		elseif  skillName == "Secondary Skills" then
			inProfessions = false
			inSecondary = true
		elseif  skillName == "Weapon Skills" then
			inSecondary = false
		elseif  inProfessions == true or inSecondary == true then
			if skillName ~= nil and (not filterTrade or filterTrade == skillName) and not invalidTrade[skillName] then
--				if skillName == "Mining" then skillName = "Smelting" end -- bandaid for mining as related spell is different than craft
				TSM.db.realm.tradeSkills[playerName][skillName] = old[skillName] or {}
				TSM.db.realm.tradeSkills[playerName][skillName].level = skillRank
				TSM.db.realm.tradeSkills[playerName][skillName].maxLevel = skillMaxRank
				TSM.db.realm.tradeSkills[playerName][skillName].isSecondary = inSecondary

				-- local spellBookSlot = btns[i]:GetID() + btns[i]:GetParent().spellOffset
				local _, link = GetSpellLink(skillName)
				if link then
					TSM.db.realm.tradeSkills[playerName][skillName].link = link
					if skillName == GetTradeSkillLine() and inProfessions == true and not TSM.isSyncing then
						TSM.db.realm.tradeSkills[playerName][skillName].account = nil
						TSM.db.realm.tradeSkills[playerName][skillName].accountKey = TSMAPI.Sync:GetAccountKey()
						TSM.Sync:BroadcastTradeSkillData()
					end
				end
			end
		end
	end


	--tidy up crafts if player unlearned a profession
	for spellid, data in pairs(TSM.db.realm.crafts) do
		for player in pairs(data.players) do
			if not TSM.db.realm.tradeSkills[player] or not TSM.db.realm.tradeSkills[player][data.profession] then
				TSM.db.realm.crafts[spellid].players[player] = nil
			end
		end
	end

	--remove craft if no players
	for spellid, data in pairs(TSM.db.realm.crafts) do
		if not next(data.players) then
			TSM.db.realm.crafts[spellid] = nil
		end
	end
end

function GUI:SaveFilters()
	local filters = {}
	filters.search = GetTradeSkillItemNameFilter()
	filters.headers = {}
	local hasHeaderCollapsed
	for i = 1, GetNumTradeSkills() do
		local name, t, _, e = GetTradeSkillInfo(i)
		if t == "header" or t == "subheader" then
			filters.headers[name] = e
			if not e then
				hasHeaderCollapsed = true
			end
		end
	end
	if not hasHeaderCollapsed then
		filters.headers = nil
	end
	private.professionFilters = filters
end

function GUI:RestoreFilters()
	if not private.professionFilters then return end
	GUI:ClearFilters()
	SetTradeSkillItemNameFilter(private.professionFilters.search)
	if private.professionFilters.headers then
		for i = 1, GetNumTradeSkills() do
			local name, t, _, e = GetTradeSkillInfo(i)
			if t == "header" or t == "subheader" then
				if private.professionFilters.headers[name] ~= e then
					if private.professionFilters.headers[name] then
						ExpandTradeSkillSubClass(i)
					else
						CollapseTradeSkillSubClass(i)
					end
				end
			end
		end
	end
	if private.professionFilters.search then
		GUI.frame.content.professionsTab.searchBar:SetTextColor(1, 1, 1, 1)
		GUI.frame.content.professionsTab.searchBar:SetText(private.professionFilters.search)
	else
		GUI.frame.content.professionsTab.searchBar:SetTextColor(1, 1, 1, 0.5)
		GUI.frame.content.professionsTab.searchBar:SetText(SEARCH)
	end
	GUI.frame.content.professionsTab.searchBar:ClearFocus()
end

function GUI:ClearFilters()
	-- close the dropdown and uncheck the buttons
	CloseDropDownMenus()
	-- local id = TradeSkillLinkDropDown:GetID()
	-- local id = 1
	-- local skillupButton = _G["DropDownList" .. id .. "Button1"]
	-- local makeableButton = _G["DropDownList" .. id .. "Button2"]
	-- if skillupButton and skillupButton.checked and skillupButton.value == CRAFT_IS_MAKEABLE then
		-- UIDropDownMenuButton_OnClick(_G["DropDownList" .. id .. "Button1"])
	-- end
	-- if makeableButton and makeableButton.checked and makeableButton.value == TRADESKILL_FILTER_HAS_SKILL_UP then
		-- UIDropDownMenuButton_OnClick(_G["DropDownList" .. id .. "Button2"])
	-- end
	-- TradeSkillOnlyShowMakeable(false)
	-- TradeSkillOnlyShowSkillUps(false)
	SetTradeSkillInvSlotFilter(0,1,1)
	SetTradeSkillSubClassFilter(0,1,1)
	GUI.frame.content.professionsTab.HaveMatsCheckBox:SetValue(false)
	TradeSkillFrameAvailableFilterCheckButton:SetChecked(false)
	TradeSkillOnlyShowMakeable(false)
	TradeSkillFrame_Update()
	-- TradeSkillSetFilter(-1, -1)
	SetTradeSkillItemNameFilter("")
	ExpandTradeSkillSubClass(0)
	for i = 1, GetNumTradeSkills() do
			local _, t, _, e = GetTradeSkillInfo(i)
			if not e and (t == "header" or t == "subheader") then
				ExpandTradeSkillSubClass(i)
			end
	end
	GUI.frame.content.professionsTab.searchBar:SetTextColor(1, 1, 1, 0.5)
	GUI.frame.content.professionsTab.searchBar:SetText(SEARCH)
	GUI.frame.content.professionsTab.searchBar:ClearFocus()
end

function GUI:CastTradeSkill(index, quantity, vellum)
	SelectTradeSkill(index)
	quantity = vellum and 1 or quantity
	DoTradeSkill(index, quantity)
	GUI.isCrafting = { quantity = quantity, spellID = TSM.Util:GetSpellID(index) }
	if vellum then
		UseItemByName(vellum)
	end
	-- Update task list after crafting
	TSMAPI:CreateTimeDelay("craftingTaskListUpdateAfterCraft", 0.5, GUI.UpdateTaskList)
end


function GUI:ShowSwitchButton()
	if not GUI.switchBtn then
		local btn = TSMAPI.GUI:CreateButton(UIParent, 16)
		btn:SetText(TSMAPI.Design:GetInlineColor("link") .. DEFAULT .. "|r")
		btn.Update = function(self)
			self:Show()
			if TSM.db.global.showingDefaultFrame then
				self:SetParent(TradeSkillFrame)
				self:SetPoint("TOPLEFT", 55, -3)
				self:SetWidth(60)
				self:SetHeight(18)
				self:SetText(TSMAPI.Design:GetInlineColor("link") .. "TSM|r")
			else
				if not GUI.frame then return TSMAPI:CreateTimeDelay("craftingSwitchBtn", 0.05, function() self:Update() end) end
				self:SetParent(GUI.frame)
				self:SetPoint("TOPLEFT", 4, -4)
				self:SetWidth(60)
				self:SetHeight(18)
				self:SetText(TSMAPI.Design:GetInlineColor("advanced") .. DEFAULT .. "|r")
			end
		end
		btn:SetScript("OnClick", function(self)
			GUI.noClose = true
			if TSM.db.global.showingDefaultFrame then
				TSM.db.global.showingDefaultFrame = nil
				GUI:ShowProfessionWindow()
			else
				TSM.db.global.showingDefaultFrame = true
				ShowUIPanel(TradeSkillFrame)
				GUI.frame:Hide()
			end
			GUI.noClose = nil
			btn:Update()
		end)
		GUI.switchBtn = btn
	end
	GUI.switchBtn:Show()
	GUI.switchBtn:Update()
end

function GUI:CreateGUI()
	local frameDefaults = {
		x = 100,
		y = 300,
		width = 450,
		height = 500,
		scale = 1,
	}
	local frame = TSMAPI:CreateMovableFrame("TSMCraftingTradeSkillFrame", frameDefaults)
	frame:SetResizable(true)
	frame:SetMinResize(450, 400)
	TSMAPI.Design:SetFrameBackdropColor(frame)
	frame:Show()
	frame:SetScript("OnHide", function() if not GUI.noClose then GUI.switchBtn:Hide() TradeSkillFrame:Show() CloseTradeSkill() end end)
	tinsert(UISpecialFrames, "TSMCraftingTradeSkillFrame")
	GUI.frame = frame

	frame.prompt = GUI:CreatePromptFrame(frame)

	frame.queue = GUI:CreateQueueFrame(frame)
	frame.queue:Hide()

	frame.gather = GUI:CreateGatheringSelectionFrame(frame)
	frame.gather:Hide()
	GUI:UpdateGatherSelectionWindow()

	frame.navFrame = GUI:CreateNavFrame(frame)
	TSMAPI.GUI:CreateHorizontalLine(frame, -55)

	local content = CreateFrame("Frame", nil, frame)
	content:SetPoint("TOPLEFT", 0, -59)
	content:SetPoint("BOTTOMRIGHT")
	frame.content = content

	local line = TSMAPI.GUI:CreateVerticalLine(frame, 0)
	line:ClearAllPoints()
	line:SetPoint("TOPRIGHT", -25, -1)
	line:SetWidth(2)
	line:SetHeight(25)

	local closeBtn = TSMAPI.GUI:CreateButton(frame, 18)
	closeBtn:SetPoint("TOPRIGHT", -3, -3)
	closeBtn:SetWidth(19)
	closeBtn:SetHeight(19)
	closeBtn:SetText("X")
	closeBtn:SetScript("OnClick", function() frame:Hide() end)
	frame.closeBtn = closeBtn

	content.professionsTab = GUI:CreateProfessionsTab(content)
	content.groupsTab = GUI:CreateGroupsTab(content)
end

function GUI:CreateQueueFrame(parent)
	local frame = CreateFrame("Frame", nil, parent)
	frame:SetPoint("TOPLEFT", parent, "TOPRIGHT", 2, 0)
	frame:SetPoint("BOTTOMLEFT", parent, "BOTTOMRIGHT", 2, 0)
	frame:SetWidth(300)
	frame:EnableMouse(true)
	frame:SetScript("OnMouseDown", function() parent:StartMoving() end)
	frame:SetScript("OnMouseUp", function() parent:StopMovingOrSizing() end)
	TSMAPI.Design:SetFrameBackdropColor(frame)

	local stContainer = CreateFrame("Frame", nil, frame)
	stContainer:SetPoint("TOPLEFT", 5, -5)
	stContainer:SetPoint("BOTTOMRIGHT", frame, "RIGHT", -5, 5)
	TSMAPI.Design:SetFrameColor(stContainer)

	local stCols = {
		{ name = L["Craft Queue"], width = 1, align = "Left" },
	}

	local function OnCraftRowEnter(self, data)
		if not data.spellID then return end
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
		GameTooltip:SetOwner(self, "ANCHOR_NONE")
		-- GameTooltip:SetPoint("LEFT", self, "RIGHT")
		GameTooltip:SetPoint("LEFT", self, "LEFT")
		GameTooltip:AddLine(TSM.db.realm.crafts[data.spellID].name .. " (x" .. data.numQueued .. ")")

		local cost = TSM.Cost:GetCraftPrices(data.spellID)
		if data.profit then
			local profitPercent = data.profit / cost * 100
			local profitPercText = format("%s%.0f%%|r", color, profitPercent)
			local profitPercentM = data.profit / cost * data.numQueued * 100
			local profitPercTextM = format("%s%.0f%%|r", color, profitPercentM)
			if data.profit>0 then
				if moneyCoinsTooltip then
					GameTooltip:AddLine("Profit: " .. (TSMAPI:FormatTextMoneyIcon(data.profit, color) or "---") .. " (" .. (profitPercText or "---") .. ")")
				else
					GameTooltip:AddLine("Profit: " .. (TSMAPI:FormatTextMoney(data.profit, color) or "---") .. " (" .. (profitPercText or "---") .. ")")
				end
				if data.numQueued>1 then
					if moneyCoinsTooltip then
						GameTooltip:AddLine("Total Profit: " .. (TSMAPI:FormatTextMoneyIcon(totalProfit, color) or "---") .. " (" .. (profitPercTextM or "---") .. ")")
					else
						GameTooltip:AddLine("Total Profit: " .. (TSMAPI:FormatTextMoney(totalProfit, color) or "---") .. " (" .. (profitPercTextM or "---") .. ")")
					end
				end
			else
				if moneyCoinsTooltip then
					GameTooltip:AddLine("Loss: " .. (TSMAPI:FormatTextMoneyIcon(data.profit, color) or "---") .. " (" .. (profitPercText or "---") .. ")")
				else
					GameTooltip:AddLine("Loss: " .. (TSMAPI:FormatTextMoney(data.profit, color) or "---") .. " (" .. (profitPercText or "---") .. ")")
				end
				if data.numQueued>1 then
					if moneyCoinsTooltip then
						GameTooltip:AddLine("Total Loss: " .. (TSMAPI:FormatTextMoneyIcon(totalProfit, color) or "---") .. " (" .. (profitPercTextM or "---") .. ")")
					else
						GameTooltip:AddLine("Total Loss: " .. (TSMAPI:FormatTextMoney(totalProfit, color) or "---") .. " (" .. (profitPercTextM or "---") .. ")")
					end
				end
			end
		end

		GameTooltip:AddLine(" ")
		if moneyCoinsTooltip then
			GameTooltip:AddLine("Crafting Cost: " .. (TSMAPI:FormatTextMoneyIcon(cost, "|cffffff00") or "---"))
		else
			GameTooltip:AddLine("Crafting Cost: " .. (TSMAPI:FormatTextMoney(cost, "|cffffff00") or "---"))
		end
		if data.numQueued>1 then
			local totalcost = cost and cost * data.numQueued
			if moneyCoinsTooltip then
				GameTooltip:AddLine("Total Cost: " .. (TSMAPI:FormatTextMoneyIcon(totalcost, "|cffffff00") or "---"))
			else
				GameTooltip:AddLine("Total Cost: " .. (TSMAPI:FormatTextMoney(totalcost, "|cffffff00") or "---"))
			end
		end

		for itemID, matQuantity in pairs(TSM.db.realm.crafts[data.spellID].mats) do
			local name = TSMAPI:GetSafeItemInfo(itemID) or (TSM.db.realm.mats[itemID] and TSM.db.realm.mats[itemID].name) or "?"

			local itemIDx = itemID

			-- Get Cheapest vellum, lower vellum types can be replaced by III
			local velName
			if strfind(name, "Vellum") then
				velName = name
			end
			if (velName ~= nil) then
				if strfind(velName, "Weapon") then
					itemIDx = "item:52511:0:0:0:0:0:0"
					name = TSMAPI:GetSafeItemInfo(itemIDx)
				else
					itemIDx = "item:52510:0:0:0:0:0:0"
					name = TSMAPI:GetSafeItemInfo(itemIDx)
				end
			end

			local inventory = TSM.Inventory:GetPlayerBagNum(itemIDx)
			local need = matQuantity * data.numQueued
			local color
			local isVendorItem = TSMAPI:GetVendorCost(itemIDx) ~= nil
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

	local function OnCraftRowClicked(_, data, _, button)
		if button == "RightButton" and data.index then
			if data.profession == GetTradeSkillLine() then
				TradeSkillFrame_SetSelection(data.index)
				TradeSkillFrame_Update()
				GUI:UpdateSelectedTradeSkill(true)
				GUI.frame.content.professionsTab.st:SetScrollOffset(max(0, data.index - 1))
			end
		else
			if data.isTitle then
				if data.stage then
					TSM.db.realm.queueStatus.collapsed[data.profession .. data.stage] = not TSM.db.realm.queueStatus.collapsed[data.profession .. data.stage]
				else
					TSM.db.realm.queueStatus.collapsed[data.profession] = not TSM.db.realm.queueStatus.collapsed[data.profession]
				end
				GUI:UpdateQueue()
			elseif data.index then
				GUI:CastTradeSkill(data.index, min(data.canCraft, data.numQueued), data.velName)
			end
		end
	end

	frame.craftST = TSMAPI:CreateScrollingTable(stContainer, stCols, { OnClick = OnCraftRowClicked, OnEnter = OnCraftRowEnter, OnLeave = OnCraftRowLeave }, 14)
	frame.craftST:SetData({})
	frame.craftST:DisableSelection(true)

	local line = TSMAPI.GUI:CreateHorizontalLine(frame, 0)
	local height = line:GetHeight()
	line:ClearAllPoints()
	line:SetPoint("LEFT")
	line:SetPoint("RIGHT")
	line:SetHeight(height)

	-- Materials by craft table - fills remaining space
	local stContainer2 = CreateFrame("Frame", nil, frame)
	stContainer2:SetPoint("TOPLEFT", frame, "LEFT", 5, -5)
	stContainer2:SetPoint("TOPRIGHT", -5, -5)
	stContainer2:SetPoint("BOTTOMLEFT", 5, 110)
	stContainer2:SetPoint("BOTTOMRIGHT", -5, 110)
	TSMAPI.Design:SetFrameColor(stContainer2)

	local stCols = {
		{ name = L["Material Name"], width = 0.49, align = "Left" },
		{ name = L["Need"], width = 0.115, align = "LEFT" },
		{ name = L["Total"], width = 0.115, align = "LEFT" },
		{ name = L["Cost"], width = 0.28, align = "LEFT" },
	}

	local function MatOnEnter(_, data, col)
		GameTooltip:SetOwner(col, "ANCHOR_RIGHT")
		TSMAPI:SafeTooltipLink(data.itemString)
		GameTooltip:Show()
	end

	local function MatOnLeave(_, data)
		GameTooltip:Hide()
	end

	local function MatOnClick(_, data)
		if IsModifiedClick() then
			local link = select(2, TSMAPI:GetSafeItemInfo(data.itemString))
			HandleModifiedItemClick(link or data.itemString)
		else
			-- Try to buy from vendor if merchant frame is open
			if MerchantFrame and MerchantFrame:IsVisible() then
				local itemID = TSMAPI:GetItemID(data.itemString)
				if itemID then
					-- Find item in merchant inventory
					local numItems = GetMerchantNumItems()
					for i = 1, numItems do
						local merchantItemLink = GetMerchantItemLink(i)
						local merchantItemID = merchantItemLink and tonumber(string.match(merchantItemLink, "item:(%d+)"))
						if merchantItemID == itemID then
							-- Calculate how many we need
							local have = TSM.Inventory:GetTotalQuantity(data.itemString)
							local need = data.cols[2].args[1] -- This is the "Need" value
							if need > 0 then
								-- Get stack size and buy enough stacks
								local _, _, _, quantity = GetMerchantItemInfo(i)
								local stacksToBuy = ceil(need / quantity)
								for j = 1, stacksToBuy do
									BuyMerchantItem(i, 1)
								end
								-- Refresh task list after purchase
								TSMAPI:CreateTimeDelay("craftingTaskListUpdateAfterVendorBuy", 0.3, GUI.UpdateTaskList)
								return
							end
						end
					end
				end
			end
		end
	end

	frame.matST = TSMAPI:CreateScrollingTable(stContainer2, stCols, { OnEnter = MatOnEnter, OnLeave = MatOnLeave, OnClick = MatOnClick }, 12)
	frame.matST:SetData({})
	frame.matST:DisableSelection(true)

	local profitLabel = TSMAPI.GUI:CreateLabel(frame, "medium")
	profitLabel:SetPoint("BOTTOMLEFT", 5, 85)
	profitLabel:SetPoint("BOTTOMRIGHT", -5, 85)
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
		self:SetText(format(L["Estimated Cost: %s\nEstimated Profit: %s"], cost, profit))
	end
	profitLabel:SetAmounts("---", "---")
	frame.profitLabel = profitLabel

	local line = TSMAPI.GUI:CreateHorizontalLine(frame, 0)
	local height = line:GetHeight()
	line:ClearAllPoints()
	line:SetPoint("BOTTOMLEFT", 0, 28)
	line:SetPoint("BOTTOMRIGHT", 0, 28)
	line:SetHeight(height)

	local btn = TSMAPI.GUI:CreateButton(frame, 14)
	btn:SetPoint("BOTTOMLEFT", 5, 5)
	btn:SetWidth(120)
	btn:SetHeight(20)
	btn:SetText(L["Clear Queue"])
	btn:SetScript("OnClick", function()
		TSM.Queue:ClearQueue()
		GUI:UpdateQueue()
		if GUI.frame.gather:IsVisible() then
			GUI.frame.gather:Hide()
		end
		private.gather = {}
		GUI:UpdateGatherSelectionWindow()
		if GUI.gatheringFrame:IsShown() then
			GUI.gatheringFrame:Hide()
			TSM.db.realm.gathering.crafter = nil
			TSM.db.realm.gathering.neededMats = {}
			TSM.db.realm.gathering.gatheredMats = false
			TSM.db.realm.sourceStatus.collapsed = {}
		end
	end)
	frame.clearBtn = btn

	local btn = TSMAPI.GUI:CreateButton(frame, 18, "TSMCraftNextButton")
	btn:SetPoint("BOTTOMLEFT", frame.clearBtn, "BOTTOMRIGHT", 5, 0)
	btn:SetPoint("BOTTOMRIGHT", -5, 5)
	btn:SetHeight(20)
	btn:SetText(L["Craft Next"])
	-- btn:SetScript("OnUpdate", function(self)
		-- if UnitCastingInfo("player") or not GUI.craftNextInfo then
			-- self:Disable()
		-- elseif GUI.isCrafting and GUI.isCrafting.quantity > 0 then
			-- self:Disable()
		-- else
			-- self:Enable()
		-- end
	-- end)
	btn:SetScript("OnClick", function(self)
		if UnitCastingInfo("player") or not GUI.craftNextInfo or not self:IsVisible() then return end
		GUI:CastTradeSkill(GUI.craftNextInfo.index, GUI.craftNextInfo.quantity, GUI.craftNextInfo.velName)
		self:Disable()
	end)
	frame.craftNextbtn = btn

	return frame
end

function GUI:CreateNavFrame(frame)
	local navFrame = CreateFrame("Frame", nil, frame)
	navFrame:SetPoint("TOPLEFT", 0, -25)
	navFrame:SetPoint("TOPRIGHT", 0, -25)
	navFrame:SetHeight(30)

	TSMAPI.GUI:CreateHorizontalLine(frame, -25)

	local title = navFrame:CreateFontString()
	title:SetFont(TSMAPI.Design:GetContentFont(), 18)
	TSMAPI.Design:SetWidgetLabelColor(title)
	title:SetPoint("TOP", frame, 0, -3)
	local version = TSM._version
	if strfind(version, "@") then version = "Dev" end
	title:SetText(format("TSM_Crafting - %s", version))

	local btn = TSMAPI.GUI:CreateButton(navFrame, 16)
	btn:SetPoint("TOPLEFT", 5, -5)
	btn:SetPoint("BOTTOMLEFT", 5, 5)
	btn:SetWidth(105)
	btn:SetText(L["Professions"])
	btn:SetScript("OnClick", GUI.ShowProfessionsTab)
	navFrame.professionsBtn = btn

	local btn = TSMAPI.GUI:CreateButton(navFrame, 16)
	btn:SetPoint("TOPLEFT", navFrame.professionsBtn, "TOPRIGHT", 5, 0)
	btn:SetPoint("BOTTOMLEFT", navFrame.professionsBtn, "BOTTOMRIGHT", 5, 0)
	btn:SetWidth(105)
	btn:SetText(L["TSM Groups"])
	btn:SetScript("OnClick", GUI.ShowGroupsTab)
	navFrame.groupsBtn = btn

	TSMAPI.GUI:CreateVerticalLine(navFrame, 224)

	local btn = TSMAPI.GUI:CreateButton(navFrame, 16)
	btn:SetPoint("TOPLEFT", navFrame.groupsBtn, "TOPRIGHT", 10, 0)
	btn:SetPoint("BOTTOMLEFT", navFrame.groupsBtn, "BOTTOMRIGHT", 10, 0)
	btn:SetWidth(60)
	btn:SetText(L["Gather"])
	btn:SetScript("OnClick", function(self)
		local queuedCrafts = TSM.Queue:GetQueue()
		if not next(queuedCrafts) then return end
		if GUI.frame.queue:IsVisible() then
			GUI.frame.gather:SetPoint("TOPLEFT", GUI.frame.queue, "TOPRIGHT", 2, 0)
		else
			GUI.frame.gather:SetPoint("TOPLEFT", frame, "TOPRIGHT", 2, 0)
		end

		if GUI.frame.gather:IsVisible() then
			GUI.frame.gather:Hide()
		else
			GUI.frame.gather:Show()
			GUI:UpdateGatherSelectionWindow()
		end
	end)
	navFrame.gatherBtn = btn

	TSMAPI.GUI:CreateVerticalLine(navFrame, 294)

	local btn = TSMAPI.GUI:CreateButton(navFrame, 16)
	btn:Hide()
	btn:SetPoint("TOPLEFT", navFrame.gatherBtn, "TOPRIGHT", 10, 0)
	btn:SetPoint("BOTTOMLEFT", navFrame.gatherBtn, "BOTTOMRIGHT", 10, 0)
	btn:SetPoint("TOPRIGHT", -5, -5)
	btn.UpdateQueueStatus = function(self)
		if TSM.db.global.frameQueueOpen then
			GUI.frame.queue:Show()
			self:SetText(L["<< Hide Queue"])
			GUI:UpdateQueue()
			if GUI.frame.gather:IsVisible() then
				GUI.frame.gather:SetPoint("TOPLEFT", GUI.frame.queue, "TOPRIGHT", 2, 0)
			end
		else
			GUI.frame.queue:Hide()
			self:SetText(L["Show Queue >>"])
			if GUI.frame.gather:IsVisible() then
				GUI.frame.gather:SetPoint("TOPLEFT", frame, "TOPRIGHT", 2, 0)
			end
		end
	end
	btn:SetScript("OnClick", function(self)
		if GUI.frame.queue:IsVisible() then
			TSM.db.global.frameQueueOpen = nil
		else
			TSM.db.global.frameQueueOpen = true
		end
		self:UpdateQueueStatus()
	end)
	btn:SetScript("OnShow", btn.UpdateQueueStatus)
	btn:Show()
	navFrame.queueBtn = btn

	return navFrame
end

local QuickRestock = false
function GUI:CreateProfessionsTab(parent)
	local frame = CreateFrame("Frame", nil, parent)
	frame:SetAllPoints()
	frame:Hide()

	local currentSelection
	local player = UnitName("player")
	local function UpdateProfession(self)
		-- Don't update the dropdown while it's open to prevent list from disappearing
		if self.dropdown.open then
			return
		end

		local list = {}
		local order = {}

		-- Collect all players and sort them alphabetically
		local players = {}
		for playerName in pairs(TSM.db.realm.tradeSkills) do
			tinsert(players, playerName)
		end
		sort(players)

		-- For each player, collect and sort their professions
		for _, playerName in ipairs(players) do
			local professionData = TSM.db.realm.tradeSkills[playerName]
			local professions = {}

			-- Collect professions for this player
			for name, data in pairs(professionData) do
				-- Show all professions (including secondary like Cooking, First Aid)
				-- Only filter out non-crafting professions (already handled by invalidTrade in UpdateTradeSkills)
				tinsert(professions, {name = name, data = data})
			end

			-- Sort professions: Primary first, then secondary; alphabetically within each group
			sort(professions, function(a, b)
				local aSecondary = a.data.isSecondary and 1 or 0
				local bSecondary = b.data.isSecondary and 1 or 0
				if aSecondary ~= bSecondary then
					return aSecondary < bSecondary
				end
				return a.name < b.name
			end)

			-- Add professions to list in sorted order, grouped by player
			for _, prof in ipairs(professions) do
				local key = playerName .. "~" .. prof.name
				local skillText = format("%d/%d", prof.data.level or 0, prof.data.maxLevel or 0)
				-- Format: "CharakterName - Beruf (Skill)"
				list[key] = format("%s - %s (%s)", playerName, prof.name, skillText)
				tinsert(order, key)
			end
		end

		self.dropdown:SetList(list, order)

		local playerName = select(2, IsTradeSkillLinked()) or player
		local professionName, level, maxLevel = GetTradeSkillLine()
		-- Format: "CharakterName - Beruf (Skill)" to match the dropdown entries
		local professionString = format("%s - %s (%d/%d)", playerName, professionName, level, maxLevel)
		currentSelection = playerName .. "~" .. professionName
		self.dropdown:SetValue(currentSelection)
		if not list[playerName .. "~" .. professionName] then
			self.dropdown:SetText(professionString)
		end
	end

	frame.UpdateProfession = UpdateProfession
	frame:SetScript("OnShow", UpdateProfession)

	local function OnValueChanged(_, _, index)
		local playerName, profession = ("~"):split(index)
		if playerName == player then
			if profession == "Mining" then
				CastSpellByName("Smelting")
			else
				CastSpellByName(profession)
			end
		else
			local link = TSM.db.realm.tradeSkills[playerName][profession].link
			if not link then
				TSM:Printf(L["Profession data not found for %s on %s. Logging into this player and opening the profession may solve this issue."], profession, playerName)
				return OnValueChanged(_, _, currentSelection)
			end
			local tradeString = strsub(select(3, ("|"):split(link)), 2)
			SetItemRef(tradeString, link)
		end
		currentSelection = index
	end

	local dd = TSMAPI.GUI:CreateDropdown(frame, {}, L["Select one of your characters' professions to browse."])
	dd.frame:SetPoint("TOPLEFT", 3, -4)
	-- dd.frame:SetPoint("TOPRIGHT", -47, -4)
	dd.frame:SetWidth(256)
	dd:SetCallback("OnValueChanged", OnValueChanged)
	frame.dropdown = dd

	local HaveMatsCheckBox = TSMAPI.GUI:CreateCheckBox(frame)
	HaveMatsCheckBox:SetLabel(" Have Mats")
	HaveMatsCheckBox:SetPoint("TOPLEFT", 252, -4)
	HaveMatsCheckBox:SetWidth(90)
	HaveMatsCheckBox:SetHeight(26)
	frame.HaveMatsCheckBox = HaveMatsCheckBox
	HaveMatsCheckBox:SetCallback("OnValueChanged", function(_, _, value)
			TradeSkillFrameAvailableFilterCheckButton:SetChecked(value)
			TradeSkillOnlyShowMakeable(value)
		end)

	local RestockBtn = TSMAPI.GUI:CreateButton(frame, 14)
	RestockBtn:SetPoint("TOPRIGHT", -50, -4)
	RestockBtn:SetWidth(56)
	RestockBtn:SetHeight(26)
	RestockBtn:SetText("Restock")
	RestockBtn:SetScript("OnClick", function(self)
		QuickRestock = true
		GUI.ShowGroupsTab()
	end)

	local linkBtn = TSMAPI.GUI:CreateButton(frame, 14)
	linkBtn:SetPoint("TOPRIGHT", -5, -4)
	linkBtn:SetWidth(40)
	linkBtn:SetHeight(26)
	linkBtn:SetText(L["Link"])
	linkBtn:SetScript("OnClick", function(self)
		local link = GetTradeSkillListLink()
		if not link then return TSM:Print(L["Could not get link for profession."]) end

		local activeEditBox = ChatEdit_GetActiveWindow()
		if MacroFrameText and MacroFrameText:IsShown() and MacroFrameText:HasFocus() then
			local text = MacroFrameText:GetText() .. link
			if strlenutf8(text) <= 255 then
				MacroFrameText:Insert(link)
			end
		elseif activeEditBox then
			ChatEdit_InsertLink(link)
		end
	end)
	frame.linkBtn = linkBtn

	local function InsertLink(link)
		local putIntoChat, v1, v2, v3 = GUI.hooks.ChatEdit_InsertLink(link)
		local hoverButton = GetMouseFocus()
		if not putIntoChat and frame:IsVisible() and not (hoverButton and hoverButton:GetName() and strfind(hoverButton:GetName(), "MerchantItem([0-9]+)ItemButton")) then
			local name = TSMAPI:GetSafeItemInfo(link)
			if name then
				frame.searchBar:SetText(name)
				frame.searchBar:SetTextColor(1, 1, 1, 1)
				return true
			end
		end
		return putIntoChat
	end

	GUI:RawHook("ChatEdit_InsertLink", InsertLink, true)

	local searchBar = TSMAPI.GUI:CreateInputBox(frame, "TSMCraftingSearchBar")
	searchBar:SetPoint("TOPLEFT", 5, -35)
	searchBar:SetWidth(220) --(240)
	searchBar:SetHeight(24)
	searchBar:SetText(SEARCH)
	searchBar:SetTextColor(1, 1, 1, 0.5)
	searchBar:SetScript("OnEditFocusGained", function(self)
		self:SetTextColor(1, 1, 1, 1)
		if self:GetText() == SEARCH then
			self:SetText("")
		end
	end)
	searchBar:SetScript("OnEditFocusLost", function(self)
		if self:GetText() == "" or self:GetText() == SEARCH then
			self:SetTextColor(1, 1, 1, 0.5)
			self:SetText(SEARCH)
		end
	end)
	searchBar:SetScript("OnTextChanged", function(self)
		local text = self:GetText()
		SetTradeSkillItemNameFilter(text == SEARCH and "" or text)
		GUI:UpdateProfessionsTabST()
	end)
	searchBar:SetScript("OnEnterPressed", searchBar.ClearFocus)
	frame.searchBar = searchBar

	local btn = TSMAPI.GUI:CreateButton(frame, 14)
	btn:SetPoint("TOPLEFT", searchBar, "TOPRIGHT", 5, 0)
	btn:SetWidth(80)
	btn:SetHeight(24)
	btn:SetText(L["Clear Filters"])
	btn:SetScript("OnClick", GUI.ClearFilters)
	frame.clearFilterBtn = btn

	-- local btn = TSMAPI.GUI:CreateButton(frame, 14, "TSMCraftingFilterButton")
	-- btn:SetPoint("TOPLEFT", frame.clearFilterBtn, "TOPRIGHT", 5, 0)
	-- btn:SetPoint("TOPRIGHT", -5, -35)
	-- btn:SetHeight(24)
	-- btn:SetText(L["Filters >>"])
	-- btn:SetScript("OnClick", function(self) ToggleDropDownMenu(1, nil, TradeSkillFilterDropDown, "TSMCraftingFilterButton", btn:GetWidth(), 0) end)
	-- frame.filterBtn = btn

	local btn = TSMAPI.GUI:CreateButton(frame, 14, "TSMCraftingFilterButton")
	btn:SetPoint("TOPLEFT", frame.clearFilterBtn, "TOPRIGHT", 5, 0)
	btn:SetWidth(80)
	btn:SetHeight(24)
	btn:SetText("Subclass >>")
	btn:SetScript("OnClick", function(self) ToggleDropDownMenu(1, nil, TradeSkillSubClassDropDown, "TSMCraftingFilter2Button", -84, 0) end)
	frame.filterBtn = btn

	local btn = TSMAPI.GUI:CreateButton(frame, 14, "TSMCraftingFilter2Button")
	btn:SetPoint("TOPLEFT", frame.filterBtn, "TOPRIGHT", 5, 0)
	btn:SetPoint("TOPRIGHT", -5, -35)
	btn:SetHeight(24)
	btn:SetText("Slot >>")
	btn:SetScript("OnClick", function(self) ToggleDropDownMenu(1, nil, TradeSkillInvSlotDropDown, "TSMCraftingFilter2Button", 0, 0) end)
	frame.filter2Btn = btn

	TSMAPI.GUI:CreateHorizontalLine(frame, -64)

	local function OnSTRowClick(_, data, col, button)
		if data.isCollapseAll then
			TradeSkillCollapseAllButton:Click()
			GUI:UpdateProfessionsTabST()
		elseif data.spellID and button == "RightButton" then
			TSM.db.realm.craftFavorites = TSM.db.realm.craftFavorites or {}
			local newState = not TSM.db.realm.craftFavorites[data.spellID]
			if newState then
				TSM.db.realm.craftFavorites[data.spellID] = true
			else
				TSM.db.realm.craftFavorites[data.spellID] = nil
			end
			GUI:UpdateProfessionsTabST()
		elseif button == "LeftButton" then
			if IsModifiedClick() then
				HandleModifiedItemClick(GetTradeSkillRecipeLink(data.index))
			else
				TradeSkillFrame_SetSelection(data.index)
				TradeSkillFrame_Update()
				GUI:UpdateSelectedTradeSkill(true)
			end
		end
	end

	local function GetPriceColumnText()
		if TSM.db.global.priceColumn == 1 then
			return L["Crafting Cost"]
		elseif TSM.db.global.priceColumn == 2 then
			return L["Item Value"]
		elseif TSM.db.global.priceColumn == 3 then
			return L["Profit"]
		end
	end

	local function OnSTColumnClick(self)
		if self.colNum == 2 then
			TSM.db.global.priceColumn = TSM.db.global.priceColumn + 1
			TSM.db.global.priceColumn = TSM.db.global.priceColumn > 3 and 1 or TSM.db.global.priceColumn
			self:SetText(GetPriceColumnText())
			wipe(priceTextCache)
			priceTextCache.lastClear = time()
			GUI:UpdateProfessionsTabST()
		end
	end

	local stContainer = CreateFrame("Frame", nil, frame)
	stContainer:SetPoint("TOPLEFT", 5, -70)
	stContainer:SetPoint("BOTTOMRIGHT", -5, 150) -- 177)
	frame.stContainer = stContainer
	TSMAPI.Design:SetFrameColor(stContainer)

	local stCols = {
		{ name = "", width = 0.05, align = "CENTER" },
		{ name = L["Name"], width = 0.65, align = "LEFT" },
		{ name = GetPriceColumnText(), width = 0.2, align = "LEFT" },
		{ name = "P. %", width = 0.1, align = "LEFT" }
	}
	frame.st = TSMAPI:CreateScrollingTable(stContainer, stCols, { OnClick = OnSTRowClick, OnColumnClick = OnSTColumnClick })

	frame.craftInfoFrame = GUI:CreateCraftInfoFrame(frame)

	return frame
end

function GUI:CreateCraftInfoFrame(parent)
	local frame = CreateFrame("Frame", nil, parent)
	frame:SetPoint("TOPLEFT", parent.stContainer, "BOTTOMLEFT", 0, -4)
	frame:SetPoint("BOTTOMRIGHT", -3, 3)
	TSMAPI.Design:SetFrameColor(frame)

	local function OnClick()
		if not frame.index then return end
		HandleModifiedItemClick(GetTradeSkillItemLink(frame.index))
	end

	local function OnEnter(self)
		if not frame.index then return end
		local spellID = TSM.Util:GetSpellID(frame.index)
		local itemID = spellID and TSM.db.realm.crafts[spellID] and TSM.db.realm.crafts[spellID].itemID
		if itemID then
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
			TSMAPI:SafeTooltipLink(itemID)
		else
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
			GameTooltip:SetTradeSkillItem(frame.index)
		end
	end

	local function OnLeave()
		if not frame.index then return end
		GameTooltip:Hide()
	end

	local infoFrame = CreateFrame("Frame", nil, frame)
	infoFrame:SetPoint("TOPLEFT", 3, -3)
	infoFrame:SetPoint("BOTTOMLEFT", 3, 53)
	infoFrame:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -220, -3)
	frame.infoFrame = infoFrame

	local iconBtn = CreateFrame("Button", nil, infoFrame)
	iconBtn:SetPoint("TOPLEFT")
	iconBtn:SetWidth(32) --40
	iconBtn:SetHeight(32) --40
	iconBtn:SetScript("OnClick", OnClick)
	iconBtn:SetScript("OnEnter", OnEnter)
	iconBtn:SetScript("OnLeave", OnLeave)
	infoFrame.iconBtn = iconBtn
	local icon = iconBtn:CreateTexture()
	icon:SetAllPoints()
	infoFrame.icon = icon

	local nameText = infoFrame:CreateFontString()
	nameText:SetPoint("TOPLEFT", icon, "TOPRIGHT", 4, 0)
	nameText:SetPoint("TOPRIGHT")
	nameText:SetJustifyH("LEFT")
	nameText:SetFont(TSMAPI.Design:GetContentFont("small"))
	infoFrame.nameText = nameText

	local toolsText = infoFrame:CreateFontString()
	toolsText:SetPoint("TOPLEFT", nameText, "BOTTOMLEFT", 0, -2)
	toolsText:SetPoint("TOPRIGHT", nameText, "BOTTOMRIGHT", 0, -2)
	toolsText:SetJustifyH("LEFT")
	toolsText:SetFont(TSMAPI.Design:GetContentFont("small"))
	infoFrame.toolsText = toolsText

	local cooldownText = infoFrame:CreateFontString()
	cooldownText:SetPoint("TOPLEFT", toolsText, "BOTTOMLEFT", 0, -2)
	cooldownText:SetPoint("TOPRIGHT", toolsText, "BOTTOMRIGHT", 0, -2)
	cooldownText:SetJustifyH("LEFT")
	cooldownText:SetFont(TSMAPI.Design:GetContentFont("small"))
	cooldownText:SetTextColor(1, 0, 0, 1)
	infoFrame.cooldownText = cooldownText

	local descText = infoFrame:CreateFontString()
	descText:SetPoint("TOPLEFT", iconBtn, "BOTTOMLEFT", 0, -2)
	descText:SetPoint("BOTTOMRIGHT")
	descText:SetFont(TSMAPI.Design:GetContentFont("small"))
	descText:SetJustifyH("LEFT")
	descText:SetJustifyV("TOP")
	infoFrame.descText = descText

	local vBar = TSMAPI.GUI:CreateVerticalLine(frame, infoFrame:GetWidth() + 3)
	vBar:ClearAllPoints()
	vBar:SetPoint("TOPLEFT", infoFrame, "TOPRIGHT", 3, 3)
	vBar:SetPoint("BOTTOMLEFT", infoFrame, "BOTTOMRIGHT", 3, -53)
	TSMAPI.GUI:CreateHorizontalLine(infoFrame, -infoFrame:GetHeight())

	local matsFrame = CreateFrame("Frame", nil, frame)
	matsFrame:SetPoint("TOPLEFT", infoFrame, "TOPRIGHT", 5, 0)
	matsFrame:SetPoint("TOPRIGHT")
	matsFrame:SetPoint("BOTTOMRIGHT")
	frame.matsFrame = matsFrame


	local function Sizer_OnMouseUp()
		GUI.frame:StopMovingOrSizing()
	end

	local function Sizer_OnMouseDown()
		GUI.frame:StartSizing("BOTTOMRIGHT")
	end

	local sizer = CreateFrame("Frame", nil, frame)
	sizer:SetPoint("BOTTOMRIGHT", -2, 2)
	sizer:SetWidth(16)
	sizer:SetHeight(16)
	sizer:EnableMouse()
	sizer:SetScript("OnMouseDown", Sizer_OnMouseDown)
	sizer:SetScript("OnMouseUp", Sizer_OnMouseUp)
	local image = sizer:CreateTexture(nil, "BACKGROUND")
	image:SetAllPoints()
	image:SetTexture("Interface\\Addons\\TradeSkillMaster\\Media\\Sizer")

	local castText = frame:CreateFontString()
	castText:SetPoint("BOTTOMRIGHT", GUI.frame, -22, 3)
	castText:SetHeight(18)
	castText:SetJustifyH("RIGHT")
	castText:SetJustifyV("BOTTOM")
	castText:SetFont(TSMAPI.Design:GetContentFont("small"))
	castText.timeout = 0
	castText.endTime = 0
	castText.UpdateTime = function()
		local startTime, endTime, isTradeSkill = select(5, UnitCastingInfo("player"))
		if isTradeSkill then
			local timePerCraft = endTime - startTime
			endTime = endTime + (timePerCraft * (GetTradeskillRepeatCount() - 1))
			castText.endTime = ceil(endTime / 1000)
		elseif not startTime then
			-- not casting a tradeskill
			if castText.endTime > GetTime() then
				castText.timeout = castText.timeout + 1
				if castText.timeout > 3 then
					castText.endTime = 0
					castText.timeout = 0
				end
			else
				castText.timeout = 0
			end
		end

		if castText.endTime > GetTime() then
			castText:SetText(TSM.Util:FormatTime(castText.endTime - GetTime()))
		else
			castText:SetText()
		end
	end
	TSMAPI:CreateTimeDelay("craftTimeText", 0.5, castText.UpdateTime, 0.5)
	matsFrame.castText = castText

	local matsText = matsFrame:CreateFontString()
	matsText:SetPoint("TOPLEFT")
	matsText:SetPoint("TOPRIGHT")
	matsText:SetFont(TSMAPI.Design:GetContentFont(), 13)
	matsText:SetJustifyH("LEFT")
	matsText:SetJustifyV("TOP")
	matsText:SetText(TSMAPI.Design:GetInlineColor("link") .. L["Materials:"] .. "|r")
	matsFrame.matsText = matsText

	local reagentButtons = {}
	for i = 1, MAX_TRADE_SKILL_REAGENTS do
		local btn = TSMAPI.GUI:CreateItemLinkLabel(matsFrame, 13)
		if i == 1 then
			btn:SetPoint("TOPLEFT", 0, -15)
			btn:SetPoint("TOPRIGHT", 0, -15)
		else
			btn:SetPoint("TOPLEFT", reagentButtons[i - 1], "BOTTOMLEFT", 0, -3)
			btn:SetPoint("TOPRIGHT", reagentButtons[i - 1], "BOTTOMRIGHT", 0, -3)
		end
		tinsert(reagentButtons, btn)
	end
	matsFrame.reagentButtons = reagentButtons

	local buttonsFrame = CreateFrame("Frame", nil, frame)
	buttonsFrame:SetPoint("TOPRIGHT", infoFrame, "BOTTOMRIGHT", -2, -5)
	buttonsFrame:SetPoint("BOTTOMLEFT", 2, 2)
	frame.buttonsFrame = buttonsFrame

	local lessBtn = CreateFrame("Button", nil, buttonsFrame)
	lessBtn:SetWidth(28)
	lessBtn:SetHeight(28)
	lessBtn:SetPoint("TOPLEFT", -4, 4)
	lessBtn:SetNormalTexture("Interface\\Buttons\\UI-SpellbookIcon-PrevPage-Up")
	lessBtn:SetPushedTexture("Interface\\Buttons\\UI-SpellbookIcon-PrevPage-Down")
	lessBtn:SetDisabledTexture("Interface\\Buttons\\UI-SpellbookIcon-PrevPage-DisabledTexture")
	lessBtn:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight")
	lessBtn:SetScript("OnClick", function()
		local num = buttonsFrame.inputBox:GetNumber() - 1
		buttonsFrame.inputBox:SetNumber(max(num, 1))
	end)
	buttonsFrame.lessBtn = lessBtn

	local inputBox = TSMAPI.GUI:CreateInputBox(buttonsFrame, "TSMCraftingCreateInputBox")
	inputBox:SetPoint("TOPLEFT", lessBtn, "TOPRIGHT", -2, -4)
	inputBox:SetPoint("BOTTOMLEFT", lessBtn, "BOTTOMRIGHT", -2, 4)
	inputBox:SetWidth(40)
	inputBox:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)
	buttonsFrame.inputBox = inputBox

	local moreBtn = CreateFrame("Button", nil, buttonsFrame)
	moreBtn:SetWidth(28)
	moreBtn:SetHeight(28)
	moreBtn:SetPoint("TOPLEFT", inputBox, "TOPRIGHT", -2, 4)
	moreBtn:SetPoint("BOTTOMLEFT", inputBox, "BOTTOMRIGHT", -2, -4)
	moreBtn:SetNormalTexture("Interface\\Buttons\\UI-SpellbookIcon-NextPage-Up")
	moreBtn:SetPushedTexture("Interface\\Buttons\\UI-SpellbookIcon-NextPage-Down")
	moreBtn:SetDisabledTexture("Interface\\Buttons\\UI-SpellbookIcon-NextPage-DisabledTexture")
	moreBtn:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight")
	moreBtn:SetScript("OnClick", function()
		local num = buttonsFrame.inputBox:GetNumber() + 1
		buttonsFrame.inputBox:SetNumber(max(num, 1))
	end)
	buttonsFrame.moreBtn = moreBtn

	local queueBtn = TSMAPI.GUI:CreateButton(buttonsFrame, 15)
	queueBtn:SetText(L["Queue"])
	queueBtn:SetPoint("TOPLEFT", moreBtn, "TOPRIGHT", 0, -4)
	queueBtn:SetPoint("BOTTOMLEFT", moreBtn, "BOTTOMRIGHT", 0, 4)
	queueBtn:SetPoint("TOPRIGHT")
	queueBtn:RegisterForClicks("AnyUp")
	queueBtn:SetScript("OnClick", function(_, button)
		local spellID = TSM.Util:GetSpellID(frame.index)
		if not spellID then
			TSM:Print("Error: Could not get spellID for index " .. (frame.index or "nil"))
			return
		end
		if not TSM.db.realm.crafts[spellID] then
			TSM:Print("Error: SpellID " .. spellID .. " not found in crafts database. Try rescanning your profession.")
			return
		end

		-- Initialize queued if it doesn't exist
		if not TSM.db.realm.crafts[spellID].queued then
			TSM.db.realm.crafts[spellID].queued = 0
		end

		TSM.db.realm.crafts[spellID].queued = max(TSM.db.realm.crafts[spellID].queued, 0)
		if button == "LeftButton" then
			if IsModifiedClick() then
				TSM.db.realm.crafts[spellID].queued = select(3, GetTradeSkillInfo(frame.index)) or 0
			else
				TSM.db.realm.crafts[spellID].queued = (TSM.db.realm.crafts[spellID].queued or 0) + buttonsFrame.inputBox:GetNumber()
			end
		elseif button == "RightButton" then
			if IsModifiedClick() then
				TSM.db.realm.crafts[spellID].queued = 0
			else
				TSM.db.realm.crafts[spellID].queued = max((TSM.db.realm.crafts[spellID].queued or 0) - buttonsFrame.inputBox:GetNumber(), 0)
			end
		end
		GUI:UpdateQueue()
		GUI:UpdateTaskList()
	end)
	local color = TSMAPI.Design:GetInlineColor("link")
	local tooltipLines = {
		color .. L["Left-Click|r to add this craft to the queue."],
		color .. L["Shift-Left-Click|r to queue all you can craft."],
		color .. L["Right-Click|r to subtract this craft from the queue."],
		color .. L["Shift-Right-Click|r to remove all from queue."],
	}
	queueBtn.tooltip = table.concat(tooltipLines, "\n")
	buttonsFrame.queueBtn = queueBtn

	local createBtn = TSMAPI.GUI:CreateButton(buttonsFrame, 15)
	createBtn:SetText("Create")--(CREATE_PROFESSION)
	createBtn:SetPoint("BOTTOMLEFT")
	createBtn:SetPoint("BOTTOMRIGHT", buttonsFrame, "BOTTOM", -2, 0)
	createBtn:SetHeight(20)
	createBtn:SetScript("OnClick", function() GUI:CastTradeSkill(frame.index, buttonsFrame.inputBox:GetNumber()) end)
	buttonsFrame.createBtn = createBtn

	local createAllBtn = TSMAPI.GUI:CreateButton(buttonsFrame, 15)
	createAllBtn:SetText(CREATE_ALL)
	createAllBtn:SetPoint("BOTTOMLEFT", buttonsFrame, "BOTTOM", 2, 0)
	createAllBtn:SetPoint("BOTTOMRIGHT")
	createAllBtn:SetHeight(20)
	createAllBtn:SetScript("OnClick", function(self)
		local quantity = select(3, GetTradeSkillInfo(frame.index))
		GUI:CastTradeSkill(frame.index, quantity, self.vellum)
		GUI.frame.content.professionsTab.craftInfoFrame.buttonsFrame.inputBox:SetNumber(GetTradeskillRepeatCount())
	end)
	buttonsFrame.createAllBtn = createAllBtn

	frame.SetTradeSkillIndex = function(self, skillIndex)
		local name, _, numAvailable, _, altVerb = GetTradeSkillInfo(skillIndex)
		-- Enable display of items created
		local lNum, hNum = GetTradeSkillNumMade(skillIndex)
		local numMade = floor(((lNum or 1) + (hNum or 1)) / 2)
		if altVerb ~= nil and strfind(name,"Enchant ") then
			numMade = 1
		end
		if numMade > 1 then
			name = numMade .. " x " .. name
		end
		self.index = skillIndex
		self.infoFrame.icon:SetTexture(GetTradeSkillIcon(skillIndex))
		self.infoFrame.nameText:SetText(TSMAPI.Design:GetInlineColor("link") .. (name or "") .. "|r")
		self.infoFrame.descText:SetText(GetTradeSkillDescription(skillIndex))

		-- The code below is heavily based on the code in Blizzard_TradeSkillUI.lua.
		local toolsInfo = BuildColoredListString(GetTradeSkillTools(skillIndex))
		self.infoFrame.toolsText:SetText(toolsInfo and REQUIRES_LABEL .. " " .. toolsInfo or "")
		local cooldown = GetTradeSkillCooldown(skillIndex)
		if not cooldown then
			self.infoFrame.cooldownText:SetText("");
		elseif cooldown > 60 * 60 * 24 then --Cooldown is greater than 1 day.
			self.infoFrame.cooldownText:SetText(COOLDOWN_REMAINING .. " " .. SecondsToTime(cooldown, true, false, 1, true))
		else
			self.infoFrame.cooldownText:SetText(COOLDOWN_REMAINING .. " " .. SecondsToTime(cooldown))
		end

		for i, btn in ipairs(self.matsFrame.reagentButtons) do
			local name, texture, needed, player = GetTradeSkillReagentInfo(skillIndex, i)
			if name then
				btn:Show()
				btn.link = GetTradeSkillReagentItemLink(skillIndex, i)
				local linkText = (texture and "|T" .. texture .. ":0|t" or "") .. " " .. (GetTradeSkillReagentItemLink(skillIndex, i) or name)
				local color = (needed > player) and "|cffff0000" or "|cff00ff00"
				btn:SetText(format("%s(%d/%d) %s|r", color, player, needed, linkText))
			else
				btn:Hide()
				btn:SetText("")
			end
		end

		-- if altVerb == ENSCRIBE then
		if altVerb ~= nil and strfind(name,"Enchant ") then
			createAllBtn:SetText(L["Enchant Vellum"])
			if strfind(name, "Weapon") or strfind(name, "Staff") then
				createAllBtn.vellum = TSMAPI:GetSafeItemInfo("item:52511:0:0:0:0:0:0") -- Weapon Vellum
			else
				createAllBtn.vellum = TSMAPI:GetSafeItemInfo("item:52510:0:0:0:0:0:0") -- Armor Vellum
			end
		else
			createAllBtn:SetText(CREATE_ALL)
			createAllBtn.vellum = nil
		end

		if numAvailable > 0 and not IsTradeSkillLinked() then
			local num = self.buttonsFrame.inputBox:GetNumber()
			self.buttonsFrame.inputBox:SetNumber(max(min(num, numAvailable), 1))
			self.buttonsFrame.createBtn:Enable()
			self.buttonsFrame.createAllBtn:Enable()
		else
			self.buttonsFrame.inputBox:SetNumber(1)
			self.buttonsFrame.createBtn:Disable()
			self.buttonsFrame.createAllBtn:Disable()
		end
	end

	return frame
end

local RestockGroups
function GUI:CreateGroupsTab(parent)
	local frame = CreateFrame("Frame", nil, parent)
	frame:SetAllPoints()
	TSMAPI.Design:SetFrameBackdropColor(frame)

	local stContainer = CreateFrame("Frame", nil, frame)
	stContainer:SetPoint("TOPLEFT", 5, -5)
	stContainer:SetPoint("BOTTOMRIGHT", -5, 35)
	TSMAPI.Design:SetFrameColor(stContainer)
	local groupTree = TSMAPI:CreateGroupTree(stContainer, "Crafting", "Crafting_Profession")
	RestockGroups = groupTree

	local function OnCreateBtnClick()
		local playerName = UnitName("player")
		local tradeSkill = GetTradeSkillLine()

		-- Ensure the tradeSkills table exists
		TSM.db.realm.tradeSkills[playerName] = TSM.db.realm.tradeSkills[playerName] or {}
		TSM.db.realm.tradeSkills[playerName][tradeSkill] = TSM.db.realm.tradeSkills[playerName][tradeSkill] or {}

		-- Reset the prompted flag to allow re-creation of profession groups
		TSM.db.realm.tradeSkills[playerName][tradeSkill].prompted = nil

		private.forceCreateGroups = true
		TSM.Util:ScanCurrentProfession()
	end

	local function OnRestockBtnClick()
		TSM.Queue:CreateRestockQueue(groupTree:GetSelectedGroupInfo())
		GUI:UpdateQueue()
	end

	local btn = TSMAPI.GUI:CreateButton(frame, 13)
	btn:SetPoint("BOTTOMLEFT", 5, 5)
	btn:SetWidth(160)
	btn:SetHeight(24)
	btn:SetText(L["Create Profession Groups"])
	btn:SetScript("OnClick", OnCreateBtnClick)
	frame.createBtn = btn

	local btn = TSMAPI.GUI:CreateButton(frame, 20)
	btn:SetPoint("BOTTOMLEFT", frame.createBtn, "BOTTOMRIGHT", 5, 0)
	btn:SetPoint("BOTTOMRIGHT", -5, 5)
	btn:SetHeight(24)
	btn:SetText(L["Restock Selected Groups"])
	btn:SetScript("OnClick", OnRestockBtnClick)
	frame.restockBtn = btn

	return frame
end

function GUI:UpdateProfessionsTabST()
	if not GUI.frame or not GUI.frame:IsVisible() then return end

	local stData = {}
	TSM:UpdateCraftReverseLookup()

	TSM.db.realm.craftFavorites = TSM.db.realm.craftFavorites or {}

	local function RGBPercToHex(tbl)
		local r = tbl.r
		local g = tbl.g
		local b = tbl.b
		r = r <= 1 and r >= 0 and r or 0
		g = g <= 1 and g >= 0 and g or 0
		b = b <= 1 and b >= 0 and b or 0
		return string.format("%02x%02x%02x", r * 255, g * 255, b * 255)
	end

	if priceTextCache.lastClear + 60 < time() then
		wipe(priceTextCache)
		priceTextCache.lastClear = time()
	end

	local collapseAllRow = {
		cols = {
			{
				value = "",
			},
			{
				value = "|cff" .. RGBPercToHex(TradeSkillTypeColor.header) .. ALL .. " [" .. (TradeSkillCollapseAllButton.collapsed and "+" or "-") .. "]|r",
			},
			{
				value = "",
			},
			{
				value = "",
			},
		},
		isCollapseAll = true,
	}
	tinsert(stData, collapseAllRow)

	local ts = ""
	local numAvailableAllCache = {}
	local inventoryTotals = select(4, TSM.Inventory:GetTotals())
	for i = 1, GetNumTradeSkills() do
		-- local skillName, skillType, numAvailable, isExpanded, _, numSkillUps, _, showProgressBar, currentRank, maxRank = GetTradeSkillInfo(i)
		local skillName, skillType, numAvailable, isExpanded, _ = GetTradeSkillInfo(i)
		if skillName then
			local spellID = TSM.Util:GetSpellID(i)
			local key = skillName .. i
			if skillType == "header" then
				ts = ""
			elseif skillType == "subheader" then
				ts = "  "
			end
			if skillType == "header" or skillType == "subheader" then
				-- if showProgressBar then
					-- skillName = skillName .. " (" .. currentRank .. "/" .. maxRank .. ") " .. (isExpanded and " [-]" or " [+]")
				-- else
					skillName = skillName .. (isExpanded and " [-]" or " [+]")
				-- end
			end

			-- if numSkillUps > 1 and skillType == "optimal" then
				-- skillName = skillName .. " <" .. numSkillUps .. ">"
			-- end

			if not numAvailableAllCache[spellID] then
				local numAvailableAll = math.huge
				if spellID and TSM.db.realm.crafts[spellID] then
					for itemString, quantity in pairs(TSM.db.realm.crafts[spellID].mats) do
						numAvailableAll = min(numAvailableAll, floor((inventoryTotals[itemString] or 0) / quantity))
					end
				end
				if numAvailableAll ~= math.huge then
					numAvailableAllCache[spellID] = numAvailableAll
				end
			end

			if numAvailable > 0 or (numAvailableAllCache[spellID] and numAvailableAllCache[spellID] > 0) then
				local availableText = numAvailable .. " (" .. (numAvailableAllCache[spellID] or 0) .. ")"
				skillName = ts .. "|cff" .. RGBPercToHex(TradeSkillTypeColor[skillType]) .. skillName .. " [" .. availableText .. "]|r"
			else
				skillName = ts .. "|cff" .. RGBPercToHex(TradeSkillTypeColor[skillType]) .. skillName .. "|r"
			end

			local priceText = priceTextCache[spellID]
			local cost, buyout, profit = TSM.Cost:GetCraftPrices(spellID)
			if spellID and not priceText then
				--local cost, buyout, profit = TSM.Cost:GetCraftPrices(spellID)

				if TSM.db.global.priceColumn == 1 then -- Crafting Cost
					if cost and cost > 0 then
						priceText = TSMAPI:FormatTextMoney(cost, TSMAPI.Design:GetInlineColor("link"))
					end
				elseif TSM.db.global.priceColumn == 2 then -- Item Value
					if buyout and buyout > 0 then
						priceText = TSMAPI:FormatTextMoney(buyout, TSMAPI.Design:GetInlineColor("link"))
					end
				elseif TSM.db.global.priceColumn == 3 then -- Profit
					if profit then
						-- if profit < 0 then
							-- priceText = "|cffff0000-|r" .. TSMAPI:FormatTextMoney(-profit, "|cffff0000") .. format(" (%s%.0f%%|r)", "|cffff0000", profitPercent)
						-- else
							-- priceText = TSMAPI:FormatTextMoney(profit, "|cff00ff00") .. format(" (%s%.0f%%|r)", "|cff00ff00", profitPercent)
						-- end
						if profit < 0 then
							priceText = "|cffff0000-|r" .. TSMAPI:FormatTextMoney(-profit, "|cffff0000")
						else
							priceText = TSMAPI:FormatTextMoney(profit, "|cff00ff00")
						end
					end
				end

				if priceText then
					priceTextCache[spellID] = priceText
				else
					priceText = "---"
				end
			end

			local profitPercent = "---"
			if profit then
				profitPercent = profit / cost * 100
				if profit < 0 then
					profitPercent = format("%s%.0f%%|r", "|cffff0000", profitPercent)
				else
					profitPercent = format("%s%.0f%%|r", "|cff00ff00", profitPercent)
				end
			end

			local isFavorite = spellID and TSM.db.realm.craftFavorites[spellID] or false
			local favIcon = ""
			if spellID then
				favIcon = isFavorite and "|cffFFD700★|r" or "|cff888888☆|r"
			end

			local row = {
				cols = {
					{
						value = favIcon,
					},
					{
						value = skillName,
					},
					{
						value = spellID and priceText or "",
					},
					{
						value = spellID and profitPercent or "",
					},
				},
				index = i,
				spellID = spellID,
			}
			tinsert(stData, row)
			if skillType == "header" then
				ts = "  "
			elseif skillType == "subheader" then
				ts = "    "
			end
		end
	end

	table.sort(stData, function(a, b)
		if a.isCollapseAll then return true end
		if b.isCollapseAll then return false end

		local aIsFav = a.spellID and TSM.db.realm.craftFavorites[a.spellID] or false
		local bIsFav = b.spellID and TSM.db.realm.craftFavorites[b.spellID] or false

		if aIsFav ~= bIsFav then
			return aIsFav
		end

		return a.index < b.index
	end)

	local frame = GUI.frame.content.professionsTab
	frame.st:SetData(stData)
	GUI:UpdateSelectedTradeSkill(true)
end

function GUI:UpdateSelectedTradeSkill(forceUpdate)
	if not GUI.frame or not GUI.frame.content or not GUI.frame.content.professionsTab:IsVisible() then return end

	local frame = GUI.frame.content.professionsTab
	TradeSkillFrame.selectedSkill = TradeSkillFrame.selectedSkill or 1

	-- Find the row in the table that matches the selected TradeSkill index
	local stData = frame.st.data
	local selectedRow = nil
	if stData then
		for i, row in ipairs(stData) do
			if row.index and row.index == TradeSkillFrame.selectedSkill then
				selectedRow = i
				break
			end
		end
	end

	-- Only update selection if we found the row
	if selectedRow then
		frame.st:SetSelection(selectedRow)
	end

	-- Always update craft info frame
	if selectedRow or forceUpdate then
		frame.craftInfoFrame:SetTradeSkillIndex(TradeSkillFrame.selectedSkill)
	end
end

local function GetSubMaterials(itemString, quantity, depth, visited)
	-- Recursive function to get all sub-materials for crafting
	depth = depth or 0
	visited = visited or {}

	if depth > 5 or visited[itemString] then
		-- Prevent infinite loops and too deep recursion
		return {}
	end

	visited[itemString] = true
	local subMats = {}

	-- Check if this item can be crafted
	TSM:UpdateCraftReverseLookup()
	local spellID = TSM.craftReverseLookup[itemString] and TSM.craftReverseLookup[itemString][1]

	if spellID and TSM.db.realm.crafts[spellID] and TSM.db.realm.crafts[spellID].mats then
		local craft = TSM.db.realm.crafts[spellID]

		-- Always show sub-materials (raw materials needed for crafting)
		for matItemString, matQuantity in pairs(craft.mats) do
			local totalMatQuantity = matQuantity * quantity
			subMats[matItemString] = (subMats[matItemString] or 0) + totalMatQuantity

			-- Recursively get sub-sub-materials (pass visited directly to detect circular dependencies)
			local subSubMats = GetSubMaterials(matItemString, totalMatQuantity, depth + 1, visited)
			for subSubMatString, subSubMatQuantity in pairs(subSubMats) do
				subMats[subSubMatString] = (subMats[subSubMatString] or 0) + subSubMatQuantity
			end
		end
	end

	visited[itemString] = nil  -- Remove from visited when done with this level
	return subMats
end

local function GetRawMaterials(itemString, quantity, depth, visited)
	depth = depth or 0
	visited = visited or {}

	if depth > 10 or visited[itemString] then
		return {}
	end

	visited[itemString] = true
	local rawMats = {}

	TSM:UpdateCraftReverseLookup()
	local spellID = TSM.craftReverseLookup[itemString] and TSM.craftReverseLookup[itemString][1]

	-- Check if we have this item in inventory
	local haveQuantity = TSM.Inventory:GetTotalQuantity(itemString)

	-- If we have enough of this item, don't break it down into sub-materials
	if haveQuantity >= quantity then
		rawMats[itemString] = quantity
		visited[itemString] = nil  -- Remove from visited since we're not recursing
		return rawMats
	end

	-- Check if this item can be crafted AND if it makes sense to craft it
	local shouldCraft = false
	if spellID and TSM.db.realm.crafts[spellID] and TSM.db.realm.crafts[spellID].mats then
		local craft = TSM.db.realm.crafts[spellID]

		-- Count number of different materials and check ratio
		local numMats = 0
		local totalMatQuantity = 0
		for matItemString, matQuantity in pairs(craft.mats) do
			numMats = numMats + 1
			totalMatQuantity = totalMatQuantity + matQuantity
		end

		-- Don't use "trading" recipes (e.g., 5x Heavy Leather -> 1x Thick Leather)
		-- These have a single material with high quantity (ratio >= 3:1) and produce 1 item
		local numResult = craft.numResult or 1
		local isTrading = (numMats == 1 and totalMatQuantity >= 3 and numResult == 1)

		-- Only craft if we have ZERO of this item and it's not a trading recipe
		shouldCraft = (haveQuantity == 0 and not isTrading)
	end

	if shouldCraft then
		local craft = TSM.db.realm.crafts[spellID]
		local stillNeed = quantity

		-- Break down what we need to craft into sub-materials
		for matItemString, matQuantity in pairs(craft.mats) do
			local totalMatQuantity = matQuantity * stillNeed
			-- Pass visited directly (not a copy) to detect circular dependencies
			local subRawMats = GetRawMaterials(matItemString, totalMatQuantity, depth + 1, visited)
			for rawMatString, rawMatQuantity in pairs(subRawMats) do
				rawMats[rawMatString] = (rawMats[rawMatString] or 0) + rawMatQuantity
			end
		end
	else
		-- This is a raw material, can't be crafted, or shouldn't be crafted (trading recipe or we have some)
		if haveQuantity > 0 then
			rawMats[itemString] = haveQuantity
		end
		-- Add what we still need as raw material
		local stillNeed = quantity - haveQuantity
		if stillNeed > 0 then
			rawMats[itemString] = (rawMats[itemString] or 0) + stillNeed
		end
	end

	visited[itemString] = nil  -- Remove from visited when done with this level
	return rawMats
end

local function AggregateRawMaterialsFromQueue(queuedCrafts)
	local aggregatedMats = {}

	for profession, crafts in pairs(queuedCrafts) do
		for _, stage in ipairs(crafts) do
			for spellID, numQueued in pairs(stage.crafts) do
				if TSM.db.realm.crafts[spellID] and TSM.db.realm.crafts[spellID].mats then
					for itemString, matQuantity in pairs(TSM.db.realm.crafts[spellID].mats) do
						local quantity = matQuantity * numQueued

						local MatName = GetItemInfo(itemString)
						if MatName ~= nil and strfind(MatName, "Vellum") then
							local NewItemString = CheapestVellum(itemString)
							if itemString ~= NewItemString then
								itemString = NewItemString
							end
						end

						local rawMats = GetRawMaterials(itemString, quantity, 0, {})
						for rawMatString, rawMatQuantity in pairs(rawMats) do
							aggregatedMats[rawMatString] = (aggregatedMats[rawMatString] or 0) + rawMatQuantity
						end
					end
				end
			end
		end
	end

	return aggregatedMats
end

function GUI:UpdateQueue()
	if not GUI.frame or not GUI.frame.queue or not GUI.frame.queue:IsVisible() then return end
	TSM.Options:UpdateCraftST()
	TSM:UpdateCraftReverseLookup()
	GUI.craftNextInfo = nil

	local skillIndexLookup = {}
	for i = 1, GetNumTradeSkills() do
		local spellID = TSM.Util:GetSpellID(i)
		if spellID then
			skillIndexLookup[spellID] = i
		end
	end

	local queuedCrafts, queuedMats, totalCost, totalProfit = TSM.Queue:GetQueue()
	GUI.frame.queue.profitLabel:SetAmounts(totalCost, totalProfit)
	local currentProfession = GetTradeSkillLine()
	local stData = {}
	local bagTotals = TSM.Inventory:GetTotals(itemID)

	for profession, crafts in pairs(queuedCrafts) do
		local professionColor, playerColor
		local players = {}
		for player, data in pairs(TSM.db.realm.tradeSkills) do
			if data[profession] then
				tinsert(players, player)
			end
		end
		if TSM.db.realm.tradeSkills[UnitName("player")][profession] then
			playerColor = "|cffffffff"
			if profession == currentProfession then
				professionColor = "|cffffffff"
			else
				professionColor = "|cffff0000"
			end
		else
			playerColor = "|cffff0000"
			professionColor = "|cffff0000"
		end

		local professionCollapsed = TSM.db.realm.queueStatus.collapsed[profession]
		local row = {
			cols = {
				{
					value = format("%s (%s) %s%s|r", professionColor .. profession .. "|r", playerColor .. table.concat(players, ", ") .. "|r", TSMAPI.Design:GetInlineColor("link"), professionCollapsed and "[+]" or "[-]")
				}
			},
			isTitle = true,
			profession = profession,
		}
		tinsert(stData, row)

		if not professionCollapsed then
			for _, stage in ipairs(crafts) do
				local stageCollapsed = TSM.db.realm.queueStatus.collapsed[profession .. stage.name]
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

						local velName
						if TSM.VellumInfo[spellID] then
							velName = GetItemInfo(TSM.VellumInfo[spellID])
						end

						for itemID, quantity in pairs(TSM.db.realm.crafts[spellID].mats) do

							local MatName = GetItemInfo(itemID)
							if MatName ~= nil and velName ~= nil and strfind(MatName, "Vellum") then
								local NewItemString = CheapestVellum(itemID)
								if itemID ~= NewItemString then
									itemID = NewItemString
									velName = GetItemInfo(itemID)
								end
							end

							local numHave = bagTotals[itemID] or 0
							canCraft = min(canCraft, floor(numHave / quantity))
						end

						local color
						local craftIndex = skillIndexLookup[spellID]
						if canCraft >= numQueued then
							-- green (can craft all)
							if craftIndex then
								color = "|cff00ff00"
							else
								color = "|cff008800"
							end
						elseif canCraft > 0 then
							-- blue (can craft some)
							if craftIndex then
								color = "|cff5599ff"
							else
								color = "|cff224488"
							end
						else
							-- orange (can't craft any)
							if craftIndex then
								color = "|cffff7700"
							else
								color = "|cff883300"
							end
						end

						local extra = ""
						if not craftIndex then
							if TSM.db.realm.crafts[spellID].players[UnitName("player")] and TSM.db.realm.crafts[spellID].profession == currentProfession then
								extra = "|cffff0000[Filtered]|r "
							end
						end

						local row = {
							cols = {
								{
									value = "        " .. extra .. color .. TSM.db.realm.crafts[spellID].name .. " (x" .. numQueued .. ")" .. "|r",
								},
							},
							spellID = spellID,
							canCraft = (canCraft > 0) and canCraft or 0,
							numQueued = numQueued,
							index = craftIndex,
							velName = velName,
							profit = select(3, TSM.Cost:GetCraftPrices(spellID)),
							profession = TSM.db.realm.crafts[spellID].profession,
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
						if not GUI.craftNextInfo and row.index and row.canCraft > 0 then
							GUI.craftNextInfo = { spellID = row.spellID, index = row.index, quantity = min(row.numQueued, row.canCraft), velName = row.velName, isCrafting = 0 }
						end
						tinsert(stData, row)
					end
				end
			end
		end
	end

	GUI.frame.queue.craftST:SetData(stData)

	-- Build materials view: only raw materials
	stData = {}
	local order = 0

	local aggregatedMats = AggregateRawMaterialsFromQueue(queuedCrafts)

	local sortedMats = {}
	for itemString, totalQuantity in pairs(aggregatedMats) do
		tinsert(sortedMats, {itemString = itemString, quantity = totalQuantity})
	end

	table.sort(sortedMats, function(a, b)
		local aName = TSM.db.realm.mats[a.itemString] and TSM.db.realm.mats[a.itemString].name or TSMAPI:GetSafeItemInfo(a.itemString) or "?"
		local bName = TSM.db.realm.mats[b.itemString] and TSM.db.realm.mats[b.itemString].name or TSMAPI:GetSafeItemInfo(b.itemString) or "?"
		return aName < bName
	end)

	for _, matInfo in ipairs(sortedMats) do
		local itemString = matInfo.itemString
		local quantity = matInfo.quantity
		local have = TSM.Inventory:GetTotalQuantity(itemString)
		local need = max(quantity - have, 0)

		local color
		local isVendorItem = TSMAPI:GetVendorCost(itemString) ~= nil

		if need == 0 then
			if TSM.Inventory:GetPlayerBagNum(itemString) >= quantity then
				color = "|cff00ff00"
			else
				color = "|cffffff00"
			end
		elseif isVendorItem then
			-- Vendor items are shown in blue
			color = "|cff00bfff"
		else
			color = "|cffff0000"
		end

		local matName = TSM.db.realm.mats[itemString] and TSM.db.realm.mats[itemString].name or TSMAPI:GetSafeItemInfo(itemString) or "?"
		local cost = TSM.Cost:GetMatCost(itemString)

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
				{
					value = TSMAPI:FormatTextMoney(cost) or "---",
					args = { cost },
				},
			},
			itemString = itemString,
			order = order,
		}
		tinsert(stData, matRow)
	end

	GUI.frame.queue.matST:SetData(stData)
	-- TSMAPI:CreateTimeDelay("gatheringUpdateThrottle", 0.3, GUI.UpdateGathering)

	TSMAPI:CreateTimeDelay("UpdateCraftButtonThrottle", 0.2, GUI.UpdateCraftButton)
end

function GUI:UpdateCraftButton()
	if UnitCastingInfo("player") or not GUI.craftNextInfo then
		TSMCraftNextButton:Disable()
	elseif GUI.isCrafting and GUI.isCrafting.quantity > 0 then
		TSMCraftNextButton:Disable()
	else
		TSMCraftNextButton:Enable()
	end
end

function GUI:ShowProfessionsTab()
	GUI.frame.navFrame.groupsBtn:UnlockHighlight()
	GUI.frame.navFrame.professionsBtn:LockHighlight()
	GUI.frame.content.groupsTab:Hide()
	GUI.frame.content.professionsTab:Show()

	GUI:UpdateProfessionsTabST()
	GUI.frame.content.professionsTab.craftInfoFrame.buttonsFrame.inputBox:SetNumber(1)
end

function GUI:ShowGroupsTab()
	GUI.frame.navFrame.professionsBtn:UnlockHighlight()
	GUI.frame.navFrame.groupsBtn:LockHighlight()
	GUI.frame.content.professionsTab:Hide()
	GUI.frame.content.groupsTab:Show()

	if QuickRestock then
		QuickRestock = false
		TSM.Queue:CreateRestockQueue(RestockGroups:GetSelectedGroupInfo())
		GUI:UpdateQueue()
		GUI.ShowProfessionsTab()
	end
end

function GUI:CreatePromptFrame(parent)
	local frame = CreateFrame("Frame", nil, parent)
	TSMAPI.Design:SetFrameBackdropColor(frame)
	frame:SetAllPoints()
	frame:SetFrameLevel(20)
	frame:EnableMouse(true)
	frame:Hide()

	local text = frame:CreateFontString()
	text:SetPoint("LEFT", 5, 50)
	text:SetPoint("RIGHT", -5, 50)
	text:SetHeight(100)
	text:SetFont(TSMAPI.Design:GetContentFont("normal"))
	text:SetText(L["Would you like to automatically create some TradeSkillMaster groups for this profession?"])
	frame.text = text
	frame.SetText = function(_, ...) text:SetText(...) end

	local yesBtn = TSMAPI.GUI:CreateButton(frame, 16)
	yesBtn:SetPoint("CENTER", -110, 0)
	yesBtn:SetWidth(100)
	yesBtn:SetHeight(20)
	yesBtn:SetText(YES)
	yesBtn:SetScript("OnClick", function()
		TSM:Printf(L["Created profession group for %s."], frame.profession)
		TSMAPI:CreatePresetGroups(frame.presetGroupInfo)
		TSM.db.realm.tradeSkills[UnitName("player")][frame.profession].prompted = true
		frame:Hide()
		GUI:UpdateProfessionsTabST()
	end)
	frame.yesBtn = yesBtn

	local laterBtn = TSMAPI.GUI:CreateButton(frame, 16)
	laterBtn:SetPoint("CENTER")
	laterBtn:SetWidth(100)
	laterBtn:SetHeight(20)
	laterBtn:SetText(L["Ask Later"])
	laterBtn:SetScript("OnClick", function() frame:Hide() end)
	frame.laterBtn = laterBtn

	local noBtn = TSMAPI.GUI:CreateButton(frame, 16)
	noBtn:SetPoint("CENTER", 110, 0)
	noBtn:SetWidth(100)
	noBtn:SetHeight(20)
	noBtn:SetText(L["No Thanks"])
	noBtn:SetScript("OnClick", function()
		TSM.db.realm.tradeSkills[UnitName("player")][frame.profession].prompted = true
		frame:Hide()
	end)
	frame.noBtn = noBtn

	return frame
end

function GUI:PromptPresetGroups(currentTradeSkill, presetGroupInfo)
	GUI:RestoreFilters()

	-- If forceCreateGroups is set, create groups directly without prompting
	if private.forceCreateGroups then
		private.forceCreateGroups = nil
		TSM:Printf(L["Created profession group for %s."], currentTradeSkill)
		TSMAPI:CreatePresetGroups(presetGroupInfo, nil, nil, true) -- forceMove = true
		if TSM.db.realm.tradeSkills[UnitName("player")][currentTradeSkill] then
			TSM.db.realm.tradeSkills[UnitName("player")][currentTradeSkill].prompted = true
		end
		GUI:UpdateProfessionsTabST()
		return
	end

	-- Normal prompt flow for first-time profession scan
	if TSM.db.realm.tradeSkills[UnitName("player")][currentTradeSkill] and not TSM.db.realm.tradeSkills[UnitName("player")][currentTradeSkill].prompted then
		GUI.frame.prompt.profession = currentTradeSkill
		GUI.frame.prompt.presetGroupInfo = presetGroupInfo
		GUI.frame.prompt:Show()
	end
end

function GUI:CreateGatheringSelectionFrame(parent)
	local frame = CreateFrame("Frame", nil, parent)
	frame:SetFrameStrata("HIGH")
	frame:SetHeight(200)
	frame:SetWidth(250)
	frame:SetPoint("TOPLEFT", parent, "TOPRIGHT", 2, 0)
	frame:EnableMouse(true)
	frame:SetScript("OnMouseDown", function() parent:StartMoving() end)
	frame:SetScript("OnMouseUp", function() parent:StopMovingOrSizing() end)
	TSMAPI.Design:SetFrameBackdropColor(frame)

	local title = TSMAPI.GUI:CreateLabel(frame)
	title:SetText("TSM_Crafting - " .. L["Gathering"])
	title:SetPoint("TOPLEFT")
	title:SetPoint("TOPRIGHT")
	title:SetHeight(20)

	TSMAPI.GUI:CreateHorizontalLine(frame, -23)

	local text1 = TSMAPI.GUI:CreateLabel(frame)
	text1:SetText(L["First select a crafter"])
	text1:SetPoint("TOPLEFT", 5, -28)
	text1:SetPoint("TOPRIGHT", -5, -28)
	text1:SetHeight(20)
	text1:SetJustifyH("CENTER")
	text1:SetJustifyV("CENTER")
	frame.text1 = text1

	TSMAPI.GUI:CreateHorizontalLine(frame, -52)

	local dropdown = TSMAPI.GUI:CreateDropdown(frame)
	dropdown:SetPoint("TOPLEFT", 5, -55)
	dropdown:SetPoint("TOPRIGHT", -5, -55)
	dropdown:SetLabel(L["Crafter"])
	dropdown:SetCallback("OnValueChanged", function(_, _, value)
		private.gather.player = value
		private.gather.professions = nil
		GUI:UpdateGatherSelectionWindow()
	end)
	frame.playerDropdown = dropdown

	local dropdown = TSMAPI.GUI:CreateDropdown(frame)
	dropdown:SetPoint("TOPLEFT", 5, -100)
	dropdown:SetPoint("TOPRIGHT", -5, -100)
	dropdown:SetLabel(L["Professions"])
	dropdown:SetMultiselect(true)
	dropdown:SetCallback("OnValueChanged", function(_, _, profession, value)
		private.gather.professions[profession] = value or nil
		GUI:UpdateGatherSelectionWindow()
	end)
	frame.professionDropdown = dropdown

	TSMAPI.GUI:CreateHorizontalLine(frame, -150)

	local btn = TSMAPI.GUI:CreateButton(frame, 18)
	btn:SetPoint("BOTTOMLEFT", 5, 5)
	btn:SetPoint("BOTTOMRIGHT", -5, 5)
	btn:SetHeight(24)
	btn:SetText(L["Start Gathering"])
	btn:SetScript("OnClick", GUI.StartGathering)
	frame.gatherButton = btn

	return frame
end

function GUI:UpdateGatherSelectionWindow()
	-- create table of crafters
	local queuedCrafts = TSM.Queue:GetQueue()
	local crafters = {}
	local numCrafters = 0
	for profession, _ in pairs(queuedCrafts) do
		for player, data in pairs(TSM.db.realm.tradeSkills) do
			if data[profession] then
				crafters[player] = player
				numCrafters = numCrafters + 1
			end
		end
	end

	local frame = GUI.frame.gather
	frame.playerDropdown:SetList(crafters)

	if not private.gather.player then
		if crafters[UnitName("player")] then
			private.gather.player = UnitName("player")
		elseif numCrafters == 1 then
			private.gather.player = next(crafters)
		end
	end

	if private.gather.player then
		frame.playerDropdown:SetValue(private.gather.player)

		-- create table of professions
		local professions = {}
		local numProfessions = 0
		for profession, _ in pairs(queuedCrafts) do
			if TSM.db.realm.tradeSkills[private.gather.player][profession] then
				professions[profession] = profession
				numProfessions = numProfessions + 1
			end
		end
		frame.professionDropdown:SetList(professions)
		if not private.gather.professions then
			private.gather.professions = {}
			for profession in pairs(professions) do
				private.gather.professions[profession] = true
			end
		end

		local currentProfession = GetTradeSkillLine()
		if currentProfession and professions[currentProfession] then
			private.gather.professions[currentProfession] = true
		end

		if next(private.gather.professions) then
			frame.gatherButton:Enable()
		else
			frame.gatherButton:Disable()
		end
		frame.professionDropdown:SetDisabled(false)
		for profession in pairs(professions) do
			frame.professionDropdown:SetItemValue(profession, private.gather.professions[profession])
		end
	else
		frame.playerDropdown:SetValue()
		frame.professionDropdown:SetDisabled(true)
		frame.professionDropdown:SetValue({})
		frame.gatherButton:Disable()
	end
end

function GUI:CreateGatheringFrame()
	local frameDefaults = {
		x = 850,
		y = 450,
		width = 325,
		height = 400,
		scale = 1,
	}
	local frame = TSMAPI:CreateMovableFrame("TSMCraftingGatherFrame", frameDefaults)
	frame:SetFrameStrata("HIGH")
	TSMAPI.Design:SetFrameBackdropColor(frame)

	local title = TSMAPI.GUI:CreateLabel(frame)
	title:SetText("TSM_Crafting - " .. L["Gathering"])
	title:SetPoint("TOPLEFT")
	title:SetPoint("TOPRIGHT")
	title:SetHeight(20)
	TSMAPI.Design:SetTitleTextColor(title)

	TSMAPI.GUI:CreateHorizontalLine(frame, -21)

	local label = TSMAPI.GUI:CreateLabel(frame)
	label:SetText("")
	label:SetPoint("TOPLEFT", 0, -22)
	label:SetPoint("TOPRIGHT", 0, -22)
	label:SetHeight(20)
	frame.label = label

	TSMAPI.GUI:CreateHorizontalLine(frame, -42)
	local containersFrame = CreateFrame("Frame", nil, frame)
	containersFrame:SetPoint("TOPLEFT", 2, -45)
	containersFrame:SetPoint("TOPRIGHT", -2, -45)
	containersFrame:SetPoint("BOTTOMLEFT", 2, 53)

	local matsFrame = CreateFrame("Frame", nil, containersFrame)
	matsFrame:SetPoint("TOPLEFT")
	matsFrame:SetPoint("BOTTOMRIGHT", containersFrame, "CENTER", -2, 2)

	local stContainer = CreateFrame("Frame", nil, matsFrame)
	stContainer:SetAllPoints()
	TSMAPI.Design:SetFrameColor(stContainer)

	local stCols = {
		{ name = L["Material Name"], width = 0.69, headAlign = "Left" },
		{ name = L["Need"], width = 0.2, headAlign = "Left" },
		{ name = L["Total"], width = 0.2, headAlign = "Left" },
	}

	local function MatOnEnter(_, data, col)
		local link = select(2, TSMAPI:GetSafeItemInfo(data.itemString))
		if link then
			GameTooltip:SetOwner(col, "ANCHOR_RIGHT")
			TSMAPI:SafeTooltipLink(link)
			GameTooltip:Show()
		end
	end

	local function MatOnLeave(_, data)
		GameTooltip:Hide()
	end

	frame.needST = TSMAPI:CreateScrollingTable(stContainer, stCols, { OnEnter = MatOnEnter, OnLeave = MatOnLeave }, 12)
	frame.needST:SetData({})
	frame.needST:DisableSelection(true)

	local sourcesFrame = CreateFrame("Frame", nil, containersFrame)
	sourcesFrame:SetPoint("TOPLEFT", containersFrame, "TOP", 2, 0)
	sourcesFrame:SetPoint("BOTTOMRIGHT")

	local stContainer2 = CreateFrame("Frame", nil, sourcesFrame)
	stContainer2:SetAllPoints()
	TSMAPI.Design:SetFrameColor(stContainer2)

	local stCols2 = {
		{ name = L["Available Sources"], width = 1, align = "Left" },
	}

	local function OnCraftRowClicked(_, data)
		if data.isTitle then
			if data.task then
				TSM.db.realm.sourceStatus.collapsed[data.source .. data.task] = not TSM.db.realm.sourceStatus.collapsed[data.source .. data.task]
			else
				TSM.db.realm.sourceStatus.collapsed[data.source] = not TSM.db.realm.sourceStatus.collapsed[data.source]
			end
			GUI:UpdateGathering()
		end
	end

	local function AvilableOnEnter(_, data, col)
		if not data.isTitle then
			local link = select(2, TSMAPI:GetSafeItemInfo(data.cols[1].itemString))
			if link then
				GameTooltip:SetOwner(col, "ANCHOR_RIGHT")
				TSMAPI:SafeTooltipLink(link)
				GameTooltip:Show()
			end
		end
	end

	frame.sourcesST = TSMAPI:CreateScrollingTable(stContainer2, stCols2, { OnEnter = AvilableOnEnter, OnLeave = MatOnLeave, OnClick = OnCraftRowClicked }, 12)
	frame.sourcesST:SetData({})
	frame.sourcesST:DisableSelection(true)

	local availFrame = CreateFrame("Frame", nil, containersFrame)
	availFrame:SetPoint("TOPRIGHT", containersFrame, "CENTER", -2, -2)
	availFrame:SetPoint("BOTTOMLEFT")
	TSMAPI.Design:SetFrameBackdropColor(availFrame)

	local stContainer3 = CreateFrame("Frame", nil, availFrame)
	stContainer3:SetAllPoints()
	TSMAPI.Design:SetFrameColor(stContainer3)

	local stCols3 = {
		{ name = L["Current Source"], width = 1, align = "Left" },
	}

	local function OnAvailRowClicked(_, data, _, button)
		if data.name and data.taskType == L["Search for Mats"] then
			if TSMAPI:AHTabIsVisible("Shopping") then
				if data.need > 0 then
					if button == "RightButton" then
						TSM.Gather:ShoppingSearch(data.itemString, data.need, true)
					else
						TSM.Gather:ShoppingSearch(data.itemString, data.need)
					end
				end
			else
				TSM:Printf(L["Please switch to the Shopping Tab to perform the gathering search."])
			end
		end
	end


	frame.availableST = TSMAPI:CreateScrollingTable(stContainer3, stCols3, { OnEnter = MatOnEnter, OnLeave = MatOnLeave, OnClick = OnAvailRowClicked }, 12)
	frame.availableST:SetData({})
	frame.availableST:DisableSelection(true)

	local checkboxFrame = CreateFrame("Frame", nil, frame)
	checkboxFrame:SetPoint("TOPLEFT", containersFrame, "BOTTOMLEFT", 2, -2)
	checkboxFrame:SetPoint("TOPRIGHT", containersFrame, "BOTTOMRIGHT", -2, 2)
	checkboxFrame:SetPoint("BOTTOMLEFT", 2, 28)

	local checkbox1 = TSMAPI.GUI:CreateCheckBox(checkboxFrame, L["If checked, only a normal AH search will be performed"])
	checkbox1:SetPoint("LEFT", checkboxFrame, "LEFT", 0, 3)
	--checkbox:SetPoint("BOTTOMRIGHT", checkboxFrame, "BOTTOMRIGHT")
	checkbox1:SetHeight(18)
	checkbox1:SetWidth(185)
	checkbox1:SetValue(TSM.db.realm.gathering.destroyDisable)
	checkbox1:SetLabel(L[" Disable Destroying Search"])
	checkbox1:SetCallback("OnValueChanged", function(_, _, value)
		TSM.db.realm.gathering.destroyDisable = value
	end)

	local checkbox2 = TSMAPI.GUI:CreateCheckBox(checkboxFrame, L["If checked, the AH destroying search will only look for even stacks"])
	checkbox2:SetPoint("RIGHT", checkboxFrame, "RIGHT", 0, 3)
	-- checkbox2:SetPoint("CENTER", checkboxFrame, "RIGHT")
	--checkbox:SetPoint("BOTTOMRIGHT", checkboxFrame, "BOTTOMRIGHT")
	checkbox2:SetHeight(18)
	checkbox2:SetWidth(100)
	checkbox2:SetValue(TSM.db.realm.gathering.evenStacks)
	checkbox2:SetLabel(L["Even Stacks"])
	checkbox2:SetCallback("OnValueChanged", function(_, _, value)
		TSM.db.realm.gathering.evenStacks = value
	end)
	TSMAPI.Design:SetFrameColor(checkboxFrame)


	local btn = TSMAPI.GUI:CreateButton(frame, 18)
	btn:SetPoint("BOTTOMLEFT", frame, "BOTTOM", 2, 4)
	btn:SetPoint("BOTTOMRIGHT", -4, 4)
	btn:SetHeight(20)
	btn:SetText(L["Stop Gathering"])
	btn:SetScript("OnClick", function()
		private.gather = {}
		GUI.gatheringFrame:Hide()
		TSM.db.realm.gathering.availableMats = {}
		TSM.db.realm.gathering.crafter = nil
		TSM.db.realm.gathering.neededMats = {}
		TSM.db.realm.gathering.gatheredMats = false
		TSM.db.realm.gathering.destroyingMats = {}
		private.currentSource = nil
	end)

	local btn = TSMAPI.GUI:CreateButton(frame, 18)
	btn:SetPoint("BOTTOMLEFT", 4, 4)
	btn:SetPoint("BOTTOMRIGHT", frame, "BOTTOM", -2, 4)
	btn:SetHeight(20)
	btn:SetText(L["Gather Items"])
	btn:Disable()
	btn:SetScript("OnClick", function()
		TSM.Gather:gatherItems(private.currentSource, private.currentTask)
	end)
	frame.gatherButton = btn

	return frame
end

function GUI:StartGathering()
	GUI.frame.gather:Hide()
	TSM.db.realm.gathering.gatheredMats = false
	local _, queuedMats = TSM.Queue:GetQueue()

	local neededMats = {}
	for profession, data in pairs(queuedMats) do
		if private.gather.professions[profession] then
			for itemString, quantity in pairs(data) do
				neededMats[itemString] = (neededMats[itemString] or 0) + quantity
			end
		end
	end

	if not next(neededMats) then
		TSM:Print(L["Nothing To Gather"])
	else
		TSM.db.realm.gathering.crafter = private.gather.player
		TSM.db.realm.gathering.professions = private.gather.professions
		TSM.db.realm.gathering.neededMats = neededMats
		GUI.gatheringFrame:Show()
		GUI:UpdateGathering()
	end
	private.gather = {}
end

function GUI:UpdateGathering()
	if not GUI.gatheringFrame or not GUI.gatheringFrame:IsVisible() then return end
	if not TSM.db.realm.gathering.crafter or not next(TSM.db.realm.gathering.neededMats) then return end

	-- recheck the craft queue and update neededMats
	local _, queuedMats = TSM.Queue:GetQueue()
	local neededMats = {}
	for profession, data in pairs(queuedMats) do
		if TSM.db.realm.gathering.professions[profession] then
			for itemString, quantity in pairs(data) do
				neededMats[itemString] = (neededMats[itemString] or 0) + quantity
			end
		end
	end

	local stData = {}
	local sources = {}
	local crafter = TSM.db.realm.gathering.crafter
	local professionList = {}
	for profession in pairs(TSM.db.realm.gathering.professions) do
		tinsert(professionList, profession)
	end

	-- double check if crafter already has all the items needed
	local shortItems = {}
	local crafterBags = TSMAPI:ModuleAPI("ItemTracker", "playerbags", crafter) or {}
	for itemString, quantity in pairs(neededMats) do
		local need = max(quantity - (crafterBags[itemString] or 0), 0)
		if need > 0 then
			shortItems[itemString] = need
		end
	end
	if not next(shortItems) then
		GUI.gatheringFrame:Hide()
		if TSM.db.realm.gathering.gatheredMats == true then
			TSM:Print("Finished Gathering")
			TSM.db.realm.gathering.gatheredMats = false
			TSM.db.realm.gathering.crafter = nil
			TSM.db.realm.gathering.neededMats = {}
			TSM.db.realm.gathering.gatheredMats = false
			TSM.db.realm.sourceStatus.collapsed = {}
			TSM.db.realm.gathering.destroyingMats = {}
		end
		return
	else
		TSM.db.realm.gathering.neededMats = CopyTable(neededMats)
	end

	sort(professionList)
	local professionsUsed = table.concat(professionList, ", ")

	GUI.gatheringFrame.label:SetText(crafter .. " (" .. professionsUsed .. ")")

	for itemString, quantity in pairs(neededMats) do
		local need = max(quantity - (TSM.Inventory:GetTotalQuantity(itemString) or 0), 0)

		local color, order
		if need == 0 then
			if (crafterBags[itemString] or 0) >= quantity then
				color = "|cff00ff00"
				order = 1
			else
				color = "|cffffff00"
				order = 2
			end
		else
			color = "|cffff0000"
			order = 3
		end

		local row = {
			cols = {
				{
					value = color .. TSM.db.realm.mats[itemString].name .. "|r",
					args = { TSM.db.realm.mats[itemString].name },
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
			name = TSM.db.realm.mats[itemString].name,
		}
		tinsert(stData, row)
	end

	sort(stData, function(a, b)
		if a.order == 3 then return false end
		if b.order == 3 then return true end
		if a.order == 2 then return false end
		if b.order == 2 then return true end
		if a.order == 1 then return false end
		if b.order == 1 then return true end
		return a.name < b.name
	end)

	GUI.gatheringFrame.needST:SetData(stData)


	-- update sources
	local sources = TSM.Inventory:GetItemSources(crafter, neededMats) or {}
	stData = {}
	if next(sources) then
		for _, source in ipairs(sources) do
			local color
			if source.sourceName == UnitName("player") then
				color = "|cff00ff00"
			else
				color = "|cffffff00"
			end
			local sourceCollapsed = TSM.db.realm.sourceStatus.collapsed[source.sourceName]
			local row = {
				cols = {
					{
						value = format("%s %s%s|r", color .. source.sourceName, TSMAPI.Design:GetInlineColor("link"), sourceCollapsed and "[+]" or "[-]")
					}
				},
				isTitle = true,
				source = source.sourceName,
			}
			tinsert(stData, row)

			if not sourceCollapsed then
				for _, task in ipairs(source.tasks) do
					local tasksCollapsed = TSM.db.realm.sourceStatus.collapsed[source.sourceName .. task.taskType]
					local row = {
						cols = {
							{
								value = format("  %s %s%s|r", color .. task.taskType, TSMAPI.Design:GetInlineColor("link"), tasksCollapsed and "[+]" or "[-]")
							}
						},
						isTitle = true,
						task = task.taskType,
						source = source.sourceName,
					}
					tinsert(stData, row)

					if not tasksCollapsed then
						for itemString, quantity in pairs(task.items) do
							local needQty
							if source.sourceName == L["Destroying"] or task.taskType == L["Collect Mail"] or task.taskType == L["Mail Items"] then
								if neededMats[itemString] then
									needQty = min(quantity, neededMats[itemString])
								else
									needQty = quantity
								end
							else
								needQty = neededMats[itemString] - (crafterBags[itemString] or 0)
							end
							local name = TSMAPI:GetSafeItemInfo(itemString) or itemString
							local row

							--							if task.taskType == L["Search for Mats"] or task.taskType == L["Visit Vendor"] or task.taskType == L["Collect Mail"] or task.taskType == L["Mail Items"] then
							row = {
								cols = {
									{
										value = format("    %s", color .. name .. " x" .. min(needQty, quantity)),
										itemString = itemString
									}
								},
							}
							--							else
							--								row = {
							--									cols = {
							--										{
							--											value = format("    %s", color .. name .. " x" .. needQty .. " (" .. quantity .. " Avail)")
							--										}
							--									},
							--								}
							--							end
							tinsert(stData, row)
						end
					end
				end
			end
		end
	end

	GUI.gatheringFrame.sourcesST:SetData(stData)

	-- update available mats if at a valid source
	stData = {}
	local availableMats = {}
	local playerBags = TSMAPI:ModuleAPI("ItemTracker", "playerbags", UnitName("player")) or {}
	local crafterMail = TSMAPI:ModuleAPI("ItemTracker", "playermail", crafter) or {}
	for itemString, quantity in pairs(neededMats) do
		local need = quantity - (crafterBags[itemString] or 0)
		if UnitName("player") ~= crafter then
			need = need - (crafterMail[itemString] or 0)
		end
		if need > 0 then
			if next(sources) then
				for _, source in ipairs(sources) do
					if private.currentSource and private.currentSource == source.sourceName then
						for _, task in ipairs(source.tasks) do
							if private.currentTask and private.currentTask == task.taskType then
								for taskItemString, taskQuantity in pairs(task.items) do
									if taskItemString == itemString then
										if task.taskType == L["Visit Vendor"] and not TSM.Gather:MerchantSells(itemString) then
											break
										end
										local availQty
										if task.taskType == L["Search for Mats"] then
											availQty = taskQuantity
										end
										if task.taskType == L["Mail Items"] then
											availQty = min(need, taskQuantity)
										elseif not crafter == UnitName("player") then
											availQty = min(need, taskQuantity) - (playerBags[itemString] or 0)
										else
											availQty = min(need, taskQuantity) -- (crafterBags[itemString] or 0)
										end
										availableMats[itemString] = availQty
										local name = select(1, TSMAPI:GetSafeItemInfo(itemString))
										if not name then
											name = GetItemInfo(itemString)
										end
										local color
										if need == availQty then
											color = "|cff00ff00"
										else
											color = "|cffffff00"
										end
										local row = {
											cols = {
												{
													value = color .. name .. " x" .. availQty .. "|r",
													args = name,
												}
											},
											name = name,
											itemString = taskItemString,
											need = availQty,
											taskType = task.taskType,
										}
										tinsert(stData, row)
									end
								end
							end
						end
					end
				end
			end
		end
	end
	-- store the available mats from source
	TSM.db.realm.gathering.availableMats = CopyTable(availableMats)

	GUI.gatheringFrame.gatherButton:SetText(L["Gather Items"])
	if next(stData) then
		GUI.gatheringFrame.gatherButton:Enable()
		if private.currentTask == L["Visit Vendor"] then
			GUI.gatheringFrame.gatherButton:SetText(L["Buy Vendor Items"])
		elseif private.currentTask == L["Mail Items"] then
			GUI.gatheringFrame.gatherButton:SetText(L["Mail Items"])
		end
	else
		GUI.gatheringFrame.gatherButton:Disable()
	end

	sort(stData, function(a, b) return a.name < b.name end)
	GUI.gatheringFrame.availableST:SetData(stData)
end

function GUI:GatheringEventHandler(event)
	if not GUI.gatheringFrame or not GUI.gatheringFrame:IsShown() then return end

	if event == "GUILDBANKFRAME_OPENED" then
		private.currentSource = UnitName("player")
		private.currentTask = L["Visit Guild Bank"]
	elseif event == "GUILDBANKFRAME_CLOSED" then
		private.currentSource = nil
		private.currentTask = nil
		GUI.gatheringFrame.gatherButton:Disable()
	elseif event == "BANKFRAME_OPENED" then
		private.currentSource = UnitName("player")
		private.currentTask = L["Visit Bank"]
	elseif event == "BANKFRAME_CLOSED" then
		private.currentSource = nil
		private.currentTask = nil
		GUI.gatheringFrame.gatherButton:Disable()
	elseif event == "MERCHANT_SHOW" then
		private.currentSource = L["Vendor"]
		private.currentTask = L["Visit Vendor"]
		-- Refresh task list when vendor opens
		TSMAPI:CreateTimeDelay("craftingTaskListUpdateAfterMerchantShow", 0.1, GUI.UpdateTaskList)
		-- Update Vendor Buy button state
		if GUI.taskListFrame and GUI.taskListFrame.UpdateVendorBuyButton then
			GUI.taskListFrame.UpdateVendorBuyButton()
		end
	elseif event == "MERCHANT_CLOSED" then
		private.currentSource = nil
		private.currentTask = nil
		GUI.gatheringFrame.gatherButton:Disable()
		-- Refresh task list when vendor closes
		TSMAPI:CreateTimeDelay("craftingTaskListUpdateAfterMerchantClose", 0.1, GUI.UpdateTaskList)
		-- Update Vendor Buy button state
		if GUI.taskListFrame and GUI.taskListFrame.UpdateVendorBuyButton then
			GUI.taskListFrame.UpdateVendorBuyButton()
		end
	elseif event == "MAIL_SHOW" then
		private.currentSource = UnitName("player")
		private.currentTask = L["Mail Items"]
	elseif event == "MAIL_CLOSED" then
		private.currentSource = nil
		private.currentTask = nil
		GUI.gatheringFrame.gatherButton:Disable()
	elseif event == "AUCTION_HOUSE_SHOW" then
		TSM.Inventory.gatherQuantity = nil
		TSM.Inventory.gatherItem = nil
		private.currentSource = L["Auction House"]
		private.currentTask = L["Search for Mats"]
		-- Update Search Auction button state
		if GUI.taskListFrame and GUI.taskListFrame.UpdateSearchAuctionButton then
			GUI.taskListFrame.UpdateSearchAuctionButton()
		end
	elseif event == "AUCTION_HOUSE_CLOSED" then
		TSM.Inventory.gatherQuantity = nil
		TSM.Inventory.gatherItem = nil
		private.currentSource = nil
		private.currentTask = nil
		GUI.gatheringFrame.gatherButton:Disable()
		-- Update Search Auction button state
		if GUI.taskListFrame and GUI.taskListFrame.UpdateSearchAuctionButton then
			GUI.taskListFrame.UpdateSearchAuctionButton()
		end
	end
	TSMAPI:CreateTimeDelay("gatheringUpdateThrottle", 0.3, GUI.UpdateGathering)
end

function GUI:GetStatus()
	if not GUI.frame or not GUI.frame:IsVisible() then return end
	return { page = (GUI.frame.content.professionsTab:IsVisible() and "profession" or "groups"), gather = GUI.frame.gather:IsVisible() and true or false, queue = GUI.frame.queue:IsVisible() and true or false }
end


function CheapestVellum(itemPassed)

		-- Return one of the two vellum available
		local MatName = GetItemInfo(itemPassed)
		-- MatName is sometimes nil ???
		if MatName ~= nil then
			local velName
			if strfind(MatName, "Vellum") then
				velName = MatName
			end
			if (velName ~= nil) then
				if strfind(velName, "Weapon") then
					itemPassed = "item:52511:0:0:0:0:0:0"
				else
					itemPassed = "item:52510:0:0:0:0:0:0"
				end
			end
		end
		return itemPassed
end

-- ============================================================================
-- Standalone Task List Window
-- ============================================================================

function GUI:CreateTaskListWindow()
	if GUI.taskListFrame then
		if GUI.taskListFrame:IsVisible() then
			GUI.taskListFrame:Hide()
		else
			-- If window is collapsed, expand it first
			if GUI.taskListFrame.isCollapsed then
				GUI.taskListFrame.isCollapsed = false
				GUI.taskListFrame:SetHeight(290)
				GUI.taskListFrame.content:Show()
				if GUI.taskListFrame.sizer then
					GUI.taskListFrame.sizer:Show()
				end
				if GUI.taskListFrame.collapseBtn then
					GUI.taskListFrame.collapseBtn:SetText("-")
				end
			end
			-- Make sure frame is in a valid position
			if not GUI.taskListFrame:GetTop() or GUI.taskListFrame:GetTop() > UIParent:GetHeight() then
				GUI.taskListFrame:ClearAllPoints()
				GUI.taskListFrame:SetPoint("CENTER")
			end
			GUI.taskListFrame:Show()
			GUI:UpdateTaskList()
		end
		return
	end

	local frameDefaults = {
		x = 100,
		y = 75,
		width = 280,
		height = 290,
		scale = 1,
	}
	local frame = TSMAPI:CreateMovableFrame("TSMCraftingTaskList", frameDefaults)
	frame:SetResizable(true)
	frame:SetMinResize(200, 150)
	-- Clean backdrop without borders
	frame:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8", edgeFile="Interface\\Buttons\\WHITE8X8", edgeSize=0})
	if TSM.db.profile.design and TSM.db.profile.design.frameColors and TSM.db.profile.design.frameColors.frameBG then
		frame:SetBackdropColor(unpack(TSM.db.profile.design.frameColors.frameBG.backdrop))
		frame:SetBackdropBorderColor(0, 0, 0, 0)
	else
		frame:SetBackdropColor(18/255, 18/255, 18/255, 1)
		frame:SetBackdropBorderColor(0, 0, 0, 0)
	end
	tinsert(UISpecialFrames, "TSMCraftingTaskList")
	GUI.taskListFrame = frame

	-- Title
	local title = frame:CreateFontString()
	title:SetFont(TSMAPI.Design:GetContentFont(), 18)
	TSMAPI.Design:SetWidgetLabelColor(title)
	title:SetPoint("TOP", frame, 0, -3)
	title:SetText(L["Task List"])

	-- Collapse button
	local collapseBtn = TSMAPI.GUI:CreateButton(frame, 18)
	collapseBtn:SetPoint("TOPRIGHT", -24, -3)
	collapseBtn:SetWidth(19)
	collapseBtn:SetHeight(19)
	collapseBtn:SetText("-")
	frame.collapseBtn = collapseBtn
	frame.isCollapsed = false

	-- Close button
	local closeBtn = TSMAPI.GUI:CreateButton(frame, 18)
	closeBtn:SetPoint("TOPRIGHT", -3, -3)
	closeBtn:SetWidth(19)
	closeBtn:SetHeight(19)
	closeBtn:SetText("X")
	closeBtn:SetScript("OnClick", function()
		-- Reset collapsed state when closing
		if frame.isCollapsed then
			frame.isCollapsed = false
			frame:SetHeight(290)
			frame.content:Show()
			if frame.sizer then
				frame.sizer:Show()
			end
			if frame.collapseBtn then
				frame.collapseBtn:SetText("-")
			end
		end
		frame:Hide()
	end)

	-- No horizontal line under title (removed)

	-- Content area
	local content = CreateFrame("Frame", nil, frame)
	content:SetPoint("TOPLEFT", 0, -30)
	content:SetPoint("BOTTOMRIGHT")
	frame.content = content

	-- Queue ScrollingTable - upper half (resizable)
	local queueContainer = CreateFrame("Frame", nil, frame.content)
	queueContainer:SetPoint("TOPLEFT", 5, -5)
	queueContainer:SetPoint("TOPRIGHT", -5, -5)
	queueContainer:SetHeight(125)
	TSMAPI.Design:SetFrameColor(queueContainer)
	frame.queueContainer = queueContainer

	local queueCols = {
		{ name = L["Craft Queue"], width = 1, align = "Left" },
	}

	local function OnCraftRowEnter(self, data)
		if not data.spellID then return end
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
		GameTooltip:AddLine(TSM.db.realm.crafts[data.spellID].name .. " (x" .. data.numQueued .. ")")

		local cost = TSM.Cost:GetCraftPrices(data.spellID)
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

		for itemID, matQuantity in pairs(TSM.db.realm.crafts[data.spellID].mats) do
			local name = TSMAPI:GetSafeItemInfo(itemID) or (TSM.db.realm.mats[itemID] and TSM.db.realm.mats[itemID].name) or "?"
			local inventory = TSM.Inventory:GetPlayerBagNum(itemID)
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

		if TSMAPI:AHTabIsVisible("Shopping") then
			GameTooltip:AddLine(" ")
			GameTooltip:AddLine(TSMAPI.Design:GetInlineColor("link") .. "Alt-Click to search in Shopping tab.|r", 1, 1, 1, true)
		end

		GameTooltip:Show()
	end

	local function OnCraftRowLeave()
		GameTooltip:Hide()
	end

	local function OnCraftRowClicked(_, data)
		if IsModifiedClick() and data.spellID then
			local itemID = TSM.db.realm.crafts[data.spellID] and TSM.db.realm.crafts[data.spellID].itemID
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
				TSM.db.realm.queueStatus.collapsed[data.profession .. data.stage] = not TSM.db.realm.queueStatus.collapsed[data.profession .. data.stage]
			else
				TSM.db.realm.queueStatus.collapsed[data.profession] = not TSM.db.realm.queueStatus.collapsed[data.profession]
			end
			GUI:UpdateTaskList()
		elseif data.spellID and data.canCraft and data.canCraft > 0 then
			-- Start crafting when clicking on a queued craft
			if data.index then
				GUI:CastTradeSkill(data.index, min(data.canCraft, data.numQueued), data.velName)
				-- Update task list after a short delay to reflect changes
				TSMAPI:CreateTimeDelay("craftingTaskListUpdateAfterCraft", 0.5, GUI.UpdateTaskList)
			else
				-- Profession window needs to be opened - automatically open it
				if data.profession then
					local currentProfession = GetTradeSkillLine()
					if currentProfession and currentProfession ~= data.profession then
						if data.profession == "Mining" then
							CastSpellByName("Smelting")
						else
							CastSpellByName(data.profession)
						end
						TSMAPI:CreateTimeDelay("craftingTaskListUpdateAfterOpen", 0.3, GUI.UpdateTaskList)
					elseif not currentProfession then
						if data.profession == "Mining" then
							CastSpellByName("Smelting")
						else
							CastSpellByName(data.profession)
						end
						TSMAPI:CreateTimeDelay("craftingTaskListUpdateAfterOpen", 0.3, GUI.UpdateTaskList)
					end
				else
					GUI:OpenFirstProfession()
					TSMAPI:CreateTimeDelay("craftingTaskListUpdateAfterOpen", 0.3, GUI.UpdateTaskList)
				end
			end
		end
	end

	frame.queueST = TSMAPI:CreateScrollingTable(queueContainer, queueCols, { OnClick = OnCraftRowClicked, OnEnter = OnCraftRowEnter, OnLeave = OnCraftRowLeave }, 14)
	frame.queueST:SetData({})
	frame.queueST:DisableSelection(true)

	-- Resizable separator between tables
	local separator = CreateFrame("Frame", nil, frame.content)
	separator:SetPoint("TOPLEFT", queueContainer, "BOTTOMLEFT", 0, -2)
	separator:SetPoint("TOPRIGHT", queueContainer, "BOTTOMRIGHT", 0, -2)
	separator:SetHeight(10)
	separator:EnableMouse(true)
	separator:SetScript("OnEnter", function(self)
		self:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8"})
		self:SetBackdropColor(0.3, 0.3, 0.3, 0.5)
		SetCursor("Interface\\CURSOR\\UI-Cursor-SizeUp")
	end)
	separator:SetScript("OnLeave", function(self)
		self:SetBackdrop(nil)
		ResetCursor()
	end)
	separator:SetScript("OnMouseDown", function(self)
		self.isResizing = true
		self.startY = select(2, GetCursorPosition()) / self:GetEffectiveScale()
		self.startHeight = queueContainer:GetHeight()
	end)
	separator:SetScript("OnMouseUp", function(self)
		self.isResizing = false
	end)
	separator:SetScript("OnUpdate", function(self)
		if self.isResizing then
			local currentY = select(2, GetCursorPosition()) / self:GetEffectiveScale()
			local deltaY = currentY - self.startY
			local newHeight = math.max(100, math.min(frame:GetHeight() - 200, self.startHeight + deltaY))
			queueContainer:SetHeight(newHeight)
		end
	end)
	frame.separator = separator

	-- Materials by craft table - fills remaining space (adjusted for two rows of buttons)
	local matContainer = CreateFrame("Frame", nil, frame.content)
	matContainer:SetPoint("TOPLEFT", separator, "BOTTOMLEFT", 0, -5)
	matContainer:SetPoint("TOPRIGHT", separator, "BOTTOMRIGHT", 0, -5)
	matContainer:SetPoint("BOTTOMLEFT", 5, 85)
	matContainer:SetPoint("BOTTOMRIGHT", -5, 85)
	TSMAPI.Design:SetFrameColor(matContainer)
	frame.matContainer = matContainer

	local matCols = {
		{ name = L["Material Name"], width = 0.69, align = "Left" },
		{ name = L["Need"], width = 0.2, align = "LEFT" },
		{ name = L["Total"], width = 0.2, align = "LEFT" },
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
				local itemID = TSMAPI:GetItemID(data.itemString)
				if itemID then
					-- Find item in merchant inventory
					local numItems = GetMerchantNumItems()
					for i = 1, numItems do
						local merchantItemLink = GetMerchantItemLink(i)
						local merchantItemID = merchantItemLink and tonumber(string.match(merchantItemLink, "item:(%d+)"))
						if merchantItemID == itemID then
							-- Calculate how many we need
							local have = TSM.Inventory:GetTotalQuantity(data.itemString)
							local need = data.cols[2].args[1] -- This is the "Need" value
							if need > 0 then
								-- Get stack size and buy enough stacks
								local _, _, _, quantity = GetMerchantItemInfo(i)
								local stacksToBuy = ceil(need / quantity)
								for j = 1, stacksToBuy do
									BuyMerchantItem(i, 1)
								end
								-- Refresh task list after purchase
								TSMAPI:CreateTimeDelay("craftingTaskListUpdateAfterVendorBuy", 0.3, GUI.UpdateTaskList)
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

	-- Profit/Cost labels (adjusted for two rows of buttons)
	local profitLabel = TSMAPI.GUI:CreateLabel(frame.content, "medium")
	profitLabel:SetPoint("BOTTOMLEFT", 5, 60)
	profitLabel:SetPoint("BOTTOMRIGHT", -35, 60)
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
		self:SetText(format(L["Estimated Cost: %s\nEstimated Profit: %s"], cost, profit))
	end
	profitLabel:SetAmounts("---", "---")
	frame.profitLabel = profitLabel

	-- Clear Queue button (top-left)
	local clearQueueBtn = TSMAPI.GUI:CreateButton(frame.content, 14)
	clearQueueBtn:SetPoint("BOTTOMLEFT", 5, 30)
	clearQueueBtn:SetWidth(120)
	clearQueueBtn:SetHeight(20)
	clearQueueBtn:SetText(L["Clear Queue"])
	clearQueueBtn:SetScript("OnClick", function()
		TSM.Queue:ClearQueue()
		GUI:UpdateTaskList()
	end)

	-- Refresh button (top-right, narrower to leave space for resize grip)
	local refreshBtn = TSMAPI.GUI:CreateButton(frame.content, 14)
	refreshBtn:SetPoint("BOTTOMLEFT", clearQueueBtn, "BOTTOMRIGHT", 5, 0)
	refreshBtn:SetPoint("BOTTOMRIGHT", -30, 30)
	refreshBtn:SetHeight(20)
	refreshBtn:SetText(L["Refresh"])
	refreshBtn:SetScript("OnClick", function()
		GUI:UpdateTaskList()
	end)

	-- Vendor Buy button (bottom-left)
	local vendorBuyBtn = TSMAPI.GUI:CreateButton(frame.content, 14)
	vendorBuyBtn:SetPoint("BOTTOMLEFT", 5, 5)
	vendorBuyBtn:SetWidth(120)
	vendorBuyBtn:SetHeight(20)
	vendorBuyBtn:SetText("Vendor Buy")

	-- Function to update button state
	local function UpdateVendorBuyButton()
		if MerchantFrame and MerchantFrame:IsVisible() then
			vendorBuyBtn:Enable()
		else
			vendorBuyBtn:Disable()
		end
	end

	-- Store reference for event handler
	frame.UpdateVendorBuyButton = UpdateVendorBuyButton

	vendorBuyBtn:SetScript("OnClick", function()
		-- Get aggregated materials from queue
		local queuedCrafts = TSM.Queue:GetQueue()
		local aggregatedMats = AggregateRawMaterialsFromQueue(queuedCrafts)

		-- Buy vendor items
		local numItems = GetMerchantNumItems()
		local purchasedAny = false
		for itemString, quantity in pairs(aggregatedMats) do
			local isVendorItem = TSMAPI:GetVendorCost(itemString) ~= nil
			if isVendorItem then
				local have = TSM.Inventory:GetTotalQuantity(itemString)
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
			TSMAPI:CreateTimeDelay("craftingTaskListUpdateAfterVendorBuy", 0.3, GUI.UpdateTaskList)
		else
			TSM:Print("No vendor items needed or available.")
		end
	end)

	-- Initial button state
	UpdateVendorBuyButton()

	-- Search Auction button (bottom-right)
	local searchAuctionBtn = TSMAPI.GUI:CreateButton(frame.content, 14)
	searchAuctionBtn:SetPoint("BOTTOMLEFT", vendorBuyBtn, "BOTTOMRIGHT", 5, 0)
	searchAuctionBtn:SetPoint("BOTTOMRIGHT", -30, 5)
	searchAuctionBtn:SetHeight(20)
	searchAuctionBtn:SetText("Search Auction")

	-- Function to update button state
	local function UpdateSearchAuctionButton()
		-- Check if AH frame exists and is shown, AND if Shopping tab is visible
		if AuctionFrame and AuctionFrame:IsShown() and TSMAPI:AHTabIsVisible("Shopping") then
			searchAuctionBtn:Enable()
		else
			searchAuctionBtn:Disable()
		end
	end

	-- Store reference for event handler
	frame.UpdateSearchAuctionButton = UpdateSearchAuctionButton

	searchAuctionBtn:SetScript("OnClick", function()
		-- Get aggregated materials from queue
		local queuedCrafts = TSM.Queue:GetQueue()
		local aggregatedMats = AggregateRawMaterialsFromQueue(queuedCrafts)

		-- Search for non-vendor items
		local searchList = {}
		for itemString, quantity in pairs(aggregatedMats) do
			local isVendorItem = TSMAPI:GetVendorCost(itemString) ~= nil
			if not isVendorItem then
				local have = TSM.Inventory:GetTotalQuantity(itemString)
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
			-- Use the Shopping module's public API function directly
			local ShoppingAddon = LibStub("AceAddon-3.0"):GetAddon("TSM_Shopping", true)
			if ShoppingAddon and ShoppingAddon.StartFilterSearch then
				ShoppingAddon:StartFilterSearch(searchString)
				TSM:Print("Searching for " .. #searchList .. " materials in Shopping tab.")
			else
				TSM:Print("Could not start search. Shopping module not loaded.")
			end
		else
			TSM:Print("No materials needed from auction house.")
		end
	end)

	-- Initial button state
	UpdateSearchAuctionButton()

	-- Update button states when frame is shown or becomes visible
	frame:SetScript("OnShow", function()
		UpdateVendorBuyButton()
		UpdateSearchAuctionButton()
	end)

	-- Also update periodically when frame is visible (to catch state changes)
	frame:SetScript("OnUpdate", function(self, elapsed)
		self.timeSinceLastUpdate = (self.timeSinceLastUpdate or 0) + elapsed
		if self.timeSinceLastUpdate >= 0.5 then
			UpdateVendorBuyButton()
			UpdateSearchAuctionButton()
			self.timeSinceLastUpdate = 0
		end
	end)

	-- Resize handle (bottom-right corner grip)
	local sizer = CreateFrame("Frame", nil, frame)
	sizer:SetPoint("BOTTOMRIGHT", -2, 2)
	sizer:SetWidth(20)
	sizer:SetHeight(20)
	sizer:EnableMouse()
	sizer:SetScript("OnMouseDown", function()
		frame:StartSizing("BOTTOMRIGHT")
	end)
	sizer:SetScript("OnMouseUp", function()
		frame:StopMovingOrSizing()
		frame:SavePositionAndSize()
	end)
	local image = sizer:CreateTexture(nil, "BACKGROUND")
	image:SetAllPoints()
	image:SetTexture("Interface\\Addons\\TradeSkillMaster\\Media\\Sizer")

	frame.sizer = sizer

	-- Collapse/Expand functionality
	local collapsedHeight = 30
	local expandedHeight = frame:GetHeight()

	collapseBtn:SetScript("OnClick", function()
		if frame.isCollapsed then
			-- Expand
			frame:SetHeight(expandedHeight)
			frame.content:Show()
			sizer:Show()
			frame.isCollapsed = false
			collapseBtn:SetText("-")
			-- Save the new height
			frame:SavePositionAndSize()
		else
			-- Collapse
			expandedHeight = frame:GetHeight()
			frame:SetHeight(collapsedHeight)
			frame.content:Hide()
			sizer:Hide()
			frame.isCollapsed = true
			collapseBtn:SetText("+")
			-- Save the new height
			frame:SavePositionAndSize()
		end
	end)

	frame:Show()
	GUI:UpdateTaskList()
end

function GUI:UpdateTaskList()
	if not GUI.taskListFrame or not GUI.taskListFrame:IsVisible() then return end

	TSM:UpdateCraftReverseLookup()
	local queuedCrafts, queuedMats, totalCost, totalProfit = TSM.Queue:GetQueue()
	GUI.taskListFrame.profitLabel:SetAmounts(totalCost, totalProfit)

	-- Update queue table
	local stData = {}
	local bagTotals = TSM.Inventory:GetTotals()

	for profession, crafts in pairs(queuedCrafts) do
		local professionColor = "|cffffffff"
		local players = {}
		for player, data in pairs(TSM.db.realm.tradeSkills) do
			if data[profession] then
				tinsert(players, player)
			end
		end

		local professionCollapsed = TSM.db.realm.queueStatus.collapsed[profession]
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
				local stageCollapsed = TSM.db.realm.queueStatus.collapsed[profession .. stage.name]
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

						for itemID, quantity in pairs(TSM.db.realm.crafts[spellID].mats) do
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

						-- Find the trade skill index for this spellID
						local tradeSkillIndex = nil
						for i = 1, GetNumTradeSkills() do
							if TSM.Util:GetSpellID(i) == spellID then
								tradeSkillIndex = i
								break
							end
						end

						local row = {
							cols = {
								{
									value = "        " .. color .. TSM.db.realm.crafts[spellID].name .. " (x" .. numQueued .. ")" .. "|r",
								},
							},
							spellID = spellID,
							index = tradeSkillIndex,
							canCraft = (canCraft > 0) and canCraft or 0,
							numQueued = numQueued,
							profit = select(3, TSM.Cost:GetCraftPrices(spellID)),
							velName = TSM.db.realm.crafts[spellID].velName,
							profession = TSM.db.realm.crafts[spellID].profession,
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

	GUI.taskListFrame.queueST:SetData(stData)

	-- Update materials table: only raw materials
	stData = {}
	local order = 0

	local aggregatedMats = AggregateRawMaterialsFromQueue(queuedCrafts)

	local sortedMats = {}
	for itemString, totalQuantity in pairs(aggregatedMats) do
		tinsert(sortedMats, {itemString = itemString, quantity = totalQuantity})
	end

	table.sort(sortedMats, function(a, b)
		local aName = TSM.db.realm.mats[a.itemString] and TSM.db.realm.mats[a.itemString].name or TSMAPI:GetSafeItemInfo(a.itemString) or "?"
		local bName = TSM.db.realm.mats[b.itemString] and TSM.db.realm.mats[b.itemString].name or TSMAPI:GetSafeItemInfo(b.itemString) or "?"
		return aName < bName
	end)

	for _, matInfo in ipairs(sortedMats) do
		local itemString = matInfo.itemString
		local quantity = matInfo.quantity
		local have = TSM.Inventory:GetTotalQuantity(itemString)
		local need = max(quantity - have, 0)

		local color
		local isVendorItem = TSMAPI:GetVendorCost(itemString) ~= nil

		if need == 0 then
			if TSM.Inventory:GetPlayerBagNum(itemString) >= quantity then
				color = "|cff00ff00"
			else
				color = "|cffffff00"
			end
		elseif isVendorItem then
			-- Vendor items are shown in blue
			color = "|cff00bfff"
		else
			color = "|cffff0000"
		end

		local matName = TSM.db.realm.mats[itemString] and TSM.db.realm.mats[itemString].name or TSMAPI:GetSafeItemInfo(itemString) or "?"

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

	GUI.taskListFrame.matST:SetData(stData)
end
