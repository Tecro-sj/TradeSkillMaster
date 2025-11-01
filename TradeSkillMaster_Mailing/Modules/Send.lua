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
	contactsMenuOpen = false,
	frame = nil,
	isTabActive = false
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

	private.frame = frame

	frame:SetScript("OnShow", function()
		private.isTabActive = true
	end)

	frame:SetScript("OnHide", function()
		private.isTabActive = false
	end)

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
	frame.sendMoneyBtn = sendMoneyBtn

	local codBtn = TSMAPI.GUI:CreateButton(frame, 15)
	codBtn:SetPoint("TOPLEFT", sendMoneyBtn, "TOPRIGHT", 5, 0)
	codBtn:SetWidth(100)
	codBtn:SetHeight(20)
	codBtn:SetText(L["C.O.D."])
	frame.codBtn = codBtn

	sendMoneyBtn:SetScript("OnClick", function(self)
		private.moneyMode = "send"
		sendMoneyBtn:LockHighlight()
		frame.codBtn:UnlockHighlight()
		private:UpdateAutoSubject()
	end)
	sendMoneyBtn.tooltip = L["Send money directly to the recipient."]
	sendMoneyBtn:LockHighlight()

	codBtn:SetScript("OnClick", function(self)
		private.moneyMode = "cod"
		codBtn:LockHighlight()
		frame.sendMoneyBtn:UnlockHighlight()
		private:UpdateAutoSubject()
	end)
	codBtn.tooltip = L["Send items with Cash on Delivery - recipient pays on receiving."]

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
	local cType, itemID, link = GetCursorInfo()
	if cType == "item" then
		local _, stackCount = GetCursorInfo()
		local quantity = 1

		if type(stackCount) == "number" then
			quantity = stackCount
		else
			local _, _, _, _, _, _, _, maxStack = GetItemInfo(link)
			if maxStack and maxStack > 1 then
				for bag = 0, NUM_BAG_SLOTS do
					for bagSlot = 1, GetContainerNumSlots(bag) do
						local itemLink = GetContainerItemLink(bag, bagSlot)
						if itemLink == link then
							local _, count = GetContainerItemInfo(bag, bagSlot)
							if count then
								quantity = count
								break
							end
						end
					end
					if quantity > 1 then break end
				end
			end
		end

		slot.itemLink = link
		slot.quantity = quantity

		local _, _, _, _, _, _, _, _, _, texture = GetItemInfo(link)
		slot.icon:SetTexture(texture)

		if quantity > 1 then
			slot.count:SetText(quantity)
		else
			slot.count:SetText("")
		end

		private.items[slot.index] = {link = link, quantity = quantity}

		ClearCursor()
		private:UpdateAutoSubject()
	end
end

function private:AddItemFromBag(bag, slot)
	if not private.isTabActive or not private.frame then
		return
	end

	local link = GetContainerItemLink(bag, slot)
	if not link then return end

	local _, count = GetContainerItemInfo(bag, slot)
	if not count then count = 1 end

	local emptySlot = nil
	for i = 1, private.maxItemSlots do
		if not private.items[i] then
			emptySlot = i
			break
		end
	end

	if not emptySlot then
		TSM:Print(L["No empty item slots available."])
		return
	end

	local itemSlot = private.frame.itemSlots[emptySlot]
	if itemSlot then
		itemSlot.itemLink = link
		itemSlot.quantity = count

		local _, _, _, _, _, _, _, _, _, texture = GetItemInfo(link)
		itemSlot.icon:SetTexture(texture)

		if count > 1 then
			itemSlot.count:SetText(count)
		else
			itemSlot.count:SetText("")
		end

		private.items[emptySlot] = {link = link, quantity = count}
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
		TSM:Print(L["Please enter a recipient name."])
		return
	end

	local totalItems = 0
	for _, itemData in pairs(private.items) do
		if itemData then
			totalItems = totalItems + 1
		end
	end

	if totalItems == 0 and private.money == 0 then
		TSM:Print(L["Please add items or gold to send."])
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

	private:AddToRecentlyMailed(private.target)
	TSM:Printf(L["Sending mail to %s..."], private.target)
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

	private:AddToRecentlyMailed(private.target)
	TSM:Printf(L["Sending %d mails to %s..."], mailCount, private.target)
end

function private:OnMailSent()
	TSM:Print(L["Mail sent successfully!"])
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
		private:ShowAddContactDialog(parentFrame)
	elseif option == "Remove Contact" then
		private:ShowRemoveContactDialog(parentFrame)
	elseif option == "Recently Mailed" then
		private:ShowRecentlyMailedList(parentFrame)
	elseif option == "Alts" then
		private:ShowAltsList(parentFrame)
	elseif option == "Friends" then
		private:ShowFriendsList(parentFrame)
	elseif option == "Guild" then
		private:ShowGuildList(parentFrame)
	end
end

function private:ShowFriendsList(parentFrame)
	ShowFriends()
	local numFriends = GetNumFriends()
	if numFriends == 0 then
		TSM:Print(L["You have no friends online."])
		return
	end

	local friendsList = {}
	for i = 1, numFriends do
		local name, level, class, zone, connected = GetFriendInfo(i)
		if connected and name then
			table.insert(friendsList, name)
		end
	end

	if #friendsList == 0 then
		TSM:Print(L["You have no friends online."])
		return
	end

	local menu = CreateFrame("Frame", nil, UIParent)
	menu:SetPoint("CENTER")
	menu:SetWidth(250)
	menu:SetHeight(math.min(300, 40 + (#friendsList * 22)))
	menu:SetFrameStrata("DIALOG")
	TSMAPI.Design:SetFrameBackdropColor(menu)

	local titleLabel = TSMAPI.GUI:CreateLabel(menu, "normal")
	titleLabel:SetPoint("TOP", 0, -10)
	titleLabel:SetText("Friends")

	local scrollFrame = CreateFrame("ScrollFrame", nil, menu)
	scrollFrame:SetPoint("TOPLEFT", 10, -35)
	scrollFrame:SetPoint("BOTTOMRIGHT", -10, 35)

	local content = CreateFrame("Frame", nil, scrollFrame)
	content:SetWidth(230)
	content:SetHeight(#friendsList * 22)
	scrollFrame:SetScrollChild(content)

	for i, name in ipairs(friendsList) do
		local btn = TSMAPI.GUI:CreateButton(content, 15)
		btn:SetPoint("TOPLEFT", 0, -((i - 1) * 22))
		btn:SetPoint("TOPRIGHT", 0, -((i - 1) * 22))
		btn:SetHeight(20)
		btn:SetText(name)
		btn:SetScript("OnClick", function()
			private.target = name
			if parentFrame.targetBox then
				parentFrame.targetBox:SetText(name)
			end
			private:UpdateAutoSubject()
			menu:Hide()
		end)
	end

	local closeBtn = TSMAPI.GUI:CreateButton(menu, 15)
	closeBtn:SetPoint("BOTTOM", 0, 10)
	closeBtn:SetWidth(100)
	closeBtn:SetHeight(20)
	closeBtn:SetText("Close")
	closeBtn:SetScript("OnClick", function()
		menu:Hide()
	end)

	menu:Show()
end

function private:ShowGuildList(parentFrame)
	if not IsInGuild() then
		TSM:Print(L["You are not in a guild."])
		return
	end

	GuildRoster()
	local numMembers = GetNumGuildMembers()
	if numMembers == 0 then
		TSM:Print(L["No guild members found."])
		return
	end

	local guildList = {}
	local playerName = UnitName("player")
	for i = 1, numMembers do
		local name, rank, rankIndex, level, class, zone, note, officernote, online = GetGuildRosterInfo(i)
		if online and name and name ~= playerName then
			table.insert(guildList, name)
		end
	end

	if #guildList == 0 then
		TSM:Print(L["No guild members online."])
		return
	end

	table.sort(guildList)

	local menu = CreateFrame("Frame", nil, UIParent)
	menu:SetPoint("CENTER")
	menu:SetWidth(250)
	menu:SetHeight(math.min(300, 40 + (#guildList * 22)))
	menu:SetFrameStrata("DIALOG")
	TSMAPI.Design:SetFrameBackdropColor(menu)

	local titleLabel = TSMAPI.GUI:CreateLabel(menu, "normal")
	titleLabel:SetPoint("TOP", 0, -10)
	titleLabel:SetText("Guild Members")

	local scrollFrame = CreateFrame("ScrollFrame", nil, menu)
	scrollFrame:SetPoint("TOPLEFT", 10, -35)
	scrollFrame:SetPoint("BOTTOMRIGHT", -10, 35)

	local content = CreateFrame("Frame", nil, scrollFrame)
	content:SetWidth(230)
	content:SetHeight(#guildList * 22)
	scrollFrame:SetScrollChild(content)

	for i, name in ipairs(guildList) do
		local btn = TSMAPI.GUI:CreateButton(content, 15)
		btn:SetPoint("TOPLEFT", 0, -((i - 1) * 22))
		btn:SetPoint("TOPRIGHT", 0, -((i - 1) * 22))
		btn:SetHeight(20)
		btn:SetText(name)
		btn:SetScript("OnClick", function()
			private.target = name
			if parentFrame.targetBox then
				parentFrame.targetBox:SetText(name)
			end
			private:UpdateAutoSubject()
			menu:Hide()
		end)
	end

	local closeBtn = TSMAPI.GUI:CreateButton(menu, 15)
	closeBtn:SetPoint("BOTTOM", 0, 10)
	closeBtn:SetWidth(100)
	closeBtn:SetHeight(20)
	closeBtn:SetText("Close")
	closeBtn:SetScript("OnClick", function()
		menu:Hide()
	end)

	menu:Show()
end

function private:AddToRecentlyMailed(targetName)
	if not TSM.db.global.recentlyMailed then
		TSM.db.global.recentlyMailed = {}
	end

	for i, name in ipairs(TSM.db.global.recentlyMailed) do
		if name == targetName then
			table.remove(TSM.db.global.recentlyMailed, i)
			break
		end
	end

	table.insert(TSM.db.global.recentlyMailed, 1, targetName)

	if #TSM.db.global.recentlyMailed > 20 then
		table.remove(TSM.db.global.recentlyMailed)
	end
end

function private:ShowAddContactDialog(parentFrame)
	StaticPopupDialogs["TSM_MAILING_ADD_CONTACT"] = {
		text = "Enter contact name:",
		button1 = "Add",
		button2 = "Cancel",
		hasEditBox = true,
		OnAccept = function(self)
			local name = self.editBox:GetText():trim()
			if name ~= "" then
				private:AddContact(name)
				TSM:Printf(L["Added %s to contacts."], name)
			end
		end,
		timeout = 0,
		whileDead = true,
		hideOnEscape = true,
		preferredIndex = 3,
	}
	StaticPopup_Show("TSM_MAILING_ADD_CONTACT")
end

function private:AddContact(name)
	if not TSM.db.global.contacts then
		TSM.db.global.contacts = {}
	end

	for _, contact in ipairs(TSM.db.global.contacts) do
		if contact == name then
			return
		end
	end

	table.insert(TSM.db.global.contacts, name)
	table.sort(TSM.db.global.contacts)
end

function private:ShowRemoveContactDialog(parentFrame)
	if not TSM.db.global.contacts or #TSM.db.global.contacts == 0 then
		TSM:Print(L["No contacts to remove."])
		return
	end

	private:ShowContactSelectionList(parentFrame, "Remove Contact", function(name)
		private:RemoveContact(name)
		TSM:Printf(L["Removed %s from contacts."], name)
	end)
end

function private:RemoveContact(name)
	if not TSM.db.global.contacts then return end

	for i, contact in ipairs(TSM.db.global.contacts) do
		if contact == name then
			table.remove(TSM.db.global.contacts, i)
			break
		end
	end
end

function private:ShowRecentlyMailedList(parentFrame)
	if not TSM.db.global.recentlyMailed or #TSM.db.global.recentlyMailed == 0 then
		TSM:Print(L["No recently mailed contacts."])
		return
	end

	private:ShowContactSelectionList(parentFrame, "Recently Mailed", function(name)
		private.target = name
		if parentFrame.targetBox then
			parentFrame.targetBox:SetText(name)
		end
		private:UpdateAutoSubject()
	end)
end

function private:ShowAltsList(parentFrame)
	local realm = GetRealmName()
	if not TSM.db.realm.alts then
		TSM.db.realm.alts = {}
	end

	if #TSM.db.realm.alts == 0 then
		TSM:Print(L["No alts configured. Add your alt names to the list."])
		private:ShowAddAltDialog(parentFrame)
		return
	end

	private:ShowContactSelectionList(parentFrame, "Alts", function(name)
		private.target = name
		if parentFrame.targetBox then
			parentFrame.targetBox:SetText(name)
		end
		private:UpdateAutoSubject()
	end, true)
end

function private:ShowAddAltDialog(parentFrame)
	StaticPopupDialogs["TSM_MAILING_ADD_ALT"] = {
		text = "Enter alt character name:",
		button1 = "Add",
		button2 = "Cancel",
		hasEditBox = true,
		OnAccept = function(self)
			local name = self.editBox:GetText():trim()
			if name ~= "" then
				private:AddAlt(name)
				TSM:Printf(L["Added %s to alts list."], name)
			end
		end,
		timeout = 0,
		whileDead = true,
		hideOnEscape = true,
		preferredIndex = 3,
	}
	StaticPopup_Show("TSM_MAILING_ADD_ALT")
end

function private:AddAlt(name)
	if not TSM.db.realm.alts then
		TSM.db.realm.alts = {}
	end

	for _, alt in ipairs(TSM.db.realm.alts) do
		if alt == name then
			return
		end
	end

	table.insert(TSM.db.realm.alts, name)
	table.sort(TSM.db.realm.alts)
end

function private:ShowContactSelectionList(parentFrame, title, onSelect, isAlts)
	local listData = {}

	if title == "Remove Contact" then
		listData = TSM.db.global.contacts or {}
	elseif title == "Recently Mailed" then
		listData = TSM.db.global.recentlyMailed or {}
	elseif title == "Alts" then
		listData = TSM.db.realm.alts or {}
	end

	if #listData == 0 then
		return
	end

	local menu = CreateFrame("Frame", nil, UIParent)
	menu:SetPoint("CENTER")
	menu:SetWidth(250)
	menu:SetHeight(math.min(300, 40 + (#listData * 22)))
	menu:SetFrameStrata("DIALOG")
	TSMAPI.Design:SetFrameBackdropColor(menu)

	local titleLabel = TSMAPI.GUI:CreateLabel(menu, "normal")
	titleLabel:SetPoint("TOP", 0, -10)
	titleLabel:SetText(title)

	local scrollFrame = CreateFrame("ScrollFrame", nil, menu)
	scrollFrame:SetPoint("TOPLEFT", 10, -35)
	scrollFrame:SetPoint("BOTTOMRIGHT", -10, 35)

	local content = CreateFrame("Frame", nil, scrollFrame)
	content:SetWidth(230)
	content:SetHeight(#listData * 22)
	scrollFrame:SetScrollChild(content)

	for i, name in ipairs(listData) do
		local btn = TSMAPI.GUI:CreateButton(content, 15)
		btn:SetPoint("TOPLEFT", 0, -((i - 1) * 22))
		btn:SetPoint("TOPRIGHT", 0, -((i - 1) * 22))
		btn:SetHeight(20)
		btn:SetText(name)
		btn:SetScript("OnClick", function()
			onSelect(name)
			menu:Hide()
		end)
	end

	local closeBtn = TSMAPI.GUI:CreateButton(menu, 15)
	closeBtn:SetPoint("BOTTOM", 0, 10)
	closeBtn:SetWidth(100)
	closeBtn:SetHeight(20)
	closeBtn:SetText("Close")
	closeBtn:SetScript("OnClick", function()
		menu:Hide()
	end)

	if isAlts then
		local addAltBtn = TSMAPI.GUI:CreateButton(menu, 15)
		addAltBtn:SetPoint("BOTTOMRIGHT", closeBtn, "BOTTOMLEFT", -5, 0)
		addAltBtn:SetWidth(80)
		addAltBtn:SetHeight(20)
		addAltBtn:SetText("Add Alt")
		addAltBtn:SetScript("OnClick", function()
			menu:Hide()
			private:ShowAddAltDialog(parentFrame)
		end)
	end

	menu:Show()
end

function private:SetupBagHooks()
	local oldUseContainerItem = UseContainerItem
	UseContainerItem = function(bag, slot, ...)
		if private.isTabActive and private.frame and IsControlKeyDown() then
			private:AddItemFromBag(bag, slot)
			return
		end
		oldUseContainerItem(bag, slot, ...)
	end
end

function Send:OnEnable()
	private:SetupBagHooks()
end

Send.frame = nil
