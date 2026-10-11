local _, core = ...;

local GetConfig = core.GetConfig;

local function HideEditBoxBorders(editBox, keepTextures)
	keepTextures = keepTextures or editBox.ChitChatBackgroundTextures;
	for _, region in ipairs({ editBox:GetRegions() }) do
		if region:GetObjectType() == "Texture" and region:GetWidth() <= 3 then
			-- Leave the blizz line alone so we get the text blinker, but delete the big round circle
		elseif not (keepTextures and keepTextures[region]) and region:GetObjectType() == "Texture" then
			region:Hide();
		elseif region.SetIgnoreParentAlpha then
			region:SetIgnoreParentAlpha(false);
		end;
	end;
	if editBox.SetBackdropBorderColor then
		editBox:SetBackdropBorderColor(0, 0, 0, 0);
	end;
	if editBox.SetFocusRegionsShown then
		editBox:SetFocusRegionsShown(false);
	end;
end;

local function ApplyChatInputPoints(editBox)
	editBox:ClearAllPoints();
	for _, p in ipairs(editBox.ChitChatPoints) do
		editBox:SetPoint(p[1], editBox.ChitChatAnchor, p[2], 0, p[3]);
	end;
end;

-- blizz re-anchors the edit box to the raw chat frame (with its own x offsets), ignoring our padding
local function RestoreChatInputPoints(editBox)
	local points = editBox.ChitChatPoints;
	if not points or editBox.ChitChatRestoring then
		return;
	end;

	if core.GetLayoutAnchor(editBox.ChitChatChatFrame) ~= editBox.ChitChatAnchor then
		editBox.ChitChatRestoring = true;
		core:PositionChatInput(editBox, editBox.ChitChatChatFrame, editBox.ChitChatTab);
		editBox.ChitChatRestoring = nil;
		return;
	end;
	local matches = editBox:GetNumPoints() == #points;
	if matches then
		for index, p in ipairs(points) do
			local point, relativeTo, relativePoint, x, y = editBox:GetPoint(index);
			if point ~= p[1] or relativeTo ~= editBox.ChitChatAnchor or relativePoint ~= p[2]
				or math.abs(x) > 0.01 or math.abs(y - p[3]) > 0.01 then
				matches = false;
				break;
			end;
		end;
	end;
	if not matches then
		editBox.ChitChatRestoring = true;
		ApplyChatInputPoints(editBox);
		editBox.ChitChatRestoring = nil;
	end;
end;

function core:PositionChatInput(editBox, chatFrame, tab)
	if not editBox then
		return;
	end;

	local height = math.max(editBox:GetHeight(), GetConfig(chatFrame, "controlSize"));
	editBox.ChitChatChatFrame = chatFrame;
	editBox.ChitChatTab = tab;
	local configFrame = chatFrame;
	chatFrame = core.GetLayoutAnchor(chatFrame);
	local points;
	if GetConfig(configFrame, "chatBoxTop") then
		if GetConfig(configFrame, "chatTabsAtBottom") then
			points = { { "BOTTOMLEFT", "TOPLEFT", 2 }, { "BOTTOMRIGHT", "TOPRIGHT", 2 } };
		elseif tab then
			local chatTop = chatFrame:GetTop();
			local tabEdge = GetConfig(configFrame, "chatBoxAboveTabs") and tab:GetTop() or tab:GetBottom();
			if not chatTop or not tabEdge then
				error("ChitChat: Unable to determine ChatFrame1 tab bounds for chatBoxTop.");
			end;
			if GetConfig(configFrame, "chatBoxAboveTabs") then
				local offset = tabEdge - chatTop + 2;
				points = { { "BOTTOMLEFT", "TOPLEFT", offset }, { "BOTTOMRIGHT", "TOPRIGHT", offset } };
			else
				local offset = tabEdge - chatTop - 2;
				points = { { "TOPLEFT", "TOPLEFT", offset }, { "TOPRIGHT", "TOPRIGHT", offset } };
			end;
		else
			points = { { "BOTTOMLEFT", "TOPLEFT", 2 }, { "BOTTOMRIGHT", "TOPRIGHT", 2 } };
		end;
	else
		points = { { "TOPLEFT", "BOTTOMLEFT", -2 }, { "TOPRIGHT", "BOTTOMRIGHT", 0 } };
	end;
	editBox.ChitChatAnchor = chatFrame;
	editBox.ChitChatPoints = points;
	ApplyChatInputPoints(editBox);
	editBox:SetHeight(height);
	HideEditBoxBorders(editBox);
end;

function core:InitializeChatInput(editBox)
	if not editBox then
		return;
	end;
	if editBox.ChitChatInputInitialized then
		return;
	end;

	local background = core.CreateGradientBackground(
		editBox,
		editBox,
		"chatInput",
		1,
		"ARTWORK",
		-1,
		nil,
		editBox.ChitChatChatFrame or editBox.chatFrame
	);
	local backgroundTextures = background.regions;
	editBox.ChitChatBackgroundTextures = backgroundTextures;
	editBox:HookScript("OnSizeChanged", function()
		background:SetOpacity(1);
	end);
	HideEditBoxBorders(editBox, backgroundTextures);

	local hoverState = {
		isFocused = false,
		isMouseOver = false,
	};
	editBox:EnableMouse(true);
	editBox:SetMouseClickEnabled(true);

	editBox:HookScript("OnShow", function()
		RestoreChatInputPoints(editBox);
		HideEditBoxBorders(editBox, backgroundTextures);
	end);
	editBox:HookScript("OnUpdate", function()
		RestoreChatInputPoints(editBox);
		HideEditBoxBorders(editBox, backgroundTextures);
	end);
	editBox:HookScript("OnEnter", function()
		hoverState.isMouseOver = true;
	end);
	editBox:HookScript("OnLeave", function()
		hoverState.isMouseOver = false;
	end);
	editBox:HookScript("OnMouseDown", function()
		editBox:SetFocus();
	end);
	editBox:HookScript("OnEditFocusGained", function()
		HideEditBoxBorders(editBox, backgroundTextures);
		hoverState.isFocused = true;
	end);
	editBox:HookScript("OnEditFocusLost", function()
		hoverState.isFocused = false;
	end);
	local inputAlpha = 0;
	editBox:SetAlpha(inputAlpha);
	editBox:Show();

	local inputFadeDriver = CreateFrame("Frame");
	inputFadeDriver:SetScript("OnUpdate", function(_, elapsed)
		local chatFrame = editBox.ChitChatChatFrame or editBox.chatFrame;
		local isMouseOver = GetConfig(chatFrame, "chatBoxMouseover")
			and (hoverState.isMouseOver or editBox:IsMouseOver());
		local targetAlpha = (hoverState.isFocused or isMouseOver) and 1 or 0;
		local step = math.min(elapsed / GetConfig(chatFrame, "fadeDuration"), 1);
		inputAlpha = inputAlpha + (targetAlpha - inputAlpha) * step;
		if math.abs(inputAlpha - targetAlpha) < 0.01 then
			inputAlpha = targetAlpha;
		end;
		editBox:SetAlpha(inputAlpha);
	end);
	editBox.ChitChatInputInitialized = true;
end;
