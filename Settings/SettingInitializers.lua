local _, core = ...;

core.SettingInitializers = {};
local initializers = core.SettingInitializers;

local ROW_EXTENT = 26;
local SWATCH_BORDER = 2;

local function AddDependencies(context, settingInfo, initializer)
    if not settingInfo.dependsOn then return; end;
    if not settingInfo.enabledWhen then
        error("ChitChat: A setting dependency requires an enabledWhen predicate.");
    end;

    local dependencies = type(settingInfo.dependsOn) == "table"
        and settingInfo.dependsOn or { settingInfo.dependsOn };
    local parent = context.initializersByKey[dependencies[1]];
    if not parent then
        error("ChitChat: Missing parent setting initializer for " .. dependencies[1] .. ".");
    end;
    initializer:SetParentInitializer(parent, settingInfo.enabledWhen);

    for index = 2, #dependencies do
        local additionalParent = context.initializersByKey[dependencies[index]];
        if not additionalParent then
            error("ChitChat: Missing parent setting initializer for " .. dependencies[index] .. ".");
        end;
        initializer:AddModifyPredicate(settingInfo.enabledWhen);
    end;

    if #dependencies > 1 then
        local baseInitFrame = initializer.InitFrame;
        initializer.InitFrame = function(self, frame)
            if baseInitFrame then baseInitFrame(self, frame); end;
            for index = 2, #dependencies do
                local additionalParent = context.initializersByKey[dependencies[index]];
                local setting = additionalParent:GetSetting();
                frame.cbrHandles:SetOnValueChangedCallback(
                    setting:GetVariable(),
                    frame.EvaluateState,
                    frame
                );
            end;
        end;
    end;
end;

function initializers.Checkbox(context, settingInfo)
    local setting = context.registerSetting(settingInfo);
    setting:SetValueChangedCallback(context.createChangedCallback(settingInfo));

    local initializer = Settings.CreateCheckbox(context.category, setting, settingInfo.description);
    AddDependencies(context, settingInfo, initializer);
    return initializer;
end;

function initializers.Slider(context, settingInfo)
    local setting = context.registerSetting(settingInfo);
    local step = settingInfo.step or 1;
    local function getMin()
        local min = settingInfo.min;
        if type(min) == "function" then return min(); end;
        return min;
    end;
    local function getMax()
        local max = settingInfo.max;
        if type(max) == "function" then return max(); end;
        return max;
    end;
    local function snap(value)
        local min = getMin();
        value = math.max(min, math.min(getMax(), value));
        value = min + math.floor((value - min) / step + 0.5) * step;
        local decimals = 2;
        return tonumber(string.format("%." .. decimals .. "f", value));
    end;

    local changed = context.createChangedCallback(settingInfo);
    local dragging = false;
    local changedDuringDrag = false;
    local activeFrame;
    setting:SetValueChangedCallback(function()
        local value = setting:GetValue();
        local snapped = snap(value);
        if activeFrame and activeFrame.ChitChatEditSetting == setting and activeFrame.ChitChatEditRefresh then
            activeFrame.ChitChatEditRefresh(nil, snapped);
        end;
        if snapped ~= value then
            setting:SetValue(snapped);
        end;
        if dragging and ChitChatGlobalStorage[settingInfo.key or settingInfo.name] ~= snapped then
            changedDuringDrag = true;
        end;
        ChitChatGlobalStorage[settingInfo.key or settingInfo.name] = snapped;
        changed(dragging);
    end);

    local options = Settings.CreateSliderOptions(getMin(), getMax(), step);
    options:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right, function(value)
        if settingInfo.options then
            local option = settingInfo.options[snap(value)];
            if option then return option.text; end;
        end;
        return tostring(snap(value));
    end);
    local initializer = Settings.CreateSlider(context.category, setting, options, settingInfo.description);
    AddDependencies(context, settingInfo, initializer);

    local baseInitFrame = initializer.InitFrame;
    initializer.InitFrame = function(self, frame)
        if baseInitFrame then baseInitFrame(self, frame); end;
        activeFrame = frame;
        local slider = frame.SliderWithSteppers and frame.SliderWithSteppers.Slider;
        if slider and settingInfo.onChange and not frame.ChitChatSliderReleaseHooked then
            frame.ChitChatSliderReleaseHooked = true;
            slider:HookScript("OnMouseDown", function(_, button)
                if button == "LeftButton" then
                    dragging = true;
                    changedDuringDrag = false;
                end;
            end);
            slider:HookScript("OnMouseUp", function()
                if not dragging then return; end;
                dragging = false;
                if changedDuringDrag then
                    settingInfo.onChange(settingInfo);
                end;
                changedDuringDrag = false;
            end);
        end;
        local label = frame.SliderWithSteppers and frame.SliderWithSteppers.RightText;
        if not label then return; end;
        if frame.ChitChatEdit then
            frame.ChitChatEdit:SetShown(not settingInfo.options);
        end;
        label:SetAlpha(settingInfo.options and 1 or 0);
        frame.ChitChatEditSetting = not settingInfo.options and setting or nil;
        frame.ChitChatEditSnap = snap;
        if settingInfo.options then return; end;
        if frame.ChitChatEdit then
            if frame.ChitChatEditRefresh then frame.ChitChatEditRefresh(); end;
            return;
        end;

        local edit = CreateFrame("EditBox", nil, frame, "InputBoxTemplate");
        edit:SetAutoFocus(false);
        edit:SetSize(50, 20);
        local forward = frame.SliderWithSteppers.Forward;
        if forward then
            edit:SetPoint("LEFT", forward, "RIGHT", 12, 0);
        else
            edit:SetPoint("CENTER", label, "CENTER", 10, 0);
        end;
        edit:SetJustifyH("CENTER");
        frame.ChitChatEdit = edit;

        local function refresh(_, sliderValue)
            local current = frame.ChitChatEditSetting;
            if not current or edit:HasFocus() then return; end;
            -- when dragging the slider the setting doesnt update right away, so use the sliders value instead
            local value = sliderValue or (slider and slider:GetValue()) or current:GetValue();
            edit:SetText(tostring(frame.ChitChatEditSnap(value)));
        end;
        frame.ChitChatEditRefresh = refresh;
        refresh();
        edit:SetScript("OnShow", function() refresh(); end);
        if slider then
            slider:HookScript("OnValueChanged", refresh);
        end;

        edit:SetScript("OnEnterPressed", function(box)
            local number = tonumber(box:GetText());
            local current = frame.ChitChatEditSetting;
            if number and current then
                current:SetValue(frame.ChitChatEditSnap(number));
            end;
            box:ClearFocus();
        end);
        edit:SetScript("OnEscapePressed", function(box) box:ClearFocus(); end);
        edit:SetScript("OnEditFocusLost", function(box)
            box:HighlightText(0, 0);
            refresh(box, frame.ChitChatEditSetting and frame.ChitChatEditSetting:GetValue());
        end);
    end;

    return initializer;
end;

function initializers.Color(context, settingInfo)
    local title, description = settingInfo.title, settingInfo.description;
    local setting = context.registerSetting(settingInfo);
    setting:SetValueChangedCallback(context.createChangedCallback(settingInfo));

    local data = Settings.CreateSettingInitializerData(setting, nil, description);
    local initializer = Settings.CreateElementInitializer("SettingsListElementTemplate", data);
    AddDependencies(context, settingInfo, initializer);

    initializer.GetExtent = function() return ROW_EXTENT; end;

    local baseInitFrame = initializer.InitFrame;
    initializer.InitFrame = function(self, frame)
        if not frame.cbrHandles then
            frame.cbrHandles = Settings.CreateCallbackHandleContainer();
        end;
        if baseInitFrame then baseInitFrame(self, frame); end;
        if frame.Text then frame.Text:SetText(title); end;

        if not frame.ChitChatSwatch then
            local swatch = CreateFrame("Button", nil, frame);
            swatch:SetSize(26, 26);
            swatch:SetPoint("LEFT", frame, "CENTER", -80, 0);
            swatch.Color = swatch:CreateTexture(nil, "ARTWORK");
            swatch.Color:SetPoint("TOPLEFT", SWATCH_BORDER, -SWATCH_BORDER);
            swatch.Color:SetPoint("BOTTOMRIGHT", -SWATCH_BORDER, SWATCH_BORDER);
            swatch.Border = swatch:CreateTexture(nil, "BACKGROUND");
            swatch.Border:SetAllPoints();
            swatch.Border:SetColorTexture(1, 1, 1, 1);
            frame.ChitChatSwatch = swatch;
        end;

        local swatch = frame.ChitChatSwatch;
        local function refresh()
            local color = setting:GetValue();
            swatch.Color:SetColorTexture(color.r, color.g, color.b, color.a or 1);
        end;
        refresh();

        swatch:SetScript("OnClick", function()
            local current = setting:GetValue();
            local function apply()
                local r, g, b = ColorPickerFrame:GetColorRGB();
                local a = ColorPickerFrame:GetColorAlpha();
                setting:SetValue({ r = r, g = g, b = b, a = a });
                refresh();
            end;
            ColorPickerFrame:SetupColorPickerAndShow({
                r = current.r,
                g = current.g,
                b = current.b,
                opacity = current.a or 1,
                hasOpacity = true,
                swatchFunc = apply,
                opacityFunc = apply,
                cancelFunc = function()
                    setting:SetValue({ r = current.r, g = current.g, b = current.b, a = current.a });
                    refresh();
                end,
            });
        end);
    end;

    context.layout:AddInitializer(initializer);
    return initializer;
end;
