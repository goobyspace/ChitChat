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
	local restoring = editBox.ChitChatRestoring;
	editBox.ChitChatRestoring = true;
	editBox:ClearAllPoints();
	for _, p in ipairs(editBox.ChitChatPoints) do
		editBox:SetPoint(p[1], editBox.ChitChatAnchor, p[2], 0, p[3]);
	end;
	editBox.ChitChatRestoring = restoring;
end;

-- blizz re-anchors the edit box to the raw chat frame (with its own x offsets), ignoring our padding
local function RestoreChatInputPoints(editBox)
	local points = editBox.ChitChatPoints;
	if not points or editBox.ChitChatRestoring then
		return;
	end;

	local chatFrame = editBox.ChitChatChatFrame;
	local anchor = core.GetLayoutAnchor(chatFrame);
	if anchor ~= editBox.ChitChatAnchor then
		local tab = editBox.ChitChatTab;
		if GetConfig(chatFrame, "chatBoxTop") and not GetConfig(chatFrame, "chatTabsAtBottom") and tab then
			local tabEdge;
			if GetConfig(chatFrame, "chatBoxAboveTabs") then
				tabEdge = tab:GetTop();
			else
				tabEdge = tab:GetBottom();
			end;
			if not anchor:GetTop() or not tabEdge then
				core.QueueChatRefresh();
				return;
			end;
		end;
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
		core.GetGradientSettings(editBox.ChitChatChatFrame or editBox.chatFrame, "chatInputBackground"),
		1,
		"ARTWORK",
		-1
	);
	local backgroundTextures = background.regions;
	editBox.ChitChatBackgroundTextures = backgroundTextures;
	editBox:HookScript("OnSizeChanged", function()
		background:SetOpacity(1);
	end);
	HideEditBoxBorders(editBox, backgroundTextures);

	local hoverState = {
		isFocused = editBox:HasFocus(),
		isMouseOver = false,
	};
	editBox:EnableMouse(true);
	editBox:SetMouseClickEnabled(true);

	editBox:HookScript("OnShow", function()
		RestoreChatInputPoints(editBox);
		HideEditBoxBorders(editBox, backgroundTextures);
	end);
	hooksecurefunc(editBox, "SetPoint", function()
		RestoreChatInputPoints(editBox);
	end);
	hooksecurefunc(editBox, "SetAllPoints", function()
		RestoreChatInputPoints(editBox);
	end);
	if editBox.SetFocusRegionsShown then
		hooksecurefunc(editBox, "SetFocusRegionsShown", function(_, shown)
			if shown then
				editBox:SetFocusRegionsShown(false);
			end;
		end);
	end;
	if editBox.SetBackdropBorderColor then
		hooksecurefunc(editBox, "SetBackdropBorderColor", function(_, r, g, b, a)
			if r ~= 0 or g ~= 0 or b ~= 0 or a ~= 0 then
				editBox:SetBackdropBorderColor(0, 0, 0, 0);
			end;
		end);
	end;
	for _, region in ipairs({ editBox:GetRegions() }) do
		if region:GetObjectType() == "Texture" and not backgroundTextures[region] and region:GetWidth() > 3 then
			hooksecurefunc(region, "Show", function()
				region:Hide();
			end);
			hooksecurefunc(region, "SetShown", function(shownRegion, shown)
				if shown then
					shownRegion:Hide();
				end;
			end);
		end;
	end;

	local inputEntry = { frame = editBox, alpha = 0 };
	local FadeInput = core.CreateAlphaFader({ inputEntry });
	local function UpdateInputAlpha()
		local chatFrame = editBox.ChitChatChatFrame or editBox.chatFrame;
		local isMouseOver = GetConfig(chatFrame, "chatBoxMouseover")
			and editBox:IsShown() and (hoverState.isMouseOver or editBox:IsMouseOver());
		FadeInput((hoverState.isFocused or isMouseOver) and 1 or 0,
			GetConfig(chatFrame, "fadeDuration"));
	end;
	editBox.ChitChatRefreshInput = function()
		RestoreChatInputPoints(editBox);
		HideEditBoxBorders(editBox, backgroundTextures);
		UpdateInputAlpha();
	end;
	editBox:HookScript("OnEnter", function()
		hoverState.isMouseOver = true;
		UpdateInputAlpha();
	end);
	editBox:HookScript("OnLeave", function()
		hoverState.isMouseOver = false;
		UpdateInputAlpha();
	end);
	editBox:HookScript("OnMouseDown", function()
		editBox:SetFocus();
	end);
	editBox:HookScript("OnEditFocusGained", function()
		HideEditBoxBorders(editBox, backgroundTextures);
		hoverState.isFocused = true;
		UpdateInputAlpha();
	end);
	editBox:HookScript("OnEditFocusLost", function()
		hoverState.isFocused = false;
		UpdateInputAlpha();
	end);
	editBox:HookScript("OnShow", UpdateInputAlpha);
	editBox:HookScript("OnHide", function()
		hoverState.isMouseOver = false;
		UpdateInputAlpha();
	end);
	editBox:SetAlpha(0);

	-- blizz resets the alpha when switching tabs, the old per-frame driver used to hide that
	hooksecurefunc(editBox, "SetAlpha", function(_, alpha)
		if alpha ~= inputEntry.alpha then
			editBox:SetAlpha(inputEntry.alpha);
		end;
	end);
	core.WatchChatLayout(editBox);
	UpdateInputAlpha();
	editBox.ChitChatInputInitialized = true;
end;
