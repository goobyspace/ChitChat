local _, core = ...;

core.SettingsExample = {};
local example = core.SettingsExample;

local WINDOW_WIDTH = 400;
local WINDOW_PADDING = 10;
local MESSAGE_AREA_HEIGHT = 160;
local EDIT_MODE_BORDER_SIZE = 2;
local SAMPLE_NAME = "Gooby";
local CONTROL_TOOLTIPS = {
    QUICK_JOIN or "Quick Join",
    CHAT_CHANNELS or "Channels",
    CHAT_MENU or "Chat Menu",
    false,
    "ChitChat Settings",
};
local CONTROL_ICON_PATH = "Interface\\AddOns\\ChitChat\\Assets\\";
local CONTROL_ICONS = {
    CONTROL_ICON_PATH .. "socialicon.png",
    CONTROL_ICON_PATH .. "chatchannels.png",
    CONTROL_ICON_PATH .. "chattype.png",
    CONTROL_ICON_PATH .. "copypaste.png",
    CONTROL_ICON_PATH .. "cogicon.png",
};

local CONTROL_BUTTON_COUNT = #CONTROL_TOOLTIPS;
-- monk :D
local SAMPLE_COLOUR = CreateColor(0.00, 1.00, 0.60);

local frame;
local messages = {};
local STATIC_MESSAGES = {
    "This is an example of how the chat would look.",
    "This one and the above message never fade.",
};
local FADING_SAMPLE_TEXT = "This message fades out.";
local ANIMATED_SAMPLE_TEXT = "This message animates!";

local function FormatSampleMessage(text)
    local timestamp = "";
    if ChitChatGlobalStorage.chitChatShowTimestamps then
        timestamp = core:GetTimestampText();
        if ChitChatGlobalStorage.chitChatTimestampGap then
            timestamp = timestamp .. " ";
        end;
    end;
    local name = "[" .. SAMPLE_COLOUR:WrapTextInColorCode(SAMPLE_NAME) .. "]";
    return timestamp .. name .. ": " .. text;
end;

function example:CreateWindow()
    if frame then return; end;
    local parent = SettingsPanel or UIParent;
    frame = CreateFrame("Frame", "ChitChatSettingsExample", parent);
    frame:SetWidth(WINDOW_WIDTH);
    frame:SetPoint("TOPLEFT", parent, "TOPRIGHT", 10, 0);
    frame:SetFrameStrata("HIGH");
    frame:Hide();

    frame.messageArea = CreateFrame("Frame", nil, frame);
    frame.messageArea:SetSize(WINDOW_WIDTH - WINDOW_PADDING * 2, MESSAGE_AREA_HEIGHT);
    frame.messageArea:SetClipsChildren(true);

    frame.editModeBox = CreateFrame("Frame", nil, frame);
    frame.editModeBox:SetWidth(WINDOW_WIDTH - WINDOW_PADDING * 2);
    frame.editModeBox:SetPoint("TOPLEFT", frame, "TOPLEFT", WINDOW_PADDING, -WINDOW_PADDING);
    frame.editModeBox:HookScript("OnSizeChanged", function()
        if frame.chatBackground then
            frame.chatBackground:SetOpacity(1);
        end;
    end);

    frame.editModeBorder = CreateFrame("Frame", nil, frame.editModeBox);
    frame.editModeBorder:SetAllPoints(frame.editModeBox);
    frame.editModeBorder:SetFrameLevel(frame:GetFrameLevel() + 20);
    frame.editModeBorder.textures = {};
    for i = 1, 4 do
        local texture = frame.editModeBorder:CreateTexture(nil, "OVERLAY");
        texture:SetColorTexture(0.1, 0.7, 1, 1);
        frame.editModeBorder.textures[i] = texture;
    end;
    frame.editModeBorder.textures[1]:SetPoint("TOPLEFT");
    frame.editModeBorder.textures[1]:SetPoint("TOPRIGHT");
    frame.editModeBorder.textures[1]:SetHeight(EDIT_MODE_BORDER_SIZE);
    frame.editModeBorder.textures[2]:SetPoint("BOTTOMLEFT");
    frame.editModeBorder.textures[2]:SetPoint("BOTTOMRIGHT");
    frame.editModeBorder.textures[2]:SetHeight(EDIT_MODE_BORDER_SIZE);
    frame.editModeBorder.textures[3]:SetPoint("TOPLEFT");
    frame.editModeBorder.textures[3]:SetPoint("BOTTOMLEFT");
    frame.editModeBorder.textures[3]:SetWidth(EDIT_MODE_BORDER_SIZE);
    frame.editModeBorder.textures[4]:SetPoint("TOPRIGHT");
    frame.editModeBorder.textures[4]:SetPoint("BOTTOMRIGHT");
    frame.editModeBorder.textures[4]:SetWidth(EDIT_MODE_BORDER_SIZE);

    frame.controlsArea = CreateFrame("Frame", nil, frame);
    frame.tabsArea = CreateFrame("Frame", nil, frame);
    frame.tabs = {};

    frame.editModeBorderLabel = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall");
    frame.editModeBorderLabel:SetText("Blue border = edit mode box");

    frame.input = CreateFrame("EditBox", nil, frame);
    frame.input:SetFontObject("ChatFontNormal");
    frame.input:SetAutoFocus(false);
    frame.input:SetTextInsets(8, 8, 0, 0);
    frame.input:SetText("Say: Example...");
    frame.input:SetAlpha(1);

    frame.hoverAlpha = { tabs = 1, controls = 1 };
    frame:SetScript("OnShow", function()
        example:UpdateControls();
    end);
    frame:SetScript("OnUpdate", function(_, elapsed)
        example:UpdateHover(elapsed);
    end);
end;

local function RebuildChatBackground()
    if frame.chatBackground then
        for texture in pairs(frame.chatBackground.regions) do
            texture:Hide();
        end;
    end;
    frame.chatBackground = core.CreateGradientBackground(
        frame,
        frame.editModeBox,
        "chat",
        1,
        "BACKGROUND",
        -9
    );
end;

local function IsRowHovered(row, buttons)
    if row:IsMouseOver() then return true; end;
    for _, button in ipairs(buttons) do
        if button:IsMouseOver() then return true; end;
    end;
    return false;
end;

local function ApplyAlpha(item, alpha)
    item:SetAlpha(alpha);
    if item.ChitChatBackground then
        item.ChitChatBackground:SetAlpha(alpha);
    end;
    for _, texture in ipairs(item.ChitChatIconTextures or {}) do
        texture:SetAlpha(alpha);
    end;
end;

function example:UpdateHover(elapsed)
    local config = ChitChatGlobalStorage;
    local alwaysShowControlsAndTabs = config.alwaysShowControlsAndTabs;
    local step = alwaysShowControlsAndTabs and 1 or math.min(elapsed / math.max(config.fadeDuration, 0.01), 1);
    local alphas = frame.hoverAlpha;
    local buttons = frame.controlButtons or {};
    local forced = GetTime() < (frame.forceHoverUntil or 0);
    local controlsHovered = forced or IsRowHovered(frame.controlsArea, buttons);
    local tabsTarget = (alwaysShowControlsAndTabs or forced or frame:IsMouseOver() or controlsHovered)
        and 1 or config.idleAlpha;
    local controlsTarget = (alwaysShowControlsAndTabs or controlsHovered) and 1 or config.idleAlpha;
    alphas.tabs = alphas.tabs + (tabsTarget - alphas.tabs) * step;
    alphas.controls = alphas.controls + (controlsTarget - alphas.controls) * step;
    for _, tab in ipairs(frame.tabs) do
        ApplyAlpha(tab, alphas.tabs);
    end;
    for _, button in ipairs(buttons) do
        ApplyAlpha(button, alphas.controls);
    end;
end;

local TAB_NAMES = { "General", "Trade" };

function example:UpdateTabs()
    if not frame then return; end;
    local config = ChitChatGlobalStorage;
    local area = frame.tabsArea;
    area:SetHeight(config.tabHeight);
    local previous;
    for i, tabName in ipairs(TAB_NAMES) do
        local tab = frame.tabs[i];
        if not tab then
            tab = CreateFrame("Button", nil, area);
            tab.Text = tab:CreateFontString(nil, "OVERLAY", "ChatFontNormal");
            tab.Text:SetText(tabName);
            tab.Text:SetPoint("CENTER");
            tab.Text:SetTextColor(1, 1, 1);
            tab.underline = tab:CreateTexture(nil, "OVERLAY");
            tab.underline:SetColorTexture(1, 1, 1, 1);
            tab.underline:SetHeight(1);
            tab.underline:SetPoint("BOTTOM", tab.Text, "BOTTOM", 0, -2);
            tab.underline:SetWidth(math.max(tab.Text:GetStringWidth(), 1));
            tab.underline:SetShown(i == 1);
            frame.tabs[i] = tab;
        end;
        tab:SetSize(math.max(tab.Text:GetStringWidth(), 1) + 20, config.tabHeight);
        tab:ClearAllPoints();
        if previous then
            tab:SetPoint("LEFT", previous, "RIGHT", 2, 0);
        else
            tab:SetPoint("LEFT", area, "LEFT", 0, 0);
        end;
        previous = tab;

        if tab.ChitChatBackground then
            tab.ChitChatBackground:Hide();
        end;
        local background = CreateFrame("Frame", nil, area);
        background:SetFrameStrata(tab:GetFrameStrata());
        background:SetFrameLevel(math.max(area:GetFrameLevel(), tab:GetFrameLevel() - 1));
        background:SetAllPoints(tab);
        core.CreateGradientBackground(background, background, "chatTab", 1, "ARTWORK");
        tab.ChitChatBackground = background;
    end;
end;

local function RebuildMessageBackground(message)
    if message.backgroundHolder then
        message.backgroundHolder:Hide();
    end;
    message.backgroundHolder = CreateFrame("Frame", nil, message);
    message.backgroundHolder:SetAllPoints(message);
    message.backgroundHolder:SetFrameLevel(math.max(message:GetFrameLevel() - 1, 0));
    message.background = core.CreateGradientBackground(
        message.backgroundHolder,
        message,
        "message",
        1,
        "BACKGROUND",
        -8
    );
    message.background:SetOpacity(1);
end;

local function GetSpacing()
    local config = ChitChatGlobalStorage;
    return config.messagePaddingHorizontal, config.messagePaddingVertical,
        config.messageMarginsHorizontal, config.messageMarginsVertical;
end;

function example:AddMessage(text, persistent, animate)
    if not frame then return; end;
    local message = CreateFrame("Frame", nil, frame.messageArea);
    message.text = message:CreateFontString(nil, "ARTWORK", "ChatFontNormal");
    message.text:SetJustifyH("LEFT");
    message.text:SetWordWrap(true);
    message.text:SetText(FormatSampleMessage(text));
    message.persistent = persistent;
    table.insert(messages, message);
    self:LayoutMessages(not animate);
    if not persistent then
        self:FadeMessage(message);
    end;
    return message;
end;

function example:AddStaticMessages()
    for _, text in ipairs(STATIC_MESSAGES) do
        self:AddMessage(text, true);
    end;
end;

function example:FadeMessage(message)
    local config = ChitChatGlobalStorage;
    local visible = config.messageTimeVisible;
    local fadeDuration = math.max(config.messageFadeDuration, 0.01);
    local elapsed = 0;
    message:SetAlpha(1);
    message:SetScript("OnUpdate", function(self, delta)
        elapsed = elapsed + delta;
        if elapsed < visible then return; end;
        local progress = (elapsed - visible) / fadeDuration;
        if progress >= 1 then
            self:SetAlpha(0);
            self:SetScript("OnUpdate", nil);
            return;
        end;
        self:SetAlpha(1 - progress);
    end);
end;

function example:RestartFadingMessage()
    for i = #messages, 1, -1 do
        messages[i]:SetScript("OnUpdate", nil);
        messages[i]:Hide();
        table.remove(messages, i);
    end;
    self:AddMessage(FADING_SAMPLE_TEXT, false);
    self:AddStaticMessages();
    self:AddMessage(ANIMATED_SAMPLE_TEXT, true, true);
end;

local function UpdateSlide(_, delta)
    local duration = math.max(ChitChatGlobalStorage.slideDuration, 0.01);
    local sliding = false;
    for _, message in ipairs(messages) do
        if message.slideElapsed then
            message.slideElapsed = message.slideElapsed + delta;
            local progress = math.min(message.slideElapsed / duration, 1);
            message.currentY = message.startY + (message.targetY - message.startY) * progress;
            if progress >= 1 then
                message.slideElapsed = nil;
            else
                sliding = true;
            end;
            message:SetPoint("BOTTOMLEFT", frame.messageArea, "BOTTOMLEFT", message.marginH,
                message.currentY + message.marginV);
        end;
    end;
    if not sliding then
        frame.messageArea:SetScript("OnUpdate", nil);
    end;
end;

function example:LayoutMessages(snap)
    if not frame then return; end;
    local paddingH, paddingV, marginH, marginV = GetSpacing();
    local areaWidth = frame.messageArea:GetWidth();
    local y = 0;
    local startSliding = false;
    for i = #messages, 1, -1 do
        local message = messages[i];
        message.text:SetWidth(areaWidth - 2 * (marginH + paddingH));
        message.text:ClearAllPoints();
        message.text:SetPoint("TOPLEFT", paddingH, -paddingV);
        local height = message.text:GetStringHeight() + 2 * paddingV;
        message:SetSize(areaWidth - 2 * marginH, height);
        message.marginH, message.marginV = marginH, marginV;
        message.targetY = y;
        if snap then
            message.currentY = y;
            message.slideElapsed = nil;
        elseif not message.currentY then
            message.currentY = y - ChitChatGlobalStorage.slideDistance - height;
            message.startY = message.currentY;
            message.slideElapsed = 0;
            startSliding = true;
        elseif message.currentY ~= y then
            message.startY = message.currentY;
            message.slideElapsed = 0;
            startSliding = true;
        end;
        message:ClearAllPoints();
        message:SetPoint("BOTTOMLEFT", frame.messageArea, "BOTTOMLEFT", marginH, message.currentY + marginV);
        RebuildMessageBackground(message);
        y = y + height + 2 * marginV;
    end;
    if startSliding then
        frame.messageArea:SetScript("OnUpdate", UpdateSlide);
    end;
end;

function example:UpdateControls(refreshBackgrounds)
    if not frame then return; end;
    local row = frame.controlsArea;
    row:SetFrameStrata(frame:GetFrameStrata());
    row:SetFrameLevel(frame:GetFrameLevel() + 10);
    frame.controlButtons = frame.controlButtons or {};
    local buttons = frame.controlButtons;
    for i = #buttons + 1, CONTROL_BUTTON_COUNT do
        local button = CreateFrame("Button", nil, row);
        button.ChitChatIcon = CONTROL_ICONS[i];
        button:SetScript("OnEnter", function(hovered)
            GameTooltip:SetOwner(hovered, "ANCHOR_RIGHT");
            GameTooltip:SetText(CONTROL_TOOLTIPS[i] or core.HISTORY_BUTTON_TOOLTIP);
            GameTooltip:Show();
        end);
        button:SetScript("OnLeave", function()
            GameTooltip:Hide();
        end);
        buttons[i] = button;
    end;
    local position = core.GetControlPosition();
    local config = ChitChatGlobalStorage;
    local tab = not config.chatTabsAtBottom and frame.tabs[1] or nil;
    core.PositionControlRow(row, frame.messageArea, #buttons, position, tab, false);
    for i, button in ipairs(buttons) do
        if refreshBackgrounds and button.ChitChatBackground then
            button.ChitChatBackground:Hide();
            button.ChitChatBackground = nil;
        end;
        button:Show();
        core.PositionControlButton(button, row, i, position);
    end;
end;

function example:UpdateInput()
    if not frame then return; end;
    local config = ChitChatGlobalStorage;
    local input = frame.input;
    local height = math.max(config.controlSize, 20);
    local area = frame.messageArea;
    local tabs = frame.tabsArea;

    local stack;
    if config.chatTabsAtBottom then
        stack = { area, tabs };
    else
        stack = { tabs, area };
    end;
    if not config.chatBoxTop then
        table.insert(stack, input);
    elseif config.chatBoxAboveTabs or config.chatTabsAtBottom then
        table.insert(stack, 1, input);
    else
        table.insert(stack, 2, input);
    end;

    local insetLeft = config.paddingLeft or 0;
    local insetRight = config.paddingRight or 0;
    local insetTop = config.paddingTop or 0;
    local insetBottom = config.paddingBottom or 0;
    if config.controlsOutside then
        local position = core.GetControlPosition();
        local size = config.controlSize + 2;
        if config.controlsVertical then
            if position.right then
                insetRight = insetRight + size;
            else
                insetLeft = insetLeft + size;
            end;
        elseif position.bottom then
            local bottomPart = (not config.chatBoxTop and input:GetHeight() or 0);
            if config.chatTabsAtBottom then
                bottomPart = math.max(bottomPart, tabs:GetHeight());
            end;
            insetBottom = insetBottom + math.max(size - bottomPart - 2, 0);
        end;
    end;
    local innerWidth = WINDOW_WIDTH - WINDOW_PADDING * 2 - insetLeft - insetRight;
    area:SetWidth(math.max(innerWidth, 1));

    local previous;
    local boxHeight = insetTop + insetBottom;
    local stackOffset = 0;
    for _, part in ipairs(stack) do
        if part == area then
            frame.areaTopOffset = stackOffset;
        end;
        stackOffset = stackOffset + (part == input and height or part:GetHeight()) + 2;
        part:ClearAllPoints();
        if part == input then
            part:SetHeight(height);
        end;
        local partHeight = part:GetHeight();
        if previous then
            part:SetPoint("TOPLEFT", previous, "BOTTOMLEFT", 0, -2);
            boxHeight = boxHeight + 2;
        else
            part:SetPoint("TOPLEFT", frame.editModeBox, "TOPLEFT", insetLeft, -insetTop);
        end;
        part:SetWidth(math.max(innerWidth, 1));
        boxHeight = boxHeight + partHeight;
        previous = part;
    end;
    frame.editModeBox:SetHeight(boxHeight);
    frame.editModeBorderLabel:ClearAllPoints();
    frame.editModeBorderLabel:SetPoint("TOPLEFT", frame.editModeBox, "BOTTOMLEFT", 0, -6);
    local labelHeight = frame.editModeBorderLabel:GetStringHeight();
    frame:SetHeight(WINDOW_PADDING * 2 + boxHeight + 6 + labelHeight);
    if input.backgroundHolder then
        input.backgroundHolder:Hide();
    end;
    input.backgroundHolder = CreateFrame("Frame", nil, input);
    input.backgroundHolder:SetAllPoints(input);
    input.backgroundHolder:SetFrameLevel(math.max(input:GetFrameLevel() - 1, 0));
    input.background = core.CreateGradientBackground(
        input.backgroundHolder,
        input,
        "chatInput",
        1,
        "BACKGROUND",
        -1
    );
    input.background:SetOpacity(1);
end;

function example:UpdateMessageAppearance()
    self:LayoutMessages();
end;

function example:TrackCategories(categories)
    local trackedCategories = {};
    for _, category in ipairs(categories) do
        trackedCategories[category] = true;
    end;
    local function refresh(selected)
        frame:SetShown(trackedCategories[selected] == true);
    end;
    hooksecurefunc(SettingsPanel, "DisplayCategory", function(_, selected)
        refresh(selected);
    end);
    SettingsPanel:HookScript("OnShow", function()
        refresh(SettingsPanel:GetCurrentCategory());
    end);
    refresh(SettingsPanel:GetCurrentCategory());
end;

function example:Initialize(categories)
    self:CreateWindow();
    RebuildChatBackground();
    self:TrackCategories(categories);
    self:UpdateTabs();
    self:UpdateInput();
    self:RestartFadingMessage();
    self:UpdateControls();
end;

function example:Update(settingInfo)
    if not frame then return; end;
    local key = settingInfo.key or settingInfo.name;

    if key:find("^chatBackground") then
        RebuildChatBackground();
        return;
    end;

    if settingInfo.onChange then
        return;
    end;

    if key == "chitChatShowTimestamps" or key == "chitChatTimestamp24Hour"
        or key == "chitChatTimestampLocalTime" or key == "chitChatTimestampColor"
        or key == "chitChatTimestampGap" then
        core:RefreshChatTimestamps();
        self:RestartFadingMessage();
        return;
    end;

    if key:find("^control") or key == "idleAlpha" or key == "alwaysShowControlsAndTabs"
        or key:find("^chatTab") or key == "tabHeight"
        or key == "chatTabsAtBottom" or key == "chatBoxAboveTabs" then
        frame.forceHoverUntil = GetTime() + 2;
    end;

    if key == "alwaysShowControlsAndTabs" then
        self:UpdateControls();
        self:UpdateTabs();
    elseif key:find("^control") or key == "idleAlpha" or key:find("^padding") then
        self:UpdateInput();
        self:UpdateControls(key:find("^controlBackground") ~= nil);
        self:LayoutMessages(true);
    elseif key:find("^chatTab") or key == "tabHeight" then
        self:UpdateTabs();
        self:UpdateInput();
    elseif key:find("^chatInput") or key == "chatBoxTop" or key == "chatBoxAboveTabs" or key == "chatTabsAtBottom" or key == "chatBoxMouseover" then
        self:UpdateInput();
    else
        self:UpdateMessageAppearance();
    end;
end;
