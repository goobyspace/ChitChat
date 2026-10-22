local _, core = ...;

local GetConfig = core.GetConfig;
local registered = false;
local wrappedChatFrames = setmetatable({}, { __mode = "k" });
local chatMessageMetadata = setmetatable({}, { __mode = "k" });
local pendingTimestamps = setmetatable({}, { __mode = "k" });
local timestampedAddMessage;

local function IsTimestamp(value)
	return type(value) == "number" and value > 0;
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

local function WrapAddMessage(addMessage)
	return function(chatFrame, message, ...)
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
			message = rawMessage;
			if GetConfig(chatFrame, "chitChatShowTimestamps") and IsTimestamp(timestamp) then
				local gap = GetConfig(chatFrame, "chitChatTimestampGap") and " " or "";
				message = GetTimestampText(timestamp, chatFrame) .. gap .. message;
			end;
		end;
		SeedChatMessageMetadata(chatFrame);
		local result = addMessage(chatFrame, message, ...);

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
		return result;
	end;
end;

local function AttachTimestampToChatFrame(chatFrame)
	if not chatFrame or wrappedChatFrames[chatFrame] then
		return;
	end;

	local addMessage = chatFrame.AddMessage;
	if type(addMessage) ~= "function" then
		error("ChitChat: chat frame AddMessage is unavailable.");
	end;
	SeedChatMessageMetadata(chatFrame);
	if addMessage == timestampedAddMessage then
		wrappedChatFrames[chatFrame] = true;
		return;
	end;
	chatFrame.AddMessage = WrapAddMessage(addMessage);
	wrappedChatFrames[chatFrame] = true;
end;

function core:RefreshChatTimestamps()
	for index = 1, core.GetChatWindowCount() do
		local chatFrame = _G["ChatFrame" .. index];
		if chatFrame and chatFrame.GetNumMessages and chatFrame.GetMessageInfo then
			SeedChatMessageMetadata(chatFrame);
			local messages = {};
			local hasSecretValues = false;
			for messageIndex = 1, chatFrame:GetNumMessages() do
				local text, r, g, b, chatTypeID, messageAccessID, lineID =
					chatFrame:GetMessageInfo(messageIndex);
				local timestamp, originalText = core:GetChatMessageTimestamp(chatFrame, messageIndex);
				messages[#messages + 1] = {
					text = text,
					timestamp = timestamp,
					r = r,
					g = g,
					b = b,
					chatTypeID = chatTypeID,
					messageAccessID = messageAccessID,
					lineID = lineID,
				};
				local message = messages[#messages];
				for _, value in pairs(message) do
					if issecretvalue and issecretvalue(value) then
						hasSecretValues = true;
						break;
					end;
				end;
				if hasSecretValues then
					break;
				end;
				if type(originalText) == "string" and not (issecretvalue and issecretvalue(originalText)) then
					message.text = originalText;
				end;
			end;

			if not hasSecretValues then
				local scrollOffset = chatFrame.GetScrollOffset and chatFrame:GetScrollOffset();
				chatFrame:Clear();
				self:ResetChatMessageMetadata(chatFrame);
				for _, message in ipairs(messages) do
					self:SetNextChatMessageTimestamp(chatFrame, message.timestamp);
					chatFrame:AddMessage(
						message.text,
						message.r,
						message.g,
						message.b,
						message.chatTypeID,
						message.messageAccessID,
						message.lineID
					);
				end;
				if scrollOffset and chatFrame.SetScrollOffset then
					chatFrame:SetScrollOffset(scrollOffset);
				end;
			end;
		end;
	end;
end;

function core:InitializeTimestamps(chatFrame)
	if not registered then
		if type(ChatFrameMixin) ~= "table" or type(ChatFrameMixin.AddMessage) ~= "function" then
			error("ChitChat: ChatFrameMixin.AddMessage is unavailable.");
		end;
		timestampedAddMessage = WrapAddMessage(ChatFrameMixin.AddMessage);
		ChatFrameMixin.AddMessage = timestampedAddMessage;
		registered = true;
	end;
	AttachTimestampToChatFrame(chatFrame);
end;
