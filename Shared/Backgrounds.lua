local _, core = ...;

local function IsSecret(value)
	return issecretvalue and issecretvalue(value);
end;

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

local function CreateBackgroundParts(parent, useGradient, oneSidedGradient, mainColourRatio, layer, subLevel)
	local parts = {};
	local regions = {};
	local function AddPart(name)
		local part = CreatePart(parent, layer, subLevel, name);
		parts[#parts + 1] = part;
		regions[part.texture] = true;
		return part;
	end;

	if not useGradient then
		AddPart("solid");
	elseif oneSidedGradient then
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

local function GetPartRange(name, width, mainColourRatio, mainColourSide)
	if name == "solid" then
		return 0, width;
	elseif name == "gradientMain" then
		if mainColourSide == "right" then
			return width * (1 - mainColourRatio), width;
		end;
		return 0, width * mainColourRatio;
	elseif name == "gradientFade" then
		if mainColourSide == "right" then
			return 0, width * (1 - mainColourRatio);
		end;
		return width * mainColourRatio, width;
	elseif name == "gradientLeft" then
		local gradientWidth = width * (1 - mainColourRatio) / 2;
		return 0, gradientWidth;
	elseif name == "gradientCenter" then
		local gradientWidth = width * (1 - mainColourRatio) / 2;
		return gradientWidth, width - gradientWidth;
	elseif name == "gradientRight" then
		local gradientWidth = width * (1 - mainColourRatio) / 2;
		return width - gradientWidth, width;
	elseif name == "left" then
		return 0, width / 2;
	elseif name == "right" then
		return width / 2, width;
	end;
	return 0, width;
end;

function core.CreateGradientBackground(parent, anchor, settings, alpha, layer, subLevel, insets)
	if type(settings) ~= "table" then
		settings = {};
	end;
	if type(settings.colour) ~= "table" then
		settings.colour = { r = 0, g = 0, b = 0, a = 0 };
	end;
	local colour = settings.colour;
	local mainColourRatio = Clamp(settings.mainColourRatio or 0, 0, 1);
	local oneSidedGradient = settings.oneSidedGradient;
	local mainColourSide = settings.mainColourSide == "right" and "right" or "left";
	local useGradient = settings.useGradient;
	local parts, regions = CreateBackgroundParts(
		parent,
		useGradient,
		oneSidedGradient,
		mainColourRatio,
		layer,
		subLevel
	);
	insets = insets or {};
	local insetLeft = insets.left or 0;
	local insetRight = insets.right or 0;
	local insetTop = insets.top or 0;
	local insetBottom = insets.bottom or 0;

	local function PositionPart(part, width, anchorLeft, scale)
		local texture = part.texture;
		texture:ClearAllPoints();
		part.startX, part.endX = GetPartRange(part.name, width, mainColourRatio, mainColourSide);
		if anchorLeft and scale then
			if part.startX > 0 and part.startX < width then
				part.startX = math.floor((anchorLeft + part.startX - insetLeft) * scale + 0.5) / scale
					- anchorLeft + insetLeft;
			end;
			if part.endX > 0 and part.endX < width then
				part.endX = math.floor((anchorLeft + part.endX - insetLeft) * scale + 0.5) / scale
					- anchorLeft + insetLeft;
			end;
		end;
		texture:SetPoint("TOPLEFT", anchor, "TOPLEFT", part.startX - insetLeft, insetTop);
		texture:SetPoint(
			"BOTTOMRIGHT",
			anchor,
			"BOTTOMRIGHT",
			part.endX - width + insetRight,
			-insetBottom
		);
	end;

	local lastWidth, lastHeight, lastAlpha, lastLeft;
	local background = {
		regions = regions,
	};
	function background:SetOpacity(opacity)
		if IsSecret(opacity) then
			return;
		end;

		local anchorWidth = anchor:GetWidth();
		local anchorHeight = anchor:GetHeight();
		local anchorLeft = anchor:GetLeft();
		local geometryIsAccessible = not IsSecret(anchorWidth)
			and not IsSecret(anchorHeight)
			and not IsSecret(anchorLeft);
		local width, height, scale;
		if geometryIsAccessible and type(anchorWidth) == "number" and type(anchorHeight) == "number"
			and (anchorLeft == nil or type(anchorLeft) == "number") then
			width = anchorWidth + insetLeft + insetRight;
			height = anchorHeight + insetTop + insetBottom;
			scale = anchor:GetEffectiveScale();
			if IsSecret(scale) or type(scale) ~= "number" then
				scale = nil;
			end;
		else
			width, height, anchorLeft = lastWidth, lastHeight, lastLeft;
		end;
		if not width or not height then
			return;
		end;
		if lastWidth ~= width or lastHeight ~= height or lastLeft ~= anchorLeft then
			for _, part in ipairs(parts) do
				PositionPart(part, width, anchorLeft, scale);
			end;
		end;
		if lastAlpha == opacity and lastWidth == width and lastHeight == height and lastLeft == anchorLeft then
			return;
		end;

		local effectiveAlpha = opacity * (colour.a or 1);
		local edgeAlpha = effectiveAlpha * (settings.edgeOpacity or 0.5);
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
		lastWidth, lastHeight, lastAlpha, lastLeft = width, height, opacity, anchorLeft;
	end;

	background:SetOpacity(alpha);
	return background;
end;
