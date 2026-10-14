local _, core = ...;

function core.StyleScrollBar(bar)
	bar:SetThumbTexture("Interface\\AddOns\\ChitChat\\Assets\\scrollbarthumb.tga");
	local thumb = bar:GetThumbTexture();
	thumb:SetSize(core.SCROLLBAR_WIDTH, 24);
	thumb:SetVertexColor(1, 1, 1, 1);
	local track = {};
	for index = 1, 2 do
		local texture = bar:CreateTexture(nil, "BACKGROUND");
		texture:SetColorTexture(1, 1, 1, 1);
		if index == 1 then
			texture:SetPoint("TOPLEFT");
			texture:SetPoint("BOTTOMRIGHT", bar, "RIGHT");
			texture:SetGradient("VERTICAL", CreateColor(1, 1, 1, 0.6), CreateColor(1, 1, 1, 0.3));
		else
			texture:SetPoint("TOPLEFT", bar, "LEFT");
			texture:SetPoint("BOTTOMRIGHT");
			texture:SetGradient("VERTICAL", CreateColor(1, 1, 1, 0.3), CreateColor(1, 1, 1, 0.6));
		end;
		texture:Hide();
		track[index] = texture;
	end;
	local selected = false;
	local function UpdateTrack()
		local visible = bar:IsShown() and (selected or bar:IsMouseOver());
		for _, texture in ipairs(track) do
			texture:SetShown(visible);
		end;
	end;
	bar:HookScript("OnMouseDown", function(_, button)
		if button == "LeftButton" then
			selected = true;
			UpdateTrack();
		end;
	end);
	bar:HookScript("OnMouseUp", function(_, button)
		if button == "LeftButton" then
			selected = false;
			UpdateTrack();
		end;
	end);
	bar:HookScript("OnHide", function()
		selected = false;
		UpdateTrack();
	end);
	for _, script in ipairs({ "OnEnter", "OnLeave", "OnShow" }) do
		bar:HookScript(script, UpdateTrack);
	end;
	bar:SetMouseMotionEnabled(true);
end;

function core.HideDefaultTextures(frame, keepTexture)
	for _, region in ipairs({ frame:GetRegions() }) do
		local keep = region == keepTexture or type(keepTexture) == "table" and keepTexture[region];
		if not keep and region:GetObjectType() == "Texture" then
			region:Hide();
		end;
	end;
end;

function core.IsCombatLogFrame(chatFrame)
	if not chatFrame then
		return false;
	end;
	if type(IsCombatLog) == "function" then
		return IsCombatLog(chatFrame);
	end;
	return chatFrame == _G["ChatFrame2"];
end;

function core.GetChatWindowCount()
	return math.max(NUM_CHAT_WINDOWS or 0, CHAT_FRAMES and #CHAT_FRAMES or 0);
end;

core.hoverRefreshes = {};
core.layoutRefreshes = {};

-- callbacks get core passed in so colon functions work as is
function core.RegisterHoverRefresh(fn)
	core.hoverRefreshes[#core.hoverRefreshes + 1] = fn;
end;

function core.RegisterLayoutRefresh(fn)
	core.layoutRefreshes[#core.layoutRefreshes + 1] = fn;
end;

local globalHooks = {};
function core.HookGlobal(name, fn)
	if type(_G[name]) ~= "function" then
		return;
	end;
	local callbacks = globalHooks[name];
	if not callbacks then
		callbacks = {};
		globalHooks[name] = callbacks;
		hooksecurefunc(name, function(...)
			for _, callback in ipairs(callbacks) do
				callback(...);
			end;
		end);
	end;
	callbacks[#callbacks + 1] = fn;
end;

function core.RegisterSizeChanged(frame, fn)
	local callbacks = frame.ChitChatSizeCallbacks;
	if not callbacks then
		callbacks = {};
		frame.ChitChatSizeCallbacks = callbacks;
		frame:HookScript("OnSizeChanged", function(...)
			for _, callback in ipairs(callbacks) do
				callback(...);
			end;
		end);
	end;
	for _, existing in ipairs(callbacks) do
		if existing == fn then
			return;
		end;
	end;
	callbacks[#callbacks + 1] = fn;
end;

function core.WatchChatHover(frame)
	if not frame or frame.ChitChatHoverWatched then
		return;
	end;
	frame.ChitChatHoverWatched = true;
	-- chat frames disable mouse clicks but still need enter and leave notifications
	-- the client turns clicks on again once motion is enabled, which makes the frame swallow clicks meant for whatever sits under it :/
	local clickEnabled = frame:IsMouseClickEnabled();
	local function RestoreClicks()
		-- turning clicks off mid drag eats the mouse up so the slider never lets go
		if not frame.ChitChatDragging and frame:IsMouseClickEnabled() ~= clickEnabled then
			frame:SetMouseClickEnabled(clickEnabled);
		end;
	end;
	frame:SetMouseMotionEnabled(true);
	RestoreClicks();
	for _, script in ipairs({ "OnEnter", "OnLeave", "OnShow", "OnHide" }) do
		frame:HookScript(script, function()
			RestoreClicks();
			core.QueueChatHoverRefresh();
		end);
	end;
end;

function core.WatchChatLayout(frame)
	if not frame or frame.ChitChatLayoutWatched then
		return;
	end;
	frame.ChitChatLayoutWatched = true;
	for _, script in ipairs({ "OnShow", "OnHide" }) do
		frame:HookScript(script, function()
			core.QueueChatRefresh();
		end);
	end;
	core.RegisterSizeChanged(frame, function()
		core.QueueChatRefresh();
	end);
	for _, method in ipairs({ "SetPoint", "SetAllPoints", "SetParent", "SetFrameStrata", "SetFrameLevel" }) do
		hooksecurefunc(frame, method, function()
			core.QueueChatRefresh();
		end);
	end;
	core.WatchChatHover(frame);
end;

function core.CreateAlphaFader(entries)
	local driver = CreateFrame("Frame");
	local targetAlpha, duration;

	local function Update(_, elapsed)
		local step = duration > 0 and math.min(elapsed / duration, 1) or 1;
		local animating = false;
		for _, entry in ipairs(entries) do
			entry.alpha = entry.alpha + (targetAlpha - entry.alpha) * step;
			if math.abs(entry.alpha - targetAlpha) < 0.01 then
				entry.alpha = targetAlpha;
			else
				animating = true;
			end;
			entry.frame:SetAlpha(entry.alpha);
			if entry.background then
				entry.background:SetAlpha(entry.alpha);
			end;
			for _, texture in ipairs(entry.frame.ChitChatIconTextures or {}) do
				texture:SetAlpha(entry.alpha);
			end;
		end;
		if not animating then
			driver:SetScript("OnUpdate", nil);
		end;
	end;

	return function(alpha, fadeDuration)
		targetAlpha, duration = alpha, fadeDuration;
		driver:SetScript("OnUpdate", Update);
		Update(nil, 0);
	end;
end;

function core.GetLayoutAnchor(chatFrame)
	local main = _G["ChatFrame1"];
	if main and main.ChitChatInner and (chatFrame == main or chatFrame.isDocked) then
		return main.ChitChatInner;
	end;
	return chatFrame;
end;

function core.GetMessageInsets(chatFrame)
	local main = _G["ChatFrame1"];
	local insets = main and (chatFrame == main or chatFrame.isDocked) and main.ChitChatSelectionInsets;
	if insets then
		return insets[1], insets[2], insets[3], insets[4];
	end;
	return 0, 0, 0, 0;
end;
