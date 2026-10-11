local _, core = ...;

local config = core.config;

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
	local _, fontHeight = ChatFontNormal:GetFont();
	tab:SetHeight(math.max(config.tabHeight, math.ceil(fontHeight or 12) + 6));
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

function core:InitializeChatTabs()
	local trackedFrames = {};
	for index = 1, NUM_CHAT_WINDOWS do
		local tab = _G["ChatFrame" .. index .. "Tab"];
		if tab then
			tab:SetAlpha(1);
			trackedFrames[#trackedFrames + 1] = {
				frame = tab,
				background = ApplyTabSkin(tab),
				alpha = 1,
			};
		end;
	end;
	return trackedFrames;
end;

function core:UpdateChatTab(entry)
	local tab = entry.frame;
	local underline = tab.ChitChatSelectedUnderline;
	if underline then
		core.HideDefaultTextures(tab, underline);
		local chatFrame = _G["ChatFrame" .. tab:GetID()];
		local text = tab.Text or tab:GetFontString();
		text:SetTextColor(1, 1, 1);
		underline:SetWidth(math.max(text:GetStringWidth(), 1));
		underline:SetShown(chatFrame == SELECTED_CHAT_FRAME);
	end;
end;
