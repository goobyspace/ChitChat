local _, core = ...;

local GetConfig = core.GetConfig;

local function GetTabChatFrame(tab)
	return _G["ChatFrame" .. tab:GetID()];
end;

local function GetTabHeight(chatFrame)
	local _, fontHeight = ChatFontNormal:GetFont();
	return math.max(GetConfig(chatFrame, "tabHeight"), math.ceil(fontHeight or 12) + 6);
end;

local function ApplyTabGradient(background, chatFrame)
	return core.CreateGradientBackground(
		background,
		background,
		"chatTab",
		1,
		"ARTWORK",
		nil,
		nil,
		chatFrame
	);
end;

local function ApplyTabTextSkin(tab)
	local text = tab.Text or tab:GetFontString();
	if not text then
		return nil;
	end;

	local textPoint, textRelativeTo, textRelativePoint, textX, textY = text:GetPoint(1);
	if text:GetNumPoints() ~= 1 or textPoint ~= "CENTER" or textRelativeTo ~= tab
		or textRelativePoint ~= "CENTER" or textX ~= 0 or textY ~= 0 then
		text:ClearAllPoints();
		text:SetPoint("CENTER", tab, "CENTER", 0, 0);
	end;
	text:SetTextColor(1, 1, 1);

	local underline = tab.ChitChatSelectedUnderline;
	if not underline then
		underline = tab:CreateTexture(tab:GetName() .. "ChitChatSelectedUnderline", "OVERLAY");
		underline:SetColorTexture(1, 1, 1, 1);
		underline:SetHeight(1);
		underline:SetPoint("BOTTOM", text, "BOTTOM", 0, -2);
		underline:Hide();
		tab.ChitChatSelectedUnderline = underline;
	end;
	underline:SetWidth(math.max(text:GetStringWidth(), 1));

	return text, underline;
end;

local function ApplyTabSkin(tab)
	if not tab then
		return;
	end;

	local chatFrame = GetTabChatFrame(tab);
	core.HideDefaultTextures(tab);
	tab:SetHeight(GetTabHeight(chatFrame));
	if tab.glow then
		tab.glow:Hide();
	end;
	local background = core.CreateControlBackground(tab, 0, "Background", chatFrame);
	ApplyTabGradient(background, chatFrame);
	background:SetShown(tab:IsVisible());
	tab:HookScript("OnShow", function()
		background:Show();
	end);
	tab:HookScript("OnHide", function()
		background:Hide();
	end);
	tab.ChitChatBackground = background;
	ApplyTabTextSkin(tab);
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

local function SyncTabBackground(tab)
	local background = tab.ChitChatBackground;
	if not background then
		return;
	end;
	local parent = tab:GetParent() or UIParent;
	if background:GetParent() ~= parent then
		background:SetParent(parent);
	end;
	local strata = tab:GetFrameStrata();
	if background:GetFrameStrata() ~= strata then
		background:SetFrameStrata(strata);
	end;
	local level = math.max(parent:GetFrameLevel(), tab:GetFrameLevel() - 1);
	if background:GetFrameLevel() ~= level then
		background:SetFrameLevel(level);
	end;
end;

function core:UpdateChatTab(entry)
	local tab = entry.frame;
	SyncTabBackground(tab);
	-- blizz fades tabs on its own (UIFrameFade) which fights our alpha, hiding the text of scrolling tabs
	if UIFrameFadeRemoveFrame then
		UIFrameFadeRemoveFrame(tab);
	end;
	local tabText = tab.Text or tab:GetFontString();
	if tabText and tabText:GetAlpha() ~= 1 then
		tabText:SetAlpha(1);
	end;
	-- blizz resets the height of tabs when they are re-docked or resized
	local height = GetTabHeight(GetTabChatFrame(tab));
	if tab:GetHeight() ~= height then
		tab:SetHeight(height);
	end;
	local _, underline = ApplyTabTextSkin(tab);
	if underline then
		core.HideDefaultTextures(tab, underline);
		local chatFrame = _G["ChatFrame" .. tab:GetID()];
		underline:SetShown(chatFrame and chatFrame:IsShown());
	end;
end;
