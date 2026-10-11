local _, core = ...;
core.Utils = {};

function core.Utils:FilterToNewArray(arr, func)
    local newArray = {};
    local newIndex = 1;
    for oldIndex, v in ipairs(arr) do
        if func(v, oldIndex) then
            newArray[newIndex] = v;
            newIndex = newIndex + 1;
        end;
    end;
    return newArray;
end;

function core.Utils:MapUnique(arr, func)
    local newArray = {};
    local newIndex = 1;
    for oldIndex, v in ipairs(arr) do
        local newValue = func(v, oldIndex);
        local newValueFound = false;
        for i = 0, # newArray do
            if newArray[i] == newValue then
                newValueFound = true;
            end;
        end;
        if not newValueFound then
            newArray[newIndex] = newValue;
            newIndex = newIndex + 1;
        end;
    end;
    return newArray;
end;

function core.Utils:FormatTime(seconds)
    local minutes = floor(seconds / 60);
    local secondsLeft = seconds % 60;
    if secondsLeft < 10 and minutes > 0 then
        secondsLeft = "0" .. secondsLeft;
    end;
    if minutes > 0 then
        return minutes .. ":" .. secondsLeft;
    else
        return secondsLeft;
    end;
end;

function core.Utils:DefaultsTableChecker(current, defaults)
    for key, value in pairs(defaults) do
        if current[key] == nil then
            current[key] = value;
        end;
    end;
end;
