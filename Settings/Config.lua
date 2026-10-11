local _, core = ...;

ChitChatGlobalStorage = ChitChatGlobalStorage or {};

local timestampSettingKeys = {
	{ "showTimestamps",     "chitChatShowTimestamps" },
	{ "timestamp24Hour",    "chitChatTimestamp24Hour" },
	{ "timestampLocalTime", "chitChatTimestampLocalTime" },
};

for _, keys in ipairs(timestampSettingKeys) do
	local oldKey, newKey = keys[1], keys[2];
	if ChitChatGlobalStorage[newKey] == nil and ChitChatGlobalStorage[oldKey] ~= nil then
		ChitChatGlobalStorage[newKey] = ChitChatGlobalStorage[oldKey];
	end;
end;

local function GetClockSetting(cvar)
	return GetCVarBool(cvar);
end;

core.config = setmetatable({}, {
	__index = function(_, key)
		return ChitChatGlobalStorage[key];
	end,
	__newindex = function(_, key, value)
		ChitChatGlobalStorage[key] = value;
	end,
});

core.Settings = {
	{
		{
			name = "Chat history",
			settings = {
				{
					name = "historyEnabled",
					reload = false,
					title = "Save chat history",
					description =
					"Saves chat history as messages arrive and shows it again when you log back in.",
					default = true,
				},
				{
					name = "historyLines",
					reload = false,
					dependsOn = "historyEnabled",
					enabledWhen = function()
						return core.config.historyEnabled;
					end,
					title = "Saved message count",
					description = "Maximum number of messages saved per chat window.",
					default = 100,
					min = 0,
					max = 5000,
					step = 50,
				},
			},
		},
		{
			name = "Timestamps",
			settings = {
				{
					name = "chitChatShowTimestamps",
					reload = false,
					title = "Show timestamps",
					description = "Show a timestamp before each message.",
					default = true,
				},
				{
					name = "chitChatTimestampGap",
					dependsOn = "chitChatShowTimestamps",
					enabledWhen = function()
						return core.config.chitChatShowTimestamps;
					end,
					title = "Timestamp gap",
					description = "Add a space between the timestamp and the message.",
					default = false,
				},
				{
					name = "chitChatTimestamp24Hour",
					dependsOn = "chitChatShowTimestamps",
					enabledWhen = function()
						return core.config.chitChatShowTimestamps;
					end,
					title = "24 Hour mode",
					description = "Enables 24 Hour mode",
					default = GetClockSetting("timeMgrUseMilitaryTime"),
				},
				{
					name = "chitChatTimestampLocalTime",
					dependsOn = "chitChatShowTimestamps",
					enabledWhen = function()
						return core.config.chitChatShowTimestamps;
					end,
					title = "Use Local Time",
					description =
					"Use the your local time instead of the server time.",
					default = GetClockSetting("timeMgrUseLocalTime"),
				},
				{
					name = "chitChatTimestampColor",
					dependsOn = "chitChatShowTimestamps",
					enabledWhen = function()
						return core.config.chitChatShowTimestamps;
					end,
					title = "Timestamp colour",
					description = "Set the colour of the timestamp.",
					default = { r = 0.5, g = 0.5, b = 0.5, a = 1 },
				},
			},
		},
		{
			name = "Fade animation",
			settings = {
				{
					name = "fadeDuration",
					reload = false,
					title = "Fade duration",
					description =
					"How long it takes to fade controls & inputs after moving your cursor. Messages use a seperate setting.",
					default = 0.45,
					min = 0.05,
					max = 5,
					step = 0.05,
					onChange = function()
						core.SettingsExample:RestartFadingMessage();
					end,
				},
			},
		},
	},
	Messages = {
		{
			name = "Timing and animation",
			settings = {
				{
					name = "messageTimeVisible",
					reload = false,
					title = "Visible time",
					description = "How long a message stays visible until it starts fading.",
					default = 30,
					min = 1,
					max = 300,
					onChange = function()
						core.SettingsExample:RestartFadingMessage();
					end,
				},
				{
					name = "messageFadeDuration",
					reload = false,
					title = "Fade duration",
					description = "Time it takes from start of fade until the message is fully faded.",
					default = 2,
					min = 0,
					max = 30,
					step = 0.1,
					onChange = function()
						core.SettingsExample:RestartFadingMessage();
					end,
				},
				{
					name = "slideDistance",
					reload = false,
					title = "Slide distance",
					description = "How far down a new message slides in from.",
					default = 12,
					min = 0,
					max = 100,
					onChange = function()
						core.SettingsExample:RestartFadingMessage();
					end,
				},
				{
					name = "slideDuration",
					reload = false,
					title = "Slide duration",
					description = "Time it takes a new message to slide in.",
					default = 0.2,
					min = 0.05,
					max = 2,
					step = 0.05,
					onChange = function()
						core.SettingsExample:RestartFadingMessage();
					end,
				},
				{
					name = "recentMessageWindow",
					reload = false,
					title = "Animation grouping time",
					description =
					"Time from first message for how many messages after get grouped into the same animation, so that a quick burst of messages just add on to the animation instead of starting a new one.",
					default = 0.3,
					min = 0,
					max = 5,
					step = 0.05,
					onChange = function()
						core.SettingsExample:RestartFadingMessage();
					end,
				},
			},
		},
		{
			name = "Padding",
			settings = {
				{
					name = "messagePadding.horizontal",
					key = "messagePaddingHorizontal",
					title = "Horizontal padding",
					description = "Padding to the left/right of the message. Includes background.",
					default = 12,
					min = 0,
					max = 100,
				},
				{
					name = "messagePadding.vertical",
					key = "messagePaddingVertical",
					title = "Vertical padding",
					description = "Padding to the top/bottom of the message. Includes background.",
					default = 6,
					min = 0,
					max = 100,
				},
			},
		},
		{
			name = "Margins",
			settings = {
				{
					name = "messageMargins.horizontal",
					key = "messageMarginsHorizontal",
					title = "Horizontal margin",
					description = "Margins to the left/right of the message. Doesn't include background.",
					default = 0,
					min = 0,
					max = 100,
				},
				{
					name = "messageMargins.vertical",
					key = "messageMarginsVertical",
					title = "Vertical margin",
					description = "Margins to the top/bottom of the message. Doesn't include background.",
					default = 2,
					min = 0,
					max = 100,
				},
			},
		},
	},
	Layout = {
		{
			name = "Input and tabs",
			settings = {
				{
					name = "chatBoxTop",
					title = "Input on top",
					description = "Place the input on top.",
					default = false,
				},
				{
					name = "chatBoxMouseover",
					reload = false,
					title = "Input on mouseover",
					description = "Shows the input box when hovered",
					default = false,
				},
				{
					name = "chatTabsAtBottom",
					title = "Chat tabs on the bottom",
					description = "Place the chat tabs on the bottom.",
					default = false,
				},
				{
					name = "chatBoxAboveTabs",
					dependsOn = { "chatBoxTop", "chatTabsAtBottom" },
					enabledWhen = function()
						return core.config.chatBoxTop and not core.config.chatTabsAtBottom;
					end,
					title = "Input above tabs",
					description = "When the input is placed on top, place it above the tabs.",
					default = true,
				},
				{
					name = "tabHeight",
					title = "Chat tab height",
					description = "Chat tab height.",
					default = 20,
					min = function()
						local _, fontHeight = ChatFontNormal:GetFont();
						return math.ceil(fontHeight or 12) + 6;
					end,
					max = 60,
				},
			},
		},
		{
			name = "Control button layout",
			settings = {
				{
					name = "controlSize",
					title = "Button size",
					description = "Width/height of each control button.",
					default = 24,
					min = 12,
					max = 48,
				},
				{
					name = "controlSpacing",
					title = "Button gap",
					description = "Gap between each button.",
					default = 0,
					min = 0,
					max = 20,
				},
				{
					name = "controls.vertical",
					key = "controlsVertical",
					title = "Vertical control buttons",
					description = "Make the control buttons vertical.",
					default = false,
				},
				{
					name = "controls.outside",
					key = "controlsOutside",
					title = "Control buttons outside",
					description = "Make the control buttons outside the frame",
					default = false,
				},
				{
					name = "controls.position",
					key = "controlsPosition",
					title = "Control buttons position",
					description =
					"Position of the control buttons.",
					default = 1,
					min = 1,
					max = 4,
					options = {
						{ value = "TOPLEFT",     text = "Top left" },
						{ value = "TOPRIGHT",    text = "Top right" },
						{ value = "BOTTOMRIGHT", text = "Bottom right" },
						{ value = "BOTTOMLEFT",  text = "Bottom left" },
					},
				},
			},
		},
		{
			name = "Controls and tabs",
			settings = {
				{
					name = "alwaysShowControlsAndTabs",
					reload = false,
					title = "Always show the controls/chat tabs",
					description =
					"Keep the chat controls and tabs fully visible instead of fading them when not hovered.",
					default = false,
				},
				{
					name = "idleAlpha",
					reload = false,
					dependsOn = "alwaysShowControlsAndTabs",
					enabledWhen = function()
						return not core.config.alwaysShowControlsAndTabs;
					end,
					title = "Base controls/chat tabs opacity",
					description = "Opacity of the controls/chat tabs when not hovered.",
					default = 0,
					min = 0,
					max = 1,
					step = 0.05,
				},
			},
		},
		{
			name = "Chat frame padding",
			settings = {
				{
					name = "padding.left",
					key = "paddingLeft",
					title = "Frame left padding",
					description = "Left padding applied to the chat frame as a whole.",
					default = 0,
					min = 0,
					max = 200,
				},
				{
					name = "padding.right",
					key = "paddingRight",
					title = "Frame right padding",
					description = "Right padding applied to the chat frame as a whole.",
					default = 0,
					min = 0,
					max = 200,
				},
				{
					name = "padding.top",
					key = "paddingTop",
					title = "Frame top padding",
					description = "Top padding applied to the chat frame as a whole.",
					default = 0,
					min = 0,
					max = 200,
				},
				{
					name = "padding.bottom",
					key = "paddingBottom",
					title = "Frame bottom padding",
					description = "Bottom padding applied to the chat frame as a whole.",
					default = 0,
					min = 0,
					max = 200,
				},
			},
		},
	},
	Gradients = {
		{
			name = "Message",
			settings = {

				{
					name = "backgrounds.message.colour",
					key = "messageBackgroundColour",
					title = "Background colour",
					description = "Set the message background colour and opacity.",
					default = { r = 0, g = 0, b = 0, a = 0.9 },
				},
				{
					name = "backgrounds.message.useGradient",
					key = "messageBackgroundUseGradient",
					title = "Gradient background",
					description = "Use a gradient for message backgrounds, static colour if false.",
					default = true,
				},
				{
					name = "backgrounds.message.gradientEdgeOpacity",
					key = "messageBackgroundGradientEdgeOpacity",
					dependsOn = "messageBackgroundUseGradient",
					enabledWhen = function()
						return core.config.messageBackgroundUseGradient;
					end,
					title = "Gradient edge opacity",
					description = "The opacity of the outer edge of the gradient.",
					default = 0,
					min = 0,
					max = 1,
					step = 0.05,
				},
				{
					name = "backgrounds.message.gradientMainColourRatio",
					key = "messageBackgroundGradientMainColourRatio",
					dependsOn = "messageBackgroundUseGradient",
					enabledWhen = function()
						return core.config.messageBackgroundUseGradient;
					end,
					title = "Gradient colour ratio",
					description = "The amount of width taken up by the colour before the gradient starts.",
					default = 0,
					min = 0,
					max = 1,
					step = 0.05,
				},
				{
					name = "backgrounds.message.gradientOneSided",
					key = "messageBackgroundGradientOneSided",
					dependsOn = "messageBackgroundUseGradient",
					enabledWhen = function()
						return core.config.messageBackgroundUseGradient;
					end,
					title = "One-sided gradient",
					description = "Makes the gradient go from one side, instead of being both directions.",
					default = true,
				},
				{
					name = "backgrounds.message.gradientMainColourSide",
					key = "messageBackgroundGradientMainColourSide",
					dependsOn = { "messageBackgroundUseGradient", "messageBackgroundGradientOneSided" },
					enabledWhen = function()
						return core.config.messageBackgroundUseGradient and core.config
							.messageBackgroundGradientOneSided;
					end,
					title = "Gradient direction",
					description = "Makes gradient go left or right, depending on if one-sided gradient is selected.",
					default = 1,
					min = 1,
					max = 2,
					options = {
						{ value = "left",  text = "Left" },
						{ value = "right", text = "Right" },
					},
				},
			},
		},
		{
			name = "Chat tab",
			settings = {
				{
					name = "backgrounds.chatTab.colour",
					key = "chatTabBackgroundColour",
					title = "Background colour",
					description = "Set the chat tab background colour and opacity.",
					default = { r = 0, g = 0, b = 0, a = 1 },
				},
				{
					name = "backgrounds.chatTab.useGradient",
					key = "chatTabBackgroundUseGradient",
					title = "Gradient background",
					description = "Use a gradient for the chat tab background, static colour if false.",
					default = true,
				},
				{
					name = "backgrounds.chatTab.gradientEdgeOpacity",
					key = "chatTabBackgroundGradientEdgeOpacity",
					dependsOn = "chatTabBackgroundUseGradient",
					enabledWhen = function()
						return core.config.chatTabBackgroundUseGradient;
					end,
					title = "Gradient edge opacity",
					description = "The opacity of the outer edge of the gradient.",
					default = 0.5,
					min = 0,
					max = 1,
					step = 0.05,
				},
				{
					name = "backgrounds.chatTab.gradientMainColourRatio",
					key = "chatTabBackgroundGradientMainColourRatio",
					dependsOn = "chatTabBackgroundUseGradient",
					enabledWhen = function()
						return core.config.chatTabBackgroundUseGradient;
					end,
					title = "Gradient colour ratio",
					description = "The amount of width taken up by the colour before the gradient starts.",
					default = 0,
					min = 0,
					max = 1,
					step = 0.05,
				},
				{
					name = "backgrounds.chatTab.gradientOneSided",
					key = "chatTabBackgroundGradientOneSided",
					dependsOn = "chatTabBackgroundUseGradient",
					enabledWhen = function()
						return core.config.chatTabBackgroundUseGradient;
					end,
					title = "One-sided gradient",
					description = "Makes the gradient go from one side, instead of being both directions.",
					default = false,
				},
				{
					name = "backgrounds.chatTab.gradientMainColourSide",
					key = "chatTabBackgroundGradientMainColourSide",
					dependsOn = { "chatTabBackgroundUseGradient", "chatTabBackgroundGradientOneSided" },
					enabledWhen = function()
						return core.config.chatTabBackgroundUseGradient and core.config
							.chatTabBackgroundGradientOneSided;
					end,
					title = "Gradient direction",
					description = "Makes gradient go left or right, depending on if one-sided gradient is selected.",
					default = 1,
					min = 1,
					max = 2,
					options = {
						{ value = "left",  text = "Left" },
						{ value = "right", text = "Right" },
					},
				},
			},
		},
		{
			name = "Control button",
			settings = {
				{
					name = "backgrounds.control.colour",
					key = "controlBackgroundColour",
					title = "Background colour",
					description = "Set the control button background colour and opacity.",
					default = { r = 0, g = 0, b = 0, a = 1 },
				},
				{
					name = "backgrounds.control.useGradient",
					key = "controlBackgroundUseGradient",
					title = "Gradient background",
					description = "Use a gradient for the control button background, static colour if false.",
					default = false,
				},
				{
					name = "backgrounds.control.gradientEdgeOpacity",
					key = "controlBackgroundGradientEdgeOpacity",
					dependsOn = "controlBackgroundUseGradient",
					enabledWhen = function()
						return core.config.controlBackgroundUseGradient;
					end,
					title = "Gradient edge opacity",
					description = "The opacity of the outer edge of the gradient.",
					default = 0.5,
					min = 0,
					max = 1,
					step = 0.05,
				},
				{
					name = "backgrounds.control.gradientMainColourRatio",
					key = "controlBackgroundGradientMainColourRatio",
					dependsOn = "controlBackgroundUseGradient",
					enabledWhen = function()
						return core.config.controlBackgroundUseGradient;
					end,
					title = "Gradient colour ratio",
					description = "The amount of width taken up by the colour before the gradient starts.",
					default = 0,
					min = 0,
					max = 1,
					step = 0.05,
				},
				{
					name = "backgrounds.control.gradientOneSided",
					key = "controlBackgroundGradientOneSided",
					dependsOn = "controlBackgroundUseGradient",
					enabledWhen = function()
						return core.config.controlBackgroundUseGradient;
					end,
					title = "One-sided gradient",
					description = "Makes the gradient go from one side, instead of being both directions.",
					default = false,
				},
				{
					name = "backgrounds.control.gradientMainColourSide",
					key = "controlBackgroundGradientMainColourSide",
					dependsOn = { "controlBackgroundUseGradient", "controlBackgroundGradientOneSided" },
					enabledWhen = function()
						return core.config.controlBackgroundUseGradient and core.config
							.controlBackgroundGradientOneSided;
					end,
					title = "Gradient direction",
					description = "Makes gradient go left or right, depending on if one-sided gradient is selected.",
					default = 1,
					min = 1,
					max = 2,
					options = {
						{ value = "left",  text = "Left" },
						{ value = "right", text = "Right" },
					},
				},
			},
		},
		{
			name = "Chat input",
			settings = {
				{
					name = "backgrounds.chatInput.colour",
					key = "chatInputBackgroundColour",
					title = "Background colour",
					description = "Set the chat input background colour and opacity.",
					default = { r = 0, g = 0, b = 0, a = 1 },
				},
				{
					name = "backgrounds.chatInput.useGradient",
					key = "chatInputBackgroundUseGradient",
					title = "Gradient background",
					description = "Use a gradient for the chat input background, static colour if false.",
					default = true,
				},
				{
					name = "backgrounds.chatInput.gradientEdgeOpacity",
					key = "chatInputBackgroundGradientEdgeOpacity",
					dependsOn = "chatInputBackgroundUseGradient",
					enabledWhen = function()
						return core.config.chatInputBackgroundUseGradient;
					end,
					title = "Gradient edge opacity",
					description = "The opacity of the outer edge of the gradient.",
					default = 0.5,
					min = 0,
					max = 1,
					step = 0.05,
				},
				{
					name = "backgrounds.chatInput.gradientMainColourRatio",
					key = "chatInputBackgroundGradientMainColourRatio",
					dependsOn = "chatInputBackgroundUseGradient",
					enabledWhen = function()
						return core.config.chatInputBackgroundUseGradient;
					end,
					title = "Gradient colour ratio",
					description = "The amount of width taken up by the colour before the gradient starts.",
					default = 0,
					min = 0,
					max = 1,
					step = 0.05,
				},
				{
					name = "backgrounds.chatInput.gradientOneSided",
					key = "chatInputBackgroundGradientOneSided",
					dependsOn = "chatInputBackgroundUseGradient",
					enabledWhen = function()
						return core.config.chatInputBackgroundUseGradient;
					end,
					title = "One-sided gradient",
					description = "Makes the gradient go from one side, instead of being both directions.",
					default = true,
				},
				{
					name = "backgrounds.chatInput.gradientMainColourSide",
					key = "chatInputBackgroundGradientMainColourSide",
					dependsOn = { "chatInputBackgroundUseGradient", "chatInputBackgroundGradientOneSided" },
					enabledWhen = function()
						return core.config.chatInputBackgroundUseGradient and
							core.config.chatInputBackgroundGradientOneSided;
					end,
					title = "Gradient direction",
					description = "Makes gradient go left or right, depending on if one-sided gradient is selected.",
					default = 1,
					min = 1,
					max = 2,
					options = {
						{ value = "left",  text = "Left" },
						{ value = "right", text = "Right" },
					},
				},
			},
		},
		{
			name = "Chat window",
			settings = {
				{
					name = "backgrounds.chat.colour",
					key = "chatBackgroundColour",
					title = "Background colour",
					description = "Set the Chat window background colour and opacity.",
					default = { r = 0, g = 0, b = 0, a = 0 },
				},
				{
					name = "backgrounds.chat.useGradient",
					key = "chatBackgroundUseGradient",
					title = "Gradient background",
					description = "Use a gradient for the background Chat window, static colour if false.",
					default = false,
				},
				{
					name = "backgrounds.chat.gradientEdgeOpacity",
					key = "chatBackgroundGradientEdgeOpacity",
					dependsOn = "chatBackgroundUseGradient",
					enabledWhen = function()
						return core.config.chatBackgroundUseGradient;
					end,
					title = "Gradient edge opacity",
					description = "The opacity of the outer edge of the gradient.",
					default = 0.5,
					min = 0,
					max = 1,
					step = 0.05,
				},
				{
					name = "backgrounds.chat.gradientMainColourRatio",
					key = "chatBackgroundGradientMainColourRatio",
					dependsOn = "chatBackgroundUseGradient",
					enabledWhen = function()
						return core.config.chatBackgroundUseGradient;
					end,
					title = "Gradient colour ratio",
					description = "The amount of width taken up by the colour before the gradient starts.",
					default = 0,
					min = 0,
					max = 1,
					step = 0.05,
				},
				{
					name = "backgrounds.chat.gradientOneSided",
					key = "chatBackgroundGradientOneSided",
					dependsOn = "chatBackgroundUseGradient",
					enabledWhen = function()
						return core.config.chatBackgroundUseGradient;
					end,
					title = "One-sided gradient",
					description = "Makes the gradient go from one side, instead of being both directions.",
					default = false,
				},
				{
					name = "backgrounds.chat.gradientMainColourSide",
					key = "chatBackgroundGradientMainColourSide",
					dependsOn = { "chatBackgroundUseGradient", "chatBackgroundGradientOneSided" },
					enabledWhen = function()
						return core.config.chatBackgroundUseGradient and
							core.config.chatBackgroundGradientOneSided;
					end,
					title = "Gradient direction",
					description = "Makes gradient go left or right, depending on if one-sided gradient is selected.",
					default = 1,
					min = 1,
					max = 2,
					options = {
						{ value = "left",  text = "Left" },
						{ value = "right", text = "Right" },
					},
				},
			},
		},
	},
};
