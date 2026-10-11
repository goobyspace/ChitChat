--errors arent real errors so disable them
---@diagnostic disable

local _, core = ...;

local config = core.config;
local controlIconPath = "Interface\\AddOns\\ChitChat\\Assets\\";

local function IsCombatLogFrame(chatFrame)
	if not chatFrame then
		return false;
	end;
	if type(IsCombatLog) == "function" then
		return IsCombatLog(chatFrame);
	end;
	return chatFrame == _G["ChatFrame2"];
end;

local function AddTrackedFrame(trackedFrames, frame, background)
	if frame then
		frame:SetAlpha(1);
		trackedFrames[#trackedFrames + 1] = {
			frame = frame,
			background = background,
			alpha = 1,
		};
	end;
end;

local function HideOriginalControl(button)
	if not button then
		return nil;
	end;
	if not button.ChitChatHidden then
		button:Hide();
		button:SetAlpha(0);
		button:HookScript("OnShow", function(hiddenButton)
			hiddenButton:Hide();
		end);
		button.ChitChatHidden = true;
	end;
	return button;
end;

local function CreateControlButton(row, name, icon, tooltip, clickHandler)
	local button = CreateFrame("Button", name, row);
	button.ChitChatIcon = icon;
	button:SetScript("OnClick", clickHandler);
	button:SetScript("OnEnter", function(hoveredButton)
		GameTooltip:SetOwner(hoveredButton, "ANCHOR_RIGHT");
		GameTooltip:SetText(tooltip, 1, 1, 1);
		GameTooltip:Show();
	end);
	button:SetScript("OnLeave", function()
		GameTooltip:Hide();
	end);
	return button;
end;

local function ForwardOriginalClick(button)
	if not button then
		return nil;
	end;
	local onClick = button:GetScript("OnClick");
	if not onClick then
		error("ChitChat: A Blizzard chat control is missing its OnClick handler.");
	end;
	return function(_, ...)
		onClick(button, ...);
	end;
end;

local function GetControlButtons(row)
	local buttons = {};
	local socialButton = HideOriginalControl(_G["QuickJoinToastButton"]);
	if socialButton then
		buttons[#buttons + 1] = CreateControlButton(
			row,
			"ChitChatQuickJoinButton",
			controlIconPath .. "socialicon.png",
			QUICK_JOIN or "Quick Join",
			ForwardOriginalClick(socialButton)
		);
	end;
	local channelButton = HideOriginalControl(_G["ChatFrameChannelButton"]);
	if channelButton then
		buttons[#buttons + 1] = CreateControlButton(
			row,
			"ChitChatChannelButton",
			controlIconPath .. "chatchannels.png",
			CHAT_CHANNELS or "Channels",
			ForwardOriginalClick(channelButton)
		);
	end;
	local menuButton = HideOriginalControl(_G["ChatFrameMenuButton"]);
	if menuButton then
		buttons[#buttons + 1] = CreateControlButton(
			row,
			"ChitChatChatTypeButton",
			controlIconPath .. "chattype.png",
			CHAT_MENU or "Chat Type",
			ForwardOriginalClick(menuButton)
		);
	end;
	buttons[#buttons + 1] = core.CreateHistoryControlButton(row);
	local settingsButton = CreateControlButton(
		row,
		"ChitChatSettingsButton",
		controlIconPath .. "cogicon.png",
		"ChitChat Settings",
		function()
			local category = core.Settings.category;
			Settings.OpenToCategory(type(category) == "table" and category:GetID() or category);
		end
	);
	buttons[#buttons + 1] = settingsButton;
	return buttons;
end;

local function HideControlRowDecorations(row)
	local minimizeButton = row.minimizeButton;
	if minimizeButton then
		minimizeButton:Hide();
		minimizeButton:SetAlpha(0);
		minimizeButton:HookScript("OnShow", function(button)
			button:Hide();
		end);
	end;
	for _, region in ipairs({ row:GetRegions() }) do
		if region:GetObjectType() == "Texture" then
			region:Hide();
		end;
	end;
	row:SetAlpha(1);
	row:SetClipsChildren(false);
end;

local function IsAnyTrackedFrameHovered(trackedFrames)
	for _, entry in ipairs(trackedFrames) do
		if entry.frame:IsShown() and entry.frame:IsMouseOver() then
			return true;
		end;
	end;
	return false;
end;

local function AreControlButtonsHovered(row, buttons)
	if row:IsMouseOver() then
		return true;
	end;
	for _, button in ipairs(buttons) do
		if button:IsShown() and button:IsMouseOver() then
			return true;
		end;
	end;
	return false;
end;

local function UpdateTrackedFrameAlpha(trackedFrames, targetAlpha, step, updateChatTab)
	for _, entry in ipairs(trackedFrames) do
		if updateChatTab then
			core:UpdateChatTab(entry);
		end;
		entry.alpha = entry.alpha + (targetAlpha - entry.alpha) * step;
		entry.frame:SetAlpha(entry.alpha);
		if entry.background then
			entry.background:SetAlpha(entry.alpha);
		end;
		if not updateChatTab then
			for _, texture in ipairs(entry.frame.ChitChatIconTextures or {}) do
				texture:SetAlpha(entry.alpha);
			end;
		end;
	end;
end;

local function CreateSelectedChatFramePositioner(row, chatFrame, buttons, controlPosition, mainTab)
	local activeChatFrame;
	local activeEditBox;
	local activeEditBoxTabOffset;

	return function()
		local selectedChatFrame = SELECTED_CHAT_FRAME or chatFrame;
		local selectedEditBox = selectedChatFrame.editBox;
		core:InitializeChatInput(selectedEditBox);
		local selectedTab;
		local selectedFrameIndex = selectedChatFrame:GetID();
		if selectedFrameIndex then
			selectedTab = _G["ChatFrame" .. selectedFrameIndex .. "Tab"];
		end;
		selectedTab = selectedTab or mainTab;

		local editBoxTabOffset;
		if config.chatBoxTop and selectedTab and not config.chatTabsAtBottom then
			local chatTop = core.GetLayoutAnchor(selectedChatFrame):GetTop();
			local tabEdge = config.chatBoxAboveTabs and selectedTab:GetTop() or selectedTab:GetBottom();
			-- bounds are unavailable while frames are mid-drag/undock
			if not chatTop or not tabEdge then
				return activeChatFrame or selectedChatFrame;
			end;
			editBoxTabOffset = tabEdge - chatTop;
		end;

		if selectedChatFrame == activeChatFrame and selectedEditBox == activeEditBox and not core.controlsDirty then
			if IsCombatLogFrame(selectedChatFrame) and selectedEditBox and not selectedEditBox:IsShown() then
				selectedEditBox:Show();
			end;
			local editBoxTabOffsetChanged = editBoxTabOffset ~= activeEditBoxTabOffset;
			if editBoxTabOffset and activeEditBoxTabOffset then
				editBoxTabOffsetChanged = math.abs(editBoxTabOffset - activeEditBoxTabOffset) > 0.01;
			end;
			if editBoxTabOffsetChanged then
				core:PositionChatInput(selectedEditBox, selectedChatFrame, selectedTab);
				activeEditBoxTabOffset = editBoxTabOffset;
			end;
			return selectedChatFrame;
		end;

		core:PositionChatInput(selectedEditBox, selectedChatFrame, selectedTab);
		core.controlsDirty = nil;
		activeEditBoxTabOffset = editBoxTabOffset;
		core.PositionControlRow(
			row,
			selectedChatFrame,
			#buttons,
			controlPosition,
			selectedTab,
			IsCombatLogFrame(selectedChatFrame)
		);
		core.SetControlLayering(row, selectedChatFrame, selectedEditBox);

		if IsCombatLogFrame(selectedChatFrame) and selectedEditBox then
			selectedEditBox:Show();
		end;
		activeChatFrame = selectedChatFrame;
		activeEditBox = selectedEditBox;
		return selectedChatFrame;
	end;
end;

-- replaces blizz's dock overflow button with a control-styled one placed after the rightmost tab.
-- the original stays shown (invisible, no mouse) so the dock scroll frame keeps reserving room for it.
local function CreateOverflowControl(row)
	local dock = GENERAL_CHAT_DOCK;
	local original = dock and dock.overflowButton;
	local mainTab = _G["ChatFrame1Tab"];
	if not original or not mainTab then
		return nil;
	end;
	local onClick = original:GetScript("OnClick");
	local button = CreateControlButton(
		UIParent,
		"ChitChatOverflowButton",
		controlIconPath .. "arrowdown.png",
		"",
		function(_, ...)
			if onClick then
				onClick(original, ...);
			end;
		end
	);
	button:SetScript("OnEnter", nil);
	button:SetScript("OnLeave", nil);
	button:SetSize(config.controlSize, config.controlSize);
	button.ChitChatBackground = core.ApplyControlButtonIcon(button, button.ChitChatIcon);
	original:EnableMouse(false);
	for _, texture in ipairs({ original:GetRegions() }) do
		texture:SetAlpha(0);
	end;

	local function Update()
		-- the control background extends past the button by the inset, so shrink the button to keep the visible size at tab height
		local height = mainTab:GetHeight() - 2 * core.CONTROL_BACKGROUND_INSET;
		local width = height;
		local reserved = width + 2 * core.CONTROL_BACKGROUND_INSET + 4;
		if original:GetWidth() ~= reserved or original:GetHeight() ~= mainTab:GetHeight() then
			original:SetSize(reserved, mainTab:GetHeight());
		end;
		local list = original.list;
		local _, listRelativeTo = list:GetPoint(1);
		if list:GetNumPoints() ~= 1 or listRelativeTo ~= button then
			list:ClearAllPoints();
			list:SetPoint("TOPLEFT", button, "BOTTOMLEFT", 0, -4);
		end;
		if not original:IsShown() then
			button:Hide();
			return;
		end;

		local frameStrata = row:GetFrameStrata();
		if button:GetFrameStrata() ~= frameStrata then
			button:SetFrameStrata(frameStrata);
		end;
		if button:GetFrameLevel() ~= row:GetFrameLevel() + 1 then
			button:SetFrameLevel(row:GetFrameLevel() + 1);
		end;
		if button:GetWidth() ~= width or button:GetHeight() ~= height then
			button:SetSize(width, height);
		end;

		local mainLeft = mainTab:GetLeft();
		if not mainLeft then
			return;
		end;
		local rightEdge = 0;
		for _, dockedFrame in ipairs(dock.DOCKED_CHAT_FRAMES or {}) do
			local tab = _G[dockedFrame:GetName() .. "Tab"];
			local tabRight = tab and tab:IsShown() and tab:GetRight();
			if tabRight and tabRight > rightEdge then
				rightEdge = tabRight;
			end;
		end;
		local clipRight = dock.scrollFrame and dock.scrollFrame:GetRight();
		if clipRight and rightEdge > clipRight then
			rightEdge = clipRight;
		end;
		local x = rightEdge - mainLeft + core.CONTROL_BACKGROUND_INSET + 2;
		local currentPoint, relativeTo, _, currentX = button:GetPoint(1);
		if button:GetNumPoints() ~= 1 or relativeTo ~= mainTab or not currentX or math.abs(currentX - x) > 0.01 then
			button:ClearAllPoints();
			button:SetPoint("LEFT", mainTab, "LEFT", x, 0);
		end;
		button:Show();
	end;
	Update();
	return button, Update;
end;

local function CreateControls(chatFrame)
	local row = chatFrame.buttonFrame or _G["ChatFrame1ButtonFrame"];
	if not row then
		error("ChitChat: ChatFrame1ButtonFrame is unavailable.");
	end;
	-- the row is a child of ChatFrame1, which gets hidden whenever another docked tab is selected
	row:SetParent(UIParent);

	local buttons = GetControlButtons(row);
	local controlPosition = core.GetControlPosition();

	HideControlRowDecorations(row);
	local mainTab = _G["ChatFrame1Tab"];
	core.PositionControlRow(
		row,
		chatFrame,
		#buttons,
		controlPosition,
		mainTab,
		IsCombatLogFrame(chatFrame)
	);
	core.SetControlLayering(row, chatFrame, chatFrame.editBox);

	local PositionForSelectedChatFrame =
		CreateSelectedChatFramePositioner(row, chatFrame, buttons, controlPosition, mainTab);

	PositionForSelectedChatFrame();

	for index, button in ipairs(buttons) do
		core.PositionControlButton(button, row, index, controlPosition);
		button:Show();
	end;

	local state = {
		trackedFrames = core:InitializeChatTabs(),
		controlFrames = {},
		overflowFrames = {},
	};
	for _, button in ipairs(buttons) do
		AddTrackedFrame(state.controlFrames, button, button.ChitChatBackground);
	end;
	local overflowButton, UpdateOverflow = CreateOverflowControl(row);
	if overflowButton then
		AddTrackedFrame(state.overflowFrames, overflowButton, overflowButton.ChitChatBackground);
	end;
	row:SetAlpha(1);

	local driver = CreateFrame("Frame", "ChitChatControlsFadeDriver");
	driver:SetScript("OnUpdate", function(_, elapsed)
		core:SyncChatTabs(state.trackedFrames);
		local selectedChatFrame = PositionForSelectedChatFrame();
		core.EnforceTabAnchor(chatFrame);
		for index, button in ipairs(buttons) do
			core.PositionControlButton(button, row, index, controlPosition);
		end;
		if UpdateOverflow then
			UpdateOverflow();
			overflowButton.ChitChatBackground:SetShown(overflowButton:IsShown());
		end;
		local hovered = IsAnyTrackedFrameHovered(state.trackedFrames)
			or IsAnyTrackedFrameHovered(state.overflowFrames);
		if selectedChatFrame.IsMouseOver and selectedChatFrame:IsMouseOver() then
			hovered = true;
		end;

		local alwaysShowChatTabs = config.alwaysShowChatTabs;
		local tabTargetAlpha = (alwaysShowChatTabs or hovered or IsCombatLogFrame(selectedChatFrame))
			and 1 or (config.chatTabsIdleAlpha or 0);
		local controlsHovered = AreControlButtonsHovered(row, buttons);
		local alwaysShowControls = config.alwaysShowControls;
		local controlTargetAlpha = (alwaysShowControls or controlsHovered) and 1 or (config.controlsIdleAlpha or 0);
		local tabStep = alwaysShowChatTabs and 1 or math.min(elapsed / config.fadeDuration, 1);
		local controlStep = alwaysShowControls and 1 or math.min(elapsed / config.fadeDuration, 1);
		UpdateTrackedFrameAlpha(state.trackedFrames, tabTargetAlpha, tabStep, true);
		UpdateTrackedFrameAlpha(state.overflowFrames, tabTargetAlpha, tabStep, false);
		UpdateTrackedFrameAlpha(state.controlFrames, controlTargetAlpha, controlStep, false);
	end);
end;

local loader = CreateFrame("Frame", "ChitChatControlsLoader");
loader:RegisterEvent("PLAYER_ENTERING_WORLD");
loader:SetScript("OnEvent", function()
	local chatFrame = _G["ChatFrame1"];
	core.PositionChatFrameForPadding(chatFrame);
	CreateControls(chatFrame);
	loader:UnregisterEvent("PLAYER_ENTERING_WORLD");
end);
