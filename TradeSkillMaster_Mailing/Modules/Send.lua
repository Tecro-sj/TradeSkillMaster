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
	subject = "",
	body = "",
	items = {},
	money = 0,
	moneyMode = "send",
	maxItemSlots = 12,
	contactsMenuOpen = false
}

local CONTACT_MENU_OPTIONS = {
	"Add Contact",
	"Remove Contact",
	"Recently Mailed",
	"Alts",
	"Friends",
	"Guild",
	"Close"
}

function Send:CreateTab(parent)
	local frame = CreateFrame("Frame", nil, parent)
	frame:Hide()
	frame:SetPoint("TOPLEFT", 5, -5)
	frame:SetPoint("BOTTOMRIGHT", -5, 5)
	frame:SetAllPoints()
	TSMAPI.Design:SetFrameColor(frame)

	local yOffset = -10

	local targetLabel = TSMAPI.GUI:CreateLabel(frame, "small")
	targetLabel:SetPoint("TOPLEFT", 10, yOffset)
	targetLabel:SetHeight(20)
	targetLabel:SetJustifyV("CENTER")
	targetLabel:SetJustifyH("LEFT")
	targetLabel:SetText(L["To:"])

	local targetBox = TSMAPI.GUI:CreateInputBox(frame)
	targetBox:SetPoint("TOPLEFT", targetLabel, "TOPRIGHT", 5, 0)
	targetBox:SetWidth(150)
	targetBox:SetHeight(20)
	targetBox:SetText(private.target)
	targetBox:SetScript("OnEnterPressed", function(self)
		self:ClearFocus()
	end)
	targetBox:SetScript("OnEditFocusLost", function(self)
		self:HighlightText(0, 0)
		private.target = self:GetText():trim()
		private:UpdateAutoSubject()
	end)
	targetBox:SetScript("OnTabPressed", function(self)
		self:ClearFocus()
		frame.subjectBox:SetFocus()
		frame.subjectBox:HighlightText()
	end)
	TSMAPI.GUI:SetAutoComplete(targetBox, AUTOCOMPLETE_LIST.MAIL)
	targetBox.tooltip = L["Enter the name of the player you want to send this mail to."].."\n\n"..TSM.SPELLING_WARNING
	frame.targetBox = targetBox

	local contactsBtn = TSMAPI.GUI:CreateButton(frame, 15)
	contactsBtn:SetPoint("TOPLEFT", targetBox, "TOPRIGHT", 5, 0)
	contactsBtn:SetWidth(80)
	contactsBtn:SetHeight(20)
	contactsBtn:SetText(L["Contacts"])
	contactsBtn:SetScript("OnClick", function(self)
		private:ToggleContactsMenu(self, frame)
	end)
	contactsBtn.tooltip = L["Open contacts menu to select recipients."]
	frame.contactsBtn = contactsBtn

	yOffset = yOffset - 30
	local subjectLabel = TSMAPI.GUI:CreateLabel(frame, "small")
	subjectLabel:SetPoint("TOPLEFT", 10, yOffset)
	subjectLabel:SetHeight(20)
	subjectLabel:SetJustifyV("CENTER")
	subjectLabel:SetJustifyH("LEFT")
	subjectLabel:SetText(L["Subject:"])

	local subjectBox = TSMAPI.GUI:CreateInputBox(frame)
	subjectBox:SetPoint("TOPLEFT", subjectLabel, "TOPRIGHT", 5, 0)
	subjectBox:SetPoint("TOPRIGHT", -10, yOffset)
	subjectBox:SetHeight(20)
	subjectBox:SetText(private.subject)
	subjectBox:SetScript("OnEnterPressed", function(self)
		self:ClearFocus()
	end)
	subjectBox:SetScript("OnEditFocusLost", function(self)
		self:HighlightText(0, 0)
		private.subject = self:GetText():trim()
	end)
	subjectBox:SetScript("OnTabPressed", function(self)
		self:ClearFocus()
		frame.bodyBox:SetFocus()
	end)
	subjectBox.tooltip = L["Subject line for the mail. This will be auto-filled based on items or gold sent."]
	frame.subjectBox = subjectBox

	yOffset = yOffset - 30
	local bodyLabel = TSMAPI.GUI:CreateLabel(frame, "small")
	bodyLabel:SetPoint("TOPLEFT", 10, yOffset)
	bodyLabel:SetHeight(20)
	bodyLabel:SetJustifyV("TOP")
	bodyLabel:SetJustifyH("LEFT")
	bodyLabel:SetText(L["Message:"])

	local bodyBox = CreateFrame("EditBox", nil, frame)
	bodyBox:SetPoint("TOPLEFT", bodyLabel, "BOTTOMLEFT", 0, -5)
	bodyBox:SetPoint("TOPRIGHT", -10, yOffset - 25)
	bodyBox:SetHeight(60)
	bodyBox:SetMultiLine(true)
	bodyBox:SetAutoFocus(false)
	bodyBox:SetFontObject(GameFontHighlight)
	bodyBox:SetMaxLetters(500)

	local bodyBg = bodyBox:CreateTexture(nil, "BACKGROUND")
	bodyBg:SetAllPoints()
	bodyBg:SetColorTexture(0, 0, 0, 0.5)

	bodyBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
	bodyBox:SetScript("OnEditFocusLost", function(self)
		private.body = self:GetText():trim()
	end)
	bodyBox:SetText(private.body)
	bodyBox.tooltip = L["Optional message body for the mail."]
	frame.bodyBox = bodyBox

	yOffset = yOffset - 100
	local itemsLabel = TSMAPI.GUI:CreateLabel(frame, "normal")
	itemsLabel:SetPoint("TOPLEFT", 10, yOffset)
	itemsLabel:SetHeight(20)
	itemsLabel:SetJustifyV("CENTER")
	itemsLabel:SetJustifyH("LEFT")
	itemsLabel:SetText(L["Items:"])

	yOffset = yOffset - 25
	frame.itemSlots = {}
	local slotsPerRow = 6
	local slotSize = 37
	local slotSpacing = 5

	for i = 1, private.maxItemSlots do
		local row = math.floor((i - 1) / slotsPerRow)
		local col = (i - 1) % slotsPerRow

		local slot = private:CreateItemSlot(frame, i)
		slot:SetPoint("TOPLEFT", 10 + (col * (slotSize + slotSpacing)), yOffset - (row * (slotSize + slotSpacing)))
		slot:SetSize(slotSize, slotSize)
		frame.itemSlots[i] = slot
	end

	yOffset = yOffset - (math.ceil(private.maxItemSlots / slotsPerRow) * (slotSize + slotSpacing)) - 10

	TSMAPI.GUI:CreateHorizontalLine(frame, yOffset)
	yOffset = yOffset - 10

	local moneyLabel = TSMAPI.GUI:CreateLabel(frame, "small")
	moneyLabel:SetPoint("TOPLEFT", 10, yOffset)
	moneyLabel:SetHeight(20)
	moneyLabel:SetJustifyV("CENTER")
	moneyLabel:SetJustifyH("LEFT")
	moneyLabel:SetText(L["Gold / Silver / Copper:"])

	local moneyBox = TSMAPI.GUI:CreateInputBox(frame)
	moneyBox:SetPoint("TOPLEFT", moneyLabel, "TOPRIGHT", 5, 0)
	moneyBox:SetWidth(120)
	moneyBox:SetHeight(20)
	moneyBox:SetText(TSMAPI:FormatTextMoney(private.money))
	moneyBox:SetScript("OnEnterPressed", function(self)
		local copper = TSMAPI:UnformatTextMoney(self:GetText():trim())
		if copper then
			private.money = copper
			self:SetText(TSMAPI:FormatTextMoney(copper))
			self:ClearFocus()
			private:UpdateAutoSubject()
		else
			self:SetFocus()
		end
	end)
	moneyBox:SetScript("OnEditFocusLost", function(self)
		local copper = TSMAPI:UnformatTextMoney(self:GetText():trim())
		if copper then
			private.money = copper
			self:SetText(TSMAPI:FormatTextMoney(copper))
		end
	end)
	moneyBox.tooltip = L["Enter the amount of money to send. Format: XXXg YYs ZZc"]
	frame.moneyBox = moneyBox

	local sendMoneyBtn = TSMAPI.GUI:CreateButton(frame, 15)
	sendMoneyBtn:SetPoint("TOPLEFT", moneyBox, "TOPRIGHT", 10, 0)
	sendMoneyBtn:SetWidth(100)
	sendMoneyBtn:SetHeight(20)
	sendMoneyBtn:SetText(L["Send Money"])
	sendMoneyBtn:SetScript("OnClick", function(self)
		private.moneyMode = "send"
		sendMoneyBtn:LockHighlight()
		codBtn:UnlockHighlight()
		private:UpdateAutoSubject()
	end)
	sendMoneyBtn.tooltip = L["Send money directly to the recipient."]
	sendMoneyBtn:LockHighlight()
	frame.sendMoneyBtn = sendMoneyBtn

	local codBtn = TSMAPI.GUI:CreateButton(frame, 15)
	codBtn:SetPoint("TOPLEFT", sendMoneyBtn, "TOPRIGHT", 5, 0)
	codBtn:SetWidth(100)
	codBtn:SetHeight(20)
	codBtn:SetText(L["C.O.D."])
	codBtn:SetScript("OnClick", function(self)
		private.moneyMode = "cod"
		codBtn:LockHighlight()
		sendMoneyBtn:UnlockHighlight()
		private:UpdateAutoSubject()
	end)
	codBtn.tooltip = L["Send items with Cash on Delivery - recipient pays on receiving."]
	frame.codBtn = codBtn

	yOffset = yOffset - 35
	local sendBtn = TSMAPI.GUI:CreateButton(frame, 15)
	sendBtn:SetPoint("TOPLEFT", 10, yOffset)
	sendBtn:SetPoint("TOPRIGHT", -10, yOffset)
	sendBtn:SetHeight(40)
	sendBtn:SetText(L["Send Mail"])
	sendBtn:SetScript("OnClick", function()
		private:SendMail(frame)
	end)
	sendBtn.tooltip = L["Click to send the mail. If more than 12 items, multiple mails will be sent."]
	frame.sendBtn = sendBtn

	return frame
end

function private:CreateItemSlot(parent, index)
	local slot = CreateFrame("Button", nil, parent)
	slot:SetSize(37, 37)

	local bg = slot:CreateTexture(nil, "BACKGROUND")
	bg:SetAllPoints()
	bg:SetColorTexture(0, 0, 0, 0.5)

	local border = slot:CreateTexture(nil, "BORDER")
	border:SetAllPoints()
	border:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
	border:SetBlendMode("ADD")
	border:SetAlpha(0.5)

	slot.icon = slot:CreateTexture(nil, "ARTWORK")
	slot.icon:SetPoint("TOPLEFT", 2, -2)
	slot.icon:SetPoint("BOTTOMRIGHT", -2, 2)
	slot.icon:SetTexture(nil)

	slot.count = slot:CreateFontString(nil, "OVERLAY")
	slot.count:SetFontObject(NumberFontNormal)
	slot.count:SetPoint("BOTTOMRIGHT", -2, 2)
	slot.count:SetText("")

	slot.itemLink = nil
	slot.quantity = 0
	slot.index = index

	slot:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	slot:RegisterForDrag("LeftButton")

	slot:SetScript("OnClick", function(self, button)
		if button == "RightButton" then
			private:ClearItemSlot(self)
		end
	end)

	slot:SetScript("OnReceiveDrag", function(self)
		private:OnItemDrag(self)
	end)

	slot:SetScript("OnDragStart", function(self)
		if self.itemLink then
			PickupItem(self.itemLink)
		end
	end)

	slot:SetScript("OnMouseDown", function(self, button)
		if button == "LeftButton" then
			private:OnItemDrag(self)
		end
	end)

	slot:SetScript("OnEnter", function(self)
		if self.itemLink then
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
			GameTooltip:SetHyperlink(self.itemLink)
			GameTooltip:Show()
		end
	end)

	slot:SetScript("OnLeave", function(self)
		GameTooltip:Hide()
	end)

	return slot
end

function private:OnItemDrag(slot)
	local cType, _, link = GetCursorInfo()
	if cType == "item" then
		local itemString = TSMAPI:GetItemString(link)
		local numHave = 0
		for _, _, iString, quantity in TSMAPI:GetBagIterator() do
			if iString == itemString then
				numHave = numHave + quantity
			end
		end

		slot.itemLink = link
		slot.quantity = numHave

		local _, _, _, _, _, _, _, _, _, texture = GetItemInfo(link)
		slot.icon:SetTexture(texture)

		if numHave > 1 then
			slot.count:SetText(numHave)
		else
			slot.count:SetText("")
		end

		private.items[slot.index] = {link = link, quantity = numHave}

		ClearCursor()
		private:UpdateAutoSubject()
	end
end

function private:ClearItemSlot(slot)
	slot.itemLink = nil
	slot.quantity = 0
	slot.icon:SetTexture(nil)
	slot.count:SetText("")
	private.items[slot.index] = nil
	private:UpdateAutoSubject()
end

function private:UpdateAutoSubject()
	if private.subject ~= "" then
		return
	end

	local itemCount = 0
	local firstItem = nil

	for _, itemData in pairs(private.items) do
		if itemData then
			itemCount = itemCount + 1
			if not firstItem then
				firstItem = itemData.link
			end
		end
	end

	local autoSubject = ""

	if itemCount > 0 and private.money > 0 then
		if itemCount == 1 then
			autoSubject = format("%s + %s", firstItem, TSMAPI:FormatTextMoney(private.money))
		else
			autoSubject = format("%d items + %s", itemCount, TSMAPI:FormatTextMoney(private.money))
		end
	elseif itemCount > 0 then
		if itemCount == 1 then
			autoSubject = firstItem
		else
			autoSubject = format("%d items", itemCount)
		end
	elseif private.money > 0 then
		autoSubject = TSMAPI:FormatTextMoney(private.money)
	end

	if autoSubject ~= "" then
		private.subject = autoSubject
		if Send.frame and Send.frame.subjectBox then
			Send.frame.subjectBox:SetText(autoSubject)
		end
	end
end

function private:SendMail(frame)
	if private.target == "" then
		TSMAPI:Print(L["Please enter a recipient name."])
		return
	end

	local totalItems = 0
	for _, itemData in pairs(private.items) do
		if itemData then
			totalItems = totalItems + 1
		end
	end

	if totalItems == 0 and private.money == 0 then
		TSMAPI:Print(L["Please add items or gold to send."])
		return
	end

	if totalItems <= private.maxItemSlots then
		private:SendSingleMail()
	else
		private:SendMultipleMails()
	end
end

function private:SendSingleMail()
	local itemsToSend = {}
	for _, itemData in pairs(private.items) do
		if itemData then
			local itemString = TSMAPI:GetItemString(itemData.link)
			itemsToSend[itemString] = itemData.quantity
		end
	end

	local codAmount = nil
	if private.moneyMode == "cod" and private.money > 0 then
		codAmount = private.money
	end

	TSM.AutoMail:SendItems(itemsToSend, private.target, function()
		private:OnMailSent()
	end, codAmount, private.subject, private.body)

	if private.moneyMode == "send" and private.money > 0 then
		SendMail(private.target, private.subject, private.body)
	end

	TSMAPI:Print(format(L["Sending mail to %s..."], private.target))
end

function private:SendMultipleMails()
	local sortedItems = {}
	for _, itemData in pairs(private.items) do
		if itemData then
			table.insert(sortedItems, itemData)
		end
	end

	local mailCount = math.ceil(#sortedItems / private.maxItemSlots)

	for mailNum = 1, mailCount do
		local startIdx = (mailNum - 1) * private.maxItemSlots + 1
		local endIdx = math.min(mailNum * private.maxItemSlots, #sortedItems)

		local itemsToSend = {}
		for i = startIdx, endIdx do
			local itemString = TSMAPI:GetItemString(sortedItems[i].link)
			itemsToSend[itemString] = sortedItems[i].quantity
		end

		local codAmount = nil
		if private.moneyMode == "cod" and private.money > 0 and mailNum == 1 then
			codAmount = private.money
		end

		local sendMoney = (private.moneyMode == "send" and private.money > 0 and mailNum == 1)

		TSM.AutoMail:SendItems(itemsToSend, private.target, function()
			private:OnMailSent()
		end, codAmount, private.subject, private.body)

		if sendMoney then
			SendMail(private.target, private.subject, private.body)
		end
	end

	TSMAPI:Print(format(L["Sending %d mails to %s..."], mailCount, private.target))
end

function private:OnMailSent()
	TSMAPI:Print(L["Mail sent successfully!"])
end

function private:ToggleContactsMenu(button, parentFrame)
	if private.contactsMenuOpen then
		private:CloseContactsMenu()
		return
	end

	local menu = CreateFrame("Frame", nil, button)
	menu:SetPoint("TOPLEFT", button, "BOTTOMLEFT", 0, -2)
	menu:SetWidth(150)
	menu:SetHeight(20 * #CONTACT_MENU_OPTIONS)
	menu:SetFrameStrata("DIALOG")
	TSMAPI.Design:SetFrameBackdropColor(menu)

	for i, option in ipairs(CONTACT_MENU_OPTIONS) do
		local btn = TSMAPI.GUI:CreateButton(menu, 15)
		btn:SetPoint("TOPLEFT", 5, -5 - ((i - 1) * 20))
		btn:SetPoint("TOPRIGHT", -5, -5 - ((i - 1) * 20))
		btn:SetHeight(18)
		btn:SetText(option)
		btn:SetScript("OnClick", function()
			private:OnContactMenuClick(option, parentFrame)
		end)
	end

	private.contactsMenu = menu
	private.contactsMenuOpen = true
end

function private:CloseContactsMenu()
	if private.contactsMenu then
		private.contactsMenu:Hide()
		private.contactsMenu = nil
	end
	private.contactsMenuOpen = false
end

function private:OnContactMenuClick(option, parentFrame)
	private:CloseContactsMenu()

	if option == "Close" then
		return
	elseif option == "Add Contact" then
		TSMAPI:Print("Add Contact - Not yet implemented")
	elseif option == "Remove Contact" then
		TSMAPI:Print("Remove Contact - Not yet implemented")
	elseif option == "Recently Mailed" then
		TSMAPI:Print("Recently Mailed - Not yet implemented")
	elseif option == "Alts" then
		TSMAPI:Print("Alts - Not yet implemented")
	elseif option == "Friends" then
		private:ShowFriendsList(parentFrame)
	elseif option == "Guild" then
		private:ShowGuildList(parentFrame)
	end
end

function private:ShowFriendsList(parentFrame)
	local numFriends = GetNumFriends()
	if numFriends == 0 then
		TSMAPI:Print(L["You have no friends online."])
		return
	end

	TSMAPI:Print("Friends list - Feature in development")
end

function private:ShowGuildList(parentFrame)
	if not IsInGuild() then
		TSMAPI:Print(L["You are not in a guild."])
		return
	end

	TSMAPI:Print("Guild list - Feature in development")
end

Send.frame = nil
