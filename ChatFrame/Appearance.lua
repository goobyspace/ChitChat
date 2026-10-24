local _, core = ...;

local GetConfig = core.GetConfig;

local chatFrames = {};
local activeSlides = {};
local slideDriver = CreateFrame("Frame", "ChitChatMessageSlideDriver");
local UpdateSlides;

local function IsSecret(value)
	return issecretvalue and issecretvalue(value);
end;

local function GetMessageTimestamp(line)
	local info = line.messageInfo;
	if not info then
		return nil;
	end;

	local timestamp = info.timestamp;
	if IsSecret(timestamp) or type(timestamp) ~= "number" then
		return nil;
	end;

	return timestamp;
end;

local function GetMessagePadding(chatFrame)
	local horizontalPadding = GetConfig(chatFrame, "messagePaddingHorizontal");
	local verticalPadding = GetConfig(chatFrame, "messagePaddingVertical");
	if type(horizontalPadding) ~= "number" or horizontalPadding < 0
		or type(verticalPadding) ~= "number" or verticalPadding < 0 then
		error("ChitChat: message padding values must be non-negative numbers.");
	end;
	return horizontalPadding, verticalPadding;
end;

local function GetMessageMargins(chatFrame)
	local horizontalMargin = GetConfig(chatFrame, "messageMarginsHorizontal");
	local verticalMargin = GetConfig(chatFrame, "messageMarginsVertical");
	if type(horizontalMargin) ~= "number" or horizontalMargin < 0
		or type(verticalMargin) ~= "number" or verticalMargin < 0 then
		error("ChitChat: message margin values must be non-negative numbers.");
	end;
	return horizontalMargin, verticalMargin;
end;

local chatFrameTextureNames = {
	"Background",
	"TopLeftTexture",
	"BottomLeftTexture",
	"TopRightTexture",
	"BottomRightTexture",
	"LeftTexture",
	"RightTexture",
	"BottomTexture",
	"TopTexture",
};

local function HideChatFrameTextures(chatFrame)
	local frameName = chatFrame:GetName();
	for _, textureName in ipairs(chatFrameTextureNames) do
		local texture = _G[frameName .. textureName];
		if texture then
			texture:Hide();
			if not texture.ChitChatHidden then
				hooksecurefunc(texture, "Show", function()
					texture:Hide();
				end);
				hooksecurefunc(texture, "SetShown", function(_, shown)
					if shown then
						texture:Hide();
					end;
				end);
				texture.ChitChatHidden = true;
			end;
		end;
	end;
end;

local function SetLineVerticalOffset(line, points, offset)
	line:ClearAllPoints();
	for _, point in ipairs(points) do
		line:SetPoint(
			point.point,
			point.relativeTo,
			point.relativePoint,
			point.x,
			point.y + offset
		);
	end;
end;

-- lines can't be read back while their text is secret (dungeon combat), so the points are rebuilt from blizzards layout instead :D
local function ApplyMessageLinePadding(chatFrame, line, lineIndex, horizontalInset, verticalPadding, verticalGap)
	local frameWidth = chatFrame:GetWidth();
	if not frameWidth then
		error("ChitChat: Unable to determine the chat frame width for message padding.");
	end;
	local outerLeft, outerRight, _, outerBottom = core.GetMessageInsets(chatFrame);
	local textWidth = frameWidth - horizontalInset * 2 - outerLeft - outerRight;
	if textWidth <= 0 then
		error("ChitChat: Unable to apply message padding and margins to the chat frame.");
	end;

	local atTop = chatFrame:GetInsertMode() == SCROLLING_MESSAGE_FRAME_INSERT_MODE_TOP;
	local spacing = chatFrame:GetSpacing() or 0;
	local paddedPoint;
	if lineIndex == 1 then
		paddedPoint = {
			point = atTop and "TOPLEFT" or "BOTTOMLEFT",
			relativeTo = chatFrame,
			relativePoint = atTop and "TOPLEFT" or "BOTTOMLEFT",
			x = horizontalInset + outerLeft,
			y = atTop and 0 or verticalPadding + outerBottom,
		};
	else
		paddedPoint = {
			point = atTop and "TOPLEFT" or "BOTTOMLEFT",
			relativeTo = chatFrame.visibleLines[lineIndex - 1],
			relativePoint = atTop and "BOTTOMLEFT" or "TOPLEFT",
			x = 0,
			y = atTop and -(spacing + verticalGap) or spacing + verticalGap,
		};
	end;

	line:SetWidth(textWidth);
	SetLineVerticalOffset(line, { paddedPoint }, 0);
	line.ChitChatPaddedPoints = { paddedPoint };
end;

local function RestoreLinePoints(line, background)
	if background.slidePoints then
		if line.ChitChatPaddedPoints == background.slidePoints then
			SetLineVerticalOffset(line, background.slidePoints, 0);
		end;
		background.slidePoints = nil;
	end;
end;

local function ClearSlideState(background)
	background.slidePoints = nil;
	background.slideElapsed = nil;
	background.slideMessageInfo = nil;
	background.slideDirection = nil;
	background.slideOffset = nil;
end;

local function CreateLineBackground(chatFrame, line)
	local horizontalPadding, verticalPadding = GetMessagePadding(chatFrame);

	local lineAlphaSlide = line:CreateAnimationGroup();
	local alpha = lineAlphaSlide:CreateAnimation("Alpha");
	alpha:SetFromAlpha(0);
	alpha:SetToAlpha(1);
	alpha:SetDuration(GetConfig(chatFrame, "slideDuration"));
	alpha:SetSmoothing("OUT");
	-- the container clips to the chat area, so backgrounds parented to it can't spill over the tabs or outside the window
	local backgroundParent = chatFrame.FontStringContainer or line:GetParent() or chatFrame;
	local surface = core.CreateGradientBackground(
		backgroundParent,
		line,
		core.GetGradientSettings(chatFrame, "messageBackground"),
		0,
		"BACKGROUND",
		-7,
		{
			left = horizontalPadding,
			right = horizontalPadding,
			top = verticalPadding,
			bottom = verticalPadding,
		}
	);

	return {
		surface = surface,
		alpha = 0,
		lineAlphaSlide = lineAlphaSlide,
	};
end;

local function SetBackgroundShown(background, shown)
	for texture in pairs(background.surface.regions) do
		texture:SetShown(shown);
	end;
end;

local function SetBackgroundOpacity(background, opacity)
	background.surface:SetOpacity(opacity);
	background.alpha = opacity;
	if not IsSecret(opacity) then
		SetBackgroundShown(background, opacity > 0);
	end;
end;

local function GetEntranceDistance(chatFrame)
	return GetConfig(chatFrame, "slideDistance") + (GetConfig(chatFrame, "paddingBottom") or 0);
end;

local function PlayEntrance(chatFrame, line, background)
	RestoreLinePoints(line, background);
	background.slidePoints = line.ChitChatPaddedPoints;
	background.slideDirection = -1;
	background.slideOffset = background.slideDirection * GetEntranceDistance(chatFrame);
	SetLineVerticalOffset(line, background.slidePoints, background.slideOffset);
	background.slideElapsed = 0;
	background.slideMessageInfo = line.messageInfo;
	activeSlides[line] = { chatFrame = chatFrame, background = background };
	slideDriver:SetScript("OnUpdate", UpdateSlides);

	background.lineAlphaSlide:Stop();
	background.lineAlphaSlide:Play();
end;

local function RefreshChatFrame(chatFrame, state)
	local visibleLines = chatFrame.visibleLines;
	if not visibleLines then
		return;
	end;

	for line, entry in pairs(activeSlides) do
		if entry.chatFrame == chatFrame then
			RestoreLinePoints(line, entry.background);
			ClearSlideState(entry.background);
			activeSlides[line] = nil;
		end;
	end;
	if not next(activeSlides) then
		slideDriver:SetScript("OnUpdate", nil);
	end;

	local activeLines = {};
	local newestRecentLine;
	local newestRecentTimestamp;
	local pendingTime = state.pendingMessageTime;
	if pendingTime and GetTime() - pendingTime > GetConfig(chatFrame, "recentMessageWindow") then
		state.pendingMessageTime = nil;
		pendingTime = nil;
	end;

	local horizontalPadding, verticalPadding = GetMessagePadding(chatFrame);
	local horizontalMargin, verticalMargin = GetMessageMargins(chatFrame);
	local horizontalInset = horizontalPadding + horizontalMargin;

	local verticalGap = 2 * (verticalPadding + verticalMargin);
	for lineIndex, line in ipairs(visibleLines) do
		local info = line.messageInfo;
		if info then
			ApplyMessageLinePadding(
				chatFrame,
				line,
				lineIndex,
				horizontalInset,
				verticalPadding,
				verticalGap
			);
			activeLines[line] = true;
			local background = line.ChitChatBackground;
			if not background then
				background = CreateLineBackground(chatFrame, line);
				line.ChitChatBackground = background;
				state.backgrounds[line] = background;
				-- blizz already drives line fading so follow its alpha writes instead of polling
				hooksecurefunc(line, "SetAlpha", function(_, opacity)
					SetBackgroundOpacity(background, line.messageInfo and opacity or 0);
				end);
			end;

			SetBackgroundShown(background, true);
			SetBackgroundOpacity(background, line:GetAlpha());

			local timestamp = pendingTime and GetMessageTimestamp(line);
			if timestamp and timestamp >= pendingTime - GetConfig(chatFrame, "recentMessageWindow")
				and timestamp <= pendingTime + 0.1
				and (not newestRecentTimestamp or timestamp > newestRecentTimestamp) then
				newestRecentLine = line;
				newestRecentTimestamp = timestamp;
			end;
		end;
	end;

	for line, background in pairs(state.backgrounds) do
		if not activeLines[line] then
			SetBackgroundShown(background, false);
		end;
	end;

	if newestRecentLine then
		local background = newestRecentLine.ChitChatBackground;
		if newestRecentLine == visibleLines[1] and chatFrame:GetScrollOffset() == 0 then
			PlayEntrance(chatFrame, newestRecentLine, background);
		end;
		state.pendingMessageTime = nil;
	end;
end;

UpdateSlides = function(_, elapsed)
	for line, entry in pairs(activeSlides) do
		local chatFrame, background = entry.chatFrame, entry.background;
		if not chatFrame:IsShown() or line ~= chatFrame.visibleLines[1]
			or not line.messageInfo or line.messageInfo ~= background.slideMessageInfo
			or chatFrame:GetScrollOffset() ~= 0 then
			RestoreLinePoints(line, background);
			ClearSlideState(background);
			activeSlides[line] = nil;
		else
			local slideDuration = GetConfig(chatFrame, "slideDuration");
			background.slideElapsed = math.min(background.slideElapsed + elapsed, slideDuration);
			local remaining = 1 - background.slideElapsed / slideDuration;
			background.slideOffset = background.slideDirection * GetEntranceDistance(chatFrame) * remaining * remaining;
			SetLineVerticalOffset(line, background.slidePoints, background.slideOffset);
			if background.slideElapsed >= slideDuration then
				RestoreLinePoints(line, background);
				ClearSlideState(background);
				activeSlides[line] = nil;
			end;
		end;
	end;
	if not next(activeSlides) then
		slideDriver:SetScript("OnUpdate", nil);
	end;
end;

local function SyncBackgroundArea(chatFrame)
	local area = chatFrame.ChitChatBackgroundArea;
	if not area then
		return;
	end;
	local anchor = chatFrame.ChitChatBackgroundAnchor or core.GetLayoutAnchor(chatFrame);
	local _, relativeTo = area:GetPoint(1);
	if area:GetNumPoints() ~= 2 or relativeTo ~= anchor then
		area:ClearAllPoints();
		area:SetPoint("TOPLEFT", anchor, "TOPLEFT", 0, 0);
		area:SetPoint("BOTTOMRIGHT", anchor, "BOTTOMRIGHT", 0, 0);
	end;
end;

-- window is only set for chat boxes that live inside another addons window (see Widgets/)
-- those windows own the chat background, fading and entrance, so only the message backgrounds are ours there
local function AttachToChatFrame(chatFrame, window)
	if not chatFrame or chatFrames[chatFrame] or not chatFrame.AddOnDisplayRefreshedCallback then
		return chatFrames[chatFrame] ~= nil;
	end;

	if not window then
		HideChatFrameTextures(chatFrame);
	end;

	local backgroundArea = CreateFrame("Frame", nil, window or chatFrame);
	chatFrame.ChitChatBackgroundArea = backgroundArea;
	chatFrame.ChitChatBackgroundAnchor = window;
	SyncBackgroundArea(chatFrame);
	local chatBackground = core.CreateGradientBackground(
		window or chatFrame,
		backgroundArea,
		core.GetGradientSettings(chatFrame, "chatBackground"),
		1,
		"BACKGROUND",
		-8
	);
	backgroundArea:SetScript("OnSizeChanged", function()
		chatBackground:SetOpacity(1);
	end);
	core.RegisterSizeChanged(chatFrame, function()
		SyncBackgroundArea(chatFrame);
		chatBackground:SetOpacity(1);
	end);

	if not window then
		chatFrame:SetClipsChildren(true);
		chatFrame:SetTimeVisible(GetConfig(chatFrame, "messageTimeVisible"));
		chatFrame:SetFadeDuration(GetConfig(chatFrame, "messageFadeDuration"));
	end;

	local state = {
		backgrounds = setmetatable({}, { __mode = "k" }),
		widget = window ~= nil,
	};
	chatFrames[chatFrame] = state;

	chatFrame:AddOnDisplayRefreshedCallback(function(refreshedFrame)
		RefreshChatFrame(refreshedFrame, state);
		SyncBackgroundArea(refreshedFrame);
	end);

	-- no pending message means no entrance, windows rebuild their whole history on refresh so it would replay constantly
	if not window then
		hooksecurefunc(chatFrame, "AddMessage", function()
			state.pendingMessageTime = GetTime();
		end);
	end;

	RefreshChatFrame(chatFrame, state);
	return true;
end;

function core:RefreshChatFrameTimings()
	for chatFrame, state in pairs(chatFrames) do
		if not state.widget then
			chatFrame:SetTimeVisible(GetConfig(chatFrame, "messageTimeVisible"));
			chatFrame:SetFadeDuration(GetConfig(chatFrame, "messageFadeDuration"));
		end;
	end;
end;

function core:InitializeChatFrameAppearance(chatFrame)
	return AttachToChatFrame(chatFrame);
end;

function core:InitializeWidgetChatFrame(chatFrame, window)
	return AttachToChatFrame(chatFrame, window);
end;

function core:RefreshChatFrameAppearance()
	for chatFrame in pairs(chatFrames) do
		SyncBackgroundArea(chatFrame);
	end;
end;

core.RegisterLayoutRefresh(core.RefreshChatFrameAppearance);
