--errors arent real errors so disable them
---@diagnostic disable

local _, core = ...;

local config = core.config;

local controlPositions = {
	TOPLEFT = { vertical = "TOP", horizontal = "LEFT", right = false, bottom = false },
	TOPRIGHT = { vertical = "TOP", horizontal = "RIGHT", right = true, bottom = false },
	BOTTOMLEFT = { vertical = "BOTTOM", horizontal = "LEFT", right = false, bottom = true },
	BOTTOMRIGHT = { vertical = "BOTTOM", horizontal = "RIGHT", right = true, bottom = true },
};

function core.GetControlPosition()
	local position = controlPositions[config.controls.position];
	if not position then
		error("ChitChat: Invalid controls.position; expected TOPLEFT, TOPRIGHT, BOTTOMLEFT, or BOTTOMRIGHT.");
	end;
	return position;
end;

function core.PositionControlButton(button, row, index, position)
	if not button then
		return;
	end;

	local frameStrata = row:GetFrameStrata();
	local frameLevel = row:GetFrameLevel() + 1;
	if button:GetFrameStrata() ~= frameStrata then
		button:SetFrameStrata(frameStrata);
	end;
	if button:GetFrameLevel() ~= frameLevel then
		button:SetFrameLevel(frameLevel);
	end;
	if button:GetWidth() ~= config.controlSize or button:GetHeight() ~= config.controlSize then
		button:SetSize(config.controlSize, config.controlSize);
	end;
	local offset = (index - 1) * (config.controlSize + config.controlSpacing);
	local point;
	local x;
	local y;
	if config.controls.vertical then
		point = position.vertical .. position.horizontal;
		x = 0;
		y = position.bottom and offset or -offset;
	else
		point = position.horizontal;
		if position.right then
			offset = (index - 1) * (config.controlSize + config.controlSpacing);
			x = -offset;
		else
			x = offset;
		end;
		y = 0;
	end;
	local currentPoint, relativeTo, relativePoint, currentX, currentY = button:GetPoint(1);
	if button:GetNumPoints() ~= 1
		or currentPoint ~= point
		or relativeTo ~= row
		or relativePoint ~= point
		or currentX ~= x
		or currentY ~= y then
		button:ClearAllPoints();
		button:SetPoint(point, row, point, x, y);
	end;
	if not button.ChitChatBackground then
		button.ChitChatBackground = core.ApplyControlButtonIcon(button);
	end;
	local background = button.ChitChatBackground;
	if background:GetFrameStrata() ~= frameStrata then
		background:SetFrameStrata(frameStrata);
	end;
	local backgroundLevel = math.max(
		background:GetParent():GetFrameLevel(),
		button:GetFrameLevel() - 1
	);
	if background:GetFrameLevel() ~= backgroundLevel then
		background:SetFrameLevel(backgroundLevel);
	end;
end;

local function GetControlRowSize(buttonCount)
	local spacing = math.max(buttonCount - 1, 0) * config.controlSpacing;
	local width = config.controls.vertical and config.controlSize
		or buttonCount * config.controlSize + spacing;
	local height = config.controls.vertical and buttonCount * config.controlSize + spacing
		or config.controlSize;
	return width, height;
end;

local function GetHighestVisibleTabTop(selectedTab)
	local tabTop = selectedTab and selectedTab:GetTop();
	for index = 1, NUM_CHAT_WINDOWS do
		local tab = _G["ChatFrame" .. index .. "Tab"];
		local visibleTabTop = tab and tab:IsShown() and tab:GetTop();
		if visibleTabTop and (not tabTop or visibleTabTop > tabTop) then
			tabTop = visibleTabTop;
		end;
	end;
	return tabTop;
end;

local function GetControlRowAnchors(chatFrame, position, selectedTab, isCombatLog)
	local rowPoint = position.vertical .. position.horizontal;
	local framePoint = rowPoint;
	local relativeTo = chatFrame;
	local offsetX = 0;
	local offsetY = 0;
	if config.controls.vertical and config.controls.outside then
		rowPoint = position.vertical .. (position.right and "LEFT" or "RIGHT");
		framePoint = position.vertical .. (position.right and "RIGHT" or "LEFT");
		offsetX = position.right and 2 or -2;
	elseif not config.controls.vertical and isCombatLog
		and not config.controls.outside
		and not position.bottom
		and selectedTab then
		rowPoint = "TOP" .. position.horizontal;
		framePoint = "BOTTOM" .. position.horizontal;
		relativeTo = selectedTab;
		offsetY = -(config.controlSize + 2);
	elseif not config.controls.vertical and config.controls.outside and not position.bottom then
		rowPoint = "BOTTOM" .. position.horizontal;
		framePoint = "TOP" .. position.horizontal;
		local chatTop = chatFrame:GetTop();
		local tabTop = GetHighestVisibleTabTop(selectedTab);
		offsetY = chatTop and tabTop and math.max(2, tabTop - chatTop + 2) or 2;
	elseif not config.controls.vertical and config.controls.outside then
		rowPoint = (position.bottom and "TOP" or "BOTTOM") .. position.horizontal;
		offsetY = position.bottom and -2 or 2;
	end;

	return rowPoint, relativeTo, framePoint, offsetX, offsetY;
end;

function core.PositionControlRow(row, chatFrame, buttonCount, position, selectedTab, isCombatLog)
	local width, height = GetControlRowSize(buttonCount);
	local rowPoint, relativeTo, framePoint, offsetX, offsetY =
		GetControlRowAnchors(chatFrame, position, selectedTab, isCombatLog);
	row:SetSize(width, height);
	row:ClearAllPoints();
	row:SetPoint(rowPoint, relativeTo, framePoint, offsetX, offsetY);
end;

local frameStrataOrder = {
	BACKGROUND = "LOW",
	LOW = "MEDIUM",
	MEDIUM = "HIGH",
	HIGH = "DIALOG",
	DIALOG = "FULLSCREEN",
	FULLSCREEN = "FULLSCREEN_DIALOG",
	FULLSCREEN_DIALOG = "TOOLTIP",
	TOOLTIP = "TOOLTIP",
};

function core.SetControlLayering(row, chatFrame, editBox)
	local frameLevel = chatFrame:GetFrameLevel();
	if editBox then
		row:SetFrameStrata(frameStrataOrder[editBox:GetFrameStrata()] or "TOOLTIP");
		frameLevel = math.max(frameLevel, editBox:GetFrameLevel());
	else
		row:SetFrameStrata(chatFrame:GetFrameStrata());
	end;
	row:SetToplevel(true);
	row:SetFrameLevel(frameLevel + 5);
end;
