local _, core = ...;

local GetConfig = core.GetConfig;
local trackedFrames = {};
local FadeTabs = core.CreateAlphaFader(trackedFrames);

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
		core.GetGradientSettings(chatFrame, "chatTabBackground"),
		1,
		"BACKGROUND"
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
	local parent = tab:GetParent() or UIParent;
	local background = CreateFrame("Frame", nil, parent);
	background:EnableMouse(false);
	background:SetFrameStrata(tab:GetFrameStrata());
	background:SetFrameLevel(math.max(parent:GetFrameLevel(), tab:GetFrameLevel() - 1));
	background:SetAllPoints(tab);
	background.ChitChatGradient = ApplyTabGradient(background, chatFrame);
	background:SetShown(tab:IsVisible());
	tab:HookScript("OnShow", function()
		background:Show();
	end);
	tab:HookScript("OnHide", function()
		background:Hide();
	end);
	tab.ChitChatBackground = background;
	ApplyTabTextSkin(tab);
	return background;
end;

function core:SyncChatTabs()
	for index = 1, core.GetChatWindowCount() do
		self:InitializeChatFrameTab(_G["ChatFrame" .. index]);
	end;
end;

function core:AreChatTabsHovered()
	for _, entry in ipairs(trackedFrames) do
		if entry.frame:IsShown() and entry.frame:IsMouseOver() then
			return true;
		end;
	end;
	return false;
end;

function core:RefreshChatTabAlpha()
	local chatFrame = SELECTED_CHAT_FRAME or _G["ChatFrame1"];
	if not chatFrame then
		return;
	end;
	local chatFrameHovered = chatFrame.IsMouseOver and chatFrame:IsMouseOver();
	local targetAlpha = (GetConfig(chatFrame, "alwaysShowChatTabs")
		or core:AreChatTabsHovered()
		or chatFrameHovered
		or core.IsCombatLogFrame(chatFrame))
		and 1 or (GetConfig(chatFrame, "chatTabsIdleAlpha") or 0);
	for _, entry in ipairs(trackedFrames) do
		if UIFrameFadeRemoveFrame then
			UIFrameFadeRemoveFrame(entry.frame);
		end;
		entry.frame:SetAlpha(entry.alpha);
	end;
	FadeTabs(targetAlpha, GetConfig(chatFrame, "alwaysShowChatTabs") and 0
		or GetConfig(chatFrame, "fadeDuration"));
end;

function core:RefreshChatTabs()
	core:SyncChatTabs();
	for _, entry in ipairs(trackedFrames) do
		core:UpdateChatTab(entry);
	end;
end;

core.RegisterLayoutRefresh(core.RefreshChatTabs);
core.RegisterHoverRefresh(core.RefreshChatTabAlpha);

function core:InitializeChatTabs()
	core:RefreshChatTabs();
	core.QueueChatHoverRefresh();
	return trackedFrames;
end;

function core:InitializeChatFrameTab(chatFrame)
	local tab = chatFrame and _G[(chatFrame:GetName() or "") .. "Tab"];
	if not tab then
		return false;
	end;
	if tab.ChitChatTrackedFrame then
		return true;
	end;
	tab:SetAlpha(1);
	local entry = { frame = tab, background = ApplyTabSkin(tab), alpha = 1 };
	tab.ChitChatTrackedFrame = entry;
	trackedFrames[#trackedFrames + 1] = entry;
	core.WatchChatLayout(tab);
	local text = tab.Text or tab:GetFontString();
	if text then
		hooksecurefunc(text, "SetText", core.QueueChatRefresh);
		hooksecurefunc(text, "SetFont", core.QueueChatRefresh);
		hooksecurefunc(text, "SetPoint", core.QueueChatRefresh);
		hooksecurefunc(text, "SetTextColor", core.QueueChatRefresh);
		hooksecurefunc(text, "SetAlpha", function(_, alpha)
			if alpha ~= 1 then
				text:SetAlpha(1);
			end;
		end);
	end;
	for _, region in ipairs({ tab:GetRegions() }) do
		if region:GetObjectType() == "Texture" and region ~= tab.ChitChatSelectedUnderline then
			hooksecurefunc(region, "Show", function()
				region:Hide();
			end);
			hooksecurefunc(region, "SetShown", function(_, shown)
				if shown then
					region:Hide();
				end;
			end);
		end;
	end;
	if tab.glow then
		hooksecurefunc(tab.glow, "Show", function()
			tab.glow:Hide();
		end);
		hooksecurefunc(tab.glow, "SetShown", function(_, shown)
			if shown then
				tab.glow:Hide();
			end;
		end);
	end;
	return true;
end;

function core:UpdateChatTab(entry)
	local tab = entry.frame;
	local background = tab.ChitChatBackground;
	if background then
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
		background.ChitChatGradient:SetOpacity(1);
	end;
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
