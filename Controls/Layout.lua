--errors arent real errors so disable them
---@diagnostic disable

local _, core = ...;

local GetConfig = core.GetConfig;

local controlPositions = {
	TOPLEFT = { vertical = "TOP", horizontal = "LEFT", right = false, bottom = false },
	TOPRIGHT = { vertical = "TOP", horizontal = "RIGHT", right = true, bottom = false },
	BOTTOMLEFT = { vertical = "BOTTOM", horizontal = "LEFT", right = false, bottom = true },
	BOTTOMRIGHT = { vertical = "BOTTOM", horizontal = "RIGHT", right = true, bottom = true },
};

function core.GetControlPosition(chatFrame)
	local position = controlPositions[GetConfig(chatFrame, "controlsPositionStringifiedValue")];
	if not position then
		core.SetConfig(chatFrame, "controlsPosition", 0);
		core.SetConfig(chatFrame, "controlsPositionStringifiedValue", "TOPLEFT");
		return controlPositions.TOPLEFT;
	end;
	return position;
end;

function core.GetControlInsets(chatFrame, tabTopOffset)
	if not GetConfig(chatFrame, "controlsOutside") then
		return 0, 0, 0, 0;
	end;

	local position = core.GetControlPosition(chatFrame);
	local size = GetConfig(chatFrame, "controlSize") + 2;
	if GetConfig(chatFrame, "controlsVertical") then
		if position.right then
			return 0, size, 0, 0;
		end;
		return size, 0, 0, 0;
	elseif position.bottom then
		return 0, 0, 0, size;
	end;
	return 0, 0, size + tabTopOffset, 0;
end;

function core.GetControlStep(chatFrame)
	return GetConfig(chatFrame, "controlSize") + GetConfig(chatFrame, "controlSpacing")
		+ 2 * core.CONTROL_BACKGROUND_INSET;
end;

function core.PositionControlButton(button, row, index, position, chatFrame)
	if not button then
		return;
	end;

	local controlSize = GetConfig(chatFrame, "controlSize");
	local frameStrata = row:GetFrameStrata();
	local frameLevel = row:GetFrameLevel() + 1;
	if button:GetFrameStrata() ~= frameStrata then
		button:SetFrameStrata(frameStrata);
	end;
	if button:GetFrameLevel() ~= frameLevel then
		button:SetFrameLevel(frameLevel);
	end;
	if button:GetWidth() ~= controlSize or button:GetHeight() ~= controlSize then
		button:SetSize(controlSize, controlSize);
	end;
	local offset = (index - 1) * core.GetControlStep(chatFrame);
	local point;
	local x;
	local y;
	if GetConfig(chatFrame, "controlsVertical") then
		point = position.vertical .. position.horizontal;
		x = 0;
		y = position.bottom and offset or -offset;
	else
		point = position.horizontal;
		if position.right then
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
		button.ChitChatBackground = core.ApplyControlButtonIcon(
			button,
			button.ChitChatIcon,
			core.GetGradientSettings(chatFrame, "controlBackground")
		);
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

local function GetControlRowSize(buttonCount, chatFrame)
	local controlSize = GetConfig(chatFrame, "controlSize");
	local vertical = GetConfig(chatFrame, "controlsVertical");
	local spacing = math.max(buttonCount - 1, 0) * (core.GetControlStep(chatFrame) - controlSize);
	local width = vertical and controlSize
		or buttonCount * controlSize + spacing;
	local height = vertical and buttonCount * controlSize + spacing
		or controlSize;
	return width, height;
end;

local function GetHighestVisibleTabTop(selectedTab)
	local tabTop = selectedTab and selectedTab:GetTop();
	for index = 1, core.GetChatWindowCount() do
		local tab = _G["ChatFrame" .. index .. "Tab"];
		local visibleTabTop = tab and tab:IsShown() and tab:GetTop();
		if visibleTabTop and (not tabTop or visibleTabTop > tabTop) then
			tabTop = visibleTabTop;
		end;
	end;
	return tabTop;
end;

local function GetControlRowAnchors(chatFrame, position, selectedTab, isCombatLog, configFrame)
	local rowPoint = position.vertical .. position.horizontal;
	local framePoint = rowPoint;
	local relativeTo = chatFrame;
	local offsetX = 0;
	local offsetY = 0;
	local vertical = GetConfig(configFrame, "controlsVertical");
	local outside = GetConfig(configFrame, "controlsOutside");
	if not vertical then
		offsetX = position.right and -core.CONTROL_BACKGROUND_INSET or core.CONTROL_BACKGROUND_INSET;
	end;
	if vertical and outside then
		rowPoint = position.vertical .. (position.right and "LEFT" or "RIGHT");
		framePoint = position.vertical .. (position.right and "RIGHT" or "LEFT");
		offsetX = position.right and 2 or -2;
	elseif not vertical and isCombatLog
		and not outside
		and not position.bottom
		and selectedTab then
		rowPoint = "TOP" .. position.horizontal;
		framePoint = "TOP" .. position.horizontal;
		offsetY = -(GetConfig(configFrame, "controlSize") + 2);
	elseif not vertical and outside and not position.bottom then
		rowPoint = "BOTTOM" .. position.horizontal;
		framePoint = "TOP" .. position.horizontal;
		local chatTop = chatFrame:GetTop();
		local tabTop = GetHighestVisibleTabTop(selectedTab);
		offsetY = chatTop and tabTop and math.max(2, tabTop - chatTop + 2) or 2;
	elseif not vertical and outside then
		rowPoint = (position.bottom and "TOP" or "BOTTOM") .. position.horizontal;
		offsetY = position.bottom and -2 or 2;
	end;

	return rowPoint, relativeTo, framePoint, offsetX, offsetY;
end;

function core.PositionControlRow(row, chatFrame, buttonCount, position, selectedTab, isCombatLog, areaTopOffset)
	local configFrame = chatFrame;
	chatFrame = core.GetLayoutAnchor(chatFrame);
	local width, height = GetControlRowSize(buttonCount, configFrame);
	local rowPoint, relativeTo, framePoint, offsetX, offsetY =
		GetControlRowAnchors(chatFrame, position, selectedTab, isCombatLog, configFrame);
	if GetConfig(configFrame, "controlsVertical") and GetConfig(configFrame, "controlsOutside")
		and not position.bottom then
		offsetY = areaTopOffset and math.max(areaTopOffset, 0) or 0;
	end;
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

function core.CreateSelectedChatFramePositioner(row, chatFrame, buttons, mainTab)
	local activeChatFrame;
	local activeEditBox;
	local activeEditBoxTabOffset;

	-- without this the other chat window's edit boxes show up in weird places when clicked
	local function ShowOnlySelectedEditBox(selectedEditBox)
		for index = 1, core.GetChatWindowCount() do
			local frame = _G["ChatFrame" .. index];
			local editBox = frame and frame.editBox;
			if editBox and editBox ~= selectedEditBox and editBox:IsShown() and not editBox:HasFocus() then
				editBox:Hide();
			end;
		end;
		if selectedEditBox and not selectedEditBox:IsShown() then
			selectedEditBox:Show();
		end;
	end;

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
		if GetConfig(selectedChatFrame, "chatBoxTop") and selectedTab
			and not GetConfig(selectedChatFrame, "chatTabsAtBottom") then
			local chatTop = core.GetLayoutAnchor(selectedChatFrame):GetTop();
			local tabEdge = GetConfig(selectedChatFrame, "chatBoxAboveTabs") and selectedTab:GetTop()
				or selectedTab:GetBottom();
			-- bounds are unavailable while frames are mid-drag/undock
			if not chatTop or not tabEdge then
				return activeChatFrame or selectedChatFrame;
			end;
			editBoxTabOffset = tabEdge - chatTop;
		end;

		if selectedChatFrame == activeChatFrame and selectedEditBox == activeEditBox and not core.controlsDirty then
			if core.IsCombatLogFrame(selectedChatFrame) and selectedEditBox and not selectedEditBox:IsShown() then
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
		ShowOnlySelectedEditBox(selectedEditBox);
		core.controlsDirty = nil;
		activeEditBoxTabOffset = editBoxTabOffset;
		core.PositionControlRow(
			row,
			selectedChatFrame,
			#buttons,
			core.GetControlPosition(selectedChatFrame),
			selectedTab,
			core.IsCombatLogFrame(selectedChatFrame)
		);
		core.SetControlLayering(row, selectedChatFrame, selectedEditBox);

		if core.IsCombatLogFrame(selectedChatFrame) and selectedEditBox then
			selectedEditBox:Show();
		end;
		activeChatFrame = selectedChatFrame;
		activeEditBox = selectedEditBox;
		return selectedChatFrame;
	end;
end;
