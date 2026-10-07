local _, core = ...;

function core:InitEventHandler(event, name)
    if event == "ADDON_LOADED" then
        if name ~= "ChitChat" then return; end;
        if ChitChatGlobalStorage == nil then ChitChatGlobalStorage = {}; end;
        return;
    end;

    if event == "PLAYER_LOGOUT" then
        core:SaveChatHistory();
        return;
    end;

    if event == "PLAYER_LOGIN" then
        core:RestoreChatHistory();
        core:InitializeChitChat();
    end;
end;

local events = CreateFrame("Frame", "ChitChatInitEventFrame");
events:RegisterEvent("ADDON_LOADED");
events:RegisterEvent("PLAYER_LOGIN");
events:RegisterEvent("PLAYER_LOGOUT");
events:SetScript("OnEvent", core.InitEventHandler);
