local _, core = ...;

local events = CreateFrame("Frame", "ChitChatInitEventFrame");

function core:InitEventHandler(event, name)
    if event == "ADDON_LOADED" then
        if name ~= "ChitChat" then return; end;
        if ChitChatGlobalStorage == nil then
            ChitChatGlobalStorage = {};
        end;
        self.Settings:Initialize();
        self:InitializeChatHistorySaving();
        return;
    end;

    if event == "PLAYER_LOGOUT" then
        self:SaveChatHistory();
        return;
    end;

    -- this is because the chat frame isnt always finished by PLAYER_LOGIN & ADDON_LOADED
    if event == "PLAYER_ENTERING_WORLD" then
        self:InitializeReactiveChat();
        self:AttachNewChatFrames();
        self:InitializeChatTabs();
        self:InitializeControls(_G["ChatFrame1"]);
        events:UnregisterEvent("PLAYER_ENTERING_WORLD");
        return;
    end;

    if event == "PLAYER_LOGIN" then
        self:InitializeReactiveChat();
        self:AttachNewChatFrames();
        self:InitializeChatTabs();
        self:InitializeChatHistorySaving();
        if not self.chatHistoryRestored then
            self:RestoreChatHistory();
            self.chatHistoryRestored = true;
        end;
    end;
end;

events:RegisterEvent("ADDON_LOADED");
events:RegisterEvent("PLAYER_LOGIN");
events:RegisterEvent("PLAYER_LOGOUT");
events:RegisterEvent("PLAYER_ENTERING_WORLD");
events:SetScript("OnEvent", function(_, event, ...)
    core:InitEventHandler(event, ...);
end);
