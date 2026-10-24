local _, core = ...;

local windowMixins = {
	"Eavesdropper_FrameMixin",
	"Eavesdropper_Mentions_FrameMixin",
	"Eavesdropper_Dedicated_FrameMixin",
	"Eavesdropper_Group_FrameMixin",
};

local function SkinWindow(window)
	if not window.ChatBox or not window.Background then
		return;
	end;
	if core:InitializeWidgetChatFrame(window.ChatBox, window) then
		window.Background:Hide();
	end;
end;

EventUtil.ContinueOnAddOnLoaded("Eavesdropper", function()
	-- stays nil until our settings initialize, which counts as enabled
	if core.GetConfig(nil, "widgetEavesdropper") == false then
		return;
	end;
	-- windows copy their methods off these tables when they are created, so hooking here catches every one
	for _, mixinName in ipairs(windowMixins) do
		local mixin = _G[mixinName];
		if mixin and mixin.OnLoad then
			hooksecurefunc(mixin, "OnLoad", SkinWindow);
		end;
	end;
end);
