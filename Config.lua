local _, core = ...;

core.config = core.config or {};

if core.config.chatBoxTop == nil then
    core.config.chatBoxTop = true;
end;
if core.config.chatBoxAboveTabs == nil then
    core.config.chatBoxAboveTabs = true;
end;
if core.config.chatBoxMouseover == nil then
    core.config.chatBoxMouseover = false;
end;
if core.config.chatTabsAtBottom == nil then
    core.config.chatTabsAtBottom = false;
end;
if core.config.historyEnabled == nil then
    core.config.historyEnabled = true;
end;

core.config.historyLines = core.config.historyLines or 100;

core.config.controlIcon = core.config.controlIcon or "Interface\\Worldmap\\ChatBubble_64Grey";
core.config.controlSize = core.config.controlSize or 24;
core.config.controlSpacing = core.config.controlSpacing or 2;
core.config.controls = core.config.controls or {
    vertical = false,
    outside = false,
    position = "TOPLEFT",
};

core.config.controls.position = core.config.controls.position or "TOPLEFT";

core.config.tabHeight = core.config.tabHeight or 20;
core.config.idleAlpha = core.config.idleAlpha or 0;

core.config.fadeDuration = core.config.fadeDuration or 0.2;
core.config.messageTimeVisible = core.config.messageTimeVisible or 10;
core.config.messageFadeDuration = core.config.messageFadeDuration or 3;

core.config.slideDistance = core.config.slideDistance or 12;
core.config.slideDuration = core.config.slideDuration or 0.2;
core.config.recentMessageWindow = core.config.recentMessageWindow or 0.75;

core.config.messagePadding = core.config.messagePadding or {
    horizontal = 12,
    vertical = 6,
};

core.config.messageMargins = core.config.messageMargins or {
    horizontal = 0,
    vertical = 2,
};

core.config.backgrounds = core.config.backgrounds or {
    message = {
        useGradient = true,
        colour = { r = 0, g = 0, b = 0, a = 0.9 },
        gradientEdgeOpacity = 0,
        gradientMainColourRatio = 0,
        gradientOneSided = true,
        gradientMainColourSide = "left",
        roundedCorners = 0,
    },
    chatInput = {
        useGradient = true,
        colour = { r = 0, g = 0, b = 0, a = 1 },
        gradientEdgeOpacity = 0.5,
        gradientMainColourRatio = 0,
        gradientOneSided = true,
        gradientMainColourSide = "left",
        roundedCorners = 0,
    },
    chatTab = {
        useGradient = true,
        colour = { r = 0, g = 0, b = 0, a = 1 },
        gradientEdgeOpacity = 0.5,
        gradientMainColourRatio = 0,
        gradientOneSided = false,
        gradientMainColourSide = "left",
        roundedCorners = 0,
    },
};

core.padding = core.padding or {
    left = 0,
    right = 0,
    top = 0,
    bottom = 0,
};

core.config.chatBoxMargin = nil;
