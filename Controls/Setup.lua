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
			if not chatTop or not tabEdge then
				error("ChitChat: Unable to determine selected chat frame tab bounds for chatBoxTop.");
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

local function CreateControls(chatFrame)
	local row = chatFrame.buttonFrame or _G["ChatFrame1ButtonFrame"];
	if not row then
		error("ChitChat: ChatFrame1ButtonFrame is unavailable.");
	end;
	if config.controlsOutside then
		row:SetParent(UIParent);
	end;

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
	};
	for _, button in ipairs(buttons) do
		AddTrackedFrame(state.controlFrames, button, button.ChitChatBackground);
	end;
	row:SetAlpha(1);

	local driver = CreateFrame("Frame", "ChitChatControlsFadeDriver");
	driver:SetScript("OnUpdate", function(_, elapsed)
		local selectedChatFrame = PositionForSelectedChatFrame();
		core.EnforceTabAnchor(chatFrame);
		for index, button in ipairs(buttons) do
			core.PositionControlButton(button, row, index, controlPosition);
		end;
		local hovered = IsAnyTrackedFrameHovered(state.trackedFrames);
		if selectedChatFrame.IsMouseOver and selectedChatFrame:IsMouseOver() then
			hovered = true;
		end;

		local alwaysShowControlsAndTabs = config.alwaysShowControlsAndTabs;
		local tabTargetAlpha = (alwaysShowControlsAndTabs or hovered or IsCombatLogFrame(selectedChatFrame))
			and 1 or config.idleAlpha;
		local controlsHovered = AreControlButtonsHovered(row, buttons);
		local controlTargetAlpha = (alwaysShowControlsAndTabs or controlsHovered) and 1 or config.idleAlpha;
		local step = alwaysShowControlsAndTabs and 1 or math.min(elapsed / config.fadeDuration, 1);
		UpdateTrackedFrameAlpha(state.trackedFrames, tabTargetAlpha, step, true);
		UpdateTrackedFrameAlpha(state.controlFrames, controlTargetAlpha, step, false);
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
