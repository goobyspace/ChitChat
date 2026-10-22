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
	local asterisk = tab.ChitChatUnreadAsterisk;
	if not asterisk then
		asterisk = tab:CreateFontString(nil, "OVERLAY");
		asterisk:SetFont(text:GetFont());
		asterisk:SetText("*");
		asterisk:Hide();
		tab.ChitChatUnreadAsterisk = asterisk;
	end;
	asterisk:SetFont(text:GetFont());
	local textEnd = text:GetStringWidth() / 2 + 2;
	asterisk:ClearAllPoints();
	asterisk:SetPoint("TOPLEFT", text, "TOP", textEnd, 0);
	asterisk:SetPoint("BOTTOMLEFT", text, "BOTTOM", textEnd, 0);
	asterisk:SetJustifyV(text:GetJustifyV());
	asterisk:SetTextColor(1, 1, 1);
	return text, underline;
end;

local function UpdateTabNotification(entry)
	local chatFrame = GetTabChatFrame(entry.frame);
	local pulseLimit = GetConfig(chatFrame, "chatTabsWhisperPulsesStringifiedValue");
	if entry.pulseLimit ~= pulseLimit then
		entry.pulseLimit = pulseLimit;
		entry.pulseCount = 0;
		entry.pulseFinished = nil;
	end;
	if chatFrame and chatFrame:IsShown() then
		entry.unread = nil;
		entry.alerting = nil;
		entry.pulseCount = 0;
		entry.pulseFinished = nil;
	end;
	local highlightUnread = GetConfig(chatFrame, "chatTabsHighlightUnread");
	local showAsterisk = entry.unread and GetConfig(chatFrame, "chatTabsUnreadAsterisk");
	local highlightColour = GetConfig(chatFrame, "chatTabsUnreadHighlightColour");
	entry.highlight:SetColorTexture(highlightColour.r, highlightColour.g, highlightColour.b, highlightColour.a);
	local pulseColour = GetConfig(chatFrame, "chatTabsWhisperPulseColour");
	entry.pulse:SetColorTexture(pulseColour.r, pulseColour.g, pulseColour.b, pulseColour.a);
	entry.highlight:SetShown(entry.unread and highlightUnread);
	local asterisk = entry.frame.ChitChatUnreadAsterisk;
	if asterisk then
		asterisk:SetShown(showAsterisk);
	end;
	entry.minAlpha = entry.alerting and not entry.pulseFinished and 1 or nil;
	if entry.alerting and not entry.pulseFinished then
		entry.pulse:Show();
		if not entry.pulse.FlashAnim:IsPlaying() then
			entry.pulse.FlashAnim:Play();
		end;
	else
		entry.pulse.FlashAnim:Stop();
		entry.pulse:Hide();
	end;
end;

function core.CreateChatTabNotifications(background)
	local highlight = background:CreateTexture(nil, "OVERLAY");
	highlight:SetAllPoints();
	highlight:Hide();
	local pulse = background:CreateTexture(nil, "OVERLAY");
	pulse:SetAllPoints();
	pulse:Hide();
	pulse.FlashAnim = pulse:CreateAnimationGroup();
	pulse.FlashAnim:SetLooping("REPEAT");
	for order = 1, 2 do
		local animation = pulse.FlashAnim:CreateAnimation("Alpha");
		animation:SetOrder(order);
		animation:SetDuration(1);
		animation:SetFromAlpha(order == 1 and 0 or 1);
		animation:SetToAlpha(order == 1 and 1 or 0);
	end;
	return highlight, pulse;
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
	local highlight, pulse = core.CreateChatTabNotifications(background);
	background:SetShown(tab:IsVisible());
	tab:HookScript("OnShow", function()
		background:Show();
	end);
	tab:HookScript("OnHide", function()
		background:Hide();
	end);
	tab.ChitChatBackground = background;
	ApplyTabTextSkin(tab);
	return background, highlight, pulse;
end;

function core:MarkChatTabUnread(chatFrame, alerting)
	if chatFrame:IsShown() or not self:InitializeChatFrameTab(chatFrame) then
		return;
	end;
	local entry = _G[chatFrame:GetName() .. "Tab"].ChitChatTrackedFrame;
	entry.unread = true;
	entry.alerting = entry.alerting or alerting;
	if alerting then
		entry.pulseCount = 0;
		entry.pulseFinished = nil;
		entry.pulse.FlashAnim:Stop();
	end;
	UpdateTabNotification(entry);
	core.QueueChatHoverRefresh();
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

local alertsHooked;

function core:InitializeChatTabs()
	if not alertsHooked then
		alertsHooked = true;
		core.HookGlobal("FCF_StartAlertFlash", function(chatFrame)
			core:MarkChatTabUnread(chatFrame, true);
		end);
		core.HookGlobal("FCF_StopAlertFlash", function(chatFrame)
			local tab = _G[chatFrame:GetName() .. "Tab"];
			local entry = tab and tab.ChitChatTrackedFrame;
			if entry then
				entry.alerting = nil;
				UpdateTabNotification(entry);
				core.QueueChatHoverRefresh();
			end;
		end);
	end;
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
	local background, highlight, pulse = ApplyTabSkin(tab);
	local entry = {
		frame = tab, background = background, alpha = 1,
		highlight = highlight, pulse = pulse,
	};
	tab.ChitChatTrackedFrame = entry;
	trackedFrames[#trackedFrames + 1] = entry;
	pulse.FlashAnim:SetScript("OnLoop", function()
		entry.pulseCount = (entry.pulseCount or 0) + 1;
		if entry.pulseLimit > 0 and entry.pulseCount >= entry.pulseLimit then
			entry.pulseFinished = true;
			UpdateTabNotification(entry);
			core.QueueChatHoverRefresh();
		end;
	end);
	chatFrame:HookScript("OnShow", function()
		UpdateTabNotification(entry);
		core.QueueChatHoverRefresh();
	end);
	if ChatFrameUtil and ChatFrameUtil.IsTabAlerting then
		entry.alerting = ChatFrameUtil.IsTabAlerting(tab);
	else
		entry.alerting = tab.alerting;
	end;
	entry.unread = entry.alerting;
	UpdateTabNotification(entry);
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
	UpdateTabNotification(entry);
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
