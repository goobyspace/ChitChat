local _, core = ...;

ChitChatGlobalStorage = ChitChatGlobalStorage or {};

local function GetChatFrameId(chatFrame)
	if type(chatFrame) == "table" and chatFrame.GetID then
		return chatFrame:GetID();
	end;
	return chatFrame;
end;

-- TODO: actually change settings per frame
-- needs a bunch more work than just getting the config but this will make it easier
function core.GetConfig(chatFrame, key)
	if chatFrame and ChitChatGlobalStorage.perTabSettings then
		local overrides = ChitChatGlobalStorage.tabOverrides;
		local id = GetChatFrameId(chatFrame);
		local frameOverrides = overrides and id and overrides[id];
		local value = frameOverrides and frameOverrides[key];
		if value ~= nil then
			return value;
		end;
	end;
	return ChitChatGlobalStorage[key];
end;

function core.GetGradientSettings(chatFrame, prefix)
	return {
		colour = core.GetConfig(chatFrame, prefix .. "Colour"),
		mainColourRatio = core.GetConfig(chatFrame, prefix .. "GradientMainColourRatio"),
		oneSidedGradient = core.GetConfig(chatFrame, prefix .. "GradientOneSided"),
		mainColourSide = core.GetConfig(chatFrame, prefix .. "GradientMainColourSideStringifiedValue"),
		edgeOpacity = core.GetConfig(chatFrame, prefix .. "GradientEdgeOpacity"),
		useGradient = core.GetConfig(chatFrame, prefix .. "UseGradient"),
	};
end;

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
						return core.GetConfig(nil, "historyEnabled");
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
					default = false,
				},
				{
					name = "chitChatTimestampGap",
					reload = false,
					dependsOn = "chitChatShowTimestamps",
					enabledWhen = function()
						return core.GetConfig(nil, "chitChatShowTimestamps");
					end,
					title = "Timestamp gap",
					description = "Add a space between the timestamp and the message.",
					default = false,
				},
				{
					name = "chitChatTimestamp24Hour",
					reload = false,
					dependsOn = "chitChatShowTimestamps",
					enabledWhen = function()
						return core.GetConfig(nil, "chitChatShowTimestamps");
					end,
					title = "24 Hour mode",
					description = "Enables 24 Hour mode",
					default = GetCVarBool("timeMgrUseMilitaryTime"),
				},
				{
					name = "chitChatTimestampLocalTime",
					reload = false,
					dependsOn = "chitChatShowTimestamps",
					enabledWhen = function()
						return core.GetConfig(nil, "chitChatShowTimestamps");
					end,
					title = "Use Local Time",
					description =
					"Use the your local time instead of the server time.",
					default = GetCVarBool("timeMgrUseLocalTime"),
				},
				{
					name = "chitChatTimestampColor",
					reload = false,
					dependsOn = "chitChatShowTimestamps",
					enabledWhen = function()
						return core.GetConfig(nil, "chitChatShowTimestamps");
					end,
					title = "Timestamp colour",
					description = "Set the colour of the timestamp.",
					default = { r = 0.5, g = 0.5, b = 0.5, a = 1 },
				},
			},
		},
		{
			name = "Control/input fade animation",
			settings = {
				{
					name = "fadeDuration",
					reload = false,
					title = "Fade duration",
					description =
					"How long it takes to fade controls & inputs after moving your cursor. Messages use a seperate setting.",
					default = 0.15,
					min = 0.05,
					max = 5,
					step = 0.05,
					onChange = function()
						core.SettingsExample:RestartFadingMessage();
					end,
				},
			},
		},
		{
			name = "Widgets",
			settings = {
				{
					name = "widgetEavesdropper",
					title = "Eavesdropper windows",
					description =
					"Reskin the Eavesdropper addon's windows with ChitChat's message and window backgrounds. Does nothing if Eavesdropper isn't installed.",
					default = true,
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
			name = "Input",
			settings = {
				{
					name = "chatBoxTop",
					title = "Input on top",
					description = "Place the input on top.",
					default = true,
				},
				{
					name = "chatBoxMouseover",
					reload = false,
					title = "Show on mouseover",
					description = "Shows the input box when hovered",
					default = false,
				},
				{
					name = "chatBoxAboveTabs",
					dependsOn = { "chatBoxTop", "chatTabsAtBottom" },
					enabledWhen = function()
						return core.GetConfig(nil, "chatBoxTop") and not core.GetConfig(nil, "chatTabsAtBottom");
					end,
					title = "Input above tabs",
					description = "When the input is placed on top, place it above the tabs.",
					default = true,
				},
			},
		},
		{
			name = "Tabs",
			settings = {
				{
					name = "chatTabsAtBottom",
					title = "Chat tabs on the bottom",
					description = "Place the chat tabs on the bottom.",
					default = false,
				},
				{
					name = "tabHeight",
					title = "Height",
					description = "Chat tab height.",
					default = 20,
					min = function()
						local _, fontHeight = ChatFontNormal:GetFont();
						return math.ceil(fontHeight or 12) + 6;
					end,
					max = 60,
				},
				{
					name = "alwaysShowChatTabs",
					reload = false,
					title = "Always show",
					description = "Keep chat tabs fully visible instead of fading them when not hovered.",
					default = false,
				},
				{
					name = "chatTabsIdleAlpha",
					reload = false,
					dependsOn = "alwaysShowChatTabs",
					enabledWhen = function()
						return not core.GetConfig(nil, "alwaysShowChatTabs");
					end,
					title = "Base opacity",
					description = "Opacity of the chat tabs when not hovered.",
					default = 0,
					min = 0,
					max = 1,
					step = 0.05,
				},
				{
					name = "chatTabsHighlightUnread",
					reload = false,
					title = "Unread message highlight",
					description = "Highlight applied to tab when you have unread messages in that tab.",
					default = true,
				},
				{
					name = "chatTabsUnreadHighlightColour",
					reload = false,
					dependsOn = "chatTabsHighlightUnread",
					enabledWhen = function()
						return core.GetConfig(nil, "chatTabsHighlightUnread");
					end,
					title = "Highlight colour",
					description = "The colour of the highlight.",
					default = { r = 1, g = 1, b = 1, a = 0.2 },
				},
				{
					name = "chatTabsWhisperPulses",
					reload = false,
					title = "Whisper pulses",
					description =
					"Number of times a chat tab with a new whisper will pulse before stopping.",
					default = 7,
					min = 1,
					max = 7,
					options = {
						{ value = 1,  text = "1" },
						{ value = 2,  text = "2" },
						{ value = 4,  text = "4" },
						{ value = 8,  text = "8" },
						{ value = 16, text = "16" },
						{ value = 24, text = "24" },
						{ value = 32, text = "32" },
						{ value = 0,  text = "Continuous" },
					},
				},
				{
					name = "chatTabsWhisperPulseColour",
					reload = false,
					title = "Whisper pulse colour",
					description = "Set the colour of the chat tab whisper pulses",
					default = { r = 1, g = 0.72, b = 0.2, a = 0.5 },
				},
				{
					name = "chatTabsUnreadAsterisk",
					reload = false,
					title = "Unread asterisk*",
					description = "Show an asterisk after the chat tab name if it contains unread messages.",
					default = true,
				},
				{
					name = "chatTabsIgnoreCombatLogUnread",
					reload = false,
					dependsOn = { "chatTabsHighlightUnread", "chatTabsUnreadAsterisk" },
					enabledWhen = function()
						return core.GetConfig(nil, "chatTabsHighlightUnread")
							or core.GetConfig(nil, "chatTabsUnreadAsterisk");
					end,
					title = "Ignore unread combat log messages",
					description = "Stops the combat log from being marked as unread.",
					default = true,
				},
			},
		},
		{
			name = "Control button layout",
			settings = {
				{
					name = "controlSize",
					title = "Size",
					description = "Width/height of each control button.",
					default = 24,
					min = 12,
					max = 48,
				},
				{
					name = "controlSpacing",
					title = "Gap",
					description = "Gap between each button.",
					default = 0,
					min = 0,
					max = 20,
				},
				{
					name = "controls.vertical",
					key = "controlsVertical",
					title = "Vertical",
					description = "Make the control buttons vertical.",
					default = false,
				},
				{
					name = "controls.outside",
					key = "controlsOutside",
					title = "Outside",
					description = "Make the control buttons outside the frame",
					default = false,
				},
				{
					name = "controls.position",
					key = "controlsPosition",
					title = "Position",
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
				{
					name = "alwaysShowControls",
					reload = false,
					title = "Always show",
					description = "Keep the controls fully visible instead of fading them when not hovered.",
					default = false,
				},
				{
					name = "controlsIdleAlpha",
					reload = false,
					dependsOn = "alwaysShowControls",
					enabledWhen = function()
						return not core.GetConfig(nil, "alwaysShowControls");
					end,
					title = "Opacity",
					description = "Opacity of the controls when not hovered.",
					default = 0,
					min = 0,
					max = 1,
					step = 0.05,
				},
			},
		},
		{
			name = "Scrollbar",
			settings = {
				{
					name = "showScrollbar",
					title = "Show",
					description = "Show a white scrollbar for more gradual scrolling.",
					default = false,
				},
				{
					name = "scrollbarSide",
					dependsOn = "showScrollbar",
					enabledWhen = function()
						return core.GetConfig(nil, "showScrollbar");
					end,
					title = "Side",
					description = "Which side of the chat frame the scrollbar is on.",
					default = 2,
					min = 1,
					max = 2,
					options = {
						{ value = "LEFT",  text = "Left" },
						{ value = "RIGHT", text = "Right" },
					},
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
						return core.GetConfig(nil, "messageBackgroundUseGradient");
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
						return core.GetConfig(nil, "messageBackgroundUseGradient");
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
						return core.GetConfig(nil, "messageBackgroundUseGradient");
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
						return core.GetConfig(nil, "messageBackgroundUseGradient")
							and core.GetConfig(nil, "messageBackgroundGradientOneSided");
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
						return core.GetConfig(nil, "chatTabBackgroundUseGradient");
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
						return core.GetConfig(nil, "chatTabBackgroundUseGradient");
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
						return core.GetConfig(nil, "chatTabBackgroundUseGradient");
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
						return core.GetConfig(nil, "chatTabBackgroundUseGradient")
							and core.GetConfig(nil, "chatTabBackgroundGradientOneSided");
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
						return core.GetConfig(nil, "controlBackgroundUseGradient");
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
						return core.GetConfig(nil, "controlBackgroundUseGradient");
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
						return core.GetConfig(nil, "controlBackgroundUseGradient");
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
						return core.GetConfig(nil, "controlBackgroundUseGradient")
							and core.GetConfig(nil, "controlBackgroundGradientOneSided");
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
						return core.GetConfig(nil, "chatInputBackgroundUseGradient");
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
						return core.GetConfig(nil, "chatInputBackgroundUseGradient");
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
						return core.GetConfig(nil, "chatInputBackgroundUseGradient");
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
						return core.GetConfig(nil, "chatInputBackgroundUseGradient")
							and core.GetConfig(nil, "chatInputBackgroundGradientOneSided");
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
						return core.GetConfig(nil, "chatBackgroundUseGradient");
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
						return core.GetConfig(nil, "chatBackgroundUseGradient");
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
						return core.GetConfig(nil, "chatBackgroundUseGradient");
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
						return core.GetConfig(nil, "chatBackgroundUseGradient")
							and core.GetConfig(nil, "chatBackgroundGradientOneSided");
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
