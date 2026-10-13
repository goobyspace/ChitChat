--errors arent real errors so disable them
---@diagnostic disable

local _, core = ...;

local GetConfig = core.GetConfig;

local function GetTabMetrics(chatFrame, tab)
	if chatFrame.ChitChatTabMetrics then
		return chatFrame.ChitChatTabMetrics;
	end;
	local tabTop, tabBottom = tab and tab:GetTop(), tab and tab:GetBottom();
	local chatTop, chatBottom = chatFrame:GetTop(), chatFrame:GetBottom();
	if tab and (not tabTop or not tabBottom or not chatTop or not chatBottom) then
		return nil;
	end;

	local heightDelta = tab and (tab:GetHeight() - GetConfig(chatFrame, "tabHeight")) or 0;
	local metrics = {
		above = tab and tabTop - chatTop - heightDelta or 0,
		below = tab and chatBottom - tabBottom or 0,
	};
	chatFrame.ChitChatTabMetrics = metrics;
	return metrics;
end;

local function GetOuterElementInsets(chatFrame, tab, metrics)
	local left, right, top, bottom = 0, 0, 0, 0;

	if tab then
		if GetConfig(chatFrame, "chatTabsAtBottom") then
			bottom = math.max(bottom, metrics.below);
		elseif not GetConfig(chatFrame, "chatBoxTop") then
			top = math.max(top, metrics.above);
		end;
	end;

	if not GetConfig(chatFrame, "chatBoxTop") then
		local editBox = chatFrame.editBox;
		local editBoxHeight = editBox and math.max(editBox:GetHeight(), GetConfig(chatFrame, "controlSize")) or 0;
		bottom = math.max(bottom, editBoxHeight + 2);
	end;

	local tabTopOffset = tab and not GetConfig(chatFrame, "chatTabsAtBottom") and math.max(0, metrics.above) or 0;
	local controlLeft, controlRight, controlTop, controlBottom = core.GetControlInsets(chatFrame, tabTopOffset);
	return math.max(left, controlLeft), math.max(right, controlRight),
		math.max(top, controlTop), math.max(bottom, controlBottom);
end;

local function GetCombatLogBarHeight(frame)
	local bar = CombatLogQuickButtonFrame_Custom;
	if bar and bar:IsShown() and type(IsCombatLog) == "function" and IsCombatLog(frame) then
		return bar:GetHeight();
	end;
	return 0;
end;

core.SCROLLBAR_WIDTH = 8;

-- horizontal space the optional scrollbar takes from the messages
local function GetScrollBarInsets(frame)
	if core.GetScrollBarInsets then
		return core.GetScrollBarInsets(frame);
	end;
	return 0, 0;
end;

-- this broke being able to click hyperlinks in chat so use it sparingly
local function AnchorMessageContainer(frame, container, inner)
	local topOffset = -GetCombatLogBarHeight(frame);
	local leftInset, rightInset = GetScrollBarInsets(frame);
	if container:GetNumPoints() == 2 then
		local topPoint, topRelativeTo, topRelativePoint, topX, topY = container:GetPoint(1);
		local bottomPoint, bottomRelativeTo, bottomRelativePoint, bottomX, bottomY = container:GetPoint(2);
		if topPoint == "TOPLEFT" and topRelativeTo == inner and topRelativePoint == "TOPLEFT"
			and math.abs(topX - leftInset) < 0.01 and math.abs(topY - topOffset) < 0.01
			and bottomPoint == "BOTTOMRIGHT" and bottomRelativeTo == inner and bottomRelativePoint == "BOTTOMRIGHT"
			and math.abs(bottomX + rightInset) < 0.01 and math.abs(bottomY) < 0.01 then
			return;
		end;
	end;
	container:ClearAllPoints();
	container:SetPoint("TOPLEFT", inner, "TOPLEFT", leftInset, topOffset);
	container:SetPoint("BOTTOMRIGHT", inner, "BOTTOMRIGHT", -rightInset, 0);
	container:SetClipsChildren(true);
end;

-- we have to update the positions because otherwise outside messages get clipped from the main box's boundary
function core.SyncMessageContainers()
	local main = _G["ChatFrame1"];
	for index = 1, core.GetChatWindowCount() do
		local frame = _G["ChatFrame" .. index];
		local container = frame and frame.FontStringContainer;
		if container and frame ~= main and not frame.isDocked then
			local _, relativeTo = container:GetPoint(1);
			if container:GetNumPoints() ~= 2 or relativeTo ~= frame then
				AnchorMessageContainer(frame, container, frame);
			end;
		elseif container and main and main.ChitChatInner and frame ~= main and frame.isDocked then
			local _, relativeTo = container:GetPoint(1);
			if container:GetNumPoints() ~= 2 or relativeTo ~= main.ChitChatInner then
				AnchorMessageContainer(frame, container, main.ChitChatInner);
			end;
		end;
	end;
end;

local function ClipMessagesToInner(main)
	for index = 1, core.GetChatWindowCount() do
		local frame = _G["ChatFrame" .. index];
		local container = frame and frame.FontStringContainer;
		if container and (frame == main or frame.isDocked) then
			AnchorMessageContainer(frame, container, main.ChitChatInner);
		end;
	end;
end;

function core.PositionCombatLogBar()
	local bar = CombatLogQuickButtonFrame_Custom;
	local main = _G["ChatFrame1"];
	local inner = main and main.ChitChatInner;
	if not bar or not inner or bar.ChitChatPositioning then
		return;
	end;
	bar.ChitChatPositioning = true;
	local point, relativeTo, _, x, y = bar:GetPoint(1);
	if bar:GetNumPoints() ~= 2 or relativeTo ~= inner or point ~= "TOPLEFT" or x ~= 0 or y ~= 0 then
		bar:ClearAllPoints();
		bar:SetPoint("TOPLEFT", inner, "TOPLEFT", 0, 0);
		bar:SetPoint("TOPRIGHT", inner, "TOPRIGHT", 0, 0);
	end;
	for index = 1, core.GetChatWindowCount() do
		local frame = _G["ChatFrame" .. index];
		local container = frame and frame.FontStringContainer;
		if container and (frame == main or frame.isDocked) then
			AnchorMessageContainer(frame, container, inner);
		end;
	end;
	bar.ChitChatPositioning = nil;
end;

local combatLogBarHooked;
local function HookCombatLogBar()
	local bar = CombatLogQuickButtonFrame_Custom;
	if combatLogBarHooked or not bar then
		return;
	end;
	combatLogBarHooked = true;
	bar:HookScript("OnShow", core.PositionCombatLogBar);
	bar:HookScript("OnHide", core.PositionCombatLogBar);
	for _, name in ipairs({ "FCF_Tab_OnClick", "FCF_SelectDockFrame", "FCF_DockUpdate", "FCF_SetTabPosition" }) do
		core.HookGlobal(name, core.PositionCombatLogBar);
	end;
	hooksecurefunc(bar, "SetPoint", core.PositionCombatLogBar);
end;

local function WaitForTabGeometry(chatFrame, tab)
	chatFrame.ChitChatWaitingForGeometry = true;
	if not chatFrame.ChitChatGeometryCallback then
		chatFrame.ChitChatGeometryCallback = function()
			if not chatFrame.ChitChatWaitingForGeometry or not GetTabMetrics(chatFrame, tab) then
				return;
			end;
			chatFrame.ChitChatWaitingForGeometry = nil;
			core.PositionChatFrameForPadding(chatFrame);
		end;
	end;
	core.RegisterSizeChanged(chatFrame, chatFrame.ChitChatGeometryCallback);
	if tab then
		core.RegisterSizeChanged(tab, chatFrame.ChitChatGeometryCallback);
	end;
end;

function core.PositionChatFrameForPadding(chatFrame)
	core.ClampChatFrameToScreen(chatFrame);
	core.HookChatFrameCornerPosition(chatFrame);
	core.RestoreSavedBottomLeftAnchor(chatFrame);
	local tab = _G["ChatFrame1Tab"];
	local metrics = GetTabMetrics(chatFrame, tab);
	if not metrics then
		WaitForTabGeometry(chatFrame, tab);
		return;
	end;
	local paddingLeft, paddingRight, paddingTop, paddingBottom = GetConfig(chatFrame, "paddingLeft"),
		GetConfig(chatFrame, "paddingRight"), GetConfig(chatFrame, "paddingTop"),
		GetConfig(chatFrame, "paddingBottom");
	local insetLeft, insetRight, insetTop, insetBottom = GetOuterElementInsets(chatFrame, tab, metrics);
	paddingLeft = paddingLeft + insetLeft;
	paddingRight = paddingRight + insetRight;
	paddingTop = paddingTop + insetTop;
	paddingBottom = paddingBottom + insetBottom;
	if GetConfig(chatFrame, "chatBoxTop") then
		local editBox = chatFrame.editBox;
		local editBoxHeight = editBox and math.max(editBox:GetHeight(), GetConfig(chatFrame, "controlSize")) or 0;
		local tabOffset = tab and not GetConfig(chatFrame, "chatTabsAtBottom")
			and GetConfig(chatFrame, "chatBoxAboveTabs") and metrics.above or 0;
		paddingTop = paddingTop + editBoxHeight + 2 + tabOffset;
	end;
	chatFrame.ChitChatSelectionInsets = { paddingLeft, paddingRight, paddingTop, paddingBottom };

	local inner = chatFrame.ChitChatInner;
	if not inner then
		inner = CreateFrame("Frame", nil, chatFrame);
		chatFrame.ChitChatInner = inner;
	end;
	inner:ClearAllPoints();
	inner:SetPoint("TOPLEFT", chatFrame, "TOPLEFT", paddingLeft, -paddingTop);
	inner:SetPoint("BOTTOMRIGHT", chatFrame, "BOTTOMRIGHT", -paddingRight, paddingBottom);
	ClipMessagesToInner(chatFrame);
	core.controlsDirty = true;
	if chatFrame.MarkLayoutDirty then
		chatFrame:MarkLayoutDirty();
	end;
	core.EnforceTabAnchor(chatFrame);
end;

function core:InitializeChatFrameLayout(chatFrame, refresh)
	if not chatFrame then
		return false;
	end;
	if chatFrame.ChitChatLayoutInitialized and not refresh then
		return true;
	end;
	if chatFrame == _G["ChatFrame1"] then
		core.PositionChatFrameForPadding(chatFrame);
	end;
	core.SyncMessageContainers();
	local editBox = chatFrame.editBox;
	if editBox and core.PositionChatInput then
		local frameIndex = chatFrame:GetID();
		local tab = frameIndex and _G["ChatFrame" .. frameIndex .. "Tab"] or _G["ChatFrame1Tab"];
		local canPositionInput = true;
		if GetConfig(chatFrame, "chatBoxTop") and tab
			and not GetConfig(chatFrame, "chatTabsAtBottom") then
			local chatTop = core.GetLayoutAnchor(chatFrame):GetTop();
			local tabEdge = GetConfig(chatFrame, "chatBoxAboveTabs") and tab:GetTop() or tab:GetBottom();
			canPositionInput = chatTop ~= nil and tabEdge ~= nil;
		end;
		if canPositionInput then
			core:PositionChatInput(editBox, chatFrame, tab);
		end;
	end;
	chatFrame.ChitChatLayoutInitialized = true;
	return true;
end;

local function AlignDockToInner(chatFrame)
	local dock = GENERAL_CHAT_DOCK;
	local insets = chatFrame.ChitChatSelectionInsets;
	if not dock or not insets then
		return;
	end;
	local left, right = insets[1], insets[2];
	-- blizz uses the dock's rect to detect dropped windows, so it has to sit on the tab row wherever the tabs are moved to
	local y = 3;
	local tab = _G["ChatFrame1Tab"];
	local tabBottom, chatTop = tab and tab:GetBottom(), chatFrame:GetTop();
	if tabBottom and chatTop then
		y = tabBottom - chatTop;
	end;
	local function IsAligned(index, point, x)
		local currentPoint, relativeTo, relativePoint, currentX, currentY = dock:GetPoint(index);
		return currentPoint == point and relativeTo == chatFrame and
			relativePoint == (point == "BOTTOMLEFT" and "TOPLEFT" or "TOPRIGHT")
			and math.abs(currentX - x) < 0.01 and math.abs(currentY - y) < 0.01;
	end;
	if dock:GetNumPoints() == 2 and IsAligned(1, "BOTTOMLEFT", left) and IsAligned(2, "BOTTOMRIGHT", -right) then
		return;
	end;
	dock:ClearAllPoints();
	dock:SetPoint("BOTTOMLEFT", chatFrame, "TOPLEFT", left, y);
	dock:SetPoint("BOTTOMRIGHT", chatFrame, "TOPRIGHT", -right, y);
	if FCFDock_OnPrimarySizeChanged then
		FCFDock_OnPrimarySizeChanged(dock);
	end;
end;

local function AlignDockScrollFrame(firstTab)
	local dock = GENERAL_CHAT_DOCK;
	local scrollFrame = dock and dock.scrollFrame;
	if not scrollFrame then
		return;
	end;

	local lastStaticTab;
	for _, dockedFrame in ipairs(dock.DOCKED_CHAT_FRAMES or {}) do
		if dockedFrame.isStaticDocked then
			lastStaticTab = _G[dockedFrame:GetName() .. "Tab"];
		end;
	end;
	local tabBottom, dockBottom, dockRight = firstTab:GetBottom(), dock:GetBottom(), dock:GetRight();
	if not lastStaticTab or not tabBottom or not dockBottom or not dockRight then
		return;
	end;

	local overflow = dock.overflowButton;
	local rightOffset = 0;
	if overflow and overflow:IsShown() and overflow:GetLeft() then
		rightOffset = overflow:GetLeft() - dockRight - 5;
	end;
	local padding = 4;
	local topOffset = padding;
	local bottomOffset = tabBottom - dockBottom - padding - 2;

	local topPoint, topRelativeTo, topRelativePoint, topX, topY = scrollFrame:GetPoint(1);
	local _, bottomRelativeTo, _, bottomX, bottomY = scrollFrame:GetPoint(2);
	if scrollFrame:GetNumPoints() == 2 and topPoint == "TOPLEFT" and topRelativeTo == lastStaticTab
		and topRelativePoint == "TOPRIGHT" and topX == 1 and topY == topOffset and bottomRelativeTo == dock
		and math.abs(bottomX - rightOffset) < 0.01 and math.abs(bottomY - bottomOffset) < 0.01 then
		return;
	end;
	scrollFrame:ClearAllPoints();
	scrollFrame:SetPoint("TOPLEFT", lastStaticTab, "TOPRIGHT", 1, topOffset);
	scrollFrame:SetPoint("BOTTOMRIGHT", dock, "BOTTOMRIGHT", rightOffset, bottomOffset);
end;

-- we want the tabs to be inside the edit mode area for clarity, but blizz doesnt naturally do that so force it
function core.EnforceTabAnchor(chatFrame)
	local inner = chatFrame.ChitChatInner;
	local container = chatFrame.FontStringContainer;
	if inner and container then
		local _, relativeTo = container:GetPoint(1);
		if container:GetNumPoints() ~= 2 or relativeTo ~= inner then
			AnchorMessageContainer(chatFrame, container, inner);
		end;
		container:SetClipsChildren(true);
	end;
	HookCombatLogBar();
	core.PositionCombatLogBar();
	local tab = _G["ChatFrame1Tab"];
	local metrics = chatFrame.ChitChatTabMetrics;
	if not tab or not inner or not metrics then
		return;
	end;
	local atBottom = GetConfig(chatFrame, "chatTabsAtBottom");
	local point = atBottom and "BOTTOMLEFT" or "TOPLEFT";
	local offset = atBottom and -metrics.below or metrics.above;
	local currentPoint, relativeTo, relativePoint, x, y = tab:GetPoint(1);
	if tab:GetNumPoints() ~= 1 or currentPoint ~= point or relativeTo ~= inner
		or relativePoint ~= point or x ~= 0 or y ~= offset then
		tab:ClearAllPoints();
		tab:SetPoint(point, inner, point, 0, offset);
	end;
	AlignDockToInner(chatFrame);
	AlignDockScrollFrame(tab);
end;

core.RegisterLayoutRefresh(core.SyncMessageContainers, 10);
core.RegisterLayoutRefresh(function()
	local main = _G["ChatFrame1"];
	if main and main.ChitChatLayoutInitialized then
		core.EnforceTabAnchor(main);
	end;
end);
