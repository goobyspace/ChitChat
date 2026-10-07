--errors arent real errors so disable them
---@diagnostic disable

local _, core = ...;

local config = core.config;

local function ClampChatFrameToScreen(chatFrame)
	if chatFrame.UpdateClampOffsets and not chatFrame.ChitChatClampHooked then
		hooksecurefunc(chatFrame, "UpdateClampOffsets", function()
			chatFrame:SetClampRectInsets(0, 0, 0, 0);
		end);
		chatFrame.ChitChatClampHooked = true;
	end;
	chatFrame:SetClampRectInsets(0, 0, 0, 0);
	chatFrame:SetClampedToScreen(true);
end;

local function HookChatFrameCornerPosition(chatFrame)
	if not chatFrame.OnDragStart or not chatFrame.OnSystemPositionChange
		or chatFrame.ChitChatCornerPositionHooked then
		return;
	end;

	hooksecurefunc(chatFrame, "OnDragStart", function()
		chatFrame.ChitChatEditModeDragging = true;
	end);
	local onSystemPositionChange = chatFrame.OnSystemPositionChange;
	chatFrame.OnSystemPositionChange = function(frame, ...)
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

		return onSystemPositionChange(frame, ...);
	end;
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

function core.PositionChatFrameForPadding(chatFrame)
	ClampChatFrameToScreen(chatFrame);
	HookChatFrameCornerPosition(chatFrame);
	RestoreSavedBottomLeftAnchor(chatFrame);
	local padding = core.padding;
	local tab = _G["ChatFrame1Tab"];
	local tabTop = tab and tab:GetTop();
	local tabBottom = tab and tab:GetBottom();
	local chatTop = chatFrame:GetTop();
	local chatBottom = chatFrame:GetBottom();
	if tab and (not tabTop or not tabBottom or not chatTop or not chatBottom) then
		error("ChitChat: Unable to determine ChatFrame1 tab bounds for chat frame positioning.");
	end;
	if padding.left == 0 and padding.right == 0 and padding.top == 0 and padding.bottom == 0 then
		if tab then
			tab:ClearAllPoints();
			if config.chatTabsAtBottom then
				tab:SetPoint("BOTTOMLEFT", chatFrame, "BOTTOMLEFT", 0, tabBottom - chatBottom);
			else
				tab:SetPoint("TOPLEFT", chatFrame, "TOPLEFT", 0, tabTop - chatTop);
			end;
		end;
		return;
	end;

	local bottom = chatFrame:GetBottom();
	local width = chatFrame:GetWidth();
	local height = chatFrame:GetHeight();
	local parentBottom = UIParent:GetBottom();
	if not bottom or not width or not height or not parentBottom then
		error("ChitChat: Unable to determine ChatFrame1 bounds for message padding.");
	end;

	local scrollBar = chatFrame.ScrollBar;
	if scrollBar then
		local scrollBarWidth = scrollBar:GetWidth();
		if scrollBarWidth and scrollBarWidth > 0 then
			width = width + scrollBarWidth;
		end;
	end;

	if config.chatBoxTop and not chatTop then
		error("ChitChat: Unable to determine ChatFrame1 bounds for chatBoxTop.");
	end;

	chatFrame:ClearAllPoints();
	width = width - padding.left - padding.right;
	if config.chatBoxTop then
		local parentTop = UIParent:GetTop();
		if not parentTop then
			error("ChitChat: Unable to determine UIParent bounds for chatBoxTop.");
		end;
		local editBox = chatFrame.editBox;
		local editBoxHeight = editBox and math.max(editBox:GetHeight(), config.controlSize) or 0;
		local tabOffset = tab and not config.chatTabsAtBottom and config.chatBoxAboveTabs and tabTop - chatTop or 0;
		local topOffset = chatTop - parentTop - editBoxHeight - 2 - tabOffset;
		chatFrame:SetPoint(
			"TOPLEFT",
			UIParent,
			"TOPLEFT",
			padding.left,
			topOffset + padding.top
		);
		chatFrame:SetSize(
			width,
			parentTop + topOffset + padding.top - parentBottom - padding.bottom
		);
	else
		chatFrame:SetPoint(
			"BOTTOMLEFT",
			UIParent,
			"BOTTOMLEFT",
			padding.left,
			bottom - parentBottom + padding.bottom
		);
		chatFrame:SetSize(width, height - padding.top - padding.bottom);
	end;

	if tab then
		tab:ClearAllPoints();
		if config.chatTabsAtBottom then
			tab:SetPoint("BOTTOMLEFT", chatFrame, "BOTTOMLEFT", 0, tabBottom - chatBottom);
		else
			tab:SetPoint("TOPLEFT", chatFrame, "TOPLEFT", 0, tabTop - chatTop);
		end;
	end;
end;

local editModeClampLoader = CreateFrame("Frame");
editModeClampLoader:RegisterEvent("ADDON_LOADED");
editModeClampLoader:SetScript("OnEvent", function(_, _, addonName)
	if addonName == "Blizzard_EditMode" then
		local chatFrame = _G["ChatFrame1"];
		ClampChatFrameToScreen(chatFrame);
		HookChatFrameCornerPosition(chatFrame);
		editModeClampLoader:UnregisterEvent("ADDON_LOADED");
	end;
end);
