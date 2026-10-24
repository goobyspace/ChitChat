local _, core = ...;

local CreateChatMenuControlButton = core.CreateChatMenuControlButton;
local HideDefaultScrollBar = core.HideDefaultScrollBar;

function core.GetSocialControlButton()
	return _G["FriendsMicroButton"], SOCIAL_LABEL or "Social";
end;

function core.HideDefaultScrollBar(chatFrame)
	HideDefaultScrollBar(chatFrame);
	local row = chatFrame.buttonFrame;
	if row then
		core.HideOriginalControl(row.upButton);
		core.HideOriginalControl(row.downButton);
		core.HideOriginalControl(row.bottomButton);
	end;
end;

function core.CreateChatMenuControlButton(row, menuButton)
	if menuButton.intrinsic ~= "DropdownButton" then
		return CreateChatMenuControlButton(row, menuButton);
	end;
	local button = core.CreateControlButton(
		row,
		"ChitChatChatTypeButton",
		"Interface\\AddOns\\ChitChat\\Assets\\chattype.png",
		CHAT_MENU or "Chat Type",
		nil,
		"DropdownButton"
	);
	button:SetupMenu(function(_, rootDescription)
		menuButton.menuGenerator(menuButton, rootDescription);
	end);
	return button;
end;

function core.GetLastStaticDockTab(dock)
	local lastStaticTab = _G["ChatFrame1Tab"];
	for _, chatFrame in ipairs(dock.DOCKED_CHAT_FRAMES or {}) do
		local tab = _G[chatFrame:GetName() .. "Tab"];
		-- static flags can change before blizzard moves the tabs out of the scroll child
		if chatFrame.isStaticDocked and tab and tab:GetParent() == dock then
			lastStaticTab = tab;
		end;
	end;
	return lastStaticTab;
end;
