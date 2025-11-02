-- ------------------------------------------------------------------------------ --
--                            TradeSkillMaster_Mailing                            --
--            http://www.curse.com/addons/wow/tradeskillmaster_mailing            --
--                                                                                --
--             A TradeSkillMaster Addon (http://tradeskillmaster.com)             --
--    All Rights Reserved* - Detailed license information included with addon.    --
-- ------------------------------------------------------------------------------ --

local TSM = select(2, ...)
local Send = TSM:NewModule("Send", "AceEvent-3.0")
local L = LibStub("AceLocale-3.0"):GetLocale("TradeSkillMaster_Mailing")

local private = {
	target = "",
	itemString = nil,
	maxQuantity = 0,
	codAmount = 0,
}

function Send:CreateTab(parent)
	local frame = CreateFrame("Frame", nil, parent)
	frame:Hide()
	frame:SetPoint("TOPLEFT", 5, -5)
	frame:SetPoint("BOTTOMRIGHT", -5, 5)
	frame:SetAllPoints()
	TSMAPI.Design:SetFrameColor(frame)

	local helpText = TSMAPI.GUI:CreateLabel(frame, "normal")
	helpText:SetPoint("TOPLEFT", 10, -10)
	helpText:SetPoint("TOPRIGHT", -10, -10)
	helpText:SetJustifyH("LEFT")
	helpText:SetText(L["This tab allows you to quickly send any quantity of an item to another character. You can also specify a COD to set on the mail (per item)."])

	TSMAPI.GUI:CreateHorizontalLine(frame, -(helpText:GetHeight()+20))

	local targetLabel = TSMAPI.GUI:CreateLabel(frame, "normal")
	targetLabel:SetPoint("TOPLEFT", 10, -(helpText:GetHeight()+30))
	targetLabel:SetText(L["Target:"])

	local targetBox = TSMAPI.GUI:CreateEditBox(frame, "editbox")
	targetBox:SetPoint("TOPLEFT", targetLabel, "TOPRIGHT", 5, 0)
	targetBox:SetPoint("TOPRIGHT", -10, 0)
	targetBox:SetHeight(20)
	targetBox:SetCallback("OnEnterPressed", function(self)
		private.target = self:GetText()
		self:ClearFocus()
	end)
	targetBox:SetCallback("OnTextChanged", function(self)
		private.target = self:GetText()
	end)
	frame.targetBox = targetBox

	local itemLabel = TSMAPI.GUI:CreateLabel(frame, "normal")
	itemLabel:SetPoint("TOPLEFT", targetLabel, "BOTTOMLEFT", 0, -15)
	itemLabel:SetText(L["Item:"])

	local itemButton = CreateFrame("Button", nil, frame)
	itemButton:SetPoint("LEFT", itemLabel, "RIGHT", 5, 0)
	itemButton:SetSize(40, 40)
	itemButton:SetNormalTexture("Interface\\Buttons\\UI-Quickslot2")
	itemButton:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
	itemButton:RegisterForDrag("LeftButton")
	itemButton:RegisterForClicks("LeftButtonUp", "RightButtonUp")

	local itemIcon = itemButton:CreateTexture(nil, "ARTWORK")
	itemIcon:SetPoint("CENTER")
	itemIcon:SetSize(36, 36)
	itemIcon:SetTexture(nil)
	itemButton.icon = itemIcon

	itemButton:SetScript("OnClick", function(self, button)
		if button == "RightButton" then
			private:ClearItem(frame)
		end
	end)

	itemButton:SetScript("OnReceiveDrag", function(self)
		local cType, _, link = GetCursorInfo()
		if cType == "item" then
			private:SetItem(frame, link)
			ClearCursor()
		end
	end)

	itemButton:SetScript("OnDragStart", function(self)
		if private.itemString then
			local link = select(2, TSMAPI:GetSafeItemInfo(private.itemString))
			if link then
				PickupItem(link)
			end
		end
	end)

	itemButton:SetScript("OnMouseDown", function(self, button)
		if button == "LeftButton" then
			local cType, _, link = GetCursorInfo()
			if cType == "item" then
				private:SetItem(frame, link)
				ClearCursor()
			end
		end
	end)

	itemButton:SetScript("OnEnter", function(self)
		if private.itemString then
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
			local link = select(2, TSMAPI:GetSafeItemInfo(private.itemString))
			if link then
				TSMAPI:SafeTooltipLink(link)
			end
			GameTooltip:Show()
		end
	end)

	itemButton:SetScript("OnLeave", function(self)
		GameTooltip:Hide()
	end)

	frame.itemButton = itemButton

	local itemNameLabel = TSMAPI.GUI:CreateLabel(frame, "normal")
	itemNameLabel:SetPoint("LEFT", itemButton, "RIGHT", 10, 0)
	itemNameLabel:SetPoint("RIGHT", -10, 0)
	itemNameLabel:SetJustifyH("LEFT")
	itemNameLabel:SetText(L["Drag an item here"])
	frame.itemNameLabel = itemNameLabel

	local quantityLabel = TSMAPI.GUI:CreateLabel(frame, "normal")
	quantityLabel:SetPoint("TOPLEFT", itemLabel, "BOTTOMLEFT", 0, -15)
	quantityLabel:SetText(L["Max Quantity (0 = all):"])

	local quantityBox = TSMAPI.GUI:CreateEditBox(frame, "editbox")
	quantityBox:SetPoint("LEFT", quantityLabel, "RIGHT", 5, 0)
	quantityBox:SetWidth(100)
	quantityBox:SetHeight(20)
	quantityBox:SetText("0")
	quantityBox:SetCallback("OnEnterPressed", function(self)
		private.maxQuantity = tonumber(self:GetText()) or 0
		self:ClearFocus()
	end)
	quantityBox:SetCallback("OnTextChanged", function(self)
		private.maxQuantity = tonumber(self:GetText()) or 0
	end)
	frame.quantityBox = quantityBox

	local codLabel = TSMAPI.GUI:CreateLabel(frame, "normal")
	codLabel:SetPoint("TOPLEFT", quantityLabel, "BOTTOMLEFT", 0, -15)
	codLabel:SetText(L["COD per Item:"])

	local codBox = TSMAPI.GUI:CreateEditBox(frame, "editbox")
	codBox:SetPoint("LEFT", codLabel, "RIGHT", 5, 0)
	codBox:SetWidth(150)
	codBox:SetHeight(20)
	codBox:SetText("0g")
	codBox:SetCallback("OnEnterPressed", function(self)
		private.codAmount = TSMAPI:UnformatTextMoney(self:GetText()) or 0
		self:SetText(TSMAPI:FormatTextMoney(private.codAmount, nil, "|cffffffff"))
		self:ClearFocus()
	end)
	codBox:SetCallback("OnTextChanged", function(self)
		local value = TSMAPI:UnformatTextMoney(self:GetText()) or 0
		private.codAmount = value
	end)
	frame.codBox = codBox

	local infoText = TSMAPI.GUI:CreateLabel(frame, "small")
	infoText:SetPoint("TOPLEFT", codLabel, "BOTTOMLEFT", 0, -20)
	infoText:SetPoint("TOPRIGHT", -10, 0)
	infoText:SetJustifyH("LEFT")
	infoText:SetTextColor(0.8, 0.8, 0.8)
	infoText:SetText(L["Right-click the item icon to clear it."])

	local sendButton = TSMAPI.GUI:CreateButton(frame, 15)
	sendButton:SetPoint("BOTTOM", 0, 10)
	sendButton:SetWidth(200)
	sendButton:SetHeight(30)
	sendButton:SetText(L["Send Mail"])
	sendButton:SetScript("OnClick", function()
		private:SendMail()
	end)
	frame.sendButton = sendButton

	Send.frame = frame
	return frame
end

function private:SetItem(frame, link)
	local itemString = TSMAPI:GetItemString(link)
	if not itemString then return end

	private.itemString = itemString

	local name, itemLink = TSMAPI:GetSafeItemInfo(itemString)
	local _, _, _, _, _, _, _, _, _, texture = GetItemInfo(itemLink)

	frame.itemButton.icon:SetTexture(texture)
	frame.itemNameLabel:SetText(itemLink or name or "Unknown")
end

function private:ClearItem(frame)
	private.itemString = nil
	frame.itemButton.icon:SetTexture(nil)
	frame.itemNameLabel:SetText(L["Drag an item here"])
end

function private:SendMail()
	if private.target == "" then
		TSM:Print(L["Please enter a recipient name."])
		return
	end

	if not private.itemString then
		TSM:Print(L["Please select an item to send."])
		return
	end

	local totalQuantity = 0
	for _, _, itemString, quantity in TSMAPI:GetBagIterator() do
		if itemString == private.itemString then
			totalQuantity = totalQuantity + quantity
		end
	end

	if totalQuantity == 0 then
		TSM:Print(L["You don't have any of this item."])
		return
	end

	local quantityToSend = private.maxQuantity
	if quantityToSend == 0 or quantityToSend > totalQuantity then
		quantityToSend = totalQuantity
	end

	local itemsToSend = {[private.itemString] = quantityToSend}
	local codAmount = nil
	if private.codAmount > 0 then
		codAmount = private.codAmount
	end

	TSM:Printf(L["Sending %d %s to %s..."], quantityToSend, select(2, TSMAPI:GetSafeItemInfo(private.itemString)), private.target)

	TSM.AutoMail:SendItems(itemsToSend, private.target, function()
		TSM:Print(L["Mail sent successfully!"])
	end, codAmount)
end

Send.frame = nil
