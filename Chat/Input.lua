local _, core = ...;

local config = core.config;

local function HideEditBoxBorders(editBox, keepTextures)
	keepTextures = keepTextures or editBox.ChitChatBackgroundTextures;
	for _, region in ipairs({ editBox:GetRegions() }) do
		if not (keepTextures and keepTextures[region]) and region:GetObjectType() == "Texture" then
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

function core:PositionChatInput(editBox, chatFrame, tab)
	if not editBox then
		return;
	end;

	local height = math.max(editBox:GetHeight(), config.controlSize);
	editBox:ClearAllPoints();
	if config.chatBoxTop then
		if config.chatTabsAtBottom then
			editBox:SetPoint("BOTTOMLEFT", chatFrame, "TOPLEFT", 0, 2);
			editBox:SetPoint("BOTTOMRIGHT", chatFrame, "TOPRIGHT", 0, 2);
		elseif tab then
			local chatTop = chatFrame:GetTop();
			local tabEdge = config.chatBoxAboveTabs and tab:GetTop() or tab:GetBottom();
			if not chatTop or not tabEdge then
				error("ChitChat: Unable to determine ChatFrame1 tab bounds for chatBoxTop.");
			end;
			if config.chatBoxAboveTabs then
				local offset = tabEdge - chatTop + 2;
				editBox:SetPoint("BOTTOMLEFT", chatFrame, "TOPLEFT", 0, offset);
				editBox:SetPoint("BOTTOMRIGHT", chatFrame, "TOPRIGHT", 0, offset);
			else
				local offset = tabEdge - chatTop - 2;
				editBox:SetPoint("TOPLEFT", chatFrame, "TOPLEFT", 0, offset);
				editBox:SetPoint("TOPRIGHT", chatFrame, "TOPRIGHT", 0, offset);
			end;
		else
			editBox:SetPoint("BOTTOMLEFT", chatFrame, "TOPLEFT", 0, 2);
			editBox:SetPoint("BOTTOMRIGHT", chatFrame, "TOPRIGHT", 0, 2);
		end;
	else
		editBox:SetPoint("TOPLEFT", chatFrame, "BOTTOMLEFT", 0, -2);
		editBox:SetPoint("TOPRIGHT", chatFrame, "BOTTOMRIGHT", 0, 0);
	end;
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

	local settings = config.backgrounds.chatInput;
	local background = core.CreateGradientBackground(
		editBox,
		editBox,
		settings,
		1,
		"ARTWORK",
		-1
	);
	local backgroundTextures = background.regions;
	editBox.ChitChatBackgroundTextures = backgroundTextures;
	HideEditBoxBorders(editBox, backgroundTextures);

	local hoverState = {
		isFocused = false,
		isMouseOver = false,
	};
	editBox:EnableMouse(true);
	editBox:SetMouseClickEnabled(true);

	editBox:HookScript("OnShow", function()
		HideEditBoxBorders(editBox, backgroundTextures);
	end);
	editBox:HookScript("OnUpdate", function()
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
		local isMouseOver = config.chatBoxMouseover
			and (hoverState.isMouseOver or editBox:IsMouseOver());
		local targetAlpha = (hoverState.isFocused or isMouseOver) and 1 or 0;
		local step = math.min(elapsed / config.fadeDuration, 1);
		inputAlpha = inputAlpha + (targetAlpha - inputAlpha) * step;
		if math.abs(inputAlpha - targetAlpha) < 0.01 then
			inputAlpha = targetAlpha;
		end;
		editBox:SetAlpha(inputAlpha);
	end);
	editBox.ChitChatInputInitialized = true;
end;
