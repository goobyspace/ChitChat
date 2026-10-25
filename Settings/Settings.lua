local _, core = ...;

local localCategory = "";
local reloadButtonAdded = false;
local closeBarReloadButton;
local SUBCATEGORY_NAMES = {
    "Messages",
    "Layout",
    "Gradients",
};

local function AddReloadButton()
    if reloadButtonAdded then return; end;
    reloadButtonAdded = true;
    if closeBarReloadButton then
        closeBarReloadButton:Show();
    end;
    local reloadButton = CreateSettingsButtonInitializer(
        "Your settings have changed",
        "Reload",
        function()
            C_UI.Reload();
        end,
        "Please reload your UI to have your changed settings take effect.",
        true
    );

    local addonLayout = SettingsPanel:GetLayout(localCategory);
    addonLayout:AddInitializer(reloadButton);
end;

local function GetSettingType(setting)
    if setting.type then return setting.type; end;
    if type(setting.default) == "table" then return "color"; end;
    if setting.min ~= nil and setting.max ~= nil then return "slider"; end;
    return "checkbox";
end;

local function SaveStringifiedValue(setting)
    local key = setting.key or setting.name;
    local option = setting.options[ChitChatGlobalStorage[key]];
    if not option then
        ChitChatGlobalStorage[key] = 0;
        option = setting.options[1];
    end;
    ChitChatGlobalStorage[key .. "StringifiedValue"] = option.value;
end;

local function CreateChangedCallback(setting)
    return function(deferOnChange)
        if setting.options then
            SaveStringifiedValue(setting);
        end;
        core.SettingsExample:Update(setting);
        if setting.onChange and not deferOnChange then
            setting.onChange(setting);
        end;
        if core.QueueChatRefresh then
            core.QueueChatRefresh();
        end;
        if setting.reload ~= false then
            AddReloadButton();
            return;
        end;
        if core.RefreshChatFrameTimings then
            core:RefreshChatFrameTimings();
        end;
    end;
end;

local function CreateCloseBarReloadButton()
    local closeButton = SettingsPanel and SettingsPanel.CloseButton;
    if not closeButton then return; end;

    closeButton:HookScript("OnClick", function()
        if reloadButtonAdded then
            C_UI.Reload();
        end;
    end);

    local button = CreateFrame("Button", nil, SettingsPanel, "UIPanelButtonTemplate");
    button:SetText("Reload");
    button:SetSize(closeButton:GetWidth(), closeButton:GetHeight());
    button:SetPoint("RIGHT", closeButton, "LEFT", -5, 0);
    button:SetScript("OnClick", function()
        C_UI.Reload();
    end);
    button:SetShown(reloadButtonAdded);
    closeBarReloadButton = button;
end;

function core.Settings:Initialize()
    CreateCloseBarReloadButton();
    local category, layout = Settings.RegisterVerticalLayoutCategory("ChitChat");
    localCategory = category;
    self.category = category;

    local pages = {
        [false] = { category = category, layout = layout },
    };
    local categories = { category };
    for _, name in ipairs(SUBCATEGORY_NAMES) do
        local subcategory, subcategoryLayout = Settings.RegisterVerticalLayoutSubcategory(category, name);
        pages[name] = { category = subcategory, layout = subcategoryLayout };
        table.insert(categories, subcategory);
    end;

    local initializers = core.SettingInitializers;
    local initializersByKey = {};

    local function RegisterPageSettings(pageName, sections)
        local page = pages[pageName or false];
        for _, section in ipairs(sections) do
            page.layout:AddInitializer(CreateSettingsListSectionHeaderInitializer(section.name));

            for _, setting in ipairs(section.settings) do
                local function registerSetting(settingInfo)
                    local key = settingInfo.key or settingInfo.name;
                    if ChitChatGlobalStorage[key] == nil then
                        ChitChatGlobalStorage[key] = settingInfo.default;
                    end;
                    return Settings.RegisterAddOnSetting(page.category, settingInfo.name, key,
                        ChitChatGlobalStorage,
                        type(settingInfo.default),
                        settingInfo.title,
                        settingInfo.default);
                end;
                local context = {
                    category = page.category,
                    layout = page.layout,
                    registerSetting = registerSetting,
                    createChangedCallback = CreateChangedCallback,
                    initializersByKey = initializersByKey,
                };

                local settingType = GetSettingType(setting);
                local settingInitializer;
                if settingType == "slider" then
                    settingInitializer = initializers.Slider(context, setting);
                elseif settingType == "color" then
                    settingInitializer = initializers.Color(context, setting);
                else
                    settingInitializer = initializers.Checkbox(context, setting);
                end;
                initializersByKey[setting.name] = settingInitializer;
                initializersByKey[setting.key or setting.name] = settingInitializer;
                if setting.options then
                    SaveStringifiedValue(setting);
                end;
            end;
        end;
    end;

    RegisterPageSettings(false, core.Settings[1]);
    for _, name in ipairs(SUBCATEGORY_NAMES) do
        RegisterPageSettings(name, core.Settings[name]);
    end;

    pages[false].layout:AddInitializer(
        CreateSettingsListSectionHeaderInitializer("Overall width & height controlled via chat window edit mode.")
    );

    Settings.RegisterAddOnCategory(category);
    for i = 2, #categories do
        Settings.RegisterAddOnCategory(categories[i]);
    end;
    core.SettingsExample:Initialize(categories);
end;
