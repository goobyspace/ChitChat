local _, core = ...;

local GetConfig = core.GetConfig;
local historyStorageKey = "chatHistoryByCharacter";
local historySavePending = false;
local historySaveScheduled = false;
local historySavingInitialized = false;

local function IsReadableText(text)
	return type(text) == "string" and not (issecretvalue and issecretvalue(text));
end;

local function IsHistoryEnabled(chatFrame)
	return GetConfig(chatFrame, "historyEnabled");
end;

local function IsHistoryEnabledForAnyFrame()
	for frameIndex = 1, core.GetChatWindowCount() do
		if IsHistoryEnabled(_G["ChatFrame" .. frameIndex]) then
			return true;
		end;
	end;
	return false;
end;

local function GetCharacterKey()
	local name, realm = UnitFullName("player");
	if type(name) ~= "string" or name == "" then
		name = UnitName("player");
	end;
	if type(realm) ~= "string" or realm == "" then
		realm = GetRealmName();
	end;
	if type(name) ~= "string" or name == "" or type(realm) ~= "string" or realm == "" then
		error("ChitChat: Unable to determine the current character.");
	end;

	return realm .. "-" .. name;
end;

local function GetCharacterHistories()
	local historiesByCharacter = ChitChatGlobalStorage and ChitChatGlobalStorage[historyStorageKey];
	if type(historiesByCharacter) ~= "table" then
		return nil;
	end;

	local histories = historiesByCharacter[GetCharacterKey()];
	if type(histories) == "table" then
		return histories;
	end;

	return nil;
end;

local function IsNormalChatFrame(chatFrame)
	if not chatFrame then
		return false;
	end;

	if type(IsCombatLog) == "function" then
		return not IsCombatLog(chatFrame);
	end;

	return chatFrame ~= _G["ChatFrame2"];
end;

local function GetSavedLineCount(chatFrame)
	local lineCount = GetConfig(chatFrame, "historyLines");
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
		if IsReadableText(text) then
			lines[#lines + 1] = { text = text };
		end;
	end;

	return lines;
end;

local function GetChatHistories()
	local histories = {};
	for frameIndex = 1, core.GetChatWindowCount() do
		local chatFrame = _G["ChatFrame" .. frameIndex];
		if IsNormalChatFrame(chatFrame) and IsHistoryEnabled(chatFrame) then
			local lineLimit = GetSavedLineCount(chatFrame);
			local lines = {};
			if chatFrame.GetNumMessages and chatFrame.GetMessageInfo then
				local messageCount = chatFrame:GetNumMessages();
				local firstMessageIndex = math.max(1, messageCount - lineLimit + 1);

				for messageIndex = firstMessageIndex, messageCount do
					local text, r, g, b, chatTypeID, messageAccessID, lineID =
						chatFrame:GetMessageInfo(messageIndex);
					if IsReadableText(text) then
						local timestamp, originalText = core:GetChatMessageTimestamp(chatFrame, messageIndex);
						local line = {
							text = IsReadableText(originalText) and originalText or text,
							r = r,
							g = g,
							b = b,
							chatTypeID = chatTypeID,
							messageAccessID = messageAccessID,
							lineID = lineID,
							timestamp = timestamp,
						};
						for key, value in pairs(line) do
							if issecretvalue and issecretvalue(value) then
								line[key] = nil;
							end;
						end;
						lines[#lines + 1] = line;
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

local function ScheduleChatHistorySave()
	if not IsHistoryEnabledForAnyFrame() then
		return;
	end;

	if InCombatLockdown() then
		historySavePending = true;
		return;
	end;
	if historySaveScheduled then
		return;
	end;

	historySaveScheduled = true;

	-- the save is delayed a frame to make sure blizz's chat has time to add the message in
	-- without it sometimes you'll race the blizz chat and win and there'll be no new message yet
	C_Timer.After(0, function()
		historySaveScheduled = false;
		if not IsHistoryEnabledForAnyFrame() then
			return;
		end;
		if InCombatLockdown() then
			historySavePending = true;
			return;
		end;

		core:SaveChatHistory();
		historySavePending = false;
	end);
end;

function core:InitializeChatHistorySaving()
	if historySavingInitialized then
		return;
	end;

	historySavingInitialized = true;

	local messageEvents = CreateFrame("Frame");
	local registered = {};
	local function RegisterMessageEvent(event)
		if not registered[event] then
			registered[event] = true;
			pcall(messageEvents.RegisterEvent, messageEvents, event);
		end;
	end;
	for _, group in pairs(ChatTypeGroup or {}) do
		for _, event in ipairs(group) do
			RegisterMessageEvent(event);
		end;
	end;
	for _, event in ipairs({ "CHAT_MSG_SAY", "CHAT_MSG_YELL", "CHAT_MSG_EMOTE", "CHAT_MSG_TEXT_EMOTE",
		"CHAT_MSG_WHISPER", "CHAT_MSG_WHISPER_INFORM", "CHAT_MSG_PARTY", "CHAT_MSG_PARTY_LEADER",
		"CHAT_MSG_RAID", "CHAT_MSG_RAID_LEADER", "CHAT_MSG_RAID_WARNING", "CHAT_MSG_GUILD",
		"CHAT_MSG_OFFICER", "CHAT_MSG_CHANNEL", "CHAT_MSG_SYSTEM", "CHAT_MSG_LOOT",
		"CHAT_MSG_INSTANCE_CHAT", "CHAT_MSG_INSTANCE_CHAT_LEADER" }) do
		RegisterMessageEvent(event);
	end;
	messageEvents:SetScript("OnEvent", function()
		ScheduleChatHistorySave();
	end);

	local combatEvents = CreateFrame("Frame");
	combatEvents:RegisterEvent("PLAYER_REGEN_ENABLED");
	combatEvents:SetScript("OnEvent", function()
		if historySavePending and IsHistoryEnabledForAnyFrame() then
			core:SaveChatHistory();
			historySavePending = false;
		end;
	end);
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
			if IsReadableText(text) then
				lines[#lines + 1] = core:GetChatMessageText(chatFrame, messageIndex, text);
			end;
		end;
	end;
	if #lines == 0 then
		for _, line in ipairs(GetVisibleLines(chatFrame, math.huge)) do
			lines[#lines + 1] = line.text;
		end;
	end;
	if #lines == 0 then
		local savedHistories = GetCharacterHistories();
		local frameIndex = chatFrame:GetID();
		local savedLines = type(savedHistories) == "table" and savedHistories[frameIndex];
		if type(savedLines) == "table" then
			for _, line in ipairs(savedLines) do
				if type(line) == "table" and IsReadableText(line.text) then
					lines[#lines + 1] = line.text;
				end;
			end;
		end;
	end;

	-- output line holding the newest message currently visible in the chat, so the copy frame can open there
	local focusLine;
	if #lines > 0 then
		local frameIndex = chatFrame:GetID();
		local tab = frameIndex and _G["ChatFrame" .. frameIndex .. "Tab"];
		local tabText = tab and (tab.Text or tab:GetFontString());
		local chatName = tabText and tabText:GetText();
		output[#output + 1] = IsReadableText(chatName) and chatName or ("Chat " .. (frameIndex or 1));

		local scrollOffset = chatFrame.GetScrollOffset and chatFrame:GetScrollOffset() or 0;
		local focusMessage = math.max(#lines - scrollOffset, 1);
		local lineNumber = 1;
		for lineIndex, line in ipairs(lines) do
			output[#output + 1] = line;
			-- messages containing newlines get split over several lines in the copy frame
			lineNumber = lineNumber + 1 + select(2, line:gsub("\n", ""));
			if lineIndex == focusMessage then
				focusLine = lineNumber;
			end;
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
		if focusLine then
			focusLine = focusLine - (firstLine - 1);
			if focusLine < 1 then
				focusLine = nil;
			end;
		end;
	end;

	return table.concat(output, "\n"), focusLine;
end;

core.HISTORY_BUTTON_TOOLTIP = "Copy chat history";

function core.CreateHistoryControlButton(parent)
	local button = CreateFrame("Button", "ChitChatCopyHistoryButton", parent);
	button:SetScript("OnClick", function()
		if InCombatLockdown() then
			return;
		end;

		local text, focusLine = core:GetChatHistoryText();
		core:ShowCopyFrame(text, "ChitChat chat history - drag to select and copy", focusLine);
	end);
	button:SetScript("OnEnter", function(hoveredButton)
		GameTooltip:SetOwner(hoveredButton, "ANCHOR_RIGHT");
		GameTooltip:SetText(InCombatLockdown() and "Combat lockdown" or core.HISTORY_BUTTON_TOOLTIP, 1, 1, 1);
		GameTooltip:Show();
	end);
	button:SetScript("OnLeave", function()
		GameTooltip:Hide();
	end);
	button.ChitChatBackground = core.ApplyControlButtonIcon(
		button,
		"Interface\\AddOns\\ChitChat\\Assets\\copypaste.png",
		core.GetGradientSettings(_G["ChatFrame1"], "controlBackground")
	);
	return button;
end;

function core:SaveChatHistory()
	if not IsHistoryEnabledForAnyFrame() then
		return;
	end;

	local historiesByCharacter = ChitChatGlobalStorage[historyStorageKey];
	if type(historiesByCharacter) ~= "table" then
		historiesByCharacter = {};
		ChitChatGlobalStorage[historyStorageKey] = historiesByCharacter;
	end;
	historiesByCharacter[GetCharacterKey()] = GetChatHistories();
end;

function core:RestoreChatHistory()
	if not IsHistoryEnabledForAnyFrame() then
		return;
	end;

	local historiesByCharacter = ChitChatGlobalStorage and ChitChatGlobalStorage[historyStorageKey];
	if type(historiesByCharacter) ~= "table" then
		historiesByCharacter = {};
		ChitChatGlobalStorage[historyStorageKey] = historiesByCharacter;
	end;

	local characterKey = GetCharacterKey();
	local histories = historiesByCharacter[characterKey];
	if type(histories) ~= "table" then
		return;
	end;

	for frameIndex = 1, core.GetChatWindowCount() do
		local chatFrame = _G["ChatFrame" .. frameIndex];
		local lines = histories[frameIndex];
		if IsNormalChatFrame(chatFrame) and IsHistoryEnabled(chatFrame) and type(lines) == "table" and #lines > 0 then
			chatFrame:Clear();
			core:ResetChatMessageMetadata(chatFrame);
			for _, line in ipairs(lines) do
				core:SetNextChatMessageTimestamp(chatFrame, line.timestamp);
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
