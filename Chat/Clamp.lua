---@diagnostic disable

local _, core = ...;

function core.ClampChatFrameToScreen(chatFrame)
	if not chatFrame then
		return;
	end;
	if chatFrame.UpdateClampOffsets and not chatFrame.ChitChatClampHooked then
		hooksecurefunc(chatFrame, "UpdateClampOffsets", function()
			chatFrame:SetClampRectInsets(0, 0, 0, 0);
		end);
		chatFrame.ChitChatClampHooked = true;
	end;
	chatFrame:SetClampRectInsets(0, 0, 0, 0);
	chatFrame:SetClampedToScreen(true);
end;

core.ClampChatFrameToScreen(_G["ChatFrame1"]);

local clampLoader = CreateFrame("Frame");
clampLoader:RegisterEvent("ADDON_LOADED");
clampLoader:RegisterEvent("PLAYER_ENTERING_WORLD");
clampLoader:SetScript("OnEvent", function(_, event, addonName)
	if event == "PLAYER_ENTERING_WORLD" or addonName == "Blizzard_EditMode" then
		core.ClampChatFrameToScreen(_G["ChatFrame1"]);
	end;
end);
