local _, core = ...;

core.ScrollBarEnabled = true;

local GetConfig = core.GetConfig;
local chatFrames = setmetatable({}, { __mode = "k" });

local function GetMaxScroll(chatFrame)
	return math.max(chatFrame:GetNumMessages() - chatFrame:GetNumVisibleLines() + 1, 0);
end;

local function GetScrollBarTrackPixels(bar)
	local thumb = bar:GetThumbTexture();
	local thumbHeight = thumb and thumb:GetHeight() or 24;
	if thumbHeight <= 0 then
		thumbHeight = 24;
	end;
	return math.max(math.floor((bar:GetHeight() or 0) - thumbHeight + 0.5), 1);
end;

local function CreateScrollBar(chatFrame)
	local bar = CreateFrame("Slider", nil, chatFrame);
	bar:SetOrientation("VERTICAL");
	bar:SetWidth(core.SCROLLBAR_WIDTH);
	bar:SetFrameLevel(chatFrame:GetFrameLevel() + 10);
	bar:SetMinMaxValues(0, 0);
	bar:SetValueStep(1);
	bar:SetObeyStepOnDrag(false);
	bar:EnableMouse(true);
	bar:SetMouseMotionEnabled(true);
	bar:SetMouseClickEnabled(false);
	bar:EnableMouseWheel(true);
	bar:SetAlpha(0);
	core.WatchChatHover(bar);
	core.StyleScrollBar(bar);
	bar:HookScript("OnMouseDown", function(self, button)
		if button == "LeftButton" then
			self.ChitChatDragging = true;
			core.QueueChatHoverRefresh();
		end;
	end);
	bar:HookScript("OnMouseUp", function(self, button)
		if button == "LeftButton" then
			self.ChitChatDragging = nil;
			core.QueueChatHoverRefresh();
		end;
	end);
	bar:HookScript("OnHide", function(self)
		self.ChitChatDragging = nil;
	end);
	bar:SetScript("OnMouseWheel", function(_, delta)
		if delta > 0 then
			chatFrame:ScrollUp();
		else
			chatFrame:ScrollDown();
		end;
	end);
	bar:SetScript("OnValueChanged", function(self, value)
		if not self.ChitChatUpdating then
			local maxScroll = GetMaxScroll(chatFrame);
			local trackPixels = GetScrollBarTrackPixels(self);
			local ratio = trackPixels > 0 and (value / trackPixels) or 0;
			local targetOffset = math.max(0, math.min(maxScroll, math.floor((1 - ratio) * maxScroll + 0.5)));
			if targetOffset ~= chatFrame:GetScrollOffset() then
				chatFrame:SetScrollOffset(targetOffset);
			end;
		end;
	end);
	chatFrame.ChitChatScrollBar = bar;
	local entry = { frame = bar, alpha = 0 };
	local state = chatFrames[chatFrame] or {};
	state.bar = bar;
	state.entry = entry;
	state.fade = core.CreateAlphaFader({ entry });
	chatFrames[chatFrame] = state;
	return bar;
end;

local function IsChatFrameHovered(chatFrame, bar)
	if not chatFrame:IsShown() then
		return false;
	end;
	if bar and bar.ChitChatDragging then
		return true;
	end;
	if bar and bar:IsShown() and bar:IsMouseOver() then
		return true;
	end;
	if chatFrame.IsMouseOver and chatFrame:IsMouseOver() then
		return true;
	end;
	local inner = chatFrame.ChitChatInner;
	if inner and inner.IsMouseOver and inner:IsMouseOver() then
		return true;
	end;
	local container = chatFrame.FontStringContainer;
	if container and container.IsMouseOver and container:IsMouseOver() then
		return true;
	end;
	return false;
end;

local function UpdateScrollBarAlpha(chatFrame, state)
	state = state or chatFrames[chatFrame];
	local bar = state and state.bar or chatFrame.ChitChatScrollBar;
	if not bar then
		return;
	end;
	local maxScroll = GetMaxScroll(chatFrame);
	if not GetConfig(chatFrame, "showScrollbar") or not chatFrame:IsVisible() or maxScroll <= 0 then
		bar:Hide();
		if state and state.entry then
			state.entry.alpha = 0;
			bar:SetAlpha(0);
		end;
		bar:SetMouseClickEnabled(false);
		return;
	end;

	bar:Show();
	local hovered = IsChatFrameHovered(chatFrame, bar);
	local targetAlpha = hovered and 1 or 0;
	local fadeDuration = GetConfig(chatFrame, "fadeDuration") or 0.15;
	bar:SetMouseClickEnabled(hovered);
	if state and state.fade then
		state.fade(targetAlpha, fadeDuration);
	else
		bar:SetAlpha(targetAlpha);
	end;
end;

local function UpdateScrollBar(chatFrame)
	local state = chatFrames[chatFrame];
	local bar = state and state.bar or chatFrame.ChitChatScrollBar;
	if not GetConfig(chatFrame, "showScrollbar") then
		if bar then
			bar:Hide();
		end;
		return;
	end;
	bar = bar or CreateScrollBar(chatFrame);
	local anchor = core.GetLayoutAnchor(chatFrame);
	local side = GetConfig(chatFrame, "scrollbarSideStringifiedValue") == "LEFT" and "LEFT" or "RIGHT";
	if bar.ChitChatAnchor ~= anchor or bar.ChitChatSide ~= side then
		bar.ChitChatAnchor, bar.ChitChatSide = anchor, side;
		bar:ClearAllPoints();
		bar:SetPoint("TOP" .. side, anchor, "TOP" .. side, 0, 0);
		bar:SetPoint("BOTTOM" .. side, anchor, "BOTTOM" .. side, 0, 0);
	end;
	local maxScroll = GetMaxScroll(chatFrame);
	local trackPixels = GetScrollBarTrackPixels(bar);
	bar.ChitChatUpdating = true;
	bar:SetMinMaxValues(0, trackPixels);
	local isDragging = bar.ChitChatDragging and (not IsMouseButtonDown or IsMouseButtonDown("LeftButton"));
	if not isDragging then
		bar.ChitChatDragging = nil;
		local currentOffset = math.min(math.max(chatFrame:GetScrollOffset() or 0, 0), maxScroll);
		local ratio = maxScroll > 0 and (1 - currentOffset / maxScroll) or 1;
		bar:SetValue(ratio * trackPixels);
	end;
	bar.ChitChatUpdating = nil;
	UpdateScrollBarAlpha(chatFrame, state);
end;

local function HideDefaultScrollBar(chatFrame)
	local scrollBar = chatFrame.ScrollBar;
	if scrollBar then
		scrollBar:SetAlpha(0);
		scrollBar:Hide();
		if not scrollBar.ChitChatHidden then
			scrollBar:HookScript("OnShow", function(shownScrollBar)
				shownScrollBar:Hide();
			end);
			scrollBar.ChitChatHidden = true;
		end;
	end;
end;

function core.GetScrollBarInsets(frame)
	if not core.ScrollBarEnabled or not chatFrames[frame] or not GetConfig(frame, "showScrollbar") then
		return 0, 0;
	end;
	if GetConfig(frame, "scrollbarSideStringifiedValue") == "LEFT" then
		return core.SCROLLBAR_WIDTH + 2, 0;
	end;
	return 0, core.SCROLLBAR_WIDTH + 2;
end;

function core:InitializeScrollBar(chatFrame)
	if not core.ScrollBarEnabled or not chatFrame or chatFrames[chatFrame] then
		return;
	end;

	HideDefaultScrollBar(chatFrame);
	local state = {};
	chatFrames[chatFrame] = state;

	if chatFrame.AddOnDisplayRefreshedCallback then
		chatFrame:AddOnDisplayRefreshedCallback(function(refreshedFrame)
			UpdateScrollBar(refreshedFrame);
		end);
	end;

	UpdateScrollBar(chatFrame);
end;

function core:RefreshScrollBar()
	if not core.ScrollBarEnabled then
		return;
	end;
	for chatFrame in pairs(chatFrames) do
		UpdateScrollBar(chatFrame);
	end;
end;

function core:RefreshScrollBarAlpha()
	if not core.ScrollBarEnabled then
		return;
	end;
	for chatFrame, state in pairs(chatFrames) do
		UpdateScrollBarAlpha(chatFrame, state);
	end;
end;

core.RegisterLayoutRefresh(core.RefreshScrollBar);
core.RegisterHoverRefresh(core.RefreshScrollBarAlpha);
