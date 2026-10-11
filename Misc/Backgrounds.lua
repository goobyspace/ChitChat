local _, core = ...;

local function Clamp(value, minimum, maximum)
	if value < minimum then
		return minimum;
	end;
	if value > maximum then
		return maximum;
	end;
	return value;
end;

local function GetGradientAlpha(x, width, alpha, edgeAlpha, mainColourRatio)
	if width <= 0 then
		return alpha;
	end;

	local gradientWidth = width * (1 - mainColourRatio) / 2;
	if gradientWidth <= 0 then
		return alpha;
	elseif x < gradientWidth then
		return edgeAlpha + (alpha - edgeAlpha) * (x / gradientWidth);
	elseif x <= width - gradientWidth then
		return alpha;
	end;
	return alpha - (alpha - edgeAlpha) * ((x - (width - gradientWidth)) / gradientWidth);
end;

local function GetOneSidedGradientAlpha(x, width, alpha, edgeAlpha, mainColourRatio, mainColourSide)
	if width <= 0 then
		return alpha;
	end;

	if mainColourSide == "right" then
		local mainStart = width * (1 - mainColourRatio);
		if x >= mainStart then
			return alpha;
		elseif mainStart <= 0 then
			return edgeAlpha;
		end;
		return edgeAlpha + (alpha - edgeAlpha) * (x / mainStart);
	end;

	local mainEnd = width * mainColourRatio;
	if x <= mainEnd then
		return alpha;
	elseif mainEnd >= width then
		return edgeAlpha;
	end;
	return alpha - (alpha - edgeAlpha) * ((x - mainEnd) / (width - mainEnd));
end;

local function CreatePart(parent, layer, subLevel, name)
	subLevel = math.max(-8, math.min(7, subLevel or 0));
	local texture = parent:CreateTexture(nil, layer, nil, subLevel);
	texture:SetColorTexture(1, 1, 1, 1);
	local part = {
		name = name,
		texture = texture,
	};
	return part;
end;

local function CreateBackgroundParts(parent, oneSidedGradient, mainColourRatio, layer, subLevel)
	local parts = {};
	local regions = {};
	local function AddPart(name)
		local part = CreatePart(parent, layer, subLevel, name);
		parts[#parts + 1] = part;
		regions[part.texture] = true;
		return part;
	end;

	if oneSidedGradient then
		if mainColourRatio > 0 then
			AddPart("gradientMain");
		end;
		if mainColourRatio < 1 then
			AddPart("gradientFade");
		end;
	elseif mainColourRatio > 0 then
		AddPart("gradientLeft");
		AddPart("gradientCenter");
		AddPart("gradientRight");
	else
		AddPart("left");
		AddPart("right");
	end;

	return parts, regions;
end;

local function CreatePartPositioners(anchor, mainColourRatio, mainColourSide)
	local function GetGradientHalfWidth(width)
		return width * (1 - mainColourRatio) / 2;
	end;

	return {
		gradientMain = function(part, width)
			local startX = mainColourSide == "right" and width * (1 - mainColourRatio) or 0;
			local endX = mainColourSide == "right" and width or width * mainColourRatio;
			part.texture:SetPoint("TOPLEFT", anchor, "TOPLEFT", startX, 0);
			part.texture:SetPoint("BOTTOMRIGHT", anchor, "BOTTOMLEFT", endX, 0);
			return startX, endX;
		end,
		gradientFade = function(part, width)
			local startX = mainColourSide == "right" and 0 or width * mainColourRatio;
			local endX = mainColourSide == "right" and width * (1 - mainColourRatio) or width;
			part.texture:SetPoint("TOPLEFT", anchor, "TOPLEFT", startX, 0);
			part.texture:SetPoint("BOTTOMRIGHT", anchor, "BOTTOMLEFT", endX, 0);
			return startX, endX;
		end,
		gradientLeft = function(part, width)
			local gradientWidth = GetGradientHalfWidth(width);
			part.texture:SetPoint("TOPLEFT", anchor, "TOPLEFT");
			part.texture:SetPoint("BOTTOMLEFT", anchor, "BOTTOMLEFT");
			part.texture:SetWidth(gradientWidth);
			return 0, gradientWidth;
		end,
		gradientCenter = function(part, width)
			local gradientWidth = GetGradientHalfWidth(width);
			part.texture:SetPoint("TOPLEFT", anchor, "TOPLEFT", gradientWidth, 0);
			part.texture:SetPoint("BOTTOMRIGHT", anchor, "BOTTOMRIGHT", -gradientWidth, 0);
			return gradientWidth, width - gradientWidth;
		end,
		gradientRight = function(part, width)
			local gradientWidth = GetGradientHalfWidth(width);
			part.texture:SetPoint("TOPRIGHT", anchor, "TOPRIGHT");
			part.texture:SetPoint("BOTTOMRIGHT", anchor, "BOTTOMRIGHT");
			part.texture:SetWidth(gradientWidth);
			return width - gradientWidth, width;
		end,
		left = function(part, width)
			part.texture:SetPoint("TOPLEFT", anchor, "TOPLEFT");
			part.texture:SetPoint("BOTTOMRIGHT", anchor, "BOTTOM");
			return 0, width / 2;
		end,
		right = function(part, width)
			part.texture:SetPoint("TOPLEFT", anchor, "TOP");
			part.texture:SetPoint("BOTTOMRIGHT", anchor, "BOTTOMRIGHT");
			return width / 2, width;
		end,
	};
end;

local gradientSettingKeys = {
	chat = {
		colour = "chatBackgroundColour",
		gradientMainColourRatio = "chatBackgroundGradientMainColourRatio",
		gradientOneSided = "chatBackgroundGradientOneSided",
		gradientMainColourSide = "chatBackgroundGradientMainColourSideStringifiedValue",
		gradientEdgeOpacity = "chatBackgroundGradientEdgeOpacity",
		useGradient = "chatBackgroundUseGradient",
	},
	message = {
		colour = "messageBackgroundColour",
		gradientMainColourRatio = "messageBackgroundGradientMainColourRatio",
		gradientOneSided = "messageBackgroundGradientOneSided",
		gradientMainColourSide = "messageBackgroundGradientMainColourSideStringifiedValue",
		gradientEdgeOpacity = "messageBackgroundGradientEdgeOpacity",
		useGradient = "messageBackgroundUseGradient",
	},
	chatTab = {
		colour = "chatTabBackgroundColour",
		gradientMainColourRatio = "chatTabBackgroundGradientMainColourRatio",
		gradientOneSided = "chatTabBackgroundGradientOneSided",
		gradientMainColourSide = "chatTabBackgroundGradientMainColourSideStringifiedValue",
		gradientEdgeOpacity = "chatTabBackgroundGradientEdgeOpacity",
		useGradient = "chatTabBackgroundUseGradient",
	},
	control = {
		colour = "controlBackgroundColour",
		gradientMainColourRatio = "controlBackgroundGradientMainColourRatio",
		gradientOneSided = "controlBackgroundGradientOneSided",
		gradientMainColourSide = "controlBackgroundGradientMainColourSideStringifiedValue",
		gradientEdgeOpacity = "controlBackgroundGradientEdgeOpacity",
		useGradient = "controlBackgroundUseGradient",
	},
	chatInput = {
		colour = "chatInputBackgroundColour",
		gradientMainColourRatio = "chatInputBackgroundGradientMainColourRatio",
		gradientOneSided = "chatInputBackgroundGradientOneSided",
		gradientMainColourSide = "chatInputBackgroundGradientMainColourSideStringifiedValue",
		gradientEdgeOpacity = "chatInputBackgroundGradientEdgeOpacity",
		useGradient = "chatInputBackgroundUseGradient",
	},
};

function core.CreateGradientBackground(parent, anchor, settingsName, alpha, layer, subLevel, overrides, chatFrame)
	local settingKeys = gradientSettingKeys[settingsName];
	if not settingKeys then
		error("ChitChat: Unknown gradient settings group " .. tostring(settingsName) .. ".");
	end;

	local function GetSetting(group)
		return core.GetConfig(chatFrame, settingKeys[group]);
	end;
	local colour = overrides and overrides.colour or GetSetting("colour");
	local mainColourRatio = Clamp(GetSetting("gradientMainColourRatio") or 0, 0, 1);
	local oneSidedGradient = GetSetting("gradientOneSided");
	local mainColourSide = GetSetting("gradientMainColourSide") == "right" and "right" or "left";
	local useGradient = overrides and overrides.useGradient;
	if useGradient == nil then
		useGradient = GetSetting("useGradient");
	end;
	local parts, regions = CreateBackgroundParts(
		parent,
		oneSidedGradient,
		mainColourRatio,
		layer,
		subLevel
	);
	local partPositioners = CreatePartPositioners(anchor, mainColourRatio, mainColourSide);

	local function PositionPart(part, width, height)
		local texture = part.texture;
		texture:ClearAllPoints();
		local positioner = partPositioners[part.name];
		if not positioner then
			error("ChitChat: No background positioner for part " .. tostring(part.name) .. ".");
		end;
		part.startX, part.endX = positioner(part, width, height);
	end;

	local lastWidth, lastHeight, lastAlpha;
	local background = {
		regions = regions,
	};
	function background:SetOpacity(opacity)
		local width = anchor:GetWidth();
		local height = anchor:GetHeight();
		if not width or not height then
			return;
		end;
		if lastWidth ~= width or lastHeight ~= height then
			for _, part in ipairs(parts) do
				PositionPart(part, width, height);
			end;
		end;
		if lastAlpha == opacity and lastWidth == width and lastHeight == height then
			return;
		end;

		local effectiveAlpha = opacity * (colour.a or 1);
		local edgeAlpha = effectiveAlpha * (GetSetting("gradientEdgeOpacity") or 0.5);
		for _, part in ipairs(parts) do
			local leftAlpha = effectiveAlpha;
			local rightAlpha = effectiveAlpha;
			if useGradient then
				if oneSidedGradient then
					leftAlpha = GetOneSidedGradientAlpha(
						part.startX,
						width,
						effectiveAlpha,
						edgeAlpha,
						mainColourRatio,
						mainColourSide
					);
					rightAlpha = GetOneSidedGradientAlpha(
						part.endX,
						width,
						effectiveAlpha,
						edgeAlpha,
						mainColourRatio,
						mainColourSide
					);
				else
					leftAlpha = GetGradientAlpha(part.startX, width, effectiveAlpha, edgeAlpha, mainColourRatio);
					rightAlpha = GetGradientAlpha(part.endX, width, effectiveAlpha, edgeAlpha, mainColourRatio);
				end;
				part.texture:SetGradient(
					"HORIZONTAL",
					CreateColor(colour.r, colour.g, colour.b, leftAlpha),
					CreateColor(colour.r, colour.g, colour.b, rightAlpha)
				);
			else
				part.texture:SetGradient(
					"HORIZONTAL",
					CreateColor(colour.r, colour.g, colour.b, effectiveAlpha),
					CreateColor(colour.r, colour.g, colour.b, effectiveAlpha)
				);
			end;
		end;
		lastWidth, lastHeight, lastAlpha = width, height, opacity;
	end;

	background:SetOpacity(alpha);
	return background;
end;
