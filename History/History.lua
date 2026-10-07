local _, core = ...;

local config = core.config;
local historyStorageKey = "chatHistory";

local function IsNormalChatFrame(chatFrame)
	if not chatFrame then
		return false;
	end;

	if type(IsCombatLog) == "function" then
		return not IsCombatLog(chatFrame);
	end;

	return chatFrame ~= _G["ChatFrame2"];
end;

local function GetSavedLineCount()
	local lineCount = config.historyLines;
	if type(lineCount) ~= "number" or lineCount < 0 or lineCount % 1 ~= 0 then
		error("ChitChat: config.historyLines must be a non-negative integer.");
	end;

	return lineCount;
end;

local function GetVisibleLines(chatFrame, lineLimit)
	local visibleLines = chatFrame.visibleLines;
	if type(visibleLines) ~= "table" or lineLimit == 0 then
		return {};
	end;

	local lines = {};
	local lastVisibleIndex = math.min(#visibleLines, lineLimit);
	for lineIndex = lastVisibleIndex, 1, -1 do
		local visibleLine = visibleLines[lineIndex];
		local text = visibleLine and visibleLine.GetText and visibleLine:GetText();
		if type(text) == "string" then
			lines[#lines + 1] = { text = text };
		end;
	end;

	return lines;
end;

local function GetChatHistories()
	local lineLimit = GetSavedLineCount();
	local histories = {};
	for frameIndex = 1, NUM_CHAT_WINDOWS do
		local chatFrame = _G["ChatFrame" .. frameIndex];
		if IsNormalChatFrame(chatFrame) then
			local lines = {};
			if chatFrame.GetNumMessages and chatFrame.GetMessageInfo then
				local messageCount = chatFrame:GetNumMessages();
				local firstMessageIndex = math.max(1, messageCount - lineLimit + 1);

				for messageIndex = firstMessageIndex, messageCount do
					local text, r, g, b, chatTypeID, messageAccessID, lineID =
						chatFrame:GetMessageInfo(messageIndex);
					if type(text) == "string" then
						lines[#lines + 1] = {
							text = text,
							r = r,
							g = g,
							b = b,
							chatTypeID = chatTypeID,
							messageAccessID = messageAccessID,
							lineID = lineID,
						};
					end;
				end;
			end;

			if #lines == 0 then
				lines = GetVisibleLines(chatFrame, lineLimit);
			end;
			if #lines > 0 then
				histories[frameIndex] = lines;
			end;
		end;
	end;

	return histories;
end;

function core:GetChatHistoryText(maxLines)
	if maxLines ~= nil
		and (type(maxLines) ~= "number" or maxLines < 0 or maxLines % 1 ~= 0) then
		error("ChitChat: maxLines must be a non-negative integer.");
	end;
	if maxLines == 0 then
		return "";
	end;

	local output = {};

	local chatFrame = SELECTED_CHAT_FRAME or _G["ChatFrame1"];
	if not IsNormalChatFrame(chatFrame) then
		return "No chat history is available to copy.";
	end;

	local lines = {};
	if chatFrame.GetNumMessages and chatFrame.GetMessageInfo then
		for messageIndex = 1, chatFrame:GetNumMessages() do
			local text = chatFrame:GetMessageInfo(messageIndex);
			if type(text) == "string" then
				lines[#lines + 1] = text;
			end;
		end;
	end;
	if #lines == 0 then
		for _, line in ipairs(GetVisibleLines(chatFrame, math.huge)) do
			lines[#lines + 1] = line.text;
		end;
	end;
	if #lines == 0 then
		local savedHistories = ChitChatGlobalStorage and ChitChatGlobalStorage[historyStorageKey];
		local frameIndex = chatFrame:GetID();
		local savedLines = type(savedHistories) == "table" and savedHistories[frameIndex];
		if type(savedLines) == "table" then
			for _, line in ipairs(savedLines) do
				if type(line) == "table" and type(line.text) == "string" then
					lines[#lines + 1] = line.text;
				end;
			end;
		end;
	end;

	if #lines > 0 then
		local frameIndex = chatFrame:GetID();
		local tab = frameIndex and _G["ChatFrame" .. frameIndex .. "Tab"];
		local tabText = tab and (tab.Text or tab:GetFontString());
		local chatName = tabText and tabText:GetText();
		output[#output + 1] = chatName or ("Chat " .. (frameIndex or 1));
		for _, line in ipairs(lines) do
			output[#output + 1] = line;
		end;
		output[#output + 1] = "";
	end;

	if #output == 0 then
		return "No chat history is available to copy.";
	end;

	if maxLines ~= nil then
		while #output > 0 and output[#output] == "" do
			output[#output] = nil;
		end;

		local firstLine = math.max(1, #output - maxLines + 1);
		local lastLines = {};
		for lineIndex = firstLine, #output do
			lastLines[#lastLines + 1] = output[lineIndex];
		end;
		output = lastLines;
	end;

	return table.concat(output, "\n");
end;

function core.CreateHistoryControlButton(parent)
	local button = CreateFrame("Button", "ChitChatCopyHistoryButton", parent);
	button:SetScript("OnClick", function()
		if InCombatLockdown() then
			return;
		end;

		local text = core:GetChatHistoryText();
		core:ShowCopyFrame(text, "ChitChat chat history - select text to copy");
	end);
	button:SetScript("OnEnter", function(hoveredButton)
		GameTooltip:SetOwner(hoveredButton, "ANCHOR_RIGHT");
		GameTooltip:SetText(InCombatLockdown() and "Combat lockdown" or "Copy chat history");
		GameTooltip:Show();
	end);
	button:SetScript("OnLeave", function()
		GameTooltip:Hide();
	end);
	button.ChitChatBackground = core.ApplyControlButtonIcon(button, config.controlIcon);
	return button;
end;

function core:SaveChatHistory()
	if not config.historyEnabled then
		return;
	end;

	ChitChatGlobalStorage[historyStorageKey] = GetChatHistories();
end;

function core:RestoreChatHistory()
	if not config.historyEnabled then
		return;
	end;

	local histories = ChitChatGlobalStorage and ChitChatGlobalStorage[historyStorageKey];
	if type(histories) ~= "table" then
		return;
	end;

	for frameIndex = 1, NUM_CHAT_WINDOWS do
		local chatFrame = _G["ChatFrame" .. frameIndex];
		local lines = histories[frameIndex];
		if IsNormalChatFrame(chatFrame) and type(lines) == "table" and #lines > 0 then
			chatFrame:Clear();
			for _, line in ipairs(lines) do
				chatFrame:AddMessage(
					line.text,
					line.r,
					line.g,
					line.b,
					line.chatTypeID,
					line.messageAccessID,
					line.lineID
				);
			end;
		end;
	end;
end;
