--errors arent real errors so disable them
---@diagnostic disable

local _, core = ...;

local config = core.config;

local ClampChatFrameToScreen = core.ClampChatFrameToScreen;

local function HookChatFrameCornerPosition(chatFrame)
	if not chatFrame.OnDragStart or not chatFrame.OnSystemPositionChange
		or chatFrame.ChitChatCornerPositionHooked then
		return;
	end;

	hooksecurefunc(chatFrame, "OnDragStart", function()
		chatFrame.ChitChatEditModeDragging = true;
	end);
	-- Post-hook instead of replacing the method, so Blizzard's edit mode code stays untainted.
	hooksecurefunc(chatFrame, "OnSystemPositionChange", function(frame)
		local normalizeCorner = frame.ChitChatEditModeDragging;
		frame.ChitChatEditModeDragging = nil;

		local left = frame:GetLeft();
		local bottom = frame:GetBottom();
		local parentLeft = UIParent:GetLeft();
		local parentBottom = UIParent:GetBottom();
		if normalizeCorner and left and bottom and parentLeft and parentBottom
			and math.abs(left - parentLeft) <= 1
			and math.abs(bottom - parentBottom) <= 1 then
			frame:ClearAllPoints();
			frame:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 0, 0);
		end;
	end);
	chatFrame.ChitChatCornerPositionHooked = true;
end;

local function RestoreSavedBottomLeftAnchor(chatFrame)
	local anchorInfo = chatFrame.systemInfo and chatFrame.systemInfo.anchorInfo;
	if not anchorInfo or anchorInfo.point ~= "BOTTOMLEFT"
		or anchorInfo.relativeTo ~= "UIParent"
		or anchorInfo.relativePoint ~= "BOTTOMLEFT"
		or math.abs(anchorInfo.offsetX or math.huge) > 0.1
		or math.abs(anchorInfo.offsetY or math.huge) > 0.1 then
		return;
	end;

	chatFrame:ClearAllPoints();
	chatFrame:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 0, 0);
end;

local function GetTabMetrics(chatFrame, tab)
	if chatFrame.ChitChatTabMetrics then
		return chatFrame.ChitChatTabMetrics;
	end;
	local tabTop, tabBottom = tab and tab:GetTop(), tab and tab:GetBottom();
	local chatTop, chatBottom = chatFrame:GetTop(), chatFrame:GetBottom();
	if tab and (not tabTop or not tabBottom or not chatTop or not chatBottom) then
		return nil;
	end;

	local heightDelta = tab and (tab:GetHeight() - config.tabHeight) or 0;
	local metrics = {
		above = tab and tabTop - chatTop - heightDelta or 0,
		below = tab and chatBottom - tabBottom or 0,
	};
	chatFrame.ChitChatTabMetrics = metrics;
	return metrics;
end;

local function GetOuterElementInsets(chatFrame, tab, metrics)
	local left, right, top, bottom = 0, 0, 0, 0;

	if tab then
		if config.chatTabsAtBottom then
			bottom = math.max(bottom, metrics.below);
		elseif not config.chatBoxTop then
			top = math.max(top, metrics.above);
		end;
	end;

	if not config.chatBoxTop then
		local editBox = chatFrame.editBox;
		local editBoxHeight = editBox and math.max(editBox:GetHeight(), config.controlSize) or 0;
		bottom = math.max(bottom, editBoxHeight + 2);
	end;

	if config.controlsOutside then
		local position = core.GetControlPosition();
		local size = config.controlSize + 2;
		if config.controlsVertical then
			if position.right then
				right = math.max(right, size);
			else
				left = math.max(left, size);
			end;
		elseif position.bottom then
			bottom = math.max(bottom, size);
		else
			top = math.max(top, size + (tab and not config.chatTabsAtBottom and math.max(0, metrics.above) or 0));
		end;
	end;

	return left, right, top, bottom;
end;

function core.GetLayoutAnchor(chatFrame)
	local main = _G["ChatFrame1"];
	if main and main.ChitChatInner and (chatFrame == main or chatFrame.isDocked) then
		return main.ChitChatInner;
	end;
	return chatFrame;
end;

function core.GetMessageInsets(chatFrame)
	local main = _G["ChatFrame1"];
	local insets = main and (chatFrame == main or chatFrame.isDocked) and main.ChitChatSelectionInsets;
	if insets then
		return insets[1], insets[2], insets[3], insets[4];
	end;
	return 0, 0, 0, 0;
end;

local function ClipMessagesToInner(main)
	for index = 1, NUM_CHAT_WINDOWS do
		local frame = _G["ChatFrame" .. index];
		local container = frame and frame.FontStringContainer;
		if container and (frame == main or frame.isDocked) then
			container:ClearAllPoints();
			container:SetAllPoints(main.ChitChatInner);
			container:SetClipsChildren(true);
		end;
	end;
end;

local function WaitForTabGeometry(chatFrame, tab)
	if chatFrame.ChitChatWaitingForGeometry then
		return;
	end;
	chatFrame.ChitChatWaitingForGeometry = true;

	local function OnSizeChanged()
		if not chatFrame.ChitChatWaitingForGeometry or not GetTabMetrics(chatFrame, tab) then
			return;
		end;
		chatFrame.ChitChatWaitingForGeometry = nil;
		core.PositionChatFrameForPadding(chatFrame);
	end;
	chatFrame:HookScript("OnSizeChanged", OnSizeChanged);
	if tab then
		tab:HookScript("OnSizeChanged", OnSizeChanged);
	end;
end;

function core.PositionChatFrameForPadding(chatFrame)
	ClampChatFrameToScreen(chatFrame);
	HookChatFrameCornerPosition(chatFrame);
	RestoreSavedBottomLeftAnchor(chatFrame);
	local tab = _G["ChatFrame1Tab"];
	local metrics = GetTabMetrics(chatFrame, tab);
	if not metrics then
		-- tab geometry isn't resolved yet, continue as soon as either frame gets sized
		WaitForTabGeometry(chatFrame, tab);
		return;
	end;
	local paddingLeft, paddingRight, paddingTop, paddingBottom = config.paddingLeft,
		config.paddingRight, config.paddingTop, config.paddingBottom;
	local insetLeft, insetRight, insetTop, insetBottom = GetOuterElementInsets(chatFrame, tab, metrics);
	paddingLeft = paddingLeft + insetLeft;
	paddingRight = paddingRight + insetRight;
	paddingTop = paddingTop + insetTop;
	paddingBottom = paddingBottom + insetBottom;
	if config.chatBoxTop then
		local editBox = chatFrame.editBox;
		local editBoxHeight = editBox and math.max(editBox:GetHeight(), config.controlSize) or 0;
		local tabOffset = tab and not config.chatTabsAtBottom and config.chatBoxAboveTabs and metrics.above or 0;
		paddingTop = paddingTop + editBoxHeight + 2 + tabOffset;
	end;
	chatFrame.ChitChatSelectionInsets = { paddingLeft, paddingRight, paddingTop, paddingBottom };

	local inner = chatFrame.ChitChatInner;
	if not inner then
		inner = CreateFrame("Frame", nil, chatFrame);
		chatFrame.ChitChatInner = inner;
	end;
	inner:ClearAllPoints();
	inner:SetPoint("TOPLEFT", chatFrame, "TOPLEFT", paddingLeft, -paddingTop);
	inner:SetPoint("BOTTOMRIGHT", chatFrame, "BOTTOMRIGHT", -paddingRight, paddingBottom);
	ClipMessagesToInner(chatFrame);
	core.controlsDirty = true;
	if chatFrame.MarkLayoutDirty then
		chatFrame:MarkLayoutDirty();
	end;
	core.EnforceTabAnchor(chatFrame);
end;

-- we want the tabs to be inside the edit mode area for clarity, but blizz doesnt naturally do that so force it
function core.EnforceTabAnchor(chatFrame)
	local inner = chatFrame.ChitChatInner;
	local container = chatFrame.FontStringContainer;
	if inner and container then
		local _, relativeTo = container:GetPoint(1);
		if container:GetNumPoints() ~= 2 or relativeTo ~= inner then
			container:ClearAllPoints();
			container:SetAllPoints(inner);
		end;
		container:SetClipsChildren(true);
	end;
	local tab = _G["ChatFrame1Tab"];
	local metrics = chatFrame.ChitChatTabMetrics;
	if not tab or not inner or not metrics then
		return;
	end;
	local atBottom = config.chatTabsAtBottom;
	local point = atBottom and "BOTTOMLEFT" or "TOPLEFT";
	local offset = atBottom and -metrics.below or metrics.above;
	local currentPoint, relativeTo, relativePoint, x, y = tab:GetPoint(1);
	if tab:GetNumPoints() == 1 and currentPoint == point and relativeTo == inner
		and relativePoint == point and x == 0 and y == offset then
		return;
	end;
	tab:ClearAllPoints();
	tab:SetPoint(point, inner, point, 0, offset);
end;

local function ReapplyPaddingAfterEditMode()
	local chatFrame = _G["ChatFrame1"];
	if not chatFrame or not chatFrame.ChitChatSelectionInsets then
		return;
	end;

	core.PositionChatFrameForPadding(chatFrame);
end;

local editModeClampLoader = CreateFrame("Frame");
editModeClampLoader:RegisterEvent("ADDON_LOADED");
editModeClampLoader:SetScript("OnEvent", function(_, _, addonName)
	if addonName == "Blizzard_EditMode" then
		local chatFrame = _G["ChatFrame1"];
		ClampChatFrameToScreen(chatFrame);
		HookChatFrameCornerPosition(chatFrame);
		if EditModeManagerFrame and EditModeManagerFrame.ExitEditMode then
			hooksecurefunc(EditModeManagerFrame, "ExitEditMode", ReapplyPaddingAfterEditMode);
		end;
		editModeClampLoader:UnregisterEvent("ADDON_LOADED");
	end;
end);
