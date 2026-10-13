--errors arent real errors so disable them
---@diagnostic disable

local _, core = ...;

local GetConfig = core.GetConfig;
local controlIconPath = "Interface\\AddOns\\ChitChat\\Assets\\";

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

-- replaces blizz's dock overflow button with a control-styled one placed after the rightmost tab.
-- the original stays shown (invisible, no mouse) so the dock scroll frame keeps reserving room for it.
local function CreateOverflowControl(row, chatFrame)
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
	core.WatchChatHover(button);
	button:SetSize(GetConfig(chatFrame, "controlSize"), GetConfig(chatFrame, "controlSize"));
	button.ChitChatBackground = core.ApplyControlButtonIcon(
		button,
		button.ChitChatIcon,
		core.GetGradientSettings(chatFrame, "controlBackground")
	);
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
	local controlPosition = core.GetControlPosition(chatFrame);

	HideControlRowDecorations(row);
	local mainTab = _G["ChatFrame1Tab"];
	core.PositionControlRow(
		row,
		chatFrame,
		#buttons,
		controlPosition,
		mainTab,
		core.IsCombatLogFrame(chatFrame)
	);
	core.SetControlLayering(row, chatFrame, chatFrame.editBox);

	local PositionForSelectedChatFrame =
		core.CreateSelectedChatFramePositioner(row, chatFrame, buttons, mainTab);

	PositionForSelectedChatFrame();

	for index, button in ipairs(buttons) do
		core.PositionControlButton(button, row, index, controlPosition, chatFrame);
		button:Show();
	end;

	local state = {
		controlFrames = {},
		overflowFrames = {},
	};
	for _, button in ipairs(buttons) do
		AddTrackedFrame(state.controlFrames, button, button.ChitChatBackground);
	end;
	local overflowButton, UpdateOverflow = CreateOverflowControl(row, chatFrame);
	if overflowButton then
		AddTrackedFrame(state.overflowFrames, overflowButton, overflowButton.ChitChatBackground);
	end;
	row:SetAlpha(1);

	local FadeControls = core.CreateAlphaFader(state.controlFrames);
	local FadeOverflow = core.CreateAlphaFader(state.overflowFrames);
	local selectedChatFrame = SELECTED_CHAT_FRAME or chatFrame;

	function core:RefreshControls()
		core.controlsDirty = true;
		selectedChatFrame = PositionForSelectedChatFrame();
		core.EnforceTabAnchor(chatFrame);
		for index, button in ipairs(buttons) do
			core.PositionControlButton(button, row, index, core.GetControlPosition(selectedChatFrame), selectedChatFrame);
		end;
		if UpdateOverflow then
			UpdateOverflow();
			overflowButton.ChitChatBackground:SetShown(overflowButton:IsShown());
		end;
		for index = 1, core.GetChatWindowCount() do
			local frame = _G["ChatFrame" .. index];
			local editBox = frame and frame.editBox;
			if editBox and editBox.ChitChatRefreshInput then
				editBox.ChitChatRefreshInput();
			end;
		end;
	end;

	function core:RefreshControlAlpha()
		local controlsHovered = AreControlButtonsHovered(row, buttons);
		local alwaysShowControls = GetConfig(selectedChatFrame, "alwaysShowControls");
		local controlTargetAlpha = (alwaysShowControls or controlsHovered) and 1
			or (GetConfig(selectedChatFrame, "controlsIdleAlpha") or 0);
		local fadeDuration = GetConfig(selectedChatFrame, "fadeDuration");
		FadeControls(controlTargetAlpha, alwaysShowControls and 0 or fadeDuration);

		local alwaysShowChatTabs = GetConfig(selectedChatFrame, "alwaysShowChatTabs");
		local tabsHovered = core:AreChatTabsHovered() or IsAnyTrackedFrameHovered(state.overflowFrames)
			or (selectedChatFrame.IsMouseOver and selectedChatFrame:IsMouseOver());
		local tabTargetAlpha = (alwaysShowChatTabs or tabsHovered or core.IsCombatLogFrame(selectedChatFrame))
			and 1 or (GetConfig(selectedChatFrame, "chatTabsIdleAlpha") or 0);
		FadeOverflow(tabTargetAlpha, alwaysShowChatTabs and 0 or fadeDuration);
	end;

	core.WatchChatLayout(row);
	for _, button in ipairs(buttons) do
		core.WatchChatHover(button);
	end;
	core.RegisterLayoutRefresh(core.RefreshControls);
	core.RegisterHoverRefresh(core.RefreshControlAlpha);
	core:RefreshControls();
	core:RefreshControlAlpha();
end;

function core:InitializeControls(chatFrame)
	chatFrame = chatFrame or _G["ChatFrame1"];
	if not chatFrame or chatFrame.ChitChatControlsInitialized then
		return;
	end;
	core:InitializeChatFrameLayout(chatFrame, true);
	CreateControls(chatFrame);
	chatFrame.ChitChatControlsInitialized = true;
end;
