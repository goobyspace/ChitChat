local _, core = ...;

local GetConfig = core.GetConfig;
local hookedChatFrames = setmetatable({}, { __mode = "k" });
local chatMessageMetadata = setmetatable({}, { __mode = "k" });
local pendingTimestamps = setmetatable({}, { __mode = "k" });

local function IsTimestamp(value)
	return not (issecretvalue and issecretvalue(value)) and type(value) == "number" and value > 0;
end;

local function GetTimestampText(timestamp, chatFrame)
	timestamp = timestamp or time();
	if not GetConfig(chatFrame, "chitChatTimestampLocalTime") then
		local serverHour, serverMinute = GetGameTime();
		local localHour = tonumber(date("%H"));
		local localMinute = tonumber(date("%M"));
		local minuteOffset = serverHour * 60 + serverMinute - localHour * 60 - localMinute;
		if minuteOffset > 720 then
			minuteOffset = minuteOffset - 1440;
		elseif minuteOffset < -720 then
			minuteOffset = minuteOffset + 1440;
		end;
		timestamp = timestamp + minuteOffset * 60;
	end;

	local format = GetConfig(chatFrame, "chitChatTimestamp24Hour") and "%H:%M" or "%I:%M %p";
	local color = GetConfig(chatFrame, "chitChatTimestampColor");
	if type(color) ~= "table"
		or type(color.r) ~= "number"
		or type(color.g) ~= "number"
		or type(color.b) ~= "number"
		or color.r < 0 or color.r > 1
		or color.g < 0 or color.g > 1
		or color.b < 0 or color.b > 1 then
		error("ChitChat: timestamp colour must have red, green, and blue values from 0 to 1.");
	end;
	local colorCode = string.format(
		"%02x%02x%02x",
		math.floor(color.r * 255 + 0.5),
		math.floor(color.g * 255 + 0.5),
		math.floor(color.b * 255 + 0.5)
	);
	return "|cff" .. colorCode .. "[" .. date(format, timestamp) .. "]|r";
end;

function core:GetTimestampText(timestamp, chatFrame)
	return GetTimestampText(timestamp, chatFrame);
end;

-- Removes timestamp prefixes this addon added (e.g. persisted in saved history).
local function StripTimestamp(text)
	if type(text) ~= "string" or (issecretvalue and issecretvalue(text)) then
		return text;
	end;
	return (text:gsub("|c%x%x%x%x%x%x%x%x%[%d%d?:%d%d[^%]|]*%]|r ?", ""));
end;

local function SeedChatMessageMetadata(chatFrame)
	if chatMessageMetadata[chatFrame] then
		return;
	end;

	local messages = {};
	if chatFrame.GetNumMessages and chatFrame.GetMessageInfo then
		for messageIndex = 1, chatFrame:GetNumMessages() do
			local message = chatFrame:GetMessageInfo(messageIndex);
			messages[#messages + 1] = {
				text = type(message) == "string" and not (issecretvalue and issecretvalue(message))
					and StripTimestamp(message) or nil,
			};
		end;
	end;
	chatMessageMetadata[chatFrame] = messages;
end;

function core:GetChatMessageTimestamp(chatFrame, messageIndex)
	local messages = chatMessageMetadata[chatFrame];
	local message = messages and messages[messageIndex];
	if message then
		return message.timestamp, message.text;
	end;
end;

function core:SetNextChatMessageTimestamp(chatFrame, timestamp)
	pendingTimestamps[chatFrame] = { timestamp = timestamp };
end;

function core:ResetChatMessageMetadata(chatFrame)
	chatMessageMetadata[chatFrame] = {};
	pendingTimestamps[chatFrame] = nil;
end;

function core:GetChatMessageText(chatFrame, messageIndex, text)
	if type(text) ~= "string" or (issecretvalue and issecretvalue(text)) then
		return text;
	end;
	local timestamp = self:GetChatMessageTimestamp(chatFrame, messageIndex);
	text = StripTimestamp(text);
	if GetConfig(chatFrame, "chitChatShowTimestamps") and IsTimestamp(timestamp) then
		local gap = GetConfig(chatFrame, "chitChatTimestampGap") and " " or "";
		return GetTimestampText(timestamp, chatFrame) .. gap .. text;
	end;
	return text;
end;

local function RecordMessage(chatFrame, message)
	local pending = pendingTimestamps[chatFrame];
	pendingTimestamps[chatFrame] = nil;
	local timestamp = time();
	if pending then
		timestamp = pending.timestamp;
	end;
	local recordableMessage = type(message) == "string"
		and not (issecretvalue and issecretvalue(message));
	local rawMessage;
	if recordableMessage then
		rawMessage = StripTimestamp(message);
	end;

	local messages = chatMessageMetadata[chatFrame];
	messages[#messages + 1] = {
		text = recordableMessage and rawMessage or nil,
		timestamp = recordableMessage and IsTimestamp(timestamp) and timestamp or nil,
	};
	local messageCount = chatFrame.GetNumMessages and chatFrame:GetNumMessages();
	if type(messageCount) == "number" then
		while #messages > messageCount do
			table.remove(messages, 1);
		end;
	end;
	-- replaying old messages shouldn't mark tabs unread
	if not pending then
		core:MarkChatTabUnread(chatFrame);
	end;
end;

local function RefreshVisibleTimestamps(chatFrame)
	local messageCount = chatFrame:GetNumMessages();
	local scrollOffset = chatFrame:GetScrollOffset();
	for lineIndex, line in ipairs(chatFrame.visibleLines) do
		local messageIndex = messageCount - scrollOffset - lineIndex + 1;
		if messageIndex > 0 then
			local text = chatFrame:GetMessageInfo(messageIndex);
			if type(text) == "string" and not (issecretvalue and issecretvalue(text)) then
				line:SetText(core:GetChatMessageText(chatFrame, messageIndex, text));
			end;
		end;
	end;
end;

function core:InitializeTimestamps(chatFrame)
	if not chatFrame or hookedChatFrames[chatFrame] then
		return;
	end;

	if type(chatFrame.AddMessage) ~= "function" then
		error("ChitChat: chat frame AddMessage is unavailable.");
	end;
	SeedChatMessageMetadata(chatFrame);
	-- replacing addmessage taints blizzard's caller and breaks the battleground join queue
	hooksecurefunc(chatFrame, "AddMessage", RecordMessage);
	chatFrame:AddOnDisplayRefreshedCallback(RefreshVisibleTimestamps);
	hookedChatFrames[chatFrame] = true;
	chatFrame:MarkDisplayDirty();
end;

function core:RefreshChatTimestamps()
	for index = 1, core.GetChatWindowCount() do
		local chatFrame = _G["ChatFrame" .. index];
		if chatFrame and hookedChatFrames[chatFrame] then
			chatFrame:MarkDisplayDirty();
		end;
	end;
end;
