local _, core = ...;

local config = core.config;

local function GetTabHeight()
	local _, fontHeight = ChatFontNormal:GetFont();
	return math.max(config.tabHeight, math.ceil(fontHeight or 12) + 6);
end;

local function ApplyTabGradient(background)
	return core.CreateGradientBackground(
		background,
		background,
		"chatTab",
		1,
		"ARTWORK"
	);
end;

local function ApplyTabSkin(tab)
	if not tab then
		return;
	end;

	core.HideDefaultTextures(tab);
	tab:SetHeight(GetTabHeight());
	if tab.glow then
		tab.glow:Hide();
	end;
	local background = core.CreateControlBackground(tab, 0, "Background");
	ApplyTabGradient(background);
	background:SetShown(tab:IsVisible());
	tab:HookScript("OnShow", function()
		background:Show();
	end);
	tab:HookScript("OnHide", function()
		background:Hide();
	end);
	tab.ChitChatBackground = background;
	local text = tab.Text or tab:GetFontString();
	if text then
		text:ClearAllPoints();
		text:SetPoint("CENTER", tab, "CENTER", 0, 0);
		text:SetTextColor(1, 1, 1);
		local underline = tab:CreateTexture(tab:GetName() .. "ChitChatSelectedUnderline", "OVERLAY");
		underline:SetColorTexture(1, 1, 1, 1);
		underline:SetHeight(1);
		underline:SetPoint("BOTTOM", text, "BOTTOM", 0, -2);
		underline:SetWidth(math.max(text:GetStringWidth(), 1));
		underline:Hide();
		tab.ChitChatSelectedUnderline = underline;
	end;
	return tab.ChitChatBackground;
end;

function core:SyncChatTabs(trackedFrames)
	for index = 1, core.GetChatWindowCount() do
		local tab = _G["ChatFrame" .. index .. "Tab"];
		if tab and not tab.ChitChatBackground then
			tab:SetAlpha(1);
			trackedFrames[#trackedFrames + 1] = {
				frame = tab,
				background = ApplyTabSkin(tab),
				alpha = 1,
			};
		end;
	end;
end;

function core:InitializeChatTabs()
	local trackedFrames = {};
	core:SyncChatTabs(trackedFrames);
	return trackedFrames;
end;

function core:UpdateChatTab(entry)
	local tab = entry.frame;
	-- blizz fades tabs on its own (UIFrameFade) which fights our alpha, hiding the text of non-general tabs
	if UIFrameFadeRemoveFrame then
		UIFrameFadeRemoveFrame(tab);
	end;
	local tabText = tab.Text or tab:GetFontString();
	if tabText and tabText:GetAlpha() ~= 1 then
		tabText:SetAlpha(1);
	end;
	-- blizz resets the height of tabs when they are re-docked or resized
	local height = GetTabHeight();
	if tab:GetHeight() ~= height then
		tab:SetHeight(height);
	end;
	local underline = tab.ChitChatSelectedUnderline;
	if underline then
		core.HideDefaultTextures(tab, underline);
		local chatFrame = _G["ChatFrame" .. tab:GetID()];
		local text = tab.Text or tab:GetFontString();
		text:SetTextColor(1, 1, 1);
		-- blizz repositions the text when it resizes a tab
		local textPoint, textRelativeTo, textRelativePoint, textX, textY = text:GetPoint(1);
		if text:GetNumPoints() ~= 1 or textPoint ~= "CENTER" or textRelativeTo ~= tab
			or textRelativePoint ~= "CENTER" or textX ~= 0 or textY ~= 0 then
			text:ClearAllPoints();
			text:SetPoint("CENTER", tab, "CENTER", 0, 0);
		end;
		underline:SetWidth(math.max(text:GetStringWidth(), 1));
		underline:SetShown(chatFrame == SELECTED_CHAT_FRAME);
	end;
end;
