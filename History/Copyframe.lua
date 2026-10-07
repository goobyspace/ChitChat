local _, core = ...;

local copyFrame;
local copyTitle;
local copyMessageFrame;
local copyScrollBar;
local updatingScrollBar;
local selectedText;
local selectionGeneration = 0;

local combatEvents = CreateFrame("Frame");
combatEvents:RegisterEvent("PLAYER_IN_COMBAT_CHANGED");
combatEvents:SetScript("OnEvent", function(_, _, isInCombat)
	if isInCombat and copyFrame then
		copyFrame:Hide();
	end;
end);

local function ClearMessageSelection()
	selectionGeneration = selectionGeneration + 1;

	if copyMessageFrame and copyMessageFrame:IsSelectingText() then
		copyMessageFrame:ResetSelectingText();
	end;

	if copyMessageFrame and copyMessageFrame.highlightTexturePool then
		copyMessageFrame.highlightTexturePool:ReleaseAll();
	end;

	selectedText = nil;
end;

local function ShowMessageSelection(messageFrame, selection)
	local startLineIndex = selection.startLineIndex;
	local endLineIndex = selection.endLineIndex;
	local startCharacterIndex = selection.startCharacterIndex;
	local endCharacterIndex = selection.endCharacterIndex;

	if not startLineIndex or not endLineIndex
		or not startCharacterIndex or not endCharacterIndex then
		return;
	end;

	for lineIndex = math.min(startLineIndex, endLineIndex), math.max(startLineIndex, endLineIndex) do
		local visibleLine = messageFrame.visibleLines[lineIndex];
		if visibleLine and visibleLine:GetText() then
			local selectingStartIndex, selectingEndIndex = messageFrame:CalculateSelectingCharacterIndicesForVisibleLine(
				lineIndex,
				startLineIndex,
				endLineIndex,
				startCharacterIndex,
				endCharacterIndex
			);
			local screenAreaTable = visibleLine:CalculateScreenAreaFromCharacterSpan(selectingStartIndex,
				selectingEndIndex);

			if screenAreaTable then
				for _, screenArea in ipairs(screenAreaTable) do
					local highlightTexture = messageFrame:AcquireHighlightTexture();
					highlightTexture:SetPoint("BOTTOMLEFT", visibleLine, "BOTTOMLEFT", screenArea.left, screenArea
						.bottom);
					highlightTexture:SetPoint("TOPRIGHT", visibleLine, "BOTTOMLEFT", screenArea.left + screenArea.width,
						screenArea.bottom + screenArea.height);
					highlightTexture:Show();
				end;
			end;
		end;
	end;
end;

local function GetMaxScrollRange(messageFrame)
	return math.max(messageFrame:GetNumMessages() - messageFrame:GetNumVisibleLines() + 1, 0);
end;

local function UpdateScrollBar(messageFrame)
	local maxScroll = GetMaxScrollRange(messageFrame);
	copyScrollBar:SetMinMaxValues(0, maxScroll);
	copyScrollBar:SetValue(maxScroll - messageFrame:GetScrollOffset());
	copyScrollBar:SetShown(maxScroll > 0);
end;

local function SetMessageFrameText(messageFrame, text)
	ClearMessageSelection();

	local lines = {};
	for line in (text .. "\n"):gmatch("(.-)\n") do
		lines[#lines + 1] = line;
	end;

	messageFrame:Clear();
	messageFrame:SetMaxLines(math.max(#lines, 10000));
	for _, line in ipairs(lines) do
		messageFrame:AddMessage(line);
	end;
	messageFrame:ScrollToBottom();
end;

local function CreateCopyFrame()
	local frame = CreateFrame("Frame", "ChitChatCopyFrame", UIParent, "BackdropTemplate");
	frame:SetSize(500, 400);
	frame:SetPoint("CENTER");
	frame:SetFrameStrata("DIALOG");
	frame:SetMovable(true);
	frame:EnableMouse(true);
	frame:RegisterForDrag("LeftButton");
	frame:SetScript("OnDragStart", frame.StartMoving);
	frame:SetScript("OnDragStop", frame.StopMovingOrSizing);
	frame:SetBackdrop({
		bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
		edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
		tile = true,
		tileSize = 32,
		edgeSize = 32,
		insets = { left = 8, right = 8, top = 8, bottom = 8 },
	});

	local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal");
	title:SetPoint("TOPLEFT", frame, "TOPLEFT", 18, -16);

	local closeButton = CreateFrame("Button", nil, frame, "UIPanelCloseButton");
	closeButton:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -4, -4);
	closeButton:SetScript("OnClick", function()
		frame:Hide();
	end);

	local messageFrame = CreateFrame("ScrollingMessageFrame", "ChitChatCopyMessageFrame", frame);
	messageFrame:SetPoint("TOPLEFT", frame, "TOPLEFT", 18, -44);
	messageFrame:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -48, 18);
	messageFrame:SetFontObject(ChatFontNormal);
	messageFrame:SetJustifyH("LEFT");
	messageFrame:SetFading(false);
	messageFrame:SetTextCopyable(not InCombatLockdown());
	messageFrame:SetIndentedWordWrap(true);
	messageFrame:EnableMouse(true);
	messageFrame:SetMouseClickEnabled(true);

	messageFrame:SetScript("OnMouseDown", function(self, buttonName)
		if InCombatLockdown() then
			return;
		end;
		if buttonName == "LeftButton" then
			ClearMessageSelection();
		end;
	end);

	messageFrame:SetScript("OnMouseUp", function(self, buttonName)
		if InCombatLockdown() then
			return;
		end;
		if buttonName == "LeftButton" and self:IsSelectingText() then
			local x, y = self:GetScaledCursorPosition();
			local endCharacterIndex, endLineIndex = self:FindCharacterAndLineIndexAtCoordinate(x, y);
			selectedText = self:GatherSelectedText(x, y);

			if selectedText and endCharacterIndex and endLineIndex then
				local currentGeneration = selectionGeneration;
				local selection = {
					startCharacterIndex = self.selectingCharacterIndex,
					startLineIndex = self.selectingVisibleLineIndex,
					endCharacterIndex = endCharacterIndex,
					endLineIndex = endLineIndex,
				};
				C_Timer.After(0, function()
					if self:IsShown() and selectedText and selectionGeneration == currentGeneration then
						ShowMessageSelection(self, selection);
					end;
				end);
			else
				selectedText = nil;
			end;
		end;
	end);

	messageFrame:EnableMouseWheel(true);
	messageFrame:SetScript("OnMouseWheel", function(self, delta)
		if InCombatLockdown() then
			return;
		end;
		ClearMessageSelection();
		local offset = self:GetScrollOffset() + (delta > 0 and 1 or -1);
		self:SetScrollOffset(math.min(math.max(offset, 0), GetMaxScrollRange(self)));
	end);

	local scrollBar = CreateFrame("Slider", "ChitChatCopyScrollBar", frame, "UIPanelScrollBarTemplate");
	scrollBar:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -18, -54);
	scrollBar:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -18, 28);
	scrollBar:SetMinMaxValues(0, 0);
	scrollBar:SetValueStep(1);
	scrollBar:SetObeyStepOnDrag(true);
	scrollBar:SetScript("OnValueChanged", function(_, value)
		if not InCombatLockdown() and not updatingScrollBar then
			ClearMessageSelection();
			local maxScroll = GetMaxScrollRange(messageFrame);
			messageFrame:SetScrollOffset(maxScroll - math.floor(value + 0.5));
		end;
	end);

	messageFrame:AddOnDisplayRefreshedCallback(function(refreshedMessageFrame)
		updatingScrollBar = true;
		UpdateScrollBar(refreshedMessageFrame);
		updatingScrollBar = false;
	end);

	frame:EnableKeyboard(true);
	if not InCombatLockdown() then
		frame:SetPropagateKeyboardInput(false);
	end;
	frame:SetScript("OnKeyDown", function(self, key)
		if not InCombatLockdown() then
			self:SetPropagateKeyboardInput(false);
			key = string.upper(key);
			if key == "ESCAPE" then
				self:Hide();
			elseif key == "C" and IsControlKeyDown() and selectedText then
				local REMOVE_MARKUP = true;
				CopyToClipboard(selectedText, REMOVE_MARKUP);
			end;
		end;
	end);
	frame:SetScript("OnHide", function()
		ClearMessageSelection();
	end);

	copyFrame = frame;
	copyTitle = title;
	copyMessageFrame = messageFrame;
	copyScrollBar = scrollBar;
end;

function core:ShowCopyFrame(text, title)
	if InCombatLockdown() then
		if copyFrame then
			copyFrame:Hide();
		end;
		return;
	end;

	if not copyFrame then
		CreateCopyFrame();
	end;

	text = tostring(text or "");
	copyTitle:SetText(title or "ChitChat chat history - select text to copy");
	copyMessageFrame:SetTextCopyable(true);
	SetMessageFrameText(copyMessageFrame, text);
	copyFrame:Show();
end;
