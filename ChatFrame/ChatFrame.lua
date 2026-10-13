local _, core = ...;

local function InitializeChatFrame(chatFrame)
	if not chatFrame or chatFrame.ChitChatInitialized then
		return;
	end;

	if not core:InitializeChatFrameAppearance(chatFrame) then
		return;
	end;

	core:InitializeChatFrameLayout(chatFrame);
	core:InitializeScrollBar(chatFrame);
	core:InitializeTimestamps(chatFrame);
	core:InitializeChatFrameTab(chatFrame);
	if chatFrame.editBox then
		core:InitializeChatInput(chatFrame.editBox);
	end;
	chatFrame.ChitChatInitialized = true;
	core.WatchChatLayout(chatFrame);
	core.WatchChatLayout(chatFrame.ChitChatInner);
	core.WatchChatLayout(chatFrame.FontStringContainer);
	core.WatchChatHover(chatFrame.ScrollBar);
	core.WatchChatHover(chatFrame.ScrollToBottomButton);
	core.WatchChatHover(chatFrame.ResizeButton);
end;

function core:AttachNewChatFrames()
	for index = 1, self.GetChatWindowCount() do
		InitializeChatFrame(_G["ChatFrame" .. index]);
	end;
end;

local editModeHooked;

local function HookEditMode()
	if editModeHooked then
		return;
	end;
	local chatFrame = _G["ChatFrame1"];
	core.ClampChatFrameToScreen(chatFrame);
	core.HookChatFrameCornerPosition(chatFrame);
	if EditModeManagerFrame and EditModeManagerFrame.ExitEditMode then
		editModeHooked = true;
		hooksecurefunc(EditModeManagerFrame, "ExitEditMode", function()
			if chatFrame.ChitChatSelectionInsets then
				core.PositionChatFrameForPadding(chatFrame);
			end;
			core.QueueChatRefresh();
		end);
	end;
end;

core.ClampChatFrameToScreen(_G["ChatFrame1"]);

local events = CreateFrame("Frame", "ChitChatChatFrameEvents");
events:RegisterEvent("ADDON_LOADED");
events:RegisterEvent("PLAYER_ENTERING_WORLD");
events:SetScript("OnEvent", function(_, event, addonName)
	if event == "PLAYER_ENTERING_WORLD" then
		core.ClampChatFrameToScreen(_G["ChatFrame1"]);
		core.QueueChatRefresh();
	elseif addonName == "Blizzard_EditMode" then
		HookEditMode();
	elseif addonName == "Blizzard_CombatLog" then
		core.QueueChatRefresh();
	end;
end);

local refreshQueued, hoverQueued, refreshing;

function core.QueueChatHoverRefresh()
	if hoverQueued then
		return;
	end;
	hoverQueued = true;
	C_Timer.After(0, function()
		hoverQueued = nil;
		for _, refresh in ipairs(core.hoverRefreshes) do
			refresh(core);
		end;
	end);
end;

function core.QueueChatRefresh()
	-- our own layout writes trigger these hooks too
	if refreshQueued or refreshing then
		return;
	end;
	refreshQueued = true;
	C_Timer.After(0, function()
		refreshQueued = nil;
		refreshing = true;
		core.WatchChatLayout(_G["CombatLogQuickButtonFrame_Custom"]);
		core:AttachNewChatFrames();
		for _, refresh in ipairs(core.layoutRefreshes) do
			refresh(core);
		end;
		refreshing = nil;
		core.QueueChatHoverRefresh();
	end);
end;

local reactiveChatInitialized;

function core:InitializeReactiveChat()
	if reactiveChatInitialized then
		return;
	end;
	reactiveChatInitialized = true;
	HookEditMode();
	for _, name in ipairs({
		"FCF_OpenNewWindow", "FCF_OpenTemporaryWindow", "FCF_Close",
		"FCF_SelectDockFrame", "FCF_Tab_OnClick", "FCF_DockFrame", "FCF_UnDockFrame",
		"FCF_DockUpdate", "FCFDock_UpdateTabs", "FCF_SetTabPosition",
		"FCF_SetChatWindowFontSize", "FCFTab_UpdateColors", "FCF_SetButtonSide",
		"FCF_StopDragging", "FCFTab_OnDragStop",
	}) do
		core.HookGlobal(name, core.QueueChatRefresh);
	end;
	for _, name in ipairs({ "FCF_FadeInChatFrame", "FCF_FadeOutChatFrame", "FCFTab_UpdateAlpha" }) do
		core.HookGlobal(name, function()
			core:RefreshChatTabAlpha();
			core.QueueChatHoverRefresh();
		end);
	end;
	local dock = _G["GENERAL_CHAT_DOCK"];
	core.WatchChatLayout(dock);
	if dock then
		core.WatchChatLayout(dock.scrollFrame);
		core.WatchChatLayout(dock.overflowButton);
		if dock.scrollFrame then
			dock.scrollFrame:HookScript("OnHorizontalScroll", core.QueueChatRefresh);
		end;
	end;
	core.WatchChatLayout(_G["CombatLogQuickButtonFrame_Custom"]);
	core.QueueChatRefresh();
end;
