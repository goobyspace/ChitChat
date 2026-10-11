local _, core = ...;

local config = core.config;

local chatFrames = {};

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

local function GetMessagePadding()
	local horizontalPadding = config.messagePaddingHorizontal;
	local verticalPadding = config.messagePaddingVertical;
	if type(horizontalPadding) ~= "number" or horizontalPadding < 0
		or type(verticalPadding) ~= "number" or verticalPadding < 0 then
		error("ChitChat: message padding values must be non-negative numbers.");
	end;
	return horizontalPadding, verticalPadding;
end;

local function GetMessageMargins()
	local horizontalMargin = config.messageMarginsHorizontal;
	local verticalMargin = config.messageMarginsVertical;
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
		end;
	end;
end;

local function GetLinePoints(line)
	local points = {};
	for index = 1, line:GetNumPoints() do
		local point, relativeTo, relativePoint, x, y = line:GetPoint(index);
		points[index] = {
			point = point,
			relativeTo = relativeTo,
			relativePoint = relativePoint,
			x = x or 0,
			y = y or 0,
		};
	end;
	return points;
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

local function ApplyMessageLinePadding(chatFrame, line, horizontalInset, verticalPadding, verticalGap)
	local frameWidth = chatFrame:GetWidth();
	if not frameWidth then
		error("ChitChat: Unable to determine the chat frame width for message padding.");
	end;
	local outerLeft, outerRight, _, outerBottom = core.GetMessageInsets(chatFrame);
	local textWidth = frameWidth - horizontalInset * 2 - outerLeft - outerRight;
	if textWidth <= 0 then
		error("ChitChat: Unable to apply message padding and margins to the chat frame.");
	end;

	local currentPoints = GetLinePoints(line);
	local paddingLayout = line.ChitChatPaddingLayout;

	local basePoints = {};
	for index, point in ipairs(currentPoints) do
		local applied = paddingLayout and paddingLayout.appliedByPoint[point.point];
		if applied and applied.relativeTo == point.relativeTo
			and applied.relativePoint == point.relativePoint and math.abs(applied.x - point.x) < 0.01
			and math.abs(applied.y - point.y) < 0.01 then
			basePoints[index] = {
				point = point.point,
				relativeTo = point.relativeTo,
				relativePoint = point.relativePoint,
				x = paddingLayout.baseXByPoint[point.point],
				y = point.y - (paddingLayout.verticalOffsetByPoint[point.point] or 0),
			};
		else
			basePoints[index] = point;
		end;
	end;
	local paddedPoints = {};
	local verticalOffsets = {};
	for index, point in ipairs(basePoints) do
		local horizontalOffset = 0;
		local pointVerticalOffset = 0;
		if point.relativeTo == chatFrame then
			horizontalOffset = point.point:find("RIGHT", 1, true)
				and -(horizontalInset + outerRight) or horizontalInset + outerLeft;
			if point.point:find("BOTTOM", 1, true) then
				pointVerticalOffset = pointVerticalOffset + verticalPadding + outerBottom;
			end;
		elseif point.point:find("TOP", 1, true) then
			pointVerticalOffset = -verticalGap;
		elseif point.point:find("BOTTOM", 1, true) then
			pointVerticalOffset = verticalGap;
		end;
		verticalOffsets[index] = pointVerticalOffset;
		paddedPoints[index] = {
			point = point.point,
			relativeTo = point.relativeTo,
			relativePoint = point.relativePoint,
			x = point.x + horizontalOffset,
			y = point.y + pointVerticalOffset,
		};
	end;

	line:SetWidth(textWidth);
	line:ClearAllPoints();
	for _, point in ipairs(paddedPoints) do
		line:SetPoint(
			point.point,
			point.relativeTo,
			point.relativePoint,
			point.x,
			point.y
		);
	end;
	local layout = { appliedByPoint = {}, baseXByPoint = {}, verticalOffsetByPoint = {} };
	for index, point in ipairs(paddedPoints) do
		layout.appliedByPoint[point.point] = point;
		layout.baseXByPoint[point.point] = basePoints[index].x;
		layout.verticalOffsetByPoint[point.point] = verticalOffsets[index];
	end;
	line.ChitChatPaddingLayout = layout;
end;

local function RestoreLinePoints(line, background)
	if background.slidePoints then
		SetLineVerticalOffset(line, background.slidePoints, 0);
		background.slidePoints = nil;
	end;
end;

local function ClearSlideState(background)
	background.slidePoints = nil;
	background.slideElapsed = nil;
	background.slideMessageInfo = nil;
	background.slideDirection = nil;
end;

local function CreateLineBackground(chatFrame, line)
	local horizontalPadding, verticalPadding = GetMessagePadding();

	local lineAlphaSlide = line:CreateAnimationGroup();
	local alpha = lineAlphaSlide:CreateAnimation("Alpha");
	alpha:SetFromAlpha(0);
	alpha:SetToAlpha(1);
	alpha:SetDuration(config.slideDuration);
	alpha:SetSmoothing("OUT");
	-- the container clips to the chat area, so backgrounds parented to it can't spill over the tabs or outside the window
	local backgroundParent = chatFrame.FontStringContainer or line:GetParent() or chatFrame;
	local surface;
	if horizontalPadding > 0 or verticalPadding > 0 then
		local texture = backgroundParent:CreateTexture(nil, "BACKGROUND", nil, -8);
		texture:SetPoint("TOPLEFT", line, "TOPLEFT", -horizontalPadding, verticalPadding);
		texture:SetPoint("BOTTOMRIGHT", line, "BOTTOMRIGHT", horizontalPadding, -verticalPadding);

		surface = {
			regions = { [texture] = true },
		};
		local lastOpacity;
		function surface:SetOpacity(opacity)
			if lastOpacity == opacity then
				return;
			end;
			lastOpacity = opacity;

			local colour = config.messageBackgroundColour;
			local effectiveAlpha = opacity * (colour.a or 1);
			if config.messageBackgroundUseGradient then
				local edgeAlpha = effectiveAlpha * (config.messageBackgroundGradientEdgeOpacity or 0.5);
				local mainColourRatio = math.max(0, math.min(config.messageBackgroundGradientMainColourRatio or 0, 1));
				local mainColourSide = config.messageBackgroundGradientMainColourSideStringifiedValue == "right"
					and "right" or "left";
				local startAlpha = effectiveAlpha;
				local endAlpha = effectiveAlpha;

				if config.messageBackgroundGradientOneSided and mainColourRatio < 1 then
					if mainColourSide == "right" then
						startAlpha = edgeAlpha;
					else
						endAlpha = edgeAlpha;
					end;
				end;

				texture:SetColorTexture(colour.r, colour.g, colour.b, 1);
				texture:SetGradient(
					"HORIZONTAL",
					CreateColor(colour.r, colour.g, colour.b, startAlpha),
					CreateColor(colour.r, colour.g, colour.b, endAlpha)
				);
			else
				texture:SetColorTexture(colour.r, colour.g, colour.b, effectiveAlpha);
			end;
		end;
	else
		surface = core.CreateGradientBackground(
			backgroundParent,
			line,
			"message",
			0,
			"BACKGROUND",
			-7
		);
	end;

	return {
		surface = surface,
		alpha = 0,
		lineAlphaSlide = lineAlphaSlide,
	};
end;

local function SetBackgroundOpacity(background, opacity)
	background.surface:SetOpacity(opacity);
	background.alpha = opacity;
end;

local function SetBackgroundShown(background, shown)
	for texture in pairs(background.surface.regions) do
		texture:SetShown(shown);
	end;
end;

local function GetEntranceDistance()
	return config.slideDistance + (config.paddingBottom or 0);
end;

local function PlayEntrance(chatFrame, line, background)
	RestoreLinePoints(line, background);
	background.slidePoints = GetLinePoints(line);
	background.slideDirection = -1;
	SetLineVerticalOffset(line, background.slidePoints, background.slideDirection * GetEntranceDistance());
	background.slideElapsed = 0;
	background.slideMessageInfo = line.messageInfo;

	background.lineAlphaSlide:Stop();
	background.lineAlphaSlide:Play();
end;

local function GetLineAlpha(chatFrame, line)
	local timestamp = GetMessageTimestamp(line);
	if not timestamp
		or not chatFrame.CalculateLineAlphaValueFromTimestamp then
		return line:GetAlpha();
	end;

	local overrideTimestamp = chatFrame.overrideFadeTimestamp;
	if not IsSecret(overrideTimestamp) and type(overrideTimestamp) == "number" then
		timestamp = math.max(timestamp, overrideTimestamp);
	end;

	return chatFrame:CalculateLineAlphaValueFromTimestamp(GetTime(), timestamp);
end;

local function RefreshChatFrame(chatFrame, state)
	local visibleLines = chatFrame.visibleLines;
	if not visibleLines then
		return;
	end;

	local activeLines = {};
	local newestRecentLine;
	local newestRecentTimestamp;
	local pendingTime = state.pendingMessageTime;

	local horizontalPadding, verticalPadding = GetMessagePadding();
	local horizontalMargin, verticalMargin = GetMessageMargins();
	local horizontalInset = horizontalPadding + horizontalMargin;

	local verticalGap = 2 * (verticalPadding + verticalMargin);
	for _, line in ipairs(visibleLines) do
		local info = line.messageInfo;
		if info then
			ApplyMessageLinePadding(
				chatFrame,
				line,
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
			end;

			SetBackgroundShown(background, true);

			local timestamp = pendingTime and GetMessageTimestamp(line);
			if timestamp and timestamp >= pendingTime - config.recentMessageWindow
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

local function UpdateBackgroundOpacity(_, elapsed)
	for chatFrame, state in pairs(chatFrames) do
		HideChatFrameTextures(chatFrame);
		for _, line in ipairs(chatFrame.visibleLines or {}) do
			local background = line.ChitChatBackground;
			if background then
				if line.messageInfo then
					SetBackgroundOpacity(background, GetLineAlpha(chatFrame, line));
				else
					SetBackgroundOpacity(background, 0);
				end;

				if background.slideElapsed then
					if line ~= chatFrame.visibleLines[1] then
						RestoreLinePoints(line, background);
						ClearSlideState(background);
					elseif not line.messageInfo
						or line.messageInfo ~= background.slideMessageInfo
						or chatFrame:GetScrollOffset() ~= 0 then
						RestoreLinePoints(line, background);
						ClearSlideState(background);
					else
						background.slideElapsed = math.min(background.slideElapsed + elapsed, config.slideDuration);
						local progress = background.slideElapsed / config.slideDuration;
						local remaining = 1 - progress;
						SetLineVerticalOffset(
							line,
							background.slidePoints,
							background.slideDirection * GetEntranceDistance() * remaining * remaining
						);

						if background.slideElapsed >= config.slideDuration then
							RestoreLinePoints(line, background);
							ClearSlideState(background);
						end;
					end;
				end;
			end;
		end;

		if state.pendingMessageTime and GetTime() - state.pendingMessageTime > config.recentMessageWindow then
			state.pendingMessageTime = nil;
		end;
	end;
end;

local function SyncBackgroundArea(chatFrame)
	local area = chatFrame.ChitChatBackgroundArea;
	if not area then
		return;
	end;
	local anchor = core.GetLayoutAnchor(chatFrame);
	local _, relativeTo = area:GetPoint(1);
	if area:GetNumPoints() ~= 2 or relativeTo ~= anchor then
		area:ClearAllPoints();
		area:SetPoint("TOPLEFT", anchor, "TOPLEFT", 0, 0);
		area:SetPoint("BOTTOMRIGHT", anchor, "BOTTOMRIGHT", 0, 0);
	end;
end;

local function AttachToChatFrame(chatFrame)
	if not chatFrame or chatFrames[chatFrame] or not chatFrame.AddOnDisplayRefreshedCallback then
		return;
	end;

	HideChatFrameTextures(chatFrame);

	local backgroundArea = CreateFrame("Frame", nil, chatFrame);
	chatFrame.ChitChatBackgroundArea = backgroundArea;
	SyncBackgroundArea(chatFrame);
	local chatBackground = core.CreateGradientBackground(chatFrame, backgroundArea, "chat", 1, "BACKGROUND", -8);
	backgroundArea:SetScript("OnSizeChanged", function()
		chatBackground:SetOpacity(1);
	end);
	chatFrame:HookScript("OnSizeChanged", function()
		SyncBackgroundArea(chatFrame);
		chatBackground:SetOpacity(1);
	end);

	local scrollBar = chatFrame.ScrollBar;
	if scrollBar then
		scrollBar:SetAlpha(0);
		scrollBar:Hide();
		scrollBar:HookScript("OnShow", function(shownScrollBar)
			shownScrollBar:Hide();
		end);
	end;

	chatFrame:SetClipsChildren(true);
	chatFrame:SetTimeVisible(config.messageTimeVisible);
	chatFrame:SetFadeDuration(config.messageFadeDuration);

	local state = {
		backgrounds = setmetatable({}, { __mode = "k" }),
	};
	chatFrames[chatFrame] = state;

	chatFrame:AddOnDisplayRefreshedCallback(function(refreshedFrame)
		RefreshChatFrame(refreshedFrame, state);
	end);

	hooksecurefunc(chatFrame, "AddMessage", function()
		state.pendingMessageTime = GetTime();
	end);

	RefreshChatFrame(chatFrame, state);
end;

function core:RefreshChatFrameTimings()
	for chatFrame in pairs(chatFrames) do
		chatFrame:SetTimeVisible(config.messageTimeVisible);
		chatFrame:SetFadeDuration(config.messageFadeDuration);
	end;
end;

function core.GetChatWindowCount()
	return math.max(NUM_CHAT_WINDOWS or 0, CHAT_FRAMES and #CHAT_FRAMES or 0);
end;

-- cant not style newly created frames
function core:AttachNewChatFrames()
	for index = 1, core.GetChatWindowCount() do
		AttachToChatFrame(_G["ChatFrame" .. index]);
	end;
end;

local driver = CreateFrame("Frame", "ChitChatMessageFadeDriver");
driver:SetScript("OnUpdate", function(frame, elapsed)
	core:AttachNewChatFrames();
	core.SyncMessageContainers();
	for chatFrame in pairs(chatFrames) do
		SyncBackgroundArea(chatFrame);
	end;
	UpdateBackgroundOpacity(frame, elapsed);
end);

function core:InitializeChitChat()
	core:AttachNewChatFrames();
end;
